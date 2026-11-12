.pragma library
// Contas da Calculadora do Matsu, separadas do desenho para dar para testar fora
// do QML (tests/test_calculadora.js, com o node).
//
// Os números são decimais de verdade, não o "double" do JavaScript: o valor é
// sinal × algarismos × 10^expoente, com os algarismos num texto ("12345"). Assim
// 0,1 + 0,2 dá 0,3 (e não 0,30000000000000004), como na calculadora do Windows.
// As contas guardam 34 algarismos (como o decimal128) e o visor mostra 16.
// Seno, logaritmo e companhia saem do Math do JavaScript, arredondados a 15
// algarismos, com os casos redondos exatos (sen 30° = 0,5; cos 90° = 0; log 1000 = 3).
//
// A máquina de estados segue a calculadora do Windows 11 (científica): a conta
// aparece em cima ("12 × 3 ="), o número grande embaixo, a precedência vale
// (2 + 3 × 4 = 14), os parênteses também, e a porcentagem é a do Windows
// (200 + 10% = 220; 200 × 10% = 20).
//   var s = novoEstado();
//   s = apertar(s, "1"); s = apertar(s, "+"); ... s = apertar(s, "=");
//   visor(s, { ingles: false }) -> { expressao: "1 + 2 =", resultado: "3", ... }

var PREC = 34;       // algarismos guardados nas contas
var MOSTRA = 16;     // algarismos no visor
var EXP_MAX = 9999;  // além de 10^9999, "Estouro"

// ---------------------------------------------------------------------------
// Inteiros grandes: textos de algarismos, sem sinal ("0" é o zero).
// ---------------------------------------------------------------------------
function zeros(n) {
    var r = "";
    while (r.length < n)
        r += "0000000000";
    return r.substring(0, n);
}

function iNorm(s) {
    var i = 0;
    while (i < s.length - 1 && s.charAt(i) === "0")
        i++;
    return s.substring(i) || "0";
}

function iCmp(a, b) {
    a = iNorm(a);
    b = iNorm(b);
    if (a.length !== b.length)
        return a.length < b.length ? -1 : 1;
    return a < b ? -1 : (a > b ? 1 : 0);
}

function iAdd(a, b) {
    var r = [], i = a.length - 1, j = b.length - 1, c = 0;
    while (i >= 0 || j >= 0 || c) {
        var s = c + (i >= 0 ? a.charCodeAt(i--) - 48 : 0) + (j >= 0 ? b.charCodeAt(j--) - 48 : 0);
        r.push(s % 10);
        c = s >= 10 ? 1 : 0;
    }
    return iNorm(r.reverse().join(""));
}

// a - b, com a >= b.
function iSub(a, b) {
    var r = [], i = a.length - 1, j = b.length - 1, c = 0;
    while (i >= 0) {
        var s = (a.charCodeAt(i--) - 48) - c - (j >= 0 ? b.charCodeAt(j--) - 48 : 0);
        if (s < 0) {
            s += 10;
            c = 1;
        } else {
            c = 0;
        }
        r.push(s);
    }
    return iNorm(r.reverse().join(""));
}

function iMul(a, b) {
    if (a === "0" || b === "0")
        return "0";
    var n = a.length, m = b.length, r = [];
    for (var k = 0; k < n + m; k++)
        r.push(0);
    for (var i = n - 1; i >= 0; i--) {
        var x = a.charCodeAt(i) - 48;
        if (x === 0)
            continue;
        var c = 0;
        for (var j = m - 1; j >= 0; j--) {
            var t = r[i + j + 1] + x * (b.charCodeAt(j) - 48) + c;
            r[i + j + 1] = t % 10;
            c = Math.floor(t / 10);
        }
        r[i] += c;
    }
    return iNorm(r.join(""));
}

// a × k, com k inteiro pequeno (até uns milhões).
function iMulPeq(a, k) {
    if (k === 0 || a === "0")
        return "0";
    var r = [], c = 0;
    for (var i = a.length - 1; i >= 0; i--) {
        var t = (a.charCodeAt(i) - 48) * k + c;
        r.push(t % 10);
        c = Math.floor(t / 10);
    }
    while (c > 0) {
        r.push(c % 10);
        c = Math.floor(c / 10);
    }
    return r.reverse().join("");
}

// Divisão longa: { q: quociente, r: resto }.
function iDivmod(a, b) {
    if (iCmp(a, b) < 0)
        return { q: "0", r: iNorm(a) };
    var q = "", r = "0";
    for (var i = 0; i < a.length; i++) {
        r = iNorm(r + a.charAt(i));
        var d = 0;
        while (iCmp(r, b) >= 0) {
            r = iSub(r, b);
            d++;
        }
        q += d;
    }
    return { q: iNorm(q), r: r };
}

// Raiz quadrada inteira (para baixo), algarismo por algarismo.
function iRaiz(n) {
    if (n.length % 2)
        n = "0" + n;
    var r = "0", resto = "0";
    for (var i = 0; i < n.length; i += 2) {
        resto = iNorm(resto + n.substring(i, i + 2));
        var base = iMulPeq(r, 20), d = 0, tira = "0";
        for (var t = 9; t >= 1; t--) {
            var cand = iMulPeq(iAdd(base, String(t)), t);
            if (iCmp(cand, resto) <= 0) {
                d = t;
                tira = cand;
                break;
            }
        }
        resto = iSub(resto, tira);
        r = iNorm(r + d);
    }
    return r;
}

// ---------------------------------------------------------------------------
// Decimais: { s: 1 ou -1, c: "algarismos", e: expoente }  (valor = s × c × 10^e)
// ---------------------------------------------------------------------------
function Falha(codigo) {
    this.erroCalc = codigo;
}

function falha(codigo) {
    return new Falha(codigo);
}

function dec(s, c, e) {
    return { s: s, c: c, e: e };
}

var ZERO = dec(1, "0", 0);
var UM = dec(1, "1", 0);

function dNorm(d) {
    var c = iNorm(d.c);
    if (c === "0")
        return ZERO;
    var k = c.length;
    while (k > 1 && c.charAt(k - 1) === "0")
        k--;
    var e = d.e + (c.length - k);
    c = c.substring(0, k);
    var ex = c.length - 1 + e;
    if (ex > EXP_MAX)
        throw falha("estouro");
    if (ex < -EXP_MAX)
        return ZERO;
    return dec(d.s < 0 ? -1 : 1, c, e);
}

// Arredonda a p algarismos significativos (metade para cima).
function dRound(d, p) {
    if (d.c.length <= p)
        return d;
    var corte = d.c.length - p;
    var c = d.c.substring(0, p);
    if (d.c.charAt(p) >= "5")
        c = iAdd(c, "1");
    return dNorm(dec(d.s, c, d.e + corte));
}

// Arredonda a "casas" casas depois da vírgula.
function dRoundCasas(d, casas) {
    if (d.c === "0" || d.e >= -casas)
        return d;
    var corte = -casas - d.e;
    var c = d.c;
    if (corte > c.length)
        return ZERO;
    var fica = c.substring(0, c.length - corte);
    var prox = c.charAt(c.length - corte);
    if (prox >= "5")
        fica = iAdd(fica || "0", "1");
    return dNorm(dec(d.s, fica || "0", -casas));
}

function dFin(d, p) {
    return dRound(dNorm(d), p || PREC);
}

function dInt(n) {
    return dParse(String(n));
}

function dNeg(d) {
    return d.c === "0" ? d : dec(-d.s, d.c, d.e);
}

function dAbs(d) {
    return d.s < 0 ? dec(1, d.c, d.e) : d;
}

function dEhZero(d) {
    return d.c === "0";
}

function dEhInteiro(d) {
    return d.c === "0" || d.e >= 0;
}

// Posição do primeiro algarismo: 0 para 1..9, 2 para 100..999, -1 para 0,1..0,9.
function dOrdem(d) {
    return d.c.length - 1 + d.e;
}

function dAdd(a, b) {
    if (a.c === "0")
        return b;
    if (b.c === "0")
        return a;
    var oa = dOrdem(a), ob = dOrdem(b);
    if (oa - ob > PREC + 2)
        return a;
    if (ob - oa > PREC + 2)
        return b;
    var e = Math.min(a.e, b.e);
    var ca = a.c + zeros(a.e - e), cb = b.c + zeros(b.e - e);
    if (a.s === b.s)
        return dFin(dec(a.s, iAdd(ca, cb), e));
    var k = iCmp(ca, cb);
    if (k === 0)
        return ZERO;
    return k > 0 ? dFin(dec(a.s, iSub(ca, cb), e)) : dFin(dec(b.s, iSub(cb, ca), e));
}

