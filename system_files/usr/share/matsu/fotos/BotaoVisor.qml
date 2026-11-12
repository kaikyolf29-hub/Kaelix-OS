// Botão do visualizador (fundo sempre escuro, nos dois temas): ícone branco, o
// círculo claro aparece com o mouse em cima e encolhe de leve ao apertar. Com
// texto, vira uma pílula. "ligado" deixa o fundo aceso (o painel de informações aberto).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property string icone: ""
    property string texto: ""
    property string dica: ""
    property string atalho: ""
    property bool ativo: true
    property bool ligado: false
    property real lado: Math.round(janela.gu * 2.1)
    property color cor: "#ffffff"
    // Círculo escuro sempre à mostra (as setas de anterior e próxima, em cima da foto).
    property bool solido: false

    signal clicado()

    implicitWidth: texto.length > 0 ? linha.implicitWidth + Math.round(janela.gu * 1.3) : lado
    implicitHeight: lado
    hoverEnabled: true
    cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: false
    Accessible.role: Accessible.Button
    Accessible.name: texto || dica
    onClicked: if (ativo) botao.clicado()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        scale: botao.pressed && botao.ativo ? 0.92 : 1
        color: botao.solido ? Qt.rgba(0.07, 0.07, 0.08, botao.pressed ? 0.85 : (botao.containsMouse ? 0.75 : 0.55))
                            : Qt.rgba(1, 1, 1, !botao.ativo ? 0 : (botao.pressed ? 0.2 : (botao.ligado ? 0.16 : (botao.containsMouse ? 0.11 : (botao.texto.length > 0 ? 0.08 : 0)))))
        border.width: botao.solido ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, botao.containsMouse ? 0.22 : 0.12)
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
    RowLayout {
        id: linha
        anchors.centerIn: parent
        spacing: Math.round(janela.gu * 0.4)
        opacity: botao.ativo ? 1 : 0.35
        Kirigami.Icon {
            visible: botao.icone.length > 0
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            source: botao.icone
            isMask: true
            color: botao.cor
        }
        QQC2.Label {
            visible: botao.texto.length > 0
            text: botao.texto
            color: botao.cor
        }
    }

    QQC2.ToolTip.visible: (dica.length > 0 || atalho.length > 0) && containsMouse
    QQC2.ToolTip.text: dica + (atalho.length > 0 ? "  (" + atalho + ")" : "")
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
