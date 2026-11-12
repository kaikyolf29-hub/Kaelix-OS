// A barra do player, embaixo de todas as páginas: a capa (clicar abre o Tocando
// agora), o título e o artista, anterior / tocar / próxima com o aleatório e o
// repetir, a onda com o progresso e os tempos, e o volume. Larga, fica tudo numa
// linha; estreita, a onda sobe para uma linha só dela.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: barra

    readonly property bool larga: width > janela.gu * 46
    readonly property var m: janela.atual

    implicitHeight: Math.round(janela.gu * (larga ? 4.2 : 6.6))
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutCubic
        }
    }

    RectangularShadow {
        anchors.fill: fundo
        radius: fundo.radius
        offset.y: Math.round(janela.gu * 0.2)
        blur: Math.round(janela.gu * 1.2)
        spread: -Math.round(janela.gu * 0.1)
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.42 : 0.1)
    }
    Rectangle {
        id: fundo
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.85)
        color: janela.escuro ? Qt.rgba(0.165, 0.165, 0.175, 0.97) : Qt.rgba(1, 1, 1, 0.94)
        border.width: 1
        border.color: janela.tinta(janela.escuro ? 0.08 : 0.07)
    }

    GridLayout {
        id: grade
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 0.6)
        anchors.rightMargin: Math.round(janela.gu * 0.8)
        anchors.topMargin: Math.round(janela.gu * (barra.larga ? 0.6 : 0.5))
        anchors.bottomMargin: Math.round(janela.gu * 0.6)
        columns: 6
        rowSpacing: Math.round(janela.gu * 0.25)
        columnSpacing: Math.round(janela.gu * 0.6)

        // ----- a capa -----
        MouseArea {
            id: areaCapa
            Layout.row: barra.larga ? 0 : 1
            Layout.column: 0
            Layout.preferredWidth: Math.round(janela.gu * 2.9)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            hoverEnabled: true
            cursorShape: barra.m ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: barra.m !== null
            Accessible.role: Accessible.Button
            Accessible.name: janela.t("Abrir o Tocando agora", "Open Now Playing")
            onClicked: janela.tocandoAgoraAberto = true

            Capa {
                id: capaBarra
                anchors.fill: parent
                caminho: barra.m ? barra.m.capa : ""
                nome: barra.m ? barra.m.album || barra.m.titulo : ""
                raio: Math.round(janela.gu * 0.4)
                scale: areaCapa.pressed ? 0.94 : (areaCapa.containsMouse ? 1.04 : 1)
                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                    }
                }
                // Com o mouse em cima: escurece e mostra a setinha de abrir.
                Rectangle {
                    anchors.fill: parent
                    radius: capaBarra.raio
                    color: Qt.rgba(0, 0, 0, 0.42)
                    opacity: areaCapa.containsMouse ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.4)
                        height: width
                        source: janela.ic("expandir")
                        isMask: true
                        color: "#ffffff"
                    }
                }
            }
            QQC2.ToolTip.visible: containsMouse && !janela.tocandoAgoraAberto
            QQC2.ToolTip.text: janela.t("Tocando agora", "Now playing")
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        // ----- título e artista -----
        Item {
            id: textos
            Layout.row: barra.larga ? 0 : 1
            Layout.column: 1
            Layout.fillWidth: !barra.larga
            Layout.preferredWidth: barra.larga ? Math.round(Math.min(janela.gu * 11, Math.max(janela.gu * 6.5, barra.width * 0.19))) : -1
            Layout.minimumWidth: Math.round(janela.gu * 4)
            Layout.preferredHeight: colunaTextos.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            clip: true

            ColumnLayout {
                id: colunaTextos
                width: parent.width
                spacing: 1
                Texto {
                    id: tituloBarra
                    Layout.fillWidth: true
                    text: barra.m ? barra.m.titulo : janela.t("Nada tocando", "Nothing playing")
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    opacity: barra.m ? 1 : 0.6
                    MouseArea {
                        anchors.fill: parent
                        enabled: barra.m !== null
                        cursorShape: Qt.PointingHandCursor
                        onClicked: janela.tocandoAgoraAberto = true
                    }
                }
                Texto {
                    id: artistaBarra
                    Layout.fillWidth: true
                    text: barra.m ? janela.nomeArtista(barra.m.artista) : janela.t("Escolha uma música", "Pick a song")
                    elide: Text.ElideRight
                    font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
                    opacity: areaArtista.containsMouse ? 0.95 : 0.62
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                    MouseArea {
                        id: areaArtista
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.min(parent.width, parent.contentWidth)
                        enabled: barra.m !== null && barra.m.chaveArtista !== undefined && !!janela.porArtista[barra.m.chaveArtista]
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: janela.abrirArtista(barra.m.chaveArtista)
                    }
                }
            }
            // A música nova entra deslizando de leve.
            Connections {
                target: janela
                function onAtualChanged() {
                    trocaTexto.restart();
                }
            }
            ParallelAnimation {
                id: trocaTexto
                NumberAnimation { target: colunaTextos; property: "opacity"; from: 0; to: 1; duration: 260 }
                NumberAnimation { target: colunaTextos; property: "x"; from: Math.round(janela.gu * 0.5); to: 0; duration: 340; easing.type: Easing.OutCubic }
            }
        }

        // ----- os controles -----
        Row {
            id: controles
            Layout.row: barra.larga ? 0 : 1
            Layout.column: 2
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(janela.gu * 0.2)

            BotaoIcone {
                anchors.verticalCenter: parent.verticalCenter
                visible: barra.width > janela.gu * 30
                icone: janela.ic("aleatorio")
                alternavel: true
                ligado: janela.aleatorio
                dica: janela.aleatorio ? janela.t("Aleatório: ligado", "Shuffle: on") : janela.t("Aleatório: desligado", "Shuffle: off")
                onClicado: janela.alternarAleatorio()
            }
            BotaoIcone {
                anchors.verticalCenter: parent.verticalCenter
                icone: janela.ic("anterior")
                ativo: janela.fila.length > 0
                dica: janela.t("Anterior", "Previous")
                atalho: "Ctrl+←"
                onClicado: janela.anterior()
            }
            BotaoTocar {
                anchors.verticalCenter: parent.verticalCenter
                diametro: Math.round(janela.gu * 2.3)
                tocando: janela.tocando
                ativo: janela.atual !== null || janela.musicas.length > 0
                onClicado: janela.tocarPausar()
            }
            BotaoIcone {
                anchors.verticalCenter: parent.verticalCenter
                icone: janela.ic("proxima")
                ativo: janela.fila.length > 0
                dica: janela.t("Próxima", "Next")
                atalho: "Ctrl+→"
                onClicado: janela.proxima(false)
            }
            BotaoIcone {
                anchors.verticalCenter: parent.verticalCenter
                visible: barra.width > janela.gu * 30
                icone: janela.ic(janela.repetir === "uma" ? "repetir-um" : "repetir")
                alternavel: true
                ligado: janela.repetir !== "nao"
                dica: janela.repetir === "tudo" ? janela.t("Repetir: a fila", "Repeat: all")
                      : (janela.repetir === "uma" ? janela.t("Repetir: esta música", "Repeat: one") : janela.t("Repetir: desligado", "Repeat: off"))
                onClicado: janela.alternarRepetir()
            }
        }

        // ----- a onda com o progresso -----
        Onda {
            id: onda
            Layout.row: 0
            Layout.column: barra.larga ? 3 : 0
            Layout.columnSpan: barra.larga ? 1 : 5
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(janela.gu * (barra.larga ? 2.0 : 1.7))
            Layout.leftMargin: barra.larga ? Math.round(janela.gu * 0.4) : Math.round(janela.gu * 0.2)
            amostras: janela.ondaAtual
            progresso: janela.progresso
            tocando: janela.tocando
            opacity: janela.atual ? 1 : 0.5
            enabled: janela.atual !== null
            onBuscar: (f) => janela.buscar(f)
        }
        Texto {
            id: tempos
            Layout.row: 0
            Layout.column: barra.larga ? 4 : 5
            Layout.alignment: Qt.AlignVCenter
            text: janela.tempo(janela.posicao / 1000) + " / " + janela.tempo(janela.duracao / 1000)
            font.features: { "tnum": 1 }
            font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
            opacity: 0.68
        }

        // ----- o volume -----
        Row {
            Layout.row: barra.larga ? 0 : 1
            Layout.column: barra.larga ? 5 : 3
            Layout.columnSpan: barra.larga ? 1 : 3
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: 2
            BotaoIcone {
                anchors.verticalCenter: parent.verticalCenter
                lado: Math.round(janela.gu * 1.7)
                icone: janela.mudo || janela.volume <= 0 ? "matsu-volume-mudo-symbolic"
                       : (janela.volume < 34 ? "matsu-volume-0-symbolic" : (janela.volume < 67 ? "matsu-volume-1-symbolic" : "matsu-volume-2-symbolic"))
                dica: janela.mudo ? janela.t("Ligar o som", "Unmute") : janela.t("Tirar o som", "Mute")
                onClicado: janela.mudo = !janela.mudo
            }
            Deslizante {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(janela.gu * (barra.larga ? 5.5 : 4.5))
                de: 0
                ate: 100
                valor: janela.mudo ? 0 : janela.volume
                nome: janela.t("Volume", "Volume")
                formato: function (v) { return janela.porcento(v); }
                onMovido: (v) => janela.mudarVolume(v)
            }
        }
    }
}
