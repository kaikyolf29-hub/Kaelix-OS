// Uma tela foi ligada (ou a sessão começou com mais telas): põe a barra só nas
// telas que ainda não têm nenhuma, com os mesmos apps fixados da barra da tela
// principal. Nunca mexe nas barras que já existem. Vem depois de comum.js e do
// arquivo do estilo; quem chama é "matsu barra --telas-novas".

// A tela tem barra se alguma está nela agora, ou se uma barra guardada é dela
// (o Plasma devolve sozinho a barra de uma tela que volta).
function telaTemBarra(barras, tela) {
    for (var i = 0; i < barras.length; i++) {
        if (barras[i].screen === tela) {
            return true;
        }
        if (barras[i].screen < 0) {
            barras[i].currentConfigGroup = [];
            if (Number(barras[i].readConfig("lastScreen", -1)) === tela) {
                return true;
            }
        }
    }
    return false;
}

var matsuBarras = panels();
if (!telaTemBarra(matsuBarras, 0)) {
    // A área de trabalho ainda está abrindo (ou a pessoa tirou todas as
    // barras). Nos dois casos, não põe nada.
    print("matsu-telas: esperando a barra da tela principal\n");
} else {
    var matsuFixados = fixadosDasBarras(matsuBarras, 0);
    var matsuNovas = 0;
    for (var matsuTela = 1; matsuTela < screenCount; matsuTela++) {
        if (!telaTemBarra(matsuBarras, matsuTela)) {
            montarTela(matsuTela);
            matsuNovas++;
        }
    }
    print("matsu-telas: pronto, " + matsuNovas + " de " + screenCount + " telas ganharam a barra agora\n");
}
