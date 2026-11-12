// Uma foto no visualizador: ajustada à janela, com zoom (roda do mouse no ponto
// do mouse, pinça do touchpad, duplo clique, botões e teclado), arrastar para
// mover quando está ampliada e o giro (só na exibição) animado.
// Carrega no tamanho da tela; ao ampliar, busca a foto inteira por cima, sem piscar.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: quadro

    property var foto: ({})
    property bool atual: false
    // A miniatura da grade (já no cache), para mostrar na hora enquanto a grande carrega.
    property var provisoria: null

    signal tocado()
    signal passarPara(int lado)

    readonly property string caminho: foto.caminho || ""
    readonly property url fonte: janela.arquivo(caminho)
    readonly property bool vetor: foto.tipo === "svg" || foto.tipo === "svgz"
    readonly property bool animada: foto.tipo === "gif" || foto.tipo === "webp"
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property int giro: janela.giroDe(caminho)
    readonly property bool deLado: giro === 90 || giro === 270
    // Tamanho natural (de pé); sem ele no cabeçalho, vem da própria imagem carregada.
    // (o tamanho lido da imagem fica guardado, para não amarrar o desenho nele mesmo)
    property real lidoL: 0
    property real lidoA: 0
    readonly property real natL: foto.largura > 0 ? foto.largura : lidoL
    readonly property real natA: foto.altura > 0 ? foto.altura : lidoA
    readonly property bool conhecido: natL > 0 && natA > 0
    readonly property real visL: deLado ? natA : natL
    readonly property real visA: deLado ? natL : natA
    readonly property real folga: Math.round(janela.gu * 0.5)
    // A escala que cabe na janela (foto pequena fica no tamanho dela; desenho vetorial cresce).
    readonly property real ajuste: conhecido ? Math.min(vetor ? 100 : 1, (width - 2 * folga) / visL, (height - 2 * folga) / visA) : 1
    readonly property real maximo: Math.max(ajuste * 10, 4)
    property real escala: ajuste
    property bool ajustado: true
    property real px: 0
    property real py: 0
    property bool animar: false
    readonly property bool zoomado: !ajustado && escala > ajuste * 1.01
    readonly property bool pronta: base.status === Image.Ready || (animacao.status === AnimatedImage.Ready)
    readonly property bool quebrada: base.status === Image.Error && (!quadro.animada || animacao.status === AnimatedImage.Error)
    readonly property int porcento: Math.round(escala * 100)

    // O tamanho pedido da foto só cresce (mudar a janela não faz recarregar à toa).
    // Sem o tamanho natural na hora de abrir, carrega a foto inteira.
    property int pedido: 0
    property bool inteira: false
    function atualizarPedido() {
        if (width <= 0 || height <= 0)
            return;
        if (!conhecido && pedido === 0) {
            inteira = true;
            return;
        }
        if (inteira)
            return;
        var lado = Math.ceil(Math.max(visL, visA) * ajuste * dpr / 256) * 256;
        if (lado > pedido)
            pedido = lado;
    }
    onWidthChanged: atualizarPedido()
    onHeightChanged: atualizarPedido()
    Component.onCompleted: atualizarPedido()

    onAjusteChanged: {
        if (ajustado) {
            escala = ajuste;
            px = 0;
            py = 0;
        } else {
            limitar();
        }
    }
    onGiroChanged: {
        girando.restart();
        animar = true;
        px = 0;
        py = 0;
        if (ajustado)
            escala = ajuste;
        limitar();
    }
    onAtualChanged: if (!atual) ajustar(false)

    function limitar() {
        var mx = Math.max(0, (visL * escala - width) / 2);
        var my = Math.max(0, (visA * escala - height) / 2);
        px = Math.max(-mx, Math.min(mx, px));
        py = Math.max(-my, Math.min(my, py));
    }
    // Zoom em volta de um ponto (mx, my: distância do centro do quadro).
    function zoomEm(nova, mx, my, comAnimacao) {
        nova = Math.max(ajuste, Math.min(maximo, nova));
        animar = !!comAnimacao;
        var f = nova / escala;
        var npx = mx - (mx - px) * f;
        var npy = my - (my - py) * f;
        ajustado = nova <= ajuste * 1.001;
        escala = nova;
        px = ajustado ? 0 : npx;
        py = ajustado ? 0 : npy;
        limitar();
        if (comAnimacao)
            fimAnimacao.restart();
    }
    function ampliar(fator) {
        zoomEm(escala * fator, 0, 0, true);
    }
    function ajustar(comAnimacao) {
        animar = comAnimacao !== false;
        ajustado = true;
        escala = ajuste;
        px = 0;
        py = 0;
        if (animar)
            fimAnimacao.restart();
    }
    function tamanhoReal() {
        zoomEm(1, 0, 0, true);
    }
    Timer {
        id: fimAnimacao
        interval: 260
        onTriggered: quadro.animar = false
    }
    Timer {
        id: girando
        interval: 320
        onTriggered: quadro.animar = false
    }

    Behavior on escala {
        enabled: quadro.animar
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    Behavior on px {
        enabled: quadro.animar
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    Behavior on py {
        enabled: quadro.animar
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // A foto em si: do tamanho natural, escalada e girada em volta do centro.
    Item {
        id: conteudo
        width: quadro.conhecido ? quadro.natL : Math.max(1, quadro.width - 2 * quadro.folga)
        height: quadro.conhecido ? quadro.natA : Math.max(1, quadro.height - 2 * quadro.folga)
        x: Math.round(quadro.width / 2 - width / 2 + quadro.px)
        y: Math.round(quadro.height / 2 - height / 2 + quadro.py)
        scale: quadro.conhecido ? quadro.escala : 1
        rotation: quadro.giro
        Behavior on rotation {
            RotationAnimation {
                direction: RotationAnimation.Shortest
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        // A miniatura da grade, na hora (borrada por um instante, até a grande chegar).
        Image {
            anchors.fill: parent
            visible: quadro.provisoria !== null && !quadro.pronta
            source: quadro.provisoria ? quadro.provisoria.fonte : ""
            sourceSize: quadro.provisoria ? Qt.size(quadro.provisoria.largura, quadro.provisoria.altura) : undefined
            fillMode: Image.PreserveAspectCrop
            autoTransform: true
            asynchronous: true
            smooth: true
        }
        Image {
            id: base
            anchors.fill: parent
            visible: !quadro.animada || animacao.status !== AnimatedImage.Ready
            source: quadro.caminho !== "" && (quadro.pedido > 0 || quadro.inteira) ? quadro.fonte : ""
            sourceSize: quadro.inteira ? undefined : Qt.size(quadro.pedido, quadro.pedido)
            fillMode: quadro.conhecido ? Image.Stretch : Image.PreserveAspectFit
            autoTransform: true
            asynchronous: true
            smooth: true
            mipmap: true
            opacity: status === Image.Ready ? 1 : 0
            onStatusChanged: {
                if (status === Image.Ready && quadro.inteira && quadro.lidoL === 0) {
                    quadro.lidoL = implicitWidth;
                    quadro.lidoA = implicitHeight;
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
        }
        // GIF e WebP animados: tocam no visualizador (a da vez).
        AnimatedImage {
            id: animacao
            anchors.fill: parent
            visible: status === AnimatedImage.Ready
            source: quadro.animada && quadro.caminho !== "" ? quadro.fonte : ""
            playing: quadro.atual && frameCount > 1
            fillMode: Image.Stretch
            asynchronous: true
            smooth: true
            cache: false
        }
        // Ampliada: a foto inteira por cima, quando chegar.
        Image {
            id: detalhe
            readonly property bool precisa: quadro.atual && quadro.conhecido && !quadro.inteira && !quadro.animada
                                            && quadro.escala > quadro.ajuste * 1.12 && quadro.pedido < Math.max(quadro.natL, quadro.natA) * (quadro.vetor ? 8 : 1)
            property bool pedida: false
            onPrecisaChanged: if (precisa) pedida = true
            anchors.fill: parent
            visible: status === Image.Ready && pedida
            source: pedida && quadro.atual ? quadro.fonte : ""
            sourceSize: {
                var lado = quadro.vetor ? Math.min(8192, Math.ceil(Math.max(quadro.natL, quadro.natA) * quadro.escala * quadro.dpr))
                                        : Math.min(8192, Math.max(quadro.natL, quadro.natA));
                return Qt.size(lado, lado);
            }
            fillMode: Image.Stretch
            autoTransform: true
            asynchronous: true
            smooth: true
            mipmap: true
        }
    }

    // Carregando (só aparece se demorar e não houver a miniatura).
    Girando {
        anchors.centerIn: parent
        width: Math.round(janela.gu * 2)
        cor: "#ffffff"
        visible: !quadro.pronta && !quadro.quebrada && quadro.provisoria === null && demora.running === false && quadro.caminho !== ""
        Timer {
            id: demora
            interval: 350
            running: !quadro.pronta
        }
    }

    // Não deu para abrir.
    Column {
        anchors.centerIn: parent
        spacing: Math.round(janela.gu * 0.5)
        visible: quadro.quebrada
        width: Math.min(parent.width - janela.gu * 2, janela.gu * 20)
        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(janela.gu * 3)
            height: width
            source: String(Qt.resolvedUrl("icones/foto-quebrada.svg"))
            isMask: true
            color: "#ffffff"
            opacity: 0.6
        }
        QQC2.Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#ffffff"
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
            text: janela.t("Não deu para abrir esta imagem", "Couldn't open this image")
        }
        QQC2.Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#ffffff"
            opacity: 0.6
            text: janela.t("O arquivo pode estar estragado ou num formato que o sistema não lê (" + janela.nomeTipo(quadro.foto.tipo) + ").",
                           "The file may be damaged or in a format the system can't read (" + janela.nomeTipo(quadro.foto.tipo) + ").")
        }
    }

    // ----- mouse e touchpad -----
    WheelHandler {
        id: roda
        target: null
        acceptedModifiers: Qt.KeyboardModifierMask
        property real lateral: 0
        onWheel: (e) => {
            var dx = e.angleDelta.x, dy = e.angleDelta.y;
            // Dois dedos para o lado no touchpad (sem zoom): passa a foto.
            if (Math.abs(dx) > Math.abs(dy) && !quadro.zoomado) {
                lateral += dx;
                if (Math.abs(lateral) >= 240) {
                    quadro.passarPara(lateral > 0 ? -1 : 1);
                    lateral = 0;
                }
                return;
            }
            lateral = 0;
            if (dy === 0)
                return;
            var p = e.point.position;
            quadro.zoomEm(quadro.escala * Math.pow(1.0018, dy), p.x - quadro.width / 2, p.y - quadro.height / 2, Math.abs(dy) >= 120);
        }
    }
    PinchHandler {
        id: pinca
        target: null
        property real inicio: 1
        onActiveChanged: if (active) inicio = quadro.escala
        onActiveScaleChanged: {
            if (!active)
                return;
            var c = centroid.position;
            quadro.zoomEm(inicio * activeScale, c.x - quadro.width / 2, c.y - quadro.height / 2, false);
        }
    }
    DragHandler {
        id: arrasto
        target: null
        enabled: quadro.zoomado
        cursorShape: Qt.ClosedHandCursor
        property real x0: 0
        property real y0: 0
        onActiveChanged: {
            if (active) {
                x0 = quadro.px;
                y0 = quadro.py;
            }
        }
        onTranslationChanged: {
            if (!active)
                return;
            quadro.animar = false;
            quadro.px = x0 + translation.x;
            quadro.py = y0 + translation.y;
            quadro.limitar();
        }
    }
    HoverHandler {
        cursorShape: quadro.zoomado ? Qt.OpenHandCursor : Qt.ArrowCursor
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onSingleTapped: quadro.tocado()
        // Duplo clique: tamanho real (ou o dobro, se a foto já cabe inteira) no ponto, e de volta.
        onDoubleTapped: (ponto) => {
            if (quadro.zoomado) {
                quadro.ajustar(true);
            } else {
                var alvo = quadro.ajuste < 0.9 ? 1 : quadro.ajuste * 2;
                var p = ponto.position;
                quadro.zoomEm(alvo, p.x - quadro.width / 2, p.y - quadro.height / 2, true);
            }
        }
    }
}
