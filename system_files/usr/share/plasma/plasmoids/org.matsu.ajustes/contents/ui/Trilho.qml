// Barra de arrastar no jeito do vídeo: trilho fino e redondo, parte cheia clara
// (azul no tema claro) e a bolinha branca.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

QQC2.Slider {
    id: trilho

    readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property int grossura: Math.round(Kirigami.Units.gridUnit * 0.45)
    readonly property int bolinha: Kirigami.Units.gridUnit

    implicitHeight: bolinha + 4
    padding: 0
    leftPadding: bolinha / 2
    rightPadding: bolinha / 2

    background: Item {
        x: trilho.leftPadding
        y: trilho.topPadding + trilho.availableHeight / 2 - height / 2
        width: trilho.availableWidth
        height: trilho.grossura

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -trilho.bolinha / 2
            anchors.rightMargin: -trilho.bolinha / 2
            radius: height / 2
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.18)
        }
        Rectangle {
            x: -trilho.bolinha / 2
            width: trilho.visualPosition * parent.width + trilho.bolinha
            height: parent.height
            radius: height / 2
            color: trilho.escuro ? Kirigami.Theme.textColor : Kirigami.Theme.highlightColor
        }
    }

    handle: Item {
        x: trilho.leftPadding + trilho.visualPosition * trilho.availableWidth - width / 2
        y: trilho.topPadding + trilho.availableHeight / 2 - height / 2
        width: trilho.bolinha
        height: trilho.bolinha

        // Sombra suave da bolinha.
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            anchors.bottomMargin: -2
            radius: width / 2
            color: Qt.rgba(0.08, 0.09, 0.24, trilho.escuro ? 0.45 : 0.22)
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#ffffff"
            scale: trilho.pressed ? 1.12 : 1
            Behavior on scale {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
    }
}
