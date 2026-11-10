#!/usr/bin/bash
# Testes do comando kaelix, com programas falsos (bootc, lspci, distrobox...)
# para rodar em qualquer máquina, sem mexer no sistema de verdade.
# shellcheck disable=SC2016  # os corpos dos programas falsos ficam em aspas simples de propósito
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KAELIX="$ROOT/system_files/usr/bin/kaelix"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
MOCK="$WORK/bin"; mkdir -p "$MOCK"
CALLS="$WORK/calls.log"
PASS=0; FAILN=0

mock() { # mock <nome> <corpo>
  printf '#!/usr/bin/bash\necho "%s $*" >> "%s"\n%s\n' "$1" "$CALLS" "$2" > "$MOCK/$1"
  chmod +x "$MOCK/$1"
}

STATUS_JSON="$WORK/status.json"
cat > "$STATUS_JSON" <<'EOF'
{"spec":{"image":{"image":"ghcr.io/dono/kaelix-os:teste","transport":"registry","signature":"insecure"}},
 "status":{"staged":null,
   "booted":{"image":{"image":{"image":"ghcr.io/dono/kaelix-os:teste"}}},
   "rollback":{"image":{"image":{"image":"ghcr.io/dono/kaelix-os:teste"}}}}}
EOF

mock sudo 'exec "$@"'
mock bootc 'case "$1" in status) cat "'"$STATUS_JSON"'" ;; *) exit 0 ;; esac'
mock flatpak 'exit 0'
mock systemctl 'exit 0'
mock lspci 'echo "01:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Ellesmere [Radeon RX 470/480/570/580] [1002:67df]"'
mock distrobox 'case "$1" in list) printf "ID | NAME | STATUS | IMAGE\nabc | ${FAKE_BOX:-nada} | Up | x\n" ;; *) exit 0 ;; esac'
mock kdialog 'exit 0'
mock pgrep 'exit 1'
mock xdg-settings 'exit 0'
mock kwriteconfig6 'exit 0'
mock busctl 'echo "s \"kaelix: resposta da area de trabalho\""; exit "${FAKE_BUSCTL_RC:-0}"'

INFO="$WORK/image-info.json"
echo '{"image-name":"kaelix-os","image-variant":"main","image-registry":"ghcr.io/dono","build-id":"20261110.1","fedora-version":"44"}' > "$INFO"

VIDRO="$WORK/share/plasma/desktoptheme/Kaelix"
run() { # run <args...>  -> saída em $OUT, código em $CODE
  : > "$CALLS"
  OUT="$(PATH="$MOCK:$PATH" KAELIX_IMAGE_INFO="$INFO" KAELIX_STATE_DIR="$WORK/state" KAELIX_BAR_DIR="$ROOT/system_files/usr/share/kaelix/barra" \
         KAELIX_VIDRO_GEN="$ROOT/system_files/usr/share/kaelix/vidro/gerar.py" KAELIX_VIDRO_DIR="$VIDRO" KAELIX_VIDRO_PAUSA=0 \
         XDG_CACHE_HOME="$WORK/cache" KAELIX_LANG="${L:-pt}" KAELIX_YES=1 KAELIX_FIRST_DELAY=0 DISPLAY="${GUI:-}" WAYLAND_DISPLAY='' \
         bash "$KAELIX" "$@" 2>&1 </dev/null)"
  CODE=$?
}

check() { # check <descrição> <condição...>
  local desc="$1"; shift
  if "$@"; then PASS=$((PASS+1)); echo "  ok   $desc"
  else FAILN=$((FAILN+1)); echo "  FAIL $desc"; printf '       | %s\n' "${OUT//$'\n'/$'\n'       | }"; fi
}
has()    { grep -qF -- "$1" <<<"$OUT"; }
called() { grep -qF -- "$1" "$CALLS"; }

echo "ajuda"
run ajuda;  check "ajuda em português" has "Baixa e prepara"
L=en run help; check "help in English" has "Downloads and stages"
run comando-que-nao-existe; check "comando desconhecido sai com código 2" test "$CODE" -eq 2

