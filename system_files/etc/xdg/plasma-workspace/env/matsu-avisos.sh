#!/bin/sh
# Matsu OS: roda no começo de cada sessão do KDE, antes da área de trabalho
# (plasmashell) ligar. Os avisos dos apps são do relógio do Matsu, no jeito do
# Mac (org.matsu.relogio, Avisos.qml). Se a peça de avisos do KDE carregar uma
# vez na sessão, ela deixa os avisos dela ligados até o fim da sessão (no canto
# de cima, à esquerda), mesmo saindo da bandeja, e cada aviso aparece duas
# vezes. Por isso ela sai das bandejas aqui, antes de carregar: some de
# "extraItems" (as ligadas) e entra em "knownItems" (para a bandeja não ligar
# de novo sozinha). Só mexe se houver um relógio do Matsu nas barras.
# Depois de ligada, /usr/libexec/matsu/matsu-avisos confere de novo.
matsu_paineis="${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc"

if [ -f "$matsu_paineis" ] && grep -q '^plugin=org\.matsu\.relogio$' "$matsu_paineis" \
  && grep -q '^extraItems=.*org\.kde\.plasma\.notifications' "$matsu_paineis"; then
  awk -v peca=org.kde.plasma.notifications '
    function fecha() {
      if (ligadas && !conhecidas) print "knownItems=" peca
      ligadas = 0; conhecidas = 0
    }
    /^\[/ { fecha(); print; next }
    /^extraItems=/ {
      n = split(substr($0, 12), itens, ","); saida = ""
      for (i = 1; i <= n; i++) if (itens[i] != peca && itens[i] != "") saida = saida (saida == "" ? "" : ",") itens[i]
      print "extraItems=" saida; ligadas = 1; next
    }
    /^knownItems=/ {
      valor = substr($0, 12); conhecidas = 1
      if (("," valor ",") !~ ("," peca ",")) valor = valor (valor == "" ? "" : ",") peca
      print "knownItems=" valor; next
    }
    { print }
    END { fecha() }
  ' "$matsu_paineis" > "$matsu_paineis.matsu-novo" 2>/dev/null \
    && [ -s "$matsu_paineis.matsu-novo" ] \
    && mv -f "$matsu_paineis.matsu-novo" "$matsu_paineis"
  rm -f "$matsu_paineis.matsu-novo"
fi
