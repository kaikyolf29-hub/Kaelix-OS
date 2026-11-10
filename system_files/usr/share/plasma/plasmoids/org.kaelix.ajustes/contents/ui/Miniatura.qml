// Miniatura com nome embaixo (tema claro ou escuro, estilo da barra, papel de
// parede). A escolhida ganha uma borda na cor de destaque.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: mini

    property string nome: ""
    property bool escolhida: false
    property real largura: Kirigami.Units.gridUnit * 6
    property real proporcao: 9 / 16
    default property alias desenho: quadro.data

    implicitWidth: largura
    implicitHeight: moldura.height + rotulo.implicitHeight + Kirigami.Units.smallSpacing * 2
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: nome
    Accessible.checked: escolhida
    Keys.onReturnPressed: clicked(null)
    Keys.onSpacePressed: clicked(null)

    Rectangle {
        id: moldura
        width: mini.largura
        height: Math.round(mini.largura * mini.proporcao)
        radius: Math.round(Kirigami.Units.gridUnit * 0.5)
        color: "transparent"
        border.width: mini.escolhida ? 3 : (mini.containsMouse || mini.activeFocus ? 2 : 0)
        border.color: mini.escolhida ? Kirigami.Theme.highlightColor
                                     : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)

        Item {
            id: quadro
            anchors.fill: parent
            anchors.margins: 4
            clip: true
        }
    }

    PlasmaComponents.Label {
        id: rotulo
        anchors.top: moldura.bottom
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.horizontalCenter: moldura.horizontalCenter
        width: mini.largura
        horizontalAlignment: Text.AlignHCenter
        text: mini.nome
        elide: Text.ElideRight
        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
        font.weight: mini.escolhida ? Font.DemiBold : Font.Normal
    }
}
