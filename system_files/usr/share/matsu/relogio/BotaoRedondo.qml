// Botão redondo só com ícone (tocar e pausar, zerar, volta), como os do vídeo de
// referência: o principal é cheio na cor de destaque; os outros, um círculo suave.
// Afunda no clique e o ícone dá um pulinho quando troca (tocar ↔ pausar).
//   BotaoRedondo { icone: Qt.resolvedUrl("icones/pausa.svg"); dica: "Pausar"; principal: true; onClicado: ... }
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: botao

    property string icone: ""
    property string dica: ""
    property bool principal: false
    property bool ativo: true
    property real tamanho: Math.round(janela.gu * 2.4)

    signal clicado()

    readonly property bool fundoClaro: (0.299 * janela.destaque.r + 0.587 * janela.destaque.g + 0.114 * janela.destaque.b) > 0.6

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
    onIconeChanged: pulo.restart()

    Rectangle {
        id: fundo
        anchors.fill: parent
        radius: width / 2
        scale: botao.pressed && botao.ativo ? 0.9 : 1
        color: botao.principal
               ? (!botao.ativo ? janela.tinta(0.12) : (botao.pressed ? Qt.darker(janela.destaque, 1.15)
                  : (botao.containsMouse && !botao.fundoClaro ? Qt.lighter(janela.destaque, 1.12) : janela.destaque)))
               : janela.tinta(!botao.ativo ? 0.03 : (botao.pressed ? 0.15 : (botao.containsMouse ? 0.1 : (janela.escuro ? 0.065 : 0.05))))
        opacity: botao.principal && botao.fundoClaro && botao.containsMouse && !botao.pressed ? 0.88 : 1
        border.width: botao.principal ? 0 : 1
        border.color: janela.tinta(janela.escuro ? 0.08 : 0.1)
        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutBack
                easing.overshoot: 2
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        // Anel de foco do teclado.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: width / 2
            color: "transparent"
            border.width: botao.activeFocus ? 1.5 : 0
            border.color: janela.frente
        }
    }
    Kirigami.Icon {
        id: simbolo
        anchors.centerIn: parent
        width: Math.round(botao.tamanho * 0.42)
        height: width
        source: botao.icone
        isMask: true
        color: botao.principal && botao.ativo ? janela.sobreDestaque : janela.frente
        opacity: botao.ativo ? 1 : 0.35
        scale: fundo.scale
    }
    SequentialAnimation {
        id: pulo
        NumberAnimation { target: simbolo; property: "rotation"; from: -25; to: 0; duration: 260; easing.type: Easing.OutBack }
    }

    QQC2.ToolTip.visible: dica.length > 0 && containsMouse
    QQC2.ToolTip.text: dica
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
