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

function barra(tela, pecas, altura = 50, lugar = "bottom") {
  const ids = pecas.map((_, i) => tela * 100 + i);
  return { screen: tela, height: altura, location: lugar, widgetIds: ids, widgetById: id => pecas[id - tela * 100] };
}

// Roda o roteiro numa área de trabalho com duas telas e devolve o que ele respondeu.
function roda(acao, apps, fixadosAntes, opcoes = {}) {
  const tela0 = peca("org.kde.plasma.icontasks", fixadosAntes);
  const tela1 = peca("org.kde.plasma.icontasks", fixadosAntes);
  const altura = opcoes.altura || 50;
  const barras = opcoes.semApps ? [barra(0, [peca("org.matsu.menu")])]
               : opcoes.mac ? [barra(0, [peca("org.matsu.menu")], 30, "top"), barra(0, [tela0], altura), barra(1, [tela1], altura)]
               : [barra(0, [peca("org.matsu.menu"), tela0], altura), barra(1, [tela1], altura)];
  let saida = "";
  const contexto = {
    panels: () => barras,
    print: t => { saida += t; },
    gridUnit: 18,
    screenCount: 2,
    // A tela 1 é a mais larga; a tela 0 tem a largura pedida (1920 se nada for pedido).
    screenGeometry: t => ({ x: 0, y: 0, width: t === 0 ? (opcoes.largura || 1920) : 2560, height: 1080 }),
    knownWidgetTypes: ["org.kde.plasma.icontasks", "org.kde.plasma.trash"],
    applicationExists: nome => ["org.matsu.terminal.desktop", "steam.desktop", "org.matsu.ajustes.desktop"].includes(nome),
  };
  const estilo = opcoes.estilo ? "var matsuEstilo = " + JSON.stringify(opcoes.estilo) + ";\n" : "";
  vm.runInNewContext(estilo + "var matsuAcao = " + JSON.stringify(acao) + ";\nvar matsuApps = " + JSON.stringify(apps) + ";\n" + codigo, contexto);
  const linhas = saida.split("\n");
  return {
    saida,
    lista: linhas.filter(l => l.startsWith("matsu-fixado: ")).map(l => l.slice(14)),
    limite: Number((linhas.find(l => l.startsWith("matsu-limite: ")) || "matsu-limite: -1").slice(14)),
    naoCouberam: linhas.filter(l => l.startsWith("matsu-nao-coube: ")).map(l => l.slice(17)),
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

console.log("\nlimite de apps na barra");
const muitos = n => Array.from({ length: n }, (_, i) => "applications:app" + i + ".desktop");
r = roda("ler", [], A);
confere("numa tela larga (1920) a fusão média cabe 12 apps", r.limite === 12, r.saida);
r = roda("ler", [], A, { largura: 1280 });
confere("numa tela de 1280 cabem menos (7), pela tela mais estreita", r.limite === 7, r.saida);
r = roda("ler", [], A, { largura: 1280, altura: 60 });
confere("com a barra grande cabem menos ainda (5)", r.limite === 5, r.saida);
r = roda("ler", [], A, { largura: 1280, altura: 42 });
confere("com a barra pequena cabem mais (8)", r.limite === 8, r.saida);
r = roda("ler", [], A, { largura: 1280, estilo: "windows" });
confere("na barra única do windows cabem 9", r.limite === 9, r.saida);
r = roda("ler", [], A, { largura: 1280, mac: true });
confere("com a barra no topo (estilo Mac) a doca cabe mais (15)", r.limite === 15, r.saida);
r = roda("ler", [], A, { largura: 800 });
confere("nunca menos de 4", r.limite === 4, r.saida);
r = roda("fixar", ["applications:novo.desktop"], muitos(7), { largura: 1280 });
confere("no limite, fixar não põe o app", r.lista.length === 7 && !r.lista.includes("applications:novo.desktop"), r.saida);
confere("no limite, avisa qual app não coube", JSON.stringify(r.naoCouberam) === JSON.stringify(["applications:novo.desktop"]), r.saida);
confere("no limite, as barras não mudam", r.tela0.length === 7 && r.tela1.length === 7);
r = roda("fixar", ["applications:a.desktop", "applications:b.desktop"], muitos(6), { largura: 1280 });
confere("fixar dois com um lugar só: entra o primeiro", r.lista.length === 7 && r.lista[6] === "applications:a.desktop" && JSON.stringify(r.naoCouberam) === JSON.stringify(["applications:b.desktop"]), r.saida);
r = roda("fixar", ["applications:novo.desktop"], muitos(7), { largura: 1280, mac: true });
confere("no estilo Mac o mesmo app cabe na doca", r.lista.length === 8 && r.naoCouberam.length === 0, r.saida);
r = roda("tirar", ["applications:app0.desktop"], muitos(10), { largura: 1280 });
confere("tirar funciona mesmo acima do limite (veio de outro estilo)", r.lista.length === 9, r.saida);
{
  // Fusão de verdade: as ilhas dos lados já têm tamanho (a da direita, 360 px).
  const apps = peca("org.kde.plasma.icontasks", A);
  const meio = { id: 2, screen: 0, height: 50, location: "bottom", alignment: "center", length: 400, maximumLength: 768, widgetIds: [0], widgetById: () => apps };
  const ilhas = [{ id: 1, screen: 0, height: 50, location: "bottom", alignment: "left", length: 300, widgetIds: [], widgetById: () => null }, meio,
                 { id: 3, screen: 0, height: 50, location: "bottom", alignment: "right", length: 360, widgetIds: [], widgetById: () => null }];
  let saida = "";
  vm.runInNewContext('var matsuEstilo = "fusao"; var matsuAcao = "ler"; var matsuApps = [];\n' + codigo, {
    panels: () => ilhas, print: t => { saida += t; }, gridUnit: 18, screenCount: 1,
    screenGeometry: () => ({ width: 1280, height: 800 }), knownWidgetTypes: [], applicationExists: () => false });
  confere("com as ilhas medidas, a do meio não encosta na da direita", meio.maximumLength === 1280 - 2 * (360 + 27), "max=" + meio.maximumLength);
  confere("e o limite sai do tamanho medido", saida.includes("matsu-limite: 6"), saida);
}
r = roda("padrao", [], A, { largura: 800, altura: 60 });
confere("padrao numa tela pequena fica no limite", r.lista.length === r.limite && r.limite === 4, r.saida);

// Montar a barra (comum.js + estilo + todas-as-telas.js) com mais apps do que cabem.
function monta(estilo, fixados, largura) {
  const arq = n => fs.readFileSync(path.join(BARRA, n), "utf8");
  const paineis = [];
  let saida = "";
  const contexto = {
    print: t => { saida += t; },
    gridUnit: 18, screenCount: 1,
    screenGeometry: () => ({ x: 0, y: 0, width: largura, height: 1080 }),
    knownWidgetTypes: ["org.kde.plasma.icontasks", "org.kde.plasma.trash", "org.matsu.menu", "org.matsu.menuapp"],
    applicationExists: () => false,
    desktopById: () => null,
    Panel: function () { this.pecas = []; paineis.push(this); this.addWidget = t => { const w = peca(t); this.pecas.push(w); return w; }; },
  };
  vm.runInNewContext("var matsuFixados = " + JSON.stringify(fixados) + ";\n" + arq("comum.js") + arq(estilo + ".js") + arq("todas-as-telas.js"), contexto);
  const apps = [].concat(...paineis.map(p => p.pecas)).find(w => w.type === "org.kde.plasma.icontasks");
  return { saida, apps: apps.readConfig("launchers", []), paineis };
}
console.log("\nmontar a barra com o limite");
r = monta("fusao", muitos(14), 1280);
confere("a fusão monta só os apps que cabem", r.apps.length === 7, r.saida);
confere("os que não couberam são avisados para o comando guardar", (r.saida.match(/matsu-cortado: /g) || []).length === 7, r.saida);
const meio = r.paineis.find(p => p.alignment === "center");
confere("a ilha do meio não encosta nas dos lados", meio.maximumLength === 1280 - 2 * (18 * 18 + 36), "maximumLength=" + meio.maximumLength);
r = monta("mac", muitos(14), 1280);
confere("a doca do Mac monta os 14", r.apps.length === 14 && !r.saida.includes("matsu-cortado"), r.saida);
const topo = r.paineis.find(p => p.location === "top");
confere("o estilo Mac põe o nome e os menus do app na barra de cima", topo && topo.pecas.some(w => w.type === "org.matsu.menuapp"));

console.log("\nResultado: " + passou + " passaram, " + falhou + " falharam");
process.exit(falhou ? 1 : 0);
