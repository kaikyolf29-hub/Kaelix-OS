// Kaelix OS — abre um app do Kaelix feito em QML numa janela própria.
//
// Uso: kaelix-janela <id do app> <arquivo .qml> [argumentos para o app]
//
// O id é o nome do arquivo .desktop do app, sem o ".desktop". Ele vira a
// identidade da janela (o "app_id" no Wayland): é por ela que a barra, o
// Alt+Tab e o balão do mouse mostram o ícone e o nome certos. Com o
// plasmawindowed do KDE todos os apps tinham a mesma identidade, e a barra
// mostrava um no lugar do outro.
//
// Se o app já estiver aberto, a janela que existe vem para a frente (como no
// Windows, quando se abre o Gerenciador de tarefas de novo).
//
// O QML recebe o objeto "kaelix" para rodar os ajudantes do app:
//   kaelix.iniciar(chave, [programa, args...])  fica rodando; cada linha da
//                                               saída chega no sinal linha(chave, texto)
//   kaelix.rodar(chave, [programa, args...])    roda uma vez; o fim chega no sinal
//                                               pronto(chave, saida, codigo)
//   kaelix.soltar([programa, args...])          abre um programa solto, que continua
//                                               aberto mesmo se o app fechar
//   kaelix.argumentos                           os argumentos extras da linha de comando
//   kaelix.ativarVidro(janela, raio)            janela de vidro: desfoca o que está atrás
//                                               (efeito Desfoque do KWin), com cantos
//                                               redondos e sombra; devolve se o desfoque existe
//   sinal pedido(argumentos)                    o app foi aberto de novo com outros argumentos
//   sinal vidroMudou(ligado)                    o desfoque foi ligado ou desligado no KWin
#include <QApplication>
#include <QDir>
#include <QHash>
#include <QIcon>
#include <QImage>
#include <QLocalServer>
#include <QLocalSocket>
#include <QPainter>
#include <QPainterPath>
#include <QPlatformSurfaceEvent>
#include <QPointer>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QRegion>
#include <QTimer>
#include <QUrl>

#include <cstdio>
#include <vector>

#ifdef TEM_KWINDOWSYSTEM
#include <KWindowEffects>
#include <KWindowShadow>
#include <KWindowSystem>
#endif

// Desfoque simples em caixa (três passadas dão quase um desfoque gaussiano),
// para a sombra da janela. "passo" é a distância entre um ponto e o próximo.
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

// A imagem da sombra: um retângulo redondo desfocado, um pouco para baixo, com o
// lugar da janela recortado (a janela é de vidro, a sombra não pode escurecer ela).
// Tem "borda" pontos de sombra em volta e "raio" de canto.
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

// Janela de vidro: pede ao KWin para desfocar o que está atrás dela (só dentro
// dos cantos redondos) e põe a sombra em volta. Em tela cheia, sem cantos e sem
// sombra. Refaz tudo quando a janela muda de tamanho ou é criada de novo.
class Vidro : public QObject
{
    Q_OBJECT

public:
    Vidro(QWindow *janela, qreal raio)
        : QObject(janela)
        , m_janela(janela)
        , m_raio(raio)
    {
        janela->installEventFilter(this);
        connect(janela, &QWindow::windowStateChanged, this, &Vidro::aplicar);
#ifdef TEM_KWINDOWSYSTEM
        const int borda = 34;
        const int r = qRound(raio);
        const QImage img = imagemDaSombra(borda, r);
        const int lado = img.width();
        const int canto = borda + r;
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
        m_sombra->setWindow(janela);
#endif
        aplicar();
    }

    void aplicar()
    {
        if (!m_janela || !m_janela->handle()) {
            return;
        }
        const bool cheia = m_janela->windowStates() & (Qt::WindowMaximized | Qt::WindowFullScreen);
        const qreal r = cheia ? 0 : m_raio;
        QPainterPath forma;
        forma.addRoundedRect(QRectF(QPointF(0, 0), QSizeF(m_janela->size())), r, r);
        const QRegion regiao(forma.toFillPolygon().toPolygon());
#ifdef TEM_KWINDOWSYSTEM
        KWindowEffects::enableBlurBehind(m_janela, true, regiao);
        if (cheia) {
            if (m_sombra->isCreated()) {
                m_sombra->destroy();
            }
        } else if (!m_sombra->isCreated()) {
            m_sombra->create();
        }
#else
        Q_UNUSED(regiao)
#endif
    }

protected:
    bool eventFilter(QObject *objeto, QEvent *evento) override
    {
        if (objeto == m_janela) {
            if (evento->type() == QEvent::Resize) {
                aplicar();
            } else if (evento->type() == QEvent::PlatformSurface) {
                const auto tipo = static_cast<QPlatformSurfaceEvent *>(evento)->surfaceEventType();
                if (tipo == QPlatformSurfaceEvent::SurfaceCreated) {
                    QTimer::singleShot(0, this, &Vidro::aplicar);
                }
#ifdef TEM_KWINDOWSYSTEM
                else if (tipo == QPlatformSurfaceEvent::SurfaceAboutToBeDestroyed && m_sombra->isCreated()) {
                    m_sombra->destroy();
                }
#endif
            }
        }
        return false;
    }

private:
    QPointer<QWindow> m_janela;
    qreal m_raio;
#ifdef TEM_KWINDOWSYSTEM
    KWindowShadow *m_sombra = nullptr;
#endif
};

