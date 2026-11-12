// Um álbum na grade: a capa grande com sombra suave (sobe um pouco e a sombra cresce
// com o mouse em cima, e aparece o botão de tocar), o nome e o artista embaixo.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: cartao

    property var album: null
    property string subtitulo: album ? janela.artistaDoAlbum(album) : ""
    readonly property bool esteTocando: album !== null && janela.atual !== null && janela.atual.chaveAlbum === album.chave

    implicitWidth: Math.round(janela.gu * 9)
    implicitHeight: width + textos.implicitHeight + Math.round(janela.gu * 0.6)
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: album ? janela.nomeAlbum(album.nome) + ", " + subtitulo : ""
    onClicked: (e) => {
        if (e.button === Qt.RightButton)
            janela.menuMusicas(cartao, e.x, e.y, janela.caminhos(album.faixas), { semAlbum: true });
        else
            janela.abrirAlbum(album.chave);
    }
    Keys.onReturnPressed: janela.abrirAlbum(album.chave)

    Item {
        id: lugarCapa
        width: parent.width
        height: width
        Capa {
            id: capa
            width: parent.width
            height: width
            y: cartao.containsMouse ? -Math.round(janela.gu * 0.2) : 0
            caminho: cartao.album ? cartao.album.capa : ""
            nome: cartao.album ? (cartao.album.nome || cartao.album.artista) : ""
            iconeVazio: "album"
            raio: Math.round(janela.gu * 0.6)
            sombra: cartao.containsMouse ? 1 : 0.5
            Behavior on y {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on sombra {
                NumberAnimation {
                    duration: 220
                }
            }
            // Anel de foco do teclado.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: capa.raio + 3
                color: "transparent"
                border.width: cartao.activeFocus ? 1.5 : 0
                border.color: janela.frente
            }
            BotaoTocarCapa {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Math.round(janela.gu * 0.55)
                mostrar: cartao.containsMouse
                tocando: cartao.esteTocando && janela.tocando
                onClicado: {
                    if (cartao.esteTocando)
                        janela.tocarPausar();
                    else
                        janela.tocarLista(janela.caminhos(cartao.album.faixas), 0, false);
                }
            }
        }
    }
    ColumnLayout {
        id: textos
        anchors.top: lugarCapa.bottom
        anchors.topMargin: Math.round(janela.gu * 0.55)
        width: parent.width
        spacing: 1
        Texto {
            Layout.fillWidth: true
            text: cartao.album ? janela.nomeAlbum(cartao.album.nome) : ""
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Texto {
            Layout.fillWidth: true
            text: cartao.subtitulo
            elide: Text.ElideRight
            font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
            opacity: 0.62
        }
    }
}
