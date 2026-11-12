// As abas dos arquivos, como as do Bloco de Notas do Windows 11: a aberta tem o
// fundo da folha e a borda fina, com os "pés" curvos que se juntam à folha
// embaixo (sem tracinho colorido). Esse fundo é um só e desliza até a aba
// escolhida. As abas encolhem até um mínimo e depois rolam; o + abre outra.
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: faixa

    property color corFolha
    property color corLinha

    readonly property int alturaAba: Math.round(janela.gu * 2.05)
    readonly property int raio: Math.round(janela.gu * 0.5)
    readonly property int pe: Math.round(janela.gu * 0.42)
    readonly property int margem: Math.round(janela.gu * 0.6)
    readonly property int ladoBotao: Math.round(janela.gu * 1.75)
    readonly property real minimo: Math.round(janela.gu * 6.5)
    readonly property real maximo: Math.round(janela.gu * 12.5)
    // Espaço das abas: tudo menos as margens, o + e (se rolar) as setas.
    readonly property real livre: width - 2 * margem - ladoBotao - Math.round(janela.gu * 0.3)
    readonly property bool transborda: janela.abas.count * minimo > livre
    readonly property real disponivel: livre - (transborda ? 2 * ladoBotao + Math.round(janela.gu * 0.2) : 0)
    readonly property real larguraAba: Math.max(minimo, Math.min(maximo, Math.floor(disponivel / Math.max(1, janela.abas.count))))
    // A aba com o mouse em cima (some a linha entre ela e a vizinha).
    property int sob: -1

    implicitHeight: Math.round(janela.gu * 2.55)

    // No tema claro a faixa fica um pouco mais funda que a folha.
    Rectangle {
        anchors.fill: parent
        color: janela.escuro ? "transparent" : janela.tinta(0.035)
    }

    // Dois cliques no vazio da faixa abrem uma aba nova.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onDoubleClicked: janela.novaAba(false)
    }

    // O fundo da aba aberta, com os pés, atrás do texto das abas.
    Item {
        id: recorte
        x: lista.x - faixa.pe
        y: lista.y
        width: lista.width + 2 * faixa.pe
        height: lista.height
        clip: true

        Shape {
            id: forma
            readonly property real w: largura
            readonly property real h: height
            readonly property real p: faixa.pe
            readonly property real r: faixa.raio
            property real xNaLista: lista.currentItem ? lista.currentItem.x : 0
            property real largura: lista.currentItem ? lista.currentItem.width : faixa.larguraAba
            Behavior on xNaLista {
                enabled: janela.iniciado
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on largura {
                enabled: janela.iniciado
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            x: xNaLista - lista.contentX
            width: largura + 2 * p
            height: parent.height
            visible: lista.currentItem !== null && janela.abas.count > 0
            preferredRendererType: Shape.CurveRenderer

            // O preenchimento (fechado embaixo, junto da folha).
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: 0
                fillColor: faixa.corFolha
                startX: 0
                startY: forma.h
                PathArc { x: forma.p; y: forma.h - forma.p; radiusX: forma.p; radiusY: forma.p; direction: PathArc.Counterclockwise }
                PathLine { x: forma.p; y: forma.r }
                PathArc { x: forma.p + forma.r; y: 0; radiusX: forma.r; radiusY: forma.r }
                PathLine { x: forma.p + forma.w - forma.r; y: 0 }
                PathArc { x: forma.p + forma.w; y: forma.r; radiusX: forma.r; radiusY: forma.r }
                PathLine { x: forma.p + forma.w; y: forma.h - forma.p }
                PathArc { x: forma.w + 2 * forma.p; y: forma.h; radiusX: forma.p; radiusY: forma.p; direction: PathArc.Counterclockwise }
                PathLine { x: 0; y: forma.h }
            }
            // A borda fina (aberta embaixo: continua na linha da folha).
            ShapePath {
                strokeColor: faixa.corLinha
                strokeWidth: 1
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin
                startX: 0
                startY: forma.h - 0.5
                PathArc { x: forma.p + 0.5; y: forma.h - forma.p; radiusX: forma.p + 0.5; radiusY: forma.p - 0.5; direction: PathArc.Counterclockwise }
                PathLine { x: forma.p + 0.5; y: forma.r + 0.5 }
                PathArc { x: forma.p + forma.r + 0.5; y: 0.5; radiusX: forma.r; radiusY: forma.r }
                PathLine { x: forma.p + forma.w - forma.r - 0.5; y: 0.5 }
                PathArc { x: forma.p + forma.w - 0.5; y: forma.r + 0.5; radiusX: forma.r; radiusY: forma.r }
                PathLine { x: forma.p + forma.w - 0.5; y: forma.h - forma.p }
                PathArc { x: forma.w + 2 * forma.p; y: forma.h - 0.5; radiusX: forma.p + 0.5; radiusY: forma.p - 0.5; direction: PathArc.Counterclockwise }
            }
        }
    }

    // A linha de cima da folha, com o vão da aba aberta.
    readonly property real vaoInicio: forma.visible ? Math.max(recorte.x, Math.min(recorte.x + recorte.width, recorte.x + forma.x)) : width
    readonly property real vaoFim: forma.visible ? Math.max(recorte.x, Math.min(recorte.x + recorte.width, recorte.x + forma.x + forma.width)) : width
    Rectangle {
        x: 0
        y: faixa.height - 1
        width: Math.max(0, faixa.vaoInicio)
        height: 1
        color: faixa.corLinha
    }
    Rectangle {
        x: faixa.vaoFim
        y: faixa.height - 1
        width: Math.max(0, faixa.width - faixa.vaoFim)
        height: 1
        color: faixa.corLinha
    }

    ListView {
        id: lista
        x: faixa.margem
        anchors.bottom: parent.bottom
        height: faixa.alturaAba
        width: Math.max(0, Math.min(contentWidth, faixa.disponivel))
        orientation: ListView.Horizontal
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        model: janela.abas
        currentIndex: janela.atual
        highlightFollowsCurrentItem: false
        cacheBuffer: 4000
        onCurrentIndexChanged: Qt.callLater(lista.mostrarAtual)
        onWidthChanged: Qt.callLater(lista.mostrarAtual)

        Behavior on width {
            enabled: janela.iniciado
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        // Rola até a aba de agora ficar à vista (com um pouco de folga).
        function mostrarAtual() {
            if (!currentItem)
                return;
            var folga = Math.round(janela.gu * 1.5);
            var alvo = contentX;
            if (currentItem.x - folga < contentX)
                alvo = currentItem.x - folga;
            else if (currentItem.x + currentItem.width + folga > contentX + width)
                alvo = currentItem.x + currentItem.width + folga - width;
            rolar(alvo);
        }
        function rolar(alvo) {
            var max = Math.max(0, contentWidth - width);
            alvo = Math.max(0, Math.min(max, alvo));
            if (Math.abs(alvo - contentX) < 0.5)
                return;
            animaRolagem.to = alvo;
            animaRolagem.restart();
        }
        NumberAnimation {
            id: animaRolagem
            target: lista
            property: "contentX"
            duration: 240
            easing.type: Easing.OutCubic
        }
        // A rodinha do mouse rola as abas para os lados.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (ev) => {
                var d = ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x;
                lista.rolar((animaRolagem.running ? animaRolagem.to : lista.contentX) - d);
            }
        }

        delegate: Aba {
            larguraAlvo: faixa.larguraAba
            alturaAba: faixa.alturaAba
            dono: faixa
            vista: lista
        }

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "fator"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 150 }
                NumberAnimation { property: "scale"; to: 0.9; duration: 180; easing.type: Easing.OutCubic }
            }
        }
        displaced: Transition {
            NumberAnimation { property: "x"; duration: 220; easing.type: Easing.OutCubic }
        }
        move: Transition {
            NumberAnimation { property: "x"; duration: 200; easing.type: Easing.OutCubic }
        }
        moveDisplaced: Transition {
            NumberAnimation { property: "x"; duration: 200; easing.type: Easing.OutCubic }
        }
    }

    // Setas para rolar quando as abas não cabem.
    Row {
        id: setas
        x: lista.x + lista.width + Math.round(janela.gu * 0.2)
        anchors.verticalCenter: lista.verticalCenter
        visible: faixa.transborda
        spacing: 0
        BotaoIcone {
            width: faixa.ladoBotao
            height: faixa.ladoBotao
            icone: "matsu-voltar-symbolic"
            dica: janela.t("Rolar para a esquerda", "Scroll left")
            ativo: lista.contentX > 0.5
            tamanhoIcone: Math.round(Kirigami.Units.iconSizes.small * 0.85)
            onClicado: lista.rolar(lista.contentX - lista.width * 0.6)
        }
        BotaoIcone {
            width: faixa.ladoBotao
            height: faixa.ladoBotao
            icone: "matsu-seta-symbolic"
            dica: janela.t("Rolar para a direita", "Scroll right")
            ativo: lista.contentX < lista.contentWidth - lista.width - 0.5
            tamanhoIcone: Math.round(Kirigami.Units.iconSizes.small * 0.85)
            onClicado: lista.rolar(lista.contentX + lista.width * 0.6)
        }
    }

    // O + logo depois da última aba.
    BotaoIcone {
        id: mais
        x: (setas.visible ? setas.x + setas.width : lista.x + lista.width) + Math.round(janela.gu * 0.25)
        anchors.verticalCenter: lista.verticalCenter
        width: faixa.ladoBotao
        height: faixa.ladoBotao
        icone: "matsu-mais-symbolic"
        dica: janela.t("Nova aba (Ctrl+T)", "New tab (Ctrl+T)")
        onClicado: janela.novaAba(false)
    }
}
