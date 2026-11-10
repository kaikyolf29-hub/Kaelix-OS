// Estilo "windows": uma barra só, de ponta a ponta, presa embaixo.
// Menu, busca e apps à esquerda; rede, som e relógio no canto direito.

var barra = new Panel;
barra.location = "bottom";
barra.height = alturaDaBarra();
barra.lengthMode = "fill";
barra.floating = false;
barra.hiding = esconder();
porMenu(barra);
porBusca(barra);
porApps(barra);
barra.addWidget("org.kde.plasma.panelspacer");
porBandeja(barra);
