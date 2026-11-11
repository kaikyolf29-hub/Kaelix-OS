#!/usr/bin/bash
# Teste da bandeja na VM (só entra na imagem de teste, como matsu-teste-bandeja).
# Abre apps de bandeja de verdade, um de cada jeito que os apps usam:
#   CopyQ    Qt, protocolo novo (StatusNotifierItem), o mesmo do Discord e da Steam
#   udiskie  GTK com a libayatana-appindicator (AppIndicator)
#   udiskie  GTK pelo jeito antigo (XEmbed), que passa pelo xembedsniproxy
# Depois mostra o que a bandeja registrou e manda uma notificação de teste.
set -u

solto() { (setsid "$@" >/dev/null 2>&1 &); }

solto copyq
solto udiskie --tray --appindicator --no-automount --no-notify
solto env GDK_BACKEND=x11 udiskie --tray --no-appindicator --no-automount --no-notify
sleep 8

echo "== Ícones registrados na bandeja (StatusNotifierItem):"
busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
  org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>&1 | tr ' ' '\n' | grep -v '^as$\|^[0-9]*$' | sed 's/^/   /'
echo "== Ponte dos apps antigos (XEmbed):"
pgrep -a xembedsniproxy | sed 's/^/   /' || echo "   xembedsniproxy não está rodando"
echo "== Bibliotecas:"
rpm -q libayatana-appindicator-gtk3 libappindicator-gtk3 | sed 's/^/   /'
echo "== Apps abertos:"
pgrep -a -f 'copyq|udiskie' | grep -v pgrep | sed 's/^/   /'

notify-send -a "Matsu" -i matsu-menu "Teste da central de notificações" "Esta notificação aparece no balão do relógio (Meta+N)."
