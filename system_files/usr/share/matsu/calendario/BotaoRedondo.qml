// Botão redondo só com o ícone (as setas ‹ › e o "mais opções"): o fundo claro
// aparece com o mouse em cima e afunda um pouco no clique.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: botao

    property var icone: ""
    property string dica: ""
    property bool ativo: true
    property real tamanho: Math.round(janela.gu * 1.9)

    signal clicado()

    implicitWidth: tamanho
    implicitHeight: tamanho
    hoverEnabled: true
    cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: ativo
    Accessible.role: Accessible.Button
    Accessible.name: dica
    onClicked: if (ativo) botao.clicado()
    Keys.onReturnPressed: if (ativo) botao.clicado()
    Keys.onSpacePressed: if (ativo) botao.clicado()

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        scale: botao.pressed ? 0.9 : 1
        color: janela.tinta(!botao.ativo ? 0 : (botao.pressed ? 0.12 : (botao.containsMouse ? 0.075 : 0)))
        border.width: botao.activeFocus ? 1 : 0
        border.color: janela.destaque
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.small
        height: width
        source: botao.icone
        isMask: true
        color: janela.frente
        opacity: botao.ativo ? 0.9 : 0.35
    }

    QQC2.ToolTip.visible: dica.length > 0 && containsMouse
    QQC2.ToolTip.text: dica
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
