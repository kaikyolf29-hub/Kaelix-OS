// Testes da lógica do Notas (system_files/usr/share/matsu/notas/notas.js): o arquivo
// das notas, a Lixeira, a busca sem acento, a ordem, o "há 5 min", a contagem e o
// texto com negrito e itálico (as marcas e o HTML do editor, com amostras do Qt 6.10).
// Uso: node tests/test_notas.js
"use strict";
process.env.TZ = "America/Sao_Paulo";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ARQUIVO = path.join(__dirname, "..", "system_files", "usr", "share", "matsu", "notas", "notas.js");
// O ".pragma library" é do QML; no node ele sai.
const codigo = fs.readFileSync(ARQUIVO, "utf8").replace(/^\.pragma library\s*$/m, "");
const N = {};
vm.runInNewContext(codigo + "\n;Object.assign(saida, { VERSAO, DIAS_LIXEIRA, DIA, CORES, cor, simples, trechosDaLinha, escapar, linhaDosTrechos, semMarcas, marcasParaHtml, linhasDoHtml, htmlParaMarcas, jeitoDoTrecho, alternarJeito, coladoParaHtml, novoId, novaNota, normalizarNota, ler, gravar, limparLixeira, diasRestantes, combina, filtrar, contar, tituloVisivel, previa, contarPalavras, contarItens, textoParaItens, itensParaTexto, quando, dataCompleta, realcar });", { saida: N });

let passou = 0, falhou = 0;
function confere(desc, ok, extra) {
  if (ok) { passou++; console.log("  ok   " + desc); }
  else { falhou++; console.log("  FAIL " + desc + (extra !== undefined ? "\n       | " + extra : "")); }
}
function igual(desc, visto, esperado) {
  const a = JSON.stringify(visto), b = JSON.stringify(esperado);
  confere(desc, a === b, "visto " + a + "\n       | esperado " + b);
}

// Saídas de verdade do TextEdit (RichText) do Qt 6.10: toHtml de um texto digitado
// com negrito, itálico, os dois, um parágrafo vazio, Shift+Enter, Tab e aspas; e o
// getFormattedText de um trecho.
const DOC_QT = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0//EN\" \"http://www.w3.org/TR/REC-html40/strict.dtd\">\n<html><head><meta name=\"qrichtext\" content=\"1\" /><meta charset=\"utf-8\" /><style type=\"text/css\">\np, li { white-space: pre-wrap; }\nhr { height: 1px; border-width: 0; }\nli.unchecked::marker { content: \"\\2610\"; }\nli.checked::marker { content: \"\\2612\"; }\n</style></head><body style=\" font-family:'Sans Serif'; font-size:15px; font-weight:400; font-style:normal;\">\n<p style=\" margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px;\">Comprar <span style=\" font-weight:700;\">p\u00e3o</span> e <span style=\" font-style:italic;\">leite</span> &amp; <span style=\" font-weight:700; font-style:italic;\">caf\u00e9</span> j\u00e1 * \\ fim</p>\n<p style=\"-qt-paragraph-type:empty; margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px;\"><br /></p>\n<p style=\" margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px;\">x<br />y\t&quot;</p></body></html>";
const FRAG_QT = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0//EN\" \"http://www.w3.org/TR/REC-html40/strict.dtd\">\n<html><head><meta name=\"qrichtext\" content=\"1\" /><meta charset=\"utf-8\" /><style type=\"text/css\">\np, li { white-space: pre-wrap; }\nhr { height: 1px; border-width: 0; }\nli.unchecked::marker { content: \"\\2610\"; }\nli.checked::marker { content: \"\\2612\"; }\n</style></head><body>\n<p style=\" margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px;\"><!--StartFragment-->rar <span style=\" font-weight:700;\">p\u00e3o</span> e <span style=\" font-style:italic;\">leit</span><!--EndFragment--></p></body></html>";
const VAZIO_QT = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0//EN\" \"http://www.w3.org/TR/REC-html40/strict.dtd\">\n<html><head><meta name=\"qrichtext\" content=\"1\" /><meta charset=\"utf-8\" /><style type=\"text/css\">\np, li { white-space: pre-wrap; }\n</style></head><body style=\" font-family:'Sans Serif'; font-size:15px; font-weight:400; font-style:normal;\">\n<p style=\"-qt-paragraph-type:empty; margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px;\"><br /></p></body></html>";

