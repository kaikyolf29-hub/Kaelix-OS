// Uma linha de ajuste: o nome à esquerda (com uma explicação curta embaixo, se
// tiver) e o controle à direita. Com "abre: true" vira um botão com a setinha,
// que abre a tela de ajustes do KDE daquele assunto.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: linha

    property string nome: ""
    property string detalhe: ""
    property bool primeira: false
    property bool abre: false
    default property alias controle: lado.data

    signal aberto()

    readonly property int folga: Math.round(Kirigami.Units.gridUnit * 0.8)

    Layout.fillWidth: true
    implicitHeight: Math.max(Math.round(Kirigami.Units.gridUnit * 2.6), conteudo.implicitHeight + folga)
    hoverEnabled: abre
    cursorShape: abre ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: abre
    Accessible.role: abre ? Accessible.Button : Accessible.StaticText
    Accessible.name: nome
    Accessible.description: detalhe
    onClicked: if (abre) linha.aberto()
    Keys.onReturnPressed: if (abre) linha.aberto()
    Keys.onSpacePressed: if (abre) linha.aberto()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: Math.round(Kirigami.Units.gridUnit * 0.45)
        visible: linha.abre && (linha.containsMouse || linha.activeFocus)
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
    }

    // Risco fino entre as linhas do mesmo cartão.
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
        id: conteudo
        anchors.fill: parent
        anchors.leftMargin: linha.folga
        anchors.rightMargin: linha.folga
        spacing: linha.folga

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: linha.nome
                wrapMode: Text.WordWrap
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: linha.detalhe.length > 0
                text: linha.detalhe
                wrapMode: Text.WordWrap
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                opacity: 0.6
            }
        }

        RowLayout {
            id: lado
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: Math.round(Kirigami.Units.gridUnit * 0.5)
        }

        Kirigami.Icon {
            visible: linha.abre
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            source: "matsu-seta-symbolic"
            isMask: true
            color: Kirigami.Theme.textColor
            opacity: 0.5
        }
    }
}
