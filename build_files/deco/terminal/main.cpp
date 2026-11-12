// Matsu OS — o terminal do Matsu.
//
// A janela é nossa: vidro em cinza neutro (o mesmo dos apps do Matsu), as
// bolinhas de fechar, minimizar e tela cheia, as abas em pílula com a cor de
// cada uma, e embaixo uma barra com a pasta, o ramo do git, o programa que está
// rodando e o tamanho do terminal. O terminal em si é o do Konsole (a peça
// "konsolepart"), que é rápido e completo: cores, fontes, busca, dividir a tela.
//
// Uso: matsu-terminal [--workdir PASTA] [--hold] [-e PROGRAMA [ARGUMENTOS...]]
//   --workdir  pasta onde o terminal começa (padrão: a pasta de onde foi aberto)
//   -e         roda o programa em vez do shell
//   --hold     com -e, deixa a aba aberta quando o programa termina
//
// Se a peça do Konsole não estiver instalada, abre o próprio Konsole.
#include <QAction>
#include <QApplication>
#include <QDesktopServices>
#include <QDir>
#include <QEasingCurve>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QKeyEvent>
#include <QMenu>
#include <QMessageBox>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QPlatformSurfaceEvent>
#include <QPointer>
#include <QProcess>
#include <QPushButton>
#include <QStackedWidget>
#include <QTimer>
#include <QToolTip>
#include <QUrl>
#include <QWindow>
#include <QtMath>

#include <KActionCollection>
#include <KConfig>
#include <KConfigGroup>
#include <KParts/ReadOnlyPart>
#include <KPluginFactory>
#include <KPluginMetaData>
#include <KSharedConfig>
#include <KWindowEffects>
#include <KWindowShadow>
#include <KWindowSystem>
#include <KXMLGUIClient>
#include <kde_terminal_interface.h>

#include <fcntl.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

#include <cstdio>
#include <memory>
#include <vector>

// ---------------------------------------------------------------------------
// Língua: português quando o sistema está em português.
static bool emPortugues()
{
    static const bool pt = QLocale::system().name().startsWith(QLatin1String("pt"));
    return pt;
}
static QString t(const char *portugues, const char *ingles)
{
    return QString::fromUtf8(emPortugues() ? portugues : ingles);
}

// ---------------------------------------------------------------------------
// Medidas da janela (em pontos lógicos).
namespace Medida
{
constexpr int raio = 10;        // cantos da janela (o mesmo dos apps do Matsu)
constexpr int cabecalho = 46;   // bolinhas e abas
constexpr int rodape = 30;      // pasta, git, programa e tamanho
constexpr int lado = 8;         // vidro dos lados do terminal (é onde se pega para redimensionar)
constexpr int raioCartao = 8;   // cantos do terminal
constexpr int borda = 6;        // faixa da borda que redimensiona a janela
constexpr int pilula = 30;      // altura das abas e dos botões do cabeçalho
}

// ---------------------------------------------------------------------------
// As cores: o vidro neutro dos apps do Matsu (veja comum/JanelaMatsu.qml).
struct Tema {
    bool escuro = true;
    bool desfoque = true;          // o KWin desfoca o que está atrás
    QString nivel = QStringLiteral("normal");
    QColor corVidro;               // a cor que a pessoa escolheu no "matsu vidro" (vazio: sem cor)

    qreal opacidade() const
    {
        if (!desfoque) {
            return 1.0;
        }
        if (nivel == QLatin1String("mais")) {
            return 0.6;
        }
        if (nivel == QLatin1String("menos")) {
            return 0.85;
        }
        return 0.72;
    }
    QColor frente() const
    {
        return escuro ? QColor(255, 255, 255) : QColor(0x1a, 0x1a, 0x1e);
    }
    QColor tinta(qreal a) const
    {
        QColor c = frente();
        c.setAlphaF(a);
        return c;
    }
    QColor fundo() const
    {
        QColor c = escuro ? QColor::fromRgbF(0.125, 0.125, 0.133) : QColor::fromRgbF(0.953, 0.953, 0.96);
        if (corVidro.isValid()) {
            // A cor do vidro bem de leve, como nos outros apps.
            c = QColor::fromRgbF(c.redF() * 0.93 + corVidro.redF() * 0.07, c.greenF() * 0.93 + corVidro.greenF() * 0.07,
                                 c.blueF() * 0.93 + corVidro.blueF() * 0.07);
        }
        c.setAlphaF(opacidade());
        return c;
    }
    QColor bordaJanela() const
    {
        return escuro ? QColor::fromRgbF(1, 1, 1, 0.13) : QColor::fromRgbF(0, 0, 0, 0.14);
    }
    // A cor de cada aba, as mesmas cores das partes do computador no Matsu.
    QColor corAba(int i) const
    {
        static const char *escuras[] = {"#45d0c1", "#b18cf5", "#f0729f", "#f59f6b", "#7fcf6a"};
        static const char *claras[] = {"#0f9c8e", "#7650dc", "#d23f78", "#d8692a", "#3d9533"};
        return QColor(QLatin1String((escuro ? escuras : claras)[((i % 5) + 5) % 5]));
    }
    QColor verde() const
    {
        return corAba(0);
    }
    QColor laranja() const
    {
        return corAba(3);
    }
    QString perfil() const
    {
        QString p = escuro ? QStringLiteral("Matsu Terminal") : QStringLiteral("Matsu Terminal Claro");
        return desfoque ? p : p + QStringLiteral(" Sólido");
    }
};
static Tema tema;

// Cores neutras para o que a peça do Konsole desenha com as cores do sistema
// (barrinha de cada lado da tela dividida, linha entre eles, busca e menu do
// botão direito): o mesmo cinza do vidro, sem o azul do esquema de cores.
static QPalette paletaNeutra(QPalette p)
{
    const bool e = tema.escuro;
    auto cor = [&p](QPalette::ColorRole papel, const QColor &c, const QColor &desligada = QColor()) {
        p.setColor(QPalette::Active, papel, c);
        p.setColor(QPalette::Inactive, papel, c);
        p.setColor(QPalette::Disabled, papel, desligada.isValid() ? desligada : c);
    };
    const QColor texto = e ? QColor(236, 236, 241) : QColor(30, 30, 36);
    const QColor textoDesligado = e ? QColor(120, 120, 128) : QColor(150, 150, 158);
    cor(QPalette::Window, e ? QColor(31, 31, 34) : QColor(240, 240, 242));
    cor(QPalette::WindowText, texto, textoDesligado);
    cor(QPalette::Base, e ? QColor(22, 22, 24) : QColor(252, 252, 253));
    cor(QPalette::AlternateBase, e ? QColor(30, 30, 33) : QColor(244, 244, 246));
    cor(QPalette::Text, texto, textoDesligado);
    cor(QPalette::Button, e ? QColor(44, 44, 48) : QColor(232, 232, 236));
    cor(QPalette::ButtonText, texto, textoDesligado);
    cor(QPalette::BrightText, e ? QColor(255, 255, 255) : QColor(0, 0, 0));
    cor(QPalette::Light, e ? QColor(72, 72, 78) : QColor(255, 255, 255));
    cor(QPalette::Midlight, e ? QColor(58, 58, 64) : QColor(236, 236, 240));
    cor(QPalette::Mid, e ? QColor(52, 52, 58) : QColor(200, 200, 206));
    cor(QPalette::Dark, e ? QColor(20, 20, 22) : QColor(170, 170, 178));
    cor(QPalette::Shadow, QColor(0, 0, 0));
    cor(QPalette::Highlight, e ? QColor(82, 82, 92) : QColor(206, 206, 214));
    cor(QPalette::HighlightedText, texto);
    cor(QPalette::ToolTipBase, e ? QColor(40, 40, 44) : QColor(250, 250, 251));
    cor(QPalette::ToolTipText, texto);
    cor(QPalette::PlaceholderText, textoDesligado);
    cor(QPalette::Link, tema.corAba(0));
    return p;
}

static void lerVidro()
{
    const QString pasta = qEnvironmentVariableIsSet("MATSU_STATE_DIR")
        ? qEnvironmentVariable("MATSU_STATE_DIR")
        : QDir::homePath() + QStringLiteral("/.config/matsu");
    QFile f(pasta + QStringLiteral("/vidro"));
    QString cor;
    QString nivel = QStringLiteral("normal");
    if (f.open(QIODevice::ReadOnly)) {
        const auto linhas = QString::fromUtf8(f.readAll()).split(QLatin1Char('\n'));
        for (const QString &linha : linhas) {
            const QString chave = linha.section(QLatin1Char('='), 0, 0).trimmed();
            const QString valor = linha.section(QLatin1Char('='), 1).trimmed().toLower();
            if (chave == QLatin1String("cor")) {
                cor = valor;
            } else if (chave == QLatin1String("transparencia")) {
                nivel = valor;
            }
        }
    }
    static const QHash<QString, QString> nomes = {
        {QStringLiteral("azul"), QStringLiteral("#2f80ed")},     {QStringLiteral("roxo"), QStringLiteral("#8b5cf6")},
        {QStringLiteral("rosa"), QStringLiteral("#ec4899")},     {QStringLiteral("vermelho"), QStringLiteral("#ef4444")},
        {QStringLiteral("laranja"), QStringLiteral("#f97316")},  {QStringLiteral("amarelo"), QStringLiteral("#eab308")},
        {QStringLiteral("verde"), QStringLiteral("#22c55e")},    {QStringLiteral("grafite"), QStringLiteral("#6b7280")},
    };
    cor = nomes.value(cor, cor);
    tema.corVidro = QColor::isValidColorName(cor) && cor.startsWith(QLatin1Char('#')) ? QColor(cor) : QColor();
    tema.nivel = (nivel == QLatin1String("mais") || nivel == QLatin1String("menos") || nivel == QLatin1String("sem"))
        ? nivel : QStringLiteral("normal");
}

static bool temDesfoque()
{
    // Para testes e prévias: forçar o vidro ligado ou desligado.
    if (qEnvironmentVariableIsSet("MATSU_TERMINAL_SEM_VIDRO")) {
        return false;
    }
    if (qEnvironmentVariableIsSet("MATSU_TERMINAL_COM_VIDRO")) {
        return true;
    }
    // "Sem vidro" nos Ajustes (matsu vidro --transparencia sem): janela sólida.
    if (tema.nivel == QLatin1String("sem")) {
        return false;
    }
    return KWindowEffects::isEffectAvailable(KWindowEffects::BlurBehind);
}

// ---------------------------------------------------------------------------
// Valores que andam suavemente até o alvo (passar o mouse, abrir e fechar abas).
class Suave : public QObject
{
public:
    explicit Suave(QWidget *dono)
        : QObject(dono)
        , m_dono(dono)
    {
        m_relogio.setInterval(16);
        connect(&m_relogio, &QTimer::timeout, this, &Suave::passo);
    }

    // Pede o valor de "chave" indo para "alvo". Uma chave nova começa em "inicio"
    // (ou já no alvo, sem animação, se "inicio" for negativo).
    qreal operator()(const QString &chave, qreal alvo, qreal inicio = -1, qreal velocidade = 16)
    {
        auto it = m_valores.find(chave);
        if (it == m_valores.end()) {
            it = m_valores.insert(chave, {inicio < 0 ? alvo : inicio, alvo, velocidade});
        }
        it->velocidade = velocidade;
        if (!qFuzzyCompare(it->alvo + 1, alvo + 1)) {
            it->alvo = alvo;
        }
        if (!qFuzzyCompare(it->atual + 1, it->alvo + 1) && !m_relogio.isActive()) {
            m_tempo.start();
            m_relogio.start();
        }
        return it->atual;
    }
    // Põe o valor atual num ponto (a animação segue dali até o alvo).
    void definir(const QString &chave, qreal atual)
    {
        auto it = m_valores.find(chave);
        if (it != m_valores.end()) {
            it->atual = atual;
            if (!m_relogio.isActive()) {
                m_tempo.start();
                m_relogio.start();
            }
        }
    }
    void esquecer(const QString &prefixo)
    {
        for (auto it = m_valores.begin(); it != m_valores.end();) {
            it = it.key().startsWith(prefixo) ? m_valores.erase(it) : std::next(it);
        }
    }

private:
    struct Valor {
        qreal atual;
        qreal alvo;
        qreal velocidade;
    };

    void passo()
    {
        const qreal dt = qBound(0.001, m_tempo.restart() / 1000.0, 0.05);
        bool mexendo = false;
        for (Valor &v : m_valores) {
            const qreal falta = v.alvo - v.atual;
            if (qAbs(falta) < 0.002) {
                v.atual = v.alvo;
                continue;
            }
            v.atual += falta * (1 - qExp(-dt * v.velocidade));
            mexendo = true;
        }
        m_dono->update();
        if (!mexendo) {
            m_relogio.stop();
        }
    }

    QWidget *m_dono;
    QHash<QString, Valor> m_valores;
    QTimer m_relogio;
    QElapsedTimer m_tempo;
};

