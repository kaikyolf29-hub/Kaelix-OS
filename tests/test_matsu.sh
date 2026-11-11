#!/usr/bin/bash
# Testes do comando matsu, com programas falsos (bootc, lspci, distrobox...)
# para rodar em qualquer máquina, sem mexer no sistema de verdade.
# shellcheck disable=SC2016  # os corpos dos programas falsos ficam em aspas simples de propósito
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MATSU="$ROOT/system_files/usr/bin/matsu"
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
{"spec":{"image":{"image":"ghcr.io/dono/matsu-os:teste","transport":"registry","signature":"insecure"}},
 "status":{"staged":null,
   "booted":{"image":{"image":{"image":"ghcr.io/dono/matsu-os:teste"}}},
   "rollback":{"image":{"image":{"image":"ghcr.io/dono/matsu-os:teste"}}}}}
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
mock busctl 'echo "s \"matsu: resposta da area de trabalho\""; exit "${FAKE_BUSCTL_RC:-0}"'

INFO="$WORK/image-info.json"
echo '{"image-name":"matsu-os","image-variant":"main","image-registry":"ghcr.io/dono","build-id":"20261110.1","fedora-version":"44"}' > "$INFO"

VIDRO="$WORK/share/plasma/desktoptheme/Matsu"
run() { # run <args...>  -> saída em $OUT, código em $CODE
  : > "$CALLS"
  OUT="$(PATH="$MOCK:$PATH" MATSU_IMAGE_INFO="$INFO" MATSU_STATE_DIR="$WORK/state" MATSU_BAR_DIR="$ROOT/system_files/usr/share/matsu/barra" \
         MATSU_VIDRO_GEN="$ROOT/system_files/usr/share/matsu/vidro/gerar.py" MATSU_VIDRO_DIR="$VIDRO" MATSU_VIDRO_PAUSA=0 \
         XDG_CACHE_HOME="$WORK/cache" MATSU_LANG="${L:-pt}" MATSU_YES=1 MATSU_FIRST_DELAY=0 DISPLAY="${GUI:-}" WAYLAND_DISPLAY='' \
         bash "$MATSU" "$@" 2>&1 </dev/null)"
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
check "primeira atualização liga a verificação de assinatura" called "bootc switch --enforce-container-sigpolicy ghcr.io/dono/matsu-os:teste"
check "sem versão nova avisa que já está atualizado" has "já está na versão mais nova"
sed -i 's/"signature":"insecure"/"signature":"containerPolicy"/' "$STATUS_JSON"
run update
check "depois disso usa bootc upgrade" called "bootc upgrade"
check "'update' também funciona" test "$CODE" -eq 0
sed -i 's/"staged":null/"staged":{"image":{"image":{"image":"ghcr.io\/dono\/matsu-os:teste"}}}/' "$STATUS_JSON"
run atualizar --reiniciar
check "versão nova pede para reiniciar" has "entra quando você reiniciar"
check "--reiniciar reinicia" called "systemctl reboot"
run atualizar --errado; check "opção errada falha" test "$CODE" -ne 0

echo "voltar"
run voltar
check "voltar chama bootc rollback" called "bootc rollback"
sed -i 's/"rollback":{"image":{"image":{"image":"ghcr.io\/dono\/matsu-os:teste"}}}/"rollback":null/' "$STATUS_JSON"
run rollback
check "sem versão anterior avisa e falha" has "Não existe versão anterior"
check "sem versão anterior não chama rollback" bash -c "! grep -qF 'bootc rollback' '$CALLS'"

echo "drivers"
run drivers
check "AMD na imagem main está certo" has "já vem no sistema"
mock lspci 'echo "01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA104 [GeForce RTX 3070] [10de:2484]"'
run drivers
check "NVIDIA na imagem main sugere trocar" has "matsu drivers --trocar"
run drivers --trocar
check "--trocar troca para a imagem nvidia no mesmo canal" called "bootc switch --enforce-container-sigpolicy ghcr.io/dono/matsu-os-nvidia:teste"

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
mock busctl 'echo "s \"matsu: resposta da area de trabalho\""; exit "${FAKE_BUSCTL_RC:-0}"'

echo "versao"
run versao
check "mostra a variante e a montagem" bash -c "grep -qF main <<<\"\$0\" && grep -qF 20261110.1 <<<\"\$0\"" "$OUT"

: > "$CALLS"
run versao
check "ver a versão não pede senha" bash -c "! grep -q '^sudo' '$CALLS'"
mock rpm-ostree 'echo "{\"deployments\":[{\"booted\":true,\"container-image-reference\":\"ostree-image-signed:docker://ghcr.io/dono/matsu-os:teste\"}]}"'
run versao
check "mostra a imagem em uso sem o prefixo" bash -c "grep -qF 'ghcr.io/dono/matsu-os:teste' <<<\"\$0\" && ! grep -qF 'ostree-image-signed' <<<\"\$0\"" "$OUT"

echo "barra"
run barra
check "sem escolha mostra o estilo atual" has "Estilo atual da barra: fusao, tamanho media"
check "sem escolha não mexe na barra" bash -c "! grep -q '^busctl' '$CALLS'"
run barra windows
check "troca para o estilo windows pela área de trabalho" called "busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s"
check "manda o arranjo do estilo windows" called 'barra.lengthMode = "fill"'
check "guarda os apps fixados antes de trocar" called "matsuFixados"
check "avisa que trocou" has "Barra trocada"
run barra
check "lembra o estilo escolhido" has "Estilo atual da barra: windows, tamanho media"
run barra --tamanho grande
check "trocar só o tamanho mantém o estilo" called 'barra.lengthMode = "fill"'
check "tamanho grande usa a escala maior" called "var matsuEscala = 3.25;"
run bar mac --size=pequena
check "estilo mac põe a barra no topo" called 'topo.location = "top"'
check "tamanho pequeno usa a escala menor" called "var matsuEscala = 2.25;"
run barra fusao --tamanho media
check "estilo fusão volta com as três ilhas" called 'var direita = ilha(tela, "right");'
check "sem --detalhes não mostra a resposta da área de trabalho" bash -c "! grep -qF 'resposta da area' <<<\"\$0\"" "$OUT"
run barra fusao --detalhes
check "--detalhes mostra a resposta da área de trabalho" has "resposta da area de trabalho"
run barra fusao --esconder sim
check "a barra pode se esconder sozinha" called "var matsuEsconder = true;"
check "lembra que a barra se esconde" grep -qx "esconder=sim" "$WORK/state/barra"
run barra --esconder nao
check "só desligar o esconder também troca a barra" called "var matsuEsconder = false;"
run barra fusao --esconder talvez
check "esconder com valor estranho é recusado" test "$CODE" -ne 0
run barra linux
check "estilo desconhecido é recusado" test "$CODE" -ne 0
run barra --tamanho enorme
check "tamanho desconhecido é recusado" test "$CODE" -ne 0
run barra --busca meio
check "só mudar a busca também troca a barra" called 'var matsuBusca = "meio";'
check "lembra onde fica a busca" grep -qx "busca=meio" "$WORK/state/barra"
run barra --menu meio
check "o menu pode ir para o meio (e a busca continua no meio)" bash -c "grep -qF 'var matsuMenu = \"meio\";' '$CALLS' && grep -qx 'busca=meio' '$WORK/state/barra'"
run barra
check "sem escolha mostra onde ficam a busca e o menu" has "Busca: meio. Menu: meio."
run barra --busca talvez
check "busca com valor estranho é recusada" test "$CODE" -ne 0
run barra fusao --busca esquerda --menu esquerda
check "a busca e o menu voltam para a esquerda" called 'var matsuMenu = "esquerda";'
# A área de trabalho responde à primeira parte (tirar as barras) com os apps
# fixados e as peças antigas, que têm atalho (Meta+A, Alt+F1, Meta+B, Meta+N).
mock busctl 'case "$*" in *matsuAntigos*) echo "s \"matsu-fixado: applications:steam.desktop\\nmatsu-fixado: preferred://browser\\nmatsu-peca-velha: 24\\nmatsu-peca-velha: 31\\n\"" ;; *) echo "s \"matsu: resposta da area de trabalho\"" ;; esac; exit "${FAKE_BUSCTL_RC:-0}"'
run barra mac
check "solta o atalho das peças antigas" bash -c "grep -qF 'unregister ss plasmashell activate widget 24' '$CALLS' && grep -qF 'unregister ss plasmashell activate widget 31' '$CALLS'"
check "solta os atalhos antes de montar a barra nova" bash -c "[ \"\$(grep -n 'unregister' '$CALLS' | head -n1 | cut -d: -f1)\" -lt \"\$(grep -n 'topo.location' '$CALLS' | head -n1 | cut -d: -f1)\" ]"
check "a barra nova recebe os apps que a pessoa fixou" called 'var matsuFixados = ["applications:steam.desktop","preferred://browser"];'
mock busctl 'echo "s \"matsu: resposta da area de trabalho\""; exit "${FAKE_BUSCTL_RC:-0}"'
run barra fusao --tamanho media
FAKE_BUSCTL_RC=1 run barra mac
check "sem área de trabalho avisa e não guarda" bash -c "grep -qF 'Não consegui falar' <<<\"\$0\" && grep -qF 'estilo=fusao' '$WORK/state/barra'" "$OUT"

echo "barra em várias telas"
run barra fusao
check "monta a barra em cada tela" called "montarTela(matsuTela);"
check "por padrão a barra vai em todas as telas" called 'var matsuTelas = "todas";'
check "por padrão o app aberto fica só na barra da tela dele" called 'var matsuAbertos = "tela";'
check "tirar as barras velhas usa as funções comuns" bash -c "grep -n 'function fixadosDasBarras' '$CALLS' | head -n1 | cut -d: -f1 | xargs -I{} test {} -lt \"\$(grep -n 'matsuAntigos\[r\].remove' '$CALLS' | head -n1 | cut -d: -f1)\""
run barra --telas principal
check "a barra pode ficar só na tela principal" called 'var matsuTelas = "principal";'
check "lembra a escolha das telas" grep -qx "telas=principal" "$WORK/state/barra"
run barra --abertos todas
check "o app aberto pode aparecer em todas as barras" called 'var matsuAbertos = "todas";'
check "lembra onde aparecem os apps abertos (e mantém as telas)" bash -c "grep -qx 'abertos=todas' '$WORK/state/barra' && grep -qx 'telas=principal' '$WORK/state/barra'"
run barra
check "sem escolha mostra as telas e os apps abertos" has "Telas: principal. Apps abertos: todas."
run barra --telas talvez
check "telas com valor estranho é recusado" test "$CODE" -ne 0
run barra --abertos talvez
check "apps abertos com valor estranho é recusado" test "$CODE" -ne 0
export MATSU_TELAS_INICIO=0 MATSU_TELAS_ESPERA=0 MATSU_TELAS_TENTATIVAS=3
run barra --telas-novas
check "com a barra só na principal, monitor novo não ganha barra" bash -c "! grep -q '^busctl' '$CALLS'"
run barra fusao --telas todas --abertos tela
cp "$WORK/state/barra" "$WORK/barra-antes"
mock busctl 'echo "s \"matsu-telas: pronto, 1 de 2 telas ganharam a barra agora\n\""'
run barra --telas-novas
check "monitor novo ganha a barra do estilo da pessoa" bash -c "grep -qF 'telaTemBarra' '$CALLS' && grep -qF 'function ilha(tela, alinhamento)' '$CALLS'"
check "monitor novo não tira as barras que já existem" bash -c "! grep -qF '.remove()' '$CALLS'"
check "monitor novo não muda as escolhas guardadas" cmp -s "$WORK/state/barra" "$WORK/barra-antes"
check "uma tentativa basta quando a área de trabalho responde" test "$(grep -c '^busctl' "$CALLS")" -eq 1
mock busctl 'echo "s \"matsu-telas: esperando a barra da tela principal\n\""'
run barra --telas-novas
check "espera a área de trabalho abrir (tenta de novo)" test "$(grep -c '^busctl' "$CALLS")" -eq 3
check "desiste sem erro e avisa" bash -c "test $CODE -eq 0 && grep -qF 'não ficou pronta' <<<\"\$0\"" "$OUT"
unset MATSU_TELAS_INICIO MATSU_TELAS_ESPERA MATSU_TELAS_TENTATIVAS
mock busctl 'echo "s \"matsu: resposta da area de trabalho\""; exit "${FAKE_BUSCTL_RC:-0}"'
# Os roteiros da barra precisam ser JavaScript válido em cada combinação.
if command -v node >/dev/null 2>&1; then
  B="$ROOT/system_files/usr/share/matsu/barra"
  for estilo in fusao mac windows; do
    check "roteiro $estilo + todas as telas é JavaScript válido" bash -c "cat '$B/comum.js' '$B/$estilo.js' '$B/todas-as-telas.js' > '$WORK/r.js' && node --check '$WORK/r.js'"
    check "roteiro $estilo + telas novas é JavaScript válido" bash -c "cat '$B/comum.js' '$B/$estilo.js' '$B/telas-novas.js' > '$WORK/r.js' && node --check '$WORK/r.js'"
  done
  check "roteiro de tirar as barras é JavaScript válido" bash -c "cat '$B/comum.js' '$B/trocar.js' > '$WORK/r.js' && node --check '$WORK/r.js'"
fi

echo "vidro"
mock plasma-apply-desktoptheme 'exit 0'
mock plasma-apply-colorscheme 'exit 0'
mock kreadconfig6 'echo Matsu'
SVG="$VIDRO/translucent/widgets/panel-background.svg"
run vidro
check "sem escolha mostra o vidro atual" has "Vidro atual: cor padrao, transparência normal"
run vidro roxo
check "gera o vidro roxo na pasta da pessoa" grep -qF 'fill="#8b5cf6"' "$SVG"
check "marca o tema como feito pelo Matsu" test -e "$VIDRO/.matsu-vidro"
check "o destaque do sistema fica roxo" called "plasma-apply-colorscheme --accent-color #8b5cf6"
check "o Plasma relê o tema (passa pelo do KDE e volta)" bash -c "grep -n 'plasma-apply-desktoptheme' '$CALLS' | tr '\n' ' ' | grep -qE 'default.*Matsu'"
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
check "no padrão o destaque volta ao cinza neutro do Matsu" called "plasma-apply-colorscheme --accent-color #6e6e76"
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
echo "arquivos do sistema"
# Um link quebrado não dá erro na montagem: o arquivo só some no sistema (foi
# assim que os ícones do tema claro e o Ctrl+Shift+Esc sumiram na troca de nome).
OUT="$(find "$ROOT/system_files" "$ROOT/installer" -xtype l 2>/dev/null)"
check "nenhum link quebrado nos arquivos do sistema" test -z "$OUT"
# (O endereço do repositório no GitHub ainda é Kaelix-OS até o criador renomear.)
OUT="$(grep -rIn -i 'kaelix' "$ROOT/system_files" 2>/dev/null | grep -v 'github.com/kaikyolf29-hub/Kaelix-OS'; find "$ROOT/system_files" -iname '*kaelix*' 2>/dev/null)"
check "nenhum arquivo do sistema com o nome antigo (Kaelix)" test -z "$OUT"

echo
echo "prompt do terminal"
# O prompt mostra a pasta, o ramo (com * quando mudou) e a setinha, que fica
# vermelha depois de um erro. Um ramo com nome de comando nunca é executado.
PR="$WORK/prompt"; mkdir -p "$PR/repo"
git -C "$PR/repo" init -q -b main
git -C "$PR/repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m x
git -C "$PR/repo" checkout -q -b 'x$(touch${IFS}pegou)'
prompt_de() { # prompt_de <comandos antes> -> o prompt como o bash mostraria
  ( cd "$PR/repo" && env -i HOME="$PR" PATH="$PATH" TERM=xterm-256color bash --norc --noprofile -c '
      PS1="x"; id() { echo 1000; }
      . "$1"; eval "$2"; eval "$PROMPT_COMMAND"; printf "%s" "${PS1@P}"' _ "$ROOT/system_files/etc/profile.d/zz-matsu-prompt.sh" "$1" )
}
OUT="$(prompt_de true)"
check "o prompt mostra a pasta e o ramo" grep -q 'repo.*x\$(touch' <<< "$OUT"
check "um ramo com nome de comando não roda" test ! -e "$PR/repo/pegou"
check "a setinha fica verde depois de dar certo" grep -q $'\e\[1;32m' <<< "$OUT"
OUT="$(prompt_de false)"
check "a setinha fica vermelha depois de um erro" grep -q $'\e\[1;31m' <<< "$OUT"
OUT="$(prompt_de 'echo oi > a; git add a')"
check "o ramo ganha * quando tem mudança" grep -q 'touch.*\*' <<< "$OUT"
check "o prompt passa no dash (o /etc/profile também roda nele)" dash -n "$ROOT/system_files/etc/profile.d/zz-matsu-prompt.sh"

echo
echo "atalhos Meta+A (central) e Meta+B (bandeja)"
# No login: o "percorrer as atividades" e o "trocar perfil de energia" do KDE
# ficam sem essas teclas no arquivo de atalhos da pessoa. O kwriteconfig6 é
# falso e anota o que gravaria. No arquivo, várias teclas ficam separadas por
# "\t" escrito com barra, como o KDE grava.
AT="$WORK/atalhos"; mkdir -p "$AT/bin" "$AT/home/.config"
KGS="$AT/home/.config/kglobalshortcutsrc"
printf '#!/usr/bin/bash\nprintf "%%s|" "$@" >> "%s"; echo >> "%s"\n' "$AT/grava.log" "$AT/grava.log" > "$AT/bin/kwriteconfig6"
chmod +x "$AT/bin/kwriteconfig6"
login_atalhos() { # login_atalhos <conteúdo do arquivo ou "-" para conta nova> -> o que foi gravado em $OUT
  rm -f "$KGS" "$AT/grava.log"; touch "$AT/grava.log"
  [[ $1 == - ]] || printf '%s\n' "$1" > "$KGS"
  env -i HOME="$AT/home" PATH="$AT/bin:$PATH" dash "$ROOT/system_files/etc/xdg/plasma-workspace/env/matsu-atalhos.sh"
  OUT="$(cat "$AT/grava.log")"
}
login_atalhos -
check "conta nova: atividades nascem sem tecla" grep -qF 'plasmashell|--key|next activity|none,none,' <<<"$OUT"
check "conta nova: perfil de energia fica só na tecla Battery" grep -qF $'powerProfile|Battery,Battery\tMeta+B,' <<<"$OUT"
login_atalhos $'[plasmashell]\nnext activity=Meta+A,Meta+A,x\n[org_kde_powerdevil]\npowerProfile=Battery\\tMeta+B,Battery\\tMeta+B,y'
check "o KDE pegou as duas teclas: as duas saem" test "$(grep -c . <<<"$OUT")" -eq 2
login_atalhos $'[plasmashell]\nnext activity=none,Meta+A,x\n[org_kde_powerdevil]\npowerProfile=Battery,Battery\\tMeta+B,y'
check "já sem as teclas: não grava nada" test -z "$OUT"
login_atalhos $'[plasmashell]\nnext activity=Meta+Alt+N,Meta+A,x\n[org_kde_powerdevil]\npowerProfile=Meta+Shift+B,Battery\\tMeta+B,y'
check "uma tecla que a pessoa escolheu (Meta+Alt+N) fica" test -z "$OUT"
login_atalhos $'[plasmashell]\nnext activity=Ctrl+F1\\tMeta+A,Meta+A,x\n[org_kde_powerdevil]\npowerProfile=Battery,Battery\\tMeta+B,y'
check "Meta+A como segunda tecla também sai" grep -qF 'next activity|none,none,' <<<"$OUT"
check "o script do login passa no dash" dash -n "$ROOT/system_files/etc/xdg/plasma-workspace/env/matsu-atalhos.sh"

# A garantia do começo da sessão: pergunta ao serviço de atalhos (busctl falso)
# e só solta a tecla de quem estiver com ela; depois a peça da barra pede de novo.
cat > "$AT/bin/busctl" <<EOF
#!/usr/bin/bash
echo "\$*" >> "$AT/busctl.log"
case "\$*" in
  *" shortcut as 4 plasmashell next activity "*) echo "ai \${FAKE_ATIV:-0}" ;;
  *" shortcut as 4 org_kde_powerdevil powerProfile "*) echo "ai \${FAKE_ENERGIA:-0}" ;;
  *setForeignShortcut*) echo ;;
  *evaluateScript*) echo 's ""' ;;
