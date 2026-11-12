// A grade das fotos, agrupadas por mês ("novembro de 2026"), com o cabeçalho do mês
// grudado no topo enquanto rola. Duas formas: "ajustada" (linhas da mesma altura,
// cada foto com o formato dela, como no Fotos do Windows e no Google Fotos) e
// "quadrada" (como no Fotos do Mac). Ctrl+roda ou Ctrl+mais/menos mudam o tamanho.
// Só desenha as linhas que aparecem: aguenta milhares de fotos.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: grade

    property var fotos: []
    property string titulo: ""
    property string detalhe: ""
    // Muda quando é outra lista (outra página, outra busca): volta para o começo.
    property string chave: ""
    property bool comVoltar: false
    property string pasta: ""
    property string vazioIcone: ""
    property string vazioTitulo: ""
    property string vazioTexto: ""
    property string vazioBotao: ""

    signal voltar()
    signal vazioClicado()

    readonly property int margem: Math.round(janela.gu * 1.4)
    readonly property bool quadrada: janela.formaGrade === "quadrada"
    readonly property int vao: Math.max(2, Math.round(janela.gu * 0.22))
    readonly property var alturas: [6, 8, 10.5, 13.5, 18]
    readonly property real alvo: janela.gu * alturas[Math.max(0, Math.min(4, janela.nivelGrade))]
    readonly property int alturaMes: Math.round(janela.gu * 2.8)
    readonly property bool estreita: width < janela.gu * 34

    // As linhas montadas: [{ mes, altura, itens: [{ i, x, w, f }] }].
    property var linhas: []
    property var linhaDaFoto: []
    property var contagemMes: ({})
    property string chaveMontada: ""

    ListModel {
        id: modelo
    }
    Timer {
        id: remontar
        interval: 25
        onTriggered: grade.montar()
    }
    onFotosChanged: remontar.restart()
    onAlvoChanged: remontar.restart()
    onQuadradaChanged: remontar.restart()
    onChaveChanged: entrada.restart()
    Connections {
        target: janela
        // O giro de uma foto muda o formato dela na grade ajustada.
        function onRotacoesChanged() {
            if (!grade.quadrada)
                remontar.restart();
        }
    }

    function proporcao(f) {
        var w = f.largura, h = f.altura;
        if (!(w > 0 && h > 0))
            return 1.5;
        var g = janela.giroDe(f.caminho);
        var p = (g === 90 || g === 270) ? h / w : w / h;
        return Math.max(0.42, Math.min(3.2, p));
    }
    function fechar(atual, h, largura, cheia) {
        var x = 0, itens = [];
        for (var n = 0; n < atual.length; n++) {
            var w = atual[n].p * h;
            var x2 = (cheia && n === atual.length - 1) ? largura : x + w;
            itens.push({ i: atual[n].i, x: Math.round(x), w: Math.max(8, Math.round(x2) - Math.round(x)), f: fotos[atual[n].i] });
            x = x2 + vao;
        }
        return { altura: Math.max(24, Math.round(h)), itens: itens };
    }
    // Linhas justificadas: junta fotos até a linha ficar na altura certa, escolhendo
    // o ponto de quebra que deixa a altura mais perto da desejada.
    function linhasAjustadas(ini, fim, largura) {
        var res = [], atual = [], soma = 0;
        for (var k = ini; k < fim; k++) {
            var p = proporcao(fotos[k]);
            if (atual.length > 0) {
                var hSem = (largura - vao * (atual.length - 1)) / soma;
                var hCom = (largura - vao * atual.length) / (soma + p);
                if (hCom < alvo) {
                    if (Math.abs(hSem - alvo) < Math.abs(hCom - alvo) && hSem < alvo * 1.45) {
                        res.push(fechar(atual, hSem, largura, true));
                        atual = [{ i: k, p: p }];
                        soma = p;
                    } else {
                        atual.push({ i: k, p: p });
                        res.push(fechar(atual, hCom, largura, true));
                        atual = [];
                        soma = 0;
                    }
                    continue;
                }
            }
            atual.push({ i: k, p: p });
            soma += p;
        }
        if (atual.length > 0) {
            var h = (largura - vao * (atual.length - 1)) / soma;
            res.push(fechar(atual, Math.min(alvo, h), largura, h <= alvo));
        }
        return res;
    }
    function linhasQuadradas(ini, fim, largura) {
        var n = Math.max(2, Math.floor((largura + vao) / (alvo * 0.92 + vao)));
        var lado = (largura - vao * (n - 1)) / n;
        var res = [];
        for (var k = ini; k < fim; k += n) {
            var itens = [];
            for (var c = 0; c < n && k + c < fim; c++) {
                var x = Math.round(c * (lado + vao));
                itens.push({ i: k + c, x: x, w: Math.round(c * (lado + vao) + lado) - x, f: fotos[k + c] });
            }
            res.push({ altura: Math.round(lado), itens: itens });
        }
        return res;
    }
    // A foto que está no topo agora (para não perder o lugar ao mudar o tamanho).
    function fotoNoTopo() {
        if (lista.contentY - lista.originY < lista.headerItem.height)
            return "";
        var idx = lista.indexAt(grade.margem + 4, lista.contentY + alturaMes + 4);
        if (idx < 0 || idx >= modelo.count)
            return "";
        var l = linhas[modelo.get(idx).linha];
        return l && l.itens.length > 0 ? l.itens[0].f.caminho : "";
    }
    function montar() {
        var largura = lista.width;
        if (largura < 20)
            return;
        var mesma = chaveMontada === chave;
        var ancora = mesma ? fotoNoTopo() : "";
        var novas = [], daFoto = new Array(fotos.length), contagem = {};
        var i = 0;
        while (i < fotos.length) {
            var mes = fotos[i].mes || janela.chaveMes(fotos[i].data);
            var j = i;
            while (j < fotos.length && (fotos[j].mes || janela.chaveMes(fotos[j].data)) === mes)
                j++;
            contagem[mes] = j - i;
            var grupo = quadrada ? linhasQuadradas(i, j, largura) : linhasAjustadas(i, j, largura);
            for (var g = 0; g < grupo.length; g++) {
                grupo[g].mes = mes;
                for (var q = 0; q < grupo[g].itens.length; q++)
                    daFoto[grupo[g].itens[q].i] = novas.length;
                novas.push(grupo[g]);
            }
            i = j;
        }
        // Primeiro esvazia (as linhas que existem não podem ver a lista nova pela metade).
        modelo.clear();
        linhas = novas;
        linhaDaFoto = daFoto;
        contagemMes = contagem;
        var itens = [];
        for (var k = 0; k < novas.length; k++)
            itens.push({ mes: novas[k].mes, linha: k });
        modelo.append(itens);
        chaveMontada = chave;
        if (!mesma) {
            lista.positionViewAtBeginning();
        } else if (ancora !== "") {
            for (var a = 0; a < fotos.length; a++) {
                if (fotos[a].caminho === ancora) {
                    var linha = daFoto[a];
                    Qt.callLater(function () {
                        lista.positionViewAtIndex(linha, ListView.Beginning);
                        lista.contentY -= grade.alturaMes;
                    });
                    break;
                }
            }
        }
    }

    // Onde está a miniatura de uma foto, na janela (o visualizador volta para ela ao fechar).
    function localizar(caminho) {
        var indice = -1;
        for (var i = 0; i < fotos.length; i++) {
            if (fotos[i].caminho === caminho) {
                indice = i;
                break;
            }
        }
        if (indice < 0 || linhaDaFoto[indice] === undefined)
            return null;
        var linha = linhaDaFoto[indice];
        var item = lista.itemAtIndex(linha);
        var dentro = item && item.y + item.height > lista.contentY + alturaMes && item.y < lista.contentY + lista.height;
        if (!dentro) {
            lista.positionViewAtIndex(linha, ListView.Center);
            item = lista.itemAtIndex(linha);
        }
        var m = item ? item.miniaturaDe(caminho) : null;
        if (!m)
            return null;
        return m;
    }
    Component.onCompleted: {
        janela.localizador = localizar;
        entrada.restart();
    }
    Component.onDestruction: {
        if (janela.localizador === localizar)
            janela.localizador = null;
    }

    function abrirMenu(foto, item, px, py) {
        menu.foto = foto;
        menu.abrirEm(item, px, py);
    }

    // Ctrl+roda, Ctrl+mais e Ctrl+menos: miniaturas maiores ou menores.
    function mudarTamanho(passo) {
        var novo = Math.max(0, Math.min(4, janela.nivelGrade + passo));
        if (novo !== janela.nivelGrade) {
            janela.nivelGrade = novo;
            janela.guardarAjustes();
        }
    }
    Shortcut {
        sequences: [StandardKey.ZoomIn, "Ctrl+="]
        enabled: !janela.visorAberto
        onActivated: grade.mudarTamanho(1)
    }
    Shortcut {
        sequences: [StandardKey.ZoomOut]
        enabled: !janela.visorAberto
        onActivated: grade.mudarTamanho(-1)
    }

    // A página entra subindo de leve (ao abrir e ao trocar de lista).
    ParallelAnimation {
        id: entrada
        NumberAnimation { target: lista; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: deslocamento; property: "y"; from: Math.round(janela.gu * 0.8); to: 0; duration: 340; easing.type: Easing.OutCubic }
    }

    ListView {
        id: lista
        anchors.fill: parent
        anchors.leftMargin: grade.margem
        anchors.rightMargin: grade.margem
        clip: true
        model: modelo
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: Math.max(0, Math.round(height))
        reuseItems: false
        transform: Translate {
            id: deslocamento
        }
        onWidthChanged: remontar.restart()

        section.property: "mes"
        section.criteria: ViewSection.FullString
        section.labelPositioning: ViewSection.InlineLabels | ViewSection.CurrentLabelAtStart
        section.delegate: Rectangle {
            id: cabecalhoMes
            required property string section
            readonly property int quantidade: grade.contagemMes[section] || 0
            // Grudado no topo (com a lista já rolada): ganha a linha fina embaixo.
            readonly property bool grudado: lista.contentY - lista.originY > lista.headerItem.height && Math.abs(y - lista.contentY) < 1.5
            width: lista.width
            height: grade.alturaMes
            color: janela.corPagina
            z: 2

            RowLayout {
                anchors.fill: parent
                anchors.bottomMargin: Math.round(janela.gu * 0.25)
                spacing: Math.round(janela.gu * 0.5)
                Texto {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: janela.tituloMes(cabecalhoMes.section)
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Texto {
                    Layout.alignment: Qt.AlignVCenter
                    text: janela.quantas(cabecalhoMes.quantidade)
                    opacity: 0.55
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.bottom
                height: Math.round(janela.gu * 0.5)
                opacity: cabecalhoMes.grudado ? 1 : 0
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, janela.escuro ? 0.22 : 0.06) }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
            }
        }

        header: Item {
            width: lista.width
            height: cabecalho.implicitHeight + Math.round(janela.gu * 1.5)

            RowLayout {
                id: cabecalho
                anchors.left: parent.left
                anchors.right: parent.right
                y: Math.round(janela.gu * 1.0)
                spacing: Math.round(janela.gu * 0.5)

                Botao {
                    visible: grade.comVoltar
                    icone: "matsu-voltar-symbolic"
                    dica: janela.t("Voltar para os álbuns", "Back to albums")
                    onClicado: grade.voltar()
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Texto {
                        Layout.fillWidth: true
                        text: grade.titulo
                        font.pixelSize: Math.round(janela.gu * 1.3)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Texto {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: grade.detalhe
                        opacity: 0.62
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideRight
                    }
                }
                Botao {
                    visible: grade.pasta !== ""
                    icone: "matsu-pasta-symbolic"
                    texto: grade.estreita ? "" : janela.t("Abrir pasta", "Open folder")
                    dica: janela.t("Abrir no Arquivos", "Open in Files")
                    onClicado: janela.abrirPasta(grade.pasta)
                }
                Botao {
                    visible: grade.fotos.length > 0
                    icone: String(Qt.resolvedUrl("icones/apresentacao.svg"))
                    texto: grade.estreita ? "" : janela.t("Apresentação", "Slideshow")
                    dica: janela.t("Ver as fotos em tela cheia, uma depois da outra", "Play the photos full screen, one after another")
                    ativo: grade.fotos.length > 0
                    onClicado: janela.apresentar(grade.fotos, 0)
                }
                Seletor {
                    visible: grade.fotos.length > 0
                    opcoes: [
                        { id: "ajustada", icone: String(Qt.resolvedUrl("icones/ajustada.svg")), nome: grade.estreita ? "" : janela.t("Ajustada", "Fitted") },
                        { id: "quadrada", icone: String(Qt.resolvedUrl("icones/grade.svg")), nome: grade.estreita ? "" : janela.t("Quadrada", "Square") }
                    ]
                    escolhido: janela.formaGrade
                    onEscolher: (id) => {
                        janela.formaGrade = id;
                        janela.guardarAjustes();
                    }
                }
            }
        }

        delegate: Item {
            id: linhaItem
            required property int linha
            readonly property var dados: grade.linhas[linha] || ({ altura: 0, itens: [] })
            width: lista.width
            height: dados.altura + grade.vao

            function miniaturaDe(caminho) {
                for (var k = 0; k < repetidor.count; k++) {
                    var it = repetidor.itemAt(k);
                    if (it && it.caminho === caminho)
                        return it;
                }
                return null;
            }

            Repeater {
                id: repetidor
                model: linhaItem.dados.itens
                Miniatura {
                    id: miniatura
                    required property var modelData
                    x: modelData.x
                    width: modelData.w
                    height: linhaItem.dados.altura
                    foto: modelData.f
                    onAbrir: janela.abrirVisor(grade.fotos, modelData.i, miniatura)
                    onPedirMenu: (px, py) => grade.abrirMenu(modelData.f, miniatura, px, py)
                }
            }
        }

        footer: Item {
            width: lista.width
            height: Math.round(janela.gu * 1.5)
        }

        QQC2.ScrollBar.vertical: BarraRolagem {
            parent: grade
            x: grade.width - width
            y: lista.y
            height: lista.height
        }

        WheelHandler {
            acceptedModifiers: Qt.ControlModifier
            property real acumulado: 0
            onWheel: (e) => {
                acumulado += e.angleDelta.y;
                if (Math.abs(acumulado) >= 120) {
                    grade.mudarTamanho(acumulado > 0 ? 1 : -1);
                    acumulado = 0;
                }
            }
        }
    }

    // Enquanto o ajudante lê as pastas pela primeira vez: blocos no lugar das fotos.
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: grade.margem
        y: Math.round(janela.gu * 5.2)
        spacing: grade.vao
        visible: !janela.lido
        Esqueleto {
            width: Math.round(janela.gu * 9)
            height: Math.round(janela.gu * 1.1)
            radius: height / 2
        }
        Item {
            width: 1
            height: Math.round(janela.gu * 0.5)
        }
        Repeater {
            model: [[0.34, 0.22, 0.44], [0.2, 0.3, 0.28, 0.22], [0.42, 0.33, 0.25]]
            Row {
                id: linhaEsqueleto
                required property var modelData
                spacing: grade.vao
                Repeater {
                    model: linhaEsqueleto.modelData
                    Esqueleto {
                        required property real modelData
                        width: Math.floor((grade.width - 2 * grade.margem - grade.vao * (linhaEsqueleto.modelData.length - 1)) * modelData)
                        height: Math.round(grade.alvo)
                        radius: Math.round(janela.gu * 0.35)
                    }
                }
            }
        }
    }

    Vazio {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(janela.gu * 1.5)
        visible: janela.lido && grade.fotos.length === 0
        icone: grade.vazioIcone
        titulo: grade.vazioTitulo
        texto: grade.vazioTexto
        botao: grade.vazioBotao
        onClicado: grade.vazioClicado()
    }

    MenuMatsu {
        id: menu
        property var foto: ({})
        itens: [
            { id: "abrir", nome: janela.t("Abrir", "Open"), icone: String(Qt.resolvedUrl("icones/fotos.svg")) },
            { id: "favorita", nome: janela.ehFavorita(menu.foto.caminho || "") ? janela.t("Tirar das favoritas", "Remove from favorites") : janela.t("Favoritar", "Add to favorites"), icone: "matsu-coracao-symbolic" },
            { id: "girar", nome: janela.t("Girar para a direita", "Rotate right"), icone: String(Qt.resolvedUrl("icones/girar.svg")) },
            { id: "copiar", nome: janela.t("Copiar", "Copy"), icone: String(Qt.resolvedUrl("icones/copiar.svg")), separador: true },
            { id: "papel", nome: janela.t("Usar como papel de parede", "Set as wallpaper"), icone: "matsu-tela-symbolic" },
            { id: "pasta", nome: janela.t("Mostrar na pasta", "Show in folder"), icone: "matsu-pasta-symbolic" },
            { id: "apagar", nome: janela.t("Mover para a Lixeira", "Move to Trash"), icone: "matsu-lixeira-symbolic", perigo: true, separador: true }
        ]
        onEscolhido: (id) => {
            var f = menu.foto;
            if (id === "abrir") {
                for (var i = 0; i < grade.fotos.length; i++)
                    if (grade.fotos[i].caminho === f.caminho)
                        janela.abrirVisor(grade.fotos, i, grade.localizar(f.caminho));
            } else if (id === "favorita") {
                janela.alternarFavorita(f.caminho);
            } else if (id === "girar") {
                janela.girar(f.caminho, 90);
            } else if (id === "copiar") {
                janela.copiar(f.caminho);
            } else if (id === "papel") {
                janela.usarComoPapel(f.caminho);
            } else if (id === "pasta") {
                janela.mostrarNaPasta(f.caminho);
            } else if (id === "apagar") {
                janela.apagar(f);
            }
        }
    }
}
