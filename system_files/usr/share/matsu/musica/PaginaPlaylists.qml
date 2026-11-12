// Playlists: as playlists da pessoa (guardadas em ~/.local/share/matsu/musica) e o
// cartão de criar uma nova. Abrir mostra as músicas, com Renomear e Apagar.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property var aberta: {
        var _m = janela.mudancasPlaylists;
        return janela.playlistAberta !== "" ? janela.playlistDe(janela.playlistAberta) : null;
    }

    Flickable {
        id: rolagem
        anchors.fill: parent
        contentHeight: coluna.implicitHeight + Math.round(janela.gu * 2.4)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        opacity: pagina.aberta ? 0 : 1
        visible: opacity > 0 && janela.playlists.length > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
        QQC2.ScrollBar.vertical: BarraRolagem {}
        ColumnLayout {
            id: coluna
            x: pagina.margem
            y: Math.round(janela.gu * 1.2)
            width: rolagem.width - 2 * pagina.margem
            spacing: Math.round(janela.gu * 1.2)
            CabecalhoPagina {
                Layout.fillWidth: true
                titulo: janela.t("Playlists", "Playlists")
                detalhe: janela.contagem(janela.playlists.length, "playlist", "playlists", "playlist", "playlists")
                BotaoDestaque {
                    texto: janela.t("Nova playlist", "New playlist")
                    icone: "matsu-mais-symbolic"
                    onClicado: janela.novaPlaylist([])
                }
            }
            GradeCartoes {
                id: grade
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                itens: janela.playlists.concat([{ nova: true }])
                delegado: Component {
                    CartaoPlaylist {
                        required property var modelData
                        width: grade.largura
                        nova: !!modelData.nova
                        playlist: modelData.nova ? null : modelData
                        onCriar: janela.novaPlaylist([])
                    }
                }
            }
        }
    }
    Vazio {
        anchors.centerIn: parent
        visible: !pagina.aberta && janela.playlists.length === 0
        icone: janela.ic("playlist")
        titulo: janela.t("Nenhuma playlist ainda", "No playlists yet")
        texto: janela.t("Junte as músicas de que você mais gosta, na ordem que quiser. Para pôr uma música numa playlist, clique nela com o botão direito.",
                        "Gather the songs you love, in any order. Then right-click any song to add it.")
        botao: janela.t("Nova playlist", "New playlist")
        onClicado: janela.novaPlaylist([])
    }
    Loader {
        id: detalhe
        anchors.fill: parent
        active: pagina.aberta !== null
        sourceComponent: DetalhePlaylist {
            playlist: pagina.aberta
        }
        onLoaded: entrada.restart()
        ParallelAnimation {
            id: entrada
            NumberAnimation { target: detalhe.item; property: "opacity"; from: 0; to: 1; duration: 220 }
            NumberAnimation { target: detalhe.item; property: "x"; from: Math.round(janela.gu * 1.5); to: 0; duration: 320; easing.type: Easing.OutCubic }
        }
    }
}