function dSub(a, b) {
    return dAdd(a, dNeg(b));
}

function dMul(a, b, p) {
    if (a.c === "0" || b.c === "0")
        return ZERO;
    return dFin(dec(a.s * b.s, iMul(a.c, b.c), a.e + b.e), p);
}

function dDiv(a, b, p) {
    if (b.c === "0")
        throw falha(a.c === "0" ? "indefinido" : "divzero");
    if (a.c === "0")
        return ZERO;
    p = p || PREC;
    var k = p + 2 + b.c.length - a.c.length;
    if (k < 0)
        k = 0;
    var q = iDivmod(a.c + zeros(k), b.c).q;
    return dFin(dec(a.s * b.s, q, a.e - b.e - k), p);
}

function dCmp(a, b) {
    var d = dSub(a, b);
    return d.c === "0" ? 0 : d.s;
}

// Resto com o sinal do dividendo (como o "mod" das calculadoras). Exato.
function dMod(a, b) {
    if (b.c === "0")
        throw falha("divzero");
    if (a.c === "0")
        return ZERO;
    var e = Math.min(a.e, b.e);
    var r = iDivmod(a.c + zeros(a.e - e), b.c + zeros(b.e - e)).r;
    return dNorm(dec(a.s, r, e));
}

// Resto sempre com o sinal do divisor (para reduzir ângulos a uma volta).
function dModPos(a, b) {
    var r = dMod(a, b);
    if (r.c !== "0" && r.s !== b.s)
        r = dAdd(r, b);
    return r;
}

function dPiso(d) {
    if (dEhInteiro(d))
        return d;
    var n = d.c.length + d.e;
    var inteiro = n > 0 ? d.c.substring(0, n) : "0";
    var r = dNorm(dec(d.s, inteiro, 0));
    return d.s < 0 ? dSub(r, UM) : r;
}

function dParse(t) {
    t = String(t).trim().replace(/−/g, "-");
    var m = /^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$/.exec(t);
    if (!m || ((m[2] || "") === "" && (m[3] || "") === ""))
        return null;
    var frac = m[3] || "";
    var c = (m[2] || "") + frac;
    var e = -frac.length + (m[4] ? parseInt(m[4], 10) : 0);
    if (Math.abs(e) > 1e6) {
        if (iNorm(c) !== "0" && e > 0)
            throw falha("estouro");
        return ZERO;
    }
    return dNorm(dec(m[1] === "-" ? -1 : 1, c, e));
}

function dNum(d) {
    return Number((d.s < 0 ? "-" : "") + d.c + "e" + d.e);
}

function dDeNumero(n, p) {
    if (!isFinite(n))
        throw falha(isNaN(n) ? "invalida" : "estouro");
    if (n === 0)
        return ZERO;
    return dRound(dParse(n.toPrecision(p || 15)), p || 15);
}

// Texto guardado (histórico, memória): "12.5", "-0.001", "1.25e+30".
function dTexto(d) {
    if (d.c === "0")
        return "0";
    var sinal = d.s < 0 ? "-" : "";
    var ex = dOrdem(d);
    if (d.e >= 0 && ex < 21)
        return sinal + d.c + zeros(d.e);
    if (d.e < 0 && ex >= -7) {
        if (ex >= 0)
            return sinal + d.c.substring(0, ex + 1) + "." + d.c.substring(ex + 1);
        return sinal + "0." + zeros(-ex - 1) + d.c;
    }
    return sinal + d.c.charAt(0) + (d.c.length > 1 ? "." + d.c.substring(1) : "") + "e" + (ex >= 0 ? "+" : "") + ex;
}

var log10 = Math.log10 || function (x) {
    return Math.log(x) / Math.LN10;
};

// log10 de |d| em double, sem perder a escala dos números enormes.
function dLog10Num(d) {
    var lider = Number(d.c.charAt(0) + "." + d.c.substring(1, 17));
    return log10(lider) + dOrdem(d);
}

function dLnNum(d) {
    var lider = Number(d.c.charAt(0) + "." + d.c.substring(1, 17));
    return Math.log(lider) + dOrdem(d) * Math.LN10;
}

// 10^t para t real (double), com a parte inteira no expoente.
function dDezA(t) {
    if (isNaN(t))
        throw falha("invalida");
    if (t > EXP_MAX + 1)
        throw falha("estouro");
    if (t < -EXP_MAX - 1)
        return ZERO;
    var i = Math.floor(t);
    var m = dDeNumero(Math.pow(10, t - i), 15);
    return dNorm(dec(m.s, m.c, m.e + i));
}

var PI = dRound(dParse("3.14159265358979323846264338327950288419716939937510"), PREC);
var E = dRound(dParse("2.71828182845904523536028747135266249775724709369995"), PREC);
var DOIS_PI = dMul(PI, dInt(2));
var CEM = dInt(100);

// ---------------------------------------------------------------------------
// Funções
// ---------------------------------------------------------------------------
function ehImpar(d) {
    if (!dEhInteiro(d) || d.e > 0)
        return false;
    return (d.c.charCodeAt(d.c.length - 1) - 48) % 2 === 1;
}

function dPotInt(x, n) {
    if (n === 0)
        return UM;
    if (x.c === "0") {
        if (n < 0)
            throw falha("divzero");
        return ZERO;
    }
    var tamanho = dLog10Num(x) * n;
    if (tamanho > EXP_MAX + 1)
        throw falha("estouro");
    if (tamanho < -EXP_MAX - 1)
        return ZERO;
    var neg = n < 0;
    n = Math.abs(n);
    var r = UM, b = x;
    while (n > 0) {
        if (n % 2 === 1)
            r = dMul(r, b, PREC + 6);
        n = Math.floor(n / 2);
        if (n > 0)
            b = dMul(b, b, PREC + 6);
    }
    return neg ? dDiv(UM, r) : dRound(r, PREC);
}

function dPot(x, y) {
    if (dEhInteiro(y) && dOrdem(y) < 7)
        return dPotInt(x, dNum(y));
    if (x.c === "0") {
        if (y.s > 0)
            return ZERO;
        throw falha("divzero");
    }
    if (dEhInteiro(y)) {
        // Expoente inteiro enorme: só pelo logaritmo (ou ±1).
        var sinal = x.s < 0 && ehImpar(y) ? -1 : 1;
        if (dCmp(dAbs(x), UM) === 0)
            return dec(sinal, "1", 0);
        var r0 = dDezA(dNum(y) * dLog10Num(x));
        return sinal < 0 ? dNeg(r0) : r0;
    }
    if (x.s < 0)
        throw falha("invalida");
    // Meios (x^0,5, x^1,5): pela raiz exata, com todos os algarismos.
    var dobro = dMul(y, dInt(2));
    if (dEhInteiro(dobro) && dOrdem(dobro) < 7)
        return dPotInt(dRaiz(x), dNum(dobro));
    var xn = dNum(x), yn = dNum(y);
    var r = Math.pow(xn, yn);
    if (isFinite(xn) && isFinite(r) && r !== 0 && Math.abs(log10(r)) < 300)
        return dDeNumero(r, 15);
    return dDezA(yn * dLog10Num(x));
}

function dRaiz(x) {
    if (x.c === "0")
        return ZERO;
    if (x.s < 0)
        throw falha("invalida");
    var c = x.c, e = x.e;
    if (e % 2 !== 0) {
        c += "0";
        e -= 1;
    }
    var alvo = 2 * (PREC + 2);
    if (c.length < alvo) {
        var k = alvo - c.length;
        if (k % 2)
            k++;
        c += zeros(k);
        e -= k;
    }
    return dFin(dec(1, iRaiz(c), e / 2));
}

