// Estilo "fusão" (o padrão do Matsu): três ilhas flutuantes embaixo.
// Menu e busca à esquerda (ou no meio), apps no meio, rede, som e relógio à direita.

function ilha(tela, alinhamento) {
    var p = novaBarra(tela);
    p.location = "bottom";
    p.height = alturaDaBarra();
    p.alignment = alinhamento;
    // A ilha tem o tamanho do que está dentro dela.
    p.lengthMode = "fit";
    p.minimumLength = gridUnit * 4;
    p.maximumLength = Math.round(screenGeometry(tela).width * 0.6);
    p.floating = true;
    p.hiding = esconder();
    return p;
}

function montarTela(tela) {
    var principal = ehPrincipal(tela);
    // A busca pode ficar junto do menu (padrão), na ilha do meio ou sumir, e o
    // menu pode ir para o meio, como no Windows 11 (aí a ilha da esquerda some).
    var buscaFica = ondeBusca();
    var menuNoMeio = ondeMenu() === "meio";
    if (!menuNoMeio) {
        var esquerda = ilha(tela, "left");
        porMenu(esquerda, buscaFica === "esquerda", principal);
    }

    var centro = ilha(tela, "center");
    if (menuNoMeio) {
        porMenu(centro, buscaFica !== "nao", principal);
    } else if (buscaFica === "meio") {
        porBuscaSozinha(centro);
    }
    porApps(centro, tela);
    if (principal) {
        porLixeira(centro);
    }
    print("matsu: tela " + tela + ": busca " + buscaFica + ", menu " + (menuNoMeio ? "meio" : "esquerda") + "\n");

    // Nas outras telas a ilha da direita tem só a hora com a data e o sino.
    var direita = ilha(tela, "right");
    porBandeja(direita, principal);
}
