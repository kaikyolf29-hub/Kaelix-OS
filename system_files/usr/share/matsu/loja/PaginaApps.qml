// Apps (e Jogos): todos os apps do catálogo em cartões, com as categorias em
// pílulas em cima. Também mostra o "Ver tudo" de uma seção do Início e o
// resultado da busca (que procura em tudo, e mostra os sites que combinam).
// A grade só desenha os cartões que aparecem (o Flathub tem milhares de apps).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property int vao: Math.round(janela.gu * 0.8)
    readonly property bool jogos: janela.pagina === "jogos"
    readonly property string busca: janela.busca.trim()
    readonly property var secaoAberta: {
        for (var i = 0; i < janela.secoes.length; i++)
            if (janela.secoes[i].id === janela.secao)
                return janela.secoes[i];
        return null;
    }
    readonly property var base: {
        var _m = janela.mudancas;
        if (busca.length > 0)
            return janela.apps;
        if (secaoAberta)
            return secaoAberta.apps.map(function (i) { return janela.app(i); }).filter(function (a) { return a !== null; });
        if (jogos)
            return janela.apps.filter(function (a) { return a.categoria === "jogos"; });
        if (janela.categoria !== "")
            return janela.apps.filter(function (a) { return a.categoria === janela.categoria; });
        return janela.apps;
    }
    readonly property var lista: janela.buscar(busca, base)
    readonly property var sitesAchados: busca.length > 0 ? janela.buscar(busca, janela.sites) : []
    readonly property string titulo: {
        if (busca.length > 0)
            return janela.t("Resultados para “" + busca + "”", "Results for “" + busca + "”");
        if (secaoAberta)
            return secaoAberta.titulo;
        if (jogos)
            return janela.t("Jogos", "Games");
        if (janela.categoria !== "")
            return janela.nomeCategoria(janela.categoria);
        return janela.t("Todos os apps", "All apps");
    }

    GridView {
        id: grade
        anchors.fill: parent
        anchors.leftMargin: pagina.margem - Math.round(pagina.vao / 2)
        anchors.rightMargin: pagina.margem - Math.round(pagina.vao / 2)
        opacity: 1 - detalhe.opacity
        visible: opacity > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property int colunas: Math.max(1, Math.floor(width / (janela.gu * 11.5 + pagina.vao)))
        cellWidth: Math.floor(width / colunas)
        cellHeight: Math.round(janela.gu * 8.4) + pagina.vao
        model: janela.lido ? pagina.lista : 9
        cacheBuffer: Math.round(janela.gu * 20)
        // A barra de rolagem fica na beirada da página, fora dos cartões
        // (como nas outras páginas), e não por cima da última coluna.
        QQC2.ScrollBar.vertical: BarraRolagem {
            parent: pagina
            x: pagina.width - width
            y: grade.y
            height: grade.height
            visible: grade.visible && size < 1.0
        }

        // Voltar para o começo quando a lista muda (outra categoria, outra busca).
        onModelChanged: positionViewAtBeginning()

        header: ColumnLayout {
            width: grade.width
            spacing: Math.round(janela.gu * 0.8)

            Item {
                Layout.preferredHeight: Math.round(janela.gu * 0.4)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(pagina.vao / 2)
                Layout.rightMargin: Math.round(pagina.vao / 2)
                spacing: Math.round(janela.gu * 0.6)
                Botao {
                    visible: pagina.busca.length === 0 && (pagina.secaoAberta !== null || (!pagina.jogos && janela.categoria !== ""))
                    icone: "matsu-voltar-symbolic"
                    dica: janela.t("Todos os apps", "All apps")
                    onClicado: {
                        janela.secao = "";
                        janela.categoria = "";
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Texto {
                        Layout.fillWidth: true
                        text: pagina.titulo
                        font.pixelSize: Math.round(janela.gu * 1.3)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Texto {
                        visible: janela.lido
                        text: {
                            var n = pagina.lista.length;
                            if (pagina.secaoAberta && pagina.busca.length === 0 && pagina.secaoAberta.texto)
                                return pagina.secaoAberta.texto;
                            if (pagina.jogos)
                                return n === 1 ? janela.t("1 jogo", "1 game") : janela.num(n) + janela.t(" jogos", " games");
                            return n === 1 ? janela.t("1 app", "1 app") : janela.num(n) + janela.t(" apps", " apps");
                        }
                        opacity: 0.62
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }

            // Categorias em pílulas (só na página Apps, sem busca e fora de uma seção).
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(pagina.vao / 2)
                Layout.rightMargin: Math.round(pagina.vao / 2)
                spacing: Math.round(janela.gu * 0.4)
                visible: !pagina.jogos && pagina.busca.length === 0 && pagina.secaoAberta === null && janela.lido
                Repeater {
                    model: [""].concat(janela.ordemCategorias.filter(function (c) {
                        return c !== "jogos" && (janela.contagem[c] || 0) > 0;
                    }))
                    MouseArea {
                        id: pilula
                        required property string modelData
                        readonly property bool escolhida: janela.categoria === modelData
                        width: rotulo.implicitWidth + Math.round(janela.gu * 1.4)
                        height: Math.round(janela.gu * 1.9)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: rotulo.text
                        onClicked: janela.categoria = modelData
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: pilula.escolhida ? janela.frente
                                 : (pilula.containsMouse ? janela.tinta(janela.escuro ? 0.12 : 0.09) : janela.cartao)
                            border.width: pilula.escolhida ? 0 : 1
                            border.color: janela.bordaCartao
                            Behavior on color {
                                ColorAnimation {
                                    duration: Kirigami.Units.shortDuration
                                }
                            }
                        }
                        Texto {
                            id: rotulo
                            anchors.centerIn: parent
                            text: pilula.modelData === "" ? janela.t("Tudo", "All") : janela.nomeCategoria(pilula.modelData)
                            color: pilula.escolhida ? (janela.escuro ? "#141416" : "#ffffff") : janela.frente
                            font.weight: pilula.escolhida ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }

            // Na busca: os sites que combinam, antes dos apps.
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(pagina.vao / 2)
                Layout.rightMargin: Math.round(pagina.vao / 2)
                spacing: Math.round(janela.gu * 0.4)
                visible: pagina.sitesAchados.length > 0
                Texto {
                    height: Math.round(janela.gu * 2.2)
                    verticalAlignment: Text.AlignVCenter
                    text: janela.t("Na web:", "On the web:")
                    opacity: 0.62
                }
                Repeater {
                    model: pagina.sitesAchados
                    MouseArea {
                        id: siteAchado
                        required property var modelData
                        width: linhaSite.implicitWidth + Math.round(janela.gu * 1.2)
                        height: Math.round(janela.gu * 2.2)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: janela.irPara("web")
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: siteAchado.containsMouse ? janela.tinta(janela.escuro ? 0.12 : 0.09) : janela.cartao
                            border.width: 1
                            border.color: janela.bordaCartao
                        }
                        RowLayout {
                            id: linhaSite
                            anchors.centerIn: parent
                            spacing: Math.round(janela.gu * 0.35)
                            IconeSite {
                                Layout.preferredWidth: Math.round(janela.gu * 1.3)
                                Layout.preferredHeight: Layout.preferredWidth
                                site: siteAchado.modelData
                            }
                            Texto {
                                text: siteAchado.modelData.nome
                            }
                        }
                    }
                }
            }

            Item {
                Layout.preferredHeight: Math.round(janela.gu * 0.1)
            }
        }

        delegate: Item {
            id: celula
            required property var modelData
            width: grade.cellWidth
            height: grade.cellHeight
            Esqueleto {
                anchors.fill: parent
                anchors.margins: Math.round(pagina.vao / 2)
                raio: Math.round(janela.gu * 0.6)
                visible: !janela.lido
            }
            CartaoApp {
                anchors.fill: parent
                anchors.margins: Math.round(pagina.vao / 2)
                visible: janela.lido
                app: janela.lido ? celula.modelData : null
            }
        }

        footer: Item {
            width: grade.width
            height: pagina.margem
        }
    }

    // Nada achado.
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * pagina.margem, janela.gu * 24)
        visible: janela.lido && pagina.lista.length === 0 && pagina.sitesAchados.length === 0 && grade.visible
        spacing: Math.round(janela.gu * 0.5)
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(janela.gu * 2.6)
            implicitHeight: implicitWidth
            source: "matsu-busca-symbolic"
            isMask: true
            color: janela.frente
            opacity: 0.5
        }
        Texto {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: pagina.busca.length > 0
                  ? janela.t("Nada encontrado para “" + pagina.busca + "”. Tente outro nome ou uma palavra do que o app faz.",
                             "Nothing found for “" + pagina.busca + "”. Try another name or a word for what the app does.")
                  : janela.t("Nenhum app aqui ainda.", "No apps here yet.")
            opacity: 0.75
        }
    }

    DetalheApp {
        id: detalhe
        anchors.fill: parent
    }
}
