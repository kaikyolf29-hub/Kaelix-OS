.pragma library
// A parte do Notas que não desenha nada: o arquivo das notas, a busca, a ordem,
// o "há 5 min", a contagem de palavras, a Lixeira e o texto com negrito e itálico.
// Tudo puro (sem QML), para dar para testar com o node: tests/test_notas.js.
//
// O texto de uma nota fica guardado como linhas com marcas leves, no jeito do
// Markdown: **negrito** e *itálico*; uma barra invertida protege o caractere
// seguinte (\* é um asterisco de verdade). O editor é um TextEdit em RichText:
// marcasParaHtml monta o HTML que ele lê, e htmlParaMarcas lê o HTML que ele dá
// (o toHtml do Qt) de volta para as marcas. Assim o arquivo continua legível e
// nada da formatação de fora (fonte, cor, tamanho) entra na nota.

var VERSAO = 1;
var DIAS_LIXEIRA = 30;
var DIA = 86400000;

// As cores das notas: tons pastel que funcionam nos dois temas (o "tom" é o
// pontinho e, com transparência, o fundo leve). Nada de azul forte.
var CORES = [
    { id: "amarelo", pt: "Manteiga", en: "Butter", tom: "#e9c65b" },
    { id: "pessego", pt: "Pêssego", en: "Peach", tom: "#ee9f72" },
    { id: "rosa", pt: "Rosa", en: "Rose", tom: "#e98aa6" },
    { id: "lavanda", pt: "Lavanda", en: "Lavender", tom: "#a993e6" },
    { id: "menta", pt: "Menta", en: "Mint", tom: "#6fc79a" },
    { id: "nevoa", pt: "Névoa", en: "Mist", tom: "#93b3c4" }
];

function cor(id) {
    for (var i = 0; i < CORES.length; i++)
        if (CORES[i].id === id)
            return CORES[i];
    return null;
}

// ----- texto simples: sem acento e sem maiúscula, para a busca -----

function simples(s) {
    var r = String(s === undefined || s === null ? "" : s).toLowerCase();
    return r.normalize ? r.normalize("NFD").replace(/[̀-ͯ]/g, "") : r;
}

// ----- as marcas (**negrito**, *itálico*) -----

// Uma linha com marcas vira pedaços { texto, negrito, italico }.
function trechosDaLinha(linha) {
    var trechos = [];
    var atual = "";
    var negrito = false, italico = false;
    function fechar() {
        if (atual.length > 0) {
            var ultimo = trechos.length > 0 ? trechos[trechos.length - 1] : null;
            if (ultimo && ultimo.negrito === negrito && ultimo.italico === italico)
                ultimo.texto += atual;
            else
                trechos.push({ texto: atual, negrito: negrito, italico: italico });
        }
        atual = "";
    }
    for (var i = 0; i < linha.length; i++) {
        var c = linha[i];
        if (c === "\\" && i + 1 < linha.length) {
            atual += linha[i + 1];
            i++;
        } else if (c === "*" && linha[i + 1] === "*") {
            fechar();
            negrito = !negrito;
            i++;
        } else if (c === "*") {
            fechar();
            italico = !italico;
        } else {
            atual += c;
        }
    }
    fechar();
    return trechos;
}

function escapar(texto) {
    return String(texto).replace(/\\/g, "\\\\").replace(/\*/g, "\\*");
}

// Pedaços de volta para uma linha com marcas. Os vizinhos com o mesmo jeito se
// juntam, e cada linha fecha o que abriu (uma linha nunca depende da outra).
function linhaDosTrechos(trechos) {
    var s = "";
    var negrito = false, italico = false;
    for (var i = 0; i < trechos.length; i++) {
        var t = trechos[i];
        if (!t.texto)
            continue;
        if (italico && !t.italico) {
            s += "*";
            italico = false;
        }
        if (negrito !== !!t.negrito) {
            s += "**";
            negrito = !!t.negrito;
        }
        if (!italico && t.italico) {
            s += "*";
            italico = true;
        }
        s += escapar(t.texto);
    }
    if (italico)
        s += "*";
    if (negrito)
        s += "**";
    return s;
}

