// Testes da conta da ampliação da doca (org.matsu.doca/contents/code/zoom.js).
// Uso: node tests/test_doca.js
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ARQ = path.join(__dirname, "..", "system_files", "usr", "share", "plasma", "plasmoids", "org.matsu.doca", "contents", "code", "zoom.js");
const contexto = {};
vm.runInNewContext(fs.readFileSync(ARQ, "utf8").replace(".pragma library", ""), contexto);
const Z = contexto;

let passou = 0, falhou = 0;
function confere(desc, ok, extra) {
  if (ok) { passou++; console.log("  ok   " + desc); }
  else { falhou++; console.log("  FAIL " + desc + (extra !== undefined ? "\n       | " + extra : "")); }
}
const perto = (a, b, e = 0.001) => Math.abs(a - b) <= e;

// Oito apps de 48 px, um vão de 12 px e a lixeira.
const C = 48;
const pedacos = [];
for (let i = 0; i < 8; i++) pedacos.push({ tamanho: C, cresce: true });
pedacos.push({ tamanho: 12, cresce: false });
pedacos.push({ tamanho: C, cresce: true });
const base = []; { let p = 0; for (const x of pedacos) { base.push(p); p += x.tamanho; } }

console.log("escala");
confere("longe do mouse não cresce", Z.escala(500, 2, 144, 1) === 1);
confere("em cima do mouse cresce até o máximo", perto(Z.escala(0, 2, 144, 1), 2));
confere("a curva é igual dos dois lados", perto(Z.escala(-40, 2, 144, 1), Z.escala(40, 2, 144, 1)));
confere("a curva só desce", Z.escala(10, 2, 144, 1) > Z.escala(60, 2, 144, 1) && Z.escala(60, 2, 144, 1) > Z.escala(120, 2, 144, 1));
confere("sem força (animação no começo) não cresce", Z.escala(0, 2, 144, 0) === 1);
confere("meia força cresce a metade", perto(Z.escala(0, 2, 144, 0.5), 1.5));
confere("máximo 1 (ampliação desligada) não cresce", Z.escala(0, 1, 144, 1) === 1);
confere("nível 0 = 1,3x e 100 = 2,2x", perto(Z.maximoDoNivel(0), 1.3) && perto(Z.maximoDoNivel(100), 2.2));
confere("nível fora da faixa fica na faixa", perto(Z.maximoDoNivel(500), 2.2) && perto(Z.maximoDoNivel(-3), 1.3));

console.log("arrumar");
{
  const r = Z.arrumar(pedacos, 100, 2, 3 * C, 0);
  confere("sem força a fileira fica igual", r.inicio.every((x, i) => perto(x, base[i])) && r.tamanho.every((t, i) => perto(t, pedacos[i].tamanho)));
}
for (const mouse of [3, 30, 100, 190, 250, 383, 390, 400, 430, 443]) {
  const r = Z.arrumar(pedacos, mouse, 1.8, 3 * C, 1);
  // O pedaço embaixo do mouse continua embaixo do mouse, no mesmo ponto relativo.
  let k = pedacos.length - 1;
  for (let i = 0; i < pedacos.length; i++) if (mouse < base[i] + pedacos[i].tamanho) { k = i; break; }
  const u = (mouse - base[k]) / pedacos[k].tamanho;
  const uNovo = (mouse - r.inicio[k]) / r.tamanho[k];
  confere("mouse em " + mouse + ": o app embaixo do mouse fica embaixo do mouse", perto(u, uNovo), u + " x " + uNovo);
  // Sem buraco nem sobreposição entre os pedaços.
  let colado = true;
  for (let i = 1; i < pedacos.length; i++) if (!perto(r.inicio[i], r.inicio[i - 1] + r.tamanho[i - 1])) colado = false;
  confere("mouse em " + mouse + ": os pedaços ficam colados, sem sobrepor", colado);
  confere("mouse em " + mouse + ": o vão não cresce", perto(r.tamanho[8], 12));
}
{
  // Andar com o mouse não dá pulo (a fileira muda aos pouquinhos).
  let maiorPulo = 0, antes = null;
  for (let m = 0; m <= 440; m += 0.5) {
    const r = Z.arrumar(pedacos, m, 2.2, 3 * C, 1);
    if (antes) for (let i = 0; i < r.inicio.length; i++) maiorPulo = Math.max(maiorPulo, Math.abs(r.inicio[i] - antes.inicio[i]));
    antes = r;
  }
  confere("andar meio pixel nunca move um app mais de 2 px", maiorPulo < 2, maiorPulo);
}
{
  const r = Z.arrumar(pedacos, base[4] + C / 2, 2, 3 * C, 1);
  confere("no meio da fileira, ela abre para os dois lados", r.inicio[0] < 0 && r.inicio[9] + r.tamanho[9] > base[9] + C);
  confere("o app do meio é o maior", r.escala[4] === Math.max(...r.escala));
  const sobra = Z.sobraMaxima(C, 2, 3 * C);
  confere("a sobra máxima cobre o quanto passou das pontas", -r.inicio[0] <= sobra && (r.inicio[9] + r.tamanho[9] - (base[9] + C)) <= sobra, sobra);
}
{
  const ponta = Z.arrumar(pedacos, 2, 2.2, 3 * C, 1);
  const sobra = Z.sobraMaxima(C, 2.2, 3 * C);
  const passou = ponta.inicio[9] + ponta.tamanho[9] - (base[9] + C);
  confere("mouse na ponta: a fileira abre para o outro lado, dentro da sobra", passou > 0 && passou <= sobra, passou + " <= " + sobra);
  confere("sem ampliação não sobra nada", Z.sobraMaxima(C, 1, 3 * C) === 0);
}
confere("fileira vazia não quebra", Z.arrumar([], 10, 2, 100, 1).inicio.length === 0);

console.log("\n" + passou + " ok, " + falhou + " falharam");
process.exit(falhou ? 1 : 0);
