// Testes das contas da Calculadora do Matsu (system_files/usr/share/matsu/calculadora/calculo.js),
// rodado como o QML roda (o arquivo é ".pragma library"): precedência, parênteses,
// porcentagem do Windows, precisão decimal, conversões, erros e números em pt-BR.
// Uso: node tests/test_calculadora.js
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ARQUIVO = path.join(__dirname, "..", "system_files", "usr", "share", "matsu", "calculadora", "calculo.js");
const codigo = fs.readFileSync(ARQUIVO, "utf8").replace(/^\.pragma library/m, "");
const C = vm.runInNewContext(codigo + "\n;({ novoEstado, apertar, visor, comValor, restaurar, avaliarTexto, lerColado," +
  " formatar, formatarEntrada, dParse, dTexto, dAdd, dSub, dMul, dDiv, converter, taxa, categoria, CATEGORIAS," +
  " digitarConversor, textoEditavel, somar, subtrair, formatarTexto, mensagemErro, aplicarFuncao })", {});

let passou = 0, falhou = 0;
function confere(desc, ok, extra) {
  if (ok) { passou++; console.log("  ok   " + desc); }
  else { falhou++; console.log("  FAIL " + desc + (extra !== undefined ? "\n       | " + extra : "")); }
}
function igual(desc, obtido, esperado) {
  confere(desc, obtido === esperado, "obtido " + JSON.stringify(obtido) + ", esperado " + JSON.stringify(esperado));
}

// Aperta as teclas de um texto: "12+3*4=" (vírgula ou ponto = separador decimal).
const NOMES = { ",": "virgula", ".": "virgula", "s": "raiz", "q": "quadrado", "r": "inverso", "!": "fatorial",
  "n": "neg", "p": "pi", "E": "EXP", "<": "apagar" };
function teclas(seq, op, estado) {
  let s = estado || C.novoEstado();
  const lista = Array.isArray(seq) ? seq : seq.split("");
  for (const t of lista) s = C.apertar(s, NOMES[t] || t, op || {});
  return s;
}
function conta(seq, op) { return C.visor(teclas(seq, op), op || {}); }
function res(seq, op) { return conta(seq, op).resultado; }
const M = "−"; // o sinal de menos do visor

console.log("precedência e parênteses");
igual("2 + 3 × 4 = 14", res("2+3*4="), "14");
igual("2 × 3 + 4 = 10", res("2*3+4="), "10");
igual("10 − 4 − 3 = 3 (da esquerda para a direita)", res("10-4-3="), "3");
igual("100 ÷ 10 ÷ 5 = 2", res("100/10/5="), "2");
igual("2 ^ 3 ^ 2 = 512 (potência da direita para a esquerda)", res("2^3^2="), "512");
igual("(2 + 3) × 4 = 20", res("(2+3)*4="), "20");
igual("2 × (3 + 4) = 14", res("2*(3+4)="), "14");
igual("((1 + 2) × (3 + 4)) = 21", res("((1+2)*(3+4))="), "21");
igual("parêntese aberto fecha sozinho no =", res("2*(3+4="), "14");
igual("2(3 + 4) multiplica sem o ×", res("2(3+4)="), "14");
igual("(2 + 3)4 multiplica sem o ×", res("(2+3)4="), "20");
igual("1 + 2 × 3 ^ 2 = 19", res("1+2*3^2="), "19");
igual("17 mod 5 = 2", res(["1", "7", "mod", "5", "="]), "2");
igual("−7 mod 3 = −1 (sinal do dividendo)", res(["7", "neg", "mod", "3", "="]), M + "1");
let v = conta("2+3*");
igual("2 + 3 × mostra 3 no visor (ainda falta o 4)", v.resultado, "3");
igual("a conta em cima: 2 + 3 ×", v.expressao, "2 + 3 ×");
v = conta("2*3+");
igual("2 × 3 + mostra o parcial 6", v.resultado, "6");
v = conta("12*3=");
igual("a conta em cima depois do =: 12 × 3 =", v.expressao, "12 × 3 =");
igual("12 × 3 = 36", v.resultado, "36");
igual("trocar a operação: 5 + × 2 = 10", res("5+*2="), "10");
igual("5 + = repete o número: 10", res("5+="), "10");
igual("= de novo repete a última operação: 2 + 3 = = dá 8", res("2+3=="), "8");
igual("(2 + 3) × 4 = mostra a conta com parênteses", conta("(2+3)*4=").expressao, "(2 + 3) × 4 =");
igual("abertos conta os parênteses", conta("((2").abertos, 2);
igual("depois do =, um número começa outra conta", res("2+3=7"), "7");
igual("depois do =, uma operação continua do resultado", res("2+3=*2="), "10");
igual("texto: 2+3*4", C.dTexto(C.avaliarTexto("2+3*4")), "14");
igual("texto: (1,5+2)×3", C.dTexto(C.avaliarTexto("(1,5+2)×3")), "10.5");
igual("texto: -2^2 com sinal na frente", C.dTexto(C.avaliarTexto("-(2)+5")), "3");
igual("texto: conta quebrada dá null", C.avaliarTexto("2+*3"), null);

