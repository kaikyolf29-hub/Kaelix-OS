// Estilo "fusão" (o padrão do Kaelix): três ilhas flutuantes embaixo.
// Menu e busca à esquerda (ou no meio), apps no meio, rede, som e relógio à direita.

function ilha(alinhamento) {
    var p = new Panel;
    p.location = "bottom";
    p.height = alturaDaBarra();
    p.alignment = alinhamento;
    // A ilha tem o tamanho do que está dentro dela.
    p.lengthMode = "fit";
    p.minimumLength = gridUnit * 4;
    p.maximumLength = Math.round(screenGeometry(p.screen).width * 0.6);
    p.floating = true;
    p.hiding = esconder();
    return p;
}

// A busca pode ficar junto do menu (padrão), na ilha do meio ou sumir, e o
// menu pode ir para o meio, como no Windows 11 (aí a ilha da esquerda some).
var buscaFica = ondeBusca();
var menuNoMeio = ondeMenu() === "meio";
if (!menuNoMeio) {
    var esquerda = ilha("left");
    porMenu(esquerda, buscaFica === "esquerda");
}

var centro = ilha("center");
if (menuNoMeio) {
    porMenu(centro, buscaFica !== "nao");
} else if (buscaFica === "meio") {
    porBuscaSozinha(centro);
}
porApps(centro);
porLixeira(centro);
print("kaelix: busca " + buscaFica + ", menu " + (menuNoMeio ? "meio" : "esquerda") + "\n");

var direita = ilha("right");
porBandeja(direita);
