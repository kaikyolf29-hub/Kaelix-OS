// Cartão de ajustes, como os grupos dos Ajustes do Mac: linhas uma embaixo da
// outra, com um risco fino entre elas (cada Linha desenha o seu).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: grupo

    property string titulo: ""
    property string nota: ""
    default property alias linhas: coluna.data
    readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5

    Layout.fillWidth: true
    spacing: Math.round(Kirigami.Units.gridUnit * 0.35)

    PlasmaComponents.Label {
        Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.6)
        visible: grupo.titulo.length > 0
        text: grupo.titulo
        font.weight: Font.DemiBold
        opacity: 0.8
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: coluna.implicitHeight
        radius: Math.round(Kirigami.Units.gridUnit * 0.6)
        color: grupo.escuro ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(1, 1, 1, 0.78)
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                              grupo.escuro ? 0.06 : 0.08)

        ColumnLayout {
            id: coluna
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.6)
        Layout.rightMargin: Math.round(Kirigami.Units.gridUnit * 0.6)
        visible: grupo.nota.length > 0
        text: grupo.nota
        wrapMode: Text.WordWrap
        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
        opacity: 0.65
    }
}
