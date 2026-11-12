// Botão só de ícone da barra do editor (negrito, fixar, cor, lixeira...). Como o
// Botao de ../comum, sem fundo até o mouse chegar; "ligado" marca o que está
// valendo agora (negrito ativo, nota fixada) com o fundo e a borda fina, sem cor.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property string icone: ""
    property string dica: ""
    property bool ligado: false
    property bool ativo: true
    // Uma bolinha de cor no canto do ícone (a cor da nota no botão da paleta).
    property color pingo: "transparent"

    signal clicado()

    implicitWidth: Math.round(janela.gu * 1.9)
    implicitHeight: implicitWidth
    hoverEnabled: true
    cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: ativo
    Accessible.role: Accessible.Button
    Accessible.name: dica
    Accessible.checkable: ligado
    onClicked: if (ativo) botao.clicado()
    Keys.onReturnPressed: if (ativo) botao.clicado()
    Keys.onSpacePressed: if (ativo) botao.clicado()

    Rectangle {
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.35)
        scale: botao.pressed && botao.ativo ? 0.92 : 1
        color: janela.tinta(!botao.ativo ? 0 : (botao.pressed ? 0.12 : (botao.ligado ? (janela.escuro ? 0.11 : 0.085) : (botao.containsMouse ? 0.065 : 0))))
        border.width: botao.ligado || botao.activeFocus ? 1 : 0
        border.color: botao.activeFocus ? janela.destaque : janela.tinta(0.12)
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
        id: simbolo
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.small
        height: width
        source: botao.icone
        isMask: true
        color: janela.frente
        opacity: botao.ativo ? (botao.ligado || botao.containsMouse ? 1 : 0.82) : 0.35
    }
    Rectangle {
        visible: botao.pingo.a > 0
        anchors.right: simbolo.right
        anchors.bottom: simbolo.bottom
        anchors.rightMargin: -2
        anchors.bottomMargin: -2
        width: Math.round(janela.gu * 0.5)
        height: width
        radius: width / 2
        color: botao.pingo
        border.width: 1.5
        border.color: janela.escuro ? "#2a2a2d" : "#f6f6f8"
    }

    QQC2.ToolTip.visible: dica.length > 0 && containsMouse
    QQC2.ToolTip.text: dica
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
