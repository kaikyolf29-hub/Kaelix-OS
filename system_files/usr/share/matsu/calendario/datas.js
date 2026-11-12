.pragma library
// Contas de datas do Calendário do Matsu: nomes em português, semana começando no
// domingo, feriados nacionais do Brasil e as repetições dos eventos. O ajudante.py
// faz as mesmas contas (para os lembretes e o .ics); os testes conferem as duas.
//
// Um evento é um objeto simples, como fica guardado no eventos.json:
//   { id, titulo, diaTodo, inicio, fim, cor, lembrete, repetir, ate, excecoes, local, notas }
//   inicio/fim: "2026-11-12T09:00" (hora local) ou "2026-11-12" no dia todo (fim incluído)
//   repetir: "nunca" | "dia" | "semana" | "mes" | "ano"; ate: último dia da série ("" = sempre)
//   excecoes: dias da série que foram apagados ("2026-11-19")

var DIAS = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"];
var DIAS_EN = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
var DIAS_CURTOS = ["dom.", "seg.", "ter.", "qua.", "qui.", "sex.", "sáb."];
var DIAS_CURTOS_EN = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
var INICIAIS = ["D", "S", "T", "Q", "Q", "S", "S"];
var INICIAIS_EN = ["S", "M", "T", "W", "T", "F", "S"];
var MESES = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];
var MESES_EN = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
var MESES_CURTOS = ["jan.", "fev.", "mar.", "abr.", "mai.", "jun.", "jul.", "ago.", "set.", "out.", "nov.", "dez."];
var MESES_CURTOS_EN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// A hora em que o lembrete de um evento de dia todo conta como "começo".
var HORA_DIA_TODO = 9;

function dois(n) {
    return n < 10 ? "0" + n : String(n);
}

// ----- dias como texto ("2026-11-12") e como Date (meia-noite local) -----
function chave(d) {
    return d.getFullYear() + "-" + dois(d.getMonth() + 1) + "-" + dois(d.getDate());
}
function momento(d) {
    return chave(d) + "T" + dois(d.getHours()) + ":" + dois(d.getMinutes());
}
function ler(texto) {
    var p = String(texto).split(/[-T:]/);
    return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]), p.length > 3 ? Number(p[3]) : 0, p.length > 4 ? Number(p[4]) : 0);
}
function meiaNoite(d) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}
function hoje() {
    return meiaNoite(new Date());
}
function somarDias(d, n) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n, d.getHours(), d.getMinutes());
}
function diasNoMes(ano, mes) {
    return new Date(ano, mes + 1, 0).getDate();
}
// Mesmo dia em outro mês; no mês mais curto, o último dia dele (31 de jan. + 1 mês = 28 de fev.).
function somarMeses(d, n) {
    var alvo = new Date(d.getFullYear(), d.getMonth() + n, 1);
    var diaMes = Math.min(d.getDate(), diasNoMes(alvo.getFullYear(), alvo.getMonth()));
    return new Date(alvo.getFullYear(), alvo.getMonth(), diaMes, d.getHours(), d.getMinutes());
}
// Dias inteiros de a até b (ignora a hora e o horário de verão).
function diasEntre(a, b) {
    return Math.round((Date.UTC(b.getFullYear(), b.getMonth(), b.getDate()) - Date.UTC(a.getFullYear(), a.getMonth(), a.getDate())) / 86400000);
}
function mesmoDia(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}
// A semana começa no domingo, como no Brasil.
function inicioSemana(d) {
    return somarDias(meiaNoite(d), -d.getDay());
}
function inicioMes(d) {
    return new Date(d.getFullYear(), d.getMonth(), 1);
}
// O primeiro domingo da grade do mês e quantas semanas ela tem (4 a 6).
function gradeMes(d) {
    var primeiro = inicioMes(d);
    var comeco = inicioSemana(primeiro);
    var total = diasEntre(comeco, primeiro) + diasNoMes(d.getFullYear(), d.getMonth());
    return { inicio: comeco, semanas: Math.ceil(total / 7) };
}