// ---------------------------------------------------------------------------
// Desenhos pequenos (traço fino e arredondado, como os ícones de linha do Matsu).
namespace Desenho
{
static QPen traco(const QColor &cor, qreal largura = 1.5)
{
    return QPen(cor, largura, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
}

// O símbolo das abas: o sinal de prompt "›_".
static void prompt(QPainter &p, const QRectF &r, const QColor &cor)
{
    p.setPen(traco(cor, 1.6));
    p.setBrush(Qt::NoBrush);
    const qreal x = r.x(), y = r.y(), s = r.width() / 16.0;
    QPainterPath seta;
    seta.moveTo(x + 2.5 * s, y + 4 * s);
    seta.lineTo(x + 6.5 * s, y + 8 * s);
    seta.lineTo(x + 2.5 * s, y + 12 * s);
    p.drawPath(seta);
    p.drawLine(QPointF(x + 8.5 * s, y + 12 * s), QPointF(x + 13.5 * s, y + 12 * s));
}

static void mais(QPainter &p, const QPointF &c, const QColor &cor)
{
    p.setPen(traco(cor, 1.6));
    p.drawLine(QPointF(c.x() - 5.5, c.y()), QPointF(c.x() + 5.5, c.y()));
    p.drawLine(QPointF(c.x(), c.y() - 5.5), QPointF(c.x(), c.y() + 5.5));
}

static void xis(QPainter &p, const QPointF &c, qreal t, const QColor &cor, qreal largura = 1.4)
{
    p.setPen(traco(cor, largura));
    p.drawLine(QPointF(c.x() - t, c.y() - t), QPointF(c.x() + t, c.y() + t));
    p.drawLine(QPointF(c.x() + t, c.y() - t), QPointF(c.x() - t, c.y() + t));
}

// Dividir: um quadro com uma linha no meio.
static void dividir(QPainter &p, const QPointF &c, const QColor &cor)
{
    p.setPen(traco(cor, 1.4));
    p.setBrush(Qt::NoBrush);
    const QRectF r(c.x() - 7.5, c.y() - 6.5, 15, 13);
    p.drawRoundedRect(r, 3, 3);
    p.drawLine(QPointF(c.x(), r.top() + 0.5), QPointF(c.x(), r.bottom() - 0.5));
}

// Menu: três pontos.
static void pontos(QPainter &p, const QPointF &c, const QColor &cor)
{
    p.setPen(Qt::NoPen);
    p.setBrush(cor);
    for (int i = -1; i <= 1; ++i) {
        p.drawEllipse(QPointF(c.x() + i * 5.0, c.y()), 1.45, 1.45);
    }
}

static void pasta(QPainter &p, const QRectF &r, const QColor &cor)
{
    p.setPen(traco(cor, 1.3));
    p.setBrush(Qt::NoBrush);
    const qreal x = r.x(), y = r.y();
    QPainterPath c;
    c.moveTo(x + 1.5, y + 3.5);
    c.quadTo(x + 1.5, y + 2, x + 3, y + 2);
    c.lineTo(x + 5.6, y + 2);
    c.lineTo(x + 7.1, y + 3.7);
    c.lineTo(x + 11, y + 3.7);
    c.quadTo(x + 12.5, y + 3.7, x + 12.5, y + 5.2);
    c.lineTo(x + 12.5, y + 10.5);
    c.quadTo(x + 12.5, y + 12, x + 11, y + 12);
    c.lineTo(x + 3, y + 12);
    c.quadTo(x + 1.5, y + 12, x + 1.5, y + 10.5);
    c.closeSubpath();
    p.drawPath(c);
}

// Monitor (htop, btop...): barrinhas de gráfico em cima de uma linha.
static void grafico(QPainter &p, const QRectF &r, const QColor &cor)
{
    p.setPen(traco(cor, 1.6));
    const qreal x = r.x(), y = r.y(), s = r.width() / 16.0;
    p.drawLine(QPointF(x + 2.5 * s, y + 13 * s), QPointF(x + 13.5 * s, y + 13 * s));
    p.drawLine(QPointF(x + 4.5 * s, y + 10.5 * s), QPointF(x + 4.5 * s, y + 8 * s));
    p.drawLine(QPointF(x + 7 * s, y + 10.5 * s), QPointF(x + 7 * s, y + 4.5 * s));
    p.drawLine(QPointF(x + 9.5 * s, y + 10.5 * s), QPointF(x + 9.5 * s, y + 6.5 * s));
    p.drawLine(QPointF(x + 12 * s, y + 10.5 * s), QPointF(x + 12 * s, y + 9 * s));
}

// Outro computador (ssh): duas gavetas de servidor com uma luzinha cada.
static void servidor(QPainter &p, const QRectF &r, const QColor &cor)
{
    p.setPen(traco(cor, 1.4));
    p.setBrush(Qt::NoBrush);
    const qreal x = r.x(), y = r.y(), s = r.width() / 16.0;
    p.drawRoundedRect(QRectF(x + 2.5 * s, y + 2.5 * s, 11 * s, 4.6 * s), 1.4 * s, 1.4 * s);
    p.drawRoundedRect(QRectF(x + 2.5 * s, y + 8.9 * s, 11 * s, 4.6 * s), 1.4 * s, 1.4 * s);
    p.setPen(Qt::NoPen);
    p.setBrush(cor);
    p.drawEllipse(QPointF(x + 5 * s, y + 4.8 * s), 0.95 * s, 0.95 * s);
    p.drawEllipse(QPointF(x + 5 * s, y + 11.2 * s), 0.95 * s, 0.95 * s);
}

// Editor de texto (nano, vim...): um lápis inclinado.
static void lapis(QPainter &p, const QRectF &r, const QColor &cor)
{
    p.setPen(traco(cor, 1.4));
    p.setBrush(Qt::NoBrush);
    const qreal x = r.x(), y = r.y(), s = r.width() / 16.0;
    QPainterPath c;
    c.moveTo(x + 10.2 * s, y + 3.3 * s);
    c.lineTo(x + 12.7 * s, y + 5.8 * s);
    c.lineTo(x + 5.6 * s, y + 12.9 * s);
    c.lineTo(x + 2.6 * s, y + 13.4 * s);
    c.lineTo(x + 3.1 * s, y + 10.4 * s);
    c.closeSubpath();
    p.drawPath(c);
    p.drawLine(QPointF(x + 8.6 * s, y + 4.9 * s), QPointF(x + 11.1 * s, y + 7.4 * s));
}

// O ramo do git: duas bolinhas ligadas e uma terceira saindo de lado.
static void ramo(QPainter &p, const QRectF &r, const QColor &cor)
{
    p.setPen(traco(cor, 1.3));
    p.setBrush(Qt::NoBrush);
    const qreal x = r.x(), y = r.y();
    p.drawEllipse(QPointF(x + 4, y + 2.8), 1.6, 1.6);
    p.drawEllipse(QPointF(x + 4, y + 11.2), 1.6, 1.6);
    p.drawEllipse(QPointF(x + 10.5, y + 4.6), 1.6, 1.6);
    p.drawLine(QPointF(x + 4, y + 4.4), QPointF(x + 4, y + 9.6));
    QPainterPath curva;
    curva.moveTo(x + 10.5, y + 6.2);
    curva.cubicTo(x + 10.5, y + 9, x + 4.5, y + 7.5, x + 4.2, y + 9.4);
    p.drawPath(curva);
}
}

// O símbolo de cada aba muda com o programa que está rodando nela: gráfico para
// os monitores, servidor para o ssh, lápis para os editores e o ramo para as
// ferramentas do git. No resto, o "›_" de sempre.
static void simboloDoPrograma(QPainter &p, const QRectF &r, const QColor &cor, const QString &programa)
{
    static const QStringList monitores = {QStringLiteral("htop"), QStringLiteral("btop"), QStringLiteral("top"),
        QStringLiteral("nvtop"), QStringLiteral("glances"), QStringLiteral("bpytop"), QStringLiteral("atop"),
        QStringLiteral("radeontop"), QStringLiteral("watch")};
    static const QStringList remotos = {QStringLiteral("ssh"), QStringLiteral("mosh"), QStringLiteral("mosh-client"),
        QStringLiteral("sftp"), QStringLiteral("telnet")};
    static const QStringList editores = {QStringLiteral("nano"), QStringLiteral("vim"), QStringLiteral("nvim"),
        QStringLiteral("vi"), QStringLiteral("micro"), QStringLiteral("hx"), QStringLiteral("helix"),
        QStringLiteral("emacs"), QStringLiteral("kak")};
    static const QStringList git = {QStringLiteral("git"), QStringLiteral("lazygit"), QStringLiteral("tig"),
        QStringLiteral("gitui")};
    const QString nome = programa.toLower();
    if (monitores.contains(nome)) {
        Desenho::grafico(p, r, cor);
    } else if (remotos.contains(nome)) {
        Desenho::servidor(p, r, cor);
    } else if (editores.contains(nome)) {
        Desenho::lapis(p, r, cor);
    } else if (git.contains(nome)) {
        Desenho::ramo(p, r.adjusted(1, 1, -1, -1), cor);
    } else {
        Desenho::prompt(p, r, cor);
    }
}

// ---------------------------------------------------------------------------
// A sombra e o desfoque da janela (o mesmo jeito da matsu-janela).
static void caixa(uchar *dados, int n, int passo, int r, std::vector<int> &tmp)
{
    for (int i = 0; i < n; ++i) {
        tmp[i] = dados[i * passo];
    }
    int soma = 0;
    for (int i = 0; i <= r && i < n; ++i) {
        soma += tmp[i];
    }
    for (int i = 0; i < n; ++i) {
        dados[i * passo] = uchar(soma / (2 * r + 1));
        const int sai = i - r;
        const int entra = i + r + 1;
        if (sai >= 0) {
            soma -= tmp[sai];
        }
        if (entra < n) {
            soma += tmp[entra];
        }
    }
}

static QImage imagemDaSombra(int borda, int raio)
{
    const int lado = 2 * (borda + raio) + 1;
    QImage mascara(lado, lado, QImage::Format_Alpha8);
    mascara.fill(0);
    {
        QPainter p(&mascara);
        p.setRenderHint(QPainter::Antialiasing);
        p.setPen(Qt::NoPen);
        p.setBrush(QColor(0, 0, 0, 255));
        p.drawRoundedRect(QRectF(borda, borda + borda / 6.0, lado - 2 * borda, lado - 2 * borda), raio, raio);
    }
    std::vector<int> tmp(lado);
    const int r = qMax(1, borda / 3);
    for (int passada = 0; passada < 3; ++passada) {
        for (int y = 0; y < lado; ++y) {
            caixa(mascara.scanLine(y), lado, 1, r, tmp);
        }
        for (int x = 0; x < lado; ++x) {
            caixa(mascara.bits() + x, lado, int(mascara.bytesPerLine()), r, tmp);
        }
    }
    QImage sombra(lado, lado, QImage::Format_ARGB32_Premultiplied);
    for (int y = 0; y < lado; ++y) {
        const uchar *m = mascara.constScanLine(y);
        auto *s = reinterpret_cast<QRgb *>(sombra.scanLine(y));
        for (int x = 0; x < lado; ++x) {
            s[x] = qRgba(0, 0, 0, int(m[x] * 0.42));
        }
    }
    QPainter p(&sombra);
    p.setRenderHint(QPainter::Antialiasing);
    p.setCompositionMode(QPainter::CompositionMode_DestinationOut);
    p.setPen(Qt::NoPen);
    p.setBrush(QColor(0, 0, 0, 255));
    p.drawRoundedRect(QRectF(borda, borda, lado - 2 * borda, lado - 2 * borda), raio, raio);
    return sombra;
}

class Vidro : public QObject
{
public:
    explicit Vidro(QWidget *janela)
        : QObject(janela)
        , m_widget(janela)
    {
        const int borda = 34;
        const QImage img = imagemDaSombra(borda, Medida::raio);
        const int lado = img.width();
        const int canto = borda + Medida::raio;
        auto pedaco = [&img](int x, int y, int w, int h) {
            auto t = KWindowShadowTile::Ptr::create();
            t->setImage(img.copy(x, y, w, h));
            return t;
        };
        m_sombra = new KWindowShadow(this);
        m_sombra->setTopLeftTile(pedaco(0, 0, canto, canto));
        m_sombra->setTopTile(pedaco(canto, 0, 1, borda));
        m_sombra->setTopRightTile(pedaco(lado - canto, 0, canto, canto));
        m_sombra->setRightTile(pedaco(lado - borda, canto, borda, 1));
        m_sombra->setBottomRightTile(pedaco(lado - canto, lado - canto, canto, canto));
        m_sombra->setBottomTile(pedaco(canto, lado - borda, 1, borda));
        m_sombra->setBottomLeftTile(pedaco(0, lado - canto, canto, canto));
        m_sombra->setLeftTile(pedaco(0, canto, borda, 1));
        m_sombra->setPadding(QMargins(borda, borda, borda, borda));
    }

    void aplicar()
    {
        QWindow *w = m_widget->windowHandle();
        if (!w || !w->handle()) {
            return;
        }
        if (m_janela != w) {
            m_janela = w;
            w->installEventFilter(this);
            m_sombra->setWindow(w);
        }
        const bool cheia = m_widget->isMaximized() || m_widget->isFullScreen();
        const qreal r = cheia ? 0 : Medida::raio;
        QPainterPath forma;
        forma.addRoundedRect(QRectF(QPointF(0, 0), QSizeF(m_widget->size())), r, r);
        KWindowEffects::enableBlurBehind(w, tema.desfoque, QRegion(forma.toFillPolygon().toPolygon()));
        if (cheia) {
            if (m_sombra->isCreated()) {
                m_sombra->destroy();
            }
        } else if (!m_sombra->isCreated()) {
            m_sombra->create();
        }
    }

protected:
    bool eventFilter(QObject *objeto, QEvent *evento) override
    {
        if (objeto == m_janela && evento->type() == QEvent::PlatformSurface) {
            const auto tipo = static_cast<QPlatformSurfaceEvent *>(evento)->surfaceEventType();
            if (tipo == QPlatformSurfaceEvent::SurfaceCreated) {
                QTimer::singleShot(0, this, &Vidro::aplicar);
            } else if (tipo == QPlatformSurfaceEvent::SurfaceAboutToBeDestroyed && m_sombra->isCreated()) {
                m_sombra->destroy();
            }
        }
        return false;
    }

private:
    QWidget *m_widget;
    QPointer<QWindow> m_janela;
    KWindowShadow *m_sombra = nullptr;
};

// ---------------------------------------------------------------------------
// Menu de vidro, com cantos redondos e os atalhos à direita.
class Menu : public QMenu
{
public:
    explicit Menu(QWidget *pai)
        : QMenu(pai)
    {
        setProperty("matsuMenu", true);
        setAttribute(Qt::WA_TranslucentBackground);
        setWindowFlags(windowFlags() | Qt::FramelessWindowHint | Qt::NoDropShadowWindowHint);
        const QColor fundo = tema.escuro ? QColor::fromRgbF(0.16, 0.16, 0.17, tema.desfoque ? 0.86 : 1)
                                         : QColor::fromRgbF(0.98, 0.98, 0.985, tema.desfoque ? 0.88 : 1);
        auto rgba = [](const QColor &c) {
            return QStringLiteral("rgba(%1,%2,%3,%4)").arg(c.red()).arg(c.green()).arg(c.blue()).arg(c.alphaF(), 0, 'f', 3);
        };
        setStyleSheet(QStringLiteral("QMenu { background: %1; border: 1px solid %2; border-radius: 10px; padding: 5px; }"
                                     "QMenu::item { color: %3; padding: 6px 28px 6px 12px; border-radius: 6px; margin: 0px; }"
                                     "QMenu::item:selected { background: %4; }"
                                     "QMenu::item:disabled { color: %5; }"
                                     "QMenu::separator { height: 1px; background: %6; margin: 5px 8px; }"
                                     "QMenu::icon { padding-left: 8px; }")
                          .arg(rgba(fundo), rgba(tema.tinta(tema.escuro ? 0.10 : 0.12)), rgba(tema.tinta(0.92)),
                               rgba(tema.tinta(tema.escuro ? 0.09 : 0.07)), rgba(tema.tinta(0.35)), rgba(tema.tinta(0.08))));
    }

