// Grade de cartões (álbuns, artistas, playlists) que se ajusta à largura: quantos
// cabem por linha e, com "linhas", só as primeiras linhas (o resto no "Ver tudo").
//   GradeCartoes { id: g; itens: lista; linhas: 1
//                  delegado: Component { CartaoAlbum { required property var modelData; width: g.largura; album: modelData } } }
import QtQuick

Item {
    id: grade

    property var itens: []
    property int linhas: 0
    property real minimo: Math.round(janela.gu * 9.2)
    property Component delegado: null
    readonly property real espaco: Math.round(janela.gu * 1.1)
    readonly property int colunas: Math.max(2, Math.floor((width + espaco) / (minimo + espaco)))
    readonly property real largura: Math.floor((width - (colunas - 1) * espaco) / colunas)
    readonly property var visiveis: linhas > 0 ? itens.slice(0, colunas * linhas) : itens
    readonly property bool sobra: itens.length > visiveis.length

    implicitHeight: fluxo.implicitHeight

    Flow {
        id: fluxo
        width: parent.width
        spacing: grade.espaco
        Repeater {
            model: grade.visiveis
            delegate: grade.delegado
        }
    }
}
