// O miolo da Música: a página aberta (que entra deslizando de leve ao trocar) e,
// embaixo de todas, a barra do player. Sem músicas na pasta, o estado vazio.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: miolo

    readonly property bool vazia: !janela.lendo && janela.lidaUmaVez && janela.musicas.length === 0
    readonly property bool primeiraLeitura: !janela.lidaUmaVez
    readonly property bool mostrarBarra: !vazia && !primeiraLeitura || janela.fila.length > 0
    readonly property string arquivoPagina: ({
        inicio: "PaginaInicio.qml", musicas: "PaginaMusicas.qml", albuns: "PaginaAlbuns.qml",
        artistas: "PaginaArtistas.qml", playlists: "PaginaPlaylists.qml", fila: "PaginaFila.qml"
    })[janela.pagina] || "PaginaInicio.qml"

    // O botão "voltar" do mouse fecha o álbum, o artista ou a playlist aberta.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onClicked: {
            if (janela.tocandoAgoraAberto)
                janela.tocandoAgoraAberto = false;
            else if (janela.albumAberto !== "")
                janela.albumAberto = "";
            else if (janela.artistaAberto !== "")
                janela.artistaAberto = "";
            else if (janela.playlistAberta !== "")
                janela.playlistAberta = "";
        }
    }

    Item {
        id: area
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: miolo.mostrarBarra ? barra.top : parent.bottom
        clip: true

        Loader {
            id: pagina
            anchors.fill: parent
            visible: !miolo.vazia && !miolo.primeiraLeitura
            source: visible ? miolo.arquivoPagina : ""
            onLoaded: entrada.restart()
            ParallelAnimation {
                id: entrada
                NumberAnimation { target: pagina.item; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { target: pagina.item; property: "y"; from: Math.round(janela.gu * 0.6); to: 0; duration: 320; easing.type: Easing.OutCubic }
            }
        }

        // Lendo a pasta pela primeira vez.
        ColumnLayout {
            anchors.centerIn: parent
            visible: miolo.primeiraLeitura
            spacing: Math.round(janela.gu * 0.7)
            Girando {
                Layout.alignment: Qt.AlignHCenter
                width: Math.round(janela.gu * 1.8)
            }
            Texto {
                Layout.alignment: Qt.AlignHCenter
                text: janela.t("Lendo a sua música…", "Reading your music…")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                font.weight: Font.DemiBold
            }
            Texto {
                Layout.alignment: Qt.AlignHCenter
                visible: janela.totalLer > 30
                text: janela.t(janela.num(janela.feitos) + " de " + janela.num(janela.totalLer), janela.num(janela.feitos) + " of " + janela.num(janela.totalLer))
                font.features: { "tnum": 1 }
                opacity: 0.6
            }
        }

        // A pasta Música não tem músicas.
        Loader {
            anchors.centerIn: parent
            // Com largura dada: o Vazio mede a largura pelo pai.
            width: Math.min(parent.width - janela.gu * 2, janela.gu * 22)
            active: miolo.vazia
            sourceComponent: Vazio {
                icone: janela.ic("nota")
                titulo: janela.t("Sua pasta Música está vazia", "Your Music folder is empty")
                texto: janela.t("Coloque músicas em MP3, FLAC, OGG, Opus, M4A ou WAV na pasta Música (pode ser em subpastas) e elas aparecem aqui sozinhas.",
                                "Put MP3, FLAC, OGG, Opus, M4A or WAV files in your Music folder (subfolders are fine) and they'll show up here.")
                botao: janela.t("Abrir a pasta Música", "Open the Music folder")
                onClicado: janela.abrirPastaMusica()
            }
        }
    }

    BarraPlayer {
        id: barra
        visible: miolo.mostrarBarra
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(janela.gu * 0.6)
    }
}
