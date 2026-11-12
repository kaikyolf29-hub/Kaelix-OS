// A miniatura da última foto ou vídeo, embaixo do botão de disparar. Clicar abre
// no app Fotos. Chegando uma nova, ela pula. Os vídeos ganham o selo de play.
// Sem nada ainda, fica um quadradinho vazio com o desenho da câmera.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: miniatura

    // { caminho, tipo: "foto" | "video", capa }
    property var item: null
    // Uma imagem já na memória (a foto que acabou de voar), enquanto o arquivo não chega.
    property string imediata: ""

    signal abrir(string caminho)

    readonly property bool tem: item !== null && item !== undefined
    readonly property string fonte: imediata !== "" ? imediata
                                  : !tem ? "" : (item.tipo === "foto" ? janela.urlDe(item.caminho) : (item.capa ? janela.urlDe(item.capa) : ""))
    readonly property real raio: Math.round(janela.gu * 0.55)

    function pular() {
        pulo.restart();
    }

    implicitWidth: Math.round(janela.gu * 3)
    implicitHeight: implicitWidth
    hoverEnabled: true
    cursorShape: tem ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: tem
    Accessible.role: Accessible.Button
    Accessible.name: dica
    onClicked: if (tem) miniatura.abrir(item.caminho)
    Keys.onReturnPressed: if (tem) miniatura.abrir(item.caminho)
    Keys.onSpacePressed: if (tem) miniatura.abrir(item.caminho)

    readonly property string dica: !tem ? janela.t("As fotos e os vídeos aparecem aqui", "Your photos and videos show up here")
                                  : item.tipo === "video" ? janela.t("Abrir o último vídeo no Fotos", "Open the last video in Photos")
                                  : janela.t("Abrir a última foto no Fotos", "Open the last photo in Photos")

    Item {
        id: caixa
        anchors.fill: parent
        scale: miniatura.pressed ? 0.92 : (miniatura.containsMouse ? 1.05 : 1)
        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: miniatura.raio
            color: janela.tinta(janela.escuro ? 0.06 : 0.05)
            border.width: 1
            border.color: janela.tinta(0.1)
            Kirigami.Icon {
                anchors.centerIn: parent
                visible: !foto.pronta
                width: Kirigami.Units.iconSizes.small
                height: width
                source: Qt.resolvedUrl(miniatura.tem && miniatura.item.tipo === "video" ? "icones/video.svg" : "icones/camera.svg")
                isMask: true
                color: janela.frente
                opacity: 0.4
            }
        }

        Item {
            id: foto
            readonly property bool pronta: imagem.status === Image.Ready && miniatura.fonte !== ""
            anchors.fill: parent
            Image {
                id: imagem
                anchors.fill: parent
                visible: false
                source: miniatura.fonte
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                sourceSize.width: 160
                sourceSize.height: 160
            }
            Rectangle {
                id: mascara
                anchors.fill: parent
                radius: miniatura.raio
                visible: false
                layer.enabled: true
                layer.smooth: true
            }
            MultiEffect {
                anchors.fill: parent
                visible: foto.pronta
                autoPaddingEnabled: false
                source: imagem
                maskEnabled: true
                maskSource: mascara
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
            // Borda fina por cima da foto.
            Rectangle {
                anchors.fill: parent
                visible: foto.pronta
                radius: miniatura.raio
                color: "transparent"
                border.width: 1
                border.color: miniatura.containsMouse ? janela.tinta(0.35) : Qt.rgba(1, 1, 1, janela.escuro ? 0.14 : 0.5)
            }
        }

        // Selo de play nos vídeos.
        Rectangle {
            visible: miniatura.tem && miniatura.item.tipo === "video"
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(janela.gu * 0.2)
            width: Math.round(janela.gu * 1.05)
            height: width
            radius: width / 2
            color: Qt.rgba(0.06, 0.06, 0.07, 0.6)
            Kirigami.Icon {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                width: Math.round(parent.width * 0.55)
                height: width
                source: Qt.resolvedUrl("icones/play.svg")
                isMask: true
                color: "#ffffff"
            }
        }

        // Anel de foco do teclado.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: miniatura.raio + 3
            color: "transparent"
            border.width: miniatura.activeFocus ? 1.5 : 0
            border.color: janela.frente
        }
    }

    SequentialAnimation {
        id: pulo
        NumberAnimation { target: caixa; property: "scale"; to: 1.16; duration: 140; easing.type: Easing.OutQuad }
        NumberAnimation { target: caixa; property: "scale"; to: 1; duration: 360; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
    }

    QQC2.ToolTip.visible: containsMouse
    QQC2.ToolTip.text: dica
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
