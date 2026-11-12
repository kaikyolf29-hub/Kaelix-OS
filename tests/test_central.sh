#!/usr/bin/bash
# Testes do ajudante da central de controle, com programas falsos (nmcli, wpctl,
# busctl...) e pastas falsas no lugar de /sys, para rodar em qualquer máquina.
# shellcheck disable=SC2016  # os corpos dos programas falsos ficam em aspas simples de propósito
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CENTRAL="$ROOT/system_files/usr/libexec/matsu/matsu-central"
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
  OUT="$(PATH="$MOCK:$PATH" MATSU_SYS_BACKLIGHT="$WORK/backlight" MATSU_SYS_POWER="$WORK/power" \
         MATSU_SYS_BLUETOOTH="$WORK/bluetooth" MATSU_STATE_DIR="$WORK/state" \
         XDG_CONFIG_HOME="$WORK/config" MATSU_WALL_DIRS="$WORK/papeis-meus:$WORK/papeis" MATSU_BIN="$MOCK/matsu" \
         MATSU_FLATPAK_DIRS="$WORK/flatpak" MATSU_PLASMA_WALL_DIRS="$WORK/pecas" bash "$CENTRAL" "$@" 2>&1 </dev/null)"
  CODE=$?
}

check() { # check <descrição> <condição...>
  local desc="$1"; shift
  if "$@"; then PASS=$((PASS+1)); echo "  ok   $desc"
  else FAILN=$((FAILN+1)); echo "  FAIL $desc"; printf '       | %s\n' "${OUT//$'\n'/$'\n'       | }"; fi
}
linha()  { grep -qxF -- "$1" <<<"$OUT"; }
has()    { grep -qF -- "$1" <<<"$OUT"; }
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
check "estilo da barra padrão é a fusão" linha "barra=fusao"
check "sem perfil de energia quando o serviço não responde" linha "perfil_tem=0"

echo "notebook: Wi-Fi, Bluetooth, brilho e bateria"
mock nmcli 'case "$*" in *"wifi list"*) printf " :40\n*:78\n" ;; *device*) printf "wifi:connected:Casa\\\\:5G\nethernet:unavailable:\n" ;; *radio*) echo enabled ;; esac'
mkdir -p "$WORK/backlight/intel_backlight" "$WORK/power/BAT0" "$WORK/bluetooth/hci0"
echo 600 > "$WORK/backlight/intel_backlight/brightness"; echo 1200 > "$WORK/backlight/intel_backlight/max_brightness"
echo 82 > "$WORK/power/BAT0/capacity"; echo Charging > "$WORK/power/BAT0/status"
mock busctl 'case "$*" in *PowerProfiles*ActiveProfile*) echo "s \"balanced\"" ;; *PowerProfiles*Profiles*) echo "aa{sv} 3 2 \"Profile\" s \"power-saver\" \"Driver\" s \"x\" 2 \"Profile\" s \"balanced\" \"Driver\" s \"x\" 2 \"Profile\" s \"performance\" \"Driver\" s \"x\"" ;; *get-property*) echo "b true" ;; esac'
mock wpctl 'case "$1" in get-volume) echo "Volume: 0.75 [MUTED]" ;; *) exit 0 ;; esac'
run estado
check "Wi-Fi ligado com o nome da rede" bash -c "grep -qx wifi_tem=1 <<<\"\$0\" && grep -qx wifi_ligado=1 <<<\"\$0\" && grep -qx 'wifi_nome=Casa:5G' <<<\"\$0\"" "$OUT"
check "força do sinal do Wi-Fi conectado" linha "wifi_sinal=78"
check "cabo existe mas está solto" bash -c "grep -qx cabo_tem=1 <<<\"\$0\" && grep -qx cabo_ligado=0 <<<\"\$0\"" "$OUT"
check "Bluetooth ligado" bash -c "grep -qx bt_tem=1 <<<\"\$0\" && grep -qx bt_ligado=1 <<<\"\$0\"" "$OUT"
check "brilho em 50" bash -c "grep -qx brilho_tem=1 <<<\"\$0\" && grep -qx brilho=50 <<<\"\$0\"" "$OUT"
check "bateria em 82 carregando" bash -c "grep -qx bateria_tem=1 <<<\"\$0\" && grep -qx bateria=82 <<<\"\$0\" && grep -qx carregando=1 <<<\"\$0\"" "$OUT"
check "perfil de energia equilibrado, com desempenho disponível" bash -c "grep -qx perfil_tem=1 <<<\"\$0\" && grep -qx perfil=balanced <<<\"\$0\" && grep -qx perfil_desempenho=1 <<<\"\$0\"" "$OUT"
check "som mudo" bash -c "grep -qx vol=75 <<<\"\$0\" && grep -qx mudo=1 <<<\"\$0\"" "$OUT"

