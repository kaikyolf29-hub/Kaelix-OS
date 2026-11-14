// Muda na hora como as barras se escondem, sem montar a barra de novo. Vai
// junto com comum.js (veja cmd_bar em /usr/bin/matsu), depois das variáveis
// matsuEstilo, matsuEsconder e matsuEsconderTopo. No estilo Mac, a barra de
// cima segue matsuEsconderTopo e a doca segue matsuEsconder; nos outros
// estilos, todas as barras seguem matsuEsconder.
var matsuBarrasEscondidas = 0;
var matsuTodasAsBarras = panels();
for (var e = 0; e < matsuTodasAsBarras.length; e++) {
    var barraAgora = matsuTodasAsBarras[e];
    var ehTopo = estiloDaBarra() === "mac" && barraAgora.location === "top";
    barraAgora.hiding = ehTopo ? esconderTopo() : esconder();
    matsuBarrasEscondidas++;
}
print("matsu-esconder: " + matsuBarrasEscondidas + " barras, " + esconder() + ", topo " + esconderTopo() + "\n");