// Raiz de índice y: x ʸ√ y.
function dRaizN(x, y) {
    if (y.c === "0")
        throw falha("invalida");
    if (dCmp(y, dInt(2)) === 0)
        return dRaiz(x);
    var neg = false;
    if (x.s < 0 && x.c !== "0") {
        if (!ehImpar(y))
            throw falha("invalida");
        neg = true;
        x = dAbs(x);
    }
    if (x.c === "0") {
        if (y.s < 0)
            throw falha("divzero");
        return ZERO;
    }
    var yn = dNum(y), xn = dNum(x), r;
    var rn = Math.pow(xn, 1 / yn);
    if (isFinite(xn) && isFinite(rn) && rn !== 0 && Math.abs(log10(rn)) < 300)
        r = dDeNumero(rn, 15);
    else
        r = dDezA(dLog10Num(x) / yn);
    // Raiz exata (∛27 = 3, ⁴√0,0016 = 0,2): confere com menos algarismos.
    if (dEhInteiro(y) && Math.abs(yn) <= 60) {
        try {
            var curto = dRound(r, 12);
            if (dCmp(dPotInt(curto, yn), x) === 0)
                r = curto;
        } catch (e) {
            // fica a conta do double
        }
    }
    return neg ? dNeg(r) : r;
}

var LANCZOS = [0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
               -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6,
               1.5056327351493116e-7];

function gama(z) {
    if (z < 0.5)
        return Math.PI / (Math.sin(Math.PI * z) * gama(1 - z));
    z -= 1;
    var x = LANCZOS[0];
    for (var i = 1; i < 9; i++)
        x += LANCZOS[i] / (z + i);
    var t = z + 7.5;
    return Math.sqrt(2 * Math.PI) * Math.pow(t, z + 0.5) * Math.exp(-t) * x;
}

function lnGama(z) {
    z -= 1;
    var x = LANCZOS[0];
    for (var i = 1; i < 9; i++)
        x += LANCZOS[i] / (z + i);
    var t = z + 7.5;
    return 0.5 * Math.log(2 * Math.PI) + (z + 0.5) * Math.log(t) - t + Math.log(x);
}

// n! (inteiro, exato até onde cabe) e Γ(x + 1) para os outros números, como no Windows.
function dFatorial(x) {
    if (dEhInteiro(x)) {
        if (x.s < 0 && x.c !== "0")
            throw falha("invalida");
        if (dOrdem(x) > 5)
            throw falha("estouro");
        var n = dNum(x);
        if (n > 3249)
            throw falha("estouro");
        var r = UM;
        for (var i = 2; i <= n; i++)
            r = dRound(dNorm(dec(1, iMulPeq(r.c, i), r.e)), PREC + 4);
        return dRound(r, PREC);
    }
    // Meios inteiros (0,5! = √π/2): Γ(k + ½) = (2k)! / (4^k · k!) · √π, exato.
    var dobro = dMul(x, dInt(2));
    if (dEhInteiro(dobro) && dOrdem(x) < 3) {
        var k = (dNum(dobro) + 1) / 2;  // x + 1 = k + ½
        var raizPi = dRaiz(PI);
        if (k >= 0) {
            var cima = dFatorial(dInt(2 * k)), baixo = dMul(dPotInt(dInt(4), k), dFatorial(dInt(k)));
            return dDiv(dMul(cima, raizPi), baixo);
        }
        // Γ(½ − n) = (−4)^n · n! / (2n)! · √π
        var n = -k;
        var r2 = dDiv(dMul(dMul(dPotInt(dInt(-4), n), dFatorial(dInt(n))), raizPi), dFatorial(dInt(2 * n)));
        return r2;
    }
    var z = dNum(x) + 1;
    if (z > 171)
        return dDezA(lnGama(z) / Math.LN10);
    if (z < -170)
        return ZERO;
    return dDeNumero(gama(z), 15);
}

// Valores exatos de sen/cos/tan nos múltiplos de 90° (índice: quartos de volta).
var SEN_Q = [0, 1, 0, -1], COS_Q = [1, 0, -1, 0];

function exatoTrig(nome, q) {
    if (nome === "sen")
        return dInt(SEN_Q[q]);
    if (nome === "cos")
        return dInt(COS_Q[q]);
    if (COS_Q[q] === 0)
        throw falha("invalida");
    return ZERO;
}

function dTrig(nome, x, angulo) {
    var rad;
    if (angulo === "radianos") {
        var xr = dOrdem(x) > 5 ? dModPos(x, DOIS_PI) : x;
        rad = dNum(xr);
        var quartos = rad / (Math.PI / 2), k = Math.round(quartos);
        if (k !== 0 && Math.abs(quartos - k) < 1e-13 * Math.max(1, Math.abs(quartos)))
            return exatoTrig(nome, ((k % 4) + 4) % 4);
    } else {
        var volta = angulo === "grados" ? 400 : 360;
        var red = dModPos(x, dInt(volta));
        if (dEhZero(dMod(red, dInt(volta / 4))))
            return exatoTrig(nome, Math.round(dNum(red) / (volta / 4)) % 4);
        rad = dNum(red) * Math.PI / (volta / 2);
    }
    var r;
    if (nome === "sen")
        r = Math.sin(rad);
    else if (nome === "cos")
        r = Math.cos(rad);
    else
        r = Math.sin(rad) / Math.cos(rad);
    return dDeNumero(r, 15);
}

function dTrigInv(nome, x, angulo) {
    var v = dNum(x);
    if ((nome === "asen" || nome === "acos") && (v < -1 || v > 1))
        throw falha("invalida");
    // Os cantos (π/2, π...) saem do π de 34 algarismos.
    if (angulo === "radianos") {
        var meioPi = dDiv(PI, dInt(2));
        if (nome === "asen" && Math.abs(v) === 1)
            return v > 0 ? meioPi : dNeg(meioPi);
        if (nome === "acos" && v === -1)
            return PI;
        if (nome === "acos" && v === 0)
            return meioPi;
    }
    var r = nome === "asen" ? Math.asin(v) : (nome === "acos" ? Math.acos(v) : Math.atan(v));
    if (angulo === "graus")
        r = r * 180 / Math.PI;
    else if (angulo === "grados")
        r = r * 200 / Math.PI;
    return dDeNumero(r, 15);
}

function dLog(x) {
    if (x.c === "0" || x.s < 0)
        throw falha("invalida");
    if (x.c === "1")
        return dInt(x.e);
    return dDeNumero(dLog10Num(x), 15);
}

function dLn(x) {
    if (x.c === "0" || x.s < 0)
        throw falha("invalida");
    if (x.c === "1" && x.e === 0)
        return ZERO;
    return dDeNumero(dLnNum(x), 15);
}

function dExp(x) {
    if (dEhInteiro(x) && dOrdem(x) < 4)
        return dPotInt(E, dNum(x));
    var v = dNum(x);
    if (Math.abs(v) < 700)
        return dDeNumero(Math.exp(v), 15);
    return dDezA(v * log10(Math.E));
}

function aplicarFuncao(nome, x, angulo) {
    switch (nome) {
    case "quadrado":
        return dMul(x, x);
    case "cubo":
        return dMul(dMul(x, x), x);
    case "raiz":
        return dRaiz(x);
    case "raiz3":
        return dRaizN(x, dInt(3));
    case "inverso":
        return dDiv(UM, x);
    case "fatorial":
        return dFatorial(x);
    case "sen":
    case "cos":
    case "tan":
        return dTrig(nome, x, angulo || "graus");
    case "asen":
    case "acos":
    case "atan":
        return dTrigInv(nome, x, angulo || "graus");
    case "log":
        return dLog(x);
    case "ln":
        return dLn(x);
    case "dez":
        return dEhInteiro(x) && dOrdem(x) < 5 ? dNorm(dec(1, "1", dNum(x))) : dDezA(dNum(x));
    case "dois":
        return dPot(dInt(2), x);
    case "exp":
        return dExp(x);
    case "abs":
        return dAbs(x);
    case "neg":
        return dNeg(x);
    }
    throw falha("invalida");
}

var PRECEDENCIA = { "+": 1, "-": 1, "*": 2, "/": 2, "mod": 2, "^": 3, "raizy": 3 };
var DIREITA = { "^": true, "raizy": true };

function operar(a, op, b) {
    switch (op) {
    case "+":
        return dAdd(a, b);
    case "-":
        return dSub(a, b);
    case "*":
        return dMul(a, b);
    case "/":
        return dDiv(a, b);
    case "^":
        return dPot(a, b);
    case "mod":
        return dMod(a, b);
    case "raizy":
        return dRaizN(a, b);
    }
    throw falha("invalida");
}

