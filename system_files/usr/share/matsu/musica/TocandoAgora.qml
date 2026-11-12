// Tocando agora: a capa enorme, o fundo na cor da capa (desfocada e bem suave),
// o título grande, a onda grande e os controles grandes. Sobe por cima das
// páginas ao clicar na capa da barra; a setinha (ou Esc) desce de volta.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: tela

    readonly property var m: janela.atual
    readonly property bool larga: width > height * 1.12
    property real abrir: janela.tocandoAgoraAberto && m !== null ? 1 : 0
    Behavior on abrir {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutCubic
        }
    }
    onMChanged: if (m === null) janela.tocandoAgoraAberto = false

    visible: abrir > 0.001
    opacity: Math.min(1, abrir * 1.6)
    // Engole os cliques e a roda do mouse (nada passa para a página de baixo).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (w) => w.accepted = true
        onClicked: (e) => { if (e.button === Qt.BackButton) janela.tocandoAgoraAberto = false; }
    }

    // Os cantos de baixo acompanham o arredondado da janela.
    layer.enabled: visible && janela.raio > 0
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: mascara
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
    Rectangle {
        id: mascara
        anchors.fill: parent
        visible: false
        layer.enabled: true
        bottomLeftRadius: Math.max(0, janela.raio - 1)
        bottomRightRadius: Math.max(0, janela.raio - 1)
        color: "white"
    }

    // ----- o fundo: a capa desfocada e um véu na cor do tema -----
    Rectangle {
        anchors.fill: parent
        color: janela.escuro ? "#141416" : "#f4f4f6"
    }
    FundoCapa {
        anchors.fill: parent
        caminho: tela.m ? tela.m.capa : ""
        nome: tela.m ? (tela.m.album || tela.m.titulo) : ""
        saturacao: janela.escuro ? 0.1 : 0.2
        opacity: janela.escuro ? 0.85 : 0.7
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: janela.escuro ? Qt.rgba(0.06, 0.06, 0.07, 0.42) : Qt.rgba(0.98, 0.98, 0.99, 0.5) }
            GradientStop { position: 1; color: janela.escuro ? Qt.rgba(0.05, 0.05, 0.06, 0.66) : Qt.rgba(0.98, 0.98, 0.99, 0.72) }
        }
    }

    // ----- o topo: descer e ir para a fila -----
    BotaoIcone {
        id: descer
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Math.round(janela.gu * 0.8)
        icone: "matsu-seta-symbolic"
        rotation: 90
        dica: janela.t("Voltar", "Back")
        atalho: "Esc"
        onClicado: janela.tocandoAgoraAberto = false
    }
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: descer.verticalCenter
        width: Math.min(parent.width - janela.gu * 9, janela.gu * 24)
        spacing: 0
        Texto {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: janela.t("TOCANDO AGORA", "NOW PLAYING")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            opacity: 0.6
        }
        Texto {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: !!(tela.m && tela.m.album)
            text: tela.m ? tela.m.album : ""
            elide: Text.ElideRight
            font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
            opacity: 0.85
        }
    }
    BotaoIcone {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Math.round(janela.gu * 0.8)
        icone: janela.ic("fila")
        dica: janela.t("Ver a fila", "Show the queue")
        onClicado: {
            janela.tocandoAgoraAberto = false;
            janela.irPara("fila");
        }
    }

    // ----- a capa e as informações -----
    GridLayout {
        id: corpo
        anchors.fill: parent
        anchors.topMargin: Math.round(janela.gu * 3.6)
        anchors.bottomMargin: Math.round(janela.gu * 1.6)
        anchors.leftMargin: Math.round(janela.gu * (tela.larga ? 3 : 1.6))
        anchors.rightMargin: Math.round(janela.gu * (tela.larga ? 3 : 1.6))
        columns: tela.larga ? 2 : 1
        columnSpacing: Math.round(janela.gu * 3)
        rowSpacing: Math.round(janela.gu * 1.2)
        // Entra subindo junto com a tela.
        transform: Translate { y: (1 - tela.abrir) * janela.gu * 3 }

        Item {
            Layout.alignment: Qt.AlignCenter
            readonly property real lado: tela.larga
                                         ? Math.min(corpo.height * 0.92, corpo.width * 0.44, janela.gu * 26)
                                         : Math.min(corpo.width * 0.7, corpo.height * 0.42, janela.gu * 20)
            Layout.preferredWidth: lado
            Layout.preferredHeight: lado
            Capa {
                id: capaGrande
                anchors.fill: parent
                caminho: tela.m ? tela.m.capa : ""
                nome: tela.m ? (tela.m.album || tela.m.titulo) : ""
                raio: Math.round(janela.gu * 0.9)
                sombra: 1
                // Pausada, a capa encolhe um pouco (como no Apple Music).
                scale: (janela.tocando ? 1 : 0.93) * (0.9 + 0.1 * tela.abrir)
                Behavior on scale {
                    NumberAnimation {
                        duration: 420
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.3
                    }
                }
            }
        }

        ColumnLayout {
            id: info
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(janela.gu * 30)
            Layout.alignment: tela.larga ? Qt.AlignVCenter | Qt.AlignLeft : Qt.AlignHCenter | Qt.AlignTop
            spacing: Math.round(janela.gu * 0.3)

            Texto {
                Layout.fillWidth: true
                horizontalAlignment: tela.larga ? Text.AlignLeft : Text.AlignHCenter
                text: tela.m ? tela.m.titulo : ""
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * (tela.larga ? 2.1 : 1.7)
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Texto {
                id: artistaGrande
                Layout.fillWidth: true
                horizontalAlignment: tela.larga ? Text.AlignLeft : Text.AlignHCenter
                text: tela.m ? janela.nomeArtista(tela.m.artista) + (tela.m.ano ? " · " + tela.m.ano : "") : ""
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
                elide: Text.ElideRight
                opacity: areaArtistaGrande.containsMouse ? 1 : 0.72
                MouseArea {
                    id: areaArtistaGrande
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !!(tela.m && janela.porArtista[tela.m.chaveArtista])
                    cursorShape: Qt.PointingHandCursor
                    onClicked: janela.abrirArtista(tela.m.chaveArtista)
                }
            }

            Onda {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 1.1)
                Layout.preferredHeight: Math.round(janela.gu * 3.4)
                grossura: Math.max(3, Math.round(janela.gu * 0.24))
                vao: Math.max(2, Math.round(janela.gu * 0.17))
                amostras: janela.ondaAtual
                progresso: janela.progresso
                tocando: janela.tocando
                onBuscar: (f) => janela.buscar(f)
            }
            RowLayout {
                Layout.fillWidth: true
                Texto {
                    text: janela.tempo(janela.posicao / 1000)
                    font.features: { "tnum": 1 }
                    opacity: 0.7
                }
                Item {
                    Layout.fillWidth: true
                }
                Texto {
                    text: "−" + janela.tempo(Math.max(0, janela.duracao - janela.posicao) / 1000)
                    font.features: { "tnum": 1 }
                    opacity: 0.7
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(janela.gu * 0.6)
                spacing: Math.round(janela.gu * 0.9)
                BotaoIcone {
                    anchors.verticalCenter: parent.verticalCenter
                    lado: Math.round(janela.gu * 2.4)
                    icone: janela.ic("aleatorio")
                    alternavel: true
                    ligado: janela.aleatorio
                    dica: janela.aleatorio ? janela.t("Aleatório: ligado", "Shuffle: on") : janela.t("Aleatório: desligado", "Shuffle: off")
                    onClicado: janela.alternarAleatorio()
                }
                BotaoIcone {
                    anchors.verticalCenter: parent.verticalCenter
                    lado: Math.round(janela.gu * 2.8)
                    icone: janela.ic("anterior")
                    dica: janela.t("Anterior", "Previous")
                    atalho: "Ctrl+←"
                    onClicado: janela.anterior()
                }
                BotaoTocar {
                    anchors.verticalCenter: parent.verticalCenter
                    diametro: Math.round(janela.gu * 3.8)
                    tocando: janela.tocando
                    onClicado: janela.tocarPausar()
                }
                BotaoIcone {
                    anchors.verticalCenter: parent.verticalCenter
                    lado: Math.round(janela.gu * 2.8)
                    icone: janela.ic("proxima")
                    dica: janela.t("Próxima", "Next")
                    atalho: "Ctrl+→"
                    onClicado: janela.proxima(false)
                }
                BotaoIcone {
                    anchors.verticalCenter: parent.verticalCenter
                    lado: Math.round(janela.gu * 2.4)
                    icone: janela.ic(janela.repetir === "uma" ? "repetir-um" : "repetir")
                    alternavel: true
                    ligado: janela.repetir !== "nao"
                    dica: janela.repetir === "tudo" ? janela.t("Repetir: a fila", "Repeat: all")
                          : (janela.repetir === "uma" ? janela.t("Repetir: esta música", "Repeat: one") : janela.t("Repetir: desligado", "Repeat: off"))
                    onClicado: janela.alternarRepetir()
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(janela.gu * 0.5)
                spacing: Math.round(janela.gu * 0.3)
                BotaoIcone {
                    lado: Math.round(janela.gu * 1.7)
                    icone: janela.mudo || janela.volume <= 0 ? "matsu-volume-mudo-symbolic" : "matsu-volume-0-symbolic"
                    dica: janela.mudo ? janela.t("Ligar o som", "Unmute") : janela.t("Tirar o som", "Mute")
                    onClicado: janela.mudo = !janela.mudo
                }
                Deslizante {
                    Layout.preferredWidth: Math.round(janela.gu * 10)
                    de: 0
                    ate: 100
                    valor: janela.mudo ? 0 : janela.volume
                    nome: janela.t("Volume", "Volume")
                    formato: function (v) { return janela.porcento(v); }
                    onMovido: (v) => janela.mudarVolume(v)
                }
                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    source: "matsu-volume-2-symbolic"
                    isMask: true
                    color: janela.frente
                    opacity: 0.7
                }
            }

            Texto {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.6)
                horizontalAlignment: Text.AlignHCenter
                visible: janela.proximaMusica !== null && corpo.height > janela.gu * 16
                text: janela.proximaMusica ? janela.t("A seguir: ", "Up next: ") + janela.proximaMusica.titulo + " · " + janela.nomeArtista(janela.proximaMusica.artista) : ""
                elide: Text.ElideRight
                font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
                opacity: 0.6
            }
        }
    }
}
