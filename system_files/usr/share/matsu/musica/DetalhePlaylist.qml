// Uma playlist aberta: o mosaico das capas, o nome, Tocar, Aleatório, Renomear e
// Apagar, e as músicas (o menu do botão direito tira da playlist).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: raiz

    property var playlist: null
    readonly property var lista: {
        var _m = janela.mudancasPlaylists;
        return janela.musicasDaPlaylist(playlist);
    }

    FundoDetalhe {
        anchors.fill: parent
        caminho: raiz.lista.length > 0 ? raiz.lista[0].capa : ""
        nome: raiz.playlist ? raiz.playlist.nome : ""
        yRolagem: listaPlaylist.contentY - listaPlaylist.originY
    }
    ListaMusicas {
        id: listaPlaylist
        anchors.fill: parent
        musicas: raiz.lista
        mostrarCabecalho: raiz.lista.length > 0
        contexto: ({ playlist: raiz.playlist ? raiz.playlist.id : "" })
        topo: Component {
            TopoDetalhe {
                voltar: janela.t("Playlists", "Playlists")
                tipo: janela.t("PLAYLIST", "PLAYLIST")
                titulo: raiz.playlist ? raiz.playlist.nome : ""
                detalhe: janela.resumo(raiz.lista)
                onVoltarClicado: janela.playlistAberta = ""
                capa: Component {
                    Mosaico {
                        musicas: raiz.lista
                        nome: raiz.playlist ? raiz.playlist.nome : ""
                        raio: Math.round(janela.gu * 0.7)
                        sombra: 1
                    }
                }
                BotaoDestaque {
                    texto: janela.t("Tocar", "Play")
                    icone: janela.ic("tocar")
                    ativo: raiz.lista.length > 0
                    onClicado: janela.tocarLista(janela.caminhos(raiz.lista), 0, false)
                }
                Botao {
                    texto: janela.t("Aleatório", "Shuffle")
                    icone: janela.ic("aleatorio")
                    ativo: raiz.lista.length > 0
                    onClicado: janela.tocarLista(janela.caminhos(raiz.lista), -1, true)
                }
                BotaoIcone {
                    icone: janela.ic("editar")
                    dica: janela.t("Renomear", "Rename")
                    onClicado: dialogoNome.pedir(janela.t("Renomear a playlist", "Rename playlist"), raiz.playlist.nome, janela.t("Renomear", "Rename"),
                                                 function (nome) { janela.renomearPlaylist(raiz.playlist.id, nome); })
                }
                BotaoIcone {
                    icone: "matsu-lixeira-symbolic"
                    dica: janela.t("Apagar a playlist", "Delete playlist")
                    onClicado: dialogo.perguntar({
                        titulo: janela.t("Apagar a playlist “" + raiz.playlist.nome + "”?", "Delete the playlist “" + raiz.playlist.nome + "”?"),
                        texto: janela.t("As músicas continuam na sua pasta Música.", "The songs stay in your Music folder."),
                        sim: janela.t("Apagar", "Delete"), perigo: true
                    }, function () { janela.apagarPlaylist(raiz.playlist.id); })
                }
            }
        }
        footer: Item {
            width: listaPlaylist.width
            height: raiz.lista.length === 0 ? Math.round(janela.gu * 8) : Math.round(janela.gu * 1.2)
            Texto {
                visible: raiz.lista.length === 0
                anchors.centerIn: parent
                width: Math.min(parent.width - janela.gu * 4, janela.gu * 24)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.62
                text: janela.t("Esta playlist está vazia. Clique com o botão direito numa música e escolha “Adicionar a uma playlist…”.",
                               "This playlist is empty. Right-click a song and choose “Add to a playlist…”.")
            }
        }
    }
}
