// O botão redondo de tocar e pausar, na cor da frente (como o do player de voz do
// vídeo de referência): o ícone vira de um no outro, cresce de leve com o mouse
// em cima e afunda ao clicar.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property bool tocando: false
    property int diametro: Math.round(janela.gu * 2.2)
    property bool ativo: true

    signal clicado()

    implicitWidth: diametro
    implicitHeight: diametro
    hoverEnabled: true
    cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: tocando ? janela.t("Pausar", "Pause") : janela.t("Tocar", "Play")
    onClicked: if (ativo) botao.clicado()
    Keys.onReturnPressed: if (ativo) botao.clicado()

    RectangularShadow {
        anchors.fill: fundo
        anchors.margins: 1
        radius: width / 2
        offset.y: Math.round(botao.diametro * 0.06)
        blur: Math.round(botao.diametro * 0.3)
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.45 : 0.22)
        scale: fundo.scale
        opacity: botao.ativo ? 1 : 0
    }
    Rectangle {
        id: fundo
        anchors.fill: parent
        radius: width / 2
        color: botao.ativo ? janela.frente : janela.tinta(0.25)
        scale: botao.pressed && botao.ativo ? 0.9 : (botao.containsMouse && botao.ativo ? 1.06 : 1)
        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
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
        IconeTocar {
            anchors.centerIn: parent
            width: Math.round(botao.diametro * 0.46)
            height: width
            tocando: botao.tocando
            cor: janela.escuro ? "#1a1a1e" : "#ffffff"
        }
    }

    QQC2.ToolTip.visible: containsMouse
    QQC2.ToolTip.text: (tocando ? janela.t("Pausar", "Pause") : janela.t("Tocar", "Play")) + "  ·  " + janela.t("Espaço", "Space")
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
