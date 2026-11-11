// Uma linha de ajuste, como as do Windows 11: ícone, nome e explicação à
// esquerda, e o controle (chave, seletor...) à direita.
//   LinhaOpcao { icone: "..."; nome: "..."; texto: "..."; Chave { ... } }
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Cartao {
    id: linha

    property string icone: ""
    property string nome: ""
    property string texto: ""
    property bool primeira: true
    property bool ultima: true
    default property alias controle: lugar.data

    implicitHeight: Math.max(Math.round(janela.gu * 3.4), colunaTexto.implicitHeight + Math.round(janela.gu * 1.2))
    // Linhas em sequência formam um bloco só: só as pontas ficam arredondadas.
    topLeftRadius: primeira ? radius : 2
    topRightRadius: primeira ? radius : 2
    bottomLeftRadius: ultima ? radius : 2
    bottomRightRadius: ultima ? radius : 2

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 0.9)
        anchors.rightMargin: Math.round(janela.gu * 0.9)
        spacing: Math.round(janela.gu * 0.8)

        Kirigami.Icon {
            visible: linha.icone.length > 0
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            source: linha.icone
            isMask: true
            color: janela.frente
            opacity: 0.85
        }
        ColumnLayout {
            id: colunaTexto
            Layout.fillWidth: true
            spacing: 1
            Texto {
                Layout.fillWidth: true
                text: linha.nome
                elide: Text.ElideRight
            }
            Texto {
                Layout.fillWidth: true
                visible: linha.texto.length > 0
                text: linha.texto
                wrapMode: Text.WordWrap
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.62
            }
        }
        Item {
            id: lugar
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
