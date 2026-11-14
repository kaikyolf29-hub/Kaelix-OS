// Matsu OS — AgenteSenha (ver agente.h).
#include "agente.h"

#include <PolkitQt1/Subject>

#include <QFileInfo>
#include <QVariantMap>

#include <grp.h>
#include <pwd.h>
#include <sys/types.h>
#include <unistd.h>

namespace
{
// O nome que a pessoa reconhece: o nome completo (GECOS) ou o de usuário.
QVariantMap dadosDaPessoa(uid_t uid)
{
    QVariantMap pessoa;
    pessoa[QStringLiteral("uid")] = uint(uid);
    pessoa[QStringLiteral("eu")] = uid == getuid();
    if (const passwd *pw = getpwuid(uid)) {
        const QString usuario = QString::fromLocal8Bit(pw->pw_name);
        QString nome = QString::fromLocal8Bit(pw->pw_gecos).section(QLatin1Char(','), 0, 0).trimmed();
        if (nome.isEmpty()) {
            nome = usuario;
        }
        pessoa[QStringLiteral("usuario")] = usuario;
        pessoa[QStringLiteral("nome")] = nome;
        // A foto: a do AccountsService (tela de login) ou o ~/.face.icon.
        QString foto = QStringLiteral("/var/lib/AccountsService/icons/") + usuario;
        if (!QFileInfo(foto).isReadable()) {
            foto = QString::fromLocal8Bit(pw->pw_dir) + QStringLiteral("/.face.icon");
        }
        pessoa[QStringLiteral("foto")] = QFileInfo(foto).isReadable() ? foto : QString();
    } else {
        pessoa[QStringLiteral("usuario")] = QString::number(uid);
        pessoa[QStringLiteral("nome")] = QString::number(uid);
        pessoa[QStringLiteral("foto")] = QString();
    }
    return pessoa;
}
}

AgenteSenha::AgenteSenha(QObject *pai)
    : PolkitQt1::Agent::Listener(pai)
{
}

AgenteSenha::~AgenteSenha()
{
    // Fechando com um pedido aberto: o polkit fica sabendo que acabou (negado).
    if (m_sessao) {
        m_sessao->disconnect(this);
        m_sessao->cancel();
    }
    if (m_atual) {
        if (m_atual->resultado) {
            m_atual->resultado->setCompleted();
        }
        delete m_atual;
        m_atual = nullptr;
    }
}

bool AgenteSenha::registrar()
{
    if (m_registrado) {
        return true;
    }
    const QString caminho = QStringLiteral("/org/matsu/PolicyKit1/AuthenticationAgent");
    // Para testar sem sessão gráfica (contêiner): o agente só de um processo.
    const qint64 processo = qEnvironmentVariableIntValue("MATSU_SENHA_PID");
    if (processo > 0) {
        m_registrado = registerListener(PolkitQt1::UnixProcessSubject(processo), caminho);
    } else {
        // O agente vale para a sessão gráfica inteira da pessoa (como o do KDE).
        m_registrado = registerListener(PolkitQt1::UnixSessionSubject(getpid()), caminho);
    }
    Q_EMIT registradoMudou();
    return m_registrado;
}

QString AgenteSenha::mensagem() const
{
    return m_atual ? m_atual->mensagem : QString();
}

QString AgenteSenha::icone() const
{
    return m_atual ? m_atual->icone : QString();
}

QString AgenteSenha::acao() const
{
    return m_atual ? m_atual->acao : QString();
}

QString AgenteSenha::programa() const
{
    return m_atual ? m_atual->programa : QString();
}

QString AgenteSenha::comando() const
{
    return m_atual ? m_atual->comando : QString();
}

void AgenteSenha::initiateAuthentication(const QString &actionId, const QString &message, const QString &iconName,
                                         const PolkitQt1::Details &details, const QString &cookie,
                                         const PolkitQt1::Identity::List &identities,
                                         PolkitQt1::Agent::AsyncResult *result)
{
    if (m_atual) {
        result->setError(QStringLiteral("Outro pedido de senha já está aberto; tente de novo depois."));
        result->setCompleted();
        return;
    }
    m_atual = new Pedido;
    m_atual->acao = actionId;
    m_atual->mensagem = message;
    m_atual->icone = iconName;
    // O pkexec diz qual programa vai rodar; outros pedidos não dizem.
    m_atual->programa = details.lookup(QStringLiteral("program"));
    m_atual->comando = details.lookup(QStringLiteral("command_line"));
    m_atual->cookie = cookie;
    m_atual->identidades = identities;
    m_atual->resultado = result;
    m_cancelado = false;
    montarPessoas();
    Q_EMIT pedidoMudou();
    Q_EMIT pessoaMudou();
    Q_EMIT pedido();
    tentar();
}

// As pessoas que podem dar a permissão. O polkit já manda os administradores um
// a um; se vier um grupo (wheel), entram os membros dele. A pessoa da sessão vem
// primeiro, quando ela pode.
void AgenteSenha::montarPessoas()
{
    m_pessoas.clear();
    m_identidades.clear();
    m_pessoa = 0;
    QList<uid_t> vistos;
    auto juntar = [this, &vistos](uid_t uid) {
        if (vistos.contains(uid)) {
            return;
        }
        vistos << uid;
        PolkitQt1::UnixUserIdentity identidade(uid);
        if (!identidade.isValid()) {
            return;
        }
        m_identidades << identidade;
        m_pessoas << dadosDaPessoa(uid);
    };
    for (PolkitQt1::Identity identidade : std::as_const(m_atual->identidades)) {
        const QString texto = identidade.toString();
        if (texto.startsWith(QLatin1String("unix-user:"))) {
            juntar(identidade.toUnixUserIdentity().uid());
        } else if (texto.startsWith(QLatin1String("unix-group:"))) {
            const QByteArray nome = texto.mid(int(qstrlen("unix-group:"))).toLocal8Bit();
            if (const group *g = getgrnam(nome.constData())) {
                for (char **membro = g->gr_mem; membro && *membro; ++membro) {
                    if (const passwd *pw = getpwnam(*membro)) {
                        juntar(pw->pw_uid);
                    }
                }
            }
        }
    }
    const int eu = vistos.indexOf(getuid());
    if (eu > 0) {
        m_identidades.move(eu, 0);
        m_pessoas.move(eu, 0);
    }
}

