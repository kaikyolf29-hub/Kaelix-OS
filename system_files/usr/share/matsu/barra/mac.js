// Estilo "mac": barra fina no topo (menu, menu do app, rede, som e relógio)
// e uma doca flutuante com os apps embaixo, no meio. Cada tela ganha as duas;
// nas outras telas a barra de cima tem só o relógio à direita.

function montarTela(tela) {
    var principal = ehPrincipal(tela);
    var topo = novaBarra(tela);
    topo.location = "top";
    topo.height = 2 * Math.ceil(gridUnit * 1.6 / 2);
    topo.lengthMode = "fill";
    topo.floating = false;
    topo.hiding = "none";
    porMenu(topo, false, principal);
    if (tem("org.kde.plasma.appmenu")) {
        topo.addWidget("org.kde.plasma.appmenu");
    }
    topo.addWidget("org.kde.plasma.panelspacer");
    porBandeja(topo, principal);

    var doca = novaBarra(tela);
    doca.location = "bottom";
    doca.height = alturaDaBarra();
    doca.alignment = "center";
    doca.lengthMode = "fit";
    doca.minimumLength = gridUnit * 4;
    doca.maximumLength = Math.round(screenGeometry(tela).width * 0.8);
    doca.floating = true;
    doca.hiding = esconder();
    porApps(doca, tela);
    if (principal) {
        porLixeira(doca);
    }
}
