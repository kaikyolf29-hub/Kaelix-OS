// Ajustes do Kaelix: uma janela de ajustes como a do Mac, com a lista de
// assuntos à esquerda (e a busca em cima) e os ajustes do assunto à direita.
// Abre como um app de verdade: "plasmawindowed org.kaelix.ajustes".
//
// Aqui é só o desenho. Quem lê e muda o sistema é /usr/libexec/kaelix/kaelix-central
// (que por sua vez usa "kaelix vidro" e "kaelix barra"). O que é mais raro de
// mexer abre a tela de ajustes do KDE daquele assunto.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: ajustes

    readonly property bool pt: Qt.locale().name.indexOf("pt") === 0
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }

    readonly property string ajudante: "/usr/libexec/kaelix/kaelix-central"
    property var estado: ({})
    property var papeis: []
    property string versao: ""
    property string pagina: "aparencia"
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
        { id: "rede", grupo: 0, cor: "#2f80ed", icone: "kaelix-wifi-3-symbolic",
          nome: t("Rede", "Network"), chaves: "wi-fi wifi internet cabo vpn network" },
        { id: "bluetooth", grupo: 0, cor: "#2563eb", icone: "kaelix-bluetooth-symbolic",
          nome: "Bluetooth", chaves: "fone teclado mouse controle aparelhos" },
        { id: "notificacoes", grupo: 1, cor: "#ef4444", icone: "kaelix-sino-symbolic",
          nome: t("Notificações", "Notifications"), chaves: "nao perturbe avisos sino" },
        { id: "som", grupo: 1, cor: "#ec4899", icone: "kaelix-volume-2-symbolic",
          nome: t("Som", "Sound"), chaves: "volume audio fone caixa microfone" },
        { id: "aparencia", grupo: 2, cor: "#3f4766", icone: "kaelix-aparencia-symbolic",
          nome: t("Aparência", "Appearance"), chaves: "tema claro escuro cor vidro transparencia destaque" },
        { id: "barra", grupo: 2, cor: "#5468e8", icone: "kaelix-barra-symbolic",
          nome: t("Barra e doca", "Bar and dock"), chaves: "dock painel fusao mac windows tamanho" },
        { id: "papel", grupo: 2, cor: "#0ea5b7", icone: "kaelix-papel-symbolic",
          nome: t("Papel de parede", "Wallpaper"), chaves: "fundo imagem foto wallpaper" },
        { id: "telas", grupo: 2, cor: "#8b5cf6", icone: "kaelix-tela-symbolic",
          nome: t("Telas", "Displays"), chaves: "monitor resolucao escala brilho luz noturna" },
        { id: "energia", grupo: 3, cor: "#22a35a", icone: "kaelix-raio-symbolic",
          nome: t("Energia", "Power"), chaves: "bateria perfil desempenho economia suspender" },
        { id: "sobre", grupo: 4, cor: "#6b7280", icone: "kaelix-info-symbolic",
          nome: t("Sobre o Kaelix", "About Kaelix"), chaves: "versao atualizar computador sistema" },
        { id: "mais", grupo: 4, cor: "#6b7280", icone: "kaelix-ajustes-symbolic",
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

    Plasmoid.icon: "kaelix-configuracoes"
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
                    ajustes.pagina = pedido.substring(7);
                }
            } else if (fonte === "kaelix versao") {
                ajustes.versao = String(dados["stdout"] || "").trim();
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
        }
    }

    Component.onCompleted: {
        fazer("papeis");
        comando.connectSource("kaelix versao");
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

                        ColumnLayout {
                            id: lista
                            width: parent.width
                            spacing: 2

                            Repeater {
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
                                        color: item.escolhido ? Kirigami.Theme.highlightColor
                                             : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                                                       item.containsMouse || item.activeFocus ? 0.07 : 0)
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
                                            radius: Math.round(width * 0.27)
                                            color: item.modelData.cor
                                            border.width: item.escolhido ? 1 : 0
                                            border.color: Qt.rgba(1, 1, 1, 0.5)

                                            Kirigami.Icon {
                                                anchors.centerIn: parent
                                                width: Math.round(parent.width * 0.68)
                                                height: width
                                                source: item.modelData.icone
                                                isMask: true
                                                color: "#ffffff"
                                            }
                                        }
                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true
                                            text: item.modelData.nome
                                            elide: Text.ElideRight
                                            color: item.escolhido ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                            font.weight: item.escolhido ? Font.DemiBold : Font.Normal
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
                        onLoaded: rolagem.contentY = 0
                    }
                }
            }
        }
    }
}
