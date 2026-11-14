// Muda os ajustes da doca do Matsu (ampliação, pontinhos, pulo ao abrir) nas
// barras que já estão na tela, sem montar a barra de novo. Vai junto com
// comum.js (veja cmd_bar em /usr/bin/matsu), depois das variáveis matsuAmpliacao,
// matsuAmpliacaoNivel, matsuIndicadores e matsuAnimar.
var matsuDocas = 0;
var matsuBarrasDaTela = panels();
for (var b = 0; b < matsuBarrasDaTela.length; b++) {
    var pecas = matsuBarrasDaTela[b].widgetIds;
    for (var w = 0; w < pecas.length; w++) {
        var peca = matsuBarrasDaTela[b].widgetById(pecas[w]);
        if (peca && peca.type === "org.matsu.doca") {
            ajustarDoca(peca);
            matsuDocas++;
        }
    }
}
print("matsu-docas: " + matsuDocas + "\n");
