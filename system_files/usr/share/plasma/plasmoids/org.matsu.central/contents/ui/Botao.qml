// Um bloco da central de controle (como no vídeo da fusão): ícone, nome e uma
// linha de estado. Ligado ele fica com a cor de destaque do Matsu.
// Clique liga e desliga; botão direito (ou segurar) abre os ajustes daquilo.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: botao

    property string icone: ""
    property string titulo: ""
    property string detalhe: ""
    property bool ligado: false
    readonly property color corDoTexto: ligado ? "#ffffff" : Kirigami.Theme.textColor
    readonly property color base: ligado ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor

    signal acionado()
    signal detalhado()

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: Kirigami.Units.gridUnit * 4
    hoverEnabled: true
    activeFocusOnTab: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    Accessible.role: Accessible.Button
    Accessible.name: titulo + ", " + detalhe
    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            botao.detalhado();
        } else {
            botao.acionado();
        }
    }
    onPressAndHold: botao.detalhado()
    Keys.onReturnPressed: botao.acionado()
    Keys.onSpacePressed: botao.acionado()

    Rectangle {
        anchors.fill: parent
        radius: Math.round(Kirigami.Units.gridUnit * 0.9)
        color: Qt.rgba(botao.base.r, botao.base.g, botao.base.b,
                       botao.ligado ? (botao.pressed ? 0.82 : (botao.containsMouse ? 0.92 : 1))
                                    : (botao.pressed ? 0.2 : (botao.containsMouse || botao.activeFocus ? 0.15 : 0.09)))
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.67)
        anchors.rightMargin: Math.round(Kirigami.Units.gridUnit * 0.67)
        spacing: Math.round(Kirigami.Units.gridUnit * 0.55)

        Kirigami.Icon {
            source: botao.icone
            isMask: true
            color: botao.corDoTexto
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: botao.titulo
                color: botao.corDoTexto
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: botao.detalhe
                color: botao.corDoTexto
                opacity: botao.ligado ? 0.88 : 0.72
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                elide: Text.ElideRight
            }
        }
    }
}
