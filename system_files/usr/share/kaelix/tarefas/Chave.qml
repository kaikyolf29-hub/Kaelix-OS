// Chave de ligar e desligar, como a do Windows 11: desligada é só o contorno
// com a bolinha; ligada, a pílula cheia na cor de destaque e a bolinha do lado.
import QtQuick
import org.kde.kirigami as Kirigami

MouseArea {
    id: chave

    property bool ligada: false
    property string nome: ""

    signal trocada(bool ligada)

    implicitWidth: 40
    implicitHeight: 20
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: nome
    Accessible.checkable: true
    Accessible.checked: ligada
    onClicked: chave.trocada(!ligada)
    Keys.onSpacePressed: chave.trocada(!ligada)
    Keys.onReturnPressed: chave.trocada(!ligada)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: chave.ligada ? (chave.containsMouse ? Qt.lighter(tarefas.destaque, 1.08) : tarefas.destaque)
             : tarefas.tinta(chave.containsMouse ? 0.06 : 0.02)
        border.width: chave.ligada ? 0 : 1
        border.color: tarefas.tinta(0.6)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }

        // Anel de foco do teclado.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.width: chave.activeFocus ? 1.5 : 0
            border.color: tarefas.frente
        }

        Rectangle {
            readonly property real lado: chave.ligada || chave.pressed ? 12 : 10
            width: chave.pressed ? lado + 3 : lado
            height: lado
            radius: lado / 2
            anchors.verticalCenter: parent.verticalCenter
            x: chave.ligada ? parent.width - width - 4 : 5
            color: chave.ligada ? (tarefas.escuro ? "#1a1a1e" : "#ffffff") : tarefas.tinta(0.75)
            Behavior on x {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
