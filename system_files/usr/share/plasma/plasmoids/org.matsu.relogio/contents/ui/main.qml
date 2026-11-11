// Relógio do Matsu, na ilha da direita: hora em negrito com a data embaixo e o
// sino ao lado, como no vídeo da fusão. Na barra fina do estilo Mac fica tudo
// numa linha só ("ter. 10 de nov.  15:57"), como no Mac.
//
// Um clique no relógio ou no sino abre as notificações e o calendário juntos,
// como no Windows 11. Atalho: Meta+N.
//
// As notificações e o calendário vêm de módulos do KDE e ficam em arquivos
// separados: se um deles faltar, o relógio continua funcionando.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: raiz

    readonly property bool pt: Qt.locale().name.indexOf("pt") === 0 || Qt.locale().uiLanguages.join(",").indexOf("pt") === 0
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }

    readonly property string ajudante: "/usr/libexec/matsu/matsu-central"
    property var agora: new Date()
    property bool silencio: false

    readonly property string hora: agora.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
    // "ter. 10 de nov." em português, "Tue 10 Nov" nas outras línguas.
    readonly property string dataCurta: agora.toLocaleDateString(Qt.locale(), pt ? "ddd d 'de' MMM" : "ddd d MMM")
    readonly property string dataLonga: {
        var s = agora.toLocaleDateString(Qt.locale(), pt ? "dddd, d 'de' MMMM 'de' yyyy" : "dddd, MMMM d, yyyy");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function lerSilencio() {
        comando.connectSource(ajudante + " estado nao-perturbe");
    }

    function alternarSilencio() {
        silencio = !silencio;
        comando.connectSource(ajudante + " nao-perturbe " + (silencio ? "on" : "off"));
    }

    Plasmoid.icon: "preferences-system-time"
    toolTipMainText: hora
    toolTipSubText: dataLonga + (silencio ? "\n" + t("Não perturbe ligado", "Do not disturb is on") : "")

    // Troca a hora quando o minuto vira (confere a cada segundo, sem custo).
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            var d = new Date();
            if (d.getMinutes() !== raiz.agora.getMinutes() || d.getHours() !== raiz.agora.getHours()
                    || d.getDate() !== raiz.agora.getDate()) {
                raiz.agora = d;
            }
        }
    }

    // O sino mostra se o "não perturbe" está ligado.
    Timer {
        interval: raiz.expanded ? 3000 : 15000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: raiz.lerSilencio()
    }

    P5Support.DataSource {
        id: comando
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            if (fonte === raiz.ajudante + " estado nao-perturbe") {
                raiz.silencio = String(dados["stdout"]).indexOf("dnd=1") !== -1;
            } else {
                raiz.lerSilencio();
            }
        }
    }

    compactRepresentation: RowLayout {
        id: compacta

        // Barra fina (estilo Mac): uma linha só.
        readonly property bool umaLinha: height > 0 && height < Kirigami.Units.gridUnit * 1.9
        readonly property int fundo: Math.min(height - 2, Math.round(Kirigami.Units.gridUnit * 2))

        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.maximumWidth: implicitWidth
        Layout.fillHeight: true
        spacing: Math.round(Kirigami.Units.gridUnit * 0.2)

        MouseArea {
            id: areaHora

            Layout.fillHeight: true
            Layout.preferredWidth: (compacta.umaLinha ? linha.implicitWidth : coluna.implicitWidth)
                                   + Kirigami.Units.smallSpacing * 3
            hoverEnabled: true
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: raiz.hora + ", " + raiz.dataLonga
            onClicked: raiz.expanded = !raiz.expanded
            Keys.onReturnPressed: raiz.expanded = !raiz.expanded
            Keys.onSpacePressed: raiz.expanded = !raiz.expanded

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: compacta.fundo
                radius: Math.round(height * 0.3)
                readonly property color base: raiz.expanded ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                color: Qt.rgba(base.r, base.g, base.b,
                               raiz.expanded ? 0.32 : (areaHora.containsMouse || areaHora.activeFocus ? 0.13 : 0))
            }

            // Duas linhas: hora em negrito, data menor e mais clara, alinhadas à direita.
            ColumnLayout {
                id: coluna
                anchors.centerIn: parent
                visible: !compacta.umaLinha
                spacing: 0

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignRight
                    text: raiz.hora
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.weight: Font.DemiBold
                }
                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignRight
                    text: raiz.dataCurta
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                    opacity: 0.78
                }
            }

            // Uma linha (estilo Mac): data e hora lado a lado.
            Row {
                id: linha
                anchors.centerIn: parent
                visible: compacta.umaLinha
                spacing: Kirigami.Units.smallSpacing * 2

                PlasmaComponents.Label {
                    text: raiz.dataCurta
                    opacity: 0.85
                }
                PlasmaComponents.Label {
                    text: raiz.hora
                    font.weight: Font.DemiBold
                }
            }
        }

        MouseArea {
            id: areaSino

            Layout.fillHeight: true
            Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 1.7)
            hoverEnabled: true
            Accessible.role: Accessible.Button
            Accessible.name: raiz.t("Notificações", "Notifications")
            onClicked: raiz.expanded = !raiz.expanded

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: compacta.fundo
                radius: Math.round(height * 0.3)
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                               areaSino.containsMouse ? 0.13 : 0)
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small
                height: width
                source: raiz.silencio ? "matsu-sino-silencio-symbolic" : "matsu-sino-symbolic"
                isMask: true
                color: Kirigami.Theme.textColor
            }
        }
    }

    fullRepresentation: Item {
        id: cheia

        readonly property int largura: Kirigami.Units.gridUnit * 20
        readonly property int margem: Kirigami.Units.largeSpacing

        Layout.minimumWidth: largura
        Layout.preferredWidth: largura
        Layout.maximumWidth: largura
        Layout.minimumHeight: pilha.implicitHeight + margem * 2
        Layout.preferredHeight: pilha.implicitHeight + margem * 2
        Layout.maximumHeight: pilha.implicitHeight + margem * 2

        ColumnLayout {
            id: pilha
            anchors.fill: parent
            anchors.margins: cheia.margem
            spacing: Kirigami.Units.largeSpacing

            Cartao {
                Layout.fillWidth: true

                Loader {
                    id: notificacoes
                    Layout.fillWidth: true
                    source: "Notificacoes.qml"
                    onLoaded: {
                        item.tradutor = raiz.t;
                        item.silencio = Qt.binding(() => raiz.silencio);
                        item.alternarSilencio.connect(raiz.alternarSilencio);
                    }
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: notificacoes.status === Loader.Error
                    text: raiz.t("As notificações não puderam ser carregadas.", "Notifications could not be loaded.")
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                }
            }

            Cartao {
                Layout.fillWidth: true

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 4
                    text: raiz.dataLonga
                    elide: Text.ElideRight
                }
                Loader {
                    id: calendario
                    Layout.fillWidth: true
                    Layout.preferredHeight: status === Loader.Error ? 0 : Kirigami.Units.gridUnit * 14
                    source: "Calendario.qml"
                    onLoaded: item.hoje = Qt.binding(() => raiz.agora)
                }
            }
        }
    }
}
