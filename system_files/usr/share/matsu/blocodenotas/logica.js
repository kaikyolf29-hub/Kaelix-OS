.pragma library
// A parte do Bloco de notas que não depende da tela: fim de linha, busca,
// linha e coluna, nomes, a sessão (as abas que voltam ao abrir) e os ajustes.
// Sem nada do Qt aqui dentro, para os testes rodarem no node
// (tests/test_blocodenotas.py tira a linha ".pragma library" e roda este arquivo).

// ----- fim de linha -----

// O fim de linha que o texto usa mais: "crlf" (Windows), "lf" (Linux e Mac) ou
// "cr" (Mac antigo). Sem nenhuma quebra, "" (quem chama decide o padrão).
function detectarFim(texto) {
    var crlf = 0, lf = 0, cr = 0;
    var s = String(texto);
    for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        if (c === 13) {
            if (s.charCodeAt(i + 1) === 10) {
                crlf++;
                i++;
            } else {
                cr++;
            }
        } else if (c === 10) {
            lf++;
        }
    }
    if (crlf === 0 && lf === 0 && cr === 0)
        return "";
    if (crlf >= lf && crlf >= cr)
        return "crlf";
    return lf >= cr ? "lf" : "cr";
}

// O editor trabalha só com "\n"; o arquivo volta com o fim de linha dele.
function paraEditor(texto) {
    return String(texto).replace(/\r\n?/g, "\n");
}

function paraArquivo(texto, fim) {
    var s = String(texto);
    if (fim === "crlf")
        return s.replace(/\n/g, "\r\n");
    if (fim === "cr")
        return s.replace(/\n/g, "\r");
    return s;
}

function nomeFim(fim, pt) {
    if (fim === "crlf")
        return "Windows (CRLF)";
    if (fim === "cr")
        return pt ? "Mac antigo (CR)" : "Classic Mac (CR)";
    return "Unix (LF)";
}

function nomeCodificacao(c, pt) {
    return ({
        "utf-8": "UTF-8",
        "utf-8-bom": pt ? "UTF-8 com BOM" : "UTF-8 with BOM",
        "utf-16-le": "UTF-16 LE",
        "utf-16-be": "UTF-16 BE",
        "windows-1252": "ANSI (Windows-1252)",
        "iso-8859-1": "ISO-8859-1"
    })[c] || "UTF-8";
}

// Para quando o ajudante não responde: o texto lido como UTF-8 tem o caractere
// nulo (arquivo de programa, imagem...) ou muitos caracteres de controle ou trocados.
function pareceBinario(texto) {
    var s = String(texto).substring(0, 8000);
    if (s.length === 0)
        return false;
    var estranhos = 0;
    for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        if (c === 0)
            return true;
        if ((c < 32 && c !== 9 && c !== 10 && c !== 13 && c !== 12 && c !== 8 && c !== 27) || c === 0xfffd)
            estranhos++;
    }
    return estranhos / s.length > 0.1;
}

// ----- linhas e colunas -----

// Linha e coluna (começando em 1) de uma posição do texto, como no "Ln 12, Col 4".
function linhaColuna(texto, pos) {
    var s = String(texto);
    var p = Math.max(0, Math.min(pos, s.length));
    var linha = 1;
    var i = s.indexOf("\n");
    var inicio = 0;
    while (i !== -1 && i < p) {
        linha++;
        inicio = i + 1;
        i = s.indexOf("\n", i + 1);
    }
    return { linha: linha, coluna: p - inicio + 1 };
}

function contarLinhas(texto) {
    var s = String(texto);
    var n = 1;
    var i = s.indexOf("\n");
    while (i !== -1) {
        n++;
        i = s.indexOf("\n", i + 1);
    }
    return n;
}

// Onde começa a linha n (1 é a primeira); -1 se o texto não tem essa linha.
function inicioDaLinha(texto, n) {
    var s = String(texto);
    if (n < 1)
        return -1;
    var pos = 0;
    for (var l = 1; l < n; l++) {
        var i = s.indexOf("\n", pos);
        if (i === -1)
            return -1;
        pos = i + 1;
    }
    return pos;
}

// O começo de cada linha (para os números de linha com a quebra ligada).
function iniciosDasLinhas(texto) {
    var s = String(texto);
    var r = [0];
    var i = s.indexOf("\n");
    while (i !== -1) {
        r.push(i + 1);
        i = s.indexOf("\n", i + 1);
    }
    return r;
}

// Índice da última linha que começa em pos ou antes (busca binária).
function linhaDaPosicao(inicios, pos) {
    var a = 0, b = inicios.length - 1;
    while (a < b) {
        var m = (a + b + 1) >> 1;
        if (inicios[m] <= pos)
            a = m;
        else
            b = m - 1;
    }
    return a;
}

