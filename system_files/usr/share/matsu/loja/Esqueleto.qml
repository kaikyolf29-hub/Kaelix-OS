// Lugar de algo que ainda está chegando (ícone, foto, cartão): um bloco que pulsa
// de leve, na cor da frente. Nunca uma letra ou um ícone genérico no lugar.
import QtQuick

Rectangle {
    id: esqueleto

    property real raio: Math.round(janela.gu * 0.4)
    // A cor da marca (um site), quando se sabe.
    property color cor: janela.frente
    property real forca: janela.escuro ? 0.07 : 0.08

    radius: raio
    color: Qt.rgba(cor.r, cor.g, cor.b, forca)

    SequentialAnimation on opacity {
        running: esqueleto.visible
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.45; duration: 850; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.45; to: 1; duration: 850; easing.type: Easing.InOutSine }
    }
}
