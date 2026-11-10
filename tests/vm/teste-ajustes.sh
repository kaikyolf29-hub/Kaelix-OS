#!/usr/bin/bash
# Teste da máquina virtual: abre os Ajustes do Kaelix e passa pelas páginas, uma
# a cada 8 segundos (o run-vm.sh tira os prints no mesmo ritmo). No fim deixa o
# vidro roxo e mais transparente por um tempo e volta ao padrão.
C=/usr/libexec/kaelix/kaelix-central
# Para o registro: o idioma que o terminal tem e o que os Ajustes recebem.
echo "terminal: LANG=${LANG:-} LC_ALL=${LC_ALL:-} LC_MESSAGES=${LC_MESSAGES:-} LC_NUMERIC=${LC_NUMERIC:-} LANGUAGE=${LANGUAGE:-}"
"$C" estado | grep '^idioma='
for pagina in aparencia barra papel telas sobre; do
  "$C" abrir ajustes "$pagina"
  sleep 8
done
pid="$(pgrep -f 'plasmawindowed org.kaelix.ajustes' | head -n1)"
[[ -n $pid ]] && echo "ajustes: $(tr '\0' '\n' < "/proc/$pid/environ" | grep -E '^(LANG|LC_|LANGUAGE)' | tr '\n' ' ')"
kaelix vidro roxo --transparencia mais
"$C" abrir ajustes aparencia
sleep 14
kaelix vidro padrao --transparencia normal