console.log("marcas (**negrito**, *itálico*)");
igual("linha simples", N.trechosDaLinha("oi"), [{ texto: "oi", negrito: false, italico: false }]);
igual("negrito e itálico", N.trechosDaLinha("a **b** *c* ***d***"), [
  { texto: "a ", negrito: false, italico: false }, { texto: "b", negrito: true, italico: false },
  { texto: " ", negrito: false, italico: false }, { texto: "c", negrito: false, italico: true },
  { texto: " ", negrito: false, italico: false }, { texto: "d", negrito: true, italico: true }]);
igual("asterisco e barra protegidos", N.semMarcas("5 \\* 3 \\\\ fim"), "5 * 3 \\ fim");
igual("sem marcas em várias linhas", N.semMarcas("**Título**\n\n*a* b"), "Título\n\na b");
igual("escapar", N.escapar("a*b\\c"), "a\\*b\\\\c");
for (const linha of ["texto puro", "**tudo negrito**", "*tudo itálico*", "mistura **n** e *i* e ***ni*** fim", "**n *ni* n**", "5 \\* 3", "barra \\\\ e \\*\\*", "***a*b**", "*a**b***"]) {
  igual("ida e volta: " + linha, N.semMarcas(N.linhaDosTrechos(N.trechosDaLinha(linha))), N.semMarcas(linha));
  igual("ida e volta guarda o jeito: " + linha, N.trechosDaLinha(N.linhaDosTrechos(N.trechosDaLinha(linha))), N.trechosDaLinha(linha));
}
igual("itálico que fecha e abre não vira negrito", N.linhaDosTrechos([{ texto: "a", italico: true }, { texto: "b", italico: true, negrito: true }]), "*a**b***");
igual("vizinhos iguais se juntam", N.linhaDosTrechos([{ texto: "a", negrito: true }, { texto: "b", negrito: true }]), "**ab**");

console.log("HTML do editor (RichText do Qt)");
igual("toHtml do Qt vira marcas", N.htmlParaMarcas(DOC_QT), "Comprar **pão** e *leite* & ***café*** já \\* \\\\ fim\n\nx\ny\t\"");
igual("documento vazio do Qt", N.htmlParaMarcas(VAZIO_QT), "");
const gerado = N.marcasParaHtml("Comprar **pão** <e> & \"leite\"\n\n  dois  espaços\n*fim*");
igual("ida e volta pelo HTML", N.htmlParaMarcas(gerado), "Comprar **pão** <e> & \"leite\"\n\n  dois  espaços\n*fim*");
confere("parágrafo vazio vira parágrafo vazio do Qt", gerado.includes('<p style="-qt-paragraph-type:empty;'));
confere("espaços guardados (pre-wrap)", gerado.includes("white-space: pre-wrap"));
confere("altura da linha opcional", N.marcasParaHtml("a", 135).includes("line-height:135%;"));
confere("sinais escapados no HTML", gerado.includes("&lt;e&gt; &amp; &quot;leite&quot;"));
igual("HTML colado de fora: só negrito e itálico ficam", N.htmlParaMarcas('<html><body><h1 style="font-size:30px;color:red">Oi</h1><p>um <strong>dois</strong> <em>três</em> <span style="font-weight:bold">q</span><span style="color:#f00">c</span></p><ul><li>a</li><li>b</li></ul></body></html>'),
  "Oi\num **dois** *três* **q**c\na\nb");
igual("entidades numéricas", N.htmlParaMarcas("<p>&#233;&#x41;&nbsp;x</p>"), "éA\u00a0x");
igual("linhas vazias no fim saem", N.htmlParaMarcas("<p>a</p><p><br /></p><p><br /></p>"), "a");

