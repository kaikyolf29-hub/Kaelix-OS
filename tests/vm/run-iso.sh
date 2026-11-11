#!/usr/bin/bash
# Liga a ISO de instalação do Matsu numa máquina virtual (QEMU com KVM) e tira
# prints do menu de boot e do instalador, para conferir a cara do Matsu, o
# português, o teclado ABNT2 e o horário de Brasília já marcados.
# Não instala nada: só abre o instalador e olha.
#
# Uso: run-iso.sh <instalador.iso> <pasta-dos-prints>
set -euo pipefail

ISO="$1"
OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
SOCK="$(mktemp -u /tmp/matsu-iso-hmp.XXXX)"
DISK="$(mktemp -u /tmp/matsu-iso-disco.XXXX).qcow2"
mkdir -p "$OUT"

hmp()  { python3 "$HERE/hmp.py" "$SOCK" "$@"; }
shot() { hmp shot "$OUT/$1.png"; echo "print: $1"; }

OVMF=/usr/share/ovmf/OVMF.fd
[[ -r $OVMF ]] || OVMF=/usr/share/OVMF/OVMF_CODE.fd

qemu-img create -q -f qcow2 "$DISK" 64G
qemu-system-x86_64 \
  -enable-kvm -cpu host -machine q35 -smp 4 -m 6144 \
  -bios "$OVMF" \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -cdrom "$ISO" -boot d \
  -device virtio-vga,xres=1920,yres=1080 -display none \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -device qemu-xhci -device usb-tablet \
  -monitor unix:"$SOCK",server,nowait \
  -qmp unix:"$SOCK.qmp",server,nowait \
  -serial file:"$OUT/serial.log" &
QEMU_PID=$!
trap 'kill $QEMU_PID 2>/dev/null || true; rm -f "$DISK"' EXIT

for _ in $(seq 1 30); do [[ -S $SOCK ]] && break; sleep 1; done

# Menu de boot da ISO. A opção marcada é "testar a mídia e instalar", que demora;
# sobe uma linha para "instalar" e entra.
sleep 10
shot "01-menu-de-boot"
hmp key up
sleep 1
hmp key ret

# O instalador abre em menos de um minuto. Um print a cada 30 segundos.
for i in 1 2 3 4; do
  sleep 30
  shot "02-instalador-$i"
done

# Abre a tela do teclado (o ABNT2 deve estar marcado), que também mostra a barra de cima.
hmp click 812 468
sleep 8
shot "03-teclado"
