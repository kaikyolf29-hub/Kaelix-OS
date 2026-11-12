// Botão redondo de ícone da coluna da Câmera (temporizador, grade, trocar de
// câmera, ajustes). O fundo claro aparece com o mouse em cima; ligado, fica com o
// fundo e a borda fina (nunca colorido). Pode ter um selinho com um texto curto
// ("3 s") que pula ao mudar.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: botao

    property string icone: ""
    property string dica: ""
    property bool ligado: false
    property bool ativo: true
    property string selo: ""

    signal clicado()

    implicitWidth: Math.round(janela.gu * 2.3)
    implicitHeight: implicitWidth
    hoverEnabled: true
    enabled: ativo
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: dica
    Accessible.checkable: ligado
    onClicked: botao.clicado()
    Keys.onReturnPressed: botao.clicado()
    Keys.onSpacePressed: botao.clicado()
    onSeloChanged: if (selo !== "") pulo.restart()

    Rectangle {
        id: fundo
        anchors.fill: parent
        radius: width / 2
        scale: botao.pressed ? 0.9 : 1
        opacity: botao.ativo ? 1 : 0.4
        color: janela.tinta(botao.pressed ? 0.14 : (botao.ligado ? (botao.containsMouse ? 0.15 : 0.11) : (botao.containsMouse ? 0.07 : 0)))
        border.width: botao.ligado || botao.activeFocus ? 1 : 0
        border.color: botao.activeFocus ? janela.destaque : janela.tinta(0.16)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: botao.pressed ? 80 : 300
                easing.type: botao.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: 2
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            source: botao.icone
            isMask: true
            color: janela.frente
            opacity: botao.ligado ? 1 : 0.85
        }
    }

    // O selinho no canto (o tempo do temporizador).
    Rectangle {
        id: seloFundo
        visible: botao.selo !== ""
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -Math.round(janela.gu * 0.2)
        anchors.bottomMargin: -Math.round(janela.gu * 0.1)
        height: Math.round(janela.gu * 0.95)
        width: Math.max(height, seloTexto.implicitWidth + Math.round(janela.gu * 0.5))
        radius: height / 2
        color: janela.frente
        border.width: 2
        border.color: janela.fundoPalco
        Texto {
            id: seloTexto
            anchors.centerIn: parent
            text: botao.selo
            color: janela.fundoPalco
            font.pixelSize: Math.round(janela.gu * 0.55)
            font.weight: Font.Bold
        }
        SequentialAnimation {
            id: pulo
            NumberAnimation { target: seloFundo; property: "scale"; from: 0.5; to: 1.15; duration: 160; easing.type: Easing.OutQuad }
            NumberAnimation { target: seloFundo; property: "scale"; to: 1; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        }
    }

    QQC2.ToolTip.visible: dica.length > 0 && containsMouse
    QQC2.ToolTip.text: dica
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
