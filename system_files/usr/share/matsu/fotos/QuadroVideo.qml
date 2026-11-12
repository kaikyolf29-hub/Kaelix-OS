// Um vídeo no visualizador (QtMultimedia): toca quando é o da vez e pausa ao
// passar para outro. Clicar toca e pausa; embaixo, a barra do tempo (clicar ou
// arrastar pula) e o som. Fica num arquivo à parte, carregado só para vídeos.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtMultimedia
import org.kde.kirigami as Kirigami

Item {
    id: quadro

    property var foto: ({})
    property bool atual: false
    property bool controles: true

    signal tocado()

    readonly property bool tocando: player.playbackState === MediaPlayer.PlayingState
    readonly property bool erro: player.error !== MediaPlayer.NoError

    function alternar() {
        if (tocando)
            player.pause();
        else
            player.play();
    }
    function tempo(ms) {
        var s = Math.max(0, Math.floor(ms / 1000));
        var m = Math.floor(s / 60);
        s -= m * 60;
        var h = Math.floor(m / 60);
        m -= h * 60;
        return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    onAtualChanged: {
        if (atual) {
            player.play();
        } else {
            player.pause();
            player.position = 0;
        }
    }
    Component.onCompleted: if (atual) player.play()

    MediaPlayer {
        id: player
        source: janela.arquivo(quadro.foto.caminho)
        videoOutput: saida
        audioOutput: AudioOutput {
            id: som
            muted: janela.semSom
        }
        loops: MediaPlayer.Once
    }
    VideoOutput {
        id: saida
        anchors.fill: parent
        anchors.margins: Math.round(janela.gu * 0.5)
        fillMode: VideoOutput.PreserveAspectFit
    }
    // A capa enquanto o vídeo não começa.
    Image {
        anchors.fill: saida
        visible: !quadro.tocando && player.position === 0 && (quadro.foto.capa || "") !== ""
        source: (quadro.foto.capa || "") !== "" ? janela.arquivo(quadro.foto.capa) : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    TapHandler {
        onSingleTapped: quadro.alternar()
        onDoubleTapped: janela.alternarTelaCheia()
    }

    // O botão grande no meio, quando está parado.
    Rectangle {
        anchors.centerIn: parent
        width: Math.round(janela.gu * 4.2)
        height: width
        radius: width / 2
        color: Qt.rgba(0, 0, 0, 0.45)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.2)
        visible: opacity > 0
        opacity: !quadro.tocando && !quadro.erro ? 1 : 0
        scale: !quadro.tocando ? 1 : 0.8
        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutBack
            }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: Math.round(parent.width * 0.04)
            width: Math.round(parent.width * 0.42)
            height: width
            source: String(Qt.resolvedUrl("icones/tocar.svg"))
            isMask: true
            color: "#ffffff"
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: quadro.alternar()
        }
    }

    // Não deu para tocar (formato sem suporte, arquivo estragado).
    Column {
        anchors.centerIn: parent
        spacing: Math.round(janela.gu * 0.5)
        visible: quadro.erro
        width: Math.min(parent.width - janela.gu * 2, janela.gu * 20)
        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(janela.gu * 3)
            height: width
            source: String(Qt.resolvedUrl("icones/video.svg"))
            isMask: true
            color: "#ffffff"
            opacity: 0.6
        }
        QQC2.Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#ffffff"
            font.weight: Font.DemiBold
            text: janela.t("Não deu para tocar este vídeo", "Couldn't play this video")
        }
    }

    // Barra de baixo: tocar/pausar, o tempo, a linha do tempo e o som.
    Rectangle {
        id: barra
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(janela.gu * 5.2)
        width: Math.min(parent.width - janela.gu * 3, janela.gu * 34)
        height: Math.round(janela.gu * 2.6)
        radius: height / 2
        color: Qt.rgba(0.08, 0.08, 0.09, 0.78)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        opacity: quadro.controles && !quadro.erro ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: Math.round(janela.gu * 0.6)
            spacing: Math.round(janela.gu * 0.5)
            BotaoVisor {
                lado: Math.round(janela.gu * 2.1)
                icone: quadro.tocando ? String(Qt.resolvedUrl("icones/pausa.svg")) : String(Qt.resolvedUrl("icones/tocar.svg"))
                dica: quadro.tocando ? janela.t("Pausar", "Pause") : janela.t("Tocar", "Play")
                atalho: janela.t("Espaço", "Space")
                onClicado: quadro.alternar()
            }
            QQC2.Label {
                text: quadro.tempo(linhaTempo.arrastando ? linhaTempo.alvo * player.duration : player.position)
                color: "#ffffff"
                font.features: { "tnum": 1 }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            Item {
                id: linhaTempo
                Layout.fillWidth: true
                Layout.fillHeight: true
                property bool arrastando: toque.pressed
                property real alvo: 0
                readonly property real fracao: arrastando ? alvo : (player.duration > 0 ? player.position / player.duration : 0)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: toque.containsMouse || linhaTempo.arrastando ? 6 : 4
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.22)
                    Behavior on height {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                    Rectangle {
                        width: parent.width * linhaTempo.fracao
                        height: parent.height
                        radius: height / 2
                        color: "#ffffff"
                    }
                }
                Rectangle {
                    x: parent.width * linhaTempo.fracao - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: toque.containsMouse || linhaTempo.arrastando ? 13 : 0
                    height: width
                    radius: width / 2
                    color: "#ffffff"
                    Behavior on width {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                            easing.type: Easing.OutBack
                        }
                    }
                }
                MouseArea {
                    id: toque
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function marcar(x) {
                        linhaTempo.alvo = Math.max(0, Math.min(1, x / width));
                    }
                    onPressed: (m) => marcar(m.x)
                    onPositionChanged: (m) => {
                        if (pressed)
                            marcar(m.x);
                    }
                    onReleased: player.position = linhaTempo.alvo * player.duration
                }
            }
            QQC2.Label {
                text: quadro.tempo(player.duration)
                color: "#ffffff"
                opacity: 0.65
                font.features: { "tnum": 1 }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            BotaoVisor {
                lado: Math.round(janela.gu * 2.1)
                icone: janela.semSom ? "matsu-volume-mudo-symbolic" : "matsu-volume-2-symbolic"
                dica: janela.semSom ? janela.t("Ligar o som", "Unmute") : janela.t("Tirar o som", "Mute")
                atalho: "M"
                onClicado: janela.semSom = !janela.semSom
            }
        }
    }
}
