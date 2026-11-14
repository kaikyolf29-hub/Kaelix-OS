#!/usr/bin/bash
# Diagnóstico do boot da ISO de instalação: liga o instalador na máquina virtual
# com o registro completo do boot saindo pela porta serial, para ver onde ele
# para. Liga duas vezes: com a cara do Matsu (updates.img) e sem ela, para saber
# se o problema vem dela ou do instalador do Fedora.
#
# Não usa o menu da ISO: pega o kernel, o initrd e as opções da entrada
# "Instalar" do grub.cfg da própria ISO e acrescenta só as opções de registro.
# O console principal continua sendo a tela (console=tty0 por último), para o
# instalador abrir no modo gráfico como abriria no PC.
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
cp "$MNT/images/pxeboot/vmlinuz" "$MNT/images/pxeboot/initrd.img" "$TMP/"
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

LOG_OPTS="console=ttyS0,115200n8 console=tty0 loglevel=6 printk.devkmsg=on log_buf_len=8M systemd.log_target=kmsg systemd.journald.forward_to_kmsg=1"

ligar() {
  local nome="$1" opcoes="$2"
  local sock="$TMP/hmp-$nome" disco="$TMP/disco-$nome.qcow2"
  echo "== boot $nome: $opcoes"
  qemu-img create -q -f qcow2 "$disco" 64G
  qemu-system-x86_64 \
    -enable-kvm -cpu host -machine q35 -smp 4 -m 6144 \
    -bios "$OVMF" \
    -kernel "$TMP/vmlinuz" -initrd "$TMP/initrd.img" -append "$opcoes" \
    -drive file="$disco",if=virtio,format=qcow2 \
    -cdrom "$ISO" \
    -device virtio-vga,xres=1920,yres=1080 -display none \
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
    -device qemu-xhci -device usb-tablet \
    -monitor unix:"$sock",server,nowait \
    -serial file:"$OUT/diag-$nome.log" &
  local pid=$!
  for _ in $(seq 1 30); do [[ -S $sock ]] && break; sleep 1; done
  for t in 60 120 180; do
    sleep 60
    python3 "$HERE/hmp.py" "$sock" shot "$OUT/diag-$nome-${t}s.png" || true
  done
  # A segunda tela de texto (no instalador, um terminal) mostra se ele está vivo.
  python3 "$HERE/hmp.py" "$sock" key ctrl-alt-f2 || true
  sleep 4
  python3 "$HERE/hmp.py" "$sock" shot "$OUT/diag-$nome-tty2.png" || true
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  rm -f "$disco"

  echo "== resumo do boot $nome (linhas que importam)"
  grep -naE 'Welcome|Switching root|switch.root|anaconda|kiosk|wayland|Xorg|Traceback|Failed|FAILED|failed|Timed out|error|Error|Freezing|panic|Starting installer|updates' \
    "$OUT/diag-$nome.log" | grep -vE 'ACPI|PCI|pci |usb |EDAC|ftrace' | tail -200 || true
  echo "== fim do registro $nome"
  tail -60 "$OUT/diag-$nome.log" || true
}

ligar com-marca "$ARGS $LOG_OPTS"
ligar sem-marca "$(xargs -n1 <<<"$ARGS" | grep -v '^inst.updates=' | xargs) $LOG_OPTS"

# Registros grandes vão comprimidos para o ramo dos prints.
for f in "$OUT"/diag-*.log; do
  if [[ $(stat -c %s "$f") -gt 3000000 ]]; then gzip -9 "$f"; fi
done
rm -rf "$TMP"
