// Botão em pílula da página Telas, no jeito dos Ajustes do Mac: de vidro
// (cinza, quase transparente) ou, o principal, claro com o texto escuro, como a
// pílula escolhida do Segmentado. Com o mouse em cima clareia; apertando, afunda.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: botao

    property string texto: ""
    property string icone: ""
    property bool principal: false
    readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5

    implicitWidth: linha.implicitWidth + Math.round(Kirigami.Units.gridUnit * 1.3)
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.75)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.Button
    Accessible.name: texto
    Keys.onReturnPressed: clicked(null)
    Keys.onSpacePressed: clicked(null)

    Rectangle {
        id: fundo
        anchors.fill: parent
        radius: height / 2
        scale: botao.pressed ? 0.96 : 1
        color: botao.principal
               ? (botao.escuro ? (botao.containsMouse ? "#ffffff" : "#ececf0") : (botao.containsMouse ? "#2c2c30" : "#1c1c1f"))
               : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                         botao.pressed ? 0.16 : (botao.containsMouse ? 0.12 : 0.08))
        border.width: botao.activeFocus ? 2 : (botao.principal ? 0 : 1)
        border.color: botao.activeFocus ? Kirigami.Theme.highlightColor
                                        : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
    }

    RowLayout {
        id: linha
        anchors.centerIn: parent
        spacing: Math.round(Kirigami.Units.gridUnit * 0.35)
        scale: fundo.scale

        Kirigami.Icon {
            visible: botao.icone.length > 0
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            source: botao.icone
            isMask: true
            color: rotulo.color
        }
        PlasmaComponents.Label {
            id: rotulo
            text: botao.texto
            font.weight: botao.principal ? Font.DemiBold : Font.Normal
            color: botao.principal ? (botao.escuro ? "#1a1a1e" : "#ffffff") : Kirigami.Theme.textColor
        }
    }
}
