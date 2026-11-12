// A lista de músicas das páginas (com o cabeçalho das colunas e, em cima, o que a
// página quiser: o título da página, a capa do álbum...). Só monta as linhas que
// aparecem, então aguenta bibliotecas grandes. Setas escolhem, Enter toca.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"

ListView {
    id: lista

    property var musicas: []
    property Component topo: null
    property bool mostrarCapa: true
    property bool mostrarAlbum: true
    property bool mostrarArtista: true
    property bool mostrarCabecalho: true
    // function (musica, indice) -> o texto da coluna "#".
    property var numeroDe: null
    // Vai junto para o menu do botão direito ({ playlist: id }, { semAlbum: true }...).
    property var contexto: ({})
    property real margem: Math.round(janela.gu * 1.2)
    // false: quem usa trata o "tocar" (a fila toca pelo índice da fila).
    property bool tocarPadrao: true

    signal tocarIndice(int indice)

    function tocar(i) {
        if (tocarPadrao)
            janela.tocarLista(janela.caminhos(musicas), i, false);
        else
            tocarIndice(i);
    }

    model: musicas
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    reuseItems: true
    currentIndex: -1
    keyNavigationEnabled: true
    highlightFollowsCurrentItem: false
    activeFocusOnTab: true
    QQC2.ScrollBar.vertical: BarraRolagem {}
    Keys.onReturnPressed: if (currentIndex >= 0) tocar(currentIndex)
    Keys.onEnterPressed: if (currentIndex >= 0) tocar(currentIndex)
    onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
    onMusicasChanged: currentIndex = -1

    // O topo pode crescer depois de aparecer (as capas chegando): sem a pessoa ter
    // rolado, a lista continua no começo (o ListView manteria a primeira linha no lugar).
    property bool rolou: false
    onMovementStarted: rolou = true
    header: Column {
        width: lista.width
        onHeightChanged: if (!lista.rolou) Qt.callLater(lista.positionViewAtBeginning)
        Loader {
            width: parent.width
            sourceComponent: lista.topo
        }
        LinhaMusica {
            visible: lista.mostrarCabecalho
            x: lista.margem
            width: lista.width - 2 * lista.margem
            cabecalho: true
            mostrarCapa: lista.mostrarCapa
            mostrarAlbum: lista.mostrarAlbum
            mostrarArtista: lista.mostrarArtista
        }
        Item {
            width: 1
            height: Math.round(janela.gu * 0.3)
        }
    }
    footer: Item {
        width: 1
        height: Math.round(janela.gu * 1.2)
    }

    // O ListView põe cada linha em x = 0: a margem fica numa caixa por fora.
    delegate: Item {
        id: caixa
        required property var modelData
        required property int index
        width: lista.width
        height: linhaLista.implicitHeight
        LinhaMusica {
            id: linhaLista
            x: lista.margem
            width: parent.width - 2 * lista.margem
            musica: caixa.modelData
            numero: lista.numeroDe ? lista.numeroDe(caixa.modelData, caixa.index) : String(caixa.index + 1)
            mostrarCapa: lista.mostrarCapa
            mostrarAlbum: lista.mostrarAlbum
            mostrarArtista: lista.mostrarArtista
            escolhida: lista.currentIndex === caixa.index
            onEscolher: {
                lista.currentIndex = caixa.index;
                lista.forceActiveFocus();
            }
            onTocar: lista.tocar(caixa.index)
            onMenu: (x, y) => janela.menuMusicas(linhaLista, x, y, [caixa.modelData.caminho], Object.assign({ indices: [caixa.index] }, lista.contexto))
        }
    }
}
