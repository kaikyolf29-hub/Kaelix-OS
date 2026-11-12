#!/usr/bin/bash
# Só na máquina virtual de teste: abre cada app do menu, um a cada 14 segundos,
# para a VM tirar uma foto de cada um (40-app-*) e dar para conferir tela por
# tela se tudo tem o tema do Matsu, em português, sem nome da base.
#
# Uso: matsu-teste-apps            abre os apps em sequência
#      matsu-teste-apps --lista    só mostra a lista (o run-vm.sh usa)
APPS=(
  org.matsu.arquivos org.matsu.relogio org.matsu.calendario org.matsu.notas org.matsu.calculadora
  org.matsu.blocodenotas org.matsu.fotos org.matsu.camera org.matsu.musica org.matsu.atualizacoes
  org.kde.ark org.kde.kate org.kde.kwrite org.kde.filelight org.kde.kfind
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
# Tudo vai para um registro (a VM mostra no fim, 41-registro-dos-apps): o
# terminal de onde isto foi aberto fecha logo depois.
REGISTRO=/tmp/matsu-teste-apps.log
exec >"$REGISTRO" 2>&1 </dev/null
echo "início: $(date +%T)"
for app in "${APPS[@]}"; do
  arquivo=""
  for pasta in /usr/share/applications /var/lib/flatpak/exports/share/applications "$HOME/.local/share/flatpak/exports/share/applications"; do
    if [[ -f $pasta/$app.desktop ]]; then arquivo=$pasta/$app.desktop; break; fi
  done
  if [[ -n $arquivo ]]; then
    # O comando do Exec= do atalho, sem os %u, %F... (que são para arquivos).
    comando="$(sed -n '/^\[Desktop Entry\]/,/^\[/{s/^Exec=//p}' "$arquivo" | head -n1 | sed -E 's/ ?%[fFuUdDnNickvm]//g')"
    echo "$(date +%T) $app: $comando"
    setsid -f sh -c "$comando" >/dev/null 2>&1 </dev/null
  else
    echo "$(date +%T) $app: não está instalado"
  fi
  sleep 14
done
echo "fim: $(date +%T)"