// O texto sem as marcas (a prévia da lista, a busca, a contagem de palavras).
function semMarcas(texto) {
    var linhas = String(texto || "").split("\n");
    var saida = [];
    for (var i = 0; i < linhas.length; i++) {
        var partes = trechosDaLinha(linhas[i]);
        var s = "";
        for (var j = 0; j < partes.length; j++)
            s += partes[j].texto;
        saida.push(s);
    }
    return saida.join("\n");
}

// ----- HTML do editor (RichText do Qt) -----

var ESTILO_P = " margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px;";

function html(texto) {
    return String(texto).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function estiloDoTrecho(t) {
    var s = "";
    if (t.negrito)
        s += " font-weight:700;";
    if (t.italico)
        s += " font-style:italic;";
    return s;
}

// Texto com marcas para o HTML que o TextEdit lê. "alturaLinha" (em %) deixa
// as linhas mais arejadas; os parágrafos novos herdam o jeito do anterior.
function marcasParaHtml(texto, alturaLinha) {
    var linhas = String(texto || "").split("\n");
    var extra = alturaLinha ? " line-height:" + Math.round(alturaLinha) + "%;" : "";
    var corpo = "";
    for (var i = 0; i < linhas.length; i++) {
        var trechos = trechosDaLinha(linhas[i]);
        if (trechos.length === 0) {
            corpo += '<p style="-qt-paragraph-type:empty;' + ESTILO_P + extra + '"><br /></p>';
            continue;
        }
        corpo += '<p style="' + ESTILO_P + extra + '">';
        for (var j = 0; j < trechos.length; j++) {
            var estilo = estiloDoTrecho(trechos[j]);
            corpo += estilo ? '<span style="' + estilo + '">' + html(trechos[j].texto) + "</span>" : html(trechos[j].texto);
        }
        corpo += "</p>";
    }
    return '<html><head><meta name="qrichtext" content="1" /><style type="text/css">p, li { white-space: pre-wrap; }</style></head><body>' + corpo + "</body></html>";
}

function entidades(s) {
    return s.replace(/&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/g, function (tudo, nome) {
        if (nome[0] === "#") {
            var n = nome[1] === "x" || nome[1] === "X" ? parseInt(nome.substring(2), 16) : parseInt(nome.substring(1), 10);
            return isNaN(n) ? tudo : String.fromCodePoint(n);
        }
        var mapa = { lt: "<", gt: ">", amp: "&", quot: "\"", apos: "'", nbsp: " " };
        return mapa.hasOwnProperty(nome) ? mapa[nome] : tudo;
    });
}

// Lê o HTML (o do toHtml do Qt, ou o que vier colado) em linhas de pedaços.
// Só negrito e itálico sobrevivem; o resto (fonte, cor, tamanho) vira texto puro.
function linhasDoHtml(codigo) {
    var s = String(codigo || "");
    var ini = s.search(/<body[^>]*>/i);
    if (ini >= 0) {
        s = s.substring(s.indexOf(">", ini) + 1);
        var fim = s.search(/<\/body>/i);
        if (fim >= 0)
            s = s.substring(0, fim);
    }
    s = s.replace(/<!--[\s\S]*?-->/g, "");
    var linhas = [];
    var linha = [];
    var pilha = [];         // { tag, negrito, italico } das marcas abertas
    var dentro = 0;         // quantos blocos (p, li, h1...) estão abertos
    var temQuebra = false;  // o último pedaço do bloco foi um <br />
    var blocos = /^(p|li|h[1-6]|div|tr|pre|blockquote|ul|ol|table)$/;
    function estado() {
        var n = false, it = false;
        for (var i = 0; i < pilha.length; i++) {
            if (pilha[i].negrito !== undefined)
                n = pilha[i].negrito;
            if (pilha[i].italico !== undefined)
                it = pilha[i].italico;
        }
        return { negrito: n, italico: it };
    }
    function empurrar() {
        linhas.push(linha);
        linha = [];
    }
    var re = /<(\/?)([a-zA-Z0-9]+)([^>]*)>|([^<]+)/g;
    var m;
    while ((m = re.exec(s)) !== null) {
        if (m[4] !== undefined) {
            var texto = entidades(m[4]);
            if (dentro === 0 && /^\s*$/.test(texto))
                continue;
            texto = texto.replace(/[\r\n]+/g, " ");
            var e = estado();
            linha.push({ texto: texto, negrito: e.negrito, italico: e.italico });
            temQuebra = false;
            continue;
        }
        var fecha = m[1] === "/";
        var tag = m[2].toLowerCase();
        var attrs = m[3] || "";
        if (tag === "br") {
            empurrar();
            temQuebra = true;
            continue;
        }
        if (blocos.test(tag)) {
            if (fecha) {
                dentro = Math.max(0, dentro - 1);
                // O <br /> no fim de um parágrafo vazio não é uma linha a mais.
                if (temQuebra && linha.length === 0) {
                    temQuebra = false;
                    continue;
                }
                if (linha.length > 0 || tag === "p" || tag === "li" || /^h[1-6]$/.test(tag))
                    empurrar();
            } else {
                if (linha.length > 0)
                    empurrar();
                dentro++;
                temQuebra = false;
            }
            continue;
        }
        if (tag === "td" || tag === "th") {
            if (fecha) {
                var e2 = estado();
                linha.push({ texto: "\t", negrito: e2.negrito, italico: e2.italico });
            }
            continue;
        }
        if (fecha) {
            for (var k = pilha.length - 1; k >= 0; k--) {
                if (pilha[k].tag === tag) {
                    pilha.splice(k, 1);
                    break;
                }
            }
            continue;
        }
        if (/\/\s*$/.test(attrs))
            continue;
        var marca = { tag: tag };
        if (tag === "b" || tag === "strong")
            marca.negrito = true;
        else if (tag === "i" || tag === "em")
            marca.italico = true;
        var estilo = /style\s*=\s*"([^"]*)"/i.exec(attrs) || /style\s*=\s*'([^']*)'/i.exec(attrs);
        if (estilo) {
            var peso = /font-weight\s*:\s*(\d+|bold|normal)/i.exec(estilo[1]);
            if (peso)
                marca.negrito = peso[1] === "bold" || (peso[1] !== "normal" && parseInt(peso[1], 10) >= 600);
            var jeito = /font-style\s*:\s*(\w+)/i.exec(estilo[1]);
            if (jeito)
                marca.italico = jeito[1] === "italic" || jeito[1] === "oblique";
        }
        pilha.push(marca);
    }
    if (linha.length > 0)
        empurrar();
    return linhas;
}

