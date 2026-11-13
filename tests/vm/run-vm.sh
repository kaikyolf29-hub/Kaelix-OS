#!/usr/bin/bash
# Liga o disco do Matsu numa máquina virtual (QEMU com KVM), faz o login,
# abre o terminal e tira prints de cada etapa.
#
# Uso: run-vm.sh <disco.qcow2> <pasta-dos-prints>
set -euo pipefail

DISK="$1"
OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
SOCK="$(mktemp -u /tmp/matsu-hmp.XXXX)"
USER_PASS="matsu"
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

# Tela de boot do Matsu (Plymouth): aparece por poucos segundos, então tira
# um print a cada 2 segundos no começo.
for i in 1 2 3 4 5 6 7 8; do
  sleep 2
  shot "01a-tela-de-boot-$i"
done
# Boot: três prints no primeiro minuto (o sistema liga em uns 15 segundos).
sleep 4
shot "01-boot-1"
for i in 2 3; do
  sleep 20
  shot "01-boot-$i"
done
sleep 30

# Tela de login: digita a senha do usuário de teste.
shot "02-login"
hmp type "$USER_PASS"
sleep 2
shot "02a-login-com-senha"
hmp key ret
# Tela de carregamento do Matsu (aparece por poucos segundos depois da senha).
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

# Menu do Matsu (tecla Meta), no jeito do vídeo. Depois digita uma busca,
# como no vídeo ("term"), e fecha com Esc (o primeiro limpa, o segundo fecha).
hmp key meta_l
sleep 5
shot "04d-menu"
hmp type "term"
sleep 4
shot "04d2-menu-buscando"
hmp key esc
sleep 1
hmp key esc
sleep 2

# Central de controle pelo atalho Meta+A, na conta nova (antes de trocar a barra).
hmp key meta_l-a
sleep 6
shot "04e-central-pelo-atalho"
hmp key esc
sleep 2

hmp key ctrl-alt-t
sleep 15
shot "05-terminal"
# Bolinhas da borda das janelas (como no Mac): com a janela maximizada, elas ficam
# no canto de cima à esquerda; o mouse chega e os símbolos aparecem.
hmp key meta_l-pgup
sleep 3
shot "05a-terminal-maximizado"
hmp mover 38 15 || echo "o mouse não foi (seguindo sem ele)"
sleep 1
shot "05b-bolinhas-com-mouse"
hmp mover 15 15 || true
sleep 1
shot "05c-bolinhas-com-mouse-no-fechar"
hmp mover 960 600 || true
sleep 1
hmp key meta_l-pgup
sleep 2
hmp type "matsu ajuda"
hmp key ret
sleep 5
shot "06-matsu-ajuda"
hmp type "clear"
hmp key ret
hmp type "matsu versao"
hmp key ret
sleep 3
hmp type "fastfetch"
hmp key ret
sleep 8
shot "07-matsu-versao-fastfetch"
# Terminal do Matsu: uma aba nova (Ctrl+Shift+T) e a tela dividida (Ctrl+( ).
hmp key ctrl-shift-t
sleep 3
hmp type "cd /usr/share/matsu && ls"
hmp key ret
sleep 2
hmp key ctrl-shift-9
sleep 3
hmp type "git -C /usr/share/matsu status 2>/dev/null || ls /usr/share/konsole"
hmp key ret
sleep 2
shot "07b-terminal-abas-e-tela-dividida"
# Fecha o lado novo e a aba nova (Ctrl+Shift+W duas vezes): volta para a primeira.
hmp key ctrl-shift-w
sleep 2
hmp key ctrl-shift-w
sleep 2
shot "07c-terminal-de-volta-na-primeira-aba"
# As janelas que o KWin conhece, com posição e tamanho (para achar uma janela
# invisível que empurre as novas para fora do centro).
hmp type "clear; matsu-teste-janelas"
hmp key ret
sleep 4
shot "07d-janelas-do-kwin"

# A pergunta do navegador, aberta à mão, e o registro do primeiro login.
hmp type "clear"
hmp key ret
hmp type "journalctl --user -b | grep -i matsu | tail -n 12"
hmp key ret
sleep 4
shot "08-registro-do-primeiro-login"
hmp type "matsu navegador"
hmp key ret
sleep 8
shot "09-escolha-do-navegador"
hmp key esc
sleep 2

