// "Hoje": pílula com a borda fina. Quando o período na tela já tem o dia de hoje,
// fica mais apagada (ainda dá para clicar, para voltar a pílula para hoje).
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

MouseArea {
    id: botao

    readonly property bool emHoje: Datas.mesmoDia(janela.foco, janela.hojeAgora)

    implicitWidth: rotulo.implicitWidth + Math.round(janela.gu * 1.4)
    implicitHeight: Math.round(janela.gu * 1.9)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: rotulo.text
    onClicked: janela.irParaHoje()
    Keys.onReturnPressed: janela.irParaHoje()
    Keys.onSpacePressed: janela.irParaHoje()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        scale: botao.pressed ? 0.95 : 1
        color: janela.tinta(botao.pressed ? 0.12 : (botao.containsMouse ? 0.075 : 0.02))
        border.width: 1
        border.color: botao.activeFocus ? janela.destaque : janela.tinta(janela.escuro ? 0.14 : 0.16)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 120
            }
        }
    }
    Texto {
        id: rotulo
        anchors.centerIn: parent
        text: janela.t("Hoje", "Today")
        font.weight: Font.DemiBold
        opacity: botao.emHoje ? 0.6 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
    }

    QQC2.ToolTip.visible: containsMouse
    QQC2.ToolTip.text: Datas.dataLonga(janela.hojeAgora, janela.pt) + " (Ctrl+T)"
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
