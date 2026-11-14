#!/usr/bin/bash
# Liga a ISO de instalação do Matsu numa máquina virtual (QEMU com KVM) e faz
# uma instalação de verdade pelo instalador do Matsu, do jeito que uma pessoa
# faria: Enter nas telas, nome e senha digitados no teclado. Tira um print de
# cada tela, espera a instalação terminar, tira o pendrive (a ISO), reinicia no
# disco e tira print do login e do primeiro login (as Boas-vindas).
#
# As telas do instalador escrevem "MATSU-INSTALADOR: tela <nome>" na porta
# serial a cada troca; o teste espera por esses sinais em vez de chutar tempos.
# Os registros ficam na pasta: serial.log (sinais e journal), anaconda.log
# (registros do instalador do Fedora, pela porta virtio) e resultado.txt.
#
# Uso: run-iso.sh <instalador.iso> <pasta-dos-prints>
set -uo pipefail

ISO="$1"
OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
SOCK="$(mktemp -u /tmp/matsu-iso-hmp.XXXX)"
DISK="$(mktemp -u /tmp/matsu-iso-disco.XXXX).qcow2"
mkdir -p "$OUT"
: > "$OUT/serial.log"

hmp()  { python3 "$HERE/hmp.py" "$SOCK" "$@"; }
shot() { hmp shot "$OUT/$1.png"; echo "print: $1"; }
resultado() { echo "$1" > "$OUT/resultado.txt"; echo "resultado: $1"; }

# Espera um texto aparecer na porta serial. esperar <texto> <segundos>
esperar() {
  local fim=$((SECONDS + $2))
  while (( SECONDS < fim )); do
    grep -aqF "$1" "$OUT/serial.log" && return 0
    sleep 2
  done
  echo "não apareceu em $2 s: $1"
  return 1
}

# Manda o journal e os registros do instalador para a porta serial, pelo
# terminal da segunda tela (o instalador deixa o teclado em ABNT2: volta para o
# americano antes de digitar).
registros() {
  hmp key ctrl-alt-f2
  sleep 3
  hmp key ret
  hmp type "loadkeys us"
  hmp key ret
  sleep 2
  hmp type "tail -n 80 /tmp/matsu-instalador.log /tmp/anaconda.log /tmp/program.log >/dev/ttyS0; journalctl -b --no-pager -o short-monotonic >/dev/ttyS0"
  hmp key ret
  sleep 25
}

OVMF=/usr/share/ovmf/OVMF.fd
[[ -r $OVMF ]] || OVMF=/usr/share/OVMF/OVMF_CODE.fd

grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //' > "$OUT/cpu.txt" || true
qemu-img create -q -f qcow2 "$DISK" 64G
qemu-system-x86_64 \
  -enable-kvm -cpu host -machine q35 -smp 4 -m 6144 \
  -bios "$OVMF" \
  -drive file="$ISO",media=cdrom,if=none,id=cdrom0,readonly=on -device ide-cd,drive=cdrom0,bootindex=1 \
  -drive file="$DISK",if=none,id=disco0,format=qcow2 -device virtio-blk-pci,drive=disco0,bootindex=2 \
  -device VGA,edid=on,xres=1920,yres=1080 -display none \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -device qemu-xhci -device usb-tablet \
  -device virtio-serial-pci \
  -chardev file,id=alog,path="$OUT/anaconda.log" \
  -device virtserialport,chardev=alog,name=org.fedoraproject.anaconda.log.0 \
  -monitor unix:"$SOCK",server,nowait \
  -qmp unix:"$SOCK.qmp",server,nowait \
  -serial file:"$OUT/serial.log" &
QEMU_PID=$!
trap 'kill $QEMU_PID 2>/dev/null || true; rm -f "$DISK"' EXIT

for _ in $(seq 1 30); do [[ -S $SOCK ]] && break; sleep 1; done

# Menu de boot da ISO. A opção marcada é "conferir o pendrive e instalar", que
# demora; sobe uma linha para "instalar" e entra.
sleep 10
shot "01-menu-de-boot"
hmp key up
sleep 1
hmp key ret

if ! esperar "MATSU-INSTALADOR: tela ola" 300; then
  shot "02-sem-instalador"
  resultado "o instalador do Matsu não abriu"
  registros
  exit 1
fi
sleep 5
shot "02-ola"

# Uma tela por vez: Enter segue (o botão principal), como no Mac.
# Se a tela ainda não deixa seguir (a internet demorando a ligar), aperta de novo.
passo() {  # passo <tela que deve abrir> <print> <segundos antes do print>
  local tentativa achou=0
  for tentativa in 1 2 3 4 5 6 7 8; do
    hmp key ret
    if esperar "MATSU-INSTALADOR: tela $1" 8 > /dev/null; then achou=1; break; fi
    echo "tela $1 ainda não abriu (tentativa $tentativa)"
  done
  if (( ! achou )); then
    shot "erro-$2"
    resultado "parou antes da tela $1"
    registros
    exit 1
  fi
  sleep "$3"
  shot "$2"
}
passo idioma "03-idioma" 2
passo internet "04-internet" 8
passo disco "05-disco" 5
passo conta "06-conta-vazia" 2

# A conta: o nome (o usuário sai sozinho dele), a senha e a confirmação.
hmp type "Matsu Teste"
hmp key tab
sleep 1
hmp key tab
hmp type "matsu123"
hmp key tab
hmp type "matsu123"
sleep 2
shot "07-conta"
passo resumo "08-resumo" 2
passo instalando "09-instalando" 40

# A instalação baixa o Matsu do ghcr.io e grava no disco. Um print a cada 4 minutos.
fim=$((SECONDS + 50 * 60))
n=1
proximo=$((SECONDS + 240))
while (( SECONDS < fim )); do
  if grep -aqF "MATSU-INSTALADOR: instalação concluída" "$OUT/serial.log"; then break; fi
  if grep -aqF "MATSU-INSTALADOR: erro" "$OUT/serial.log"; then break; fi
  if (( SECONDS >= proximo )); then
    shot "10-instalando-$n"
    n=$((n + 1))
    proximo=$((SECONDS + 240))
  fi
  sleep 5
done

if ! esperar "MATSU-INSTALADOR: tela pronto" 20; then
  shot "11-fim-da-instalacao"
  if grep -aqF "MATSU-INSTALADOR: erro" "$OUT/serial.log"; then
    resultado "a instalação deu erro: $(grep -aF 'MATSU-INSTALADOR: erro' "$OUT/serial.log" | head -1 | cut -c1-200)"
  else
    resultado "a instalação não terminou em 50 minutos"
  fi
  registros
  exit 1
fi
sleep 3
shot "11-pronto"

# Tira o pendrive e reinicia (Enter no "Reiniciar"): agora liga pelo disco.
hmp cmd "eject -f cdrom0"
sleep 2
hmp key ret
sleep 150
shot "12-sistema-instalado"

# Entra com a senha criada na instalação: no primeiro login abrem as Boas-vindas.
hmp type "matsu123"
hmp key ret
sleep 60
shot "13-primeiro-login"
resultado "instalou e ligou pelo disco"
exit 0