console.log("porcentagem como no Windows");
igual("200 + 10% = 220", res("200+10%="), "220");
igual("200 − 10% = 180", res("200-10%="), "180");
igual("200 × 10% = 20", res("200*10%="), "20");
igual("200 ÷ 10% = 2.000", res("200/10%="), "2.000");
v = conta("200+10%");
igual("200 + 10% mostra 20 no visor", v.resultado, "20");
igual("e a conta em cima: 200 + 20", v.expressao, "200 + 20");
igual("50% sozinho dá 0 (como no Windows)", res("50%"), "0");
igual("2 × 3 + 10% usa o 6 da esquerda", res("2*3+10%="), "6,6");

console.log("precisão decimal");
igual("0,1 + 0,2 = 0,3", res("0,1+0,2="), "0,3");
igual("0,3 − 0,1 = 0,2", res("0.3-0.1="), "0,2");
igual("1,1 × 1,1 = 1,21", res("1,1*1,1="), "1,21");
igual("1 ÷ 3 = 0,3333333333333333", res("1/3="), "0,3333333333333333");
igual("2 ÷ 3 = 0,6666666666666667 (arredonda)", res("2/3="), "0,6666666666666667");
igual("1 ÷ 3 × 3 = 1", res("1/3*3="), "1");
igual("√2 × √2 = 2", res(["2", "raiz", "*", "2", "raiz", "="]), "2");
igual("0,1 × 3 = 0,3", res("0,1*3="), "0,3");
igual("1.000.000 × 1.000.000 = 1.000.000.000.000", res("1000000*1000000="), "1.000.000.000.000");
igual("9999999999999999 + 1 = 10.000.000.000.000.000", res("9999999999999999+1="), "1e+16");
igual("1 − 0,9 = 0,1", res("1-0,9="), "0,1");
igual("4,35 × 100 = 435", res("4,35*100="), "435");
igual("1,15 + 2,2 = 3,35", res("1,15+2,2="), "3,35");
igual("somar textos da memória", C.somar("0.1", "0.2"), "0.3");
igual("subtrair textos da memória", C.subtrair("1", "0.9"), "0.1");

