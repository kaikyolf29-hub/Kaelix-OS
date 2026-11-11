// Cartão do Início: bolinha com o ícone na cor do assunto, nome, uma linha de
// explicação e o controle à direita. Clicar no cartão leva à página dele.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Cartao {
    id: cartao

    property string icone: ""
    property color cor: janela.frente
    property string nome: ""
    property string texto: ""
    default property alias controle: lugar.data

    signal clicado()

    implicitHeight: Math.max(Math.round(janela.gu * 5.4), linha.implicitHeight + Math.round(janela.gu * 1.6))
    color: area.containsMouse ? Qt.rgba(janela.cartao.r, janela.cartao.g, janela.cartao.b, Math.min(1, janela.cartao.a * 1.6)) : janela.cartao
    Behavior on color {
        ColorAnimation {
            duration: Kirigami.Units.shortDuration
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cartao.clicado()
    }

    RowLayout {
        id: linha
        anchors.fill: parent
        anchors.margins: Math.round(janela.gu * 0.9)
        spacing: Math.round(janela.gu * 0.75)

        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Math.round(janela.gu * 2.2)
            Layout.preferredHeight: Layout.preferredWidth
            radius: Math.round(width * 0.32)
            color: Qt.rgba(cartao.cor.r, cartao.cor.g, cartao.cor.b, janela.escuro ? 0.18 : 0.14)
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small
                height: width
                source: cartao.icone
                isMask: true
                color: cartao.cor
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 2
            Texto {
                Layout.fillWidth: true
                text: cartao.nome
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Texto {
                Layout.fillWidth: true
                text: cartao.texto
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.65
            }
        }
        Item {
            id: lugar
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
