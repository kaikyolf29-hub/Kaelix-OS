// A janela dos apps do Matsu (Gerenciador de tarefas, Central de jogos...): vidro
// em cinza neutro (o papel de parede desfocado atrás, como o Mica do Windows 11),
// barra de título própria com as bolinhas, o nome do app e a busca no meio, a lista
// de assuntos à esquerda (recolhível) e o miolo, uma camada mais funda onde ficam
// as páginas. Quem abre é o matsu-janela, que dá a identidade, o vidro e a sombra.
//
// Uso, no Main.qml do app (o id precisa ser "janela": as peças desta pasta usam):
//
//   import "../comum"
//   JanelaMatsu {
//       id: janela
//       title: t("Central de jogos", "Game Center")
//       icone: "org.matsu.jogos"
//       dicaBusca: t("Buscar jogos", "Search games")
//       paginas: [{ id: "inicio", icone: "...", nome: t("Início", "Home") }, ...]
//       conteudo: Qt.resolvedUrl("Pagina" + ... + ".qml")
//   }
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.ApplicationWindow {
    id: janela

    // ----- o que cada app diz -----
    property string icone: ""
    property string iconeReserva: ""
    // Busca em pílula no meio da barra de título (sem dica, sem busca).
    property string dicaBusca: ""
    property string busca: ""
    // Ao digitar na busca, vai para esta página (vazio: fica onde está).
    property string paginaDaBusca: ""
    // Assuntos da lista à esquerda: [{ id, icone, nome }]. Ctrl+1, Ctrl+2... levam a eles.
    property var paginas: []
    property string pagina: paginas.length > 0 ? paginas[0].id : ""
    property bool recolhida: false
    // O arquivo da página aberta agora.
    property url conteudo
    // Algo embaixo da lista de assuntos (some com a lista recolhida).
    property Component rodapeLateral: null
    readonly property alias campoBusca: campo

    readonly property int gu: Kirigami.Units.gridUnit
    readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5

    // Português quando o sistema está em português (o ajudante do app confirma).
    property string lingua: Qt.locale().name.indexOf("pt") === 0 ? "pt" : "en"
    readonly property bool pt: lingua === "pt"
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }
    readonly property var local: Qt.locale(pt ? "pt_BR" : "en_US")

    // ----- o vidro -----
    // "desfoque": o KWin desfoca o que está atrás. Sem ele, a janela fica opaca.
    property bool desfoque: false
    // A cor e a transparência que a pessoa escolheu para o vidro (matsu vidro).
    property var vidroConf: ({ cor: "", nivel: "normal" })
    readonly property bool cheia: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property int raio: cheia ? 0 : 10
    // "Sem vidro" nos Ajustes (nível "sem"): a janela fica sólida mesmo com o desfoque.
    readonly property bool comVidro: desfoque && vidroConf.nivel !== "sem"
    readonly property real opacidadeVidro: comVidro ? ({ mais: 0.6, normal: 0.72, menos: 0.85 })[vidroConf.nivel] || 0.72 : 1
    // Cinza neutro, como o Mica do Windows 11: nada do azul do esquema de cores.
    readonly property color fundo: escuro ? Qt.rgba(0.125, 0.125, 0.133, opacidadeVidro) : Qt.rgba(0.953, 0.953, 0.96, opacidadeVidro)
    // O miolo (onde ficam as páginas) é uma camada um pouco mais funda.
    readonly property color miolo: escuro ? Qt.rgba(0, 0, 0, 0.2) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color frente: escuro ? "#ffffff" : "#1a1a1e"
    // Destaque, só em detalhes pequenos (tracinho do escolhido, chave ligada): a cor
    // do vidro que a pessoa escolheu; no vidro padrão, a própria cor da frente.
    readonly property color destaque: vidroConf.cor ? (escuro ? Qt.lighter(vidroConf.cor, 1.25) : vidroConf.cor) : frente
    // A cor do texto em cima do destaque (quase preto em cor clara, branco em cor escura).
    readonly property color sobreDestaque: (0.299 * destaque.r + 0.587 * destaque.g + 0.114 * destaque.b) > 0.6 ? "#141416" : "#ffffff"
    // A cor da frente com transparência: textos fracos, linhas, fundos de seleção.
    function tinta(a) {
        return Qt.rgba(frente.r, frente.g, frente.b, a);
    }
    // Cartão no miolo (um degrau acima do miolo).
    readonly property color cartao: escuro ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.6)
    readonly property color bordaCartao: tinta(escuro ? 0.07 : 0.08)

    // Cores de cada parte do computador, as mesmas em todo o Matsu.
    readonly property var cores: escuro
        ? ({ cpu: "#45d0c1", mem: "#b18cf5", disco: "#7fcf6a", rede: "#f59f6b", gpu: "#f0729f" })
        : ({ cpu: "#0f9c8e", mem: "#7650dc", disco: "#3d9533", rede: "#d8692a", gpu: "#d23f78" })

    // ----- números do jeito da pessoa (vírgula no Brasil) -----
    function num(valor, casas) {
        return Number(valor).toLocaleString(local, "f", casas === undefined ? 0 : casas);
    }
    function porcento(v) {
        return num(v, 0) + "%";
    }
    function bytes(b) {
        var u = ["B", "KB", "MB", "GB", "TB"];
        var i = 0;
        var v = Number(b) || 0;
        while (v >= 1024 && i < u.length - 1) {
            v /= 1024;
            i++;
        }
        return num(v, i >= 2 ? 1 : 0) + " " + u[i];
    }
    // Dois tamanhos na mesma unidade: "1,6 / 8,0 GB".
    function par(a, b) {
        var u = ["B", "KB", "MB", "GB", "TB"];
        var i = 0;
        var maior = Math.max(Number(a) || 0, Number(b) || 0);
        while (maior >= 1024 && i < u.length - 1) {
            maior /= 1024;
            i++;
        }
        var f = Math.pow(1024, i);
        return num((Number(a) || 0) / f, i >= 2 ? 1 : 0) + " / " + num((Number(b) || 0) / f, i >= 2 ? 1 : 0) + " " + u[i];
    }
    function duracao(segundos) {
        var s = Math.floor(segundos);
        var d = Math.floor(s / 86400);
        s -= d * 86400;
        var h = Math.floor(s / 3600);
        s -= h * 3600;
        var m = Math.floor(s / 60);
        s -= m * 60;
        function dois(n) {
            return n < 10 ? "0" + n : String(n);
        }
        // Fácil de ler: "4 h 14 min", ou "2 d 4 h" depois de um dia; no começo, "3 min 20 s".
        if (d > 0)
            return d + " d " + h + " h";
        if (h > 0)
            return h + " h " + dois(m) + " min";
        return m + " min " + dois(s) + " s";
    }
    // Tira acentos e maiúsculas, para a busca achar "area" e "Área".
    function simples(s) {
        var r = String(s).toLowerCase();
        return r.normalize ? r.normalize("NFD").replace(/[̀-ͯ]/g, "") : r;
    }

    width: gu * 60
    height: gu * 38
    minimumWidth: gu * 40
    minimumHeight: gu * 26
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    background: Item {}

    function alternarCheia() {
        if (cheia)
            showNormal();
        else
            showMaximized();
    }

    // Aviso rápido embaixo, que some sozinho: tipo "" (informação), "certo" ou "erro".
    // Com acao e funcao, mostra um botão (ex.: "Desfazer").
    //   janela.avisoRapido(t("Alarme criado", "Alarm created"), "certo")
    property var _aviso: ({ texto: "", tipo: "", acao: "", funcao: null })
    property bool _avisoAberto: false
    function avisoRapido(texto, tipo, acao, funcao) {
        _aviso = { texto: texto, tipo: tipo || "", acao: acao || "", funcao: funcao || null };
        _avisoAberto = true;
        tempoAviso.interval = tipo === "erro" ? 8000 : (acao ? 6000 : 3500);
        tempoAviso.restart();
    }

    function irPara(nome) {
        for (var i = 0; i < paginas.length; i++) {
            if (paginas[i].id === nome) {
                pagina = nome;
                return true;
            }
        }
        return false;
    }

    Connections {
        target: matsu
        function onVidroMudou(ligado) {
            janela.desfoque = ligado;
        }
    }

    Component.onCompleted: desfoque = matsu.ativarVidro(janela, 10)

    // Ctrl+1, Ctrl+2... levam a cada assunto da lista.
    Instantiator {
        model: janela.paginas.length
        delegate: Shortcut {
            required property int index
            sequences: ["Ctrl+" + (index + 1)]
            onActivated: janela.pagina = janela.paginas[index].id
        }
    }
    Shortcut {
        sequences: [StandardKey.Find]
        enabled: janela.dicaBusca.length > 0
        onActivated: campo.forceActiveFocus()
    }

    // ----- o vidro: fundo cinza meio transparente, com a linha clara na borda -----
    Rectangle {
        id: vidro
        anchors.fill: parent
        radius: janela.raio
        color: janela.fundo
        border.width: janela.cheia ? 0 : 1
        border.color: janela.escuro ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.14)

        // A cor do vidro que a pessoa escolheu, bem de leve.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            visible: janela.vidroConf.cor !== ""
            color: janela.vidroConf.cor || "transparent"
            opacity: 0.07
        }
    }

    // ----- barra de título: bolinhas, nome do app e a busca no meio -----
    Item {
        id: titulo
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.round(janela.gu * 2.7)

        // Arrastar move a janela; dois cliques deixam em tela cheia. Fica atrás
        // das bolinhas e da busca, para não roubar o clique delas.
        Item {
            anchors.fill: parent
            DragHandler {
                target: null
                onActiveChanged: if (active) janela.startSystemMove()
            }
            TapHandler {
                onDoubleTapped: janela.alternarCheia()
            }
        }

        Row {
            id: bolinhas
            anchors.left: parent.left
            anchors.leftMargin: Math.round(janela.gu * 0.75)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            // Mouse em cima de qualquer bolinha (ou no vão entre elas): as três mostram o símbolo.
            HoverHandler {
                id: sobreBolinhas
            }

            BotaoJanela {
                tipo: "fechar"
                mostrar: sobreBolinhas.hovered
                dica: janela.t("Fechar", "Close")
                onClicado: janela.close()
            }
            BotaoJanela {
                tipo: "minimizar"
                mostrar: sobreBolinhas.hovered
                dica: janela.t("Minimizar", "Minimize")
                onClicado: janela.showMinimized()
            }
            BotaoJanela {
                tipo: "cheia"
                mostrar: sobreBolinhas.hovered
                ligado: janela.cheia
                dica: janela.cheia ? janela.t("Sair da tela cheia", "Restore") : janela.t("Tela cheia", "Maximize")
                onClicado: janela.alternarCheia()
            }
        }

        Row {
            id: nomeApp
            anchors.left: bolinhas.right
            anchors.leftMargin: Math.round(janela.gu * 0.9)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(janela.gu * 0.45)

            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: Kirigami.Units.iconSizes.small
                height: width
                visible: janela.icone.length > 0
                source: janela.icone
                fallback: janela.iconeReserva
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: janela.title
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                opacity: 0.85
            }
        }

        // Busca em pílula, no meio da barra (como no Windows 11).
        Rectangle {
            id: caixaBusca
            readonly property int largura: Math.min(Math.round(janela.gu * 22), Math.round(parent.width * 0.38))
            visible: janela.dicaBusca.length > 0
            width: largura
            height: Math.round(janela.gu * 1.75)
            x: Math.max(nomeApp.x + nomeApp.width + janela.gu, Math.round((parent.width - width) / 2))
            anchors.verticalCenter: parent.verticalCenter
            radius: height / 2
            color: janela.tinta(campo.activeFocus ? (janela.escuro ? 0.1 : 0.04) : (janela.escuro ? 0.065 : 0.045))
            border.width: 1
            border.color: campo.activeFocus ? janela.destaque : janela.tinta(janela.escuro ? 0.08 : 0.1)

            Kirigami.Icon {
                id: lupa
                anchors.left: parent.left
                anchors.leftMargin: Math.round(janela.gu * 0.65)
                anchors.verticalCenter: parent.verticalCenter
                width: Kirigami.Units.iconSizes.small
                height: width
                source: "matsu-busca-symbolic"
                isMask: true
                color: janela.frente
                opacity: 0.65
            }
            TextInput {
                id: campo
                anchors.left: lupa.right
                anchors.leftMargin: Math.round(janela.gu * 0.45)
                anchors.right: limpar.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                color: janela.frente
                selectionColor: janela.destaque
                selectedTextColor: janela.escuro ? "#1a1a1e" : "#ffffff"
                font: Kirigami.Theme.defaultFont
                clip: true
                onTextChanged: {
                    janela.busca = text;
                    if (text.length > 0 && janela.paginaDaBusca.length > 0)
                        janela.pagina = janela.paginaDaBusca;
                }
                Keys.onEscapePressed: text = ""
                Accessible.name: janela.dicaBusca

                Texto {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: campo.text.length === 0
                    text: janela.dicaBusca
                    opacity: 0.55
                    elide: Text.ElideRight
                }
            }
            Kirigami.Icon {
                id: limpar
                anchors.right: parent.right
                anchors.rightMargin: Math.round(janela.gu * 0.55)
                anchors.verticalCenter: parent.verticalCenter
                width: campo.text.length > 0 ? Kirigami.Units.iconSizes.small : 0
                height: Kirigami.Units.iconSizes.small
                source: "matsu-fechar-symbolic"
                isMask: true
                color: janela.frente
                opacity: 0.65
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: campo.text = ""
                }
            }
        }
    }

    // ----- lista dos assuntos, no vidro -----
    Item {
        id: lateral
        anchors.top: titulo.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Math.round(janela.gu * (janela.recolhida ? 3.4 : 12.5))
        Behavior on width {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }

        // O fundo do assunto aberto: uma pílula só, que desliza até o novo (e o
        // tracinho estica no caminho, como no Windows 11).
        Rectangle {
            id: pilula
            readonly property Item alvo: {
                for (var i = 0; i < janela.paginas.length; i++)
                    if (janela.paginas[i].id === janela.pagina)
                        return repetidorPaginas.count > i ? repetidorPaginas.itemAt(i) : null;
                return null;
            }
            visible: alvo !== null
            x: colunaLateral.x + (alvo ? alvo.x : 0)
            y: colunaLateral.y + (alvo ? alvo.y : 0)
            width: alvo ? alvo.width : 0
            height: alvo ? alvo.height : 0
            radius: Math.round(janela.gu * 0.3)
            color: janela.tinta(janela.escuro ? 0.08 : 0.065)
            onAlvoChanged: if (visible) esticar.restart()
            Behavior on y {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
            Rectangle {
                id: tracinho
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: Math.round(parent.height * 0.42)
                radius: 1.5
                color: janela.frente
            }
            SequentialAnimation {
                id: esticar
                NumberAnimation { target: tracinho; property: "height"; to: Math.round(pilula.height * 0.7); duration: 110; easing.type: Easing.OutQuad }
                NumberAnimation { target: tracinho; property: "height"; to: Math.round(pilula.height * 0.42); duration: 220; easing.type: Easing.OutBack }
            }
        }

        ColumnLayout {
            id: colunaLateral
            anchors.fill: parent
            anchors.leftMargin: Math.round(janela.gu * 0.4)
            anchors.rightMargin: Math.round(janela.gu * 0.4)
            anchors.bottomMargin: Math.round(janela.gu * 0.6)
            spacing: 2

            // Recolher e abrir a lista (como o botão de três riscos do Windows).
            ItemLateral {
                Layout.fillWidth: true
                icone: "matsu-menu-symbolic"
                nome: janela.recolhida ? janela.t("Abrir a lista", "Expand") : janela.t("Recolher a lista", "Collapse")
                soIcone: true
                onAtivado: janela.recolhida = !janela.recolhida
            }
            Item {
                implicitHeight: Math.round(janela.gu * 0.2)
            }

            Repeater {
                id: repetidorPaginas
                model: janela.paginas

                ItemLateral {
                    required property var modelData
                    Layout.fillWidth: true
                    icone: modelData.icone
                    nome: modelData.nome
                    soIcone: janela.recolhida
                    escolhido: janela.pagina === modelData.id
                    fundoEscolhido: false
                    onAtivado: janela.pagina = modelData.id
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Loader {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(janela.gu * 0.5)
                Layout.rightMargin: Math.round(janela.gu * 0.5)
                sourceComponent: janela.rodapeLateral
                visible: status === Loader.Ready && lateral.width > janela.gu * 8
                opacity: janela.recolhida ? 0 : 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
            }
        }
    }

    // ----- o miolo, uma camada mais funda com o canto de cima arredondado -----
    Rectangle {
        id: painel
        anchors.top: titulo.bottom
        anchors.left: lateral.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: janela.cheia ? 0 : 1
        anchors.bottomMargin: janela.cheia ? 0 : 1
        color: janela.miolo
        topLeftRadius: Math.round(janela.gu * 0.5)
        topRightRadius: 0
        bottomLeftRadius: 0
        bottomRightRadius: Math.max(0, janela.raio - 1)
        border.width: 1
        border.color: janela.tinta(janela.escuro ? 0.07 : 0.08)

        Loader {
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            source: janela.conteudo
        }
    }

    // ----- o aviso rápido embaixo, por cima de tudo -----
    Timer {
        id: tempoAviso
        onTriggered: janela._avisoAberto = false
    }
    Rectangle {
        id: avisoBalao
        readonly property bool mostrar: janela._aviso.texto !== "" && janela._avisoAberto
        readonly property color corTipo: janela._aviso.tipo === "erro" ? (janela.escuro ? "#ff8a8a" : "#c62828")
                                       : (janela._aviso.tipo === "certo" ? (janela.escuro ? "#5fd39a" : "#1f8a52") : janela.frente)
        z: 90
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - (mostrar ? height + Math.round(janela.gu * 1.2) : -Math.round(janela.gu * 0.4))
        width: Math.min(linhaAviso.implicitWidth + linhaAviso.anchors.leftMargin + linhaAviso.anchors.rightMargin + 2,
                        parent.width - janela.gu * 4)
        height: Math.round(janela.gu * 2.5)
        radius: height / 2
        opacity: mostrar ? 1 : 0
        scale: mostrar ? 1 : 0.92
        visible: opacity > 0
        color: janela.escuro ? Qt.rgba(0.18, 0.18, 0.19, 0.98) : Qt.rgba(0.99, 0.99, 1, 0.99)
        border.width: 1
        border.color: janela.tinta(0.12)
        Behavior on y {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
        // Segura os cliques (não passam para o que está embaixo).
        MouseArea {
            anchors.fill: parent
        }
        // Com o mouse em cima, o aviso espera.
        HoverHandler {
            onHoveredChanged: if (hovered) tempoAviso.stop(); else if (avisoBalao.mostrar) tempoAviso.restart()
        }
        RowLayout {
            id: linhaAviso
            anchors.fill: parent
            anchors.leftMargin: Math.round(janela.gu * 0.8)
            anchors.rightMargin: Math.round(janela.gu * (janela._aviso.acao ? 0.4 : 0.9))
            spacing: Math.round(janela.gu * 0.5)
            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                source: janela._aviso.tipo === "erro" ? "matsu-alerta-symbolic" : (janela._aviso.tipo === "certo" ? "matsu-certo-symbolic" : "matsu-info-symbolic")
                isMask: true
                color: avisoBalao.corTipo
            }
            Texto {
                Layout.fillWidth: true
                text: janela._aviso.texto
                elide: Text.ElideRight
            }
            Botao {
                visible: janela._aviso.acao !== ""
                texto: janela._aviso.acao
                onClicado: {
                    tempoAviso.stop();
                    janela._avisoAberto = false;
                    if (janela._aviso.funcao)
                        janela._aviso.funcao();
                }
            }
        }
    }

    // ----- bordas para mudar o tamanho (a janela não tem a borda do sistema) -----
    Repeater {
        model: [
            { b: Qt.LeftEdge, x: 0, y: 1, w: 0, h: 2, cursor: Qt.SizeHorCursor },
            { b: Qt.RightEdge, x: 2, y: 1, w: 0, h: 2, cursor: Qt.SizeHorCursor },
            { b: Qt.TopEdge, x: 1, y: 0, w: 2, h: 0, cursor: Qt.SizeVerCursor },
            { b: Qt.BottomEdge, x: 1, y: 2, w: 2, h: 0, cursor: Qt.SizeVerCursor },
            { b: Qt.TopEdge | Qt.LeftEdge, x: 0, y: 0, w: 1, h: 1, cursor: Qt.SizeFDiagCursor },
            { b: Qt.TopEdge | Qt.RightEdge, x: 2, y: 0, w: 1, h: 1, cursor: Qt.SizeBDiagCursor },
            { b: Qt.BottomEdge | Qt.LeftEdge, x: 0, y: 2, w: 1, h: 1, cursor: Qt.SizeBDiagCursor },
            { b: Qt.BottomEdge | Qt.RightEdge, x: 2, y: 2, w: 1, h: 1, cursor: Qt.SizeFDiagCursor }
        ]

        // x/y: 0 começo, 1 meio, 2 fim; w/h: 0 fino, 1 canto, 2 o lado todo.
        MouseArea {
            required property var modelData
            readonly property int fino: 5
            readonly property int canto: 14
            visible: !janela.cheia
            z: 100
            width: modelData.w === 0 ? fino : (modelData.w === 1 ? canto : janela.width - 2 * canto)
            height: modelData.h === 0 ? fino : (modelData.h === 1 ? canto : janela.height - 2 * canto)
            x: modelData.x === 0 ? 0 : (modelData.x === 1 ? canto : janela.width - width)
            y: modelData.y === 0 ? 0 : (modelData.y === 1 ? canto : janela.height - height)
            cursorShape: modelData.cursor
            acceptedButtons: Qt.LeftButton
            onPressed: janela.startSystemResize(modelData.b)
        }
    }
}
