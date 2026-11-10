// Um botão grande da central de controle: ícone, nome e uma linha de estado.
// Aceso (ligado) ele ganha a cor de destaque do Kaelix.
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
    readonly property color corDoTexto: ligado ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor

    signal acionado()
    signal detalhado()

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 3.2)
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
        radius: 12
        color: botao.ligado ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        opacity: botao.ligado ? (botao.pressed ? 0.8 : (botao.containsMouse ? 0.92 : 1))
                              : (botao.pressed ? 0.2 : (botao.containsMouse || botao.activeFocus ? 0.14 : 0.08))
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

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
            spacing: 0

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: botao.titulo
                color: botao.corDoTexto
                font.bold: true
                elide: Text.ElideRight
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: botao.detalhe
                color: botao.corDoTexto
                opacity: 0.75
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
            }
        }
    }
}