console.log("funções científicas");
const G = { angulo: "graus" }, R = { angulo: "radianos" };
igual("√9 = 3", res("9s"), "3");
igual("√2,25 = 1,5", res("2,25s"), "1,5");
igual("√2 = 1,414213562373095", res("2s"), "1,414213562373095");
igual("5² = 25", res("5q"), "25");
igual("1/4 = 0,25", res("4r"), "0,25");
igual("5! = 120", res("5!"), "120");
igual("0! = 1", res("0!"), "1");
igual("20! = 2.432.902.008.176.640.000 (vira e+18)", res("20!"), "2,43290200817664e+18");
igual("0,5! = Γ(1,5) = 0,886226925452758", res("0,5!"), "0,886226925452758");
igual("sen 30° = 0,5", res(["3", "0", "sen"], G), "0,5");
igual("cos 60° = 0,5", res(["6", "0", "cos"], G), "0,5");
igual("cos 90° = 0", res(["9", "0", "cos"], G), "0");
igual("sen 180° = 0", res(["1", "8", "0", "sen"], G), "0");
igual("tan 45° = 1", res(["4", "5", "tan"], G), "1");
igual("sen 390° = 0,5", res(["3", "9", "0", "sen"], G), "0,5");
igual("sen −30° = −0,5", res(["3", "0", "neg", "sen"], G), M + "0,5");
igual("tan 90° = Entrada inválida", res(["9", "0", "tan"], G), "Entrada inválida");
igual("sen π (rad) = 0", res(["pi", "sen"], R), "0");
igual("cos π (rad) = −1", res(["pi", "cos"], R), M + "1");
igual("sen 1 rad = 0,841470984807897", res(["1", "sen"], R), "0,841470984807897");
igual("sen⁻¹ 0,5 = 30°", res(["0", "virgula", "5", "asen"], G), "30");
igual("cos⁻¹ −1 = π (rad)", res(["1", "neg", "acos"], R), "3,141592653589793");
igual("log 1000 = 3", res(["1", "0", "0", "0", "log"]), "3");
igual("log 2 = 0,301029995663981", res(["2", "log"]), "0,301029995663981");
igual("ln e = 1", res(["e", "ln"]), "1");
igual("ln 0 = Entrada inválida", res(["0", "ln"]), "Entrada inválida");
igual("2 ^ 10 = 1.024", res("2^10="), "1.024");
igual("2 ^ −2 = 0,25", res(["2", "^", "2", "neg", "="]), "0,25");
igual("2 ^ 0,5 = √2", res("2^0,5="), "1,414213562373095");
igual("2 ^ 0,3 = 1,23114441334492", res("2^0,3="), "1,23114441334492");
igual("(−0,5)! = √π", res(["0", "virgula", "5", "neg", "fatorial"]), "1,772453850905516");
igual("1,5! = 1,329340388179137", res("1,5!"), "1,329340388179137");
igual("27 ʸ√ 3 = 3", res(["2", "7", "raizy", "3", "="]), "3");
igual("−8 ʸ√ 3 = −2", res(["8", "neg", "raizy", "3", "="]), M + "2");
igual("−8 ʸ√ 2 = Entrada inválida", res(["8", "neg", "raizy", "2", "="]), "Entrada inválida");
igual("10ˣ de 3 = 1.000", res(["3", "dez"]), "1.000");
igual("eˣ de 1 = e", res(["1", "exp"]), "2,718281828459045");
igual("π = 3,141592653589793", res(["pi"]), "3,141592653589793");
igual("e = 2,718281828459045", res(["e"]), "2,718281828459045");
igual("|−5| = 5", res(["5", "neg", "abs"]), "5");
igual("2π: 2 × π = 6,283185307179586", res(["2", "*", "pi", "="]), "6,283185307179586");
v = conta("9s");
igual("√ mostra a função em cima: √(9)", v.expressao, "√(9)");
v = conta(["5", "+", "9", "raiz"]);
igual("5 + √(9) em cima", v.expressao, "5 + √(9)");
igual("e o resultado 5 + √9 = 8", res(["5", "+", "9", "raiz", "="]), "8");
igual("(2 + 3)² = 25", res(["(", "2", "+", "3", ")", "quadrado", "="]), "25");
igual("(2 + 3)² em cima", conta(["(", "2", "+", "3", ")", "quadrado"]).expressao, "(2 + 3)²");
igual("sen(30°) em cima", conta(["3", "0", "sen"], G).expressao, "sen(30°)");
igual("sin em inglês", conta(["3", "0", "sen"], { angulo: "graus", ingles: true }).expressao, "sin(30°)");
igual("± depois do = nega o resultado", res("2+3=n"), M + "5");

console.log("digitando");
igual("número com milhar", res("1234567"), "1.234.567");
igual("vírgula no fim enquanto digita", res("12,"), "12,");
igual("ponto também é vírgula", res("3.5"), "3,5");
igual("zeros depois da vírgula ficam", res("1,50"), "1,50");
igual("só uma vírgula", res("1,2,3"), "1,23");
igual("zero à esquerda some", res("007"), "7");
igual("apagar o último algarismo", res("123<"), "12");
igual("apagar tudo deixa 0", res("1<<"), "0");
igual("± no que está digitando", res("12n"), M + "12");
igual("limite de 16 algarismos", res("12345678901234567890"), "1.234.567.890.123.456");
igual("EXP: 1,5 EXP 3 = 1.500", res("1,5E3="), "1.500");
igual("EXP mostra 1,5e+3 enquanto digita", res("1,5E3"), "1,5e+3");
igual("EXP com ± no expoente", res("2E3n="), "0,002");
igual("CE limpa só o número", res(["5", "+", "3", "CE", "4", "="]), "9");
igual("C limpa tudo", conta(["5", "+", "3", "C"]).expressao, "");
igual("inglês: 1,234.5", res("1234.5", { ingles: true }), "1,234.5");
v = C.visor(teclas("2+3="), {});
igual("valor guardado do resultado", v.valor, "5");
igual("texto para copiar sem milhar", C.visor(teclas("1234567,5"), {}).copiar, "1234567,5");
igual("copiar negativo com hífen", C.visor(teclas("5n"), {}).copiar, "-5");

