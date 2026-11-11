// Antes de trocar de estilo: lê os apps que a pessoa fixou e tira as barras atuais.
// Roda sozinho, antes do arranjo novo (veja cmd_bar em /usr/bin/matsu).

// O Plasma pode devolver a lista como texto ("a,b,c") ou como lista. Aqui vira sempre lista limpa.
function matsuLista(valor) {
    var itens = [];
    if (!valor) {
        return itens;
    }
    var partes = (typeof valor === "string") ? valor.split(",") : valor;
    for (var n = 0; n < partes.length; n++) {
        var texto = String(partes[n]).replace(/^\s+|\s+$/g, "");
        if (texto.length && texto.indexOf("://") === -1 && texto.indexOf(":") === -1) {
            continue;   // não parece um atalho de app
        }
        if (texto.length) {
            itens.push(texto);
        }
    }
    return itens;
}

var matsuFixados = [];
var matsuAntigos = panels();
for (var a = 0; a < matsuAntigos.length; a++) {
    var ids = matsuAntigos[a].widgetIds;
    for (var w = 0; w < ids.length; w++) {
        var item = matsuAntigos[a].widgetById(ids[w]);
        if (item && item.type === "org.kde.plasma.icontasks" && !matsuFixados.length) {
            item.currentConfigGroup = ["General"];
            var lidos = item.readConfig("launchers", "");
            print("matsu: fixados lidos (" + (typeof lidos) + "): " + lidos + "\n");
            matsuFixados = matsuLista(lidos);
        }
    }
}
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