echo "Wi-Fi desligado no botão"
mock nmcli 'case "$*" in *device*) printf "wifi:unavailable:\n" ;; *radio*) echo disabled ;; esac'
run estado
check "Wi-Fi existe mas está desligado" bash -c "grep -qx wifi_tem=1 <<<\"\$0\" && grep -qx wifi_ligado=0 <<<\"\$0\" && grep -qx wifi_nome= <<<\"\$0\"" "$OUT"
check "sem Wi-Fi conectado, sinal zero" linha "wifi_sinal=0"

echo "estilo da barra escolhido"
mkdir -p "$WORK/state"; printf 'estilo=mac\ntamanho=media\n' > "$WORK/state/barra"
run estado
check "mostra o estilo da barra que a pessoa escolheu" linha "barra=mac"
rm -rf "$WORK/state"

echo "tema, não perturbe e luz noturna"
mock kreadconfig6 'case "$*" in *LookAndFeelPackage*) echo org.matsu.claro.desktop ;; *DoNotDisturb*) echo "2999,1,2,3,4,5" ;; *NightColor*) echo true ;; esac'
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
run tema claro;  check "troca para o tema claro" called "plasma-apply-lookandfeel -a org.matsu.claro.desktop"
run tema escuro; check "troca para o tema escuro" called "plasma-apply-lookandfeel -a org.matsu.escuro.desktop"
run tema roxo;   check "tema desconhecido é recusado" test "$CODE" -eq 2
run tema claro;  check "o terminal acompanha o tema claro" called "kwriteconfig6 --file konsolerc --group Desktop Entry --key DefaultProfile MatsuClaro.profile"
run tema escuro; check "o terminal acompanha o tema escuro" called "kwriteconfig6 --file konsolerc --group Desktop Entry --key DefaultProfile Matsu.profile"
mock kreadconfig6 'case "$*" in *DefaultProfile*) echo Meu.profile ;; esac'
run tema claro;  check "perfil de terminal da pessoa não é trocado" bash -c "! grep -qF 'DefaultProfile MatsuClaro' '$CALLS'"
mock kreadconfig6 'exit 0'
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
mock busctl 'case "$*" in *UPower.PowerProfiles*ActiveProfile*) [[ $* == *get-property* ]] && echo "s \"balanced\"" ;; esac; exit 0'
run perfil desempenho; check "muda o perfil de energia para desempenho" called "set-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile s performance"
run perfil economia;   check "muda o perfil de energia para economia" called "ActiveProfile s power-saver"
run perfil turbo;      check "perfil desconhecido é recusado" test "$CODE" -eq 2
mock busctl 'case "$*" in *net.hadess*ActiveProfile*) [[ $* == *get-property* ]] && echo "s \"balanced\"" ;; esac; exit 0'
run perfil equilibrado; check "usa o nome antigo do serviço quando o novo não responde" called "set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s balanced"
mock busctl 'exit 0'
run perfil desempenho; check "sem perfil de energia, avisa" test "$CODE" -eq 1
run bloquear;  check "bloqueia a tela" called "loginctl lock-session"
run sair;      check "abre a tela de desligar" called "org.kde.LogoutPrompt promptAll"
echo "ajustes do Matsu"
mock matsu 'exit 0'
mock plasma-apply-wallpaperimage 'exit 0'
mock plasmawindowed 'exit 0'
rm -rf "$WORK/state"
run estado
check "sem escolha, barra média e vidro padrão" bash -c "grep -qx 'barra_tamanho=media' <<<\"\$0\" && grep -qx 'vidro_cor=padrao' <<<\"\$0\" && grep -qx 'vidro_transparencia=normal' <<<\"\$0\"" "$OUT"
mkdir -p "$WORK/state" "$WORK/config"
printf 'estilo=mac\ntamanho=grande\nesconder=sim\n' > "$WORK/state/barra"
printf 'cor=roxo\ntransparencia=mais\n' > "$WORK/state/vidro"
printf '[Containments][1][Wallpaper][org.kde.image][General]\nImage=file:///usr/share/wallpapers/Matsu/\n' > "$WORK/config/plasma-org.kde.plasma.desktop-appletsrc"
run estado
check "lê o tamanho da barra escolhido" bash -c "grep -qx 'barra=mac' <<<\"\$0\" && grep -qx 'barra_tamanho=grande' <<<\"\$0\" && grep -qx 'barra_esconder=1' <<<\"\$0\"" "$OUT"
printf 'estilo=fusao\ntamanho=media\nesconder=nao\nbusca=meio\nmenu=meio\n' > "$WORK/state/barra"
run estado
check "lê onde ficam a busca e o menu" bash -c "grep -qx 'barra_busca=meio' <<<\"\$0\" && grep -qx 'barra_menu=meio' <<<\"\$0\"" "$OUT"
check "várias telas: por padrão a barra em todas e o app na tela dele" bash -c "grep -qx 'barra_telas=todas' <<<\"\$0\" && grep -qx 'barra_abertos=tela' <<<\"\$0\"" "$OUT"
printf 'estilo=fusao\ntelas=principal\nabertos=principal\n' > "$WORK/state/barra"
run estado
check "lê a escolha das várias telas" bash -c "grep -qx 'barra_telas=principal' <<<\"\$0\" && grep -qx 'barra_abertos=principal' <<<\"\$0\"" "$OUT"
printf 'estilo=fusao\ntelas=;rm\nabertos=x\n' > "$WORK/state/barra"
run estado
check "escolha estranha das telas volta ao padrão" bash -c "grep -qx 'barra_telas=todas' <<<\"\$0\" && grep -qx 'barra_abertos=tela' <<<\"\$0\"" "$OUT"
printf 'estilo=fusao\nbusca=;rm\n' > "$WORK/state/barra"
run estado
check "busca guardada estranha vira o padrão" linha "barra_busca=esquerda"
check "lê a cor e a transparência do vidro" bash -c "grep -qx 'vidro_cor=roxo' <<<\"\$0\" && grep -qx 'vidro_transparencia=mais' <<<\"\$0\"" "$OUT"
check "lê o papel de parede sem file:// e sem a barra do fim" bash -c "grep -qx 'papel=/usr/share/wallpapers/Matsu' <<<\"\$0\"" "$OUT"
printf 'cor=padrao\ntransparencia=sem\n' > "$WORK/state/vidro"
run estado
check "lê o vidro desligado (sem vidro)" linha "vidro_transparencia=sem"
run vidro azul menos
check "vidro chama o comando matsu" called "matsu vidro azul --transparencia menos"
run vidro; check "vidro sem cor é recusado" test "$CODE" -eq 2
run barra windows pequena
check "barra chama o comando matsu" called "matsu barra windows --tamanho pequena"
run barra mac media sim
check "barra pode pedir para se esconder sozinha" called "matsu barra mac --tamanho media --esconder sim"
run barra fusao media nao meio esquerda
check "barra pode levar a busca para a ilha do meio" called "matsu barra fusao --tamanho media --esconder nao --busca meio --menu esquerda"
run barra windows media nao esquerda esquerda principal todas
check "barra passa a escolha das várias telas" called "matsu barra windows --tamanho media --esconder nao --busca esquerda --menu esquerda --telas principal --abertos todas"
run barra linux; check "barra desconhecida é recusada" test "$CODE" -eq 2
mkdir -p "$WORK/papeis/Matsu/contents/images" "$WORK/papeis/Matsu/contents/images_dark" "$WORK/papeis/Nuvens/contents/images" "$WORK/papeis/vazio"
touch "$WORK/papeis/Matsu/contents/images/3840x2160.png" "$WORK/papeis/Matsu/contents/screenshot.png"
touch "$WORK/papeis/Nuvens/contents/images/3840x2160.jpg" "$WORK/papeis/Nuvens/contents/images/1280x720.jpg" "$WORK/papeis/Nuvens/contents/images/640x480.jpg"
echo '{"KPlugin":{"Name":"Matsu Pixel"}}' > "$WORK/papeis/Matsu/metadata.json"
run papeis
check "lista os papéis com nome e miniatura do pacote" has "papel|$WORK/papeis/Matsu|Matsu Pixel|$WORK/papeis/Matsu/contents/screenshot.png"
check "sem miniatura usa a menor imagem" has "papel|$WORK/papeis/Nuvens|Nuvens|$WORK/papeis/Nuvens/contents/images/640x480.jpg"
check "pasta sem imagens fica de fora" bash -c "! grep -qF vazio <<<\"\$0\"" "$OUT"
run papel "$WORK/papeis/Nuvens"
check "troca o papel de parede" called "plasma-apply-wallpaperimage $WORK/papeis/Nuvens"
run papel /nao/existe; check "papel que não existe é recusado" test "$CODE" -eq 2
mock kdialog "echo $WORK/foto.png"
touch "$WORK/foto.png"
run papel escolher
check "escolher abre a janela de arquivo e aplica" bash -c "grep -qF 'kdialog' '$CALLS' && grep -qF 'plasma-apply-wallpaperimage $WORK/foto.png' '$CALLS'"
run estado
check "sem Waywallen o papel animado não aparece" bash -c "grep -qx 'papel_animado_tem=0' <<<\"\$0\" && grep -qx 'papel_animado_peca=' <<<\"\$0\" && grep -qx 'papel_tipo=org.kde.image' <<<\"\$0\"" "$OUT"
run papel animado; check "sem a peça, usar o papel animado falha" test "$CODE" -ne 0
mkdir -p "$WORK/flatpak/org.waywallen.waywallen" "$WORK/pecas/org.waywallen.kde"
echo '{"KPlugin":{"Id":"org.waywallen.kde","Name":"Waywallen"}}' > "$WORK/pecas/org.waywallen.kde/metadata.json"
run estado
check "com o Waywallen e a peça, o papel animado aparece" bash -c "grep -qx 'papel_animado_tem=1' <<<\"\$0\" && grep -qx 'papel_animado_peca=org.waywallen.kde' <<<\"\$0\"" "$OUT"
run papel animado
check "usar o papel animado troca a peça do papel em todas as telas" called 'wallpaperPlugin = "org.waywallen.kde"'
mock flatpak 'exit 0'
run abrir papel-animado
check "abre o Waywallen" bash -c "sleep 0.3; grep -qF 'flatpak run org.waywallen.waywallen' '$CALLS'"
run abrir ajustes
check "abre os Ajustes do Matsu" bash -c "sleep 0.3; grep -qF 'plasmawindowed org.matsu.ajustes' '$CALLS'"
run pagina-pedida; check "sem pedido não diz página" test -z "$OUT"
# Os apps que a central abre saem no idioma da pessoa, não no LC_ALL=C do ajudante.
mock plasmawindowed 'echo "plasmawindowed LC_ALL=${LC_ALL-nenhum}" >> "'"$CALLS"'"'
LC_ALL="" run abrir ajustes
check "app aberto não herda o LC_ALL=C do ajudante" bash -c "sleep 0.3; grep -qF 'plasmawindowed LC_ALL=nenhum' '$CALLS'"
LC_ALL=C.UTF-8 run abrir ajustes
check "app aberto recebe o LC_ALL da pessoa" bash -c "sleep 0.3; grep -qF 'plasmawindowed LC_ALL=C.UTF-8' '$CALLS'"
mock plasmawindowed 'exit 0'
run abrir ajustes barra
run pagina-pedida; check "abrir ajustes barra pede a página da barra" linha "pagina=barra"
run pagina-pedida; check "o pedido vale uma vez só" test -z "$OUT"

