// Estilo "mac": barra fina no topo (menu, menu do app, rede, som e relógio)
// e uma doca flutuante com os apps embaixo, no meio.

var topo = new Panel;
topo.location = "top";
topo.height = 2 * Math.ceil(gridUnit * 1.6 / 2);
topo.lengthMode = "fill";
topo.floating = false;
topo.hiding = "none";
porMenu(topo);
if (tem("org.kde.plasma.appmenu")) {
    topo.addWidget("org.kde.plasma.appmenu");
}
topo.addWidget("org.kde.plasma.panelspacer");
porBandeja(topo);

var doca = new Panel;
doca.location = "bottom";
doca.height = alturaDaBarra();
doca.alignment = "center";
doca.lengthMode = "fit";
doca.minimumLength = gridUnit * 4;
doca.maximumLength = Math.round(screenGeometry(doca.screen).width * 0.8);
doca.floating = true;
doca.hiding = "none";
porApps(doca);