    // Com estilo próprio, o Qt deixa só 12 px entre o nome do item e o atalho,
    // e o atalho cola no nome mais comprido. Uma largura mínima maior afasta
    // a coluna dos atalhos. Chamar depois de pôr os itens.
    void afastarAtalhos(int folga = 28)
    {
        ensurePolished();
        setMinimumWidth(QMenu::sizeHint().width() + folga);
        // Faz o menu medir os itens de novo, agora com a largura nova.
        QAction *vazio = addAction(QString());
        removeAction(vazio);
        delete vazio;
    }

protected:
    void showEvent(QShowEvent *e) override
    {
        QMenu::showEvent(e);
        QTimer::singleShot(0, this, [this]() {
            if (QWindow *w = windowHandle()) {
                QPainterPath forma;
                forma.addRoundedRect(QRectF(rect()), 10, 10);
                KWindowEffects::enableBlurBehind(w, tema.desfoque, QRegion(forma.toFillPolygon().toPolygon()));
            }
        });
    }
};

// ---------------------------------------------------------------------------
// Os menus e as caixas que a peça do Konsole abre (botão direito, ajustar o
// perfil, perguntas) ganham as cores neutras também, em vez das do esquema do
// sistema. O menu do "..." já é de vidro (Menu, acima).
class CoresNeutras : public QObject
{
public:
    using QObject::QObject;

protected:
    bool eventFilter(QObject *objeto, QEvent *evento) override
    {
        if (evento->type() == QEvent::Polish && objeto->isWidgetType()) {
            auto *w = static_cast<QWidget *>(objeto);
            if (w->isWindow() && !w->property("matsuMenu").toBool() && !w->inherits("Janela")) {
                w->setPalette(paletaNeutra(QApplication::palette()));
            }
        }
        return false;
    }
};

// ---------------------------------------------------------------------------
// Os cantos redondos do terminal. Estes quadradinhos ficam por cima dos quatro
// cantos e repintam o vidro da janela só por fora da curva, com a borda suave:
// por dentro fica o que o terminal desenhou (o fundo dele, a barrinha da tela
// dividida...), seja qual for a cor.
class Canto : public QWidget
{
public:
    Canto(int qual, QWidget *pai)
        : QWidget(pai)
        , m_qual(qual)
    {
        setAttribute(Qt::WA_TransparentForMouseEvents);
        setAttribute(Qt::WA_NoSystemBackground);
        resize(Medida::raioCartao, Medida::raioCartao);
    }
    void setVidro(const QColor &vidro)
    {
        m_vidro = vidro;
        update();
    }

protected:
    void paintEvent(QPaintEvent *) override
    {
        QPainter p(this);
        p.setRenderHint(QPainter::Antialiasing);
        // "Source" com a borda suave mistura o vidro com o que já está embaixo na
        // medida certa; dentro da curva não toca em nada.
        p.setCompositionMode(QPainter::CompositionMode_Source);
        const qreal r = Medida::raioCartao;
        // 0: em cima à esquerda, 1: em cima à direita, 2: embaixo à esquerda, 3: embaixo à direita.
        const QPointF centro((m_qual % 2) ? 0 : r, (m_qual < 2) ? r : 0);
        QPainterPath fora;
        fora.addRect(QRectF(rect()));
        QPainterPath quarto;
        quarto.addEllipse(centro, r, r);
        p.fillPath(fora.subtracted(quarto), m_vidro);
    }

private:
    int m_qual;
    QColor m_vidro;
};

// ---------------------------------------------------------------------------
// Uma aba: uma peça do Konsole com um shell (ou um programa) dentro.
struct Aba {
    int id = 0;
    int cor = 0;
    QPointer<KParts::ReadOnlyPart> parte;
    TerminalInterface *terminal = nullptr;
    int pid = 0;            // o shell do lado ativo (com a tela dividida, o lado com o foco)
    QString pasta;          // pasta atual do shell
    QString programa;       // programa rodando agora (vazio: o shell está esperando)
    QString shell;          // nome do shell (bash, zsh...)
    bool terminou = false;  // um programa terminou com a aba em segundo plano
    QString programaFixo;   // aberta com -e: o nome do programa
};

class Janela;

// ---------------------------------------------------------------------------
// O cabeçalho: bolinhas, abas e os botões de nova aba, dividir e menu.
class Cabecalho : public QWidget
{
public:
    explicit Cabecalho(Janela *janela);

    // Áreas clicáveis.
    enum Tipo { Nada, Bolinha, Aba, FecharAba, NovaAba, Dividir, MenuBotao };
    struct Alvo {
        Tipo tipo = Nada;
        int indice = -1;
        bool operator==(const Alvo &o) const
        {
            return tipo == o.tipo && indice == o.indice;
        }
    };

protected:
    void paintEvent(QPaintEvent *) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mousePressEvent(QMouseEvent *e) override;
    void mouseReleaseEvent(QMouseEvent *e) override;
    void mouseDoubleClickEvent(QMouseEvent *e) override;
    void leaveEvent(QEvent *) override;
    bool event(QEvent *e) override;

private:
    QRectF retBolinha(int i) const;
    QRectF retGrupoBolinhas() const;
    QVector<QRectF> retAbas() const;
    QRectF retFechar(const QRectF &aba) const;
    QRectF retNovaAba() const;
    QRectF retDividir() const;
    QRectF retMenu() const;
    Alvo alvoEm(const QPointF &p) const;
    void desenharBolinhas(QPainter &p);
    void desenharAba(QPainter &p, int i, const QRectF &r);
    void desenharBotao(QPainter &p, const QRectF &r, Tipo tipo, const QString &chave);

    Janela *m_janela;
    Suave m_suave;
    Alvo m_sobre;
    Alvo m_apertado;
    QPointF m_inicioArraste;
    int m_arrastando = -1;     // aba sendo arrastada para mudar de lugar
    qreal m_pega = 0;          // onde o mouse pegou a aba (distância da beirada esquerda)
    qreal m_xArrastada = 0;    // onde a aba arrastada está agora
    bool m_moveuJanela = false;
};

// ---------------------------------------------------------------------------
// O rodapé: pasta, git, programa e tamanho do terminal.
class Rodape : public QWidget
{
public:
    explicit Rodape(Janela *janela);

    void setInfo(const QString &pasta, const QString &ramo, int mudancas, int frente, int atras, const QString &programa,
                 bool rodando, QSize tamanho);

protected:
    void paintEvent(QPaintEvent *) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mousePressEvent(QMouseEvent *e) override;
    void leaveEvent(QEvent *) override;
    bool event(QEvent *e) override;

private:
    QRectF retPasta() const;

    Janela *m_janela;
    Suave m_suave;
    QString m_pasta;
    QString m_ramo;
    int m_mudancas = 0;
    int m_frente = 0;
    int m_atras = 0;
    QString m_programa;
    bool m_rodando = false;
    QSize m_tamanho;
    bool m_sobrePasta = false;
    mutable QRectF m_retPasta;
};

// ---------------------------------------------------------------------------
class Janela : public QWidget
{
    Q_OBJECT

public:
    Janela(const QString &pasta, const QStringList &comando, bool segurar);
    ~Janela() override;

    // Para o cabeçalho e o rodapé.
    const QVector<Aba> &abas() const
    {
        return m_abas;
    }
    int atual() const
    {
        return m_atual;
    }
    QString tituloAba(int i) const;
    void irPara(int i);
    void novaAba(const QString &pasta = QString(), const QStringList &comando = {}, bool segurar = false);
    void fecharAba(int i);
    void moverAba(int de, int para);
    void dividir(bool ladoALado);
    void abrirMenu(const QPoint &onde);
    void menuDaAba(int i, const QPoint &onde);
    void alternarCheia();
    void abrirPasta();
    bool bordaEm(const QPoint &p, Qt::Edges &bordas) const;

protected:
    void paintEvent(QPaintEvent *) override;
    void resizeEvent(QResizeEvent *) override;
    void showEvent(QShowEvent *) override;
    void changeEvent(QEvent *e) override;
    void closeEvent(QCloseEvent *e) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mousePressEvent(QMouseEvent *e) override;

private Q_SLOTS:
    // A peça do Konsole pergunta se um atalho de um modificador é do terminal.
    void sobreporAtalhoSlot(QKeyEvent *e, bool &sobrepor)
    {
        sobreporAtalho(e, sobrepor);
    }

private:
    QAction *acaoDaParte(int i, const char *nome) const;
    void limparAtalhos(KParts::ReadOnlyPart *parte);
    void sobreporAtalho(QKeyEvent *e, bool &sobrepor);
    void atualizarTema();
    void atualizarCantos();
    void atualizarInfo();
    void atualizarGit();
    void posicionar();

