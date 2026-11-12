// Músicas: todas, numa lista com a capa pequena, o título, o artista, o álbum e a
// duração. Ordena pela lista suspensa; a busca da barra de título filtra.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property var opcoes: [
        { id: "titulo", nome: janela.t("Título", "Title") },
        { id: "artista", nome: janela.t("Artista", "Artist") },
        { id: "album", nome: janela.t("Álbum", "Album") },
        { id: "recentes", nome: janela.t("Adicionadas recentemente", "Recently added") },
        { id: "duracao", nome: janela.t("Duração", "Duration") }
    ]
    readonly property var lista: {
        var b = janela.busca;
        var r = janela.musicas.filter(function (m) { return janela.bate(m.busca, b); });
        var o = janela.ordemMusicas;
        r.sort(function (x, y) {
            if (o === "artista")
                return x.chaveArtista.localeCompare(y.chaveArtista) || x.chaveAlbum.localeCompare(y.chaveAlbum) || janela.porFaixa(x, y);
            if (o === "album")
                return x.chaveAlbum.localeCompare(y.chaveAlbum) || janela.porFaixa(x, y);
            if (o === "recentes")
                return y.adicionada - x.adicionada || x.titulo.localeCompare(y.titulo);
            if (o === "duracao")
                return x.duracao - y.duracao || x.titulo.localeCompare(y.titulo);
            return x.titulo.localeCompare(y.titulo);
        });
        return r;
    }

    ListaMusicas {
        id: listaMusicas
        anchors.fill: parent
        musicas: pagina.lista
        topo: Component {
            Item {
                implicitHeight: cab.implicitHeight + Math.round(janela.gu * 2.2)
                CabecalhoPagina {
                    id: cab
                    x: Math.round(janela.gu * 1.6)
                    y: Math.round(janela.gu * 1.2)
                    width: parent.width - 2 * x
                    titulo: janela.t("Músicas", "Songs")
                    detalhe: janela.busca.trim().length > 0
                             ? janela.t("“" + janela.busca.trim() + "”: ", "“" + janela.busca.trim() + "”: ") + janela.resumo(pagina.lista)
                             : janela.resumo(pagina.lista)
                    Suspensa {
                        nome: janela.t("Ordenar por", "Sort by")
                        opcoes: pagina.opcoes
                        escolhido: janela.ordemMusicas
                        onEscolher: (id) => { janela.ordemMusicas = id; janela.salvarDepois(); }
                    }
                    Botao {
                        texto: janela.t("Aleatório", "Shuffle")
                        icone: janela.ic("aleatorio")
                        onClicado: janela.tocarLista(janela.caminhos(pagina.lista), -1, true)
                    }
                    BotaoDestaque {
                        texto: janela.t("Tocar", "Play")
                        icone: janela.ic("tocar")
                        ativo: pagina.lista.length > 0
                        onClicado: janela.tocarLista(janela.caminhos(pagina.lista), 0, false)
                    }
                }
            }
        }
    }
    Vazio {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(janela.gu * 3)
        visible: pagina.lista.length === 0
        icone: "matsu-busca-symbolic"
        titulo: janela.t("Nenhuma música encontrada", "No songs found")
        texto: janela.t("Tente outro nome de música, artista ou álbum.", "Try another song, artist or album name.")
    }
}
