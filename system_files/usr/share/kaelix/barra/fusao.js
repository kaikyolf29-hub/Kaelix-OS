// Estilo "fusão" (o padrão do Kaelix): três ilhas flutuantes embaixo.
// Menu e busca à esquerda, apps no meio, rede, som e relógio à direita.

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
    p.hiding = "none";
    return p;
}

var esquerda = ilha("left");
porMenu(esquerda);
porBusca(esquerda);

var centro = ilha("center");
porApps(centro);
porLixeira(centro);

var direita = ilha("right");
porBandeja(direita);
