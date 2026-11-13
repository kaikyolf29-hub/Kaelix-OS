// Central de controle do Matsu: rede, Bluetooth, não perturbe, tema, luz
// noturna, som e brilho em um balão só, na ilha da direita (atalho Meta+A).
//
// Aqui é só o desenho. Quem lê e muda o sistema é /usr/libexec/matsu/matsu-central.
// O que a máquina não tem fica escondido: no PC aparece a rede cabeada e não
// aparecem brilho nem bateria; no notebook aparecem Wi-Fi, brilho e bateria.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: raiz

    // Português quando o sistema está em português. O ajudante também diz o
    // idioma (lê o plasma-localerc), porque o programa pode abrir sem ele no ambiente.
    readonly property bool pt: estado.idioma !== undefined ? estado.idioma === "pt"
        : (Qt.locale().name.indexOf("pt") === 0 || Qt.locale().uiLanguages.join(",").indexOf("pt") === 0)
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }

    readonly property string ajudante: "/usr/libexec/matsu/matsu-central"
    property var estado: ({})

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

    // Mostra a mudança na hora, sem esperar o sistema responder.
    function definir(chave, valor) {
        var novo = {};
        for (var k in estado) {
            novo[k] = estado[k];
        }
        novo[chave] = valor;
        estado = novo;
    }

    function atualizar() {
        comando.connectSource(ajudante + " estado");
    }

    function fazer(argumentos) {
        comando.connectSource(ajudante + " " + argumentos);
    }

    function alternar(chave, acao) {
        var ligar = !sim(chave);
        definir(chave, ligar ? "1" : "0");
        fazer(acao + (ligar ? " on" : " off"));
    }

    Plasmoid.icon: "matsu-ajuste-area-de-trabalho"
    toolTipMainText: t("Central de controle", "Control center")

    P5Support.DataSource {
        id: comando
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            if (fonte === raiz.ajudante + " estado") {
                raiz.ler(dados["stdout"]);
            } else {
                raiz.atualizar();
            }
        }
    }

    // Confere o sistema de tempos em tempos: a pílula da barra mostra rede, som
    // e bateria, e precisa acompanhar quando eles mudam.
    Timer {
        interval: raiz.expanded ? 2000 : 5000
        repeat: true
        running: true
        onTriggered: raiz.atualizar()
    }

    Component.onCompleted: atualizar()

    // Ícone da rede: cabo, Wi-Fi com a força do sinal, Wi-Fi desligado ou sem rede.
    readonly property string iconeRede: {
        if (sim("cabo_ligado")) {
            return "matsu-rede-cabo-symbolic";
        }
        if (sim("wifi_tem") && !sim("wifi_ligado")) {
            return "matsu-wifi-desligado-symbolic";
        }
        if (texto("wifi_nome").length > 0) {
            var sinal = numero("wifi_sinal");
            return "matsu-wifi-" + (sinal === 0 || sinal >= 70 ? 3 : sinal >= 40 ? 2 : 1) + "-symbolic";
        }
        return estado["cabo_tem"] === undefined ? "matsu-rede-cabo-symbolic" : "matsu-rede-desconectada-symbolic";
    }
    readonly property string iconeSom: {
        if (!sim("vol_tem") || sim("mudo")) {
            return "matsu-volume-mudo-symbolic";
        }
        var v = numero("vol");
        return v === 0 ? "matsu-volume-0-symbolic" : v < 50 ? "matsu-volume-1-symbolic" : "matsu-volume-2-symbolic";
    }
    readonly property string resumoRede: sim("cabo_ligado") ? t("Rede cabeada conectada", "Wired network connected")
        : texto("wifi_nome").length > 0 ? "Wi-Fi: " + texto("wifi_nome")
        : sim("wifi_tem") && !sim("wifi_ligado") ? t("Wi-Fi desligado", "Wi-Fi off")
        : t("Sem conexão", "Not connected")

    toolTipSubText: {
        var partes = [resumoRede];
        if (sim("vol_tem")) {
            partes.push(sim("mudo") ? t("Som mudo", "Sound muted") : t("Som ", "Sound ") + numero("vol") + "%");
        }
        if (sim("bateria_tem")) {
            partes.push(t("Bateria ", "Battery ") + numero("bateria") + "%" + (sim("carregando") ? t(", carregando", ", charging") : ""));
        }
        return partes.join("\n");
    }

    // Na barra: uma pílula com rede, Bluetooth, som e bateria, como no vídeo da
    // fusão e no Windows 11. Um clique abre a central.
    compactRepresentation: MouseArea {
        id: compacta

        readonly property int icone: Kirigami.Units.iconSizes.small
        readonly property int folga: Math.round(Kirigami.Units.gridUnit * 0.6)

        Layout.minimumWidth: pilula.width + 2
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: raiz.t("Central de controle", "Control center")
        onClicked: raiz.expanded = !raiz.expanded
        onContainsMouseChanged: if (containsMouse) raiz.atualizar()
        Keys.onReturnPressed: raiz.expanded = !raiz.expanded
        Keys.onSpacePressed: raiz.expanded = !raiz.expanded

        Rectangle {
            id: pilula

            readonly property color base: raiz.expanded ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor

            anchors.centerIn: parent
            height: Math.min(compacta.height - 2, Math.round(Kirigami.Units.gridUnit * 2))
            width: icones.implicitWidth + compacta.folga * 2
            radius: Math.round(height * 0.3)
            color: Qt.rgba(base.r, base.g, base.b,
                           raiz.expanded ? 0.42 : (compacta.containsMouse || compacta.activeFocus ? 0.17 : 0.09))
            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
        }

        Row {
            id: icones
            anchors.centerIn: pilula
            spacing: compacta.folga

            Kirigami.Icon {
                width: compacta.icone
                height: compacta.icone
                source: raiz.iconeRede
                isMask: true
                color: Kirigami.Theme.textColor
            }
            Kirigami.Icon {
                visible: raiz.sim("bt_tem") && raiz.sim("bt_ligado")
                width: compacta.icone
                height: compacta.icone
                source: "matsu-bluetooth-symbolic"
                isMask: true
                color: Kirigami.Theme.textColor
            }
            Kirigami.Icon {
                width: compacta.icone
                height: compacta.icone
                source: raiz.iconeSom
                isMask: true
                color: Kirigami.Theme.textColor
                opacity: raiz.sim("vol_tem") ? 1 : 0.5
            }
            Bateria {
                visible: raiz.sim("bateria_tem")
                height: compacta.icone
                nivel: raiz.numero("bateria")
                carregando: raiz.sim("carregando")
            }
        }
    }

    // O balão, como no vídeo da fusão: blocos de liga e desliga, som, brilho e
    // perfil de energia. Embaixo, bateria (no notebook), ajustes, bloquear e desligar.
    fullRepresentation: Item {
        id: cheia

        readonly property int largura: Kirigami.Units.gridUnit * 19
        readonly property int margem: Math.round(Kirigami.Units.gridUnit * 0.35)

        Layout.minimumWidth: largura
        Layout.preferredWidth: largura
        Layout.maximumWidth: largura
        Layout.minimumHeight: coluna.implicitHeight + margem * 2
        Layout.preferredHeight: coluna.implicitHeight + margem * 2
        Layout.maximumHeight: coluna.implicitHeight + margem * 2

        ColumnLayout {
            id: coluna
            anchors.fill: parent
            anchors.margins: cheia.margem
            spacing: Math.round(Kirigami.Units.gridUnit * 0.67)

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Math.round(Kirigami.Units.gridUnit * 0.55)
                rowSpacing: Math.round(Kirigami.Units.gridUnit * 0.55)

                Botao {
                    visible: raiz.sim("wifi_tem")
                    icone: raiz.sim("wifi_ligado") ? "matsu-wifi-3-symbolic" : "matsu-wifi-desligado-symbolic"
                    titulo: "Wi-Fi"
                    detalhe: !raiz.sim("wifi_ligado") ? raiz.t("Desligado", "Off")
                           : raiz.texto("wifi_nome").length > 0 ? raiz.texto("wifi_nome")
                           : raiz.t("Sem conexão", "Not connected")
                    ligado: raiz.sim("wifi_ligado")
                    onAcionado: raiz.alternar("wifi_ligado", "wifi")
                    onDetalhado: raiz.fazer("abrir rede")
                }
                Botao {
                    visible: raiz.sim("cabo_ligado") || !raiz.sim("wifi_tem")
                    icone: raiz.sim("cabo_ligado") ? "matsu-rede-cabo-symbolic" : "matsu-rede-desconectada-symbolic"
                    titulo: raiz.t("Rede por cabo", "Wired network")
                    detalhe: raiz.sim("cabo_ligado") ? raiz.t("Conectada", "Connected") : raiz.t("Sem cabo", "No cable")
                    ligado: raiz.sim("cabo_ligado")
                    onAcionado: raiz.fazer("abrir rede")
                    onDetalhado: raiz.fazer("abrir rede")
                }
                Botao {
                    visible: raiz.sim("bt_tem")
                    icone: "matsu-bluetooth-symbolic"
                    titulo: "Bluetooth"
                    detalhe: raiz.sim("bt_ligado") ? raiz.t("Ligado", "On") : raiz.t("Desligado", "Off")
                    ligado: raiz.sim("bt_ligado")
                    onAcionado: raiz.alternar("bt_ligado", "bluetooth")
                    onDetalhado: raiz.fazer("abrir bluetooth")
                }
                Botao {
                    icone: "matsu-nao-perturbe-symbolic"
                    titulo: raiz.t("Não perturbe", "Do not disturb")
                    detalhe: raiz.sim("dnd") ? raiz.t("Ligado", "On") : raiz.t("Desligado", "Off")
                    ligado: raiz.sim("dnd")
                    onAcionado: raiz.alternar("dnd", "nao-perturbe")
                }
                Botao {
                    icone: "matsu-lua-symbolic"
                    titulo: raiz.t("Modo escuro", "Dark mode")
                    detalhe: raiz.sim("escuro") ? raiz.t("Ligado", "On") : raiz.t("Desligado", "Off")
                    ligado: raiz.sim("escuro")
                    onAcionado: {
                        var escurecer = !raiz.sim("escuro");
                        raiz.definir("escuro", escurecer ? "1" : "0");
                        raiz.fazer("tema " + (escurecer ? "escuro" : "claro"));
                    }
                }
                Botao {
                    icone: "matsu-luz-noturna-symbolic"
                    titulo: raiz.t("Luz noturna", "Night light")
                    detalhe: raiz.sim("noturna") ? raiz.t("Tela mais quente", "Warmer screen") : raiz.t("Desligada", "Off")
                    ligado: raiz.sim("noturna")
                    onAcionado: raiz.alternar("noturna", "luz-noturna")
                }
                // FPS no jogo: a sobreposição da Central de jogos (a mesma chave da
                // página Sobreposição e do atalho Meta+Alt+F). Botão direito abre a página.
                Botao {
                    visible: raiz.sim("fps_tem")
                    icone: "matsu-sobreposicao-symbolic"
                    titulo: raiz.t("FPS no jogo", "In-game FPS")
                    detalhe: raiz.sim("fps_ligado") ? raiz.t("Aparece no jogo", "Shows in games") : raiz.t("Desligado", "Off")
                    ligado: raiz.sim("fps_ligado")
                    onAcionado: raiz.alternar("fps_ligado", "fps")
                    onDetalhado: {
                        raiz.expanded = false;
                        raiz.fazer("abrir sobreposicao");
                    }
                }
                Botao {
                    // Quando sobra um bloco sozinho na última linha (PC sem Wi-Fi e
                    // sem Bluetooth), ele ocupa a linha inteira em vez de deixar um buraco.
                    readonly property int acima: (raiz.sim("wifi_tem") ? 1 : 0)
                        + ((raiz.sim("cabo_ligado") || !raiz.sim("wifi_tem")) ? 1 : 0)
                        + (raiz.sim("bt_tem") ? 1 : 0) + (raiz.sim("fps_tem") ? 1 : 0) + 3
                    Layout.columnSpan: acima % 2 === 0 ? 2 : 1
                    icone: "matsu-barra-symbolic"
                    titulo: raiz.t("Estilo da barra", "Bar style")
                    detalhe: raiz.texto("barra") === "mac" ? "Mac" : raiz.texto("barra") === "windows" ? "Windows" : raiz.t("Fusão", "Fusion")
                    onAcionado: {
                        raiz.expanded = false;
                        raiz.fazer("abrir ajustes barra");
                    }
                }
            }

            Deslizante {
                Layout.fillWidth: true
                visible: raiz.sim("vol_tem")
                icone: raiz.iconeSom
                nome: raiz.t("Som", "Sound")
                valor: raiz.numero("vol")
                botaoClicavel: true
                onMudou: (novo) => {
                    raiz.definir("vol", String(novo));
                    raiz.fazer("volume " + novo);
                }
                onIconeClicado: {
                    raiz.definir("mudo", raiz.sim("mudo") ? "0" : "1");
                    raiz.fazer("mudo");
                }
            }

            Deslizante {
                Layout.fillWidth: true
                visible: raiz.sim("brilho_tem")
                icone: "matsu-brilho-symbolic"
                nome: raiz.t("Brilho", "Brightness")
                valor: raiz.numero("brilho")
                minimo: 1
                onMudou: (novo) => {
                    raiz.definir("brilho", String(novo));
                    raiz.fazer("brilho " + novo);
                }
            }

            Cartao {
                Layout.fillWidth: true
                visible: raiz.sim("perfil_tem")

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: raiz.t("Perfil de energia", "Power profile")
                    font.weight: Font.DemiBold
                }
                Segmentado {
                    Layout.fillWidth: true
                    atual: raiz.texto("perfil")
                    opcoes: [
                        { valor: "power-saver", nome: raiz.t("Economia", "Power saver") },
                        { valor: "balanced", nome: raiz.t("Equilibrado", "Balanced") },
                        { valor: "performance", nome: raiz.t("Desempenho", "Performance"), ativa: raiz.sim("perfil_desempenho") }
                    ]
                    onEscolhido: (valor) => {
                        raiz.definir("perfil", valor);
                        raiz.fazer("perfil " + valor);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Bateria {
                    visible: raiz.sim("bateria_tem")
                    height: Kirigami.Units.iconSizes.small
                    nivel: raiz.numero("bateria")
                    carregando: raiz.sim("carregando")
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                }
                PlasmaComponents.Label {
                    visible: raiz.sim("bateria_tem")
                    text: raiz.numero("bateria") + "%" + (raiz.sim("carregando") ? raiz.t(", carregando", ", charging") : "")
                    opacity: 0.8
                }
                Item {
                    Layout.fillWidth: true
                }
                Repeater {
                    model: [
                        { icone: "matsu-ajustes-symbolic", nome: raiz.t("Ajustes do Matsu", "Matsu Settings"), acao: "abrir ajustes" },
                        { icone: "matsu-cadeado-symbolic", nome: raiz.t("Bloquear", "Lock"), acao: "bloquear" },
                        { icone: "matsu-desligar-symbolic", nome: raiz.t("Desligar", "Power"), acao: "sair" }
                    ]
                    PlasmaComponents.ToolButton {
                        required property var modelData
                        icon.name: modelData.icone
                        text: modelData.nome
                        display: QQC2.AbstractButton.IconOnly
                        QQC2.ToolTip.text: modelData.nome
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        onClicked: {
                            raiz.expanded = false;
                            raiz.fazer(modelData.acao);
                        }
                    }
                }
            }
        }
    }
}
