#!/bin/sh
# Kaelix OS: roda no começo de cada sessão do KDE, antes dos atalhos ligarem.
# O Meta+A é da central de controle. Se o atalho de trocar de atividade ficou
# com ele (contas criadas antes do conserto), solta, senão a central não abre.
kaelix_atalhos="${XDG_CONFIG_HOME:-$HOME/.config}/kglobalshortcutsrc"
if [ -f "$kaelix_atalhos" ] && grep -q '^next activity=[^,]*Meta+A' "$kaelix_atalhos"; then
  kwriteconfig6 --file "$kaelix_atalhos" --group plasmashell --key "next activity" "none,none,Percorrer as atividades"
fi
unset kaelix_atalhos
