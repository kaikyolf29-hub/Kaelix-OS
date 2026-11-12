// Uma música na lista (Músicas, álbum, artista, playlist, fila): o número (ou as
// barrinhas que pulam, se é a que está tocando; com o mouse em cima, o botão de
// tocar), a capa pequena, o título, o artista, o álbum e a duração. Dois cliques
// tocam; o botão direito (ou o "…") abre o menu. Com cabecalho: true, a mesma
// linha vira o cabeçalho das colunas (assim tudo fica alinhado).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: linha

    property var musica: null
    property string numero: ""
    property bool cabecalho: false
    property bool mostrarCapa: true
    property bool mostrarAlbum: true
    property bool mostrarArtista: true
    property bool escolhida: false
    // Na fila, a música de agora é a do índice, não qualquer uma com o mesmo caminho.
    property bool eAtual: !cabecalho && musica !== null && janela.atual !== null && janela.atual.caminho === musica.caminho

    signal tocar()
    signal menu(real x, real y)
    signal escolher()

    readonly property bool cabeAlbum: mostrarAlbum && width > janela.gu * 36
    readonly property bool cabeArtista: mostrarArtista && width > janela.gu * 24
    readonly property real fixo: Math.round(janela.gu * 2.2) + (mostrarCapa ? Math.round(janela.gu * 2.6) : 0) + Math.round(janela.gu * 3.2) + Math.round(janela.gu * 1.8)
    readonly property real livre: Math.max(0, width - fixo - Math.round(janela.gu * 1.6))
    readonly property real largTitulo: cabeAlbum ? livre * 0.42 : (cabeArtista ? livre * 0.58 : livre)
    readonly property real largArtista: cabeAlbum ? livre * 0.29 : livre * 0.42

    implicitHeight: cabecalho ? Math.round(janela.gu * 1.8) : Math.round(janela.gu * (mostrarCapa ? 2.9 : 2.5))
    hoverEnabled: !cabecalho
    acceptedButtons: cabecalho ? Qt.NoButton : Qt.LeftButton | Qt.RightButton
    Accessible.role: cabecalho ? Accessible.ColumnHeader : Accessible.ListItem
    Accessible.name: musica ? musica.titulo + ", " + janela.nomeArtista(musica.artista) : ""
    onClicked: (e) => {
        linha.escolher();
        if (e.button === Qt.RightButton)
            linha.menu(e.x, e.y);
    }
    onDoubleClicked: (e) => { if (e.button === Qt.LeftButton) linha.tocar(); }

    Rectangle {
        anchors.fill: parent
        visible: !linha.cabecalho
        radius: Math.round(janela.gu * 0.4)
        color: janela.tinta(linha.escolhida ? (janela.escuro ? 0.085 : 0.07) : (linha.pressed ? 0.07 : (linha.containsMouse ? 0.045 : 0)))
        border.width: linha.escolhida ? 1 : 0
        border.color: janela.tinta(janela.escuro ? 0.09 : 0.1)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }
    // Linha fina embaixo do cabeçalho.
    Rectangle {
        visible: linha.cabecalho
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(janela.gu * 0.4)
        anchors.rightMargin: Math.round(janela.gu * 0.4)
        height: 1
        color: janela.tinta(0.08)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 0.4)
        anchors.rightMargin: Math.round(janela.gu * 0.4)
        spacing: 0

        // ----- número, barrinhas ou o botão de tocar -----
        Item {
            Layout.preferredWidth: Math.round(janela.gu * 2.2)
            Layout.fillHeight: true
            Texto {
                anchors.centerIn: parent
                visible: linha.cabecalho || (!linha.eAtual && !linha.containsMouse)
                text: linha.cabecalho ? "#" : linha.numero
                font.features: { "tnum": 1 }
                font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
                opacity: 0.5
            }
            Barrinhas {
                anchors.centerIn: parent
                visible: linha.eAtual && !(linha.containsMouse && !janela.tocando)
                rodando: janela.tocando
            }
            MouseArea {
                id: tocarAqui
                anchors.centerIn: parent
                width: Math.round(janela.gu * 1.6)
                height: width
                visible: !linha.cabecalho && linha.containsMouse && !(linha.eAtual && janela.tocando)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: linha.eAtual ? janela.tocarPausar() : linha.tocar()
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: janela.tinta(tocarAqui.containsMouse ? 0.12 : 0)
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(janela.gu * 0.75)
                    height: width
                    source: janela.ic("tocar")
                    isMask: true
                    color: janela.frente
                }
            }
        }

        // ----- capa -----
        Item {
            visible: linha.mostrarCapa
            Layout.preferredWidth: Math.round(janela.gu * 2.6)
            Layout.fillHeight: true
            Capa {
                visible: !linha.cabecalho
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(janela.gu * 2.1)
                height: width
                raio: Math.round(janela.gu * 0.3)
                caminho: linha.musica ? linha.musica.capa : ""
                nome: linha.musica ? (linha.musica.album || linha.musica.titulo) : ""
            }
        }

        // ----- título (com o artista embaixo quando não cabe a coluna) -----
        ColumnLayout {
            Layout.preferredWidth: linha.largTitulo
            Layout.maximumWidth: linha.largTitulo
            Layout.rightMargin: Math.round(janela.gu * 0.8)
            spacing: 0
            Texto {
                Layout.fillWidth: true
                text: linha.cabecalho ? janela.t("Título", "Title") : (linha.musica ? linha.musica.titulo : "")
                elide: Text.ElideRight
                font.weight: linha.eAtual ? Font.DemiBold : Font.Normal
                font.pointSize: linha.cabecalho ? Kirigami.Theme.smallFont.pointSize + 0.5 : Kirigami.Theme.defaultFont.pointSize
                opacity: linha.cabecalho ? 0.55 : 1
            }
            Texto {
                Layout.fillWidth: true
                visible: !linha.cabecalho && !linha.cabeArtista && linha.mostrarArtista
                text: linha.musica ? janela.nomeArtista(linha.musica.artista) : ""
                elide: Text.ElideRight
                font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
                opacity: 0.6
            }
        }

        Texto {
            visible: linha.cabeArtista
            Layout.preferredWidth: linha.largArtista
            Layout.maximumWidth: linha.largArtista
            Layout.rightMargin: Math.round(janela.gu * 0.8)
            text: linha.cabecalho ? janela.t("Artista", "Artist") : (linha.musica ? janela.nomeArtista(linha.musica.artista) : "")
            elide: Text.ElideRight
            font.pointSize: linha.cabecalho ? Kirigami.Theme.smallFont.pointSize + 0.5 : Kirigami.Theme.defaultFont.pointSize
            opacity: linha.cabecalho ? 0.55 : 0.72
        }
        Texto {
            visible: linha.cabeAlbum
            Layout.fillWidth: true
            Layout.rightMargin: Math.round(janela.gu * 0.8)
            text: linha.cabecalho ? janela.t("Álbum", "Album") : (linha.musica ? janela.nomeAlbum(linha.musica.album) : "")
            elide: Text.ElideRight
            font.pointSize: linha.cabecalho ? Kirigami.Theme.smallFont.pointSize + 0.5 : Kirigami.Theme.defaultFont.pointSize
            opacity: linha.cabecalho ? 0.55 : 0.72
        }
        Item {
            visible: !linha.cabeAlbum
            Layout.fillWidth: true
        }

        // ----- duração -----
        Item {
            Layout.preferredWidth: Math.round(janela.gu * 3.2)
            Layout.fillHeight: true
            Kirigami.Icon {
                visible: linha.cabecalho
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Kirigami.Units.iconSizes.small
                height: width
                source: "matsu-relogio-symbolic"
                isMask: true
                color: janela.frente
                opacity: 0.5
            }
            Texto {
                visible: !linha.cabecalho
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: linha.musica && linha.musica.duracao > 0 ? janela.tempo(linha.musica.duracao) : "–"
                font.features: { "tnum": 1 }
                opacity: 0.62
            }
        }

        // ----- o botão "…" (aparece com o mouse em cima) -----
        Item {
            Layout.preferredWidth: Math.round(janela.gu * 1.8)
            Layout.fillHeight: true
            BotaoIcone {
                id: mais
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !linha.cabecalho
                lado: Math.round(janela.gu * 1.5)
                icone: janela.ic("mais-opcoes")
                dica: janela.t("Mais opções", "More options")
                opacity: linha.containsMouse || linha.escolhida || containsMouse ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
                onClicado: {
                    linha.escolher();
                    var p = mais.mapToItem(linha, 0, mais.height);
                    linha.menu(p.x, p.y);
                }
            }
        }
    }
}
