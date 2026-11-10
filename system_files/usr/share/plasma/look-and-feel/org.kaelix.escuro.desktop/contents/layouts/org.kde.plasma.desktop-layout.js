// Kaelix OS: a barra "fusão". Três ilhas flutuantes embaixo:
// menu e busca à esquerda, apps no meio, rede, som e relógio à direita.

function tem(tipo) {
    return knownWidgetTypes.indexOf(tipo) !== -1;
}

function ilha(alinhamento) {
    var p = new Panel;
    p.location = "bottom";
    p.height = 2 * Math.ceil(gridUnit * 2.75 / 2);
    p.alignment = alinhamento;
    // A ilha tem o tamanho do que está dentro dela.
    p.lengthMode = "fit";
    p.minimumLength = gridUnit * 4;
    p.maximumLength = Math.round(screenGeometry(p.screen).width * 0.6);
    p.floating = true;
    p.hiding = "none";
    return p;
}

// Esquerda: menu do Kaelix e busca.
var esquerda = ilha("left");
var menu = esquerda.addWidget("org.kde.plasma.kickoff");
menu.currentConfigGroup = ["General"];
menu.writeConfig("icon", "kaelix-menu");
menu.currentConfigGroup = ["Shortcuts"];
menu.writeConfig("global", "Alt+F1");
if (tem("org.kaelix.busca")) {
    esquerda.addWidget("org.kaelix.busca");
} else if (tem("org.kde.milou")) {
    esquerda.addWidget("org.kde.milou");
}

// Meio: os apps, como num Dock.
var centro = ilha("center");
var apps = centro.addWidget("org.kde.plasma.icontasks");
apps.currentConfigGroup = ["General"];
// Só entra na barra o programa que está instalado, para não sobrar um ícone
// em branco (foi o que aconteceu com o VS Code no primeiro teste).
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
apps.writeConfig("launchers", fixados);

// Direita: rede, som, o resto da bandeja e o relógio. A bandeja mostra sozinha
// o que a máquina tem: cabo no PC, Wi-Fi e bateria no notebook.
var direita = ilha("right");
direita.addWidget("org.kde.plasma.systemtray");
direita.addWidget("org.kde.plasma.digitalclock");

// Papel de parede do Kaelix em todas as telas.
var telas = desktopsForActivity(currentActivity());
for (var i = 0; i < telas.length; i++) {
    telas[i].wallpaperPlugin = "org.kde.image";
    telas[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    telas[i].writeConfig("Image", "file:///usr/share/wallpapers/Kaelix/");
}
