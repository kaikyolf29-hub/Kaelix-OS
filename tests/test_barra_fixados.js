// Testes do roteiro dos apps fixados na barra (system_files/usr/share/matsu/barra/fixados.js),
// rodado como o Plasma roda: comum.js + fixados.js, com uma área de trabalho falsa.
// Uso: node tests/test_barra_fixados.js
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const BARRA = path.join(__dirname, "..", "system_files", "usr", "share", "matsu", "barra");
const codigo = fs.readFileSync(path.join(BARRA, "comum.js"), "utf8") + "\n" + fs.readFileSync(path.join(BARRA, "fixados.js"), "utf8");

let passou = 0, falhou = 0;
function confere(desc, ok, extra) {
  if (ok) { passou++; console.log("  ok   " + desc); }
  else { falhou++; console.log("  FAIL " + desc + (extra ? "\n       | " + extra : "")); }
}

// Uma peça falsa do Plasma com a configuração guardada num objeto.
function peca(tipo, fixados) {
  const config = { "General/launchers": fixados ? fixados.join(",") : "" };
  return {
    type: tipo,
    currentConfigGroup: [],
    readConfig(chave, padrao) { const v = config[this.currentConfigGroup.join("/") + "/" + chave]; return v === undefined ? padrao : v; },
    writeConfig(chave, valor) { config[this.currentConfigGroup.join("/") + "/" + chave] = valor; },
    fixados() { const v = config["General/launchers"]; return Array.isArray(v) ? v : String(v).split(",").filter(x => x); },
  };
}

function barra(tela, pecas) {
  const ids = pecas.map((_, i) => tela * 100 + i);
  return { screen: tela, widgetIds: ids, widgetById: id => pecas[id - tela * 100] };
}

// Roda o roteiro numa área de trabalho com duas telas e devolve o que ele respondeu.
function roda(acao, apps, fixadosAntes, opcoes = {}) {
  const tela0 = peca("org.kde.plasma.icontasks", fixadosAntes);
  const tela1 = peca("org.kde.plasma.icontasks", fixadosAntes);
  const barras = opcoes.semApps ? [barra(0, [peca("org.matsu.menu")])]
                                : [barra(0, [peca("org.matsu.menu"), tela0]), barra(1, [tela1])];
  let saida = "";
  const contexto = {
    panels: () => barras,
    print: t => { saida += t; },
    knownWidgetTypes: ["org.kde.plasma.icontasks", "org.kde.plasma.trash"],
    applicationExists: nome => ["org.matsu.terminal.desktop", "steam.desktop", "org.matsu.ajustes.desktop"].includes(nome),
  };
  vm.runInNewContext("var matsuAcao = " + JSON.stringify(acao) + ";\nvar matsuApps = " + JSON.stringify(apps) + ";\n" + codigo, contexto);
  const linhas = saida.split("\n");
  return {
    saida,
    lista: linhas.filter(l => l.startsWith("matsu-fixado: ")).map(l => l.slice(14)),
    tela0: tela0.fixados(),
    tela1: tela1.fixados(),
  };
}

const A = ["preferred://filemanager", "preferred://browser", "applications:steam.desktop"];
let r;

console.log("apps fixados na barra (roteiro do Plasma)");
r = roda("ler", [], A);
confere("ler devolve os fixados na ordem", JSON.stringify(r.lista) === JSON.stringify(A), r.saida);
confere("ler termina com pronto", r.saida.includes("matsu-fixados: pronto"));

r = roda("fixar", ["applications:org.kde.kate.desktop"], A);
confere("fixar põe o app no fim", r.lista[3] === "applications:org.kde.kate.desktop" && r.lista.length === 4, r.saida);
confere("fixar vale para a barra das duas telas", JSON.stringify(r.tela0) === JSON.stringify(r.lista) && JSON.stringify(r.tela1) === JSON.stringify(r.lista));

r = roda("fixar", ["applications:steam.desktop"], A);
confere("fixar um app que já está não repete", r.lista.length === 3, r.saida);

r = roda("tirar", ["preferred://browser"], A);
confere("tirar tira só aquele app", JSON.stringify(r.lista) === JSON.stringify([A[0], A[2]]), r.saida);
confere("tirar vale para as duas telas", JSON.stringify(r.tela1) === JSON.stringify([A[0], A[2]]));

r = roda("tirar", ["applications:nao-existe.desktop"], A);
confere("tirar um app que não está não muda nada", JSON.stringify(r.lista) === JSON.stringify(A));

r = roda("ordem", ["applications:steam.desktop", "preferred://filemanager"], A);
confere("ordem põe na ordem pedida e o resto no fim", JSON.stringify(r.lista) === JSON.stringify([A[2], A[0], A[1]]), r.saida);

r = roda("ordem", ["applications:intruso.desktop", "preferred://browser"], A);
confere("ordem não traz app que não estava fixado", !r.lista.includes("applications:intruso.desktop") && r.lista.length === 3 && r.lista[0] === A[1], r.saida);

r = roda("tirar", ["applications:steam.desktop"], ["[atividade-1]\napplications:steam.desktop", A[0]]);
confere("app guardado só para uma atividade também sai", JSON.stringify(r.lista) === JSON.stringify([A[0]]), r.saida);

r = roda("padrao", [], ["applications:x.desktop"]);
confere("padrao volta aos apps do começo", r.lista[0] === "preferred://filemanager" && r.lista.includes("applications:steam.desktop") && !r.lista.includes("applications:x.desktop"), r.saida);

r = roda("ler", [], A, { semApps: true });
confere("sem a peça dos apps, avisa sem-barra", r.saida.includes("matsu-fixados: sem-barra") && r.lista.length === 0, r.saida);

console.log("\nResultado: " + passou + " passaram, " + falhou + " falharam");
process.exit(falhou ? 1 : 0);
