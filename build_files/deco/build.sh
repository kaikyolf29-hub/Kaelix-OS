#!/usr/bin/bash
# Matsu OS — compila os botões de janela do Matsu.
#
# A moldura das janelas é a do Breeze (KDE). Aqui baixamos o código dela, na
# mesma versão que está na imagem, colocamos o desenho dos nossos botões
# (matsu-botoes.inc) e compilamos só essa peça. O resultado fica em /out e a
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

log "Colocando os botões do Matsu"
alvo=/tmp/breeze/kdecoration/breezebutton.cpp
# O desenho entra logo depois desta linha da função que pinta o botão. Se o
# Breeze mudar e a linha sumir, a montagem para aqui para a gente perceber.
if [[ "$(grep -c '^    painter->translate(1, 1);$' "$alvo")" -ne 1 ]]; then
  echo "ERRO: o código do Breeze mudou; revise build_files/deco." >&2
  exit 1
fi
sed -i '/^    painter->translate(1, 1);$/r '"${HERE}/matsu-botoes.inc" "$alvo"
grep -q 'Matsu OS: botões de janela' "$alvo"
# A animação dos símbolos (aparecem com o mouse em cima) usa estas peças do Qt.
sed -i -e '1i #include <QEasingCurve>' -e '1i #include <QPolygonF>' -e '1i #include <QTimer>' "$alvo"

log "Compilando"
cmake -S /tmp/breeze -B /tmp/breeze-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
  -DBUILD_QT5=OFF -DBUILD_QT6=ON -DBUILD_CURSOR=OFF -DWITH_WALLPAPERS=OFF -DBUILD_TESTING=OFF
cmake --build /tmp/breeze-build --target breezedecoration

pronto="$(find /tmp/breeze-build -name 'org.kde.breeze.so' | head -n1)"
[[ -n $pronto ]]
install -Dm0755 "$pronto" /out/org.kde.breeze.so
echo "$destino" > /out/destino
log "Botões do Matsu compilados: $(stat -c %s /out/org.kde.breeze.so) bytes"

# Janela dos apps do Matsu feitos em QML (ver janela/main.cpp).
log "Compilando a matsu-janela"
dnf5 -y install qt6-qtbase-devel qt6-qtdeclarative-devel kf6-kwindowsystem-devel
cmake -S "${HERE}/janela" -B /tmp/janela-build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DMATSU_EXIGIR_KWS=ON
cmake --build /tmp/janela-build
install -Dm0755 /tmp/janela-build/matsu-janela /out/matsu-janela
log "matsu-janela compilada: $(stat -c %s /out/matsu-janela) bytes"

# A janela de senha do sistema (agente do polkit) do Matsu: a peça de QML
# org.matsu.senha (ver senha/agente.h), carregada pela matsu-janela. Se não
# compilar, a imagem sai com a janela de senha do KDE (o build.sh confere).
compilar_senha() {
  dnf5 -y install polkit-qt6-1-devel qt6-qtdeclarative-devel || return 1
  cmake -S "${HERE}/senha" -B /tmp/senha-build -G Ninja -DCMAKE_BUILD_TYPE=Release || return 1
  cmake --build /tmp/senha-build || return 1
  local pronto=/tmp/senha-build/org/matsu/senha
  [[ -s $pronto/libmatsusenha.so && -s $pronto/qmldir ]] || return 1
  mkdir -p /out/senha || return 1
  install -m0755 "$pronto/libmatsusenha.so" /out/senha/ || return 1
  install -m0644 "$pronto/qmldir" "$pronto/matsusenha.qmltypes" /out/senha/ || return 1
}
log "Compilando a janela de senha do Matsu"
if compilar_senha; then
  log "Janela de senha compilada: $(stat -c %s /out/senha/libmatsusenha.so) bytes"
else
  echo "AVISO: a janela de senha do Matsu não compilou; fica a do KDE." >&2
  rm -rf /out/senha
fi

# O terminal do Matsu (ver terminal/main.cpp): janela própria com a peça do
# Konsole dentro.
log "Compilando o matsu-terminal"
dnf5 -y install kf6-kparts-devel kf6-kcoreaddons-devel kf6-kconfig-devel kf6-kwindowsystem-devel
cmake -S "${HERE}/terminal" -B /tmp/terminal-build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build /tmp/terminal-build
install -Dm0755 /tmp/terminal-build/matsu-terminal /out/matsu-terminal
log "matsu-terminal compilado: $(stat -c %s /out/matsu-terminal) bytes"

# Os Arquivos do Matsu (ver arquivos/main.cpp): janela própria de vidro, igual à
# imagem escolhida, com a lista do Dolphin (a peça dolphinpart) dentro.
log "Compilando o matsu-arquivos"
dnf5 -y install kf6-kparts-devel kf6-kio-devel kf6-solid-devel kf6-kcoreaddons-devel kf6-kconfig-devel \
  kf6-kwindowsystem-devel qt6-qtbase-devel
cmake -S "${HERE}/arquivos" -B /tmp/arquivos-build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build /tmp/arquivos-build
install -Dm0755 /tmp/arquivos-build/matsu-arquivos /out/matsu-arquivos
log "matsu-arquivos compilado: $(stat -c %s /out/matsu-arquivos) bytes"
