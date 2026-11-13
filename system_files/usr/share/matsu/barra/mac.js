// Estilo "mac": a barra de cima e uma doca flutuante com os apps embaixo, no
// meio. Na barra de cima, à esquerda, o logo do Matsu (o menu), o nome do app
// em uso em negrito e os menus dele; à direita, os ícones dos apps em segundo
// plano (a setinha), rede, Bluetooth, som, bateria e o botão da central, e a
// data com a hora. Cada tela ganha as duas; nas outras telas a barra de cima
// tem o logo, o app e o relógio.

var matsuEstilo = "mac";

// Fina e com respiro: o relógio e a central se arrumam numa linha só quando a
// barra tem menos de 1,9 gridUnit.
function alturaDaBarraDeCima() {
    return 2 * Math.ceil(gridUnit * 1.75 / 2);
}

// O nome do app em uso e o menu de reserva (Janela) dos apps sem menu, e logo
// depois o menu global do Plasma (Arquivo, Editar, Exibir...) dos apps que
// mandam o menu deles.
function porMenusDoApp(painel) {
    if (tem("org.matsu.menuapp")) {
        painel.addWidget("org.matsu.menuapp");
    }
    if (tem("org.kde.plasma.appmenu")) {
        var global = painel.addWidget("org.kde.plasma.appmenu");
        global.currentConfigGroup = ["General"];
        global.writeConfig("compactView", false);
    }
}

function montarBarraDeCima(tela, principal) {
    var topo = novaBarra(tela);
    topo.location = "top";
    topo.height = alturaDaBarraDeCima();
    topo.lengthMode = "fill";
    topo.floating = false;
    topo.hiding = "none";
    porMenu(topo, false, principal);
    porMenusDoApp(topo);
    topo.addWidget("org.kde.plasma.panelspacer");
    porBandeja(topo, principal);
    return topo;
}

function montarTela(tela) {
    var principal = ehPrincipal(tela);
    montarBarraDeCima(tela, principal);

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
