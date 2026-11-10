#!/usr/bin/bash
# Testes do ajudante da central de controle, com programas falsos (nmcli, wpctl,
# busctl...) e pastas falsas no lugar de /sys, para rodar em qualquer máquina.
# shellcheck disable=SC2016  # os corpos dos programas falsos ficam em aspas simples de propósito
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CENTRAL="$ROOT/system_files/usr/libexec/kaelix/kaelix-central"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
MOCK="$WORK/bin"; mkdir -p "$MOCK"
CALLS="$WORK/calls.log"
PASS=0; FAILN=0
OUT=""; CODE=0

mock() { # mock <nome> <corpo>
  printf '#!/usr/bin/bash\necho "%s $*" >> "%s"\n%s\n' "$1" "$CALLS" "$2" > "$MOCK/$1"
  chmod +x "$MOCK/$1"
}

run() { # run <args...>  -> saída em $OUT, código em $CODE
  : > "$CALLS"
  OUT="$(PATH="$MOCK:$PATH" KAELIX_SYS_BACKLIGHT="$WORK/backlight" KAELIX_SYS_POWER="$WORK/power" \
         KAELIX_SYS_BLUETOOTH="$WORK/bluetooth" bash "$CENTRAL" "$@" 2>&1 </dev/null)"
  CODE=$?
}

check() { # check <descrição> <condição...>
  local desc="$1"; shift
  if "$@"; then PASS=$((PASS+1)); echo "  ok   $desc"
  else FAILN=$((FAILN+1)); echo "  FAIL $desc"; printf '       | %s\n' "${OUT//$'\n'/$'\n'       | }"; fi
}
linha()  { grep -qxF -- "$1" <<<"$OUT"; }
called() { grep -qF -- "$1" "$CALLS"; }

# Programas do sistema que não são o assunto de cada teste ficam quietos.
mock kreadconfig6 'exit 0'
mock kwriteconfig6 'exit 0'
mock busctl 'exit 0'
mock rfkill 'exit 0'
mock loginctl 'exit 0'
mock plasma-apply-lookandfeel 'exit 0'

echo "PC de mesa: rede cabeada, sem Wi-Fi, sem Bluetooth, sem brilho, sem bateria"
mock nmcli 'case "$*" in *device*) printf "ethernet:connected:Conexao cabeada 1\nloopback:connected (externally):lo\n" ;; *radio*) echo enabled ;; esac'
mock wpctl 'case "$1" in get-volume) echo "Volume: 0.40" ;; *) exit 0 ;; esac'
run estado
check "sem Wi-Fi" linha "wifi_tem=0"
check "Wi-Fi não conta como ligado sem placa" linha "wifi_ligado=0"
check "rede cabeada conectada" bash -c "grep -qx cabo_tem=1 <<<\"\$0\" && grep -qx cabo_ligado=1 <<<\"\$0\"" "$OUT"
check "sem Bluetooth" linha "bt_tem=0"
check "volume em 40" bash -c "grep -qx vol_tem=1 <<<\"\$0\" && grep -qx vol=40 <<<\"\$0\" && grep -qx mudo=0 <<<\"\$0\"" "$OUT"
check "sem ajuste de brilho" linha "brilho_tem=0"
check "sem bateria" linha "bateria_tem=0"
check "tema escuro é o padrão" linha "escuro=1"
check "não perturbe desligado" linha "dnd=0"
check "luz noturna desligada" linha "noturna=0"

echo "notebook: Wi-Fi, Bluetooth, brilho e bateria"
mock nmcli 'case "$*" in *"wifi list"*) printf " :40\n*:78\n" ;; *device*) printf "wifi:connected:Casa\\\\:5G\nethernet:unavailable:\n" ;; *radio*) echo enabled ;; esac'
mkdir -p "$WORK/backlight/intel_backlight" "$WORK/power/BAT0" "$WORK/bluetooth/hci0"
echo 600 > "$WORK/backlight/intel_backlight/brightness"; echo 1200 > "$WORK/backlight/intel_backlight/max_brightness"
echo 82 > "$WORK/power/BAT0/capacity"; echo Charging > "$WORK/power/BAT0/status"
mock busctl 'case "$*" in *get-property*) echo "b true" ;; esac'
mock wpctl 'case "$1" in get-volume) echo "Volume: 0.75 [MUTED]" ;; *) exit 0 ;; esac'
run estado
check "Wi-Fi ligado com o nome da rede" bash -c "grep -qx wifi_tem=1 <<<\"\$0\" && grep -qx wifi_ligado=1 <<<\"\$0\" && grep -qx 'wifi_nome=Casa:5G' <<<\"\$0\"" "$OUT"
check "força do sinal do Wi-Fi conectado" linha "wifi_sinal=78"
check "cabo existe mas está solto" bash -c "grep -qx cabo_tem=1 <<<\"\$0\" && grep -qx cabo_ligado=0 <<<\"\$0\"" "$OUT"
check "Bluetooth ligado" bash -c "grep -qx bt_tem=1 <<<\"\$0\" && grep -qx bt_ligado=1 <<<\"\$0\"" "$OUT"
check "brilho em 50" bash -c "grep -qx brilho_tem=1 <<<\"\$0\" && grep -qx brilho=50 <<<\"\$0\"" "$OUT"
check "bateria em 82 carregando" bash -c "grep -qx bateria_tem=1 <<<\"\$0\" && grep -qx bateria=82 <<<\"\$0\" && grep -qx carregando=1 <<<\"\$0\"" "$OUT"
check "som mudo" bash -c "grep -qx vol=75 <<<\"\$0\" && grep -qx mudo=1 <<<\"\$0\"" "$OUT"

