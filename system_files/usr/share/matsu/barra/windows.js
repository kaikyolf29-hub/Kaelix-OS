// Estilo "windows": uma barra só, de ponta a ponta, presa embaixo.
// Menu, busca e apps à esquerda; rede, som e relógio no canto direito
// (nas outras telas, só o relógio, como no Windows).

function montarTela(tela) {
    var principal = ehPrincipal(tela);
    var barra = novaBarra(tela);
    barra.location = "bottom";
    barra.height = alturaDaBarra();
    barra.lengthMode = "fill";
    barra.floating = false;
    barra.hiding = esconder();
    // Numa barra só, a busca fica sempre ao lado do menu (ou some, se a pessoa pediu).
    porMenu(barra, ondeBusca() !== "nao", principal);
    porApps(barra, tela);
    barra.addWidget("org.kde.plasma.panelspacer");
    porBandeja(barra, principal);
}
