#!/usr/bin/bash
# Diagnóstico do boot da ISO de instalação: liga o instalador na máquina virtual
# pelo menu da própria ISO, como no PC, e tira de dentro dele os registros:
# - os do instalador, pela porta virtio que ele já procura sozinho
#   (org.fedoraproject.anaconda.log.0);
# - o journal e os /tmp/*.log, digitados no terminal da segunda tela (Ctrl+Alt+F2)
#   e mandados para a porta serial.
# Liga duas vezes: "Instalar" e "Instalar em modo simples" (sem o driver de vídeo),
# para saber se a tela gráfica depende do driver de vídeo.
#
# Uso: diag-iso.sh <instalador.iso> <pasta-dos-registros>
set -euo pipefail

ISO="$(readlink -f "$1")"
OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d /tmp/matsu-diag.XXXX)"
MNT="$TMP/iso"
mkdir -p "$MNT"

OVMF=/usr/share/ovmf/OVMF.fd
[[ -r $OVMF ]] || OVMF=/usr/share/OVMF/OVMF_CODE.fd

sudo mount -o loop,ro "$ISO" "$MNT"
cp "$MNT/EFI/BOOT/grub.cfg" "$OUT/diag-grub.cfg"

echo "== grub.cfg da ISO"
cat "$OUT/diag-grub.cfg"

# A linha "linux" da primeira entrada "Instalar o ..." (a que não é o modo simples).
ARGS="$(awk '
  /^[[:space:]]*menuentry / { dentro = ($0 ~ /Instalar o/ && $0 !~ /modo simples/ && $0 !~ /Conferir/) }
  dentro && /^[[:space:]]*linux/ { $1 = ""; $2 = ""; print; exit }
' "$OUT/diag-grub.cfg" | xargs -n1 | grep -vxE 'quiet|rhgb' | xargs)"
echo "== opções da entrada Instalar: $ARGS"
[[ -n $ARGS ]] || { echo "não achei a entrada Instalar no grub.cfg"; exit 1; }

echo "== arquivos da ISO na raiz"
ls -la "$MNT"
UPD="$(grep -oE 'inst.updates=[^ ]+' <<<"$ARGS" | sed -E 's/.*:\///' || true)"
if [[ -n $UPD && -f "$MNT/$UPD" ]]; then
  echo "== conteúdo do $UPD"
  python3 - "$MNT/$UPD" <<'EOF'
import gzip, sys
# Lê o cpio (formato newc) e lista nome, dono e permissão de cada entrada.
d = gzip.open(sys.argv[1]).read()
i = 0
while i < len(d):
    h = d[i:i + 110]
    if h[:6] != b"070701":
        break
    campo = lambda n: int(h[6 + 8 * n:14 + 8 * n], 16)
    modo, uid, gid, tam, ntam = campo(1), campo(2), campo(3), campo(6), campo(11)
    nome = d[i + 110:i + 110 + ntam - 1].decode()
    if nome == "TRAILER!!!":
        break
    print(f"{modo:07o} {uid}:{gid} {tam:>8} {nome}")
    i = (i + 110 + ntam + 3) & ~3
    i = (i + tam + 3) & ~3
EOF
fi
sudo umount "$MNT"

ligar() {
  local nome="$1"; shift
  local sock="$TMP/hmp-$nome" disco="$TMP/disco-$nome.qcow2"
  echo "== boot $nome (teclas no menu: $*)"
  qemu-img create -q -f qcow2 "$disco" 64G
  qemu-system-x86_64 \
    -enable-kvm -cpu host -machine q35 -smp 4 -m 6144 \
    -bios "$OVMF" \
    -drive file="$disco",if=virtio,format=qcow2 \
    -cdrom "$ISO" -boot d \
    -device virtio-vga,xres=1920,yres=1080 -display none \
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
    -device qemu-xhci -device usb-tablet \
    -device virtio-serial-pci \
    -chardev file,id=alog,path="$OUT/diag-$nome-anaconda.log" \
    -device virtserialport,chardev=alog,name=org.fedoraproject.anaconda.log.0 \
    -monitor unix:"$sock",server,nowait \
    -serial file:"$OUT/diag-$nome.log" &
  local pid=$!
  for _ in $(seq 1 30); do [[ -S $sock ]] && break; sleep 1; done
  sleep 10
  python3 "$HERE/hmp.py" "$sock" key "$@"
  for t in 60 120; do
    sleep 60
    python3 "$HERE/hmp.py" "$sock" shot "$OUT/diag-$nome-${t}s.png" || true
  done
  # Terminal da segunda tela. O instalador já trocou o teclado para ABNT2:
  # volta para o americano antes de digitar (a barra "/" muda de lugar).
  python3 "$HERE/hmp.py" "$sock" key ctrl-alt-f2 || true
  sleep 3
  python3 "$HERE/hmp.py" "$sock" key ret || true
  python3 "$HERE/hmp.py" "$sock" type "loadkeys us" || true
  python3 "$HERE/hmp.py" "$sock" key ret || true
  sleep 2
  python3 "$HERE/hmp.py" "$sock" type "journalctl -b -o short-monotonic >/dev/ttyS0" || true
  python3 "$HERE/hmp.py" "$sock" key ret || true
  sleep 10
  python3 "$HERE/hmp.py" "$sock" type "tail -n 400 /tmp/*.log >/dev/ttyS0" || true
  python3 "$HERE/hmp.py" "$sock" key ret || true
  sleep 8
  python3 "$HERE/hmp.py" "$sock" shot "$OUT/diag-$nome-tty2.png" || true
  python3 "$HERE/hmp.py" "$sock" key ctrl-alt-f1 || true
  sleep 3
  python3 "$HERE/hmp.py" "$sock" shot "$OUT/diag-$nome-tty1.png" || true
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  rm -f "$disco"

  echo "== resumo do boot $nome (linhas que importam)"
  grep -naiE 'kiosk|wayland|xorg|mutter|display|graphical|gui|text mode|traceback|failed|timed out|error|core.dump|segfault|drm|virtio.gpu|simpledrm|efifb' \
    "$OUT/diag-$nome.log" "$OUT/diag-$nome-anaconda.log" 2>/dev/null \
    | grep -vE 'ACPI|PCI|pci |usb |EDAC|ftrace|kvm.ko|edac_mce' | cut -c1-300 | tail -150 || true
}

# Menu: a segunda entrada ("Conferir...") vem marcada. "up" vai para "Instalar";
# "down" entra em "Se algo der errado", onde a primeira é o modo simples.
ligar normal up ret
ligar simples down ret ret

# Registros grandes vão comprimidos para o ramo dos prints.
for f in "$OUT"/diag-*.log; do
  if [[ $(stat -c %s "$f") -gt 3000000 ]]; then gzip -9 "$f"; fi
done
rm -rf "$TMP"
