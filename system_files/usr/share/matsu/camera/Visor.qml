// O visor da Câmera: a imagem da câmera com os cantos redondos e a sombra, e por
// cima o que conta naquele momento: a grade de terços, a contagem do temporizador
// (o número rola e o anel esvazia), a pílula de "gravando" com o pontinho que
// pulsa, a rodinha enquanto a câmera abre e o clarão branco da foto.
// No modo de demonstração (--demo, só para a prévia) mostra uma imagem no lugar
// da câmera.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtMultimedia
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: visor

    // A saída da câmera (a CaptureSession do Main.qml desenha aqui).
    property alias saida: saidaVideo
    // O que vira a foto no modo de demonstração (e a capa dos vídeos).
    readonly property Item imagem: janela.demo ? imagemDemo : saidaVideo
    property real raio: Math.round(janela.gu * 0.8)
    // Fração do temporizador que falta (1 a 0), para o anel da contagem.
    property real falta: 1

    function piscar() {
        clarao.restart();
    }
    function contar(segundos) {
        esvaziar.stop();
        falta = 1;
        esvaziar.duration = segundos * 1000;
        esvaziar.start();
    }
    function pularNumero() {
        pulo.restart();
    }

    NumberAnimation {
        id: esvaziar
        target: visor
        property: "falta"
        from: 1
        to: 0
    }

    // Sombra suave embaixo (o palco é sólido, ela aparece nos dois temas).
    RectangularShadow {
        anchors.fill: parent
        radius: visor.raio
        offset.y: Math.round(janela.gu * 0.35)
        blur: Math.round(janela.gu * 1.4)
        spread: -Math.round(janela.gu * 0.25)
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.55 : 0.2)
    }

    Item {
        id: recorte
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: mascara
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Rectangle {
            anchors.fill: parent
            color: "#0c0c0e"
        }

        // A imagem, espelhada se a pessoa quiser (só na tela). Ao ligar e desligar,
        // ela vira como uma carta.
        Item {
            id: espelho
            anchors.fill: parent
            transform: Scale {
                origin.x: espelho.width / 2
                xScale: janela.espelhar ? -1 : 1
                Behavior on xScale {
                    NumberAnimation {
                        duration: 380
                        easing.type: Easing.OutCubic
                    }
                }
            }

            VideoOutput {
                id: saidaVideo
                anchors.fill: parent
                visible: !janela.demo
                fillMode: VideoOutput.PreserveAspectCrop
            }
            Image {
                id: imagemDemo
                anchors.fill: parent
                visible: janela.demo
                source: janela.demo ? janela.imagemDemo : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                sourceSize.width: 1920
                onStatusChanged: if (status === Image.Ready) janela.chegouImagem()
            }
        }

        // ----- grade de terços -----
        Item {
            anchors.fill: parent
            opacity: janela.grade ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                }
            }
            Repeater {
                model: [1 / 3, 2 / 3]
                Item {
                    required property real modelData
                    anchors.fill: parent
                    // Uma linha escura de 1 px ao lado da clara: aparece no céu e na sombra.
                    Rectangle { x: Math.round(parent.width * modelData) + 1; width: 1; height: parent.height; color: Qt.rgba(0, 0, 0, 0.22) }
                    Rectangle { x: Math.round(parent.width * modelData); width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.55) }
                    Rectangle { y: Math.round(parent.height * modelData) + 1; height: 1; width: parent.width; color: Qt.rgba(0, 0, 0, 0.22) }
                    Rectangle { y: Math.round(parent.height * modelData); height: 1; width: parent.width; color: Qt.rgba(1, 1, 1, 0.55) }
                }
            }
        }

        // ----- abrindo a câmera (antes da primeira imagem) -----
        Rectangle {
            id: abrindo
            anchors.fill: parent
            color: "#0c0c0e"
            opacity: janela.abrindo ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: Math.round(janela.gu * 0.7)
                Girando {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(janela.gu * 1.6)
                    cor: "#ffffff"
                    rodando: abrindo.visible
                }
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: janela.t("Abrindo a câmera…", "Starting the camera…")
                    color: "#ffffff"
                    opacity: 0.75
                }
            }
        }

        // ----- gravando: pílula no alto com o pontinho pulsando e o tempo -----
        Rectangle {
            id: pilulaGravando
            readonly property bool mostrar: janela.estado === "gravando"
            anchors.horizontalCenter: parent.horizontalCenter
            y: mostrar ? Math.round(janela.gu * 0.8) : -height
            height: Math.round(janela.gu * 1.9)
            width: linhaGravando.implicitWidth + Math.round(janela.gu * 1.5)
            radius: height / 2
            color: Qt.rgba(0.06, 0.06, 0.07, 0.62)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
            opacity: mostrar ? 1 : 0
            visible: opacity > 0
            Behavior on y {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.4
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }
            Row {
                id: linhaGravando
                anchors.centerIn: parent
                spacing: Math.round(janela.gu * 0.5)
                Rectangle {
                    id: pontinho
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(janela.gu * 0.55)
                    height: width
                    radius: width / 2
                    color: "#ff4d57"
                    SequentialAnimation on opacity {
                        running: pilulaGravando.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.25; to: 1; duration: 600; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on scale {
                        running: pilulaGravando.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.78; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.78; to: 1; duration: 600; easing.type: Easing.InOutSine }
                    }
                }
                NumeroRolante {
                    anchors.verticalCenter: parent.verticalCenter
                    texto: janela.tempoGravado
                    cor: "#ffffff"
                    duracao: 360
                    font.pixelSize: Math.round(janela.gu * 0.85)
                    font.weight: Font.DemiBold
                }
            }
        }

        // ----- contagem do temporizador, no meio -----
        Item {
            id: contagem
            readonly property bool mostrar: janela.estado === "contando"
            anchors.centerIn: parent
            width: Math.min(Math.round(janela.gu * 7.5), parent.height * 0.6)
            height: width
            opacity: mostrar ? 1 : 0
            scale: mostrar ? 1 : 0.7
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 360
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.6
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(0.06, 0.06, 0.07, 0.5)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
            }
            Shape {
                id: anel
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                readonly property real espessura: Math.max(3, Math.round(width * 0.045))
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.rgba(1, 1, 1, 0.16)
                    strokeWidth: anel.espessura
                    PathAngleArc {
                        centerX: contagem.width / 2
                        centerY: contagem.height / 2
                        radiusX: contagem.width / 2 - contagem.width * 0.09
                        radiusY: radiusX
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: "#ffffff"
                    strokeWidth: anel.espessura
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: contagem.width / 2
                        centerY: contagem.height / 2
                        radiusX: contagem.width / 2 - contagem.width * 0.09
                        radiusY: radiusX
                        startAngle: -90
                        sweepAngle: 360 * visor.falta
                    }
                }
            }
            NumeroRolante {
                id: numero
                anchors.centerIn: parent
                texto: String(janela.contagem)
                cor: "#ffffff"
                duracao: 420
                font.pixelSize: Math.round(contagem.width * 0.42)
                font.weight: Font.DemiBold
            }
            SequentialAnimation {
                id: pulo
                NumberAnimation { target: numero; property: "scale"; to: 1.14; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: numero; property: "scale"; to: 1; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
            }
        }

        // ----- o clarão da foto -----
        Rectangle {
            id: brilho
            anchors.fill: parent
            color: "#ffffff"
            opacity: 0
            visible: opacity > 0
        }
        SequentialAnimation {
            id: clarao
            NumberAnimation { target: brilho; property: "opacity"; to: 0.92; duration: 45; easing.type: Easing.OutQuad }
            NumberAnimation { target: brilho; property: "opacity"; to: 0; duration: 380; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        id: mascara
        anchors.fill: parent
        radius: visor.raio
        visible: false
        layer.enabled: true
        layer.smooth: true
    }
    // Uma linha bem fina na borda dá acabamento (como nas fotos do Mac).
    Rectangle {
        anchors.fill: parent
        radius: visor.raio
        color: "transparent"
        border.width: 1
        border.color: janela.escuro ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.1)
    }
}
