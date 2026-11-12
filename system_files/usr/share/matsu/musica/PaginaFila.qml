// Fila: a música de agora em destaque e o que vem a seguir. Arrastar pela alça
// muda a ordem; o menu (ou Delete) tira da fila; "Limpar" tira tudo o que vem a
// seguir (a música de agora continua).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property var aSeguir: janela.fila.slice(janela.indice + 1).map(function (c) { return janela.musicaDe(c); })
    readonly property real totalSeguir: {
        var t = 0;
        for (var i = 0; i < aSeguir.length; i++)
            t += aSeguir[i] ? aSeguir[i].duracao : 0;
        return t;
    }

    ListView {
        id: lista
        anchors.fill: parent
        visible: janela.atual !== null
        model: pagina.aSeguir.length
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1
        keyNavigationEnabled: true
        highlightFollowsCurrentItem: false
        activeFocusOnTab: true
        QQC2.ScrollBar.vertical: BarraRolagem {}
        // Arrastando: de onde saiu e para onde vai (-1: nada).
        property int arrastando: -1
        property int alvo: -1
        Keys.onDeletePressed: if (currentIndex >= 0) janela.removerDaFila(janela.indice + 1 + currentIndex)
        Keys.onReturnPressed: if (currentIndex >= 0) { janela.indice = janela.indice + 1 + currentIndex; janela.carregar(true, 0); }

        header: ColumnLayout {
            width: lista.width
            spacing: Math.round(janela.gu * 1.0)
            CabecalhoPagina {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 1.2)
                Layout.leftMargin: pagina.margem
                Layout.rightMargin: pagina.margem
                titulo: janela.t("Fila", "Queue")
                detalhe: pagina.aSeguir.length > 0
                         ? janela.contagem(pagina.aSeguir.length, "música a seguir", "músicas a seguir", "song up next", "songs up next") + " · " + janela.tempoTotal(pagina.totalSeguir)
                         : janela.t("Nada a seguir", "Nothing up next")
                Botao {
                    texto: janela.t("Limpar", "Clear")
                    icone: "matsu-lixeira-symbolic"
                    ativo: pagina.aSeguir.length > 0
                    dica: janela.t("Tira da fila tudo o que vem a seguir", "Removes everything up next")
                    onClicado: janela.limparFila()
                }
            }

            // ----- tocando agora -----
            Texto {
                Layout.leftMargin: pagina.margem
                text: janela.t("TOCANDO AGORA", "NOW PLAYING")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
                opacity: 0.6
            }
            Cartao {
                id: agora
                Layout.fillWidth: true
                Layout.leftMargin: pagina.margem
                Layout.rightMargin: pagina.margem
                implicitHeight: Math.round(janela.gu * 5.2)
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: janela.tocandoAgoraAberto = true
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.7)
                    spacing: Math.round(janela.gu * 0.9)
                    Capa {
                        Layout.preferredWidth: Math.round(janela.gu * 3.8)
                        Layout.preferredHeight: Layout.preferredWidth
                        caminho: janela.atual ? janela.atual.capa : ""
                        nome: janela.atual ? (janela.atual.album || janela.atual.titulo) : ""
                        raio: Math.round(janela.gu * 0.45)
                        sombra: 0.5
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Texto {
                            Layout.fillWidth: true
                            text: janela.atual ? janela.atual.titulo : ""
                            font.weight: Font.DemiBold
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                            elide: Text.ElideRight
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: janela.atual ? janela.nomeArtista(janela.atual.artista) + " · " + janela.nomeAlbum(janela.atual.album) : ""
                            opacity: 0.65
                            elide: Text.ElideRight
                        }
                    }
                    Barrinhas {
                        Layout.preferredWidth: Math.round(janela.gu * 1.2)
                        Layout.preferredHeight: Math.round(janela.gu * 1.1)
                        rodando: janela.tocando
                    }
                    BotaoTocar {
                        diametro: Math.round(janela.gu * 2.4)
                        tocando: janela.tocando
                        onClicado: janela.tocarPausar()
                    }
                }
            }

            Titulo {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.6)
                Layout.leftMargin: pagina.margem
                Layout.rightMargin: pagina.margem
                visible: pagina.aSeguir.length > 0
                texto: janela.t("A seguir", "Up next")
            }
            Texto {
                Layout.fillWidth: true
                Layout.leftMargin: pagina.margem
                Layout.rightMargin: pagina.margem
                Layout.topMargin: Math.round(janela.gu * 0.6)
                visible: pagina.aSeguir.length === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.6
                text: janela.t("Nada a seguir. Use “Tocar a seguir” ou “Adicionar à fila” no menu de uma música.",
                               "Nothing up next. Use “Play next” or “Add to queue” from a song's menu.")
            }
            Item {
                implicitHeight: Math.round(janela.gu * 0.1)
            }
        }
        footer: Item {
            width: 1
            height: Math.round(janela.gu * 1.2)
        }

        delegate: Item {
            id: item
            required property int index
            readonly property var musica: pagina.aSeguir[index] || null
            width: lista.width
            height: linhaFila.implicitHeight
            opacity: lista.arrastando === index ? 0.45 : 1

            // A linha onde a música arrastada vai entrar.
            Rectangle {
                z: 3
                visible: lista.arrastando >= 0 && lista.alvo === index && lista.alvo !== lista.arrastando
                x: pagina.margem
                width: parent.width - 2 * pagina.margem
                height: 2
                radius: 1
                y: lista.alvo > lista.arrastando ? parent.height - 1 : -1
                color: janela.frente
            }
            // A alça de arrastar.
            MouseArea {
                id: alca
                x: Math.round(pagina.margem * 0.15)
                width: Math.round(pagina.margem * 0.75)
                height: parent.height
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true
                onPressed: { lista.arrastando = item.index; lista.alvo = item.index; }
                onPositionChanged: (m) => {
                    if (!pressed)
                        return;
                    var p = alca.mapToItem(lista.contentItem, m.x, m.y);
                    var i = lista.indexAt(lista.width / 2, p.y);
                    if (i >= 0)
                        lista.alvo = i;
                    else if (p.y < lista.contentItem.childrenRect.y + janela.gu * 12)
                        lista.alvo = 0;
                    else
                        lista.alvo = pagina.aSeguir.length - 1;
                }
                onReleased: {
                    if (lista.alvo >= 0 && lista.alvo !== lista.arrastando)
                        janela.moverNaFila(janela.indice + 1 + lista.arrastando, janela.indice + 1 + lista.alvo);
                    lista.arrastando = -1;
                    lista.alvo = -1;
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    source: janela.ic("arrastar")
                    isMask: true
                    color: janela.frente
                    opacity: alca.containsMouse || alca.pressed ? 0.8 : (linhaFila.containsMouse ? 0.4 : 0)
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }
                QQC2.ToolTip.visible: containsMouse && !pressed
                QQC2.ToolTip.text: janela.t("Arraste para mudar a ordem", "Drag to reorder")
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            LinhaMusica {
                id: linhaFila
                x: pagina.margem
                width: parent.width - 2 * pagina.margem
                musica: item.musica
                numero: String(item.index + 1)
                eAtual: false
                escolhida: lista.currentIndex === item.index
                onEscolher: {
                    lista.currentIndex = item.index;
                    lista.forceActiveFocus();
                }
                onTocar: {
                    janela.indice = janela.indice + 1 + item.index;
                    janela.carregar(true, 0);
                }
                onMenu: (x, y) => janela.menuMusicas(linhaFila, x, y, [item.musica.caminho], { filaIndice: janela.indice + 1 + item.index })
            }
        }
    }

    Vazio {
        anchors.centerIn: parent
        visible: janela.atual === null
        icone: janela.ic("fila")
        titulo: janela.t("A fila está vazia", "The queue is empty")
        texto: janela.t("Escolha uma música, um álbum ou uma playlist para tocar.", "Pick a song, an album or a playlist to play.")
        botao: janela.t("Tocar tudo", "Play all")
        onClicado: janela.tocarTudo(false)
    }
}
