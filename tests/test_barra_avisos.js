// Testes do roteiro que desliga os avisos do KDE nas bandejas
// (system_files/usr/share/matsu/barra/avisos.js), rodado como o Plasma roda:
// comum.js + avisos.js, com uma área de trabalho falsa. Os avisos dos apps são
// do relógio do Matsu (Avisos.qml); com a peça do KDE ligada, cada aviso
// apareceria duas vezes.
// Uso: node tests/test_barra_avisos.js
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const RAIZ = path.join(__dirname, "..", "system_files");
const BARRA = path.join(RAIZ, "usr", "share", "matsu", "barra");
const codigo = fs.readFileSync(path.join(BARRA, "comum.js"), "utf8") + "\n" + fs.readFileSync(path.join(BARRA, "avisos.js"), "utf8");
const KDE = "org.kde.plasma.notifications";

let passou = 0, falhou = 0;
function confere(desc, ok, extra) {
  if (ok) { passou++; console.log("  ok   " + desc); }
  else { falhou++; console.log("  FAIL " + desc + (extra ? "\n       | " + extra : "")); }
}

// Uma peça falsa do Plasma com a configuração guardada num objeto.
function peca(tipo, config = {}) {
  return {
    type: tipo,
    config,
    recarregou: 0,
    currentConfigGroup: [],
    readConfig(chave, padrao) { const v = config[this.currentConfigGroup.join("/") + "/" + chave]; return v === undefined ? padrao : v; },
    writeConfig(chave, valor) { config[this.currentConfigGroup.join("/") + "/" + chave] = valor; },
    reloadConfig() { this.recarregou++; },
  };
}
function lista(v) { return Array.isArray(v) ? v : String(v || "").split(",").filter(x => x); }

function barra(tela, pecas) {
  const ids = pecas.map((_, i) => tela * 100 + i);
  return { screen: tela, widgetIds: ids, widgetById: id => pecas[id - tela * 100] };
}

function roda(barras, internos = {}) {
  let saida = "";
  vm.runInNewContext(codigo, {
    panels: () => barras,
    desktopById: id => internos[id],
    print: t => { saida += t; },
    knownWidgetTypes: ["org.matsu.relogio", "org.kde.plasma.systemtray", KDE],
  });
  return saida;
}

// Bandeja de quem montou a barra antes dos avisos do Matsu: a peça do KDE ligada.
const bandeja = peca("org.kde.plasma.systemtray", { "General/extraItems": "org.kde.plasma.clipboard," + KDE + ",org.kde.plasma.battery", "General/knownItems": "org.kde.plasma.clipboard,org.kde.plasma.battery" });
let saida = roda([barra(0, [peca("org.matsu.menu"), bandeja, peca("org.matsu.relogio")])]);
confere("tira a peça de avisos do KDE das ligadas", !lista(bandeja.config["General/extraItems"]).includes(KDE), bandeja.config["General/extraItems"]);
confere("as outras peças da bandeja continuam ligadas", lista(bandeja.config["General/extraItems"]).join(",") === "org.kde.plasma.clipboard,org.kde.plasma.battery");
confere("a peça do KDE fica nas conhecidas (a bandeja não liga de novo sozinha)", lista(bandeja.config["General/knownItems"]).includes(KDE));
confere("a bandeja relê a configuração", bandeja.recarregou === 1);
confere("diz quantas bandejas mudou", saida.includes("matsu-avisos: 1 bandeja(s), 1 mudada(s)"), saida);

saida = roda([barra(0, [bandeja, peca("org.matsu.relogio")])]);
confere("na sessão seguinte, sem nada a mudar, não mexe na bandeja", bandeja.recarregou === 1 && saida.includes("0 mudada(s)"), saida);

// Sem o relógio do Matsu ninguém mostraria os avisos: a do KDE fica.
const semRelogio = peca("org.kde.plasma.systemtray", { "General/extraItems": KDE });
saida = roda([barra(0, [semRelogio, peca("org.kde.plasma.digitalclock")])]);
confere("sem o relógio do Matsu, a peça do KDE continua ligada", lista(semRelogio.config["General/extraItems"]).includes(KDE) && semRelogio.recarregou === 0);
confere("e diz que não achou o relógio", saida.includes("sem relógio do Matsu"), saida);

