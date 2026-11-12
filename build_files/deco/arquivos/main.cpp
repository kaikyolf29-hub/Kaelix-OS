// Matsu OS — os Arquivos do Matsu.
//
// A janela é nossa, igual à que o Kaiky escolheu (a "fusão" do Mac com o
// Windows): vidro em cinza neutro, as bolinhas e as abas na mesma linha, embaixo
// voltar, avançar e subir, o caminho em pedaços ("Este computador › Downloads")
// e a busca; do lado, o Acesso rápido e os discos do computador com os nomes do
// Matsu ("Matsu (SSD)"); embaixo, quantos itens tem e quanto espaço sobra.
//
// A lista de arquivos em si é a mesma do Dolphin (a peça "dolphinpart"), que é
// rápida e completa: miniaturas, renomear no lugar, arrastar e soltar, desfazer.
// O nome dele não aparece em lugar nenhum: o app se chama Arquivos.
//
// Uso: matsu-arquivos [PASTA ou ENDEREÇO...] [--select ARQUIVO] [--daemon]
//   --select  abre a pasta do arquivo com ele já selecionado
//   --daemon  fica esperando pedidos de outros apps ("Mostrar na pasta"), pelo
//             serviço org.freedesktop.FileManager1
//
// Se a peça do Dolphin não estiver instalada, abre o próprio Dolphin.
#include <QAction>
#include <QActionGroup>
#include <QApplication>
#include <QClipboard>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDir>
#include <QDragEnterEvent>
#include <QDropEvent>
#include <QEasingCurve>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QGraphicsScene>
#include <QGraphicsView>
#include <QHash>
#include <QKeyEvent>
#include <QLineEdit>
#include <QMenu>
#include <QMessageBox>
#include <QMimeData>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QPlatformSurfaceEvent>
#include <QPointer>
#include <QProcess>
#include <QPushButton>
#include <QScrollArea>
#include <QStackedWidget>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QTextDocumentFragment>
#include <QTimer>
#include <QToolTip>
#include <QUrl>
#include <QUrlQuery>
#include <QWheelEvent>
#include <QWindow>
#include <QtMath>

#include <KActionCollection>
#include <KActionMenu>
#include <KConfig>
#include <KConfigGroup>
#include <KFileItem>
#include <KFileItemActions>
#include <KFileItemListProperties>
#include <KIO/DropJob>
#include <KIO/EmptyTrashJob>
#include <KIO/FileUndoManager>
#include <KIO/Global>
#include <KIO/JobUiDelegateFactory>
#include <KIO/OpenUrlJob>
#include <KIO/Paste>
#include <KIO/RestoreJob>
#include <KNewFileMenu>
#include <KParts/ListingFilterExtension>
#include <KParts/NavigationExtension>
#include <KParts/ReadOnlyPart>
#include <KPluginFactory>
#include <KPluginMetaData>
#include <KPropertiesDialog>
#include <KSharedConfig>
#include <KWindowEffects>
#include <KWindowShadow>
#include <KWindowSystem>
#include <Solid/Block>
#include <Solid/Device>
#include <Solid/DeviceNotifier>
#include <Solid/StorageAccess>
#include <Solid/StorageDrive>
#include <Solid/StorageVolume>

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
constexpr int barra = 44;       // voltar, avançar, subir, caminho e busca
constexpr int rodape = 30;      // itens e espaço livre
constexpr int lateral = 200;    // Acesso rápido e Este computador
constexpr int borda = 6;        // faixa da borda que redimensiona a janela
constexpr int pilula = 30;      // altura das abas e dos botões
constexpr int item = 30;        // altura de cada linha do lado
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
        c.setAlphaF(qBound(0.0, a, 1.0));
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
    // A área da lista de arquivos: um degrau acima do vidro do lado.
    QColor miolo() const
    {
        return escuro ? QColor::fromRgbF(1, 1, 1, 0.03) : QColor::fromRgbF(1, 1, 1, desfoque ? 0.5 : 0.7);
    }
    // O fundo do caminho e da busca.
    QColor campo(qreal sobre = 0) const
    {
        return escuro ? QColor::fromRgbF(0, 0, 0, 0.2 + 0.06 * sobre) : QColor::fromRgbF(1, 1, 1, 0.62 + 0.2 * sobre);
    }
    QColor linha() const
    {
        return tinta(escuro ? 0.075 : 0.09);
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
};
static Tema tema;

// Cores neutras para o que vem do KDE (caixas, menus da peça): o mesmo cinza do
// vidro, sem o azul do esquema de cores.
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
    // A lista do Dolphin pinta a seleção e o contorno do item atual com a cor de
    // destaque: cinza neutro, nada de azul.
    cor(QPalette::Accent, e ? QColor(132, 132, 144) : QColor(120, 120, 132));
    cor(QPalette::ToolTipBase, e ? QColor(40, 40, 44) : QColor(250, 250, 251));
    cor(QPalette::ToolTipText, texto);
    cor(QPalette::PlaceholderText, textoDesligado);
    cor(QPalette::Link, tema.corAba(0));
    return p;
}

// A lista de arquivos fica por cima do vidro: fundo transparente e a seleção num
// cinza translúcido (nada do azul do esquema de cores).
static QPalette paletaDaLista(QPalette p)
{
    p = paletaNeutra(p);
    const bool e = tema.escuro;
    const QColor nada(0, 0, 0, 0);
    for (auto grupo : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
        p.setColor(grupo, QPalette::Base, nada);
        p.setColor(grupo, QPalette::Window, nada);
        p.setColor(grupo, QPalette::AlternateBase, e ? QColor(255, 255, 255, 6) : QColor(0, 0, 0, 6));
        p.setColor(grupo, QPalette::Button, nada);
        p.setColor(grupo, QPalette::Highlight, e ? QColor(255, 255, 255, 34) : QColor(0, 0, 0, 22));
    }
    p.setColor(QPalette::Inactive, QPalette::Highlight, e ? QColor(255, 255, 255, 24) : QColor(0, 0, 0, 16));
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
    if (qEnvironmentVariableIsSet("MATSU_ARQUIVOS_SEM_VIDRO")) {
        return false;
    }
    if (qEnvironmentVariableIsSet("MATSU_ARQUIVOS_COM_VIDRO")) {
        return true;
    }
    // "Sem vidro" nos Ajustes (matsu vidro --transparencia sem): janela sólida.
    if (tema.nivel == QLatin1String("sem")) {
        return false;
    }
    return KWindowEffects::isEffectAvailable(KWindowEffects::BlurBehind);
}

static QFont fonte(qreal px, int peso = QFont::Normal)
{
    QFont f = QApplication::font();
    f.setPixelSize(qRound(px));
    f.setWeight(QFont::Weight(peso));
#if QT_VERSION >= QT_VERSION_CHECK(6, 7, 0)
    f.setFeature(QFont::Tag("tnum"), 1); // números com a mesma largura
#endif
    return f;
}

