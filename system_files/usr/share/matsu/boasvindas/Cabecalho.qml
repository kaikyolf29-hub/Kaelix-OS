// O título grande de cada tela das Boas-vindas e a explicação embaixo, centrados.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

ColumnLayout {
    property string titulo: ""
    property string texto: ""

    Layout.fillWidth: true
    spacing: Math.round(janela.gu * 0.4)

    Texto {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: parent.titulo
        font.pixelSize: Math.round(janela.gu * 1.45)
        font.weight: Font.DemiBold
    }
    Texto {
        Layout.fillWidth: true
        Layout.maximumWidth: Math.round(janela.gu * 30)
        Layout.alignment: Qt.AlignHCenter
        visible: text !== ""
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: parent.texto
        opacity: 0.7
    }
}
