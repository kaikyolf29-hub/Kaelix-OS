#!/usr/bin/bash
# Resumo do teste da ISO na máquina virtual: até onde o instalador do Matsu
# chegou (as telas que abriram), como terminou a instalação e, se deu errado,
# as linhas dos registros que explicam o porquê.
#
# Uso: resumo-iso.sh <pasta-dos-prints>
set -uo pipefail
OUT="$1"
cd "$OUT" || exit 0

limpo() { sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$@" 2>/dev/null; }

echo "== processador da máquina do GitHub: $(cat cpu.txt 2>/dev/null)"
echo "== telas do instalador do Matsu que abriram:"
limpo serial.log | grep -aoE 'MATSU-INSTALADOR: tela [a-z]+' | sed 's/.*tela /   /' | uniq | tr '\n' ' '
echo
echo "== sinais do instalador do Matsu"
limpo serial.log | grep -aE 'MATSU-INSTALADOR' | grep -v ': tela ' | cut -c1-240 | head -20

if ! grep -aqF "instalou e ligou pelo disco" resultado.txt 2>/dev/null; then
  echo "-- registro das telas do Matsu"
  limpo serial.log | grep -aE '^[0-9:]{8} |Traceback|Error|error' | grep -av 'MATSU-INSTALADOR' | cut -c1-240 | tail -40
  echo "-- instalador do Fedora (anaconda.log)"
  grep -aiE 'traceback|error|failed|exception|ostree|deploy|bootc|storage configuration failed' anaconda.log 2>/dev/null \
    | grep -vE 'NetworkManager|dbus-daemon|kickstart_manager' | cut -c1-260 | tail -40
  echo "-- journal"
  limpo serial.log | grep -aiE 'kiosk|segfault|core dump|SIGSEGV|SIGABRT|anaconda\.service|tmux|Failed to start|matsu-instalador' \
    | grep -vE 'audit|AVC' | cut -c1-240 | head -40
fi
echo "== fim: $(cat resultado.txt 2>/dev/null || echo 'sem resultado'); processador $(cat cpu.txt 2>/dev/null)"
exit 0
