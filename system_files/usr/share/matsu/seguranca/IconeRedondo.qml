// Ícone de linha dentro de um círculo suave (na cor do estado, ou na cor da frente).
//   IconeRedondo { icone: janela.ic("camera"); cor: janela.verde }
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: redondo

    property string icone: ""
    property color cor: janela.frente
    property real tamanhoIcone: Math.round(width * 0.5)

    implicitWidth: Math.round(janela.gu * 2.3)
    implicitHeight: implicitWidth
    radius: width / 2
    color: Qt.rgba(cor.r, cor.g, cor.b, janela.escuro ? 0.14 : 0.1)
    Behavior on color {
        ColorAnimation { duration: 300 }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: redondo.tamanhoIcone
        height: width
        source: redondo.icone
        isMask: true
        color: redondo.cor
    }
}
