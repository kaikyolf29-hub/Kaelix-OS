// Uma playlist na grade (o mosaico das capas, o nome e quantas músicas), ou o
// cartão de criar uma nova (nova: true), com o + no meio e a borda tracejada.
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: cartao

    property var playlist: null
    property bool nova: false
    readonly property var lista: {
        var _m = janela.mudancasPlaylists;
        return playlist ? janela.musicasDaPlaylist(playlist) : [];
    }
    readonly property bool estaTocando: playlist !== null && janela.tocando && lista.length > 0 && janela.atual !== null
                                        && janela.fila.length === lista.length && janela.fila.indexOf(lista[0].caminho) >= 0

    signal criar()

    implicitWidth: Math.round(janela.gu * 9)
    implicitHeight: width + textos.implicitHeight + Math.round(janela.gu * 0.6)
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: nova ? janela.t("Nova playlist", "New playlist") : (playlist ? playlist.nome : "")
    onClicked: (e) => {
        if (nova)
            cartao.criar();
        else if (e.button === Qt.RightButton && lista.length > 0)
            janela.menuMusicas(cartao, e.x, e.y, janela.caminhos(lista), { semAlbum: true, semArtista: true });
        else if (e.button === Qt.LeftButton)
            janela.abrirPlaylist(playlist.id);
    }
    Keys.onReturnPressed: nova ? cartao.criar() : janela.abrirPlaylist(playlist.id)

    Item {
        id: lugar
        width: parent.width
        height: width
        Mosaico {
            id: mosaico
            visible: !cartao.nova
            width: parent.width
            height: width
            y: cartao.containsMouse ? -Math.round(janela.gu * 0.2) : 0
            musicas: cartao.lista
            nome: cartao.playlist ? cartao.playlist.nome : ""
            sombra: cartao.containsMouse ? 1 : 0.5
            Behavior on y {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
            BotaoTocarCapa {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Math.round(janela.gu * 0.55)
                mostrar: cartao.containsMouse && cartao.lista.length > 0
                tocando: cartao.estaTocando
                onClicado: cartao.estaTocando ? janela.tocarPausar() : janela.tocarLista(janela.caminhos(cartao.lista), 0, false)
            }
        }
        // O cartão "Nova playlist": borda tracejada e o + que gira de leve com o mouse.
        Rectangle {
            visible: cartao.nova
            anchors.fill: parent
            radius: Math.round(janela.gu * 0.6)
            color: janela.tinta(cartao.pressed ? 0.08 : (cartao.containsMouse ? 0.06 : 0.03))
            Behavior on color {
                ColorAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: janela.tinta(cartao.containsMouse ? 0.32 : 0.2)
                    strokeWidth: 1.5
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [4, 4]
                    PathRectangle {
                        x: 1
                        y: 1
                        width: lugar.width - 2
                        height: lugar.height - 2
                        radius: Math.round(janela.gu * 0.6)
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: Math.round(janela.gu * 3)
                height: width
                radius: width / 2
                color: janela.tinta(cartao.containsMouse ? 0.12 : 0.07)
                scale: cartao.containsMouse ? 1.08 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutBack
                    }
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.48)
                    height: width
                    source: "matsu-mais-symbolic"
                    isMask: true
                    color: janela.frente
                    rotation: cartao.containsMouse ? 90 : 0
                    Behavior on rotation {
                        NumberAnimation {
                            duration: 320
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Math.round(janela.gu * 0.6) + 3
            color: "transparent"
            border.width: cartao.activeFocus ? 1.5 : 0
            border.color: janela.frente
        }
    }
    ColumnLayout {
        id: textos
        anchors.top: lugar.bottom
        anchors.topMargin: Math.round(janela.gu * 0.55)
        width: parent.width
        spacing: 1
        Texto {
            Layout.fillWidth: true
            text: cartao.nova ? janela.t("Nova playlist", "New playlist") : (cartao.playlist ? cartao.playlist.nome : "")
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Texto {
            Layout.fillWidth: true
            text: cartao.nova ? janela.t("Ctrl+N", "Ctrl+N") : janela.resumo(cartao.lista)
            elide: Text.ElideRight
            font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
            opacity: 0.62
        }
    }
}
