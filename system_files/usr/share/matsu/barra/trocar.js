// Antes de trocar de estilo: lê os apps que a pessoa fixou e tira as barras atuais.
// Vai junto com comum.js, antes do arranjo novo (veja cmd_bar em /usr/bin/matsu).

// Os fixados da barra da tela principal (as outras barras têm os mesmos, ou
// menos). listaDeApps e fixadosDasBarras vêm de comum.js.
var matsuAntigos = panels();
var matsuFixados = fixadosDasBarras(matsuAntigos, 0);
print("matsu: " + matsuFixados.length + " apps fixados mantidos, " + matsuAntigos.length + " barras antigas\n");
// O comando "matsu barra" lê estas linhas: os apps fixados vão para a barra
// nova, e o atalho das peças antigas (Meta+A, Alt+F1...) é solto antes, senão
// a peça nova não consegue pegar o mesmo atalho.
for (var f = 0; f < matsuFixados.length; f++) {
    print("matsu-fixado: " + matsuFixados[f] + "\n");
}
for (var b = 0; b < matsuAntigos.length; b++) {
    var pecas = matsuAntigos[b].widgetIds;
    for (var q = 0; q < pecas.length; q++) {
        print("matsu-peca-velha: " + pecas[q] + "\n");
    }
}
for (var r = 0; r < matsuAntigos.length; r++) {
    matsuAntigos[r].remove();
}
