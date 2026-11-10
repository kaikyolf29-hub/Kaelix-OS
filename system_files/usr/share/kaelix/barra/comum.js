// Kaelix OS: peças comuns aos estilos de barra (fusão, mac e windows).
// Este arquivo é juntado com o do estilo escolhido e enviado ao Plasma.
// Variáveis opcionais que o comando "kaelix barra" define antes:
//   kaelixEscala   tamanho da barra (2.25 pequena, 2.75 média, 3.25 grande)
//   kaelixFixados  lista dos apps que a pessoa já tinha fixado

function tem(tipo) {
    return knownWidgetTypes.indexOf(tipo) !== -1;
}

function alturaDaBarra() {
    var escala = (typeof kaelixEscala !== "undefined" && kaelixEscala) ? kaelixEscala : 2.75;
    return 2 * Math.ceil(gridUnit * escala / 2);
}

// Menu do Kaelix, com o logo.
function porMenu(painel) {
    var menu = painel.addWidget("org.kde.plasma.kickoff");
    menu.currentConfigGroup = ["General"];
    menu.writeConfig("icon", "kaelix-menu");
    menu.currentConfigGroup = ["Shortcuts"];
    menu.writeConfig("global", "Alt+F1");
    return menu;
}

// Pílula "Buscar".
function porBusca(painel) {
    if (tem("org.kaelix.busca")) {
        painel.addWidget("org.kaelix.busca");
    }
}

// Só entra na barra o programa que está instalado, para não sobrar ícone em branco.
function fixadosPadrao() {
    var fixados = ["preferred://filemanager", "preferred://browser"];
    var candidatos = [
        "org.kde.konsole.desktop",
        "steam.desktop",
        "code.desktop",
        "org.kde.discover.desktop",
        "org.kde.plasma-systemmonitor.desktop",
        "systemsettings.desktop"
    ];
    for (var c = 0; c < candidatos.length; c++) {
        if (applicationExists(candidatos[c])) {
            fixados.push("applications:" + candidatos[c]);
        }
    }
    return fixados;
}

// Apps fixados e abertos. Mantém o que a pessoa já tinha fixado, se houver.
function porApps(painel) {
    var apps = painel.addWidget("org.kde.plasma.icontasks");
    apps.currentConfigGroup = ["General"];
    var guardados = (typeof kaelixFixados !== "undefined") ? kaelixFixados : null;
    apps.writeConfig("launchers", (guardados && guardados.length) ? guardados : fixadosPadrao());
    return apps;
}

// Rede, som, o resto da bandeja e o relógio. A bandeja mostra sozinha o que a
// máquina tem: cabo no PC, Wi-Fi e bateria no notebook.
function porBandeja(painel) {
    painel.addWidget("org.kde.plasma.systemtray");
    painel.addWidget("org.kde.plasma.digitalclock");
}