// ----- textos -----
function hora(d) {
    return dois(d.getHours()) + ":" + dois(d.getMinutes());
}
function minutos(d) {
    return d.getHours() * 60 + d.getMinutes();
}
function deMinutos(m) {
    return dois(Math.floor(m / 60) % 24) + ":" + dois(m % 60);
}
// "novembro de 2026" / "November 2026"
function tituloMes(d, pt) {
    return pt ? MESES[d.getMonth()] + " de " + d.getFullYear() : MESES_EN[d.getMonth()] + " " + d.getFullYear();
}
// "qua., 12 de nov." / "Wed, Nov 12"
function dataCurta(d, pt) {
    return pt ? DIAS_CURTOS[d.getDay()] + ", " + d.getDate() + " de " + MESES_CURTOS[d.getMonth()]
              : DIAS_CURTOS_EN[d.getDay()] + ", " + MESES_CURTOS_EN[d.getMonth()] + " " + d.getDate();
}
// "qua., 12 de nov. de 2027" quando não é deste ano.
function dataCurtaAno(d, pt) {
    if (d.getFullYear() === new Date().getFullYear())
        return dataCurta(d, pt);
    return pt ? dataCurta(d, pt) + " de " + d.getFullYear() : dataCurta(d, pt) + ", " + d.getFullYear();
}
// "quinta-feira, 12 de novembro de 2026" / "Thursday, November 12, 2026"
function dataLonga(d, pt) {
    return pt ? DIAS[d.getDay()] + ", " + d.getDate() + " de " + MESES[d.getMonth()] + " de " + d.getFullYear()
              : DIAS_EN[d.getDay()] + ", " + MESES_EN[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear();
}
// "8 – 14 de novembro de 2026", "29 de nov. – 5 de dez. de 2026", "28 de dez. de 2026 – 3 de jan. de 2027"
function tituloSemana(d, pt) {
    var a = inicioSemana(d), b = somarDias(a, 6);
    if (!pt) {
        if (a.getMonth() === b.getMonth())
            return MESES_EN[a.getMonth()] + " " + a.getDate() + " – " + b.getDate() + ", " + b.getFullYear();
        if (a.getFullYear() === b.getFullYear())
            return MESES_CURTOS_EN[a.getMonth()] + " " + a.getDate() + " – " + MESES_CURTOS_EN[b.getMonth()] + " " + b.getDate() + ", " + b.getFullYear();
        return MESES_CURTOS_EN[a.getMonth()] + " " + a.getDate() + ", " + a.getFullYear() + " – " + MESES_CURTOS_EN[b.getMonth()] + " " + b.getDate() + ", " + b.getFullYear();
    }
    if (a.getMonth() === b.getMonth())
        return a.getDate() + " – " + b.getDate() + " de " + MESES[b.getMonth()] + " de " + b.getFullYear();
    if (a.getFullYear() === b.getFullYear())
        return a.getDate() + " de " + MESES_CURTOS[a.getMonth()] + " – " + b.getDate() + " de " + MESES_CURTOS[b.getMonth()] + " de " + b.getFullYear();
    return a.getDate() + " de " + MESES_CURTOS[a.getMonth()] + " de " + a.getFullYear() + " – " + b.getDate() + " de " + MESES_CURTOS[b.getMonth()] + " de " + b.getFullYear();
}
// "Hoje", "Amanhã", "Ontem" ou a data curta.
function relativo(d, pt) {
    var n = diasEntre(hoje(), d);
    if (n === 0)
        return pt ? "Hoje" : "Today";
    if (n === 1)
        return pt ? "Amanhã" : "Tomorrow";
    if (n === -1)
        return pt ? "Ontem" : "Yesterday";
    return dataCurtaAno(d, pt);
}

// ----- feriados nacionais do Brasil -----
// Páscoa pelo método de Meeus/Jones/Butcher (calendário gregoriano).
function pascoa(ano) {
    var a = ano % 19, b = Math.floor(ano / 100), c = ano % 100;
    var d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3);
    var h = (19 * a + b - d - g + 15) % 30, i = Math.floor(c / 4), k = c % 4;
    var l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451);
    var mes = Math.floor((h + l - 7 * m + 114) / 31), dia = ((h + l - 7 * m + 114) % 31) + 1;
    return new Date(ano, mes - 1, dia);
}
var FIXOS = [
    [1, 1, "Confraternização Universal", "New Year's Day"],
    [4, 21, "Tiradentes", "Tiradentes Day"],
    [5, 1, "Dia do Trabalho", "Labour Day"],
    [9, 7, "Independência do Brasil", "Independence Day"],
    [10, 12, "Nossa Senhora Aparecida", "Our Lady of Aparecida"],
    [11, 2, "Finados", "All Souls' Day"],
    [11, 15, "Proclamação da República", "Republic Day"],
    [11, 20, "Consciência Negra", "Black Consciousness Day"],
    [12, 25, "Natal", "Christmas Day"]
];
// Distância da Páscoa, nome e tipo ("feriado", "facultativo" ou "data").
var MOVEIS = [
    [-48, "Carnaval", "Carnival", "facultativo"],
    [-47, "Carnaval", "Carnival", "facultativo"],
    [-2, "Sexta-feira Santa", "Good Friday", "feriado"],
    [0, "Páscoa", "Easter", "data"],
    [60, "Corpus Christi", "Corpus Christi", "facultativo"]
];
var _feriados = {};
// [{ chave: "2026-02-16", nome, nomeEn, tipo }], em ordem.
function feriados(ano) {
    if (_feriados[ano])
        return _feriados[ano];
    var lista = [];
    for (var i = 0; i < FIXOS.length; i++) {
        // O Dia da Consciência Negra é feriado nacional desde 2024 (Lei 14.759/2023).
        if (FIXOS[i][0] === 11 && FIXOS[i][1] === 20 && ano < 2024)
            continue;
        lista.push({ chave: ano + "-" + dois(FIXOS[i][0]) + "-" + dois(FIXOS[i][1]), nome: FIXOS[i][2], nomeEn: FIXOS[i][3], tipo: "feriado" });
    }
    var p = pascoa(ano);
    for (var j = 0; j < MOVEIS.length; j++)
        lista.push({ chave: chave(somarDias(p, MOVEIS[j][0])), nome: MOVEIS[j][1], nomeEn: MOVEIS[j][2], tipo: MOVEIS[j][3] });
    lista.sort(function (x, y) { return x.chave < y.chave ? -1 : (x.chave > y.chave ? 1 : 0); });
    _feriados[ano] = lista;
    return lista;
}
// { "2026-11-15": {...}, ... } entre dois dias.
function feriadosEntre(de, ate) {
    var mapa = {};
    for (var ano = de.getFullYear(); ano <= ate.getFullYear(); ano++) {
        var lista = feriados(ano);
        for (var i = 0; i < lista.length; i++) {
            var d = ler(lista[i].chave);
            if (d >= meiaNoite(de) && d <= meiaNoite(ate) && !mapa[lista[i].chave])
                mapa[lista[i].chave] = lista[i];
        }
    }
    return mapa;
}

