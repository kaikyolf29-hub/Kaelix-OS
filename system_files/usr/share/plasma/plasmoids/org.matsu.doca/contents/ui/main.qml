// Doca do Matsu: os apps fixados e os abertos, no jeito da doca do Mac.
//
// Ao passar o mouse, os apps crescem como uma lupa (o do meio mais, os
// vizinhos um pouco) e o nome do app aparece num balão em cima. O app que está
// embaixo do mouse fica parado embaixo do mouse, então o clique cai sempre no
// app que a pessoa está vendo. Um app que está abrindo pula, como no Mac, e o
// pontinho embaixo mostra quem está aberto (o app em uso ganha um traço).
//
// Como a barra do Plasma é uma janela da altura da barra, um app ampliado não
// caberia nela. Por isso a ampliação é desenhada numa janela à parte, sem
// fundo e que deixa o mouse passar ("sobre"), em cima da barra: enquanto ela
// aparece, os ícones da barra somem; quando o mouse sai, os apps voltam ao
// tamanho normal, a janela some e os ícones da barra voltam no mesmo lugar.
//
// Os apps fixados ficam em "launchers" (o mesmo nome da barra do KDE), e quem
// fixa, tira e põe em ordem nas barras de todas as telas é o comando "matsu
// barra" (pelo /usr/libexec/matsu/matsu-central), para valer em todas.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager

import "../code/zoom.js" as Zoom