function htmlParaMarcas(codigo) {
    var linhas = linhasDoHtml(codigo);
    var saida = [];
    for (var i = 0; i < linhas.length; i++)
        saida.push(linhaDosTrechos(linhas[i]));
    // Linhas vazias no fim não fazem falta.
    while (saida.length > 0 && saida[saida.length - 1].replace(/[ \t ]/g, "") === "")
        saida.pop();
    return saida.join("\n");
}

// O jeito de um trecho (getFormattedText): se ele todo está em negrito e/ou itálico.
function jeitoDoTrecho(fragmento) {
    var linhas = linhasDoHtml(fragmento);
    var r = { negrito: false, italico: false };
    var algum = false;
    var n = true, it = true;
    for (var i = 0; i < linhas.length; i++) {
        for (var j = 0; j < linhas[i].length; j++) {
            var t = linhas[i][j];
            if (!t.texto.length)
                continue;
            algum = true;
            n = n && t.negrito;
            it = it && t.italico;
        }
    }
    if (algum) {
        r.negrito = n;
        r.italico = it;
    }
    return r;
}

// Negrito (ou itálico) num trecho escolhido de UM parágrafo: recebe o
// getFormattedText do trecho e devolve o HTML para pôr no lugar. Se o trecho
// todo já tem o jeito, tira; senão, põe em tudo ("forcar" decide quando o
// trecho é parte de uma escolha maior). Os espaços ficam como estão.
function alternarJeito(fragmento, jeito, forcar) {
    var linhas = linhasDoHtml(fragmento);
    var trechos = [];
    for (var i = 0; i < linhas.length; i++)
        trechos = trechos.concat(linhas[i]);
    var ligar = forcar === undefined ? !jeitoDoTrecho(fragmento)[jeito] : !!forcar;
    var saida = "";
    for (var k = 0; k < trechos.length; k++) {
        var t = { texto: trechos[k].texto, negrito: trechos[k].negrito, italico: trechos[k].italico };
        t[jeito] = ligar;
        saida += '<span style="white-space:pre-wrap;' + (t.negrito ? " font-weight:700;" : " font-weight:400;") + (t.italico ? " font-style:italic;" : " font-style:normal;") + '">' + html(t.texto) + "</span>";
    }
    return { html: saida, ligar: ligar };
}

