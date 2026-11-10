// Antes de trocar de estilo: guarda os apps que a pessoa fixou e tira as barras atuais.
var kaelixFixados = null;
var kaelixAntigos = panels();
for (var a = 0; a < kaelixAntigos.length; a++) {
    var ids = kaelixAntigos[a].widgetIds;
    for (var w = 0; w < ids.length; w++) {
        var item = kaelixAntigos[a].widgetById(ids[w]);
        if (item && item.type === "org.kde.plasma.icontasks" && !kaelixFixados) {
            item.currentConfigGroup = ["General"];
            var lidos = item.readConfig("launchers");
            if (lidos && lidos.length) {
                kaelixFixados = lidos;
            }
        }
    }
}
for (var r = 0; r < kaelixAntigos.length; r++) {
    kaelixAntigos[r].remove();
}
