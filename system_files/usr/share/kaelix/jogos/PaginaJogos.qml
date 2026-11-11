// Meus jogos: as capas da biblioteca da Steam em grade, em ordem de último
// jogado, mais jogados ou nome. A busca da barra de título filtra. Clicar numa
// capa abre os detalhes do jogo (o fundo grande, as horas e o perfil dele).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    property string ordem: "recentes"
    readonly property int margem: Math.round(janela.gu * 1.4)

    readonly property var lista: {
        var b = janela.simples(janela.busca.trim());
        var l = janela.jogos.filter(function (j) {
            return b.length === 0 || janela.simples(j.nome).indexOf(b) >= 0;
        });
        if (ordem === "mais")
            l.sort(function (a, c) { return c.minutos - a.minutos || a.nome.localeCompare(c.nome); });
        else if (ordem === "nome")
            l.sort(function (a, c) { return a.nome.localeCompare(c.nome, janela.pt ? "pt-BR" : "en"); });
        return l;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: pagina.margem
        spacing: Math.round(janela.gu * 0.9)
        // Com os detalhes de um jogo abertos, a grade some (os detalhes ficam no vidro).
        opacity: 1 - detalhe.opacity
        visible: opacity > 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: pagina.margem
            Layout.rightMargin: pagina.margem
            spacing: Math.round(janela.gu * 0.8)

            ColumnLayout {
                spacing: 0
                Texto {
                    text: janela.t("Meus jogos", "My games")
                    font.pixelSize: Math.round(janela.gu * 1.3)
                    font.weight: Font.DemiBold
                }
                Texto {
                    text: {
                        var n = janela.jogos.length;
                        var total = 0;
                        for (var i = 0; i < janela.jogos.length; i++)
                            total += janela.jogos[i].minutos;
                        if (janela.busca.length > 0)
                            return pagina.lista.length + janela.t(" de " + n + " jogos", " of " + n + " games");
                        return (n === 1 ? janela.t("1 jogo", "1 game") : n + janela.t(" jogos", " games"))
                               + (total > 0 ? "  ·  " + janela.horas(total) + janela.t(" jogadas no total", " played in total") : "");
                    }
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.6
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Seletor {
                visible: janela.jogos.length > 1
                opcoes: [{ id: "recentes", nome: janela.t("Recentes", "Recent") },
                         { id: "mais", nome: janela.t("Mais jogados", "Most played") },
                         { id: "nome", nome: janela.t("A a Z", "A to Z") }]
                escolhido: pagina.ordem
                onEscolher: (id) => pagina.ordem = id
            }
        }

        GridView {
            id: grade
            readonly property int alvo: Math.round(janela.gu * 7.6)
            readonly property int colunas: Math.max(2, Math.floor((width - 2 * pagina.margem) / (alvo + janela.gu)))
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            leftMargin: pagina.margem
            rightMargin: pagina.margem
            topMargin: Math.round(janela.gu * 0.4)
            bottomMargin: pagina.margem
            cellWidth: Math.floor((width - 2 * pagina.margem) / colunas)
            cellHeight: Math.round((cellWidth - janela.gu) * 1.5 + janela.gu * 3.6)
            model: pagina.lista
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

            delegate: Item {
                id: celula
                required property var modelData
                width: grade.cellWidth
                height: grade.cellHeight
                Capa {
                    x: Math.round(janela.gu * 0.5)
                    y: Math.round(janela.gu * 0.3)
                    width: celula.width - janela.gu
                    jogo: celula.modelData
                    onAbrir: janela.jogoAberto = celula.modelData.id
                    onJogar: janela.jogar(celula.modelData.id)
                }
            }

            // Vazio: sem jogos, ou nada na busca.
            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 4 * janela.gu, janela.gu * 22)
                visible: janela.bibliotecaLida && pagina.lista.length === 0
                spacing: Math.round(janela.gu * 0.6)
                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.round(janela.gu * 3.2)
                    Layout.preferredHeight: Layout.preferredWidth
                    source: janela.busca.length > 0 ? "kaelix-busca-symbolic" : "kaelix-jogos-symbolic"
                    isMask: true
                    color: janela.frente
                    opacity: 0.4
                }
                Texto {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: janela.busca.length > 0 ? janela.t("Nenhum jogo com “" + janela.busca + "”", "No games matching “" + janela.busca + "”")
                                                  : janela.t("Nenhum jogo ainda", "No games yet")
                    font.weight: Font.DemiBold
                }
                Texto {
                    Layout.fillWidth: true
                    visible: janela.busca.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: janela.t("Os jogos que você instalar pela Steam aparecem aqui sozinhos, com a capa.",
                                   "Games you install with Steam show up here on their own, with their cover art.")
                    opacity: 0.65
                }
                BotaoDestaque {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Math.round(janela.gu * 0.3)
                    visible: janela.busca.length === 0
                    texto: janela.t("Abrir a Steam", "Open Steam")
                    icone: "steam"
                    iconeColorido: true
                    onClicado: janela.abrirSteam()
                }
            }
        }
    }

    // ----- detalhes do jogo, por cima da grade -----
    DetalheJogo {
        id: detalhe
        anchors.fill: parent
        jogo: janela.jogoAberto ? janela.jogoPorId(janela.jogoAberto) : null
        onFechar: janela.jogoAberto = ""
    }
}
