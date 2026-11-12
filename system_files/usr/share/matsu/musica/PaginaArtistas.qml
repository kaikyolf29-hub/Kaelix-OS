// Artistas: a grade com as fotos redondas (a capa de um álbum de cada um). Abrir
// mostra os álbuns e as músicas do artista.
import QtQuick
import QtQuick.Controls as QQC2
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property var aberto: janela.artistaAberto !== "" ? janela.artistaDe(janela.artistaAberto) : null
    readonly property var lista: {
        var b = janela.busca;
        return janela.artistas.filter(function (a) { return janela.bate(a.busca, b); });
    }

    GridView {
        id: grade
        anchors.fill: parent
        anchors.leftMargin: pagina.margem - espaco / 2
        anchors.rightMargin: pagina.margem - espaco / 2
        readonly property real espaco: Math.round(janela.gu * 1.2)
        readonly property int colunas: Math.max(2, Math.floor(width / (janela.gu * 7.6 + espaco)))
        cellWidth: Math.floor(width / colunas)
        cellHeight: cellWidth - espaco + Math.round(janela.gu * 4.2)
        model: pagina.lista
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        opacity: pagina.aberto ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
        QQC2.ScrollBar.vertical: BarraRolagem {}
        header: Item {
            width: grade.width
            implicitHeight: cab.implicitHeight + Math.round(janela.gu * 2.4)
            CabecalhoPagina {
                id: cab
                x: grade.espaco / 2
                y: Math.round(janela.gu * 1.2)
                width: parent.width - grade.espaco
                titulo: janela.t("Artistas", "Artists")
                detalhe: janela.contagem(pagina.lista.length, "artista", "artistas", "artist", "artists")
            }
        }
        delegate: Item {
            required property var modelData
            width: grade.cellWidth
            height: grade.cellHeight
            CartaoArtista {
                x: grade.espaco / 2
                width: parent.width - grade.espaco
                artista: parent.modelData
            }
        }
    }
    Vazio {
        anchors.centerIn: parent
        visible: !pagina.aberto && pagina.lista.length === 0
        icone: "matsu-busca-symbolic"
        titulo: janela.t("Nenhum artista encontrado", "No artists found")
        texto: janela.t("Tente outro nome.", "Try another name.")
    }
    Loader {
        id: detalhe
        anchors.fill: parent
        active: pagina.aberto !== null
        sourceComponent: DetalheArtista {
            artista: pagina.aberto
        }
        onLoaded: entrada.restart()
        ParallelAnimation {
            id: entrada
            NumberAnimation { target: detalhe.item; property: "opacity"; from: 0; to: 1; duration: 220 }
            NumberAnimation { target: detalhe.item; property: "x"; from: Math.round(janela.gu * 1.5); to: 0; duration: 320; easing.type: Easing.OutCubic }
        }
    }
}
