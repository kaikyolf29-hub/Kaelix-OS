// Um ícone solto na barra fina de cima (estilo Mac): rede, Bluetooth, som,
// bateria ou o botão da central. A pílula de vidro aparece ao passar o mouse
// e fica acesa com a central aberta; ao apertar, o ícone afunda um pouquinho.
import QtQuick
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property bool aceso: false
    default property alias conteudo: dentro.data

    readonly property int folga: Math.round(Kirigami.Units.gridUnit * 0.38)

    width: dentro.implicitWidth + folga * 2
    height: parent ? parent.height : implicitHeight
    hoverEnabled: true

    Rectangle {
        readonly property color base: Kirigami.Theme.textColor

        anchors.centerIn: parent
        width: parent.width
        height: Math.min(parent.height - 6, Math.round(Kirigami.Units.gridUnit * 1.45))
        radius: Math.round(height * 0.34)
        color: Qt.rgba(base.r, base.g, base.b,
                       botao.pressed ? 0.20 : botao.aceso ? 0.16 : botao.containsMouse ? 0.11 : 0)
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    Row {
        id: dentro
        anchors.centerIn: parent
        spacing: Math.round(Kirigami.Units.gridUnit * 0.28)
        scale: botao.pressed ? 0.9 : 1
        Behavior on scale {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
    }
}