mock kstart 'exit 0'
run abrir tarefas
check "abre o Gerenciador de tarefas pelo .desktop" bash -c "sleep 0.3; grep -qF 'kstart --application org.matsu.tarefas' '$CALLS'"
run abrir atualizacoes
check "abre a janela Atualizações pelo .desktop" bash -c "sleep 0.3; grep -qF 'kstart --application org.matsu.atualizacoes' '$CALLS'"

mock kcmshell6 'exit 0'
run abrir kcm kcm_keyboard
check "abre uma tela de ajustes do KDE pelo nome" bash -c "sleep 0.3; grep -qF 'kcmshell6 kcm_keyboard' '$CALLS'"
run abrir kcm "kcm_x; rm -rf /"; check "nome de tela estranho é recusado" test "$CODE" -eq 2
run abrir nada; check "abrir algo desconhecido é recusado" test "$CODE" -eq 2
run dancar; check "comando desconhecido sai com código 2" test "$CODE" -eq 2
run estado tudo; check "parte do estado desconhecida sai com código 2" test "$CODE" -eq 2

echo "Idioma (para os Ajustes e a central)"
LC_ALL="" LC_MESSAGES="" LANGUAGE="" MATSU_LANG="" LANG=pt_BR.UTF-8 run estado
check "LANG em português dá idioma=pt" linha "idioma=pt"
LC_ALL="" LC_MESSAGES="" LANGUAGE="" MATSU_LANG="" LANG=en_US.UTF-8 run estado
check "LANG em inglês dá idioma=en" linha "idioma=en"
mkdir -p "$WORK/config"; printf '[Translations]\nLANGUAGE=pt_BR:pt:en_US\n' > "$WORK/config/plasma-localerc"
LC_ALL="" LC_MESSAGES="" LANGUAGE="" MATSU_LANG="" LANG=C run estado
check "sem idioma no ambiente, lê o plasma-localerc" linha "idioma=pt"
rm -f "$WORK/config/plasma-localerc"
LC_ALL="" LC_MESSAGES="" LANGUAGE="pt_BR:pt" MATSU_LANG="" LANG=en_US.UTF-8 run estado
check "LANGUAGE vale mais que o LANG" linha "idioma=pt"
LC_ALL="" LC_MESSAGES="" LANGUAGE="" MATSU_LANG="" LANG=pt_BR.UTF-8 run estado idioma
check "o menu pergunta só o idioma" test "$OUT" = "idioma=pt"

echo
echo "Resultado: $PASS passaram, $FAILN falharam"
[[ $FAILN -eq 0 ]]
