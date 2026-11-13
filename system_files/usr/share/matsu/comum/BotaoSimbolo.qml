// Botão só de ícone (localizar, negrito, fixar, setas, o + das abas): sem fundo
// até o mouse chegar, afunda no clique e, "ligado" (negrito ativo, busca aberta),
// fica com o fundo e a borda fina, nunca colorido. O ícone pode girar ("giro"),
// como a setinha que abre a troca, e ter um pingo de cor no canto ("pingo").
//   BotaoSimbolo { icone: "matsu-busca-symbolic"; dica: "Localizar"; ligado: aberta; onClicado: ... }
// (Não se chama BotaoIcone porque Música, Notas e Bloco de notas já tiveram um
// BotaoIcone próprio, e uma peça daqui ganha da que tem o mesmo nome na pasta do app.)
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property string icone: ""
    property string dica: ""
    property bool ligado: false
    property bool ativo: true
    // Quanto o ícone gira (em graus), animado.
    property real giro: 0
    property real tamanhoIcone: Kirigami.Units.iconSizes.small
    property int lado: Math.round(janela.gu * 1.9)
    property bool redondo: false
    // Uma bolinha de cor no canto do ícone (a cor de uma nota, por exemplo).
    property color pingo: "transparent"
    // Se o Tab passa por ele.
    property bool focavel: true

    signal clicado()

    implicitWidth: lado
    implicitHeight: lado
    hoverEnabled: true
    cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: focavel && ativo
    Accessible.role: Accessible.Button
    Accessible.name: dica
    Accessible.checkable: ligado
    onClicked: if (ativo) botao.clicado()
    Keys.onReturnPressed: if (ativo) botao.clicado()
    Keys.onSpacePressed: if (ativo) botao.clicado()

    Rectangle {
        anchors.fill: parent
        radius: botao.redondo ? width / 2 : Math.round(janela.gu * 0.34)
        scale: botao.pressed && botao.ativo ? 0.92 : 1
        color: janela.tinta(!botao.ativo ? 0 : (botao.pressed ? 0.12 : (botao.ligado ? (botao.containsMouse ? 0.13 : (janela.escuro ? 0.1 : 0.088)) : (botao.containsMouse ? 0.068 : 0))))
        border.width: botao.ligado || botao.activeFocus ? 1 : 0
        border.color: botao.activeFocus ? janela.destaque : janela.tinta(janela.escuro ? 0.15 : 0.16)
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
        width: botao.tamanhoIcone
        height: width
        source: botao.icone
        isMask: true
        color: janela.frente
        opacity: botao.ativo ? (botao.ligado || botao.containsMouse ? 1 : 0.82) : 0.33
        rotation: botao.giro
        Behavior on rotation {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
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

    QQC2.ToolTip.visible: dica.length > 0 && containsMouse && !pressed
    QQC2.ToolTip.text: dica
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
