// O desenho das telas, como na página Monitores do Mac e do Windows 11: cada
// tela é um retângulo de vidro na proporção certa, com o número e o nome.
// Clicar escolhe a tela; arrastar muda o lugar dela. Ao soltar, ela encaixa na
// borda da tela mais perto (alinhando em cima, embaixo ou no meio quando chega
// perto), e a página manda as posições novas de todas de uma vez.
// Duplicadas aparecem empilhadas; as desligadas ficam à direita, apagadas.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: arranjo

    property var telas: []
    property string escolhida: ""
    property string modo: "estender"
    readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property int gu: Kirigami.Units.gridUnit
    readonly property bool podeArrastar: modo === "estender" && ligadas.length > 1

    // Escolher uma tela; mover: { "HDMI-A-1": [x, y], ... } (lógico, já com 0,0).
    signal escolher(string nome)
    signal mover(var posicoes)

    implicitHeight: Math.round(gu * 10.5)
    // A tela arrastada passa por cima das linhas de baixo do cartão.
    z: 2

    readonly property int folga: Math.round(gu * 1.1)
    readonly property real passoPilha: Math.round(gu * 0.6)
    readonly property var ligadas: telas.filter(function (t) { return t.ligada; })
    readonly property var desligadas: telas.filter(function (t) { return !t.ligada; })
    readonly property int pilha: modo === "duplicar" ? Math.max(0, ligadas.length - 1) : 0

    // Onde cada tela fica no desenho, em pixels lógicos da tela de verdade.
    readonly property var caixas: {
        var r = {};
        var minX = 0, minY = 0, maxX = 1, maxY = 1, primeira = true;
        // Na pilha das duplicadas, a principal fica na frente e todas têm o
        // tamanho dela (mostram a mesma coisa).
        var ordem = ligadas.slice().sort(function (a, b) { return (a.principal ? 1 : 0) - (b.principal ? 1 : 0); });
        var frente = ordem.length > 0 ? ordem[ordem.length - 1] : null;
        for (var i = 0; i < ordem.length; i++) {
            var t = ordem[i];
            var c = modo === "duplicar" ? { x: 0, y: 0, w: frente.largura, h: frente.altura, pilha: i }
                                        : { x: t.x, y: t.y, w: t.largura, h: t.altura, pilha: 0 };
            r[t.nome] = c;
            if (primeira) {
                minX = c.x; minY = c.y; maxX = c.x + c.w; maxY = c.y + c.h; primeira = false;
            } else {
                minX = Math.min(minX, c.x); minY = Math.min(minY, c.y);
                maxX = Math.max(maxX, c.x + c.w); maxY = Math.max(maxY, c.y + c.h);
            }
        }
        // As desligadas: à direita das ligadas, alinhadas em cima.
        var vao = primeira ? 0 : Math.round((maxX - minX) * 0.08) + 200;
        var x = primeira ? 0 : maxX + vao;
        for (var j = 0; j < desligadas.length; j++) {
            var d = desligadas[j];
            var w = d.largura > 0 ? d.largura : 1920, h = d.altura > 0 ? d.altura : 1080;
            r[d.nome] = { x: x, y: minY, w: w, h: h, pilha: 0, desligada: true };
            maxX = Math.max(maxX, x + w);
            maxY = Math.max(maxY, minY + h);
            x += w + vao;
        }
        r["#caixa"] = { x: minX, y: minY, w: Math.max(1, maxX - minX), h: Math.max(1, maxY - minY) };
        return r;
    }
    readonly property var caixa: caixas["#caixa"]
    readonly property real escala: Math.max(0.001, Math.min((width - 2 * folga - pilha * passoPilha) / caixa.w,
                                                            (height - 2 * folga - pilha * passoPilha) / caixa.h))
    readonly property real ox: Math.round((width - caixa.w * escala - pilha * passoPilha) / 2)
    readonly property real oy: Math.round((height - caixa.h * escala - pilha * passoPilha) / 2)

    // Uma prévia de onde a tela arrastada vai encaixar (em pixels do desenho).
    property var previa: null

    // O melhor lugar encostado numa das outras telas, perto de (lx, ly).
    function encaixar(nome, lx, ly) {
        var d = caixas[nome];
        var outras = [];
        for (var i = 0; i < ligadas.length; i++)
            if (ligadas[i].nome !== nome)
                outras.push(caixas[ligadas[i].nome]);
        var limiar = (gu * 0.9) / escala;
        var melhor = null, distancia = Infinity;
        function testar(x, y) {
            for (var k = 0; k < outras.length; k++) {
                var o = outras[k];
                if (x < o.x + o.w - 0.5 && x + d.w > o.x + 0.5 && y < o.y + o.h - 0.5 && y + d.h > o.y + 0.5)
                    return;
            }
            var dist = Math.sqrt((x - lx) * (x - lx) + (y - ly) * (y - ly));
            if (dist < distancia) {
                distancia = dist;
                melhor = { x: Math.round(x), y: Math.round(y) };
            }
        }
        function alinhar(v, opcoes) {
            for (var k = 0; k < opcoes.length; k++)
                if (Math.abs(v - opcoes[k]) <= limiar)
                    return opcoes[k];
            return v;
        }
        for (var j = 0; j < outras.length; j++) {
            var o = outras[j];
            var my = Math.min(d.h, o.h) * 0.15;
            var y = alinhar(Math.max(o.y - d.h + my, Math.min(ly, o.y + o.h - my)), [o.y, o.y + o.h - d.h, o.y + (o.h - d.h) / 2]);
            testar(o.x + o.w, y);
            testar(o.x - d.w, y);
            var mx = Math.min(d.w, o.w) * 0.15;
            var x = alinhar(Math.max(o.x - d.w + mx, Math.min(lx, o.x + o.w - mx)), [o.x, o.x + o.w - d.w, o.x + (o.w - d.w) / 2]);
            testar(x, o.y + o.h);
            testar(x, o.y - d.h);
        }
        return melhor;
    }

    // As posições de todas as ligadas com a arrastada no lugar novo, com 0,0.
    function posicoesCom(nome, lugar) {
        var r = {};
        var menorX = Infinity, menorY = Infinity;
        for (var i = 0; i < ligadas.length; i++) {
            var n = ligadas[i].nome;
            var p = n === nome ? [lugar.x, lugar.y] : [caixas[n].x, caixas[n].y];
            r[n] = p;
            menorX = Math.min(menorX, p[0]);
            menorY = Math.min(menorY, p[1]);
        }
        for (var k in r)
            r[k] = [r[k][0] - menorX, r[k][1] - menorY];
        return r;
    }

    Repeater {
        id: repetidor
        // Só o número de telas: o desenho não é refeito a cada leitura (a cada 3 s).
        model: arranjo.telas.length

        Item {
            id: tela

            required property int index
            readonly property var t: arranjo.telas[index] || ({})
            readonly property var c: arranjo.caixas[t.nome] || { x: 0, y: 0, w: 1920, h: 1080, pilha: 0 }
            readonly property bool escolhida: t.nome === arranjo.escolhida
            readonly property bool desligada: !t.ligada
            // segurando: o dedo está no botão (as animações de lugar param);
            // preso: o lugar segue o mouse e não o desenho. Soltando, primeiro
            // as animações voltam e depois o lugar volta ao desenho (anima).
            property bool segurando: false
            property bool preso: false
            property bool arrastou: false

            readonly property real alvoX: arranjo.ox + (c.x - arranjo.caixa.x) * arranjo.escala + c.pilha * arranjo.passoPilha
            readonly property real alvoY: arranjo.oy + (c.y - arranjo.caixa.y) * arranjo.escala + c.pilha * arranjo.passoPilha

            width: Math.max(8, c.w * arranjo.escala)
            height: Math.max(8, c.h * arranjo.escala)
            z: segurando ? 20 : (arranjo.modo === "duplicar" ? 1 + c.pilha : (escolhida ? 5 : 1))
            opacity: desligada ? 0.55 : 1

            Binding on x {
                value: tela.alvoX
                when: !tela.preso
                restoreMode: Binding.RestoreNone
            }
            Binding on y {
                value: tela.alvoY
                when: !tela.preso
                restoreMode: Binding.RestoreNone
            }
            Behavior on x {
                enabled: !tela.segurando
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: !tela.segurando
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }

            Kirigami.ShadowedRectangle {
                id: corpo
                // Um respiro entre telas encostadas, para não virarem uma só.
                anchors.fill: parent
                anchors.margins: 1.5
                radius: Math.round(arranjo.gu * 0.45)
                scale: tela.segurando && tela.arrastou ? 1.03 : (area.pressed ? 0.985 : 1)
                color: tela.desligada ? "transparent"
                       : arranjo.escuro ? Qt.rgba(0.27, 0.27, 0.29, 1) : Qt.rgba(0.97, 0.97, 0.975, 1)
                border.width: tela.escolhida ? 2 : 1
                border.color: tela.escolhida ? Kirigami.Theme.highlightColor
                              : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                                        tela.desligada ? 0.35 : (area.containsMouse ? 0.3 : 0.16))
                shadow.size: tela.desligada ? 0 : (tela.segurando && tela.arrastou ? arranjo.gu * 1.2 : arranjo.gu * 0.4)
                shadow.yOffset: tela.segurando && tela.arrastou ? 4 : 1
                shadow.color: Qt.rgba(0, 0, 0, arranjo.escuro ? 0.4 : 0.14)
                Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on shadow.size {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on border.color {
                    ColorAnimation { duration: Kirigami.Units.shortDuration }
                }

                // Brilho de vidro: mais claro em cima.
                Rectangle {
                    visible: !tela.desligada
                    anchors.fill: parent
                    anchors.margins: corpo.border.width
                    radius: corpo.radius - 1
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, arranjo.escuro ? 0.07 : 0.5) }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - Math.round(arranjo.gu * 0.5)
                    spacing: Math.round(arranjo.gu * 0.15)
                    // Na pilha das duplicadas, só a da frente mostra o nome.
                    visible: tela.c.pilha === arranjo.pilha

                    // O número da tela (o mesmo do "Identificar").
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        readonly property real d: Math.round(Math.max(arranjo.gu * 1.05, Math.min(arranjo.gu * 1.7, tela.height * 0.3)))
                        implicitWidth: d
                        implicitHeight: d
                        radius: d / 2
                        color: tela.escolhida ? Kirigami.Theme.textColor
                                              : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            text: tela.t.numero || ""
                            font.weight: Font.Bold
                            font.pixelSize: Math.round(parent.d * 0.52)
                            color: tela.escolhida ? Kirigami.Theme.backgroundColor : Kirigami.Theme.textColor
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: tela.height > arranjo.gu * 3.2
                        horizontalAlignment: Text.AlignHCenter
                        text: tela.t.rotulo || ""
                        elide: Text.ElideRight
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                        font.weight: tela.escolhida ? Font.DemiBold : Font.Normal
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: tela.height > arranjo.gu * 4.4
                        horizontalAlignment: Text.AlignHCenter
                        text: tela.desligada ? ajustes.t("Desligada", "Off")
                                             : (tela.t.modo ? tela.t.modo.largura + " × " + tela.t.modo.altura : "")
                        elide: Text.ElideRight
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2
                        font.features: ({ "tnum": 1 })
                        opacity: 0.6
                    }
                }

                // A principal ganha a barra do Matsu embaixo (com a bandeja e a central).
                Rectangle {
                    visible: !!tela.t.principal && !tela.desligada
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.max(3, Math.round(parent.height * 0.06))
                    width: Math.round(parent.width * 0.5)
                    height: Math.max(3, Math.round(parent.height * 0.055))
                    radius: height / 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.32)
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: arranjo.podeArrastar && !tela.desligada ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                drag.target: arranjo.podeArrastar && !tela.desligada ? tela : null
                drag.threshold: Math.round(arranjo.gu * 0.3)
                drag.minimumX: -tela.width * 0.5
                drag.maximumX: arranjo.width - tela.width * 0.5
                drag.minimumY: -tela.height * 0.5
                drag.maximumY: arranjo.height - tela.height * 0.5
                Accessible.role: Accessible.Button
                Accessible.name: (tela.t.rotulo || "") + (tela.t.principal ? ajustes.t(", principal", ", main") : "")

                onPressed: {
                    tela.arrastou = false;
                    tela.segurando = true;
                    tela.preso = true;
                }
                onPositionChanged: {
                    if (!drag.active)
                        return;
                    tela.arrastou = true;
                    var lugar = arranjo.encaixar(tela.t.nome, arranjo.caixa.x + (tela.x - arranjo.ox) / arranjo.escala,
                                                 arranjo.caixa.y + (tela.y - arranjo.oy) / arranjo.escala);
                    arranjo.previa = lugar ? { x: arranjo.ox + (lugar.x - arranjo.caixa.x) * arranjo.escala,
                                               y: arranjo.oy + (lugar.y - arranjo.caixa.y) * arranjo.escala,
                                               w: tela.width, h: tela.height } : null;
                }
                onReleased: {
                    if (tela.arrastou) {
                        var lugar = arranjo.encaixar(tela.t.nome, arranjo.caixa.x + (tela.x - arranjo.ox) / arranjo.escala,
                                                     arranjo.caixa.y + (tela.y - arranjo.oy) / arranjo.escala);
                        if (lugar && (lugar.x !== tela.c.x || lugar.y !== tela.c.y))
                            arranjo.mover(arranjo.posicoesCom(tela.t.nome, lugar));
                    }
                    arranjo.previa = null;
                    tela.segurando = false;
                    tela.preso = false;
                }
                onCanceled: {
                    arranjo.previa = null;
                    tela.segurando = false;
                    tela.preso = false;
                }
                onClicked: arranjo.escolher(tela.t.nome)
            }
        }
    }

    // A prévia do encaixe: um contorno fino onde a tela vai parar.
    Rectangle {
        visible: opacity > 0
        opacity: arranjo.previa ? 1 : 0
        x: arranjo.previa ? arranjo.previa.x : 0
        y: arranjo.previa ? arranjo.previa.y : 0
        width: arranjo.previa ? arranjo.previa.w : 0
        height: arranjo.previa ? arranjo.previa.h : 0
        z: 10
        radius: Math.round(arranjo.gu * 0.45)
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
        border.width: 1.5
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.45)
        Behavior on x {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }
}
