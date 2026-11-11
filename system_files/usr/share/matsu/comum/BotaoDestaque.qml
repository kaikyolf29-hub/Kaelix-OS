// Botão principal de uma página (como o botão cheio do Windows 11): fundo na cor
// de destaque e o texto na cor que contrasta com ela (nunca texto escuro em cor escura).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property string texto: ""
    property string icone: ""
    // Ícone com as cores dele (a logo de um app), em vez de pintado com a cor do texto.
    property bool iconeColorido: false
    property bool ativo: true

    signal clicado()

    readonly property color fundo: janela.destaque
    readonly property bool fundoClaro: (0.299 * fundo.r + 0.587 * fundo.g + 0.114 * fundo.b) > 0.6
    readonly property color letra: fundoClaro ? "#141416" : "#ffffff"

    implicitWidth: linha.implicitWidth + Math.round(janela.gu * 1.6)
    implicitHeight: Math.round(janela.gu * 2)
    hoverEnabled: true
    cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: ativo
    Accessible.role: Accessible.Button
    Accessible.name: texto
    onClicked: if (ativo) botao.clicado()
    Keys.onReturnPressed: if (ativo) botao.clicado()
    Keys.onSpacePressed: if (ativo) botao.clicado()

    Rectangle {
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.35)
        color: !botao.ativo ? janela.tinta(0.12) : (botao.pressed ? Qt.darker(botao.fundo, 1.12) : (botao.containsMouse ? Qt.lighter(botao.fundo, botao.fundoClaro ? 1.0 : 1.1) : botao.fundo))
        opacity: botao.containsMouse && botao.fundoClaro && !botao.pressed ? 0.9 : 1
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        // Anel de foco do teclado.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: botao.activeFocus ? 1.5 : 0
            border.color: janela.frente
        }
    }
    RowLayout {
        id: linha
        anchors.centerIn: parent
        spacing: Math.round(janela.gu * 0.45)
        opacity: botao.ativo ? 1 : 0.5
        Kirigami.Icon {
            visible: botao.icone.length > 0
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            source: botao.icone
            isMask: !botao.iconeColorido
            color: botao.letra
        }
        Texto {
            text: botao.texto
            color: botao.ativo ? botao.letra : janela.frente
            font.weight: Font.DemiBold
        }
    }
}