    QVector<Aba> m_abas;
    int m_atual = -1;
    int m_proximoId = 1;
    int m_proximaCor = 0;
    QStackedWidget *m_pilha;
    Cabecalho *m_cabecalho;
    Rodape *m_rodape;
    Canto *m_cantos[4];
    Vidro *m_vidro;
    QTimer m_relogio;
    QProcess *m_git = nullptr;
    QString m_gitPasta;
    QString m_gitRamo;
    int m_gitMudancas = 0, m_gitFrente = 0, m_gitAtras = 0;
    QElapsedTimer m_desdeGit;
    QList<QKeySequence> m_atalhosNossos;
    bool m_semPeca = false;
};

// ---------------------------------------------------------------------------
// Coisas do sistema.

// Nome curto de um processo, pelo /proc.
static QString nomeDoProcesso(int pid)
{
    if (pid <= 0) {
        return QString();
    }
    QFile f(QStringLiteral("/proc/%1/comm").arg(pid));
    if (!f.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return QString::fromUtf8(f.readAll()).trimmed();
}

// O que está rodando na frente no terminal de um shell: o /proc/<pid>/stat diz o
// grupo do shell e o grupo que está na frente do terminal dele. Se forem
// diferentes, um programa está rodando (o nome é o do líder do grupo da frente).
// Devolve false se o shell já não existe.
static bool programaNaFrente(int pid, QString &programa)
{
    programa.clear();
    if (pid <= 0) {
        return false;
    }
    QFile f(QStringLiteral("/proc/%1/stat").arg(pid));
    if (!f.open(QIODevice::ReadOnly)) {
        return false;
    }
    const QByteArray stat = f.readAll();
    const int fecha = stat.lastIndexOf(')');
    if (fecha < 0) {
        return false;
    }
    // Depois do nome: estado, pai, grupo, sessão, terminal, grupo da frente...
    const QList<QByteArray> campos = stat.mid(fecha + 2).split(' ');
    if (campos.size() < 6) {
        return false;
    }
    const int grupo = campos.at(2).toInt();
    const int frente = campos.at(5).toInt();
    if (frente > 0 && frente != grupo) {
        programa = nomeDoProcesso(frente);
    }
    return true;
}

// Colunas e linhas do terminal, perguntando ao próprio pty (o número exato).
static QSize tamanhoDoTerminal(int pid)
{
    if (pid <= 0) {
        return {};
    }
    const QString pts = QFile::symLinkTarget(QStringLiteral("/proc/%1/fd/0").arg(pid));
    if (!pts.startsWith(QLatin1String("/dev/pts/"))) {
        return {};
    }
    const int fd = ::open(QFile::encodeName(pts).constData(), O_RDONLY | O_NOCTTY | O_CLOEXEC | O_NONBLOCK);
    if (fd < 0) {
        return {};
    }
    winsize ws{};
    const int r = ::ioctl(fd, TIOCGWINSZ, &ws);
    ::close(fd);
    if (r < 0 || ws.ws_col == 0) {
        return {};
    }
    return QSize(ws.ws_col, ws.ws_row);
}

// A pasta como a pessoa lê: a casa vira "~".
static QString pastaCurta(const QString &pasta)
{
    if (pasta.isEmpty()) {
        return QString();
    }
    const QString casa = QDir::homePath();
    QString p = QDir::cleanPath(pasta);
    if (p == casa) {
        return QStringLiteral("~");
    }
    if (p.startsWith(casa + QLatin1Char('/'))) {
        return QStringLiteral("~") + p.mid(casa.size());
    }
    return p;
}

static QString nomeDaPasta(const QString &pasta)
{
    const QString curta = pastaCurta(pasta);
    if (curta == QLatin1String("~") || curta == QLatin1String("/")) {
        return curta;
    }
    return curta.section(QLatin1Char('/'), -1);
}

// O cursor de redimensionar certo para cada borda.
static Qt::CursorShape cursorDaBorda(Qt::Edges b)
{
    const bool horizontal = b & (Qt::LeftEdge | Qt::RightEdge);
    const bool vertical = b & (Qt::TopEdge | Qt::BottomEdge);
    if (horizontal && vertical) {
        return (((b & Qt::LeftEdge) && (b & Qt::TopEdge)) || ((b & Qt::RightEdge) && (b & Qt::BottomEdge))) ? Qt::SizeFDiagCursor
                                                                                                          : Qt::SizeBDiagCursor;
    }
    return horizontal ? Qt::SizeHorCursor : Qt::SizeVerCursor;
}

static QFont fonte(qreal px, int peso = QFont::Normal)
{
    QFont f = QApplication::font();
    f.setPixelSize(qRound(px));
    f.setWeight(QFont::Weight(peso));
#if QT_VERSION >= QT_VERSION_CHECK(6, 7, 0)
    f.setFeature(QFont::Tag("tnum"), 1); // números com a mesma largura (o tamanho não pula)
#endif
    return f;
}

// ---------------------------------------------------------------------------
// Cabeçalho

Cabecalho::Cabecalho(Janela *janela)
    : QWidget(janela)
    , m_janela(janela)
    , m_suave(this)
{
    setMouseTracking(true);
    setAttribute(Qt::WA_Hover);
}

QRectF Cabecalho::retBolinha(int i) const
{
    // Como nos apps do Matsu: 18 pontos cada, 4 de vão, a 13 da borda.
    return QRectF(13 + i * 22, (height() - 18) / 2.0, 18, 18);
}

QRectF Cabecalho::retGrupoBolinhas() const
{
    return retBolinha(0).united(retBolinha(2)).adjusted(-3, -6, 3, 6);
}

QRectF Cabecalho::retMenu() const
{
    return QRectF(width() - 10 - Medida::pilula, (height() - Medida::pilula) / 2.0, Medida::pilula, Medida::pilula);
}

QRectF Cabecalho::retDividir() const
{
    return retMenu().translated(-(Medida::pilula + 4), 0);
}

QVector<QRectF> Cabecalho::retAbas() const
{
    const int n = m_janela->abas().size();
    QVector<QRectF> r;
    if (n == 0) {
        return r;
    }
    const qreal inicio = retBolinha(2).right() + 18;
    const qreal fim = retDividir().left() - 12 - Medida::pilula - 6; // espaço para o "+"
    const qreal largura = qBound<qreal>(64, (fim - inicio - (n - 1) * 4) / n, 220);
    const qreal y = (height() - Medida::pilula) / 2.0;
    for (int i = 0; i < n; ++i) {
        r << QRectF(inicio + i * (largura + 4), y, largura, Medida::pilula);
    }
    return r;
}

QRectF Cabecalho::retFechar(const QRectF &aba) const
{
    return QRectF(aba.right() - 7 - 18, aba.center().y() - 9, 18, 18);
}

QRectF Cabecalho::retNovaAba() const
{
    const auto abas = retAbas();
    const qreal x = abas.isEmpty() ? retBolinha(2).right() + 18 : abas.last().right() + 6;
    return QRectF(x, (height() - Medida::pilula) / 2.0, Medida::pilula, Medida::pilula);
}

Cabecalho::Alvo Cabecalho::alvoEm(const QPointF &p) const
{
    for (int i = 0; i < 3; ++i) {
        if (retBolinha(i).adjusted(-2, -6, 2, 6).contains(p)) {
            return {Bolinha, i};
        }
    }
    if (retNovaAba().contains(p)) {
        return {NovaAba, -1};
    }
    if (retDividir().contains(p)) {
        return {Dividir, -1};
    }
    if (retMenu().contains(p)) {
        return {MenuBotao, -1};
    }
    const auto abas = retAbas();
    for (int i = 0; i < abas.size(); ++i) {
        if (abas[i].contains(p)) {
            if (retFechar(abas[i]).adjusted(-2, -2, 2, 2).contains(p)) {
                return {FecharAba, i};
            }
            return {Aba, i};
        }
    }
    return {};
}

void Cabecalho::desenharBolinhas(QPainter &p)
{
    // Iguais às da borda das janelas do Matsu (comum/BotaoJanela.qml).
    static const QColor cores[3] = {QColor("#ff5f57"), QColor("#febc2e"), QColor("#28c840")};
    static const QColor simbolos[3] = {QColor("#4d0000"), QColor("#995700"), QColor("#006500")};
    const bool sobreGrupo = m_sobre.tipo == Bolinha;
    const qreal mostrar = m_suave(QStringLiteral("bolinhas"), sobreGrupo ? 1 : 0, -1, 20);
    const bool ativa = window()->isActiveWindow();
    const qreal colorida = m_suave(QStringLiteral("colorida"), (ativa || sobreGrupo) ? 1 : 0, -1, 14);
    const QColor cinza = tema.tinta(tema.escuro ? 0.2 : 0.16);
    static const QEasingCurve salto = [] {
        QEasingCurve c(QEasingCurve::OutBack);
        c.setOvershoot(2.2);
        return c;
    }();

    for (int i = 0; i < 3; ++i) {
        const QRectF r = retBolinha(i);
        const QPointF c = r.center();
        QColor cor = cores[i];
        if (m_apertado == Alvo{Bolinha, i} && m_sobre == m_apertado) {
            cor = cor.darker(120);
        }
        const QColor mistura = QColor::fromRgbF(cinza.redF() + (cor.redF() - cinza.redF()) * colorida,
                                                cinza.greenF() + (cor.greenF() - cinza.greenF()) * colorida,
                                                cinza.blueF() + (cor.blueF() - cinza.blueF()) * colorida,
                                                cinza.alphaF() + (1 - cinza.alphaF()) * colorida);
        p.setPen(QPen(QColor::fromRgbF(0, 0, 0, (tema.escuro ? 0.18 : 0.1) * colorida), 1));
        p.setBrush(mistura);
        p.drawEllipse(QRectF(c.x() - 6.5, c.y() - 6.5, 13, 13));
        if (mostrar > 0.01) {
            p.save();
            const qreal escala = 0.4 + 0.6 * salto.valueForProgress(qBound(0.0, mostrar, 1.0));
            p.translate(c);
            p.scale(escala, escala);
            p.setOpacity(qBound(0.0, mostrar, 1.0));
            const QColor s = simbolos[i];
            if (i == 0) {
                Desenho::xis(p, QPointF(0, 0), 2.3, s);
            } else if (i == 1) {
                p.setPen(Desenho::traco(s, 1.4));
                p.drawLine(QPointF(-2.8, 0), QPointF(2.8, 0));
            } else {
                // Tela cheia: dois triângulos; saindo dela, eles apontam para dentro.
                p.setPen(QPen(s, 0.8, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
                p.setBrush(s);
                QPainterPath tri;
                if (m_janela->isMaximized() || m_janela->isFullScreen()) {
                    tri.moveTo(-0.7, -3.5); tri.lineTo(-0.7, -0.7); tri.lineTo(-3.5, -0.7); tri.closeSubpath();
                    tri.moveTo(0.7, 3.5); tri.lineTo(0.7, 0.7); tri.lineTo(3.5, 0.7); tri.closeSubpath();
                } else {
                    tri.moveTo(-3, -3); tri.lineTo(0, -3); tri.lineTo(-3, 0); tri.closeSubpath();
                    tri.moveTo(3, 3); tri.lineTo(0, 3); tri.lineTo(3, 0); tri.closeSubpath();
                }
                p.drawPath(tri);
            }
            p.restore();
        }
    }
}

void Cabecalho::desenharAba(QPainter &p, int i, const QRectF &r)
{
    const ::Aba &aba = m_janela->abas().at(i);
    const QString chave = QString::number(aba.id);
    const bool ativa = i == m_janela->atual();
    const bool sobre = (m_sobre.tipo == Aba || m_sobre.tipo == FecharAba) && m_sobre.indice == i;
    const qreal a = m_suave(QStringLiteral("ativa:") + chave, ativa ? 1 : 0, -1, 18);
    const qreal h = m_suave(QStringLiteral("sobre:") + chave, sobre ? 1 : 0, -1, 22);
    const qreal entrada = m_suave(QStringLiteral("entrada:") + chave, 1, 0, 14);

    p.save();
    p.setOpacity(entrada);
    // Fundo: a ativa fica num degrau mais claro, com uma borda fina; as outras só
    // aparecem com o mouse em cima.
    // As de trás têm um fundo bem leve, para mostrar onde cada aba começa e acaba.
    const qreal fundo = tema.escuro ? (0.028 + 0.03 * h) * (1 - a) + 0.095 * a : (0.035 + 0.035 * h) * (1 - a);
    if (fundo > 0.002) {
        p.setPen(Qt::NoPen);
        p.setBrush(tema.tinta(fundo));
        p.drawRoundedRect(r, 8, 8);
    }
    if (!tema.escuro && a > 0.002) {
        // No claro, a ativa é uma pílula branca leitosa.
        p.setPen(Qt::NoPen);
        p.setBrush(QColor::fromRgbF(1, 1, 1, 0.78 * a));
        p.drawRoundedRect(r, 8, 8);
    }
    if (a > 0.002) {
        p.setPen(QPen(tema.tinta((tema.escuro ? 0.07 : 0.09) * a), 1));
        p.setBrush(Qt::NoBrush);
        p.drawRoundedRect(r.adjusted(0.5, 0.5, -0.5, -0.5), 7.5, 7.5);
        if (tema.escuro) {
            // Um brilho de leve na beirada de cima, como vidro.
            QLinearGradient brilho(r.topLeft(), r.bottomLeft());
            brilho.setColorAt(0, QColor::fromRgbF(1, 1, 1, 0.07 * a));
            brilho.setColorAt(0.5, QColor::fromRgbF(1, 1, 1, 0));
            p.setPen(QPen(QBrush(brilho), 1));
            p.drawRoundedRect(r.adjusted(0.5, 0.5, -0.5, -0.5), 7.5, 7.5);
        }
    }

    // A aba aberta se destaca só pelo fundo (sem tracinho colorido embaixo: o
    // Kaiky achou desnecessário, 11/11/2026).

    // O símbolo na cor da aba: "›_", ou o do programa que está rodando nela.
    QColor cor = tema.corAba(aba.cor);
    cor.setAlphaF(0.55 + 0.45 * qMax(a, h));
    const QRectF simbolo(r.left() + 10, r.center().y() - 8, 16, 16);
    simboloDoPrograma(p, simbolo, cor, aba.programa.isEmpty() ? aba.programaFixo : aba.programa);

    // O título.
    const QRectF fechar = retFechar(r);
    const qreal mostrarFechar = m_suave(QStringLiteral("fechar:") + chave, (ativa || sobre) ? 1 : 0, -1, 22);
    const qreal direita = (mostrarFechar > 0.01 || aba.terminou) ? fechar.left() - 4 : r.right() - 12;
    const QRectF texto(simbolo.right() + 7, r.top(), direita - simbolo.right() - 7, r.height());
    const QFont f = fonte(13, ativa ? QFont::Medium : QFont::Normal);
    p.setFont(f);
    const QFontMetricsF fm(f);
    const QString titulo = fm.elidedText(m_janela->tituloAba(i), Qt::ElideRight, texto.width());
    p.setPen(tema.tinta(0.62 + 0.33 * qMax(a, h * 0.6)));
    p.drawText(texto, Qt::AlignVCenter | Qt::AlignLeft, titulo);

    // Bolinha de "terminou" (um programa acabou com a aba em segundo plano).
    if (aba.terminou && mostrarFechar < 0.99) {
        p.save();
        p.setOpacity(p.opacity() * (1 - mostrarFechar));
        p.setPen(Qt::NoPen);
        p.setBrush(tema.corAba(aba.cor));
        p.drawEllipse(fechar.center(), 3.2, 3.2);
        p.restore();
    }
    // O "x" de fechar.
    if (mostrarFechar > 0.01) {
        p.save();
        p.setOpacity(p.opacity() * mostrarFechar);
        const bool sobreX = m_sobre == Alvo{FecharAba, i};
        if (sobreX) {
            p.setPen(Qt::NoPen);
            p.setBrush(tema.tinta(m_apertado == m_sobre ? 0.18 : 0.11));
            p.drawEllipse(fechar);
        }
        Desenho::xis(p, fechar.center(), 3.4, tema.tinta(sobreX ? 0.95 : 0.6), 1.35);
        p.restore();
    }
    p.restore();
}

void Cabecalho::desenharBotao(QPainter &p, const QRectF &r, Tipo tipo, const QString &chave)
{
    const bool sobre = m_sobre.tipo == tipo;
    const bool apertado = sobre && m_apertado.tipo == tipo;
    const qreal h = m_suave(chave, sobre ? 1 : 0, -1, 22);
    if (h > 0.002 || apertado) {
        p.setPen(Qt::NoPen);
        p.setBrush(tema.tinta((apertado ? 0.12 : 0.07) * qMax(h, apertado ? 1.0 : 0.0)));
        p.drawRoundedRect(r, 8, 8);
    }
    const QColor cor = tema.tinta(0.62 + 0.33 * h);
    switch (tipo) {
    case NovaAba:
        Desenho::mais(p, r.center(), cor);
        break;
    case Dividir:
        Desenho::dividir(p, r.center(), cor);
        break;
    case MenuBotao:
        Desenho::pontos(p, r.center(), cor);
        break;
    default:
        break;
    }
}

void Cabecalho::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::TextAntialiasing);
    desenharBolinhas(p);

    const auto abas = retAbas();
    for (int i = 0; i < abas.size(); ++i) {
        const QString chave = QString::number(m_janela->abas().at(i).id);
        // As abas deslizam para o lugar novo quando outra abre, fecha ou muda de lugar.
        const qreal x = m_suave(QStringLiteral("x:") + chave, abas[i].x(), abas[i].x(), 18);
        const qreal w = m_suave(QStringLiteral("w:") + chave, abas[i].width(), abas[i].width(), 18);
        QRectF r(x, abas[i].y(), w, abas[i].height());
        if (i == m_arrastando) {
            continue;
        }
        desenharAba(p, i, r);
    }
    if (m_arrastando >= 0 && m_arrastando < abas.size()) {
        // A aba arrastada por cima das outras, seguindo o mouse.
        QRectF r = abas[m_arrastando];
        r.moveLeft(m_xArrastada);
        desenharAba(p, m_arrastando, r);
    }

    const QRectF nova = retNovaAba();
    const qreal xNova = m_suave(QStringLiteral("x:nova"), nova.x(), nova.x(), 18);
    desenharBotao(p, QRectF(xNova, nova.y(), nova.width(), nova.height()), NovaAba, QStringLiteral("botao:nova"));
    desenharBotao(p, retDividir(), Dividir, QStringLiteral("botao:dividir"));
    desenharBotao(p, retMenu(), MenuBotao, QStringLiteral("botao:menu"));
}

bool Cabecalho::event(QEvent *e)
{
    if (e->type() == QEvent::ToolTip) {
        auto *he = static_cast<QHelpEvent *>(e);
        const Alvo a = alvoEm(he->pos());
        QString dica;
        switch (a.tipo) {
        case Bolinha:
            dica = a.indice == 0 ? t("Fechar", "Close")
                 : a.indice == 1 ? t("Minimizar", "Minimize")
                 : (m_janela->isMaximized() ? t("Sair da tela cheia", "Restore") : t("Tela cheia", "Maximize"));
            break;
        case FecharAba:
            dica = t("Fechar aba", "Close tab");
            break;
        case NovaAba:
            dica = t("Nova aba (Ctrl+Shift+T)", "New tab (Ctrl+Shift+T)");
            break;
        case Dividir:
            dica = t("Dividir lado a lado (Ctrl+()", "Split left and right (Ctrl+()");
            break;
        case MenuBotao:
            dica = t("Mais opções", "More options");
            break;
        case Aba: {
            const ::Aba &aba = m_janela->abas().at(a.indice);
            dica = pastaCurta(aba.pasta);
            if (!aba.programa.isEmpty()) {
                dica = aba.programa + QStringLiteral(" · ") + dica;
            }
            break;
        }
        default:
            break;
        }
        if (dica.isEmpty()) {
            QToolTip::hideText();
            e->ignore();
        } else {
            QToolTip::showText(he->globalPos(), dica, this);
        }
        return true;
    }
    return QWidget::event(e);
}

void Cabecalho::mouseMoveEvent(QMouseEvent *e)
{
    if (m_arrastando >= 0) {
        // Arrastando uma aba: ela segue o mouse e as outras abrem espaço quando
        // ela passa do meio delas.
        const auto abas = retAbas();
        m_xArrastada = qBound(abas.first().x(), e->position().x() - m_pega, abas.last().x());
        const qreal centro = m_xArrastada + abas.first().width() / 2;
        int lugar = 0;
        for (int i = 0; i < abas.size(); ++i) {
            if (qAbs(abas[i].center().x() - centro) < qAbs(abas[lugar].center().x() - centro)) {
                lugar = i;
            }
        }
        if (lugar != m_arrastando) {
            m_janela->moverAba(m_arrastando, lugar);
            m_arrastando = lugar;
        }
        update();
        return;
    }
    if (m_apertado.tipo == Aba && (e->buttons() & Qt::LeftButton) && m_janela->abas().size() > 1
        && qAbs(e->position().x() - m_inicioArraste.x()) > QApplication::startDragDistance()) {
        const auto abas = retAbas();
        m_arrastando = m_apertado.indice;
        m_pega = m_inicioArraste.x() - abas[m_arrastando].x();
        m_xArrastada = abas[m_arrastando].x();
        update();
        return;
    }
    if (m_apertado.tipo == Nada && (e->buttons() & Qt::LeftButton) && !m_moveuJanela
        && (e->position() - m_inicioArraste).manhattanLength() > QApplication::startDragDistance()) {
        // Arrastar o cabeçalho move a janela.
        m_moveuJanela = true;
        if (QWindow *w = window()->windowHandle()) {
            w->startSystemMove();
        }
        return;
    }
    const Alvo a = alvoEm(e->position());
    if (!(a == m_sobre)) {
        m_sobre = a;
        update();
    }
    Qt::Edges bordas;
    setCursor(m_janela->bordaEm(mapTo(m_janela, e->position().toPoint()), bordas) ? cursorDaBorda(bordas) : Qt::ArrowCursor);
}

void Cabecalho::mousePressEvent(QMouseEvent *e)
{
    Qt::Edges bordas;
    if (e->button() == Qt::LeftButton && m_janela->bordaEm(mapTo(m_janela, e->position().toPoint()), bordas)) {
        if (QWindow *w = window()->windowHandle()) {
            w->startSystemResize(bordas);
        }
        return;
    }
    m_sobre = alvoEm(e->position());
    m_inicioArraste = e->position();
    m_moveuJanela = false;
    if (e->button() == Qt::MiddleButton && (m_sobre.tipo == Aba || m_sobre.tipo == FecharAba)) {
        m_janela->fecharAba(m_sobre.indice);
        return;
    }
    if (e->button() == Qt::RightButton) {
        if (m_sobre.tipo == Aba || m_sobre.tipo == FecharAba) {
            m_janela->menuDaAba(m_sobre.indice, e->globalPosition().toPoint());
        }
        return;
    }
    if (e->button() != Qt::LeftButton) {
        return;
    }
    m_apertado = m_sobre;
    if (m_apertado.tipo == Aba) {
        m_janela->irPara(m_apertado.indice);
    } else if (m_apertado.tipo == MenuBotao) {
        // O menu abre no aperto, logo abaixo do botão.
        const QRectF r = retMenu();
        m_apertado = {};
        update();
        m_janela->abrirMenu(mapToGlobal(QPoint(qRound(r.right()), qRound(r.bottom()) + 4)));
        return;
    }
    update();
}

void Cabecalho::mouseReleaseEvent(QMouseEvent *e)
{
    if (e->button() != Qt::LeftButton) {
        return;
    }
    if (m_arrastando >= 0) {
        // Solta a aba: ela desliza de onde está até o lugar dela.
        const QString chave = QString::number(m_janela->abas().at(m_arrastando).id);
        m_suave.definir(QStringLiteral("x:") + chave, m_xArrastada);
        m_arrastando = -1;
        m_apertado = {};
        update();
        return;
    }
    const Alvo solto = alvoEm(e->position());
    const Alvo apertado = m_apertado;
    m_apertado = {};
    update();
    if (!(solto == apertado)) {
        return;
    }
    switch (apertado.tipo) {
    case Bolinha:
        if (apertado.indice == 0) {
            m_janela->close();
        } else if (apertado.indice == 1) {
            m_janela->showMinimized();
        } else {
            m_janela->alternarCheia();
        }
        break;
    case FecharAba:
        m_janela->fecharAba(apertado.indice);
        break;
    case NovaAba:
        m_janela->novaAba();
        break;
    case Dividir:
        m_janela->dividir(true);
        break;
    default:
        break;
    }
}

void Cabecalho::mouseDoubleClickEvent(QMouseEvent *e)
{
    const Alvo a = alvoEm(e->position());
    if (e->button() == Qt::LeftButton && a.tipo == Nada) {
        m_janela->alternarCheia();
    } else if (e->button() == Qt::LeftButton && a.tipo == Aba) {
        m_apertado = a;
    } else {
        mousePressEvent(e);
    }
}

void Cabecalho::leaveEvent(QEvent *)
{
    m_sobre = {};
    update();
}

// ---------------------------------------------------------------------------
// Rodapé

Rodape::Rodape(Janela *janela)
    : QWidget(janela)
    , m_janela(janela)
    , m_suave(this)
{
    setMouseTracking(true);
}

void Rodape::setInfo(const QString &pasta, const QString &ramo, int mudancas, int frente, int atras, const QString &programa,
                     bool rodando, QSize tamanho)
{
    if (pasta == m_pasta && ramo == m_ramo && mudancas == m_mudancas && frente == m_frente && atras == m_atras
        && programa == m_programa && rodando == m_rodando && tamanho == m_tamanho) {
        return;
    }
    m_pasta = pasta;
    m_ramo = ramo;
    m_mudancas = mudancas;
    m_frente = frente;
    m_atras = atras;
    m_programa = programa;
    m_rodando = rodando;
    m_tamanho = tamanho;
    update();
}

QRectF Rodape::retPasta() const
{
    return m_retPasta;
}

void Rodape::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::TextAntialiasing);
    const qreal meio = height() / 2.0;
    const QFont f = fonte(12);
    const QFont fForte = fonte(12, QFont::Medium);
    const QFontMetricsF fm(f), fmForte(fForte);

