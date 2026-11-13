// O aviso de arquivo baixado (o "SmartScreen" do Matsu). Abre quando a pessoa
// tenta abrir um programa que veio da internet e não está na lista de liberados
// (o tratador org.matsu.seguranca.aviso.desktop chama "ajudante.py abrir").
//
// Pequeno e centrado, no jeito dos alertas do Mac: o ícone do arquivo com o selo
// do escudo, uma pergunta, uma frase e os botões um embaixo do outro. O resto
// (tipo, assinatura, pasta, SHA-256) fica escondido em "Mais informações".
//
// O que fazer de mais seguro é o botão principal ("Não abrir"). "Abrir mesmo
// assim" fica em "Mais informações" e pede a senha da própria pessoa (polkit,
// auth_self); depois o arquivo abre do jeito esperado (AppImage roda, script abre
// no terminal, programa do Windows no Bottles...).
// Com uma ameaça encontrada, não há "Abrir mesmo assim": só a quarentena.
//
// Roda como org.matsu.seguranca.aviso (uma janela só; outro arquivo entra na fila).
// Argumento: o caminho do arquivo.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

JanelaMatsu {
    id: janela

    title: t("Arquivo baixado", "Downloaded file")
    icone: "org.matsu.seguranca"
    iconeReserva: "matsu-escudo-symbolic"
    paginas: []
    alerta: true

    readonly property int margem: Math.round(gu * 1.4)
    // Tamanho fixo; a altura acompanha o conteúdo (cresce ao abrir "Mais informações").
    readonly property int larguraCerta: Math.round(gu * 18.5)
    readonly property int alturaCerta: Math.min(Math.round(gu * 34), Math.round(painel.implicitHeight) + margem + Math.round(gu * 1.6))
    width: larguraCerta
    height: alturaCerta
    minimumWidth: larguraCerta
    maximumWidth: larguraCerta
    minimumHeight: alturaCerta
    maximumHeight: alturaCerta

    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }
    function ic(nome) {
        return nome.indexOf("matsu-") === 0 ? nome : Qt.resolvedUrl("icones/" + nome + ".svg");
    }
    readonly property color verde: escuro ? "#4fca8c" : "#1d8a50"
    readonly property color ambar: escuro ? "#f1b84f" : "#b06a00"
    readonly property color coral: escuro ? "#ff8b78" : "#c63f2b"

    property string caminho: matsu.argumentos.length > 0 ? String(matsu.argumentos[0]) : ""
    property var fila: []
    property var info: null
    // aviso, ameaca, pacote, biblioteca, sumiu, sem-windows, sem-java
    property string modo: info ? info.modo : ""
    // "", conferindo, OK, FOUND, SEMLISTA, PAUSADO, INDISPONIVEL
    property string escudo: ""
    property string ameaca: ""
    property bool detalhes: false
    property bool abrindo: false
    property bool feito: false
    property bool trancando: false

    readonly property bool deRisco: modo === "aviso" || modo === "ameaca"
    readonly property color corSelo: feito ? verde : (modo === "ameaca" ? coral : ambar)

    function carregar() {
        info = null;
        escudo = "";
        ameaca = "";
        detalhes = false;
        abrindo = false;
        feito = false;
        trancando = false;
        if (caminho)
            matsu.rodar("info", comando(["aviso-info", caminho]));
    }
    // Próximo arquivo da fila, ou fecha.
    function proximo() {
        if (fila.length > 0) {
            var f = fila.slice();
            caminho = f.shift();
            fila = f;
            carregar();
        } else {
            close();
        }
    }
    function naoAbrir() {
        matsu.soltar(comando(["nao-abrir", caminho]));
        proximo();
    }
    function trancar() {
        trancando = true;
        matsu.rodar("trancar", comando(["quarentenar", caminho, ameaca]));
    }
    function abrirMesmoAssim() {
        abrindo = true;
        matsu.rodar("liberar", comando(["liberar", caminho]));
    }
    function abrirLoja(app) {
        matsu.soltar(comando(["loja", app]));
        proximo();
    }
    function copiar(texto) {
        areaCopia.text = texto;
        areaCopia.selectAll();
        areaCopia.copy();
        avisoRapido(t("Copiado", "Copied"), "certo");
    }
    // Nome comprido vira "começo…fim", para a pergunta caber em duas linhas.
    function curto(nome) {
        nome = String(nome || "");
        return nome.length > 34 ? nome.slice(0, 20) + "…" + nome.slice(-11) : nome;
    }

    readonly property string nome: info ? curto(info.nome) : ""
    readonly property string site: info && info.origem && info.origem.site ? String(info.origem.site) : ""

    readonly property string iconeArquivo: {
        var tipo = info ? info.tipo || "" : "";
        if (tipo === "deb" || tipo === "rpm")
            return "matsu-tipo-pacote";
        if (tipo === "script")
            return "matsu-tipo-codigo";
        if (tipo === "biblioteca" || modo === "sumiu" || tipo === "")
            return "matsu-tipo-generico";
        return "matsu-tipo-executavel";
    }

    readonly property string titulo: {
        switch (modo) {
        case "aviso":
            return t("Abrir “" + nome + "”?", "Open “" + nome + "”?");
        case "ameaca":
            return t("“" + nome + "” tem uma ameaça", "“" + nome + "” contains a threat");
        case "pacote":
            return t("Os apps do Matsu vêm da Loja", "Matsu apps come from the Store");
        case "biblioteca":
            return t("Isto é parte de outro programa", "This is part of another program");
        case "sumiu":
            return t("O arquivo não está mais lá", "The file is no longer there");
        case "sem-windows":
            return t("Programas do Windows precisam do Bottles", "Windows programs need Bottles");
        case "sem-java":
            return t("Este programa precisa do Java", "This program needs Java");
        default:
            return t("Conferindo o arquivo…", "Checking the file…");
        }
    }
    readonly property string texto: {
        switch (modo) {
        case "aviso":
            return (site ? t("Baixado de " + site + ".", "Downloaded from " + site + ".") : t("Veio da internet.", "It came from the internet."))
                + " " + t("Só abra se você confia em quem fez.", "Only open it if you trust who made it.");
        case "ameaca":
            return t("O escudo achou " + ameaca + ". Na quarentena ele fica trancado e não faz nada.",
                     "The shield found " + ameaca + ". In quarantine it's locked away and can't do anything.");
        case "pacote":
            return info && info.tipo === "deb"
                ? t("Pacotes .deb são do Debian e do Ubuntu e não instalam aqui. Procure o app na Loja.",
                    ".deb packages are for Debian and Ubuntu and don't install here. Look for the app in the Store.")
                : t("O Matsu não instala pacotes soltos. Procure o app na Loja.",
                    "Matsu doesn't install loose packages. Look for the app in the Store.");
        case "biblioteca":
            return t("Ela não abre sozinha. Abra o programa que veio junto.", "It doesn't open by itself. Open the program that came with it.");
        case "sumiu":
            return t("Ele foi apagado ou mudou de lugar.", "It was deleted or moved.");
        case "sem-windows":
            return t("O Bottles roda programas do Windows e é grátis na Loja.", "Bottles runs Windows programs and is free in the Store.");
        case "sem-java":
            return t("Veja se o app existe na Loja.", "Check whether the app is in the Store.");
        default:
            return "";
        }
    }
    readonly property string textoEscudo: ({
        conferindo: t("Conferindo com o escudo…", "Checking with the shield…"),
        OK: t("O escudo não achou ameaças", "The shield found no threats"),
        SEMLISTA: t("O escudo ainda não tem a lista de ameaças", "The shield has no threat list yet"),
        PAUSADO: t("O escudo está pausado", "The shield is paused"),
        INDISPONIVEL: t("O escudo não conseguiu conferir", "The shield couldn't check it")
    })[escudo] || ""

    Connections {
        target: matsu
        function onPronto(chave, saida, codigo) {
            var r = null;
            try {
                r = JSON.parse(saida);
            } catch (e) {
                r = null;
            }
            if (chave === "info") {
                janela.info = r || { modo: "sumiu", nome: janela.caminho.split("/").pop() };
                if (janela.info.modo === "aviso") {
                    if (janela.info.escudoPausado) {
                        janela.escudo = "PAUSADO";
                    } else {
                        janela.escudo = "conferindo";
                        matsu.rodar("verificar", janela.comando(["aviso-verificar", janela.caminho]));
                    }
                }
                entrada.restart();
            } else if (chave === "verificar") {
                janela.escudo = r ? r.resultado : "INDISPONIVEL";
                if (r && r.resultado === "FOUND") {
                    janela.ameaca = r.ameaca;
                    janela.modo = "ameaca";
                    pulo.restart();
                }
            } else if (chave === "liberar") {
                janela.abrindo = false;
                if (r && r.ok && r.acao === "aberto") {
                    janela.feito = true;
                    pulo.restart();
                    fechar.restart();
                } else if (r && (r.acao === "sem-windows" || r.acao === "sem-java" || r.acao === "pacote")) {
                    janela.modo = r.acao;
                } else if (r && r.cancelado) {
                    janela.avisoRapido(r.erro || janela.t("A confirmação foi fechada.", "The confirmation was closed."));
                } else {
                    janela.avisoRapido(r && r.erro ? r.erro : janela.t("Não deu para abrir.", "Couldn't open it."), "erro");
                }
            } else if (chave === "trancar") {
                janela.trancando = false;
                if (r && r.ok) {
                    janela.feito = true;
                    pulo.restart();
                    janela.avisoRapido(janela.t("Trancado na quarentena", "Locked away in quarantine"), "certo");
                    fechar.restart();
                } else {
                    janela.avisoRapido(r && r.erro ? r.erro : janela.t("Não deu para mover.", "Couldn't move it."), "erro");
                }
            }
        }
        function onPedido(argumentos) {
            if (argumentos.length > 0 && String(argumentos[0]) !== janela.caminho && janela.fila.indexOf(String(argumentos[0])) < 0)
                janela.fila = janela.fila.concat([String(argumentos[0])]);
            janela.raise();
            janela.requestActivate();
        }
    }
    Timer {
        id: fechar
        interval: 1100
        onTriggered: janela.proximo()
    }
    // Para copiar o SHA-256 (a área de transferência passa por um campo de texto).
    TextEdit {
        id: areaCopia
        visible: false
    }
    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: if (janela.modo === "aviso") janela.naoAbrir(); else janela.proximo()
    }

    Component.onCompleted: carregar()

    // Botão de segunda opção: a mesma forma do principal, num cinza de vidro.
    component BotaoCalmo: MouseArea {
        id: calmo
        property string texto: ""
        property bool ativo: true
        property string dica: ""
        signal clicado()
        Layout.fillWidth: true
        implicitHeight: Math.round(janela.gu * 2)
        hoverEnabled: true
        cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
        activeFocusOnTab: ativo
        Accessible.role: Accessible.Button
        Accessible.name: texto
        onClicked: if (ativo) calmo.clicado()
        Keys.onReturnPressed: if (ativo) calmo.clicado()
        Keys.onSpacePressed: if (ativo) calmo.clicado()
        Rectangle {
            anchors.fill: parent
            radius: Math.round(janela.gu * 0.35)
            scale: calmo.pressed && calmo.ativo ? 0.97 : 1
            color: janela.tinta(!calmo.ativo ? 0.05 : (calmo.pressed ? 0.16 : (calmo.containsMouse ? 0.12 : 0.08)))
            border.width: calmo.activeFocus ? 1.5 : 0
            border.color: janela.frente
            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
            Behavior on scale {
                NumberAnimation { duration: 120 }
            }
        }
        Texto {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - janela.gu)
            text: calmo.texto
            elide: Text.ElideRight
            opacity: calmo.ativo ? 1 : 0.4
        }
        QQC2.ToolTip.visible: dica.length > 0 && containsMouse
        QQC2.ToolTip.text: dica
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    // Uma linha de "Mais informações": o nome do dado à esquerda, o valor à direita.
    component LinhaDado: RowLayout {
        property string nome: ""
        property string valor: ""
        Layout.fillWidth: true
        spacing: Math.round(janela.gu * 0.6)
        Texto {
            text: parent.nome
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.55
        }
        Texto {
            Layout.fillWidth: true
            text: parent.valor
            horizontalAlignment: Text.AlignRight
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            elide: Text.ElideMiddle
        }
    }

    // O ícone entra crescendo de leve; o selo pula quando muda (ameaça, aberto).
    ParallelAnimation {
        id: entrada
        NumberAnimation { target: icone; property: "scale"; from: 0.82; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        NumberAnimation { target: icone; property: "opacity"; from: 0; to: 1; duration: 220 }
    }
    SequentialAnimation {
        id: pulo
        NumberAnimation { target: selo; property: "scale"; to: 1.3; duration: 140; easing.type: Easing.OutQuad }
        NumberAnimation { target: selo; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
    }

    // ----- o miolo, direto no vidro -----
    ColumnLayout {
        id: painel
        parent: janela.contentItem
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: janela.margem
        anchors.leftMargin: janela.margem
        anchors.rightMargin: janela.margem
        spacing: 0

        // O arquivo, com o selo do escudo no canto.
        Item {
            id: icone
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(janela.gu * 3.6)
            implicitHeight: implicitWidth
            Kirigami.Icon {
                anchors.fill: parent
                source: janela.iconeArquivo
                fallback: janela.ic("arquivo")
            }
            Rectangle {
                id: selo
                visible: janela.deRisco || janela.feito
                width: Math.round(janela.gu * 1.55)
                height: width
                radius: width / 2
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -Math.round(janela.gu * 0.25)
                anchors.bottomMargin: -Math.round(janela.gu * 0.1)
                color: janela.escuro ? "#2a2a2e" : "#ffffff"
                border.width: 1
                border.color: janela.tinta(0.1)
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: width / 2
                    color: Qt.rgba(janela.corSelo.r, janela.corSelo.g, janela.corSelo.b, janela.escuro ? 0.22 : 0.15)
                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.56)
                    height: width
                    isMask: true
                    color: janela.corSelo
                    source: janela.feito ? "matsu-certo-symbolic" : janela.ic(janela.modo === "ameaca" ? "escudo-alerta" : "escudo-busca")
                }
            }
        }

        Texto {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.9)
            text: janela.titulo
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Math.round(janela.gu * 0.85)
            font.weight: Font.Bold
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
        Texto {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.35)
            visible: text.length > 0
            text: janela.texto
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
            opacity: 0.68
            wrapMode: Text.Wrap
        }

        // O que o escudo achou, numa linha só.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(janela.gu * 0.6)
            visible: janela.modo === "aviso" && janela.textoEscudo.length > 0
            spacing: Math.round(janela.gu * 0.35)
            Girando {
                Layout.preferredWidth: Math.round(janela.gu * 0.7)
                Layout.preferredHeight: Layout.preferredWidth
                visible: janela.escudo === "conferindo"
            }
            Rectangle {
                visible: janela.escudo !== "conferindo"
                Layout.preferredWidth: Math.round(janela.gu * 0.4)
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: janela.escudo === "OK" ? janela.verde : janela.ambar
            }
            Texto {
                Layout.maximumWidth: painel.width - janela.gu
                text: janela.textoEscudo
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.8
                elide: Text.ElideRight
            }
        }

        // ----- os botões, um embaixo do outro -----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 1.1)
            spacing: Math.round(janela.gu * 0.45)
            visible: !!janela.info

            // Aviso: não abrir (o seguro) e quarentena.
            BotaoDestaque {
                Layout.fillWidth: true
                visible: janela.modo === "aviso"
                texto: janela.t("Não abrir", "Don't open")
                estado: janela.feito ? "feito" : ""
                textoFeito: janela.t("Abrindo", "Opening")
                onClicado: janela.naoAbrir()
            }
            BotaoCalmo {
                visible: janela.modo === "aviso"
                texto: janela.t("Pôr na quarentena", "Quarantine it")
                ativo: !janela.trancando && !janela.feito
                onClicado: janela.trancar()
            }
            // Ameaça: só a quarentena ou fechar.
            BotaoDestaque {
                Layout.fillWidth: true
                visible: janela.modo === "ameaca"
                texto: janela.t("Pôr na quarentena", "Quarantine it")
                estado: janela.trancando ? "carregando" : (janela.feito ? "feito" : "")
                textoFeito: janela.t("Trancado", "Locked away")
                onClicado: janela.trancar()
            }
            // Os outros casos: a Loja ou o Bottles, e fechar.
            BotaoDestaque {
                Layout.fillWidth: true
                visible: janela.modo === "pacote" || janela.modo === "sem-java"
                texto: janela.t("Abrir a Loja", "Open the Store")
                onClicado: janela.abrirLoja("inicio")
            }
            BotaoDestaque {
                Layout.fillWidth: true
                visible: janela.modo === "sem-windows"
                texto: janela.t("Instalar o Bottles", "Install Bottles")
                onClicado: janela.abrirLoja("com.usebottles.bottles")
            }
            BotaoDestaque {
                Layout.fillWidth: true
                visible: janela.modo === "biblioteca" || janela.modo === "sumiu"
                texto: "OK"
                onClicado: janela.proximo()
            }
            BotaoCalmo {
                visible: janela.modo === "ameaca" || janela.modo === "pacote" || janela.modo === "sem-java" || janela.modo === "sem-windows"
                texto: janela.t("Fechar", "Close")
                onClicado: janela.proximo()
            }
        }

        // "Mais informações", discreto, no meio.
        MouseArea {
            id: mais
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(janela.gu * 0.55)
            visible: janela.deRisco
            implicitWidth: linhaMais.implicitWidth + Math.round(janela.gu * 0.8)
            implicitHeight: Math.round(janela.gu * 1.4)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: textoMais.text
            onClicked: janela.detalhes = !janela.detalhes
            Keys.onReturnPressed: janela.detalhes = !janela.detalhes
            Keys.onSpacePressed: janela.detalhes = !janela.detalhes
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: janela.tinta(mais.containsMouse ? 0.06 : 0)
                border.width: mais.activeFocus ? 1 : 0
                border.color: janela.frente
            }
            Row {
                id: linhaMais
                anchors.centerIn: parent
                spacing: Math.round(janela.gu * 0.25)
                Texto {
                    id: textoMais
                    anchors.verticalCenter: parent.verticalCenter
                    text: janela.detalhes ? janela.t("Menos informações", "Less info") : janela.t("Mais informações", "More info")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: mais.containsMouse ? 0.9 : 0.6
                }
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(janela.gu * 0.7)
                    height: width
                    source: "matsu-seta-symbolic"
                    isMask: true
                    color: janela.frente
                    opacity: textoMais.opacity
                    rotation: janela.detalhes ? -90 : 90
                    Behavior on rotation {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        // ----- mais informações -----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.45)
            visible: janela.detalhes && janela.deRisco
            spacing: Math.round(janela.gu * 0.45)

            Cartao {
                Layout.fillWidth: true
                implicitHeight: dados.implicitHeight + Math.round(janela.gu * 1.1)
                ColumnLayout {
                    id: dados
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Math.round(janela.gu * 0.8)
                    anchors.rightMargin: Math.round(janela.gu * 0.5)
                    spacing: Math.round(janela.gu * 0.3)
                    LinhaDado {
                        nome: janela.t("Tipo", "Type")
                        valor: janela.info ? (janela.info.tipoNome || "") + (janela.info.tamanho ? " · " + janela.bytes(janela.info.tamanho) : "") : ""
                    }
                    LinhaDado {
                        visible: janela.modo === "aviso"
                        readonly property string a: janela.info ? janela.info.assinatura || "" : ""
                        nome: janela.t("Assinatura", "Signature")
                        valor: a === "sim" ? janela.t("Assinado (quem assinou é desconhecido)", "Signed (unknown signer)")
                             : a === "nao" ? janela.t("Sem assinatura", "Unsigned")
                             : janela.t("Não tem", "None")
                    }
                    LinhaDado {
                        nome: janela.t("Pasta", "Folder")
                        valor: janela.info ? String(janela.info.pasta || "").replace(/^\/home\/[^\/]+/, "~") : ""
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.6)
                        Texto {
                            text: "SHA-256"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.55
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: janela.info ? janela.info.sha256 || "" : ""
                            horizontalAlignment: Text.AlignRight
                            font.family: "monospace"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize - 0.5
                            opacity: 0.7
                            elide: Text.ElideMiddle
                        }
                        BotaoSimbolo {
                            icone: janela.ic("copiar")
                            dica: janela.t("Copiar o SHA-256", "Copy SHA-256")
                            lado: Math.round(janela.gu * 1.4)
                            onClicado: janela.copiar(janela.info.sha256 || "")
                        }
                    }
                }
            }

            BotaoCalmo {
                visible: janela.modo === "aviso"
                texto: janela.abrindo ? janela.t("Esperando a senha…", "Waiting for password…") : janela.t("Abrir mesmo assim", "Open anyway")
                ativo: !janela.abrindo && !janela.feito && janela.escudo !== "conferindo"
                dica: janela.escudo === "conferindo" ? janela.t("Espere o escudo terminar de conferir", "Wait for the shield to finish") : ""
                onClicado: janela.abrirMesmoAssim()
            }
            Texto {
                Layout.fillWidth: true
                visible: janela.modo === "aviso"
                text: janela.t("Pede a sua senha. Depois este arquivo não é mais avisado.",
                               "Asks for your password. This file won't be flagged again.")
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
                wrapMode: Text.Wrap
            }
        }
    }
}
