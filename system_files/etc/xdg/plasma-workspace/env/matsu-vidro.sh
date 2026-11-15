#!/bin/sh
# Matsu OS: roda no começo de cada sessão do KDE, antes da área de trabalho
# ligar. Deixa o tema da pessoa (o vidro com cor, outra transparência ou os
# balões com o vidro do Mac no estilo Mac) de acordo com o que ela escolheu e
# com o gerador do vidro desta versão do sistema. Assim, depois de uma
# atualização, o vidro novo já aparece sem precisar escolher nada de novo.
# Quando não há nada a mudar, só confere e sai (rápido).
if [ -x /usr/bin/matsu ]; then
  /usr/bin/matsu vidro --sincronizar >/dev/null 2>&1 || true
fi