// ---------------------------------------------------------------------------
// Formatação (pt-BR: "1.234.567,89"; números enormes: "1,23e+25")
// ---------------------------------------------------------------------------
function agrupar(s, sep) {
    var r = "";
    while (s.length > 3) {
        r = sep + s.substring(s.length - 3) + r;
        s = s.substring(0, s.length - 3);
    }
    return s + r;
}

// [parte inteira, parte depois da vírgula] de |d|.
function partes(d) {
    if (d.e >= 0)
        return [d.c + zeros(d.e), ""];
    var n = d.c.length + d.e;
    if (n > 0)
        return [d.c.substring(0, n), d.c.substring(n)];
    return ["0", zeros(-n) + d.c];
}

// opcoes: { ingles, algarismos (16), semGrupo }
function formatar(d, opcoes) {
    opcoes = opcoes || {};
    var maxAlg = opcoes.algarismos || MOSTRA;
    var sepDec = opcoes.ingles ? "." : ",";
    var sepMil = opcoes.semGrupo ? "" : (opcoes.ingles ? "," : ".");
    var menos = opcoes.semGrupo ? "-" : "−";
    if (!d || d.c === "0")
        return "0";
    var r = dRound(d, maxAlg);
    var ex = dOrdem(r);
    var sinal = r.s < 0 ? menos : "";
    if (ex >= maxAlg || ex < -5) {
        var mant = r.c.charAt(0) + (r.c.length > 1 ? sepDec + r.c.substring(1) : "");
        return sinal + mant + "e" + (ex >= 0 ? "+" : menos) + Math.abs(ex);
    }
    if (ex < 0)
        r = dRoundCasas(r, maxAlg);
    if (r.c === "0")
        return "0";
    var p = partes(r);
    return sinal + agrupar(p[0], sepMil) + (p[1].length ? sepDec + p[1] : "");
}

// O que a pessoa está digitando ("1234.5", "0.", "1.5e+3"), com os separadores do idioma.
function formatarEntrada(texto, opcoes) {
    opcoes = opcoes || {};
    var sepDec = opcoes.ingles ? "." : ",";
    var sepMil = opcoes.ingles ? "," : ".";
    var t = String(texto), sinal = "";
    if (t.charAt(0) === "-") {
        sinal = "−";
        t = t.substring(1);
    }
    var expo = "";
    var ie = t.indexOf("e");
    if (ie >= 0) {
        expo = "e" + t.substring(ie + 1).replace("-", "−");
        t = t.substring(0, ie);
    }
    var ip = t.indexOf(".");
    var inteiro = ip >= 0 ? t.substring(0, ip) : t;
    var resto = ip >= 0 ? sepDec + t.substring(ip + 1) : "";
    return sinal + agrupar(inteiro || "0", sepMil) + resto + expo;
}

function mensagemErro(codigo, ingles) {
    var m = {
        divzero: ["Não é possível dividir por zero", "Cannot divide by zero"],
        indefinido: ["Resultado indefinido", "Result is undefined"],
        invalida: ["Entrada inválida", "Invalid input"],
        estouro: ["Estouro", "Overflow"]
    }[codigo] || ["Entrada inválida", "Invalid input"];
    return ingles ? m[1] : m[0];
}

var SIMBOLOS = { "+": "+", "-": "−", "*": "×", "/": "÷", "^": "^", "mod": "mod", "raizy": "ʸ√" };

function simbolo(op) {
    return SIMBOLOS[op] || op;
}

// ---------------------------------------------------------------------------
// Avaliação de uma lista de peças: { t: "n", v, r } número; { t: "o", o } operação;
// { t: "(" } e { t: ")" }. Precedência com duas pilhas (shunting-yard).
// ---------------------------------------------------------------------------
function reduzir(pecas, ateOFim) {
    var vals = [], ops = [];
    function aplica() {
        var op = ops.pop();
        var b = vals.pop(), a = vals.pop();
        vals.push(operar(a, op, b));
    }
    for (var i = 0; i < pecas.length; i++) {
        var p = pecas[i];
        if (p.t === "n") {
            vals.push(p.v);
        } else if (p.t === "(") {
            ops.push("(");
        } else if (p.t === ")") {
            while (ops.length && ops[ops.length - 1] !== "(")
                aplica();
            ops.pop();
        } else if (p.t === "o") {
            var pr = PRECEDENCIA[p.o];
            while (ops.length) {
                var topo = ops[ops.length - 1];
                if (topo === "(")
                    break;
                var pt = PRECEDENCIA[topo];
                if (pt > pr || (pt === pr && !DIREITA[p.o]))
                    aplica();
                else
                    break;
            }
            ops.push(p.o);
        }
    }
    if (ateOFim) {
        while (ops.length) {
            if (ops[ops.length - 1] === "(")
                ops.pop();
            else
                aplica();
        }
    }
    return vals;
}

function textoPecas(pecas) {
    var s = "";
    for (var i = 0; i < pecas.length; i++) {
        var p = pecas[i];
        var parte = p.t === "n" ? p.r : (p.t === "o" ? simbolo(p.o) : p.t);
        if (s === "" || s.charAt(s.length - 1) === "(" || parte === ")")
            s += parte;
        else
            s += " " + parte;
    }
    return s;
}

