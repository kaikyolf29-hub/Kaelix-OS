// Apps fixados na barra: ler, fixar, tirar, pôr em ordem ou voltar ao padrão.
// Vai junto com comum.js (veja cmd_bar_apps em /usr/bin/matsu). Os fixados são
// os mesmos em todas as barras (uma por tela), então a mudança vale para todas.
// Variáveis que o comando "matsu barra" define antes:
//   matsuAcao  "ler", "fixar", "tirar", "ordem" ou "padrao"
//   matsuApps  os apps da ação, como a barra guarda ("applications:x.desktop",
//              "preferred://browser"...). Em "ordem", a lista inteira na ordem nova.
//
//   matsuEstilo o estilo da barra agora (para o limite; sem ele, vale o que
//              a área de trabalho mostrar: barra no topo é o estilo Mac)
//
// Responde uma linha "matsu-fixado: <app>" para cada app fixado depois da
// mudança, "matsu-limite: <n>" (quantos apps cabem na barra), uma linha
// "matsu-nao-coube: <app>" para cada app que não coube e, no fim,
// "matsu-fixados: pronto" (ou "matsu-fixados: sem-barra").

// A barra pode guardar um app só para algumas atividades: "[atividades]\napp".
// Para comparar, vale só o app.
function semAtividade(app) {
    var texto = String(app);
    var quebra = texto.lastIndexOf("\n");
    return quebra === -1 ? texto : texto.substring(quebra + 1);
}

function posicao(lista, app) {
    var alvo = semAtividade(app);
    for (var i = 0; i < lista.length; i++) {
        if (semAtividade(lista[i]) === alvo) {
            return i;
        }
    }
    return -1;
}

var matsuBarras = panels();
var matsuPecas = [];
for (var b = 0; b < matsuBarras.length; b++) {
    var ids = matsuBarras[b].widgetIds;
    for (var w = 0; w < ids.length; w++) {
        var peca = matsuBarras[b].widgetById(ids[w]);
        if (peca && (peca.type === "org.kde.plasma.icontasks" || peca.type === "org.kde.plasma.taskmanager")) {
            matsuPecas.push(peca);
        }
    }
}

// Sem o estilo dito pelo comando: uma barra no topo quer dizer estilo Mac.
function estiloDasBarras(barras) {
    if (typeof matsuEstilo !== "undefined" && matsuEstilo) {
        return estiloDaBarra();
    }
    for (var i = 0; i < barras.length; i++) {
        if (barras[i].location === "top") {
            return "mac";
        }
    }
    return "fusao";
}

if (matsuPecas.length === 0) {
    print("matsu-fixados: sem-barra\n");
} else {
    var acao = (typeof matsuAcao !== "undefined") ? matsuAcao : "ler";
    var pedidos = (typeof matsuApps !== "undefined") ? matsuApps : [];
    var antes = fixadosDasBarras(matsuBarras, 0);
    var depois = antes.slice();
    var limite = limiteDasBarras(matsuBarras, estiloDasBarras(matsuBarras));
    var p, achado;

    if (acao === "fixar") {
        // Só até o limite. Quem já passou dele (veio de outro estilo) fica,
        // mas não entra mais nenhum.
        for (p = 0; p < pedidos.length; p++) {
            if (posicao(depois, pedidos[p]) !== -1) {
                continue;
            }
            if (limite > 0 && depois.length >= limite) {
                print("matsu-nao-coube: " + pedidos[p] + "\n");
                continue;
            }
            depois.push(pedidos[p]);
        }
    } else if (acao === "tirar") {
        for (p = 0; p < pedidos.length; p++) {
            achado = posicao(depois, pedidos[p]);
            if (achado !== -1) {
                depois.splice(achado, 1);
            }
        }
    } else if (acao === "ordem") {
        // A ordem nova só pode trazer apps que já estavam fixados; o que ficou
        // de fora da lista nova vai para o fim, para nada sumir por engano.
        depois = [];
        for (p = 0; p < pedidos.length; p++) {
            achado = posicao(antes, pedidos[p]);
            if (achado !== -1 && posicao(depois, antes[achado]) === -1) {
                depois.push(antes[achado]);
            }
        }
        for (p = 0; p < antes.length; p++) {
            if (posicao(depois, antes[p]) === -1) {
                depois.push(antes[p]);
            }
        }
    } else if (acao === "padrao") {
        depois = fixadosPadrao();
        if (limite > 0 && depois.length > limite) {
            depois = depois.slice(0, limite);
        }
    }

    if (acao !== "ler") {
        for (var q = 0; q < matsuPecas.length; q++) {
            matsuPecas[q].currentConfigGroup = ["General"];
            matsuPecas[q].writeConfig("launchers", depois);
        }
    }
    for (var f = 0; f < depois.length; f++) {
        print("matsu-fixado: " + depois[f] + "\n");
    }
    print("matsu-limite: " + limite + "\n");
    print("matsu-fixados: pronto\n");
}