# Tema claro.
hmp type "clear"
hmp key ret
hmp type "plasma-apply-lookandfeel -a org.matsu.claro.desktop"
hmp key ret
sleep 15
shot "10-tema-claro"
hmp key alt-f4
sleep 3
shot "11-tema-claro-area-de-trabalho"

# Estilos da barra (personalização): windows, mac, fusão grande, busca e menu no
# meio, e de volta ao padrão.
hmp key ctrl-alt-t
sleep 8
hmp type "matsu barra windows --detalhes"
hmp key ret
sleep 10
shot "12-barra-estilo-windows"
hmp type "matsu barra mac --detalhes"
hmp key ret
sleep 10
shot "13-barra-estilo-mac"
hmp type "matsu barra fusao --tamanho grande --detalhes"
hmp key ret
sleep 10
shot "14-barra-fusao-grande"
# A busca dentro da ilha do meio, e depois o menu também no meio (Windows 11).
hmp type "matsu barra fusao --tamanho media --busca meio"
hmp key ret
sleep 10
shot "14b-barra-busca-no-meio"
hmp type "matsu barra --menu meio"
hmp key ret
sleep 10
shot "14c-barra-menu-e-busca-no-meio"
hmp type "matsu barra fusao --tamanho media --busca esquerda --menu esquerda"
hmp key ret
sleep 10
shot "15-barra-de-volta-ao-padrao"
# Apps fixados: põe a Central de jogos na barra e mostra a lista.
hmp type "clear; matsu barra fixar jogos; matsu barra apps"
hmp key ret
sleep 8
shot "15b-barra-app-fixado"

# Tela de boas-vindas com a cara do Matsu (no primeiro login de verdade ela abre sozinha).
hmp type "clear"
hmp key ret
hmp type "plasma-welcome"
hmp key ret
sleep 12
shot "16-boas-vindas-1"
# Avança as telas com a seta para a direita; as do Matsu ficam perto do fim.
for n in 2 3 4 5 6 7 8; do
  hmp key right
  sleep 3
  shot "16-boas-vindas-$n"
done
hmp key alt-f4
sleep 3

# Escolha de telas do Meta+P (estender, duplicar, só uma tela), com o balão do Matsu.
hmp key meta_l-p
sleep 5
shot "17-escolha-de-telas"
hmp key esc
sleep 2
# Menu de novo, agora que os balões têm o canto redondo do Matsu.
hmp key meta_l
sleep 5
shot "18-menu-com-balao-redondo"
hmp key esc
sleep 2

# Central de controle do Matsu (Meta+A), na ilha da direita. Primeiro no tema claro.
hmp key meta_l-a
sleep 6
shot "19-central-de-controle-claro"
hmp key esc
sleep 2
# O ajudante da central volta para o tema escuro e mostra o que leu do sistema.
hmp key ctrl-alt-t
sleep 8
hmp type "/usr/libexec/matsu/matsu-central tema escuro"
hmp key ret
sleep 15
hmp type "/usr/libexec/matsu/matsu-central estado"
hmp key ret
sleep 4
shot "20-central-estado-lido-do-sistema"
# Onde os atalhos Meta+A (central), Meta+N (relógio) e Meta+B (bandeja) ficaram, e se
# as atividades e o perfil de energia do KDE ficaram sem essas teclas (matsu-atalhos).
hmp type "clear"
hmp key ret
hmp type "grep -i -e meta.a -e meta.n -e meta.b -e widget -e next.activity -e powerprofile .config/kglobalshortcutsrc | tail -n 22"
hmp key ret
sleep 3
shot "20b-atalho-da-central"
# Se algo do Matsu reclamou ao carregar, aparece aqui.
hmp type "clear"
hmp key ret
hmp type "journalctl --user -b | grep -i -e matsu -e qml | tail -n 25"
hmp key ret
sleep 4
shot "21-registro-das-telas-do-matsu"
hmp key alt-f4
sleep 3
# Agora no tema escuro, abrindo com um clique na pílula da central (ilha da direita).
hmp click 1726 1046 || echo "o clique não foi (seguindo sem ele)"
sleep 6
shot "22-central-de-controle-escuro"
hmp key esc
sleep 2

