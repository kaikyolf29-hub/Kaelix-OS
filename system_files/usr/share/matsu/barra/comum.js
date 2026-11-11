// Matsu OS: peças comuns aos estilos de barra (fusão, mac e windows).
// Este arquivo é juntado com o do estilo escolhido e enviado ao Plasma.
// Variáveis opcionais que o comando "matsu barra" define antes:
//   matsuEscala   tamanho da barra (2.25 pequena, 2.75 média, 3.25 grande)
//   matsuFixados  lista dos apps que a pessoa já tinha fixado
//   matsuEsconder true para a barra se esconder sozinha (aparece com o mouse)
//   matsuBusca    onde fica a pílula da busca: "esquerda" (junto do menu),
//                  "meio" (na ilha do meio, junto dos apps) ou "nao"
//   matsuMenu     onde fica o botão do menu: "esquerda" ou "meio" (Windows 11)

function tem(tipo) {
    return knownWidgetTypes.indexOf(tipo) !== -1;
}

// "autohide" quando a pessoa pediu para a barra se esconder sozinha.
function esconder() {
    return (typeof matsuEsconder !== "undefined" && matsuEsconder) ? "autohide" : "none";
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
function porMenu(painel, comBusca) {
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
    menu.currentConfigGroup = ["Shortcuts"];
    menu.writeConfig("global", "Alt+F1");
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

// Só entra na barra o programa que está instalado, para não sobrar ícone em branco.
function fixadosPadrao() {
    var fixados = ["preferred://filemanager", "preferred://browser"];
    var candidatos = [
        "org.matsu.terminal.desktop",
        "steam.desktop",
        "code.desktop",
        "org.kde.discover.desktop",
        "org.kde.plasma-systemmonitor.desktop"
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

// Apps fixados e abertos. Mantém o que a pessoa já tinha fixado, se houver.
function porApps(painel) {
    var apps = painel.addWidget("org.kde.plasma.icontasks");
    apps.currentConfigGroup = ["General"];
    var guardados = (typeof matsuFixados !== "undefined") ? matsuFixados : null;
    var lista = (guardados && guardados.length) ? guardados : fixadosPadrao();
    apps.writeConfig("launchers", lista);
    print("matsu: barra com " + lista.length + " apps fixados\n");
    return apps;
}

// Lixeira do Matsu no fim dos apps, separada por um risquinho, como no Mac.
// Recebe arquivos arrastados, mostra quando está cheia e abre com um clique.
function porLixeira(painel) {
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
// (central de controle), a hora com a data e o sino.
function porBandeja(painel) {
    var bandeja = painel.addWidget("org.kde.plasma.systemtray");
    arrumarBandeja(bandeja);
    porCentral(painel);
    porRelogio(painel);
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
    var guardados = [];
    for (var i = 0; i < knownWidgetTypes.length; i++) {
        guardados.push(knownWidgetTypes[i]);
    }
    alvo.currentConfigGroup = ["General"];
    alvo.writeConfig("hiddenItems", guardados);
    alvo.writeConfig("shownItems", []);
    alvo.writeConfig("iconSize", 0);        // 16 px, do tamanho dos ícones da pílula
    alvo.writeConfig("iconSpacing", 2);
    bandeja.currentConfigGroup = ["Shortcuts"];
    bandeja.writeConfig("global", "Meta+B");
    bandeja.globalShortcut = "Meta+B";
    print("matsu: bandeja com " + guardados.length + " peças do KDE na setinha (contêiner " + (antigo ? "antigo " + antigo : "novo") + ")\n");
}

// Relógio do Matsu: hora em negrito, data embaixo e o sino; um clique abre as
// notificações e o calendário (Meta+N, como no Windows). Se ele faltar, entra o
// relógio do KDE, discreto como no Windows 11.
function porRelogio(painel) {
    if (tem("org.matsu.relogio")) {
        var nosso = painel.addWidget("org.matsu.relogio");
        nosso.currentConfigGroup = ["Shortcuts"];
        nosso.writeConfig("global", "Meta+N");
        nosso.globalShortcut = "Meta+N";
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