console.log("erros");
igual("1 ÷ 0", res("1/0="), "Não é possível dividir por zero");
igual("0 ÷ 0", res("0/0="), "Resultado indefinido");
igual("1/x de 0", res("0r"), "Não é possível dividir por zero");
igual("√ de negativo", res(["4", "neg", "raiz"]), "Entrada inválida");
igual("fatorial de negativo", res(["3", "neg", "fatorial"]), "Entrada inválida");
igual("log de negativo", res(["2", "neg", "log"]), "Entrada inválida");
igual("10 ^ 10000 estoura", res(["1", "0", "^", "1", "0", "0", "0", "0", "="]), "Estouro");
igual("5000! estoura", res(["5", "0", "0", "0", "fatorial"]), "Estouro");
v = conta("1/0=");
confere("erro marcado no visor", v.erro === true);
igual("a conta que deu erro fica em cima", v.expressao, "1 ÷ 0 =");
igual("depois do erro, um número começa de novo", res("1/0=7"), "7");
igual("depois do erro, operação é ignorada", res("1/0=+"), "Não é possível dividir por zero");
igual("C tira o erro", res("1/0=C"), "0");
igual("erro em inglês", res("1/0=", { ingles: true }), "Cannot divide by zero");
igual("mensagem de entrada inválida", C.mensagemErro("invalida", false), "Entrada inválida");
igual("divisão por zero no meio da conta: 5 ÷ 0 +", res("5/0+"), "Não é possível dividir por zero");

console.log("formatação pt-BR");
const f = (t, op) => C.formatar(C.dParse(t), op);
igual("1.234.567,89", f("1234567.89"), "1.234.567,89");
igual("negativo com o sinal de menos", f("-1234.5"), M + "1.234,5");
igual("número enorme vira 1,23e+25", f("1.23e25"), "1,23e+25");
igual("10^16 vira 1e+16", f("1e16"), "1e+16");
igual("9.999.999.999.999.999 → 1e+16 (arredonda a 16)", f("9999999999999999.9"), "1e+16");
igual("número pequeno: 0,00001234", f("0.00001234"), "0,00001234");
igual("bem pequeno vira 1,234e−7", f("0.0000001234"), "1,234e" + M + "7");
igual("zero", f("0"), "0");
igual("inteiro sem vírgula", f("42"), "42");
igual("inglês: 1,234,567.89", f("1234567.89", { ingles: true }), "1,234,567.89");
igual("inglês: 1.23e+25", f("1.23e25", { ingles: true }), "1.23e+25");
igual("sem milhar (copiar)", f("1234567.89", { semGrupo: true }), "1234567,89");
igual("7 algarismos para a taxa", f("3.28083989501312", { algarismos: 7 }), "3,28084");
igual("entrada: 1234,5 digitando", C.formatarEntrada("1234.5", {}), "1.234,5");
igual("entrada: -0, digitando", C.formatarEntrada("-0.", {}), M + "0,");
igual("entrada com expoente", C.formatarEntrada("1.5e-3", {}), "1,5e" + M + "3");
igual("texto de memória formatado", C.formatarTexto("-2500.75", {}), M + "2.500,75");

console.log("colar");
igual("1.234,56 (pt)", C.lerColado("1.234,56", {}), "1234.56");
igual("1,234.56 (en)", C.lerColado("1,234.56", { ingles: true }), "1234.56");
igual("1.234 no pt é mil duzentos e trinta e quatro", C.lerColado("1.234", {}), "1234");
igual("3.14 no pt é decimal", C.lerColado("3.14", {}), "3.14");
igual("12,5", C.lerColado("12,5", {}), "12.5");
igual("R$ 1.500,00", C.lerColado("R$ 1.500,00", {}), "1500");
igual("−42 com o sinal de menos", C.lerColado("−42", {}), "-42");
igual("1e5", C.lerColado("1e5", {}), "100000");
igual("espaços em volta", C.lerColado("  7  ", {}), "7");
igual("uma conta colada: 2+3×4", C.lerColado("2+3×4", {}), "14");
igual("texto qualquer não cola", C.lerColado("banana", {}), null);
let s = C.comValor(teclas("5+"), "2.5", {});
igual("valor colado entra no lugar do número", C.visor(C.apertar(s, "=", {}), {}).resultado, "7,5");
s = C.restaurar("12 × 3 =", "36", {});
igual("voltar do histórico mostra a conta", C.visor(s, {}).expressao, "12 × 3 =");
igual("e o resultado", C.visor(s, {}).resultado, "36");
s = C.apertar(teclas("12*3="), "=", {});
confere("o = de novo também vai para o histórico", s.registro && s.registro.expressao === "36 × 3 =", JSON.stringify(s.registro));
s = teclas("2+3=");
confere("o = devolve o registro do histórico", s.registro && s.registro.expressao === "2 + 3 =" && s.registro.valor === "5", JSON.stringify(s.registro));
s = teclas("7=");
confere("7 = sozinho não vai para o histórico", s.registro === null);