# Bandeja como no Windows: apps de bandeja de verdade (CopyQ e udiskie, cada um
# de um jeito: protocolo novo, AppIndicator e XEmbed) e o que a bandeja registrou.
hmp key ctrl-alt-t
sleep 8
hmp type "matsu-teste-bandeja"
hmp key ret
sleep 16
shot "24-bandeja-o-que-registrou"
hmp key alt-f4
sleep 4
shot "25-bandeja-com-apps"
# Área "mostrar mais" (a setinha), pelo atalho do Windows: Meta+B.
hmp key meta_l-b
sleep 4
shot "26-bandeja-mostrar-mais"
hmp key esc
sleep 2
# Botão direito no ícone do app mais perto da setinha: o menu do app.
hmp rclick 1640 1046 || echo "o clique não foi (seguindo sem ele)"
sleep 3
shot "27-bandeja-menu-do-botao-direito"
hmp key esc
sleep 2
# Clique simples no mesmo ícone: abre o app.
hmp click 1640 1046 || echo "o clique não foi (seguindo sem ele)"
sleep 4
shot "28-bandeja-clique-abre-o-app"
hmp key esc
sleep 2
# Relógio: notificações (com a de teste) e calendário juntos, pelo Meta+N.
hmp key meta_l-n
sleep 4
shot "29-relogio-notificacoes-e-calendario"
hmp key esc
sleep 2

# Ajustes do Matsu (como os Ajustes do Mac): o ajudante passa pelas páginas a
# cada 8 segundos e no fim deixa o vidro roxo e mais transparente, depois sem vidro.
hmp key ctrl-alt-t
sleep 8
hmp type "matsu-teste-ajustes"
hmp key ret
sleep 7
for pagina in aparencia barra barra-apps papel telas sobre; do
  shot "30-ajustes-$pagina"
  sleep 8
done
sleep 10
shot "31-vidro-roxo-mais-transparente"
sleep 18
shot "31b-sem-vidro"
sleep 16
shot "32-vidro-de-volta-ao-padrao"
# Alt+Tab como no Windows 11: as janelas em miniatura (Ajustes e terminal).
hmp segurar alt tab 2 "$OUT/33-alt-tab.png" && echo "print: 33-alt-tab"
sleep 2
hmp key alt-f4
sleep 2
hmp key alt-f4
sleep 2

# Configurações do sistema do KDE com os ícones do Matsu na lista inteira
# (visual/icones/ajustes.js), maximizada para caber mais páginas.
hmp key ctrl-alt-t
sleep 8
hmp type "setsid systemsettings >/dev/null 2>&1 & sleep 1; exit"
hmp key ret
sleep 15
hmp key meta_l-pgup
sleep 4
shot "34-configuracoes-do-sistema"
hmp key alt-f4
sleep 3

# Gerenciador de tarefas do Matsu (Ctrl+Shift+Esc), de vidro: Processos,
# Desempenho (Ctrl+2) e Inicialização (Ctrl+3). Com ele aberto, o mouse passa
# em cima do ícone do meio da barra para mostrar o balão com o nome.
hmp key ctrl-shift-esc
sleep 9
shot "34-gerenciador-processos"
hmp key ctrl-2
sleep 4
shot "34b-gerenciador-desempenho"
hmp key ctrl-3
sleep 3
shot "34c-gerenciador-inicializacao"
hmp key ctrl-1
sleep 1
# As bolinhas do próprio gerenciador, com ele maximizado (ficam no canto de cima à esquerda).
hmp key meta_l-pgup
sleep 3
hmp mover 45 24 || echo "o mouse não foi (seguindo sem ele)"
sleep 1
shot "34d-gerenciador-bolinhas-com-mouse"
hmp mover 960 600 || true
sleep 1
hmp key meta_l-pgup
sleep 2
hmp mover 960 1046 || echo "o mouse não foi (seguindo sem ele)"
sleep 3
shot "35-balao-do-icone-na-barra"
hmp mover 960 500 || true
hmp key alt-f4
sleep 2

