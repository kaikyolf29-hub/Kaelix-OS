#!/bin/sh
# Matsu OS: roda no começo de cada sessão do KDE, antes do serviço de atalhos
# (kglobalaccel) ligar. Os atalhos do Matsu são como no Windows: Meta+A abre a
# central de controle e Meta+B a setinha da bandeja. Dois atalhos do KDE brigam
# com eles:
#   - "Percorrer as atividades" (plasmashell, "next activity") pega o Meta+A
#     sozinho na primeira vez que o trocador de atividades carrega;
#   - "Trocar perfil de energia" (powerdevil, "powerProfile") pega o Meta+B.
# Quem chega primeiro fica com a tecla, e a central e a bandeja não abriam.
#
# O serviço de atalhos só lê o arquivo da pessoa (~/.config/kglobalshortcutsrc),
# nunca o /etc/xdg, então o conserto vai no arquivo dela: antes da primeira
# sessão (conta nova, ou conta em que eles ainda não apareceram) e em toda
# sessão em que um dos dois voltou a ter a tecla.
# O KDE respeita o que estiver salvo ali, então eles ficam sem essas teclas.
# O perfil de energia continua na tecla "Battery" dos notebooks que têm.
# Na linha salva, a primeira parte (antes da vírgula) é a tecla em uso, e
# várias teclas ficam separadas por "\t" escrito com barra. Só conta o Meta+A
# (ou Meta+B) inteiro: uma tecla que a pessoa escolheu, como Meta+Alt+N, fica.
matsu_atalhos="${XDG_CONFIG_HOME:-$HOME/.config}/kglobalshortcutsrc"
matsu_tab="$(printf '\t')"

mkdir -p "$(dirname "$matsu_atalhos")"
if ! grep -q '^next activity=' "$matsu_atalhos" 2>/dev/null || grep -qE '^next activity=([^,]*\\t)?Meta\+A(\\t|,|$)' "$matsu_atalhos"; then
  kwriteconfig6 --file "$matsu_atalhos" --group plasmashell --key "next activity" \
    "none,none,Percorrer as atividades"
fi
if ! grep -q '^powerProfile=' "$matsu_atalhos" 2>/dev/null || grep -qE '^powerProfile=([^,]*\\t)?Meta\+B(\\t|,|$)' "$matsu_atalhos"; then
  kwriteconfig6 --file "$matsu_atalhos" --group org_kde_powerdevil --key powerProfile \
    "Battery,Battery${matsu_tab}Meta+B,Trocar perfil de energia"
fi
unset matsu_atalhos matsu_tab
