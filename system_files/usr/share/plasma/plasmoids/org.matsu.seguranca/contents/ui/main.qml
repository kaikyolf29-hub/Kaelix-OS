// O escudo do Matsu na bandeja: o ícone muda com o estado (protegido, pausado,
// atenção, sem proteção) e o balão mostra o estado, pausa rápida e o botão para
// abrir a Central de segurança. Quem lê e muda é /usr/libexec/matsu/matsu-seguranca.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: raiz

    readonly property string ajudante: "/usr/libexec/matsu/matsu-seguranca"
    readonly property string icones: "file:///usr/share/matsu/seguranca/icones/"
    property var estado: ({})
    property real agora: Date.now() / 1000
    readonly property string geral: estado.geral || "lendo"
    readonly property bool pt: estado.idioma !== undefined ? estado.idioma === "pt" : Qt.locale().name.indexOf("pt") === 0
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }
    readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    function cor(e) {
        if (e === "protegido")
            return escuro ? "#4fca8c" : "#1d8a50";
        if (e === "pausado" || e === "baixando" || e === "sem-lista")
            return escuro ? "#f1b84f" : "#b06a00";
        if (e === "atencao" || e === "parado" || e === "desligado")
            return escuro ? "#ff8b78" : "#c63f2b";
        return Kirigami.Theme.disabledTextColor;
    }
    readonly property string icone: ({
        "protegido": "matsu-escudo-symbolic",
        "pausado": icones + "escudo-pausa.svg",
        "atencao": icones + "escudo-alerta.svg",
        "parado": icones + "escudo-alerta.svg",
        "desligado": icones + "escudo-desligado.svg",
        "baixando": icones + "escudo-baixar.svg",
        "sem-lista": icones + "escudo-baixar.svg",
        "indisponivel": icones + "escudo-desligado.svg"
    })[geral] || "matsu-escudo-symbolic"
    function falta(ate) {
        var s = Math.max(0, Math.round(ate - agora));
        var m = Math.floor(s / 60), x = s % 60;
        return m + ":" + (x < 10 ? "0" : "") + x;
    }
    readonly property string titulo: ({
        "protegido": t("Protegido", "Protected"),
        "pausado": t("Escudo pausado", "Shield paused"),
        "atencao": t("Ameaça na quarentena", "Threat quarantined"),
        "parado": t("Escudo parado", "Shield stopped"),
        "desligado": t("Escudo desligado", "Shield off"),
        "baixando": t("Baixando a lista de ameaças", "Downloading threat list"),
        "sem-lista": t("Falta a lista de ameaças", "Threat list missing"),
        "indisponivel": t("Sem antivírus", "No antivirus")
    })[geral] || t("Segurança", "Security")
    readonly property string detalhe: {
        if (geral === "pausado")
            return estado.pausaReiniciar ? t("Volta quando você reiniciar", "Back after restart") : t("Volta em ", "Back in ") + falta(estado.pausaAte || 0);
        if (geral === "atencao")
            return t("Abra a Central para ver o arquivo", "Open the center to see the file");
        if (geral === "baixando" && estado.lista && estado.lista.total > 0)
            return Math.round(100 * Math.min(1, estado.lista.baixado / estado.lista.total)) + "%";
        if (geral === "protegido")
            return t("Vigiando os arquivos novos", "Watching new files");
        return "";
    }

    function atualizar() {
        fonte.connectSource(ajudante + " bandeja");
    }
    function fazer(args) {
        fonte.connectSource(ajudante + " " + args);
    }
    function abrir(pagina) {
        fonte.connectSource(ajudante + " central " + (pagina || "inicio"));
        raiz.expanded = false;
    }

    Plasmoid.icon: icone
    Plasmoid.status: geral === "atencao" ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.ActiveStatus
    toolTipMainText: t("Segurança", "Security")
    toolTipSubText: titulo + (detalhe ? "\n" + detalhe : "")

    P5Support.DataSource {
        id: fonte
        engine: "executable"
        connectedSources: []
        onNewData: (origem, dados) => {
            disconnectSource(origem);
            if (origem === raiz.ajudante + " bandeja") {
                try {
                    raiz.estado = JSON.parse(dados["stdout"]);
                } catch (e) {
                    raiz.estado = ({});
                }
            } else {
                raiz.atualizar();
            }
        }
    }
    Timer {
        interval: raiz.expanded || raiz.geral === "pausado" || raiz.geral === "baixando" ? 1000 : 10000
        repeat: true
        running: true
        onTriggered: {
            raiz.agora = Date.now() / 1000;
            raiz.atualizar();
        }
    }
    Component.onCompleted: atualizar()

    compactRepresentation: MouseArea {
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        Accessible.role: Accessible.Button
        Accessible.name: raiz.titulo
        onClicked: (m) => {
            if (m.button === Qt.MiddleButton)
                raiz.abrir("inicio");
            else
                raiz.expanded = !raiz.expanded;
        }
        Kirigami.Icon {
            anchors.fill: parent
            source: raiz.icone
            isMask: true
            color: raiz.geral === "protegido" || raiz.geral === "lendo" ? Kirigami.Theme.textColor : raiz.cor(raiz.geral)
            active: parent.containsMouse
        }
    }

    fullRepresentation: Item {
        readonly property int largura: Kirigami.Units.gridUnit * 16
        Layout.minimumWidth: largura
        Layout.preferredWidth: largura
        Layout.minimumHeight: coluna.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.preferredHeight: Layout.minimumHeight

        ColumnLayout {
            id: coluna
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Rectangle {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.6
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    readonly property color c: raiz.cor(raiz.geral)
                    color: Qt.rgba(c.r, c.g, c.b, 0.16)
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: parent.width * 0.55
                        height: width
                        source: raiz.icone
                        isMask: true
                        color: parent.c
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: raiz.titulo
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: raiz.detalhe
                        opacity: 0.7
                        font.features: { "tnum": 1 }
                        elide: Text.ElideRight
                    }
                }
            }

            // Pausa rápida (ou voltar agora).
            RowLayout {
                Layout.fillWidth: true
                visible: raiz.estado.ligado !== false && raiz.geral !== "indisponivel"
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Button {
                    visible: raiz.geral !== "pausado"
                    Layout.fillWidth: true
                    text: "15 min"
                    icon.source: raiz.icones + "pausa.svg"
                    onClicked: raiz.fazer("pausar 15")
                }
                PlasmaComponents.Button {
                    visible: raiz.geral !== "pausado"
                    Layout.fillWidth: true
                    text: raiz.t("1 hora", "1 hour")
                    icon.source: raiz.icones + "pausa.svg"
                    onClicked: raiz.fazer("pausar 60")
                }
                PlasmaComponents.Button {
                    visible: raiz.geral === "pausado"
                    Layout.fillWidth: true
                    text: raiz.t("Voltar a proteger agora", "Resume protection now")
                    icon.name: "matsu-escudo-symbolic"
                    onClicked: raiz.fazer("retomar")
                }
            }
            PlasmaComponents.Button {
                Layout.fillWidth: true
                visible: raiz.estado.ligado === false
                text: raiz.t("Ligar o escudo", "Turn on the shield")
                icon.name: "matsu-escudo-symbolic"
                onClicked: raiz.fazer("ajuste ligado sim")
            }
            PlasmaComponents.Button {
                Layout.fillWidth: true
                text: raiz.t("Abrir a Central de segurança", "Open the Security center")
                icon.name: "org.matsu.seguranca"
                onClicked: raiz.abrir(raiz.geral === "atencao" ? "historico" : "inicio")
            }
        }
    }
}
