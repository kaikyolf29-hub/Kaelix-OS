// Antes de trocar de estilo: guarda os apps que a pessoa fixou e tira as barras atuais.

// O Plasma pode devolver a lista como texto ("a,b,c") ou como lista. Aqui vira sempre lista limpa.
function kaelixLista(valor) {
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

var kaelixFixados = [];
var kaelixAntigos = panels();
for (var a = 0; a < kaelixAntigos.length; a++) {
    var ids = kaelixAntigos[a].widgetIds;
    for (var w = 0; w < ids.length; w++) {
        var item = kaelixAntigos[a].widgetById(ids[w]);
        if (item && item.type === "org.kde.plasma.icontasks" && !kaelixFixados.length) {
            item.currentConfigGroup = ["General"];
            var lidos = item.readConfig("launchers", "");
            print("kaelix: fixados lidos (" + (typeof lidos) + "): " + lidos + "\n");
            kaelixFixados = kaelixLista(lidos);
        }
    }
}
print("kaelix: " + kaelixFixados.length + " apps fixados mantidos, " + kaelixAntigos.length + " barras antigas\n");
for (var r = 0; r < kaelixAntigos.length; r++) {
    kaelixAntigos[r].remove();
}