echo "atualizar"
run atualizar
check "primeira atualização liga a verificação de assinatura" called "bootc switch --enforce-container-sigpolicy ghcr.io/dono/kaelix-os:teste"
check "sem versão nova avisa que já está atualizado" has "já está na versão mais nova"
sed -i 's/"signature":"insecure"/"signature":"containerPolicy"/' "$STATUS_JSON"
run update
check "depois disso usa bootc upgrade" called "bootc upgrade"
check "'update' também funciona" test "$CODE" -eq 0
sed -i 's/"staged":null/"staged":{"image":{"image":{"image":"ghcr.io\/dono\/kaelix-os:teste"}}}/' "$STATUS_JSON"
run atualizar --reiniciar
check "versão nova pede para reiniciar" has "entra quando você reiniciar"
check "--reiniciar reinicia" called "systemctl reboot"
run atualizar --errado; check "opção errada falha" test "$CODE" -ne 0

echo "voltar"
run voltar
check "voltar chama bootc rollback" called "bootc rollback"
sed -i 's/"rollback":{"image":{"image":{"image":"ghcr.io\/dono\/kaelix-os:teste"}}}/"rollback":null/' "$STATUS_JSON"
run rollback
check "sem versão anterior avisa e falha" has "Não existe versão anterior"
check "sem versão anterior não chama rollback" bash -c "! grep -qF 'bootc rollback' '$CALLS'"

echo "drivers"
run drivers
check "AMD na imagem main está certo" has "já vem no sistema"
mock lspci 'echo "01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA104 [GeForce RTX 3070] [10de:2484]"'
run drivers
check "NVIDIA na imagem main sugere trocar" has "kaelix drivers --trocar"
run drivers --trocar
check "--trocar troca para a imagem nvidia no mesmo canal" called "bootc switch --enforce-container-sigpolicy ghcr.io/dono/kaelix-os-nvidia:teste"

echo "seguranca"
run seguranca
check "cria o contêiner do Kali quando não existe" called "distrobox create --yes --name kali"
check "entra no contêiner" called "distrobox enter kali"
FAKE_BOX=kali run security
check "não recria quando já existe" bash -c "! grep -qF 'distrobox create' '$CALLS'"
FAKE_BOX=kali run seguranca remover
check "remover apaga o contêiner" called "distrobox rm --force kali"

echo "navegador"
run navegador brave
check "instala o Brave pelo Flathub" called "flatpak install --user -y --noninteractive flathub com.brave.Browser"
check "o Brave vira o navegador padrão (e vai para a barra)" called "xdg-settings set default-web-browser com.brave.Browser.desktop"
check "avisa que tomou o lugar do Firefox" has "no lugar do Firefox"
rm -rf "$WORK/state"
GUI=:0 run navegador brave
check "com a área de trabalho aberta, a barra troca o ícone na hora" bash -c "grep -qzP 'busctl[^\\n]*evaluateScript[\\s\\S]*preferred://browser' '$CALLS'"
run navegador --primeira-vez
check "primeira vez não pergunta de novo depois de escolher" bash -c "! grep -qF 'flatpak install' '$CALLS'"
rm -rf "$WORK/state"
run browser both
check "os dois instala Chrome e Brave" bash -c "grep -qF com.google.Chrome '$CALLS' && grep -qF com.brave.Browser '$CALLS'"
check "com os dois, o Chrome fica como padrão" called "xdg-settings set default-web-browser com.google.Chrome.desktop"
rm -rf "$WORK/state"
mock flatpak 'case "$1" in install) exit 1 ;; *) exit 0 ;; esac'
run navegador chrome
check "se a instalação falha, não mexe no navegador padrão" bash -c "[ '$CODE' -ne 0 ] && ! grep -q xdg-settings '$CALLS'"
mock flatpak 'exit 0'
rm -rf "$WORK/state"
mock xdg-settings 'exit 1'
mock xdg-mime 'exit 0'
run navegador brave
check "sem xdg-settings, usa o xdg-mime" called "xdg-mime default com.brave.Browser.desktop x-scheme-handler/http x-scheme-handler/https text/html"
mock xdg-settings 'exit 0'