esac
exit "\${FAKE_BUSCTL_RC:-0}"
EOF
chmod +x "$AT/bin/busctl"
ajudante() { # ajudante <variáveis...> -> chamadas em $OUT
  : > "$AT/busctl.log"
  env "$@" MATSU_ATALHOS_UMA_VEZ=1 PATH="$AT/bin:$PATH" bash "$ROOT/system_files/usr/libexec/matsu/matsu-atalhos" >/dev/null 2>&1
  CODE=$?
  OUT="$(cat "$AT/busctl.log")"
}
ajudante FAKE_ATIV="2 268435521 268435534" FAKE_ENERGIA="1 268435522"
check "solta o Meta+A das atividades" grep -qF 'setForeignShortcut asai 4 plasmashell next activity   0' <<<"$OUT"
check "solta o Meta+B do perfil de energia" grep -qF 'setForeignShortcut asai 4 org_kde_powerdevil powerProfile   0' <<<"$OUT"
check "a central e a bandeja pedem a tecla de novo" grep -qF 'var soltas = ["Meta+A","Meta+B"]' <<<"$OUT"
ajudante FAKE_ATIV="1 268435534" FAKE_ENERGIA="0"
check "sem a tecla, não mexe em nada" bash -c '! grep -q -e setForeignShortcut -e evaluateScript <<<"$1"' _ "$OUT"
check "nunca usa a chamada que derruba o KWin" bash -c '! grep -rq -e setForeignShortcutKeys -e actionList "$1"' _ "$ROOT/system_files/usr/libexec/matsu/matsu-atalhos"
ajudante FAKE_BUSCTL_RC=1
check "sem o serviço de atalhos, sai sem erro" test "$CODE" -eq 0
check "a garantia roda no começo de cada sessão do KDE" grep -qx 'Exec=/usr/libexec/matsu/matsu-atalhos' "$ROOT/system_files/etc/xdg/autostart/matsu-atalhos.desktop"

