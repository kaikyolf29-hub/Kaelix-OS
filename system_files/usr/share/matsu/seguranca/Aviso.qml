// O aviso de arquivo baixado (o "SmartScreen" do Matsu). Abre quando a pessoa
// tenta abrir um programa que veio da internet e não está na lista de liberados
// (o tratador org.matsu.seguranca.aviso.desktop chama "ajudante.py abrir").
//
// O que fazer de mais seguro é o botão principal ("Não abrir"). "Abrir mesmo
// assim" fica escondido em "Mais informações" e pede a senha da própria pessoa
// (polkit, auth_self); depois o arquivo abre do jeito esperado (AppImage roda,
// script abre no terminal, programa do Windows no Bottles...).
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
    width: gu * 34
    // A altura acompanha o conteúdo (cresce ao abrir "Mais informações").
    height: Math.min(gu * 36, Math.max(gu * 16, painel.implicitHeight + Math.round(gu * 2.7) + Math.round(gu * 1.4) + 2))
    minimumWidth: gu * 28
    minimumHeight: gu * 16
    paginas: []

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
    // "", conferindo, OK, FOUND, SEMLISTA, INDISPONIVEL
    property string escudo: ""
    property string ameaca: ""
    property bool detalhes: false
    property bool abrindo: false
    property bool feito: false
    property bool trancando: false

    readonly property color corModo: modo === "ameaca" ? coral : (modo === "aviso" ? ambar : frente)

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

    readonly property string titulo: {
        switch (modo) {
        case "aviso":
            return t("Abrir um programa baixado da internet?", "Open a program downloaded from the internet?");
        case "ameaca":
            return t("Este arquivo tem uma ameaça", "This file contains a threat");
        case "pacote":
            return t("Os apps do Matsu vêm da Loja", "Matsu apps come from the Store");
        case "biblioteca":
            return t("Isto é uma peça de outro programa", "This is a piece of another program");
        case "sumiu":
            return t("O arquivo não está mais lá", "The file is no longer there");
        case "sem-windows":
            return t("Para programas do Windows, falta o Bottles", "Windows programs need Bottles");
        case "sem-java":
            return t("Falta o Java para abrir este arquivo", "Java is needed to open this file");
        default:
            return t("Conferindo o arquivo…", "Checking the file…");
        }
    }
    readonly property string texto: {
        switch (modo) {
        case "aviso":
            return t("Programas baixados podem ter vírus ou mexer nos seus arquivos. Só abra se você confia em quem fez e no site de onde veio.",
                     "Downloaded programs can carry viruses or tamper with your files. Only open it if you trust who made it and the site it came from.");
        case "ameaca":
            return t("O escudo achou " + ameaca + " nele. Não abra: na quarentena ele fica trancado e não faz nada.",
                     "The shield found " + ameaca + " in it. Don't open it: in quarantine it's locked away and can't do anything.");
        case "pacote":
            return info && info.tipo === "deb"
                ? t("Arquivos .deb são feitos para o Debian e o Ubuntu e não instalam no Matsu. Procure o app na Loja: quase tudo está lá, com atualização automática.",
                    ".deb files are made for Debian and Ubuntu and don't install on Matsu. Look for the app in the Store: almost everything is there, with automatic updates.")
                : t("O sistema do Matsu é uma imagem assinada e não muda por pacotes soltos. Procure o app na Loja: quase tudo está lá, com atualização automática.",
                    "Matsu's system is a signed image and doesn't change through loose packages. Look for the app in the Store: almost everything is there, with automatic updates.");
        case "biblioteca":
            return t("Arquivos .so são partes que outros programas usam. Eles não abrem sozinhos: abra o programa que veio junto.",
                     ".so files are parts other programs use. They don't open by themselves: open the program that came with it.");
        case "sumiu":
            return t("Ele foi apagado ou mudou de lugar antes de abrir.", "It was deleted or moved before opening.");
        case "sem-windows":
            return t("O Bottles roda muitos programas do Windows numa caixa separada. Ele está na Loja, de graça.",
                     "Bottles runs many Windows programs in a separate box. It's free in the Store.");
        case "sem-java":
            return t("Este é um programa em Java e o Java não está instalado. Veja se o app existe na Loja.",
                     "This is a Java program and Java isn't installed. Check whether the app is in the Store.");
        default:
            return "";
        }
    }

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
            } else if (chave === "verificar") {
                janela.escudo = r ? r.resultado : "INDISPONIVEL";
                if (r && r.resultado === "FOUND") {
                    janela.ameaca = r.ameaca;
                    janela.modo = "ameaca";
                }
            } else if (chave === "liberar") {
                janela.abrindo = false;
                if (r && r.ok && r.acao === "aberto") {
                    janela.feito = true;
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

    // ----- o miolo (sem a lista de assuntos, por cima do fundo da janela) -----
    ColumnLayout {
        id: painel
        parent: janela.contentItem
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.round(janela.gu * 2.7) + Math.round(janela.gu * 1.4)
        anchors.leftMargin: Math.round(janela.gu * 1.6)
        anchors.rightMargin: Math.round(janela.gu * 1.6)
        spacing: Math.round(janela.gu * 0.8)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 1)
            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Math.round(janela.gu * 3.4)
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: Qt.rgba(janela.corModo.r, janela.corModo.g, janela.corModo.b, janela.escuro ? 0.16 : 0.12)
                Behavior on color {
                    ColorAnimation { duration: 300 }
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.52)
                    height: width
                    isMask: true
                    color: janela.corModo
                    source: janela.feito ? "matsu-certo-symbolic"
                          : janela.modo === "ameaca" ? janela.ic("escudo-alerta")
                          : janela.modo === "aviso" ? janela.ic("escudo-busca")
                          : janela.modo === "pacote" || janela.modo === "sem-windows" || janela.modo === "sem-java" ? "matsu-apps-symbolic"
                          : "matsu-info-symbolic"
                }
                // Um pulinho quando muda (ameaça achada, tudo certo).
                scale: 1
                Behavior on scale {
                    NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2 }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.3)
                Texto {
                    Layout.fillWidth: true
                    text: janela.titulo
                    font.pixelSize: Math.round(janela.gu * 1.3)
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }
                Texto {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: janela.texto
                    opacity: 0.72
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ----- o arquivo -----
        Cartao {
            Layout.fillWidth: true
            visible: !!janela.info && janela.modo !== "sumiu"
            implicitHeight: colunaArquivo.implicitHeight + Math.round(janela.gu * 1.6)
            Behavior on implicitHeight {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            ColumnLayout {
                id: colunaArquivo
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Math.round(janela.gu * 0.8)
                anchors.leftMargin: Math.round(janela.gu * 1)
                anchors.rightMargin: Math.round(janela.gu * 1)
                spacing: Math.round(janela.gu * 0.5)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.6)
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Layout.preferredWidth
                        source: janela.ic("arquivo")
                        isMask: true
                        color: janela.frente
                        opacity: 0.8
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Texto {
                            Layout.fillWidth: true
                            text: janela.info ? janela.info.nome || "" : ""
                            font.weight: Font.DemiBold
                            elide: Text.ElideMiddle
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: janela.info ? (janela.info.tipoNome || "") + (janela.info.tamanho ? " · " + janela.bytes(janela.info.tamanho) : "") : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: janela.tinta(0.07)
                    visible: janela.modo === "aviso" || janela.modo === "ameaca"
                }
                // De onde veio, a assinatura e o que o escudo achou.
                GridLayout {
                    Layout.fillWidth: true
                    visible: janela.modo === "aviso" || janela.modo === "ameaca"
                    columns: 2
                    columnSpacing: Math.round(janela.gu * 0.8)
                    rowSpacing: Math.round(janela.gu * 0.35)

                    Texto {
                        text: janela.t("Baixado de", "Downloaded from")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.6
                    }
                    Texto {
                        Layout.fillWidth: true
                        readonly property var o: janela.info && janela.info.origem ? janela.info.origem : ({})
                        text: o.site ? o.site : (o.downloads ? janela.t("Pasta Downloads (o site não foi gravado)", "Downloads folder (site not recorded)") : janela.t("Não se sabe", "Unknown"))
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                    }
                    Texto {
                        text: janela.t("Assinatura", "Signature")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.6
                    }
                    Texto {
                        Layout.fillWidth: true
                        readonly property string a: janela.info ? janela.info.assinatura || "" : ""
                        text: a === "sim" ? janela.t("Tem assinatura digital (o Matsu não conhece quem assinou)", "Digitally signed (Matsu doesn't know the signer)")
                            : a === "nao" ? janela.t("Sem assinatura: não dá para saber quem fez", "Unsigned: no way to know who made it")
                            : janela.t("Este tipo de arquivo não tem assinatura", "This file type has no signature")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        wrapMode: Text.WordWrap
                    }
                    Texto {
                        text: janela.t("Escudo", "Shield")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.6
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.35)
                        Girando {
                            Layout.preferredWidth: Math.round(janela.gu * 0.8)
                            Layout.preferredHeight: Layout.preferredWidth
                            visible: janela.escudo === "conferindo"
                        }
                        Rectangle {
                            visible: janela.escudo !== "conferindo"
                            Layout.preferredWidth: Math.round(janela.gu * 0.45)
                            Layout.preferredHeight: Layout.preferredWidth
                            radius: width / 2
                            color: janela.escudo === "OK" ? janela.verde : janela.escudo === "FOUND" ? janela.coral : janela.ambar
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: ({
                                conferindo: janela.t("Conferindo…", "Checking…"),
                                OK: janela.t("Nenhuma ameaça conhecida (isso não garante que é seguro)", "No known threat (that doesn't mean it's safe)"),
                                FOUND: janela.ameaca,
                                SEMLISTA: janela.t("Ainda sem a lista de ameaças: não conferido", "No threat list yet: not checked"),
                                PAUSADO: janela.t("Pausado: não conferido", "Paused: not checked"),
                                INDISPONIVEL: janela.t("Não deu para conferir agora", "Couldn't check right now")
                            })[janela.escudo] || ""
                            color: janela.escudo === "FOUND" ? janela.coral : janela.frente
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Mais informações: o caminho, o SHA-256 e "Abrir mesmo assim".
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: janela.detalhes && (janela.modo === "aviso" || janela.modo === "ameaca")
                    spacing: Math.round(janela.gu * 0.35)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: janela.tinta(0.07)
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: janela.info ? String(janela.info.pasta || "").replace(/^\/home\/[^\/]+/, "~") : ""
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.6
                        elide: Text.ElideMiddle
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.3)
                        Texto {
                            Layout.fillWidth: true
                            text: "SHA-256  " + (janela.info ? janela.info.sha256 || "" : "")
                            font.family: "monospace"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize - 0.5
                            opacity: 0.6
                            wrapMode: Text.WrapAnywhere
                        }
                        BotaoSimbolo {
                            icone: janela.ic("copiar")
                            dica: janela.t("Copiar o SHA-256", "Copy SHA-256")
                            lado: Math.round(janela.gu * 1.6)
                            onClicado: janela.copiar(janela.info.sha256 || "")
                        }
                    }
                    Texto {
                        Layout.fillWidth: true
                        visible: janela.modo === "aviso"
                        text: janela.t("Abrir pede a sua senha. O arquivo entra na lista de liberados e não será mais avisado.",
                                       "Opening asks for your password. The file joins the allowed list and won't be flagged again.")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.6
                        wrapMode: Text.WordWrap
                    }
                    Botao {
                        visible: janela.modo === "aviso"
                        texto: janela.abrindo ? janela.t("Esperando a senha…", "Waiting for password…") : janela.t("Abrir mesmo assim", "Open anyway")
                        icone: janela.ic("abrir-fora")
                        ativo: !janela.abrindo && !janela.feito && janela.escudo !== "conferindo"
                        dica: janela.escudo === "conferindo" ? janela.t("Espere o escudo terminar de conferir", "Wait for the shield to finish") : ""
                        onClicado: janela.abrirMesmoAssim()
                    }
                }
            }
        }

        // ----- os botões -----
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.2)
            Layout.bottomMargin: Math.round(janela.gu * 1.2)
            spacing: Math.round(janela.gu * 0.5)

            Botao {
                visible: janela.modo === "aviso" || janela.modo === "ameaca"
                texto: janela.detalhes ? janela.t("Menos informações", "Less info") : janela.t("Mais informações", "More info")
                icone: "matsu-seta-symbolic"
                iconeNoFim: true
                onClicado: janela.detalhes = !janela.detalhes
            }
            Item {
                Layout.fillWidth: true
            }
            Botao {
                visible: janela.modo === "aviso"
                texto: janela.t("Mover para a quarentena", "Move to quarantine")
                icone: janela.ic("quarentena")
                ativo: !janela.trancando && !janela.feito
                onClicado: janela.trancar()
            }
            BotaoDestaque {
                visible: janela.modo === "aviso"
                texto: janela.t("Não abrir", "Don't open")
                estado: janela.feito ? "feito" : ""
                textoFeito: janela.t("Abrindo", "Opening")
                onClicado: janela.naoAbrir()
            }
            Botao {
                visible: janela.modo === "ameaca"
                texto: janela.t("Fechar", "Close")
                onClicado: janela.proximo()
            }
            BotaoDestaque {
                visible: janela.modo === "ameaca"
                texto: janela.t("Mover para a quarentena", "Move to quarantine")
                icone: janela.ic("quarentena")
                estado: janela.trancando ? "carregando" : (janela.feito ? "feito" : "")
                textoFeito: janela.t("Trancado", "Locked away")
                onClicado: janela.trancar()
            }
            Botao {
                visible: janela.modo === "pacote" || janela.modo === "sem-windows" || janela.modo === "sem-java" || janela.modo === "biblioteca" || janela.modo === "sumiu"
                texto: janela.t("Fechar", "Close")
                onClicado: janela.proximo()
            }
            BotaoDestaque {
                visible: janela.modo === "pacote" || janela.modo === "sem-java"
                texto: janela.t("Abrir a Loja", "Open the Store")
                icone: "matsu-apps-symbolic"
                onClicado: janela.abrirLoja("inicio")
            }
            BotaoDestaque {
                visible: janela.modo === "sem-windows"
                texto: janela.t("Instalar o Bottles", "Install Bottles")
                icone: "matsu-baixar-symbolic"
                onClicado: janela.abrirLoja("com.usebottles.bottles")
            }
        }
    }
}
