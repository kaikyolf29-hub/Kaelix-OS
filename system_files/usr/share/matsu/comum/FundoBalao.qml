// Fundo dos balões que abrem por cima da janela (lista suspensa, menu, diálogo):
// mais sólido que o vidro, com a linha fina na borda e uma sombra suave.
import QtQuick

Rectangle {
    radius: Math.round(janela.gu * 0.55)
    color: janela.escuro ? Qt.rgba(0.17, 0.17, 0.18, 0.985) : Qt.rgba(0.99, 0.99, 0.995, 0.99)
    border.width: 1
    border.color: janela.escuro ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.12)
    // Sombra em camadas (sem efeito gráfico, funciona em qualquer placa).
    Repeater {
        model: 4
        Rectangle {
            required property int index
            z: -1
            anchors.fill: parent
            anchors.margins: -(index + 1) * 2
            anchors.topMargin: -(index + 1) * 1
            anchors.bottomMargin: -(index + 1) * 3
            radius: parent.radius + (index + 1) * 2
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(0, 0, 0, (janela.escuro ? 0.16 : 0.05) / (index + 1))
        }
    }
}
