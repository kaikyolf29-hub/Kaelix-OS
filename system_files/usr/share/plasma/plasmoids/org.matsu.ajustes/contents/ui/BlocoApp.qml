// Um app na grade de "Adicionar app": o ícone grande e o nome embaixo, como a
// grade de "Todos os apps" do menu do Matsu. Um clique fixa o app na barra.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: bloco

    property string nome: ""
    property string icone: ""

    signal escolhido()

    readonly property color texto: Kirigami.Theme.textColor

    hoverEnabled: true
    activeFocusOnTab: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: ajustes.t("Fixar " + nome + " na barra", "Pin " + nome + " to the bar")
    onClicked: escolhido()
    Keys.onReturnPressed: escolhido()
    Keys.onSpacePressed: escolhido()

    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.round(Kirigami.Units.gridUnit * 0.15)
        radius: Math.round(Kirigami.Units.gridUnit * 0.6)
        color: bloco.activeFocus
            ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.28)
            : Qt.rgba(bloco.texto.r, bloco.texto.g, bloco.texto.b, bloco.pressed ? 0.14 : (bloco.containsMouse ? 0.08 : 0))
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Math.round(Kirigami.Units.gridUnit * 0.5)
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Math.round(Kirigami.Units.gridUnit * 0.3)

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(Kirigami.Units.gridUnit * 2.1)
            implicitHeight: implicitWidth
            source: bloco.icone
            fallback: "application-x-executable"
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: bloco.nome
            textFormat: Text.PlainText
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
}