// Texto puro colado (de qualquer lugar) como HTML para o TextEdit inserir sem
// formatação de fora; as quebras de linha viram parágrafos.
function coladoParaHtml(texto) {
    return '<span style="white-space:pre-wrap">' + html(String(texto).replace(/\r\n?/g, "\n")) + "</span>";
}

// ----- notas -----

function novoId(agora, sorte) {
    var r = sorte === undefined ? Math.random() : sorte;
    return "n" + Math.floor(agora).toString(36) + Math.floor(r * 1679616).toString(36);
}

function novaNota(tipo, agora, id) {
    return {
        id: id || novoId(agora),
        tipo: tipo === "lista" ? "lista" : "texto",
        titulo: "",
        texto: "",
        itens: [],
        cor: "",
        fixada: false,
        criada: agora,
        editada: agora,
        apagada: 0
    };
}

function numero(v, padrao) {
    var n = Number(v);
    return isFinite(n) && n >= 0 ? Math.floor(n) : padrao;
}

function normalizarItem(i, n, agora) {
    if (typeof i === "string")
        return { id: "i" + n + "-" + Math.floor(agora).toString(36), texto: i, feito: false };
    if (!i || typeof i !== "object")
        return null;
    return {
        id: typeof i.id === "string" && i.id ? i.id : "i" + n + "-" + Math.floor(agora).toString(36),
        texto: typeof i.texto === "string" ? i.texto.replace(/[\r\n]+/g, " ") : "",
        feito: !!i.feito
    };
}

// Uma nota lida do arquivo, conferida campo a campo (o arquivo pode ter sido
// mexido à mão). Devolve null se não der para aproveitar.
function normalizarNota(n, agora, vistos) {
    if (!n || typeof n !== "object")
        return null;
    var id = typeof n.id === "string" && n.id ? n.id : novoId(agora);
    if (vistos) {
        while (vistos[id])
            id = id + "x";
        vistos[id] = true;
    }
    var criada = numero(n.criada, agora);
    var itens = [];
    if (Array.isArray(n.itens)) {
        for (var k = 0; k < n.itens.length; k++) {
            var item = normalizarItem(n.itens[k], k, agora);
            if (item)
                itens.push(item);
        }
    }
    var c = typeof n.cor === "string" && cor(n.cor) ? n.cor : "";
    return {
        id: id,
        tipo: n.tipo === "lista" ? "lista" : "texto",
        titulo: typeof n.titulo === "string" ? n.titulo.replace(/[\r\n]+/g, " ") : "",
        texto: typeof n.texto === "string" ? n.texto.replace(/\r\n?/g, "\n") : "",
        itens: itens,
        cor: c,
        fixada: !!n.fixada,
        criada: criada,
        editada: numero(n.editada, criada),
        apagada: numero(n.apagada, 0)
    };
}

