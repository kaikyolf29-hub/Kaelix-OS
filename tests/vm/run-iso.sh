#!/usr/bin/bash
# Liga a ISO de instalação do Matsu numa máquina virtual (QEMU com KVM) e tira
# prints do menu de boot e do instalador, para conferir a cara do Matsu, o
# português, o teclado ABNT2 e o horário de Brasília já marcados.
# Não instala nada: só abre o instalador e olha.
#
# Também guarda os registros do instalador (porta virtio que ele procura
# sozinho) e, no fim, o journal inteiro, digitado no terminal da segunda tela
# e mandado para a porta serial. O resumo-iso.sh mostra o que importa deles.
#
# Uso: run-iso.sh <instalador.iso> <pasta-dos-prints>
set -euo pipefail

ISO="$1"
OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
SOCK="$(mktemp -u /tmp/matsu-iso-hmp.XXXX)"
DISK="$(mktemp -u /tmp/matsu-iso-disco.XXXX).qcow2"
TELA="$(mktemp -u /tmp/matsu-iso-tela.XXXX).ppm"
mkdir -p "$OUT"

hmp()  { python3 "$HERE/hmp.py" "$SOCK" "$@"; }
shot() { hmp shot "$OUT/$1.png"; echo "print: $1"; }

OVMF=/usr/share/ovmf/OVMF.fd
[[ -r $OVMF ]] || OVMF=/usr/share/OVMF/OVMF_CODE.fd

grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //' > "$OUT/cpu.txt" || true
qemu-img create -q -f qcow2 "$DISK" 64G
qemu-system-x86_64 \
  -enable-kvm -cpu host -machine q35 -smp 4 -m 6144 \
  -bios "$OVMF" \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -cdrom "$ISO" -boot d \
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

# Uma cópia sem compressão da tela (PPM), para o resumo-iso.sh saber se o
# instalador gráfico está mesmo aparecendo.
hmp ppm "$TELA"
sleep 2
python3 - "$TELA" > "$OUT/tela.txt" <<'PY' || echo "não deu para ler a tela" > "$OUT/tela.txt"
import sys
# PPM (P6): cabeçalho em texto e depois os pixels em RGB.
d = open(sys.argv[1], "rb").read()
campos, i = [], 0
while len(campos) < 4:
    while d[i:i + 1].isspace():
        i += 1
    j = i
    while not d[j:j + 1].isspace():
        j += 1
    campos.append(d[i:j]); i = j
larg, alt = int(campos[1]), int(campos[2])
px = d[i + 1:]
def brilho(x0, x1, y0, y1):
    soma = n = 0
    for y in range(y0, y1, 8):
        for x in range(x0, x1, 8):
            k = (y * larg + x) * 3
            soma += px[k] + px[k + 1] + px[k + 2]; n += 3
    return soma / n
# O instalador gráfico tem o fundo claro à direita; o boot em texto é preto.
direita = brilho(larg // 4, larg, 0, alt)
print("instalador gráfico na tela" if direita > 120 else f"tela escura (boot em texto ou parada), brilho {direita:.0f}")
PY
rm -f "$TELA"

# Abre a tela do teclado (o ABNT2 deve estar marcado), que também mostra a barra de cima.
hmp click 812 468
sleep 8
shot "03-teclado"

# O journal do boot, pelo terminal da segunda tela. O instalador já trocou o
# teclado para ABNT2: volta para o americano antes de digitar.
hmp key ctrl-alt-f2
sleep 3
hmp key ret
hmp type "loadkeys us"
hmp key ret
sleep 2
hmp type "journalctl -b --no-pager -o short-monotonic >/dev/ttyS0"
hmp key ret
sleep 20
