// Central de controle do Kaelix: rede, Bluetooth, não perturbe, tema, luz
// noturna, som e brilho em um balão só, na ilha da direita (atalho Meta+A).
//
// Aqui é só o desenho. Quem lê e muda o sistema é /usr/libexec/kaelix/kaelix-central.
// O que a máquina não tem fica escondido: no PC aparece a rede cabeada e não
// aparecem brilho nem bateria; no notebook aparecem Wi-Fi, brilho e bateria.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: raiz

    readonly property bool pt: Qt.locale().name.indexOf("pt") === 0
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }

    readonly property string ajudante: "/usr/libexec/kaelix/kaelix-central"
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

    Plasmoid.icon: "configure"
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
            return "kaelix-rede-cabo-symbolic";
        }
        if (sim("wifi_tem") && !sim("wifi_ligado")) {
            return "kaelix-wifi-desligado-symbolic";
        }
        if (texto("wifi_nome").length > 0) {
            var sinal = numero("wifi_sinal");
            return "kaelix-wifi-" + (sinal === 0 || sinal >= 70 ? 3 : sinal >= 40 ? 2 : 1) + "-symbolic";
        }
        return estado["cabo_tem"] === undefined ? "kaelix-rede-cabo-symbolic" : "kaelix-rede-desconectada-symbolic";
    }
    readonly property string iconeSom: {
        if (!sim("vol_tem") || sim("mudo")) {
            return "kaelix-volume-mudo-symbolic";
        }
        var v = numero("vol");
        return v === 0 ? "kaelix-volume-0-symbolic" : v < 50 ? "kaelix-volume-1-symbolic" : "kaelix-volume-2-symbolic";
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
                source: "kaelix-bluetooth-symbolic"
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

    fullRepresentation: Item {
        id: cheia

        readonly property int largura: Kirigami.Units.gridUnit * 21
        readonly property int margem: Kirigami.Units.largeSpacing

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
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 3
                    text: raiz.t("Central de controle", "Control center")
                    elide: Text.ElideRight
                }
                Kirigami.Icon {
                    visible: raiz.sim("bateria_tem")
                    source: raiz.sim("carregando") ? "battery-full-charging" : "battery-full"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
                PlasmaComponents.Label {
                    visible: raiz.sim("bateria_tem")
                    text: raiz.numero("bateria") + "%"
                    opacity: 0.8
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.smallSpacing * 2
                rowSpacing: Kirigami.Units.smallSpacing * 2

                Botao {
                    visible: raiz.sim("wifi_tem")
                    icone: raiz.sim("wifi_ligado") ? "network-wireless" : "network-wireless-disconnected"
                    titulo: "Wi-Fi"
                    detalhe: !raiz.sim("wifi_ligado") ? raiz.t("Desligado", "Off")
                           : raiz.texto("wifi_nome").length > 0 ? raiz.texto("wifi_nome")
                           : raiz.sim("cabo_ligado") ? raiz.t("Usando o cabo", "Using the cable")
                           : raiz.t("Sem conexão", "Not connected")
                    ligado: raiz.sim("wifi_ligado")
                    onAcionado: raiz.alternar("wifi_ligado", "wifi")
                    onDetalhado: raiz.fazer("abrir rede")
                }
                Botao {
                    visible: !raiz.sim("wifi_tem")
                    icone: "network-wired"
                    titulo: raiz.t("Rede cabeada", "Wired network")
                    detalhe: raiz.sim("cabo_ligado") ? raiz.t("Conectada", "Connected") : raiz.t("Sem cabo", "No cable")
                    ligado: raiz.sim("cabo_ligado")
                    onAcionado: raiz.fazer("abrir rede")
                    onDetalhado: raiz.fazer("abrir rede")
                }
                Botao {
                    visible: raiz.sim("bt_tem")
                    icone: "network-bluetooth"
                    titulo: "Bluetooth"
                    detalhe: raiz.sim("bt_ligado") ? raiz.t("Ligado", "On") : raiz.t("Desligado", "Off")
                    ligado: raiz.sim("bt_ligado")
                    onAcionado: raiz.alternar("bt_ligado", "bluetooth")
                    onDetalhado: raiz.fazer("abrir bluetooth")
                }
                Botao {
                    icone: raiz.sim("dnd") ? "notifications-disabled" : "notifications"
                    titulo: raiz.t("Não perturbe", "Do not disturb")
                    detalhe: raiz.sim("dnd") ? raiz.t("Avisos em silêncio", "Notifications silenced") : raiz.t("Desligado", "Off")
                    ligado: raiz.sim("dnd")
                    onAcionado: raiz.alternar("dnd", "nao-perturbe")
                }
                Botao {
                    icone: "weather-clear-night"
                    titulo: raiz.t("Tema escuro", "Dark theme")
                    detalhe: raiz.sim("escuro") ? raiz.t("Ligado", "On") : raiz.t("Desligado", "Off")
                    ligado: raiz.sim("escuro")
                    onAcionado: {
                        var escurecer = !raiz.sim("escuro");
                        raiz.definir("escuro", escurecer ? "1" : "0");
                        raiz.fazer("tema " + (escurecer ? "escuro" : "claro"));
                    }
                }
                Botao {
                    icone: "redshift-status-on"
                    titulo: raiz.t("Luz noturna", "Night light")
                    detalhe: raiz.sim("noturna") ? raiz.t("Tela mais quente", "Warmer screen") : raiz.t("Desligada", "Off")
                    ligado: raiz.sim("noturna")
                    onAcionado: raiz.alternar("noturna", "luz-noturna")
                }
                Botao {
                    icone: "view-split-top-bottom"
                    titulo: raiz.t("Estilo da barra", "Bar style")
                    detalhe: raiz.t("Fusão, Mac ou Windows", "Fusion, Mac or Windows")
                    onAcionado: {
                        raiz.expanded = false;
                        raiz.fazer("abrir barra");
                    }
                }
            }

            Deslizante {
                Layout.fillWidth: true
                visible: raiz.sim("vol_tem")
                icone: raiz.sim("mudo") || raiz.numero("vol") === 0 ? "audio-volume-muted" : "audio-volume-high"
                nome: raiz.t("Volume", "Volume")
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
                icone: "brightness-high"
                nome: raiz.t("Brilho", "Brightness")
                valor: raiz.numero("brilho")
                minimo: 1
                onMudou: (novo) => {
                    raiz.definir("brilho", String(novo));
                    raiz.fazer("brilho " + novo);
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.ToolButton {
                    icon.name: "configure"
                    text: raiz.t("Configurações", "Settings")
                    onClicked: {
                        raiz.expanded = false;
                        raiz.fazer("abrir configuracoes");
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                PlasmaComponents.ToolButton {
                    icon.name: "system-lock-screen"
                    text: raiz.t("Bloquear", "Lock")
                    onClicked: {
                        raiz.expanded = false;
                        raiz.fazer("bloquear");
                    }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "system-shutdown"
                    text: raiz.t("Desligar", "Power")
                    onClicked: {
                        raiz.expanded = false;
                        raiz.fazer("sair");
                    }
                }
            }
        }
    }
}
