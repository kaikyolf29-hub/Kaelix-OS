// Menu do Kaelix, no jeito do vídeo da fusão: um balão de vidro com a busca em
// cima, os recentes (numa conta nova, os fixados), todos os apps e, embaixo, a
// pessoa, os Ajustes do Kaelix, bloquear e desligar. Na fusão e no estilo
// windows o botão do logo vem com a pílula "Buscar apps e arquivos" ao lado.
//
// Abre com a tecla Meta (o metadata diz que este é o menu do sistema) e com
// Alt+F1. Os apps, os recentes e a busca vêm das mesmas peças do menu do KDE.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
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

    readonly property string ajudante: "/usr/libexec/kaelix/kaelix-central"
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool comBusca: Plasmoid.configuration.comBusca && !vertical

    // O que a pessoa digitou na busca.
    property string busca: ""
    readonly property bool buscando: busca.trim().length > 0

    preferredRepresentation: compactRepresentation
    toolTipMainText: t("Menu do Kaelix", "Kaelix menu")
    toolTipSubText: t("Apps, arquivos e ajustes", "Apps, files and settings")

    // Todos os apps, em ordem alfabética (a linha 1 do modelo; a 0 é dos fixados).
    readonly property Kicker.RootModel apps: Kicker.RootModel {
        autoPopulate: false
        appletInterface: raiz
        flat: true
        sorted: true
        showSeparators: false
        showRootSeparator: true
        showTopLevelItems: true
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: true

        Component.onCompleted: {
            favoritesModel.initForClient("org.kaelix.menu.favorites.instance-" + Plasmoid.id);
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
            }
        }
    }

    function fazer(argumentos) {
        comando.connectSource(ajudante + " " + argumentos);
    }

    // Abre o que foi escolhido (app, arquivo ou resultado da busca) e fecha o menu.
    function abrir(modelo, indice) {
        if (modelo && modelo.trigger && indice >= 0) {
            modelo.trigger(indice, "", null);
        }
        expanded = false;
    }

    Plasmoid.contextualActions: [
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
    }

    // Na barra: o logo do Kaelix e, na fusão e no windows, a pílula da busca.
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
                width: compacta.lado
                height: compacta.lado
                hoverEnabled: true
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: raiz.t("Menu do Kaelix", "Kaelix menu")
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
                        source: "kaelix-busca-symbolic"
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

        readonly property int largura: Kirigami.Units.gridUnit * 24
        readonly property int altura: Kirigami.Units.gridUnit * 32
        readonly property int margem: Math.round(Kirigami.Units.gridUnit * 0.35)
        readonly property int alturaLinha: Math.round(Kirigami.Units.gridUnit * 2.9)
        readonly property color texto: Kirigami.Theme.textColor
        readonly property color realce: Kirigami.Theme.highlightColor

        // No lugar dos recentes, numa conta nova (sem nada aberto ainda), os fixados.
        readonly property var modeloTopo: recentes.count > 0 ? recentes : raiz.apps.favoritesModel
        readonly property int linhasTopo: Math.min(topo.count, 4)

        // Todos os apps. O modelo só fica pronto depois do refresh, então é
        // lido de novo cada vez que o KDE refaz a lista (app instalado ou removido).
        property var todos: null
        function lerTodos() {
            todos = raiz.apps.modelForRow(1);
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
            } else if (topo.count > 0) {
                raiz.abrir(topo.model, 0);
            }
        }

        function mover(passo) {
            if (raiz.buscando) {
                if (lista.count > 0) {
                    lista.currentIndex = Math.max(0, Math.min(lista.count - 1, lista.currentIndex + passo));
                }
            } else if (passo > 0) {
                if (topo.count > 0) {
                    topo.currentIndex = 0;
                    topo.forceActiveFocus();
                } else {
                    grade.forceActiveFocus();
                }
            }
        }

        function preparar() {
            campo.text = "";
            topo.currentIndex = 0;
            grade.currentIndex = 0;
            grade.positionViewAtBeginning();
            campo.forceActiveFocus();
        }

        Connections {
            target: raiz.apps
            function onRefreshed() {
                cheia.lerTodos();
            }
        }

        Connections {
            target: raiz
            function onExpandedChanged() {
                if (raiz.expanded) {
                    cheia.preparar();
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
            } else {
                raiz.expanded = false;
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
                border.color: campo.activeFocus ? Qt.rgba(cheia.realce.r, cheia.realce.g, cheia.realce.b, 0.75) : "transparent"

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
                        source: "kaelix-busca-symbolic"
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
                            text: raiz.t("Buscar apps e arquivos", "Search apps and files")
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            opacity: 0.55
                        }
                    }

                    PlasmaComponents.ToolButton {
                        visible: campo.text.length > 0
                        icon.name: "kaelix-fechar-symbolic"
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

            // Título da seção, como no vídeo: "Recentes" ou "Resultados para ...".
            PlasmaComponents.Label {
                text: raiz.buscando ? raiz.t("Resultados para “%1”", "Results for “%1”").arg(raiz.busca.trim())
                    : (recentes.count > 0 ? raiz.t("Recentes", "Recent") : raiz.t("Fixados", "Pinned"))
                textFormat: Text.PlainText
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.6
                opacity: 0.6
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.55)
                Layout.topMargin: Kirigami.Units.smallSpacing
            }

            // Sem busca: recentes (até 4) e todos os apps.
            ColumnLayout {
                visible: !raiz.buscando
                spacing: Math.round(Kirigami.Units.gridUnit * 0.5)
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: topo
                    model: cheia.modeloTopo
                    interactive: false
                    clip: true
                    keyNavigationEnabled: true
                    Layout.fillWidth: true
                    Layout.preferredHeight: cheia.linhasTopo * cheia.alturaLinha
                    delegate: Linha {
                        width: ListView.view.width
                        height: cheia.alturaLinha
                        icone: model.decoration
                        titulo: model.display || ""
                        detalhe: model.description || ""
                        destacado: topo.activeFocus && index === topo.currentIndex
                        onAcionado: raiz.abrir(topo.model, index)
                    }
                    Keys.onReturnPressed: raiz.abrir(model, currentIndex)
                    Keys.onEnterPressed: raiz.abrir(model, currentIndex)
                    Keys.onUpPressed: {
                        if (currentIndex > 0) {
                            decrementCurrentIndex();
                        } else {
                            campo.forceActiveFocus();
                        }
                    }
                    Keys.onDownPressed: {
                        if (currentIndex < cheia.linhasTopo - 1) {
                            incrementCurrentIndex();
                        } else {
                            grade.forceActiveFocus();
                        }
                    }
                }

                PlasmaComponents.Label {
                    text: raiz.t("Todos os apps", "All apps")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.6
                    opacity: 0.6
                    Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.55)
                    Layout.topMargin: Kirigami.Units.smallSpacing
                }

                GridView {
                    id: grade
                    model: cheia.todos
                    clip: true
                    keyNavigationEnabled: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: Math.floor(width / 4)
                    cellHeight: Math.round(Kirigami.Units.gridUnit * 4.9)
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    QQC2.ScrollBar.vertical: PlasmaComponents.ScrollBar {}
                    delegate: Celula {
                        width: grade.cellWidth
                        height: grade.cellHeight
                        icone: model.decoration
                        titulo: model.display || ""
                        destacado: grade.activeFocus && index === grade.currentIndex
                        onAcionado: raiz.abrir(grade.model, index)
                    }
                    Keys.onReturnPressed: raiz.abrir(model, currentIndex)
                    Keys.onEnterPressed: raiz.abrir(model, currentIndex)
                    Keys.onUpPressed: {
                        if (currentIndex >= 4) {
                            moveCurrentIndexUp();
                        } else if (topo.count > 0) {
                            topo.currentIndex = cheia.linhasTopo - 1;
                            topo.forceActiveFocus();
                        } else {
                            campo.forceActiveFocus();
                        }
                    }
                }
            }

            // Com busca: os resultados, o primeiro já escolhido (Enter abre).
            Item {
                visible: raiz.buscando
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: lista
                    anchors.fill: parent
                    model: raiz.resultados.count > 0 ? raiz.resultados.modelForRow(0) : null
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    QQC2.ScrollBar.vertical: PlasmaComponents.ScrollBar {}
                    delegate: Linha {
                        width: ListView.view.width
                        height: cheia.alturaLinha
                        icone: model.decoration
                        titulo: model.display || ""
                        detalhe: cheia.detalheDoResultado(model.group, model.description)
                        destacado: index === lista.currentIndex
                        onAcionado: raiz.abrir(lista.model, index)
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

            // Rodapé: a pessoa, os Ajustes do Kaelix, bloquear e desligar.
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

                        // A foto da conta; sem foto, a inicial do nome num círculo do Kaelix.
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
                        { icone: "kaelix-ajustes-symbolic", nome: raiz.t("Ajustes do Kaelix", "Kaelix Settings"), acao: "abrir ajustes" },
                        { icone: "kaelix-cadeado-symbolic", nome: raiz.t("Bloquear", "Lock"), acao: "bloquear" },
                        { icone: "kaelix-desligar-symbolic", nome: raiz.t("Desligar", "Power"), acao: "sair" }
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
