// Fundo das telas de login e bloqueio: o papel de parede fica limpo, como no Mac
// (sem desfoque); só um escurecido leve em cima e embaixo, para a hora e a senha
// ficarem fáceis de ler em qualquer papel de parede.
import QtQuick

Item {
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height * 0.42
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.32) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.5
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.42) }
        }
    }
}