// ----- busca -----

function escapar(s) {
    return String(s).replace(/[.*+?^${}()|[\]\\\/]/g, "\\$&");
}

// Letra (de qualquer língua), número ou "_": o que conta como parte de uma palavra.
function ehDePalavra(c) {
    if (!c)
        return false;
    if (c === "_" || (c >= "0" && c <= "9"))
        return true;
    return c.toLowerCase() !== c.toUpperCase();
}

// Onde a consulta aparece: a lista dos começos (o tamanho de cada achado é o
// tamanho da consulta). "maiusculas": diferencia A de a; "palavra": só a
// palavra inteira (não acha "sol" dentro de "girassol"). No máximo "limite".
function buscar(texto, consulta, maiusculas, palavra, limite) {
    var r = [];
    var q = String(consulta);
    if (q.length === 0)
        return r;
    var s = String(texto);
    var max = limite || 10000;
    var re = new RegExp(escapar(q), maiusculas ? "g" : "gi");
    var m;
    while ((m = re.exec(s)) !== null) {
        var i = m.index;
        var f = i + m[0].length;
        if (!palavra || (!ehDePalavra(s.charAt(i - 1)) && !ehDePalavra(s.charAt(f))))
            r.push(i);
        if (r.length >= max)
            break;
        // Sem achados sobrepostos, como no Bloco de Notas do Windows.
        re.lastIndex = f > i ? f : i + 1;
    }
    return r;
}

// O primeiro achado que começa em pos ou depois (dá a volta para o primeiro).
function proximoAchado(achados, pos) {
    if (achados.length === 0)
        return -1;
    var a = 0, b = achados.length;
    while (a < b) {
        var m = (a + b) >> 1;
        if (achados[m] < pos)
            a = m + 1;
        else
            b = m;
    }
    return a < achados.length ? a : 0;
}

// O último achado que começa antes de pos (dá a volta para o último).
function achadoAnterior(achados, pos) {
    if (achados.length === 0)
        return -1;
    var a = 0, b = achados.length;
    while (a < b) {
        var m = (a + b) >> 1;
        if (achados[m] < pos)
            a = m + 1;
        else
            b = m;
    }
    return a > 0 ? a - 1 : achados.length - 1;
}

// Trocar todas: devolve o trecho que muda (do primeiro ao último achado) já
// trocado, para o editor fazer uma troca só (e o Ctrl+Z desfazer de uma vez).
function trocarTudo(texto, consulta, troca, maiusculas, palavra) {
    var s = String(texto);
    var achados = buscar(s, consulta, maiusculas, palavra, 1000000);
    if (achados.length === 0)
        return { n: 0, inicio: 0, fim: 0, trecho: "" };
    var tam = String(consulta).length;
    var inicio = achados[0];
    var fim = achados[achados.length - 1] + tam;
    var partes = [];
    var pos = inicio;
    for (var k = 0; k < achados.length; k++) {
        partes.push(s.substring(pos, achados[k]));
        partes.push(troca);
        pos = achados[k] + tam;
    }
    return { n: achados.length, inicio: inicio, fim: fim, trecho: partes.join("") };
}

// ----- caminhos e nomes -----

// Argumento da linha de comando ou endereço "file://" para o caminho do arquivo.
function caminhoLocal(arg) {
    var s = String(arg || "");
    if (s.indexOf("file://") === 0) {
        s = s.substring(7);
        try {
            s = decodeURIComponent(s);
        } catch (e) {
        }
    }
    return s;
}

function nomeDoCaminho(caminho) {
    var s = String(caminho || "");
    var i = s.lastIndexOf("/");
    return i >= 0 ? s.substring(i + 1) : s;
}

function pastaDoCaminho(caminho) {
    var s = String(caminho || "");
    var i = s.lastIndexOf("/");
    return i > 0 ? s.substring(0, i) : (i === 0 ? "/" : "");
}

// A pasta com "~" no lugar da pasta pessoal: "~/Documentos".
function pastaCurta(caminho, casa) {
    var p = pastaDoCaminho(caminho);
    if (casa && (p === casa || p.indexOf(casa + "/") === 0))
        return "~" + p.substring(casa.length);
    return p;
}

// "Sem título", "Sem título 2", "Sem título 3"... o primeiro número livre.
function proximoSemTitulo(nomes, base) {
    var usados = {};
    for (var i = 0; i < nomes.length; i++)
        usados[nomes[i]] = true;
    if (!usados[base])
        return base;
    for (var n = 2; ; n++) {
        if (!usados[base + " " + n])
            return base + " " + n;
    }
}

// ----- ajustes e recentes -----

var PADRAO = {
    quebra: true,
    barraStatus: true,
    numeros: false,
    fonte: "mono",
    tamanho: 11,
    zoom: 100,
    lembrar: true,
    recentes: []
};

