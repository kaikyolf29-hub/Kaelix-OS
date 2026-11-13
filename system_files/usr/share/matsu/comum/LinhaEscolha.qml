// Linha de ajuste com o controle embaixo, ocupando a largura toda (lista suspensa,
// seletor): para painéis estreitos, onde o controle não cabe ao lado do nome.
// Mesmo visual da LinhaOpcao (cartão, ícone, nome e explicação); várias em
// sequência formam um bloco só (primeira/ultima).
//   LinhaEscolha { icone; nome; texto; Suspensa { Layout.fillWidth: true ... } }
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

    implicitHeight: coluna.implicitHeight + Math.round(janela.gu * 1.3)
    topLeftRadius: primeira ? radius : 2
    topRightRadius: primeira ? radius : 2
    bottomLeftRadius: ultima ? radius : 2
    bottomRightRadius: ultima ? radius : 2

    ColumnLayout {
        id: coluna
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Math.round(janela.gu * 0.9)
        anchors.rightMargin: Math.round(janela.gu * 0.9)
        spacing: Math.round(janela.gu * 0.55)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.8)
            Kirigami.Icon {
                visible: linha.icone.length > 0
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                Layout.alignment: Qt.AlignTop
                source: linha.icone
                isMask: true
                color: janela.frente
                opacity: 0.85
            }
            ColumnLayout {
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
        }
        ColumnLayout {
            id: lugar
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.4)
        }
    }
}
