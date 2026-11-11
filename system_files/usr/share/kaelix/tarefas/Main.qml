// Gerenciador de tarefas do Kaelix: janela de vidro (o papel de parede desfocado
// atrás, em cinza neutro), com a barra de título própria (bolinhas da janela, nome
// e a busca no meio, como no Windows 11) e a lista de assuntos à esquerda:
// Processos, Desempenho e Inicialização. Abre com Ctrl+Shift+Esc, pelo
// kaelix-janela (que dá a identidade da janela, o vidro e a sombra).
//
// Aqui é só o desenho. Quem lê o sistema e fecha os processos é o ajudante.py
// desta pasta: ele fica rodando e manda uma leitura completa por segundo.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.ApplicationWindow {
    id: tarefas

    readonly property int gu: Kirigami.Units.gridUnit
    readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5

    // Português quando o sistema está em português (o ajudante confirma pelo plasma-localerc).
    property string lingua: Qt.locale().name.indexOf("pt") === 0 ? "pt" : "en"
    readonly property bool pt: lingua === "pt"
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }
    readonly property var local: Qt.locale(pt ? "pt_BR" : "en_US")

    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }

    property var dados: null
    property string pagina: "processos"
    property string busca: ""
    property bool recolhida: false
    property int tique: 0
    // Últimos 60 valores de cada gráfico (chave: "cpu", "mem", "disco:sda"...).
    property var historico: ({})
    readonly property int pontos: 60

    // ----- o vidro -----
    // "desfoque": o KWin desfoca o que está atrás. Sem ele, a janela fica opaca.
    property bool desfoque: false
    // A cor e a transparência que a pessoa escolheu para o vidro (kaelix vidro).
    property var vidroConf: ({ cor: "", nivel: "normal" })
    readonly property bool cheia: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property int raio: cheia ? 0 : 10
    readonly property real opacidadeVidro: desfoque ? ({ mais: 0.6, normal: 0.72, menos: 0.85 })[vidroConf.nivel] || 0.72 : 1
    // Cinza neutro, como o Mica do Windows 11: nada do azul do esquema de cores.
    readonly property color fundo: escuro ? Qt.rgba(0.125, 0.125, 0.133, opacidadeVidro) : Qt.rgba(0.953, 0.953, 0.96, opacidadeVidro)
    // O miolo (onde ficam as páginas) é uma camada um pouco mais funda.
    readonly property color miolo: escuro ? Qt.rgba(0, 0, 0, 0.2) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color frente: escuro ? "#ffffff" : "#1a1a1e"
    // Destaque, só em detalhes pequenos (tracinho do escolhido, chave ligada): a cor
    // do vidro que a pessoa escolheu; no vidro padrão, a própria cor da frente.
    readonly property color destaque: vidroConf.cor ? (escuro ? Qt.lighter(vidroConf.cor, 1.25) : vidroConf.cor) : frente
    // A cor da frente com transparência: textos fracos, linhas, fundos de seleção.
    function tinta(a) {
        return Qt.rgba(frente.r, frente.g, frente.b, a);
    }

    // Cores de cada parte, as mesmas nas colunas e nos gráficos.
    readonly property var cores: escuro
        ? ({ cpu: "#45d0c1", mem: "#b18cf5", disco: "#7fcf6a", rede: "#f59f6b", gpu: "#f0729f" })
        : ({ cpu: "#0f9c8e", mem: "#7650dc", disco: "#3d9533", rede: "#d8692a", gpu: "#d23f78" })

    // O "calor" das colunas, como no Windows: um âmbar bem leve, mais forte quanto
    // mais a coisa gasta. Parada, fica sem cor.
    readonly property color brasa: escuro ? "#eab24c" : "#f5b330"
    function calor(valor, cheio) {
        var r = cheio > 0 ? Math.sqrt(Math.min(1, Math.max(0, valor) / cheio)) : 0;
        if (r < 0.15)
            return "transparent";
        var a = escuro ? 0.04 + 0.26 * r : 0.14 + 0.5 * r;
        return Qt.rgba(brasa.r, brasa.g, brasa.b, a);
    }

    title: t("Gerenciador de tarefas", "Task Manager")
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

    // ----- números do jeito da pessoa (vírgula no Brasil) -----
    function num(valor, casas) {
        return Number(valor).toLocaleString(local, "f", casas);
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
    function mbs(b) {
        var v = (Number(b) || 0) / 1048576;
        return num(v, v > 0 && v < 0.05 ? 2 : 1) + " MB/s";
    }
    function bits(b) {
        var v = (Number(b) || 0) * 8;
        if (v >= 1e9)
            return num(v / 1e9, 1) + " Gbps";
        if (v >= 1e6)
            return num(v / 1e6, 1) + " Mbps";
        return num(v / 1e3, 0) + " Kbps";
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
    function porcento(v) {
        return num(v, 0) + "%";
    }
    // Tira acentos e maiúsculas, para a busca achar "area" e "Área".
    function simples(s) {
        var r = String(s).toLowerCase();
        return r.normalize ? r.normalize("NFD").replace(/[̀-ͯ]/g, "") : r;
    }

    function guardar(h, chave, valor) {
        var lista = h[chave] || [];
        lista.push(valor);
        if (lista.length > pontos)
            lista.shift();
        h[chave] = lista;
    }

    function receber(texto) {
        var d;
        try {
            d = JSON.parse(texto);
        } catch (e) {
            return;
        }
        if (d.idioma)
            lingua = d.idioma;
        if (d.vidro && JSON.stringify(d.vidro) !== JSON.stringify(vidroConf))
            vidroConf = d.vidro;
        var h = historico;
        guardar(h, "cpu", d.cpu.uso);
        guardar(h, "mem", d.memoria.total > 0 ? 100 * d.memoria.usada / d.memoria.total : 0);
        for (var i = 0; i < d.discos.length; i++) {
            var k = d.discos[i];
            guardar(h, "disco:" + k.nome, k.ativo);
            guardar(h, "disco-l:" + k.nome, k.leitura);
            guardar(h, "disco-g:" + k.nome, k.gravacao);
        }
        for (var j = 0; j < d.redes.length; j++) {
            var r = d.redes[j];
            guardar(h, "rede-r:" + r.nome, r.rec);
            guardar(h, "rede-e:" + r.nome, r.env);
        }
        for (var p = 0; p < d.placas.length; p++)
            guardar(h, "gpu:" + p, Math.max(0, d.placas[p].uso));
        historico = h;
        dados = d;
        tique++;
    }

    function iniciarVigia() {
        kaelix.iniciar("vigia", comando(["vigiar", "1"]));
    }

    function irPara(nome) {
        for (var i = 0; i < paginas.length; i++) {
            if (paginas[i].id === nome) {
                pagina = nome;
                return;
            }
        }
    }

    readonly property var paginas: [
        { id: "processos", icone: "kaelix-processos-symbolic", nome: t("Processos", "Processes") },
        { id: "desempenho", icone: "kaelix-desempenho-symbolic", nome: t("Desempenho", "Performance") },
        { id: "inicializacao", icone: "kaelix-inicializacao-symbolic", nome: t("Inicialização", "Startup apps") }
    ]

    Connections {
        target: kaelix
        function onLinha(chave, texto) {
            if (chave === "vigia")
                tarefas.receber(texto);
        }
        function onParou(chave, codigo) {
            if (chave === "vigia")
                religar.start();
        }
        function onPedido(argumentos) {
            if (argumentos.length > 0)
                tarefas.irPara(argumentos[0]);
        }
        function onVidroMudou(ligado) {
            tarefas.desfoque = ligado;
        }
    }

    // Se o ajudante cair, volta a ler depois de um instante.
    Timer {
        id: religar
        interval: 2000
        onTriggered: tarefas.iniciarVigia()
    }

    Component.onCompleted: {
        desfoque = kaelix.ativarVidro(tarefas, 10);
        iniciarVigia();
        if (kaelix.argumentos.length > 0)
            irPara(kaelix.argumentos[0]);
    }

    Shortcut {
        sequences: ["Ctrl+1"]
        onActivated: tarefas.pagina = "processos"
    }
    Shortcut {
        sequences: ["Ctrl+2"]
        onActivated: tarefas.pagina = "desempenho"
    }
    Shortcut {
        sequences: ["Ctrl+3"]
        onActivated: tarefas.pagina = "inicializacao"
    }
    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: campo.forceActiveFocus()
    }

    // ----- o vidro: fundo cinza meio transparente, com a linha clara na borda -----
    Rectangle {
        id: vidro
        anchors.fill: parent
        radius: tarefas.raio
        color: tarefas.fundo
        border.width: tarefas.cheia ? 0 : 1
        border.color: tarefas.escuro ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.14)

        // A cor do vidro que a pessoa escolheu, bem de leve.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            visible: tarefas.vidroConf.cor !== ""
            color: tarefas.vidroConf.cor || "transparent"
            opacity: 0.07
        }
    }

    // ----- barra de título: bolinhas, nome do app e a busca no meio -----
    Item {
        id: titulo
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.round(tarefas.gu * 2.7)

        // Arrastar move a janela; dois cliques deixam em tela cheia. Fica atrás
        // das bolinhas e da busca, para não roubar o clique delas.
        Item {
            anchors.fill: parent
            DragHandler {
                target: null
                onActiveChanged: if (active) tarefas.startSystemMove()
            }
            TapHandler {
                onDoubleTapped: tarefas.alternarCheia()
            }
        }

        Row {
            id: bolinhas
            anchors.left: parent.left
            anchors.leftMargin: Math.round(tarefas.gu * 0.75)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            BotaoJanela {
                tipo: "fechar"
                dica: tarefas.t("Fechar", "Close")
                onClicado: tarefas.close()
            }
            BotaoJanela {
                tipo: "minimizar"
                dica: tarefas.t("Minimizar", "Minimize")
                onClicado: tarefas.showMinimized()
            }
            BotaoJanela {
                tipo: "cheia"
                ligado: tarefas.cheia
                dica: tarefas.cheia ? tarefas.t("Sair da tela cheia", "Restore") : tarefas.t("Tela cheia", "Maximize")
                onClicado: tarefas.alternarCheia()
            }
        }

        Row {
            id: nomeApp
            anchors.left: bolinhas.right
            anchors.leftMargin: Math.round(tarefas.gu * 0.9)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(tarefas.gu * 0.45)

            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: Kirigami.Units.iconSizes.small
                height: width
                source: "org.kaelix.tarefas"
                fallback: "kaelix-tarefas"
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: tarefas.title
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                opacity: 0.85
            }
        }

        // Busca em pílula, no meio da barra (como no Windows 11). Buscar leva
        // para Processos.
        Rectangle {
            id: caixaBusca
            readonly property int largura: Math.min(Math.round(tarefas.gu * 22), Math.round(parent.width * 0.38))
            width: largura
            height: Math.round(tarefas.gu * 1.75)
            x: Math.max(nomeApp.x + nomeApp.width + tarefas.gu, Math.round((parent.width - width) / 2))
            anchors.verticalCenter: parent.verticalCenter
            radius: height / 2
            color: tarefas.tinta(campo.activeFocus ? (tarefas.escuro ? 0.1 : 0.04) : (tarefas.escuro ? 0.065 : 0.045))
            border.width: 1
            border.color: campo.activeFocus ? tarefas.destaque : tarefas.tinta(tarefas.escuro ? 0.08 : 0.1)

            Kirigami.Icon {
                id: lupa
                anchors.left: parent.left
                anchors.leftMargin: Math.round(tarefas.gu * 0.65)
                anchors.verticalCenter: parent.verticalCenter
                width: Kirigami.Units.iconSizes.small
                height: width
                source: "kaelix-busca-symbolic"
                isMask: true
                color: tarefas.frente
                opacity: 0.65
            }
            TextInput {
                id: campo
                anchors.left: lupa.right
                anchors.leftMargin: Math.round(tarefas.gu * 0.45)
                anchors.right: limpar.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                color: tarefas.frente
                selectionColor: tarefas.destaque
                selectedTextColor: tarefas.escuro ? "#1a1a1e" : "#ffffff"
                font: Kirigami.Theme.defaultFont
                clip: true
                onTextChanged: {
                    tarefas.busca = text;
                    if (text.length > 0)
                        tarefas.pagina = "processos";
                }
                Keys.onEscapePressed: text = ""
                Accessible.name: tarefas.t("Buscar por nome ou número do processo", "Search by name or process ID")

                Texto {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: campo.text.length === 0
                    text: tarefas.t("Buscar por nome ou PID", "Search by name or PID")
                    opacity: 0.55
                    elide: Text.ElideRight
                }
            }
            Kirigami.Icon {
                id: limpar
                anchors.right: parent.right
                anchors.rightMargin: Math.round(tarefas.gu * 0.55)
                anchors.verticalCenter: parent.verticalCenter
                width: campo.text.length > 0 ? Kirigami.Units.iconSizes.small : 0
                height: Kirigami.Units.iconSizes.small
                source: "kaelix-fechar-symbolic"
                isMask: true
                color: tarefas.frente
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
        width: Math.round(tarefas.gu * (tarefas.recolhida ? 3.4 : 12.5))
        Behavior on width {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(tarefas.gu * 0.4)
            anchors.rightMargin: Math.round(tarefas.gu * 0.4)
            anchors.bottomMargin: Math.round(tarefas.gu * 0.6)
            spacing: 2

            // Recolher e abrir a lista (como o botão de três riscos do Windows).
            ItemLateral {
                Layout.fillWidth: true
                icone: "kaelix-menu-symbolic"
                nome: tarefas.recolhida ? tarefas.t("Abrir a lista", "Expand") : tarefas.t("Recolher a lista", "Collapse")
                soIcone: true
                onAtivado: tarefas.recolhida = !tarefas.recolhida
            }
            Item {
                implicitHeight: Math.round(tarefas.gu * 0.2)
            }

            Repeater {
                model: tarefas.paginas

                ItemLateral {
                    required property var modelData
                    Layout.fillWidth: true
                    icone: modelData.icone
                    nome: modelData.nome
                    soIcone: tarefas.recolhida
                    escolhido: tarefas.pagina === modelData.id
                    onAtivado: tarefas.pagina = modelData.id
                }
            }

            Item {
                Layout.fillHeight: true
            }

            // Resumo embaixo: CPU e memória agora, como uma olhada rápida.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(tarefas.gu * 0.5)
                Layout.rightMargin: Math.round(tarefas.gu * 0.5)
                spacing: Math.round(tarefas.gu * 0.4)
                visible: tarefas.dados !== null && lateral.width > tarefas.gu * 8
                opacity: tarefas.recolhida ? 0 : 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }

                Repeater {
                    model: [
                        { nome: "CPU", cor: tarefas.cores.cpu, valor: tarefas.dados ? tarefas.dados.cpu.uso : 0 },
                        { nome: tarefas.t("Memória", "Memory"), cor: tarefas.cores.mem,
                          valor: tarefas.dados && tarefas.dados.memoria.total > 0 ? 100 * tarefas.dados.memoria.usada / tarefas.dados.memoria.total : 0 }
                    ]

                    ColumnLayout {
                        id: resumo
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Texto {
                                Layout.fillWidth: true
                                text: resumo.modelData.nome
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.7
                            }
                            Texto {
                                text: tarefas.porcento(resumo.modelData.valor)
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.features: { "tnum": 1 }
                                opacity: 0.9
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 3
                            radius: 1.5
                            color: tarefas.tinta(0.1)
                            Rectangle {
                                width: parent.width * Math.min(1, resumo.modelData.valor / 100)
                                height: parent.height
                                radius: 1.5
                                color: resumo.modelData.cor
                                Behavior on width {
                                    NumberAnimation {
                                        duration: Kirigami.Units.longDuration
                                    }
                                }
                            }
                        }
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
        anchors.rightMargin: tarefas.cheia ? 0 : 1
        anchors.bottomMargin: tarefas.cheia ? 0 : 1
        color: tarefas.miolo
        topLeftRadius: Math.round(tarefas.gu * 0.5)
        topRightRadius: 0
        bottomLeftRadius: 0
        bottomRightRadius: Math.max(0, tarefas.raio - 1)
        border.width: 1
        border.color: tarefas.tinta(tarefas.escuro ? 0.07 : 0.08)

        Loader {
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            source: {
                switch (tarefas.pagina) {
                case "desempenho":
                    return "PaginaDesempenho.qml";
                case "inicializacao":
                    return "PaginaInicializacao.qml";
                default:
                    return "PaginaProcessos.qml";
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
            visible: !tarefas.cheia
            z: 100
            width: modelData.w === 0 ? fino : (modelData.w === 1 ? canto : tarefas.width - 2 * canto)
            height: modelData.h === 0 ? fino : (modelData.h === 1 ? canto : tarefas.height - 2 * canto)
            x: modelData.x === 0 ? 0 : (modelData.x === 1 ? canto : tarefas.width - width)
            y: modelData.y === 0 ? 0 : (modelData.y === 1 ? canto : tarefas.height - height)
            cursorShape: modelData.cursor
            acceptedButtons: Qt.LeftButton
            onPressed: tarefas.startSystemResize(modelData.b)
        }
    }
}