// Tamanhos como no Windows e no Mac ("1,2 GB", e não "1,2 GiB").
static QString tamanhoLegivel(QString s)
{
    s.replace(QLatin1String("KiB"), QLatin1String("KB"));
    s.replace(QLatin1String("MiB"), QLatin1String("MB"));
    s.replace(QLatin1String("GiB"), QLatin1String("GB"));
    s.replace(QLatin1String("TiB"), QLatin1String("TB"));
    return s;
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
// Os desenhos de linha (traço fino e arredondado, como os ícones do Matsu). Cada
// um cabe num quadrado de 16 por 16 pontos.
enum Icone {
    ICasa, IMesa, IBaixar, IDocumento, IImagem, IVideo, IMusica, ILixeira, IDisco, IUsb, IPasta, ILupa, IComputador
};

namespace Desenho
{
static QPen traco(const QColor &cor, qreal largura = 1.4)
{
    return QPen(cor, largura, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
}

// Prepara o pintor para desenhar no quadrado de 16 de "r".
struct Quadro {
    Quadro(QPainter &p, const QRectF &r, const QColor &cor, qreal largura = 1.4)
        : m_p(p)
    {
        p.save();
        p.translate(r.topLeft());
        p.scale(r.width() / 16.0, r.height() / 16.0);
        p.setPen(traco(cor, largura * 16.0 / r.width()));
        p.setBrush(Qt::NoBrush);
    }
    ~Quadro()
    {
        m_p.restore();
    }
    QPainter &m_p;
};

static void icone(QPainter &p, const QRectF &r, int qual, const QColor &cor)
{
    Quadro q(p, r, cor);
    QPainterPath c;
    switch (qual) {
    case ICasa:
        c.moveTo(2.3, 7.6);
        c.lineTo(8, 2.7);
        c.lineTo(13.7, 7.6);
        p.drawPath(c);
        p.drawRoundedRect(QRectF(4, 6.6, 8, 7), 1.3, 1.3);
        p.drawLine(QPointF(8, 10.3), QPointF(8, 13.4));
        break;
    case IMesa:
    case IComputador:
        p.drawRoundedRect(QRectF(2, 2.8, 12, 8.4), 1.6, 1.6);
        p.drawLine(QPointF(8, 11.4), QPointF(8, 13.4));
        p.drawLine(QPointF(5.4, 13.4), QPointF(10.6, 13.4));
        break;
    case IBaixar:
        p.drawLine(QPointF(8, 2.4), QPointF(8, 9.8));
        c.moveTo(4.8, 6.8);
        c.lineTo(8, 10);
        c.lineTo(11.2, 6.8);
        p.drawPath(c);
        c.clear();
        c.moveTo(2.6, 10.2);
        c.lineTo(2.6, 12.2);
        c.quadTo(2.6, 13.4, 3.8, 13.4);
        c.lineTo(12.2, 13.4);
        c.quadTo(13.4, 13.4, 13.4, 12.2);
        c.lineTo(13.4, 10.2);
        p.drawPath(c);
        break;
    case IDocumento:
        c.moveTo(9.4, 2);
        c.lineTo(4.6, 2);
        c.quadTo(3.4, 2, 3.4, 3.2);
        c.lineTo(3.4, 12.8);
        c.quadTo(3.4, 14, 4.6, 14);
        c.lineTo(11.4, 14);
        c.quadTo(12.6, 14, 12.6, 12.8);
        c.lineTo(12.6, 5.2);
        c.closeSubpath();
        p.drawPath(c);
        c.clear();
        c.moveTo(9.4, 2);
        c.lineTo(9.4, 5.2);
        c.lineTo(12.6, 5.2);
        p.drawPath(c);
        p.drawLine(QPointF(5.7, 8.6), QPointF(10.3, 8.6));
        p.drawLine(QPointF(5.7, 11), QPointF(9, 11));
        break;
    case IImagem:
        p.drawRoundedRect(QRectF(2, 2.8, 12, 10.4), 2, 2);
        p.drawEllipse(QPointF(5.7, 6.2), 1.15, 1.15);
        c.moveTo(2.4, 12);
        c.lineTo(6.4, 8.4);
        c.lineTo(9, 10.8);
        c.lineTo(10.8, 9.2);
        c.lineTo(13.6, 11.8);
        p.drawPath(c);
        break;
    case IVideo:
        p.drawRoundedRect(QRectF(2, 3.4, 12, 9.2), 2, 2);
        p.setBrush(p.pen().color());
        c.moveTo(6.8, 5.9);
        c.lineTo(10.4, 8);
        c.lineTo(6.8, 10.1);
        c.closeSubpath();
        p.drawPath(c);
        break;
    case IMusica:
        p.drawLine(QPointF(6.2, 12), QPointF(6.2, 3.8));
        p.drawLine(QPointF(6.2, 3.8), QPointF(12.6, 2.6));
        p.drawLine(QPointF(12.6, 2.6), QPointF(12.6, 10.6));
        p.drawEllipse(QPointF(4.6, 12.1), 1.7, 1.5);
        p.drawEllipse(QPointF(11, 10.7), 1.7, 1.5);
        break;
    case ILixeira:
        p.drawLine(QPointF(2.4, 4.4), QPointF(13.6, 4.4));
        c.moveTo(6.2, 4.4);
        c.lineTo(6.2, 2.7);
        c.lineTo(9.8, 2.7);
        c.lineTo(9.8, 4.4);
        p.drawPath(c);
        c.clear();
        c.moveTo(3.8, 4.4);
        c.lineTo(4.6, 12.6);
        c.quadTo(4.7, 13.6, 5.7, 13.6);
        c.lineTo(10.3, 13.6);
        c.quadTo(11.3, 13.6, 11.4, 12.6);
        c.lineTo(12.2, 4.4);
        p.drawPath(c);
        p.drawLine(QPointF(6.7, 7), QPointF(6.9, 11));
        p.drawLine(QPointF(9.3, 7), QPointF(9.1, 11));
        break;
    case IDisco:
        p.drawRoundedRect(QRectF(1.8, 4, 12.4, 8.4), 2.2, 2.2);
        p.drawLine(QPointF(2.2, 8.9), QPointF(13.8, 8.9));
        p.setPen(Qt::NoPen);
        p.setBrush(cor);
        p.drawEllipse(QPointF(11.3, 10.65), 0.85, 0.85);
        break;
    case IUsb:
        p.drawRoundedRect(QRectF(4.6, 6.2, 6.8, 7.8), 1.6, 1.6);
        p.drawRect(QRectF(6.1, 2.4, 3.8, 3.8));
        p.drawLine(QPointF(7.4, 3.9), QPointF(7.4, 4.5));
        p.drawLine(QPointF(8.6, 3.9), QPointF(8.6, 4.5));
        break;
    case IPasta:
        c.moveTo(2, 4.4);
        c.quadTo(2, 3, 3.4, 3);
        c.lineTo(6.1, 3);
        c.lineTo(7.6, 4.6);
        c.lineTo(12.6, 4.6);
        c.quadTo(14, 4.6, 14, 6);
        c.lineTo(14, 12);
        c.quadTo(14, 13.4, 12.6, 13.4);
        c.lineTo(3.4, 13.4);
        c.quadTo(2, 13.4, 2, 12);
        c.closeSubpath();
        p.drawPath(c);
        break;
    case ILupa:
        p.drawEllipse(QPointF(7, 7), 4.3, 4.3);
        p.drawLine(QPointF(10.2, 10.2), QPointF(13.6, 13.6));
        break;
    default:
        break;
    }
}

static void voltar(QPainter &p, const QRectF &r, const QColor &cor)
{
    Quadro q(p, r, cor, 1.6);
    QPainterPath c;
    c.moveTo(10, 3.6);
    c.lineTo(5.6, 8);
    c.lineTo(10, 12.4);
    p.drawPath(c);
}

static void avancar(QPainter &p, const QRectF &r, const QColor &cor)
{
    Quadro q(p, r, cor, 1.6);
    QPainterPath c;
    c.moveTo(6, 3.6);
    c.lineTo(10.4, 8);
    c.lineTo(6, 12.4);
    p.drawPath(c);
}

static void subir(QPainter &p, const QRectF &r, const QColor &cor)
{
    Quadro q(p, r, cor, 1.6);
    p.drawLine(QPointF(8, 13), QPointF(8, 3.4));
    QPainterPath c;
    c.moveTo(3.8, 7.6);
    c.lineTo(8, 3.4);
    c.lineTo(12.2, 7.6);
    p.drawPath(c);
}

// O "›" entre os pedaços do caminho.
static void separador(QPainter &p, const QRectF &r, const QColor &cor)
{
    Quadro q(p, r, cor, 1.3);
    QPainterPath c;
    c.moveTo(6.6, 4.6);
    c.lineTo(9.8, 8);
    c.lineTo(6.6, 11.4);
    p.drawPath(c);
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

static void pontos(QPainter &p, const QPointF &c, const QColor &cor)
{
    p.setPen(Qt::NoPen);
    p.setBrush(cor);
    for (int i = -1; i <= 1; ++i) {
        p.drawEllipse(QPointF(c.x() + i * 5.0, c.y()), 1.45, 1.45);
    }
}

// Ver em lista: três linhas com um ponto na frente.
static void lista(QPainter &p, const QRectF &r, const QColor &cor)
{
    Quadro q(p, r, cor, 1.4);
    for (qreal y : {4.4, 8.0, 11.6}) {
        p.drawLine(QPointF(6, y), QPointF(13.2, y));
    }
    p.setPen(Qt::NoPen);
    p.setBrush(cor);
    for (qreal y : {4.4, 8.0, 11.6}) {
        p.drawEllipse(QPointF(3, y), 1, 1);
    }
}

// Ver em ícones: quatro quadradinhos.
static void grade(QPainter &p, const QRectF &r, const QColor &cor)
{
    Quadro q(p, r, cor, 1.3);
    p.drawRoundedRect(QRectF(2.6, 2.6, 4.6, 4.6), 1.3, 1.3);
    p.drawRoundedRect(QRectF(8.8, 2.6, 4.6, 4.6), 1.3, 1.3);
    p.drawRoundedRect(QRectF(2.6, 8.8, 4.6, 4.6), 1.3, 1.3);
    p.drawRoundedRect(QRectF(8.8, 8.8, 4.6, 4.6), 1.3, 1.3);
}

// Ejetar: um triângulo em cima de uma barra.
static void ejetar(QPainter &p, const QRectF &r, const QColor &cor)
{
    Quadro q(p, r, cor, 1.3);
    QPainterPath c;
    c.moveTo(8, 3.6);
    c.lineTo(12.4, 8.8);
    c.lineTo(3.6, 8.8);
    c.closeSubpath();
    p.drawPath(c);
    p.drawLine(QPointF(3.6, 12), QPointF(12.4, 12));
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
// Menus de vidro, com cantos redondos e os atalhos à direita. Vale para os
// nossos e para os que a peça abre (submenus de "Abrir com", colunas...).
static void vestirMenu(QMenu *m)
{
    if (m->property("matsuMenu").toBool()) {
        return;
    }
    m->setProperty("matsuMenu", true);
    m->setAttribute(Qt::WA_TranslucentBackground);
    const QColor fundo = tema.escuro ? QColor::fromRgbF(0.16, 0.16, 0.17, tema.desfoque ? 0.86 : 1)
                                     : QColor::fromRgbF(0.98, 0.98, 0.985, tema.desfoque ? 0.88 : 1);
    auto rgba = [](const QColor &c) {
        return QStringLiteral("rgba(%1,%2,%3,%4)").arg(c.red()).arg(c.green()).arg(c.blue()).arg(c.alphaF(), 0, 'f', 3);
    };
    m->setStyleSheet(QStringLiteral("QMenu { background: %1; border: 1px solid %2; border-radius: 10px; padding: 5px; }"
                                    "QMenu::item { color: %3; padding: 6px 28px 6px 12px; border-radius: 6px; margin: 0px; }"
                                    "QMenu::item:selected { background: %4; }"
                                    "QMenu::item:disabled { color: %5; }"
                                    "QMenu::separator { height: 1px; background: %6; margin: 5px 8px; }"
                                    "QMenu::icon { padding-left: 8px; }"
                                    "QMenu::right-arrow { width: 0px; }")
                         .arg(rgba(fundo), rgba(tema.tinta(tema.escuro ? 0.10 : 0.12)), rgba(tema.tinta(0.92)),
                              rgba(tema.tinta(tema.escuro ? 0.09 : 0.07)), rgba(tema.tinta(0.35)), rgba(tema.tinta(0.08))));
}

class Menu : public QMenu
{
public:
    explicit Menu(QWidget *pai)
        : QMenu(pai)
    {
        setWindowFlags(windowFlags() | Qt::FramelessWindowHint | Qt::NoDropShadowWindowHint);
        vestirMenu(this);
    }

    // Com estilo próprio, o Qt deixa só 12 px entre o nome do item e o atalho.
    // Uma largura mínima maior afasta a coluna dos atalhos.
    void afastarAtalhos(int folga = 28)
    {
        ensurePolished();
        setMinimumWidth(QMenu::sizeHint().width() + folga);
        QAction *vazio = addAction(QString());
        removeAction(vazio);
        delete vazio;
    }
};

// O que a peça e o KDE abrem (menus, caixas de perguntas, propriedades) ganha as
// cores neutras e o vidro nos menus.
class CoresNeutras : public QObject
{
public:
    using QObject::QObject;

protected:
    bool eventFilter(QObject *objeto, QEvent *evento) override
    {
        if (evento->type() == QEvent::Polish && objeto->isWidgetType()) {
            auto *w = static_cast<QWidget *>(objeto);
            if (auto *m = qobject_cast<QMenu *>(w)) {
                vestirMenu(m);
            } else if (w->isWindow() && !w->inherits("Janela")) {
                w->setPalette(paletaNeutra(QApplication::palette()));
            }
        } else if (evento->type() == QEvent::Show && objeto->isWidgetType() && objeto->property("matsuMenu").toBool()) {
            auto *m = static_cast<QWidget *>(objeto);
            QTimer::singleShot(0, m, [m]() {
                if (QWindow *w = m->windowHandle()) {
                    QPainterPath forma;
                    forma.addRoundedRect(QRectF(m->rect()), 10, 10);
                    KWindowEffects::enableBlurBehind(w, tema.desfoque, QRegion(forma.toFillPolygon().toPolygon()));
                }
            });
        }
        return false;
    }
};

// ---------------------------------------------------------------------------
// Pastas e discos.

static QString caminhoReal(const QString &p)
{
    const QString c = QFileInfo(p).canonicalFilePath();
    return c.isEmpty() ? QDir::cleanPath(p) : c;
}

static bool dentroDe(const QString &caminho, const QString &base)
{
    if (base == QLatin1String("/")) {
        return caminho.startsWith(QLatin1Char('/'));
    }
    return caminho == base || caminho.startsWith(base + QLatin1Char('/'));
}

static bool mesmoEndereco(const QUrl &a, const QUrl &b)
{
    if (a.isLocalFile() && b.isLocalFile()) {
        return caminhoReal(a.toLocalFile()) == caminhoReal(b.toLocalFile());
    }
    return a.matches(b, QUrl::StripTrailingSlash | QUrl::NormalizePathSegments);
}

// As pastas de sempre, com os nomes do Matsu.
struct PastaConhecida {
    QStandardPaths::StandardLocation onde;
    Icone icone;
    const char *pt;
    const char *en;
};
static const PastaConhecida pastasConhecidas[] = {
    {QStandardPaths::DesktopLocation, IMesa, "Área de trabalho", "Desktop"},
    {QStandardPaths::DownloadLocation, IBaixar, "Downloads", "Downloads"},
    {QStandardPaths::DocumentsLocation, IDocumento, "Documentos", "Documents"},
    {QStandardPaths::PicturesLocation, IImagem, "Imagens", "Pictures"},
    {QStandardPaths::MoviesLocation, IVideo, "Vídeos", "Videos"},
    {QStandardPaths::MusicLocation, IMusica, "Músicas", "Music"},
};

// "SSD" ou "HD" (pelo /sys: se o disco gira ou não). Vazio quando não dá para
// saber (disco virtual, por exemplo).
static QString tipoDoDisco(const QString &dispositivo)
{
    if (qEnvironmentVariableIsSet("MATSU_ARQUIVOS_TIPO_DISCO")) {
        return qEnvironmentVariable("MATSU_ARQUIVOS_TIPO_DISCO"); // só para as prévias
    }
    QString nome = QFileInfo(caminhoReal(dispositivo)).fileName(); // dm-0, nvme0n1p3, sda2
    if (nome.isEmpty() || !dispositivo.startsWith(QLatin1String("/dev/"))) {
        return QString();
    }
    // Disco criptografado ou LVM: desce até o disco de verdade.
    for (int volta = 0; volta < 8; ++volta) {
        const QStringList lista = QDir(QStringLiteral("/sys/class/block/%1/slaves").arg(nome)).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        if (lista.isEmpty()) {
            break;
        }
        nome = lista.first();
    }
    if (nome.startsWith(QLatin1String("vd")) || nome.startsWith(QLatin1String("xvd")) || nome.startsWith(QLatin1String("loop"))) {
        return QString();
    }
    QString base = QStringLiteral("/sys/class/block/") + nome;
    if (QFile::exists(base + QStringLiteral("/partition"))) {
        base = QFileInfo(base).canonicalFilePath() + QStringLiteral("/..");
    }
    QFile f(base + QStringLiteral("/queue/rotational"));
    if (!f.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return f.readAll().trimmed() == "1" ? QStringLiteral("HD") : QStringLiteral("SSD");
}

// O disco onde o Matsu está: "Matsu (SSD)".
static QString nomeDoDiscoDoSistema()
{
    static const QString nome = [] {
        const QString tipo = tipoDoDisco(QString::fromLocal8Bit(QStorageInfo(QDir::homePath()).device()));
        return tipo.isEmpty() ? QStringLiteral("Matsu") : QStringLiteral("Matsu (%1)").arg(tipo);
    }();
    return nome;
}

// Pontos de montagem do próprio sistema (não aparecem como discos).
static bool pontoDoSistema(const QString &p)
{
    static const QStringList exatos = {
        QStringLiteral("/"), QStringLiteral("/boot"), QStringLiteral("/efi"), QStringLiteral("/sysroot"), QStringLiteral("/usr"),
        QStringLiteral("/etc"), QStringLiteral("/var"), QStringLiteral("/home"), QStringLiteral("/var/home"), QStringLiteral("/root"),
        QStringLiteral("/opt"), QStringLiteral("/srv"), QStringLiteral("/tmp"), QStringLiteral("/var/log"), QStringLiteral("/var/lib"),
        QStringLiteral("/var/cache"), QStringLiteral("/var/tmp"), QStringLiteral("/snap"),
    };
    return exatos.contains(p) || p.startsWith(QLatin1String("/boot/")) || p.startsWith(QLatin1String("/sysroot/"))
        || p.startsWith(QLatin1String("/ostree/")) || p.startsWith(QLatin1String("/var/lib/"));
}

// Um lugar do lado: pasta do Acesso rápido, disco ou título de seção.
struct Lugar {
    enum Tipo { Secao, Pasta, Disco };
    Tipo tipo = Pasta;
    QString nome;
    QUrl url;           // vazio: disco ainda não montado
    int icone = IPasta;
    QString udi;        // discos: o identificador do Solid
    bool removivel = false;
    QString dica;
};

// Um pedaço do caminho ("Este computador", "Downloads"...).
struct Migalha {
    QString texto;
    QUrl url;
    bool computador = false; // "Este computador": abre a lista dos discos
};

// Uma aba: uma peça do Dolphin com uma pasta dentro.
struct Aba {
    int id = 0;
    int cor = 0;
    QPointer<KParts::ReadOnlyPart> parte;
    QPointer<KParts::NavigationExtension> extensao;
    QUrl url;
    QList<QUrl> antes;      // voltar
    QList<QUrl> depois;     // avançar
    QString status;         // "5 pastas, 3 arquivos (1,2 GB)"
    QString busca;          // o que está escrito na busca
    QString livre;          // "120 GB livres" no disco da pasta
    bool carregando = false;
};

class Janela;

// ---------------------------------------------------------------------------
// O cabeçalho: bolinhas, abas e o botão de nova aba.
class Cabecalho : public QWidget
{
public:
    explicit Cabecalho(Janela *janela);

    enum Tipo { Nada, Bolinha, AbaAlvo, FecharAba, NovaAba };
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
    void dragEnterEvent(QDragEnterEvent *e) override;
    void dragMoveEvent(QDragMoveEvent *e) override;
    void dragLeaveEvent(QDragLeaveEvent *e) override;
    void dropEvent(QDropEvent *e) override;

private:
    QRectF retBolinha(int i) const;
    QVector<QRectF> retAbas() const;
    QRectF retFechar(const QRectF &aba) const;
    QRectF retNovaAba() const;
    Alvo alvoEm(const QPointF &p) const;
    void desenharBolinhas(QPainter &p);
    void desenharAba(QPainter &p, int i, const QRectF &r);

    Janela *m_janela;
    Suave m_suave;
    Alvo m_sobre;
    Alvo m_apertado;
    QPointF m_inicioArraste;
    int m_arrastando = -1;
    qreal m_pega = 0;
    qreal m_xArrastada = 0;
    bool m_moveuJanela = false;
    QTimer m_trocarAoArrastar; // arrastar arquivos por cima de uma aba abre a aba
    int m_abaSobArraste = -1;
};

// ---------------------------------------------------------------------------
// A barra: voltar, avançar, subir, o caminho em pedaços e a busca.
class Barra : public QWidget
{
public:
    explicit Barra(Janela *janela);

    void atualizar();          // a pasta mudou
    void editarCaminho();      // Ctrl+L: o caminho vira texto para digitar
    void focarBusca();         // Ctrl+F
    QLineEdit *busca() const
    {
        return m_busca;
    }

    enum Tipo { Nada, Voltar, Avancar, Subir, Pedaco, Campo, Mais };
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
    void resizeEvent(QResizeEvent *) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mousePressEvent(QMouseEvent *e) override;
    void mouseReleaseEvent(QMouseEvent *e) override;
    void mouseDoubleClickEvent(QMouseEvent *e) override;
    void leaveEvent(QEvent *) override;
    bool event(QEvent *e) override;
    bool eventFilter(QObject *o, QEvent *e) override;
    void dragEnterEvent(QDragEnterEvent *e) override;
    void dragMoveEvent(QDragMoveEvent *e) override;
    void dropEvent(QDropEvent *e) override;

private:
    QRectF retBotao(int i) const;  // 0 voltar, 1 avançar, 2 subir
    QRectF retCampo() const;
    QRectF retBusca() const;
    QRectF retMais() const;
    QVector<QRectF> retPedacos() const;
    Alvo alvoEm(const QPointF &p) const;
    void fimDaEdicao(bool ir);

    Janela *m_janela;
    Suave m_suave;
    Alvo m_sobre;
    Alvo m_apertado;
    QLineEdit *m_editor;
    QLineEdit *m_busca;
    QVector<Migalha> m_pedacos;
    QVector<int> m_visiveis;   // quais pedaços cabem (os do começo viram "…")
    mutable QVector<QRectF> m_retPedacos;
    int m_pedacoSobArraste = -1;
};

// ---------------------------------------------------------------------------
// O lado: Acesso rápido e Este computador.
class Lateral : public QWidget
{
public:
    explicit Lateral(Janela *janela);

protected:
    void paintEvent(QPaintEvent *) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mousePressEvent(QMouseEvent *e) override;
    void mouseReleaseEvent(QMouseEvent *e) override;
    void leaveEvent(QEvent *) override;
    void wheelEvent(QWheelEvent *e) override;
    bool event(QEvent *e) override;
    void dragEnterEvent(QDragEnterEvent *e) override;
    void dragMoveEvent(QDragMoveEvent *e) override;
    void dragLeaveEvent(QDragLeaveEvent *e) override;
    void dropEvent(QDropEvent *e) override;

private:
    QRectF retItem(int i) const;
    QRectF retEjetar(const QRectF &item) const;
    int itemEm(const QPointF &p) const;
    int alturaTotal() const;

    Janela *m_janela;
    Suave m_suave;
    int m_sobre = -1;
    int m_apertado = -1;
    bool m_sobreEjetar = false;
    int m_soltarEm = -1;
    qreal m_rolagem = 0;
};

// ---------------------------------------------------------------------------
// O rodapé: quantos itens tem, o espaço livre e o jeito de ver (lista ou ícones).
class Rodape : public QWidget
{
public:
    explicit Rodape(Janela *janela);

protected:
    void paintEvent(QPaintEvent *) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mousePressEvent(QMouseEvent *e) override;
    void leaveEvent(QEvent *) override;
    bool event(QEvent *e) override;

private:
    QRectF retModo(int i) const; // 0 lista, 1 ícones
    int modoEm(const QPointF &p) const;

    Janela *m_janela;
    Suave m_suave;
    int m_sobre = -1;
};

// ---------------------------------------------------------------------------
class Janela : public QWidget
{
    Q_OBJECT

public:
    Janela(const QList<QUrl> &urls, const QList<QUrl> &selecionar = {});
    ~Janela() override;

    // Abas.
    const QVector<Aba> &abas() const
    {
        return m_abas;
    }
    int atual() const
    {
        return m_atual;
    }
    QString tituloAba(int i) const;
    int iconeAba(int i) const;
    void irPara(int i);
    void novaAba(const QUrl &url, bool ativar = true);
    void fecharAba(int i);
    void moverAba(int de, int para);
    void menuDaAba(int i, const QPoint &onde);

    // Navegação na aba atual.
    QUrl urlAtual() const;
    void abrir(const QUrl &url);
    void voltar();
    void avancar();
    void subir();
    void recarregar();
    bool podeVoltar() const;
    bool podeAvancar() const;
    bool podeSubir() const;
    QVector<Migalha> migalhas(const QUrl &url) const;
    QString nomeDe(const QUrl &url) const;
    void menuDosDiscos(const QPoint &onde);
    void menuDoPedaco(const QUrl &url, const QPoint &onde);

    // Busca: escrever filtra a pasta; Enter procura nas subpastas também.
    void filtrar(const QString &texto);
    void buscar(const QString &texto);

    // O lado.
    const QVector<Lugar> &lugares() const
    {
        return m_lugares;
    }
    int lugarAtual() const;
    void abrirLugar(int i, bool emNovaAba);
    void menuDoLugar(int i, const QPoint &onde);
    void ejetar(int i);
    void soltar(const QUrl &destino, QDropEvent *e);

    // O jeito de ver e o rodapé.
    QString modo() const;
    void mudarModo(const QString &modo);
    QString status() const;
    QString livre() const;

    void abrirMenu(const QPoint &onde); // o "⋯"
    void alternarCheia();
    bool bordaEm(const QPoint &p, Qt::Edges &bordas) const;
    KParts::ReadOnlyPart *parteAtual() const;
    Barra *barra() const
    {
        return m_barra;
    }

    // Para os testes (roteiro).
    void selecionar(const QList<QUrl> &urls);

protected:
    void paintEvent(QPaintEvent *) override;
    void resizeEvent(QResizeEvent *) override;
    void showEvent(QShowEvent *) override;
    void changeEvent(QEvent *e) override;
    void closeEvent(QCloseEvent *e) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mousePressEvent(QMouseEvent *e) override;

private Q_SLOTS:
    void lugaresMudaram();

private:
    int indiceDaAba(int id) const;
    void navegar(int id, const QUrl &url, bool guardar);
    void pedidoDeAbrir(int id, const QUrl &url, const QString &tipo);
    void menuDeContexto(int id, const QPoint &onde, const KFileItemList &itens,
                        const KParts::NavigationExtension::ActionGroupMap &grupos);
    QAction *acao(const char *nome) const;
    void atualizarLugares();
    void atualizarTema();
    void atualizarTudo();
    void posicionar();
    void prepararParte(KParts::ReadOnlyPart *parte);

    QVector<Aba> m_abas;
    int m_atual = -1;
    int m_proximoId = 1;
    int m_proximaCor = 0;
    QVector<Lugar> m_lugares;
    QTimer m_relerLugares;
    QStackedWidget *m_pilha;
    Cabecalho *m_cabecalho;
    Barra *m_barra;
    Lateral *m_lateral;
    Rodape *m_rodape;
    Vidro *m_vidro;
    QList<Solid::Device> m_dispositivos; // os discos do lado (vivos para avisar quando montam)
    QList<QUrl> m_selecionarNaAbertura;
};

// ---------------------------------------------------------------------------
// Coisas pequenas de janela.

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

// Pega a borda para redimensionar quando o mouse está nela; devolve true se pegou.
static bool pegarBorda(Janela *janela, QWidget *w, QMouseEvent *e)
{
    Qt::Edges bordas;
    if (e->button() == Qt::LeftButton && janela->bordaEm(w->mapTo(janela, e->position().toPoint()), bordas)) {
        if (QWindow *win = janela->windowHandle()) {
            win->startSystemResize(bordas);
        }
        return true;
    }
    return false;
}

static void cursorDaBordaEm(Janela *janela, QWidget *w, const QPointF &p, Qt::CursorShape normal = Qt::ArrowCursor)
{
    Qt::Edges bordas;
    w->setCursor(janela->bordaEm(w->mapTo(janela, p.toPoint()), bordas) ? cursorDaBorda(bordas) : normal);
}

// Um botão redondo de vidro (fundo só com o mouse em cima).
static void fundoDeBotao(QPainter &p, const QRectF &r, qreal sobre, bool apertado)
{
    if (sobre > 0.002 || apertado) {
        p.setPen(Qt::NoPen);
        p.setBrush(tema.tinta((apertado ? 0.12 : 0.07) * qMax(sobre, apertado ? 1.0 : 0.0)));
        p.drawRoundedRect(r, 8, 8);
    }
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
    setAcceptDrops(true);
    m_trocarAoArrastar.setSingleShot(true);
    m_trocarAoArrastar.setInterval(650);
    connect(&m_trocarAoArrastar, &QTimer::timeout, this, [this]() {
        if (m_abaSobArraste >= 0) {
            m_janela->irPara(m_abaSobArraste);
        }
    });
}

QRectF Cabecalho::retBolinha(int i) const
{
    // Como nos apps do Matsu: 18 pontos cada, 4 de vão, a 13 da borda.
    return QRectF(13 + i * 22, (height() - 18) / 2.0, 18, 18);
}

QVector<QRectF> Cabecalho::retAbas() const
{
    const int n = m_janela->abas().size();
    QVector<QRectF> r;
    if (n == 0) {
        return r;
    }
    const qreal inicio = retBolinha(2).right() + 18;
    const qreal fim = width() - 120 - Medida::pilula - 6; // espaço para o "+" e para arrastar a janela
    const qreal largura = qBound<qreal>(72, (fim - inicio - (n - 1) * 4) / n, 210);
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
    const auto abas = retAbas();
    for (int i = 0; i < abas.size(); ++i) {
        if (abas[i].contains(p)) {
            if (retFechar(abas[i]).adjusted(-2, -2, 2, 2).contains(p) && m_janela->abas().size() > 1) {
                return {FecharAba, i};
            }
            return {AbaAlvo, i};
        }
    }
    return {};
}

void Cabecalho::desenharBolinhas(QPainter &p)
{
    // Iguais às da borda das janelas do Matsu (comum/BotaoJanela.qml).
    static const QColor cores[3] = {QColor("#ec6a5e"), QColor("#f2c14e"), QColor("#5bc36a")};
    static const QColor simbolos[3] = {QColor("#5e1610"), QColor("#7a4d00"), QColor("#0f4d1b")};
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
    const bool sobre = ((m_sobre.tipo == AbaAlvo || m_sobre.tipo == FecharAba) && m_sobre.indice == i) || m_abaSobArraste == i;
    const qreal a = m_suave(QStringLiteral("ativa:") + chave, ativa ? 1 : 0, -1, 18);
    const qreal h = m_suave(QStringLiteral("sobre:") + chave, sobre ? 1 : 0, -1, 22);
    const qreal entrada = m_suave(QStringLiteral("entrada:") + chave, 1, 0, 14);

    p.save();
    p.setOpacity(entrada);
    // A ativa fica num degrau mais claro, com uma borda fina; as de trás têm um
    // fundo bem leve, para mostrar onde cada uma começa e acaba.
    const qreal fundo = tema.escuro ? (0.028 + 0.03 * h) * (1 - a) + 0.095 * a : (0.035 + 0.035 * h) * (1 - a);
    if (fundo > 0.002) {
        p.setPen(Qt::NoPen);
        p.setBrush(tema.tinta(fundo));
        p.drawRoundedRect(r, 8, 8);
    }
    if (!tema.escuro && a > 0.002) {
        p.setPen(Qt::NoPen);
        p.setBrush(QColor::fromRgbF(1, 1, 1, 0.78 * a));
        p.drawRoundedRect(r, 8, 8);
    }
    if (a > 0.002) {
        p.setPen(QPen(tema.tinta((tema.escuro ? 0.07 : 0.09) * a), 1));
        p.setBrush(Qt::NoBrush);
        p.drawRoundedRect(r.adjusted(0.5, 0.5, -0.5, -0.5), 7.5, 7.5);
        if (tema.escuro) {
            QLinearGradient brilho(r.topLeft(), r.bottomLeft());
            brilho.setColorAt(0, QColor::fromRgbF(1, 1, 1, 0.07 * a));
            brilho.setColorAt(0.5, QColor::fromRgbF(1, 1, 1, 0));
            p.setPen(QPen(QBrush(brilho), 1));
            p.drawRoundedRect(r.adjusted(0.5, 0.5, -0.5, -0.5), 7.5, 7.5);
        }
    }

    // O símbolo da pasta na cor da aba.
    QColor cor = tema.corAba(aba.cor);
    cor.setAlphaF(0.6 + 0.4 * qMax(a, h));
    const QRectF simbolo(r.left() + 10, r.center().y() - 8, 16, 16);
    Desenho::icone(p, simbolo, m_janela->iconeAba(i), cor);

    const QRectF fechar = retFechar(r);
    const bool podeFechar = m_janela->abas().size() > 1;
    const qreal mostrarFechar = m_suave(QStringLiteral("fechar:") + chave, (podeFechar && (ativa || sobre)) ? 1 : 0, -1, 22);
    const qreal direita = mostrarFechar > 0.01 ? fechar.left() - 4 : r.right() - 12;
    const QRectF texto(simbolo.right() + 7, r.top(), direita - simbolo.right() - 7, r.height());
    const QFont f = fonte(13, ativa ? QFont::Medium : QFont::Normal);
    p.setFont(f);
    const QString titulo = QFontMetricsF(f).elidedText(m_janela->tituloAba(i), Qt::ElideRight, texto.width());
    p.setPen(tema.tinta(0.62 + 0.33 * qMax(a, h * 0.6)));
    p.drawText(texto, Qt::AlignVCenter | Qt::AlignLeft, titulo);

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
        if (i == m_arrastando) {
            continue;
        }
        desenharAba(p, i, QRectF(x, abas[i].y(), w, abas[i].height()));
    }
    if (m_arrastando >= 0 && m_arrastando < abas.size()) {
        QRectF r = abas[m_arrastando];
        r.moveLeft(m_xArrastada);
        desenharAba(p, m_arrastando, r);
    }

    const QRectF nova = retNovaAba();
    const qreal xNova = m_suave(QStringLiteral("x:nova"), nova.x(), nova.x(), 18);
    const QRectF rNova(xNova, nova.y(), nova.width(), nova.height());
    const qreal h = m_suave(QStringLiteral("botao:nova"), m_sobre.tipo == NovaAba ? 1 : 0, -1, 22);
    fundoDeBotao(p, rNova, h, m_sobre.tipo == NovaAba && m_apertado.tipo == NovaAba);
    Desenho::mais(p, rNova.center(), tema.tinta(0.62 + 0.33 * h));
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
            dica = t("Fechar aba (Ctrl+W)", "Close tab (Ctrl+W)");
            break;
        case NovaAba:
            dica = t("Nova aba (Ctrl+T)", "New tab (Ctrl+T)");
            break;
        case AbaAlvo: {
            const QUrl u = m_janela->abas().at(a.indice).url;
            dica = u.toDisplayString(QUrl::PreferLocalFile);
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
    if (m_apertado.tipo == AbaAlvo && (e->buttons() & Qt::LeftButton) && m_janela->abas().size() > 1
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
    cursorDaBordaEm(m_janela, this, e->position());
}

void Cabecalho::mousePressEvent(QMouseEvent *e)
{
    if (pegarBorda(m_janela, this, e)) {
        return;
    }
    m_sobre = alvoEm(e->position());
    m_inicioArraste = e->position();
    m_moveuJanela = false;
    if (e->button() == Qt::MiddleButton && (m_sobre.tipo == AbaAlvo || m_sobre.tipo == FecharAba)) {
        m_janela->fecharAba(m_sobre.indice);
        return;
    }
    if (e->button() == Qt::RightButton) {
        if (m_sobre.tipo == AbaAlvo || m_sobre.tipo == FecharAba) {
            m_janela->menuDaAba(m_sobre.indice, e->globalPosition().toPoint());
        }
        return;
    }
    if (e->button() != Qt::LeftButton) {
        return;
    }
    m_apertado = m_sobre;
    if (m_apertado.tipo == AbaAlvo) {
        m_janela->irPara(m_apertado.indice);
    }
    update();
}

void Cabecalho::mouseReleaseEvent(QMouseEvent *e)
{
    if (e->button() != Qt::LeftButton) {
        return;
    }
    if (m_arrastando >= 0) {
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
        m_janela->novaAba(QUrl::fromLocalFile(QDir::homePath()));
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
    } else if (e->button() == Qt::LeftButton && a.tipo == AbaAlvo) {
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

void Cabecalho::dragEnterEvent(QDragEnterEvent *e)
{
    if (e->mimeData()->hasUrls()) {
        e->acceptProposedAction();
    }
}

void Cabecalho::dragMoveEvent(QDragMoveEvent *e)
{
    const Alvo a = alvoEm(e->position());
    const int aba = (a.tipo == AbaAlvo || a.tipo == FecharAba) ? a.indice : -1;
    if (aba != m_abaSobArraste) {
        m_abaSobArraste = aba;
        if (aba >= 0 && aba != m_janela->atual()) {
            m_trocarAoArrastar.start();
        } else {
            m_trocarAoArrastar.stop();
        }
        update();
    }
    if (aba >= 0) {
        e->acceptProposedAction();
    } else {
        e->ignore();
    }
}

void Cabecalho::dragLeaveEvent(QDragLeaveEvent *)
{
    m_abaSobArraste = -1;
    m_trocarAoArrastar.stop();
    update();
}

void Cabecalho::dropEvent(QDropEvent *e)
{
    const int aba = m_abaSobArraste;
    m_abaSobArraste = -1;
    m_trocarAoArrastar.stop();
    update();
    if (aba >= 0 && aba < m_janela->abas().size()) {
        m_janela->soltar(m_janela->abas().at(aba).url, e);
    }
}

// ---------------------------------------------------------------------------
// Barra

// Os dois campos de texto da barra (caminho e busca) não têm fundo nem borda: o
// fundo é a pílula que a barra desenha embaixo.
static void vestirCampo(QLineEdit *e)
{
    auto rgba = [](const QColor &c) {
        return QStringLiteral("rgba(%1,%2,%3,%4)").arg(c.red()).arg(c.green()).arg(c.blue()).arg(c.alphaF(), 0, 'f', 3);
    };
    e->setFrame(false);
    e->setAttribute(Qt::WA_MacShowFocusRect, false);
    e->setStyleSheet(QStringLiteral("QLineEdit { background: transparent; border: none; padding: 0px; color: %1;"
                                    " selection-background-color: %2; selection-color: %1; }")
                         .arg(rgba(tema.tinta(0.92)), rgba(tema.tinta(tema.escuro ? 0.22 : 0.18))));
    QPalette p = e->palette();
    p.setColor(QPalette::PlaceholderText, tema.tinta(0.42));
    p.setColor(QPalette::Text, tema.tinta(0.92));
    e->setPalette(p);
    e->setFont(fonte(13));
}

Barra::Barra(Janela *janela)
    : QWidget(janela)
    , m_janela(janela)
    , m_suave(this)
{
    setMouseTracking(true);
    setAttribute(Qt::WA_Hover);
    setAcceptDrops(true);

    m_editor = new QLineEdit(this);
    m_editor->hide();
    m_editor->installEventFilter(this);
    connect(m_editor, &QLineEdit::returnPressed, this, [this]() {
        fimDaEdicao(true);
    });

    m_busca = new QLineEdit(this);
    m_busca->setClearButtonEnabled(true);
    m_busca->installEventFilter(this);
    connect(m_busca, &QLineEdit::textEdited, this, [this](const QString &texto) {
        m_janela->filtrar(texto);
    });
    connect(m_busca, &QLineEdit::textChanged, this, [this](const QString &texto) {
        if (texto.isEmpty()) {
            m_janela->filtrar(QString()); // o "x" de limpar também tira o filtro
        }
        update();
    });
    connect(m_busca, &QLineEdit::returnPressed, this, [this]() {
        m_janela->buscar(m_busca->text());
    });
    vestirCampo(m_editor);
    vestirCampo(m_busca);
}

QRectF Barra::retBotao(int i) const
{
    return QRectF(10 + i * 32, (height() - Medida::pilula) / 2.0, Medida::pilula, Medida::pilula);
}

QRectF Barra::retMais() const
{
    return QRectF(width() - 10 - Medida::pilula, (height() - Medida::pilula) / 2.0, Medida::pilula, Medida::pilula);
}

QRectF Barra::retBusca() const
{
    const qreal largura = qBound(170.0, width() * 0.24, 270.0);
    return QRectF(retMais().left() - 8 - largura, (height() - Medida::pilula) / 2.0, largura, Medida::pilula);
}

QRectF Barra::retCampo() const
{
    const qreal x = retBotao(2).right() + 10;
    return QRectF(x, (height() - Medida::pilula) / 2.0, retBusca().left() - 8 - x, Medida::pilula);
}

// Onde fica cada pedaço do caminho. Se não couber, os do meio viram "…" (o
// primeiro, "Este computador", e os últimos sempre aparecem).
QVector<QRectF> Barra::retPedacos() const
{
    return m_retPedacos;
}

void Barra::atualizar()
{
    m_pedacos = m_janela->migalhas(m_janela->urlAtual());
    const QRectF campo = retCampo();
    const qreal folga = 6;     // de cada lado do texto
    const qreal seta = 14;     // o "›"
    auto largura = [&](int i) {
        const QFont f = fonte(13, i == m_pedacos.size() - 1 ? QFont::DemiBold : QFont::Normal);
        return QFontMetricsF(f).horizontalAdvance(m_pedacos[i].texto) + 2 * folga;
    };
    const qreal reticencias = QFontMetricsF(fonte(13)).horizontalAdvance(QStringLiteral("…")) + 2 * folga;
    const qreal disponivel = campo.width() - 16 - 30; // sobra para clicar e digitar
    // Escolhe quais cabem: começa com todos e vai tirando do segundo em diante.
    QVector<int> visiveis;
    for (int i = 0; i < m_pedacos.size(); ++i) {
        visiveis << i;
    }
    auto total = [&](const QVector<int> &v) {
        qreal s = 0;
        for (int k = 0; k < v.size(); ++k) {
            s += (v[k] < 0 ? reticencias : largura(v[k])) + (k > 0 ? seta : 0);
        }
        return s;
    };
    while (visiveis.size() > 2 && total(visiveis) > disponivel) {
        if (visiveis.size() > 1 && visiveis[1] == -1) {
            if (visiveis.size() <= 3) {
                break;
            }
            visiveis.remove(2);
        } else {
            visiveis[1] = -1;
        }
    }
    m_visiveis = visiveis;
    m_retPedacos.clear();
    qreal x = campo.left() + 6;
    for (int k = 0; k < visiveis.size(); ++k) {
        if (k > 0) {
            x += seta;
        }
        const qreal w = visiveis[k] < 0 ? reticencias : largura(visiveis[k]);
        m_retPedacos << QRectF(x, campo.top() + 3, qMin(w, campo.right() - 4 - x), campo.height() - 6);
        x += w;
    }
    const QString nome = m_janela->nomeDe(m_janela->urlAtual());
    m_busca->setPlaceholderText(t("Buscar em %1", "Search %1").arg(nome));
    const int i = m_janela->atual();
    const QString busca = i >= 0 ? m_janela->abas().at(i).busca : QString();
    if (m_busca->text() != busca) {
        m_busca->setText(busca);
    }
    vestirCampo(m_editor);
    vestirCampo(m_busca);
    update();
}

void Barra::resizeEvent(QResizeEvent *)
{
    const QRectF campo = retCampo();
    m_editor->setGeometry(campo.adjusted(12, 4, -10, -4).toRect());
    const QRectF busca = retBusca();
    m_busca->setGeometry(busca.adjusted(32, 4, -6, -4).toRect());
    atualizar();
}

void Barra::editarCaminho()
{
    const QUrl url = m_janela->urlAtual();
    m_editor->setText(url.isLocalFile() ? url.toLocalFile() : url.toDisplayString(QUrl::PreferLocalFile));
    m_editor->show();
    m_editor->setFocus(Qt::ShortcutFocusReason);
    m_editor->selectAll();
    update();
}

void Barra::focarBusca()
{
    m_busca->setFocus(Qt::ShortcutFocusReason);
    m_busca->selectAll();
}

void Barra::fimDaEdicao(bool ir)
{
    if (!m_editor->isVisible()) {
        return;
    }
    const QString texto = m_editor->text().trimmed();
    m_editor->hide();
    update();
    if (KParts::ReadOnlyPart *parte = m_janela->parteAtual()) {
        parte->widget()->setFocus();
    }
    if (!ir || texto.isEmpty()) {
        return;
    }
    QString caminho = texto;
    if (caminho == QLatin1String("~") || caminho.startsWith(QLatin1String("~/"))) {
        caminho = QDir::homePath() + caminho.mid(1);
    }
    QUrl url;
    if (caminho.startsWith(QLatin1Char('/'))) {
        url = QUrl::fromLocalFile(caminho);
    } else {
        const QUrl atual = m_janela->urlAtual();
        url = QUrl::fromUserInput(caminho, atual.isLocalFile() ? atual.toLocalFile() : QDir::homePath(), QUrl::AssumeLocalFile);
    }
    if (url.isValid()) {
        m_janela->abrir(url);
    }
}

bool Barra::eventFilter(QObject *o, QEvent *e)
{
    if (o == m_editor) {
        if (e->type() == QEvent::FocusOut) {
            fimDaEdicao(false);
        } else if (e->type() == QEvent::KeyPress && static_cast<QKeyEvent *>(e)->key() == Qt::Key_Escape) {
            fimDaEdicao(false);
            return true;
        }
    } else if (o == m_busca) {
        if (e->type() == QEvent::FocusIn || e->type() == QEvent::FocusOut) {
            update();
        } else if (e->type() == QEvent::KeyPress && static_cast<QKeyEvent *>(e)->key() == Qt::Key_Escape) {
            m_busca->clear();
            m_janela->filtrar(QString());
            if (KParts::ReadOnlyPart *parte = m_janela->parteAtual()) {
                parte->widget()->setFocus();
            }
            return true;
        } else if (e->type() == QEvent::KeyPress && static_cast<QKeyEvent *>(e)->key() == Qt::Key_Down) {
            if (KParts::ReadOnlyPart *parte = m_janela->parteAtual()) {
                parte->widget()->setFocus(); // seta para baixo: vai para a lista
            }
            return true;
        }
    }
    return QWidget::eventFilter(o, e);
}

Barra::Alvo Barra::alvoEm(const QPointF &p) const
{
    for (int i = 0; i < 3; ++i) {
        if (retBotao(i).contains(p)) {
            return {Tipo(Voltar + i), -1};
        }
    }
    if (retMais().contains(p)) {
        return {Mais, -1};
    }
    if (retCampo().contains(p) && !m_editor->isVisible()) {
        for (int k = 0; k < m_retPedacos.size(); ++k) {
            if (m_retPedacos[k].contains(p)) {
                return {Pedaco, k};
            }
        }
        return {Campo, -1};
    }
    return {};
}

void Barra::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::TextAntialiasing);

    // Voltar, avançar e subir.
    const bool pode[3] = {m_janela->podeVoltar(), m_janela->podeAvancar(), m_janela->podeSubir()};
    for (int i = 0; i < 3; ++i) {
        const QRectF r = retBotao(i);
        const bool sobre = pode[i] && m_sobre.tipo == Voltar + i;
        const qreal h = m_suave(QStringLiteral("botao:%1").arg(i), sobre ? 1 : 0, -1, 22);
        fundoDeBotao(p, r, h, sobre && m_apertado.tipo == Voltar + i);
        const QColor cor = tema.tinta(pode[i] ? 0.68 + 0.3 * h : 0.25);
        const QRectF ic(r.center().x() - 8, r.center().y() - 8, 16, 16);
        if (i == 0) {
            Desenho::voltar(p, ic, cor);
        } else if (i == 1) {
            Desenho::avancar(p, ic, cor);
        } else {
            Desenho::subir(p, ic, cor);
        }
    }

    // O caminho.
    const QRectF campo = retCampo();
    const bool sobreCampo = m_sobre.tipo == Campo || m_sobre.tipo == Pedaco;
    const qreal hc = m_suave(QStringLiteral("campo"), (sobreCampo || m_editor->isVisible()) ? 1 : 0, -1, 18);
    p.setPen(QPen(tema.tinta((tema.escuro ? 0.06 : 0.08) + 0.06 * (m_editor->isVisible() ? 1 : 0)), 1));
    p.setBrush(tema.campo(hc));
    p.drawRoundedRect(campo.adjusted(0.5, 0.5, -0.5, -0.5), 8, 8);
    if (!m_editor->isVisible()) {
        for (int k = 0; k < m_visiveis.size() && k < m_retPedacos.size(); ++k) {
            const QRectF r = m_retPedacos[k];
            const int i = m_visiveis[k];
            const bool ultimo = i == m_pedacos.size() - 1;
            if (k > 0) {
                Desenho::separador(p, QRectF(r.left() - 15, r.center().y() - 8, 16, 16), tema.tinta(0.38));
            }
            const bool sobre = m_sobre == Alvo{Pedaco, k} || m_pedacoSobArraste == k;
            const qreal h = m_suave(QStringLiteral("pedaco:%1:%2").arg(k).arg(i < 0 ? QStringLiteral("…") : m_pedacos[i].texto),
                                    sobre ? 1 : 0, -1, 22);
            if (h > 0.002) {
                p.setPen(Qt::NoPen);
                p.setBrush(tema.tinta((m_apertado == Alvo{Pedaco, k} ? 0.12 : 0.07) * h));
                p.drawRoundedRect(r, 6, 6);
            }
            const QFont f = fonte(13, ultimo ? QFont::DemiBold : QFont::Normal);
            p.setFont(f);
            p.setPen(tema.tinta(ultimo ? 0.95 : 0.66 + 0.26 * h));
            const QString texto = i < 0 ? QStringLiteral("…") : m_pedacos[i].texto;
            p.drawText(r.adjusted(6, 0, -4, 0), Qt::AlignVCenter | Qt::AlignLeft,
                       QFontMetricsF(f).elidedText(texto, Qt::ElideRight, r.width() - 10));
        }
    }

    // A busca.
    const QRectF busca = retBusca();
    const bool focada = m_busca->hasFocus();
    const qreal hb = m_suave(QStringLiteral("busca"), focada ? 1 : 0, -1, 18);
    p.setPen(QPen(tema.tinta((tema.escuro ? 0.06 : 0.08) + 0.1 * hb), 1));
    p.setBrush(tema.campo(hb));
    p.drawRoundedRect(busca.adjusted(0.5, 0.5, -0.5, -0.5), 8, 8);
    Desenho::icone(p, QRectF(busca.left() + 10, busca.center().y() - 7.5, 15, 15), ILupa, tema.tinta(0.45 + 0.3 * hb));

    // O "⋯".
    const QRectF mais = retMais();
    const qreal hm = m_suave(QStringLiteral("mais"), m_sobre.tipo == Mais ? 1 : 0, -1, 22);
    fundoDeBotao(p, mais, hm, m_sobre.tipo == Mais && m_apertado.tipo == Mais);
    Desenho::pontos(p, mais.center(), tema.tinta(0.62 + 0.33 * hm));
}

bool Barra::event(QEvent *e)
{
    if (e->type() == QEvent::ToolTip) {
        auto *he = static_cast<QHelpEvent *>(e);
        const Alvo a = alvoEm(he->pos());
        QString dica;
        switch (a.tipo) {
        case Voltar:
            dica = t("Voltar (Alt+←)", "Back (Alt+Left)");
            break;
        case Avancar:
            dica = t("Avançar (Alt+→)", "Forward (Alt+Right)");
            break;
        case Subir:
            dica = t("Pasta de cima (Alt+↑)", "Up (Alt+Up)");
            break;
        case Mais:
            dica = t("Mais opções", "More options");
            break;
        case Campo:
            dica = t("Clique para digitar o caminho (Ctrl+L)", "Click to type a path (Ctrl+L)");
            break;
        case Pedaco: {
            const int i = a.indice < m_visiveis.size() ? m_visiveis[a.indice] : -1;
            if (i > 0) {
                dica = m_pedacos[i].url.toDisplayString(QUrl::PreferLocalFile);
            } else if (i == 0 && m_pedacos[0].computador) {
                dica = t("Discos e pastas deste computador", "Drives and folders on this PC");
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

void Barra::mouseMoveEvent(QMouseEvent *e)
{
    const Alvo a = alvoEm(e->position());
    if (!(a == m_sobre)) {
        m_sobre = a;
        update();
    }
    cursorDaBordaEm(m_janela, this, e->position(), a.tipo == Campo ? Qt::IBeamCursor : Qt::ArrowCursor);
}

void Barra::mousePressEvent(QMouseEvent *e)
{
    if (pegarBorda(m_janela, this, e)) {
        return;
    }
    m_sobre = alvoEm(e->position());
    if (m_sobre.tipo == Pedaco) {
        const int i = m_sobre.indice < m_visiveis.size() ? m_visiveis[m_sobre.indice] : -2;
        const QRectF r = m_retPedacos.value(m_sobre.indice);
        const QPoint embaixo = mapToGlobal(QPoint(qRound(r.left()), qRound(r.bottom()) + 6));
        if (e->button() == Qt::MiddleButton && i >= 0 && !m_pedacos[i].url.isEmpty()) {
            m_janela->novaAba(m_pedacos[i].url, false);
            return;
        }
        if (e->button() == Qt::RightButton && i >= 0 && !m_pedacos[i].url.isEmpty()) {
            m_janela->menuDoPedaco(m_pedacos[i].url, e->globalPosition().toPoint());
            return;
        }
        if (e->button() == Qt::LeftButton && i == 0 && m_pedacos[0].computador) {
            m_janela->menuDosDiscos(embaixo); // "Este computador": a lista dos discos
            return;
        }
    }
    if (e->button() == Qt::LeftButton && m_sobre.tipo == Mais) {
        const QRectF r = retMais();
        m_janela->abrirMenu(mapToGlobal(QPoint(qRound(r.right()), qRound(r.bottom()) + 6)));
        return;
    }
    if (e->button() == Qt::LeftButton && m_sobre.tipo == Campo) {
        editarCaminho();
        return;
    }
    if (e->button() == Qt::BackButton) {
        m_janela->voltar();
        return;
    }
    if (e->button() == Qt::ForwardButton) {
        m_janela->avancar();
        return;
    }
    if (e->button() == Qt::LeftButton) {
        m_apertado = m_sobre;
        update();
    }
}

void Barra::mouseReleaseEvent(QMouseEvent *e)
{
    if (e->button() != Qt::LeftButton) {
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
    case Voltar:
        m_janela->voltar();
        break;
    case Avancar:
        m_janela->avancar();
        break;
    case Subir:
        m_janela->subir();
        break;
    case Pedaco: {
        const int k = apertado.indice;
        if (k >= m_visiveis.size()) {
            break;
        }
        int i = m_visiveis[k];
        if (i < 0) {
            // "…": vai para o último pedaço escondido.
            i = (k + 1 < m_visiveis.size()) ? m_visiveis[k + 1] - 1 : -1;
        }
        if (i >= 0 && i < m_pedacos.size() && !m_pedacos[i].url.isEmpty()) {
            m_janela->abrir(m_pedacos[i].url);
        }
        break;
    }
    default:
        break;
    }
}

void Barra::mouseDoubleClickEvent(QMouseEvent *e)
{
    const Alvo a = alvoEm(e->position());
    if (e->button() == Qt::LeftButton && (a.tipo == Campo || a.tipo == Pedaco)) {
        editarCaminho(); // dois cliques no caminho: digitar
        return;
    }
    if (e->button() == Qt::LeftButton && a.tipo == Nada) {
        m_janela->alternarCheia();
        return;
    }
    mousePressEvent(e);
}

void Barra::leaveEvent(QEvent *)
{
    m_sobre = {};
    update();
}

void Barra::dragEnterEvent(QDragEnterEvent *e)
{
    if (e->mimeData()->hasUrls()) {
        e->acceptProposedAction();
    }
}

void Barra::dragMoveEvent(QDragMoveEvent *e)
{
    const Alvo a = alvoEm(e->position());
    int k = -1;
    if (a.tipo == Pedaco && a.indice < m_visiveis.size()) {
        const int i = m_visiveis[a.indice];
        if (i >= 0 && !m_pedacos[i].url.isEmpty()) {
            k = a.indice;
        }
    }
    if (k != m_pedacoSobArraste) {
        m_pedacoSobArraste = k;
        update();
    }
    if (k >= 0) {
        e->acceptProposedAction();
    } else {
        e->ignore();
    }
}

void Barra::dropEvent(QDropEvent *e)
{
    const int k = m_pedacoSobArraste;
    m_pedacoSobArraste = -1;
    update();
    if (k >= 0 && k < m_visiveis.size()) {
        m_janela->soltar(m_pedacos[m_visiveis[k]].url, e);
    }
}

// ---------------------------------------------------------------------------
// Lateral

Lateral::Lateral(Janela *janela)
    : QWidget(janela)
    , m_janela(janela)
    , m_suave(this)
{
    setMouseTracking(true);
    setAttribute(Qt::WA_Hover);
    setAcceptDrops(true);
}

// Cada linha: títulos de seção um pouco mais altos (com um respiro antes, menos
// o primeiro), pastas e discos com a mesma altura.
QRectF Lateral::retItem(int i) const
{
    const auto &l = m_janela->lugares();
    qreal y = 6 - m_rolagem;
    for (int k = 0; k < l.size(); ++k) {
        const bool secao = l[k].tipo == Lugar::Secao;
        const qreal h = secao ? (k == 0 ? 26 : 38) : Medida::item;
        if (k == i) {
            return QRectF(8, y, width() - 16, h);
        }
        y += h + (secao ? 0 : 2);
    }
    return QRectF();
}

int Lateral::alturaTotal() const
{
    const auto &l = m_janela->lugares();
    if (l.isEmpty()) {
        return 0;
    }
    return qRound(retItem(l.size() - 1).bottom() + m_rolagem + 10);
}

QRectF Lateral::retEjetar(const QRectF &item) const
{
    return QRectF(item.right() - 6 - 22, item.center().y() - 11, 22, 22);
}

int Lateral::itemEm(const QPointF &p) const
{
    const auto &l = m_janela->lugares();
    for (int i = 0; i < l.size(); ++i) {
        if (l[i].tipo != Lugar::Secao && retItem(i).contains(p)) {
            return i;
        }
    }
    return -1;
}

void Lateral::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::TextAntialiasing);
    const auto &l = m_janela->lugares();
    const int atual = m_janela->lugarAtual();
    const int iAba = m_janela->atual();
    const QColor corDaAba = iAba >= 0 ? tema.corAba(m_janela->abas().at(iAba).cor) : tema.corAba(0);

    for (int i = 0; i < l.size(); ++i) {
        const Lugar &lugar = l[i];
        const QRectF r = retItem(i);
        if (r.bottom() < 0 || r.top() > height()) {
            continue;
        }
        if (lugar.tipo == Lugar::Secao) {
            QFont f = fonte(10.5, QFont::DemiBold);
            f.setLetterSpacing(QFont::PercentageSpacing, 108);
            p.setFont(f);
            p.setPen(tema.tinta(0.45));
            p.drawText(r.adjusted(10, 0, -4, -6), Qt::AlignBottom | Qt::AlignLeft, lugar.nome);
            continue;
        }
        const bool escolhido = i == atual;
        const bool sobre = i == m_sobre || i == m_soltarEm;
        const qreal h = m_suave(QStringLiteral("sobre:%1").arg(lugar.nome), sobre ? 1 : 0, -1, 22);
        const qreal a = m_suave(QStringLiteral("escolhido:%1").arg(lugar.nome), escolhido ? 1 : 0, -1, 18);
        // Fundo: o escolhido num degrau mais claro (no claro, branco leitoso), os
        // outros só com o mouse em cima.
        if (a > 0.002) {
            p.setPen(QPen(tema.tinta((tema.escuro ? 0.06 : 0.08) * a), 1));
            p.setBrush(tema.escuro ? tema.tinta(0.095 * a) : QColor::fromRgbF(1, 1, 1, 0.8 * a));
            p.drawRoundedRect(r.adjusted(0.5, 0.5, -0.5, -0.5), 7.5, 7.5);
        }
        if (h > 0.002 && a < 0.99) {
            p.setPen(Qt::NoPen);
            p.setBrush(tema.tinta((i == m_soltarEm ? 0.12 : (m_apertado == i ? 0.1 : 0.055)) * h * (1 - a)));
            p.drawRoundedRect(r, 8, 8);
        }
        if (i == m_soltarEm) {
            p.setPen(QPen(corDaAba, 1.4));
            p.setBrush(Qt::NoBrush);
            p.drawRoundedRect(r.adjusted(0.7, 0.7, -0.7, -0.7), 7.3, 7.3);
        }
        // O desenho: na cor da aba quando é o lugar aberto.
        QColor corIcone = tema.tinta(0.72 + 0.2 * h);
        if (a > 0.002) {
            corIcone = QColor::fromRgbF(corIcone.redF() + (corDaAba.redF() - corIcone.redF()) * a,
                                        corIcone.greenF() + (corDaAba.greenF() - corIcone.greenF()) * a,
                                        corIcone.blueF() + (corDaAba.blueF() - corIcone.blueF()) * a, 1.0);
        }
        Desenho::icone(p, QRectF(r.left() + 10, r.center().y() - 8, 16, 16), lugar.icone, corIcone);
        // O nome.
        const bool comEjetar = lugar.tipo == Lugar::Disco && lugar.removivel && !lugar.url.isEmpty();
        const QRectF texto(r.left() + 36, r.top(), r.width() - 36 - (comEjetar ? 30 : 6), r.height());
        const QFont f = fonte(13, escolhido ? QFont::Medium : QFont::Normal);
        p.setFont(f);
        const bool desmontado = lugar.tipo == Lugar::Disco && lugar.url.isEmpty();
        p.setPen(tema.tinta(desmontado ? 0.5 + 0.2 * h : 0.8 + 0.15 * qMax(a, h)));
        p.drawText(texto, Qt::AlignVCenter | Qt::AlignLeft, QFontMetricsF(f).elidedText(lugar.nome, Qt::ElideRight, texto.width()));
        if (comEjetar) {
            const QRectF ej = retEjetar(r);
            const bool sobreEj = sobre && m_sobreEjetar;
            if (sobreEj) {
                p.setPen(Qt::NoPen);
                p.setBrush(tema.tinta(0.1));
                p.drawEllipse(ej);
            }
            Desenho::ejetar(p, QRectF(ej.center().x() - 7, ej.center().y() - 7, 14, 14), tema.tinta(sobreEj ? 0.9 : 0.5 + 0.2 * h));
        }
    }

    // Uma sombra leve em cima e embaixo quando tem mais para rolar.
    const int total = alturaTotal();
    if (total > height()) {
        if (m_rolagem > 0.5) {
            QLinearGradient g(0, 0, 0, 14);
            g.setColorAt(0, tema.tinta(0.06));
            g.setColorAt(1, Qt::transparent);
            p.fillRect(QRectF(0, 0, width(), 14), g);
        }
        if (m_rolagem < total - height() - 0.5) {
            QLinearGradient g(0, height() - 14, 0, height());
            g.setColorAt(0, Qt::transparent);
            g.setColorAt(1, tema.tinta(0.06));
            p.fillRect(QRectF(0, height() - 14, width(), 14), g);
        }
    }
}

bool Lateral::event(QEvent *e)
{
    if (e->type() == QEvent::ToolTip) {
        auto *he = static_cast<QHelpEvent *>(e);
        const int i = itemEm(he->pos());
        QString dica;
        if (i >= 0) {
            const Lugar &l = m_janela->lugares().at(i);
            dica = !l.dica.isEmpty() ? l.dica : l.url.toDisplayString(QUrl::PreferLocalFile);
            if (l.tipo == Lugar::Disco && l.removivel && !l.url.isEmpty() && m_sobreEjetar) {
                dica = t("Tirar com segurança", "Safely remove");
            }
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

void Lateral::mouseMoveEvent(QMouseEvent *e)
{
    const int i = itemEm(e->position());
    bool ej = false;
    if (i >= 0) {
        const Lugar &l = m_janela->lugares().at(i);
        ej = l.tipo == Lugar::Disco && l.removivel && !l.url.isEmpty() && retEjetar(retItem(i)).contains(e->position());
    }
    if (i != m_sobre || ej != m_sobreEjetar) {
        m_sobre = i;
        m_sobreEjetar = ej;
        update();
    }
    cursorDaBordaEm(m_janela, this, e->position());
}

void Lateral::mousePressEvent(QMouseEvent *e)
{
    if (pegarBorda(m_janela, this, e)) {
        return;
    }
    const int i = itemEm(e->position());
    if (e->button() == Qt::BackButton) {
        m_janela->voltar();
        return;
    }
    if (e->button() == Qt::ForwardButton) {
        m_janela->avancar();
        return;
    }
    if (i < 0) {
        return;
    }
    if (e->button() == Qt::MiddleButton) {
        m_janela->abrirLugar(i, true);
        return;
    }
    if (e->button() == Qt::RightButton) {
        m_janela->menuDoLugar(i, e->globalPosition().toPoint());
        return;
    }
    if (e->button() == Qt::LeftButton) {
        m_apertado = i;
        update();
    }
}

void Lateral::mouseReleaseEvent(QMouseEvent *e)
{
    if (e->button() != Qt::LeftButton) {
        return;
    }
    const int i = itemEm(e->position());
    const int apertado = m_apertado;
    m_apertado = -1;
    update();
    if (i < 0 || i != apertado) {
        return;
    }
    const Lugar &l = m_janela->lugares().at(i);
    if (l.tipo == Lugar::Disco && l.removivel && !l.url.isEmpty() && retEjetar(retItem(i)).contains(e->position())) {
        m_janela->ejetar(i);
        return;
    }
    m_janela->abrirLugar(i, e->modifiers() & Qt::ControlModifier);
}

void Lateral::leaveEvent(QEvent *)
{
    m_sobre = -1;
    m_sobreEjetar = false;
    update();
}

void Lateral::wheelEvent(QWheelEvent *e)
{
    const int maximo = qMax(0, alturaTotal() - height());
    m_rolagem = qBound(0.0, m_rolagem - e->angleDelta().y() / 3.0, qreal(maximo));
    update();
}

void Lateral::dragEnterEvent(QDragEnterEvent *e)
{
    if (e->mimeData()->hasUrls()) {
        e->acceptProposedAction();
    }
}

void Lateral::dragMoveEvent(QDragMoveEvent *e)
{
    int i = itemEm(e->position());
    if (i >= 0 && m_janela->lugares().at(i).url.isEmpty()) {
        i = -1; // disco ainda não montado
    }
    if (i != m_soltarEm) {
        m_soltarEm = i;
        update();
    }
    if (i >= 0) {
        e->acceptProposedAction();
    } else {
        e->ignore();
    }
}

void Lateral::dragLeaveEvent(QDragLeaveEvent *)
{
    m_soltarEm = -1;
    update();
}

void Lateral::dropEvent(QDropEvent *e)
{
    const int i = m_soltarEm;
    m_soltarEm = -1;
    update();
    if (i >= 0 && i < m_janela->lugares().size()) {
        m_janela->soltar(m_janela->lugares().at(i).url, e);
    }
}

// ---------------------------------------------------------------------------
// Rodapé

Rodape::Rodape(Janela *janela)
    : QWidget(janela)
    , m_janela(janela)
    , m_suave(this)
{
    setMouseTracking(true);
    setAttribute(Qt::WA_Hover);
}

QRectF Rodape::retModo(int i) const
{
    const qreal x = width() - 12 - 26 - (1 - i) * 30;
    return QRectF(x, (height() - 22) / 2.0, 26, 22);
}

int Rodape::modoEm(const QPointF &p) const
{
    for (int i = 0; i < 2; ++i) {
        if (retModo(i).contains(p)) {
            return i;
        }
    }
    return -1;
}

void Rodape::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::TextAntialiasing);
    p.fillRect(QRectF(0, 0, width(), 1), tema.linha());

    // Lista ou ícones (como no canto do Explorador do Windows).
    const QString modo = m_janela->modo();
    for (int i = 0; i < 2; ++i) {
        const QRectF r = retModo(i);
        const bool ativo = (i == 0 && modo == QLatin1String("details")) || (i == 1 && modo == QLatin1String("icons"));
        const qreal h = m_suave(QStringLiteral("modo:%1").arg(i), m_sobre == i ? 1 : 0, -1, 22);
        const qreal a = m_suave(QStringLiteral("ativo:%1").arg(i), ativo ? 1 : 0, -1, 18);
        const qreal fundo = 0.1 * a + 0.06 * h * (1 - a);
        if (fundo > 0.002) {
            p.setPen(Qt::NoPen);
            p.setBrush(tema.tinta(fundo));
            p.drawRoundedRect(r, 6, 6);
        }
        const QRectF ic(r.center().x() - 7, r.center().y() - 7, 14, 14);
        const QColor cor = tema.tinta(0.5 + 0.45 * qMax(a, h));
        if (i == 0) {
            Desenho::lista(p, ic, cor);
        } else {
            Desenho::grade(p, ic, cor);
        }
    }

    const QFont f = fonte(12);
    p.setFont(f);
    const QFontMetricsF fm(f);
    const QString livre = m_janela->livre();
    const qreal xLivre = retModo(0).left() - 14 - fm.horizontalAdvance(livre);
    p.setPen(tema.tinta(0.45));
    p.drawText(QRectF(xLivre, 0, fm.horizontalAdvance(livre) + 2, height()), Qt::AlignVCenter | Qt::AlignLeft, livre);
    p.setPen(tema.tinta(0.66));
    const QRectF texto(14, 0, xLivre - 14 - 16, height());
    p.drawText(texto, Qt::AlignVCenter | Qt::AlignLeft, fm.elidedText(m_janela->status(), Qt::ElideMiddle, texto.width()));
}

bool Rodape::event(QEvent *e)
{
    if (e->type() == QEvent::ToolTip) {
        auto *he = static_cast<QHelpEvent *>(e);
        const int i = modoEm(he->pos());
        if (i < 0) {
            QToolTip::hideText();
            e->ignore();
        } else {
            QToolTip::showText(he->globalPos(), i == 0 ? t("Ver em lista (Ctrl+3)", "Details (Ctrl+3)") : t("Ver em ícones (Ctrl+1)", "Icons (Ctrl+1)"), this);
        }
        return true;
    }
    return QWidget::event(e);
}

void Rodape::mouseMoveEvent(QMouseEvent *e)
{
    const int i = modoEm(e->position());
    if (i != m_sobre) {
        m_sobre = i;
        update();
    }
    cursorDaBordaEm(m_janela, this, e->position());
}

void Rodape::mousePressEvent(QMouseEvent *e)
{
    if (pegarBorda(m_janela, this, e)) {
        return;
    }
    const int i = modoEm(e->position());
    if (e->button() == Qt::LeftButton && i >= 0) {
        m_janela->mudarModo(i == 0 ? QStringLiteral("details") : QStringLiteral("icons"));
        update();
    }
}

void Rodape::leaveEvent(QEvent *)
{
    m_sobre = -1;
    update();
}

// ---------------------------------------------------------------------------
// Janela

static Janela *abrirJanela(const QList<QUrl> &urls, const QList<QUrl> &selecionar = {});

// Os desenhos de linha como ícone de menu.
static QIcon iconeDesenhado(int qual)
{
    QPixmap px(QSize(16, 16) * 2);
    px.setDevicePixelRatio(2);
    px.fill(Qt::transparent);
    QPainter p(&px);
    p.setRenderHint(QPainter::Antialiasing);
    Desenho::icone(p, QRectF(0, 0, 16, 16), qual, tema.tinta(0.8));
    p.end();
    return QIcon(px);
}

static QString livreEm(const QUrl &url)
{
    if (!url.isLocalFile()) {
        return QString();
    }
    const QStorageInfo info(url.toLocalFile());
    if (!info.isValid() || info.bytesTotal() <= 0) {
        return QString();
    }
    return t("%1 livres", "%1 free").arg(tamanhoLegivel(KIO::convertSize(KIO::filesize_t(info.bytesAvailable()))));
}

Janela::Janela(const QList<QUrl> &urls, const QList<QUrl> &selecionar)
    : QWidget(nullptr)
{
    setAttribute(Qt::WA_TranslucentBackground);
    setWindowFlags(Qt::Window | Qt::FramelessWindowHint);
    setMouseTracking(true);
    setMinimumSize(640, 400);
    setWindowTitle(t("Arquivos", "Files"));

    lerVidro();
    tema.escuro = palette().color(QPalette::Window).lightnessF() < 0.5;
    if (qEnvironmentVariableIsSet("MATSU_ARQUIVOS_TEMA")) {
        tema.escuro = qEnvironmentVariable("MATSU_ARQUIVOS_TEMA") != QLatin1String("claro");
    }
    tema.desfoque = temDesfoque();

    m_pilha = new QStackedWidget(this);
    m_pilha->setFrameShape(QFrame::NoFrame);
    m_cabecalho = new Cabecalho(this);
    m_barra = new Barra(this);
    m_lateral = new Lateral(this);
    m_rodape = new Rodape(this);
    m_vidro = new Vidro(this);

    // Atalhos da janela.
    auto atalho = [this](const QList<QKeySequence> &teclas, auto funcao, QWidget *onde = nullptr) {
        auto *a = new QAction(onde ? onde : this);
        a->setShortcuts(teclas);
        a->setShortcutContext(onde ? Qt::WidgetWithChildrenShortcut : Qt::WindowShortcut);
        connect(a, &QAction::triggered, this, funcao);
        (onde ? onde : this)->addAction(a);
        return a;
    };
    atalho({QKeySequence(Qt::CTRL | Qt::Key_T)}, [this]() {
        novaAba(QUrl::fromLocalFile(QDir::homePath()));
    });
    atalho({QKeySequence(Qt::CTRL | Qt::Key_W)}, [this]() {
        if (m_abas.size() > 1) {
            fecharAba(m_atual);
        } else {
            close();
        }
    });
    atalho({QKeySequence(Qt::CTRL | Qt::Key_N)}, [this]() {
        abrirJanela({urlAtual()});
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
    }
    atalho({QKeySequence(Qt::ALT | Qt::Key_Left), QKeySequence(Qt::Key_Back)}, [this]() {
        voltar();
    });
    atalho({QKeySequence(Qt::ALT | Qt::Key_Right), QKeySequence(Qt::Key_Forward)}, [this]() {
        avancar();
    });
    atalho({QKeySequence(Qt::ALT | Qt::Key_Up)}, [this]() {
        subir();
    });
    atalho({QKeySequence(Qt::Key_Backspace)}, [this]() {
        voltar();
    }, m_pilha);
    atalho({QKeySequence(Qt::CTRL | Qt::Key_L), QKeySequence(Qt::ALT | Qt::Key_D), QKeySequence(Qt::Key_F6)}, [this]() {
        m_barra->editarCaminho();
    });
    atalho({QKeySequence(Qt::CTRL | Qt::Key_F), QKeySequence(Qt::CTRL | Qt::Key_E)}, [this]() {
        m_barra->focarBusca();
    });
    atalho({QKeySequence(Qt::Key_F5), QKeySequence(Qt::CTRL | Qt::Key_R)}, [this]() {
        recarregar();
    });
    atalho({QKeySequence(Qt::Key_F11)}, [this]() {
        if (isFullScreen()) {
            showNormal();
        } else {
            showFullScreen();
        }
    });
    atalho({QKeySequence::Copy}, [this]() {
        if (m_atual >= 0 && m_abas[m_atual].extensao) {
            QMetaObject::invokeMethod(m_abas[m_atual].extensao, "copy");
        }
    }, m_pilha);
    atalho({QKeySequence::Cut}, [this]() {
        if (m_atual >= 0 && m_abas[m_atual].extensao) {
            QMetaObject::invokeMethod(m_abas[m_atual].extensao, "cut");
        }
    }, m_pilha);
    atalho({QKeySequence::Paste}, [this]() {
        if (m_atual >= 0 && m_abas[m_atual].extensao) {
            QMetaObject::invokeMethod(m_abas[m_atual].extensao, "paste");
        }
    }, m_pilha);
    atalho({QKeySequence::Undo}, []() {
        KIO::FileUndoManager::self()->undo();
    }, m_pilha);

    // Discos que entram e saem (pendrive, HD externo).
    m_relerLugares.setSingleShot(true);
    m_relerLugares.setInterval(250);
    connect(&m_relerLugares, &QTimer::timeout, this, &Janela::atualizarLugares);
    connect(Solid::DeviceNotifier::instance(), &Solid::DeviceNotifier::deviceAdded, this, &Janela::lugaresMudaram);
    connect(Solid::DeviceNotifier::instance(), &Solid::DeviceNotifier::deviceRemoved, this, &Janela::lugaresMudaram);
    atualizarLugares();

    const KConfigGroup grupo(KSharedConfig::openConfig(), QStringLiteral("Janela"));
    resize(grupo.readEntry("Largura", 1000), grupo.readEntry("Altura", 620));

    connect(qApp, &QApplication::focusChanged, this, [this]() {
        m_cabecalho->update();
        m_barra->update();
    });

    m_selecionarNaAbertura = selecionar;
    const QList<QUrl> lista = urls.isEmpty() ? QList<QUrl>{QUrl::fromLocalFile(QDir::homePath())} : urls;
    for (const QUrl &u : lista) {
        novaAba(u, m_abas.isEmpty());
    }
    atualizarTema();
}

Janela::~Janela()
{
    // As peças morrem depois da lista de abas: que não avisem mais esta janela.
    for (const Aba &aba : std::as_const(m_abas)) {
        if (aba.parte) {
            aba.parte->disconnect(this);
            if (aba.extensao) {
                aba.extensao->disconnect(this);
            }
        }
    }
}

int Janela::indiceDaAba(int id) const
{
    for (int i = 0; i < m_abas.size(); ++i) {
        if (m_abas[i].id == id) {
            return i;
        }
    }
    return -1;
}

KParts::ReadOnlyPart *Janela::parteAtual() const
{
    return (m_atual >= 0 && m_atual < m_abas.size()) ? m_abas[m_atual].parte.data() : nullptr;
}

QUrl Janela::urlAtual() const
{
    return (m_atual >= 0 && m_atual < m_abas.size()) ? m_abas[m_atual].url : QUrl::fromLocalFile(QDir::homePath());
}

QAction *Janela::acao(const char *nome) const
{
    KParts::ReadOnlyPart *parte = parteAtual();
    return parte ? parte->actionCollection()->action(QLatin1String(nome)) : nullptr;
}

// O nome de um lugar, como aparece na aba e na busca: "Downloads", "Pasta
// pessoal", "Matsu (SSD)", "Lixeira"...
QString Janela::nomeDe(const QUrl &url) const
{
    const QVector<Migalha> m = migalhas(url);
    return m.isEmpty() ? url.toDisplayString(QUrl::PreferLocalFile) : m.last().texto;
}

QVector<Migalha> Janela::migalhas(const QUrl &url) const
{
    QVector<Migalha> m;
    if (url.scheme() == QLatin1String("trash")) {
        m << Migalha{t("Lixeira", "Trash"), QUrl(QStringLiteral("trash:/"))};
        QString atual;
        const QStringList partes = url.path().split(QLatin1Char('/'), Qt::SkipEmptyParts);
        for (int i = 0; i < partes.size(); ++i) {
            atual += QLatin1Char('/') + partes[i];
            QUrl u = url;
            u.setPath(atual);
            // Na lixeira, cada item de cima tem um número na frente ("3-foto.png").
            QString nome = partes[i];
            if (i == 0 && nome.contains(QLatin1Char('-'))) {
                nome = nome.section(QLatin1Char('-'), 1);
            }
            m << Migalha{nome, u};
        }
        return m;
    }
    if (url.scheme() == QLatin1String("filenamesearch")) {
        const QUrlQuery q(url);
        m << Migalha{t("Busca por “%1”", "Search for “%1”").arg(q.queryItemValue(QStringLiteral("search"), QUrl::FullyDecoded)), url};
        return m;
    }
    if (url.isLocalFile()) {
        const QString p = caminhoReal(url.toLocalFile());
        m << Migalha{t("Este computador", "This PC"), QUrl(), true};
        QString base;
        QString nomeBase;
        for (const Lugar &l : m_lugares) {
            if (l.tipo == Lugar::Secao || !l.url.isLocalFile()) {
                continue;
            }
            const QString b = caminhoReal(l.url.toLocalFile());
            if (dentroDe(p, b) && b.size() > base.size()) {
                base = b;
                nomeBase = l.nome;
            }
        }
        if (base.isEmpty()) {
            base = QStringLiteral("/");
            nomeBase = nomeDoDiscoDoSistema();
        }
        m << Migalha{nomeBase, QUrl::fromLocalFile(base)};
        QString atual = base;
        const QStringList partes = p.mid(base.size()).split(QLatin1Char('/'), Qt::SkipEmptyParts);
        for (const QString &parte : partes) {
            atual = (atual.endsWith(QLatin1Char('/')) ? atual : atual + QLatin1Char('/')) + parte;
            m << Migalha{parte, QUrl::fromLocalFile(atual)};
        }
        return m;
    }
    // Outros endereços (rede, celular...): o servidor e cada pasta.
    QUrl raiz = url;
    raiz.setPath(QStringLiteral("/"));
    raiz.setQuery(QString());
    m << Migalha{url.host().isEmpty() ? url.scheme() : url.host(), raiz};
    QString atual;
    const QStringList partes = url.path().split(QLatin1Char('/'), Qt::SkipEmptyParts);
    for (const QString &parte : partes) {
        atual += QLatin1Char('/') + parte;
        QUrl u = raiz;
        u.setPath(atual);
        m << Migalha{parte, u};
    }
    return m;
}

QString Janela::tituloAba(int i) const
{
    return nomeDe(m_abas.at(i).url);
}

int Janela::iconeAba(int i) const
{
    const QUrl &u = m_abas.at(i).url;
    if (u.scheme() == QLatin1String("trash")) {
        return ILixeira;
    }
    if (u.scheme() == QLatin1String("filenamesearch")) {
        return ILupa;
    }
    for (const Lugar &l : m_lugares) {
        if (l.tipo != Lugar::Secao && !l.url.isEmpty() && mesmoEndereco(l.url, u)) {
            return l.icone;
        }
    }
    return IPasta;
}

int Janela::lugarAtual() const
{
    const QUrl u = urlAtual();
    if (u.scheme() == QLatin1String("trash")) {
        for (int i = 0; i < m_lugares.size(); ++i) {
            if (m_lugares[i].url.scheme() == QLatin1String("trash")) {
                return i;
            }
        }
        return -1;
    }
    if (!u.isLocalFile()) {
        return -1;
    }
    const QString p = caminhoReal(u.toLocalFile());
    int melhor = -1;
    int tamanho = -1;
    for (int i = 0; i < m_lugares.size(); ++i) {
        const Lugar &l = m_lugares[i];
        if (l.tipo == Lugar::Secao || !l.url.isLocalFile()) {
            continue;
        }
        const QString b = caminhoReal(l.url.toLocalFile());
        if (dentroDe(p, b) && b.size() > tamanho) {
            melhor = i;
            tamanho = b.size();
        }
    }
    return melhor;
}

void Janela::prepararParte(KParts::ReadOnlyPart *parte)
{
    QWidget *w = parte->widget();
    const QPalette p = paletaDaLista(QApplication::palette());
    w->setPalette(p);
    const auto vistas = w->findChildren<QGraphicsView *>();
    for (QGraphicsView *v : vistas) {
        v->setPalette(p);
        if (v->scene()) {
            v->scene()->setPalette(p);
        }
    }
    const auto areas = w->findChildren<QAbstractScrollArea *>();
    for (QAbstractScrollArea *a : areas) {
        a->setFrameShape(QFrame::NoFrame);
    }
}

void Janela::novaAba(const QUrl &url, bool ativar)
{
    const KPluginMetaData peca(QStringLiteral("kf6/parts/dolphinpart"));
    const auto resultado = KPluginFactory::instantiatePlugin<KParts::ReadOnlyPart>(peca, m_pilha);
    if (!resultado) {
        std::fprintf(stderr, "matsu-arquivos: não deu para carregar a lista de arquivos: %s\n", qPrintable(resultado.errorText));
        return;
    }
    KParts::ReadOnlyPart *parte = resultado.plugin;
    Aba aba;
    aba.id = m_proximoId++;
    aba.cor = m_proximaCor++;
    aba.parte = parte;
    aba.extensao = KParts::NavigationExtension::childObject(parte);
    const int id = aba.id;

    // Os atalhos da peça (F2 renomear, Del lixeira, Ctrl+A...) valem dentro dela.
    // Os que a janela já tem (buscar) ou que dariam conflito saem.
    KActionCollection *colecao = parte->actionCollection();
    for (const char *nome : {"edit_find", "delete_shortcut", "select_items_matching"}) {
        if (QAction *a = colecao->action(QLatin1String(nome))) {
            colecao->setDefaultShortcuts(a, {});
            a->setShortcuts({});
        }
    }
    QWidget *w = parte->widget();
    for (QAction *a : colecao->actions()) {
        if (!a->shortcuts().isEmpty()) {
            a->setShortcutContext(Qt::WidgetWithChildrenShortcut);
            w->addAction(a);
        }
    }
    prepararParte(parte);
    m_pilha->addWidget(w);

    if (aba.extensao) {
        connect(aba.extensao, &KParts::NavigationExtension::openUrlRequest, this,
                [this, id](const QUrl &u, const KParts::OpenUrlArguments &args) {
                    pedidoDeAbrir(id, u, args.mimeType());
                });
        // A peça do Dolphin não liga o "Duplicar aqui" (Ctrl+D) sozinha: liga
        // quando tem algo selecionado numa pasta onde dá para escrever.
        connect(aba.extensao, &KParts::NavigationExtension::enableAction, this, [parte](const char *nome, bool ligado) {
            if (qstrcmp(nome, "copy") != 0) {
                return;
            }
            if (QAction *duplicar = parte->actionCollection()->action(QStringLiteral("duplicate"))) {
                const QUrl pasta = parte->url();
                const bool escrever = !pasta.isLocalFile() || QFileInfo(pasta.toLocalFile()).isWritable();
                duplicar->setEnabled(ligado && escrever && pasta.scheme() != QLatin1String("trash"));
            }
        });
        connect(aba.extensao, &KParts::NavigationExtension::createNewWindow, this, [this](const QUrl &u) {
            novaAba(u, false); // clique do meio numa pasta: abre numa aba de trás
        });
        connect(aba.extensao,
                qOverload<const QPoint &, const KFileItemList &, const KParts::OpenUrlArguments &, KParts::NavigationExtension::PopupFlags,
                          const KParts::NavigationExtension::ActionGroupMap &>(&KParts::NavigationExtension::popupMenu),
                this,
                [this, id](const QPoint &onde, const KFileItemList &itens, const KParts::OpenUrlArguments &,
                           KParts::NavigationExtension::PopupFlags, const KParts::NavigationExtension::ActionGroupMap &grupos) {
                    menuDeContexto(id, onde, itens, grupos);
                });
    }
    connect(parte, &KParts::ReadOnlyPart::urlChanged, this, [this, id](const QUrl &u) {
        // A peça trocou de endereço sozinha (um atalho que leva a outra pasta).
        const int i = indiceDaAba(id);
        if (i >= 0 && !u.isEmpty() && !mesmoEndereco(m_abas[i].url, u)) {
            m_abas[i].url = u;
            if (i == m_atual) {
                atualizarTudo();
            }
        }
    });
    connect(parte, &KParts::Part::setStatusBarText, this, [this, id](const QString &texto) {
        const int i = indiceDaAba(id);
        if (i < 0) {
            return;
        }
        m_abas[i].status = tamanhoLegivel(QTextDocumentFragment::fromHtml(texto).toPlainText().simplified());
        if (i == m_atual) {
            m_rodape->update();
        }
    });
    connect(parte, &KParts::ReadOnlyPart::started, this, [this, id]() {
        const int i = indiceDaAba(id);
        if (i >= 0) {
            m_abas[i].carregando = true;
        }
    });
    auto terminou = [this, id]() {
        const int i = indiceDaAba(id);
        if (i >= 0) {
            m_abas[i].carregando = false;
            m_abas[i].livre = livreEm(m_abas[i].url);
            if (i == m_atual) {
                m_rodape->update();
            }
        }
    };
    connect(parte, &KParts::ReadOnlyPart::completed, this, terminou);
    connect(parte, &KParts::ReadOnlyPart::canceled, this, terminou);
    connect(parte, SIGNAL(viewModeChanged()), m_rodape, SLOT(update()));

    // A aba nova entra logo depois da atual (como no navegador).
    const int lugar = m_atual >= 0 ? m_atual + 1 : m_abas.size();
    m_abas.insert(lugar, aba);
    if (m_atual >= lugar) {
        ++m_atual;
    }
    if (!m_selecionarNaAbertura.isEmpty()) {
        parte->setProperty("filesToSelect", QVariant::fromValue(m_selecionarNaAbertura));
        m_selecionarNaAbertura.clear();
    }
    navegar(id, url, false);
    if (ativar || m_atual < 0) {
        irPara(lugar);
    } else {
        m_cabecalho->update();
    }
}

void Janela::irPara(int i)
{
    if (i < 0 || i >= m_abas.size()) {
        return;
    }
    m_atual = i;
    Aba &aba = m_abas[i];
    if (aba.parte) {
        m_pilha->setCurrentWidget(aba.parte->widget());
        aba.parte->widget()->setFocus();
    }
    atualizarTudo();
}

void Janela::fecharAba(int i)
{
    if (i < 0 || i >= m_abas.size()) {
        return;
    }
    if (m_abas.size() == 1) {
        close();
        return;
    }
    KParts::ReadOnlyPart *parte = m_abas[i].parte;
    m_abas.removeAt(i);
    if (parte) {
        parte->disconnect(this);
        parte->deleteLater();
    }
    // Fechou uma antes da atual: a atual andou uma casa. Fechou a atual: a da
    // direita entra no lugar (ou a da esquerda, se era a última).
    if (i < m_atual) {
        --m_atual;
    }
    irPara(qBound(0, m_atual, int(m_abas.size()) - 1));
}

void Janela::moverAba(int de, int para)
{
    if (de < 0 || para < 0 || de >= m_abas.size() || para >= m_abas.size() || de == para) {
        return;
    }
    const int idAtual = m_abas[m_atual].id;
    m_abas.move(de, para);
    m_atual = indiceDaAba(idAtual);
    m_cabecalho->update();
}

void Janela::navegar(int id, const QUrl &url, bool guardar)
{
    const int i = indiceDaAba(id);
    if (i < 0 || !m_abas[i].parte || !url.isValid()) {
        return;
    }
    Aba &aba = m_abas[i];
    if (!aba.url.isEmpty() && mesmoEndereco(aba.url, url)) {
        return;
    }
    if (guardar && !aba.url.isEmpty()) {
        aba.antes << aba.url;
        aba.depois.clear();
    }
    aba.url = url;
    aba.busca.clear();
    aba.status.clear();
    aba.livre = livreEm(url);
    aba.parte->openUrl(url);
    if (i == m_atual) {
        atualizarTudo();
    } else {
        m_cabecalho->update();
    }
}

void Janela::abrir(const QUrl &url)
{
    if (m_atual >= 0) {
        navegar(m_abas[m_atual].id, url, true);
    }
}

bool Janela::podeVoltar() const
{
    return m_atual >= 0 && !m_abas[m_atual].antes.isEmpty();
}

bool Janela::podeAvancar() const
{
    return m_atual >= 0 && !m_abas[m_atual].depois.isEmpty();
}

bool Janela::podeSubir() const
{
    const QUrl u = urlAtual();
    if (u.scheme() == QLatin1String("filenamesearch")) {
        return false;
    }
    const QUrl cima = KIO::upUrl(u);
    return cima.isValid() && !mesmoEndereco(cima, u);
}

void Janela::voltar()
{
    if (!podeVoltar()) {
        return;
    }
    Aba &aba = m_abas[m_atual];
    const QUrl url = aba.antes.takeLast();
    aba.depois.prepend(aba.url);
    aba.url = QUrl();
    navegar(aba.id, url, false);
}

void Janela::avancar()
{
    if (!podeAvancar()) {
        return;
    }
    Aba &aba = m_abas[m_atual];
    const QUrl url = aba.depois.takeFirst();
    aba.antes << aba.url;
    aba.url = QUrl();
    navegar(aba.id, url, false);
}

void Janela::subir()
{
    if (podeSubir()) {
        const QUrl atual = urlAtual();
        abrir(KIO::upUrl(atual));
        // Na pasta de cima, a pasta de onde veio fica selecionada.
        if (KParts::ReadOnlyPart *parte = parteAtual()) {
            parte->setProperty("filesToSelect", QVariant::fromValue(QList<QUrl>{atual}));
        }
    }
}

void Janela::recarregar()
{
    KParts::ReadOnlyPart *parte = parteAtual();
    if (!parte) {
        return;
    }
    KParts::OpenUrlArguments args = parte->arguments();
    args.setReload(true);
    parte->setArguments(args);
    parte->openUrl(urlAtual());
    args.setReload(false);
    parte->setArguments(args);
}

void Janela::selecionar(const QList<QUrl> &urls)
{
    if (KParts::ReadOnlyPart *parte = parteAtual()) {
        // Recarregar devolve a seleção que a lista tinha antes; por isso a nova
        // seleção é marcada depois, e vale quando a pasta terminar de carregar.
        recarregar();
        parte->setProperty("filesToSelect", QVariant::fromValue(urls));
    }
}

// A peça pediu para abrir algo (dois cliques, Enter): pasta abre aqui mesmo;
// arquivo abre no app de sempre.
void Janela::pedidoDeAbrir(int id, const QUrl &url, const QString &tipo)
{
    const bool pasta = tipo == QLatin1String("inode/directory")
        || (tipo.isEmpty() && url.isLocalFile() && QFileInfo(url.toLocalFile()).isDir());
    if (pasta) {
        navegar(id, url, true);
        return;
    }
    auto *job = new KIO::OpenUrlJob(url, tipo);
    job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, this));
    job->setShowOpenOrExecuteDialog(true);
    job->start();
}

void Janela::filtrar(const QString &texto)
{
    if (m_atual < 0 || !m_abas[m_atual].parte) {
        return;
    }
    m_abas[m_atual].busca = texto;
    if (auto *filtro = KParts::ListingFilterExtension::childObject(m_abas[m_atual].parte)) {
        filtro->setFilter(KParts::ListingFilterExtension::SubString, texto);
    }
}

void Janela::buscar(const QString &texto)
{
    const QString procura = texto.trimmed();
    if (procura.isEmpty() || m_atual < 0) {
        return;
    }
    QUrl onde = urlAtual();
    if (onde.scheme() == QLatin1String("filenamesearch")) {
        onde = QUrl(QUrlQuery(onde).queryItemValue(QStringLiteral("url"), QUrl::FullyDecoded));
    }
    QUrl url;
    url.setScheme(QStringLiteral("filenamesearch"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("search"), procura);
    q.addQueryItem(QStringLiteral("url"), onde.url());
    q.addQueryItem(QStringLiteral("title"), t("Busca por “%1”", "Search for “%1”").arg(procura));
    url.setQuery(q);
    abrir(url);
    m_abas[m_atual].busca = procura;
    m_barra->atualizar();
}

QString Janela::modo() const
{
    KParts::ReadOnlyPart *parte = parteAtual();
    return parte ? parte->property("currentViewMode").toString() : QString();
}

void Janela::mudarModo(const QString &modo)
{
    if (KParts::ReadOnlyPart *parte = parteAtual()) {
        parte->setProperty("currentViewMode", modo);
        m_rodape->update();
    }
}

QString Janela::status() const
{
    return m_atual >= 0 ? m_abas[m_atual].status : QString();
}

QString Janela::livre() const
{
    return m_atual >= 0 ? m_abas[m_atual].livre : QString();
}

void Janela::soltar(const QUrl &destino, QDropEvent *e)
{
    if (destino.isEmpty()) {
        return;
    }
    KIO::DropJob *job = KIO::drop(e, destino);
    if (job) {
        job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, this));
    }
}

void Janela::atualizarTudo()
{
    if (m_atual >= 0 && m_atual < m_abas.size()) {
        const QString titulo = tituloAba(m_atual);
        if (windowTitle() != titulo) {
            setWindowTitle(titulo); // o Qt põe " — Arquivos" no fim
        }
    }
    m_barra->atualizar();
    m_cabecalho->update();
    m_lateral->update();
    m_rodape->update();
}

// ---------------------------------------------------------------------------
// Menus

// O botão direito na lista: no vazio, coisas da pasta; em cima de itens, o que
// dá para fazer com eles.
void Janela::menuDeContexto(int id, const QPoint &onde, const KFileItemList &itens,
                            const KParts::NavigationExtension::ActionGroupMap &grupos)
{
    const int i = indiceDaAba(id);
    if (i < 0 || !m_abas[i].parte) {
        return;
    }
    KParts::ReadOnlyPart *parte = m_abas[i].parte;
    QPointer<KParts::NavigationExtension> extensao = m_abas[i].extensao;
    const QUrl pasta = m_abas[i].url;
    KActionCollection *col = parte->actionCollection();
    auto *menu = new Menu(this);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    auto daParte = [&](const char *nome, const QString &texto = QString()) -> QAction * {
        QAction *a = col->action(QLatin1String(nome));
        if (a && a->isVisible()) {
            if (!texto.isEmpty()) {
                a->setText(texto);
            }
            menu->addAction(a);
        }
        return a;
    };
    auto chamar = [extensao](const char *metodo) {
        if (extensao) {
            QMetaObject::invokeMethod(extensao, metodo);
        }
    };
    const bool naLixeira = pasta.scheme() == QLatin1String("trash");
    const bool fundo = itens.size() == 1 && (mesmoEndereco(itens.first().url(), parte->url()) || mesmoEndereco(itens.first().url(), pasta));
    const bool podeColar = KIO::canPasteMimeData(QApplication::clipboard()->mimeData());

    if (fundo) {
        if (naLixeira) {
            const bool vazia = KConfig(QStringLiteral("trashrc"), KConfig::SimpleConfig).group(QStringLiteral("Status")).readEntry("Empty", true);
            QAction *esvaziar = menu->addAction(iconeDesenhado(ILixeira), t("Esvaziar a lixeira", "Empty Trash"), this, [this]() {
                QMessageBox caixa(this);
                caixa.setIcon(QMessageBox::Question);
                caixa.setWindowTitle(t("Esvaziar a lixeira", "Empty Trash"));
                caixa.setText(t("Apagar de vez tudo o que está na lixeira? Não dá para desfazer.",
                                "Permanently delete everything in the Trash? This cannot be undone."));
                QPushButton *sim = caixa.addButton(t("Esvaziar", "Empty"), QMessageBox::AcceptRole);
                caixa.addButton(t("Cancelar", "Cancel"), QMessageBox::RejectRole);
                caixa.exec();
                if (caixa.clickedButton() == sim) {
                    KIO::Job *job = KIO::emptyTrash();
                    job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, this));
                }
            });
            esvaziar->setEnabled(!vazia);
        } else {
            daParte("create_dir", t("Nova pasta", "New folder"));
            if (auto *novo = parte->findChild<KNewFileMenu *>()) {
                novo->setWorkingDirectory(pasta);
                novo->checkUpToDate();
                novo->setText(t("Novo arquivo", "New file"));
                menu->addAction(novo);
            }
            menu->addSeparator();
            QAction *colar = menu->addAction(t("Colar", "Paste"), this, [chamar]() {
                chamar("paste");
            });
            colar->setShortcut(QKeySequence::Paste);
            colar->setEnabled(podeColar);
            menu->addSeparator();
            daParte("open_terminal", t("Abrir terminal aqui", "Open terminal here"));
        }
        menu->addSeparator();
        daParte("view_mode", t("Exibir", "View"));
        daParte("sort", t("Ordenar por", "Sort by"));
        daParte("show_hidden_files", t("Mostrar arquivos ocultos", "Show hidden files"));
        menu->addSeparator();
        daParte("edit_select_all", t("Selecionar tudo", "Select all"));
        menu->addSeparator();
        QAction *prop = menu->addAction(t("Propriedades", "Properties"), this, [this, pasta]() {
            KPropertiesDialog::showDialog(pasta, this, false);
        });
        prop->setShortcut(QKeySequence(Qt::ALT | Qt::Key_Return));
    } else {
        const KFileItemListProperties propriedades(itens);
        const bool umaPasta = itens.size() == 1 && itens.first().isDir();
        if (umaPasta) {
            const QUrl u = itens.first().targetUrl();
            menu->addAction(t("Abrir", "Open"), this, [this, id, u]() {
                navegar(id, u, true);
            });
            menu->addAction(t("Abrir em nova aba", "Open in new tab"), this, [this, u]() {
                novaAba(u, false);
            });
            menu->addAction(t("Abrir em nova janela", "Open in new window"), this, [u]() {
                abrirJanela({u});
            });
        } else {
            menu->addAction(t("Abrir", "Open"), this, [this, id, itens]() {
                for (const KFileItem &item : itens) {
                    pedidoDeAbrir(id, item.targetUrl(), item.isDir() ? QStringLiteral("inode/directory") : item.mimetype());
                }
            });
        }
        // "Abrir com" (o app de sempre e os outros que abrem esse tipo).
        auto *acoes = new KFileItemActions(menu);
        acoes->setItemListProperties(propriedades);
        acoes->setParentWidget(this);
        acoes->insertOpenWithActionsTo(nullptr, menu, {QStringLiteral("org.kde.dolphin"), QStringLiteral("org.matsu.arquivos")});
        menu->addSeparator();
        if (naLixeira) {
            QList<QUrl> urls;
            for (const KFileItem &item : itens) {
                urls << item.url();
            }
            menu->addAction(t("Restaurar", "Restore"), this, [this, urls]() {
                KIO::Job *job = KIO::restoreFromTrash(urls);
                job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, this));
            });
        } else {
            QAction *recortar = menu->addAction(t("Recortar", "Cut"), this, [chamar]() {
                chamar("cut");
            });
            recortar->setShortcut(QKeySequence::Cut);
            recortar->setEnabled(propriedades.supportsMoving());
            QAction *copiar = menu->addAction(t("Copiar", "Copy"), this, [chamar]() {
                chamar("copy");
            });
            copiar->setShortcut(QKeySequence::Copy);
            if (umaPasta) {
                const QUrl u = itens.first().url();
                QAction *colarDentro = menu->addAction(t("Colar dentro da pasta", "Paste into folder"), this, [extensao, u]() {
                    if (extensao) {
                        QMetaObject::invokeMethod(extensao, "pasteTo", Q_ARG(QUrl, u));
                    }
                });
                colarDentro->setEnabled(podeColar);
            }
        }
        daParte("copy_location", t("Copiar caminho", "Copy path"));
        const QList<QAction *> edicao = grupos.value(QStringLiteral("editactions"));
        if (!edicao.isEmpty()) {
            menu->addSeparator();
            for (QAction *a : edicao) {
                menu->addAction(a);
            }
        }
        if (!naLixeira && propriedades.supportsWriting()) {
            daParte("duplicate", t("Duplicar aqui", "Duplicate here"));
        }
        // Os extras do sistema (compactar, extrair, enviar...).
        menu->addSeparator();
        acoes->addActionsTo(menu);
        menu->addSeparator();
        QAction *prop = menu->addAction(t("Propriedades", "Properties"), this, [this, itens]() {
            KPropertiesDialog::showDialog(itens, this, false);
        });
        prop->setShortcut(QKeySequence(Qt::ALT | Qt::Key_Return));
    }
    // Sem separadores sobrando no começo, no fim ou dois seguidos.
    QAction *anterior = nullptr;
    const auto todas = menu->actions();
    for (QAction *a : todas) {
        if (a->isSeparator() && (!anterior || anterior->isSeparator())) {
            menu->removeAction(a);
            continue;
        }
        anterior = a;
    }
    if (anterior && anterior->isSeparator()) {
        menu->removeAction(anterior);
    }
    menu->afastarAtalhos();
    menu->popup(onde);
}

void Janela::menuDaAba(int i, const QPoint &onde)
{
    if (i < 0 || i >= m_abas.size()) {
        return;
    }
    const int id = m_abas[i].id;
    const QUrl url = m_abas[i].url;
    auto *menu = new Menu(this);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    QAction *nova = menu->addAction(t("Nova aba", "New tab"), this, [this]() {
        novaAba(QUrl::fromLocalFile(QDir::homePath()));
    });
    nova->setShortcut(QKeySequence(Qt::CTRL | Qt::Key_T));
    menu->addAction(t("Duplicar aba", "Duplicate tab"), this, [this, url]() {
        novaAba(url);
    });
    menu->addAction(t("Abrir em nova janela", "Open in new window"), this, [this, id, url]() {
        abrirJanela({url});
        fecharAba(indiceDaAba(id));
    })->setEnabled(m_abas.size() > 1);
    menu->addSeparator();
    QAction *fechar = menu->addAction(t("Fechar aba", "Close tab"), this, [this, id]() {
        fecharAba(indiceDaAba(id));
    });
    fechar->setShortcut(QKeySequence(Qt::CTRL | Qt::Key_W));
    fechar->setEnabled(m_abas.size() > 1);
    menu->addAction(t("Fechar as outras abas", "Close other tabs"), this, [this, id]() {
        for (int k = m_abas.size() - 1; k >= 0; --k) {
            if (m_abas[k].id != id) {
                fecharAba(k);
            }
        }
    })->setEnabled(m_abas.size() > 1);
    menu->afastarAtalhos();
    menu->popup(onde);
}

// "Este computador": a pasta pessoal e os discos.
void Janela::menuDosDiscos(const QPoint &onde)
{
    auto *menu = new Menu(this);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    bool separou = false;
    for (int i = 0; i < m_lugares.size(); ++i) {
        const Lugar &l = m_lugares[i];
        if (l.tipo == Lugar::Pasta && l.icone != ICasa) {
            continue;
        }
        if (l.tipo == Lugar::Secao) {
            continue;
        }
        if (l.tipo == Lugar::Disco && !separou) {
            menu->addSeparator();
            separou = true;
        }
        menu->addAction(iconeDesenhado(l.icone), l.nome, this, [this, i]() {
            abrirLugar(i, false);
        });
    }
    menu->popup(onde);
}

void Janela::menuDoPedaco(const QUrl &url, const QPoint &onde)
{
    auto *menu = new Menu(this);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    menu->addAction(t("Abrir em nova aba", "Open in new tab"), this, [this, url]() {
        novaAba(url, false);
    });
    menu->addAction(t("Abrir em nova janela", "Open in new window"), this, [url]() {
        abrirJanela({url});
    });
    menu->addSeparator();
    menu->addAction(t("Copiar caminho", "Copy path"), this, [url]() {
        QApplication::clipboard()->setText(url.isLocalFile() ? url.toLocalFile() : url.toDisplayString());
    });
    menu->addAction(t("Propriedades", "Properties"), this, [this, url]() {
        KPropertiesDialog::showDialog(url, this, false);
    });
    menu->popup(onde);
}

void Janela::menuDoLugar(int i, const QPoint &onde)
{
    if (i < 0 || i >= m_lugares.size()) {
        return;
    }
    const Lugar l = m_lugares[i];
    auto *menu = new Menu(this);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    menu->addAction(t("Abrir", "Open"), this, [this, i]() {
        abrirLugar(i, false);
    });
    menu->addAction(t("Abrir em nova aba", "Open in new tab"), this, [this, i]() {
        abrirLugar(i, true);
    });
    if (!l.url.isEmpty()) {
        menu->addAction(t("Abrir em nova janela", "Open in new window"), this, [l]() {
            abrirJanela({l.url});
        });
    }
    if (l.url.scheme() == QLatin1String("trash")) {
        menu->addSeparator();
        const bool vazia = KConfig(QStringLiteral("trashrc"), KConfig::SimpleConfig).group(QStringLiteral("Status")).readEntry("Empty", true);
        menu->addAction(t("Esvaziar a lixeira", "Empty Trash"), this, [this]() {
            QMessageBox caixa(this);
            caixa.setIcon(QMessageBox::Question);
            caixa.setWindowTitle(t("Esvaziar a lixeira", "Empty Trash"));
            caixa.setText(t("Apagar de vez tudo o que está na lixeira? Não dá para desfazer.",
                            "Permanently delete everything in the Trash? This cannot be undone."));
            QPushButton *sim = caixa.addButton(t("Esvaziar", "Empty"), QMessageBox::AcceptRole);
            caixa.addButton(t("Cancelar", "Cancel"), QMessageBox::RejectRole);
            caixa.exec();
            if (caixa.clickedButton() == sim) {
                KIO::Job *job = KIO::emptyTrash();
                job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, this));
            }
        })->setEnabled(!vazia);
    }
    if (l.tipo == Lugar::Disco && !l.udi.isEmpty() && !l.url.isEmpty()) {
        menu->addSeparator();
        menu->addAction(l.removivel ? t("Tirar com segurança", "Safely remove") : t("Desmontar", "Unmount"), this, [this, i]() {
            ejetar(i);
        });
    }
    if (!l.url.isEmpty()) {
        menu->addSeparator();
        menu->addAction(t("Propriedades", "Properties"), this, [this, l]() {
            KPropertiesDialog::showDialog(l.url, this, false);
        });
    }
    menu->popup(onde);
}

// O "⋯" da barra.
void Janela::abrirMenu(const QPoint &onde)
{
    auto *menu = new Menu(this);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    auto daParte = [&](const char *nome, const QString &texto) {
        if (QAction *a = acao(nome)) {
            a->setText(texto);
            menu->addAction(a);
        }
    };
    menu->addAction(t("Nova janela", "New window"), this, [this]() {
        abrirJanela({urlAtual()});
    })->setShortcut(QKeySequence(Qt::CTRL | Qt::Key_N));
    menu->addAction(t("Nova aba", "New tab"), this, [this]() {
        novaAba(QUrl::fromLocalFile(QDir::homePath()));
    })->setShortcut(QKeySequence(Qt::CTRL | Qt::Key_T));
    daParte("create_dir", t("Nova pasta", "New folder"));
    menu->addSeparator();
    daParte("view_mode", t("Exibir", "View"));
    daParte("sort", t("Ordenar por", "Sort by"));
    daParte("show_hidden_files", t("Mostrar arquivos ocultos", "Show hidden files"));
    daParte("show_preview", t("Mostrar miniaturas", "Show previews"));
    menu->addSeparator();
    daParte("edit_select_all", t("Selecionar tudo", "Select all"));
    daParte("invert_selection", t("Inverter seleção", "Invert selection"));
    menu->addSeparator();
    daParte("open_terminal", t("Abrir terminal aqui", "Open terminal here"));
    menu->addAction(iconeDesenhado(ILixeira), t("Lixeira", "Trash"), this, [this]() {
        abrir(QUrl(QStringLiteral("trash:/")));
    });
    menu->addSeparator();
    menu->addAction(t("Propriedades da pasta", "Folder properties"), this, [this]() {
        KPropertiesDialog::showDialog(urlAtual(), this, false);
    });
    menu->afastarAtalhos();
    // O menu abre embaixo do botão, alinhado pela direita.
    menu->ensurePolished();
    menu->popup(onde - QPoint(menu->sizeHint().width(), 0));
}

// ---------------------------------------------------------------------------
// O lado: lugares e discos

void Janela::lugaresMudaram()
{
    m_relerLugares.start();
}

void Janela::atualizarLugares()
{
    const QString casa = QDir::homePath();
    QVector<Lugar> l;
    l << Lugar{Lugar::Secao, t("ACESSO RÁPIDO", "QUICK ACCESS")};
    l << Lugar{Lugar::Pasta, t("Pasta pessoal", "Home"), QUrl::fromLocalFile(casa), ICasa};
    for (const PastaConhecida &pc : pastasConhecidas) {
        const QString c = QStandardPaths::writableLocation(pc.onde);
        if (c.isEmpty() || caminhoReal(c) == caminhoReal(casa) || !QFileInfo(c).isDir()) {
            continue;
        }
        l << Lugar{Lugar::Pasta, t(pc.pt, pc.en), QUrl::fromLocalFile(c), pc.icone};
    }
    l << Lugar{Lugar::Pasta, t("Lixeira", "Trash"), QUrl(QStringLiteral("trash:/")), ILixeira};
    l << Lugar{Lugar::Secao, t("ESTE COMPUTADOR", "THIS PC")};

    // O disco do Matsu.
    Lugar raiz{Lugar::Disco, nomeDoDiscoDoSistema(), QUrl::fromLocalFile(QStringLiteral("/")), IDisco};
    const QStorageInfo infoCasa(casa);
    if (infoCasa.isValid() && infoCasa.bytesTotal() > 0) {
        raiz.dica = t("%1 livres de %2", "%1 free of %2")
                        .arg(tamanhoLegivel(KIO::convertSize(KIO::filesize_t(infoCasa.bytesAvailable()))),
                             tamanhoLegivel(KIO::convertSize(KIO::filesize_t(infoCasa.bytesTotal()))));
    }
    l << raiz;

    // Os outros discos e pendrives.
    const QString dispRaiz = caminhoReal(QString::fromLocal8Bit(infoCasa.device()));
    static const QStringList escondidos = {
        QStringLiteral("boot"), QStringLiteral("efi"), QStringLiteral("efi-system"), QStringLiteral("esp"), QStringLiteral("system"),
        QStringLiteral("msr"), QStringLiteral("recovery"), QStringLiteral("recuperação"), QStringLiteral("winre_drv"),
        QStringLiteral("system_drv"), QStringLiteral("system reserved"), QStringLiteral("reservado pelo sistema"),
    };
    m_dispositivos.clear();
    const auto dispositivos = Solid::Device::listFromType(Solid::DeviceInterface::StorageAccess);
    for (const Solid::Device &d : dispositivos) {
        auto *acesso = d.as<Solid::StorageAccess>();
        const auto *vol = d.as<Solid::StorageVolume>();
        if (!acesso || !vol || vol->isIgnored() || vol->usage() != Solid::StorageVolume::FileSystem) {
            continue;
        }
        const bool montado = acesso->isAccessible();
        const QString ponto = acesso->filePath();
        if (montado && pontoDoSistema(ponto)) {
            continue;
        }
        const auto *bloco = d.as<Solid::Block>();
        const QString disp = bloco ? caminhoReal(bloco->device()) : QString();
        if (!disp.isEmpty() && disp == dispRaiz) {
            continue;
        }
        const Solid::StorageDrive *drive = nullptr;
        for (Solid::Device p = d.parent(); p.isValid(); p = p.parent()) {
            if (p.is<Solid::StorageDrive>()) {
                drive = p.as<Solid::StorageDrive>();
                break;
            }
        }
        const bool removivel = drive && (drive->isRemovable() || drive->isHotpluggable());
        const QString rotulo = vol->label().trimmed();
        if (!montado && (escondidos.contains(rotulo.toLower())
                         || (vol->fsType() == QLatin1String("vfat") && vol->size() < 1100000000ULL && !removivel))) {
            continue;
        }
        QString nome = rotulo.isEmpty() ? t("Disco de %1", "%1 drive").arg(tamanhoLegivel(KIO::convertSize(vol->size()))) : rotulo;
        const QString tipo = removivel ? QStringLiteral("USB") : tipoDoDisco(disp);
        if (!tipo.isEmpty()) {
            nome += QStringLiteral(" (%1)").arg(tipo);
        }
        Lugar x{Lugar::Disco, nome, montado ? QUrl::fromLocalFile(ponto) : QUrl(), removivel ? IUsb : IDisco, d.udi(), removivel};
        if (montado) {
            const QStorageInfo info(ponto);
            x.dica = t("%1 livres de %2", "%1 free of %2")
                         .arg(tamanhoLegivel(KIO::convertSize(KIO::filesize_t(info.bytesAvailable()))),
                              tamanhoLegivel(KIO::convertSize(KIO::filesize_t(info.bytesTotal()))));
        } else {
            x.dica = t("%1 · clique para abrir", "%1 · click to open").arg(tamanhoLegivel(KIO::convertSize(vol->size())));
        }
        connect(acesso, &Solid::StorageAccess::accessibilityChanged, this, &Janela::lugaresMudaram, Qt::UniqueConnection);
        m_dispositivos << d;
        l << x;
    }
    m_lugares = l;
    atualizarTudo();
}

void Janela::abrirLugar(int i, bool emNovaAba)
{
    if (i < 0 || i >= m_lugares.size()) {
        return;
    }
    const Lugar &l = m_lugares[i];
    if (l.url.isEmpty() && !l.udi.isEmpty()) {
        // Disco ainda não montado: monta e abre quando ficar pronto.
        Solid::Device d(l.udi);
        auto *acesso = d.as<Solid::StorageAccess>();
        if (!acesso) {
            return;
        }
        const QString udi = l.udi;
        connect(
            acesso, &Solid::StorageAccess::setupDone, this,
            [this, udi, emNovaAba](Solid::ErrorType erro, const QVariant &info, const QString &qual) {
                if (qual != udi) {
                    return;
                }
                if (erro != Solid::NoError) {
                    QMessageBox::warning(this, t("Não deu para abrir o disco", "Could not open the drive"), info.toString());
                    return;
                }
                Solid::Device pronto(udi);
                if (auto *a = pronto.as<Solid::StorageAccess>()) {
                    const QUrl u = QUrl::fromLocalFile(a->filePath());
                    if (emNovaAba) {
                        novaAba(u);
                    } else {
                        abrir(u);
                    }
                }
            },
            Qt::SingleShotConnection);
        acesso->setup();
        return;
    }
    if (emNovaAba) {
        novaAba(l.url, false);
    } else {
        abrir(l.url);
    }
}

void Janela::ejetar(int i)
{
    if (i < 0 || i >= m_lugares.size() || m_lugares[i].udi.isEmpty()) {
        return;
    }
    const Lugar l = m_lugares[i];
    // Abas abertas dentro do disco vão para a pasta pessoal antes.
    for (const Aba &aba : std::as_const(m_abas)) {
        if (aba.url.isLocalFile() && l.url.isLocalFile() && dentroDe(caminhoReal(aba.url.toLocalFile()), caminhoReal(l.url.toLocalFile()))) {
            navegar(aba.id, QUrl::fromLocalFile(QDir::homePath()), true);
        }
    }
    Solid::Device d(l.udi);
    if (auto *acesso = d.as<Solid::StorageAccess>()) {
        connect(
            acesso, &Solid::StorageAccess::teardownDone, this,
            [this](Solid::ErrorType erro, const QVariant &info, const QString &) {
                if (erro != Solid::NoError && erro != Solid::UserCanceled) {
                    QMessageBox::warning(this, t("Não deu para tirar o disco", "Could not remove the drive"),
                                         info.toString().isEmpty() ? t("Algum app ainda está usando o disco.", "An app is still using the drive.")
                                                                   : info.toString());
                }
            },
            Qt::SingleShotConnection);
        acesso->teardown();
    }
}

// ---------------------------------------------------------------------------
// Janela: tema, desenho e bordas

void Janela::atualizarTema()
{
    if (!qEnvironmentVariableIsSet("MATSU_ARQUIVOS_TEMA")) {
        tema.escuro = QApplication::palette().color(QPalette::Window).lightnessF() < 0.5;
    }
    lerVidro();
    tema.desfoque = temDesfoque();
    for (const Aba &aba : std::as_const(m_abas)) {
        if (aba.parte) {
            prepararParte(aba.parte);
        }
    }
    m_vidro->aplicar();
    QToolTip::setPalette(paletaNeutra(QApplication::palette()));
    atualizarTudo();
    update();
}

void Janela::posicionar()
{
    const int topo = Medida::cabecalho + Medida::barra;
    m_cabecalho->setGeometry(0, 0, width(), Medida::cabecalho);
    m_barra->setGeometry(0, Medida::cabecalho, width(), Medida::barra);
    m_lateral->setGeometry(0, topo + 1, Medida::lateral, height() - topo - 1 - Medida::raio / 2);
    // Do lado direito sobra uma faixa do vidro para pegar e redimensionar.
    m_pilha->setGeometry(Medida::lateral + 1, topo + 1, width() - Medida::lateral - 1 - 4, height() - topo - 1 - Medida::rodape);
    m_rodape->setGeometry(Medida::lateral + 1, height() - Medida::rodape, width() - Medida::lateral - 2, Medida::rodape - 1);
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

void Janela::alternarCheia()
{
    if (isMaximized() || isFullScreen()) {
        showNormal();
    } else {
        showMaximized();
    }
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

    // A área da lista, um degrau acima do vidro, separada por linhas finas.
    p.save();
    p.setClipPath(forma);
    const int topo = Medida::cabecalho + Medida::barra;
    p.fillRect(QRectF(Medida::lateral + 1, topo + 1, width() - Medida::lateral - 1, height() - topo - 1), tema.miolo());
    p.fillRect(QRectF(0, topo, width(), 1), tema.linha());
    p.fillRect(QRectF(Medida::lateral, topo + 1, 1, height() - topo - 1), tema.linha());
    p.restore();

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
}

void Janela::showEvent(QShowEvent *)
{
    posicionar();
    m_vidro->aplicar();
}

void Janela::changeEvent(QEvent *e)
{
    if (e->type() == QEvent::ApplicationPaletteChange) {
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
    if (!isMaximized() && !isFullScreen()) {
        KConfigGroup grupo(KSharedConfig::openConfig(), QStringLiteral("Janela"));
        grupo.writeEntry("Largura", width());
        grupo.writeEntry("Altura", height());
        grupo.sync();
    }
    e->accept();
}

void Janela::mouseMoveEvent(QMouseEvent *e)
{
    Qt::Edges bordas;
    setCursor(bordaEm(e->position().toPoint(), bordas) ? cursorDaBorda(bordas) : Qt::ArrowCursor);
}

void Janela::mousePressEvent(QMouseEvent *e)
{
    if (e->button() == Qt::BackButton) {
        voltar();
        return;
    }
    if (e->button() == Qt::ForwardButton) {
        avancar();
        return;
    }
    pegarBorda(this, this, e);
}

// ---------------------------------------------------------------------------
// Os botões de voltar e avançar do mouse valem na janela toda (a lista de
// arquivos não repassa esses cliques).
class BotoesDoMouse : public QObject
{
public:
    using QObject::QObject;

protected:
    bool eventFilter(QObject *objeto, QEvent *evento) override
    {
        if (evento->type() == QEvent::MouseButtonPress && objeto->isWidgetType()) {
            const auto *m = static_cast<QMouseEvent *>(evento);
            if (m->button() == Qt::BackButton || m->button() == Qt::ForwardButton) {
                if (auto *janela = qobject_cast<Janela *>(static_cast<QWidget *>(objeto)->window())) {
                    if (m->button() == Qt::BackButton) {
                        janela->voltar();
                    } else {
                        janela->avancar();
                    }
                    return true;
                }
            }
        }
        return false;
    }
};

// ---------------------------------------------------------------------------
// Outros apps pedem "Mostrar na pasta" pelo serviço org.freedesktop.FileManager1
// (o navegador depois de baixar, as notificações...). Aqui ele abre os Arquivos.
static void ativar(QWidget *w, const QString &token)
{
    if (!token.isEmpty()) {
        KWindowSystem::setCurrentXdgActivationToken(token);
    }
    w->show();
    w->raise();
    w->activateWindow();
    if (w->windowHandle()) {
        KWindowSystem::activateWindow(w->windowHandle());
    }
}

static QList<QUrl> urlsDe(const QStringList &uris)
{
    QList<QUrl> urls;
    for (const QString &u : uris) {
        const QUrl url = QUrl::fromUserInput(u, QDir::currentPath(), QUrl::AssumeLocalFile);
        if (url.isValid()) {
            urls << url;
        }
    }
    return urls;
}

class Gerente : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.FileManager1")

public:
    using QObject::QObject;

public Q_SLOTS:
    void ShowFolders(const QStringList &uris, const QString &startUpId)
    {
        const QList<QUrl> urls = urlsDe(uris);
        if (!urls.isEmpty()) {
            ativar(abrirJanela(urls), startUpId);
        }
    }
    void ShowItems(const QStringList &uris, const QString &startUpId)
    {
        // Uma janela para cada pasta, com os itens dela já selecionados.
        QHash<QUrl, QList<QUrl>> porPasta;
        QList<QUrl> ordem;
        for (const QUrl &u : urlsDe(uris)) {
            const QUrl pasta = KIO::upUrl(u);
            if (!porPasta.contains(pasta)) {
                ordem << pasta;
            }
            porPasta[pasta] << u;
        }
        for (const QUrl &pasta : std::as_const(ordem)) {
            ativar(abrirJanela({pasta}, porPasta.value(pasta)), startUpId);
        }
    }
    void ShowItemProperties(const QStringList &uris, const QString &startUpId)
    {
        Q_UNUSED(startUpId)
        const QList<QUrl> urls = urlsDe(uris);
        if (!urls.isEmpty()) {
            KPropertiesDialog::showDialog(urls, nullptr, false);
        }
    }
};

static Janela *abrirJanela(const QList<QUrl> &urls, const QList<QUrl> &selecionar)
{
    auto *janela = new Janela(urls, selecionar);
    janela->setAttribute(Qt::WA_DeleteOnClose);
    janela->show();
    return janela;
}

// ---------------------------------------------------------------------------
// Só para as prévias e os testes: com a variável MATSU_ARQUIVOS_ROTEIRO, a
// janela segue um roteiro, um comando por linha:
//   ir ENDEREÇO        abre na aba atual       aba ENDEREÇO   abre uma aba nova
//   selecionar NOMES   seleciona itens da pasta (separados por "|")
//   buscar TEXTO       escreve na busca        editar         o caminho vira texto
//   modo details|icons|compact                 menu           abre o "⋯"
//   mouse X Y          põe o mouse em (X, Y)   clicar X Y [direito|duplo]
//   fechar-menu        esperar MS              sair
//   foto ARQUIVO       salva a janela por cima do papel de parede (MATSU_ARQUIVOS_PAPEL),
//                      com o desfoque e a sombra, como fica na tela
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
    const QImage imgPapel(qEnvironmentVariable("MATSU_ARQUIVOS_PAPEL"));
    {
        QPainter p(&fundo);
        if (!imgPapel.isNull()) {
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
    if (tema.desfoque) {
        QPainterPath forma;
        forma.addRoundedRect(QRectF(lugar), cheia ? 0 : Medida::raio, cheia ? 0 : Medida::raio);
        p.save();
        p.setClipPath(forma);
        p.drawImage(QRectF(QPointF(0, 0), QSizeF(tela)), desfocar(fundo, int(28 * escala)));
        p.restore();
    }
    p.drawPixmap(lugar.topLeft(), janela->grab());
    // Um menu aberto entra na foto também (com o submenu, se tiver).
    QList<QWidget *> menus;
    for (QWidget *w : QApplication::topLevelWidgets()) {
        if (qobject_cast<QMenu *>(w) && w->isVisible()) {
            menus << w;
        }
    }
    for (QWidget *popup : std::as_const(menus)) {
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

static void enviarMouse(Janela *janela, const QPoint &ponto, const QString &jeito)
{
    QWidget *alvo = janela->childAt(ponto);
    if (!alvo) {
        alvo = janela;
    }
    const QPointF local = alvo->mapFrom(janela, ponto);
    const QPointF global = alvo->mapToGlobal(local);
    QEnterEvent entra(local, local, global);
    QApplication::sendEvent(alvo, &entra);
    QMouseEvent move(QEvent::MouseMove, local, global, Qt::NoButton, Qt::NoButton, Qt::NoModifier);
    QApplication::sendEvent(alvo, &move);
    if (jeito == QLatin1String("passar")) {
        return;
    }
    const Qt::MouseButton botao = jeito == QLatin1String("direito") ? Qt::RightButton : Qt::LeftButton;
    QMouseEvent aperta(QEvent::MouseButtonPress, local, global, botao, botao, Qt::NoModifier);
    QApplication::sendEvent(alvo, &aperta);
    QMouseEvent solta(QEvent::MouseButtonRelease, local, global, botao, Qt::NoButton, Qt::NoModifier);
    QApplication::sendEvent(alvo, &solta);
    if (jeito == QLatin1String("duplo")) {
        QMouseEvent duplo(QEvent::MouseButtonDblClick, local, global, botao, botao, Qt::NoModifier);
        QApplication::sendEvent(alvo, &duplo);
        QMouseEvent solta2(QEvent::MouseButtonRelease, local, global, botao, Qt::NoButton, Qt::NoModifier);
        QApplication::sendEvent(alvo, &solta2);
    }
    if (botao == Qt::RightButton) {
        QContextMenuEvent menu(QContextMenuEvent::Mouse, local.toPoint(), global.toPoint());
        QApplication::sendEvent(alvo, &menu);
    }
}

static QUrl enderecoDoRoteiro(const QString &texto)
{
    if (texto.startsWith(QLatin1Char('~'))) {
        return QUrl::fromLocalFile(QDir::homePath() + texto.mid(1));
    }
    return QUrl::fromUserInput(texto, QDir::homePath(), QUrl::AssumeLocalFile);
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
        if (comando == QLatin1String("ir")) {
            janela->abrir(enderecoDoRoteiro(resto));
            espera = 700;
        } else if (comando == QLatin1String("aba")) {
            janela->novaAba(enderecoDoRoteiro(resto));
            espera = 700;
        } else if (comando == QLatin1String("selecionar")) {
            QList<QUrl> urls;
            const QUrl pasta = janela->urlAtual();
            for (const QString &nome : resto.split(QLatin1Char('|'), Qt::SkipEmptyParts)) {
                QUrl u = pasta;
                u.setPath(pasta.path() + (pasta.path().endsWith(QLatin1Char('/')) ? QString() : QStringLiteral("/")) + nome.trimmed());
                urls << u;
            }
            janela->selecionar(urls);
            espera = 700;
        } else if (comando == QLatin1String("buscar")) {
            janela->barra()->busca()->setText(resto);
            janela->filtrar(resto);
        } else if (comando == QLatin1String("editar")) {
            janela->barra()->editarCaminho();
        } else if (comando == QLatin1String("modo")) {
            janela->mudarModo(resto);
            espera = 500;
        } else if (comando == QLatin1String("mouse")) {
            enviarMouse(janela, QPoint(resto.section(QLatin1Char(' '), 0, 0).toInt(), resto.section(QLatin1Char(' '), 1, 1).toInt()),
                        QStringLiteral("passar"));
        } else if (comando == QLatin1String("clicar")) {
            enviarMouse(janela, QPoint(resto.section(QLatin1Char(' '), 0, 0).toInt(), resto.section(QLatin1Char(' '), 1, 1).toInt()),
                        resto.section(QLatin1Char(' '), 2, 2));
            espera = 400;
        } else if (comando == QLatin1String("menu")) {
            QTimer::singleShot(0, janela, [janela]() {
                janela->abrirMenu(janela->mapToGlobal(QPoint(janela->width() - 10, Medida::cabecalho + Medida::barra - 4)));
            });
            espera = 400;
        } else if (comando == QLatin1String("fechar-menu")) {
            for (QWidget *w : QApplication::topLevelWidgets()) {
                if (qobject_cast<QMenu *>(w) && w->isVisible()) {
                    w->close();
                }
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
// O jeito da lista na primeira vez: em lista, com nome, data, tipo e tamanho
// (como na imagem escolhida). Depois vale o que a pessoa mudar.
static void jeitoDaPrimeiraVez()
{
    const QString pasta = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/view_properties/global");
    const QString arquivo = pasta + QStringLiteral("/.directory");
    if (QFile::exists(arquivo)) {
        return;
    }
    QDir().mkpath(pasta);
    const QString doDolphin = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/dolphin/view_properties/global/.directory");
    if (QFile::exists(doDolphin) && QFile::copy(doDolphin, arquivo)) {
        return;
    }
    QFile f(arquivo);
    if (f.open(QIODevice::WriteOnly)) {
        f.write("[Dolphin]\nVersion=4\nViewMode=1\nVisibleRoles=Details_text,Details_modificationtime,Details_type,Details_size,CustomizedDetails\n"
                "SortRole=text\nSortFoldersFirst=true\nPreviewsShown=true\n");
    }
}

// ---------------------------------------------------------------------------
int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("matsu-arquivos"));
    app.setApplicationDisplayName(t("Arquivos", "Files"));
    app.setDesktopFileName(QStringLiteral("org.matsu.arquivos"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("matsu-arquivos"), QIcon::fromTheme(QStringLiteral("system-file-manager"))));

    // Argumentos (os mesmos nomes do Dolphin, para quem chama o gerenciador de
    // arquivos padrão).
    QList<QUrl> urls;
    QList<QUrl> selecionar;
    bool daemon = false;
    const QStringList args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        const QString &a = args[i];
        if (a == QLatin1String("--daemon")) {
            daemon = true;
        } else if (a == QLatin1String("--select") || a == QLatin1String("--selecionar")) {
            for (++i; i < args.size() && !args[i].startsWith(QLatin1String("--")); ++i) {
                selecionar << QUrl::fromUserInput(args[i], QDir::currentPath(), QUrl::AssumeLocalFile);
            }
            --i;
        } else if (a == QLatin1String("-h") || a == QLatin1String("--help") || a == QLatin1String("--ajuda")) {
            std::printf("%s", qPrintable(t("Uso: matsu-arquivos [PASTA ou ENDEREÇO...] [--select ARQUIVO...] [--daemon]\n",
                                           "Usage: matsu-arquivos [FOLDER or URL...] [--select FILE...] [--daemon]\n")));
            return 0;
        } else if (a.startsWith(QLatin1String("-"))) {
            continue; // --new-window, --split...: aqui toda abertura já é uma janela nova
        } else {
            urls << QUrl::fromUserInput(a, QDir::currentPath(), QUrl::AssumeLocalFile);
        }
    }
    // Com --select, abre a pasta de cada arquivo.
    if (!selecionar.isEmpty() && urls.isEmpty()) {
        urls << KIO::upUrl(selecionar.first());
    }
    // Abrir um arquivo (e não uma pasta) pelo comando: abre a pasta dele com ele selecionado.
    if (urls.size() == 1 && urls.first().isLocalFile() && QFileInfo(urls.first().toLocalFile()).isFile()) {
        selecionar << urls.first();
        urls[0] = KIO::upUrl(urls.first());
    }

    // Sem a peça do Dolphin, abre o próprio Dolphin com os mesmos argumentos.
    if (!KPluginMetaData(QStringLiteral("kf6/parts/dolphinpart")).isValid()) {
        std::fprintf(stderr, "matsu-arquivos: peça do Dolphin não encontrada; abrindo o Dolphin\n");
        return QProcess::startDetached(QStringLiteral("dolphin"), args.mid(1)) ? 0 : 1;
    }

    jeitoDaPrimeiraVez();
    app.installEventFilter(new CoresNeutras(&app));
    app.installEventFilter(new BotoesDoMouse(&app));

    // O serviço "Mostrar na pasta". Com --daemon, o app fica esperando pedidos
    // sem janela; sem ele, atende enquanto tiver janela aberta.
    auto *gerente = new Gerente(&app);
    QDBusConnection sessao = QDBusConnection::sessionBus();
    if (sessao.isConnected() && sessao.registerObject(QStringLiteral("/org/freedesktop/FileManager1"), gerente, QDBusConnection::ExportAllSlots)) {
        if (!sessao.registerService(QStringLiteral("org.freedesktop.FileManager1")) && daemon) {
            std::fprintf(stderr, "matsu-arquivos: outro gerenciador de arquivos já atende org.freedesktop.FileManager1\n");
            return 0;
        }
    }
    if (daemon) {
        app.setQuitOnLastWindowClosed(false);
        // Sem janela por 10 minutos: sai (o sistema abre de novo no próximo pedido).
        auto *ocioso = new QTimer(&app);
        ocioso->setInterval(10 * 60 * 1000);
        QObject::connect(ocioso, &QTimer::timeout, &app, []() {
            for (QWidget *w : QApplication::topLevelWidgets()) {
                if (qobject_cast<Janela *>(w) && w->isVisible()) {
                    return;
                }
            }
            QCoreApplication::quit();
        });
        ocioso->start();
        return app.exec();
    }

    Janela *janela = abrirJanela(urls, selecionar);
    if (janela->abas().isEmpty()) {
        delete janela;
        return QProcess::startDetached(QStringLiteral("dolphin"), args.mid(1)) ? 0 : 1;
    }
    if (qEnvironmentVariableIsSet("MATSU_ARQUIVOS_ROTEIRO")) {
        QFile roteiro(qEnvironmentVariable("MATSU_ARQUIVOS_ROTEIRO"));
        if (roteiro.open(QIODevice::ReadOnly)) {
            const QStringList linhas = QString::fromUtf8(roteiro.readAll()).split(QLatin1Char('\n'));
            janela->activateWindow();
            QTimer::singleShot(1200, janela, [janela, linhas]() {
                seguirRoteiro(janela, linhas);
            });
        }
    }
    return app.exec();
}

#include "main.moc"
