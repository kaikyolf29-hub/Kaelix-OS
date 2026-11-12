// A barra de status, como a do Bloco de Notas do Windows 11: linha e coluna,
// caracteres, e na direita o zoom, o fim de linha e a codificação. Clicar na
// posição abre "Ir para a linha"; no resto, um menu para trocar.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"
import "logica.js" as Logica

Item {
    id: barra

    property Item editor: null
    readonly property var area: editor ? editor.area : null
    readonly property var posicao: area ? Logica.linhaColuna(area.text, area.cursorPosition) : ({ linha: 1, coluna: 1 })
    readonly property int selecao: area ? area.selectionEnd - area.selectionStart : 0
    readonly property int total: area ? area.length : 0

    implicitHeight: Math.round(janela.gu * 1.85)

    component Celula: MouseArea {
        id: celula
        property string texto: ""
        property string dica: ""
        property bool clicavel: true
        signal escolhido()
        implicitWidth: rotulo.implicitWidth + Math.round(janela.gu * 1.1)
        implicitHeight: Math.round(janela.gu * 1.45)
        hoverEnabled: clicavel
        cursorShape: clicavel ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (clicavel) celula.escolhido()
        Accessible.role: clicavel ? Accessible.Button : Accessible.StaticText
        Accessible.name: texto
        Rectangle {
            anchors.fill: parent
            radius: Math.round(janela.gu * 0.28)
            color: janela.tinta(celula.pressed ? 0.1 : (celula.containsMouse ? 0.065 : 0))
            Behavior on color {
                ColorAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
        Texto {
            id: rotulo
            anchors.centerIn: parent
            text: celula.texto
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: celula.containsMouse ? 0.95 : 0.72
        }
        QQC2.ToolTip.visible: dica.length > 0 && containsMouse
        QQC2.ToolTip.text: dica
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    }
    component Divisor: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: Math.round(janela.gu * 0.9)
        Layout.leftMargin: Math.round(janela.gu * 0.15)
        Layout.rightMargin: Math.round(janela.gu * 0.15)
        color: janela.tinta(janela.escuro ? 0.12 : 0.14)
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: janela.tinta(janela.escuro ? 0.06 : 0.07)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 0.4)
        anchors.rightMargin: Math.round(janela.gu * 0.4)
        anchors.topMargin: 1
        spacing: 0

        Celula {
            texto: janela.t("Ln %1, Col %2", "Ln %1, Col %2").arg(janela.num(barra.posicao.linha)).arg(janela.num(barra.posicao.coluna))
            dica: janela.t("Ir para a linha (Ctrl+G)", "Go to line (Ctrl+G)")
            onEscolhido: janela.abrirIrPara()
        }
        Divisor {}
        Celula {
            clicavel: false
            texto: barra.selecao > 0
                   ? janela.t("%1 de %2 caracteres", "%1 of %2 characters").arg(janela.num(barra.selecao)).arg(janela.num(barra.total))
                   : (barra.total === 1 ? janela.t("1 caractere", "1 character") : janela.t("%1 caracteres", "%1 characters").arg(janela.num(barra.total)))
        }
        Item {
            Layout.fillWidth: true
        }
        Celula {
            id: celZoom
            texto: janela.num(janela.zoom) + "%"
            dica: janela.t("Zoom (Ctrl+rodinha)", "Zoom (Ctrl+wheel)")
            onEscolhido: janela.abrirMenuStatus("zoom", celZoom)
        }
        Divisor {}
        Celula {
            id: celFim
            texto: Logica.nomeFim(janela.abaAtual ? janela.abaAtual.fim : "lf", janela.pt)
            dica: janela.t("Fim de linha", "Line ending")
            onEscolhido: janela.abrirMenuStatus("fim", celFim)
        }
        Divisor {}
        Celula {
            id: celCod
            texto: Logica.nomeCodificacao(janela.abaAtual ? janela.abaAtual.codificacao : "utf-8", janela.pt)
            dica: janela.t("Codificação", "Encoding")
            onEscolhido: janela.abrirMenuStatus("codificacao", celCod)
        }
    }
}