// O arquivo notas.json: { versao, notas: [...], preferencias: {...} }.
// Aceita também uma lista solta de notas. erro: "" | "vazio" | "quebrado".
function ler(texto, agora) {
    var estado = { notas: [], preferencias: { visao: "lista" }, erro: "" };
    if (!texto || !String(texto).trim()) {
        estado.erro = "vazio";
        return estado;
    }
    var dados;
    try {
        dados = JSON.parse(texto);
    } catch (e) {
        estado.erro = "quebrado";
        return estado;
    }
    var lista = Array.isArray(dados) ? dados : (dados && Array.isArray(dados.notas) ? dados.notas : null);
    if (!lista) {
        estado.erro = "quebrado";
        return estado;
    }
    var vistos = {};
    for (var i = 0; i < lista.length; i++) {
        var n = normalizarNota(lista[i], agora, vistos);
        if (n)
            estado.notas.push(n);
    }
    if (dados && dados.preferencias && typeof dados.preferencias === "object") {
        var p = dados.preferencias;
        estado.preferencias.visao = p.visao === "grade" ? "grade" : "lista";
    }
    return estado;
}

function gravar(notas, preferencias) {
    return JSON.stringify({ versao: VERSAO, notas: notas, preferencias: preferencias || { visao: "lista" } }, null, 1) + "\n";
}

// Tira da Lixeira o que passou de 30 dias.
function limparLixeira(notas, agora, dias) {
    var limite = (dias === undefined ? DIAS_LIXEIRA : dias) * DIA;
    var ficam = [];
    var saem = 0;
    for (var i = 0; i < notas.length; i++) {
        if (notas[i].apagada > 0 && agora - notas[i].apagada >= limite)
            saem++;
        else
            ficam.push(notas[i]);
    }
    return { notas: ficam, removidas: saem };
}

function diasRestantes(apagada, agora, dias) {
    var total = dias === undefined ? DIAS_LIXEIRA : dias;
    return Math.max(0, Math.ceil(total - (agora - apagada) / DIA));
}

// Tudo o que a busca olha numa nota, já simplificado.
function textoDaNota(n) {
    var partes = [n.titulo, semMarcas(n.texto)];
    for (var i = 0; i < n.itens.length; i++)
        partes.push(n.itens[i].texto);
    return partes.join("\n");
}

function combina(n, busca) {
    var termos = simples(busca).split(/\s+/).filter(function (t) { return t.length > 0; });
    if (termos.length === 0)
        return true;
    var alvo = simples(textoDaNota(n));
    for (var i = 0; i < termos.length; i++)
        if (alvo.indexOf(termos[i]) < 0)
            return false;
    return true;
}

// As notas de uma página da lista à esquerda, na ordem da tela: fixadas
// primeiro e depois a mais recente; na Lixeira, a apagada por último primeiro.
function filtrar(notas, pagina, busca) {
    var r = [];
    for (var i = 0; i < notas.length; i++) {
        var n = notas[i];
        var naLixeira = n.apagada > 0;
        if (pagina === "lixeira" ? !naLixeira : naLixeira)
            continue;
        if (pagina === "fixadas" && !n.fixada)
            continue;
        if (pagina === "listas" && n.tipo !== "lista")
            continue;
        if (busca && !combina(n, busca))
            continue;
        r.push(n);
    }
    r.sort(function (a, b) {
        if (pagina === "lixeira")
            return b.apagada - a.apagada || b.editada - a.editada;
        if (a.fixada !== b.fixada)
            return a.fixada ? -1 : 1;
        return b.editada - a.editada || (a.id < b.id ? -1 : 1);
    });
    return r;
}

