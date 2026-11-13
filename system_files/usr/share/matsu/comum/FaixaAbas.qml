// Faixa de abas no topo do miolo (arquivos do Bloco de notas, conversas...), como
// as do Bloco de Notas do Windows 11: a aba aberta tem o fundo da folha e a borda
// fina, com os "pés" curvos que se juntam à folha embaixo (nada de tracinho
// colorido). Esse fundo é um só e desliza até a aba escolhida. As abas encolhem
// até um mínimo e depois rolam (rodinha e setas); o + abre outra. Botão do meio
// fecha, botão direito pede o menu, arrastar muda a ordem.
//
//   FaixaAbas {
//       modelo: abas            // ListModel com o papel "nome" e, se tiver, "modificado"
//                               // (a bolinha •), "carregando" (a rodinha) e "dica"
//       atual: indiceAberto
//       corFolha: corDaFolha    // a cor do que fica embaixo (a aba aberta se junta a ela)
//       onEscolher: (i) => ...; onFechar: (i) => ...; onMover: (de, para) => ...
//       onNova: ...; onMenu: (i, item, x, y) => ...
//   }
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: faixa

    property var modelo
    property int atual: 0
    // A cor da folha embaixo da faixa e a da linha fina (a borda da aba aberta).
    property color corFolha: janela.escuro ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.8)
    property color corLinha: janela.tinta(janela.escuro ? 0.1 : 0.11)
    // Animações de deslizar ligadas (desligue enquanto as abas são montadas ao abrir).
    property bool animar: true
    property bool podeFechar: true
    property bool podeArrastar: true
    property bool botaoNova: true
    property string dicaNova: janela.t("Nova aba (Ctrl+T)", "New tab (Ctrl+T)")
    // O balão de cada aba, a partir dos dados dela (o padrão é o papel "dica").
    property var dicaDe: function (dados) {
        return dados.dica || "";
    }

    signal escolher(int indice)
    signal fechar(int indice)
    signal mover(int de, int para)
    signal nova()
    signal menu(int indice, Item item, real x, real y)

    readonly property int quantas: lista.count
    readonly property int alturaAba: Math.round(janela.gu * 2.05)
    readonly property int raio: Math.round(janela.gu * 0.5)
    readonly property int pe: Math.round(janela.gu * 0.42)
    readonly property int margem: Math.round(janela.gu * 0.6)
    readonly property int ladoBotao: Math.round(janela.gu * 1.75)
    readonly property real minimo: Math.round(janela.gu * 6.5)
    readonly property real maximo: Math.round(janela.gu * 12.5)
    // Espaço das abas: tudo menos as margens, o + e (se rolar) as setas.
    readonly property real livre: width - 2 * margem - (botaoNova ? ladoBotao : 0) - Math.round(janela.gu * 0.3)
    readonly property bool transborda: quantas * minimo > livre
    readonly property real disponivel: livre - (transborda ? 2 * ladoBotao + Math.round(janela.gu * 0.2) : 0)
    readonly property real larguraAba: Math.max(minimo, Math.min(maximo, Math.floor(disponivel / Math.max(1, quantas))))
    // A aba com o mouse em cima (some a linha entre ela e a vizinha).
    property int sob: -1

    // Rola até a aba aberta ficar à vista.
    function mostrarAtual() {
        lista.mostrarAtual();
    }

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
        enabled: faixa.botaoNova
        onDoubleClicked: faixa.nova()
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
                enabled: faixa.animar
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on largura {
                enabled: faixa.animar
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            x: xNaLista - lista.contentX
            width: largura + 2 * p
            height: parent.height
            visible: lista.currentItem !== null && faixa.quantas > 0
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
        model: faixa.modelo
        currentIndex: faixa.atual
        highlightFollowsCurrentItem: false
        cacheBuffer: 4000
        onCurrentIndexChanged: Qt.callLater(lista.mostrarAtual)
        onWidthChanged: Qt.callLater(lista.mostrarAtual)

        Behavior on width {
            enabled: faixa.animar
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

        // Uma aba: o nome e, na ponta, o × (na aba aberta e com o mouse em cima)
        // ou a bolinha • das mudanças não salvas, que vira × com o mouse.
        delegate: MouseArea {
            id: aba

            required property int index
            required property var model
            readonly property string nome: model.nome || ""
            readonly property bool modificado: !!model.modificado
            readonly property bool carregando: !!model.carregando
            // Cresce de 0 a 1 ao nascer (a animação da faixa).
            property real fator: 1

            readonly property bool ativa: ListView.isCurrentItem
            readonly property bool vizinhaAtiva: index + 1 === faixa.atual
            readonly property bool mostrarX: faixa.podeFechar && (containsMouse || (ativa && !modificado))
            property real pressX: 0
            property bool arrastando: false

            width: Math.max(0, faixa.larguraAba * fator)
            height: faixa.alturaAba
            clip: fator < 1
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: arrastando ? Qt.ClosedHandCursor : Qt.ArrowCursor
            Accessible.role: Accessible.PageTab
            Accessible.name: nome
            Accessible.selected: ativa

            onContainsMouseChanged: {
                if (containsMouse)
                    faixa.sob = index;
                else if (faixa.sob === index)
                    faixa.sob = -1;
            }
            onPressed: (m) => {
                if (m.button === Qt.LeftButton) {
                    pressX = m.x;
                    arrastando = false;
                    faixa.escolher(index);
                }
            }
            onReleased: arrastando = false
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton && faixa.podeFechar)
                    faixa.fechar(index);
                else if (m.button === Qt.RightButton)
                    faixa.menu(index, aba, m.x, m.y);
            }
            // Arrastar para os lados troca a aba de lugar.
            onPositionChanged: (m) => {
                if (!faixa.podeArrastar || !(pressedButtons & Qt.LeftButton))
                    return;
                if (!arrastando && Math.abs(m.x - pressX) > Qt.styleHints.startDragDistance)
                    arrastando = true;
                if (!arrastando)
                    return;
                var p = mapToItem(lista.contentItem, m.x, height / 2);
                var alvo = lista.indexAt(p.x, p.y);
                if (alvo >= 0 && alvo !== index)
                    faixa.mover(index, alvo);
            }

            // Fundo com o mouse em cima (a aba aberta já tem o fundo da folha).
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.bottomMargin: 5
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                radius: Math.round(janela.gu * 0.35)
                color: janela.tinta(!aba.ativa && aba.containsMouse ? (aba.pressed ? 0.08 : 0.055) : 0)
                Behavior on color {
                    ColorAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
            }
            // A linha fina entre duas abas fechadas.
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -1
                width: 1
                height: Math.round(parent.height * 0.42)
                color: janela.tinta(janela.escuro ? 0.14 : 0.16)
                opacity: !aba.ativa && !aba.vizinhaAtiva && faixa.sob !== aba.index && faixa.sob !== aba.index + 1 ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(janela.gu * 0.85)
                anchors.rightMargin: Math.round(janela.gu * 0.4)
                spacing: Math.round(janela.gu * 0.35)

                Girando {
                    visible: aba.carregando
                    Layout.preferredWidth: Math.round(janela.gu * 0.8)
                    Layout.preferredHeight: Math.round(janela.gu * 0.8)
                }
                Texto {
                    Layout.fillWidth: true
                    text: aba.nome
                    elide: Text.ElideRight
                    opacity: aba.ativa ? 1 : (aba.containsMouse ? 0.9 : 0.68)
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }
                // O × e a bolinha das mudanças no mesmo lugar.
                MouseArea {
                    id: botaoFechar
                    visible: faixa.podeFechar || aba.modificado
                    Layout.preferredWidth: Math.round(janela.gu * 1.3)
                    Layout.preferredHeight: Math.round(janela.gu * 1.3)
                    hoverEnabled: true
                    enabled: faixa.podeFechar
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: faixa.fechar(aba.index)
                    Accessible.role: Accessible.Button
                    Accessible.name: janela.t("Fechar aba", "Close tab")

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(janela.gu * 0.3)
                        color: janela.tinta(botaoFechar.pressed ? 0.14 : (botaoFechar.containsMouse ? 0.09 : 0))
                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Math.round(Kirigami.Units.iconSizes.small * 0.82)
                        height: width
                        source: "matsu-fechar-symbolic"
                        isMask: true
                        color: janela.frente
                        opacity: aba.mostrarX ? (botaoFechar.containsMouse ? 1 : 0.75) : 0
                        scale: aba.mostrarX ? 1 : 0.5
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(janela.gu * 0.42)
                        height: width
                        radius: width / 2
                        color: janela.frente
                        readonly property bool mostrar: aba.modificado && !aba.mostrarX
                        opacity: mostrar ? 0.8 : 0
                        scale: mostrar ? 1 : 0.2
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Kirigami.Units.longDuration
                                easing.type: Easing.OutBack
                            }
                        }
                    }
                }
            }

            QQC2.ToolTip.visible: containsMouse && !pressed && !botaoFechar.containsMouse && QQC2.ToolTip.text.length > 0
            QQC2.ToolTip.text: faixa.dicaDe(model) || ""
            QQC2.ToolTip.delay: 700
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
        BotaoSimbolo {
            lado: faixa.ladoBotao
            focavel: false
            icone: "matsu-voltar-symbolic"
            dica: janela.t("Rolar para a esquerda", "Scroll left")
            ativo: lista.contentX > 0.5
            tamanhoIcone: Math.round(Kirigami.Units.iconSizes.small * 0.85)
            onClicado: lista.rolar(lista.contentX - lista.width * 0.6)
        }
        BotaoSimbolo {
            lado: faixa.ladoBotao
            focavel: false
            icone: "matsu-seta-symbolic"
            dica: janela.t("Rolar para a direita", "Scroll right")
            ativo: lista.contentX < lista.contentWidth - lista.width - 0.5
            tamanhoIcone: Math.round(Kirigami.Units.iconSizes.small * 0.85)
            onClicado: lista.rolar(lista.contentX + lista.width * 0.6)
        }
    }

    // O + logo depois da última aba.
    BotaoSimbolo {
        id: mais
        x: (setas.visible ? setas.x + setas.width : lista.x + lista.width) + Math.round(janela.gu * 0.25)
        anchors.verticalCenter: lista.verticalCenter
        visible: faixa.botaoNova
        lado: faixa.ladoBotao
        focavel: false
        icone: "matsu-mais-symbolic"
        dica: faixa.dicaNova
        onClicado: faixa.nova()
    }
}
