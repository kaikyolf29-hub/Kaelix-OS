// Um artista aberto: a foto redonda, o nome, Tocar e Aleatório, os álbuns dele em
// cartões e, embaixo, todas as músicas.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: raiz

    property var artista: null
    readonly property var albunsDele: {
        if (!artista)
            return [];
        return artista.albuns.map(function (c) { return janela.porAlbum[c]; }).filter(function (a) { return !!a; })
                             .sort(function (x, y) { return (y.ano || 0) - (x.ano || 0) || x.ordem.localeCompare(y.ordem); });
    }

    FundoDetalhe {
        anchors.fill: parent
        caminho: raiz.artista ? raiz.artista.capa : ""
        nome: raiz.artista ? raiz.artista.nome : ""
        yRolagem: lista.contentY - lista.originY
    }
    ListaMusicas {
        id: lista
        anchors.fill: parent
        musicas: raiz.artista ? raiz.artista.faixas : []
        mostrarArtista: false
        contexto: ({ semArtista: true })
        topo: Component {
            ColumnLayout {
                spacing: 0
                TopoDetalhe {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    voltar: janela.t("Artistas", "Artists")
                    tipo: janela.t("ARTISTA", "ARTIST")
                    titulo: raiz.artista ? janela.nomeArtista(raiz.artista.nome) : ""
                    detalhe: raiz.artista ? janela.contagem(raiz.albunsDele.length, "álbum", "álbuns", "album", "albums") + " · " + janela.resumo(raiz.artista.faixas) : ""
                    onVoltarClicado: janela.artistaAberto = ""
                    capa: Component {
                        Capa {
                            caminho: raiz.artista ? raiz.artista.capa : ""
                            nome: raiz.artista ? raiz.artista.nome : ""
                            iconeVazio: "artista"
                            redonda: true
                            sombra: 1
                        }
                    }
                    BotaoDestaque {
                        texto: janela.t("Tocar", "Play")
                        icone: janela.ic("tocar")
                        onClicado: janela.tocarLista(janela.caminhos(raiz.artista.faixas), 0, false)
                    }
                    Botao {
                        texto: janela.t("Aleatório", "Shuffle")
                        icone: janela.ic("aleatorio")
                        onClicado: janela.tocarLista(janela.caminhos(raiz.artista.faixas), -1, true)
                    }
                }
                Titulo {
                    Layout.fillWidth: true
                    Layout.leftMargin: Math.round(janela.gu * 1.6)
                    Layout.rightMargin: Math.round(janela.gu * 1.6)
                    Layout.topMargin: Math.round(janela.gu * 0.4)
                    texto: janela.t("Álbuns", "Albums")
                }
                GradeCartoes {
                    id: gradeAlbuns
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.leftMargin: Math.round(janela.gu * 1.6)
                    Layout.rightMargin: Math.round(janela.gu * 1.6)
                    Layout.topMargin: Math.round(janela.gu * 0.8)
                    itens: raiz.albunsDele
                    minimo: Math.round(janela.gu * 8.4)
                    delegado: Component {
                        CartaoAlbum {
                            required property var modelData
                            width: gradeAlbuns.largura
                            album: modelData
                            subtitulo: modelData.ano ? String(modelData.ano) : janela.contagem(modelData.faixas.length, "música", "músicas", "song", "songs")
                        }
                    }
                }
                Titulo {
                    Layout.fillWidth: true
                    Layout.leftMargin: Math.round(janela.gu * 1.6)
                    Layout.rightMargin: Math.round(janela.gu * 1.6)
                    Layout.topMargin: Math.round(janela.gu * 1.4)
                    Layout.bottomMargin: Math.round(janela.gu * 0.6)
                    texto: janela.t("Músicas", "Songs")
                }
            }
        }
    }
}