    // ----- à direita: o programa e o tamanho -----
    qreal direita = width() - 18;
    if (m_tamanho.isValid()) {
        const QString tam = QStringLiteral("%1 × %2").arg(m_tamanho.width()).arg(m_tamanho.height());
        p.setFont(f);
        p.setPen(tema.tinta(0.45));
        const qreal w = fm.horizontalAdvance(tam);
        p.drawText(QRectF(direita - w, 0, w, height()), Qt::AlignVCenter | Qt::AlignRight, tam);
        direita -= w + 16;
    }
    if (!m_programa.isEmpty()) {
        p.setFont(f);
        const qreal w = fm.horizontalAdvance(m_programa);
        p.setPen(tema.tinta(m_rodando ? 0.85 : 0.6));
        p.drawText(QRectF(direita - w, 0, w, height()), Qt::AlignVCenter | Qt::AlignRight, m_programa);
        direita -= w + 8;
        // A bolinha: verde com o shell esperando, laranja com um programa rodando.
        const QColor cor = m_rodando ? tema.laranja() : tema.verde();
        p.setPen(Qt::NoPen);
        QColor halo = cor;
        halo.setAlphaF(0.22);
        p.setBrush(halo);
        p.drawEllipse(QPointF(direita - 3.5, meio), 5.5, 5.5);
        p.setBrush(cor);
        p.drawEllipse(QPointF(direita - 3.5, meio), 3, 3);
        direita -= 7 + 12;
    }

    // ----- à esquerda: a pasta e o git -----
    qreal x = 16;
    const qreal sobre = m_suave(QStringLiteral("pasta"), m_sobrePasta ? 1 : 0, -1, 22);
    if (!m_pasta.isEmpty()) {
        const QString curta = pastaCurta(m_pasta);
        QString pai, ultimo;
        const int corte = curta.lastIndexOf(QLatin1Char('/'));
        if (curta == QLatin1String("/") || curta == QLatin1String("~") || corte < 0) {
            ultimo = curta;
        } else {
            pai = curta.left(corte + 1);
            ultimo = curta.mid(corte + 1);
        }
        const qreal limite = direita - 12 - (m_ramo.isEmpty() ? 0 : 150);
        const qreal inicio = x;
        Desenho::pasta(p, QRectF(x, meio - 7, 14, 14), tema.tinta(0.5 + 0.35 * sobre));
        x += 14 + 7;
        // Pasta comprida: corta no começo, para o nome da pasta atual sempre aparecer.
        const qreal wUltimo = fmForte.horizontalAdvance(ultimo);
        const qreal cabePai = qMax<qreal>(0, limite - x - wUltimo);
        pai = fm.elidedText(pai, Qt::ElideLeft, cabePai);
        p.setFont(f);
        p.setPen(tema.tinta(0.48 + 0.2 * sobre));
        const qreal wPai = fm.horizontalAdvance(pai);
        p.drawText(QRectF(x, 0, wPai + 1, height()), Qt::AlignVCenter | Qt::AlignLeft, pai);
        x += wPai;
        p.setFont(fForte);
        p.setPen(tema.tinta(0.86 + 0.1 * sobre));
        const QString ultimoCabe = fmForte.elidedText(ultimo, Qt::ElideMiddle, qMax<qreal>(24, limite - x));
        const qreal wU = fmForte.horizontalAdvance(ultimoCabe);
        p.drawText(QRectF(x, 0, wU + 1, height()), Qt::AlignVCenter | Qt::AlignLeft, ultimoCabe);
        x += wU;
        m_retPasta = QRectF(inicio - 4, 4, x - inicio + 8, height() - 8);
        if (sobre > 0.01) {
            // Clicar abre a pasta nos Arquivos: um sublinhado de leve mostra que dá.
            p.setPen(QPen(tema.tinta(0.3 * sobre), 1));
            p.drawLine(QPointF(inicio + 21, meio + 8.5), QPointF(x, meio + 8.5));
        }
        x += 18;
    }
    if (!m_ramo.isEmpty() && x < direita - 40) {
        const QColor cor = tema.verde();
        Desenho::ramo(p, QRectF(x, meio - 7, 14, 14), cor);
        x += 14 + 6;
        p.setFont(fForte);
        p.setPen(cor);
        const QString ramo = fmForte.elidedText(m_ramo, Qt::ElideMiddle, qMax<qreal>(30, direita - 12 - x - 60));
        const qreal w = fmForte.horizontalAdvance(ramo);
        p.drawText(QRectF(x, 0, w + 1, height()), Qt::AlignVCenter | Qt::AlignLeft, ramo);
        x += w + 8;
        p.setFont(f);
        // Por extenso ("2 mudanças", "↑1 para enviar") quando cabe; se a janela
        // está estreita, a versão curta ("2", "↑1").
        QString mudancas, setas;
        const auto montar = [&](bool extenso) {
            mudancas.clear();
            setas.clear();
            if (m_mudancas > 0) {
                mudancas = !extenso ? QString::number(m_mudancas)
                    : m_mudancas == 1 ? t("1 mudança", "1 change")
                                      : t("%1 mudanças", "%1 changes").arg(m_mudancas);
            }
            if (m_frente > 0) {
                setas = extenso ? t("↑%1 para enviar", "↑%1 to push").arg(m_frente) : QStringLiteral("↑%1").arg(m_frente);
            }
            if (m_atras > 0) {
                setas += (setas.isEmpty() ? QString() : (extenso ? QStringLiteral("  ") : QStringLiteral(" ")))
                    + (extenso ? t("↓%1 para baixar", "↓%1 to pull").arg(m_atras) : QStringLiteral("↓%1").arg(m_atras));
            }
            return (mudancas.isEmpty() ? 0 : 9 + fm.horizontalAdvance(mudancas) + 12) + fm.horizontalAdvance(setas);
        };
        if (x + montar(true) > direita - 12) {
            montar(false);
        }
        if (!mudancas.isEmpty()) {
            // Arquivos mudados: um ponto laranja e quantos.
            p.setPen(Qt::NoPen);
            p.setBrush(tema.laranja());
            p.drawEllipse(QPointF(x + 2.5, meio), 2.5, 2.5);
            x += 9;
            p.setPen(tema.tinta(0.6));
            p.drawText(QRectF(x, 0, fm.horizontalAdvance(mudancas) + 1, height()), Qt::AlignVCenter | Qt::AlignLeft, mudancas);
            x += fm.horizontalAdvance(mudancas) + 12;
        }
        if (!setas.isEmpty()) {
            p.setPen(tema.tinta(0.5));
            p.drawText(QRectF(x, 0, fm.horizontalAdvance(setas) + 1, height()), Qt::AlignVCenter | Qt::AlignLeft, setas);
        }
    }
}

bool Rodape::event(QEvent *e)
{
    if (e->type() == QEvent::ToolTip) {
        auto *he = static_cast<QHelpEvent *>(e);
        if (m_retPasta.contains(he->pos())) {
            QToolTip::showText(he->globalPos(), t("Abrir esta pasta nos Arquivos", "Open this folder in Files"), this);
        } else {
            QToolTip::hideText();
            e->ignore();
        }
        return true;
    }
    return QWidget::event(e);
}

void Rodape::mouseMoveEvent(QMouseEvent *e)
{
    Qt::Edges bordas;
    if (m_janela->bordaEm(mapTo(m_janela, e->position().toPoint()), bordas)) {
        setCursor(cursorDaBorda(bordas));
        if (m_sobrePasta) {
            m_sobrePasta = false;
            update();
        }
        return;
    }
    const bool sobre = m_retPasta.contains(e->position());
    setCursor(sobre ? Qt::PointingHandCursor : Qt::ArrowCursor);
    if (sobre != m_sobrePasta) {
        m_sobrePasta = sobre;
        update();
    }
}

void Rodape::mousePressEvent(QMouseEvent *e)
{
    Qt::Edges bordas;
    if (e->button() == Qt::LeftButton && m_janela->bordaEm(mapTo(m_janela, e->position().toPoint()), bordas)) {
        if (QWindow *w = window()->windowHandle()) {
            w->startSystemResize(bordas);
        }
        return;
    }
    if (e->button() == Qt::LeftButton && m_retPasta.contains(e->position())) {
        m_janela->abrirPasta();
        return;
    }
    if (e->button() == Qt::LeftButton) {
        if (QWindow *w = window()->windowHandle()) {
            w->startSystemMove();
        }
    }
}

void Rodape::leaveEvent(QEvent *)
{
    if (m_sobrePasta) {
        m_sobrePasta = false;
        update();
    }
}

// ---------------------------------------------------------------------------
// Janela