echo
echo "apps fixados na barra"
# Atalhos de apps de mentira: um da pessoa (vale mais), um escondido e um só do GNOME.
APPS="$WORK/apps"; mkdir -p "$APPS/sistema" "$APPS/pessoa"
app_falso() { # app_falso <pasta> <arquivo> <linhas...>
  local pasta="$1" arq="$2"; shift 2
  { echo "[Desktop Entry]"; echo "Type=Application"; printf '%s\n' "$@"; echo "[Desktop Action nova]"; echo "Name=Nova janela"; } > "$APPS/$pasta/$arq"
}
app_falso sistema steam.desktop "Name=Steam" "Icon=steam"
app_falso pessoa steam.desktop "Name=Steam da pessoa" "Icon=steam"
app_falso sistema org.kde.kate.desktop "Name=Kate" "Icon=kate"
app_falso sistema firefox.desktop "Name=Firefox" "Name[pt_BR]=Navegador Firefox" "Icon=firefox"
app_falso sistema org.kde.dolphin.desktop "Name=Dolphin" "Icon=system-file-manager"
app_falso sistema escondido.desktop "Name=Escondido" "NoDisplay=true"
app_falso sistema gnome-only.desktop "Name=SoGnome" "OnlyShowIn=GNOME;"
export MATSU_APPS_DIRS="$APPS/pessoa:$APPS/sistema"
# A área de trabalho falsa responde com os apps de FAKE_FIXADOS (ou "sem-barra").
cat > "$MOCK/busctl" <<EOF
#!/usr/bin/bash
echo "busctl \$*" >> "$CALLS"
if [[ \${FAKE_RESPOSTA:-} == sem-barra ]]; then echo 's "matsu-fixados: sem-barra\\n"'; exit 0; fi
r=""
for a in \${FAKE_FIXADOS:-}; do r+="matsu-fixado: \$a\\\\n"; done
echo "s \"\${r}matsu-fixados: pronto\\\\n\""
EOF
chmod +x "$MOCK/busctl"
mock xdg-settings 'case "$1" in get) echo "${FAKE_NAVEGADOR:-}" ;; esac; exit 0'
export FAKE_FIXADOS="preferred://browser applications:steam.desktop" FAKE_NAVEGADOR=firefox.desktop
run barra apps
check "lista os apps fixados com o nome de verdade" has "Navegador Firefox (navegador padrão)"
check "o atalho da pessoa vale mais que o do sistema" has "Steam da pessoa"
check "lê os fixados pela área de trabalho" called 'var matsuAcao = "ler";'
run barra apps --lista
check "lista para os Ajustes: fixado|app|nome|ícone|atalho" has "fixado|preferred://browser|Navegador Firefox|firefox|firefox.desktop"
run barra fixar kate
check "fixar acha o app pelo fim do nome do arquivo" called 'var matsuApps = ["applications:org.kde.kate.desktop"];'
check "fixar avisa que o app está na barra" has "Kate está na barra"
run barra fixar "navegador firefox"
check "fixar acha o app pelo nome traduzido" called 'var matsuApps = ["applications:firefox.desktop"];'
run barra fixar sognome
check "não fixa app que não aparece no KDE" bash -c '[[ $1 != 0 ]] && grep -q "Não achei o app" <<<"$2"' _ "$CODE" "$OUT"
run barra fixar naoexiste
check "app que não existe dá erro claro" bash -c '[[ $1 != 0 ]] && grep -q "Não achei o app \"naoexiste\"" <<<"$2"' _ "$CODE" "$OUT"
run barra tirar firefox
check "tirar o navegador padrão pelo nome dele" called 'var matsuApps = ["preferred://browser"];'
check "tirar manda a ação certa" called 'var matsuAcao = "tirar";'
run barra tirar kate
check "tirar um app que não está fixado avisa" bash -c '[[ $1 != 0 ]] && grep -q "não está fixado" <<<"$2"' _ "$CODE" "$OUT"
run barra ordem steam,navegador
check "ordem manda a lista na ordem pedida" called 'var matsuApps = ["applications:steam.desktop","preferred://browser"];'
run barra ordem steam navegador
check "ordem também aceita os apps separados por espaço" called 'var matsuApps = ["applications:steam.desktop","preferred://browser"];'
run barra apps --instalados
check "lista de apps para escolher com nome e ícone" has "app|applications:firefox.desktop|Navegador Firefox|firefox"
check "a lista não mostra app escondido nem só do GNOME" bash -c '! grep -q -e escondido -e gnome-only <<<"$1"' _ "$OUT"
check "a lista vem em ordem de nome" test "$(cut -d'|' -f3 <<<"$OUT" | tr '\n' ',')" = "Dolphin,Kate,Navegador Firefox,Steam da pessoa,"
FAKE_RESPOSTA=sem-barra run barra apps
check "sem lugar para apps na barra, explica" has "não tem lugar para apps fixados"
run barra apps --padrao
check "voltar aos apps do começo" called 'var matsuAcao = "padrao";'
# Os Ajustes e o menu pedem pelo matsu-central, na língua da pessoa.
cat > "$WORK/matsu-falso" <<EOF
#!/usr/bin/bash
echo "MATSU_LANG=\$MATSU_LANG \$*" >> "$WORK/matsu-falso.log"
EOF
chmod +x "$WORK/matsu-falso"
: > "$WORK/matsu-falso.log"
env -i HOME="$WORK" PATH="$PATH" LANGUAGE=pt_BR MATSU_BIN="$WORK/matsu-falso" bash "$ROOT/system_files/usr/libexec/matsu/matsu-central" apps-barra
env -i HOME="$WORK" PATH="$PATH" LANGUAGE=pt_BR MATSU_BIN="$WORK/matsu-falso" bash "$ROOT/system_files/usr/libexec/matsu/matsu-central" fixar "applications:org.kde.kate.desktop"
env -i HOME="$WORK" PATH="$PATH" LANGUAGE=pt_BR MATSU_BIN="$WORK/matsu-falso" bash "$ROOT/system_files/usr/libexec/matsu/matsu-central" ordem "preferred://browser,applications:steam.desktop"
OUT="$(cat "$WORK/matsu-falso.log")"
check "a central pede os fixados em português" has "MATSU_LANG=pt barra apps --lista"
check "a central fixa o app que o menu mandou" has "barra fixar applications:org.kde.kate.desktop"
check "a central manda a ordem nova" has "barra ordem preferred://browser,applications:steam.desktop"
unset MATSU_APPS_DIRS FAKE_FIXADOS FAKE_NAVEGADOR
mock busctl 'echo "s \"matsu: resposta da area de trabalho\""; exit "${FAKE_BUSCTL_RC:-0}"'
mock xdg-settings 'exit 0'

echo
echo "Resultado: $PASS passaram, $FAILN falharam"
[[ $FAILN -eq 0 ]]
