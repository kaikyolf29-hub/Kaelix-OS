// Matsu OS: peças comuns aos estilos de barra (fusão, mac e windows).
// Este arquivo é juntado com o do estilo escolhido e enviado ao Plasma.
// Variáveis opcionais que o comando "matsu barra" define antes:
//   matsuEscala   tamanho da barra (2.25 pequena, 2.75 média, 3.25 grande)
//   matsuFixados  lista dos apps que a pessoa já tinha fixado
//   matsuEsconder true para a barra se esconder sozinha (aparece com o mouse)
//   matsuBusca    onde fica a pílula da busca: "esquerda" (junto do menu),
//                  "meio" (na ilha do meio, junto dos apps) ou "nao"
//   matsuMenu     onde fica o botão do menu: "esquerda" ou "meio" (Windows 11)
//   matsuTelas    "todas" (uma barra em cada tela, o padrão) ou "principal"
//   matsuAbertos  com mais de uma tela, onde aparece cada app aberto:
//                  "tela" (só na barra da tela onde a janela está, o padrão),
//                  "todas" (em todas as barras) ou "principal" (na barra da
//                  tela principal e na da tela onde a janela está)
//   matsuEstilo   o estilo da barra ("fusao", "mac" ou "windows"); cada
//                  arquivo de estilo também diz o seu. Serve para o limite de
//                  apps fixados (veja limiteDeApps).
//   matsuAmpliacao      true para os apps crescerem ao passar o mouse (a doca
//                        do Matsu, na fusão e no Mac)
//   matsuAmpliacaoNivel quanto crescem, de 0 a 100
//   matsuIndicadores    true para o pontinho embaixo dos apps abertos
//   matsuAnimar         true para o app pular enquanto abre
//   matsuPosicao        onde fica a doca no estilo Mac: "embaixo", "esquerda"
//                        ou "direita"
//
// Cada estilo define montarTela(tela), que monta a barra numa tela só. Quem
// escolhe as telas é o arquivo que vem depois: todas-as-telas.js (montar tudo
// de novo) ou telas-novas.js (só as telas que ficaram sem barra).

function tem(tipo) {
    return knownWidgetTypes.indexOf(tipo) !== -1;
}

// As peças que mostram os apps fixados e abertos: a doca do Matsu (fusão e
// Mac) e a barra de apps do KDE (estilo Windows, ou sem a doca).
var PECAS_DE_APPS = ["org.matsu.doca", "org.kde.plasma.icontasks", "org.kde.plasma.taskmanager"];
function pecaDeApps(item) {
    return !!item && PECAS_DE_APPS.indexOf(item.type) !== -1;
}

// A doca do Matsu (com a ampliação do Mac) entra na fusão e no Mac; no estilo
// Windows fica a barra de apps do KDE, reta como a do Windows.
function usaDoca() {
    return tem("org.matsu.doca") && estiloDaBarra() !== "windows";
}

// Os ajustes da doca (ampliação, pontinhos, pulo ao abrir).
function ajustarDoca(doca) {
    doca.currentConfigGroup = ["General"];
    doca.writeConfig("ampliacao", (typeof matsuAmpliacao !== "undefined") ? !!matsuAmpliacao : true);
    var nivel = (typeof matsuAmpliacaoNivel !== "undefined") ? Number(matsuAmpliacaoNivel) : 50;
    doca.writeConfig("ampliacaoNivel", Math.max(0, Math.min(100, isNaN(nivel) ? 50 : Math.round(nivel))));
    doca.writeConfig("indicadores", (typeof matsuIndicadores !== "undefined") ? !!matsuIndicadores : true);
    doca.writeConfig("animarAbertura", (typeof matsuAnimar !== "undefined") ? !!matsuAnimar : true);
}

// "autohide" quando a pessoa pediu para a barra se esconder sozinha.
function esconder() {
    return (typeof matsuEsconder !== "undefined" && matsuEsconder) ? "autohide" : "none";
}

// O Plasma numera as telas a partir da principal: a tela 0 é a principal. Só
// nela ficam a bandeja, a central, a lixeira e os atalhos (Meta+A, Meta+B,
// Meta+N, Alt+F1). A tecla Meta abre o menu da tela onde está o mouse.
function ehPrincipal(tela) {
    return tela === 0;
}

function emTodasAsTelas() {
    return !(typeof matsuTelas !== "undefined" && matsuTelas === "principal");
}

