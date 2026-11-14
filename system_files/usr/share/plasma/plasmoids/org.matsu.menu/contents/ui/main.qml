// Menu do Matsu: o Menu Iniciar do Windows 11 junto com a vista Apps do Mac,
// num balão de vidro do Matsu. Em cima a busca; depois os fixados (seis por
// linha, duas linhas e "Mostrar tudo"), os recentes e "Todos os apps", que
// aparecem em blocos por categoria (como no Mac: três apps grandes e os
// próximos pequenos), em grade ou em lista com as letras. Clicar num bloco
// abre a categoria inteira. Embaixo, a pessoa, os Ajustes do Matsu, bloquear
// e desligar. Na fusão e no estilo windows o botão do logo vem com a pílula
// "Buscar apps e arquivos" ao lado. O botão direito num app fixa ou tira o
// app do menu e da barra.
//
// Abre com a tecla Meta (o metadata diz que este é o menu do sistema) e com
// Alt+F1. Os apps, os recentes e a busca vêm das mesmas peças do menu do KDE;
// a categoria de cada app vem do ajudante (matsu-central apps-categorias).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: raiz

    // Português quando o sistema está em português. O ajudante confirma (lê o
    // plasma-localerc), porque o Plasma pode abrir sem o idioma no ambiente.
    property string idioma: ""
    readonly property bool pt: idioma !== "" ? idioma === "pt"
        : (Qt.locale().name.indexOf("pt") === 0 || Qt.locale().uiLanguages.join(",").indexOf("pt") === 0)
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }

    readonly property string ajudante: "/usr/libexec/matsu/matsu-central"
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    // Só a pílula da busca, sem o logo: é a busca que fica na ilha do meio.
    readonly property bool soBusca: Plasmoid.configuration.soBusca === true && !vertical
    readonly property bool comBusca: (Plasmoid.configuration.comBusca === true || soBusca) && !vertical

    // O que a pessoa digitou na busca.
    property string busca: ""
    readonly property bool buscando: busca.trim().length > 0

    preferredRepresentation: compactRepresentation
    toolTipMainText: t("Menu do Matsu", "Matsu menu")
    toolTipSubText: t("Apps, arquivos e ajustes", "Apps, files and settings")

    // Todos os apps, em ordem alfabética (a linha 1 do modelo; a 0 é dos fixados).
    readonly property Kicker.RootModel apps: Kicker.RootModel {
        autoPopulate: false
        appletInterface: raiz
        flat: true
        sorted: true
        showSeparators: false
        showTopLevelItems: true
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: true

        Component.onCompleted: {
            favoritesModel.initForClient("org.matsu.menu.favorites.instance-" + Plasmoid.id);
            // Numa conta nova, os fixados começam com os apps do dia a dia.
            if (!Plasmoid.configuration.fixadosProntos) {
                if (favoritesModel.count < 1) {
                    favoritesModel.portOldFavorites(Plasmoid.configuration.fixados);
                }
                Plasmoid.configuration.fixadosProntos = true;
            }
        }
    }

    // A busca: apps, arquivos, ajustes, contas e o que mais o KRunner achar.
    readonly property Kicker.RunnerModel resultados: Kicker.RunnerModel {
        query: raiz.busca
        appletInterface: raiz
        mergeResults: true
        favoritesModel: raiz.apps.favoritesModel
    }

    // Apps e arquivos abertos por último.
    Kicker.RecentUsageModel {
        id: recentes
        favoritesModel: raiz.apps.favoritesModel
    }

    Kicker.ProcessRunner {
        id: processos
    }

    // A conta da pessoa (nome e foto), para o rodapé.
    KCoreAddons.KUser {
        id: pessoa
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
            } else if (fonte === raiz.ajudante + " apps-barra") {
                raiz.lerBarra(dados["stdout"]);
            } else if (fonte === raiz.ajudante + " apps-categorias") {
                raiz.lerCategorias(dados["stdout"]);
            } else if (/^\S+ (fixar|tirar) /.test(fonte)) {
                raiz.fazer("apps-barra");
            }
        }
    }

    function fazer(argumentos) {
        comando.connectSource(ajudante + " " + argumentos);
    }

    // Põe entre aspas simples para o shell.
    function aspas(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // Os apps fixados na barra, pelo atalho (.desktop) que cada um abre:
    // "firefox.desktop" -> "preferred://browser", como a barra guarda.
    property var naBarra: ({})
    function lerBarra(saida) {
        var mapa = {};
        var linhas = String(saida || "").split("\n");
        for (var i = 0; i < linhas.length; i++) {
            var partes = linhas[i].split("|");
            if (partes.length >= 5 && partes[0] === "fixado" && partes[4].length > 0) {
                mapa[partes[4]] = partes[1];
            }
        }
        naBarra = mapa;
    }

    // A categoria de cada app ("org.kde.kate.desktop" -> "utilitarios").
    property var categorias: ({})
    function lerCategorias(saida) {
        var mapa = {};
        var linhas = String(saida || "").split("\n");
        for (var i = 0; i < linhas.length; i++) {
            var partes = linhas[i].split("|");
            if (partes.length === 2 && partes[0].length > 0) {
                mapa[partes[0]] = partes[1];
            }
        }
        if (linhas.length > 1) {
            categorias = mapa;
        }
    }

    // Tira acentos e maiúsculas ("Área" -> "area"), para as letras da lista.
    function simples(s) {
        var r = String(s).toLowerCase();
        return r.normalize ? r.normalize("NFD").replace(/[\u0300-\u036f]/g, "") : r;
    }

    // O atalho (.desktop) de um item do menu, ou vazio se não for um app.
    function atalhoDe(favoriteId, url) {
        var f = favoriteId ? String(favoriteId) : "";
        if (f.indexOf("applications:") === 0) {
            f = f.substring(13);
        }
        if (/\.desktop$/.test(f) && f.indexOf("/") === -1) {
            return f;
        }
        var u = url ? String(url) : "";
        if (/\.desktop$/.test(u)) {
            return u.substring(u.lastIndexOf("/") + 1);
        }
        return "";
    }

    // O app do menu de botão direito aberto agora: o atalho (para a barra) e o
    // id dos fixados do menu.
    property string appDoMenu: ""
    property string appDoMenuId: ""
    property bool appDoMenuNoMenu: false
    readonly property bool appDoMenuNaBarra: naBarra[appDoMenu] !== undefined
    function menuDoApp(item, favoriteId, url, x, y) {
        var atalho = atalhoDe(favoriteId, url);
        var id = favoriteId ? String(favoriteId) : (atalho !== "" ? "applications:" + atalho : "");
        if (atalho === "" && id === "") {
            return;
        }
        appDoMenu = atalho;
        appDoMenuId = id;
        appDoMenuNoMenu = id !== "" && apps.favoritesModel.isFavorite(id);
        contexto.visualParent = item;
        contexto.open(x, y);
    }

    PlasmaExtras.Menu {
        id: contexto

        PlasmaExtras.MenuItem {
            text: raiz.t("Fixar no menu", "Pin to the menu")
            icon: "bookmark-new"
            visible: raiz.appDoMenuId !== "" && !raiz.appDoMenuNoMenu
            onClicked: raiz.apps.favoritesModel.addFavorite(raiz.appDoMenuId)
        }
        PlasmaExtras.MenuItem {
            text: raiz.t("Tirar do menu", "Unpin from the menu")
            icon: "bookmark-remove"
            visible: raiz.appDoMenuId !== "" && raiz.appDoMenuNoMenu
            onClicked: raiz.apps.favoritesModel.removeFavorite(raiz.appDoMenuId)
        }
        PlasmaExtras.MenuItem {
            text: raiz.t("Fixar na barra", "Pin to the bar")
            icon: "window-pin"
            visible: raiz.appDoMenu !== "" && !raiz.appDoMenuNaBarra
            onClicked: raiz.fazer("fixar " + raiz.aspas("applications:" + raiz.appDoMenu))
        }
        PlasmaExtras.MenuItem {
            text: raiz.t("Tirar da barra", "Unpin from the bar")
            icon: "window-unpin"
            visible: raiz.appDoMenu !== "" && raiz.appDoMenuNaBarra
            onClicked: raiz.fazer("tirar " + raiz.aspas(raiz.naBarra[raiz.appDoMenu]))
        }
        PlasmaExtras.MenuItem {
            separator: true
        }
        PlasmaExtras.MenuItem {
            text: raiz.t("Organizar os apps da barra…", "Arrange the bar apps…")
            icon: "matsu-barra-symbolic"
            onClicked: raiz.organizarBarra()
        }
    }

    // Os Ajustes do Matsu já abertos nos apps fixados da barra.
    function organizarBarra() {
        fazer("abrir ajustes barra-apps");
        expanded = false;
    }

    // Abre o que foi escolhido (app, arquivo ou resultado da busca) e fecha o menu.
    function abrir(modelo, indice) {
        if (modelo && modelo.trigger && indice >= 0) {
            modelo.trigger(indice, "", null);
        }
        expanded = false;
    }

    Plasmoid.contextualActions: [
        // Como no botão Iniciar do Windows (botão direito): o Gerenciador de tarefas.
        PlasmaCore.Action {
            text: raiz.t("Gerenciador de tarefas", "Task Manager")
            icon.name: "org.matsu.tarefas"
            onTriggered: raiz.fazer("abrir tarefas")
        },
        PlasmaCore.Action {
            text: raiz.t("Organizar os apps da barra…", "Arrange the bar apps…")
            icon.name: "matsu-barra-symbolic"
            onTriggered: raiz.organizarBarra()
        },
        PlasmaCore.Action {
            text: raiz.t("Editar os apps do menu…", "Edit applications…")
            icon.name: "kmenuedit"
            visible: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            onTriggered: processos.runMenuEditor()
        }
    ]

    Component.onCompleted: {
        // A tecla Meta e o Alt+F1 abrem e fecham o menu. (A chave mudou de lugar
        // entre versões do Plasma; liga onde ela existir.)
        if (Plasmoid.activationTogglesExpanded !== undefined) {
            Plasmoid.activationTogglesExpanded = true;
        }
        if (raiz.activationTogglesExpanded !== undefined) {
            raiz.activationTogglesExpanded = true;
        }
        comando.connectSource(ajudante + " estado idioma");
        fazer("apps-categorias");
    }

    // Na barra: o logo do Matsu e, na fusão e no windows, a pílula da busca.
    // Com "soBusca", só a pílula (a busca que fica na ilha do meio).
    compactRepresentation: Item {
        id: compacta

        readonly property bool aberto: raiz.expanded
        readonly property int lado: raiz.vertical ? width : height

        Layout.minimumWidth: raiz.vertical ? -1 : linhaCompacta.implicitWidth
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.minimumHeight: raiz.vertical ? width : -1
        Layout.preferredHeight: Layout.minimumHeight
        Layout.fillHeight: !raiz.vertical
        Layout.fillWidth: raiz.vertical

        // Guarda se o menu estava aberto ao apertar: clicar no botão com o menu
        // aberto fecha, em vez de fechar e abrir de novo.
        property bool estavaAberto: false
        function apertou() {
            estavaAberto = raiz.expanded;
        }
        function clicou() {
            raiz.expanded = !estavaAberto;
        }

        Row {
            id: linhaCompacta
            height: parent.height
            spacing: Kirigami.Units.smallSpacing

            MouseArea {
                id: botao
                visible: !raiz.soBusca
                width: visible ? compacta.lado : 0
                height: compacta.lado
                hoverEnabled: true
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: raiz.t("Menu do Matsu", "Matsu menu")
                onPressed: compacta.apertou()
                onClicked: compacta.clicou()
                Keys.onReturnPressed: raiz.expanded = !raiz.expanded
                Keys.onSpacePressed: raiz.expanded = !raiz.expanded

                Kirigami.Icon {
                    anchors.fill: parent
                    source: Plasmoid.icon
                    active: botao.containsMouse || compacta.aberto
                    roundToIconSize: false
                }
            }

            MouseArea {
                id: pilula
                visible: raiz.comBusca
                width: visible ? Math.round(Kirigami.Units.gridUnit * 12.5) : 0
                height: parent.height
                hoverEnabled: true
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: raiz.t("Buscar apps e arquivos", "Search apps and files")
                onPressed: compacta.apertou()
                onClicked: compacta.clicou()
                Keys.onReturnPressed: raiz.expanded = !raiz.expanded
                Keys.onSpacePressed: raiz.expanded = !raiz.expanded

                Rectangle {
                    readonly property color base: compacta.aberto ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor

                    anchors.fill: parent
                    anchors.topMargin: Kirigami.Units.smallSpacing
                    anchors.bottomMargin: Kirigami.Units.smallSpacing
                    radius: Math.min(height / 2, Kirigami.Units.gridUnit * 0.7)
                    color: Qt.rgba(base.r, base.g, base.b, compacta.aberto ? 0.30
                                   : (pilula.pressed ? 0.22 : (pilula.containsMouse || pilula.activeFocus ? 0.16 : 0.10)))
                    Behavior on color {
                        ColorAnimation { duration: Kirigami.Units.shortDuration }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.7)
                    anchors.rightMargin: Math.round(Kirigami.Units.gridUnit * 0.7)
                    spacing: Math.round(Kirigami.Units.gridUnit * 0.45)

                    Kirigami.Icon {
                        source: "matsu-busca-symbolic"
                        isMask: true
                        color: Kirigami.Theme.textColor
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignVCenter
                    }
                    PlasmaComponents.Label {
                        text: raiz.t("Buscar apps e arquivos", "Search apps and files")
                        opacity: 0.75
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }

    // O balão do menu.
    fullRepresentation: FocusScope {
        id: cheia

        readonly property int largura: Kirigami.Units.gridUnit * 36
        // Cabe também na tela de um notebook pequeno (1366x768).
        readonly property int alturaTela: Screen.height > 0 ? Screen.height : 1080
        readonly property int altura: Math.min(Kirigami.Units.gridUnit * 40, Math.round(alturaTela * 0.84))
        readonly property int margem: Math.round(Kirigami.Units.gridUnit * 0.35)
        readonly property int alturaLinha: Math.round(Kirigami.Units.gridUnit * 2.9)
        readonly property int alturaCelula: Math.round(Kirigami.Units.gridUnit * 5)
        readonly property color texto: Kirigami.Theme.textColor
        readonly property color realce: Kirigami.Theme.highlightColor

        // Como no Windows 11: os fixados em seis colunas, duas linhas e "Mostrar tudo".
        readonly property int colunas: 6
        property bool todosFixados: false
        readonly property int linhasFixados: {
            var total = Math.ceil(fixados.count / colunas);
            return todosFixados ? total : Math.min(2, total);
        }
        // Os recentes em duas colunas, até quatro.
        readonly property int linhasRecentes: Math.min(2, Math.ceil(recentes.count / 2))

        // Como aparecem "Todos os apps": categorias, grade ou lista.
        readonly property string exibicao: {
            var e = String(Plasmoid.configuration.exibicao || "");
            return e === "grade" || e === "lista" ? e : "categorias";
        }
        function exibir(e) {
            Plasmoid.configuration.exibicao = e;
        }
        function nomeExibicao(e) {
            return e === "grade" ? raiz.t("Grade", "Grid") : (e === "lista" ? raiz.t("Lista", "List") : raiz.t("Categorias", "Categories"));
        }

        // A categoria aberta (clicou num bloco), ou "" na página principal.
        property string categoriaAberta: ""

        // Todos os apps. O modelo só fica pronto depois do refresh, então é
        // lido de novo cada vez que o KDE refaz a lista (app instalado ou removido).
        property var todos: null
        function lerTodos() {
            todos = raiz.apps.modelForRow(1);
        }

        // Os apps de "todos" numa lista simples (nome, ícone, atalho, letra e a
        // linha no modelo do KDE, para abrir), para os blocos, a grade e a lista.
        property var appsLista: []
        Instantiator {
            id: leitor
            model: cheia.todos
            delegate: QtObject {
                readonly property int linha: index
                readonly property string nome: model.display || ""
                readonly property var icone: model.decoration
                readonly property string favoriteId: model.favoriteId ? String(model.favoriteId) : ""
                readonly property string url: model.url ? String(model.url) : ""
            }
            onObjectAdded: juntar.restart()
            onObjectRemoved: juntar.restart()
        }
        Timer {
            id: juntar
            interval: 50
            onTriggered: cheia.juntarApps()
        }
        function letraDe(nome) {
            var c = raiz.simples(nome).charAt(0).toUpperCase();
            return /[A-Z]/.test(c) ? c : "#";
        }
        function juntarApps() {
            var lista = [];
            for (var i = 0; i < leitor.count; i++) {
                var o = leitor.objectAt(i);
                if (!o || o.nome.length === 0) {
                    continue;
                }
                lista.push({ nome: o.nome, icone: o.icone, favoriteId: o.favoriteId, url: o.url, linha: o.linha,
                             atalho: raiz.atalhoDe(o.favoriteId, o.url), letra: letraDe(o.nome) });
            }
            appsLista = lista;
        }

        // As categorias na ordem da vista Apps do Mac (só as que têm apps).
        readonly property var ordemCategorias: ["utilitarios", "produtividade", "internet", "criatividade", "leitura",
                                                "entretenimento", "jogos", "desenvolvimento", "outros"]
        function nomeCategoria(id) {
            switch (id) {
            case "utilitarios": return raiz.t("Utilitários", "Utilities");
            case "produtividade": return raiz.t("Produtividade", "Productivity");
            case "internet": return raiz.t("Internet e social", "Internet & Social");
            case "criatividade": return raiz.t("Criatividade", "Creativity");
            case "leitura": return raiz.t("Informação e leitura", "Information & Reading");
            case "entretenimento": return raiz.t("Entretenimento", "Entertainment");
            case "jogos": return raiz.t("Jogos", "Games");
            case "desenvolvimento": return raiz.t("Desenvolvimento", "Developer Tools");
            default: return raiz.t("Outros", "Other");
            }
        }
        readonly property var grupos: {
            var mapa = {};
            for (var i = 0; i < appsLista.length; i++) {
                var a = appsLista[i];
                var c = raiz.categorias[a.atalho] || "outros";
                if (!mapa[c]) {
                    mapa[c] = [];
                }
                mapa[c].push(a);
            }
            var r = [];
            for (var k = 0; k < ordemCategorias.length; k++) {
                var id = ordemCategorias[k];
                if (mapa[id]) {
                    r.push({ id: id, nome: nomeCategoria(id), apps: mapa[id] });
                }
            }
            return r;
        }
        readonly property var grupoAberto: {
            for (var i = 0; i < grupos.length; i++) {
                if (grupos[i].id === categoriaAberta) {
                    return grupos[i];
                }
            }
            return null;
        }

        function abrirApp(app) {
            if (app && cheia.todos) {
                raiz.abrir(cheia.todos, app.linha);
            }
        }
        function abrirCategoria(id) {
            categoriaAberta = id;
            gradeCategoria.currentIndex = -1;
            gradeCategoria.positionViewAtBeginning();
        }

        Layout.minimumWidth: largura
        Layout.preferredWidth: largura
        Layout.maximumWidth: largura
        Layout.minimumHeight: altura
        Layout.preferredHeight: altura
        Layout.maximumHeight: altura
        focus: true

        // O que aparece embaixo do nome de um resultado: o tipo e o detalhe,
        // como no vídeo ("App: ...", "Configurações: ...").
        function detalheDoResultado(grupo, descricao) {
            var g = grupo ? String(grupo) : "";
            var d = descricao ? String(descricao) : "";
            if (g.length > 0 && d.length > 0 && g !== d) {
                return g + ": " + d;
            }
            return g.length > 0 ? g : d;
        }

        function abrirEscolhido() {
            if (raiz.buscando) {
                raiz.abrir(lista.model, lista.currentIndex >= 0 ? lista.currentIndex : 0);
            } else if (fixados.count > 0) {
                raiz.abrir(fixados.model, 0);
            }
        }

        function mover(passo) {
            if (raiz.buscando) {
                if (lista.count > 0) {
                    lista.currentIndex = Math.max(0, Math.min(lista.count - 1, lista.currentIndex + passo));
                }
            } else if (passo > 0 && categoriaAberta !== "") {
                gradeCategoria.currentIndex = 0;
                gradeCategoria.forceActiveFocus();
            } else if (passo > 0 && fixados.count > 0) {
                fixados.currentIndex = 0;
                fixados.forceActiveFocus();
            }
        }

        function preparar() {
            campo.text = "";
            categoriaAberta = "";
            todosFixados = false;
            fixados.currentIndex = -1;
            pagina.contentY = 0;
            campo.forceActiveFocus();
        }

        Connections {
            target: raiz.apps
            function onRefreshed() {
                cheia.lerTodos();
                raiz.fazer("apps-categorias");
            }
        }

        Connections {
            target: raiz
            function onExpandedChanged() {
                if (raiz.expanded) {
                    cheia.preparar();
                    raiz.fazer("apps-barra");
                }
            }
        }

        Component.onCompleted: {
            raiz.apps.refresh();
            lerTodos();
            preparar();
        }

        Keys.onEscapePressed: {
            if (campo.text.length > 0) {
                campo.text = "";
                campo.forceActiveFocus();
            } else if (categoriaAberta !== "") {
                categoriaAberta = "";
                campo.forceActiveFocus();
            } else {
                raiz.expanded = false;
            }
        }

        // A escolha da exibição de "Todos os apps", como o "Exibição" do Windows 11.
        PlasmaExtras.Menu {
            id: menuExibicao

            PlasmaExtras.MenuItem {
                text: raiz.t("Categorias", "Categories")
                icon: "view-list-icons"
                checkable: true
                checked: cheia.exibicao === "categorias"
                onClicked: cheia.exibir("categorias")
            }
            PlasmaExtras.MenuItem {
                text: raiz.t("Grade", "Grid")
                icon: "view-grid"
                checkable: true
                checked: cheia.exibicao === "grade"
                onClicked: cheia.exibir("grade")
            }
            PlasmaExtras.MenuItem {
                text: raiz.t("Lista", "List")
                icon: "view-list-text"
                checkable: true
                checked: cheia.exibicao === "lista"
                onClicked: cheia.exibir("lista")
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: cheia.margem
            spacing: Math.round(Kirigami.Units.gridUnit * 0.5)

            // Campo da busca.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 2.3)
                radius: Math.round(Kirigami.Units.gridUnit * 0.7)
                color: Qt.rgba(cheia.texto.r, cheia.texto.g, cheia.texto.b, campo.activeFocus ? 0.12 : 0.09)
                border.width: 1
                border.color: campo.activeFocus ? Qt.rgba(cheia.texto.r, cheia.texto.g, cheia.texto.b, 0.28) : "transparent"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: campo.forceActiveFocus()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.7)
                    anchors.rightMargin: Math.round(Kirigami.Units.gridUnit * 0.35)
                    spacing: Math.round(Kirigami.Units.gridUnit * 0.5)

                    Kirigami.Icon {
                        source: "matsu-busca-symbolic"
                        isMask: true
                        color: Kirigami.Theme.textColor
                        opacity: 0.8
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextInput {
                        id: campo
                        focus: true
                        clip: true
                        selectByMouse: true
                        color: Kirigami.Theme.textColor
                        selectionColor: Kirigami.Theme.highlightColor
                        selectedTextColor: Kirigami.Theme.highlightedTextColor
                        font: Kirigami.Theme.defaultFont
                        verticalAlignment: TextInput.AlignVCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Accessible.role: Accessible.EditableText
                        Accessible.name: raiz.t("Buscar apps e arquivos", "Search apps and files")
                        onTextChanged: {
                            raiz.busca = text;
                            lista.currentIndex = 0;
                            esperaBusca.restart();
                        }
                        Keys.onDownPressed: cheia.mover(1)
                        Keys.onUpPressed: cheia.mover(-1)
                        Keys.onReturnPressed: cheia.abrirEscolhido()
                        Keys.onEnterPressed: cheia.abrirEscolhido()

                        PlasmaComponents.Label {
                            anchors.fill: parent
                            visible: campo.text.length === 0
                            text: raiz.t("Buscar apps, arquivos e ajustes", "Search apps, files and settings")
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            opacity: 0.55
                        }
                    }

                    PlasmaComponents.ToolButton {
                        visible: campo.text.length > 0
                        icon.name: "matsu-fechar-symbolic"
                        text: raiz.t("Limpar", "Clear")
                        display: QQC2.AbstractButton.IconOnly
                        Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 1.7)
                        Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 1.7)
                        onClicked: {
                            campo.text = "";
                            campo.forceActiveFocus();
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ---------------------------------------------- a página principal
                Flickable {
                    id: pagina
                    anchors.fill: parent
                    visible: !raiz.buscando && cheia.categoriaAberta === ""
                    clip: true
                    contentWidth: width
                    contentHeight: colunaPagina.implicitHeight + Kirigami.Units.largeSpacing
                    boundsBehavior: Flickable.StopAtBounds
                    QQC2.ScrollBar.vertical: PlasmaComponents.ScrollBar {
                        id: barraRolagem
                    }

                    // Mantém à vista o app escolhido pelo teclado.
                    function mostrar(item) {
                        if (!item) {
                            return;
                        }
                        var y = item.mapToItem(colunaPagina, 0, 0).y;
                        if (y < contentY) {
                            contentY = Math.max(0, y - Kirigami.Units.smallSpacing);
                        } else if (y + item.height > contentY + height) {
                            contentY = Math.min(contentHeight - height, y + item.height - height + Kirigami.Units.smallSpacing);
                        }
                    }

                    ColumnLayout {
                        id: colunaPagina
                        width: pagina.width - (barraRolagem.visible ? Kirigami.Units.smallSpacing * 2 : 0)
                        spacing: Math.round(Kirigami.Units.gridUnit * 0.4)

                        // Fixados.
                        Titulo {
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            texto: raiz.t("Fixados", "Pinned")
                            acao: fixados.count > cheia.colunas * 2
                                  ? (cheia.todosFixados ? raiz.t("Mostrar menos", "Show less") : raiz.t("Mostrar tudo", "Show all")) : ""
                            iconeAcao: cheia.todosFixados ? "go-up-symbolic" : "go-next-symbolic"
                            onAcionado: cheia.todosFixados = !cheia.todosFixados
                        }

                        GridView {
                            id: fixados
                            model: raiz.apps.favoritesModel
                            interactive: false
                            clip: true
                            keyNavigationEnabled: true
                            currentIndex: -1
                            cellWidth: Math.floor(width / cheia.colunas)
                            cellHeight: cheia.alturaCelula
                            Layout.fillWidth: true
                            Layout.preferredHeight: cheia.linhasFixados * cellHeight
                            Behavior on Layout.preferredHeight {
                                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                            }
                            delegate: Celula {
                                id: celulaFixada
                                width: fixados.cellWidth
                                height: fixados.cellHeight
                                icone: model.decoration
                                titulo: model.display || ""
                                destacado: fixados.activeFocus && index === fixados.currentIndex
                                onAcionado: raiz.abrir(fixados.model, index)
                                onMenuPedido: (x, y) => raiz.menuDoApp(celulaFixada, model.favoriteId, model.url, x, y)
                            }
                            onCurrentIndexChanged: if (activeFocus) pagina.mostrar(currentItem)
                            Keys.onReturnPressed: raiz.abrir(model, currentIndex)
                            Keys.onEnterPressed: raiz.abrir(model, currentIndex)
                            Keys.onUpPressed: {
                                if (currentIndex >= cheia.colunas) {
                                    moveCurrentIndexUp();
                                } else {
                                    campo.forceActiveFocus();
                                }
                            }
                            Keys.onDownPressed: {
                                if (currentIndex + cheia.colunas < Math.min(count, cheia.linhasFixados * cheia.colunas)) {
                                    moveCurrentIndexDown();
                                }
                            }
                        }

                        PlasmaComponents.Label {
                            visible: fixados.count === 0
                            text: raiz.t("Clique com o botão direito num app para fixá-lo aqui.", "Right-click an app to pin it here.")
                            wrapMode: Text.Wrap
                            opacity: 0.6
                            Layout.fillWidth: true
                            Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.55)
                        }

                        // Recentes (apps e arquivos abertos por último).
                        Titulo {
                            visible: recentes.count > 0
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            texto: raiz.t("Recentes", "Recent")
                        }

                        GridView {
                            id: gradeRecentes
                            visible: recentes.count > 0
                            model: recentes
                            interactive: false
                            clip: true
                            cellWidth: Math.floor(width / 2)
                            cellHeight: cheia.alturaLinha
                            Layout.fillWidth: true
                            Layout.preferredHeight: cheia.linhasRecentes * cellHeight
                            delegate: Linha {
                                id: linhaRecente
                                visible: index < 4
                                width: gradeRecentes.cellWidth
                                height: gradeRecentes.cellHeight
                                icone: model.decoration
                                titulo: model.display || ""
                                detalhe: model.description || ""
                                onAcionado: raiz.abrir(gradeRecentes.model, index)
                                onMenuPedido: (x, y) => raiz.menuDoApp(linhaRecente, model.favoriteId, model.url, x, y)
                            }
                        }

                        // Todos os apps, com a escolha da exibição à direita.
                        Titulo {
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            texto: raiz.t("Todos os apps", "All apps")
                            acao: raiz.t("Exibição: ", "View: ") + cheia.nomeExibicao(cheia.exibicao)
                            iconeAcao: "go-down-symbolic"
                            onAcionado: botao => {
                                menuExibicao.visualParent = botao;
                                menuExibicao.openRelative();
                            }
                        }

                        // Em blocos por categoria.
                        Grid {
                            id: blocos
                            visible: cheia.exibicao === "categorias"
                            readonly property real largura: colunaPagina.width - Math.round(Kirigami.Units.gridUnit * 0.6)
                            readonly property int colunasBlocos: Math.max(3, Math.floor(largura / (Kirigami.Units.gridUnit * 7.6)))
                            readonly property real ladoBloco: Math.floor((largura - columnSpacing * (colunasBlocos - 1)) / colunasBlocos)
                            columns: colunasBlocos
                            columnSpacing: Math.round(Kirigami.Units.gridUnit * 0.9)
                            rowSpacing: Math.round(Kirigami.Units.gridUnit * 0.7)
                            Layout.preferredWidth: largura
                            Layout.preferredHeight: implicitHeight
                            Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.3)
                            Layout.topMargin: Kirigami.Units.smallSpacing

                            Repeater {
                                model: cheia.grupos
                                BlocoCategoria {
                                    required property var modelData
                                    width: blocos.ladoBloco
                                    height: implicitHeight
                                    nome: modelData.nome
                                    apps: modelData.apps
                                    onAbrirApp: app => cheia.abrirApp(app)
                                    onAbrirCategoria: cheia.abrirCategoria(modelData.id)
                                    onMenuPedido: (item, app, x, y) => raiz.menuDoApp(item, app.favoriteId, app.url, x, y)
                                }
                            }
                        }

                        // Em grade, em ordem alfabética.
                        GridView {
                            id: gradeTodos
                            visible: cheia.exibicao === "grade"
                            model: visible ? cheia.appsLista : []
                            interactive: false
                            cellWidth: Math.floor(width / cheia.colunas)
                            cellHeight: cheia.alturaCelula
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.ceil(count / cheia.colunas) * cellHeight
                            delegate: Celula {
                                id: celulaTodos
                                required property var modelData
                                width: gradeTodos.cellWidth
                                height: gradeTodos.cellHeight
                                icone: modelData.icone
                                titulo: modelData.nome
                                onAcionado: cheia.abrirApp(modelData)
                                onMenuPedido: (x, y) => raiz.menuDoApp(celulaTodos, modelData.favoriteId, modelData.url, x, y)
                            }
                        }

                        // Em lista, com a letra antes de cada grupo (como no Windows 11).
                        Column {
                            visible: cheia.exibicao === "lista"
                            Layout.fillWidth: true

                            Repeater {
                                model: parent.visible ? cheia.appsLista : []
                                Column {
                                    id: itemLista
                                    required property var modelData
                                    required property int index
                                    readonly property bool primeiraDaLetra: index === 0 || cheia.appsLista[index - 1].letra !== modelData.letra
                                    width: parent.width

                                    PlasmaComponents.Label {
                                        visible: itemLista.primeiraDaLetra
                                        text: itemLista.modelData.letra
                                        font.weight: Font.DemiBold
                                        opacity: 0.6
                                        leftPadding: Math.round(Kirigami.Units.gridUnit * 0.65)
                                        topPadding: itemLista.index === 0 ? 0 : Kirigami.Units.smallSpacing * 2
                                        bottomPadding: Kirigami.Units.smallSpacing
                                    }
                                    Linha {
                                        id: linhaTodos
                                        width: parent.width
                                        height: Math.round(Kirigami.Units.gridUnit * 2.3)
                                        tamanhoIcone: Math.round(Kirigami.Units.gridUnit * 1.5)
                                        simples: true
                                        icone: itemLista.modelData.icone
                                        titulo: itemLista.modelData.nome
                                        detalhe: ""
                                        onAcionado: cheia.abrirApp(itemLista.modelData)
                                        onMenuPedido: (x, y) => raiz.menuDoApp(linhaTodos, itemLista.modelData.favoriteId, itemLista.modelData.url, x, y)
                                    }
                                }
                            }
                        }

                        PlasmaComponents.Label {
                            visible: cheia.appsLista.length === 0
                            text: raiz.t("Carregando os apps…", "Loading apps…")
                            opacity: 0.6
                            Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.55)
                        }
                    }
                }

                // ---------------------------------------------- uma categoria aberta
                ColumnLayout {
                    anchors.fill: parent
                    visible: !raiz.buscando && cheia.categoriaAberta !== ""
                    spacing: Math.round(Kirigami.Units.gridUnit * 0.4)

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.ToolButton {
                            icon.name: "go-previous-symbolic"
                            text: raiz.t("Voltar", "Back")
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            onClicked: {
                                cheia.categoriaAberta = "";
                                campo.forceActiveFocus();
                            }
                        }
                        PlasmaComponents.Label {
                            text: cheia.grupoAberto ? cheia.grupoAberto.nome : ""
                            textFormat: Text.PlainText
                            font.weight: Font.DemiBold
                            font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 1.15)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Label {
                            text: cheia.grupoAberto ? (cheia.grupoAberto.apps.length === 1 ? raiz.t("1 app", "1 app")
                                                       : raiz.t(cheia.grupoAberto.apps.length + " apps", cheia.grupoAberto.apps.length + " apps")) : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                            Layout.rightMargin: Math.round(Kirigami.Units.gridUnit * 0.5)
                        }
                    }

                    GridView {
                        id: gradeCategoria
                        model: cheia.grupoAberto ? cheia.grupoAberto.apps : []
                        clip: true
                        keyNavigationEnabled: true
                        currentIndex: -1
                        boundsBehavior: Flickable.StopAtBounds
                        cellWidth: Math.floor(width / cheia.colunas)
                        cellHeight: cheia.alturaCelula
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        QQC2.ScrollBar.vertical: PlasmaComponents.ScrollBar {}
                        delegate: Celula {
                            id: celulaCategoria
                            required property var modelData
                            required property int index
                            width: gradeCategoria.cellWidth
                            height: gradeCategoria.cellHeight
                            icone: modelData.icone
                            titulo: modelData.nome
                            destacado: gradeCategoria.activeFocus && index === gradeCategoria.currentIndex
                            onAcionado: cheia.abrirApp(modelData)
                            onMenuPedido: (x, y) => raiz.menuDoApp(celulaCategoria, modelData.favoriteId, modelData.url, x, y)
                        }
                        Keys.onReturnPressed: cheia.abrirApp(cheia.grupoAberto.apps[currentIndex])
                        Keys.onEnterPressed: cheia.abrirApp(cheia.grupoAberto.apps[currentIndex])
                        Keys.onUpPressed: {
                            if (currentIndex >= cheia.colunas) {
                                moveCurrentIndexUp();
                            } else {
                                campo.forceActiveFocus();
                            }
                        }
                    }
                }

                // ---------------------------------------------- a busca
                // Os resultados, o primeiro já escolhido (Enter abre).
                Item {
                    anchors.fill: parent
                    visible: raiz.buscando

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Math.round(Kirigami.Units.gridUnit * 0.4)

                        Titulo {
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            texto: raiz.t("Resultados para “%1”", "Results for “%1”").arg(raiz.busca.trim())
                        }

                        ListView {
                            id: lista
                            model: raiz.resultados.count > 0 ? raiz.resultados.modelForRow(0) : null
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            highlightMoveDuration: 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            QQC2.ScrollBar.vertical: PlasmaComponents.ScrollBar {}
                            delegate: Linha {
                                id: linhaResultado
                                width: ListView.view.width
                                height: cheia.alturaLinha
                                icone: model.decoration
                                titulo: model.display || ""
                                detalhe: cheia.detalheDoResultado(model.group, model.description)
                                destacado: index === lista.currentIndex
                                onAcionado: raiz.abrir(lista.model, index)
                                onMenuPedido: (x, y) => raiz.menuDoApp(linhaResultado, model.favoriteId, model.url, x, y)
                            }
                        }
                    }

                    Timer {
                        id: esperaBusca
                        interval: 700
                    }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit * 2
                        visible: lista.count === 0 && !esperaBusca.running
                        text: raiz.t("Nada encontrado. Tente outra palavra.", "Nothing found. Try another word.")
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        opacity: 0.6
                    }
                }
            }

            // Rodapé: a pessoa, os Ajustes do Matsu, bloquear e desligar.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(cheia.texto.r, cheia.texto.g, cheia.texto.b, 0.10)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                MouseArea {
                    id: conta
                    readonly property string nome: pessoa.fullName.length > 0 ? pessoa.fullName : pessoa.loginName
                    hoverEnabled: true
                    Accessible.role: Accessible.Button
                    Accessible.name: raiz.t("Conta: ", "Account: ") + nome
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 2.2)
                    onClicked: {
                        raiz.expanded = false;
                        raiz.fazer("abrir kcm kcm_users");
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(Kirigami.Units.gridUnit * 0.6)
                        color: Qt.rgba(cheia.texto.r, cheia.texto.g, cheia.texto.b, conta.pressed ? 0.16 : (conta.containsMouse ? 0.09 : 0))
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Math.round(Kirigami.Units.gridUnit * 0.5)

                        // A foto da conta; sem foto, a inicial do nome num círculo do Matsu.
                        Item {
                            implicitWidth: Math.round(Kirigami.Units.gridUnit * 1.6)
                            implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.6)
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Kirigami.Theme.highlightColor
                                visible: foto.status !== Image.Ready

                                PlasmaComponents.Label {
                                    anchors.centerIn: parent
                                    text: conta.nome.length > 0 ? conta.nome.charAt(0).toUpperCase() : "K"
                                    color: Kirigami.Theme.highlightedTextColor
                                    font.weight: Font.DemiBold
                                }
                            }
                            Kirigami.ShadowedImage {
                                id: foto
                                anchors.fill: parent
                                radius: width / 2
                                source: pessoa.faceIconUrl
                                sourceSize.width: width * 2
                                sourceSize.height: height * 2
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                            }
                        }

                        PlasmaComponents.Label {
                            text: conta.nome
                            textFormat: Text.PlainText
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                Repeater {
                    model: [
                        { icone: "matsu-ajustes-symbolic", nome: raiz.t("Ajustes do Matsu", "Matsu Settings"), acao: "abrir ajustes" },
                        { icone: "matsu-cadeado-symbolic", nome: raiz.t("Bloquear", "Lock"), acao: "bloquear" },
                        { icone: "matsu-desligar-symbolic", nome: raiz.t("Desligar", "Power"), acao: "sair" }
                    ]
                    PlasmaComponents.ToolButton {
                        required property var modelData
                        icon.name: modelData.icone
                        text: modelData.nome
                        display: QQC2.AbstractButton.IconOnly
                        QQC2.ToolTip.text: modelData.nome
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        onClicked: {
                            raiz.expanded = false;
                            raiz.fazer(modelData.acao);
                        }
                    }
                }
            }
        }
    }
}