void AgenteSenha::tentar()
{
    limparSessao();
    if (!m_atual) {
        return;
    }
    if (m_identidades.isEmpty()) {
        // Ninguém pode dar a permissão (sem administrador no sistema).
        Q_EMIT erro(QStringLiteral("sem-pessoa"));
        return;
    }
    m_pergunta.clear();
    m_mostrarTexto = false;
    Q_EMIT perguntaMudou();
    m_sessao = new PolkitQt1::Agent::Session(m_identidades.value(m_pessoa), m_atual->cookie, m_atual->resultado, this);
    connect(m_sessao, &PolkitQt1::Agent::Session::request, this, [this](const QString &texto, bool eco) {
        m_pergunta = texto;
        m_mostrarTexto = eco;
        Q_EMIT perguntaMudou();
        // A pessoa já tinha digitado (a sessão anterior falhou sozinha): vai agora.
        if (!m_pendente.isEmpty() && m_sessao) {
            m_respondeu = true;
            m_sessao->setResponse(m_pendente);
            m_pendente.fill(QLatin1Char(' '));
            m_pendente.clear();
            return;
        }
        if (m_esperando) {
            m_esperando = false;
            Q_EMIT esperandoMudou();
        }
    });
    connect(m_sessao, &PolkitQt1::Agent::Session::showError, this, [this](const QString &texto) {
        m_ultimoErro = texto;
        Q_EMIT erro(texto);
    });
    connect(m_sessao, &PolkitQt1::Agent::Session::showInfo, this, [this](const QString &texto) {
        Q_EMIT info(texto);
    });
    connect(m_sessao, &PolkitQt1::Agent::Session::completed, this, [this](bool autorizado) {
        if (m_esperando) {
            m_esperando = false;
            Q_EMIT esperandoMudou();
        }
        if (autorizado || m_cancelado) {
            acabar(autorizado);
            return;
        }
        if (m_respondeu) {
            // Senha errada: avisa e pergunta de novo, com uma sessão nova.
            Q_EMIT erro(QStringLiteral("senha-errada"));
            tentar();
            return;
        }
        // A conversa com o sistema falhou antes da senha (o ajudante do polkit não
        // abriu, por exemplo): não tenta de novo sozinha, para não ficar em volta;
        // a próxima vez que a pessoa tocar em Permitir começa outra.
        limparSessao();
        m_pendente.clear();
        Q_EMIT erro(QStringLiteral("falhou"));
    });
    m_respondeu = false;
    m_ultimoErro.clear();
    m_sessao->initiate();
}

void AgenteSenha::responder(const QString &senha)
{
    if (!m_atual || m_esperando) {
        return;
    }
    m_esperando = true;
    Q_EMIT esperandoMudou();
    if (!m_sessao || m_pergunta.isEmpty()) {
        // Sem conversa aberta (falhou antes) ou ainda sem a pergunta: a senha
        // espera a pergunta chegar.
        m_pendente = senha;
        if (!m_sessao) {
            tentar();
        }
        return;
    }
    m_respondeu = true;
    m_sessao->setResponse(senha);
}

void AgenteSenha::escolherPessoa(int indice)
{
    if (!m_atual || indice < 0 || indice >= m_identidades.size() || indice == m_pessoa) {
        return;
    }
    m_pessoa = indice;
    Q_EMIT pessoaMudou();
    if (m_sessao) {
        m_sessao->disconnect(this);
        m_sessao->cancel();
    }
    tentar();
}

void AgenteSenha::cancelar()
{
    if (!m_atual) {
        return;
    }
    m_cancelado = true;
    if (m_sessao) {
        m_sessao->disconnect(this);
        m_sessao->cancel();
    }
    acabar(false);
}

bool AgenteSenha::initiateAuthenticationFinish()
{
    return true;
}

// O polkit desistiu do pedido (o programa que pediu fechou, por exemplo).
void AgenteSenha::cancelAuthentication()
{
    cancelar();
}

void AgenteSenha::acabar(bool autorizado)
{
    if (!m_atual) {
        return;
    }
    Pedido *pedido = m_atual;
    m_atual = nullptr;
    limparSessao();
    // O resultado diz ao polkit que a conversa acabou; se a senha não foi aceita,
    // a permissão fica negada.
    if (pedido->resultado) {
        pedido->resultado->setCompleted();
    }
    delete pedido;
    m_pendente.clear();
    m_identidades.clear();
    m_pessoas.clear();
    m_pergunta.clear();
    if (m_esperando) {
        m_esperando = false;
        Q_EMIT esperandoMudou();
    }
    Q_EMIT pedidoMudou();
    Q_EMIT perguntaMudou();
    Q_EMIT terminado(autorizado);
}

void AgenteSenha::limparSessao()
{
    if (m_sessao) {
        m_sessao->disconnect(this);
        m_sessao->deleteLater();
        m_sessao.clear();
    }
}
