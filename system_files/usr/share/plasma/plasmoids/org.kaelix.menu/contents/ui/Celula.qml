// Um app na grade de "Todos os apps": o ícone e o nome embaixo, em até duas linhas.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: celula

    property var icone
    property string titulo
    property bool destacado: false

    signal acionado()

    readonly property color texto: Kirigami.Theme.textColor
    readonly property color realce: Kirigami.Theme.highlightColor

    hoverEnabled: true
    Accessible.role: Accessible.Button
    Accessible.name: titulo
    onClicked: acionado()

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
            implicitWidth: Math.round(Kirigami.Units.gridUnit * 2.2)
            implicitHeight: Math.round(Kirigami.Units.gridUnit * 2.2)
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