function ondeAbertos() {
    var v = (typeof matsuAbertos !== "undefined" && matsuAbertos) ? matsuAbertos : "tela";
    return (v === "todas" || v === "principal") ? v : "tela";
}

// Uma barra nova na tela pedida. O Plasma cria a barra na tela que estiver em
// uso (a do mouse); aqui ela vai sempre para a tela certa.
function novaBarra(tela) {
    var p = new Panel;
    p.screen = tela;
    return p;
}

function alturaDaBarra() {
    var escala = (typeof matsuEscala !== "undefined" && matsuEscala) ? matsuEscala : 2.75;
    return 2 * Math.ceil(gridUnit * escala / 2);
}

// Menu do Matsu, com o logo, no jeito do vídeo da fusão (busca, recentes,
// todos os apps, ajustes e desligar). "comBusca" põe ao lado a pílula
// "Buscar apps e arquivos", que abre o mesmo menu já pronto para digitar.
// Sem o menu do Matsu (não deveria acontecer), fica o menu do KDE e a busca
// do sistema.
function porMenu(painel, comBusca, principal) {
    var menu;
    if (tem("org.matsu.menu")) {
        menu = painel.addWidget("org.matsu.menu");
        menu.currentConfigGroup = ["General"];
        menu.writeConfig("comBusca", comBusca ? true : false);
    } else {
        menu = painel.addWidget("org.kde.plasma.kickoff");
        menu.currentConfigGroup = ["General"];
        menu.writeConfig("icon", "matsu-menu");
        if (comBusca) {
            porBusca(painel);
        }
    }
    if (principal) {
        menu.currentConfigGroup = ["Shortcuts"];
        menu.writeConfig("global", "Alt+F1");
    }
    return menu;
}

function ondeBusca() {
    var v = (typeof matsuBusca !== "undefined" && matsuBusca) ? matsuBusca : "esquerda";
    return (v === "meio" || v === "nao") ? v : "esquerda";
}

function ondeMenu() {
    return (typeof matsuMenu !== "undefined" && matsuMenu === "meio") ? "meio" : "esquerda";
}

// Só a pílula "Buscar apps e arquivos", longe do botão do menu (na ilha do
// meio). Abre o mesmo menu, já pronto para digitar. Não pega atalho: a tecla
// Meta e o Alt+F1 ficam com o botão do logo.
function porBuscaSozinha(painel) {
    if (tem("org.matsu.menu")) {
        var busca = painel.addWidget("org.matsu.menu");
        busca.currentConfigGroup = ["General"];
        busca.writeConfig("comBusca", true);
        busca.writeConfig("soBusca", true);
        return busca;
    }
    porBusca(painel);
    return null;
}

// Pílula "Buscar" que abre a busca do sistema (só quando falta o menu do Matsu).
function porBusca(painel) {
    if (tem("org.matsu.busca")) {
        painel.addWidget("org.matsu.busca");
    }
}

// De que lado fica a doca no estilo Mac: embaixo (o padrão), à esquerda ou à direita.
function posicaoDaDoca() {
    var v = (typeof matsuPosicao !== "undefined" && matsuPosicao) ? matsuPosicao : "embaixo";
    return (v === "esquerda" || v === "direita") ? v : "embaixo";
}

function estiloDaBarra() {
    var v = (typeof matsuEstilo !== "undefined" && matsuEstilo) ? matsuEstilo : "fusao";
    return (v === "mac" || v === "windows") ? v : "fusao";
}

// Medidas da barra de baixo, em pixels, para saber quantos apps cabem nela.
// Vêm do que o Plasma desenha (com folga, porque o gridUnit deste roteiro pode
// sair um pouco menor que o das peças): cada app é um quadrado da altura da
// barra com um respiro em volta; a pílula da busca tem 12,5 gridUnits mais o
// espaço; a ilha da direita (escudo, setinha, central, relógio e sino) cerca
// de 17,5.
function larguraDoApp(altura) {
    return altura + Math.round(gridUnit * 0.45);
}

function larguraDaBusca() {
    return gridUnit * 13;
}

function larguraDaBandeja() {
    return gridUnit * 18;
}