// Relógio numa tela, bandejas nas duas (o relógio da tela principal mostra os avisos de todas).
const b0 = peca("org.kde.plasma.systemtray", { "General/extraItems": KDE });
const b1 = peca("org.kde.plasma.systemtray", { "General/extraItems": KDE });
saida = roda([barra(0, [b0, peca("org.matsu.relogio")]), barra(1, [b1])]);
confere("desliga a peça do KDE em todas as bandejas", !lista(b0.config["General/extraItems"]).includes(KDE) && !lista(b1.config["General/extraItems"]).includes(KDE), saida);

// Bandeja antiga (até o Plasma 6.3): as peças ficam num contêiner à parte.
const interno = peca("org.kde.plasma.private.systemtray", { "General/extraItems": KDE });
const antiga = peca("org.kde.plasma.systemtray", { "/SystrayContainmentId": 42 });
roda([barra(0, [antiga, peca("org.matsu.relogio")])], { 42: interno });
confere("na bandeja antiga, muda o contêiner de dentro", !lista(interno.config["General/extraItems"]).includes(KDE) && interno.recarregou === 1);

// Barra montada de novo (trocar de estilo): a bandeja nova já vem sem a peça do KDE.
const nova = peca("org.kde.plasma.systemtray", { "General/extraItems": "org.kde.plasma.clipboard," + KDE });
vm.runInNewContext(fs.readFileSync(path.join(BARRA, "comum.js"), "utf8") + "\narrumarBandeja(nova);", {
  nova, desktopById: () => null, print: () => {}, knownWidgetTypes: ["org.matsu.relogio", KDE, "org.kde.plasma.clipboard"],
});
confere("ao montar a barra, a bandeja nova vem sem a peça do KDE", !lista(nova.config["General/extraItems"]).includes(KDE) && lista(nova.config["General/knownItems"]).includes(KDE));
const semNosso = peca("org.kde.plasma.systemtray", { "General/extraItems": KDE });
vm.runInNewContext(fs.readFileSync(path.join(BARRA, "comum.js"), "utf8") + "\narrumarBandeja(semNosso);", {
  semNosso, desktopById: () => null, print: () => {}, knownWidgetTypes: [KDE],
});
confere("sem o relógio do Matsu instalado, a barra montada mantém a peça do KDE", lista(semNosso.config["General/extraItems"]).includes(KDE));

// As peças que fazem isso no começo da sessão.
const ajudante = path.join(RAIZ, "usr", "libexec", "matsu", "matsu-avisos");
confere("o ajudante do começo da sessão existe e é executável", (fs.statSync(ajudante).mode & 0o111) !== 0);
const inicio = fs.readFileSync(path.join(RAIZ, "etc", "xdg", "autostart", "matsu-avisos.desktop"), "utf8");
confere("roda no começo de cada sessão do Plasma", /^Exec=\/usr\/libexec\/matsu\/matsu-avisos$/m.test(inicio) && /^OnlyShowIn=KDE;$/m.test(inicio) && /^NoDisplay=true$/m.test(inicio));

// O relógio cria os avisos (só o da tela principal) e eles não ficam um em cima do outro.
const UI = path.join(RAIZ, "usr", "share", "plasma", "plasmoids", "org.matsu.relogio", "contents", "ui");
const principal = fs.readFileSync(path.join(UI, "main.qml"), "utf8");
const avisos = fs.readFileSync(path.join(UI, "Avisos.qml"), "utf8");
confere("só o relógio da tela principal mostra os avisos", /source: "Avisos\.qml"/.test(principal) && /containment\.screen === 0/.test(principal));
confere("a janela do aviso é pedida de novo ao mudar de lugar (no Wayland)", /requestUpdate\(\)/.test(avisos));
confere("o \"não perturbe\" do relógio vale para os avisos", /Server[\s\S]*property: "inhibited"/.test(avisos));
confere("\"Mostrar notificações\" abre o balão do relógio", /onShowNotificationsRequested/.test(avisos) && /mostrarLista\.connect/.test(principal));

