// Apps (e Jogos): todos os apps do catálogo em cartões, com as categorias em
// pílulas em cima. Também mostra o "Ver tudo" de uma seção do Início e o
// resultado da busca (que procura em tudo, e mostra os sites que combinam).
// A grade só desenha os cartões que aparecem (o Flathub tem milhares de apps).
// Trocar de categoria (ou de ordem) faz os cartões entrarem em cascata; a pílula
// da categoria escolhida desliza até a nova.
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
    // Sem depender de janela.mudancas: o progresso de uma instalação não refaz a grade.
    readonly property var base: {
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
    readonly property var lista: {
        var l = janela.buscar(busca, base);
        if (busca.length > 0 || janela.ordem === "matsu")
            return l;
        var ordenada = l.map(function (a, n) { return { app: a, n: n }; });
        if (janela.ordem === "nome")
            ordenada.sort(function (x, y) { return x.app.nome.localeCompare(y.app.nome) || x.n - y.n; });
        else
            ordenada.sort(function (x, y) { return (x.app.verificado ? 0 : 1) - (y.app.verificado ? 0 : 1) || x.n - y.n; });
        return ordenada.map(function (x) { return x.app; });
    }
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

        // Voltar para o começo quando a lista muda (outra categoria, outra busca),
        // com o título à mostra. O cabeçalho pode crescer depois (as pílulas das
        // categorias quebram linha): no topo, a grade acompanha e o título não corta.
        property bool noTopo: true
        function voltarAoTopo() {
            if (noTopo && !atYBeginning)
                positionViewAtBeginning();
        }
        onModelChanged: {
            noTopo = true;
            Qt.callLater(voltarAoTopo);
        }
        onMovementStarted: noTopo = false
        // Os cartões entram em cascata quando a lista troca (e quando o catálogo chega).
        populate: Transition {
            id: cascata
            SequentialAnimation {
                PropertyAction { property: "opacity"; value: 0 }
                PauseAnimation { duration: Math.min(cascata.ViewTransition.index, 16) * 22 }
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                    NumberAnimation {
                        property: "y"
                        from: cascata.ViewTransition.destination.y + Math.round(janela.gu * 0.9)
                        to: cascata.ViewTransition.destination.y
                        duration: 380
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
        onMovementEnded: noTopo = atYBeginning
        Timer {
            id: esperaTopo
            interval: 40
            onTriggered: grade.voltarAoTopo()
        }

        header: ColumnLayout {
            width: grade.width
            onHeightChanged: esperaTopo.restart()
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
                    // Quantos são: o número rola quando a lista muda.
                    RowLayout {
                        id: quantos
                        readonly property int n: pagina.lista.length
                        readonly property bool comTexto: pagina.secaoAberta !== null && pagina.busca.length === 0 && !!pagina.secaoAberta.texto
                        visible: janela.lido
                        spacing: 0
                        opacity: 0.62
                        NumeroRolante {
                            visible: !quantos.comTexto
                            texto: janela.num(quantos.n)
                            font: Kirigami.Theme.smallFont
                            duracao: 420
                        }
                        Texto {
                            text: quantos.comTexto ? pagina.secaoAberta.texto
                                  : pagina.jogos ? (quantos.n === 1 ? janela.t(" jogo", " game") : janela.t(" jogos", " games"))
                                  : (quantos.n === 1 ? janela.t(" app", " app") : janela.t(" apps", " apps"))
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }
                }
                // A ordem da lista (fora da busca, que ordena pelo que combina mais).
                Suspensa {
                    Layout.alignment: Qt.AlignBottom
                    visible: janela.lido && pagina.busca.length === 0 && pagina.lista.length > 1
                    nome: janela.t("Ordenar", "Sort")
                    opcoes: [
                        { id: "matsu", nome: janela.t("Recomendados", "Recommended") },
                        { id: "nome", nome: janela.t("Nome (A–Z)", "Name (A–Z)") },
                        { id: "verificados", nome: janela.t("Verificados primeiro", "Verified first") }
                    ]
                    escolhido: janela.ordem
                    onEscolher: (id) => janela.ordem = id
                }
            }

            // Categorias em pílulas (só na página Apps, sem busca e fora de uma seção).
            // A escolhida é um fundo só, que desliza de uma pílula para a outra.
            Item {
                id: categorias
                readonly property var lista: [""].concat(janela.ordemCategorias.filter(function (c) {
                    return c !== "jogos" && (janela.contagem[c] || 0) > 0;
                }))
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(pagina.vao / 2)
                Layout.rightMargin: Math.round(pagina.vao / 2)
                implicitHeight: fluxo.implicitHeight
                visible: !pagina.jogos && pagina.busca.length === 0 && pagina.secaoAberta === null && janela.lido

                Rectangle {
                    id: marca
                    readonly property Item alvo: {
                        var i = categorias.lista.indexOf(janela.categoria);
                        return i >= 0 && i < repetidorCategorias.count ? repetidorCategorias.itemAt(i) : null;
                    }
                    // Só desliza quando a categoria troca (ao redimensionar, vai direto).
                    property bool animar: false
                    visible: alvo !== null
                    x: alvo ? alvo.x : 0
                    y: alvo ? alvo.y : 0
                    width: alvo ? alvo.width : 0
                    height: alvo ? alvo.height : 0
                    radius: height / 2
                    color: janela.frente
                    Behavior on x {
                        enabled: marca.animar
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        enabled: marca.animar
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on width {
                        enabled: marca.animar
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    Connections {
                        target: janela
                        function onCategoriaChanged() {
                            marca.animar = true;
                            fimDeslize.restart();
                        }
                    }
                    Timer {
                        id: fimDeslize
                        interval: 420
                        onTriggered: marca.animar = false
                    }
                }

                Flow {
                    id: fluxo
                    width: parent.width
                    spacing: Math.round(janela.gu * 0.4)
                    Repeater {
                        id: repetidorCategorias
                        model: categorias.lista
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
                                color: pilula.escolhida ? "transparent"
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
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 220
                                    }
                                }
                            }
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
            // O cartão com o mouse fica por cima dos vizinhos (a sombra não some embaixo deles).
            z: cartaoApp.containsMouse ? 1 : 0
            Esqueleto {
                anchors.fill: parent
                anchors.margins: Math.round(pagina.vao / 2)
                raio: Math.round(janela.gu * 0.6)
                visible: !janela.lido
            }
            CartaoApp {
                id: cartaoApp
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
