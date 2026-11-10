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
  -device virtio-vga,xres=1920,yres=1080 -display none \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -device qemu-xhci -device usb-tablet \
  -monitor unix:"$SOCK",server,nowait \
  -qmp unix:"$SOCK.qmp",server,nowait \
  -serial file:"$OUT/serial.log" &
QEMU_PID=$!
trap 'kill $QEMU_PID 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do [[ -S $SOCK ]] && break; sleep 1; done

# Boot: três prints no primeiro minuto (o sistema liga em uns 15 segundos).
for i in 1 2 3; do
  sleep 20
  shot "01-boot-$i"
done
sleep 30

# Tela de login: digita a senha do usuário de teste.
shot "02-login"
hmp type "$USER_PASS"
hmp key ret
# Tela de carregamento do Kaelix (aparece por poucos segundos depois da senha).
for i in 1 2 3; do
  sleep 3
  shot "02b-carregando-$i"
done
sleep 51
shot "03-area-de-trabalho"
sleep 40
shot "04-primeiro-login"

# Fecha a pergunta do navegador (se apareceu) e abre o terminal.
hmp key esc
sleep 3
shot "04b-area-de-trabalho-limpa"

# Gerenciador de arquivos (Meta+E), para ver as janelas e as cores.
hmp key meta_l-e
sleep 12
shot "04c-arquivos"
hmp key alt-f4
sleep 2

# Menu do Kaelix (tecla Meta).
hmp key meta_l
sleep 5
shot "04d-menu"
hmp key esc
sleep 2

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

# A pergunta do navegador, aberta à mão, e o registro do primeiro login.
hmp type "clear"
hmp key ret
hmp type "journalctl --user -b | grep -i kaelix | tail -n 12"
hmp key ret
sleep 4
shot "08-registro-do-primeiro-login"
hmp type "kaelix navegador"
hmp key ret
sleep 8
shot "09-escolha-do-navegador"
hmp key esc
sleep 2

# Tema claro.
hmp type "clear"
hmp key ret
hmp type "plasma-apply-lookandfeel -a org.kaelix.claro.desktop"
hmp key ret
sleep 15
shot "10-tema-claro"
hmp key alt-f4
sleep 3
shot "11-tema-claro-area-de-trabalho"

# Estilos da barra (personalização): windows, mac, fusão grande e de volta ao padrão.
hmp key ctrl-alt-t
sleep 8
hmp type "kaelix barra windows --detalhes"
hmp key ret
sleep 10
shot "12-barra-estilo-windows"
hmp type "kaelix barra mac --detalhes"
hmp key ret
sleep 10
shot "13-barra-estilo-mac"
hmp type "kaelix barra fusao --tamanho grande --detalhes"
hmp key ret
sleep 10
shot "14-barra-fusao-grande"
hmp type "kaelix barra fusao --tamanho media"
hmp key ret
sleep 10
shot "15-barra-de-volta-ao-padrao"

# Tela de boas-vindas com a cara do Kaelix (no primeiro login de verdade ela abre sozinha).
hmp type "clear"
hmp key ret
hmp type "plasma-welcome"
hmp key ret
sleep 12
shot "16-boas-vindas-1"
# Avança as telas com a seta para a direita; as do Kaelix ficam perto do fim.
for n in 2 3 4 5 6 7 8; do
  hmp key right
  sleep 3
  shot "16-boas-vindas-$n"
done
hmp key alt-f4
sleep 3

# Escolha de telas do Meta+P (estender, duplicar, só uma tela), com o balão do Kaelix.
hmp key meta_l-p
sleep 5
shot "17-escolha-de-telas"
hmp key esc
sleep 2
# Menu de novo, agora que os balões têm o canto redondo do Kaelix.
hmp key meta_l
sleep 5
shot "18-menu-com-balao-redondo"
hmp key esc
sleep 2

# Central de controle do Kaelix (Meta+A), na ilha da direita. Primeiro no tema claro.
hmp key meta_l-a
sleep 6
shot "19-central-de-controle-claro"
hmp key esc
sleep 2
# O ajudante da central volta para o tema escuro e mostra o que leu do sistema.
hmp key ctrl-alt-t
sleep 8
hmp type "/usr/libexec/kaelix/kaelix-central tema escuro"
hmp key ret
sleep 15
hmp type "/usr/libexec/kaelix/kaelix-central estado"
hmp key ret
sleep 4
shot "20-central-estado-lido-do-sistema"
# Onde o atalho Meta+A da central ficou registrado (ou com quem ele briga).
hmp type "clear"
hmp key ret
hmp type "grep -i -e meta.a -e widget .config/kglobalshortcutsrc"
hmp key ret
sleep 3
shot "20b-atalho-da-central"
# Se algo do Kaelix reclamou ao carregar, aparece aqui.
hmp type "clear"
hmp key ret
hmp type "journalctl --user -b | grep -i -e kaelix -e qml | tail -n 25"
hmp key ret
sleep 4
shot "21-registro-das-telas-do-kaelix"
hmp key alt-f4
sleep 3
# Agora no tema escuro, abrindo com um clique no ícone da central (ilha da direita).
hmp click 1762 1047 || echo "o clique não foi (seguindo sem ele)"
sleep 6
shot "22-central-de-controle-escuro"
hmp key esc
sleep 2

# Tela de bloqueio (Meta+L), com o papel de parede do Kaelix.
hmp key meta_l-l
sleep 8
shot "23-tela-de-bloqueio"

echo "Prints em $OUT"
ls -l "$OUT"