// Na fusão, a ilha do meio (os apps) fica centrada e não pode encostar nas
// ilhas dos lados: o tamanho máximo dela sai da largura da tela menos o dobro
// da ilha mais larga dos lados (ela é centrada), com um respiro.
function espacoDoMeio(largura, altura) {
    var esquerda = 0;
    if (ondeMenu() !== "meio") {
        esquerda = altura + (ondeBusca() === "esquerda" ? larguraDaBusca() : 0) + gridUnit;
    }
    var lados = Math.max(esquerda, larguraDaBandeja()) + gridUnit * 2;
    return Math.max(gridUnit * 8, Math.min(Math.round(largura * 0.6), largura - lados * 2));
}

// Quantos apps fixados cabem na barra de baixo sem passar da borda e sem
// encostar nas outras ilhas, numa tela com esta largura e uma barra com esta
// altura. Fica um lugar livre para um app aberto que não é fixado (com mais
// abertos, o Plasma encolhe os ícones um pouco, sem passar da borda). Nunca
// menos de 4; na fusão e no windows, até 12 (mais que isso já não fica bonito);
// na doca do estilo Mac, até 24 (a barra de cima leva a bandeja e o relógio).
function limiteDeApps(estilo, largura, altura, meioMedido) {
    var app = larguraDoApp(altura);
    var lixeira = app + Math.round(gridUnit * 0.5);
    var espaco, maximo = 12;
    if (estilo === "mac") {
        espaco = Math.round(largura * 0.8) - lixeira - gridUnit;
        maximo = 24;
    } else if (estilo === "windows") {
        espaco = largura - altura - (ondeBusca() !== "nao" ? larguraDaBusca() : 0) - larguraDaBandeja() - gridUnit * 2;
    } else {
        var junto = 0;
        if (ondeMenu() === "meio") {
            junto = altura + (ondeBusca() !== "nao" ? larguraDaBusca() : 0);
        } else if (ondeBusca() === "meio") {
            junto = larguraDaBusca();
        }
        espaco = (meioMedido > 0 ? meioMedido : espacoDoMeio(largura, altura)) - junto - lixeira - gridUnit;
    }
    var cabem = Math.floor(espaco / app) - 1;
    return Math.max(4, Math.min(maximo, cabem));
}

// O limite para as barras que este arranjo vai montar: conta a tela mais
// estreita (os fixados são os mesmos em todas as barras).
function limiteDoArranjo(estilo, altura) {
    var telas = emTodasAsTelas() ? Math.max(1, screenCount) : 1;
    var limite = 0;
    for (var t = 0; t < telas; t++) {
        var g = screenGeometry(t);
        // A doca do Mac de pé (à esquerda ou à direita) usa a altura da tela.
        var comprimento = (estilo === "mac" && posicaoDaDoca() !== "embaixo") ? g.height - gridUnit * 3 : g.width;
        var l = limiteDeApps(estilo, comprimento, altura);
        limite = (limite === 0) ? l : Math.min(limite, l);
    }
    return limite;
}

// Na fusão, com as ilhas já na tela: o espaço da ilha do meio pelo
// comprimento de verdade das ilhas dos lados (o Plasma sabe quanto cada uma
// ocupa). Zero quando não dá para medir.
function espacoDoMeioMedido(barras, painel) {
    if (painel.alignment !== "center") {
        return 0;
    }
    var lados = 0;
    for (var i = 0; i < barras.length; i++) {
        var b = barras[i];
        if (b.id !== painel.id && b.screen === painel.screen && b.location === painel.location
                && (b.alignment === "left" || b.alignment === "right") && b.length > 0) {
            lados = Math.max(lados, b.length);
        }
    }
    if (lados <= 0) {
        return 0;
    }
    var largura = screenGeometry(painel.screen >= 0 ? painel.screen : 0).width;
    // A ilha flutuante fica um pouco longe da borda; mais um respiro entre as ilhas.
    return Math.max(gridUnit * 8, Math.min(Math.round(largura * 0.6), largura - 2 * (lados + Math.round(gridUnit * 1.5))));
}

