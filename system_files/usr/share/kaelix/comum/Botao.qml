// Botão da barra de ferramentas das páginas, como os do Windows 11: ícone e
// texto, sem fundo; o fundo claro aparece com o mouse em cima. Apagado quando
// não dá para usar agora (o balão explica o porquê).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property string texto: ""
    property string icone: ""
    property string dica: ""
    property bool ativo: true
    // Ícone com as cores dele (a logo de um app), em vez de pintado com a cor do texto.
    property bool iconeColorido: false
    // Ícone depois do texto (setinha de "Ver todos").
    property bool iconeNoFim: false

    signal clicado()

    implicitWidth: conteudo.implicitWidth + Math.round(janela.gu * 1.1)
    implicitHeight: Math.round(janela.gu * 1.9)
    hoverEnabled: true
    cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: ativo
    Accessible.role: Accessible.Button
    Accessible.name: texto
    Accessible.description: dica
    onClicked: if (ativo) botao.clicado()
    Keys.onReturnPressed: if (ativo) botao.clicado()
    Keys.onSpacePressed: if (ativo) botao.clicado()

    Rectangle {
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.3)
        color: janela.tinta(!botao.ativo ? 0 : (botao.pressed ? 0.1 : (botao.containsMouse ? 0.065 : 0)))
        border.width: botao.activeFocus ? 1 : 0
        border.color: janela.destaque
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }

    GridLayout {
        id: conteudo
        rows: 1
        anchors.centerIn: parent
        columnSpacing: Math.round(janela.gu * 0.45)
        opacity: botao.ativo ? 1 : 0.38

        Kirigami.Icon {
            Layout.row: 0
            Layout.column: botao.iconeNoFim ? 1 : 0
            visible: botao.icone.length > 0
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            source: botao.icone
            isMask: !botao.iconeColorido
            color: janela.frente
        }
        Texto {
            Layout.row: 0
            Layout.column: botao.iconeNoFim ? 0 : 1
            text: botao.texto
        }
    }

    QQC2.ToolTip.visible: dica.length > 0 && containsMouse
    QQC2.ToolTip.text: dica
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