// ----- eventos e repetições -----
// Quantos dias a mais o evento ocupa depois do primeiro (0 para um evento de um dia).
function extensao(ev) {
    var a = ler(ev.inicio), b = ler(ev.fim || ev.inicio);
    return Math.max(0, diasEntre(a, b));
}
// Os dias em que a série começa uma ocorrência, entre de e ate (Dates à meia-noite).
function diasDaSerie(ev, de, ate) {
    var ini = meiaNoite(ler(ev.inicio));
    var rep = ev.repetir || "nunca";
    var r = [];
    var fimSerie = rep !== "nunca" && ev.ate ? meiaNoite(ler(ev.ate)) : null;
    if (fimSerie && fimSerie < ate)
        ate = fimSerie;
    if (ate < ini)
        return r;
    if (rep === "nunca") {
        if (ini >= de && ini <= ate)
            r.push(ini);
        return r;
    }
    if (rep === "dia" || rep === "semana") {
        var passo = rep === "dia" ? 1 : 7;
        var n = Math.max(0, Math.ceil(diasEntre(ini, de) / passo));
        for (var d = somarDias(ini, n * passo); d <= ate; d = somarDias(d, passo))
            r.push(d);
        return r;
    }
    if (rep === "mes") {
        // Todo dia 31: os meses sem dia 31 ficam de fora (como no iCalendar).
        var k = Math.max(0, (de.getFullYear() - ini.getFullYear()) * 12 + de.getMonth() - ini.getMonth() - 1);
        for (;; k++) {
            var primeiro = new Date(ini.getFullYear(), ini.getMonth() + k, 1);
            if (primeiro > ate)
                break;
            if (ini.getDate() > diasNoMes(primeiro.getFullYear(), primeiro.getMonth()))
                continue;
            var dm = new Date(primeiro.getFullYear(), primeiro.getMonth(), ini.getDate());
            if (dm >= de && dm <= ate && dm >= ini)
                r.push(dm);
        }
        return r;
    }
    if (rep === "ano") {
        // 29 de fevereiro: só nos anos bissextos.
        for (var ano = Math.max(ini.getFullYear(), de.getFullYear() - 1); ano <= ate.getFullYear(); ano++) {
            if (ini.getDate() > diasNoMes(ano, ini.getMonth()))
                continue;
            var da = new Date(ano, ini.getMonth(), ini.getDate());
            if (da >= de && da <= ate && da >= ini)
                r.push(da);
        }
    }
    return r;
}
// As ocorrências que tocam os dias de de até ate:
//   [{ ev, chave (dia em que começa), inicio: Date, fim: Date, diaTodo, extensao }]
function ocorrencias(eventos, de, ate) {
    var lista = [];
    de = meiaNoite(de);
    ate = meiaNoite(ate);
    for (var i = 0; i < eventos.length; i++) {
        var ev = eventos[i];
        var ini = ler(ev.inicio), fim = ler(ev.fim || ev.inicio);
        if (fim < ini)
            fim = ini;
        var ext = Math.max(0, diasEntre(ini, fim));
        var dur = fim.getTime() - ini.getTime();
        var exc = ev.excecoes || [];
        var dias = diasDaSerie(ev, somarDias(de, -ext), ate);
        for (var j = 0; j < dias.length; j++) {
            var k = chave(dias[j]);
            if (exc.indexOf(k) >= 0)
                continue;
            var oIni = ev.diaTodo ? dias[j] : new Date(dias[j].getFullYear(), dias[j].getMonth(), dias[j].getDate(), ini.getHours(), ini.getMinutes());
            var oFim = ev.diaTodo ? somarDias(dias[j], ext) : new Date(oIni.getTime() + dur);
            lista.push({ ev: ev, chave: k, inicio: oIni, fim: oFim, diaTodo: !!ev.diaTodo, extensao: ext });
        }
    }
    lista.sort(comparar);
    return lista;
}
// Dia todo primeiro (os mais longos antes), depois pela hora, depois pelo nome.
function comparar(a, b) {
    if (a.diaTodo !== b.diaTodo)
        return a.diaTodo ? -1 : 1;
    if (a.inicio.getTime() !== b.inicio.getTime())
        return a.inicio - b.inicio;
    if (a.diaTodo && a.extensao !== b.extensao)
        return b.extensao - a.extensao;
    return String(a.ev.titulo).localeCompare(String(b.ev.titulo));
}
// O último dia que a ocorrência ocupa (um evento até 00:00 não ocupa o dia seguinte).
function ultimoDia(o) {
    if (o.diaTodo)
        return meiaNoite(o.fim);
    var f = new Date(o.fim.getTime() - (o.fim > o.inicio ? 60000 : 0));
    return meiaNoite(f);
}
// { "2026-11-12": [ocorrências que tocam o dia], ... } para as grades.
function porDia(eventos, de, ate) {
    var mapa = {};
    var lista = ocorrencias(eventos, de, ate);
    de = meiaNoite(de);
    ate = meiaNoite(ate);
    for (var i = 0; i < lista.length; i++) {
        var o = lista[i];
        var ultimo = ultimoDia(o);
        for (var d = meiaNoite(o.inicio); d <= ultimo; d = somarDias(d, 1)) {
            if (d < de || d > ate)
                continue;
            var k = chave(d);
            (mapa[k] = mapa[k] || []).push(o);
        }
    }
    for (var c in mapa)
        mapa[c].sort(comparar);
    return mapa;
}

