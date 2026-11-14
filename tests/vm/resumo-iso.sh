#!/usr/bin/bash
# Resumo dos testes da ISO na máquina virtual: para cada boot, diz se a tela
# gráfica do instalador abriu e mostra as linhas dos registros que explicam o
# que aconteceu com a tela (instalador, gnome-kiosk, vídeo, plymouth).
#
# Uso: resumo-iso.sh <pasta-dos-prints>
set -uo pipefail
OUT="$1"
cd "$OUT" || exit 0

echo "== processador da máquina do GitHub: $(cat cpu.txt 2>/dev/null)"
echo "== tela da máquina virtual depois de 2 minutos: $(cat tela.txt 2>/dev/null)"
for alog in *anaconda.log; do
  [[ -f $alog ]] || continue
  nome="${alog%anaconda.log}"; nome="${nome%-}"; [[ -n $nome ]] || nome="principal"
  serial="serial.log"; [[ $nome == principal ]] || serial="$nome.log"
  if grep -q 'ui.gui.hubs: Starting event loop for hub' "$alog"; then
    echo "== boot $nome: o instalador entrou no modo gráfico"
  elif grep -q 'ui.tui' "$alog"; then
    echo "== boot $nome: abriu em modo texto"
  else
    echo "== boot $nome: o instalador não chegou a mostrar nada ($(wc -c < "$alog") bytes de registro)"
  fi
  echo "-- instalador"
  grep -aiE 'display mode|run-in-new-session|kiosk|wayland|x startup|falling back|text mode|traceback|core dump|ui.tui|Starting event loop|libEGL' "$alog" \
    | grep -vE 'Image packages|kickstart_manager|NetworkManager|dbus-daemon' | cut -c1-260 | head -40
  echo "-- journal ($serial)"
  sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$serial" 2>/dev/null \
    | grep -aiE 'kiosk|mutter|virtio_gpu|simpledrm|drm|fbcon|plymouth|segfault|core dump|SIGSEGV|SIGILL|SIGABRT|anaconda\.service|anaconda-direct|tmux|Failed to start|Startup finished|Switching root' \
    | grep -vE 'audit|AVC' | cut -c1-240 | head -80
done
echo "== fim: tela $(cat tela.txt 2>/dev/null); processador $(cat cpu.txt 2>/dev/null)"
exit 0
