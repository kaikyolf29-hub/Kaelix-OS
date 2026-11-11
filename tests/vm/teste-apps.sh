#!/usr/bin/bash
# Só na máquina virtual de teste: abre cada app do menu, um a cada 14 segundos,
# para a VM tirar uma foto de cada um (40-app-*) e dar para conferir tela por
# tela se tudo tem o tema do Matsu, em português, sem nome da base.
#
# Uso: matsu-teste-apps            abre os apps em sequência
#      matsu-teste-apps --lista    só mostra a lista (o run-vm.sh usa)
APPS=(
  org.kde.dolphin org.kde.ark org.kde.kate org.kde.kwrite org.kde.filelight org.kde.kfind
  org.kde.kcharselect org.kde.plasma.emojier org.kde.spectacle org.kde.kinfocenter org.kde.khelpcenter
  org.kde.plasma-systemmonitor org.kde.partitionmanager org.kde.kwalletmanager org.kde.kmenuedit
  org.kde.kjournaldbrowser org.kde.drkonqi.coredump.gui org.kde.kdebugsettings org.kde.kdeconnect.app
  org.kde.krfb org.kde.discover org.kde.plasma-welcome firewall-config org.corectrl.CoreCtrl
  org.mozilla.firefox com.microsoft.VSCode
)
if [[ ${1:-} == --lista ]]; then
  printf '%s\n' "${APPS[@]}"
  exit 0
fi
for app in "${APPS[@]}"; do
  if [[ -f /usr/share/applications/$app.desktop ]]; then
    kioclient exec "/usr/share/applications/$app.desktop" >/dev/null 2>&1 \
      || kstart --application "$app" >/dev/null 2>&1 &
  fi
  sleep 14
done