console.log("negrito e itálico num trecho (Ctrl+B, Ctrl+I)");
let r = N.alternarJeito(FRAG_QT, "negrito");
confere("trecho misturado: liga o negrito", r.ligar === true);
igual("trecho misturado fica todo em negrito", N.htmlParaMarcas("<p>" + r.html + "</p>"), "**rar pão e *leit***");
r = N.alternarJeito("<p><span style=\" font-weight:700;\">tudo</span></p>", "negrito");
confere("trecho todo em negrito: desliga", r.ligar === false);
igual("negrito sai, o resto fica", N.htmlParaMarcas("<p>" + r.html + "</p>"), "tudo");
r = N.alternarJeito("<p><span style=\" font-weight:700;\">a</span><span style=\" font-weight:700; font-style:italic;\">b</span></p>", "negrito");
igual("tirar o negrito guarda o itálico", N.htmlParaMarcas("<p>" + r.html + "</p>"), "a*b*");
igual("jeito de um trecho todo em negrito", N.jeitoDoTrecho("<p><b>a</b><b><i>b</i></b></p>"), { negrito: true, italico: false });
igual("jeito de um trecho vazio", N.jeitoDoTrecho("<p></p>"), { negrito: false, italico: false });
r = N.alternarJeito("<p><b>já</b></p>", "negrito", true);
confere("forçar ligado mantém o negrito", r.ligar === true && N.htmlParaMarcas("<p>" + r.html + "</p>") === "**já**");
confere("os espaços do trecho não somem (pre-wrap)", N.alternarJeito("<p>a  b</p>", "italico").html.includes("white-space:pre-wrap"));
confere("colado vira texto puro com pre-wrap", N.coladoParaHtml("<b>x</b>\r\ny") === '<span style="white-space:pre-wrap">&lt;b&gt;x&lt;/b&gt;\ny</span>');

console.log("arquivo das notas");
const AGORA = new Date(2026, 10, 12, 14, 30).getTime();
let est = N.ler("", AGORA);
confere("arquivo vazio: sem notas, erro vazio", est.notas.length === 0 && est.erro === "vazio");
est = N.ler("{ isso não é json", AGORA);
confere("arquivo quebrado é avisado", est.erro === "quebrado" && est.notas.length === 0);
est = N.ler('{"versao":1,"notas":"x"}', AGORA);
confere("notas que não são lista: quebrado", est.erro === "quebrado");
est = N.ler(JSON.stringify({ versao: 1, notas: [
  { id: "a", tipo: "texto", titulo: "Oi\nvocê", texto: "linha\r\noutra", cor: "rosa", fixada: 1, criada: 10, editada: 20 },
  { id: "a", tipo: "lista", itens: ["solto", { texto: "feito\n", feito: true }, null, 3], cor: "azul-do-kde" },
  "lixo", null, 42,
  { tipo: "esquisito", editada: -5, apagada: "ontem" }
], preferencias: { visao: "grade" } }), AGORA);
confere("notas ruins saem, as boas ficam", est.notas.length === 3, est.notas.length);
confere("id repetido ganha outro", est.notas[0].id === "a" && est.notas[1].id !== "a");
igual("título numa linha só", est.notas[0].titulo, "Oi você");
igual("quebras do Windows viram \\n", est.notas[0].texto, "linha\noutra");
confere("fixada vira verdadeiro ou falso", est.notas[0].fixada === true);
igual("itens soltos e ruins", est.notas[1].itens.map((i) => [i.texto, i.feito]), [["solto", false], ["feito ", true]]);
igual("cor que não existe sai", est.notas[1].cor, "");
confere("tipo esquisito vira texto", est.notas[2].tipo === "texto");
confere("datas ruins viram agora e zero", est.notas[2].criada === AGORA && est.notas[2].editada === AGORA && est.notas[2].apagada === 0);
igual("preferências", est.preferencias, { visao: "grade" });
est = N.ler(JSON.stringify([{ id: "x", titulo: "lista solta" }]), AGORA);
confere("aceita uma lista solta de notas", est.notas.length === 1 && est.erro === "");
const nova = N.novaNota("lista", AGORA, "fixo");
const relido = N.ler(N.gravar([nova], { visao: "lista" }), AGORA);
igual("gravar e ler de novo dá a mesma nota", relido.notas[0], nova);
confere("gravado tem a versão", JSON.parse(N.gravar([], null)).versao === N.VERSAO);
confere("ids novos são diferentes", N.novoId(AGORA, 0.1) !== N.novoId(AGORA, 0.2));

console.log("Lixeira");
const notasLixo = [
  { id: "1", apagada: 0 }, { id: "2", apagada: AGORA - 29 * N.DIA }, { id: "3", apagada: AGORA - 30 * N.DIA }, { id: "4", apagada: AGORA - 400 * N.DIA }];
