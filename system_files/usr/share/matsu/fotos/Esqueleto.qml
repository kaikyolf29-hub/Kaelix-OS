// Lugar de uma foto que ainda está chegando: um bloco que pulsa de leve, na cor
// da frente (nunca um ícone genérico no lugar).
import QtQuick

Rectangle {
    id: esqueleto

    property real forca: janela.escuro ? 0.07 : 0.085
    // Todos os blocos pulsam juntos (a fase vem do relógio, não de quando nasceram).
    property bool pulsando: visible

    color: janela.tinta(forca)

    SequentialAnimation on opacity {
        running: esqueleto.pulsando
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.5; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.5; to: 1; duration: 900; easing.type: Easing.InOutSine }
    }
}
