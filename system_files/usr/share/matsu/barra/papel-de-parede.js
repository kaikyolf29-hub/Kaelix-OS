// Papel de parede do Matsu em todas as telas (só no primeiro arranjo da conta).
var telas = desktopsForActivity(currentActivity());
for (var i = 0; i < telas.length; i++) {
    telas[i].wallpaperPlugin = "org.kde.image";
    telas[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    telas[i].writeConfig("Image", "file:///usr/share/wallpapers/Matsu/");
}
