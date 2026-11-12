// O visualizador: abre saindo da miniatura (a foto voa até o meio e o fundo
// escurece) e volta para ela ao fechar. Anterior e próxima com deslize, setas do
// teclado, dois dedos no touchpad e a tira de miniaturas embaixo; zoom, girar,
// favoritar, informações (painel que desliza), apresentação, papel de parede,
// copiar e Lixeira. As barras somem quando o mouse para. Fundo sempre escuro.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

FocusScope {
    id: visor

    // fechado, abrindo, aberto, fechando
    property string fase: "fechado"
    readonly property bool aberto: fase === "abrindo" || fase === "aberto"
    property var lista: []
    property int indice: 0
    readonly property var atual: indice >= 0 && indice < lista.length ? lista[indice] : null
    readonly property bool ehVideo: atual !== null && atual.video === true
    // A miniatura da grade da foto aberta (mostrada na hora, enquanto a grande carrega).
    property var provisoria: null
    property string caminhoProvisoria: ""
    property string esperandoVizinhas: ""
    property bool mostrandoInfo: false
    property bool apresentando: false
    property bool mexendo: true
    readonly property bool sobreBarras: sobreTopo.hovered || sobreBaixo.hovered || sobreLados.hovered
    readonly property Item paginaAtual: fita.currentItem
    readonly property Item quadroAtual: paginaAtual ? paginaAtual.quadro : null
    readonly property bool podeZoom: quadroAtual !== null && !ehVideo && quadroAtual.zoomEm !== undefined
    readonly property bool controles: fase === "aberto" && !apresentando
                                      && (mexendo || sobreBarras || mostrandoInfo || menuMais.opened || (podeZoom && quadroAtual.quebrada))
    readonly property bool estreito: width < janela.gu * 44

    visible: fase !== "fechado"
    focus: aberto

    // ----- abrir e fechar -----
    function item(f) {
        return { caminho: f.caminho, json: JSON.stringify(f) };
    }
    function pularPara(i) {
        fita.highlightMoveDuration = 0;
        fita.currentIndex = i;
        fita.positionViewAtIndex(i, ListView.Beginning);
        fita.highlightMoveDuration = 300;
        indice = i;
    }
    function irPara(i) {
        if (i < 0 || i >= lista.length || i === indice)
            return;
        fita.currentIndex = i;
    }
    function passar(lado) {
        irPara(indice + lado);
        mexer();
    }
    function abrir(l, i, origem) {
        if (l.length === 0)
            return;
        animVoo.stop();
        animSimples.stop();
        var f = l[Math.max(0, Math.min(i, l.length - 1))];
        lista = l.slice();
        provisoria = origem && origem.provisoria ? origem.provisoria : null;
        caminhoProvisoria = f.caminho;
        esperandoVizinhas = "";
        modeloFita.clear();
        modeloFita.append(lista.map(item));
        pularPara(Math.max(0, Math.min(i, l.length - 1)));
        fase = "abrindo";
        mexer();
        forceActiveFocus();
        var destino = retanguloAjustado(f);
        if (origem && destino && provisoria && !f.video) {
            var r0 = origem.mapToItem(visor, 0, 0, origem.width, origem.height);
            voar(f, provisoria.fonte, provisoria.largura, provisoria.altura, Image.PreserveAspectCrop, r0, destino, true);
        } else {
            entrarSimples(true);
        }
    }
    // Aberto pelo Arquivos: mostra na hora e espera as outras imagens da pasta.
    function abrirArquivo(caminho) {
        var nome = caminho.split("/").pop();
        var tipo = nome.indexOf(".") >= 0 ? nome.split(".").pop().toLowerCase() : "";
        var video = ["mp4", "m4v", "mkv", "webm", "mov", "avi", "ogv", "wmv", "mpg", "mpeg", "3gp"].indexOf(tipo) >= 0;
        var f = { caminho: caminho, nome: nome, pasta: caminho.substring(0, caminho.lastIndexOf("/")), album: "", tamanho: 0,
                  mtime: 0, data: 0, exif: false, largura: 0, altura: 0, tipo: tipo, mini: "", miniLado: 0, captura: false, video: video };
        abrir(janela.preparar([f]), 0, null);
        esperandoVizinhas = caminho;
    }
    function receberVizinhas(l, arquivo) {
        if (!aberto || esperandoVizinhas !== arquivo || lista.length !== 1 || lista[0].caminho !== arquivo)
            return;
        esperandoVizinhas = "";
        var k = -1;
        for (var i = 0; i < l.length; i++)
            if (l[i].caminho === arquivo)
                k = i;
        if (k < 0)
            return;
        lista = l.slice();
        modeloFita.setProperty(0, "json", JSON.stringify(l[k]));
        for (var a = 0; a < k; a++)
            modeloFita.insert(a, item(l[a]));
        for (var b = k + 1; b < l.length; b++)
            modeloFita.append(item(l[b]));
        pularPara(k);
    }
    function fechar() {
        if (!aberto)
            return;
        animVoo.stop();
        if (apresentando)
            apresentacao.parar();
        mostrandoMenu = false;
        fase = "fechando";
        var f = atual;
        var alvo = f && janela.localizador && !ehVideo ? janela.localizador(f.caminho) : null;
        var q = quadroAtual;
        if (alvo && q && q.conhecido && q.pronta && (q.pedido > 0)) {
            var w = q.visL * q.escala, h = q.visA * q.escala;
            var r0 = Qt.rect(palco.x + q.width / 2 - w / 2 + q.px, palco.y + q.height / 2 - h / 2 + q.py, w, h);
            var r1 = alvo.mapToItem(visor, 0, 0, alvo.width, alvo.height);
            voar(f, q.fonte, q.pedido, q.pedido, Image.Stretch, r0, r1, false);
        } else {
            entrarSimples(false);
        }
    }
    function terminou() {
        if (fase === "abrindo") {
            fase = "aberto";
        } else if (fase === "fechando") {
            fase = "fechado";
            modeloFita.clear();
            lista = [];
            provisoria = null;
        }
        janela.fotoEmVoo = "";
    }
    // Onde a foto fica ajustada no palco (o mesmo cálculo do QuadroFoto).
    function retanguloAjustado(f) {
        var w = f.largura, h = f.altura;
        if (!(w > 0 && h > 0) || palco.width <= 0)
            return null;
        var g = janela.giroDe(f.caminho);
        if (g === 90 || g === 270) {
            var t = w;
            w = h;
            h = t;
        }
        var folga = Math.round(janela.gu * 0.5);
        var vetor = f.tipo === "svg" || f.tipo === "svgz";
        var a = Math.min(vetor ? 100 : 1, (palco.width - 2 * folga) / w, (palco.height - 2 * folga) / h);
        return Qt.rect(palco.x + (palco.width - w * a) / 2, palco.y + (palco.height - h * a) / 2, w * a, h * a);
    }
    function voar(f, fonte, pl, pa, modo, de, para, abrindo) {
        var g = janela.giroDe(f.caminho);
        voo.fonte = fonte;
        voo.pl = pl;
        voo.pa = pa;
        voo.modo = modo;
        voo.giro = g;
        voo.asp = (g === 90 || g === 270) ? f.altura / f.largura : f.largura / f.altura;
        animVoo.de = de;
        animVoo.para = para;
        animVoo.abrindo = abrindo;
        janela.fotoEmVoo = f.caminho;
        animVoo.restart();
    }
    function entrarSimples(abrindo) {
        animSimples.abrindo = abrindo;
        animSimples.restart();
    }

    // ----- a lista muda por fora (Lixeira, Desfazer) -----
    function posicaoDe(caminho) {
        for (var i = 0; i < lista.length; i++)
            if (lista[i].caminho === caminho)
                return i;
        return -1;
    }
    function tirar(caminho) {
        var k = posicaoDe(caminho);
        if (k < 0 || fase === "fechado")
            return;
        var eraAtual = k === indice;
        var l = lista.slice();
        l.splice(k, 1);
        lista = l;
        modeloFita.remove(k);
        if (l.length === 0) {
            fechar();
            return;
        }
        pularPara(eraAtual ? Math.min(k, l.length - 1) : (k < indice ? indice - 1 : indice));
    }
    function devolver(foto, posicao) {
        if (!aberto || posicao < 0 || posicaoDe(foto.caminho) >= 0)
            return;
        var p = Math.min(posicao, lista.length);
        var l = lista.slice();
        l.splice(p, 0, foto);
        lista = l;
        modeloFita.insert(p, item(foto));
        pularPara(p);
    }

    // ----- as barras somem quando o mouse para -----
    function mexer() {
        mexendo = true;
        sossego.restart();
    }
    Timer {
        id: sossego
        interval: 2600
        onTriggered: visor.mexendo = false
    }
    HoverHandler {
        onPointChanged: visor.mexer()
        cursorShape: visor.controles || visor.fase !== "aberto" ? Qt.ArrowCursor : Qt.BlankCursor
    }

    // ----- apresentação e tela cheia -----
    property int visibilidadeAntes: Window.Windowed
    function apresentar() {
        var fotosSo = lista.filter(function (f) { return f.video !== true; });
        if (fotosSo.length === 0)
            return;
        var inicio = 0;
        for (var i = 0; i < fotosSo.length; i++)
            if (atual && fotosSo[i].caminho === atual.caminho)
                inicio = i;
        apresentando = true;
        apresentacao.comecar(fotosSo, inicio);
    }

    // ----- teclado -----
    property bool mostrandoMenu: false
    Keys.onPressed: (e) => {
        var q = visor.podeZoom ? visor.quadroAtual : null;
        var ctrl = e.modifiers & Qt.ControlModifier;
        var aceito = true;
        switch (e.key) {
        case Qt.Key_Escape:
            if (janela.visibility === Window.FullScreen)
                janela.alternarTelaCheia();
            else if (visor.mostrandoInfo)
                visor.mostrandoInfo = false;
            else if (q && q.zoomado)
                q.ajustar(true);
            else
                visor.fechar();
            break;
        case Qt.Key_Left:
        case Qt.Key_PageUp:
            visor.irPara(visor.indice - 1);
            break;
        case Qt.Key_Right:
        case Qt.Key_PageDown:
            visor.irPara(visor.indice + 1);
            break;
        case Qt.Key_Home:
            visor.irPara(0);
            break;
        case Qt.Key_End:
            visor.irPara(visor.lista.length - 1);
            break;
        case Qt.Key_Space:
            if (visor.ehVideo && visor.quadroAtual && visor.quadroAtual.item)
                visor.quadroAtual.item.alternar();
            else
                visor.irPara(visor.indice + 1);
            break;
        case Qt.Key_Plus:
        case Qt.Key_Equal:
            if (q)
                q.ampliar(1.4);
            break;
        case Qt.Key_Minus:
            if (q)
                q.ampliar(1 / 1.4);
            break;
        case Qt.Key_0:
            if (q)
                q.ajustar(true);
            break;
        case Qt.Key_1:
            if (q)
                q.tamanhoReal();
            break;
        case Qt.Key_R:
            if (visor.atual && !visor.ehVideo)
                janela.girar(visor.atual.caminho, (e.modifiers & Qt.ShiftModifier) ? -90 : 90);
            break;
        case Qt.Key_Period:
            if (visor.atual)
                janela.alternarFavorita(visor.atual.caminho);
            break;
        case Qt.Key_D:
            if (ctrl && visor.atual)
                janela.alternarFavorita(visor.atual.caminho);
            else
                aceito = false;
            break;
        case Qt.Key_C:
            if (ctrl && visor.atual)
                janela.copiar(visor.atual.caminho);
            else
                aceito = false;
            break;
        case Qt.Key_M:
            janela.semSom = !janela.semSom;
            break;
        case Qt.Key_I:
            visor.mostrandoInfo = !visor.mostrandoInfo;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (e.modifiers & Qt.AltModifier)
                visor.mostrandoInfo = !visor.mostrandoInfo;
            else
                aceito = false;
            break;
        case Qt.Key_Delete:
            if (visor.atual)
                janela.apagar(visor.atual);
            break;
        case Qt.Key_F5:
            visor.apresentar();
            break;
        case Qt.Key_F11:
        case Qt.Key_F:
            janela.alternarTelaCheia();
            break;
        default:
            aceito = false;
        }
        e.accepted = aceito;
    }

    // ----- o fundo escuro -----
    Rectangle {
        id: fundo
        anchors.fill: parent
        radius: janela.raio
        color: Qt.rgba(0.055, 0.055, 0.062, janela.comVidro ? 0.93 : 1)
        border.width: janela.cheia ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        opacity: 0
        // Clicar no fundo não passa para a grade embaixo.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (w) => w.accepted = true
        }
    }

    // ----- o palco: as fotos lado a lado, uma por vez -----
    Item {
        id: palco
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: painel.left
        opacity: 0
        transformOrigin: Item.Center

        ListModel {
            id: modeloFita
        }

        ListView {
            id: fita
            anchors.fill: parent
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: width
            highlightMoveDuration: 300
            highlightMoveVelocity: -1
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 4000
            interactive: visor.fase === "aberto" && modeloFita.count > 1 && !(visor.podeZoom && visor.quadroAtual.zoomado)
            cacheBuffer: Math.max(0, width)
            model: modeloFita
            clip: false
            onCurrentIndexChanged: if (currentIndex >= 0) visor.indice = currentIndex
            onWidthChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Beginning)

            delegate: Item {
                id: pagina
                required property int index
                required property string json
                readonly property var foto: JSON.parse(json)
                readonly property bool ehAtual: ListView.isCurrentItem
                readonly property Item quadro: carregador.item
                width: fita.width
                height: fita.height
                clip: true

                Loader {
                    id: carregador
                    anchors.fill: parent
                    sourceComponent: pagina.foto.video ? componenteVideo : componenteFoto

                    Component {
                        id: componenteFoto
                        QuadroFoto {
                            foto: pagina.foto
                            atual: pagina.ehAtual && visor.fase === "aberto"
                            provisoria: pagina.foto.caminho === visor.caminhoProvisoria ? visor.provisoria : null
                            onTocado: visor.mexendo ? (visor.mexendo = false) : visor.mexer()
                            onPassarPara: (lado) => visor.passar(lado)
                        }
                    }
                    // O vídeo fica num arquivo à parte (QtMultimedia só é carregado para vídeos).
                    Component {
                        id: componenteVideo
                        Loader {
                            id: carregaVideo
                            source: Qt.resolvedUrl("QuadroVideo.qml")
                            Binding {
                                target: carregaVideo.item
                                property: "foto"
                                value: pagina.foto
                                when: carregaVideo.status === Loader.Ready
                            }
                            Binding {
                                target: carregaVideo.item
                                property: "atual"
                                value: pagina.ehAtual && visor.fase === "aberto"
                                when: carregaVideo.status === Loader.Ready
                            }
                            Binding {
                                target: carregaVideo.item
                                property: "controles"
                                value: visor.controles
                                when: carregaVideo.status === Loader.Ready
                            }
                            QQC2.Label {
                                anchors.centerIn: parent
                                visible: carregaVideo.status === Loader.Error
                                color: "#ffffff"
                                text: janela.t("Este sistema não consegue tocar vídeos aqui.", "This system can't play videos here.")
                            }
                        }
                    }
                }
            }
        }
    }

    // A foto que voa entre a miniatura e o meio (abrir e fechar).
    Item {
        id: voo
        property url fonte
        property int pl: 0
        property int pa: 0
        property int modo: Image.PreserveAspectCrop
        property real asp: 1
        property int giro: 0
        visible: animVoo.running
        clip: true
        Image {
            readonly property bool deLado: voo.giro === 90 || voo.giro === 270
            readonly property real cobreL: Math.max(voo.width, voo.height * voo.asp)
            readonly property real cobreA: cobreL / Math.max(0.01, voo.asp)
            anchors.centerIn: parent
            width: deLado ? cobreA : cobreL
            height: deLado ? cobreL : cobreA
            rotation: voo.giro
            source: voo.visible ? voo.fonte : ""
            sourceSize: Qt.size(voo.pl, voo.pa)
            fillMode: voo.modo
            autoTransform: true
            asynchronous: true
            smooth: true
        }
    }
    ParallelAnimation {
        id: animVoo
        property rect de
        property rect para
        property bool abrindo: true
        NumberAnimation { target: voo; property: "x"; from: animVoo.de.x; to: animVoo.para.x; duration: animVoo.abrindo ? 340 : 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: voo; property: "y"; from: animVoo.de.y; to: animVoo.para.y; duration: animVoo.abrindo ? 340 : 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: voo; property: "width"; from: animVoo.de.width; to: animVoo.para.width; duration: animVoo.abrindo ? 340 : 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: voo; property: "height"; from: animVoo.de.height; to: animVoo.para.height; duration: animVoo.abrindo ? 340 : 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: fundo; property: "opacity"; to: animVoo.abrindo ? 1 : 0; duration: animVoo.abrindo ? 300 : 260; easing.type: Easing.OutQuad }
        NumberAnimation { target: palco; property: "opacity"; to: 0; duration: 1 }
        onStarted: palco.scale = 1
        onFinished: {
            if (animVoo.abrindo)
                palco.opacity = 1;
            visor.terminou();
        }
    }
    ParallelAnimation {
        id: animSimples
        property bool abrindo: true
        NumberAnimation { target: fundo; property: "opacity"; to: animSimples.abrindo ? 1 : 0; duration: 220; easing.type: Easing.OutQuad }
        NumberAnimation { target: palco; property: "opacity"; to: animSimples.abrindo ? 1 : 0; duration: 220; easing.type: Easing.OutQuad }
        NumberAnimation { target: palco; property: "scale"; from: animSimples.abrindo ? 0.96 : 1; to: animSimples.abrindo ? 1 : 0.96; duration: 280; easing.type: Easing.OutCubic }
        onFinished: visor.terminou()
    }

    // ----- anterior e próxima, nas beiradas -----
    Item {
        anchors.fill: palco
        opacity: visor.controles ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }
        HoverHandler {
            id: sobreLados
            enabled: false
        }
        BotaoVisor {
            anchors.left: parent.left
            anchors.leftMargin: Math.round(janela.gu * 0.8)
            anchors.verticalCenter: parent.verticalCenter
            lado: Math.round(janela.gu * 2.6)
            solido: true
            visible: visor.indice > 0
            icone: "matsu-voltar-symbolic"
            dica: janela.t("Anterior", "Previous")
            atalho: "←"
            onClicado: visor.passar(-1)
        }
        BotaoVisor {
            anchors.right: parent.right
            anchors.rightMargin: Math.round(janela.gu * 0.8)
            anchors.verticalCenter: parent.verticalCenter
            lado: Math.round(janela.gu * 2.6)
            solido: true
            visible: visor.indice < visor.lista.length - 1
            icone: "matsu-seta-symbolic"
            dica: janela.t("Próxima", "Next")
            atalho: "→"
            onClicado: visor.passar(1)
        }
    }

    // ----- barra de cima: bolinhas, voltar, nome e as ações -----
    Item {
        id: barraTopo
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: painel.left
        height: Math.round(janela.gu * 3)
        opacity: visor.controles ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }
        HoverHandler {
            id: sobreTopo
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height * 1.7
            topLeftRadius: janela.raio
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.62) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
            }
        }
        // Arrastar move a janela; dois cliques deixam em tela cheia.
        Item {
            anchors.fill: parent
            DragHandler {
                target: null
                onActiveChanged: if (active) janela.startSystemMove()
            }
            TapHandler {
                onDoubleTapped: janela.alternarCheia()
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(janela.gu * 0.75)
            anchors.rightMargin: Math.round(janela.gu * 0.6)
            spacing: Math.round(janela.gu * 0.3)

            Row {
                id: bolinhas
                spacing: 4
                visible: janela.visibility !== Window.FullScreen
                HoverHandler {
                    id: sobreBolinhas
                }
                BotaoJanela {
                    tipo: "fechar"
                    mostrar: sobreBolinhas.hovered
                    dica: janela.t("Fechar", "Close")
                    onClicado: janela.close()
                }
                BotaoJanela {
                    tipo: "minimizar"
                    mostrar: sobreBolinhas.hovered
                    dica: janela.t("Minimizar", "Minimize")
                    onClicado: janela.showMinimized()
                }
                BotaoJanela {
                    tipo: "cheia"
                    mostrar: sobreBolinhas.hovered
                    ligado: janela.cheia
                    dica: janela.cheia ? janela.t("Sair da tela cheia", "Restore") : janela.t("Tela cheia", "Maximize")
                    onClicado: janela.alternarCheia()
                }
            }
            BotaoVisor {
                Layout.leftMargin: Math.round(janela.gu * 0.4)
                icone: "matsu-voltar-symbolic"
                dica: janela.t("Voltar para a galeria", "Back to the gallery")
                atalho: "Esc"
                onClicado: visor.fechar()
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(janela.gu * 0.2)
                spacing: 0
                QQC2.Label {
                    Layout.fillWidth: true
                    text: visor.atual ? visor.atual.nome : ""
                    color: "#ffffff"
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: {
                        if (!visor.atual)
                            return "";
                        var partes = [];
                        if (visor.lista.length > 1)
                            partes.push(janela.t(janela.num(visor.indice + 1) + " de " + janela.num(visor.lista.length),
                                                 janela.num(visor.indice + 1) + " of " + janela.num(visor.lista.length)));
                        if (visor.atual.data > 0)
                            partes.push(janela.dataLonga(visor.atual.data));
                        return partes.join("  ·  ");
                    }
                    color: "#ffffff"
                    opacity: 0.65
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                }
            }
            BotaoCoracao {
                visible: visor.atual !== null
                claro: true
                comFundo: false
                lado: Math.round(janela.gu * 2.1)
                ligado: visor.atual ? janela.ehFavorita(visor.atual.caminho) : false
                onClicado: if (visor.atual) janela.alternarFavorita(visor.atual.caminho)
            }
            BotaoVisor {
                visible: !visor.ehVideo && !visor.estreito
                icone: String(Qt.resolvedUrl("icones/girar.svg"))
                dica: janela.t("Girar", "Rotate")
                atalho: "R"
                onClicado: if (visor.atual) janela.girar(visor.atual.caminho, 90)
            }
            BotaoVisor {
                visible: !visor.estreito
                icone: "matsu-lixeira-symbolic"
                dica: janela.t("Mover para a Lixeira", "Move to Trash")
                atalho: janela.t("Delete", "Delete")
                onClicado: if (visor.atual) janela.apagar(visor.atual)
            }
            BotaoVisor {
                icone: "matsu-info-symbolic"
                dica: janela.t("Informações", "Info")
                atalho: "I"
                ligado: visor.mostrandoInfo
                onClicado: visor.mostrandoInfo = !visor.mostrandoInfo
            }
            BotaoVisor {
                id: botaoMais
                icone: String(Qt.resolvedUrl("icones/mais-opcoes.svg"))
                dica: janela.t("Mais opções", "More options")
                ligado: menuMais.opened
                onClicado: menuMais.abrirEm(botaoMais, botaoMais.width - menuMais.width, botaoMais.height + 4)
            }
        }
    }

    // ----- embaixo: a tira de miniaturas e o zoom -----
    Item {
        id: barraBaixo
        anchors.left: parent.left
        anchors.right: painel.left
        anchors.bottom: parent.bottom
        height: Math.round(janela.gu * 4.4)
        opacity: visor.controles ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 1.4
            bottomLeftRadius: janela.raio
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
            }
        }
        HoverHandler {
            id: sobreBaixo
        }

        // A tira: a foto da vez maior e acesa; clicar pula para ela.
        Rectangle {
            id: fundoTira
            readonly property int celula: Math.round(janela.gu * 2.3)
            readonly property real limite: zoom.visible ? zoom.x - Math.round(janela.gu * 0.8) : parent.width - Math.round(janela.gu * 0.8)
            anchors.verticalCenter: parent.verticalCenter
            // No meio, mas sem encostar no zoom.
            x: Math.max(Math.round(janela.gu * 0.8), Math.min(Math.round((parent.width - width) / 2), limite - width))
            width: Math.min(tira.contentWidth + 12, limite - Math.round(janela.gu * 0.8))
            height: celula + 12
            radius: Math.round(janela.gu * 0.6)
            color: Qt.rgba(0.07, 0.07, 0.08, 0.6)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.09)
            visible: modeloFita.count > 1 && width > celula * 2

            ListView {
                id: tira
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                orientation: ListView.Horizontal
                spacing: 4
                model: visor.fase === "fechado" ? null : modeloFita
                currentIndex: visor.indice
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: width / 2 - fundoTira.celula
                preferredHighlightEnd: width / 2 + fundoTira.celula
                highlightMoveDuration: 260
                highlightMoveVelocity: -1
                boundsBehavior: Flickable.StopAtBounds
                delegate: MouseArea {
                    id: celulaTira
                    required property int index
                    required property string json
                    readonly property var foto: JSON.parse(json)
                    readonly property bool daVez: index === visor.indice
                    readonly property string fonteMini: foto.video ? (foto.capa || "") : (foto.mini || foto.caminho)
                    width: fundoTira.celula
                    height: fundoTira.celula
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: visor.irPara(index)
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Qt.rgba(1, 1, 1, 0.08)
                        scale: celulaTira.daVez ? 1 : 0.86
                        opacity: celulaTira.daVez ? 1 : (celulaTira.containsMouse ? 0.9 : 0.55)
                        clip: true
                        Behavior on scale {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutBack
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 160
                            }
                        }
                        Image {
                            anchors.fill: parent
                            source: celulaTira.fonteMini !== "" ? janela.arquivo(celulaTira.fonteMini) : ""
                            sourceSize: Qt.size(96, 96)
                            fillMode: Image.PreserveAspectCrop
                            autoTransform: true
                            asynchronous: true
                            rotation: janela.giroDe(celulaTira.foto.caminho)
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.small
                            height: width
                            visible: celulaTira.foto.video === true
                            source: String(Qt.resolvedUrl("icones/tocar.svg"))
                            isMask: true
                            color: "#ffffff"
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: "transparent"
                            border.width: celulaTira.daVez ? 2 : 0
                            border.color: "#ffffff"
                        }
                    }
                }
            }
        }

        // O zoom: − 100% + e "ajustar à janela".
        Rectangle {
            id: zoom
            anchors.right: parent.right
            anchors.rightMargin: Math.round(janela.gu * 0.8)
            anchors.verticalCenter: parent.verticalCenter
            width: linhaZoom.implicitWidth + 8
            height: Math.round(janela.gu * 2.3)
            radius: height / 2
            color: Qt.rgba(0.07, 0.07, 0.08, 0.6)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.09)
            visible: visor.podeZoom
            RowLayout {
                id: linhaZoom
                anchors.centerIn: parent
                spacing: 0
                BotaoVisor {
                    lado: Math.round(janela.gu * 1.9)
                    icone: String(Qt.resolvedUrl("icones/zoom-menos.svg"))
                    dica: janela.t("Diminuir", "Zoom out")
                    atalho: "−"
                    ativo: visor.podeZoom && visor.quadroAtual.zoomado
                    onClicado: visor.quadroAtual.ampliar(1 / 1.4)
                }
                MouseArea {
                    implicitWidth: Math.round(janela.gu * 3.2)
                    implicitHeight: Math.round(janela.gu * 1.9)
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        if (visor.quadroAtual.zoomado)
                            visor.quadroAtual.ajustar(true);
                        else
                            visor.quadroAtual.tamanhoReal();
                    }
                    QQC2.Label {
                        anchors.centerIn: parent
                        text: visor.podeZoom ? janela.num(visor.quadroAtual.porcento) + "%" : ""
                        color: "#ffffff"
                        font.features: { "tnum": 1 }
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: parent.containsMouse ? 1 : 0.85
                    }
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: visor.podeZoom && visor.quadroAtual.zoomado ? janela.t("Ajustar à janela", "Fit to window") : janela.t("Tamanho real", "Actual size")
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
                BotaoVisor {
                    lado: Math.round(janela.gu * 1.9)
                    icone: String(Qt.resolvedUrl("icones/zoom-mais.svg"))
                    dica: janela.t("Ampliar", "Zoom in")
                    atalho: "+"
                    onClicado: visor.quadroAtual.ampliar(1.4)
                }
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: Math.round(janela.gu * 1.1)
                    Layout.leftMargin: 3
                    Layout.rightMargin: 3
                    color: Qt.rgba(1, 1, 1, 0.16)
                }
                BotaoVisor {
                    lado: Math.round(janela.gu * 1.9)
                    icone: String(Qt.resolvedUrl("icones/ajustar.svg"))
                    dica: janela.t("Ajustar à janela", "Fit to window")
                    atalho: "0"
                    ligado: visor.podeZoom && !visor.quadroAtual.zoomado
                    onClicado: visor.quadroAtual.ajustar(true)
                }
            }
        }
    }

    // ----- o painel de informações, que desliza da direita -----
    Rectangle {
        id: painel
        readonly property int largura: Math.min(Math.round(janela.gu * 17), Math.round(visor.width * 0.45))
        readonly property var f: visor.atual
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: visor.mostrandoInfo && visor.fase !== "fechado" ? visor.width - largura : visor.width
        width: largura
        topRightRadius: janela.raio
        bottomRightRadius: janela.raio
        color: Qt.rgba(0.1, 0.1, 0.11, janela.comVidro ? 0.94 : 1)
        Behavior on x {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Qt.rgba(1, 1, 1, 0.09)
        }

        RowLayout {
            id: topoPainel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Math.round(janela.gu * 1.1)
            anchors.rightMargin: Math.round(janela.gu * 0.6)
            height: Math.round(janela.gu * 3)
            QQC2.Label {
                Layout.fillWidth: true
                text: janela.t("Informações", "Info")
                color: "#ffffff"
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
            }
            BotaoVisor {
                icone: "matsu-fechar-symbolic"
                dica: janela.t("Fechar", "Close")
                onClicado: visor.mostrandoInfo = false
            }
        }

        Flickable {
            anchors.top: topoPainel.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            contentHeight: colunaInfo.implicitHeight + janela.gu * 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: colunaInfo
                x: Math.round(janela.gu * 1.1)
                width: parent.width - 2 * x
                spacing: Math.round(janela.gu * 0.9)

                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(janela.gu * 0.3)
                    text: painel.f ? painel.f.nome : ""
                    color: "#ffffff"
                    font.weight: Font.DemiBold
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
                Repeater {
                    model: {
                        var f = painel.f;
                        if (!f)
                            return [];
                        var linhas = [];
                        if (f.data > 0)
                            linhas.push({ icone: "matsu-calendario-symbolic", nome: f.exif ? janela.t("Tirada em", "Taken") : janela.t("Modificada em", "Modified"), valor: janela.dataLonga(f.data) });
                        if (f.largura > 0 && f.altura > 0) {
                            var mp = f.largura * f.altura / 1e6;
                            linhas.push({ icone: "matsu-papel-symbolic", nome: janela.t("Dimensões", "Dimensions"),
                                          valor: janela.num(f.largura) + " × " + janela.num(f.altura) + (mp >= 0.1 ? "  ·  " + janela.num(mp, 1) + " MP" : "") });
                        }
                        if (f.tamanho > 0)
                            linhas.push({ icone: "matsu-disco-symbolic", nome: janela.t("Tamanho", "Size"), valor: janela.bytes(f.tamanho) + "  ·  " + janela.nomeTipo(f.tipo) });
                        var g = janela.giroDe(f.caminho);
                        if (g !== 0)
                            linhas.push({ icone: String(Qt.resolvedUrl("icones/girar.svg")), nome: janela.t("Girada", "Rotated"),
                                          valor: janela.t(g + "° (só aqui no Fotos; o arquivo não muda)", g + "° (only here in Photos; the file is unchanged)") });
                        linhas.push({ icone: "matsu-pasta-symbolic", nome: janela.t("Pasta", "Folder"), valor: janela.pastaBonita(f.pasta) });
                        return linhas;
                    }
                    RowLayout {
                        id: linhaInfo
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.7)
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 2
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: implicitWidth
                            source: linhaInfo.modelData.icone
                            isMask: true
                            color: "#ffffff"
                            opacity: 0.6
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: linhaInfo.modelData.nome
                                color: "#ffffff"
                                opacity: 0.55
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: linhaInfo.modelData.valor
                                color: "#ffffff"
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
                BotaoVisor {
                    Layout.topMargin: Math.round(janela.gu * 0.2)
                    visible: painel.f !== null
                    icone: "matsu-pasta-symbolic"
                    texto: janela.t("Mostrar na pasta", "Show in folder")
                    onClicado: janela.mostrarNaPasta(painel.f.caminho)
                }
            }
        }
    }

    MenuMatsu {
        id: menuMais
        readonly property var f: visor.atual
        itens: {
            var l = [];
            if (visor.estreito && !visor.ehVideo)
                l.push({ id: "girar", nome: janela.t("Girar para a direita", "Rotate right"), icone: String(Qt.resolvedUrl("icones/girar.svg")), atalho: "R" });
            if (!visor.ehVideo) {
                l.push({ id: "esquerda", nome: janela.t("Girar para a esquerda", "Rotate left"), icone: String(Qt.resolvedUrl("icones/girar.svg")), atalho: "Shift+R" });
                l.push({ id: "apresentacao", nome: janela.t("Apresentação de slides", "Slideshow"), icone: String(Qt.resolvedUrl("icones/apresentacao.svg")), atalho: "F5" });
            }
            l.push({ id: "cheia", nome: janela.visibility === Window.FullScreen ? janela.t("Sair da tela cheia", "Exit full screen") : janela.t("Tela cheia", "Full screen"),
                     icone: janela.visibility === Window.FullScreen ? String(Qt.resolvedUrl("icones/sair-tela-cheia.svg")) : String(Qt.resolvedUrl("icones/tela-cheia.svg")), atalho: "F11" });
            l.push({ id: "copiar", nome: janela.t("Copiar", "Copy"), icone: String(Qt.resolvedUrl("icones/copiar.svg")), atalho: "Ctrl+C", separador: true });
            if (!visor.ehVideo)
                l.push({ id: "papel", nome: janela.t("Usar como papel de parede", "Set as wallpaper"), icone: "matsu-tela-symbolic" });
            l.push({ id: "pasta", nome: janela.t("Mostrar na pasta", "Show in folder"), icone: "matsu-pasta-symbolic" });
            l.push({ id: "apagar", nome: janela.t("Mover para a Lixeira", "Move to Trash"), icone: "matsu-lixeira-symbolic", atalho: "Delete", perigo: true, separador: true });
            return l;
        }
        onClosed: visor.forceActiveFocus()
        onEscolhido: (id) => {
            var f = menuMais.f;
            if (!f)
                return;
            if (id === "girar")
                janela.girar(f.caminho, 90);
            else if (id === "esquerda")
                janela.girar(f.caminho, -90);
            else if (id === "apresentacao")
                visor.apresentar();
            else if (id === "cheia")
                janela.alternarTelaCheia();
            else if (id === "copiar")
                janela.copiar(f.caminho);
            else if (id === "papel")
                janela.usarComoPapel(f.caminho);
            else if (id === "pasta")
                janela.mostrarNaPasta(f.caminho);
            else if (id === "apagar")
                janela.apagar(f);
        }
    }

    Apresentacao {
        id: apresentacao
        anchors.fill: parent
        onSair: (caminho) => {
            visor.apresentando = false;
            var k = visor.posicaoDe(caminho);
            if (k >= 0)
                visor.pularPara(k);
            visor.forceActiveFocus();
            visor.mexer();
        }
    }
}
