// Monta a barra do estilo escolhido em cada tela, ou só na principal se a
// pessoa pediu. Vem depois de comum.js e do arquivo do estilo.

var matsuQuantasTelas = emTodasAsTelas() ? Math.max(1, screenCount) : 1;
for (var matsuTela = 0; matsuTela < matsuQuantasTelas; matsuTela++) {
    montarTela(matsuTela);
}
print("matsu: barra em " + matsuQuantasTelas + " de " + screenCount + " telas\n");
