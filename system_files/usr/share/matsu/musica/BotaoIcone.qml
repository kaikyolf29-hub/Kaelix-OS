// Botão redondo só com o ícone (anterior, próxima, aleatório, repetir, volume...).
// "ligado" (aleatório e repetir ligados): fundo claro e borda fina, o ícone forte;
// desligado, o ícone fica mais apagado. Nada de azul.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property url icone
    property string dica: ""
    property string atalho: ""
    property bool ligado: false
    property bool alternavel: false
    property bool ativo: true
    property int lado: Math.round(janela.gu * 1.9)
    property real tamanhoIcone: Math.round(lado * 0.5)
    property color cor: janela.frente

    signal clicado()

    implicitWidth: lado
    implicitHeight: lado
    hoverEnabled: true
    enabled: ativo
    cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: ativo
    Accessible.role: alternavel ? Accessible.CheckBox : Accessible.Button
    Accessible.name: dica
    Accessible.checked: ligado
    onClicked: { botao.clicado(); pulo.restart(); }
    Keys.onReturnPressed: botao.clicado()

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: botao.cor === janela.frente
               ? janela.tinta(botao.pressed ? 0.16 : (botao.ligado ? (botao.containsMouse ? 0.17 : 0.13) : (botao.containsMouse ? 0.08 : 0)))
               : Qt.rgba(botao.cor.r, botao.cor.g, botao.cor.b, botao.pressed ? 0.2 : (botao.ligado ? 0.16 : (botao.containsMouse ? 0.1 : 0)))
        border.width: botao.ligado || botao.activeFocus ? 1 : 0
        border.color: botao.activeFocus ? janela.destaque : Qt.rgba(botao.cor.r, botao.cor.g, botao.cor.b, 0.14)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
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
        color: botao.cor
        opacity: !botao.ativo ? 0.3 : (botao.alternavel && !botao.ligado ? (botao.containsMouse ? 0.85 : 0.6) : 1)
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }
    SequentialAnimation {
        id: pulo
        NumberAnimation { target: simbolo; property: "scale"; to: 0.78; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: simbolo; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
    }

    QQC2.ToolTip.visible: dica.length > 0 && containsMouse
    QQC2.ToolTip.text: atalho.length > 0 ? dica + "  ·  " + atalho : dica
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
