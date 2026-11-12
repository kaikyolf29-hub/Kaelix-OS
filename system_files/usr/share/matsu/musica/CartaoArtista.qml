// Um artista na grade: a foto redonda (a capa de um álbum dele), o nome e quantas músicas.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: cartao

    property var artista: null

    implicitWidth: Math.round(janela.gu * 8)
    implicitHeight: width + textos.implicitHeight + Math.round(janela.gu * 0.6)
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: artista ? janela.nomeArtista(artista.nome) : ""
    onClicked: (e) => {
        if (e.button === Qt.RightButton)
            janela.menuMusicas(cartao, e.x, e.y, janela.caminhos(artista.faixas), { semArtista: true, semAlbum: true });
        else
            janela.abrirArtista(artista.chave);
    }
    Keys.onReturnPressed: janela.abrirArtista(artista.chave)

    Capa {
        id: foto
        width: parent.width
        height: width
        redonda: true
        iconeVazio: "artista"
        caminho: cartao.artista ? cartao.artista.capa : ""
        nome: cartao.artista ? cartao.artista.nome : ""
        sombra: cartao.containsMouse ? 0.9 : 0.4
        scale: cartao.pressed ? 0.97 : (cartao.containsMouse ? 1.03 : 1)
        Behavior on scale {
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
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: width / 2
            color: "transparent"
            border.width: cartao.activeFocus ? 1.5 : 0
            border.color: janela.frente
        }
    }
    ColumnLayout {
        id: textos
        anchors.top: foto.bottom
        anchors.topMargin: Math.round(janela.gu * 0.55)
        width: parent.width
        spacing: 1
        Texto {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: cartao.artista ? janela.nomeArtista(cartao.artista.nome) : ""
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Texto {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: cartao.artista ? janela.contagem(cartao.artista.faixas.length, "música", "músicas", "song", "songs") : ""
            font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
            opacity: 0.62
        }
    }
}
