// Nome e menus do app, na barra de cima do estilo Mac, logo depois do logo do
// Matsu: o nome do app em uso, em negrito, e os menus dele.
//
// Os menus de verdade do app (Arquivo, Editar, Exibir...) vêm do menu global do
// Plasma, a peça org.kde.plasma.appmenu, que fica logo depois desta na barra.
// Os apps que não mandam menu (os do Matsu, feitos em QML) ganham aqui um menu
// de reserva: "Janela" (minimizar, maximizar, tela cheia, sempre na frente).
// O menu do nome (sobre, nova janela, esconder, fechar) vale para todo app.
// Na área de trabalho, sem janela na frente, o nome vira "Área de trabalho",
// com os ajustes e o menu "Ir" (as pastas da pessoa).
//
// Tudo sai do gerenciador de tarefas do Plasma (TasksModel): a janela ativa,
// o nome, o ícone e as ações de janela.
import QtQuick
import QtQuick.Layouts
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: raiz

    // Português quando o sistema está em português (o ajudante confirma, porque
    // o Plasma pode abrir sem o idioma no ambiente).
    property string idioma: ""
    readonly property bool pt: idioma !== "" ? idioma === "pt"
        : (Qt.locale().name.indexOf("pt") === 0 || Qt.locale().uiLanguages.join(",").indexOf("pt") === 0)
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }

    readonly property string ajudante: "/usr/libexec/matsu/matsu-central"

    preferredRepresentation: fullRepresentation
    Plasmoid.icon: "matsu-barra-symbolic"
    toolTipMainText: ""

    // ---------------------------------------------------------------------
    // A janela ativa

    TaskManager.TasksModel {
        id: tarefas
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortLastActivated

        onActiveTaskChanged: raiz.lerDepois()
        onDataChanged: raiz.lerDepois()
        onCountChanged: raiz.lerDepois()
    }


    // O app que aparece agora: {valido, nome, icone, generico, appId, ids,
    // temMenu, minimizada, maximizada, cheia, frente, podeMax, podeCheia,
    // podeMin, podeFechar, podeNova}. Com um menu aberto ele fica parado: o
    // menu pega o foco e, sem isso, o nome trocaria para "Área de trabalho".
    property var atual: ({ valido: false })
    // A última janela que esteve na frente (a lista de ids dela, em texto).
    property string ultimaJanela: ""

    function dado(indice, qual) {
        return tarefas.data(indice, qual);
    }

    function idsDe(indice) {
        return JSON.stringify(dado(indice, TaskManager.AbstractTasksModel.WinIdList) || []);
    }

    function acharJanela(ids) {
        if (ids === "") {
            return null;
        }
        for (var r = 0; r < tarefas.count; r++) {
            var i = tarefas.index(r, 0);
            if (idsDe(i) === ids) {
                return i;
            }
        }
        return null;
    }

    // Lê de novo um instante depois: o Plasma muda vários dados de uma vez.
    function lerDepois() {
        espera.restart();
    }
    Timer {
        id: espera
        interval: 60
        onTriggered: raiz.ler()
    }

    function ler() {
        if (raiz.menuAberto !== "") {
            return;
        }
        var i = tarefas.activeTask;
        if (i && i.valid) {
            ultimaJanela = idsDe(i);
        } else {
            // Um balão do Plasma (a central, o calendário) pegou o foco: o app
            // de antes continua na frente, se a janela dele ainda está à vista.
            i = acharJanela(ultimaJanela);
            if (i && dado(i, TaskManager.AbstractTasksModel.IsMinimized) === true) {
                i = null;
            }
        }
        if (!i || !i.valid) {
            atual = { valido: false };
            return;
        }
        var nome = String(dado(i, TaskManager.AbstractTasksModel.AppName) || "");
        if (nome === "") {
            // Sem atalho (.desktop): o título da janela, sem o " — App" do fim.
            nome = String(dado(i, Qt.DisplayRole) || "").split(" — ").pop().split(" - ").pop();
        }
        atual = {
            valido: true,
            nome: nome,
            icone: dado(i, Qt.DecorationRole),
            generico: String(dado(i, TaskManager.AbstractTasksModel.GenericName) || ""),
            appId: String(dado(i, TaskManager.AbstractTasksModel.AppId) || ""),
            ids: idsDe(i),
            temMenu: String(dado(i, TaskManager.AbstractTasksModel.ApplicationMenuServiceName) || "") !== "",
            minimizada: dado(i, TaskManager.AbstractTasksModel.IsMinimized) === true,
            maximizada: dado(i, TaskManager.AbstractTasksModel.IsMaximized) === true,
            cheia: dado(i, TaskManager.AbstractTasksModel.IsFullScreen) === true,
            frente: dado(i, TaskManager.AbstractTasksModel.IsKeepAbove) === true,
            podeMax: dado(i, TaskManager.AbstractTasksModel.IsMaximizable) === true,
            podeCheia: dado(i, TaskManager.AbstractTasksModel.IsFullScreenable) === true,
            podeMin: dado(i, TaskManager.AbstractTasksModel.IsMinimizable) === true,
            podeFechar: dado(i, TaskManager.AbstractTasksModel.IsClosable) !== false,
            podeNova: dado(i, TaskManager.AbstractTasksModel.CanLaunchNewInstance) === true
        };
    }

    readonly property string nomeAgora: atual.valido ? atual.nome : t("Área de trabalho", "Desktop")

    // ---------------------------------------------------------------------
    // Ações

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

    function pasta(local) {
        Qt.openUrlExternally(StandardPaths.writableLocation(local));
    }

    // Cada janela do mesmo app que o app do menu.
    function janelasDoApp(appId) {
        var lista = [];
        for (var r = 0; r < tarefas.count; r++) {
            var i = tarefas.index(r, 0);
            if (dado(i, TaskManager.AbstractTasksModel.IsWindow) === true && String(dado(i, TaskManager.AbstractTasksModel.AppId) || "") === appId) {
                lista.push(i);
            }
        }
        return lista;
    }

    function agir(acao) {
        fecharMenu();
        var i = acharJanela(atual.ids || "");
        var r, j, todas;
        switch (acao) {
        case "sobre":
            return;
        case "nova":
            if (i) tarefas.requestNewInstance(i);
            break;
        case "minimizar":
            if (i && !atual.minimizada) tarefas.requestToggleMinimized(i);
            break;
        case "esconder":
            todas = janelasDoApp(atual.appId);
            for (j = 0; j < todas.length; j++) {
                if (dado(todas[j], TaskManager.AbstractTasksModel.IsMinimized) !== true) tarefas.requestToggleMinimized(todas[j]);
            }
            break;
        case "esconder-outros":
            for (r = 0; r < tarefas.count; r++) {
                j = tarefas.index(r, 0);
                if (dado(j, TaskManager.AbstractTasksModel.IsWindow) === true && String(dado(j, TaskManager.AbstractTasksModel.AppId) || "") !== atual.appId
                        && dado(j, TaskManager.AbstractTasksModel.IsMinimized) !== true && dado(j, TaskManager.AbstractTasksModel.IsMinimizable) === true) {
                    tarefas.requestToggleMinimized(j);
                }
            }
            break;
        case "mostrar-todos":
            for (r = 0; r < tarefas.count; r++) {
                j = tarefas.index(r, 0);
                if (dado(j, TaskManager.AbstractTasksModel.IsWindow) === true && dado(j, TaskManager.AbstractTasksModel.IsMinimized) === true) {
                    tarefas.requestToggleMinimized(j);
                }
            }
            break;
        case "maximizar":
            if (i) tarefas.requestToggleMaximized(i);
            break;
        case "tela-cheia":
            if (i) tarefas.requestToggleFullScreen(i);
            break;
        case "frente":
            if (i) tarefas.requestToggleKeepAbove(i);
            break;
        case "fechar-janela":
            if (i) tarefas.requestClose(i);
            break;
        case "fechar-app":
            todas = janelasDoApp(atual.appId);
            if (todas.length === 0 && i) todas = [i];
            for (j = 0; j < todas.length; j++) {
                tarefas.requestClose(todas[j]);
            }
            break;
        case "sobre-matsu":
            fazer("abrir ajustes sobre");
            break;
        case "ajustes":
            fazer("abrir ajustes");
            break;
        case "papel":
            fazer("abrir ajustes papel");
            break;
        case "barra":
            fazer("abrir ajustes barra");
            break;
        case "bloquear":
            fazer("bloquear");
            break;
        case "sair":
            fazer("sair");
            break;
        case "pessoal":
            pasta(StandardPaths.HomeLocation);
            break;
        case "documentos":
            pasta(StandardPaths.DocumentsLocation);
            break;
        case "downloads":
            pasta(StandardPaths.DownloadLocation);
            break;
        case "imagens":
            pasta(StandardPaths.PicturesLocation);
            break;
        case "musicas":
            pasta(StandardPaths.MusicLocation);
            break;
        case "videos":
            pasta(StandardPaths.MoviesLocation);
            break;
        case "lixeira":
            Qt.openUrlExternally("trash:/");
            break;
        }
        raiz.lerDepois();
    }

    // ---------------------------------------------------------------------
    // Os menus

    function separador() {
        return { separador: true };
    }

    readonly property var menus: {
        if (!atual.valido) {
            return [
                { id: "mesa", titulo: nomeAgora, negrito: true, itens: [
                    { texto: t("Sobre o Matsu", "About Matsu"), acao: "sobre-matsu" },
                    separador(),
                    { texto: t("Ajustes do Matsu…", "Matsu Settings…"), acao: "ajustes" },
                    { texto: t("Papel de parede…", "Wallpaper…"), acao: "papel" },
                    { texto: t("Barra e doca…", "Bar and dock…"), acao: "barra" },
                    separador(),
                    { texto: t("Mostrar as janelas escondidas", "Show hidden windows"), acao: "mostrar-todos" },
                    separador(),
                    { texto: t("Bloquear a tela", "Lock screen"), acao: "bloquear" },
                    { texto: t("Sair…", "Log out…"), acao: "sair" }
                ] },
                { id: "ir", titulo: t("Ir", "Go"), itens: [
                    { texto: t("Pasta pessoal", "Home"), acao: "pessoal" },
                    { texto: t("Documentos", "Documents"), acao: "documentos" },
                    { texto: "Downloads", acao: "downloads" },
                    { texto: t("Imagens", "Pictures"), acao: "imagens" },
                    { texto: t("Músicas", "Music"), acao: "musicas" },
                    { texto: t("Vídeos", "Videos"), acao: "videos" },
                    separador(),
                    { texto: t("Lixeira", "Trash"), acao: "lixeira" }
                ] }
            ];
        }
        var lista = [
            { id: "app", titulo: nomeAgora, negrito: true, itens: [
                { texto: t("Sobre o ", "About ") + atual.nome, acao: "sobre" },
                separador(),
                { texto: t("Nova janela", "New window"), acao: "nova", ativo: atual.podeNova },
                separador(),
                { texto: t("Esconder ", "Hide ") + atual.nome, acao: "esconder", ativo: atual.podeMin },
                { texto: t("Esconder os outros", "Hide others"), acao: "esconder-outros" },
                { texto: t("Mostrar todos", "Show all"), acao: "mostrar-todos" },
                separador(),
                { texto: t("Fechar ", "Quit ") + atual.nome, acao: "fechar-app", ativo: atual.podeFechar }
            ] }
        ];
        // O menu de reserva só para quem não manda o menu dele.
        if (!atual.temMenu) {
            lista.push({ id: "janela", titulo: t("Janela", "Window"), itens: [
                { texto: t("Minimizar", "Minimize"), acao: "minimizar", ativo: atual.podeMin && !atual.minimizada },
                { texto: atual.maximizada ? t("Voltar ao tamanho de antes", "Restore size") : t("Maximizar", "Maximize"),
                  acao: "maximizar", ativo: atual.podeMax },
                { texto: t("Tela cheia", "Full screen"), acao: "tela-cheia", ativo: atual.podeCheia, marcado: atual.cheia },
                { texto: t("Sempre na frente", "Keep on top"), acao: "frente", marcado: atual.frente },
                separador(),
                { texto: t("Fechar janela", "Close window"), acao: "fechar-janela", dica: "Alt+F4", ativo: atual.podeFechar }
            ] });
        }
        return lista;
    }

    // O menu aberto agora (o id dele) e o título de onde ele desce.
    property string menuAberto: ""
    property Item tituloAberto: null
    readonly property var menuAtual: {
        for (var m = 0; m < menus.length; m++) {
            if (menus[m].id === menuAberto) {
                return menus[m];
            }
        }
        return null;
    }
    property bool mostrandoSobre: false

    // Clicar no título do menu aberto fecha o menu. (O clique na barra já
    // fecha o balão antes de chegar aqui; então não abre de novo.)
    property string fechouId: ""
    property double fechouEm: 0

    function abrirMenu(id, titulo) {
        if (menuAberto === id && balao.visible) {
            fecharMenu();
            return;
        }
        if (!balao.visible && fechouId === id && Date.now() - fechouEm < 350) {
            fechouId = "";
            return;
        }
        mostrandoSobre = false;
        menuAberto = id;
        tituloAberto = titulo;
        // O menu desce colado no título, alinhado pela esquerda, como no Mac.
        var ponto = titulo.mapToGlobal(0, titulo.height);
        balao.x = Math.round(ponto.x - balao.margins.left + Kirigami.Units.smallSpacing);
        balao.y = Math.round(ponto.y + 2);
        // Mostra depois que o menu novo ganhou tamanho (senão o balão abre vazio).
        Qt.callLater(function () {
            balao.visible = true;
            conteudo.entrar();
        });
    }

    function fecharMenu() {
        balao.visible = false;
    }

    // Com um menu aberto, passar o mouse em outro título troca de menu.
    function passou(id, titulo) {
        if (balao.visible && menuAberto !== id) {
            abrirMenu(id, titulo);
        }
    }

    Component.onCompleted: {
        comando.connectSource(ajudante + " estado idioma");
        ler();
    }

    // ---------------------------------------------------------------------
    // Na barra

    fullRepresentation: Item {
        id: barra

        Layout.minimumWidth: titulos.implicitWidth
        Layout.preferredWidth: titulos.implicitWidth
        Layout.maximumWidth: titulos.implicitWidth
        Layout.fillHeight: true

        Row {
            id: titulos
            height: parent.height
            spacing: 0

            // Troca o nome com um esmaecer rápido, sem pular.
            opacity: 1
            property string nome: raiz.nomeAgora
            onNomeChanged: troca.restart()
            SequentialAnimation {
                id: troca
                NumberAnimation { target: titulos; property: "opacity"; to: 0.25; duration: 70 }
                NumberAnimation { target: titulos; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutCubic }
            }

            Repeater {
                model: raiz.menus
                Titulo {
                    id: titulo
                    required property var modelData
                    texto: modelData.titulo
                    negrito: modelData.negrito === true
                    aberto: raiz.menuAberto === modelData.id && balao.visible
                    onAbrir: raiz.abrirMenu(modelData.id, titulo)
                    onContainsMouseChanged: if (containsMouse) raiz.passou(modelData.id, titulo)
                }
            }
        }
    }

    // ---------------------------------------------------------------------
    // O menu que desce: um balão de vidro do Matsu, que aparece com um
    // esmaecer e uma descida curtinha.

    PlasmaCore.Dialog {
        id: balao

        visible: false
        type: PlasmaCore.Dialog.PopupMenu
        location: PlasmaCore.Types.Floating
        hideOnWindowDeactivate: true
        flags: Qt.WindowStaysOnTopHint
        onVisibleChanged: {
            if (!visible) {
                raiz.fechouId = raiz.menuAberto;
                raiz.fechouEm = Date.now();
                raiz.menuAberto = "";
                raiz.tituloAberto = null;
                raiz.mostrandoSobre = false;
                raiz.lerDepois();
            }
        }

        mainItem: Item {
            id: conteudo

            readonly property int largura: Math.max(Kirigami.Units.gridUnit * 12,
                                                    Math.min(Kirigami.Units.gridUnit * 22, colunaMenu.implicitWidth))

            width: raiz.mostrandoSobre ? sobre.implicitWidth : largura
            height: Math.max(Kirigami.Units.gridUnit * 2, raiz.mostrandoSobre ? sobre.implicitHeight : colunaMenu.implicitHeight)
            focus: true
            Keys.onEscapePressed: raiz.fecharMenu()
            Keys.onLeftPressed: conteudo.vizinho(-1)
            Keys.onRightPressed: conteudo.vizinho(1)

            function entrar() {
                aparecer.restart();
                forceActiveFocus();
            }

            // Setas para os lados: o menu do lado.
            function vizinho(passo) {
                for (var m = 0; m < raiz.menus.length; m++) {
                    if (raiz.menus[m].id === raiz.menuAberto) {
                        var n = m + passo;
                        if (n >= 0 && n < raiz.menus.length) {
                            raiz.menuAberto = raiz.menus[n].id;
                            aparecer.restart();
                        }
                        return;
                    }
                }
            }

            Item {
                id: pilha
                anchors.fill: parent
                transform: Translate { id: descida }

                ColumnLayout {
                    id: colunaMenu
                    visible: !raiz.mostrandoSobre
                    width: conteudo.largura
                    spacing: 0

                    Repeater {
                        model: raiz.menuAtual ? raiz.menuAtual.itens : []
                        ItemMenu {
                            required property var modelData
                            dados: modelData
                            onEscolhido: {
                                if (modelData.acao === "sobre") {
                                    raiz.mostrandoSobre = true;
                                    aparecer.restart();
                                } else {
                                    raiz.agir(modelData.acao);
                                }
                            }
                        }
                    }
                }

                // "Sobre o app": o ícone, o nome e o que ele é.
                ColumnLayout {
                    id: sobre
                    visible: raiz.mostrandoSobre
                    width: implicitWidth
                    spacing: Kirigami.Units.smallSpacing

                    Item {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 15
                        Layout.preferredHeight: Kirigami.Units.smallSpacing
                    }
                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Kirigami.Units.iconSizes.huge
                        implicitHeight: implicitWidth
                        source: raiz.atual.icone || "application-x-executable"
                    }
                    Kirigami.Heading {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 15
                        level: 3
                        text: raiz.atual.nome || ""
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 15
                        visible: text.length > 0
                        text: raiz.atual.generico || ""
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        opacity: 0.75
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 15
                        visible: text.length > 0
                        text: raiz.atual.appId || ""
                        elide: Text.ElideMiddle
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.5
                    }
                    Item {
                        Layout.preferredHeight: Kirigami.Units.smallSpacing
                    }
                    PlasmaComponents.Button {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: Kirigami.Units.smallSpacing
                        text: raiz.t("Fechar", "Close")
                        onClicked: raiz.fecharMenu()
                    }
                }
            }

            ParallelAnimation {
                id: aparecer
                NumberAnimation { target: pilha; property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
                NumberAnimation { target: descida; property: "y"; from: -Kirigami.Units.smallSpacing * 1.5; to: 0; duration: 180; easing.type: Easing.OutCubic }
            }
        }
    }
}