// O limite das barras que já estão na área de trabalho (para fixar um app
// novo): a barra com apps mais apertada manda. Zero se não achar nenhuma.
// Na fusão, de quebra, a ilha do meio passa a respeitar o tamanho medido das
// ilhas dos lados (assim ela nunca encosta nelas, nem com muitos abertos).
function limiteDasBarras(barras, estilo) {
    var limite = 0;
    for (var a = 0; a < barras.length; a++) {
        var ids = barras[a].widgetIds;
        for (var w = 0; w < ids.length; w++) {
            var item = barras[a].widgetById(ids[w]);
            if (!pecaDeApps(item)) {
                continue;
            }
            var tela = barras[a].screen >= 0 ? barras[a].screen : 0;
            var altura = barras[a].height > 0 ? barras[a].height : alturaDaBarra();
            var medido = (estilo === "fusao") ? espacoDoMeioMedido(barras, barras[a]) : 0;
            if (medido > 0 && barras[a].maximumLength !== medido) {
                barras[a].maximumLength = medido;
            }
            var geo = screenGeometry(tela);
            var dePe = barras[a].location === "left" || barras[a].location === "right";
            var l = limiteDeApps(estilo, dePe ? geo.height - gridUnit * 3 : geo.width, altura, medido);
            limite = (limite === 0) ? l : Math.min(limite, l);
        }
    }
    return limite;
}

// Só entra na barra o programa que está instalado, para não sobrar ícone em branco.
function fixadosPadrao() {
    var fixados = ["preferred://filemanager", "preferred://browser"];
    var candidatos = [
        "org.matsu.terminal.desktop",
        "steam.desktop",
        "code.desktop",
        "org.matsu.loja.desktop",
        "org.matsu.tarefas.desktop"
    ];
    for (var c = 0; c < candidatos.length; c++) {
        if (applicationExists(candidatos[c])) {
            fixados.push("applications:" + candidatos[c]);
        }
    }
    // Ajustes do Matsu (como os Ajustes do Mac); sem eles, os do KDE.
    if (applicationExists("org.matsu.ajustes.desktop")) {
        fixados.push("applications:org.matsu.ajustes.desktop");
    } else if (applicationExists("systemsettings.desktop")) {
        fixados.push("applications:systemsettings.desktop");
    }
    return fixados;
}