function contar(notas) {
    var c = { todas: 0, fixadas: 0, listas: 0, lixeira: 0 };
    for (var i = 0; i < notas.length; i++) {
        var n = notas[i];
        if (n.apagada > 0) {
            c.lixeira++;
            continue;
        }
        c.todas++;
        if (n.fixada)
            c.fixadas++;
        if (n.tipo === "lista")
            c.listas++;
    }
    return c;
}

// O título que aparece: o que a pessoa escreveu, ou a primeira linha do texto.
function tituloVisivel(n, reserva) {
    var t = (n.titulo || "").trim();
    if (t)
        return t;
    if (n.tipo === "lista") {
        for (var i = 0; i < n.itens.length; i++)
            if (n.itens[i].texto.trim())
                return n.itens[i].texto.trim();
    } else {
        var linhas = semMarcas(n.texto).split("\n");
        for (var j = 0; j < linhas.length; j++)
            if (linhas[j].trim())
                return linhas[j].trim();
    }
    return reserva || "";
}

// O começo do texto, numa linha só (sem repetir o que já virou título).
function previa(n, maximo) {
    var max = maximo || 160;
    var partes = [];
    var pulou = !!(n.titulo || "").trim();
    if (n.tipo === "lista") {
        for (var i = 0; i < n.itens.length; i++) {
            var t = n.itens[i].texto.trim();
            if (!t)
                continue;
            if (!pulou) {
                pulou = true;
                continue;
            }
            if (!n.itens[i].feito)
                partes.push(t);
        }
    } else {
        var linhas = semMarcas(n.texto).split("\n");
        for (var j = 0; j < linhas.length; j++) {
            var l = linhas[j].trim();
            if (!l)
                continue;
            if (!pulou) {
                pulou = true;
                continue;
            }
            partes.push(l);
        }
    }
    var s = partes.join(n.tipo === "lista" ? " · " : " ");
    return s.length > max ? s.substring(0, max - 1).replace(/\s+$/, "") + "…" : s;
}

