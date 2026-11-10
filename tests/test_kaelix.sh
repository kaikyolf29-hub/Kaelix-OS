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

INFO="$WORK/image-info.json"
echo '{"image-name":"kaelix-os","image-variant":"main","image-registry":"ghcr.io/dono","build-id":"20261110.1","fedora-version":"44"}' > "$INFO"

run() { # run <args...>  -> saída em $OUT, código em $CODE
  : > "$CALLS"
  OUT="$(PATH="$MOCK:$PATH" KAELIX_IMAGE_INFO="$INFO" KAELIX_STATE_DIR="$WORK/state" \
         KAELIX_LANG="${L:-pt}" KAELIX_YES=1 DISPLAY='' WAYLAND_DISPLAY='' \
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
run navegador --primeira-vez
check "primeira vez não pergunta de novo depois de escolher" bash -c "! grep -qF 'flatpak install' '$CALLS'"
rm -rf "$WORK/state"
run browser both
check "os dois instala Chrome e Brave" bash -c "grep -qF com.google.Chrome '$CALLS' && grep -qF com.brave.Browser '$CALLS'"

echo "versao"
run versao
check "mostra a variante e a montagem" bash -c "grep -qF main <<<\"\$0\" && grep -qF 20261110.1 <<<\"\$0\"" "$OUT"

echo
echo "Resultado: $PASS passaram, $FAILN falharam"
[[ $FAILN -eq 0 ]]
