#!/usr/bin/bash
# Testes dos temas de ícones Matsu e Matsu-claro: os geradores estão em dia com
# o que está no repositório, toda ligação aponta para um arquivo que existe,
# todo app e peça do Matsu pede um ícone que existe, e os nomes de ação e de
# aparelho do KDE (que aparecem nos menus dos apps, no Arquivos, no Bluetooth)
# continuam com o ícone do Breeze.
set -u
cd "$(dirname "$0")/.." || exit 1
ok=0; falhas=0
check() { if eval "$2"; then ok=$((ok + 1)); else falhas=$((falhas + 1)); echo "FALHOU: $1"; fi; }

ICONES=system_files/usr/share/icons
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# 1) Rodar os geradores numa cópia dá exatamente o que está no repositório.
cp -a "$ICONES/Matsu" "$ICONES/Matsu-claro" "$tmp/"
node visual/icones/gerar.js "$tmp/Matsu/apps/scalable" >/dev/null
node visual/icones/ajustes.js "$tmp/Matsu" "$tmp/Matsu-claro" >/dev/null
python3 visual/icones/tipos.py "$tmp" >/dev/null
for t in Matsu Matsu-claro; do
  check "$t: os geradores estão em dia (rode visual/icones/ajustes.js, gerar.js e tipos.py)" \
    "diff -r --no-dereference '$ICONES/$t' '$tmp/$t' >/dev/null"
done

# 2) Toda ligação relativa aponta para um arquivo que existe; as absolutas são
# só as do Breeze, na pasta actions/16, e cada uma tem o quadrado do Matsu.
quebradas=""; absolutas_fora=""; sem_quadrado=""
while IFS= read -r l; do
  alvo="$(readlink "$l")"
  if [[ $alvo == /* ]]; then
    [[ $l == */actions/16/* && $alvo == /usr/share/icons/breeze*/actions/16/* ]] || absolutas_fora+=" $l"
    [[ -e "$(dirname "$l")/../../ajustes/scalable/$(basename "$l")" ]] || sem_quadrado+=" $l"
  else
    [[ -e $l ]] || quebradas+=" $l"
  fi
done < <(find "$ICONES/Matsu" "$ICONES/Matsu-claro" -type l)
check "ligações quebradas:${quebradas:- nenhuma}" "[[ -z '$quebradas' ]]"
check "ligações absolutas fora de actions/16:${absolutas_fora:- nenhuma}" "[[ -z '$absolutas_fora' ]]"
check "ícone de ação sem o quadrado do Matsu:${sem_quadrado:- nenhum}" "[[ -z '$sem_quadrado' ]]"

# 3) Os dois temas têm os mesmos ícones (o claro usa a pasta apps do escuro).
check "Matsu-claro usa os mesmos ícones de apps" "[[ \$(readlink '$ICONES/Matsu-claro/apps') == ../Matsu/apps ]]"
check "Matsu e Matsu-claro com os mesmos nomes" \
  "diff <(cd '$ICONES/Matsu' && find . ! -name index.theme -not -path './apps*' | sort) <(cd '$ICONES/Matsu-claro' && find . ! -name index.theme -not -path './apps*' | sort) >/dev/null"
for d in apps/scalable ajustes/scalable actions/16 status/symbolic mimetypes/pequeno mimetypes/pequeno@2x mimetypes/scalable \
         places/pequeno places/pequeno@2x places/scalable; do
  check "index.theme do Matsu lista a pasta $d" "grep -q '^Directories=.*$d' '$ICONES/Matsu/index.theme'"
  check "index.theme do Matsu-claro lista a pasta $d" "grep -q '^Directories=.*$d' '$ICONES/Matsu-claro/index.theme'"
done

# 4) Todo ícone que os apps e as peças do Matsu pedem existe no tema ou no hicolor.
existe() {
  local n="$1"
  [[ -e "$ICONES/Matsu/apps/scalable/$n.svg" || -e "$ICONES/Matsu/status/symbolic/$n.svg" || -e "$ICONES/hicolor/scalable/apps/$n.svg" ]]
}
faltam=""
while IFS= read -r n; do
  existe "$n" || faltam+=" $n"
done < <({ sed -n 's/^Icon=//p' system_files/usr/share/applications/*.desktop
           grep -ho '"Icon": *"[^"]*"' system_files/usr/share/plasma/plasmoids/*/metadata.json | sed 's/.*"\([^"]*\)"$/\1/'; } | sort -u)
check "ícones pedidos pelos .desktop e peças do Matsu que faltam:${faltam:- nenhum}" "[[ -z '$faltam' ]]"
check "Ajustes do Matsu e Configurações do sistema com ícones diferentes" \
  "[[ \$(readlink -f '$ICONES/Matsu/apps/scalable/org.matsu.ajustes.svg') != \$(readlink -f '$ICONES/Matsu/apps/scalable/systemsettings.svg') ]]"
check "Estilo da barra com o ícone da barra e abrindo nos Ajustes" \
  "grep -q '^Icon=matsu-ajuste-barra$' system_files/usr/share/applications/matsu-barra.desktop && grep -q '^Exec=/usr/libexec/matsu/matsu-central abrir ajustes barra$' system_files/usr/share/applications/matsu-barra.desktop"

# 5) Páginas das Configurações do sistema e apps do KDE com o quadrado do Matsu.
for n in preferences-desktop-mouse preferences-desktop-theme-global preferences-system-network preferences-system-network-connection \
         preferences-desktop-sound preferences-system-users preferences-security preferences-desktop-wallpaper \
         ark help-browser hwinfo kwalletmanager kdeconnect firewall-config filelight kfind partitionmanager \
         accessories-character-map start-here-kde-plasma; do
  check "$n coberto pelo tema Matsu" "[[ -e '$ICONES/Matsu/apps/scalable/$n.svg' ]]"