Janela::Janela(const QString &pasta, const QStringList &comando, bool segurar)
    : QWidget(nullptr)
{
    setAttribute(Qt::WA_TranslucentBackground);
    setWindowFlags(Qt::Window | Qt::FramelessWindowHint);
    setMouseTracking(true);
    setMinimumSize(520, 300);
    setWindowTitle(t("Terminal", "Terminal"));

    lerVidro();
    tema.escuro = palette().color(QPalette::Window).lightnessF() < 0.5;
    if (qEnvironmentVariableIsSet("MATSU_TERMINAL_TEMA")) {
        tema.escuro = qEnvironmentVariable("MATSU_TERMINAL_TEMA") != QLatin1String("claro");
    }
    tema.desfoque = temDesfoque();

    m_pilha = new QStackedWidget(this);
    m_pilha->setAttribute(Qt::WA_TranslucentBackground);
    m_pilha->setFrameShape(QFrame::NoFrame);
    m_cabecalho = new Cabecalho(this);
    m_rodape = new Rodape(this);
    for (int i = 0; i < 4; ++i) {
        m_cantos[i] = new Canto(i, this);
    }
    m_vidro = new Vidro(this);

    // Atalhos da janela. Os de um modificador só passam pelo terminal primeiro
    // (sobreporAtalho decide); os outros chegam direto aqui.
    auto atalho = [this](const QList<QKeySequence> &teclas, auto funcao) {
        auto *a = new QAction(this);
        a->setShortcuts(teclas);
        a->setShortcutContext(Qt::WindowShortcut);
        connect(a, &QAction::triggered, this, funcao);
        addAction(a);
        return a;
    };
    atalho({QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_T)}, [this]() {
        novaAba();
    });
    atalho({QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_N)}, []() {
        QProcess::startDetached(QCoreApplication::applicationFilePath(), {});
    });
    atalho({QKeySequence(Qt::CTRL | Qt::Key_PageDown), QKeySequence(Qt::CTRL | Qt::Key_Tab)}, [this]() {
        if (m_abas.size() > 1) {
            irPara((m_atual + 1) % m_abas.size());
        }
    });
    atalho({QKeySequence(Qt::CTRL | Qt::Key_PageUp), QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_Backtab),
            QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_Tab)},
           [this]() {
               if (m_abas.size() > 1) {
                   irPara((m_atual + m_abas.size() - 1) % m_abas.size());
               }
           });
    for (int i = 0; i < 9; ++i) {
        atalho({QKeySequence(Qt::ALT | Qt::Key(Qt::Key_1 + i))}, [this, i]() {
            if (i < m_abas.size()) {
                irPara(i);
            }
        });
        m_atalhosNossos << QKeySequence(Qt::ALT | Qt::Key(Qt::Key_1 + i));
    }
    m_atalhosNossos << QKeySequence(Qt::CTRL | Qt::Key_PageDown) << QKeySequence(Qt::CTRL | Qt::Key_PageUp)
                    << QKeySequence(Qt::CTRL | Qt::Key_Tab);
    atalho({QKeySequence(Qt::CTRL | Qt::Key_ParenLeft)}, [this]() {
        dividir(true);
    });
    atalho({QKeySequence(Qt::CTRL | Qt::Key_ParenRight)}, [this]() {
        dividir(false);
    });
    atalho({QKeySequence(Qt::Key_F11)}, [this]() {
        if (isFullScreen()) {
            showNormal();
        } else {
            showFullScreen();
        }
    });

    // O tamanho de antes.
    const KConfigGroup grupo(KSharedConfig::openConfig(), QStringLiteral("Janela"));
    resize(grupo.readEntry("Largura", 920), grupo.readEntry("Altura", 580));

    // A informação do rodapé e das abas (pasta, programa, tamanho) a cada pouco.
    m_relogio.setInterval(700);
    connect(&m_relogio, &QTimer::timeout, this, &Janela::atualizarInfo);
    m_relogio.start();

    connect(qApp, &QApplication::focusChanged, this, [this]() {
        m_cabecalho->update();
    });

    novaAba(pasta, comando, segurar);
    atualizarTema();
}

Janela::~Janela()
{
    // As peças morrem depois da lista de abas: que não avisem mais esta janela.
    m_relogio.stop();
    for (const Aba &aba : std::as_const(m_abas)) {
        if (aba.parte) {
            aba.parte->disconnect(this);
        }
    }
}

QString Janela::tituloAba(int i) const
{
    const Aba &aba = m_abas.at(i);
    if (!aba.programa.isEmpty()) {
        return aba.programa;
    }
    if (!aba.programaFixo.isEmpty()) {
        return aba.programaFixo;
    }
    const QString nome = nomeDaPasta(aba.pasta);
    return nome.isEmpty() ? t("Terminal", "Terminal") : nome;
}

void Janela::limparAtalhos(KParts::ReadOnlyPart *parte)
{
    // A peça do Konsole traz atalhos de abas dela (que aqui não existem). Tira os
    // que batem com os nossos, para o atalho não ficar ambíguo.
    static const QStringList nomes = {
        QStringLiteral("next-tab"), QStringLiteral("previous-tab"), QStringLiteral("last-tab"),
        QStringLiteral("last-used-tab"), QStringLiteral("last-used-tab-reverse"), QStringLiteral("toggle-two-tabs"),
        QStringLiteral("split-view-left-right"), QStringLiteral("split-view-top-bottom"),
        QStringLiteral("split-view-left-right-next-tab"), QStringLiteral("split-view-top-bottom-next-tab"),
        QStringLiteral("move-tab-to-right"), QStringLiteral("move-tab-to-left"), QStringLiteral("detach-view"),
        QStringLiteral("detach-tab"),
    };
    KActionCollection *colecao = parte->actionCollection();
    for (QAction *a : colecao->actions()) {
        if (nomes.contains(a->objectName()) || a->objectName().startsWith(QLatin1String("switch-to-tab-"))) {
            colecao->setDefaultShortcuts(a, {});
            a->setShortcuts({});
        }
    }
}

QAction *Janela::acaoDaParte(int i, const char *nome) const
{
    if (i < 0 || i >= m_abas.size() || !m_abas[i].parte) {
        return nullptr;
    }
    KParts::ReadOnlyPart *parte = m_abas[i].parte;
    // As ações da sessão ficam no "controlador" da peça (um cliente filho).
    const auto filhos = parte->childClients();
    for (KXMLGUIClient *c : filhos) {
        if (QAction *a = c->actionCollection()->action(QLatin1String(nome))) {
            return a;
        }
    }
    return parte->actionCollection()->action(QLatin1String(nome));
}

void Janela::sobreporAtalho(QKeyEvent *e, bool &sobrepor)
{
    // Atalhos de um modificador (Ctrl+PgDown, Alt+1...) vão para o terminal, a
    // não ser os nossos.
    const QKeySequence tecla(e->keyCombination());
    for (const QKeySequence &s : std::as_const(m_atalhosNossos)) {
        if (s.matches(tecla) == QKeySequence::ExactMatch) {
            sobrepor = false;
            return;
        }
    }
}

void Janela::novaAba(const QString &pastaPedida, const QStringList &comando, bool segurar)
{
    QString pasta = pastaPedida;
    if (pasta.isEmpty() && m_atual >= 0 && m_atual < m_abas.size()) {
        pasta = m_abas[m_atual].pasta; // a aba nova começa na pasta da atual
    }
    if (pasta.isEmpty() || !QFileInfo(pasta).isDir()) {
        pasta = QDir::currentPath();
    }

    const KPluginMetaData peca(QStringLiteral("kf6/parts/konsolepart"));
    const auto resultado = KPluginFactory::instantiatePlugin<KParts::ReadOnlyPart>(peca, this);
    if (!resultado) {
        std::fprintf(stderr, "matsu-terminal: não deu para carregar a peça do Konsole: %s\n",
                     qPrintable(resultado.errorText));
        if (m_abas.isEmpty()) {
            m_semPeca = true;
        }
        return;
    }
    KParts::ReadOnlyPart *parte = resultado.plugin;
    auto *terminal = qobject_cast<TerminalInterface *>(parte);
    if (!terminal) {
        delete parte;
        return;
    }

    Aba aba;
    aba.id = m_proximoId++;
    aba.cor = m_proximaCor++;
    aba.parte = parte;
    aba.terminal = terminal;
    aba.pasta = pasta;

    limparAtalhos(parte);
    QWidget *w = parte->widget();
    w->setAttribute(Qt::WA_TranslucentBackground);
    w->setPalette(paletaNeutra(w->palette()));
    m_pilha->addWidget(w);

    connect(parte, SIGNAL(overrideShortcut(QKeyEvent *, bool &)), this, SLOT(sobreporAtalhoSlot(QKeyEvent *, bool &)));
    // A peça avisa o título quando o lado ativo muda (tela dividida) ou a pasta
    // muda: é a hora segura de perguntar qual é o shell do lado ativo. O resto
    // (pasta, programa, tamanho) sai do /proc, sem mexer na peça.
    connect(parte, &KParts::Part::setWindowCaption, this, [this, id = aba.id]() {
        for (::Aba &a : m_abas) {
            if (a.id == id && a.parte && !a.parte->childClients().isEmpty()) {
                a.pid = a.terminal->terminalProcessId();
            }
        }
    });
    connect(parte, &QObject::destroyed, this, [this, id = aba.id]() {
        // O shell terminou (exit) ou a aba foi fechada: tira a aba.
        for (int i = 0; i < m_abas.size(); ++i) {
            if (m_abas[i].id == id) {
                m_abas.removeAt(i);
                if (m_abas.isEmpty()) {
                    close();
                    return;
                }
                // Fechou uma aba antes da atual: a atual andou uma casa. Fechou a
                // atual: a da direita entra no lugar (ou a da esquerda, se era a última).
                if (i < m_atual) {
                    --m_atual;
                }
                irPara(qBound(0, m_atual, int(m_abas.size()) - 1));
                break;
            }
        }
    });

    if (terminal->availableProfiles().contains(tema.perfil())) {
        terminal->setCurrentProfile(tema.perfil());
    }
    if (comando.isEmpty()) {
        terminal->showShellInDir(pasta);
    } else {
        aba.programaFixo = QFileInfo(comando.first()).fileName();
        QStringList args = comando;
        QString programa = comando.first();
        if (segurar) {
            // Mostra o fim e espera um Enter antes de fechar a aba.
            programa = QStringLiteral("/bin/sh");
            args = QStringList{programa, QStringLiteral("-c"),
                               QStringLiteral("\"$@\"; printf '\\n\\033[2m%1\\033[0m'; read -r _").arg(
                                   t("[ terminou: aperte Enter para fechar ]", "[ finished: press Enter to close ]")),
                               QStringLiteral("sh")}
                + comando;
        }
        const QString antes = QDir::currentPath();
        QDir::setCurrent(pasta);
        terminal->startProgram(programa, args);
        QDir::setCurrent(antes);
    }
    aba.pid = terminal->terminalProcessId();

    m_abas.append(aba);
    irPara(m_abas.size() - 1);
    atualizarCantos();
}

void Janela::irPara(int i)
{
    if (i < 0 || i >= m_abas.size()) {
        return;
    }
    m_atual = i;
    Aba &aba = m_abas[i];
    aba.terminou = false;
    if (aba.parte) {
        m_pilha->setCurrentWidget(aba.parte->widget());
        aba.parte->widget()->setFocus();
        // O foco vai para o terminal de dentro (a peça tem um quadro em volta).
        QTimer::singleShot(0, aba.parte->widget(), [w = QPointer<QWidget>(aba.parte->widget())]() {
            if (w && w->focusProxy()) {
                w->focusProxy()->setFocus();
            } else if (w) {
                const auto filhos = w->findChildren<QWidget *>();
                for (QWidget *f : filhos) {
                    if (f->inherits("Konsole::TerminalDisplay") && f->isVisible()) {
                        f->setFocus();
                        break;
                    }
                }
            }
        });
    }
    for (Canto *c : m_cantos) {
        c->raise();
    }
    atualizarInfo();
    atualizarCantos();
    m_gitPasta.clear(); // relê o git da aba nova
    atualizarGit();
    m_cabecalho->update();
}

void Janela::fecharAba(int i)
{
    if (i < 0 || i >= m_abas.size()) {
        return;
    }
    if (!m_abas[i].programa.isEmpty()) {
        QMessageBox caixa(this);
        caixa.setIcon(QMessageBox::Question);
        caixa.setWindowTitle(t("Fechar aba", "Close tab"));
        caixa.setText(t("O programa \"%1\" ainda está rodando nesta aba. Fechar mesmo assim?",
                        "\"%1\" is still running in this tab. Close it anyway?")
                          .arg(m_abas[i].programa));
        QPushButton *fechar = caixa.addButton(t("Fechar", "Close"), QMessageBox::AcceptRole);
        caixa.addButton(t("Cancelar", "Cancel"), QMessageBox::RejectRole);
        caixa.exec();
        if (caixa.clickedButton() != fechar) {
            return;
        }
    }
    if (m_abas[i].parte) {
        delete m_abas[i].parte.data(); // o "destroyed" tira a aba da lista
    }
}

void Janela::moverAba(int de, int para)
{
    if (de < 0 || para < 0 || de >= m_abas.size() || para >= m_abas.size() || de == para) {
        return;
    }
    const int idAtual = m_abas[m_atual].id;
    m_abas.move(de, para);
    for (int i = 0; i < m_abas.size(); ++i) {
        if (m_abas[i].id == idAtual) {
            m_atual = i;
        }
    }
    m_cabecalho->update();
}

// Segura os redimensionamentos dos terminais que já estavam na aba enquanto o
// Konsole divide a tela. Ao encaixar a vista nova, o divisor do Qt primeiro dá
// à vista antiga um tamanho de passagem, bem mais estreito, e só depois iguala
// as duas. A sessão antiga chegava a ser refeita nessa largura de passagem: o
// texto era quebrado, o bash redesenhava o prompt, e no tamanho final sobrava
// uma linha a menos e o cursor no meio do caminho. Assim cada terminal só vê o
// tamanho final.
class SegurarTamanho : public QObject
{
public:
    using QObject::QObject;
    QList<QPointer<QWidget>> alvos;

    bool eventFilter(QObject *, QEvent *evento) override
    {
        return evento->type() == QEvent::Resize;
    }
};

static QList<QWidget *> terminaisDe(QWidget *raiz)
{
    QList<QWidget *> lista;
    if (!raiz) {
        return lista;
    }
    const auto filhos = raiz->findChildren<QWidget *>();
    for (QWidget *w : filhos) {
        if (w->inherits("Konsole::TerminalDisplay")) {
            lista.append(w);
        }
    }
    return lista;
}

void Janela::dividir(bool ladoALado)
{
    if (m_atual < 0 || m_atual >= m_abas.size() || !m_abas[m_atual].parte) {
        return;
    }
    QAction *acao = acaoDaParte(m_atual, ladoALado ? "split-view-left-right" : "split-view-top-bottom");
    if (!acao || !acao->isEnabled()) {
        return;
    }
    SegurarTamanho segurar;
    const auto antigos = terminaisDe(m_abas[m_atual].parte->widget());
    for (QWidget *w : antigos) {
        segurar.alvos.append(w);
        w->installEventFilter(&segurar);
    }
    acao->trigger();
    for (const QPointer<QWidget> &w : std::as_const(segurar.alvos)) {
        if (!w) {
            continue;
        }
        w->removeEventFilter(&segurar);
        // O Konsole recalcula as linhas e colunas pelo tamanho atual do
        // terminal; o evento só avisa que é hora de fazer isso.
        QResizeEvent evento(w->size(), w->size());
        QCoreApplication::sendEvent(w, &evento);
    }
}

