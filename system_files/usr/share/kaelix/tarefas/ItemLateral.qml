// Um item da lista de assuntos à esquerda: ícone de linha e o nome. O escolhido
// ganha um fundo claro e o tracinho da cor de destaque na ponta, como no
// Windows 11. Com a lista recolhida, fica só o ícone (o nome aparece no balão).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

MouseArea {
    id: item

    property string icone: ""
    property string nome: ""
    property bool escolhido: false
    property bool soIcone: false

    signal ativado()

    implicitHeight: Math.round(tarefas.gu * 2)
    hoverEnabled: true
    activeFocusOnTab: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.PageTab
    Accessible.name: nome
    Accessible.selected: escolhido
    onClicked: item.ativado()
    Keys.onReturnPressed: item.ativado()
    Keys.onSpacePressed: item.ativado()

    Rectangle {
        anchors.fill: parent
        radius: Math.round(tarefas.gu * 0.3)
        color: tarefas.tinta(item.escolhido ? (tarefas.escuro ? 0.08 : 0.065) : (item.pressed ? 0.06 : (item.containsMouse || item.activeFocus ? 0.045 : 0)))
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: item.escolhido ? Math.round(parent.height * 0.42) : 0
        radius: 1.5
        color: tarefas.destaque
        Behavior on height {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    Kirigami.Icon {
        id: simbolo
        x: Math.round(tarefas.gu * 0.75)
        anchors.verticalCenter: parent.verticalCenter
        width: Kirigami.Units.iconSizes.small
        height: width
        source: item.icone
        isMask: true
        color: tarefas.frente
        opacity: item.escolhido ? 1 : 0.85
    }
    Texto {
        anchors.left: simbolo.right
        anchors.leftMargin: Math.round(tarefas.gu * 0.7)
        anchors.right: parent.right
        anchors.rightMargin: Math.round(tarefas.gu * 0.4)
        anchors.verticalCenter: parent.verticalCenter
        text: item.nome
        elide: Text.ElideRight
        visible: !item.soIcone
        opacity: item.soIcone ? 0 : (item.escolhido ? 1 : 0.88)
        font.weight: item.escolhido ? Font.DemiBold : Font.Normal
    }

    QQC2.ToolTip.visible: item.soIcone && containsMouse
    QQC2.ToolTip.text: nome
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
