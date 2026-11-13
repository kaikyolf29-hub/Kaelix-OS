// Gráfico do último minuto, como os do Windows: linha na cor da parte (CPU,
// memória...) com a área em degradê embaixo, sobre uma grade neutra bem fina.
// O valor mais novo fica na direita. "valores2" desenha uma segunda linha
// (enviar/gravar), tracejada. Com "suave", a linha vira curva, o gráfico desliza
// para a esquerda a cada valor novo (em vez de pular) e a escala muda devagar.
import QtQuick
import org.kde.kirigami as Kirigami

Canvas {
    id: grafico

    property var valores: []
    property var valores2: []
    property real maximo: 100     // 0: ajusta sozinho ao maior valor
    property color cor: Kirigami.Theme.highlightColor
    property bool mini: false
    // Sem moldura: só a linha e o degradê (nos cartões, onde a moldura pesa).
    property bool moldura: true
    property int pontos: 60
    property int tique: 0
    property bool suave: false

    readonly property real escala: {
        if (maximo > 0)
            return maximo;
        var m = 1;
        for (var i = 0; i < valores.length; i++)
            m = Math.max(m, valores[i]);
        for (var j = 0; j < valores2.length; j++)
            m = Math.max(m, valores2[j]);
        // Arredonda para cima, para a linha não encostar no teto.
        var passo = Math.pow(10, Math.floor(Math.log(m) / Math.LN10));
        return Math.ceil(m * 1.15 / passo) * passo;
    }

    // Quanto do último passo ainda falta deslizar (1 → 0 a cada valor novo) e a
    // escala que o desenho usa (acompanha "escala", devagar quando suave).
    property real _deslize: 0
    property real _escala: escala
    Behavior on _escala {
        enabled: grafico.suave
        NumberAnimation {
            duration: 450
            easing.type: Easing.OutCubic
        }
    }
    NumberAnimation {
        id: deslizar
        target: grafico
        property: "_deslize"
        from: 1
        to: 0
        duration: 800
        easing.type: Easing.OutQuad
    }
    on_DeslizeChanged: requestPaint()
    on_EscalaChanged: requestPaint()

    onTiqueChanged: {
        if (suave && visible && valores.length > 1)
            deslizar.restart();
        requestPaint();
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCorChanged: requestPaint()
    onMolduraChanged: requestPaint()
    readonly property color neutra: janela.frente
    onNeutraChanged: requestPaint()

    function linhaDe(ctx, lista, w, h, folga) {
        var n = lista.length;
        var passo = w / (pontos - 1);
        var x0 = w - (n - 1) * passo + (suave ? _deslize * passo : 0);
        var esc = _escala > 0 ? _escala : 1;
        ctx.beginPath();
        var xa = 0, ya = 0;
        for (var i = 0; i < n; i++) {
            var x = x0 + i * passo;
            var y = h - folga - (h - 2 * folga) * Math.min(1, Math.max(0, lista[i] / esc));
            if (i === 0)
                ctx.moveTo(x, y);
            else if (suave)
                // Curva pelo meio de cada trecho (não passa do topo nem do zero).
                ctx.quadraticCurveTo(xa, ya, (xa + x) / 2, (ya + y) / 2);
            else
                ctx.lineTo(x, y);
            xa = x;
            ya = y;
        }
        if (suave && n > 1)
            ctx.lineTo(xa, ya);
        return x0;
    }

    onPaint: {
        var ctx = getContext("2d");
        var w = width;
        var h = height;
        ctx.reset();
        var r = grafico.cor.r * 255, g = grafico.cor.g * 255, b = grafico.cor.b * 255;
        function rgba(a) {
            return "rgba(" + Math.round(r) + "," + Math.round(g) + "," + Math.round(b) + "," + a + ")";
        }
        function tinta(a) {
            return "rgba(" + Math.round(neutra.r * 255) + "," + Math.round(neutra.g * 255) + "," + Math.round(neutra.b * 255) + "," + a + ")";
        }
        var raio = mini ? 3 : 5;

        // Fundo e borda arredondados.
        ctx.beginPath();
        ctx.roundedRect(0.5, 0.5, w - 1, h - 1, raio, raio);
        if (moldura) {
            ctx.fillStyle = tinta(0.02);
            ctx.fill();
        }
        ctx.save();
        ctx.clip();

        if (!mini) {
            ctx.strokeStyle = tinta(0.06);
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (var gx = 1; gx < 10; gx++) {
                var x = Math.round(w * gx / 10) + 0.5;
                ctx.moveTo(x, 0);
                ctx.lineTo(x, h);
            }
            for (var gy = 1; gy < 5; gy++) {
                var y = Math.round(h * gy / 5) + 0.5;
                ctx.moveTo(0, y);
                ctx.lineTo(w, y);
            }
            ctx.stroke();
        }

        var folga = mini ? 1.5 : 1;
        if (valores2.length > 1) {
            linhaDe(ctx, valores2, w, h, folga);
            ctx.strokeStyle = rgba(0.75);
            ctx.lineWidth = mini ? 1 : 1.4;
            ctx.setLineDash ? ctx.setLineDash([4, 3]) : null;
            ctx.stroke();
            ctx.setLineDash ? ctx.setLineDash([]) : null;
        }
        if (valores.length > 1) {
            var x0 = linhaDe(ctx, valores, w, h, folga);
            ctx.lineTo(suave ? w + _deslize * w / (pontos - 1) : w, h);
            ctx.lineTo(x0, h);
            ctx.closePath();
            var degrade = ctx.createLinearGradient(0, 0, 0, h);
            degrade.addColorStop(0, rgba(mini ? 0.38 : 0.32));
            degrade.addColorStop(1, rgba(0.03));
            ctx.fillStyle = degrade;
            ctx.fill();
            linhaDe(ctx, valores, w, h, folga);
            ctx.strokeStyle = rgba(1);
            ctx.lineWidth = mini ? 1.3 : 2;
            ctx.lineJoin = "round";
            ctx.stroke();
        }
        ctx.restore();
        if (!moldura)
            return;

        ctx.beginPath();
        ctx.roundedRect(0.5, 0.5, w - 1, h - 1, raio, raio);
        ctx.strokeStyle = tinta(mini ? 0.2 : 0.16);
        ctx.lineWidth = 1;
        ctx.stroke();
    }
}
