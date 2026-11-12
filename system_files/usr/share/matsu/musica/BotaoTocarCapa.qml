// O botãozinho redondo de tocar que aparece em cima da capa (álbum, playlist).
import QtQuick
import QtQuick.Effects

MouseArea {
    id: botao

    property bool tocando: false
    property bool mostrar: false

    signal clicado()

    width: Math.round(janela.gu * 2.3)
    height: width
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    visible: opacity > 0
    opacity: mostrar || tocando ? 1 : 0
    scale: (mostrar || tocando ? 1 : 0.6) * (pressed ? 0.88 : (containsMouse ? 1.08 : 1))
    Accessible.role: Accessible.Button
    Accessible.name: tocando ? janela.t("Pausar", "Pause") : janela.t("Tocar", "Play")
    onClicked: botao.clicado()
    Behavior on opacity {
        NumberAnimation {
            duration: 160
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutBack
            easing.overshoot: 2
        }
    }

    RectangularShadow {
        anchors.fill: parent
        radius: width / 2
        offset.y: 2
        blur: 10
        color: Qt.rgba(0, 0, 0, 0.35)
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: janela.frente
        IconeTocar {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.46)
            height: width
            tocando: botao.tocando
            cor: janela.escuro ? "#1a1a1e" : "#ffffff"
        }
    }
}