// Antes da área de trabalho ligar (login): a peça do KDE sai do arquivo das barras.
// Se ela carregar uma vez, os avisos dela ficam ligados até o fim da sessão.
const os = require("os");
const { execFileSync } = require("child_process");
const casa = fs.mkdtempSync(path.join(os.tmpdir(), "matsu-avisos-"));
fs.mkdirSync(path.join(casa, ".config"));
const arq = path.join(casa, ".config", "plasma-org.kde.plasma.desktop-appletsrc");
const antes = "[Containments][2][Applets][5][Configuration][General]\nextraItems=org.kde.plasma.clipboard," + KDE + "\nknownItems=org.kde.plasma.clipboard\n\n[Containments][2][Applets][6]\nplugin=org.matsu.relogio\n\n[Containments][3][General]\nextraItems=" + KDE + "\n";
const login = path.join(RAIZ, "etc", "xdg", "plasma-workspace", "env", "matsu-avisos.sh");
fs.writeFileSync(arq, antes);
execFileSync("sh", [login], { env: { HOME: casa, PATH: process.env.PATH } });
let depois = fs.readFileSync(arq, "utf8");
confere("no login, a peça do KDE sai das bandejas antes de carregar", !/extraItems=.*notifications/.test(depois) && /extraItems=org\.kde\.plasma\.clipboard\n/.test(depois), depois);
confere("no login, ela entra nas conhecidas (também onde não havia a lista)", (depois.match(/knownItems=[^\n]*org\.kde\.plasma\.notifications/g) || []).length === 2, depois);
execFileSync("sh", [login], { env: { HOME: casa, PATH: process.env.PATH } });
confere("no login seguinte, não muda nada", fs.readFileSync(arq, "utf8") === depois);
fs.writeFileSync(arq, antes.replace("plugin=org.matsu.relogio", "plugin=org.kde.plasma.digitalclock"));
execFileSync("sh", [login], { env: { HOME: casa, PATH: process.env.PATH } });
confere("no login, sem o relógio do Matsu, não mexe nas barras", fs.readFileSync(arq, "utf8") === antes.replace("plugin=org.matsu.relogio", "plugin=org.kde.plasma.digitalclock"));
fs.rmSync(casa, { recursive: true, force: true });

// 4) Na montagem da imagem (build.sh), a peça de avisos do KDE sai: uma bandeja
// nova liga essa peça sozinha antes de o roteiro da barra desligar, e ela deixa
// os avisos dela na tela até o fim da sessão. O trecho roda aqui numa raiz falsa.
const build = fs.readFileSync(path.join(__dirname, "..", "build_files", "build.sh"), "utf8");
const trecho = build.match(/\nif \[\[ -f \/usr\/share\/plasma\/plasmoids\/org\.matsu\.relogio\/contents\/ui\/Avisos\.qml \]\]; then\n[\s\S]*?\n  fi\nfi\n/);
confere("o build.sh tem o trecho que tira a peça de avisos do KDE", !!trecho);
if (trecho) {
  const raiz = fs.mkdtempSync(path.join(os.tmpdir(), "matsu-imagem-"));
  const pecas = path.join(raiz, "usr", "lib64", "qt6", "plugins", "plasma", "applets");
  const relogio = path.join(raiz, "usr", "share", "plasma", "plasmoids", "org.matsu.relogio", "contents", "ui");
  fs.mkdirSync(pecas, { recursive: true });
  fs.mkdirSync(relogio, { recursive: true });
  const doKde = path.join(pecas, KDE + ".so");
  const bandeja = path.join(pecas, "org.kde.plasma.systemtray.so");
  const roda = () => execFileSync("bash", ["-euo", "pipefail", "-c", trecho[0].split("/usr/").join(raiz + "/usr/")], { encoding: "utf8" });
  fs.writeFileSync(doKde, "");
  fs.writeFileSync(bandeja, "");
  let saida = roda();
  confere("sem o relógio do Matsu na imagem, a peça do KDE fica", fs.existsSync(doKde) && saida === "", saida);
  fs.writeFileSync(path.join(relogio, "Avisos.qml"), "");
  saida = roda();
  confere("com o relógio do Matsu, a peça de avisos do KDE sai da imagem", !fs.existsSync(doKde) && /fora da imagem/.test(saida), saida);
  confere("as outras peças do KDE ficam (a bandeja)", fs.existsSync(bandeja));
  saida = roda();
  confere("se a peça do KDE mudar de lugar, a montagem avisa e segue", /::warning::/.test(saida), saida);
  fs.rmSync(raiz, { recursive: true, force: true });
}

console.log(`\n${passou} passaram, ${falhou} falharam`);
process.exit(falhou ? 1 : 0);
