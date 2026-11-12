// Um álbum aberto: a capa grande, o nome, o artista (leva ao artista), o ano, as
// músicas e a duração, Tocar e Aleatório, e a lista das faixas.
import QtQuick
import QtQuick.Layouts
import "../comum"

Item {
    id: raiz

    property var album: null

    FundoDetalhe {
        anchors.fill: parent
        caminho: raiz.album ? raiz.album.capa : ""
        nome: raiz.album ? (raiz.album.nome || raiz.album.artista) : ""
        yRolagem: lista.contentY - lista.originY
    }
    ListaMusicas {
        id: lista
        anchors.fill: parent
        musicas: raiz.album ? raiz.album.faixas : []
        mostrarCapa: false
        mostrarAlbum: false
        mostrarArtista: !!(raiz.album && raiz.album.varios)
        numeroDe: function (m, i) { return String(m.faixa || i + 1); }
        contexto: ({ semAlbum: true })
        topo: Component {
            TopoDetalhe {
                voltar: janela.t("Álbuns", "Albums")
                tipo: janela.t("ÁLBUM", "ALBUM")
                titulo: raiz.album ? janela.nomeAlbum(raiz.album.nome) : ""
                subtitulo: raiz.album ? janela.artistaDoAlbum(raiz.album) : ""
                subtituloClicavel: !!(raiz.album && !raiz.album.varios && janela.porArtista[janela.simples(raiz.album.artista)])
                detalhe: raiz.album ? (raiz.album.ano ? raiz.album.ano + " · " : "") + janela.resumo(raiz.album.faixas) : ""
                onVoltarClicado: janela.albumAberto = ""
                onSubtituloClicado: janela.abrirArtista(janela.simples(raiz.album.artista))
                capa: Component {
                    Capa {
                        caminho: raiz.album ? raiz.album.capa : ""
                        nome: raiz.album ? (raiz.album.nome || raiz.album.artista) : ""
                        iconeVazio: "album"
                        raio: Math.round(janela.gu * 0.7)
                        sombra: 1
                    }
                }
                BotaoDestaque {
                    texto: janela.t("Tocar", "Play")
                    icone: janela.ic("tocar")
                    onClicado: janela.tocarLista(janela.caminhos(raiz.album.faixas), 0, false)
                }
                Botao {
                    texto: janela.t("Aleatório", "Shuffle")
                    icone: janela.ic("aleatorio")
                    onClicado: janela.tocarLista(janela.caminhos(raiz.album.faixas), -1, true)
                }
                BotaoIcone {
                    id: maisAlbum
                    icone: janela.ic("mais-opcoes")
                    dica: janela.t("Mais opções", "More options")
                    onClicado: janela.menuMusicas(maisAlbum, 0, maisAlbum.height, janela.caminhos(raiz.album.faixas), { semAlbum: true })
                }
            }
        }
    }
}