function limitar(v, a, b, padrao) {
    var n = Number(v);
    if (!isFinite(n))
        return padrao;
    return Math.max(a, Math.min(b, n));
}

// Os ajustes guardados, com o padrão no que faltar ou vier estragado.
function lerAjustes(texto) {
    var d = {};
    try {
        d = JSON.parse(texto || "{}") || {};
    } catch (e) {
        d = {};
    }
    if (typeof d !== "object" || Array.isArray(d))
        d = {};
    function bool(v, p) {
        return typeof v === "boolean" ? v : p;
    }
    var recentes = [];
    if (Array.isArray(d.recentes)) {
        for (var i = 0; i < d.recentes.length && recentes.length < 10; i++) {
            var r = d.recentes[i];
            if (typeof r === "string" && r.charAt(0) === "/" && recentes.indexOf(r) === -1)
                recentes.push(r);
        }
    }
    return {
        quebra: bool(d.quebra, PADRAO.quebra),
        barraStatus: bool(d.barraStatus, PADRAO.barraStatus),
        numeros: bool(d.numeros, PADRAO.numeros),
        fonte: d.fonte === "inter" ? "inter" : "mono",
        tamanho: Math.round(limitar(d.tamanho, 6, 48, PADRAO.tamanho)),
        zoom: Math.round(limitar(d.zoom, 10, 500, PADRAO.zoom)),
        lembrar: bool(d.lembrar, PADRAO.lembrar),
        recentes: recentes
    };
}

// O arquivo vai para o começo da lista (sem repetir), no máximo "max".
function adicionarRecente(lista, caminho, max) {
    var r = [caminho];
    for (var i = 0; i < lista.length && r.length < (max || 10); i++) {
        if (lista[i] !== caminho)
            r.push(lista[i]);
    }
    return r;
}

// ----- sessão -----

var CODIFICACOES = ["utf-8", "utf-8-bom", "utf-16-le", "utf-16-be", "windows-1252", "iso-8859-1"];

// Uma aba como vai para a sessão. O texto só vai quando precisa: aba sem
// arquivo ou com mudanças não salvas. As outras voltam lendo o arquivo.
function abaParaSessao(a) {
    var precisaTexto = !a.caminho || a.modificado;
    return {
        caminho: a.caminho || "",
        nome: a.nome || "",
        texto: precisaTexto ? String(a.texto || "") : null,
        modificado: !!a.modificado,
        fim: a.fim || "lf",
        codificacao: a.codificacao || "utf-8",
        cursor: Math.max(0, Math.floor(Number(a.cursor) || 0)),
        rolagem: Math.max(0, Number(a.rolagem) || 0)
    };
}

function montarSessao(abas, atual) {
    var lista = [];
    for (var i = 0; i < abas.length; i++)
        lista.push(abaParaSessao(abas[i]));
    return JSON.stringify({ versao: 1, atual: Math.max(0, Math.min(atual, lista.length - 1)), abas: lista });
}

// A sessão guardada, conferida: abas sem arquivo e sem texto (vazias) não
// voltam, valores estragados viram o padrão, "atual" sempre aponta para uma aba.
function lerSessao(texto) {
    var d;
    try {
        d = JSON.parse(texto || "");
    } catch (e) {
        return { atual: 0, abas: [] };
    }
    if (!d || typeof d !== "object" || !Array.isArray(d.abas))
        return { atual: 0, abas: [] };
    var abas = [];
    var atualOriginal = Math.floor(Number(d.atual) || 0);
    var atual = 0;
    for (var i = 0; i < d.abas.length; i++) {
        var a = d.abas[i];
        if (!a || typeof a !== "object")
            continue;
        var caminho = typeof a.caminho === "string" && a.caminho.charAt(0) === "/" ? a.caminho : "";
        var temTexto = typeof a.texto === "string";
        if (!caminho && (!temTexto || a.texto.length === 0))
            continue;
        if (i <= atualOriginal)
            atual = abas.length;
        abas.push({
            caminho: caminho,
            nome: typeof a.nome === "string" && a.nome ? a.nome : (caminho ? nomeDoCaminho(caminho) : ""),
            texto: temTexto ? a.texto : null,
            modificado: temTexto && (!!a.modificado || !caminho),
            fim: a.fim === "crlf" || a.fim === "cr" ? a.fim : "lf",
            codificacao: CODIFICACOES.indexOf(a.codificacao) >= 0 ? a.codificacao : "utf-8",
            cursor: Math.max(0, Math.floor(Number(a.cursor) || 0)),
            rolagem: Math.max(0, Number(a.rolagem) || 0)
        });
    }
    return { atual: abas.length ? Math.min(atual, abas.length - 1) : 0, abas: abas };
}
