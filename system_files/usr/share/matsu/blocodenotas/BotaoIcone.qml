// Botão só de ícone (localizar, setas, opções de busca, o + das abas): fundo que
// aparece com o mouse, afunda no clique e, "ligado", fica com o fundo e a borda
// fina (nunca colorido). O ícone pode girar ("giro"), como a setinha que abre a troca.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property string icone: ""
    property string dica: ""
    property bool ligado: false
    property bool ativo: true
    property real giro: 0
    property real tamanhoIcone: Kirigami.Units.iconSizes.small
    property bool redondo: false

    signal clicado()

    implicitWidth: Math.round(janela.gu * 1.85)
    implicitHeight: Math.round(janela.gu * 1.85)
    hoverEnabled: true
    cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: false
    Accessible.role: Accessible.Button
    Accessible.name: dica
    Accessible.checkable: ligado
    onClicked: if (ativo) botao.clicado()

    Rectangle {
        anchors.fill: parent
        radius: botao.redondo ? width / 2 : Math.round(janela.gu * 0.32)
        scale: botao.pressed && botao.ativo ? 0.92 : 1
        color: janela.tinta(!botao.ativo ? 0 : (botao.pressed ? 0.12 : (botao.ligado ? (botao.containsMouse ? 0.12 : 0.09) : (botao.containsMouse ? 0.07 : 0))))
        border.width: botao.ligado ? 1 : 0
        border.color: janela.tinta(janela.escuro ? 0.16 : 0.18)
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
        width: botao.tamanhoIcone
        height: width
        source: botao.icone
        isMask: true
        color: janela.frente
        opacity: botao.ativo ? (botao.ligado || botao.containsMouse ? 1 : 0.82) : 0.32
        rotation: botao.giro
        Behavior on rotation {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    QQC2.ToolTip.visible: dica.length > 0 && containsMouse && !pressed
    QQC2.ToolTip.text: dica
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