done
for n in system-run tools-check-spelling lighttable; do
  check "$n: quadrado do Matsu de 20 px para cima" "[[ -e '$ICONES/Matsu/ajustes/scalable/$n.svg' && ! -e '$ICONES/Matsu/apps/scalable/$n.svg' ]]"
  check "$n: Breeze no tamanho de menu" "[[ \$(readlink '$ICONES/Matsu/actions/16/$n.svg') == /usr/share/icons/breeze-dark/actions/16/$n.svg ]]"
  check "$n: Breeze claro no tamanho de menu (Matsu-claro)" "[[ \$(readlink '$ICONES/Matsu-claro/actions/16/$n.svg') == /usr/share/icons/breeze/actions/16/$n.svg ]]"
done

# 6) Nomes de ação, aparelho e estado do KDE ficam com o Breeze (não podem virar
# quadrado colorido no menu Ajuda, no pendrive do Arquivos, no som da bandeja).
for n in edit-copy edit-paste help-about tools-report-bug debug-run system-log-out system-shutdown system-lock-screen \
         input-keyboard input-keyboard-virtual input-mouse drive-removable-media drive-harddisk camera-photo smartphone \
         battery audio-volume-high audio-card network-wireless video-display computer folder-open application-pdf \
         printer network-connect applications-games applications-internet; do
  check "$n continua com o Breeze" "! compgen -G '$ICONES/Matsu/*/*/$n.svg' >/dev/null"
done

# 6b) Pastas e tipos de arquivo: cada nome do Breeze vira ligação para o desenho
# certo do Matsu (build_files/icones-de-arquivo.py, rodado num Breeze de mentira).
falso="$tmp/raiz/usr/share/icons"
mkdir -p "$falso"
cp -a "$ICONES/Matsu" "$ICONES/Matsu-claro" "$falso/"
for b in breeze breeze-dark; do
  mkdir -p "$falso/$b/mimetypes/22" "$falso/$b/places/22"
  for n in video-x-matroska application-x-cd-image application-vnd.efi.iso application-pdf application-zip \
           text-markdown text-x-python image-png audio-mpeg application-x-rpm application-x-krita \
           application-vnd.oasis.opendocument.spreadsheet video-x-generic-symbolic; do
    touch "$falso/$b/mimetypes/22/$n.svg"
  done
  for n in folder folder-download folder-pictures folder-red folder-open user-home folder-games folder-symbolic; do
    touch "$falso/$b/places/22/$n.svg"
  done
done
python3 build_files/icones-de-arquivo.py "$tmp/raiz" >/dev/null
liga() { [[ $(readlink "$falso/Matsu/$1") == "$2" && $(readlink "$falso/Matsu-claro/$1") == "$2" ]]; }
for par in video-x-matroska:video application-x-cd-image:disco application-vnd.efi.iso:disco application-pdf:pdf \
           application-zip:compactado text-markdown:texto text-x-python:codigo image-png:imagem audio-mpeg:audio \
           application-x-rpm:pacote application-vnd.oasis.opendocument.spreadsheet:planilha; do
  check "${par%%:*} vira o desenho ${par#*:}" "liga mimetypes/pequeno/${par%%:*}.svg matsu-tipo-${par#*:}.svg && liga mimetypes/scalable/${par%%:*}.svg matsu-tipo-${par#*:}.svg"
done
check "inode-directory vira a pasta do Matsu" "liga mimetypes/pequeno/inode-directory.svg ../../places/pequeno/matsu-pasta.svg"
for par in folder: folder-download:-downloads folder-pictures:-imagens user-home:-pessoal folder-games:-jogos; do
  check "${par%%:*} vira a pasta matsu-pasta${par#*:}" "liga places/scalable/${par%%:*}.svg matsu-pasta${par#*:}.svg"
done
for n in places/scalable/folder-red places/pequeno/folder-open places/pequeno/folder-symbolic \
         mimetypes/pequeno/video-x-generic-symbolic mimetypes/pequeno/application-x-krita; do
  check "$n continua com o Breeze" "[[ ! -e '$falso/Matsu/$n.svg' ]]"
done
check "todo desenho de tipo existe nos dois temas" \
  "[[ -z \$(find '$falso'/Matsu*/mimetypes '$falso'/Matsu*/places -xtype l) ]]"

# 7) O build.sh troca o ícone dos dois apps que pedem ícone de ação.
check "build.sh troca o ícone do visualizador de falhas" "grep -q 'org.kde.drkonqi.coredump.gui:matsu-ajuste-falhas' build_files/build.sh"
check "build.sh troca o ícone das configurações do KDebug" "grep -q 'org.kde.kdebugsettings:matsu-ajuste-depuracao' build_files/build.sh"
check "ícones do build.sh existem" "[[ -e '$ICONES/Matsu/apps/scalable/matsu-ajuste-falhas.svg' && -e '$ICONES/Matsu/apps/scalable/matsu-ajuste-depuracao.svg' ]]"

# 8) Todo SVG é XML válido e do tamanho 256.
ruins=""
for f in "$ICONES"/Matsu/apps/scalable/matsu-*.svg; do
  python3 -c "import sys, xml.dom.minidom as m; d=m.parse(sys.argv[1]); assert d.documentElement.getAttribute('viewBox')=='0 0 256 256'" "$f" 2>/dev/null || ruins+=" ${f##*/}"
done
check "SVGs válidos com viewBox 0 0 256 256:${ruins:- todos}" "[[ -z '$ruins' ]]"

echo "ícones: $ok certos, $falhas falharam"
[[ $falhas -eq 0 ]]
