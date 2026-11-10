#!/usr/bin/bash
# Kaelix OS — compila os botões de janela do Kaelix.
#
# A moldura das janelas é a do Breeze (KDE). Aqui baixamos o código dela, na
# mesma versão que está na imagem, colocamos o desenho dos nossos botões
# (kaelix-botoes.inc) e compilamos só essa peça. O resultado fica em /out e a
# etapa final da imagem copia para o lugar.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
log() { printf '\n==> %s\n' "$*"; }

destino="$(find /usr/lib64/qt6/plugins -path '*org.kde.kdecoration*' -name 'org.kde.breeze.so' | head -n1)"
if [[ -z $destino ]]; then
  echo "ERRO: não achei a moldura de janelas do Breeze na imagem." >&2
  exit 1
fi
pacote="$(rpm -qf --qf '%{NAME}' "$destino")"
versao="$(rpm -q --qf '%{VERSION}' "$pacote")"
fonte="$(rpm -q --qf '%{SOURCERPM}' "$pacote" | sed -E 's/-[^-]+-[^-]+\.src\.rpm$//')"
log "Moldura: $destino (pacote $pacote, versão $versao, fonte $fonte)"

log "Instalando o que é preciso para compilar"
dnf5 -y install git-core cmake gcc-c++ ninja-build extra-cmake-modules
if ! dnf5 -y builddep "$fonte"; then
  dnf5 -y install \
    kf6-rpm-macros qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtsvg-devel \
    kf6-kcmutils-devel kf6-kcolorscheme-devel kf6-kconfig-devel kf6-kcoreaddons-devel \
    kf6-kguiaddons-devel kf6-ki18n-devel kf6-kiconthemes-devel kf6-kwindowsystem-devel \
    kf6-frameworkintegration-devel kf6-kirigami-devel kdecoration-devel
fi

log "Baixando o código do Breeze $versao"
git clone --depth 1 --branch "v${versao}" https://invent.kde.org/plasma/breeze.git /tmp/breeze \
  || git clone --depth 1 --branch "v${versao}" https://github.com/KDE/breeze.git /tmp/breeze

log "Colocando os botões do Kaelix"
alvo=/tmp/breeze/kdecoration/breezebutton.cpp
# O desenho entra logo depois desta linha da função que pinta o botão. Se o
# Breeze mudar e a linha sumir, a montagem para aqui para a gente perceber.
if [[ "$(grep -c '^    painter->translate(1, 1);$' "$alvo")" -ne 1 ]]; then
  echo "ERRO: o código do Breeze mudou; revise build_files/deco." >&2
  exit 1
fi
sed -i '/^    painter->translate(1, 1);$/r '"${HERE}/kaelix-botoes.inc" "$alvo"
grep -q 'Kaelix OS: botões de janela' "$alvo"

log "Compilando"
cmake -S /tmp/breeze -B /tmp/breeze-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
  -DBUILD_QT5=OFF -DBUILD_QT6=ON -DBUILD_CURSOR=OFF -DWITH_WALLPAPERS=OFF -DBUILD_TESTING=OFF
cmake --build /tmp/breeze-build --target breezedecoration

pronto="$(find /tmp/breeze-build -name 'org.kde.breeze.so' | head -n1)"
[[ -n $pronto ]]
install -Dm0755 "$pronto" /out/org.kde.breeze.so
echo "$destino" > /out/destino
log "Botões do Kaelix compilados: $(stat -c %s /out/org.kde.breeze.so) bytes"
