// Um título na barra de cima (o nome do app ou "Janela"): a pílula de vidro
// aparece ao passar o mouse e fica acesa com o menu aberto. Abre ao apertar,
// como no Mac; com outro menu aberto, basta passar o mouse para trocar.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: titulo

    property string texto: ""
    property bool negrito: false
    property bool aberto: false
    property int larguraMaxima: Kirigami.Units.gridUnit * 14

    signal abrir()

    readonly property int folga: Math.round(Kirigami.Units.gridUnit * 0.5)

    width: Math.min(rotulo.implicitWidth, larguraMaxima) + folga * 2
    height: parent ? parent.height : implicitHeight
    hoverEnabled: true
    activeFocusOnTab: true
    Accessible.role: Accessible.MenuItem
    Accessible.name: texto
    onPressed: titulo.abrir()
    Keys.onReturnPressed: titulo.abrir()
    Keys.onSpacePressed: titulo.abrir()
    Keys.onDownPressed: titulo.abrir()

    Rectangle {
        readonly property color base: Kirigami.Theme.textColor

        anchors.centerIn: parent
        width: parent.width
        height: Math.min(parent.height - 6, Math.round(Kirigami.Units.gridUnit * 1.45))
        radius: Math.round(height * 0.34)
        color: Qt.rgba(base.r, base.g, base.b,
                       titulo.aberto ? 0.17 : (titulo.containsMouse || titulo.activeFocus ? 0.10 : 0))
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    PlasmaComponents.Label {
        id: rotulo
        anchors.centerIn: parent
        width: Math.min(implicitWidth, titulo.larguraMaxima)
        text: titulo.texto
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.weight: titulo.negrito ? Font.Bold : Font.Normal
    }
}
