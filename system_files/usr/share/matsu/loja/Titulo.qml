// Título de uma parte da página, com o texto embaixo e, à direita, o "Ver tudo".
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

RowLayout {
    id: titulo

    property string texto: ""
    property string detalhe: ""
    property string verTudo: ""

    signal clicado()

    spacing: Math.round(janela.gu * 0.5)

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Texto {
            Layout.fillWidth: true
            text: titulo.texto
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Texto {
            Layout.fillWidth: true
            visible: titulo.detalhe.length > 0
            text: titulo.detalhe
            opacity: 0.62
            elide: Text.ElideRight
        }
    }
    Botao {
        visible: titulo.verTudo.length > 0
        Layout.alignment: Qt.AlignBottom
        texto: titulo.verTudo
        icone: "matsu-seta-symbolic"
        iconeNoFim: true
        onClicado: titulo.clicado()
    }
}