console.log("conversor");
const cv = (v, c, a, b) => C.converter(v, c, a, b);
igual("1 polegada = 2,54 cm", cv("1", "comprimento", "in", "cm"), "2.54");
igual("1 milha = 1,609344 km", cv("1", "comprimento", "mi", "km"), "1.609344");
igual("1 m = 100 cm", cv("1", "comprimento", "m", "cm"), "100");
igual("100 °C = 212 °F", cv("100", "temperatura", "c", "f"), "212");
igual("98,6 °F = 37 °C", cv("98.6", "temperatura", "f", "c"), "37");
igual("0 °C = 273,15 K", cv("0", "temperatura", "c", "k"), "273.15");
igual("−40 °F = −40 °C", cv("-40", "temperatura", "f", "c"), "-40");
igual("1 kg = 2,204622621848776 lb", C.formatar(C.dParse(cv("1", "massa", "kg", "lb"))), "2,204622621848776");
igual("1 arroba = 15 kg", cv("1", "massa", "arroba", "kg"), "15");
igual("1 hectare = 10.000 m²", cv("1", "area", "ha", "m2"), "10000");
igual("1 alqueire paulista = 2,42 ha", cv("1", "area", "alqp", "ha"), "2.42");
igual("1 L = 1.000 mL", cv("1", "volume", "l", "ml"), "1000");
igual("1 m³ = 1.000 L", cv("1", "volume", "m3", "l"), "1000");
igual("100 km/h = 27,77777777777778 m/s", C.formatar(C.dParse(cv("100", "velocidade", "kmh", "ms"))), "27,77777777777778");
igual("36 km/h = 10 m/s", cv("36", "velocidade", "kmh", "ms"), "10");
igual("1 h = 60 min", cv("1", "tempo", "h", "min"), "60");
igual("1 dia = 86.400 s", cv("1", "tempo", "d", "s"), "86400");
igual("1 GB = 1.000 MB", cv("1", "dados", "GB", "MB"), "1000");
igual("1 GiB = 1.024 MiB", cv("1", "dados", "GiB", "MiB"), "1024");
igual("1 byte = 8 bits", cv("1", "dados", "B", "bit"), "8");
igual("100 Mb = 12,5 MB (internet)", cv("100", "dados", "Mbit", "MB"), "12.5");
igual("180° = π rad", C.formatar(C.dParse(cv("180", "angulo", "grau", "rad"))), "3,141592653589793");
igual("π rad = 180°", C.formatar(C.dParse(cv("3.14159265358979323846264338327950288", "angulo", "rad", "grau"))), "180");
igual("1 volta = 360°", cv("1", "angulo", "volta", "grau"), "360");
igual("taxa: 1 m = 3,28084 pé", C.taxa("comprimento", "m", "ft", {}), "1 m = 3,28084 pé");
igual("taxa em inglês: 1 m = 3.28084 ft", C.taxa("comprimento", "m", "ft", { ingles: true }), "1 m = 3.28084 ft");
igual("taxa de graus sem espaço", C.taxa("angulo", "rad", "grau", {}), "1 rad = 57,29578°");
confere("todas as categorias têm de e para válidos", C.CATEGORIAS.every((c) => c.unidades.some((u) => u.id === c.de) && c.unidades.some((u) => u.id === c.para)));
confere("9 categorias", C.CATEGORIAS.length === 9);
let ok = true, ruim = "";
for (const c of C.CATEGORIAS) for (const a of c.unidades) for (const b of c.unidades) {
  const ida = cv("7", c.id, a.id, b.id), volta = cv(ida, c.id, b.id, a.id);
  if (ida === null || C.formatar(C.dParse(volta)) !== "7") { ok = false; ruim += c.id + ":" + a.id + "->" + b.id + " "; }
}
confere("ida e volta em todas as unidades dá o mesmo número", ok, ruim);
igual("digitar no conversor", C.digitarConversor("12", "3", false), "123");
igual("vírgula no conversor", C.digitarConversor("12", "virgula", false), "12.");
igual("± só com temperatura", C.digitarConversor("12", "neg", false), "12");
igual("± na temperatura", C.digitarConversor("12", "neg", true), "-12");
igual("apagar no conversor", C.digitarConversor("1", "apagar", false), "0");
igual("valor calculado vira texto editável", C.textoEditavel("0.27777777777777777777777777777778"), "0.2777777777777778");

console.log("\n" + passou + " ok, " + falhou + " falhas");
process.exit(falhou ? 1 : 0);