void Janela::abrirPasta()
{
    if (m_atual >= 0 && m_atual < m_abas.size() && !m_abas[m_atual].pasta.isEmpty()) {
        QDesktopServices::openUrl(QUrl::fromLocalFile(m_abas[m_atual].pasta));
    }
}

void Janela::abrirMenu(const QPoint &onde)
{
    Menu menu(this);
    auto item = [&menu](const QString &texto, const QKeySequence &tecla, auto funcao) {
        QAction *a = menu.addAction(texto);
        if (!tecla.isEmpty()) {
            a->setShortcut(tecla);
            a->setShortcutVisibleInContextMenu(true);
        }
        QObject::connect(a, &QAction::triggered, &menu, funcao);
        return a;
    };
    auto daParte = [this](const char *nome) {
        return [this, nome]() {
            if (QAction *a = acaoDaParte(m_atual, nome)) {
                a->trigger();
            }
        };
    };
    item(t("Nova aba", "New tab"), QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_T), [this]() {
        novaAba();
    });
    item(t("Nova janela", "New window"), QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_N), []() {
        QProcess::startDetached(QCoreApplication::applicationFilePath(), {});
    });
    menu.addSeparator();
    item(t("Dividir lado a lado", "Split left and right"), QKeySequence(Qt::CTRL | Qt::Key_ParenLeft), [this]() {
        dividir(true);
    });
    item(t("Dividir em cima e embaixo", "Split top and bottom"), QKeySequence(Qt::CTRL | Qt::Key_ParenRight), [this]() {
        dividir(false);
    });
    menu.addSeparator();
    QAction *copiar = item(t("Copiar", "Copy"), QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_C), daParte("edit_copy"));
    if (QAction *a = acaoDaParte(m_atual, "edit_copy")) {
        copiar->setEnabled(a->isEnabled());
    }
    item(t("Colar", "Paste"), QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_V), daParte("edit_paste"));
    item(t("Buscar", "Find"), QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_F), daParte("edit_find"));
    item(t("Limpar a tela", "Clear screen"), QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_K), daParte("clear-history-and-reset"));
    menu.addSeparator();
    item(t("Letra maior", "Bigger text"), QKeySequence(Qt::CTRL | Qt::Key_Plus), daParte("enlarge-font"));
    item(t("Letra menor", "Smaller text"), QKeySequence(Qt::CTRL | Qt::Key_Minus), daParte("shrink-font"));
    menu.addSeparator();
    item(t("Abrir a pasta nos Arquivos", "Open folder in Files"), QKeySequence(), [this]() {
        abrirPasta();
    });
    item(t("Ajustar o perfil do terminal…", "Edit terminal profile…"), QKeySequence(), [this]() {
        if (m_atual >= 0 && m_abas[m_atual].parte) {
            QMetaObject::invokeMethod(m_abas[m_atual].parte, "showEditCurrentProfileDialog", Q_ARG(QWidget *, this));
        }
    });
    menu.addSeparator();
    item(t("Fechar aba", "Close tab"), QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_W), [this]() {
        fecharAba(m_atual);
    });
    menu.afastarAtalhos();
    // O menu abre alinhado pela direita com o botão.
    const QSize tamanho = menu.sizeHint();
    menu.exec(QPoint(onde.x() - tamanho.width(), onde.y()));
}

void Janela::menuDaAba(int i, const QPoint &onde)
{
    Menu menu(this);
    QObject::connect(menu.addAction(t("Nova aba nesta pasta", "New tab in this folder")), &QAction::triggered, &menu, [this, i]() {
        novaAba(m_abas.value(i).pasta);
    });
    menu.addSeparator();
    QObject::connect(menu.addAction(t("Fechar aba", "Close tab")), &QAction::triggered, &menu, [this, i]() {
        fecharAba(i);
    });
    QAction *outras = menu.addAction(t("Fechar as outras abas", "Close other tabs"));
    outras->setEnabled(m_abas.size() > 1);
    QObject::connect(outras, &QAction::triggered, &menu, [this, i]() {
        const int id = m_abas.value(i).id;
        for (int j = m_abas.size() - 1; j >= 0; --j) {
            if (m_abas[j].id != id && m_abas[j].programa.isEmpty() && m_abas[j].parte) {
                delete m_abas[j].parte.data();
            }
        }
    });
    menu.exec(onde);
}

void Janela::alternarCheia()
{
    if (isMaximized() || isFullScreen()) {
        showNormal();
    } else {
        showMaximized();
    }
}

void Janela::atualizarCantos()
{
    for (Canto *c : m_cantos) {
        c->setVidro(tema.fundo());
    }
}

void Janela::atualizarTema()
{
    lerVidro();
    tema.desfoque = temDesfoque();
    if (!qEnvironmentVariableIsSet("MATSU_TERMINAL_TEMA")) {
        tema.escuro = QApplication::palette().color(QPalette::Window).lightnessF() < 0.5;
    }
    // Com a tela dividida, o Konsole escurece a barrinha do painel sem foco
    // com a cor de sombra do aplicativo, que no esquema de cores puxa para o
    // azul (no tema claro fica uma faixa azulada). A sombra passa a ser preta.
    // Trocar a paleta chama esta função de novo, e aí a sombra já está certa.
    QPalette doApp = QApplication::palette();
    if (doApp.color(QPalette::Active, QPalette::Shadow) != QColor(Qt::black)
        || doApp.color(QPalette::Inactive, QPalette::Shadow) != QColor(Qt::black)) {
        for (const auto grupo : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
            doApp.setColor(grupo, QPalette::Shadow, QColor(Qt::black));
        }
        QApplication::setPalette(doApp);
    }
    for (Aba &aba : m_abas) {
        if (aba.parte && aba.parte->widget()) {
            aba.parte->widget()->setPalette(paletaNeutra(QApplication::palette()));
        }
        if (aba.terminal && aba.parte && !aba.parte->childClients().isEmpty()
            && aba.terminal->currentProfileName() != tema.perfil()
            && aba.terminal->availableProfiles().contains(tema.perfil())) {
            aba.terminal->setCurrentProfile(tema.perfil());
        }
    }
    m_vidro->aplicar();
    atualizarCantos();
    QToolTip::setPalette(paletaNeutra(QApplication::palette()));
    update();
    m_cabecalho->update();
    m_rodape->update();
}

void Janela::atualizarInfo()
{
    bool mudouAba = false;
    for (int i = 0; i < m_abas.size(); ++i) {
        Aba &aba = m_abas[i];
        if (!aba.parte) {
            continue;
        }
        QString programa;
        if (!programaNaFrente(aba.pid, programa)) {
            continue; // o shell acabou de sair: a aba está fechando
        }
        if (aba.shell.isEmpty()) {
            aba.shell = nomeDoProcesso(aba.pid);
        }
        if (programa == aba.shell) {
            programa.clear();
        }
        const QString pasta = QFile::symLinkTarget(QStringLiteral("/proc/%1/cwd").arg(aba.pid));
        if (!aba.programa.isEmpty() && programa.isEmpty() && i != m_atual) {
            aba.terminou = true; // terminou em segundo plano: a aba ganha uma bolinha
        }
        if ((!pasta.isEmpty() && pasta != aba.pasta) || programa != aba.programa) {
            mudouAba = true;
        }
        if (!pasta.isEmpty()) {
            aba.pasta = pasta;
        }
        aba.programa = programa;
    }
    if (m_atual >= 0 && m_atual < m_abas.size()) {
        const Aba &aba = m_abas[m_atual];
        const QSize tamanho = tamanhoDoTerminal(aba.pid);
        const QString programa = !aba.programa.isEmpty() ? aba.programa
                               : !aba.programaFixo.isEmpty() ? aba.programaFixo
                                                             : aba.shell;
        if (aba.pasta != m_gitPasta || m_desdeGit.hasExpired(4000)) {
            atualizarGit();
        }
        m_rodape->setInfo(aba.pasta, m_gitRamo, m_gitMudancas, m_gitFrente, m_gitAtras, programa, !aba.programa.isEmpty(),
                          tamanho);
        const QString titulo = tituloAba(m_atual) + QStringLiteral(" — ") + t("Terminal", "Terminal");
        if (windowTitle() != titulo) {
            setWindowTitle(titulo);
        }
    }
    if (mudouAba) {
        m_cabecalho->update();
    }
}

void Janela::atualizarGit()
{
    if (m_atual < 0 || m_atual >= m_abas.size() || m_git) {
        return;
    }
    const QString pasta = m_abas[m_atual].pasta;
    if (pasta.isEmpty()) {
        return;
    }
    if (pasta != m_gitPasta) {
        // Pasta nova: some com o ramo antigo na hora (não mostra o ramo errado).
        m_gitRamo.clear();
        m_gitMudancas = m_gitFrente = m_gitAtras = 0;
    }
    m_gitPasta = pasta;
    m_desdeGit.start();
    m_git = new QProcess(this);
    QProcessEnvironment amb = QProcessEnvironment::systemEnvironment();
    amb.insert(QStringLiteral("GIT_OPTIONAL_LOCKS"), QStringLiteral("0"));
    amb.insert(QStringLiteral("LC_ALL"), QStringLiteral("C"));
    m_git->setProcessEnvironment(amb);
    m_git->setProcessChannelMode(QProcess::SeparateChannels);
    connect(m_git, &QProcess::finished, this, [this, pasta](int codigo) {
        const QString saida = QString::fromUtf8(m_git->readAllStandardOutput());
        m_git->deleteLater();
        m_git = nullptr;
        if (pasta != m_gitPasta) {
            return;
        }
        m_gitRamo.clear();
        m_gitMudancas = m_gitFrente = m_gitAtras = 0;
        if (codigo == 0) {
            const QStringList linhas = saida.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            for (const QString &linha : linhas) {
                if (linha.startsWith(QLatin1String("## "))) {
                    QString r = linha.mid(3);
                    if (r.startsWith(QLatin1String("No commits yet on "))) {
                        r = r.mid(18);
                    } else if (r.startsWith(QLatin1String("HEAD (no branch)"))) {
                        r = QStringLiteral("HEAD");
                    }
                    const int colchete = r.indexOf(QLatin1String(" ["));
                    if (colchete > 0) {
                        const QString info = r.mid(colchete + 2).chopped(1);
                        for (const QString &parte : info.split(QStringLiteral(", "))) {
                            if (parte.startsWith(QLatin1String("ahead "))) {
                                m_gitFrente = parte.mid(6).toInt();
                            } else if (parte.startsWith(QLatin1String("behind "))) {
                                m_gitAtras = parte.mid(7).toInt();
                            }
                        }
                        r = r.left(colchete);
                    }
                    m_gitRamo = r.section(QStringLiteral("..."), 0, 0);
                } else {
                    ++m_gitMudancas;
                }
            }
        }
        atualizarInfo();
    });
    connect(m_git, &QProcess::errorOccurred, this, [this](QProcess::ProcessError erro) {
        if (erro == QProcess::FailedToStart && m_git) {
            m_git->deleteLater();
            m_git = nullptr;
        }
    });
    m_git->start(QStringLiteral("git"), {QStringLiteral("-C"), pasta, QStringLiteral("status"), QStringLiteral("--porcelain=v1"),
                                         QStringLiteral("--branch"), QStringLiteral("--untracked-files=normal")});
    QTimer::singleShot(3000, m_git, [p = QPointer<QProcess>(m_git)]() {
        if (p && p->state() != QProcess::NotRunning) {
            p->kill(); // repositório gigante: desiste desta vez
        }
    });
}

void Janela::posicionar()
{
    const bool cheia = isFullScreen();
    const int cab = cheia ? 0 : Medida::cabecalho;
    const int rod = cheia ? 0 : Medida::rodape;
    const int lado = cheia ? 0 : Medida::lado;
    m_cabecalho->setVisible(!cheia);
    m_rodape->setVisible(!cheia);
    m_cabecalho->setGeometry(0, 0, width(), Medida::cabecalho);
    m_rodape->setGeometry(0, height() - Medida::rodape, width(), Medida::rodape);
    const QRect cartao(lado, cab, width() - 2 * lado, height() - cab - rod);
    m_pilha->setGeometry(cartao);
    const int r = Medida::raioCartao;
    m_cantos[0]->move(cartao.left(), cartao.top());
    m_cantos[1]->move(cartao.right() + 1 - r, cartao.top());
    m_cantos[2]->move(cartao.left(), cartao.bottom() + 1 - r);
    m_cantos[3]->move(cartao.right() + 1 - r, cartao.bottom() + 1 - r);
    for (Canto *c : m_cantos) {
        c->setVisible(!cheia);
        c->raise();
    }
}

bool Janela::bordaEm(const QPoint &p, Qt::Edges &bordas) const
{
    bordas = {};
    if (isMaximized() || isFullScreen()) {
        return false;
    }
    const int b = Medida::borda;
    const int canto = 16;
    if (p.x() < b) {
        bordas |= Qt::LeftEdge;
    }
    if (p.x() >= width() - b) {
        bordas |= Qt::RightEdge;
    }
    if (p.y() < b) {
        bordas |= Qt::TopEdge;
    }
    if (p.y() >= height() - b) {
        bordas |= Qt::BottomEdge;
    }
    // Perto de um canto, pega as duas bordas (fica mais fácil acertar).
    if (bordas & (Qt::LeftEdge | Qt::RightEdge)) {
        if (p.y() < canto) {
            bordas |= Qt::TopEdge;
        } else if (p.y() >= height() - canto) {
            bordas |= Qt::BottomEdge;
        }
    } else if (bordas & (Qt::TopEdge | Qt::BottomEdge)) {
        if (p.x() < canto) {
            bordas |= Qt::LeftEdge;
        } else if (p.x() >= width() - canto) {
            bordas |= Qt::RightEdge;
        }
    }
    return bordas != Qt::Edges();
}

void Janela::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);
    p.setCompositionMode(QPainter::CompositionMode_Source);
    p.fillRect(rect(), Qt::transparent);
    p.setCompositionMode(QPainter::CompositionMode_SourceOver);
    const bool cheia = isMaximized() || isFullScreen();
    const qreal r = cheia ? 0 : Medida::raio;
    QPainterPath forma;
    forma.addRoundedRect(QRectF(rect()), r, r);
    p.fillPath(forma, tema.fundo());
    if (!cheia) {
        p.setPen(QPen(tema.bordaJanela(), 1));
        p.setBrush(Qt::NoBrush);
        p.drawRoundedRect(QRectF(rect()).adjusted(0.5, 0.5, -0.5, -0.5), r - 0.5, r - 0.5);
    }
}

