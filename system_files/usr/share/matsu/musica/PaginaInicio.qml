// Início: a saudação com Tocar tudo e Aleatório (no fundo, as cores do álbum mais
// novo), os álbuns tocados recentemente, os adicionados recentemente, os artistas
// e as playlists, em cartões com a capa grande e a sombra suave.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property var tocados: {
        var vistos = {}, r = [];
        for (var i = 0; i < janela.recentes.length && r.length < 16; i++) {
            var m = janela.musicaDe(janela.recentes[i].caminho);
            if (!m || vistos[m.chaveAlbum] || !janela.porAlbum[m.chaveAlbum])
                continue;
            vistos[m.chaveAlbum] = true;
            r.push(janela.porAlbum[m.chaveAlbum]);
        }
        return r;
    }
    readonly property var novos: janela.albuns.slice().sort(function (x, y) { return y.adicionada - x.adicionada || x.ordem.localeCompare(y.ordem); })
    readonly property var destaque: novos.length > 0 ? novos[0] : null

    Flickable {
        id: rolagem
        anchors.fill: parent
        contentHeight: coluna.implicitHeight + pagina.margem
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: BarraRolagem {}

        ColumnLayout {
            id: coluna
            x: pagina.margem
            y: Math.round(janela.gu * 1.2)
            width: rolagem.width - 2 * pagina.margem
            spacing: Math.round(janela.gu * 1.1)

            // ----- a saudação -----
            Item {
                id: saudacao
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(janela.gu * 8.6)
                Layout.bottomMargin: Math.round(janela.gu * 0.6)

                Item {
                    id: fundoSaudacao
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: mascaraSaudacao
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                    FundoCapa {
                        anchors.fill: parent
                        caminho: pagina.destaque ? pagina.destaque.capa : ""
                        nome: pagina.destaque ? pagina.destaque.nome : "Matsu"
                        saturacao: 0.15
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: janela.escuro ? Qt.rgba(0.07, 0.07, 0.08, 0.72) : Qt.rgba(1, 1, 1, 0.74) }
                            GradientStop { position: 1; color: janela.escuro ? Qt.rgba(0.07, 0.07, 0.08, 0.35) : Qt.rgba(1, 1, 1, 0.38) }
                        }
                    }
                }
                Rectangle {
                    id: mascaraSaudacao
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    radius: Math.round(janela.gu * 0.9)
                    color: "white"
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(janela.gu * 0.9)
                    color: "transparent"
                    border.width: 1
                    border.color: janela.tinta(0.08)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(janela.gu * 1.5)
                    anchors.rightMargin: Math.round(janela.gu * 1.5)
                    spacing: Math.round(janela.gu * 1.2)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Math.round(janela.gu * 0.2)
                        Texto {
                            Layout.fillWidth: true
                            text: janela.saudacao()
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.1
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: janela.resumo(janela.musicas) + " · " + janela.contagem(janela.albuns.length, "álbum", "álbuns", "album", "albums")
                            opacity: 0.72
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            Layout.topMargin: Math.round(janela.gu * 0.6)
                            spacing: Math.round(janela.gu * 0.5)
                            BotaoDestaque {
                                texto: janela.t("Tocar tudo", "Play all")
                                icone: janela.ic("tocar")
                                onClicado: janela.tocarTudo(false)
                            }
                            Botao {
                                texto: janela.t("Aleatório", "Shuffle")
                                icone: janela.ic("aleatorio")
                                onClicado: janela.tocarTudo(true)
                            }
                        }
                    }
                    // Uma pilha com as capas mais novas, de enfeite (só cabe na janela larga).
                    Item {
                        Layout.preferredWidth: Math.round(janela.gu * 9)
                        Layout.fillHeight: true
                        visible: saudacao.width > janela.gu * 30 && pagina.novos.length > 0
                        Repeater {
                            model: Math.min(3, pagina.novos.length)
                            Capa {
                                required property int index
                                readonly property var album: pagina.novos[Math.min(pagina.novos.length - 1, 2 - index)]
                                width: Math.round(janela.gu * 5.6)
                                height: width
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.round(parent.width - width - (2 - index) * janela.gu * 1.4)
                                rotation: (index - 2) * 7
                                caminho: album.capa
                                nome: album.nome || album.artista
                                iconeVazio: "album"
                                raio: Math.round(janela.gu * 0.5)
                                sombra: 0.8
                                opacity: index === 2 ? 1 : 0.92
                            }
                        }
                    }
                }
            }

            // ----- tocadas recentemente -----
            Titulo {
                Layout.fillWidth: true
                visible: pagina.tocados.length > 0
                texto: janela.t("Tocadas recentemente", "Recently played")
            }
            GradeCartoes {
                id: gradeTocados
                Layout.fillWidth: true
                Layout.bottomMargin: Math.round(janela.gu * 0.6)
                visible: pagina.tocados.length > 0
                itens: pagina.tocados
                linhas: 1
                delegado: Component {
                    CartaoAlbum {
                        required property var modelData
                        width: gradeTocados.largura
                        album: modelData
                    }
                }
            }

            // ----- adicionadas recentemente -----
            Titulo {
                Layout.fillWidth: true
                texto: janela.t("Adicionadas recentemente", "Recently added")
                verTudo: gradeNovos.sobra ? janela.t("Ver todos os álbuns", "See all albums") : ""
                onClicado: {
                    janela.ordemAlbuns = "recentes";
                    janela.irPara("albuns");
                }
            }
            GradeCartoes {
                id: gradeNovos
                Layout.fillWidth: true
                Layout.bottomMargin: Math.round(janela.gu * 0.6)
                itens: pagina.novos
                linhas: pagina.tocados.length > 0 ? 1 : 2
                delegado: Component {
                    CartaoAlbum {
                        required property var modelData
                        width: gradeNovos.largura
                        album: modelData
                    }
                }
            }

            // ----- artistas -----
            Titulo {
                Layout.fillWidth: true
                visible: janela.artistas.length > 1
                texto: janela.t("Artistas", "Artists")
                verTudo: gradeArtistas.sobra ? janela.t("Ver todos", "See all") : ""
                onClicado: janela.irPara("artistas")
            }
            GradeCartoes {
                id: gradeArtistas
                Layout.fillWidth: true
                Layout.bottomMargin: Math.round(janela.gu * 0.6)
                visible: janela.artistas.length > 1
                itens: janela.artistas
                linhas: 1
                minimo: Math.round(janela.gu * 7.4)
                delegado: Component {
                    CartaoArtista {
                        required property var modelData
                        width: gradeArtistas.largura
                        artista: modelData
                    }
                }
            }

            // ----- playlists -----
            Titulo {
                Layout.fillWidth: true
                visible: janela.playlists.length > 0
                texto: janela.t("Suas playlists", "Your playlists")
                verTudo: gradePlaylists.sobra ? janela.t("Ver todas", "See all") : ""
                onClicado: janela.irPara("playlists")
            }
            GradeCartoes {
                id: gradePlaylists
                Layout.fillWidth: true
                visible: janela.playlists.length > 0
                itens: janela.playlists
                linhas: 1
                delegado: Component {
                    CartaoPlaylist {
                        required property var modelData
                        width: gradePlaylists.largura
                        playlist: modelData
                    }
                }
            }
        }
    }
}
