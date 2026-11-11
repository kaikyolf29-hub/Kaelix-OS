// Campo de busca da barra do Matsu: uma pílula "Buscar" que abre a busca do
// sistema (apps, arquivos, contas, configurações), a mesma do atalho Alt+Espaço.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: raiz

    preferredRepresentation: fullRepresentation
    toolTipMainText: "Buscar"
    toolTipSubText: "Apps, arquivos e configurações"

    P5Support.DataSource {
        id: comando
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => disconnectSource(fonte)
    }

    function abrirBusca() {
        comando.connectSource("busctl --user call org.kde.krunner /App org.kde.krunner.App display")
    }

    fullRepresentation: MouseArea {
        id: area

        readonly property int largura: Kirigami.Units.gridUnit * 11

        Layout.minimumWidth: largura
        Layout.preferredWidth: largura
        Layout.maximumWidth: largura
        Layout.fillHeight: true
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: "Buscar"
        onClicked: raiz.abrirBusca()
        Keys.onReturnPressed: raiz.abrirBusca()
        Keys.onSpacePressed: raiz.abrirBusca()

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.bottomMargin: Kirigami.Units.smallSpacing
            radius: Math.min(height / 2, Kirigami.Units.gridUnit * 0.7)
            color: Kirigami.Theme.textColor
            opacity: area.pressed ? 0.22 : (area.containsMouse || area.activeFocus ? 0.16 : 0.10)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "search"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                Layout.alignment: Qt.AlignVCenter
            }

            PlasmaComponents.Label {
                text: "Buscar"
                opacity: 0.75
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
