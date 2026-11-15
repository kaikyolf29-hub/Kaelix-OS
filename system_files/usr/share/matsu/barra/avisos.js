// Matsu OS: os avisos dos apps (notificações) aparecem no jeito do Mac, pelo
// relógio do Matsu (org.matsu.relogio, Avisos.qml). Este roteiro desliga a
// peça de avisos do KDE nas bandejas, senão cada aviso apareceria duas vezes.
// Vai junto com comum.js (semAvisosDoKde). Roda no começo de cada sessão
// (usr/libexec/matsu/matsu-avisos): quem já tinha a barra montada antes dos
// avisos do Matsu também fica assim. Sem nada a mudar, não mexe em nada.
//
// Só desliga a do KDE se houver um relógio do Matsu em alguma barra (sem ele,
// ninguém mostraria os avisos).
var bandejasDoKde = [];
var temRelogio = false;
var paineis = panels();
for (var i = 0; i < paineis.length; i++) {
    var ids = paineis[i].widgetIds;
    for (var j = 0; j < ids.length; j++) {
        var peca = paineis[i].widgetById(ids[j]);
        if (!peca) {
            continue;
        }
        if (peca.type === "org.matsu.relogio") {
            temRelogio = true;
        } else if (peca.type === "org.kde.plasma.systemtray") {
            bandejasDoKde.push(peca);
        }
    }
}
var mudadas = 0;
if (temRelogio) {
    for (var k = 0; k < bandejasDoKde.length; k++) {
        var bandeja = bandejasDoKde[k];
        var alvo = bandeja;
        // Até o Plasma 6.3 a bandeja guardava as peças num contêiner à parte.
        bandeja.currentConfigGroup = [];
        var antigo = bandeja.readConfig("SystrayContainmentId");
        if (antigo && desktopById(antigo)) {
            alvo = desktopById(antigo);
        }
        if (semAvisosDoKde(alvo)) {
            alvo.reloadConfig();
            mudadas++;
        }
    }
}
print("matsu-avisos: " + bandejasDoKde.length + " bandeja(s), " + mudadas + " mudada(s)" + (temRelogio ? "" : ", sem relógio do Matsu") + "\n");