PlasmoidItem {
    id: raiz

    // Português quando o sistema está em português (o ajudante confirma).
    property string idioma: ""
    readonly property bool pt: idioma !== "" ? idioma === "pt"
        : (Qt.locale().name.indexOf("pt") === 0 || Qt.locale().uiLanguages.join(",").indexOf("pt") === 0)
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }
    readonly property string ajudante: "/usr/libexec/matsu/matsu-central"

    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    // ------------------------------------------------------------ medidas
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    // De que borda da tela a doca sai (a ampliação cresce para dentro da tela).
    readonly property string borda: {
        switch (Plasmoid.location) {
        case PlasmaCore.Types.TopEdge: return "cima";
        case PlasmaCore.Types.LeftEdge: return "esquerda";
        case PlasmaCore.Types.RightEdge: return "direita";
        default: return vertical ? "esquerda" : "baixo";
        }
    }
    readonly property real espessura: Math.max(1, vertical ? width : height)
    readonly property real comprimento: vertical ? height : width
    readonly property bool temLixeira: Plasmoid.configuration.lixeira === true
    // O risquinho entre os apps e a lixeira, como no Mac.
    readonly property real vao: temLixeira ? Math.round(Kirigami.Units.gridUnit * 0.8) : 0
    readonly property int quantos: tarefas.count + (temLixeira ? 1 : 0)
    // Cada app é um quadrado da espessura da doca; com apps demais para o
    // espaço, os quadrados encolhem (nunca passam da borda).
    readonly property real celula: quantos > 0
        ? Math.max(8, Math.min(espessura, Math.floor((comprimento - vao) / quantos))) : espessura
    readonly property real tamanhoIcone: Math.round(celula * 0.8)
    // Espaço entre a borda da tela e o ícone: é onde fica o pontinho.
    readonly property real margemIcone: Math.max(2, Math.round((espessura - tamanhoIcone) * 0.62))
    readonly property real inicioFileira: Math.max(0, Math.round((comprimento - (quantos * celula + vao)) / 2))

    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    Layout.minimumWidth: vertical ? -1 : Math.max(espessura, Math.round(quantos * espessura * 0.5 + vao))
    Layout.preferredWidth: vertical ? -1 : Math.max(espessura, quantos * espessura + vao)
    Layout.maximumWidth: vertical ? -1 : Math.max(espessura, quantos * espessura + vao)
    Layout.minimumHeight: vertical ? Math.max(espessura, Math.round(quantos * espessura * 0.5 + vao)) : -1
    Layout.preferredHeight: vertical ? Math.max(espessura, quantos * espessura + vao) : -1
    Layout.maximumHeight: vertical ? Math.max(espessura, quantos * espessura + vao) : -1

    // Converte um retângulo dado no eixo da doca (a: ao longo, c: a partir da
    // borda da tela) para x, y, largura e altura de um item com este
    // comprimento e esta espessura.
    function caixa(a, c, la, lc, total, fundo) {
        switch (borda) {
        case "cima": return Qt.rect(a, c, la, lc);
        case "esquerda": return Qt.rect(c, a, lc, la);
        case "direita": return Qt.rect(fundo - c - lc, a, lc, la);
        default: return Qt.rect(a, fundo - c - lc, la, lc);
        }
    }

    // Onde começa o app (ou a lixeira) de número i na fileira normal.
    function inicioDe(i) {
        return inicioFileira + i * celula + (temLixeira && i >= tarefas.count ? vao : 0);
    }

    // O app embaixo de um ponto do eixo: o número na fileira, tarefas.count
    // para a lixeira e -1 para nada (o risquinho ou fora da fileira).
    function pedacoEm(a) {
        var p = a - inicioFileira;
        if (p < 0) {
            return -1;
        }
        var apps = tarefas.count * celula;
        if (p < apps) {
            return Math.min(tarefas.count - 1, Math.floor(p / celula));
        }
        if (temLixeira && p >= apps + vao && p < apps + vao + celula) {
            return tarefas.count;
        }
        return -1;
    }

    // ---------------------------------------------------------- ampliação
    readonly property bool amplia: Plasmoid.configuration.ampliacao !== false
    readonly property real maximo: amplia ? Zoom.maximoDoNivel(Plasmoid.configuration.ampliacaoNivel) : 1
    readonly property real raio: celula * 3
    // Onde o mouse está no eixo (fica o último ponto quando ele sai, para os
    // apps voltarem ao tamanho normal a partir dali).
    property real ponteiro: 0
    readonly property bool emCima: area.containsMouse && !arrastando
    // A janela da ampliação já apareceu (os ícones da barra podem sumir).
    property bool sobreposto: false
    property real forca: (emCima && sobreposto && maximo > 1) ? 1 : 0
    Behavior on forca {
        NumberAnimation {
            duration: raiz.forca > 0.5 ? 230 : 170
            easing.type: Easing.OutCubic
        }
    }
    // Os pedaços da fileira (apps, o risquinho e a lixeira) para a conta.
    readonly property var pedacos: {
        var lista = [];
        for (var i = 0; i < tarefas.count; i++) {
            lista.push({ tamanho: celula, cresce: true });
        }
        if (temLixeira) {
            lista.push({ tamanho: vao, cresce: false });
            lista.push({ tamanho: celula, cresce: true });
        }
        return lista;
    }
    readonly property var arranjo: Zoom.arrumar(pedacos, ponteiro - inicioFileira, maximo, raio, forca)
    // O número do pedaço da conta de um app (a lixeira vem depois do risquinho).
    function indiceDoPedaco(i) {
        return (temLixeira && i >= tarefas.count) ? tarefas.count + 1 : i;
    }

    // O app com o mouse em cima (para o balão com o nome).
    readonly property int apontado: emCima ? pedacoEm(ponteiro) : -1

    // Algum app está abrindo (pulando): a janela da ampliação aparece para o
    // pulo caber, mesmo sem o mouse em cima.
    property int pulando: 0
    function recontarPulos() {
        var n = 0;
        for (var i = 0; i < repetidor.count; i++) {
            var it = repetidor.itemAt(i);
            if (it && it.pulando) {
                n++;
            }
        }
        pulando = n;
    }

    readonly property bool querSobre: (area.containsMouse || pulando > 0 || forca > 0) && !arrastando && quantos > 0
    onQuerSobreChanged: {
        if (querSobre) {
            esconderSobre.stop();
            sobre.mostrar();
        } else {
            sobreposto = false;
            esconderSobre.restart();
        }
    }
    Timer {
        id: esconderSobre
        interval: 140
        onTriggered: {
            if (!raiz.querSobre) {
                sobre.visible = false;
            }
        }
    }

    // ------------------------------------------------------------ modelo
    TaskManager.TasksModel {
        id: tarefas
        virtualDesktop: mesas.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: atividades.currentActivity
        filterByVirtualDesktop: true
        filterByScreen: Plasmoid.configuration.showOnlyCurrentScreen === true
        filterByActivity: true
        filterHidden: true
        launchInPlace: true
        separateLaunchers: false
        hideActivatedLaunchers: true
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        groupingWindowTasksThreshold: -1
        sortMode: TaskManager.TasksModel.SortManual
        taskReorderingEnabled: true
        // Já na criação, para os fixados virem antes dos apps que já estavam
        // abertos (ao trocar o estilo da barra com janelas na tela).
        launcherList: Plasmoid.configuration.launchers

        onLauncherListChanged: {
            if (raiz.pronto) {
                Plasmoid.configuration.launchers = launcherList;
            }
        }
        Component.onCompleted: {
            raiz.pronto = true;
            repetidor.model = tarefas;
            repetidorSobre.model = tarefas;
            arrumarAbertos.restart();
        }
    }
    property bool pronto: false

    // Ao montar a doca com janelas já abertas (ao trocar o estilo da barra), o
    // KDE põe esses apps antes dos fixados, fora do lugar de cada um. Aqui cada
    // app volta para a ordem dos fixados (o aberto de um app fixado fica no
    // lugar dele) e os abertos que não estão fixados vão para o fim, como no Mac.
    Timer {
        id: arrumarAbertos
        interval: 300
        onTriggered: raiz.arrumarOrdem()
    }
    function arrumarOrdem() {
        var n = tarefas.count;
        var itens = [];
        var atual = [];
        for (var i = 0; i < n; i++) {
            var idx = tarefas.makeModelIndex(i);
            var url = tarefas.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
            var p = url ? tarefas.launcherPosition(url) : -1;
            var fixado = tarefas.data(idx, TaskManager.AbstractTasksModel.IsLauncher) === true
                || tarefas.data(idx, TaskManager.AbstractTasksModel.HasLauncher) === true;
            itens.push({ de: i, chave: p >= 0 ? p : (fixado ? 500 + i : 1000 + i) });
            atual.push(i);
        }
        itens.sort(function (x, y) { return x.chave - y.chave; });
        for (var t = 0; t < n; t++) {
            var j = atual.indexOf(itens[t].de);
            if (j !== t) {
                tarefas.move(j, t);
                atual.splice(t, 0, atual.splice(j, 1)[0]);
            }
        }
    }

    // Para as outras partes (o menu do app, a lixeira).
    readonly property TaskManager.TasksModel modelo: tarefas
    function itemDoApp(i) {
        return repetidor.itemAt(i);
    }

    TaskManager.VirtualDesktopInfo {
        id: mesas
    }
    TaskManager.ActivityInfo {
        id: atividades
    }

    // Lê um papel (role) de um app ou de uma janela de um grupo.
    function dado(indice, papel) {
        return tarefas.data(indice, papel);
    }

    // ------------------------------------------------------------ ações
    function clicar(i) {
        if (i < 0 || i >= tarefas.count) {
            return;
        }
        var idx = tarefas.makeModelIndex(i);
        if (dado(idx, TaskManager.AbstractTasksModel.IsLauncher) === true) {
            tarefas.requestActivate(idx);
            return;
        }
        if (dado(idx, TaskManager.AbstractTasksModel.IsGroupParent) === true) {
            // Várias janelas do mesmo app: um clique traz a próxima delas.
            var n = dado(idx, TaskManager.AbstractTasksModel.ChildCount) || 0;
            var ativa = -1;
            for (var j = 0; j < n; j++) {
                if (dado(tarefas.makeModelIndex(i, j), TaskManager.AbstractTasksModel.IsActive) === true) {
                    ativa = j;
                    break;
                }
            }
            tarefas.requestActivate(tarefas.makeModelIndex(i, ativa < 0 ? 0 : (ativa + 1) % Math.max(1, n)));
            return;
        }
        // Uma janela: como no Windows, clicar no app em uso esconde a janela.
        if (dado(idx, TaskManager.AbstractTasksModel.IsActive) === true
                && dado(idx, TaskManager.AbstractTasksModel.IsMinimized) !== true) {
            tarefas.requestToggleMinimized(idx);
        } else {
            tarefas.requestActivate(idx);
        }
    }

    function novaJanela(i) {
        if (i >= 0 && i < tarefas.count) {
            tarefas.requestNewInstance(tarefas.makeModelIndex(i));
        }
    }

    // "file:///usr/share/applications/x.desktop" vira "applications:x.desktop",
    // como o menu e o comando "matsu barra" guardam.
    function nomeDoLancador(url) {
        var u = url ? String(url) : "";
        var achado = u.match(/^file:\/\/.*\/applications\/([^\/]+\.desktop)$/);
        return achado ? "applications:" + achado[1] : u;
    }

    function fixar(i) {
        var url = nomeDoLancador(dado(tarefas.makeModelIndex(i), TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon));
        if (url.length > 0) {
            fazer("fixar " + aspas(url));
        }
    }

    // Tira da barra daqui (o modelo acha o nome certo, até o "navegador
    // padrão") e manda o mesmo nome para as barras das outras telas.
    function tirar(i) {
        var antes = tarefas.launcherList.slice();
        var url = dado(tarefas.makeModelIndex(i), TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
        tarefas.requestRemoveLauncher(url);
        var depois = tarefas.launcherList;
        for (var k = 0; k < antes.length; k++) {
            if (depois.indexOf(antes[k]) === -1) {
                fazer("tirar " + aspas(antes[k]));
                return;
            }
        }
    }

    function fechar(i) {
        if (i >= 0 && i < tarefas.count) {
            tarefas.requestClose(tarefas.makeModelIndex(i));
        }
    }

    function aspas(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    P5Support.DataSource {
        id: comando
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            if (fonte === raiz.ajudante + " estado idioma") {
                var achado = String(dados["stdout"] || "").match(/idioma=(\w+)/);
                if (achado) {
                    raiz.idioma = achado[1];
                }
            }
        }
    }
    function fazer(argumentos) {
        comando.connectSource(ajudante + " " + argumentos);
    }

    Component.onCompleted: fazer("estado idioma")

    // Avisa o KWin onde está cada app, para a animação de minimizar ir até ele.
    Timer {
        id: publicar
        interval: 400
        onTriggered: {
            for (var i = 0; i < repetidor.count; i++) {
                var it = repetidor.itemAt(i);
                if (it) {
                    var g = it.mapToGlobal(0, 0);
                    tarefas.requestPublishDelegateGeometry(tarefas.makeModelIndex(i), Qt.rect(g.x, g.y, it.width, it.height), it);
                }
            }
        }
    }
    onCelulaChanged: publicar.restart()
    onInicioFileiraChanged: publicar.restart()

    // ------------------------------------------- reordenar arrastando
    property bool arrastando: false
    property int arrastado: -1

    // --------------------------------------------- a fileira na barra
    Item {
        id: fileira
        anchors.fill: parent

        // O risquinho antes da lixeira.
        Rectangle {
            visible: raiz.temLixeira
            readonly property rect r: raiz.caixa(raiz.inicioFileira + tarefas.count * raiz.celula + raiz.vao / 2 - 0.5,
                                                 raiz.espessura * 0.22, 1, raiz.espessura * 0.56, raiz.comprimento, raiz.espessura)
            x: r.x; y: r.y; width: r.width; height: r.height
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.22)
            opacity: raiz.sobreposto ? 0 : 1
        }

        Repeater {
            id: repetidor
            delegate: Tarefa {
                doca: raiz
                numero: index
                icone: model.decoration
                nome: model.AppName || model.display || ""
                aberto: model.IsWindow === true || model.IsGroupParent === true
                ativo: model.IsActive === true
                pedindo: model.IsDemandingAttention === true
                pulando: model.IsStartup === true && Plasmoid.configuration.animarAbertura !== false
                arrastado: raiz.arrastando && raiz.arrastado === index
                // Em cima da janela da ampliação, o ícone da barra some.
                escondido: raiz.sobreposto
                onPulandoChanged: raiz.recontarPulos()
                Component.onDestruction: Qt.callLater(raiz.recontarPulos)
            }
            onCountChanged: {
                publicar.restart();
                Qt.callLater(raiz.recontarPulos);
            }
        }

        Loader {
            id: lixeira
            active: raiz.temLixeira
            source: "Lixeira.qml"
            readonly property rect r: raiz.caixa(raiz.inicioDe(tarefas.count), 0, raiz.celula, raiz.espessura, raiz.comprimento, raiz.espessura)
            x: r.x; y: r.y; width: r.width; height: r.height
            onLoaded: item.doca = raiz
        }

        // O ícone da lixeira (cheia ou vazia).
        Tarefa {
            visible: raiz.temLixeira
            doca: raiz
            numero: tarefas.count
            icone: lixeira.item && lixeira.item.cheia ? "user-trash-full" : "user-trash"
            nome: raiz.t("Lixeira", "Trash")
            escondido: raiz.sobreposto
        }
    }

    // Um só lugar recebe o mouse: passar por cima (a ampliação), clicar,
    // botão do meio (nova janela), botão direito (o menu do app) e arrastar
    // para mudar a ordem.
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        preventStealing: true

        property real apertouEm: -1
        property int apertado: -1

        function eixo(mouse) {
            return raiz.vertical ? mouse.y : mouse.x;
        }

        onPositionChanged: mouse => {
            raiz.ponteiro = eixo(mouse);
            if (pressed && apertado >= 0 && apertado < tarefas.count && (mouse.buttons & Qt.LeftButton)) {
                if (!raiz.arrastando && Math.abs(eixo(mouse) - apertouEm) > Kirigami.Units.gridUnit * 0.6) {
                    raiz.arrastando = true;
                    raiz.arrastado = apertado;
                }
                if (raiz.arrastando) {
                    var alvo = Math.max(0, Math.min(tarefas.count - 1, Math.floor((eixo(mouse) - raiz.inicioFileira) / raiz.celula)));
                    if (alvo !== raiz.arrastado) {
                        tarefas.move(raiz.arrastado, alvo);
                        raiz.arrastado = alvo;
                    }
                }
            }
        }
        onEntered: raiz.ponteiro = raiz.vertical ? mouseY : mouseX
        onPressed: mouse => {
            apertouEm = eixo(mouse);
            apertado = raiz.pedacoEm(apertouEm);
        }
        onReleased: {
            if (raiz.arrastando) {
                raiz.arrastando = false;
                raiz.arrastado = -1;
                tarefas.syncLaunchers();
                // A ordem nova vale para as barras das outras telas também.
                raiz.fazer("ordem " + raiz.aspas(tarefas.launcherList.join(",")));
                publicar.restart();
            }
        }
        onCanceled: {
            raiz.arrastando = false;
            raiz.arrastado = -1;
        }
        onClicked: mouse => {
            if (raiz.arrastando) {
                return;
            }
            var i = raiz.pedacoEm(eixo(mouse));
            if (i < 0) {
                return;
            }
            if (i === tarefas.count && raiz.temLixeira) {
                if (lixeira.item) {
                    if (mouse.button === Qt.RightButton) {
                        lixeira.item.abrirMenu(lixeira);
                    } else if (mouse.button === Qt.LeftButton) {
                        lixeira.item.abrir();
                    }
                }
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                raiz.novaJanela(i);
            } else if (mouse.button === Qt.RightButton) {
                menu.abrirPara(i);
            } else {
                raiz.clicar(i);
            }
        }
    }

    // Arquivos soltos em cima de um app abrem nele; um atalho de app (.desktop)
    // solto na doca fixa o app; arquivos soltos na lixeira vão para a lixeira.
    DropArea {
        anchors.fill: parent
        onPositionChanged: drag => {
            raiz.ponteiro = raiz.vertical ? drag.y : drag.x;
        }
        onDropped: drop => {
            if (!drop.hasUrls) {
                return;
            }
            var i = raiz.pedacoEm(raiz.vertical ? drop.y : drop.x);
            var urls = drop.urls;
            if (i === tarefas.count && raiz.temLixeira && lixeira.item) {
                lixeira.item.jogarFora(urls);
                drop.accept();
                return;
            }
            var atalhos = [];
            for (var k = 0; k < urls.length; k++) {
                if (/\.desktop$/.test(String(urls[k]))) {
                    atalhos.push(String(urls[k]));
                }
            }
            if (atalhos.length > 0) {
                for (var a = 0; a < atalhos.length; a++) {
                    raiz.fazer("fixar " + raiz.aspas(raiz.nomeDoLancador(atalhos[a])));
                }
                drop.accept();
            } else if (i >= 0 && i < tarefas.count) {
                tarefas.requestOpenUrls(tarefas.makeModelIndex(i), urls);
                drop.accept();
            }
        }
    }

    // --------------------------------------------------- o menu do app
    MenuApp {
        id: menu
        doca: raiz
    }

    // ------------------------------------------ a janela da ampliação
    // Os ícones da barra só somem depois que a janela já desenhou.
    Timer {
        id: primeiroQuadro
        interval: 34
        onTriggered: {
            if (raiz.querSobre && sobre.visible) {
                raiz.sobreposto = true;
            }
        }
    }

    PlasmaCore.Dialog {
        id: sobre

        // Quanto a fileira ampliada pode passar das pontas, e quanto espaço
        // ela precisa para dentro da tela (o app maior, o pulo e o balão; na
        // doca de lado, o balão fica ao lado do app e precisa da largura do nome).
        readonly property real sobra: Math.ceil(Zoom.sobraMaxima(raiz.celula, Math.max(raiz.maximo, 1.0001), raiz.raio) + Kirigami.Units.gridUnit * 5)
        readonly property real fundo: Math.ceil(raiz.espessura + raiz.tamanhoIcone * (Math.max(raiz.maximo, 1) - 1)
                                                + raiz.celula * 0.55 + Kirigami.Units.gridUnit * 2.6
                                                + (raiz.vertical ? Kirigami.Units.gridUnit * 11 : 0))
        readonly property real eixoTotal: raiz.comprimento + sobra * 2

        type: PlasmaCore.Dialog.Tooltip
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Dialog.NoBackground
        outputOnly: true
        hideOnWindowDeactivate: false
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
        visible: false

        // Põe a janela exatamente em cima da doca (e sobrando para os lados e
        // para dentro da tela).
        function mostrar() {
            var g = raiz.mapToGlobal(0, 0);
            var x = g.x, y = g.y;
            switch (raiz.borda) {
            case "cima": x -= sobra; break;
            case "esquerda": y -= sobra; break;
            case "direita": x += raiz.espessura - fundo; y -= sobra; break;
            default: x -= sobra; y += raiz.espessura - fundo; break;
            }
            sobre.x = Math.round(x);
            sobre.y = Math.round(y);
            sobre.visible = true;
            primeiroQuadro.restart();
        }

        mainItem: Item {
            id: palco
            width: raiz.vertical ? sobre.fundo : sobre.eixoTotal
            height: raiz.vertical ? sobre.eixoTotal : sobre.fundo

            // O risquinho antes da lixeira, acompanhando a fileira.
            Rectangle {
                visible: raiz.temLixeira
                readonly property int k: tarefas.count
                readonly property real a: sobre.sobra + raiz.inicioFileira + (raiz.arranjo.inicio[k] !== undefined ? raiz.arranjo.inicio[k] : 0) + raiz.vao / 2 - 0.5
                readonly property rect r: raiz.caixa(a, raiz.espessura * 0.22, 1, raiz.espessura * 0.56, sobre.eixoTotal, sobre.fundo)
                x: r.x; y: r.y; width: r.width; height: r.height
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.22)
            }

            Repeater {
                id: repetidorSobre
                delegate: IconeAmpliado {
                    doca: raiz
                    numero: index
                    sobra: sobre.sobra
                    fundo: sobre.fundo
                    eixoTotal: sobre.eixoTotal
                    icone: model.decoration
                    nome: model.AppName || model.display || ""
                    aberto: model.IsWindow === true || model.IsGroupParent === true
                    ativo: model.IsActive === true
                    pedindo: model.IsDemandingAttention === true
                    comecando: model.IsStartup === true && Plasmoid.configuration.animarAbertura !== false
                }
            }

            // A lixeira ampliada.
            IconeAmpliado {
                visible: raiz.temLixeira
                doca: raiz
                numero: tarefas.count
                sobra: sobre.sobra
                fundo: sobre.fundo
                eixoTotal: sobre.eixoTotal
                icone: lixeira.item && lixeira.item.cheia ? "user-trash-full" : "user-trash"
                nome: raiz.t("Lixeira", "Trash")
                aberto: false
                ativo: false
            }
        }
    }
}
