// O miolo do Notas, o mesmo para as quatro páginas (Todas, Fixadas, Listas e
// Lixeira): o cabeçalho com o nome da página e os botões de nota nova; embaixo,
// a lista das notas com o editor ao lado, ou a grade de cartões com o editor
// por cima. Sem notas, o Vazio no meio.
//
// As notas da página ficam num ListModel que é acertado item a item (entra,
// sai, muda de lugar), para a lista animar cada mudança em vez de piscar.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "notas.js" as N

Item {
    id: pagina

    readonly property bool emGrade: janela.preferencias.visao === "grade"
    readonly property bool vazia: modelo.count === 0
    readonly property real larguraLista: Math.round(Math.max(janela.gu * 13.5, Math.min(janela.gu * 19, width * 0.36)))
    property bool sobreposta: false
    property bool animar: true
    property bool acertando: false
    property bool agrupar: false

    ListModel {
        id: modelo
    }

    // ----- o modelo da página -----
    function dadosDe(n, agrupar) {
        var lista = n.tipo === "lista";
        var conta = N.contarItens(n.itens);
        var amostra = [];
        if (lista) {
            var pend = n.itens.filter(function (i) { return !i.feito && i.texto.trim(); });
            var fe = n.itens.filter(function (i) { return i.feito && i.texto.trim(); });
            amostra = pend.concat(fe).slice(0, 6).map(function (i) { return { texto: i.texto, feito: i.feito }; });
        }
        return {
            nid: n.id,
            titulo: N.tituloVisivel(n, lista ? janela.t("Nova lista", "New list") : janela.t("Nova nota", "New note")),
            previa: N.previa(n, 140),
            corpo: lista ? "" : N.semMarcas(n.texto).replace(/\n{3,}/g, "\n\n").substring(0, 420),
            amostra: JSON.stringify(amostra),
            editada: n.editada,
            apagada: n.apagada,
            cor: n.cor,
            fixada: n.fixada,
            tipo: n.tipo,
            feitos: conta.feitos,
            total: conta.total,
            grupo: agrupar ? (n.fixada ? "fixadas" : "outras") : ""
        };
    }
    function sincronizar() {
        var lista = N.filtrar(janela.notas, janela.pagina, janela.busca);
        var temFixadas = false;
        if (janela.pagina === "todas")
            for (var f = 0; f < lista.length; f++)
                if (lista[f].fixada)
                    temFixadas = true;
        agrupar = temFixadas;
        var ids = {};
        for (var a = 0; a < lista.length; a++)
            ids[lista[a].id] = true;
        acertando = true;
        // Primeiro saem as que não estão mais (a lista anima a saída no lugar).
        for (var r = modelo.count - 1; r >= 0; r--)
            if (!ids[modelo.get(r).nid])
                modelo.remove(r);
        for (var i = 0; i < lista.length; i++) {
            var d = dadosDe(lista[i], temFixadas);
            if (i < modelo.count && modelo.get(i).nid === d.nid) {
                var atual = modelo.get(i);
                for (var k in d)
                    if (atual[k] !== d[k])
                        modelo.setProperty(i, k, d[k]);
                continue;
            }
            var j = -1;
            for (var b = i + 1; b < modelo.count; b++) {
                if (modelo.get(b).nid === d.nid) {
                    j = b;
                    break;
                }
            }
            if (j >= 0) {
                modelo.move(j, i, 1);
                modelo.set(i, d);
            } else {
                modelo.insert(i, d);
            }
        }
        // Nota levada para a Lixeira (ou apagada) com o editor por cima: ele fecha.
        if (sobreposta) {
            var aberta = janela.porId(janela.selecionada);
            if (!aberta || (aberta.apagada > 0) !== (janela.pagina === "lixeira"))
                sobreposta = false;
        }
        acertarAtual();
        acertando = false;
    }
    function agendar() {
        Qt.callLater(sincronizar);
    }
    function indiceDe(id) {
        for (var i = 0; i < modelo.count; i++)
            if (modelo.get(i).nid === id)
                return i;
        return -1;
    }
    // A lista mostra a escolhida (sem nunca trocar a escolha).
    function acompanhar() {
        var i = indiceDe(janela.selecionada);
        if (i >= 0 && listaNotas.currentIndex !== i) {
            acertando = true;
            listaNotas.currentIndex = i;
            acertando = false;
        }
    }
    // A nota escolhida precisa estar na página; se não estiver, fica a do lado.
    property int ultimoIndice: 0
    function acertarAtual() {
        var antes = acertando;
        acertando = true;
        var i = indiceDe(janela.selecionada);
        if (i < 0 && modelo.count > 0 && !(sobreposta && janela.porId(janela.selecionada))) {
            i = Math.min(ultimoIndice, modelo.count - 1);
            janela.selecionada = modelo.get(i).nid;
        } else if (modelo.count === 0 && !sobreposta) {
            janela.selecionada = "";
        }
        if (listaNotas.currentIndex !== i)
            listaNotas.currentIndex = i;
        if (i >= 0)
            ultimoIndice = i;
        acertando = antes;
    }

    Connections {
        target: janela
        function onRevisaoChanged() {
            pagina.agendar();
        }
        function onBuscaChanged() {
            pagina.agendar();
        }
        function onLinguaChanged() {
            pagina.agendar();
        }
        function onPaginaChanged() {
            pagina.fecharSobreposta();
            troca.restart();
        }
        function onSelecionadaChanged() {
            if (pagina.acertando)
                return;
            var i = pagina.indiceDe(janela.selecionada);
            if (i >= 0) {
                pagina.acertando = true;
                listaNotas.currentIndex = i;
                pagina.ultimoIndice = i;
                pagina.acertando = false;
            } else {
                // A nota é nova (a lista ainda vai recebê-la): acerta depois.
                pagina.agendar();
            }
        }
        function onFocarEditor(onde) {
            if (pagina.emGrade)
                pagina.sobreposta = true;
            Qt.callLater(function () {
                var e = pagina.emGrade ? editorFlutuante.item : editorLado.item;
                if (e)
                    e.focar(onde);
            });
        }
    }
    Component.onCompleted: sincronizar()

    // Trocar de página: o conteúdo some rápido e volta subindo (sem animar item por item).
    SequentialAnimation {
        id: troca
        NumberAnimation { target: conteudo; property: "opacity"; to: 0; duration: 90 }
        ScriptAction {
            script: {
                pagina.animar = false;
                pagina.ultimoIndice = 0;
                pagina.sincronizar();
                listaNotas.positionViewAtBeginning();
                grade.contentY = 0;
                pagina.animar = true;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: conteudo; property: "opacity"; to: 1; duration: 200 }
            NumberAnimation { target: deslize; property: "y"; from: Math.round(janela.gu * 0.6); to: 0; duration: 280; easing.type: Easing.OutCubic }
        }
    }

    function abrirNota(id) {
        janela.selecionada = id;
        if (emGrade)
            sobreposta = true;
    }
    function fecharSobreposta() {
        if (!sobreposta)
            return;
        if (editorFlutuante.item)
            editorFlutuante.item.gravarPendente();
        sobreposta = false;
        var n = janela.porId(janela.selecionada);
        if (n && n.apagada === 0 && janela.vazia(n)) {
            janela.notas.splice(janela.indice(n.id), 1);
            janela.tocar();
        }
    }

    // ----- o menu do botão direito numa nota -----
    property string alvoMenu: ""
    MenuMatsu {
        id: menuNota
        readonly property var nota: {
            janela.revisao;
            var n = janela.porId(pagina.alvoMenu);
            return n ? Object.assign({}, n) : null;
        }
        itens: !nota ? [] : (nota.apagada > 0 ? [
            { id: "restaurar", nome: janela.t("Restaurar", "Restore"), icone: Qt.resolvedUrl("icones/restaurar.svg") },
            { id: "apagar", nome: janela.t("Apagar para sempre", "Delete forever"), icone: "matsu-lixeira-symbolic", perigo: true, separador: true }
        ] : [
            { id: "fixar", nome: nota.fixada ? janela.t("Desafixar", "Unpin") : janela.t("Fixar no topo", "Pin to top"), icone: Qt.resolvedUrl(nota.fixada ? "icones/desafixar.svg" : "icones/fixar.svg") },
            { id: "converter", nome: nota.tipo === "lista" ? janela.t("Transformar em texto", "Turn into text") : janela.t("Transformar em lista", "Turn into checklist"), icone: Qt.resolvedUrl(nota.tipo === "lista" ? "icones/nota.svg" : "icones/lista.svg") },
            { id: "duplicar", nome: janela.t("Duplicar", "Duplicate"), icone: Qt.resolvedUrl("icones/duplicar.svg") },
            { id: "apagar", nome: janela.t("Mover para a Lixeira", "Move to Trash"), icone: "matsu-lixeira-symbolic", atalho: "Delete", perigo: true, separador: true }
        ])
        onEscolhido: (id) => {
            var alvo = pagina.alvoMenu;
            if (id === "restaurar")
                janela.restaurar(alvo);
            else if (id === "apagar")
                janela.apagar(alvo);
            else if (id === "fixar")
                janela.fixar(alvo);
            else if (id === "converter")
                janela.converter(alvo);
            else if (id === "duplicar")
                janela.duplicar(alvo);
        }
    }
    function abrirMenu(id, item, px, py) {
        alvoMenu = id;
        janela.selecionada = id;
        menuNota.abrirEm(item, px, py);
    }

    readonly property string nomePagina: ({ todas: janela.t("Todas as notas", "All notes"), fixadas: janela.t("Fixadas", "Pinned"),
                                            listas: janela.t("Listas", "Checklists"), lixeira: janela.t("Lixeira", "Trash") })[janela.pagina] || ""
    readonly property string resumo: {
        var n = modelo.count;
        if (janela.busca.trim())
            return n === 0 ? janela.t("Nada encontrado", "Nothing found") : (n === 1 ? janela.t("1 resultado", "1 result") : janela.t(n + " resultados", n + " results"));
        if (janela.pagina === "lixeira")
            return n === 0 ? janela.t("Vazia", "Empty") : (n === 1 ? janela.t("1 nota · some em 30 dias", "1 note · deleted after 30 days") : janela.t(n + " notas · somem em 30 dias", n + " notes · deleted after 30 days"));
        if (janela.pagina === "listas")
            return n === 1 ? janela.t("1 lista", "1 list") : janela.t(n + " listas", n + " lists");
        return n === 1 ? janela.t("1 nota", "1 note") : janela.t(n + " notas", n + " notes");
    }

    Item {
        id: conteudo
        anchors.fill: parent

        Item {
            id: deslize
            width: parent.width
            height: parent.height

            // ----- cabeçalho -----
            RowLayout {
                id: cabecalho
                x: Math.round(janela.gu * 1.1)
                y: Math.round(janela.gu * 0.75)
                width: (pagina.emGrade || pagina.vazia ? pagina.width : pagina.larguraLista) - Math.round(janela.gu * 1.1) - Math.round(janela.gu * 0.6)
                height: Math.round(janela.gu * 2.6)
                spacing: Math.round(janela.gu * 0.2)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Texto {
                        Layout.fillWidth: true
                        text: pagina.nomePagina
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.35
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: pagina.resumo
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.55
                        elide: Text.ElideRight
                    }
                }
                BotaoSimbolo {
                    visible: janela.pagina !== "lixeira"
                    icone: Qt.resolvedUrl("icones/nova-nota.svg")
                    dica: janela.t("Nova nota (Ctrl+N)", "New note (Ctrl+N)")
                    onClicado: janela.nova("texto")
                }
                BotaoSimbolo {
                    visible: janela.pagina !== "lixeira"
                    icone: Qt.resolvedUrl("icones/lista.svg")
                    dica: janela.t("Nova lista (Ctrl+Shift+N)", "New checklist (Ctrl+Shift+N)")
                    onClicado: janela.nova("lista")
                }
                Botao {
                    visible: janela.pagina === "lixeira"
                    ativo: janela.contagem.lixeira > 0
                    icone: "matsu-lixeira-symbolic"
                    texto: janela.t("Esvaziar", "Empty")
                    dica: janela.t("Apagar para sempre tudo o que está na Lixeira", "Delete everything in the Trash forever")
                    onClicado: janela.esvaziarLixeira()
                }
            }

            // ----- a lista das notas (exibição em lista) -----
            ListView {
                id: listaNotas
                visible: !pagina.emGrade && !pagina.vazia
                anchors.top: cabecalho.bottom
                anchors.topMargin: Math.round(janela.gu * 0.5)
                anchors.bottom: parent.bottom
                x: Math.round(janela.gu * 0.45)
                width: pagina.larguraLista - Math.round(janela.gu * 0.9)
                clip: true
                model: modelo
                currentIndex: -1
                activeFocusOnTab: true
                // A nota escolhida manda: a lista só acompanha (ela acerta o currentIndex
                // sozinha um instante depois de cada nota que entra ou sai).
                keyNavigationEnabled: false
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: false
                QQC2.ScrollBar.vertical: BarraRolagem {}
                onCurrentIndexChanged: {
                    if (!pagina.acertando)
                        Qt.callLater(pagina.acompanhar);
                }
                function andar(passo) {
                    var i = Math.max(0, Math.min(modelo.count - 1, pagina.indiceDe(janela.selecionada) + passo));
                    if (i >= 0 && i < modelo.count) {
                        janela.selecionada = modelo.get(i).nid;
                        positionViewAtIndex(i, ListView.Contain);
                    }
                }
                Keys.onUpPressed: andar(-1)
                Keys.onDownPressed: andar(1)
                Keys.onReturnPressed: janela.focarEditor("fim")

                highlight: Rectangle {
                    width: listaNotas.width
                    y: listaNotas.currentItem ? listaNotas.currentItem.y : 0
                    height: listaNotas.currentItem ? listaNotas.currentItem.height : 0
                    radius: Math.round(janela.gu * 0.45)
                    color: janela.tinta(janela.escuro ? 0.085 : 0.065)
                    border.width: 1
                    border.color: janela.tinta(listaNotas.activeFocus ? 0.2 : 0.09)
                    Behavior on y {
                        enabled: pagina.animar
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                section.property: "grupo"
                section.delegate: Item {
                    required property string section
                    width: listaNotas.width
                    height: section === "" ? 0 : Math.round(janela.gu * 1.9)
                    visible: section !== ""
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(janela.gu * 0.75)
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Math.round(janela.gu * 0.35)
                        spacing: Math.round(janela.gu * 0.35)
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(Kirigami.Units.iconSizes.small * 0.8)
                            height: width
                            source: Qt.resolvedUrl(parent.parent.section === "fixadas" ? "icones/fixar.svg" : "icones/nota.svg")
                            isMask: true
                            color: janela.frente
                            opacity: 0.5
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.section === "fixadas" ? janela.t("Fixadas", "Pinned") : janela.t("Notas", "Notes")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.weight: Font.DemiBold
                            opacity: 0.55
                        }
                    }
                }

                delegate: ItemNota {
                    id: itemNota
                    onEscolher: {
                        listaNotas.forceActiveFocus();
                        janela.selecionada = nid;
                    }
                    onPedirMenu: (px, py) => pagina.abrirMenu(nid, itemNota, px, py)
                }
                footer: Item {
                    width: 1
                    height: Math.round(janela.gu * 0.8)
                }

                add: Transition {
                    enabled: pagina.animar
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
                    NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 260; easing.type: Easing.OutCubic }
                }
                remove: Transition {
                    enabled: pagina.animar
                    NumberAnimation { property: "opacity"; to: 0; duration: 180 }
                    NumberAnimation { property: "x"; to: -Math.round(janela.gu * 1.5); duration: 200; easing.type: Easing.InCubic }
                }
                move: Transition {
                    enabled: pagina.animar
                    NumberAnimation { property: "y"; duration: 300; easing.type: Easing.OutCubic }
                }
                displaced: Transition {
                    enabled: pagina.animar
                    NumberAnimation { property: "y"; duration: 280; easing.type: Easing.OutCubic }
                    NumberAnimation { properties: "opacity,scale"; to: 1; duration: 120 }
                }
            }

            // A linha entre a lista e o editor.
            Rectangle {
                visible: !pagina.emGrade && !pagina.vazia
                x: pagina.larguraLista
                width: 1
                height: parent.height
                color: janela.tinta(janela.escuro ? 0.07 : 0.08)
            }

            Loader {
                id: editorLado
                active: !pagina.emGrade && !pagina.vazia
                x: pagina.larguraLista + 1
                width: pagina.width - x
                height: parent.height
                sourceComponent: Editor {
                    nid: janela.selecionada
                }
            }

            // ----- a grade de cartões -----
            Grade {
                id: grade
                visible: pagina.emGrade && !pagina.vazia
                anchors.top: cabecalho.bottom
                anchors.topMargin: Math.round(janela.gu * 0.5)
                anchors.bottom: parent.bottom
                width: parent.width
                modelo: modelo
                agrupar: pagina.agrupar
                onAbrir: (nid) => pagina.abrirNota(nid)
                onPedirMenu: (nid, item, px, py) => pagina.abrirMenu(nid, item, px, py)
            }

            // ----- sem notas -----
            Loader {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Math.round(janela.gu * 1.2)
                width: Math.min(pagina.width - janela.gu * 2, janela.gu * 24)
                height: item ? item.implicitHeight : 0
                active: pagina.vazia && janela.carregado
                sourceComponent: Vazio {
                    readonly property bool buscando: janela.busca.trim().length > 0
                    icone: buscando ? "matsu-busca-symbolic" : ({ todas: Qt.resolvedUrl("icones/nota.svg"), fixadas: Qt.resolvedUrl("icones/fixar.svg"),
                                                                  listas: Qt.resolvedUrl("icones/lista.svg"), lixeira: "matsu-lixeira-symbolic" })[janela.pagina]
                    titulo: buscando ? janela.t("Nada encontrado", "Nothing found")
                                     : ({ todas: janela.t("Nenhuma nota ainda", "No notes yet"), fixadas: janela.t("Nenhuma nota fixada", "No pinned notes"),
                                          listas: janela.t("Nenhuma lista", "No checklists"), lixeira: janela.t("A Lixeira está vazia", "Trash is empty") })[janela.pagina]
                    texto: buscando ? janela.t("Nenhuma nota tem “" + janela.busca.trim() + "”. Tente outra palavra.", "No note has “" + janela.busca.trim() + "”. Try another word.")
                                    : ({ todas: janela.t("Anote ideias, compras e lembretes. Tudo fica salvo sozinho enquanto você escreve.", "Jot down ideas, groceries and reminders. Everything saves itself as you type."),
                                         fixadas: janela.t("Fixe as notas importantes e elas ficam sempre no topo.", "Pin important notes and they stay at the top."),
                                         listas: janela.t("Listas de compras, de tarefas, de viagem: marque cada item quando terminar.", "Shopping, to-do or packing lists: tick each item when you're done."),
                                         lixeira: janela.t("As notas apagadas ficam aqui por 30 dias antes de sumir de vez.", "Deleted notes stay here for 30 days before they're gone for good.") })[janela.pagina]
                    botao: buscando || janela.pagina === "lixeira" ? "" : (janela.pagina === "listas" ? janela.t("Nova lista", "New checklist") : janela.t("Nova nota", "New note"))
                    onClicado: janela.nova(janela.pagina === "listas" ? "lista" : "texto")
                }
            }
        }
    }

    // ----- o editor por cima da grade -----
    Item {
        id: sobreposicao
        anchors.fill: parent
        z: 10
        visible: pagina.sobreposta || painel.opacity > 0

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, janela.escuro ? 0.42 : 0.18)
            opacity: pagina.sobreposta ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: pagina.fecharSobreposta()
            }
        }
        Rectangle {
            id: painel
            anchors.centerIn: parent
            width: Math.min(parent.width - Math.round(janela.gu * 2.4), Math.round(janela.gu * 40))
            height: parent.height - Math.round(janela.gu * 2.4)
            radius: Math.round(janela.gu * 0.8)
            color: janela.escuro ? Qt.rgba(0.15, 0.15, 0.16, 1) : Qt.rgba(0.985, 0.985, 0.99, 1)
            border.width: 1
            border.color: janela.escuro ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.12)
            opacity: pagina.sobreposta ? 1 : 0
            scale: pagina.sobreposta ? 1 : 0.94
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }
            MouseArea {
                anchors.fill: parent
            }
            Loader {
                id: editorFlutuante
                anchors.fill: parent
                active: pagina.sobreposta || painel.opacity > 0
                sourceComponent: Editor {
                    nid: janela.selecionada
                    flutuante: true
                    onFechar: pagina.fecharSobreposta()
                }
            }
        }
        Shortcut {
            sequences: [StandardKey.Cancel]
            enabled: pagina.sobreposta
            onActivated: pagina.fecharSobreposta()
        }
    }
}
