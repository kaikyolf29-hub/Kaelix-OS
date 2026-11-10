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
    var lista = (guardados && guardados.length) ? guardados : fixadosPadrao();
    apps.writeConfig("launchers", lista);
    print("kaelix: barra com " + lista.length + " apps fixados\n");
    return apps;
}

// Rede, som, o resto da bandeja e o relógio. A bandeja mostra sozinha o que a
// máquina tem: cabo no PC, Wi-Fi e bateria no notebook.
function porBandeja(painel) {
    painel.addWidget("org.kde.plasma.systemtray");
    porCentral(painel);
    porRelogio(painel);
}

// Relógio discreto, como no Windows 11: hora em cima e data embaixo, em letra
// de 11 pontos, centralizados na ilha. O padrão do KDE estica o texto até
// encher a altura da barra e fica grande demais na ilha.
function porRelogio(painel) {
    var relogio = painel.addWidget("org.kde.plasma.digitalclock");
    relogio.currentConfigGroup = ["Appearance"];
    relogio.writeConfig("showDate", true);
    relogio.writeConfig("dateFormat", "shortDate");
    relogio.writeConfig("dateDisplayFormat", 2);      // data embaixo da hora
    relogio.writeConfig("autoFontAndSize", false);
    relogio.writeConfig("fontSize", 11);
    relogio.writeConfig("fontWeight", 500);           // médio; a escala do Qt 6 vai de 100 a 900
    return relogio;
}

// Central de controle do Kaelix (rede, som, tema, não perturbe), no atalho Meta+A.
function porCentral(painel) {
    if (tem("org.kaelix.central")) {
        var central = painel.addWidget("org.kaelix.central");
        central.currentConfigGroup = ["Shortcuts"];
        central.writeConfig("global", "Meta+A");
        // Vale na hora, sem esperar o próximo login.
        central.globalShortcut = "Meta+A";
    }
}