// Avalia um texto como "2+3*4", "(1,5+2)×3" ou "2^10" (colar uma conta, testes).
function avaliarTexto(texto, opcoes) {
    opcoes = opcoes || {};
    var t = String(texto).replace(/\s+/g, "").replace(/−/g, "-").replace(/[×x]/g, "*").replace(/÷/g, "/");
    if (!opcoes.ingles)
        t = t.replace(/\./g, "").replace(/,/g, ".");
    else
        t = t.replace(/,/g, "");
    var pecas = [], i = 0, espera = true;
    while (i < t.length) {
        var ch = t.charAt(i);
        var m = /^(\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/i.exec(t.substring(i));
        if (espera && m) {
            pecas.push({ t: "n", v: dParse(m[0]), r: m[0] });
            i += m[0].length;
            espera = false;
        } else if (espera && ch === "-") {
            // Sinal de menos na frente: vira (0 - ...) só para o próximo número/grupo.
            pecas.push({ t: "n", v: ZERO, r: "0" });
            pecas.push({ t: "o", o: "-" });
            if (t.charAt(i + 1) !== "(") {
                var m2 = /^(\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/i.exec(t.substring(i + 1));
                if (!m2)
                    return null;
                pecas.splice(pecas.length - 2, 2, { t: "n", v: dNeg(dParse(m2[0])), r: "-" + m2[0] });
                i += 1 + m2[0].length;
                espera = false;
                continue;
            }
            i++;
        } else if (espera && ch === "(") {
            pecas.push({ t: "(" });
            i++;
        } else if (!espera && ch === ")") {
            pecas.push({ t: ")" });
            i++;
        } else if (!espera && "+-*/^".indexOf(ch) >= 0) {
            pecas.push({ t: "o", o: ch });
            i++;
            espera = true;
        } else if (!espera && ch === "%") {
            // 50% = 0,5 numa conta colada.
            var ult = pecas[pecas.length - 1];
            if (ult.t !== "n")
                return null;
            pecas[pecas.length - 1] = { t: "n", v: dDiv(ult.v, CEM), r: ult.r + "%" };
            i++;
        } else {
            return null;
        }
    }
    if (espera || pecas.length === 0)
        return null;
    var abertos = 0;
    for (var k = 0; k < pecas.length; k++) {
        abertos += pecas[k].t === "(" ? 1 : (pecas[k].t === ")" ? -1 : 0);
        if (abertos < 0)
            return null;
    }
    var vals = reduzir(pecas, true);
    return vals[vals.length - 1];
}

// ---------------------------------------------------------------------------
// A máquina de estados (as teclas da calculadora)
// ---------------------------------------------------------------------------
// expr: peças já confirmadas; entrada: o número sendo digitado ("12.5");
// calc: { v, r, ver } um valor calculado no lugar do número (√9, π, memória);
// mostrado: o valor no visor quando não há entrada nem calc (resultado parcial);
// fim: { texto } depois do "=" (calc tem o resultado); erro: "divzero"...
function novoEstado() {
    return { expr: [], entrada: null, calc: null, mostrado: ZERO, fim: null, erro: "", ultimo: null,
             registro: null, tentativa: "" };
}

function copiar(s) {
    return { expr: s.expr.slice(), entrada: s.entrada, calc: s.calc, mostrado: s.mostrado, fim: s.fim,
             erro: s.erro, ultimo: s.ultimo, registro: null, tentativa: "" };
}

function limpar(s) {
    var n = novoEstado();
    for (var k in n)
        s[k] = n[k];
}

function ultimaPeca(s) {
    return s.expr.length ? s.expr[s.expr.length - 1] : null;
}

function abertos(expr) {
    var n = 0;
    for (var i = 0; i < expr.length; i++)
        n += expr[i].t === "(" ? 1 : (expr[i].t === ")" ? -1 : 0);
    return n;
}

function temOperando(s) {
    return s.entrada !== null || s.calc !== null;
}

function valorEntrada(t) {
    var u = t;
    if (/e[+-]?$/.test(u))
        u = u.replace(/e[+-]?$/, "");
    if (u.charAt(u.length - 1) === ".")
        u = u.substring(0, u.length - 1);
    if (u === "" || u === "-")
        u = "0";
    return dParse(u) || ZERO;
}

function contaAlgarismos(t) {
    var m = t.replace("-", "").split("e")[0];
    var ip = m.indexOf(".");
    var inteiro = ip >= 0 ? m.substring(0, ip) : m;
    var frac = ip >= 0 ? m.substring(ip + 1) : "";
    return (inteiro === "0" ? 0 : inteiro.length) + frac.length;
}

function numero(v, op, r) {
    return { t: "n", v: v, r: r !== undefined ? r : formatar(v, op) };
}

function confirmar(s, op) {
    if (s.entrada !== null) {
        s.expr.push(numero(valorEntrada(s.entrada), op));
        s.entrada = null;
    } else if (s.calc) {
        s.expr.push(numero(s.calc.v, op, s.calc.r));
        s.calc = null;
    }
}

// Onde começa o grupo entre parênteses que termina a expressão.
function inicioGrupoFinal(expr) {
    var n = 0;
    for (var i = expr.length - 1; i >= 0; i--) {
        if (expr[i].t === ")")
            n++;
        else if (expr[i].t === "(") {
            n--;
            if (n === 0)
                return i;
        }
    }
    return 0;
}

// Pega (e tira do estado) o operando atual para uma função: o que está sendo
// digitado, o valor calculado, o grupo "( … )" que acabou de fechar ou o visor.
function tomarOperando(s, op) {
    if (s.fim) {
        var c0 = s.calc;
        limpar(s);
        return { v: c0.v, r: c0.r };
    }
    if (s.entrada !== null) {
        var v = valorEntrada(s.entrada);
        s.entrada = null;
        return { v: v, r: formatar(v, op) };
    }
    if (s.calc) {
        var c = s.calc;
        s.calc = null;
        return { v: c.v, r: c.r };
    }
    var u = ultimaPeca(s);
    if (u && u.t === ")") {
        var i = inicioGrupoFinal(s.expr);
        var g = s.expr.slice(i);
        s.expr = s.expr.slice(0, i);
        var vals = reduzir(g, true);
        return { v: vals[vals.length - 1], r: textoPecas(g) };
    }
    return { v: s.mostrado, r: formatar(s.mostrado, op) };
}

function ehSimples(r) {
    return /^−?[0-9.,]+(e[+−]?\d+)?$/.test(r) || r === "π" || r === "e";
}

// "(2 + 3)" é um grupo só; "(2) + (3)" não.
function embrulhado(r) {
    if (r.charAt(0) !== "(" || r.charAt(r.length - 1) !== ")")
        return false;
    var n = 0;
    for (var i = 0; i < r.length; i++) {
        var ch = r.charAt(i);
        if (ch === "(")
            n++;
        else if (ch === ")") {
            n--;
            if (n === 0 && i < r.length - 1)
                return false;
        }
    }
    return true;
}

function rotuloFuncao(nome, r, op) {
    var dentro = embrulhado(r) ? r : "(" + r + ")";
    var depois = ehSimples(r) && r.charAt(0) !== "−" ? r : dentro;
    var ingles = op && op.ingles;
    var ang = op && op.angulo === "radianos" ? "" : (op && op.angulo === "grados" ? "ᵍ" : "°");
    var trig = ehSimples(r) && ang ? "(" + r + ang + ")" : dentro;
    switch (nome) {
    case "quadrado":
        return depois + "²";
    case "cubo":
        return depois + "³";
    case "raiz":
        return "√" + dentro;
    case "raiz3":
        return "∛" + dentro;
    case "inverso":
        return "1/" + dentro;
    case "fatorial":
        return depois + "!";
    case "sen":
        return (ingles ? "sin" : "sen") + trig;
    case "cos":
        return "cos" + trig;
    case "tan":
        return "tan" + trig;
    case "asen":
        return (ingles ? "sin" : "sen") + "⁻¹" + dentro;
    case "acos":
        return "cos⁻¹" + dentro;
    case "atan":
        return "tan⁻¹" + dentro;
    case "log":
        return "log" + dentro;
    case "ln":
        return "ln" + dentro;
    case "dez":
        return "10^" + depois;
    case "dois":
        return "2^" + depois;
    case "exp":
        return "e^" + depois;
    case "abs":
        return "|" + r + "|";
    case "neg":
        return "−" + dentro;
    }
    return nome + dentro;
}

var FUNCOES = { quadrado: 1, cubo: 1, raiz: 1, raiz3: 1, inverso: 1, fatorial: 1, sen: 1, cos: 1, tan: 1,
                asen: 1, acos: 1, atan: 1, log: 1, ln: 1, dez: 1, dois: 1, exp: 1, abs: 1, neg: 1 };
var OPERACOES = { "+": 1, "-": 1, "*": 1, "/": 1, "^": 1, "mod": 1, "raizy": 1 };

function textoAtual(s, op) {
    var pecas = s.expr.slice();
    if (s.calc && s.calc.ver)
        pecas.push(numero(s.calc.v, op, s.calc.r));
    return textoPecas(pecas);
}

// Um número novo no lugar do operando (algarismo, π, memória): depois de ")" vira "× número".
function abrirOperando(s) {
    if (s.fim)
        limpar(s);
    if (temOperando(s)) {
        s.entrada = null;
        s.calc = null;
    } else {
        var u = ultimaPeca(s);
        if (u && u.t === ")")
            s.expr.push({ t: "o", o: "*" });
    }
}

function teclaAlgarismo(s, d, op) {
    if (s.entrada !== null && !s.fim) {
        var t = s.entrada;
        var ie = t.indexOf("e");
        if (ie >= 0) {
            var expo = t.substring(ie + 2);
            if (expo.length >= 4)
                return;
            s.entrada = t.substring(0, ie + 2) + (expo === "0" ? "" : expo) + d;
            return;
        }
        if (contaAlgarismos(t) >= (op.limite || MOSTRA))
            return;
        if (t === "0")
            s.entrada = d;
        else if (t === "-0")
            s.entrada = "-" + d;
        else
            s.entrada = t + d;
        return;
    }
    abrirOperando(s);
    s.entrada = d;
}

function teclaVirgula(s) {
    if (s.entrada !== null && !s.fim) {
        if (s.entrada.indexOf("e") < 0 && s.entrada.indexOf(".") < 0)
            s.entrada += ".";
        return;
    }
    abrirOperando(s);
    s.entrada = "0.";
}

function teclaExpoente(s) {
    if (s.entrada === null || s.fim) {
        abrirOperando(s);
        s.entrada = "1";
    }
    if (s.entrada.indexOf("e") >= 0)
        return;
    var t = s.entrada;
    if (t.charAt(t.length - 1) === ".")
        t = t.substring(0, t.length - 1);
    s.entrada = t + "e+";
}

function teclaOperacao(s, o, op) {
    if (s.fim) {
        var v = s.calc.v;
        limpar(s);
        s.expr.push(numero(v, op));
        s.expr.push({ t: "o", o: o });
        s.mostrado = v;
        return;
    }
    var u = ultimaPeca(s);
    if (temOperando(s)) {
        confirmar(s, op);
        s.expr.push({ t: "o", o: o });
    } else if (u && u.t === "o") {
        s.expr[s.expr.length - 1] = { t: "o", o: o };
    } else if (u && u.t === ")") {
        s.expr.push({ t: "o", o: o });
    } else {
        s.expr.push(numero(s.mostrado, op));
        s.expr.push({ t: "o", o: o });
    }
    s.tentativa = textoPecas(s.expr);
    var vals = reduzir(s.expr, false);
    s.mostrado = vals.length ? vals[vals.length - 1] : ZERO;
}

// A última operação de fora dos parênteses e o que veio depois dela (para "= =").
function ultimaOperacao(expr) {
    var n = 0;
    for (var i = expr.length - 1; i >= 0; i--) {
        var p = expr[i];
        if (p.t === ")")
            n++;
        else if (p.t === "(")
            n--;
        else if (p.t === "o" && n === 0) {
            var lado = expr.slice(i + 1);
            var vals = reduzir(lado, true);
            return { o: p.o, v: vals[vals.length - 1], r: textoPecas(lado) };
        }
    }
    return null;
}

function concluir(s, texto, res, op, registrar) {
    s.fim = { texto: texto };
    s.calc = { v: res, r: formatar(res, op), ver: false };
    s.expr = [];
    s.entrada = null;
    s.mostrado = res;
    if (registrar)
        s.registro = { expressao: texto, valor: dTexto(res) };
}

function teclaIgual(s, op) {
    if (s.fim) {
        if (!s.ultimo)
            return;
        var a = s.calc.v;
        var texto0 = formatar(a, op) + " " + simbolo(s.ultimo.o) + " " + s.ultimo.r + " =";
        s.tentativa = texto0;
        concluir(s, texto0, operar(a, s.ultimo.o, s.ultimo.v), op, true);
        return;
    }
    var u = ultimaPeca(s);
    if (temOperando(s))
        confirmar(s, op);
    else if (!u || u.t === "o" || u.t === "(")
        s.expr.push(numero(s.mostrado, op));
    var falta = abertos(s.expr);
    for (var i = 0; i < falta; i++)
        s.expr.push({ t: ")" });
    var texto = textoPecas(s.expr) + " =";
    s.tentativa = texto;
    var vals = reduzir(s.expr, true);
    var res = vals[vals.length - 1];
    var registrar = s.expr.length > 1 || s.expr[0].r !== formatar(res, op);
    s.ultimo = ultimaOperacao(s.expr);
    concluir(s, texto, res, op, registrar);
}

function teclaAbre(s, op) {
    if (s.fim)
        limpar(s);
    if (temOperando(s)) {
        confirmar(s, op);
        s.expr.push({ t: "o", o: "*" });
    } else {
        var u = ultimaPeca(s);
        if (u && u.t === ")")
            s.expr.push({ t: "o", o: "*" });
    }
    s.expr.push({ t: "(" });
    s.mostrado = ZERO;
}

function teclaFecha(s, op) {
    if (s.fim || abertos(s.expr) === 0)
        return;
    var u = ultimaPeca(s);
    if (temOperando(s))
        confirmar(s, op);
    else if (u.t === "o" || u.t === "(")
        s.expr.push(numero(s.mostrado, op));
    s.expr.push({ t: ")" });
    s.tentativa = textoPecas(s.expr);
    var g = s.expr.slice(inicioGrupoFinal(s.expr));
    var vals = reduzir(g, true);
    s.mostrado = vals[vals.length - 1];
}

function teclaFuncao(s, nome, op) {
    var base = tomarOperando(s, op);
    var rotulo = rotuloFuncao(nome, base.r, op);
    s.tentativa = textoPecas(s.expr.concat([{ t: "n", r: rotulo }]));
    s.calc = { v: aplicarFuncao(nome, base.v, op.angulo), r: rotulo, ver: true };
}

function teclaNegar(s, op) {
    if (s.entrada !== null && !s.fim) {
        var t = s.entrada, ie = t.indexOf("e");
        if (ie >= 0) {
            var sinal = t.charAt(ie + 1) === "-" ? "+" : "-";
            s.entrada = t.substring(0, ie + 1) + sinal + t.substring(ie + 2);
            return;
        }
        if (t.charAt(0) === "-")
            s.entrada = t.substring(1);
        else if (t !== "0")
            s.entrada = "-" + t;
        return;
    }
    teclaFuncao(s, "neg", op);
}

// Porcentagem do Windows: depois de × ou ÷, x% = x/100; nos outros casos,
// x% = (o número da esquerda) × x/100 (200 + 10% = 200 + 20). Sem conta antes, 0.
function teclaPorcento(s, op) {
    var base = tomarOperando(s, op);
    var u = ultimaPeca(s);
    var res;
    if (u && u.t === "o") {
        if (u.o === "*" || u.o === "/") {
            res = dDiv(base.v, CEM);
        } else {
            var vals = reduzir(s.expr, false);
            res = dDiv(dMul(vals[vals.length - 1], base.v), CEM);
        }
    } else {
        res = ZERO;
    }
    s.calc = { v: res, r: formatar(res, op), ver: true };
}

function teclaApagar(s) {
    if (s.fim) {
        s.fim = { texto: "" };
        return;
    }
    if (s.entrada === null)
        return;
    var t = s.entrada;
    if (/e[+-]$/.test(t))
        t = t.substring(0, t.length - 2);
    else
        t = t.substring(0, t.length - 1);
    if (t === "" || t === "-" || t === "-0")
        t = "0";
    s.entrada = t;
}

function teclaConstante(s, v, r) {
    abrirOperando(s);
    s.calc = { v: v, r: r, ver: false };
}

function acao(s, k, op) {
    if (s.erro) {
        if (k === "C" || k === "CE" || k === "apagar" || k === "=") {
            limpar(s);
            return;
        }
        if (/^[0-9]$/.test(k) || k === "virgula" || k === "pi" || k === "e" || k === "(")
            limpar(s);
        else
            return;
    }
    if (/^[0-9]$/.test(k))
        return teclaAlgarismo(s, k, op);
    if (OPERACOES[k])
        return teclaOperacao(s, k, op);
    if (FUNCOES[k])
        return k === "neg" ? teclaNegar(s, op) : teclaFuncao(s, k, op);
    switch (k) {
    case "virgula":
        return teclaVirgula(s);
    case "EXP":
        return teclaExpoente(s);
    case "=":
        return teclaIgual(s, op);
    case "(":
        return teclaAbre(s, op);
    case ")":
        return teclaFecha(s, op);
    case "%":
        return teclaPorcento(s, op);
    case "pi":
        return teclaConstante(s, PI, "π");
    case "e":
        return teclaConstante(s, E, "e");
    case "apagar":
        return teclaApagar(s);
    case "CE":
        if (s.fim)
            return limpar(s);
        s.calc = null;
        s.entrada = "0";
        return;
    case "C":
        return limpar(s);
    }
}

// opcoes: { ingles, angulo: "graus" | "radianos" | "grados", limite: 16 }
function apertar(estado, tecla, opcoes) {
    var op = opcoes || {};
    var s = copiar(estado || novoEstado());
    try {
        acao(s, tecla, op);
    } catch (e) {
        if (!(e instanceof Falha))
            throw e;
        var texto = s.tentativa;
        limpar(s);
        s.erro = e.erroCalc;
        s.fim = { texto: texto };
    }
    return s;
}

// Põe um valor (memória, colar, histórico) no lugar do número atual.
function comValor(estado, texto, opcoes) {
    var v = dParse(texto);
    if (!v)
        return estado;
    var s = copiar(estado || novoEstado());
    if (s.erro)
        limpar(s);
    teclaConstante(s, v, formatar(v, opcoes));
    return s;
}

// Volta uma conta do histórico: a conta em cima e o resultado embaixo.
function restaurar(expressao, texto, opcoes) {
    var s = novoEstado();
    var v = dParse(texto) || ZERO;
    concluir(s, expressao, v, opcoes, false);
    return s;
}

function valorAtual(s) {
    if (s.erro)
        return null;
    if (s.entrada !== null && !s.fim)
        return valorEntrada(s.entrada);
    if (s.calc)
        return s.calc.v;
    return s.mostrado;
}

function visor(s, opcoes) {
    var op = opcoes || {};
    if (s.erro)
        return { expressao: s.fim ? s.fim.texto : "", resultado: mensagemErro(s.erro, op.ingles), erro: true,
                 digitando: false, abertos: 0, valor: "", copiar: "" };
    var v = valorAtual(s);
    var resultado = s.entrada !== null && !s.fim ? formatarEntrada(s.entrada, op) : formatar(v, op);
    return {
        expressao: s.fim ? s.fim.texto : textoAtual(s, op),
        resultado: resultado,
        erro: false,
        digitando: s.entrada !== null && !s.fim,
        abertos: abertos(s.expr),
        valor: dTexto(v),
        copiar: formatar(v, { ingles: op.ingles, semGrupo: true })
    };
}

// Texto colado: "1.234,56", "1,234.56", "R$ 10,00", "1e5", "-3"... ou uma conta ("2+3").
function lerColado(texto, opcoes) {
    var op = opcoes || {};
    var t = String(texto).trim().replace(/[\s  ]/g, "").replace(/[−–]/g, "-")
        .replace(/^(R\$|US\$|\$|€|£)/, "").replace(/^([+-])(R\$|US\$|\$|€|£)/, "$1");
    var m = /^([+-]?)([\d.,]*\d[\d.,]*)(?:[eE]([+-]?\d+))?$/.exec(t);
    if (m) {
        var corpo = m[2];
        var temPonto = corpo.indexOf(".") >= 0, temVirgula = corpo.indexOf(",") >= 0;
        var decimal = "";
        if (temPonto && temVirgula)
            decimal = corpo.lastIndexOf(".") > corpo.lastIndexOf(",") ? "." : ",";
        else if (temVirgula)
            decimal = corpo.split(",").length === 2 && !(op.ingles && /^\d{1,3}(,\d{3})+$/.test(corpo)) ? "," : "";
        else if (temPonto)
            decimal = corpo.split(".").length === 2 && !(!op.ingles && /^\d{1,3}(\.\d{3})+$/.test(corpo)) ? "." : "";
        var grupo = decimal === "," ? /\./g : (decimal === "." ? /,/g : /[.,]/g);
        var limpo = corpo.replace(grupo, "");
        if (decimal)
            limpo = limpo.replace(decimal, ".");
        if (limpo.split(".").length > 2)
            return null;
        try {
            var v = dParse(m[1] + limpo + (m[3] ? "e" + m[3] : ""));
            return v ? dTexto(v) : null;
        } catch (e) {
            return null;
        }
    }
    try {
        var r = avaliarTexto(texto, op);
        return r ? dTexto(r) : null;
    } catch (e2) {
        return null;
    }
}

// Contas com textos guardados (memória): somar("1.5", "2") -> "3.5".
function somar(a, b) {
    return dTexto(dAdd(dParse(a) || ZERO, dParse(b) || ZERO));
}

function subtrair(a, b) {
    return dTexto(dSub(dParse(a) || ZERO, dParse(b) || ZERO));
}

function formatarTexto(texto, opcoes) {
    var v = dParse(texto);
    return v ? formatar(v, opcoes) : "";
}

// ---------------------------------------------------------------------------
// Conversor de unidades
// ---------------------------------------------------------------------------
// Fator de cada unidade para a unidade base da categoria ("a/b" e "pi" valem).
var CATEGORIAS = [
    { id: "comprimento", pt: "Comprimento", en: "Length", unidades: [
        { id: "nm", pt: "Nanômetros", en: "Nanometers", s: "nm", f: "1e-9" },
        { id: "um", pt: "Micrômetros", en: "Micrometers", s: "µm", f: "1e-6" },
        { id: "mm", pt: "Milímetros", en: "Millimeters", s: "mm", f: "0.001" },
        { id: "cm", pt: "Centímetros", en: "Centimeters", s: "cm", f: "0.01" },
        { id: "m", pt: "Metros", en: "Meters", s: "m", f: "1" },
        { id: "km", pt: "Quilômetros", en: "Kilometers", s: "km", f: "1000" },
        { id: "in", pt: "Polegadas", en: "Inches", s: "pol", sEn: "in", f: "0.0254" },
        { id: "ft", pt: "Pés", en: "Feet", s: "pé", sEn: "ft", f: "0.3048" },
        { id: "yd", pt: "Jardas", en: "Yards", s: "jd", sEn: "yd", f: "0.9144" },
        { id: "mi", pt: "Milhas", en: "Miles", s: "mi", f: "1609.344" },
        { id: "nmi", pt: "Milhas náuticas", en: "Nautical miles", s: "M", sEn: "nmi", f: "1852" }
    ], de: "m", para: "cm" },
    { id: "massa", pt: "Massa", en: "Mass", unidades: [
        { id: "mg", pt: "Miligramas", en: "Milligrams", s: "mg", f: "0.000001" },
        { id: "g", pt: "Gramas", en: "Grams", s: "g", f: "0.001" },
        { id: "kg", pt: "Quilogramas", en: "Kilograms", s: "kg", f: "1" },
        { id: "t", pt: "Toneladas", en: "Metric tons", s: "t", f: "1000" },
        { id: "arroba", pt: "Arrobas", en: "Arrobas", s: "@", f: "15" },
        { id: "ct", pt: "Quilates", en: "Carats", s: "ct", f: "0.0002" },
        { id: "oz", pt: "Onças", en: "Ounces", s: "oz", f: "0.028349523125" },
        { id: "lb", pt: "Libras", en: "Pounds", s: "lb", f: "0.45359237" },
        { id: "st", pt: "Stones", en: "Stones", s: "st", f: "6.35029318" }
    ], de: "kg", para: "lb" },
    { id: "temperatura", pt: "Temperatura", en: "Temperature", unidades: [
        { id: "c", pt: "Celsius", en: "Celsius", s: "°C" },
        { id: "f", pt: "Fahrenheit", en: "Fahrenheit", s: "°F" },
        { id: "k", pt: "Kelvin", en: "Kelvin", s: "K" }
    ], de: "c", para: "f" },
    { id: "area", pt: "Área", en: "Area", unidades: [
        { id: "mm2", pt: "Milímetros quadrados", en: "Square millimeters", s: "mm²", f: "0.000001" },
        { id: "cm2", pt: "Centímetros quadrados", en: "Square centimeters", s: "cm²", f: "0.0001" },
        { id: "m2", pt: "Metros quadrados", en: "Square meters", s: "m²", f: "1" },
        { id: "ha", pt: "Hectares", en: "Hectares", s: "ha", f: "10000" },
        { id: "km2", pt: "Quilômetros quadrados", en: "Square kilometers", s: "km²", f: "1000000" },
        { id: "alqp", pt: "Alqueires paulistas", en: "Alqueires (São Paulo)", s: "alq SP", f: "24200" },
        { id: "alqm", pt: "Alqueires mineiros", en: "Alqueires (Minas)", s: "alq MG", f: "48400" },
        { id: "in2", pt: "Polegadas quadradas", en: "Square inches", s: "pol²", sEn: "in²", f: "0.00064516" },
        { id: "ft2", pt: "Pés quadrados", en: "Square feet", s: "pé²", sEn: "ft²", f: "0.09290304" },
        { id: "ac", pt: "Acres", en: "Acres", s: "ac", f: "4046.8564224" }
    ], de: "m2", para: "ha" },
    { id: "volume", pt: "Volume", en: "Volume", unidades: [
        { id: "ml", pt: "Mililitros", en: "Milliliters", s: "mL", f: "0.001" },
        { id: "l", pt: "Litros", en: "Liters", s: "L", f: "1" },
        { id: "m3", pt: "Metros cúbicos", en: "Cubic meters", s: "m³", f: "1000" },
        { id: "cc", pt: "Colheres de chá", en: "Teaspoons", s: "c. chá", sEn: "tsp", f: "0.005" },
        { id: "cs", pt: "Colheres de sopa", en: "Tablespoons", s: "c. sopa", sEn: "tbsp", f: "0.015" },
        { id: "xic", pt: "Xícaras", en: "Cups", s: "xíc.", sEn: "cup", f: "0.24" },
        { id: "floz", pt: "Onças fluidas (EUA)", en: "Fluid ounces (US)", s: "fl oz", f: "0.0295735295625" },
        { id: "gal", pt: "Galões (EUA)", en: "Gallons (US)", s: "gal", f: "3.785411784" },
        { id: "galuk", pt: "Galões imperiais", en: "Gallons (UK)", s: "gal UK", f: "4.54609" },
        { id: "ft3", pt: "Pés cúbicos", en: "Cubic feet", s: "pé³", sEn: "ft³", f: "28.316846592" }
    ], de: "l", para: "ml" },
    { id: "velocidade", pt: "Velocidade", en: "Speed", unidades: [
        { id: "ms", pt: "Metros por segundo", en: "Meters per second", s: "m/s", f: "1" },
        { id: "kmh", pt: "Quilômetros por hora", en: "Kilometers per hour", s: "km/h", f: "1000/3600" },
        { id: "mph", pt: "Milhas por hora", en: "Miles per hour", s: "mph", f: "0.44704" },
        { id: "no", pt: "Nós", en: "Knots", s: "nó", sEn: "kn", f: "1852/3600" },
        { id: "fts", pt: "Pés por segundo", en: "Feet per second", s: "pé/s", sEn: "ft/s", f: "0.3048" },
        { id: "mach", pt: "Mach", en: "Mach", s: "Mach", f: "340.3" }
    ], de: "kmh", para: "ms" },
    { id: "tempo", pt: "Tempo", en: "Time", unidades: [
        { id: "us", pt: "Microssegundos", en: "Microseconds", s: "µs", f: "0.000001" },
        { id: "msg", pt: "Milissegundos", en: "Milliseconds", s: "ms", f: "0.001" },
        { id: "s", pt: "Segundos", en: "Seconds", s: "s", f: "1" },
        { id: "min", pt: "Minutos", en: "Minutes", s: "min", f: "60" },
        { id: "h", pt: "Horas", en: "Hours", s: "h", f: "3600" },
        { id: "d", pt: "Dias", en: "Days", s: "d", f: "86400" },
        { id: "sem", pt: "Semanas", en: "Weeks", s: "sem.", sEn: "wk", f: "604800" },
        { id: "ano", pt: "Anos (365 dias)", en: "Years (365 days)", s: "anos", sEn: "yr", f: "31536000" }
    ], de: "h", para: "min" },
    { id: "dados", pt: "Dados", en: "Data", unidades: [
        { id: "bit", pt: "Bits", en: "Bits", s: "bit", f: "1/8" },
        { id: "B", pt: "Bytes", en: "Bytes", s: "B", f: "1" },
        { id: "KB", pt: "Kilobytes", en: "Kilobytes", s: "KB", f: "1000" },
        { id: "MB", pt: "Megabytes", en: "Megabytes", s: "MB", f: "1000000" },
        { id: "GB", pt: "Gigabytes", en: "Gigabytes", s: "GB", f: "1000000000" },
        { id: "TB", pt: "Terabytes", en: "Terabytes", s: "TB", f: "1000000000000" },
        { id: "Mbit", pt: "Megabits", en: "Megabits", s: "Mb", f: "125000" },
        { id: "KiB", pt: "Kibibytes (1024)", en: "Kibibytes (1024)", s: "KiB", f: "1024" },
        { id: "MiB", pt: "Mebibytes (1024²)", en: "Mebibytes (1024²)", s: "MiB", f: "1048576" },
        { id: "GiB", pt: "Gibibytes (1024³)", en: "Gibibytes (1024³)", s: "GiB", f: "1073741824" },
        { id: "TiB", pt: "Tebibytes (1024⁴)", en: "Tebibytes (1024⁴)", s: "TiB", f: "1099511627776" }
    ], de: "GB", para: "MB" },
    { id: "angulo", pt: "Ângulo", en: "Angle", unidades: [
        { id: "grau", pt: "Graus", en: "Degrees", s: "°", f: "1" },
        { id: "rad", pt: "Radianos", en: "Radians", s: "rad", f: "180/pi" },
        { id: "grado", pt: "Grados", en: "Gradians", s: "grad", f: "0.9" },
        { id: "minarc", pt: "Minutos de arco", en: "Arcminutes", s: "′", f: "1/60" },
        { id: "segarc", pt: "Segundos de arco", en: "Arcseconds", s: "″", f: "1/3600" },
        { id: "volta", pt: "Voltas", en: "Turns", s: "volta", sEn: "turn", f: "360" }
    ], de: "grau", para: "rad" }
];

function categoria(id) {
    for (var i = 0; i < CATEGORIAS.length; i++)
        if (CATEGORIAS[i].id === id)
            return CATEGORIAS[i];
    return CATEGORIAS[0];
}

function unidade(cat, id) {
    var c = typeof cat === "string" ? categoria(cat) : cat;
    for (var i = 0; i < c.unidades.length; i++)
        if (c.unidades[i].id === id)
            return c.unidades[i];
    return c.unidades[0];
}

function fatorParte(t) {
    return t === "pi" ? PI : dParse(t);
}

// [numerador, denominador] do fator de uma unidade.
function fator(u) {
    var p = String(u.f).split("/");
    return [fatorParte(p[0]), p.length > 1 ? fatorParte(p[1]) : UM];
}

function paraCelsius(v, u) {
    if (u === "f")
        return dDiv(dMul(dSub(v, dInt(32)), dInt(5)), dInt(9));
    if (u === "k")
        return dSub(v, dParse("273.15"));
    return v;
}

function deCelsius(v, u) {
    if (u === "f")
        return dAdd(dDiv(dMul(v, dInt(9)), dInt(5)), dInt(32));
    if (u === "k")
        return dAdd(v, dParse("273.15"));
    return v;
}

function converterValor(v, cat, de, para) {
    if (cat === "temperatura")
        return deCelsius(paraCelsius(v, de), para);
    var c = categoria(cat);
    var a = fator(unidade(c, de)), b = fator(unidade(c, para));
    return dDiv(dMul(dMul(v, a[0], PREC + 6), b[1], PREC + 6), dMul(a[1], b[0], PREC + 6));
}

// converter("1", "comprimento", "in", "cm") -> "2.54"
function converter(texto, cat, de, para) {
    var v = dParse(texto);
    if (!v)
        return null;
    try {
        return dTexto(converterValor(v, cat, de, para));
    } catch (e) {
        if (e instanceof Falha)
            return null;
        throw e;
    }
}

// "1 m = 3,28084 pés" (a taxa da conversão, com 7 algarismos).
function taxa(cat, de, para, opcoes) {
    var op = opcoes || {};
    var c = categoria(cat);
    var ud = unidade(c, de), up = unidade(c, para);
    var sd = op.ingles && ud.sEn ? ud.sEn : ud.s, sp = op.ingles && up.sEn ? up.sEn : up.s;
    if (cat === "temperatura") {
        // Temperatura não é proporcional: a fórmula diz mais que "1 °C = 33,8 °F".
        var k = op.ingles ? "273.15" : "273,15";
        var formulas = {
            "c>f": "°F = °C × 9/5 + 32", "f>c": "°C = (°F − 32) × 5/9",
            "c>k": "K = °C + " + k, "k>c": "°C = K − " + k,
            "f>k": "K = (°F − 32) × 5/9 + " + k, "k>f": "°F = (K − " + k + ") × 9/5 + 32"
        };
        return formulas[de + ">" + para] || (sd + " = " + sp);
    }
    var junto = function (n, s) {
        return n + (s === "°" || s === "′" || s === "″" ? "" : " ") + s;
    };
    var v = converterValor(UM, cat, de, para);
    return junto("1", sd) + " = " + junto(formatar(v, { ingles: op.ingles, algarismos: 7 }), sp);
}

// Os textos de uma entrada do conversor: o que se digita, com o sinal só na temperatura.
function digitarConversor(texto, tecla, permiteNegativo) {
    var t = texto || "0";
    if (/^[0-9]$/.test(tecla)) {
        if (contaAlgarismos(t) >= MOSTRA)
            return t;
        if (t === "0")
            return tecla;
        if (t === "-0")
            return "-" + tecla;
        return t + tecla;
    }
    if (tecla === "virgula")
        return t.indexOf(".") >= 0 ? t : t + ".";
    if (tecla === "apagar") {
        t = t.substring(0, t.length - 1);
        return t === "" || t === "-" || t === "-0" ? "0" : t;
    }
    if (tecla === "neg" && permiteNegativo)
        return t.charAt(0) === "-" ? t.substring(1) : (t === "0" ? t : "-" + t);
    if (tecla === "CE" || tecla === "C")
        return "0";
    return t;
}

// Para editar um valor calculado: o texto com até 16 algarismos ("2.54").
function textoEditavel(texto) {
    var v = dParse(texto);
    if (!v)
        return "0";
    var r = dRound(v, MOSTRA);
    var ex = dOrdem(r);
    if (ex >= MOSTRA || ex < -5)
        return dTexto(r);
    if (ex < 0)
        r = dRoundCasas(r, MOSTRA);
    return dTexto(r);
}