// ----- blocos da grade de horas (Semana e Dia) -----
// As ocorrências com hora de um dia, com a coluna de cada uma quando se sobrepõem:
//   [{ o, de: minutos, ate: minutos, coluna, colunas }]
function blocosDoDia(ocorrenciasDoDia, d) {
    var inicioDia = meiaNoite(d).getTime();
    var fimDia = somarDias(meiaNoite(d), 1).getTime();
    var blocos = [];
    for (var i = 0; i < ocorrenciasDoDia.length; i++) {
        var o = ocorrenciasDoDia[i];
        if (o.diaTodo)
            continue;
        var a = Math.max(o.inicio.getTime(), inicioDia), b = Math.min(o.fim.getTime(), fimDia);
        if (b < a)
            continue;
        var de = Math.round((a - inicioDia) / 60000), ate = Math.round((b - inicioDia) / 60000);
        blocos.push({ o: o, de: de, ate: Math.max(ate, de + 20), coluna: 0, colunas: 1 });
    }
    blocos.sort(function (x, y) { return x.de - y.de || y.ate - x.ate; });
    // Grupos de blocos que se encostam: cada grupo divide a largura em colunas.
    var grupo = [], colunasFim = [], fimGrupo = -1;
    function fechar() {
        for (var g = 0; g < grupo.length; g++)
            grupo[g].colunas = colunasFim.length;
        grupo = [];
        colunasFim = [];
    }
    for (var j = 0; j < blocos.length; j++) {
        var bl = blocos[j];
        if (bl.de >= fimGrupo && grupo.length > 0)
            fechar();
        var c = 0;
        while (c < colunasFim.length && colunasFim[c] > bl.de)
            c++;
        colunasFim[c] = bl.ate;
        bl.coluna = c;
        grupo.push(bl);
        fimGrupo = Math.max(fimGrupo, bl.ate);
    }
    fechar();
    return blocos;
}

