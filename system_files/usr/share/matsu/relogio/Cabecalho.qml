// Título de uma página do Relógio (grande, como no Windows 11), com uma linha
// fraca embaixo e os botões da página à direita.
//   Cabecalho { titulo: "Alarmes"; subtitulo: "..."; BotaoDestaque { ... } }
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: cabecalho

    property string titulo: ""
    property string subtitulo: ""
    default property alias acoes: linhaAcoes.data

    implicitHeight: Math.round(janela.gu * 4.2)

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: linhaAcoes.left
        anchors.rightMargin: janela.gu
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Texto {
            Layout.fillWidth: true
            text: cabecalho.titulo
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 6
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Accessible.role: Accessible.Heading
        }
        Texto {
            Layout.fillWidth: true
            visible: text.length > 0
            text: cabecalho.subtitulo
            opacity: 0.65
            elide: Text.ElideRight
        }
    }
    Row {
        id: linhaAcoes
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(janela.gu * 0.4)
    }
}
