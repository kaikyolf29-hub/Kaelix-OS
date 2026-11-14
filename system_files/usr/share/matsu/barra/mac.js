// Estilo "mac": a barra de cima e uma doca flutuante com os apps embaixo, no
// meio (ou de pé, à esquerda ou à direita, se a pessoa escolher). A doca é a
// do Matsu, com a ampliação do Mac ao passar o mouse. Na barra de cima, à esquerda, o logo do Matsu (o menu), o nome do app
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
    topo.hiding = esconderTopo();
    vidroDaBarra(topo);
    porMenu(topo, false, principal);
    porMenusDoApp(topo);
    topo.addWidget("org.kde.plasma.panelspacer");
    porBandeja(topo, principal);
    return topo;
}

function montarTela(tela) {
    var principal = ehPrincipal(tela);
    montarBarraDeCima(tela, principal);

    // A doca embaixo (o padrão) ou de pé, à esquerda ou à direita, como no Mac.
    var lado = posicaoDaDoca();
    var geo = screenGeometry(tela);
    var doca = novaBarra(tela);
    doca.location = lado === "esquerda" ? "left" : (lado === "direita" ? "right" : "bottom");
    doca.height = alturaDaBarra();
    doca.alignment = "center";
    doca.lengthMode = "fit";
    doca.minimumLength = gridUnit * 4;
    doca.maximumLength = Math.round(lado === "embaixo" ? geo.width * 0.8 : (geo.height - alturaDaBarraDeCima()) * 0.86);
    doca.floating = true;
    doca.hiding = esconder();
    vidroDaBarra(doca);
    var apps = porApps(doca, tela);
    if (principal) {
        porLixeira(doca, apps);
    }
}
