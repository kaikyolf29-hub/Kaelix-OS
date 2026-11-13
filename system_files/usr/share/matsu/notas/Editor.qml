// O editor de uma nota: a barra (quando foi editada, o "Salvo", negrito e
// itálico, fixar, cor, lixeira e mais), o título grande e o corpo (texto com
// negrito e itálico, ou a lista de tarefas) e a contagem discreta embaixo.
// Na Lixeira tudo fica só para ler, com Restaurar e Apagar para sempre.
//
// O corpo é um TextEdit em RichText. O que ele mostra vem de N.marcasParaHtml
// e o que a pessoa escreve volta para a nota por N.htmlParaMarcas (um instante
// depois de digitar). Colar entra sempre como texto puro.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "notas.js" as N

Item {
    id: editor

    property string nid: ""
    property bool flutuante: false

    signal fechar()

    // Uma cópia nova a cada mudança: assim tudo o que depende da nota se atualiza.
    readonly property var nota: {
        janela.revisao;
        var n = janela.porId(nid);
        return n ? Object.assign({}, n) : null;
    }
    readonly property bool naLixeira: nota !== null && nota.apagada > 0
    readonly property bool ehLista: nota !== null && nota.tipo === "lista"
    property string carregada: ""
    property bool carregando: false
    property int palavras: 0
    property var jeito: ({ negrito: false, italico: false })
    // Negrito/itálico pedido sem nada escolhido: vale para o que for digitado em seguida.
    property var pendente: null

    // ----- ler e escrever a nota -----
    function gravarPendente() {
        if (converte.running) {
            converte.stop();
            escreverCorpo();
        }
    }
    function escreverCorpo() {
        if (carregada === "" || carregando)
            return;
        var n = janela.porId(carregada);
        if (!n || n.tipo !== "texto" || n.apagada > 0)
            return;
        janela.mudar(carregada, { texto: N.htmlParaMarcas(corpo.text) });
    }
    function carregar() {
        gravarPendente();
        carregando = true;
        var n = janela.porId(nid);
        carregada = n ? n.id : "";
        titulo.text = n ? n.titulo : "";
        corpo.text = N.marcasParaHtml(n && n.tipo === "texto" ? n.texto : "", 0);
        tarefas.carregar(n);
        carregando = false;
        contar();
        rolagem.contentY = 0;
        surgir.restart();
    }
    onNidChanged: carregar()
    Connections {
        target: janela
        function onRecargaChanged() {
            editor.carregar();
        }
    }
    Component.onCompleted: carregar()
    Component.onDestruction: gravarPendente()

    function contar() {
        palavras = N.contarPalavras(corpo.getText(0, corpo.length));
    }
    Timer {
        id: converte
        interval: 250
        onTriggered: {
            editor.escreverCorpo();
            editor.contar();
        }
    }

    // Foco pedido de fora: "titulo" (nota nova), "corpo" ou "fim".
    function focar(onde) {
        if (naLixeira)
            return;
        if (onde === "titulo") {
            titulo.forceActiveFocus();
            titulo.cursorPosition = titulo.length;
        } else if (ehLista) {
            tarefas.focarPrimeiro();
        } else {
            corpo.forceActiveFocus();
            corpo.cursorPosition = onde === "corpo" ? 0 : corpo.length;
        }
    }

    // Deixa o cursor à vista enquanto se escreve.
    function mostrar(item, r) {
        if (!item.activeFocus)
            return;
        var p = item.mapToItem(coluna, r.x, r.y);
        var y = p.y + coluna.y;
        var margem = janela.gu * 1.5;
        if (y < rolagem.contentY + margem)
            rolagem.contentY = Math.max(0, y - margem);
        else if (y + r.height > rolagem.contentY + rolagem.height - margem)
            rolagem.contentY = Math.max(0, Math.min(rolagem.contentHeight - rolagem.height, y + r.height - rolagem.height + margem));
    }

    // ----- negrito e itálico -----
    function lerJeito() {
        if (pendente) {
            jeito = pendente;
            return;
        }
        var a = corpo.selectionStart, b = corpo.selectionEnd;
        if (a === b) {
            if (a === 0) {
                jeito = { negrito: false, italico: false };
                return;
            }
            a = a - 1;
        }
        jeito = N.jeitoDoTrecho(corpo.getFormattedText(a, b));
    }
    function formatar(qual) {
        if (naLixeira || ehLista)
            return;
        var a = corpo.selectionStart, b = corpo.selectionEnd, cursor = corpo.cursorPosition;
        var semEscolha = a === b;
        if (semEscolha) {
            // Com o cursor no meio de uma palavra, vale para ela; na ponta ou num
            // espaço, vale para o que for digitado em seguida (como no Word).
            var tudo = corpo.getText(0, corpo.length);
            var letra = /[0-9A-Za-zÀ-ÖØ-öø-ÿĀ-ɏ'’-]/;
            if (a === 0 || a >= tudo.length || !letra.test(tudo[a - 1]) || !letra.test(tudo[a])) {
                var base = pendente ? pendente : jeito;
                var novo = { negrito: base.negrito, italico: base.italico };
                novo[qual] = !novo[qual];
                pendente = novo;
                jeito = novo;
                return;
            }
            var ini = a, fim = a;
            while (ini > 0 && letra.test(tudo[ini - 1]))
                ini--;
            while (fim < tudo.length && letra.test(tudo[fim]))
                fim++;
            a = ini;
            b = fim;
        }
        // Cada parágrafo do trecho é trocado por inteiro (sem mexer nas quebras).
        var texto = corpo.getText(a, b);
        var pedacos = [];
        var comeco = a;
        for (var i = 0; i <= texto.length; i++) {
            if (i === texto.length || texto[i] === " " || texto[i] === " ") {
                if (a + i > comeco)
                    pedacos.push([comeco, a + i]);
                comeco = a + i + 1;
            }
        }
        if (pedacos.length === 0)
            return;
        var ligar = !N.jeitoDoTrecho(corpo.getFormattedText(a, b))[qual];
        for (var k = pedacos.length - 1; k >= 0; k--) {
            var r = N.alternarJeito(corpo.getFormattedText(pedacos[k][0], pedacos[k][1]), qual, ligar);
            corpo.remove(pedacos[k][0], pedacos[k][1]);
            corpo.insert(pedacos[k][0], r.html);
        }
        if (semEscolha)
            corpo.cursorPosition = cursor;
        else
            corpo.select(a, b);
        lerJeito();
    }
    // Colar entra como texto puro (nada de fonte e cor de fora).
    function colar() {
        if (naLixeira)
            return;
        ajudante.text = "";
        ajudante.paste();
        var t = ajudante.text;
        if (!t)
            return;
        var a = corpo.selectionStart;
        if (corpo.selectionEnd > a)
            corpo.remove(a, corpo.selectionEnd);
        corpo.insert(a, N.coladoParaHtml(t));
    }
    function copiarTudo() {
        var n = nota;
        if (!n)
            return;
        var linhas = [];
        if (n.titulo.trim())
            linhas.push(n.titulo.trim());
        if (n.tipo === "lista") {
            for (var i = 0; i < n.itens.length; i++)
                if (n.itens[i].texto.trim())
                    linhas.push((n.itens[i].feito ? "☑ " : "☐ ") + n.itens[i].texto.trim());
        } else {
            linhas.push(N.semMarcas(n.texto));
        }
        ajudante.text = linhas.join("\n");
        ajudante.selectAll();
        ajudante.copy();
        janela.avisoRapido(janela.t("Texto copiado", "Text copied"), "certo");
    }
    // Para colar como texto puro e copiar a nota inteira.
    TextEdit {
        id: ajudante
        visible: false
        textFormat: TextEdit.PlainText
    }

    // ----- o fundo leve da cor da nota -----
    Rectangle {
        anchors.fill: parent
        radius: editor.flutuante ? Math.round(janela.gu * 0.8) : 0
        color: editor.nota ? janela.fundoCor(editor.nota.cor) : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.longDuration
            }
        }
    }

    // ----- a barra -----
    RowLayout {
        id: barra
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Math.round(janela.gu * 0.5)
        anchors.leftMargin: Math.round(janela.gu * 1.1)
        anchors.rightMargin: Math.round(janela.gu * 0.6)
        height: Math.round(janela.gu * 2.2)
        spacing: Math.round(janela.gu * 0.2)
        visible: editor.nota !== null

        Texto {
            Layout.preferredWidth: implicitWidth
            Layout.minimumWidth: Math.round(janela.gu * 3)
            text: !editor.nota ? "" : (editor.naLixeira
                  ? janela.t("Na Lixeira · some em " + N.diasRestantes(editor.nota.apagada, janela.agora) + " dias", "In Trash · deleted in " + N.diasRestantes(editor.nota.apagada, janela.agora) + " days")
                  : N.dataCompleta(editor.nota.editada, janela.lingua))
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            elide: Text.ElideRight
            opacity: 0.55
        }
        SeloSalvo {
            Layout.leftMargin: Math.round(janela.gu * 0.4)
            visible: !editor.naLixeira && opacity > 0
        }
        Item {
            Layout.fillWidth: true
        }

        // Formatação (só no texto).
        BotaoSimbolo {
            visible: !editor.naLixeira && !editor.ehLista
            icone: Qt.resolvedUrl("icones/negrito.svg")
            dica: janela.t("Negrito (Ctrl+B)", "Bold (Ctrl+B)")
            ligado: editor.jeito.negrito
            onClicado: editor.formatar("negrito")
        }
        BotaoSimbolo {
            visible: !editor.naLixeira && !editor.ehLista
            icone: Qt.resolvedUrl("icones/italico.svg")
            dica: janela.t("Itálico (Ctrl+I)", "Italic (Ctrl+I)")
            ligado: editor.jeito.italico
            onClicado: editor.formatar("italico")
        }
        Rectangle {
            visible: !editor.naLixeira && !editor.ehLista
            Layout.leftMargin: Math.round(janela.gu * 0.25)
            Layout.rightMargin: Math.round(janela.gu * 0.25)
            implicitWidth: 1
            implicitHeight: Math.round(janela.gu * 1.1)
            color: janela.tinta(0.14)
        }
        BotaoSimbolo {
            visible: !editor.naLixeira
            icone: editor.nota && editor.nota.fixada ? Qt.resolvedUrl("icones/fixada.svg") : Qt.resolvedUrl("icones/fixar.svg")
            dica: editor.nota && editor.nota.fixada ? janela.t("Desafixar", "Unpin") : janela.t("Fixar no topo", "Pin to top")
            ligado: editor.nota !== null && editor.nota.fixada
            onClicado: janela.fixar(editor.nid)
        }
        BotaoSimbolo {
            id: botaoCor
            visible: !editor.naLixeira
            icone: Qt.resolvedUrl("icones/cor.svg")
            dica: janela.t("Cor da nota", "Note color")
            pingo: editor.nota && editor.nota.cor ? janela.tom(editor.nota.cor) : "transparent"
            ligado: paleta.opened
            onClicado: paleta.abrirEm(botaoCor)
        }
        BotaoSimbolo {
            visible: !editor.naLixeira
            icone: "matsu-lixeira-symbolic"
            dica: janela.t("Mover para a Lixeira (Delete)", "Move to Trash (Delete)")
            onClicado: janela.apagar(editor.nid)
        }
        BotaoSimbolo {
            id: botaoMais
            visible: !editor.naLixeira
            icone: Qt.resolvedUrl("icones/reticencias.svg")
            dica: janela.t("Mais", "More")
            ligado: menuMais.opened
            onClicado: menuMais.abrirEm(botaoMais, botaoMais.width - menuMais.width, botaoMais.height + 4)
        }
        // Na Lixeira: restaurar ou apagar de vez.
        Botao {
            visible: editor.naLixeira
            icone: "matsu-lixeira-symbolic"
            texto: janela.t("Apagar para sempre", "Delete forever")
            onClicado: janela.apagarParaSempre(editor.nid)
        }
        BotaoDestaque {
            visible: editor.naLixeira
            Layout.leftMargin: Math.round(janela.gu * 0.3)
            icone: Qt.resolvedUrl("icones/restaurar.svg")
            texto: janela.t("Restaurar", "Restore")
            onClicado: janela.restaurar(editor.nid)
        }
        BotaoSimbolo {
            visible: editor.flutuante
            Layout.leftMargin: Math.round(janela.gu * 0.2)
            icone: "matsu-fechar-symbolic"
            dica: janela.t("Fechar (Esc)", "Close (Esc)")
            onClicado: editor.fechar()
        }
    }

    PaletaCores {
        id: paleta
        cor: editor.nota ? editor.nota.cor : ""
        onEscolher: (id) => janela.pintar(editor.nid, id)
    }
    MenuMatsu {
        id: menuMais
        itens: [
            editor.ehLista ? { id: "converter", nome: janela.t("Transformar em texto", "Turn into text"), icone: Qt.resolvedUrl("icones/nota.svg") }
                           : { id: "converter", nome: janela.t("Transformar em lista", "Turn into checklist"), icone: Qt.resolvedUrl("icones/lista.svg") },
            { id: "duplicar", nome: janela.t("Duplicar", "Duplicate"), icone: Qt.resolvedUrl("icones/duplicar.svg") },
            { id: "copiar", nome: janela.t("Copiar o texto", "Copy text"), icone: "matsu-link-symbolic" },
            { id: "apagar", nome: janela.t("Mover para a Lixeira", "Move to Trash"), icone: "matsu-lixeira-symbolic", atalho: "Delete", perigo: true, separador: true }
        ]
        onEscolhido: (id) => {
            if (id === "converter")
                janela.converter(editor.nid);
            else if (id === "duplicar")
                janela.duplicar(editor.nid);
            else if (id === "copiar")
                editor.copiarTudo();
            else if (id === "apagar")
                janela.apagar(editor.nid);
        }
    }
    MenuMatsu {
        id: menuTexto
        itens: [
            { id: "recortar", nome: janela.t("Recortar", "Cut"), atalho: "Ctrl+X", ativo: corpo.selectedText.length > 0 && !editor.naLixeira },
            { id: "copiar", nome: janela.t("Copiar", "Copy"), atalho: "Ctrl+C", ativo: corpo.selectedText.length > 0 },
            { id: "colar", nome: janela.t("Colar", "Paste"), atalho: "Ctrl+V", ativo: corpo.canPaste && !editor.naLixeira },
            { id: "negrito", nome: janela.t("Negrito", "Bold"), icone: Qt.resolvedUrl("icones/negrito.svg"), atalho: "Ctrl+B", separador: true, ativo: !editor.naLixeira },
            { id: "italico", nome: janela.t("Itálico", "Italic"), icone: Qt.resolvedUrl("icones/italico.svg"), atalho: "Ctrl+I", ativo: !editor.naLixeira },
            { id: "tudo", nome: janela.t("Selecionar tudo", "Select all"), atalho: "Ctrl+A", separador: true }
        ]
        onEscolhido: (id) => {
            if (id === "recortar")
                corpo.cut();
            else if (id === "copiar")
                corpo.copy();
            else if (id === "colar")
                editor.colar();
            else if (id === "negrito" || id === "italico")
                editor.formatar(id);
            else if (id === "tudo")
                corpo.selectAll();
        }
    }

    // ----- o título e o corpo -----
    Flickable {
        id: rolagem
        anchors.top: barra.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: rodape.top
        anchors.topMargin: Math.round(janela.gu * 0.2)
        clip: true
        visible: editor.nota !== null
        contentWidth: width
        contentHeight: coluna.height + Math.round(janela.gu * 2)
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: BarraRolagem {}

        ColumnLayout {
            id: coluna
            readonly property real largura: Math.min(rolagem.width - Math.round(janela.gu * (editor.flutuante ? 3 : 3.4)), Math.round(janela.gu * 44))
            x: Math.round((rolagem.width - largura) / 2)
            y: Math.round(janela.gu * 0.6)
            width: largura
            spacing: Math.round(janela.gu * 0.55)

            TextEdit {
                id: titulo
                Layout.fillWidth: true
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                color: janela.frente
                selectionColor: janela.escuro ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.16)
                selectedTextColor: janela.frente
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.75
                font.weight: Font.Bold
                font.letterSpacing: -0.3
                readOnly: editor.naLixeira
                selectByMouse: true
                Accessible.name: janela.t("Título", "Title")
                onTextChanged: {
                    if (editor.carregando)
                        return;
                    if (text.indexOf("\n") >= 0) {
                        var p = cursorPosition;
                        text = text.replace(/\n+/g, " ");
                        cursorPosition = Math.min(p, length);
                        return;
                    }
                    janela.mudar(editor.carregada, { titulo: text });
                }
                onCursorRectangleChanged: editor.mostrar(titulo, cursorRectangle)
                Keys.onPressed: (e) => {
                    var fimDaLinha = cursorRectangle.y + cursorRectangle.height > contentHeight - 4;
                    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Tab || (e.key === Qt.Key_Down && fimDaLinha)) {
                        e.accepted = true;
                        editor.focar("corpo");
                    }
                }
                Texto {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    visible: titulo.length === 0
                    text: editor.ehLista ? janela.t("Título da lista", "List title") : janela.t("Título", "Title")
                    font: titulo.font
                    opacity: 0.3
                }
            }

            TextEdit {
                id: corpo
                visible: !editor.ehLista
                Layout.fillWidth: true
                // Ocupa o resto da altura: clicar embaixo do texto já escreve.
                Layout.minimumHeight: Math.max(Math.round(janela.gu * 4), rolagem.height - titulo.height - Math.round(janela.gu * 2.6))
                textFormat: TextEdit.RichText
                wrapMode: TextEdit.Wrap
                color: janela.frente
                selectionColor: janela.escuro ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.16)
                selectedTextColor: janela.frente
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.12
                readOnly: editor.naLixeira
                selectByMouse: true
                persistentSelection: menuTexto.opened
                Accessible.name: janela.t("Texto da nota", "Note text")
                onTextChanged: if (!editor.carregando) converte.restart()
                onCursorRectangleChanged: editor.mostrar(corpo, cursorRectangle)
                onCursorPositionChanged: {
                    editor.pendente = null;
                    Qt.callLater(editor.lerJeito);
                }
                onSelectionEndChanged: Qt.callLater(editor.lerJeito)
                Keys.onPressed: (e) => {
                    // Primeira letra depois de ligar/desligar o negrito sem escolha:
                    // entra com o jeito pedido, e as próximas herdam dela.
                    if (editor.pendente && e.text.length > 0 && e.text.charCodeAt(0) >= 32 && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                        e.accepted = true;
                        var j = editor.pendente;
                        editor.pendente = null;
                        var a = selectionStart;
                        if (selectionEnd > a)
                            remove(a, selectionEnd);
                        insert(a, '<span style="white-space:pre-wrap; font-weight:' + (j.negrito ? 700 : 400) + "; font-style:" + (j.italico ? "italic" : "normal") + ';">' + N.html(e.text) + "</span>");
                        return;
                    }
                    if (e.matches(StandardKey.Paste)) {
                        e.accepted = true;
                        editor.colar();
                    } else if (e.matches(StandardKey.Bold)) {
                        e.accepted = true;
                        editor.formatar("negrito");
                    } else if (e.matches(StandardKey.Italic)) {
                        e.accepted = true;
                        editor.formatar("italico");
                    } else if ((e.key === Qt.Key_Up && cursorRectangle.y < 4) || (e.key === Qt.Key_Backspace && cursorPosition === 0 && selectedText.length === 0)) {
                        e.accepted = true;
                        titulo.forceActiveFocus();
                        titulo.cursorPosition = titulo.length;
                    }
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: (ponto) => menuTexto.abrirEm(corpo, ponto.position.x, ponto.position.y)
                }
                Texto {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    visible: corpo.length === 0 && !editor.naLixeira
                    text: janela.t("Comece a escrever…", "Start writing…")
                    font: corpo.font
                    opacity: 0.32
                }
            }

            ListaTarefas {
                id: tarefas
                visible: editor.ehLista
                Layout.fillWidth: true
                Layout.leftMargin: 0
                nid: editor.carregada
                somenteLer: editor.naLixeira
                onVoltarAoTitulo: {
                    titulo.forceActiveFocus();
                    titulo.cursorPosition = titulo.length;
                }
            }
        }
    }

    // Ao trocar de nota, o conteúdo entra subindo de leve.
    ParallelAnimation {
        id: surgir
        NumberAnimation { target: coluna; property: "opacity"; from: 0; to: 1; duration: 220 }
        NumberAnimation { target: coluna; property: "y"; from: Math.round(janela.gu * 1.1); to: Math.round(janela.gu * 0.6); duration: 300; easing.type: Easing.OutCubic }
    }

    // ----- a contagem embaixo -----
    Item {
        id: rodape
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.round(janela.gu * 1.8)
        visible: editor.nota !== null
        Texto {
            anchors.right: parent.right
            anchors.rightMargin: Math.round(janela.gu * 1.1)
            anchors.verticalCenter: parent.verticalCenter
            text: editor.ehLista
                  ? (tarefas.pendentes + tarefas.feitos === 0 ? janela.t("Nenhum item", "No items")
                     : janela.t(tarefas.feitos + " de " + (tarefas.pendentes + tarefas.feitos) + " concluídos", tarefas.feitos + " of " + (tarefas.pendentes + tarefas.feitos) + " done"))
                  : (editor.palavras === 1 ? janela.t("1 palavra", "1 word") : janela.t(janela.num(editor.palavras) + " palavras", janela.num(editor.palavras) + " words"))
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.features: { "tnum": 1 }
            opacity: 0.45
        }
    }
}