function contarPalavras(texto) {
    var m = String(texto || "").match(/[0-9A-Za-zÀ-ÖØ-öø-ÿĀ-ɏͰ-ϿЀ-ӿ]+(['’-][0-9A-Za-zÀ-ÖØ-öø-ÿĀ-ɏ]+)*/g);
    return m ? m.length : 0;
}

function contarItens(itens) {
    var feitos = 0, total = 0;
    for (var i = 0; i < itens.length; i++) {
        if (!itens[i].texto.trim() && !itens[i].feito)
            continue;
        total++;
        if (itens[i].feito)
            feitos++;
    }
    return { feitos: feitos, total: total };
}

// Texto para lista: cada linha com algo vira um item ("- [x]" e "•" saem).
function textoParaItens(texto, agora) {
    var linhas = semMarcas(texto).split("\n");
    var itens = [];
    for (var i = 0; i < linhas.length; i++) {
        var l = linhas[i].trim();
        if (!l)
            continue;
        var feito = false;
        var m = /^[-*+•◦▪]?\s*\[( |x|X)\]\s*(.*)$/.exec(l);
        if (m) {
            feito = m[1] !== " ";
            l = m[2];
        } else {
            l = l.replace(/^[-*+•◦▪]\s+/, "");
        }
        itens.push({ id: "i" + i + "-" + Math.floor(agora).toString(36), texto: l, feito: feito });
    }
    return itens;
}

function itensParaTexto(itens) {
    var linhas = [];
    for (var i = 0; i < itens.length; i++) {
        var t = itens[i].texto.trim();
        if (t)
            linhas.push(escapar(t));
    }
    return linhas.join("\n");
}

// ----- datas -----

var MESES_PT = ["jan.", "fev.", "mar.", "abr.", "mai.", "jun.", "jul.", "ago.", "set.", "out.", "nov.", "dez."];
var MESES_PT_LONGOS = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];
var MESES_EN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
var MESES_EN_LONGOS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
var DIAS_PT = ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"];
var DIAS_EN = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

function inicioDoDia(d) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

function hora(d) {
    function dois(n) {
        return n < 10 ? "0" + n : String(n);
    }
    return dois(d.getHours()) + ":" + dois(d.getMinutes());
}

// "agora", "há 5 min", "há 3 h", "ontem", "terça", "12 de nov.", "12 de nov. de 2025".
function quando(ms, agora, lingua) {
    var pt = lingua !== "en";
    var d = new Date(ms);
    var a = new Date(agora);
    var dif = agora - ms;
    var dias = Math.round((inicioDoDia(a) - inicioDoDia(d)) / DIA);
    if (dif < 60000 && dias <= 0)
        return pt ? "agora" : "now";
    if (dias <= 0) {
        if (dif < 3600000) {
            var min = Math.floor(dif / 60000);
            return pt ? "há " + min + " min" : min + " min ago";
        }
        var h = Math.floor(dif / 3600000);
        return pt ? "há " + h + " h" : h + " h ago";
    }
    if (dias === 1)
        return pt ? "ontem" : "yesterday";
    if (dias < 7)
        return pt ? DIAS_PT[d.getDay()] : DIAS_EN[d.getDay()];
    var mesmoAno = d.getFullYear() === a.getFullYear();
    if (pt)
        return d.getDate() + " de " + MESES_PT[d.getMonth()] + (mesmoAno ? "" : " de " + d.getFullYear());
    return MESES_EN[d.getMonth()] + " " + d.getDate() + (mesmoAno ? "" : ", " + d.getFullYear());
}

// Data completa, para o alto do editor: "12 de novembro de 2026, 14:32".
function dataCompleta(ms, lingua) {
    var d = new Date(ms);
    if (lingua === "en")
        return MESES_EN_LONGOS[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear() + ", " + hora(d);
    return d.getDate() + " de " + MESES_PT_LONGOS[d.getMonth()] + " de " + d.getFullYear() + ", " + hora(d);
}

// ----- busca: realçar o que foi achado -----

// HTML (para um Text em StyledText) com os pedaços achados realçados. A busca não
// liga para acento: "cafe" acha "Café" e realça a palavra como ela está escrita.
// "abre" e "fecha" são as marcas em volta do achado (no padrão, um fundo amarelo).
function realcar(texto, busca, abre, fecha) {
    var original = String(texto || "");
    var termos = simples(busca).split(/\s+/).filter(function (t) { return t.length > 0; });
    if (termos.length === 0)
        return html(original);
    // Cada letra simplificada aponta para a letra original de onde veio.
    var simplificado = "";
    var origem = [];
    for (var i = 0; i < original.length; i++) {
        var s = simples(original[i]);
        for (var k = 0; k < s.length; k++) {
            simplificado += s[k];
            origem.push(i);
        }
    }
    var marcado = [];
    for (var t = 0; t < termos.length; t++) {
        var de = 0, pos;
        while ((pos = simplificado.indexOf(termos[t], de)) >= 0) {
            for (var p = pos; p < pos + termos[t].length; p++)
                marcado[origem[p]] = true;
            de = pos + termos[t].length;
        }
    }
    var saida = "";
    var aberto = false;
    for (var j = 0; j < original.length; j++) {
        if (marcado[j] && !aberto) {
            saida += abre === undefined ? '<span style="background-color:#ffe08a;">' : abre;
            aberto = true;
        } else if (!marcado[j] && aberto) {
            saida += fecha === undefined ? "</span>" : fecha;
            aberto = false;
        }
        saida += html(original[j]);
    }
    if (aberto)
        saida += fecha === undefined ? "</span>" : fecha;
    return saida;
}
