// Barra e doca: o estilo da barra (fusão, Mac ou Windows), o tamanho, onde
// ficam a busca e o menu, se a barra se esconde sozinha, os apps fixados nela
// (tirar, mudar a ordem e pôr outros) e, com mais de uma
// tela, se a barra aparece em todas e onde ficam os apps abertos (como no Windows).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: pagina

    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    readonly property string estilo: ajustes.texto("barra") || "fusao"
    readonly property string tamanho: ajustes.texto("barra_tamanho") || "media"
    readonly property bool esconde: ajustes.sim("barra_esconder")
    readonly property string busca: ajustes.texto("barra_busca") || "esquerda"
    readonly property string menu: ajustes.texto("barra_menu") || "esquerda"
    readonly property bool todasAsTelas: ajustes.texto("barra_telas") !== "principal"
    readonly property string abertos: ajustes.texto("barra_abertos") || "tela"
    readonly property int telas: Qt.application.screens.length

    // "abrir ajustes barra-apps" (o menu, o botão direito no logo): rola até os
    // apps fixados, depois que a página terminou de montar.
    function mostrarApps() {
        var y = grupoApps.mapToItem(corpo, 0, 0).y - Kirigami.Units.gridUnit;
        rolagem.contentY = Math.max(0, Math.min(y, rolagem.contentHeight - rolagem.height));
        ajustes.secao = "";
    }
    Timer {
        id: esperaMontar
        interval: 250
        onTriggered: pagina.mostrarApps()
    }
    Connections {
        target: ajustes
        function onSecaoChanged() {
            if (ajustes.secao === "apps") {
                esperaMontar.restart();
            }
        }
    }
    Component.onCompleted: {
        if (ajustes.secao === "apps") {
            esperaMontar.restart();
        }
    }

    function trocar(estilo, tamanho, esconde, busca, menu, todas, abertos) {
        var b = busca !== undefined ? busca : pagina.busca;
        var m = menu !== undefined ? menu : pagina.menu;
        var t = (todas !== undefined ? todas : pagina.todasAsTelas) ? "todas" : "principal";
        var a = abertos !== undefined ? abertos : pagina.abertos;
        ajustes.definir("barra", estilo);
        ajustes.definir("barra_tamanho", tamanho);
        ajustes.definir("barra_esconder", esconde ? "1" : "0");
        ajustes.definir("barra_busca", b);
        ajustes.definir("barra_menu", m);
        ajustes.definir("barra_telas", t);
        ajustes.definir("barra_abertos", a);
        ajustes.fazer("barra " + estilo + " " + tamanho + " " + (esconde ? "sim" : "nao") + " " + b + " " + m + " " + t + " " + a);
    }

    Grupo {
        nota: ajustes.t("Os apps que você fixou na barra continuam lá quando troca o estilo.",
                        "The apps you pinned stay on the bar when you change the style.")

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Math.round(Kirigami.Units.gridUnit * 0.8)
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents.Label {
                text: ajustes.t("Estilo", "Style")
            }

            RowLayout {
                id: estilos
                Layout.fillWidth: true
                spacing: Kirigami.Units.gridUnit

                Repeater {
                    model: [
                        { id: "fusao", nome: ajustes.t("Fusão", "Fusion") },
                        { id: "mac", nome: "Mac" },
                        { id: "windows", nome: "Windows" }
                    ]
                    Miniatura {
                        id: opcao
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        largura: Math.min(Kirigami.Units.gridUnit * 9, (estilos.width - estilos.spacing * 2) / 3)
                        nome: modelData.nome
                        escolhida: pagina.estilo === modelData.id
                        onClicked: pagina.trocar(modelData.id, pagina.tamanho, pagina.esconde)
                        MiniTela {
                            escuro: ajustes.sim("escuro") || ajustes.texto("escuro") === ""
                            estilo: opcao.modelData.id
                            busca: pagina.busca
                            menu: pagina.menu
                        }
                    }
                }
            }
        }

        Linha {
            nome: ajustes.t("Tamanho", "Size")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                atual: pagina.tamanho
                opcoes: [
                    { valor: "pequena", nome: ajustes.t("Pequena", "Small") },
                    { valor: "media", nome: ajustes.t("Média", "Medium") },
                    { valor: "grande", nome: ajustes.t("Grande", "Large") }
                ]
                onEscolhido: valor => pagina.trocar(pagina.estilo, valor, pagina.esconde)
            }
        }

        // Onde fica a pílula "Buscar apps e arquivos". No meio ela se junta à
        // ilha dos apps. Na barra única do Windows ela fica sempre ao lado do menu.
        Linha {
            visible: pagina.estilo !== "mac"
            nome: ajustes.t("Busca", "Search")
            detalhe: pagina.estilo === "windows" ? ajustes.t("Na barra única, a busca fica ao lado do menu.", "On the single bar, search sits next to the menu.")
                                                 : ajustes.t("No meio, a busca se junta à ilha dos apps.", "In the middle, search joins the apps island.")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 17
                atual: pagina.estilo === "windows" && pagina.busca === "meio" ? "esquerda" : pagina.busca
                opcoes: pagina.estilo === "windows"
                    ? [
                        { valor: "esquerda", nome: ajustes.t("Ao lado do menu", "Next to the menu") },
                        { valor: "nao", nome: ajustes.t("Sem busca", "No search") }
                    ]
                    : [
                        { valor: "esquerda", nome: ajustes.t("Junto do menu", "With the menu") },
                        { valor: "meio", nome: ajustes.t("No meio", "In the middle") },
                        { valor: "nao", nome: ajustes.t("Sem busca", "No search") }
                    ]
                onEscolhido: valor => pagina.trocar(pagina.estilo, pagina.tamanho, pagina.esconde, valor, pagina.menu)
            }
        }

        // O botão do menu no meio, junto dos apps, como no Windows 11.
        Linha {
            visible: pagina.estilo === "fusao"
            nome: ajustes.t("Menu", "Menu")
            detalhe: ajustes.t("No meio, o logo fica junto dos apps, como no Windows 11.", "In the middle, the logo sits with the apps, like Windows 11.")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                atual: pagina.menu
                opcoes: [
                    { valor: "esquerda", nome: ajustes.t("À esquerda", "On the left") },
                    { valor: "meio", nome: ajustes.t("No meio", "In the middle") }
                ]
                onEscolhido: valor => pagina.trocar(pagina.estilo, pagina.tamanho, pagina.esconde, pagina.busca, valor)
            }
        }

        Linha {
            nome: ajustes.t("Esconder a barra sozinha", "Automatically hide the bar")
            detalhe: pagina.estilo === "mac" ? ajustes.t("A doca aparece quando o mouse encosta embaixo; a barra de cima fica.", "The dock shows up when the mouse touches the bottom; the top bar stays.")
                                              : ajustes.t("Ela aparece quando o mouse encosta embaixo da tela.", "It shows up when the mouse touches the bottom of the screen.")
            PlasmaComponents.Switch {
                checked: pagina.esconde
                onToggled: pagina.trocar(pagina.estilo, pagina.tamanho, checked)
                Accessible.name: ajustes.t("Esconder a barra sozinha", "Automatically hide the bar")
            }
        }
    }

    // Apps fixados na barra, como no Windows e no Mac: tirar, mudar a ordem e pôr
    // outros. São os mesmos na barra de todas as telas.
    Grupo {
        id: grupoApps

        property bool escolhendo: false
        property string filtro: ""

        titulo: ajustes.t("Apps na barra", "Apps on the bar")
        nota: ajustes.t("A ordem da lista é a ordem da barra. Também dá para fixar pelo botão direito num app do menu.",
                        "The list order is the bar order. You can also pin from the right-click menu on an app in the menu.")

        Component.onCompleted: ajustes.lerFixadosDaBarra()

        Repeater {
            model: ajustes.fixados
            AppFixado {
                required property var modelData
                required property int index
                primeira: index === 0
                ultima: index === ajustes.fixados.length - 1
                nome: modelData.nome
                icone: modelData.icone
                detalhe: modelData.app === "preferred://browser" ? ajustes.t("O navegador padrão", "The default browser")
                       : modelData.app === "preferred://filemanager" ? ajustes.t("O app de arquivos padrão", "The default file manager") : ""
                onSubir: ajustes.moverFixado(index, -1)
                onDescer: ajustes.moverFixado(index, 1)
                onTirar: ajustes.tirarFixado(modelData.app)
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.margins: Math.round(Kirigami.Units.gridUnit * 0.8)
            visible: ajustes.fixados.length === 0
            text: ajustes.t("Nenhum app fixado. Os apps abertos aparecem na barra mesmo assim.",
                            "No pinned apps. Open apps still show up on the bar.")
            wrapMode: Text.WordWrap
            opacity: 0.65
        }

        // Os botões de baixo: pôr outro app e voltar aos apps do começo.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.6)
            Layout.rightMargin: Math.round(Kirigami.Units.gridUnit * 0.6)
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Math.round(Kirigami.Units.gridUnit * 0.5)
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Button {
                icon.name: grupoApps.escolhendo ? "go-up-symbolic" : "list-add-symbolic"
                text: grupoApps.escolhendo ? ajustes.t("Fechar a lista de apps", "Close the app list") : ajustes.t("Adicionar app…", "Add app…")
                onClicked: {
                    grupoApps.escolhendo = !grupoApps.escolhendo;
                    if (grupoApps.escolhendo) {
                        busca.text = "";
                        ajustes.fazer("apps-instalados");
                        busca.forceActiveFocus();
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            PlasmaComponents.ToolButton {
                icon.name: "edit-undo-symbolic"
                text: ajustes.t("Voltar ao começo", "Reset")
                QQC2.ToolTip.text: ajustes.t("Volta aos apps que a barra tinha no começo", "Goes back to the apps the bar started with")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: ajustes.fixadosPadrao()
            }
        }

        // A escolha do app novo: a busca e a grade de apps que ainda não estão na barra.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.6)
            Layout.rightMargin: Math.round(Kirigami.Units.gridUnit * 0.6)
            Layout.bottomMargin: Math.round(Kirigami.Units.gridUnit * 0.6)
            visible: grupoApps.escolhendo
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.TextField {
                id: busca
                Layout.fillWidth: true
                placeholderText: ajustes.t("Buscar um app", "Search for an app")
                onTextChanged: grupoApps.filtro = ajustes.simples(text)
                Keys.onEscapePressed: grupoApps.escolhendo = false
                Keys.onReturnPressed: {
                    if (grade.count > 0) {
                        grupoApps.fixar(grade.model[0]);
                    }
                }
                Keys.onDownPressed: grade.forceActiveFocus()
                Accessible.name: ajustes.t("Buscar um app para fixar", "Search for an app to pin")
            }

            GridView {
                id: grade

                readonly property int colunas: Math.max(3, Math.floor(width / (Kirigami.Units.gridUnit * 5.6)))

                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 10.4)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cellWidth: Math.floor(width / colunas)
                cellHeight: Math.round(Kirigami.Units.gridUnit * 5.2)
                keyNavigationEnabled: true
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                model: {
                    var ja = {};
                    for (var i = 0; i < ajustes.fixados.length; i++) {
                        ja[ajustes.fixados[i].app] = true;
                        ja["applications:" + ajustes.fixados[i].desk] = true;
                    }
                    var lista = [];
                    for (var j = 0; j < ajustes.instalados.length; j++) {
                        var a = ajustes.instalados[j];
                        if (ja[a.app]) {
                            continue;
                        }
                        if (grupoApps.filtro.length > 0 && ajustes.simples(a.nome).indexOf(grupoApps.filtro) === -1
                                && a.app.toLowerCase().indexOf(grupoApps.filtro) === -1) {
                            continue;
                        }
                        lista.push(a);
                    }
                    return lista;
                }
                delegate: BlocoApp {
                    required property var modelData
                    width: grade.cellWidth
                    height: grade.cellHeight
                    nome: modelData.nome
                    icone: modelData.icone
                    onEscolhido: grupoApps.fixar(modelData)
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    visible: grade.count === 0
                    text: ajustes.instalados.length === 0 ? ajustes.t("Carregando os apps…", "Loading apps…")
                                                          : ajustes.t("Nenhum app encontrado.", "No apps found.")
                    opacity: 0.6
                }
            }
        }

        function fixar(app) {
            ajustes.fixarApp(app);
            busca.text = "";
            grupoApps.escolhendo = false;
        }
    }

    // Várias telas, como no Windows: a barra em todas as telas (só a principal
    // tem a bandeja, a central e a lixeira) e onde aparece cada app aberto.
    Grupo {
        titulo: ajustes.t("Várias telas", "Multiple screens")
        nota: pagina.telas > 1
              ? ajustes.t("Agora há " + pagina.telas + " telas ligadas. Ao ligar outro monitor, a barra aparece nele sozinha.",
                          "There are " + pagina.telas + " screens connected now. When you plug in another monitor, the bar shows up on it by itself.")
              : ajustes.t("Vale quando houver mais de uma tela. Ao ligar um monitor, a barra aparece nele sozinha.",
                          "Applies when there is more than one screen. When you plug in a monitor, the bar shows up on it by itself.")

        Linha {
            primeira: true
            nome: ajustes.t("Mostrar a barra em todas as telas", "Show the bar on all screens")
            detalhe: ajustes.t("A bandeja, a central e a lixeira ficam na tela principal.",
                               "The tray, control center and trash stay on the main screen.")
            PlasmaComponents.Switch {
                checked: pagina.todasAsTelas
                onToggled: pagina.trocar(pagina.estilo, pagina.tamanho, pagina.esconde, pagina.busca, pagina.menu, checked, pagina.abertos)
                Accessible.name: ajustes.t("Mostrar a barra em todas as telas", "Show the bar on all screens")
            }
        }

        Linha {
            visible: pagina.todasAsTelas
            nome: ajustes.t("Apps abertos aparecem", "Open apps show up")
            detalhe: pagina.abertos === "tela" ? ajustes.t("Cada app fica só na barra da tela onde a janela está.", "Each app stays only on the bar of the screen its window is on.")
                   : pagina.abertos === "todas" ? ajustes.t("Todo app aberto aparece em todas as barras.", "Every open app shows up on every bar.")
                   : ajustes.t("Na barra principal e na barra da tela onde a janela está.", "On the main bar and on the bar of the screen its window is on.")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 19
                atual: pagina.abertos
                opcoes: [
                    { valor: "tela", nome: ajustes.t("Na tela dele", "On its screen") },
                    { valor: "principal", nome: ajustes.t("Principal e dele", "Main and its") },
                    { valor: "todas", nome: ajustes.t("Em todas", "On all") }
                ]
                onEscolhido: valor => pagina.trocar(pagina.estilo, pagina.tamanho, pagina.esconde, pagina.busca, pagina.menu, pagina.todasAsTelas, valor)
            }
        }
    }
}
