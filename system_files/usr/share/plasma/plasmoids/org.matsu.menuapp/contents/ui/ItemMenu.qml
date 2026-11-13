// Uma linha do menu que desce da barra de cima: o visto (quando é uma chave
// ligada), o nome e, à direita, o atalho. A linha acende com o mouse em cima.
// Com "separador", é só um risco fino entre os grupos.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: item

    property var dados: ({})
    property bool destacado: false

    readonly property bool separador: dados.separador === true
    readonly property bool ativo: dados.ativo !== false && !separador
    readonly property int folga: Math.round(Kirigami.Units.gridUnit * 0.55)

    signal escolhido()

    Layout.fillWidth: true
    implicitHeight: separador ? Math.round(Kirigami.Units.gridUnit * 0.65) : Math.round(Kirigami.Units.gridUnit * 1.7)
    implicitWidth: separador ? 0 : linha.implicitWidth + folga * 2
    hoverEnabled: ativo
    enabled: ativo
    onClicked: item.escolhido()
    Accessible.role: separador ? Accessible.Separator : Accessible.MenuItem
    Accessible.name: dados.texto || ""

    Rectangle {
        visible: !item.separador
        anchors.fill: parent
        radius: Math.round(Kirigami.Units.gridUnit * 0.38)
        readonly property color base: Kirigami.Theme.textColor
        color: Qt.rgba(base.r, base.g, base.b, item.pressed ? 0.17 : (item.containsMouse || item.destacado ? 0.10 : 0))
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    Rectangle {
        visible: item.separador
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: item.folga
        anchors.rightMargin: item.folga
        height: 1
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.13)
    }

    RowLayout {
        id: linha
        visible: !item.separador
        anchors.fill: parent
        anchors.leftMargin: Math.round(item.folga * 0.6)
        anchors.rightMargin: item.folga
        spacing: Math.round(Kirigami.Units.gridUnit * 0.4)
        opacity: item.ativo ? 1 : 0.4

        // O lugar do visto fica sempre reservado, para os nomes ficarem alinhados.
        Item {
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            Kirigami.Icon {
                anchors.fill: parent
                source: "matsu-certo-symbolic"
                isMask: true
                color: Kirigami.Theme.textColor
                opacity: item.dados.marcado === true ? 1 : 0
                scale: item.dados.marcado === true ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutBack } }
            }
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: item.dados.texto || ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            visible: (item.dados.dica || "").length > 0
            Layout.leftMargin: Kirigami.Units.gridUnit
            text: item.dados.dica || ""
            textFormat: Text.PlainText
            opacity: 0.55
        }
    }
}
