// O nome de um grupo na página ("Verificar agora", "Ajustes"), com uma frase opcional.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

ColumnLayout {
    property string titulo: ""
    property string texto: ""

    Layout.fillWidth: true
    Layout.topMargin: Math.round(janela.gu * 0.7)
    spacing: 1

    Texto {
        Layout.fillWidth: true
        text: parent.titulo
        font.weight: Font.DemiBold
        opacity: 0.9
        elide: Text.ElideRight
    }
    Texto {
        Layout.fillWidth: true
        visible: parent.texto.length > 0
        text: parent.texto
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.6
        wrapMode: Text.WordWrap
    }
}
