// Bolinha de cor, como a cor de destaque dos Ajustes do Mac. A escolhida ganha
// um anel em volta e um sinal de certo.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

MouseArea {
    id: ponto

    property color cor: "#5468e8"
    property string nome: ""
    property bool escolhido: false
    readonly property int tamanho: Math.round(Kirigami.Units.gridUnit * 1.25)

    implicitWidth: tamanho + 8
    implicitHeight: tamanho + 8
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: nome
    Accessible.checked: escolhido

    Rectangle {
        anchors.centerIn: parent
        width: ponto.tamanho + 8
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: ponto.cor
        visible: ponto.escolhido || ponto.activeFocus
        opacity: ponto.escolhido ? 1 : 0.5
    }
    Rectangle {
        anchors.centerIn: parent
        width: ponto.tamanho
        height: width
        radius: width / 2
        color: ponto.cor
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.15)
        scale: ponto.pressed ? 0.92 : (ponto.containsMouse ? 1.06 : 1)
        Behavior on scale {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.62)
            height: width
            visible: ponto.escolhido
            source: "matsu-certo-symbolic"
            isMask: true
            color: "#ffffff"
        }
    }

    QQC2.ToolTip.visible: containsMouse && nome.length > 0
    QQC2.ToolTip.text: nome
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