static bool temDesfoque()
{
#ifdef TEM_KWINDOWSYSTEM
    return KWindowEffects::isEffectAvailable(KWindowEffects::BlurBehind);
#else
    return false;
#endif
}

class Kaelix : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList argumentos READ argumentos CONSTANT)
    Q_PROPERTY(QString appId READ appId CONSTANT)

public:
    Kaelix(const QString &appId, const QStringList &argumentos, QObject *pai = nullptr)
        : QObject(pai)
        , m_appId(appId)
        , m_argumentos(argumentos)
    {
    }

    ~Kaelix() override
    {
        for (QProcess *p : std::as_const(m_vigias)) {
            p->disconnect(this);
            p->terminate();
            if (!p->waitForFinished(500)) {
                p->kill();
                p->waitForFinished(500);
            }
        }
    }

    QStringList argumentos() const
    {
        return m_argumentos;
    }

    // Liga o vidro na janela. Devolve se o KWin vai desfocar o fundo; se não, o
    // app deve deixar a janela opaca (vidro sem desfoque fica difícil de ler).
    Q_INVOKABLE bool ativarVidro(QObject *objeto, qreal raio)
    {
        auto *janela = qobject_cast<QWindow *>(objeto);
        if (!janela) {
            return false;
        }
        if (!janela->findChild<Vidro *>(QString(), Qt::FindDirectChildrenOnly)) {
            new Vidro(janela, raio);
        }
        if (!m_olhaDesfoque) {
            // O desfoque pode ser ligado e desligado nos efeitos do KWin com o app aberto.
            m_desfoque = temDesfoque();
            m_olhaDesfoque = new QTimer(this);
            m_olhaDesfoque->setInterval(3000);
            connect(m_olhaDesfoque, &QTimer::timeout, this, [this]() {
                const bool agora = temDesfoque();
                if (agora != m_desfoque) {
                    m_desfoque = agora;
                    Q_EMIT vidroMudou(agora);
                }
            });
            m_olhaDesfoque->start();
        }
        return m_desfoque;
    }
    QString appId() const
    {
        return m_appId;
    }

    Q_INVOKABLE void iniciar(const QString &chave, const QStringList &comando)
    {
        if (comando.isEmpty() || m_vigias.contains(chave)) {
            return;
        }
        auto *p = new QProcess(this);
        p->setProcessChannelMode(QProcess::ForwardedErrorChannel);
        m_vigias.insert(chave, p);
        connect(p, &QProcess::readyReadStandardOutput, this, [this, p, chave]() {
            while (p->canReadLine()) {
                const QString texto = QString::fromUtf8(p->readLine()).trimmed();
                if (!texto.isEmpty()) {
                    Q_EMIT linha(chave, texto);
                }
            }
        });
        connect(p, &QProcess::finished, this, [this, p, chave](int codigo) {
            m_vigias.remove(chave);
            p->deleteLater();
            Q_EMIT parou(chave, codigo);
        });
        p->start(comando.first(), comando.mid(1));
    }

    Q_INVOKABLE void parar(const QString &chave)
    {
        if (QProcess *p = m_vigias.value(chave)) {
            p->terminate();
        }
    }

    Q_INVOKABLE void rodar(const QString &chave, const QStringList &comando)
    {
        if (comando.isEmpty()) {
            return;
        }
        auto *p = new QProcess(this);
        p->setProcessChannelMode(QProcess::ForwardedErrorChannel);
        connect(p, &QProcess::finished, this, [this, p, chave](int codigo) {
            Q_EMIT pronto(chave, QString::fromUtf8(p->readAllStandardOutput()), codigo);
            p->deleteLater();
        });
        connect(p, &QProcess::errorOccurred, this, [this, p, chave](QProcess::ProcessError erro) {
            if (erro == QProcess::FailedToStart) {
                Q_EMIT pronto(chave, QString(), -1);
                p->deleteLater();
            }
        });
        p->start(comando.first(), comando.mid(1));
    }

    Q_INVOKABLE bool soltar(const QStringList &comando)
    {
        return !comando.isEmpty() && QProcess::startDetached(comando.first(), comando.mid(1));
    }

