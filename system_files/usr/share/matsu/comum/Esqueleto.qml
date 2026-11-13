// Lugar de algo que ainda está chegando (ícone, foto, cartão, uma linha de texto):
// um bloco na cor da frente com um brilho que passa da esquerda para a direita,
// como os "skeletons" do Windows 11 e da App Store. Nunca uma letra ou um ícone
// genérico no lugar. Todos os blocos andam juntos: o tempo vem do relógio e o
// brilho chega antes aos da esquerda, como uma luz só passando pela tela.
//   Esqueleto { anchors.fill: parent; raio: janela.gu * 0.6; visible: !pronto }
import QtQuick

Rectangle {
    id: esqueleto

    property real raio: Math.round(janela.gu * 0.4)
    // A cor do bloco (a cor da marca de um site, quando se sabe).
    property color cor: janela.frente
    property real forca: janela.escuro ? 0.07 : 0.08
    // Se o brilho anda (parado quando não está à vista).
    property bool pulsando: visible
    // Sem o brilho: um bloco liso que só pulsa de leve.
    property bool brilho: true

    // ----- o brilho -----
    readonly property int periodo: 1700
    // Meia largura da faixa de luz, em fração da largura do bloco (mais larga nos estreitos).
    readonly property real faixa: Math.min(0.45, Math.max(0.18, janela.gu * 5 / Math.max(1, width)))
    readonly property color base: Qt.rgba(cor.r, cor.g, cor.b, forca)
    readonly property color luz: Qt.rgba(cor.r, cor.g, cor.b, Math.min(1, forca * (janela.escuro ? 1.85 : 1.7) + 0.015))
    // O tempo do ciclo, de 0 a 1: a luz passa nos primeiros 70% e o resto é pausa.
    property real tempo: 0
    readonly property real fase: {
        var t = Math.min(1, tempo / 0.7);
        var suave = 0.5 - 0.5 * Math.cos(Math.PI * t);
        return -faixa + (1 + 2 * faixa) * suave;
    }
    function _limite(x) {
        return Math.max(0, Math.min(1, x));
    }
    function _cor(x) {
        var f = Math.max(0, 1 - Math.abs(x - fase) / faixa);
        f = f * f * (3 - 2 * f);
        return Qt.rgba(cor.r, cor.g, cor.b, base.a + (luz.a - base.a) * f);
    }

    radius: raio
    color: base
    // Os pontos da faixa de luz (do começo ao fim), já dentro do bloco.
    readonly property real _p1: _limite(fase - faixa)
    readonly property real _p2: _limite(fase - faixa * 0.5)
    readonly property real _p3: _limite(fase)
    readonly property real _p4: _limite(fase + faixa * 0.5)
    readonly property real _p5: _limite(fase + faixa)
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: esqueleto._cor(0) }
        GradientStop { position: esqueleto._p1; color: esqueleto._cor(esqueleto._p1) }
        GradientStop { position: esqueleto._p2; color: esqueleto._cor(esqueleto._p2) }
        GradientStop { position: esqueleto._p3; color: esqueleto._cor(esqueleto._p3) }
        GradientStop { position: esqueleto._p4; color: esqueleto._cor(esqueleto._p4) }
        GradientStop { position: esqueleto._p5; color: esqueleto._cor(esqueleto._p5) }
        GradientStop { position: 1; color: esqueleto._cor(1) }
    }

    readonly property bool andando: pulsando && visible && brilho && width > 0
    onAndandoChanged: _comecar()
    Component.onCompleted: _comecar()
    function _comecar() {
        primeiraVolta.stop();
        volta.stop();
        if (!andando) {
            tempo = 0.99;
            return;
        }
        // Começa no ponto do relógio, um pouco atrasado conforme a posição na janela.
        var p = mapToItem(null, 0, 0);
        var atraso = Math.max(0, Math.min(1, p.x / Math.max(1, janela.width))) * 0.22;
        var inicio = ((Date.now() % periodo) / periodo - atraso + 1) % 1;
        tempo = inicio;
        primeiraVolta.from = inicio;
        primeiraVolta.duration = Math.max(1, Math.round((1 - inicio) * periodo));
        primeiraVolta.start();
    }
    NumberAnimation {
        id: primeiraVolta
        target: esqueleto
        property: "tempo"
        to: 1
        onFinished: if (esqueleto.andando) volta.start()
    }
    NumberAnimation {
        id: volta
        target: esqueleto
        property: "tempo"
        from: 0
        to: 1
        duration: esqueleto.periodo
        loops: Animation.Infinite
    }
    // Sem o brilho: pulsa de leve, como antes.
    SequentialAnimation on opacity {
        running: esqueleto.pulsando && esqueleto.visible && !esqueleto.brilho
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.5; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.5; to: 1; duration: 900; easing.type: Easing.InOutSine }
    }
}
