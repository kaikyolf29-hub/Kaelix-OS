// Matsu OS — AgenteSenha: a janela de senha do sistema (agente do polkit).
//
// Quando um programa pede permissão de administrador (instalar driver, mudar o
// firewall, "abrir mesmo assim"...), o polkit pergunta a senha por um "agente".
// O do KDE tem a cara do KDE; este é do Matsu: a matsu-janela carrega
// /usr/share/matsu/senha/Main.qml, que usa este tipo:
//
//   import org.matsu.senha
//   AgenteSenha {
//       id: agente
//       onPedido: janela.show()            // chegou um pedido: mostrar a janela
//       onErro: (texto) => ...             // senha errada (o pedido continua)
//       onTerminado: (autorizado) => ...   // acabou: esconder a janela
//   }
//   agente.registrar()                     // vira o agente da sessão (false se não deu)
//   agente.responder(senha)                // manda a senha digitada
//   agente.escolherPessoa(i)               // com mais de um administrador
//   agente.cancelar()
//
// Um pedido por vez, como no agente do KDE: um segundo pedido ao mesmo tempo
// volta com "tente de novo" (o polkit não diz qual pedido foi cancelado, então
// uma fila confundiria os dois). A senha errada não fecha a janela (o PAM decide
// se trava depois de muitas tentativas).
#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QVariantList>

#include <PolkitQt1/Agent/Listener>
#include <PolkitQt1/Agent/Session>
#include <PolkitQt1/Details>
#include <PolkitQt1/Identity>

class AgenteSenha : public PolkitQt1::Agent::Listener
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool registrado READ registrado NOTIFY registradoMudou)
    Q_PROPERTY(bool ativo READ ativo NOTIFY pedidoMudou)
    Q_PROPERTY(QString mensagem READ mensagem NOTIFY pedidoMudou)
    Q_PROPERTY(QString icone READ icone NOTIFY pedidoMudou)
    Q_PROPERTY(QString acao READ acao NOTIFY pedidoMudou)
    Q_PROPERTY(QString programa READ programa NOTIFY pedidoMudou)
    Q_PROPERTY(QString comando READ comando NOTIFY pedidoMudou)
    Q_PROPERTY(QVariantList pessoas READ pessoas NOTIFY pedidoMudou)
    Q_PROPERTY(int pessoa READ pessoa NOTIFY pessoaMudou)
    Q_PROPERTY(QString pergunta READ pergunta NOTIFY perguntaMudou)
    Q_PROPERTY(bool mostrarTexto READ mostrarTexto NOTIFY perguntaMudou)
    Q_PROPERTY(bool esperando READ esperando NOTIFY esperandoMudou)

public:
    explicit AgenteSenha(QObject *pai = nullptr);
    ~AgenteSenha() override;

    bool registrado() const { return m_registrado; }
    bool ativo() const { return m_atual != nullptr; }
    QString mensagem() const;
    QString icone() const;
    QString acao() const;
    QString programa() const;
    QString comando() const;
    QVariantList pessoas() const { return m_pessoas; }
    int pessoa() const { return m_pessoa; }
    QString pergunta() const { return m_pergunta; }
    bool mostrarTexto() const { return m_mostrarTexto; }
    bool esperando() const { return m_esperando; }

    Q_INVOKABLE bool registrar();
    Q_INVOKABLE void responder(const QString &senha);
    Q_INVOKABLE void escolherPessoa(int indice);
    Q_INVOKABLE void cancelar();

    // O que o polkit chama.
    void initiateAuthentication(const QString &actionId, const QString &message, const QString &iconName,
                                const PolkitQt1::Details &details, const QString &cookie,
                                const PolkitQt1::Identity::List &identities,
                                PolkitQt1::Agent::AsyncResult *result) override;
    bool initiateAuthenticationFinish() override;
    void cancelAuthentication() override;

Q_SIGNALS:
    void registradoMudou();
    void pedidoMudou();
    void pessoaMudou();
    void perguntaMudou();
    void esperandoMudou();
    void pedido();
    void erro(const QString &texto);
    void info(const QString &texto);
    void terminado(bool autorizado);

private:
    struct Pedido {
        QString acao;
        QString mensagem;
        QString icone;
        QString programa;
        QString comando;
        QString cookie;
        PolkitQt1::Identity::List identidades;
        PolkitQt1::Agent::AsyncResult *resultado = nullptr;
    };

    void tentar();
    void acabar(bool autorizado);
    void limparSessao();
    void montarPessoas();

    bool m_registrado = false;
    Pedido *m_atual = nullptr;
    QPointer<PolkitQt1::Agent::Session> m_sessao;
    QVariantList m_pessoas;
    PolkitQt1::Identity::List m_identidades;
    int m_pessoa = 0;
    QString m_pergunta;
    bool m_mostrarTexto = false;
    bool m_esperando = false;
    bool m_cancelado = false;
    bool m_respondeu = false;     // a senha foi mandada nesta conversa
    QString m_pendente;           // senha digitada antes da pergunta chegar
    QString m_ultimoErro;
};