Q_SIGNALS:
    void linha(const QString &chave, const QString &texto);
    void parou(const QString &chave, int codigo);
    void pronto(const QString &chave, const QString &saida, int codigo);
    void pedido(const QStringList &argumentos);
    void vidroMudou(bool ligado);

private:
    QString m_appId;
    QStringList m_argumentos;
    QHash<QString, QProcess *> m_vigias;
    QTimer *m_olhaDesfoque = nullptr;
    bool m_desfoque = false;
};

// Traz a janela para a frente. No Wayland só dá com a "ficha de ativação"
// que o lançador passou para a segunda cópia do app.
static void trazer(QQuickWindow *janela, const QByteArray &ficha)
{
    if (!janela) {
        return;
    }
    if (janela->windowStates() & Qt::WindowMinimized) {
        janela->setWindowStates(janela->windowStates() & ~Qt::WindowMinimized);
    }
    janela->show();
    janela->raise();
#ifdef TEM_KWINDOWSYSTEM
    if (!ficha.isEmpty()) {
        KWindowSystem::setCurrentXdgActivationToken(QString::fromUtf8(ficha));
    }
    KWindowSystem::activateWindow(janela);
#else
    Q_UNUSED(ficha)
    janela->requestActivate();
#endif
}

int main(int argc, char *argv[])
{
    if (argc < 3) {
        std::fprintf(stderr, "uso: kaelix-janela <id do app> <arquivo .qml> [argumentos]\n");
        return 2;
    }

    QApplication app(argc, argv);
    const QString id = QString::fromLocal8Bit(argv[1]);
    const QString arquivo = QString::fromLocal8Bit(argv[2]);
    QStringList extras;
    for (int i = 3; i < argc; ++i) {
        extras << QString::fromLocal8Bit(argv[i]);
    }

    app.setDesktopFileName(id);
    app.setApplicationName(id);
    QApplication::setWindowIcon(QIcon::fromTheme(id));

    // Já está aberto? Manda a ficha de ativação e os argumentos para ele e sai.
    const QString pasta = qEnvironmentVariable("XDG_RUNTIME_DIR", QDir::tempPath());
    const QString canal = pasta + QStringLiteral("/kaelix-janela-") + id;
    {
        QLocalSocket outro;
        outro.connectToServer(canal);
        if (outro.waitForConnected(400)) {
            QByteArray mensagem = qgetenv("XDG_ACTIVATION_TOKEN") + '\n';
            for (const QString &a : std::as_const(extras)) {
                mensagem += a.toUtf8().replace('\n', ' ') + '\n';
            }
            outro.write(mensagem);
            outro.waitForBytesWritten(400);
            outro.disconnectFromServer();
            return 0;
        }
    }
    QLocalServer::removeServer(canal);
    QLocalServer servidor;
    servidor.setSocketOptions(QLocalServer::UserAccessOption);
    servidor.listen(canal);

    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }
    // Janelas com transparência (o vidro dos apps do Kaelix).
    QQuickWindow::setDefaultAlphaBuffer(true);

    Kaelix kaelix(id, extras);
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("kaelix"), &kaelix);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() {
            QCoreApplication::exit(1);
        },
        Qt::QueuedConnection);
    engine.load(QUrl::fromLocalFile(arquivo));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }
    QPointer<QQuickWindow> janela = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());

    QObject::connect(&servidor, &QLocalServer::newConnection, &app, [&servidor, &kaelix, janela]() {
        while (QLocalSocket *c = servidor.nextPendingConnection()) {
            QObject::connect(c, &QLocalSocket::disconnected, c, [c, &kaelix, janela]() {
                const QList<QByteArray> linhas = c->readAll().split('\n');
                const QByteArray ficha = linhas.value(0).trimmed();
                QStringList args;
                for (int i = 1; i < linhas.size(); ++i) {
                    if (!linhas.at(i).isEmpty()) {
                        args << QString::fromUtf8(linhas.at(i));
                    }
                }
                trazer(janela, ficha);
                if (!args.isEmpty()) {
                    Q_EMIT kaelix.pedido(args);
                }
                c->deleteLater();
            });
        }
    });

    const int codigo = app.exec();
    servidor.close();
    return codigo;
}

#include "main.moc"
