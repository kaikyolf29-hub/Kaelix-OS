// Notas do Matsu: notas rápidas e listas de tarefas, como o Notas do Mac e o
// Google Keep. A janela de vidro é a JanelaMatsu (../comum): à esquerda, as
// páginas (Todas, Fixadas, Listas e Lixeira); no miolo, a lista das notas e o
// editor (ou a grade de cartões, com o editor por cima).
//
// Tudo fica num arquivo só, ~/.local/share/matsu/notas/notas.json, gravado
// sozinho um instante depois de cada mudança (matsu.gravar não deixa o arquivo
// pela metade). Antes de gravar por cima, o arquivo anterior vira a cópia de
// segurança notas.json.bak (na primeira gravação e depois a cada 10 minutos).
// A lógica que não desenha nada (busca, ordem, datas, o texto com negrito e
// itálico) fica em notas.js, testada por tests/test_notas.js.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "notas.js" as N

JanelaMatsu {
    id: janela

    title: t("Notas", "Notes")
    icone: "org.matsu.notas"
    iconeReserva: "matsu-texto-symbolic"
    dicaBusca: t("Buscar nas notas", "Search notes")
    paginas: [
        { id: "todas", icone: Qt.resolvedUrl("icones/nota.svg"), nome: t("Todas as notas", "All notes") },
        { id: "fixadas", icone: Qt.resolvedUrl("icones/fixar.svg"), nome: t("Fixadas", "Pinned") },
        { id: "listas", icone: Qt.resolvedUrl("icones/lista.svg"), nome: t("Listas", "Checklists") },
        { id: "lixeira", icone: "matsu-lixeira-symbolic", nome: t("Lixeira", "Trash") }
    ]
    conteudo: Qt.resolvedUrl("PaginaNotas.qml")

    // ----- as notas -----
    property var notas: []
    property var preferencias: ({ visao: "lista" })
    // Sobe a cada mudança: quem mostra as notas se atualiza por ele.
    property int revisao: 0
    // O editor relê a nota inteira (depois de converter em lista, por exemplo).
    property int recarga: 0
    property string selecionada: ""
    property bool carregado: false
    // A hora de agora, para o "há 5 min" (atualiza a cada 30 s).
    property double agora: Date.now()
    readonly property var contagem: {
        revisao;
        return N.contar(notas);
    }
    readonly property string arquivo: matsu.pasta("dados") + "/notas.json"
    property string ultimoGravado: ""
    property bool podeCopiar: true
    property double ultimaCopia: 0

    signal salvou()
    // Pede o foco no editor: "titulo", "corpo" ou "fim".
    signal focarEditor(string onde)

    function porId(id) {
        for (var i = 0; i < notas.length; i++)
            if (notas[i].id === id)
                return notas[i];
        return null;
    }
    function indice(id) {
        for (var i = 0; i < notas.length; i++)
            if (notas[i].id === id)
                return i;
        return -1;
    }
    function vazia(n) {
        return !!n && !n.titulo.trim() && !N.semMarcas(n.texto).trim() && N.contarItens(n.itens).total === 0;
    }
    function tocar() {
        revisao++;
        salvarDepois.restart();
    }

    // Muda campos de uma nota; a data de edição anda junto (a não ser com manterData).
    function mudar(id, campos, manterData) {
        var n = porId(id);
        if (!n)
            return;
        var mudou = false;
        for (var k in campos) {
            if (JSON.stringify(n[k]) !== JSON.stringify(campos[k])) {
                n[k] = campos[k];
                mudou = true;
            }
        }
        if (!mudou)
            return;
        if (!manterData)
            n.editada = Date.now();
        tocar();
    }

    function nova(tipo) {
        if (!carregado)
            return;
        var n = N.novaNota(tipo, Date.now());
        // Na página das fixadas a nota nova já nasce fixada; nas outras, vai para Todas.
        if (pagina === "fixadas")
            n.fixada = true;
        else if (!(pagina === "listas" && tipo === "lista"))
            pagina = "todas";
        campoBusca.text = "";
        notas.push(n);
        selecionada = n.id;
        tocar();
        focarEditor("titulo");
    }

    // A nota que ficou vazia some sozinha quando a pessoa vai para outra (como no Keep).
    property string anterior: ""
    onSelecionadaChanged: {
        var velha = porId(anterior);
        if (velha && velha.apagada === 0 && vazia(velha) && anterior !== selecionada) {
            notas.splice(indice(anterior), 1);
            tocar();
        }
        anterior = selecionada;
    }

    function apagar(id) {
        var n = porId(id);
        if (!n)
            return;
        if (n.apagada > 0) {
            apagarParaSempre(id);
            return;
        }
        if (vazia(n)) {
            notas.splice(indice(id), 1);
            tocar();
            return;
        }
        n.apagada = Date.now();
        tocar();
        avisoRapido(t("Nota movida para a Lixeira", "Note moved to Trash"), "", t("Desfazer", "Undo"), function () {
            var m = porId(id);
            if (!m)
                return;
            m.apagada = 0;
            if (pagina === "lixeira")
                pagina = "todas";
            selecionada = id;
            tocar();
        });
    }
    function restaurar(id) {
        var n = porId(id);
        if (!n)
            return;
        n.apagada = 0;
        tocar();
        avisoRapido(t("Nota restaurada", "Note restored"), "certo", t("Abrir", "Open"), function () {
            pagina = n.tipo === "lista" && pagina === "listas" ? "listas" : "todas";
            selecionada = id;
        });
    }
    function apagarParaSempre(id) {
        var n = porId(id);
        if (!n)
            return;
        var nome = N.tituloVisivel(n, "");
        dialogo.perguntar({
            titulo: t("Apagar a nota para sempre?", "Delete the note forever?"),
            texto: nome ? t("“" + nome + "” vai sumir de vez. Não dá para desfazer.", "“" + nome + "” will be gone for good. This can't be undone.")
                        : t("Não dá para desfazer.", "This can't be undone."),
            sim: t("Apagar", "Delete"),
            perigo: true
        }, function () {
            var i = indice(id);
            if (i < 0)
                return;
            notas.splice(i, 1);
            tocar();
            avisoRapido(t("Nota apagada", "Note deleted"), "certo");
        });
    }
    function esvaziarLixeira() {
        var total = contagem.lixeira;
        if (total === 0)
            return;
        dialogo.perguntar({
            titulo: t("Esvaziar a Lixeira?", "Empty the Trash?"),
            texto: total === 1 ? t("A nota da Lixeira vai sumir de vez. Não dá para desfazer.", "The note in the Trash will be gone for good. This can't be undone.")
                               : t("As " + total + " notas da Lixeira vão sumir de vez. Não dá para desfazer.", "The " + total + " notes in the Trash will be gone for good. This can't be undone."),
            sim: t("Esvaziar", "Empty"),
            perigo: true
        }, function () {
            notas = notas.filter(function (n) { return n.apagada === 0; });
            tocar();
            avisoRapido(t("Lixeira vazia", "Trash emptied"), "certo");
        });
    }
    function fixar(id) {
        var n = porId(id);
        if (n)
            mudar(id, { fixada: !n.fixada }, true);
    }
    function pintar(id, cor) {
        mudar(id, { cor: cor }, true);
    }
    function duplicar(id) {
        var n = porId(id);
        if (!n)
            return;
        var c = JSON.parse(JSON.stringify(n));
        var agoraMs = Date.now();
        c.id = N.novoId(agoraMs);
        c.criada = agoraMs;
        c.editada = agoraMs;
        c.fixada = false;
        c.apagada = 0;
        if (c.titulo)
            c.titulo = t(c.titulo + " (cópia)", c.titulo + " (copy)");
        notas.push(c);
        selecionada = c.id;
        tocar();
    }
    // Texto vira lista (cada linha um item) e lista vira texto; dá para desfazer.
    function converter(id) {
        var n = porId(id);
        if (!n)
            return;
        var antes = JSON.stringify(n);
        if (n.tipo === "texto")
            mudar(id, { tipo: "lista", itens: N.textoParaItens(n.texto, Date.now()), texto: "" });
        else
            mudar(id, { tipo: "texto", texto: N.itensParaTexto(n.itens), itens: [] });
        recarga++;
        avisoRapido(n.tipo === "lista" ? t("Virou uma lista", "Turned into a checklist") : t("Virou um texto", "Turned into a text note"), "certo", t("Desfazer", "Undo"), function () {
            var i = indice(id);
            if (i < 0)
                return;
            notas[i] = JSON.parse(antes);
            recarga++;
            tocar();
        });
    }
    function mudarVisao(v) {
        if (preferencias.visao === v)
            return;
        preferencias = { visao: v };
        salvarDepois.restart();
    }

    // ----- o arquivo -----
    function carregar() {
        var texto = matsu.ler(arquivo);
        var estado = N.ler(texto, Date.now());
        ultimoGravado = estado.erro === "" ? texto : "";
        if (estado.erro === "quebrado") {
            // Guarda o arquivo estragado do lado (nada se perde) e tenta a cópia de segurança.
            matsu.gravar(arquivo + ".quebrado", texto);
            var copia = N.ler(matsu.ler(arquivo + ".bak"), Date.now());
            podeCopiar = false;
            if (copia.erro === "") {
                estado = copia;
                avisoRapido(t("O arquivo das notas estava estragado; voltei a cópia de segurança", "The notes file was damaged; restored the backup"), "erro");
            } else {
                avisoRapido(t("O arquivo das notas estava estragado (guardei como notas.json.quebrado)", "The notes file was damaged (kept as notas.json.quebrado)"), "erro");
            }
            salvarDepois.restart();
        }
        var limpo = N.limparLixeira(estado.notas, Date.now());
        notas = limpo.notas;
        preferencias = estado.preferencias;
        if (limpo.removidas > 0)
            salvarDepois.restart();
        carregado = true;
        revisao++;
    }
    function salvar() {
        salvarDepois.stop();
        if (!carregado)
            return;
        var texto = N.gravar(notas, preferencias);
        if (texto === ultimoGravado)
            return;
        var agoraMs = Date.now();
        // Cópia de segurança do arquivo anterior: na primeira gravação e a cada 10 min.
        if (ultimoGravado && podeCopiar && (ultimaCopia === 0 || agoraMs - ultimaCopia > 600000)) {
            if (matsu.gravar(arquivo + ".bak", ultimoGravado))
                ultimaCopia = agoraMs;
        }
        if (matsu.gravar(arquivo, texto)) {
            ultimoGravado = texto;
            podeCopiar = true;
            salvou();
        } else {
            avisoRapido(t("Não deu para salvar as notas", "Couldn't save the notes"), "erro", t("Tentar de novo", "Try again"), salvar);
        }
    }
    Timer {
        id: salvarDepois
        interval: 700
        onTriggered: janela.salvar()
    }
    onClosing: {
        var n = porId(selecionada);
        if (n && n.apagada === 0 && vazia(n))
            notas.splice(indice(selecionada), 1);
        salvar();
    }

    // A hora anda; de hora em hora a Lixeira perde o que passou de 30 dias.
    Timer {
        interval: 30000
        running: true
        repeat: true
        property int voltas: 0
        onTriggered: {
            janela.agora = Date.now();
            if (++voltas % 120 === 0) {
                var limpo = N.limparLixeira(janela.notas, Date.now());
                if (limpo.removidas > 0) {
                    janela.notas = limpo.notas;
                    janela.tocar();
                }
            }
        }
    }

    // ----- o vidro que a pessoa escolheu (o mesmo arquivo do "matsu vidro") -----
    function lerVidro() {
        var cores = { azul: "#2f80ed", roxo: "#8b5cf6", rosa: "#ec4899", vermelho: "#ef4444", laranja: "#f97316",
                      amarelo: "#eab308", verde: "#22c55e", grafite: "#6b7280" };
        var valores = {};
        var linhas = matsu.ler(matsu.pasta("config") + "/vidro").split("\n");
        for (var i = 0; i < linhas.length; i++) {
            var p = linhas[i].indexOf("=");
            if (p > 0)
                valores[linhas[i].substring(0, p).trim()] = linhas[i].substring(p + 1).trim().toLowerCase();
        }
        var cor = valores.cor || "";
        cor = cores[cor] || (/^#[0-9a-f]{6}$/.test(cor) ? cor : "");
        var nivel = ["mais", "normal", "menos", "sem"].indexOf(valores.transparencia) >= 0 ? valores.transparencia : "normal";
        if (cor !== vidroConf.cor || nivel !== vidroConf.nivel)
            vidroConf = { cor: cor, nivel: nivel };
    }
    onActiveChanged: if (active) lerVidro()

    // ----- cores das notas -----
    function tom(id) {
        var c = N.cor(id);
        return c ? c.tom : "transparent";
    }
    function rgba(hex, a) {
        return Qt.rgba(parseInt(hex.substr(1, 2), 16) / 255, parseInt(hex.substr(3, 2), 16) / 255, parseInt(hex.substr(5, 2), 16) / 255, a);
    }
    // O fundo leve de uma nota colorida (força 1 = o editor; mais = o cartão da grade).
    function fundoCor(id, forca) {
        var c = N.cor(id);
        if (!c)
            return "transparent";
        return rgba(c.tom, (escuro ? 0.085 : 0.2) * (forca === undefined ? 1 : forca));
    }
    function nomeCor(id) {
        var c = N.cor(id);
        return c ? (pt ? c.pt : c.en) : t("Sem cor", "No color");
    }
    // Cor do texto achado na busca (âmbar, legível nos dois temas).
    readonly property color corAchado: escuro ? "#f5c45e" : "#a86400"

    // Com a janela estreita, a lista das páginas se recolhe sozinha (e volta depois).
    readonly property bool estreita: width < gu * 50
    property bool recolhidaAntes: false
    onEstreitaChanged: {
        if (estreita) {
            recolhidaAntes = recolhida;
            recolhida = true;
        } else {
            recolhida = recolhidaAntes;
        }
    }

    // ----- atalhos -----
    readonly property bool digitando: activeFocusItem !== null && activeFocusItem.cursorPosition !== undefined
    Shortcut {
        sequences: [StandardKey.New]
        onActivated: janela.nova("texto")
    }
    Shortcut {
        sequences: ["Ctrl+Shift+N"]
        onActivated: janela.nova("lista")
    }
    Shortcut {
        sequences: [StandardKey.Delete]
        enabled: !janela.digitando && janela.selecionada !== ""
        onActivated: janela.apagar(janela.selecionada)
    }

    Connections {
        target: matsu
        function onPedido(argumentos) {
            janela.abrirCom(argumentos);
        }
    }
    function abrirCom(args) {
        if (args.indexOf("--nova") >= 0)
            nova("texto");
        else if (args.indexOf("--lista") >= 0)
            nova("lista");
    }

    Component.onCompleted: {
        lerVidro();
        carregar();
        if (estreita)
            recolhida = true;
        abrirCom(matsu.argumentos);
    }

    Dialogo {
        id: dialogo
    }

    // Embaixo da lista das páginas: ver as notas em colunas ou em grade.
    rodapeLateral: Component {
        ColumnLayout {
            spacing: Math.round(janela.gu * 0.35)
            Texto {
                text: janela.t("Exibição", "View")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.6
            }
            Seletor {
                Layout.fillWidth: true
                opcoes: [
                    { id: "lista", nome: janela.t("Lista", "List"), icone: String(Qt.resolvedUrl("icones/colunas.svg")) },
                    { id: "grade", nome: janela.t("Grade", "Grid"), icone: String(Qt.resolvedUrl("icones/grade.svg")) }
                ]
                escolhido: janela.preferencias.visao
                onEscolher: (id) => janela.mudarVisao(id)
            }
        }
    }
}