const limpo = N.limparLixeira(notasLixo, AGORA);
igual("mais de 30 dias saem sozinhas", limpo.notas.map((n) => n.id), ["1", "2"]);
confere("conta as que saíram", limpo.removidas === 2);
confere("dias que faltam", N.diasRestantes(AGORA - 3 * N.DIA, AGORA) === 27 && N.diasRestantes(AGORA - 29.5 * N.DIA, AGORA) === 1 && N.diasRestantes(AGORA - 40 * N.DIA, AGORA) === 0);

console.log("páginas, ordem e busca");
function nota(id, extra) { return Object.assign(N.novaNota("texto", AGORA, id), extra); }
const varias = [
  nota("velha", { titulo: "Receita de pão", texto: "Farinha, **fermento** e água", editada: AGORA - 5 * N.DIA }),
  nota("nova", { titulo: "Reunião", texto: "Falar com a Área de vendas", editada: AGORA - 1000 }),
  nota("fixa", { titulo: "Senha do Wi-Fi", texto: "na geladeira", fixada: true, editada: AGORA - 9 * N.DIA }),
  nota("compras", { tipo: "lista", titulo: "Mercado", itens: [{ id: "i", texto: "Café", feito: false }, { id: "j", texto: "Açúcar", feito: true }], editada: AGORA - 3000 }),
  nota("lixo1", { titulo: "Velharia", apagada: AGORA - 2 * N.DIA }),
  nota("lixo2", { titulo: "Rascunho", apagada: AGORA - N.DIA }),
];
igual("Todas: fixadas no topo, depois a mais recente", N.filtrar(varias, "todas", "").map((n) => n.id), ["fixa", "nova", "compras", "velha"]);
igual("Fixadas", N.filtrar(varias, "fixadas", "").map((n) => n.id), ["fixa"]);
igual("Listas", N.filtrar(varias, "listas", "").map((n) => n.id), ["compras"]);
igual("Lixeira: a apagada por último primeiro", N.filtrar(varias, "lixeira", "").map((n) => n.id), ["lixo2", "lixo1"]);
igual("busca sem acento acha com acento", N.filtrar(varias, "todas", "area").map((n) => n.id), ["nova"]);
igual("busca com acento acha sem acento", N.filtrar(varias, "todas", "RECEITA DE PÃO").map((n) => n.id), ["velha"]);
igual("busca olha o texto sem as marcas", N.filtrar(varias, "todas", "fermento").map((n) => n.id), ["velha"]);
igual("busca olha os itens da lista", N.filtrar(varias, "todas", "acucar").map((n) => n.id), ["compras"]);
igual("várias palavras: todas precisam estar", N.filtrar(varias, "todas", "pão água").map((n) => n.id), ["velha"]);
igual("busca não acha o que está na Lixeira em Todas", N.filtrar(varias, "todas", "rascunho").map((n) => n.id), []);
igual("busca na Lixeira", N.filtrar(varias, "lixeira", "rascunho").map((n) => n.id), ["lixo2"]);
igual("contagem das páginas", N.contar(varias), { todas: 4, fixadas: 1, listas: 1, lixeira: 2 });

console.log("título, prévia e contagem");
igual("título escrito", N.tituloVisivel(varias[0], "Nova nota"), "Receita de pão");
igual("sem título: primeira linha do texto, sem marcas", N.tituloVisivel(nota("x", { texto: "\n**Ideia** boa\nresto" }), "Nova nota"), "Ideia boa");
igual("sem nada: a reserva", N.tituloVisivel(nota("x", {}), "Nova nota"), "Nova nota");
igual("lista sem título: o primeiro item", N.tituloVisivel(nota("x", { tipo: "lista", itens: [{ texto: " " }, { texto: "Leite" }] }), "Nova lista"), "Leite");
igual("prévia junta as linhas", N.previa(nota("x", { titulo: "T", texto: "um\n\n*dois*\ntrês" })), "um dois três");
igual("prévia não repete o que virou título", N.previa(nota("x", { texto: "Título\ncorpo" })), "corpo");
igual("prévia da lista mostra o que falta", N.previa(varias[3]), "Café");
confere("prévia longa termina em reticências", N.previa(nota("x", { titulo: "T", texto: "a".repeat(300) }), 50).length === 50 && N.previa(nota("x", { titulo: "T", texto: "a".repeat(300) }), 50).endsWith("…"));
igual("palavras com acento e hífen", N.contarPalavras("Olá, mundo! Guarda-chuva d'água 2026 — ok"), 6);
igual("sem palavras", N.contarPalavras("  \n — "), 0);
igual("itens feitos e total (vazios não contam)", N.contarItens([{ texto: "a", feito: true }, { texto: "b", feito: false }, { texto: " ", feito: false }]), { feitos: 1, total: 2 });