void Janela::resizeEvent(QResizeEvent *)
{
    posicionar();
    m_vidro->aplicar();
    // O tamanho do terminal muda um pouco depois (o shell recebe o novo tamanho).
    QTimer::singleShot(120, this, &Janela::atualizarInfo);
}

void Janela::showEvent(QShowEvent *)
{
    posicionar();
    m_vidro->aplicar();
}

void Janela::changeEvent(QEvent *e)
{
    if (e->type() == QEvent::ApplicationPaletteChange || e->type() == QEvent::PaletteChange) {
        atualizarTema();
    } else if (e->type() == QEvent::WindowStateChange) {
        posicionar();
        m_vidro->aplicar();
        update();
    } else if (e->type() == QEvent::ActivationChange) {
        m_cabecalho->update();
        // O vidro pode ter sido trocado nos Ajustes ou nos efeitos do KWin.
        const QString nivelAntes = tema.nivel;
        const QColor corAntes = tema.corVidro;
        lerVidro();
        if (tema.desfoque != temDesfoque() || tema.nivel != nivelAntes || tema.corVidro != corAntes) {
            atualizarTema();
        }
    }
    QWidget::changeEvent(e);
}

void Janela::closeEvent(QCloseEvent *e)
{
    QStringList rodando;
    for (const Aba &aba : std::as_const(m_abas)) {
        if (!aba.programa.isEmpty()) {
            rodando << aba.programa;
        }
    }
    if (!rodando.isEmpty()) {
        QMessageBox caixa(this);
        caixa.setIcon(QMessageBox::Question);
        caixa.setWindowTitle(t("Fechar o terminal", "Close terminal"));
        caixa.setText(rodando.size() == 1
                          ? t("O programa \"%1\" ainda está rodando. Fechar mesmo assim?", "\"%1\" is still running. Close anyway?")
                                .arg(rodando.first())
                          : t("Ainda tem programas rodando (%1). Fechar mesmo assim?", "Programs are still running (%1). Close anyway?")
                                .arg(rodando.join(QStringLiteral(", "))));
        QPushButton *fechar = caixa.addButton(t("Fechar", "Close"), QMessageBox::AcceptRole);
        caixa.addButton(t("Cancelar", "Cancel"), QMessageBox::RejectRole);
        caixa.exec();
        if (caixa.clickedButton() != fechar) {
            e->ignore();
            return;
        }
    }
    if (!isMaximized() && !isFullScreen()) {
        KConfigGroup grupo(KSharedConfig::openConfig(), QStringLiteral("Janela"));
        grupo.writeEntry("Largura", width());
        grupo.writeEntry("Altura", height());
        grupo.sync();
    }
    m_relogio.stop();
    e->accept();
}

void Janela::mouseMoveEvent(QMouseEvent *e)
{
    // A janela só recebe o mouse no vidro dos lados do terminal: é a borda de
    // verdade (perto dos cantos, redimensiona na diagonal).
    Qt::Edges bordas;
    setCursor(bordaEm(e->position().toPoint(), bordas) ? cursorDaBorda(bordas) : Qt::SizeHorCursor);
}

void Janela::mousePressEvent(QMouseEvent *e)
{
    if (e->button() != Qt::LeftButton || isMaximized() || isFullScreen()) {
        return;
    }
    QWindow *w = windowHandle();
    if (!w) {
        return;
    }
    Qt::Edges bordas;
    if (!bordaEm(e->position().toPoint(), bordas)) {
        bordas = e->position().x() < width() / 2.0 ? Qt::LeftEdge : Qt::RightEdge;
    }
    w->startSystemResize(bordas);
}

// ---------------------------------------------------------------------------
// Só para as prévias e os testes: com a variável
// MATSU_TERMINAL_ROTEIRO, o terminal segue um roteiro de comandos, um por linha:
//   digitar TEXTO      escreve no terminal (\n é Enter, \e é Esc)
//   aba [PASTA]        abre uma aba nova     ir N         vai para a aba N
//   dividir            divide lado a lado    dividir-baixo  divide em cima e embaixo
//   mouse X Y          põe o mouse em (X, Y) da janela
//   menu               abre o menu           esperar MS   espera
//   foto ARQUIVO       salva a janela por cima do papel de parede (MATSU_TERMINAL_PAPEL),
//                      com o desfoque e a sombra, como fica na tela
//   sair               fecha sem perguntar
static QImage desfocar(const QImage &img, int fator)
{
    const QSize pequeno(qMax(1, img.width() / fator), qMax(1, img.height() / fator));
    QImage p = img.scaled(pequeno, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    p = p.scaled(qMax(1, pequeno.width() / 2), qMax(1, pequeno.height() / 2), Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
            .scaled(pequeno, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    return p.scaled(img.size(), Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
}

static void fotoDaJanela(QWidget *janela, const QString &arquivo)
{
    const int margem = 56;
    const qreal escala = janela->devicePixelRatioF();
    const QSize tela = janela->size() + QSize(2 * margem, 2 * margem);
    QImage fundo(tela * escala, QImage::Format_ARGB32_Premultiplied);
    fundo.setDevicePixelRatio(escala);
    const QString papel = qEnvironmentVariable("MATSU_TERMINAL_PAPEL");
    QImage imgPapel(papel);
    {
        QPainter p(&fundo);
        if (!imgPapel.isNull()) {
            // O papel de parede cobrindo tudo, pegando um pedaço do meio.
            const QImage cobre = imgPapel.scaled(fundo.size() * 1.25, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
            p.drawImage(QRectF(QPointF(0, 0), QSizeF(tela)), cobre,
                        QRectF((cobre.width() - fundo.width()) / 2.0, (cobre.height() - fundo.height()) * 0.6, fundo.width(), fundo.height()));
        } else {
            p.fillRect(QRect(QPoint(0, 0), tela), QColor(60, 70, 90));
        }
    }
    QImage resultado = fundo.copy();
    resultado.setDevicePixelRatio(escala);
    QPainter p(&resultado);
    p.setRenderHint(QPainter::Antialiasing);
    const QRect lugar(QPoint(margem, margem), janela->size());
    const bool cheia = janela->isMaximized() || janela->isFullScreen();
    // A sombra.
    if (!cheia) {
        const QImage sombra = imagemDaSombra(34, Medida::raio);
        const int canto = 34 + Medida::raio;
        const int l = sombra.width();
        const QRect fora = lugar.adjusted(-34, -34, 34, 34);
        auto pedaco = [&](const QRect &destino, const QRect &origem) {
            p.drawImage(destino, sombra, origem);
        };
        pedaco(QRect(fora.left(), fora.top(), canto, canto), QRect(0, 0, canto, canto));
        pedaco(QRect(fora.right() + 1 - canto, fora.top(), canto, canto), QRect(l - canto, 0, canto, canto));
        pedaco(QRect(fora.left(), fora.bottom() + 1 - canto, canto, canto), QRect(0, l - canto, canto, canto));
        pedaco(QRect(fora.right() + 1 - canto, fora.bottom() + 1 - canto, canto, canto), QRect(l - canto, l - canto, canto, canto));
        pedaco(QRect(fora.left() + canto, fora.top(), fora.width() - 2 * canto, 34), QRect(canto, 0, 1, 34));
        pedaco(QRect(fora.left() + canto, fora.bottom() + 1 - 34, fora.width() - 2 * canto, 34), QRect(canto, l - 34, 1, 34));
        pedaco(QRect(fora.left(), fora.top() + canto, 34, fora.height() - 2 * canto), QRect(0, canto, 34, 1));
        pedaco(QRect(fora.right() + 1 - 34, fora.top() + canto, 34, fora.height() - 2 * canto), QRect(l - 34, canto, 34, 1));
    }
    // O desfoque do KWin atrás da janela (dentro dos cantos redondos).
    if (tema.desfoque) {
        QPainterPath forma;
        forma.addRoundedRect(QRectF(lugar), cheia ? 0 : Medida::raio, cheia ? 0 : Medida::raio);
        p.save();
        p.setClipPath(forma);
        p.drawImage(QRectF(QPointF(0, 0), QSizeF(tela)), desfocar(fundo, int(28 * escala)));
        p.restore();
    }
    p.drawPixmap(lugar.topLeft(), janela->grab());
    // Um menu aberto entra na foto também.
    if (QWidget *popup = QApplication::activePopupWidget()) {
        const QPoint onde = popup->mapToGlobal(QPoint(0, 0)) - janela->mapToGlobal(QPoint(0, 0)) + lugar.topLeft();
        QPainterPath forma;
        forma.addRoundedRect(QRectF(QRect(onde, popup->size())), 10, 10);
        p.save();
        p.setClipPath(forma);
        p.drawImage(QRectF(QPointF(0, 0), QSizeF(tela)), desfocar(resultado, int(20 * escala)));
        p.restore();
        p.drawPixmap(onde, popup->grab());
    }
    p.end();
    resultado.save(arquivo);
}

static void seguirRoteiro(Janela *janela, QStringList linhas)
{
    while (!linhas.isEmpty()) {
        const QString linha = linhas.takeFirst().trimmed();
        if (linha.isEmpty() || linha.startsWith(QLatin1Char('#'))) {
            continue;
        }
        const QString comando = linha.section(QLatin1Char(' '), 0, 0);
        const QString resto = linha.section(QLatin1Char(' '), 1);
        int espera = 250;
        if (comando == QLatin1String("digitar")) {
            QString texto = resto;
            texto.replace(QLatin1String("\\n"), QLatin1String("\n")).replace(QLatin1String("\\e"), QLatin1String("\x1b"));
            const int i = janela->atual();
            if (i >= 0 && janela->abas().at(i).terminal) {
                janela->abas().at(i).terminal->sendInput(texto);
            }
        } else if (comando == QLatin1String("aba")) {
            janela->novaAba(resto);
            espera = 500;
        } else if (comando == QLatin1String("ir")) {
            janela->irPara(resto.toInt());
        } else if (comando == QLatin1String("dividir")) {
            janela->dividir(true);
            espera = 500;
        } else if (comando == QLatin1String("dividir-baixo")) {
            janela->dividir(false);
            espera = 500;
        } else if (comando == QLatin1String("mouse")) {
            const QPoint ponto(resto.section(QLatin1Char(' '), 0, 0).toInt(), resto.section(QLatin1Char(' '), 1, 1).toInt());
            if (QWidget *alvo = janela->childAt(ponto)) {
                const QPointF local = alvo->mapFrom(janela, ponto);
                QEnterEvent entra(local, local, alvo->mapToGlobal(local));
                QApplication::sendEvent(alvo, &entra);
                QMouseEvent move(QEvent::MouseMove, local, alvo->mapToGlobal(local), Qt::NoButton, Qt::NoButton, Qt::NoModifier);
                QApplication::sendEvent(alvo, &move);
            }
        } else if (comando == QLatin1String("menu")) {
            QTimer::singleShot(0, janela, [janela]() {
                janela->abrirMenu(janela->mapToGlobal(QPoint(janela->width() - 10, Medida::cabecalho - 4)));
            });
        } else if (comando == QLatin1String("fechar-menu")) {
            if (QWidget *popup = QApplication::activePopupWidget()) {
                popup->close();
            }
        } else if (comando == QLatin1String("esperar")) {
            espera = resto.toInt();
        } else if (comando == QLatin1String("foto")) {
            fotoDaJanela(janela, resto);
        } else if (comando == QLatin1String("sair")) {
            QCoreApplication::exit(0);
            return;
        }
        QTimer::singleShot(espera, janela, [janela, linhas]() {
            seguirRoteiro(janela, linhas);
        });
        return;
    }
}

// ---------------------------------------------------------------------------
int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("matsu-terminal"));
    app.setApplicationDisplayName(t("Terminal", "Terminal"));
    app.setDesktopFileName(QStringLiteral("org.matsu.terminal"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("org.matsu.terminal"), QIcon::fromTheme(QStringLiteral("utilities-terminal"))));

    // Argumentos (os mesmos nomes do Konsole, para quem chama o terminal padrão).
    QString pasta;
    QStringList comando;
    bool segurar = false;
    const QStringList args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        const QString &a = args[i];
        if ((a == QLatin1String("--workdir") || a == QLatin1String("--pasta")) && i + 1 < args.size()) {
            pasta = args[++i];
        } else if (a.startsWith(QLatin1String("--workdir="))) {
            pasta = a.mid(10);
        } else if (a == QLatin1String("--hold") || a == QLatin1String("--noclose") || a == QLatin1String("--segurar")) {
            segurar = true;
        } else if (a == QLatin1String("-e") || a == QLatin1String("--")) {
            comando = args.mid(i + 1);
            break;
        } else if (a == QLatin1String("-h") || a == QLatin1String("--help") || a == QLatin1String("--ajuda")) {
            std::printf("%s", qPrintable(t("Uso: matsu-terminal [--workdir PASTA] [--hold] [-e PROGRAMA [ARGUMENTOS...]]\n",
                                           "Usage: matsu-terminal [--workdir DIR] [--hold] [-e PROGRAM [ARGS...]]\n")));
            return 0;
        }
    }
    // "-e 'programa com argumentos'" num argumento só (como alguns lançadores fazem).
    if (comando.size() == 1 && comando.first().contains(QLatin1Char(' '))) {
        comando = QProcess::splitCommand(comando.first());
    }

    // Sem a peça do Konsole, abre o próprio Konsole com os mesmos argumentos.
    if (!KPluginMetaData(QStringLiteral("kf6/parts/konsolepart")).isValid()) {
        std::fprintf(stderr, "matsu-terminal: peça do Konsole não encontrada; abrindo o Konsole\n");
        return QProcess::startDetached(QStringLiteral("konsole"), args.mid(1)) ? 0 : 1;
    }

    app.installEventFilter(new CoresNeutras(&app));
    auto *janela = new Janela(pasta, comando, segurar);
    if (janela->abas().isEmpty()) {
        delete janela;
        return QProcess::startDetached(QStringLiteral("konsole"), args.mid(1)) ? 0 : 1;
    }
    janela->setAttribute(Qt::WA_DeleteOnClose);
    janela->show();
    if (qEnvironmentVariableIsSet("MATSU_TERMINAL_ROTEIRO")) {
        QFile roteiro(qEnvironmentVariable("MATSU_TERMINAL_ROTEIRO"));
        if (roteiro.open(QIODevice::ReadOnly)) {
            const QStringList linhas = QString::fromUtf8(roteiro.readAll()).split(QLatin1Char('\n'));
            janela->activateWindow();
            QTimer::singleShot(900, janela, [janela, linhas]() {
                seguirRoteiro(janela, linhas);
            });
        }
    }
    return app.exec();
}

#include "main.moc"
