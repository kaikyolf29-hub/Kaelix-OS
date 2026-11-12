// Título de uma parte da página (Tocadas recentemente...), com o "Ver tudo" à direita.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

RowLayout {
    id: titulo

    property string texto: ""
    property string verTudo: ""

    signal clicado()

    spacing: Math.round(janela.gu * 0.5)

    Texto {
        Layout.fillWidth: true
        text: titulo.texto
        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 3
        font.weight: Font.Bold
        elide: Text.ElideRight
    }
    Botao {
        visible: titulo.verTudo.length > 0
        texto: titulo.verTudo
        icone: "matsu-seta-symbolic"
        iconeNoFim: true
        onClicado: titulo.clicado()
    }
}
