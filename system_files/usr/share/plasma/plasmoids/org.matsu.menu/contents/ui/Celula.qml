// Um app numa grade do menu (fixados, "Todos os apps" em grade, uma
// categoria aberta): o ícone e o nome embaixo, em até duas linhas.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: celula

    property var icone
    property string titulo
    property bool destacado: false
    property real tamanhoIcone: Math.round(Kirigami.Units.gridUnit * 2.2)

    signal acionado()
    // Botão direito (ou segurar apertado): o menu do app (fixar na barra...).
    signal menuPedido(real x, real y)

    readonly property color texto: Kirigami.Theme.textColor
    readonly property color realce: Kirigami.Theme.highlightColor

    hoverEnabled: true
    Accessible.role: Accessible.Button
    Accessible.name: titulo
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            menuPedido(mouse.x, mouse.y);
        } else {
            acionado();
        }
    }
    onPressAndHold: mouse => menuPedido(mouse.x, mouse.y)

    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.round(Kirigami.Units.gridUnit * 0.15)
        radius: Math.round(Kirigami.Units.gridUnit * 0.67)
        color: celula.destacado
            ? Qt.rgba(celula.realce.r, celula.realce.g, celula.realce.b, celula.pressed ? 0.42 : 0.28)
            : Qt.rgba(celula.texto.r, celula.texto.g, celula.texto.b, celula.pressed ? 0.16 : (celula.containsMouse ? 0.09 : 0))
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Math.round(Kirigami.Units.gridUnit * 0.55)
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Math.round(Kirigami.Units.gridUnit * 0.3)

        Kirigami.Icon {
            source: celula.icone
            implicitWidth: celula.tamanhoIcone
            implicitHeight: celula.tamanhoIcone
            Layout.alignment: Qt.AlignHCenter
        }
        PlasmaComponents.Label {
            text: celula.titulo
            textFormat: Text.PlainText
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
