// O topo de uma página: o título grande, uma linha de detalhe embaixo e os botões
// à direita (Tocar, Aleatório, ordenar...). Estreita, os botões descem.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

GridLayout {
    id: cabecalho

    property string titulo: ""
    property string detalhe: ""
    default property alias acoes: linhaAcoes.data

    readonly property bool estreito: width < janela.gu * 30
    columns: estreito ? 1 : 2
    columnSpacing: Math.round(janela.gu * 1)
    rowSpacing: Math.round(janela.gu * 0.6)

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Texto {
            Layout.fillWidth: true
            text: cabecalho.titulo
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.9
            font.weight: Font.Bold
            elide: Text.ElideRight
        }
        Texto {
            Layout.fillWidth: true
            visible: text.length > 0
            text: cabecalho.detalhe
            opacity: 0.62
            elide: Text.ElideRight
        }
    }
    RowLayout {
        id: linhaAcoes
        Layout.alignment: cabecalho.estreito ? Qt.AlignLeft : Qt.AlignRight | Qt.AlignBottom
        spacing: Math.round(janela.gu * 0.4)
    }
}