echo "navegador no primeiro login"
rm -rf "$WORK/state"
run navegador --primeira-vez
check "sem área de trabalho, não marca como escolhido" bash -c "[ ! -e '$WORK/state/navegador-escolhido' ]"
mock kdialog 'exit 2'
GUI=:0 run navegador --primeira-vez
check "se a janela não abre, tenta de novo no próximo login" bash -c "[ ! -e '$WORK/state/navegador-escolhido' ] && ! grep -qF 'flatpak install' '$CALLS'"
mock kdialog 'echo "\"chrome\""'
GUI=:0 run navegador --primeira-vez
check "com a janela, instala o que foi escolhido" bash -c "grep -qF com.google.Chrome '$CALLS' && [ -e '$WORK/state/navegador-escolhido' ]"
mock pgrep 'exit 0'
rm -rf "$WORK/state"
: > "$CALLS"
GUI=:0 run navegador --primeira-vez
check "com a tela de boas-vindas aberta, não abre a janela nem marca" bash -c "[ ! -e '$WORK/state/navegador-escolhido' ] && ! grep -q '^kdialog' '$CALLS'"
mock pgrep 'exit 1'
mock kdialog 'exit 1'
rm -rf "$WORK/state"
GUI=:0 run navegador --primeira-vez
check "cancelar não pergunta de novo" bash -c "[ -e '$WORK/state/navegador-escolhido' ] && ! grep -qF 'flatpak install' '$CALLS'"
mock kdialog 'exit 0'
mock busctl 'echo "s \"kaelix: resposta da area de trabalho\""; exit "${FAKE_BUSCTL_RC:-0}"'

echo "versao"
run versao
check "mostra a variante e a montagem" bash -c "grep -qF main <<<\"\$0\" && grep -qF 20261110.1 <<<\"\$0\"" "$OUT"

: > "$CALLS"
run versao
check "ver a versão não pede senha" bash -c "! grep -q '^sudo' '$CALLS'"
mock rpm-ostree 'echo "{\"deployments\":[{\"booted\":true,\"container-image-reference\":\"ostree-image-signed:docker://ghcr.io/dono/kaelix-os:teste\"}]}"'
run versao
check "mostra a imagem em uso sem o prefixo" bash -c "grep -qF 'ghcr.io/dono/kaelix-os:teste' <<<\"\$0\" && ! grep -qF 'ostree-image-signed' <<<\"\$0\"" "$OUT"

echo "barra"
run barra
check "sem escolha mostra o estilo atual" has "Estilo atual da barra: fusao, tamanho media"
check "sem escolha não mexe na barra" bash -c "! grep -q '^busctl' '$CALLS'"
run barra windows
check "troca para o estilo windows pela área de trabalho" called "busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s"
check "manda o arranjo do estilo windows" called 'barra.lengthMode = "fill"'
check "guarda os apps fixados antes de trocar" called "kaelixFixados"
check "avisa que trocou" has "Barra trocada"
run barra
check "lembra o estilo escolhido" has "Estilo atual da barra: windows, tamanho media"
run barra --tamanho grande
check "trocar só o tamanho mantém o estilo" called 'barra.lengthMode = "fill"'
check "tamanho grande usa a escala maior" called "var kaelixEscala = 3.25;"
run bar mac --size=pequena
check "estilo mac põe a barra no topo" called 'topo.location = "top"'
check "tamanho pequeno usa a escala menor" called "var kaelixEscala = 2.25;"
run barra fusao --tamanho media
check "estilo fusão volta com as três ilhas" called 'var direita = ilha("right");'
check "sem --detalhes não mostra a resposta da área de trabalho" bash -c "! grep -qF 'resposta da area' <<<\"\$0\"" "$OUT"
run barra fusao --detalhes
check "--detalhes mostra a resposta da área de trabalho" has "resposta da area de trabalho"
run barra linux
check "estilo desconhecido é recusado" test "$CODE" -ne 0
run barra --tamanho enorme
check "tamanho desconhecido é recusado" test "$CODE" -ne 0
# A área de trabalho responde à primeira parte (tirar as barras) com os apps
# fixados e as peças antigas, que têm atalho (Meta+A, Alt+F1, Meta+B, Meta+N).
mock busctl 'case "$*" in *kaelixAntigos*) echo "s \"kaelix-fixado: applications:steam.desktop\\nkaelix-fixado: preferred://browser\\nkaelix-peca-velha: 24\\nkaelix-peca-velha: 31\\n\"" ;; *) echo "s \"kaelix: resposta da area de trabalho\"" ;; esac; exit "${FAKE_BUSCTL_RC:-0}"'
run barra mac
check "solta o atalho das peças antigas" bash -c "grep -qF 'unregister ss plasmashell activate widget 24' '$CALLS' && grep -qF 'unregister ss plasmashell activate widget 31' '$CALLS'"
check "solta os atalhos antes de montar a barra nova" bash -c "[ \"\$(grep -n 'unregister' '$CALLS' | head -n1 | cut -d: -f1)\" -lt \"\$(grep -n 'topo.location' '$CALLS' | head -n1 | cut -d: -f1)\" ]"
check "a barra nova recebe os apps que a pessoa fixou" called 'var kaelixFixados = ["applications:steam.desktop","preferred://browser"];'
mock busctl 'echo "s \"kaelix: resposta da area de trabalho\""; exit "${FAKE_BUSCTL_RC:-0}"'
run barra fusao --tamanho media
FAKE_BUSCTL_RC=1 run barra mac
check "sem área de trabalho avisa e não guarda" bash -c "grep -qF 'Não consegui falar' <<<\"\$0\" && grep -qF 'estilo=fusao' '$WORK/state/barra'" "$OUT"

