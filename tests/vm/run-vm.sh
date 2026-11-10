#!/usr/bin/bash
# Liga o disco do Kaelix numa máquina virtual (QEMU com KVM), faz o login,
# abre o terminal e tira prints de cada etapa.
#
# Uso: run-vm.sh <disco.qcow2> <pasta-dos-prints>
set -euo pipefail

DISK="$1"
OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
SOCK="$(mktemp -u /tmp/kaelix-hmp.XXXX)"
USER_PASS="kaelix"
mkdir -p "$OUT"

hmp()  { python3 "$HERE/hmp.py" "$SOCK" "$@"; }
shot() { hmp shot "$OUT/$1.png"; echo "print: $1"; }

OVMF=/usr/share/ovmf/OVMF.fd
[[ -r $OVMF ]] || OVMF=/usr/share/OVMF/OVMF_CODE.fd

qemu-system-x86_64 \
  -enable-kvm -cpu host -machine q35 -smp 4 -m 6144 \
  -bios "$OVMF" \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -device virtio-vga -display none \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -device qemu-xhci -device usb-tablet \
  -monitor unix:"$SOCK",server,nowait \
  -serial file:"$OUT/serial.log" &
QEMU_PID=$!
trap 'kill $QEMU_PID 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do [[ -S $SOCK ]] && break; sleep 1; done

# Boot: um print a cada 20 segundos nos primeiros 3 minutos.
for i in $(seq -w 1 9); do
  sleep 20
  shot "01-boot-$i"
done

# Tela de login: digita a senha do usuário de teste.
shot "02-login"
hmp type "$USER_PASS"
hmp key ret
sleep 60
shot "03-area-de-trabalho"
sleep 40
shot "04-primeiro-login"

# Fecha a pergunta do navegador (se apareceu) e abre o terminal.
hmp key esc
sleep 5
hmp key ctrl-alt-t
sleep 15
shot "05-terminal"
hmp type "kaelix ajuda"
hmp key ret
sleep 5
shot "06-kaelix-ajuda"
hmp type "clear"
hmp key ret
hmp type "kaelix versao"
hmp key ret
sleep 3
hmp type "fastfetch"
hmp key ret
sleep 8
shot "07-kaelix-versao-fastfetch"

echo "Prints em $OUT"
ls -l "$OUT"