echo "Wi-Fi desligado no botão"
mock nmcli 'case "$*" in *device*) printf "wifi:unavailable:\n" ;; *radio*) echo disabled ;; esac'
run estado
check "Wi-Fi existe mas está desligado" bash -c "grep -qx wifi_tem=1 <<<\"\$0\" && grep -qx wifi_ligado=0 <<<\"\$0\" && grep -qx wifi_nome= <<<\"\$0\"" "$OUT"
check "sem Wi-Fi conectado, sinal zero" linha "wifi_sinal=0"

echo "tema, não perturbe e luz noturna"
mock kreadconfig6 'case "$*" in *LookAndFeelPackage*) echo org.kaelix.claro.desktop ;; *DoNotDisturb*) echo "2999,1,2,3,4,5" ;; *NightColor*) echo true ;; esac'
run estado
check "tema claro" linha "escuro=0"
check "não perturbe ligado enquanto a data está no futuro" linha "dnd=1"
check "luz noturna ligada" linha "noturna=1"
mock kreadconfig6 'case "$*" in *DoNotDisturb*) echo "2001,1,2,3,4,5.5" ;; esac'
run estado
check "não perturbe com data vencida conta como desligado" linha "dnd=0"
run estado nao-perturbe
check "estado só do não perturbe (para o sino do relógio)" test "$OUT" = "dnd=0"
mock kreadconfig6 'exit 0'

echo "máquina sem nada (nenhum programa responde)"
rm -f "$MOCK/nmcli" "$MOCK/wpctl"
mock nmcli 'exit 1'
mock wpctl 'exit 1'
rm -rf "$WORK/backlight" "$WORK/power" "$WORK/bluetooth"
run estado
check "não quebra e sai com 0" test "$CODE" -eq 0
check "sem som" linha "vol_tem=0"
check "sem rede" bash -c "grep -qx wifi_tem=0 <<<\"\$0\" && grep -qx cabo_tem=0 <<<\"\$0\"" "$OUT"

echo "ações"
mock nmcli 'exit 0'
mock wpctl 'exit 0'
run wifi on;  check "liga o Wi-Fi" called "nmcli radio wifi on"
run wifi off; check "desliga o Wi-Fi" called "nmcli radio wifi off"
run wifi talvez; check "valor estranho é recusado" test "$CODE" -eq 2
run bluetooth on; check "sem Bluetooth, avisa e não chama nada" bash -c "[ '$CODE' -eq 1 ] && ! grep -q busctl '$CALLS'"
mkdir -p "$WORK/bluetooth/hci1"
run bluetooth on;  check "liga o Bluetooth no adaptador que existe" called "busctl set-property org.bluez /org/bluez/hci1 org.bluez.Adapter1 Powered b true"
check "destrava o Bluetooth antes de ligar" called "rfkill unblock bluetooth"
run bluetooth off; check "desliga o Bluetooth" called "Powered b false"
run nao-perturbe on;  check "liga o não perturbe com data no formato do KDE" bash -c "grep -Eq 'kwriteconfig6 --file plasmanotifyrc --group DoNotDisturb --key Until --notify [0-9]{4},[0-9]+,[0-9]+,[0-9]+,[0-9]+,[0-9]+$' '$CALLS'"
run nao-perturbe off; check "desliga o não perturbe" called "--key Until --notify --delete"
run tema claro;  check "troca para o tema claro" called "plasma-apply-lookandfeel -a org.kaelix.claro.desktop"
run tema escuro; check "troca para o tema escuro" called "plasma-apply-lookandfeel -a org.kaelix.escuro.desktop"
run tema roxo;   check "tema desconhecido é recusado" test "$CODE" -eq 2
run luz-noturna on;  check "liga a luz noturna e avisa o sistema" bash -c "grep -qF -- '--key Active --notify true' '$CALLS' && grep -qF 'org.kde.KWin reconfigure' '$CALLS'"
run luz-noturna off; check "desliga a luz noturna" called "--key Active --notify false"
run volume 37;  check "ajusta o volume" called "wpctl set-volume @DEFAULT_AUDIO_SINK@ 37%"
run volume 250; check "volume não passa de 100" called "wpctl set-volume @DEFAULT_AUDIO_SINK@ 100%"
run volume alto; check "volume sem número é recusado" bash -c "[ '$CODE' -eq 2 ] && ! grep -q wpctl '$CALLS'"
run mudo; check "alterna o mudo" called "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
run brilho 50; check "sem tela com brilho, avisa" test "$CODE" -eq 1
mkdir -p "$WORK/backlight/amdgpu_bl0"
echo 10 > "$WORK/backlight/amdgpu_bl0/brightness"; echo 255 > "$WORK/backlight/amdgpu_bl0/max_brightness"
run brilho 50; check "ajusta o brilho pela sessão" called "SetBrightness ssu backlight amdgpu_bl0 128"
run brilho 0;  check "brilho nunca apaga a tela" called "SetBrightness ssu backlight amdgpu_bl0 3"
run bloquear;  check "bloqueia a tela" called "loginctl lock-session"
run sair;      check "abre a tela de desligar" called "org.kde.LogoutPrompt promptAll"
run abrir nada; check "abrir algo desconhecido é recusado" test "$CODE" -eq 2
run dancar; check "comando desconhecido sai com código 2" test "$CODE" -eq 2
run estado tudo; check "parte do estado desconhecida sai com código 2" test "$CODE" -eq 2

echo
echo "Resultado: $PASS passaram, $FAILN falharam"
[[ $FAILN -eq 0 ]]
