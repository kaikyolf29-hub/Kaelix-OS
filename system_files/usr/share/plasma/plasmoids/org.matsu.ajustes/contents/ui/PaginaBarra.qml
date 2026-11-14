// Barra e doca: o estilo da barra (fusão, Mac ou Windows), o tamanho (no Mac,
// uma régua livre, como no Mac), onde ficam a busca e o menu, quando a barra
// some sozinha (nunca, com um app maximizado ou sempre; no Mac, também a barra
// de cima), a doca (ampliar os ícones embaixo do mouse, quanto, o lado
// da tela no Mac, os pontinhos dos apps abertos e o pulo ao abrir), os apps
// fixados nela (tirar, mudar a ordem e pôr outros) e, com mais de uma tela, se
// a barra aparece em todas e onde ficam os apps abertos (como no Windows).
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
    // Quando a barra (no Mac, a doca) some sozinha: "nao", "maximizado" ou
    // "sempre" ("1" era o sempre de antes). A barra de cima do Mac: "tela-cheia",
    // "maximizado" ou "sempre".
    readonly property string esconde: {
        var v = ajustes.texto("barra_esconder");
        return v === "1" || v === "sim" || v === "sempre" ? "sempre" : (v === "maximizado" ? v : "nao");
    }
    readonly property string escondeTopo: {
        var v = ajustes.texto("barra_esconder_topo");
        return v === "maximizado" || v === "sempre" ? v : "tela-cheia";
    }
    // A borda onde o mouse traz a barra (ou a doca) de volta.
    readonly property string borda: pagina.estilo !== "mac" || pagina.posicao === "embaixo"
                                    ? ajustes.t("embaixo da tela", "the bottom of the screen")
                                    : (pagina.posicao === "esquerda" ? ajustes.t("na esquerda da tela", "the left of the screen")
                                                                      : ajustes.t("na direita da tela", "the right of the screen"))
    readonly property string busca: ajustes.texto("barra_busca") || "esquerda"
    readonly property string menu: ajustes.texto("barra_menu") || "esquerda"
    readonly property bool todasAsTelas: ajustes.texto("barra_telas") !== "principal"
    readonly property string abertos: ajustes.texto("barra_abertos") || "tela"
    readonly property int telas: Qt.application.screens.length
    readonly property bool amplia: ajustes.texto("barra_ampliacao") !== "0"
    readonly property int nivel: ajustes.texto("barra_ampliacao_nivel") === "" ? 50 : ajustes.numero("barra_ampliacao_nivel")
    readonly property bool indicadores: ajustes.texto("barra_indicadores") !== "0"
    readonly property bool animar: ajustes.texto("barra_animar") !== "0"
    readonly property string posicao: ajustes.texto("barra_posicao") || "embaixo"

    // O tamanho guardado pode ser um dos três (pequena, média, grande) ou um
    // número da régua da doca do Mac (de 1,8 a 4,2 vezes a letra do sistema).
    readonly property var escalas: ({ pequena: 2.25, media: 2.75, grande: 3.25 })
    function escalaDe(t) {
        if (escalas[t] !== undefined) {
            return escalas[t];
        }
        var n = parseFloat(String(t).replace(",", "."));
        return isNaN(n) ? 2.75 : Math.max(1.8, Math.min(4.2, n));
    }
    // Fora do Mac só há os três tamanhos: o número vira o mais perto.
    function tamanhoDe(t) {
        if (escalas[t] !== undefined) {
            return t;
        }
        var n = escalaDe(t);
        return n < 2.5 ? "pequena" : (n < 3 ? "media" : "grande");
    }

    // As opções da doca valem na hora, sem montar a barra de novo.
    function doca(chave, opcao, valor) {
        ajustes.definir(chave, typeof valor === "boolean" ? (valor ? "1" : "0") : String(valor));
        ajustes.fazer("doca " + opcao + " " + (typeof valor === "boolean" ? (valor ? "sim" : "nao") : valor));
    }

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
        if (estilo !== "mac") {
            tamanho = pagina.tamanhoDe(tamanho);
        }
        ajustes.definir("barra", estilo);
        ajustes.definir("barra_tamanho", tamanho);
        ajustes.definir("barra_esconder", esconde);
        ajustes.definir("barra_busca", b);
        ajustes.definir("barra_menu", m);
        ajustes.definir("barra_telas", t);
        ajustes.definir("barra_abertos", a);
        ajustes.fazer("barra " + estilo + " " + tamanho + " " + esconde + " " + b + " " + m + " " + t + " " + a);
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

        // No Mac, uma régua livre para a doca; nos outros estilos, três tamanhos.
        Linha {
            nome: ajustes.t("Tamanho", "Size")
            detalhe: pagina.estilo === "mac" ? ajustes.t("Arraste para deixar a doca do tamanho que quiser.", "Drag to make the dock the size you like.") : ""

            Regua {
                visible: pagina.estilo === "mac"
                de: 1.8
                ate: 4.2
                passo: 0.05
                valor: pagina.escalaDe(pagina.tamanho)
                esquerda: ajustes.t("Pequena", "Small")
                direita: ajustes.t("Grande", "Large")
                nome: ajustes.t("Tamanho da doca", "Dock size")
                onEscolhido: valor => pagina.trocar(pagina.estilo, valor.toFixed(2), pagina.esconde)
            }

            Segmentado {
                visible: pagina.estilo !== "mac"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                atual: pagina.tamanhoDe(pagina.tamanho)
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

        // Quando a barra some: nunca, quando um app maximizado encosta nela
        // (o que o Windows e o Mac fazem com apps em tela cheia, aqui também
        // com os maximizados) ou sempre (o "ocultar automaticamente" dos dois).
        // Ela volta quando o mouse encosta na borda. Vale na hora.
        Linha {
            nome: pagina.estilo === "mac" ? ajustes.t("Esconder a doca", "Hide the dock")
                                          : ajustes.t("Esconder a barra", "Hide the bar")
            detalhe: pagina.esconde === "maximizado"
                     ? ajustes.t("Some quando um app maximizado encosta nela e volta com o mouse ", "Hides when a maximized app touches it and comes back with the mouse at ") + pagina.borda + "."
                     : pagina.esconde === "sempre"
                       ? ajustes.t("Fica escondida e aparece quando o mouse encosta ", "Stays hidden and shows up when the mouse touches ") + pagina.borda + "."
                       : ajustes.t("Fica sempre na tela; só um app em tela cheia cobre.", "Always stays on screen; only a full-screen app covers it.")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 15
                atual: pagina.esconde
                opcoes: [
                    { valor: "nao", nome: ajustes.t("Nunca", "Never") },
                    { valor: "maximizado", nome: ajustes.t("Maximizado", "Maximized") },
                    { valor: "sempre", nome: ajustes.t("Sempre", "Always") }
                ]
                onEscolhido: valor => pagina.doca("barra_esconder", "esconder", valor)
            }
        }

        // A barra de cima do Mac: como no Mac, some só com um app em tela cheia;
        // também pode sumir com um app maximizado ou sempre.
        Linha {
            visible: pagina.estilo === "mac"
            nome: ajustes.t("Esconder a barra de cima", "Hide the top bar")
            detalhe: pagina.escondeTopo === "maximizado"
                     ? ajustes.t("Some quando um app maximizado encosta nela e volta com o mouse no alto da tela.", "Hides when a maximized app touches it and comes back with the mouse at the top of the screen.")
                     : pagina.escondeTopo === "sempre"
                       ? ajustes.t("Fica escondida e aparece quando o mouse encosta no alto da tela.", "Stays hidden and shows up when the mouse touches the top of the screen.")
                       : ajustes.t("Some só com um app em tela cheia, como no Mac.", "Hides only behind a full-screen app, like on a Mac.")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 15
                atual: pagina.escondeTopo
                opcoes: [
                    { valor: "tela-cheia", nome: ajustes.t("Tela cheia", "Full screen") },
                    { valor: "maximizado", nome: ajustes.t("Maximizado", "Maximized") },
                    { valor: "sempre", nome: ajustes.t("Sempre", "Always") }
                ]
                onEscolhido: valor => pagina.doca("barra_esconder_topo", "esconder-topo", valor)
            }
        }
    }

    // A doca dos apps (fusão e Mac): a ampliação embaixo do mouse, como no Mac,
    // o lado da tela (só no Mac), os pontinhos dos apps abertos e o pulo do
    // ícone enquanto o app abre. Vale na hora, em todas as telas.
    Grupo {
        visible: pagina.estilo !== "windows"
        titulo: ajustes.t("Doca", "Dock")
        nota: ajustes.t("Vale na hora, na barra de todas as telas.", "Applies right away, on the bar of every screen.")

        Linha {
            primeira: true
            nome: ajustes.t("Ampliar os apps ao passar o mouse", "Magnify apps on hover")
            detalhe: ajustes.t("Os ícones crescem embaixo do mouse, como no Mac.", "Icons grow under the mouse, like on a Mac.")
            PlasmaComponents.Switch {
                checked: pagina.amplia
                onToggled: pagina.doca("barra_ampliacao", "ampliacao", checked)
                Accessible.name: ajustes.t("Ampliar os apps ao passar o mouse", "Magnify apps on hover")
            }
        }

        Linha {
            visible: pagina.amplia
            nome: ajustes.t("Ampliação", "Magnification")

            Regua {
                de: 0
                ate: 100
                passo: 5
                valor: pagina.nivel
                esquerda: ajustes.t("Pouca", "Less")
                direita: ajustes.t("Muita", "More")
                nome: ajustes.t("Ampliação", "Magnification")
                onEscolhido: valor => pagina.doca("barra_ampliacao_nivel", "ampliacao-nivel", Math.round(valor))
            }
        }

        Linha {
            visible: pagina.estilo === "mac"
            nome: ajustes.t("Posição na tela", "Position on screen")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 15
                atual: pagina.posicao
                opcoes: [
                    { valor: "esquerda", nome: ajustes.t("Esquerda", "Left") },
                    { valor: "embaixo", nome: ajustes.t("Embaixo", "Bottom") },
                    { valor: "direita", nome: ajustes.t("Direita", "Right") }
                ]
                onEscolhido: valor => pagina.doca("barra_posicao", "posicao", valor)
            }
        }

        Linha {
            nome: ajustes.t("Mostrar um ponto nos apps abertos", "Show a dot under open apps")
            PlasmaComponents.Switch {
                checked: pagina.indicadores
                onToggled: pagina.doca("barra_indicadores", "indicadores", checked)
                Accessible.name: ajustes.t("Mostrar um ponto nos apps abertos", "Show a dot under open apps")
            }
        }

        Linha {
            nome: ajustes.t("Animar ao abrir os apps", "Animate apps while opening")
            detalhe: ajustes.t("O ícone pula de leve enquanto o app abre.", "The icon bounces gently while the app opens.")
            PlasmaComponents.Switch {
                checked: pagina.animar
                onToggled: pagina.doca("barra_animar", "animar", checked)
                Accessible.name: ajustes.t("Animar ao abrir os apps", "Animate apps while opening")
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

        // A barra cheia: um aviso gentil no lugar de deixar fixar mais (a barra
        // passaria da borda). O número vem da barra: depende do tamanho dela e
        // da largura da tela.
        Rectangle {
            id: avisoCheia
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.6)
            Layout.rightMargin: Math.round(Kirigami.Units.gridUnit * 0.6)
            Layout.topMargin: ajustes.barraCheia ? Kirigami.Units.smallSpacing : 0
            Layout.preferredHeight: ajustes.barraCheia ? linhaCheia.implicitHeight + Kirigami.Units.largeSpacing * 2 : 0
            visible: Layout.preferredHeight > 0
            opacity: ajustes.barraCheia ? 1 : 0
            clip: true
            radius: Math.round(Kirigami.Units.gridUnit * 0.45)
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.longDuration }
            }

            RowLayout {
                id: linhaCheia
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    source: "matsu-info-symbolic"
                    isMask: true
                    color: Kirigami.Theme.textColor
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: ajustes.estiloDoLimite === "mac"
                          ? ajustes.t("A doca cabe até " + ajustes.limiteFixados + " apps. Para pôr outro, tire um da lista.",
                                      "The dock fits up to " + ajustes.limiteFixados + " apps. To add another, remove one from the list.")
                          : ajustes.t("A barra cabe até " + ajustes.limiteFixados + " apps. No estilo Mac a doca cabe mais.",
                                      "The bar fits up to " + ajustes.limiteFixados + " apps. The Mac style dock fits more.")
                    wrapMode: Text.WordWrap
                }
            }
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
                enabled: grupoApps.escolhendo || !ajustes.barraCheia
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

        // Ao chegar no limite, a lista de apps fecha (o aviso aparece no lugar).
        function fixar(app) {
            if (ajustes.barraCheia) {
                grupoApps.escolhendo = false;
                return;
            }
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