// ----- repetição, em palavras -----
function textoRepetir(rep, d, pt) {
    if (rep === "dia")
        return pt ? "Todo dia" : "Every day";
    if (rep === "semana")
        return pt ? "Toda semana, " + (d.getDay() === 0 || d.getDay() === 6 ? "no " : "na ") + DIAS[d.getDay()] : "Weekly on " + DIAS_EN[d.getDay()];
    if (rep === "mes")
        return pt ? "Todo mês, no dia " + d.getDate() : "Monthly on day " + d.getDate();
    if (rep === "ano")
        return pt ? "Todo ano, em " + d.getDate() + " de " + MESES[d.getMonth()] : "Every year on " + MESES_EN[d.getMonth()] + " " + d.getDate();
    return pt ? "Não se repete" : "Does not repeat";
}

// Um id curto para os eventos novos (também serve no nome da unidade do systemd).
function novoId() {
    return Date.now().toString(36) + Math.floor(Math.random() * 1679616).toString(36);
}

// Para os testes, no Node (no QML "module" não existe).
if (typeof module !== "undefined")
    module.exports = { chave: chave, ler: ler, somarDias: somarDias, somarMeses: somarMeses, diasEntre: diasEntre, inicioSemana: inicioSemana,
                       gradeMes: gradeMes, pascoa: pascoa, feriados: feriados, diasDaSerie: diasDaSerie, ocorrencias: ocorrencias,
                       porDia: porDia, blocosDoDia: blocosDoDia, tituloMes: tituloMes, dataCurta: dataCurta, tituloSemana: tituloSemana,
                       dataLonga: dataLonga };
