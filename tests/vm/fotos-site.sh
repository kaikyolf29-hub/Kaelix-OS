#!/usr/bin/bash
# Só na máquina virtual de teste: as fotos do site do Matsu (site-*). Fecha as
# janelas que sobraram dos outros testes e abre um app por vez, sozinho na tela,
# para a VM tirar a foto perto do fim de cada vez. O visual/site/preparar-fotos.py
# transforma essas prints nas fotos do site.
#
# Uso: matsu-fotos-site            faz a sequência
#      matsu-fotos-site --lista    "nome segundos" de cada vez (o run-vm.sh usa)
VEZES=(
  "site-01-menu 14"
  "site-02-escuro 10"
  "site-03-claro 16"
  "site-10-jogos 14"
  "site-11-loja 30"
  "site-12-arquivos 14"
  "site-13-terminal 12"
  "site-14-tarefas 14"
  "site-15-ajustes 16"
)
# Fecha toda janela comum (o que sobrou dos testes de antes) por um roteiro do
# KWin. Pelo gdbus, que sempre vem no sistema (o qdbus do Qt 6 não vem).
fechar_tudo() {
  local roteiro nome="matsu-fotos-$RANDOM"
  roteiro="$(mktemp --suffix=.js)"
  echo 'for (const w of workspace.windowList()) { if (w.normalWindow && w.closeable) w.closeWindow(); }' >"$roteiro"
  gdbus call --session --dest org.kde.KWin --object-path /Scripting \
    --method org.kde.kwin.Scripting.loadScript "$roteiro" "$nome" >/dev/null
  gdbus call --session --dest org.kde.KWin --object-path /Scripting --method org.kde.kwin.Scripting.start >/dev/null
  sleep 1
  gdbus call --session --dest org.kde.KWin --object-path /Scripting \
    --method org.kde.kwin.Scripting.unloadScript "$nome" >/dev/null
  rm -f "$roteiro"
}

if [[ ${1:-} == --lista ]]; then
  printf '%s\n' "${VEZES[@]}"
  exit 0
fi
# Só fecha as janelas (o run-vm.sh usa antes da Loja, que precisa da tela limpa).
if [[ ${1:-} == --fechar ]]; then
  fechar_tudo
  exit 0
fi
REGISTRO=/tmp/matsu-fotos-site.log
exec >"$REGISTRO" 2>&1 </dev/null

abrir() { setsid -f "$@" >/dev/null 2>&1 </dev/null; }

# Cada vez começa na hora marcada (a soma das de antes, mais 2 segundos cada),
# para o run-vm.sh acertar a foto mesmo quando trocar o tema demora.
inicio=$(date +%s)
comeco=0
echo "início: $(date +%T)"
for vez in "${VEZES[@]}"; do
  nome="${vez%% *}"; segundos="${vez##* }"
  agora=$(date +%s)
  if (( inicio + comeco > agora )); then sleep $((inicio + comeco - agora)); fi
  fechar_tudo
  echo "$(date +%T) $nome"
  case $nome in
    site-01-menu) ;;  # o run-vm.sh abre o menu com a tecla Meta
    site-02-escuro) ;;
    site-03-claro) plasma-apply-lookandfeel -a org.matsu.claro.desktop ;;
    site-10-jogos)
      plasma-apply-lookandfeel -a org.matsu.escuro.desktop
      abrir /usr/libexec/matsu/matsu-janela org.matsu.jogos /usr/share/matsu/jogos/Main.qml ;;
    site-11-loja) abrir /usr/libexec/matsu/matsu-janela org.matsu.loja /usr/share/matsu/loja/Main.qml ;;
    site-12-arquivos) abrir matsu-arquivos "$HOME" ;;
    site-13-terminal) abrir matsu-terminal ;;
    site-14-tarefas) abrir /usr/libexec/matsu/matsu-janela org.matsu.tarefas /usr/share/matsu/tarefas/Main.qml ;;
    site-15-ajustes) abrir plasmawindowed org.matsu.ajustes ;;
  esac
  comeco=$((comeco + segundos + 2))
done
agora=$(date +%s)
if (( inicio + comeco > agora )); then sleep $((inicio + comeco - agora)); fi
fechar_tudo
echo "fim: $(date +%T)"