# Central de jogos: Início (sem jogos na máquina de teste, mostra o convite da
# Steam), Gráficos (Ctrl+3), Sobreposição (Ctrl+4), Controles (Ctrl+5), Placa de
# vídeo (Ctrl+6) e Drivers (Ctrl+7).
hmp key ctrl-alt-t
sleep 8
hmp type "setsid -f /usr/libexec/matsu/matsu-janela org.matsu.jogos /usr/share/matsu/jogos/Main.qml </dev/null >/dev/null 2>&1; sleep 2; exit"
hmp key ret
sleep 10
shot "36-jogos-inicio"
hmp key ctrl-3
sleep 3
shot "36b-jogos-graficos"
hmp key ctrl-4
sleep 3
shot "36c-jogos-sobreposicao"
hmp key ctrl-5
sleep 4
shot "36e-jogos-controles"
hmp key ctrl-6
sleep 4
shot "36d-jogos-placa"
hmp key ctrl-7
sleep 6
shot "36f-jogos-drivers"
hmp key alt-f4
sleep 2

# Central de segurança: Início, Escudo (Ctrl+2), Rede e firewall (Ctrl+3),
# Permissões dos apps (Ctrl+4), Integridade (Ctrl+5) e Histórico (Ctrl+6).
# Depois, um "programa baixado da internet" de mentira (com o site gravado no
# arquivo, como o Brave faz) aberto pelo sistema mostra o aviso antes de abrir.
hmp key ctrl-alt-t
sleep 8
hmp type "setsid -f /usr/libexec/matsu/matsu-janela org.matsu.seguranca /usr/share/matsu/seguranca/Main.qml </dev/null >/dev/null 2>&1; sleep 2; exit"
hmp key ret
sleep 10
shot "38-seguranca-inicio"
hmp key ctrl-2
sleep 4
shot "38b-seguranca-escudo"
hmp key ctrl-3
sleep 5
shot "38c-seguranca-rede"
hmp key ctrl-4
sleep 5
shot "38d-seguranca-apps"
hmp key ctrl-5
sleep 6
shot "38e-seguranca-integridade"
hmp key ctrl-6
sleep 3
shot "38f-seguranca-historico"
hmp key alt-f4
sleep 2
hmp key ctrl-alt-t
sleep 8
hmp type "d=\$(xdg-user-dir DOWNLOAD); printf '#!/bin/sh\\necho oi\\n' > \"\$d/programa-teste.AppImage\"; python3 -c 'import os,sys; os.setxattr(sys.argv[1], \"user.xdg.origin.url\", b\"https://exemplo.com.br/programa-teste.AppImage\")' \"\$d/programa-teste.AppImage\"; setsid -f xdg-open \"\$d/programa-teste.AppImage\" </dev/null >/dev/null 2>&1; sleep 2; exit"
hmp key ret
sleep 12
shot "38g-seguranca-aviso-de-programa-baixado"
hmp key alt-f4
sleep 2

# Cada app do menu, um por um (40-app-*), para conferir tela por tela o tema
# do Matsu, o português e se sobrou nome da base. O script de dentro
# (teste-apps.sh) abre um app a cada 14 segundos; aqui a foto sai perto do fim
# de cada vez e o app fecha com Alt+F4 (o Esc desfaz a tela de sair se nenhum
# app tiver aberto).
mapfile -t APPS < <(bash "$HERE/teste-apps.sh" --lista)
hmp key ctrl-alt-t
sleep 8
hmp type "setsid -f matsu-teste-apps </dev/null >/dev/null 2>&1; sleep 2; exit"
hmp key ret
inicio=$(date +%s)
for i in "${!APPS[@]}"; do
  alvo=$((inicio + 12 + i * 14))
  agora=$(date +%s)
  if (( alvo > agora )); then sleep $((alvo - agora)); fi
  shot "40-app-$(printf '%02d' "$i")-${APPS[$i]}"
  hmp key alt-f4
  sleep 1
  hmp key esc
done
sleep 3
hmp key ctrl-alt-t
sleep 8
hmp type "cat /tmp/matsu-teste-apps.log"
hmp key ret
sleep 2
shot "41-registro-dos-apps"
# Se os apps não abriram: o que estava pesando na VM e os registros dos testes.
hmp type "clear; uptime; ps -eo pcpu,pmem,etime,comm --sort=-pcpu | head -16; ls -la /tmp/matsu-*.log"
hmp key ret
sleep 3
shot "41b-carga-do-sistema"
hmp key alt-f4
sleep 2

