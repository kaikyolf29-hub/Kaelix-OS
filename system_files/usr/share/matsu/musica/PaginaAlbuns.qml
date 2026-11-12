// Álbuns: a grade com as capas (ordenada pela lista suspensa, filtrada pela busca).
// Abrir um mostra o álbum com a capa grande e a lista; o "voltar" (ou o botão de
// voltar do mouse) volta para a grade no mesmo lugar.
import QtQuick
import QtQuick.Controls as QQC2
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property var aberto: janela.albumAberto !== "" ? janela.albumDe(janela.albumAberto) : null
    readonly property var lista: {
        var b = janela.busca;
        var r = janela.albuns.filter(function (a) { return janela.bate(a.busca, b); });
        var o = janela.ordemAlbuns;
        if (o !== "nome")
            r.sort(function (x, y) {
                if (o === "artista")
                    return janela.simples(x.artista || "￿").localeCompare(janela.simples(y.artista || "￿")) || x.ordem.localeCompare(y.ordem);
                if (o === "ano")
                    return (y.ano || 0) - (x.ano || 0) || x.ordem.localeCompare(y.ordem);
                return y.adicionada - x.adicionada || x.ordem.localeCompare(y.ordem);
            });
        return r;
    }

    GridView {
        id: grade
        anchors.fill: parent
        anchors.leftMargin: pagina.margem - espaco / 2
        anchors.rightMargin: pagina.margem - espaco / 2
        readonly property real espaco: Math.round(janela.gu * 1.1)
        readonly property int colunas: Math.max(2, Math.floor(width / (janela.gu * 9.2 + espaco)))
        cellWidth: Math.floor(width / colunas)
        cellHeight: cellWidth - espaco + Math.round(janela.gu * 4.4)
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
                titulo: janela.t("Álbuns", "Albums")
                detalhe: janela.contagem(pagina.lista.length, "álbum", "álbuns", "album", "albums")
                Suspensa {
                    nome: janela.t("Ordenar por", "Sort by")
                    opcoes: [
                        { id: "nome", nome: janela.t("Nome", "Name") },
                        { id: "artista", nome: janela.t("Artista", "Artist") },
                        { id: "ano", nome: janela.t("Ano", "Year") },
                        { id: "recentes", nome: janela.t("Adicionados recentemente", "Recently added") }
                    ]
                    escolhido: janela.ordemAlbuns
                    onEscolher: (id) => { janela.ordemAlbuns = id; janela.salvarDepois(); }
                }
            }
        }
        footer: Item {
            width: 1
            height: Math.round(janela.gu * 0.6)
        }
        delegate: Item {
            required property var modelData
            width: grade.cellWidth
            height: grade.cellHeight
            CartaoAlbum {
                x: grade.espaco / 2
                width: parent.width - grade.espaco
                album: parent.modelData
            }
        }
    }
    Vazio {
        anchors.centerIn: parent
        visible: !pagina.aberto && pagina.lista.length === 0
        icone: "matsu-busca-symbolic"
        titulo: janela.t("Nenhum álbum encontrado", "No albums found")
        texto: janela.t("Tente outro nome de álbum ou artista.", "Try another album or artist name.")
    }
    Loader {
        id: detalhe
        anchors.fill: parent
        active: pagina.aberto !== null
        sourceComponent: DetalheAlbum {
            album: pagina.aberto
        }
        onLoaded: entrada.restart()
        ParallelAnimation {
            id: entrada
            NumberAnimation { target: detalhe.item; property: "opacity"; from: 0; to: 1; duration: 220 }
            NumberAnimation { target: detalhe.item; property: "x"; from: Math.round(janela.gu * 1.5); to: 0; duration: 320; easing.type: Easing.OutCubic }
        }
    }
}
