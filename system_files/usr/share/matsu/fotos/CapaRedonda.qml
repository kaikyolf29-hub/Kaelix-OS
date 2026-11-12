// Capa com cantos redondos (álbuns e vídeos): carrega no fundo, no tamanho certo,
// com o bloco pulsando até chegar. "aproximar" amplia de leve por dentro (mouse em cima).
import QtQuick
import QtQuick.Effects

Item {
    id: capa

    property string arquivo: ""
    property real raio: Math.round(janela.gu * 0.55)
    property real aproximar: 1
    property int giro: 0
    readonly property bool pronta: imagem.status === Image.Ready
    readonly property bool vazia: arquivo === "" || imagem.status === Image.Error
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property bool deLado: giro === 90 || giro === 270

    Esqueleto {
        anchors.fill: parent
        radius: capa.raio
        visible: !capa.pronta && !capa.vazia
    }
    Item {
        id: quadro
        anchors.fill: parent
        visible: capa.pronta
        layer.enabled: capa.pronta
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mascara
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        Image {
            id: imagem
            anchors.centerIn: parent
            width: capa.deLado ? parent.height : parent.width
            height: capa.deLado ? parent.width : parent.height
            rotation: capa.giro
            scale: capa.aproximar
            source: capa.arquivo !== "" ? janela.arquivo(capa.arquivo) : ""
            sourceSize: Qt.size(Math.ceil(width * capa.dpr / 64) * 64, Math.ceil(height * capa.dpr / 64) * 64)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            autoTransform: true
            smooth: true
            opacity: capa.pronta ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    Rectangle {
        id: mascara
        anchors.fill: parent
        visible: false
        layer.enabled: true
        radius: capa.raio
        color: "white"
    }
}
