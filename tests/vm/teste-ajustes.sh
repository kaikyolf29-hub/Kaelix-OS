#!/usr/bin/bash
# Teste da máquina virtual: abre os Ajustes do Kaelix e passa pelas páginas, uma
# a cada 8 segundos (o run-vm.sh tira os prints no mesmo ritmo). No fim deixa o
# vidro roxo e mais transparente por um tempo e volta ao padrão.
C=/usr/libexec/kaelix/kaelix-central
for pagina in aparencia barra papel telas sobre; do
  "$C" abrir ajustes "$pagina"
  sleep 8
done
kaelix vidro roxo --transparencia mais
"$C" abrir ajustes aparencia
sleep 14
kaelix vidro padrao --transparencia normal