console.log("texto e lista");
igual("texto vira itens", N.textoParaItens("Leite\n\n- Pão\n- [x] Café\n• **Ovos**\n[ ] Sal", AGORA).map((i) => [i.texto, i.feito]),
  [["Leite", false], ["Pão", false], ["Café", true], ["Ovos", false], ["Sal", false]]);
igual("itens viram texto (asterisco protegido)", N.itensParaTexto([{ texto: "a*b" }, { texto: " " }, { texto: "c", feito: true }]), "a\\*b\nc");

console.log("datas");
const min = 60000, hora = 60 * min;
igual("agora", N.quando(AGORA - 20000, AGORA, "pt"), "agora");
igual("há 5 min", N.quando(AGORA - 5 * min, AGORA, "pt"), "há 5 min");
igual("há 3 h", N.quando(AGORA - 3 * hora, AGORA, "pt"), "há 3 h");
igual("ontem (mesmo com menos de 24 h)", N.quando(new Date(2026, 10, 11, 23, 50).getTime(), AGORA, "pt"), "ontem");
igual("dia da semana", N.quando(new Date(2026, 10, 9, 10, 0).getTime(), AGORA, "pt"), "segunda");
igual("12 de nov.", N.quando(new Date(2026, 9, 3, 10, 0).getTime(), AGORA, "pt"), "3 de out.");
igual("outro ano", N.quando(new Date(2025, 0, 7, 10, 0).getTime(), AGORA, "pt"), "7 de jan. de 2025");
igual("em inglês", [N.quando(AGORA - 5 * min, AGORA, "en"), N.quando(AGORA - N.DIA, AGORA, "en"), N.quando(new Date(2026, 9, 3).getTime(), AGORA, "en")], ["5 min ago", "yesterday", "Oct 3"]);
igual("data completa", N.dataCompleta(new Date(2026, 10, 12, 9, 5).getTime(), "pt"), "12 de novembro de 2026, 09:05");
igual("data completa em inglês", N.dataCompleta(new Date(2026, 10, 12, 21, 5).getTime(), "en"), "November 12, 2026, 21:05");

console.log("realce da busca");
igual("realça sem ligar para acento", N.realcar("Café com pão", "cafe", "<b>", "</b>"), "<b>Café</b> com pão");
igual("escapa o resto", N.realcar("<a> & b", "b", "<b>", "</b>"), "&lt;a&gt; &amp; <b>b</b>");
igual("realce padrão é um fundo amarelo", N.realcar("Ação", "acao"), '<span style="background-color:#ffe08a;">Ação</span>');
igual("vários termos", N.realcar("pão de queijo", "queijo pao", "[", "]"), "[pão] de [queijo]");
igual("sem busca, só escapa", N.realcar("x < y", ""), "x &lt; y");

console.log("cores");
confere("seis cores pastel", N.CORES.length === 6);
confere("nenhuma é azul forte (matiz de azul com muita saturação)", N.CORES.every((c) => {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(c.tom.substr(i, 2), 16) / 255);
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, d = mx - mn;
  const sat = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1));
  let h = 0;
  if (d) h = mx === r ? 60 * (((g - b) / d) % 6) : mx === g ? 60 * ((b - r) / d + 2) : 60 * ((r - g) / d + 4);
  if (h < 0) h += 360;
  return !(h >= 195 && h <= 250 && sat > 0.45);
}));
confere("cor por id", N.cor("menta").pt === "Menta" && N.cor("x") === null);

console.log("\n" + passou + " ok, " + falhou + " com falha");
process.exit(falhou ? 1 : 0);
