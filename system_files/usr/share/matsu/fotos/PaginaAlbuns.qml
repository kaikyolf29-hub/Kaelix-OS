// Álbuns: cada subpasta de Imagens vira um cartão com a capa (a foto mais nova),
// o nome e quantas fotos tem. Clicar abre a grade do álbum, com o botão de voltar.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.4)
    readonly property var albumInfo: {
        for (var i = 0; i < janela.albuns.length; i++)
            if (janela.albuns[i].nome === janela.albumAberto)
                return janela.albuns[i];
        return null;
    }
    readonly property var lista: {
        var b = janela.simples(janela.busca.trim());
        return b.length === 0 ? janela.albuns : janela.albuns.filter(function (a) {
            return janela.simples(a.nome).indexOf(b) >= 0;
        });
    }
    readonly property var fotosDoAlbum: albumInfo ? janela.busca2(janela.fotos.filter(function (f) {
        return f.album === pagina.albumInfo.nome;
    })) : []

    // O álbum sumiu (a pasta foi apagada): volta para a lista.
    onAlbumInfoChanged: if (!albumInfo && janela.albumAberto !== "" && janela.lido) janela.albumAberto = ""

    Shortcut {
        sequences: ["Backspace", "Alt+Left"]
        enabled: janela.albumAberto !== "" && !janela.visorAberto
        onActivated: janela.albumAberto = ""
    }

    // ----- a grade de um álbum -----
    Loader {
        anchors.fill: parent
        active: pagina.albumInfo !== null
        visible: active
        sourceComponent: GradeFotos {
            fotos: pagina.fotosDoAlbum
            chave: "album|" + janela.albumAberto + "|" + janela.busca
            comVoltar: true
            pasta: pagina.albumInfo ? pagina.albumInfo.caminho : ""
            titulo: janela.albumAberto
            detalhe: pagina.fotosDoAlbum.length === 0 ? "" : janela.quantas(pagina.fotosDoAlbum.length) + " · " + janela.periodo(pagina.fotosDoAlbum)
            vazioIcone: "matsu-busca-symbolic"
            vazioTitulo: janela.t("Nada encontrado", "Nothing found")
            vazioTexto: janela.t("Nenhuma foto deste álbum com “" + janela.busca.trim() + "” no nome.", "No photo in this album with “" + janela.busca.trim() + "” in its name.")
            onVoltar: janela.albumAberto = ""
        }
    }

    // ----- os cartões dos álbuns -----
    GridView {
        id: grade
        anchors.fill: parent
        anchors.leftMargin: pagina.margem - Math.round(vao / 2)
        anchors.rightMargin: pagina.margem - Math.round(vao / 2)
        visible: pagina.albumInfo === null
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property int vao: Math.round(janela.gu * 1.1)
        readonly property int colunas: Math.max(2, Math.floor(width / (janela.gu * 11.5)))
        cellWidth: Math.floor(width / colunas)
        cellHeight: Math.round((cellWidth - vao) * 0.78) + Math.round(janela.gu * 3.6)
        model: pagina.lista
        cacheBuffer: Math.round(janela.gu * 20)
        QQC2.ScrollBar.vertical: BarraRolagem {
            parent: pagina
            x: pagina.width - width
            y: grade.y
            height: grade.height
            visible: grade.visible && size < 1.0
        }
        Component.onCompleted: entrada.restart()
        onVisibleChanged: if (visible) entrada.restart()
        transform: Translate {
            id: deslocamento
        }
        ParallelAnimation {
            id: entrada
            NumberAnimation { target: grade; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: deslocamento; property: "y"; from: Math.round(janela.gu * 0.8); to: 0; duration: 340; easing.type: Easing.OutCubic }
        }

        header: Item {
            width: grade.width
            height: Math.round(janela.gu * 5)
            ColumnLayout {
                x: Math.round(grade.vao / 2)
                y: Math.round(janela.gu * 1.0)
                width: parent.width - grade.vao
                spacing: 1
                Texto {
                    Layout.fillWidth: true
                    text: janela.busca.trim().length > 0 ? janela.t("Álbuns com “" + janela.busca.trim() + "”", "Albums matching “" + janela.busca.trim() + "”") : janela.t("Álbuns", "Albums")
                    font.pixelSize: Math.round(janela.gu * 1.3)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Cada pasta dentro de Imagens é um álbum", "Each folder inside Pictures is an album")
                    opacity: 0.62
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                }
            }
        }

        delegate: Item {
            id: celula
            required property var modelData
            required property int index
            width: grade.cellWidth
            height: grade.cellHeight

            MouseArea {
                id: cartao
                anchors.fill: parent
                anchors.leftMargin: Math.round(grade.vao / 2)
                anchors.rightMargin: Math.round(grade.vao / 2)
                anchors.topMargin: Math.round(janela.gu * 0.7)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                Accessible.role: Accessible.Button
                Accessible.name: celula.modelData.nome
                onClicked: (m) => {
                    if (m.button === Qt.RightButton) {
                        menuAlbum.album = celula.modelData;
                        menuAlbum.abrirEm(cartao, m.x, m.y);
                    } else {
                        janela.albumAberto = celula.modelData.nome;
                    }
                }

                // As folhas de trás: o cartão parece uma pilha de fotos.
                Rectangle {
                    anchors.horizontalCenter: capaAlbum.horizontalCenter
                    y: capaAlbum.y - Math.round(janela.gu * (cartao.containsMouse ? 0.62 : 0.5))
                    width: capaAlbum.width - Math.round(janela.gu * 1.6)
                    height: capaAlbum.height
                    radius: Math.round(janela.gu * 0.55)
                    color: janela.tinta(janela.escuro ? 0.07 : 0.07)
                    visible: celula.modelData.quantidade > 2
                    Behavior on y {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: capaAlbum.horizontalCenter
                    y: capaAlbum.y - Math.round(janela.gu * (cartao.containsMouse ? 0.32 : 0.25))
                    width: capaAlbum.width - Math.round(janela.gu * 0.8)
                    height: capaAlbum.height
                    radius: Math.round(janela.gu * 0.55)
                    color: janela.tinta(janela.escuro ? 0.12 : 0.12)
                    visible: celula.modelData.quantidade > 1
                    Behavior on y {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                CapaRedonda {
                    id: capaAlbum
                    x: 0
                    y: Math.round(janela.gu * 0.6)
                    width: parent.width
                    height: Math.round(width * 0.78)
                    arquivo: celula.modelData.capaMini && Math.max(width, height) * dpr <= celula.modelData.capaLado * 1.15 ? celula.modelData.capaMini : celula.modelData.capa
                    giro: janela.giroDe(celula.modelData.capa)
                    aproximar: cartao.containsMouse ? 1.045 : 1
                    scale: cartao.pressed ? 0.98 : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: 140
                        }
                    }
                }
                Rectangle {
                    anchors.fill: capaAlbum
                    radius: Math.round(janela.gu * 0.55)
                    color: "transparent"
                    border.width: 1
                    border.color: janela.tinta(cartao.containsMouse ? 0.22 : 0.08)
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: capaAlbum.bottom
                    anchors.topMargin: Math.round(janela.gu * 0.5)
                    spacing: 0
                    Texto {
                        Layout.fillWidth: true
                        text: celula.modelData.nome
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: janela.quantas(celula.modelData.quantidade) + " · " + janela.bytes(celula.modelData.tamanho)
                        opacity: 0.6
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Vazio {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(janela.gu * 1.5)
        visible: janela.lido && pagina.albumInfo === null && pagina.lista.length === 0
        icone: janela.busca.trim().length > 0 ? "matsu-busca-symbolic" : String(Qt.resolvedUrl("icones/album.svg"))
        titulo: janela.busca.trim().length > 0 ? janela.t("Nenhum álbum encontrado", "No albums found") : janela.t("Nenhum álbum ainda", "No albums yet")
        texto: janela.busca.trim().length > 0 ? janela.t("Nenhum álbum com “" + janela.busca.trim() + "” no nome.", "No album with “" + janela.busca.trim() + "” in its name.")
                                             : janela.t("Crie pastas dentro de Imagens (Viagem, Família...) e cada uma vira um álbum aqui.",
                                                        "Create folders inside Pictures (Trip, Family...) and each one becomes an album here.")
        botao: janela.busca.trim().length === 0 && janela.raiz !== "" ? janela.t("Abrir a pasta Imagens", "Open the Pictures folder") : ""
        onClicado: janela.abrirPasta(janela.raiz)
    }

    MenuMatsu {
        id: menuAlbum
        property var album: ({})
        itens: [
            { id: "abrir", nome: janela.t("Abrir álbum", "Open album"), icone: String(Qt.resolvedUrl("icones/album.svg")) },
            { id: "apresentacao", nome: janela.t("Apresentação de slides", "Slideshow"), icone: String(Qt.resolvedUrl("icones/apresentacao.svg")) },
            { id: "pasta", nome: janela.t("Abrir no Arquivos", "Open in Files"), icone: "matsu-pasta-symbolic", separador: true }
        ]
        onEscolhido: (id) => {
            if (id === "abrir") {
                janela.albumAberto = menuAlbum.album.nome;
            } else if (id === "apresentacao") {
                janela.apresentar(janela.fotos.filter(function (f) { return f.album === menuAlbum.album.nome; }), 0);
            } else if (id === "pasta") {
                janela.abrirPasta(menuAlbum.album.caminho);
            }
        }
    }
}
