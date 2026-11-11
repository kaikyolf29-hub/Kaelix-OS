// Um app fixado na barra, na lista dos Ajustes: o ícone, o nome e, à direita,
// subir, descer e tirar da barra. Os botões ficam claros só com o mouse em cima
// (ou com o foco do teclado), para a lista ficar limpa como a do Mac.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: linha

    property string nome: ""
    property string icone: ""
    property string detalhe: ""
    property bool primeira: false
    property bool ultima: false

    signal subir()
    signal descer()
    signal tirar()

    readonly property int folga: Math.round(Kirigami.Units.gridUnit * 0.8)
    readonly property bool ativa: containsMouse || activeFocus || subirBotao.activeFocus || descerBotao.activeFocus || tirarBotao.activeFocus

    Layout.fillWidth: true
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 2.7)
    hoverEnabled: true
    Accessible.role: Accessible.ListItem
    Accessible.name: nome

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: Math.round(Kirigami.Units.gridUnit * 0.45)
        visible: linha.ativa
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.05)
    }

    // Risco fino entre as linhas, como nas outras linhas dos Ajustes.
    Rectangle {
        visible: !linha.primeira
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: linha.folga
        anchors.rightMargin: linha.folga
        height: 1
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: linha.folga
        anchors.rightMargin: Math.round(linha.folga * 0.6)
        spacing: Math.round(Kirigami.Units.gridUnit * 0.7)

        Kirigami.Icon {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.round(Kirigami.Units.gridUnit * 1.6)
            implicitHeight: implicitWidth
            source: linha.icone
            fallback: "application-x-executable"
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: linha.nome
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: linha.detalhe.length > 0
                text: linha.detalhe
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                opacity: 0.6
            }
        }

        PlasmaComponents.ToolButton {
            id: subirBotao
            icon.name: "go-up-symbolic"
            enabled: !linha.primeira
            opacity: linha.ativa ? 1 : 0.35
            display: QQC2.AbstractButton.IconOnly
            text: ajustes.t("Subir", "Move up")
            Accessible.name: ajustes.t("Subir " + linha.nome + " (fica antes na barra)", "Move " + linha.nome + " up (earlier on the bar)")
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: linha.subir()
        }
        PlasmaComponents.ToolButton {
            id: descerBotao
            icon.name: "go-down-symbolic"
            enabled: !linha.ultima
            opacity: linha.ativa ? 1 : 0.35
            display: QQC2.AbstractButton.IconOnly
            text: ajustes.t("Descer", "Move down")
            Accessible.name: ajustes.t("Descer " + linha.nome + " (fica depois na barra)", "Move " + linha.nome + " down (later on the bar)")
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: linha.descer()
        }
        PlasmaComponents.ToolButton {
            id: tirarBotao
            icon.name: "list-remove-symbolic"
            opacity: linha.ativa ? 1 : 0.35
            display: QQC2.AbstractButton.IconOnly
            text: ajustes.t("Tirar da barra", "Unpin from the bar")
            Accessible.name: ajustes.t("Tirar " + linha.nome + " da barra", "Unpin " + linha.nome + " from the bar")
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: linha.tirar()
        }
    }
}