# Fotos do site do Matsu (site-*): cada app sozinho na tela, sem as janelas dos
# testes de antes (o fotos-site.sh fecha tudo antes de cada uma). Cada vez dura
# os segundos da lista mais uns 2 de fechar e abrir; a foto sai perto do fim. O
# visual/site/preparar-fotos.py faz as fotos do site a partir delas.
mapfile -t FOTOS_SITE < <(bash "$HERE/fotos-site.sh" --lista)
hmp key ctrl-alt-t
sleep 8
hmp type "setsid -f matsu-fotos-site </dev/null >/dev/null 2>&1; sleep 2; exit"
hmp key ret
inicio=$(date +%s)
comeco=0
for vez in "${FOTOS_SITE[@]}"; do
  nome="${vez%% *}"; segundos="${vez##* }"
  if [[ $nome == site-01-menu ]]; then
    sleep 5
    hmp key meta_l
  fi
  alvo=$((inicio + comeco + segundos))
  agora=$(date +%s)
  if (( alvo > agora )); then sleep $((alvo - agora)); fi
  shot "$nome"
  if [[ $nome == site-01-menu ]]; then hmp key esc; fi
  comeco=$((comeco + segundos + 2))
done
sleep 4
hmp key ctrl-alt-t
sleep 8
hmp type "cat /tmp/matsu-fotos-site.log"
hmp key ret
sleep 3
shot "site-99-registro"
hmp key alt-f4
sleep 2

# Loja do Matsu: Início (a vitrine e as seções, com o catálogo do Flathub),
# Apps (Ctrl+2), Jogos (Ctrl+3), Na web (Ctrl+4), Biblioteca (Ctrl+5) e a
# página de um app (aberta pelo link appstream://, como os outros apps fazem).
# Fica depois dos outros testes: a Loja baixa o catálogo e pesa na VM. Antes,
# fecha as janelas que sobraram (os Ajustes ficavam por cima da Loja).
hmp key ctrl-alt-t
sleep 8
hmp type "setsid -f matsu-fotos-site --fechar </dev/null >/dev/null 2>&1; sleep 4; exit"
hmp key ret
sleep 8
hmp key ctrl-alt-t
sleep 8
hmp type "setsid -f /usr/libexec/matsu/matsu-janela org.matsu.loja /usr/share/matsu/loja/Main.qml </dev/null >/dev/null 2>&1; sleep 2; exit"
hmp key ret
sleep 25
shot "37-loja-inicio"
hmp key ctrl-2
sleep 4
shot "37b-loja-apps"
hmp key ctrl-3
sleep 4
shot "37c-loja-jogos"
hmp key ctrl-4
sleep 6
shot "37d-loja-na-web"
hmp key ctrl-5
sleep 4
shot "37e-loja-biblioteca"
hmp key alt-f4
sleep 2
hmp key ctrl-alt-t
sleep 8
hmp type "setsid -f xdg-open appstream://com.brave.Browser </dev/null >/dev/null 2>&1; sleep 2; exit"
hmp key ret
sleep 20
shot "37f-loja-pagina-do-app"
hmp key alt-f4
sleep 2

# Tela de bloqueio (Meta+L), com o papel de parede do Matsu. Depois digita a
# senha (aparece a foto, o nome e o campo) e desbloqueia, para provar que
# desbloquear continua funcionando com as peças do Matsu.
hmp key meta_l-l
sleep 8
shot "23-tela-de-bloqueio"
hmp type "$USER_PASS"
sleep 2
shot "23b-bloqueio-com-senha"
hmp key ret
sleep 6
shot "23c-desbloqueado"

# Tela de sair (Ctrl+Alt+Del): sair, reiniciar, desligar. Fica por último e
# fecha com Esc logo depois do print.
hmp key ctrl-alt-delete
sleep 5
shot "34-tela-de-sair"
hmp key esc
sleep 2

echo "Prints em $OUT"
ls -l "$OUT"
