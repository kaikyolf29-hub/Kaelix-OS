// Ajustes do Matsu: uma janela de ajustes como a do Mac, com a lista de
// assuntos à esquerda (e a busca em cima) e os ajustes do assunto à direita.
// Abre como um app de verdade: "plasmawindowed org.matsu.ajustes".
//
// Aqui é só o desenho. Quem lê e muda o sistema é /usr/libexec/matsu/matsu-central
// (que por sua vez usa "matsu vidro" e "matsu barra"). O que é mais raro de
// mexer abre a tela de ajustes do KDE daquele assunto.
// Acabamento: o fundo do assunto escolhido desliza na lista, e a página nova
// entra subindo de leve.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: ajustes

    // Português quando o sistema está em português. O ajudante também diz o
    // idioma (lê o plasma-localerc), porque o programa pode abrir sem ele no ambiente.
    readonly property bool pt: estado.idioma !== undefined ? estado.idioma === "pt"
        : (Qt.locale().name.indexOf("pt") === 0 || Qt.locale().uiLanguages.join(",").indexOf("pt") === 0)
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }

    readonly property string ajudante: "/usr/libexec/matsu/matsu-central"
    property var estado: ({})
    property var papeis: []
    // Apps fixados na barra ({app, nome, icone, desk}) e todos os apps para escolher.
    property var fixados: []
    property var instalados: []
    // Quantos apps cabem na barra (0 = a barra não disse) e o estilo dela.
    property int limiteFixados: 0
    property string estiloDoLimite: ""
    readonly property bool barraCheia: limiteFixados > 0 && fixados.length >= limiteFixados
    // Mudanças nos fixados ainda indo para a barra: enquanto houver, a lista da
    // tela não é trocada pela lida da barra (evita piscar a ordem velha).
    property int fixadosPendentes: 0
    // Cada leitura dos fixados tem o seu número (o "#n" no fim é comentário para
    // o shell), e uma leitura que começou antes da última mudança é jogada fora.
    property int leituras: 0
    property var inicioLeitura: ({})
    property double ultimaMudanca: 0
    property string versao: ""
    // Sua conta: usuario, nome e foto (do "matsu-central conta").
    property var conta: ({})
    property int contaVersao: 0
    // A foto que a pessoa escolheu agora (a página recorta e manda gravar).
    property string fotoEscolhida: ""
    property string pagina: "aparencia"
    // Uma parte da página para mostrar ao abrir ("apps": os apps da barra).
    property string secao: ""
    property string busca: ""

    function texto(chave) {
        return estado[chave] !== undefined ? estado[chave] : "";
    }
    function sim(chave) {
        return estado[chave] === "1";
    }
    function numero(chave) {
        var n = parseInt(estado[chave], 10);
        return isNaN(n) ? 0 : n;
    }

    // Lê as linhas "chave=valor" do ajudante.
    function ler(saida) {
        var novo = {};
        var linhas = String(saida || "").split("\n");
        for (var i = 0; i < linhas.length; i++) {
            var p = linhas[i].indexOf("=");
            if (p > 0) {
                novo[linhas[i].substring(0, p)] = linhas[i].substring(p + 1);
            }
        }
        estado = novo;
    }

    // Lê a lista de papéis de parede: "papel|pasta|nome|miniatura".
    function lerPapeis(saida) {
        var lista = [];
        var linhas = String(saida || "").split("\n");
        for (var i = 0; i < linhas.length; i++) {
            var partes = linhas[i].split("|");
            if (partes.length >= 4 && partes[0] === "papel") {
                lista.push({ pasta: partes[1], nome: partes[2], miniatura: partes[3] });
            }
        }
        papeis = lista;
    }

    // Lê os apps fixados: "fixado|app|nome|ícone|atalho".
    function lerFixados(saida) {
        if (fixadosPendentes > 0) {
            return;
        }
        var lista = [];
        var linhas = String(saida || "").split("\n");
        for (var i = 0; i < linhas.length; i++) {
            var partes = linhas[i].split("|");
            if (partes.length >= 4 && partes[0] === "fixado") {
                lista.push({ app: partes[1], nome: partes[2], icone: partes[3], desk: partes[4] || "" });
            } else if (partes.length >= 2 && partes[0] === "limite") {
                limiteFixados = parseInt(partes[1], 10) || 0;
                estiloDoLimite = partes[2] || "";
            }
        }
        fixados = lista;
    }

    // Lê todos os apps que dá para fixar: "app|app|nome|ícone".
    function lerInstalados(saida) {
        var lista = [];
        var linhas = String(saida || "").split("\n");
        for (var i = 0; i < linhas.length; i++) {
            var partes = linhas[i].split("|");
            if (partes.length >= 4 && partes[0] === "app") {
                lista.push({ app: partes[1], nome: partes[2], icone: partes[3], desk: partes[1].replace("applications:", "") });
            }
        }
        instalados = lista;
    }

    // As mudanças nos fixados aparecem na hora e depois vão para a barra.
    function mudarFixados(lista, argumentos) {
        fixados = lista;
        fixadosPendentes += 1;
        fazer(argumentos);
    }
    function moverFixado(indice, passo) {
        var destino = indice + passo;
        if (destino < 0 || destino >= fixados.length) {
            return;
        }
        var lista = fixados.slice();
        var app = lista.splice(indice, 1)[0];
        lista.splice(destino, 0, app);
        var ordem = [];
        for (var i = 0; i < lista.length; i++) {
            ordem.push(lista[i].app);
        }
        mudarFixados(lista, "ordem " + aspas(ordem.join(",")));
    }
    function tirarFixado(app) {
        mudarFixados(fixados.filter(function (x) { return x.app !== app; }), "tirar " + aspas(app));
    }
    function fixarApp(item) {
        if (barraCheia) {
            return;
        }
        mudarFixados(fixados.concat([item]), "fixar " + aspas(item.app));
    }
    function fixadosPadrao() {
        fixadosPendentes += 1;
        fazer("fixados-padrao");
    }
    function lerFixadosDaBarra() {
        leituras += 1;
        var fonte = ajudante + " apps-barra #" + leituras;
        inicioLeitura[fonte] = Date.now();
        comando.connectSource(fonte);
    }

    // Mostra a mudança na hora, sem esperar o sistema responder.
    function definir(chave, valor) {
        var novo = {};
        for (var k in estado) {
            novo[k] = estado[k];
        }
        novo[chave] = valor;
        estado = novo;
    }

    // Põe entre aspas simples para o shell (caminhos com espaço).
    function aspas(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function atualizar() {
        comando.connectSource(ajudante + " estado");
    }
    function lerConta() {
        comando.connectSource(ajudante + " conta");
    }
    function fazer(argumentos) {
        comando.connectSource(ajudante + " " + argumentos);
    }
    function abrir(onde) {
        fazer("abrir " + onde);
    }
    function alternar(chave, acao) {
        var ligar = !sim(chave);
        definir(chave, ligar ? "1" : "0");
        fazer(acao + (ligar ? " on" : " off"));
    }

    // Tira acentos e maiúsculas, para a busca achar "aparencia" e "Aparência".
    function simples(s) {
        var r = String(s).toLowerCase();
        return r.normalize ? r.normalize("NFD").replace(/[̀-ͯ]/g, "") : r;
    }

    // Os assuntos da lista da esquerda, em grupos como no Mac.
    readonly property var paginas: [
        { id: "conta", grupo: -1, cor: "#6e6e76", icone: "matsu-outra-pessoa-symbolic",
          nome: t("Sua conta", "Your account"), chaves: "foto usuario usuaria senha nome perfil avatar pessoa login" },
        { id: "rede", grupo: 0, cor: "#2f80ed", icone: "matsu-wifi-3-symbolic",
          nome: t("Rede", "Network"), chaves: "wi-fi wifi internet cabo vpn network" },
        { id: "bluetooth", grupo: 0, cor: "#2563eb", icone: "matsu-bluetooth-symbolic",
          nome: "Bluetooth", chaves: "fone teclado mouse controle aparelhos" },
        { id: "notificacoes", grupo: 1, cor: "#ef4444", icone: "matsu-sino-symbolic",
          nome: t("Notificações", "Notifications"), chaves: "nao perturbe avisos sino" },
        { id: "som", grupo: 1, cor: "#ec4899", icone: "matsu-volume-2-symbolic",
          nome: t("Som", "Sound"), chaves: "volume audio fone caixa microfone" },
        { id: "aparencia", grupo: 2, cor: "#3f3f46", icone: "matsu-aparencia-symbolic",
          nome: t("Aparência", "Appearance"), chaves: "tema claro escuro cor vidro transparencia transparente solido destaque efeito" },
        { id: "barra", grupo: 2, cor: "#f59e0b", icone: "matsu-barra-symbolic",
          nome: t("Barra e doca", "Bar and dock"), chaves: "dock doca painel fusao mac windows tamanho ampliar ampliacao lupa zoom animacao pontos monitor monitores telas segunda tela" },
        { id: "papel", grupo: 2, cor: "#0ea5b7", icone: "matsu-papel-symbolic",
          nome: t("Papel de parede", "Wallpaper"), chaves: "fundo imagem foto wallpaper" },
        { id: "telas", grupo: 2, cor: "#8b5cf6", icone: "matsu-tela-symbolic",
          nome: t("Telas", "Displays"), chaves: "monitor resolucao escala brilho luz noturna" },
        { id: "energia", grupo: 3, cor: "#22a35a", icone: "matsu-raio-symbolic",
          nome: t("Energia", "Power"), chaves: "bateria perfil desempenho economia suspender" },
        { id: "sobre", grupo: 4, cor: "#6b7280", icone: "matsu-info-symbolic",
          nome: t("Sobre o Matsu", "About Matsu"), chaves: "versao atualizar computador sistema" },
        { id: "mais", grupo: 4, cor: "#6b7280", icone: "matsu-ajustes-symbolic",
          nome: t("Mais ajustes", "More settings"), chaves: "teclado mouse usuarios data hora idioma apps padrao atalhos kde" }
    ]

    function achaPagina(id) {
        for (var i = 0; i < paginas.length; i++) {
            if (paginas[i].id === id) {
                return paginas[i];
            }
        }
        return paginas[0];
    }

    function combina(p) {
        if (busca.length === 0) {
            return true;
        }
        var b = simples(busca);
        return simples(p.nome).indexOf(b) !== -1 || simples(p.chaves).indexOf(b) !== -1;
    }

    Plasmoid.icon: "matsu-ajustes"
    preferredRepresentation: fullRepresentation

    P5Support.DataSource {
        id: comando
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            if (fonte === ajustes.ajudante + " estado") {
                ajustes.ler(dados["stdout"]);
            } else if (fonte === ajustes.ajudante + " papeis") {
                ajustes.lerPapeis(dados["stdout"]);
            } else if (fonte === ajustes.ajudante + " pagina-pedida") {
                var pedido = String(dados["stdout"] || "").trim();
                if (pedido.indexOf("pagina=") === 0) {
                    var pedida = pedido.substring(7);
                    if (pedida === "barra-apps") {
                        ajustes.secao = "apps";
                        pedida = "barra";
                    }
                    ajustes.pagina = pedida;
                }
            } else if (fonte === ajustes.ajudante + " conta") {
                var c = {};
                String(dados["stdout"] || "").split("\n").forEach(function (l) {
                    var i = l.indexOf("=");
                    if (i > 0) c[l.substring(0, i)] = l.substring(i + 1);
                });
                ajustes.conta = c;
            } else if (fonte === ajustes.ajudante + " foto-escolher") {
                var e = String(dados["stdout"] || "").trim();
                if (e.indexOf("escolhida=") === 0 && e.length > 10) {
                    ajustes.fotoEscolhida = e.substring(10);
                }
            } else if (fonte.indexOf(ajustes.ajudante + " foto ") === 0) {
                ajustes.contaVersao += 1;
                ajustes.lerConta();
            } else if (fonte === "matsu versao") {
                ajustes.versao = String(dados["stdout"] || "").trim();
            } else if (fonte.indexOf(ajustes.ajudante + " apps-barra") === 0) {
                var comecou = ajustes.inicioLeitura[fonte] || 0;
                delete ajustes.inicioLeitura[fonte];
                if (comecou >= ajustes.ultimaMudanca) {
                    ajustes.lerFixados(dados["stdout"]);
                }
            } else if (fonte === ajustes.ajudante + " apps-instalados") {
                ajustes.lerInstalados(dados["stdout"]);
            } else if (/^\S+ (fixar|tirar|ordem|fixados-padrao)( |$)/.test(fonte)) {
                ajustes.fixadosPendentes = Math.max(0, ajustes.fixadosPendentes - 1);
                ajustes.ultimaMudanca = Date.now();
                ajustes.lerFixadosDaBarra();
            } else {
                ajustes.atualizar();
                if (fonte.indexOf(ajustes.ajudante + " papel") === 0) {
                    ajustes.fazer("papeis");
                }
            }
        }
    }

    // O sistema pode mudar por fora (pela central, pelo terminal): confere sempre.
    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            ajustes.atualizar();
            comando.connectSource(ajustes.ajudante + " pagina-pedida");
            // Os fixados também mudam por fora (botão direito no menu ou na barra).
            if (ajustes.pagina === "barra" && ajustes.fixadosPendentes === 0) {
                ajustes.lerFixadosDaBarra();
            }
        }
    }

    Component.onCompleted: {
        fazer("papeis");
        lerConta();
        comando.connectSource("matsu versao");
    }

    fullRepresentation: Rectangle {
        id: janela

        readonly property int gu: Kirigami.Units.gridUnit
        readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5

        Layout.minimumWidth: gu * 44
        Layout.minimumHeight: gu * 31
        Layout.preferredWidth: gu * 46
        Layout.preferredHeight: gu * 33
        color: Kirigami.Theme.backgroundColor

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Lista dos assuntos, com a busca em cima.
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: janela.gu * 13
                color: janela.escuro ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(0.36, 0.4, 0.62, 0.07)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.6)
                    spacing: Math.round(janela.gu * 0.6)

                    PlasmaComponents.TextField {
                        id: campoBusca
                        Layout.fillWidth: true
                        placeholderText: ajustes.t("Buscar", "Search")
                        onTextChanged: ajustes.busca = text
                        Accessible.name: ajustes.t("Buscar nos ajustes", "Search settings")
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: lista.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        // O fundo do assunto escolhido: um só, que desliza até o novo.
                        Rectangle {
                            id: marca
                            readonly property Item alvo: {
                                var _p = ajustes.pagina;
                                var _b = ajustes.busca;
                                for (var i = 0; i < repetidorPaginas.count; i++) {
                                    var it = repetidorPaginas.itemAt(i);
                                    if (it && it.escolhido)
                                        return it;
                                }
                                return null;
                            }
                            property bool animar: false
                            visible: alvo !== null && alvo.visible
                            x: lista.x
                            y: alvo ? lista.y + alvo.y : 0
                            width: lista.width
                            height: alvo ? alvo.height : 0
                            radius: Math.round(janela.gu * 0.4)
                            color: Kirigami.Theme.highlightColor
                            Behavior on y {
                                enabled: marca.animar
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Connections {
                                target: ajustes
                                function onPaginaChanged() {
                                    marca.animar = true;
                                    fimMarca.restart();
                                }
                            }
                            Timer {
                                id: fimMarca
                                interval: 400
                                onTriggered: marca.animar = false
                            }
                        }

                        ColumnLayout {
                            id: lista
                            width: parent.width
                            spacing: 2

                            Repeater {
                                id: repetidorPaginas
                                model: ajustes.paginas

                                MouseArea {
                                    id: item

                                    required property var modelData
                                    required property int index
                                    readonly property bool escolhido: ajustes.pagina === modelData.id
                                    readonly property bool novoGrupo: index > 0 && ajustes.paginas[index - 1].grupo !== modelData.grupo

                                    Layout.fillWidth: true
                                    Layout.topMargin: novoGrupo && ajustes.busca.length === 0 ? Math.round(janela.gu * 0.6) : 0
                                    implicitHeight: Math.round(janela.gu * 1.9)
                                    visible: ajustes.combina(modelData)
                                    hoverEnabled: true
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.PageTab
                                    Accessible.name: modelData.nome
                                    Accessible.selected: escolhido
                                    onClicked: ajustes.pagina = modelData.id
                                    Keys.onReturnPressed: ajustes.pagina = modelData.id
                                    Keys.onSpacePressed: ajustes.pagina = modelData.id

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Math.round(janela.gu * 0.4)
                                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                                                       !item.escolhido && (item.containsMouse || item.activeFocus) ? 0.07 : 0)
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Kirigami.Units.shortDuration
                                            }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(janela.gu * 0.35)
                                        anchors.rightMargin: Math.round(janela.gu * 0.35)
                                        spacing: Math.round(janela.gu * 0.5)

                                        // Quadradinho colorido com o ícone branco, como no Mac.
                                        Rectangle {
                                            implicitWidth: Math.round(janela.gu * 1.35)
                                            implicitHeight: implicitWidth
                                            radius: item.modelData.id === "conta" ? width / 2 : Math.round(width * 0.27)
                                            color: item.modelData.cor
                                            border.width: item.escolhido ? 1 : 0
                                            border.color: Qt.rgba(1, 1, 1, 0.5)

                                            Kirigami.Icon {
                                                anchors.centerIn: parent
                                                width: Math.round(parent.width * 0.68)
                                                height: width
                                                visible: !fotoDaConta.visible
                                                source: item.modelData.icone
                                                isMask: true
                                                color: "#ffffff"
                                            }
                                            // Em "Sua conta", a foto da pessoa (ou a primeira letra).
                                            Avatar {
                                                id: fotoDaConta
                                                anchors.fill: parent
                                                visible: item.modelData.id === "conta" && !!ajustes.conta.nome
                                                name: ajustes.conta.nome || ""
                                                source: ajustes.conta.foto ? "file://" + ajustes.conta.foto + "?v=" + ajustes.contaVersao : ""
                                                color: "#6e6e76"
                                                initialsColor: "#ffffff"
                                            }
                                        }
                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true
                                            text: item.modelData.nome
                                            elide: Text.ElideRight
                                            color: item.escolhido ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                            font.weight: item.escolhido ? Font.DemiBold : Font.Normal
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 200
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                Layout.topMargin: janela.gu
                                visible: {
                                    for (var i = 0; i < ajustes.paginas.length; i++) {
                                        if (ajustes.combina(ajustes.paginas[i])) {
                                            return false;
                                        }
                                    }
                                    return true;
                                }
                                text: ajustes.t("Nada encontrado.", "Nothing found.")
                                horizontalAlignment: Text.AlignHCenter
                                opacity: 0.6
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 1
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
            }

            // Os ajustes do assunto escolhido.
            Flickable {
                id: rolagem
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: corpo.implicitHeight + janela.gu * 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                ColumnLayout {
                    id: corpo
                    x: Math.round(janela.gu * 1.4)
                    y: Math.round(janela.gu * 1.1)
                    width: rolagem.width - Math.round(janela.gu * 2.8)
                    spacing: Math.round(janela.gu * 0.9)
                    transform: Translate {
                        id: deslizeCorpo
                    }

                    // A página nova entra aparecendo e subindo de leve.
                    ParallelAnimation {
                        id: entradaPagina
                        NumberAnimation { target: corpo; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                        NumberAnimation { target: deslizeCorpo; property: "y"; from: Math.round(janela.gu * 0.9); to: 0; duration: 320; easing.type: Easing.OutCubic }
                    }

                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 1
                        text: ajustes.achaPagina(ajustes.pagina).nome
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Loader {
                        id: conteudo
                        Layout.fillWidth: true
                        source: {
                            switch (ajustes.pagina) {
                            case "conta": return "PaginaConta.qml";
                            case "rede": return "PaginaRede.qml";
                            case "bluetooth": return "PaginaBluetooth.qml";
                            case "notificacoes": return "PaginaNotificacoes.qml";
                            case "som": return "PaginaSom.qml";
                            case "barra": return "PaginaBarra.qml";
                            case "papel": return "PaginaPapel.qml";
                            case "telas": return "PaginaTelas.qml";
                            case "energia": return "PaginaEnergia.qml";
                            case "sobre": return "PaginaSobre.qml";
                            case "mais": return "PaginaMais.qml";
                            default: return "PaginaAparencia.qml";
                            }
                        }
                        onLoaded: {
                            rolagem.contentY = 0;
                            entradaPagina.restart();
                        }
                    }
                }
            }
        }
    }
}