echo "vidro"
mock plasma-apply-desktoptheme 'exit 0'
mock plasma-apply-colorscheme 'exit 0'
mock kreadconfig6 'echo Kaelix'
SVG="$VIDRO/translucent/widgets/panel-background.svg"
run vidro
check "sem escolha mostra o vidro atual" has "Vidro atual: cor padrao, transparência normal"
run vidro roxo
check "gera o vidro roxo na pasta da pessoa" grep -qF 'fill="#8b5cf6"' "$SVG"
check "marca o tema como feito pelo Kaelix" test -e "$VIDRO/.kaelix-vidro"
check "o destaque do sistema fica roxo" called "plasma-apply-colorscheme --accent-color #8b5cf6"
check "o Plasma relê o tema (passa pelo do KDE e volta)" bash -c "grep -n 'plasma-apply-desktoptheme' '$CALLS' | tr '\n' ' ' | grep -qE 'default.*Kaelix'"
check "a transparência continua a normal (cobre 62%)" grep -qF 'opacity="0.5"' "$SVG"
run vidro
check "lembra a cor escolhida" has "Vidro atual: cor roxo, transparência normal"
run vidro --transparencia mais
check "trocar só a transparência mantém a cor" grep -qF 'fill="#8b5cf6"' "$SVG"
check "mais transparente cobre menos" grep -qF 'opacity="0.237"' "$SVG"
L=en run glass blue --transparency=less
check "em inglês também (blue, less)" bash -c "grep -qF 'fill=\"#2f80ed\"' '$SVG' && grep -qF 'transparencia=menos' '$WORK/state/vidro' && grep -qF 'cor=azul' '$WORK/state/vidro'"
run vidro '#FF8800'
check "aceita cor em #rrggbb" grep -qF 'fill="#ff8800"' "$SVG"
run vidro padrao --transparencia normal
check "no padrão apaga o tema da pessoa (vale o do sistema)" test ! -e "$VIDRO"
check "no padrão o destaque volta ao anil do Kaelix" called "plasma-apply-colorscheme --accent-color #5468e8"
run vidro padrao --transparencia mais
check "padrão mais transparente gera o vidro sem cor" bash -c "grep -qF 'opacity=\"0.42\"' '$SVG' && ! grep -qE 'fill=\"#[0-9a-f]{6}\" opacity=\"0.24\"' '$SVG'"
run vidro magenta
check "cor desconhecida é recusada" test "$CODE" -ne 0
run vidro azul --transparencia total
check "transparência desconhecida é recusada" test "$CODE" -ne 0
run vidro padrao --transparencia normal
mkdir -p "$VIDRO" && echo meu > "$VIDRO/metadata.json"
run vidro verde
check "não apaga um tema que a pessoa fez" bash -c "grep -qF 'Não vou mexer' <<<\"\$0\" && grep -qF meu '$VIDRO/metadata.json'" "$OUT"
rm -rf "$VIDRO"

echo
echo "Resultado: $PASS passaram, $FAILN falharam"
[[ $FAILN -eq 0 ]]