// O Plasma pode devolver a lista dos fixados como texto ("a,b,c") ou como
// lista. Aqui vira sempre lista limpa.
function listaDeApps(valor) {
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

// Os apps fixados na barra da tela pedida (ou em qualquer barra, se a tela
// não tiver). Lista vazia quando não acha nenhuma.
function fixadosDasBarras(barras, tela) {
    var achados = null;
    for (var a = 0; a < barras.length; a++) {
        var ids = barras[a].widgetIds;
        for (var w = 0; w < ids.length; w++) {
            var item = barras[a].widgetById(ids[w]);
            if (!pecaDeApps(item)) {
                continue;
            }
            item.currentConfigGroup = ["General"];
            var lidos = listaDeApps(item.readConfig("launchers", ""));
            if (barras[a].screen === tela) {
                return lidos;
            }
            if (achados === null) {
                achados = lidos;
            }
        }
    }
    return achados || [];
}

// Apps fixados e abertos. Mantém o que a pessoa já tinha fixado, se houver.
// Com mais de uma tela, cada barra mostra os apps abertos na sua tela (ou em
// todas, como a pessoa escolher). Os fixados aparecem em todas as barras.
function porApps(painel, tela) {
    var doca = usaDoca();
    var apps = painel.addWidget(doca ? "org.matsu.doca" : "org.kde.plasma.icontasks");
    if (doca) {
        ajustarDoca(apps);
    }
    apps.currentConfigGroup = ["General"];
    var guardados = (typeof matsuFixados !== "undefined") ? matsuFixados : null;
    var lista = (guardados && guardados.length) ? guardados : fixadosPadrao();
    // Nunca mais apps do que cabem na barra deste estilo. Os que sobram são
    // avisados ("matsu-cortado") e o comando "matsu barra" guarda: voltam
    // quando a pessoa usar um estilo com mais lugar (a doca do Mac).
    var limite = limiteDoArranjo(estiloDaBarra(), painel.height > 0 ? painel.height : alturaDaBarra());
    if (lista.length > limite) {
        if (tela === 0) {
            for (var c = limite; c < lista.length; c++) {
                print("matsu-cortado: " + lista[c] + "\n");
            }
        }
        lista = lista.slice(0, limite);
    }
    apps.writeConfig("launchers", lista);
    var abertos = ondeAbertos();
    var soDaTela = abertos === "tela" || (abertos === "principal" && !ehPrincipal(tela));
    apps.writeConfig("showOnlyCurrentScreen", soDaTela);
    print("matsu: barra da tela " + tela + " com " + lista.length + " apps fixados (cabem " + limite + ")" + (soDaTela ? ", abertos só desta tela" : "") + "\n");
    return apps;
}

// Lixeira do Matsu no fim dos apps, separada por um risquinho, como no Mac.
// Recebe arquivos arrastados, mostra quando está cheia e abre com um clique.
// Na doca do Matsu a lixeira fica dentro dela (e cresce junto com os apps).
function porLixeira(painel, apps) {
    if (apps && apps.type === "org.matsu.doca") {
        apps.currentConfigGroup = ["General"];
        apps.writeConfig("lixeira", true);
        return;
    }
    if (!tem("org.kde.plasma.trash")) {
        return;
    }
    if (tem("org.kde.plasma.marginsseparator")) {
        painel.addWidget("org.kde.plasma.marginsseparator");
    }
    painel.addWidget("org.kde.plasma.trash");
}

// Ilha da direita, como no vídeo da fusão: ícones dos apps em segundo plano
// (com a setinha "mostrar mais"), a pílula de rede, Bluetooth, som e bateria
// (central de controle), a hora com a data e o sino. Nas outras telas, como
// no Windows, fica só a hora com a data e o sino.
function porBandeja(painel, principal) {
    if (!principal) {
        porRelogio(painel, false);
        return;
    }
    var bandeja = painel.addWidget("org.kde.plasma.systemtray");
    arrumarBandeja(bandeja);
    porCentral(painel);
    porRelogio(painel, true);
}

// Uma lista de peças guardada pelo Plasma ("a,b" ou lista) como lista limpa.
function listaDePecas(valor) {
    var itens = [];
    var partes = !valor ? [] : (typeof valor === "string") ? valor.split(",") : valor;
    for (var n = 0; n < partes.length; n++) {
        var texto = String(partes[n]).replace(/^\s+|\s+$/g, "");
        if (texto.length) {
            itens.push(texto);
        }
    }
    return itens;
}

// Bandeja como no Windows: aparecem os ícones dos apps que estão rodando
// (Discord, Steam, OBS...), com menu no botão direito. Rede, som, Bluetooth e
// bateria já estão na pílula da central; as outras peças do KDE (área de
// transferência, discos, impressoras...) ficam guardadas na setinha
// "mostrar mais", que também abre com Meta+B, como no Windows.
function arrumarBandeja(bandeja) {
    var alvo = bandeja;
    // Até o Plasma 6.3 a bandeja guardava as peças num contêiner à parte.
    bandeja.currentConfigGroup = [];
    var antigo = bandeja.readConfig("SystrayContainmentId");
    if (antigo) {
        var interno = desktopById(antigo);
        if (interno) {
            alvo = interno;
        }
    }
    // O escudo da Central de segurança fica à mostra, perto dos ícones da
    // central (como no mockup); o resto das peças do KDE vai para a setinha.
    var aMostra = tem("org.matsu.seguranca") ? ["org.matsu.seguranca"] : [];
    var guardados = [];
    for (var i = 0; i < knownWidgetTypes.length; i++) {
        if (aMostra.indexOf(knownWidgetTypes[i]) === -1) {
            guardados.push(knownWidgetTypes[i]);
        }
    }
    alvo.currentConfigGroup = ["General"];
    alvo.writeConfig("hiddenItems", guardados);
    alvo.writeConfig("shownItems", aMostra);
    if (aMostra.length) {
        // Liga o escudo na bandeja (sem desligar as outras peças já ligadas).
        var extras = listaDePecas(alvo.readConfig("extraItems", ""));
        for (var m = 0; m < aMostra.length; m++) {
            if (extras.indexOf(aMostra[m]) === -1) {
                extras.push(aMostra[m]);
            }
        }
        alvo.writeConfig("extraItems", extras);
    }
    alvo.writeConfig("iconSize", 0);        // 16 px, do tamanho dos ícones da pílula
    alvo.writeConfig("iconSpacing", 2);
    bandeja.currentConfigGroup = ["Shortcuts"];
    bandeja.writeConfig("global", "Meta+B");
    bandeja.globalShortcut = "Meta+B";
    print("matsu: bandeja com " + guardados.length + " peças do KDE na setinha (contêiner " + (antigo ? "antigo " + antigo : "novo") + ")\n");
}

// Relógio do Matsu: hora em negrito, data embaixo e o sino; um clique abre as
// notificações e o calendário (Meta+N, como no Windows). Se ele faltar, entra o
// relógio do KDE, discreto como no Windows 11. O atalho fica só no da tela
// principal.
function porRelogio(painel, comAtalho) {
    if (tem("org.matsu.relogio")) {
        var nosso = painel.addWidget("org.matsu.relogio");
        if (comAtalho) {
            nosso.currentConfigGroup = ["Shortcuts"];
            nosso.writeConfig("global", "Meta+N");
            nosso.globalShortcut = "Meta+N";
        }
        return nosso;
    }
    var relogio = painel.addWidget("org.kde.plasma.digitalclock");
    relogio.currentConfigGroup = ["Appearance"];
    relogio.writeConfig("showDate", true);
    relogio.writeConfig("dateFormat", "shortDate");
    relogio.writeConfig("dateDisplayFormat", 2);      // data embaixo da hora
    relogio.writeConfig("autoFontAndSize", false);
    relogio.writeConfig("fontSize", 10);
    relogio.writeConfig("fontWeight", 600);
    return relogio;
}

// Central de controle do Matsu (rede, som, tema, não perturbe), no atalho Meta+A.
function porCentral(painel) {
    if (tem("org.matsu.central")) {
        var central = painel.addWidget("org.matsu.central");
        central.currentConfigGroup = ["Shortcuts"];
        central.writeConfig("global", "Meta+A");
        // Vale na hora, sem esperar o próximo login.
        central.globalShortcut = "Meta+A";
    }
}
// Estilo "fusão" (o padrão do Matsu): três ilhas flutuantes embaixo.
// Menu e busca à esquerda (ou no meio), apps no meio, rede, som e relógio à direita.

var matsuEstilo = "fusao";

function ilha(tela, alinhamento) {
    var p = novaBarra(tela);
    p.location = "bottom";
    p.height = alturaDaBarra();
    p.alignment = alinhamento;
    // A ilha tem o tamanho do que está dentro dela.
    p.lengthMode = "fit";
    p.minimumLength = gridUnit * 4;
    // A ilha do meio nunca encosta nas dos lados (nem com muitos apps abertos:
    // aí o Plasma encolhe os ícones).
    p.maximumLength = (alinhamento === "center") ? espacoDoMeio(screenGeometry(tela).width, p.height)
                                                 : Math.round(screenGeometry(tela).width * 0.6);
    p.floating = true;
    p.hiding = esconder();
    return p;
}

function montarTela(tela) {
    var principal = ehPrincipal(tela);
    // A busca pode ficar junto do menu (padrão), na ilha do meio ou sumir, e o
    // menu pode ir para o meio, como no Windows 11 (aí a ilha da esquerda some).
    var buscaFica = ondeBusca();
    var menuNoMeio = ondeMenu() === "meio";
    if (!menuNoMeio) {
        var esquerda = ilha(tela, "left");
        porMenu(esquerda, buscaFica === "esquerda", principal);
    }

    var centro = ilha(tela, "center");
    if (menuNoMeio) {
        porMenu(centro, buscaFica !== "nao", principal);
    } else if (buscaFica === "meio") {
        porBuscaSozinha(centro);
    }
    var apps = porApps(centro, tela);
    if (principal) {
        porLixeira(centro, apps);
    }
    print("matsu: tela " + tela + ": busca " + buscaFica + ", menu " + (menuNoMeio ? "meio" : "esquerda") + "\n");

    // Nas outras telas a ilha da direita tem só a hora com a data e o sino.
    var direita = ilha(tela, "right");
    porBandeja(direita, principal);
}
// Monta a barra do estilo escolhido em cada tela, ou só na principal se a
// pessoa pediu. Vem depois de comum.js e do arquivo do estilo.

var matsuQuantasTelas = emTodasAsTelas() ? Math.max(1, screenCount) : 1;
for (var matsuTela = 0; matsuTela < matsuQuantasTelas; matsuTela++) {
    montarTela(matsuTela);
}
print("matsu: barra em " + matsuQuantasTelas + " de " + screenCount + " telas\n");
// Papel de parede do Matsu em todas as telas (só no primeiro arranjo da conta).
var telas = desktopsForActivity(currentActivity());
for (var i = 0; i < telas.length; i++) {
    telas[i].wallpaperPlugin = "org.kde.image";
    telas[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    telas[i].writeConfig("Image", "file:///usr/share/wallpapers/Matsu/");
}
