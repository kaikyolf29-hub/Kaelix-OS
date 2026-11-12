// Calculadora do Matsu, no jeito da Calculadora do Windows 11: Padrão, Científica
// e Conversor de unidades na lista da esquerda (que começa recolhida), o visor com
// a conta em cima e o resultado grande embaixo (os algarismos rolam), histórico e
// memória num painel à direita, teclado completo (a tecla na tela afunda junto).
// A janela de vidro é a JanelaMatsu, de ../comum.
//
// As contas ficam em calculo.js (decimais de verdade: 0,1 + 0,2 = 0,3), que tem
// testes em tests/test_calculadora.js. Histórico, memória e as escolhas ficam em
// ~/.local/share/matsu/calculadora/ (historico.json, memoria.json, preferencias.json).
// Abrir com "cientifica" ou "conversor" leva direto ao modo.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "calculo.js" as Calculo

JanelaMatsu {
    id: janela

    title: t("Calculadora", "Calculator")
    icone: "org.matsu.calculadora"
    iconeReserva: "accessories-calculator"
    paginas: [
        { id: "padrao", icone: Qt.resolvedUrl("icones/padrao.svg"), nome: t("Padrão", "Standard") },
        { id: "cientifica", icone: Qt.resolvedUrl("icones/cientifica.svg"), nome: t("Científica", "Scientific") },
        { id: "conversor", icone: Qt.resolvedUrl("icones/conversor.svg"), nome: t("Conversor", "Converter") }
    ]
    // Padrão e Científica são a mesma página (a grade troca com animação).
    conteudo: Qt.resolvedUrl(pagina === "conversor" ? "PaginaConversor.qml" : "PaginaCalculadora.qml")
    recolhida: true
    width: Math.round(gu * 22)
    height: Math.round(gu * 34)
    minimumWidth: Math.round(gu * 20)
    minimumHeight: Math.round(gu * 28)

    // ----- a lista da esquerda numa janela estreita -----
    // Aberta, a lista come 9 gu: a janela alarga para a calculadora não espremer,
    // e volta ao tamanho de antes quando a lista recolhe.
    property int alargou: 0
    onRecolhidaChanged: {
        var aberta = Math.round(gu * 30), fechada = Math.round(gu * 20);
        if (!recolhida) {
            var falta = aberta - width;
            if (falta > 0 && !cheia) {
                alargou = falta;
                width = width + falta;
            }
            minimumWidth = aberta;
        } else {
            minimumWidth = fechada;
            if (alargou > 0 && !cheia)
                width = Math.max(fechada, width - alargou);
            alargou = 0;
        }
    }

    // ----- a conta -----
    property string angulo: "graus"
    property bool segunda: false
    property var estado: Calculo.novoEstado()
    readonly property var opcoes: ({ ingles: !pt, angulo: angulo, limite: 16 })
    readonly property var tela: Calculo.visor(estado, opcoes)
    property bool painelAberto: false
    property string abaPainel: "historico"

    // A tecla da tela que corresponde à tecla apertada no teclado afunda junto.
    signal piscar(string chave)

    function aviso(texto, tipo, acao, funcao) {
        avisoRapido(texto, tipo, acao, funcao);
    }
    signal copiado()

    function acionar(chave) {
        estado = Calculo.apertar(estado, chave, opcoes);
        if (estado.registro)
            guardarHistorico(estado.registro);
    }

    // ----- histórico e memória -----
    ListModel {
        id: modeloHistorico
    }
    ListModel {
        id: modeloMemoria
    }
    readonly property alias historico: modeloHistorico
    readonly property alias memoria: modeloMemoria

    function guardarHistorico(r) {
        historico.insert(0, { expressao: r.expressao, valor: r.valor });
        while (historico.count > 100)
            historico.remove(historico.count - 1);
        salvarLogo();
    }
    function voltarHistorico(i) {
        var h = historico.get(i);
        estado = Calculo.restaurar(h.expressao, h.valor, opcoes);
    }
    function apagarHistorico(i) {
        historico.remove(i);
        salvarLogo();
    }
    function copiarLista(modelo) {
        var l = [];
        for (var i = 0; i < modelo.count; i++)
            l.push(Object.assign({}, modelo.get(i)));
        return l;
    }
    function limparHistorico() {
        if (historico.count === 0)
            return;
        var antes = copiarLista(historico);
        historico.clear();
        salvarLogo();
        aviso(t("Histórico limpo", "History cleared"), "", t("Desfazer", "Undo"), function () {
            historico.clear();
            for (var i = 0; i < antes.length; i++)
                historico.append(antes[i]);
            salvarLogo();
        });
    }

    readonly property bool temMemoria: memoria.count > 0
    // Depois de guardar, o próximo algarismo começa outro número (como no Windows).
    function fecharEntrada() {
        if (tela.digitando)
            estado = Calculo.comValor(estado, tela.valor, opcoes);
    }
    function memoriaGuardar() {
        if (tela.erro)
            return;
        memoria.insert(0, { valor: tela.valor });
        fecharEntrada();
        salvarLogo();
    }
    function memoriaSomar(i, sinal) {
        if (tela.erro)
            return;
        if (memoria.count === 0)
            return memoriaGuardar();
        var antes = memoria.get(i).valor;
        memoria.setProperty(i, "valor", sinal > 0 ? Calculo.somar(antes, tela.valor) : Calculo.subtrair(antes, tela.valor));
        fecharEntrada();
        salvarLogo();
    }
    function memoriaLer(i) {
        if (memoria.count > i)
            estado = Calculo.comValor(estado, memoria.get(i).valor, opcoes);
    }
    function memoriaApagar(i) {
        memoria.remove(i);
        salvarLogo();
    }
    function memoriaLimpar() {
        memoria.clear();
        salvarLogo();
    }
    function memoria_(chave) {
        if (chave === "MS")
            memoriaGuardar();
        else if (chave === "M+")
            memoriaSomar(0, 1);
        else if (chave === "M-")
            memoriaSomar(0, -1);
        else if (chave === "MR")
            memoriaLer(0);
        else if (chave === "MC")
            memoriaLimpar();
    }
    function alternarPainel(aba) {
        if (painelAberto && abaPainel === aba)
            painelAberto = false;
        else {
            abaPainel = aba;
            painelAberto = true;
        }
    }

    // ----- conversor -----
    property string convCategoria: "comprimento"
    property string convA: "m"
    property string convB: "cm"
    property string convAtivo: "a"   // a linha onde se digita
    property bool convAEmCima: true
    property string convEntrada: "1"
    // O "1" do começo (e o valor de uma linha recém-escolhida) some no primeiro algarismo.
    property bool convNovo: true
    property var convUnidades: ({})  // as últimas unidades de cada categoria
    readonly property string convValorA: convAtivo === "a" ? convEntrada : (Calculo.converter(convEntrada, convCategoria, convB, convA) || "0")
    readonly property string convValorB: convAtivo === "b" ? convEntrada : (Calculo.converter(convEntrada, convCategoria, convA, convB) || "0")

    function conversorCategoria(id) {
        if (id === convCategoria)
            return;
        var cat = Calculo.categoria(id);
        var guardadas = convUnidades[id];
        convCategoria = id;
        convA = guardadas ? guardadas[0] : cat.de;
        convB = guardadas ? guardadas[1] : cat.para;
        convAtivo = convAEmCima ? "a" : "b";
        convEntrada = "1";
        convNovo = true;
        lembrarUnidades();
    }
    function conversorUnidade(lado, id) {
        if (lado === "a")
            convA = id;
        else
            convB = id;
        lembrarUnidades();
    }
    function lembrarUnidades() {
        var u = Object.assign({}, convUnidades);
        u[convCategoria] = [convA, convB];
        convUnidades = u;
        salvarLogo();
    }
    function conversorAtivar(lado) {
        if (lado === convAtivo)
            return;
        convEntrada = Calculo.textoEditavel(lado === "a" ? convValorA : convValorB);
        convAtivo = lado;
        convNovo = true;
    }
    // ⇅: as linhas trocam de lugar e a de cima vira a de digitar.
    function conversorTrocar() {
        convAEmCima = !convAEmCima;
        conversorAtivar(convAEmCima ? "a" : "b");
    }
    function conversorTecla(chave) {
        if (!(chave === "C" || chave === "CE" || chave === "apagar" || chave === "virgula" || chave === "neg" || /^[0-9]$/.test(chave)))
            return;
        if (convNovo && (chave === "virgula" || /^[0-9]$/.test(chave)))
            convEntrada = "0";
        convNovo = false;
        convEntrada = Calculo.digitarConversor(convEntrada, chave, convCategoria === "temperatura");
    }

    // ----- copiar e colar -----
    TextEdit {
        id: areaTransferencia
        visible: false
    }
    function copiar() {
        var texto = pagina === "conversor"
            ? Calculo.formatarTexto(convAtivo === "a" ? convValorB : convValorA, { ingles: !pt, semGrupo: true })
            : tela.copiar;
        copiarTexto(texto);
    }
    function copiarTexto(texto) {
        if (!texto)
            return;
        areaTransferencia.text = texto;
        areaTransferencia.selectAll();
        areaTransferencia.copy();
        copiado();
        aviso(t("Copiado: ", "Copied: ") + texto, "certo");
    }
    function colar() {
        areaTransferencia.text = "";
        areaTransferencia.paste();
        var lido = Calculo.lerColado(areaTransferencia.text, opcoes);
        if (lido === null) {
            aviso(t("Não dá para colar: não é um número", "Can't paste: that's not a number"), "erro");
            return;
        }
        if (pagina === "conversor") {
            convEntrada = Calculo.textoEditavel(lido);
            convNovo = true;
        }
        else
            estado = Calculo.comValor(estado, lido, opcoes);
    }

    // ----- teclado -----
    readonly property var teclasSimples: ({ ",": "virgula", ".": "virgula", "+": "+", "-": "-", "*": "*", "x": "*", "X": "*",
                                            "/": "/", "=": "=", "%": "%", "(": "(", ")": ")", "r": "inverso", "R": "inverso",
                                            "q": "quadrado", "Q": "quadrado", "@": "raiz" })
    readonly property var teclasCientificas: ({ "^": "^", "y": "^", "Y": "^", "!": "fatorial", "s": "sen", "S": "sen",
                                                "o": "cos", "O": "cos", "t": "tan", "T": "tan", "l": "log", "L": "log",
                                                "n": "ln", "N": "ln", "p": "pi", "P": "pi", "e": "EXP", "E": "EXP",
                                                "m": "mod", "M": "mod", "|": "abs" })
    function chaveDaTecla(e) {
        switch (e.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            return "=";
        case Qt.Key_Backspace:
            return "apagar";
        case Qt.Key_Escape:
            return "C";
        case Qt.Key_Delete:
            return "CE";
        case Qt.Key_F9:
            return "neg";
        }
        var tx = e.text;
        if (tx.length !== 1)
            return "";
        if (tx >= "0" && tx <= "9")
            return tx;
        if (teclasSimples[tx])
            return teclasSimples[tx];
        if (pagina === "cientifica" && teclasCientificas[tx])
            return teclasCientificas[tx];
        return "";
    }
    // As páginas mandam para cá as teclas que recebem.
    function teclaFisica(e) {
        if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return false;
        if (e.key === Qt.Key_Escape && painelAberto) {
            painelAberto = false;
            return true;
        }
        var c = chaveDaTecla(e);
        if (!c)
            return false;
        if (pagina === "conversor") {
            if (c === "=" || c === "+" || c === "*" || c === "/")
                return true;
            if (c === "-")
                c = "neg";
            piscar(c);
            conversorTecla(c);
            return true;
        }
        if (c === "C" && tela.digitando && pagina === "cientifica")
            piscar("CE");
        piscar(c);
        acionar(c);
        return true;
    }

    Shortcut {
        sequences: [StandardKey.Copy]
        onActivated: janela.copiar()
    }
    Shortcut {
        sequences: [StandardKey.Paste]
        onActivated: janela.colar()
    }
    Shortcut {
        sequence: "Ctrl+H"
        enabled: janela.pagina !== "conversor"
        onActivated: janela.alternarPainel("historico")
    }
    Shortcut {
        sequence: "Ctrl+Shift+D"
        onActivated: janela.limparHistorico()
    }
    Shortcut {
        sequence: "Ctrl+M"
        enabled: janela.pagina !== "conversor"
        onActivated: { janela.piscar("MS"); janela.memoria_("MS"); }
    }
    Shortcut {
        sequence: "Ctrl+P"
        enabled: janela.pagina !== "conversor"
        onActivated: { janela.piscar("M+"); janela.memoria_("M+"); }
    }
    Shortcut {
        sequence: "Ctrl+Q"
        enabled: janela.pagina !== "conversor"
        onActivated: { janela.piscar("M-"); janela.memoria_("M-"); }
    }
    Shortcut {
        sequence: "Ctrl+R"
        enabled: janela.pagina !== "conversor"
        onActivated: { janela.piscar("MR"); janela.memoria_("MR"); }
    }
    Shortcut {
        sequence: "Ctrl+L"
        enabled: janela.pagina !== "conversor"
        onActivated: { janela.piscar("MC"); janela.memoria_("MC"); }
    }

    // ----- guardar e ler (~/.local/share/matsu/calculadora) -----
    readonly property string pastaDados: matsu.pasta("dados")
    function lerJson(nome, padrao) {
        try {
            var texto = matsu.ler(pastaDados + "/" + nome);
            return texto ? JSON.parse(texto) : padrao;
        } catch (e) {
            return padrao;
        }
    }
    function carregar() {
        var h = lerJson("historico.json", []);
        for (var i = 0; Array.isArray(h) && i < h.length && i < 100; i++)
            if (h[i] && Calculo.dParse(String(h[i].valor)))
                historico.append({ expressao: String(h[i].expressao || ""), valor: String(h[i].valor) });
        var m = lerJson("memoria.json", []);
        for (var j = 0; Array.isArray(m) && j < m.length; j++)
            if (Calculo.dParse(String(m[j])))
                memoria.append({ valor: String(m[j]) });
        var p = lerJson("preferencias.json", {});
        if (p.angulo === "radianos" || p.angulo === "graus")
            angulo = p.angulo;
        if (p.modo === "padrao" || p.modo === "cientifica" || p.modo === "conversor")
            pagina = p.modo;
        if (p.conversor && typeof p.conversor === "object") {
            var c = p.conversor;
            var cat = Calculo.categoria(String(c.categoria || ""));
            convUnidades = c.unidades && typeof c.unidades === "object" ? c.unidades : {};
            convCategoria = cat.id;
            var u = convUnidades[cat.id];
            var valida = function (id) {
                return cat.unidades.some(function (x) { return x.id === id; });
            };
            convA = u && valida(u[0]) ? u[0] : cat.de;
            convB = u && valida(u[1]) ? u[1] : cat.para;
        }
    }
    function salvar() {
        var h = [];
        for (var i = 0; i < historico.count; i++)
            h.push({ expressao: historico.get(i).expressao, valor: historico.get(i).valor });
        var m = [];
        for (var j = 0; j < memoria.count; j++)
            m.push(memoria.get(j).valor);
        matsu.gravar(pastaDados + "/historico.json", JSON.stringify(h));
        matsu.gravar(pastaDados + "/memoria.json", JSON.stringify(m));
        matsu.gravar(pastaDados + "/preferencias.json", JSON.stringify({
            modo: pagina, angulo: angulo,
            conversor: { categoria: convCategoria, unidades: convUnidades }
        }));
    }
    Timer {
        id: tempoSalvar
        interval: 500
        onTriggered: janela.salvar()
    }
    function salvarLogo() {
        tempoSalvar.restart();
    }
    onPaginaChanged: {
        painelAberto = false;
        salvarLogo();
    }
    onAnguloChanged: salvarLogo()
    onClosing: salvar()

    // ----- o vidro que a pessoa escolheu (~/.config/matsu/vidro) -----
    readonly property var coresVidro: ({ azul: "#2f80ed", roxo: "#8b5cf6", rosa: "#ec4899", vermelho: "#ef4444",
                                         laranja: "#f97316", amarelo: "#eab308", verde: "#22c55e", grafite: "#6b7280" })
    property string vidroLido: "-"
    function lerVidro() {
        var texto = matsu.ler(matsu.pasta("config") + "/vidro");
        if (texto === vidroLido)
            return;
        vidroLido = texto;
        var valores = {};
        var linhas = texto.split("\n");
        for (var i = 0; i < linhas.length; i++) {
            var k = linhas[i].indexOf("=");
            if (k > 0)
                valores[linhas[i].substring(0, k).trim()] = linhas[i].substring(k + 1).trim().toLowerCase();
        }
        var cor = valores.cor || "";
        cor = coresVidro[cor] || (/^#[0-9a-f]{6}$/.test(cor) ? cor : "");
        var nivel = valores.transparencia || "normal";
        vidroConf = { cor: cor, nivel: ["mais", "normal", "menos", "sem"].indexOf(nivel) >= 0 ? nivel : "normal" };
    }
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: janela.lerVidro()
    }

    function abrirModo(args) {
        for (var i = 0; i < args.length; i++)
            if (irPara(args[i]))
                return;
    }
    Connections {
        target: matsu
        function onPedido(argumentos) {
            janela.abrirModo(argumentos);
        }
    }

    Component.onCompleted: {
        // Sem idioma no ambiente (locale "C"), vale o do Plasma.
        if (Qt.locale().name === "C" || Qt.locale().name === "") {
            var rc = matsu.ler(matsu.pasta("casa") + "/.config/plasma-localerc");
            var achado = /^(LANGUAGE|LANG)=(\S+)/m.exec(rc);
            if (achado)
                lingua = achado[2].indexOf("pt") === 0 ? "pt" : "en";
        }
        lerVidro();
        carregar();
        abrirModo(matsu.argumentos);
    }
}
