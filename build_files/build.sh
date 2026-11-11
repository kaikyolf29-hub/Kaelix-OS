#!/usr/bin/bash
# Matsu OS — script que monta a imagem (roda dentro do Containerfile).
# Cada parte está separada e comentada para ficar fácil de entender e mudar.
set -euo pipefail

CTX=/ctx
: "${IMAGE_NAME:?}" "${IMAGE_VARIANT:?}" "${IMAGE_REGISTRY:?}" "${BUILD_ID:?}" "${FEDORA_VERSION:?}"

log() { printf '\n==> %s\n' "$*"; }

# ---------------------------------------------------------------------------
log "Conferindo a chave pública de assinatura"
# A assinatura é obrigatória desde o primeiro dia (plano, seção 2).
# Sem a chave pública verdadeira, a imagem não é montada.
if ! grep -q "BEGIN PUBLIC KEY" "${CTX}/cosign.pub"; then
  echo "ERRO: cosign.pub não tem uma chave pública válida. Veja docs/CHAVES.md." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
log "Copiando os arquivos próprios do Matsu para o sistema"
cp -a "${CTX}/system_files/." /
chmod 0755 /usr/bin/matsu /usr/libexec/matsu/*

# ---------------------------------------------------------------------------
log "Instalando pacotes"
# Jogos: GameMode (desempenho) e MangoHud (números na tela), 64 e 32 bits.
# Programação: compiladores, Node, Python e Distrobox.
# Utilidades usadas pelo comando matsu: jq, pciutils e kdialog.
dnf5 -y install \
  gamemode mangohud \
  distrobox podman \
  git gcc gcc-c++ make cmake \
  nodejs npm python3 python3-pip \
  jq pciutils kdialog \
  fastfetch

dnf5 -y install --skip-unavailable gamemode.i686 mangohud.i686

# Bandeja do sistema (perto do relógio), como no Windows. O KDE já mostra os
# ícones dos apps pelo protocolo novo (StatusNotifierItem). Aqui entram as
# bibliotecas que os apps usam para chegar nele (libayatana-appindicator e a
# antiga libappindicator, com os menus do botão direito) e a ponte para apps
# antigos que usam o XEmbed (xembedsniproxy).
dnf5 -y install --skip-unavailable \
  libayatana-appindicator-gtk3 libappindicator-gtk3 libdbusmenu-gtk3 xembedsniproxy
rpm -q libayatana-appindicator-gtk3 libappindicator-gtk3 libdbusmenu-gtk3 || true
if command -v xembedsniproxy >/dev/null; then
  echo "Ponte XEmbed: $(command -v xembedsniproxy) ($(rpm -qf "$(command -v xembedsniproxy)"))"
  for f in /usr/lib/systemd/user/*xembed* /etc/xdg/autostart/*xembed*; do [[ -e $f ]] && echo "  $f"; done
else
  echo "AVISO: xembedsniproxy não está na imagem; apps antigos (XEmbed) não vão aparecer na bandeja." >&2
fi

# Perfil de energia (economia, equilibrado, desempenho) para a central de controle.
if ! rpm -q tuned-ppd >/dev/null 2>&1 && ! rpm -q power-profiles-daemon >/dev/null 2>&1; then
  dnf5 -y install --skip-unavailable tuned-ppd
fi
echo "Perfil de energia: $(rpm -q tuned-ppd power-profiles-daemon 2>/dev/null | grep -v 'not installed\|não está' | tr '\n' ' ')"

# Fonte Inter, a mesma do vídeo de demonstração da fusão.
dnf5 -y install --skip-unavailable rsms-inter-fonts rsms-inter-vf-fonts
# Fonte do terminal do Matsu (a mesma do vídeo de demonstração).
dnf5 -y install --skip-unavailable jetbrains-mono-fonts-all || dnf5 -y install --skip-unavailable jetbrains-mono-fonts || true
fc-list : family | grep -i -m1 "jetbrains mono" || echo "AVISO: fonte JetBrains Mono não entrou; o terminal usa a fonte mono padrão"

# Controle da placa de vídeo (ventoinha, temperatura, desempenho). O driver da
# AMD já vem no sistema; isto faz o papel do "AMD Software" do Windows.
# Preferimos o LACT; se o Fedora não tiver, entra o CoreCtrl.
if dnf5 -y install lact; then
  systemctl enable lactd.service || true
  echo "lact" > /tmp/matsu-gpu-tool
else
  dnf5 -y install --skip-unavailable corectrl
  echo "corectrl" > /tmp/matsu-gpu-tool
fi
echo "Controle da placa de vídeo: $(cat /tmp/matsu-gpu-tool)"
rm -f /tmp/matsu-gpu-tool

# Steam (com Proton) vem do repositório oficial "rpmfusion-nonfree-steam",
# o mesmo que o Fedora oferece. Ele só é ligado durante a instalação.
dnf5 -y install fedora-workstation-repositories
dnf5 -y --enablerepo=rpmfusion-nonfree-steam install steam
dnf5 -y --enablerepo=rpmfusion-nonfree-steam install --skip-unavailable steam-devices

# VS Code, do repositório oficial da Microsoft.
rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat > /etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
dnf5 -y install code
# Num sistema atômico os pacotes chegam pela imagem, então o repositório fica desligado.
sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/vscode.repo

# ---------------------------------------------------------------------------
log "Colocando o nome Matsu 27 OS no sistema"
# Uma edição por ano: só o número muda (arquivo EDICAO na raiz do repositório;
# 27 = edição 2027, 28 = edição 2028...).
EDICAO="$(tr -dc '0-9' < "${CTX}/EDICAO")"
[[ -n $EDICAO ]] || { echo "ERRO: o arquivo EDICAO está vazio" >&2; exit 1; }
ANO="20${EDICAO}"
NOME="Matsu ${EDICAO} OS"
OWNER="${IMAGE_REGISTRY#*/}"
REPO_URL="https://github.com/${OWNER}/Kaelix-OS"
# O nome do Fedora não aparece para a pessoa: o sistema se apresenta como
# Matsu em tudo (Sobre, menu de boot, terminal, nome do computador). O ID e o
# VERSION_ID continuam os do Fedora, porque programas como o dnf e o toolbox
# conferem a base por eles.
sed -i \
  -e 's/^NAME=.*/NAME="Matsu OS"/' \
  -e "s/^VERSION=.*/VERSION=\"${EDICAO} (Edição ${ANO})\"/" \
  -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${NOME}\"/" \
  -e "s/^VARIANT=.*/VARIANT=\"Edição ${ANO}\"/" \
  -e 's/^VARIANT_ID=.*/VARIANT_ID=matsu/' \
  -e "s|^HOME_URL=.*|HOME_URL=\"${REPO_URL}\"|" \
  -e "s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL=\"${REPO_URL}\"|" \
  -e "s|^SUPPORT_URL=.*|SUPPORT_URL=\"${REPO_URL}/issues\"|" \
  -e "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"${REPO_URL}/issues\"|" \
  -e '/^DEFAULT_HOSTNAME=/d' \
  /usr/lib/os-release
grep -q '^VARIANT_ID=' /usr/lib/os-release || echo 'VARIANT_ID=matsu' >> /usr/lib/os-release
grep -q '^VARIANT=' /usr/lib/os-release || echo "VARIANT=\"Edição ${ANO}\"" >> /usr/lib/os-release
# Sem /etc/hostname, o computador se chama "matsu" (antes aparecia "fedora").
echo 'DEFAULT_HOSTNAME=matsu' >> /usr/lib/os-release
# Logo do Matsu (o pinheiro) como logo do sistema, por exemplo em "Sobre este sistema".
if grep -q '^LOGO=' /usr/lib/os-release; then
  sed -i 's/^LOGO=.*/LOGO=matsu-logo/' /usr/lib/os-release
else
  echo 'LOGO=matsu-logo' >> /usr/lib/os-release
fi
# Os textos do sistema que mostram o nome com o ano usam @EDICAO@ e @ANO@.
# (A tela de login em texto, Ctrl+Alt+F3, já mostra o PRETTY_NAME pelo \S do /etc/issue.)
{ grep -rlZ -e '@EDICAO@' -e '@ANO@' /usr/share/matsu /usr/share/plasma /usr/share/applications \
    /usr/share/plymouth /etc/xdg 2>/dev/null || true; } | xargs -0 -r sed -i -e "s/@EDICAO@/${EDICAO}/g" -e "s/@ANO@/${ANO}/g"
echo "Nome no sistema: $(grep -E '^(NAME|PRETTY_NAME|VERSION|VARIANT|DEFAULT_HOSTNAME)=' /usr/lib/os-release | tr '\n' ' ')"

mkdir -p /usr/share/matsu
jq -n \
  --arg name "${IMAGE_NAME}" \
  --arg variant "${IMAGE_VARIANT}" \
  --arg registry "${IMAGE_REGISTRY}" \
  --arg build "${BUILD_ID}" \
  --arg fedora "${FEDORA_VERSION}" \
  --arg edicao "${EDICAO}" \
  '{"image-name":$name, "image-variant":$variant, "image-registry":$registry,
    "build-id":$build, "fedora-version":$fedora, "edicao":$edicao}' \
  > /usr/share/matsu/image-info.json

# ---------------------------------------------------------------------------
log "Configurando a verificação de assinatura das atualizações"
# A máquina só aceita imagens do Matsu assinadas com a chave do criador.
install -Dm0644 "${CTX}/cosign.pub" /etc/pki/containers/matsu-os.pub

for img in matsu-os matsu-os-nvidia; do
  tmp=$(mktemp)
  jq --arg scope "${IMAGE_REGISTRY}/${img}" \
    '.transports.docker[$scope] = [{
        "type": "sigstoreSigned",
        "keyPath": "/etc/pki/containers/matsu-os.pub",
        "signedIdentity": {"type": "matchRepository"}
     }]' /etc/containers/policy.json > "${tmp}"
  install -m0644 "${tmp}" /etc/containers/policy.json
  rm -f "${tmp}"
done

cat > /etc/containers/registries.d/matsu-os.yaml <<EOF
docker:
  ${IMAGE_REGISTRY}:
    use-sigstore-attachments: true
EOF

# ---------------------------------------------------------------------------
log "Português do Brasil como padrão"
# O sistema já nasce em português, com data, moeda e horário do Brasil. Quem
# preferir outro idioma troca na instalação ou nas configurações. O teclado
# vem do instalador, que já deixa o ABNT2 marcado (installer/matsu.ks.in).
dnf5 -y install --skip-unavailable glibc-langpack-pt langpacks-core-pt_BR || true
echo 'LANG=pt_BR.UTF-8' > /etc/locale.conf
cat > /etc/xdg/plasma-localerc <<'EOF'
[Formats]
LANG=pt_BR.UTF-8

[Translations]
LANGUAGE=pt_BR:pt:en_US
EOF
ln -sfn ../usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# ---------------------------------------------------------------------------
log "Deixando o visual do Matsu como padrão"
# O tema global (cores sem preto puro, papel de parede em pixel art e a barra em
# três ilhas) fica em /usr/share/plasma/look-and-feel. Aqui ele vira o padrão
# para toda conta nova. A pessoa pode trocar depois nas configurações.
for f in /etc/xdg/kdeglobals /usr/share/kde-settings/kde-profile/default/xdg/kdeglobals; do
  if [[ $f == /etc/xdg/kdeglobals || -e $f ]]; then
    kwriteconfig6 --file "$f" --group KDE --key LookAndFeelPackage org.matsu.escuro.desktop
    kwriteconfig6 --file "$f" --group General --key ColorScheme MatsuEscuro
    kwriteconfig6 --file "$f" --group Icons --key Theme Matsu
    # Letra do sistema: Inter, como no vídeo da fusão (se a fonte entrou).
    if fc-list : family | grep -qx "Inter"; then
      kwriteconfig6 --file "$f" --group General --key font "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
      kwriteconfig6 --file "$f" --group General --key menuFont "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
      kwriteconfig6 --file "$f" --group General --key toolBarFont "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
      kwriteconfig6 --file "$f" --group General --key smallestReadableFont "Inter,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
      kwriteconfig6 --file "$f" --group WM --key activeFont "Inter,10,-1,5,600,0,0,0,0,0,0,0,0,0,0,1"
    fi
  fi
done
# A barra padrão (fusão) dos temas globais é montada a partir dos mesmos arquivos
# que o comando "matsu barra" usa, para existir uma fonte só.
for tema in org.matsu.escuro.desktop org.matsu.claro.desktop; do
  mkdir -p "/usr/share/plasma/look-and-feel/$tema/contents/layouts"
  cat /usr/share/matsu/barra/comum.js /usr/share/matsu/barra/fusao.js /usr/share/matsu/barra/papel-de-parede.js \
    > "/usr/share/plasma/look-and-feel/$tema/contents/layouts/org.kde.plasma.desktop-layout.js"
done
# Papel de parede animado: a peça do KDE do Waywallen, que mostra na área de
# trabalho os papéis do Wallpaper Engine da Steam (e vídeos). O app Waywallen
# vem do Flathub no primeiro boot. Se não der para baixar, a imagem sai sem ela.
ww_url="$(curl -fsSL --retry 3 https://api.github.com/repos/waywallen/waywallen-display/releases/latest 2>/dev/null \
  | jq -r '.assets[]?.browser_download_url | select(test("waywallen-kde-.*-(x86_64|amd64)-embed\\.zip$"))' | head -n1 || true)"
if [[ -n $ww_url ]] && curl -fsSL --retry 3 -o /tmp/waywallen-kde.zip "$ww_url"; then
  echo "Waywallen (peça do KDE): $ww_url sha256=$(sha256sum /tmp/waywallen-kde.zip | cut -d' ' -f1)"
  mkdir -p /usr/share/plasma/wallpapers
  kpackagetool6 --type Plasma/Wallpaper --packageroot /usr/share/plasma/wallpapers --install /tmp/waywallen-kde.zip \
    || echo "AVISO: a peça do KDE do Waywallen não instalou"
  grep -l -i waywallen /usr/share/plasma/wallpapers/*/metadata.json 2>/dev/null || true
  rm -f /tmp/waywallen-kde.zip
else
  echo "AVISO: não deu para baixar a peça do KDE do Waywallen; o papel animado fica para depois"
fi
# Tela de boas-vindas do primeiro uso com a cara do Matsu (endereço do projeto).
sed -i "s|@REPO_URL@|${REPO_URL}|" /usr/share/plasma/plasma-welcome/intro-customization.desktop
# Tela de carregamento depois da senha: o emblema do Matsu no lugar do logo do KDE.
kwriteconfig6 --file /etc/xdg/ksplashrc --group KSplash --key Engine KSplashQML
kwriteconfig6 --file /etc/xdg/ksplashrc --group KSplash --key Theme org.matsu.escuro.desktop
chmod 0644 /etc/xdg/ksplashrc
# Tela de login e tela de bloqueio com o papel de parede do Matsu.
for f in /etc/plasmalogin.conf /etc/xdg/kscreenlockerrc; do
  for chave in Image PreviewImage; do
    kwriteconfig6 --file "$f" --group Greeter --group Wallpaper --group org.kde.image --group General \
      --key "$chave" "file:///usr/share/wallpapers/Matsu"
  done
  chmod 0644 "$f"
done
# Para o registro da montagem: o que a tela de login lê.
ls -la /etc/plasmalogin.conf* /usr/lib/plasmalogin* /usr/share/plasmalogin* 2>/dev/null || true
cat /etc/plasmalogin.conf
# Atalhos do Matsu como no Windows: Meta+A abre a central, Meta+N as
# notificações e o calendário, Meta+B a setinha da bandeja. No KDE o Meta+A
# trocava de "atividade" e não deixava a central pegar o atalho. O "Meta+A"
# não pode aparecer em nenhuma das duas partes da linha (a usada e a padrão):
# com "none,Meta+A" o KDE acabou devolvendo o Meta+A para as atividades.
# Contas antigas são arrumadas no login por plasma-workspace/env/matsu-atalhos.sh.
kwriteconfig6 --file /etc/xdg/kglobalshortcutsrc --group plasmashell --key "next activity" "none,none,Percorrer as atividades"
chmod 0644 /etc/xdg/kglobalshortcutsrc
grep -i -e "meta+a" -e "meta+n" -e "meta+b" /etc/xdg/kglobalshortcutsrc || true
# Tema Plasma do Matsu: ilhas de vidro com cantos redondos (o resto vem do KDE).
kwriteconfig6 --file /etc/xdg/plasmarc --group Theme --key name Matsu
chmod 0644 /etc/xdg/plasmarc
# Botões de janela do Matsu (bolinhas rosa, azul e verde água), compilados na
# etapa "deco" do Containerfile. Entram no lugar da moldura padrão.
if [[ -s /deco/org.kde.breeze.so && -s /deco/destino ]]; then
  install -m0755 /deco/org.kde.breeze.so "$(cat /deco/destino)"
  echo "Botões de janela do Matsu instalados em $(cat /deco/destino)"
else
  echo "ERRO: os botões de janela do Matsu não foram compilados." >&2
  exit 1
fi
# Janela dos apps do Matsu feitos em QML (Gerenciador de tarefas), também
# compilada na etapa "deco". Ela dá a cada app a identidade do seu .desktop,
# para a barra mostrar o ícone e o nome certos.
if [[ -s /deco/matsu-janela ]]; then
  install -Dm0755 /deco/matsu-janela /usr/libexec/matsu/matsu-janela
  echo "matsu-janela instalada"
else
  echo "ERRO: a matsu-janela não foi compilada." >&2
  exit 1
fi
python3 -c "import ast,sys; ast.parse(open('/usr/share/matsu/tarefas/ajudante.py').read())"
# Botões da janela do lado esquerdo, nesta ordem: fechar, minimizar, tela cheia.
kwriteconfig6 --file /etc/xdg/kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft XIA
kwriteconfig6 --file /etc/xdg/kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ""
# Alt+Tab como no Windows 11: as janelas em miniatura lado a lado, no vidro do Matsu.
kwriteconfig6 --file /etc/xdg/kwinrc --group TabBox --key LayoutName thumbnail_grid
chmod 0644 /etc/xdg/kdeglobals /etc/xdg/kwinrc

# Terminal do Matsu (como no vídeo): perfil próprio com vidro, sem barra de
# menu e sem barra de ferramentas. O tema claro troca para o perfil claro.
kwriteconfig6 --file /etc/xdg/konsolerc --group "Desktop Entry" --key DefaultProfile Matsu.profile
kwriteconfig6 --file /etc/xdg/konsolerc --group MainWindow --key MenuBar Disabled
kwriteconfig6 --file /etc/xdg/konsolerc --group MainWindow --group "Toolbar mainToolBar" --key Hidden true
kwriteconfig6 --file /etc/xdg/konsolerc --group MainWindow --group "Toolbar sessionToolbar" --key Hidden true
kwriteconfig6 --file /etc/xdg/konsolerc --group KonsoleWindow --key ShowWindowTitleOnTitleBar true
# Arquivos (Dolphin) como no vídeo: lista com nome, data, tipo e tamanho em
# todas as pastas (o jeito vem de /etc/skel), barra de status embaixo.
kwriteconfig6 --file /etc/xdg/dolphinrc --group General --key GlobalViewProps true
kwriteconfig6 --file /etc/xdg/dolphinrc --group General --key ShowStatusBar true
kwriteconfig6 --file /etc/xdg/dolphinrc --group General --key ShowFullPathInTitlebar false
chmod 0644 /etc/xdg/konsolerc /etc/xdg/dolphinrc
gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
# Ícones próprios dos apps do sistema (tema de ícones Matsu). Fica no registro
# qual nome de ícone cada app pede, para conferir que o nosso está cobrindo.
grep -H '^Icon=' /usr/share/applications/org.kde.{dolphin,konsole,discover,plasma-systemmonitor,kwrite,kate,spectacle,gwenview}.desktop \
  /usr/share/applications/{systemsettings,kdesystemsettings}.desktop 2>/dev/null || true

# ---------------------------------------------------------------------------
log "Ligando os serviços do Matsu"
# Flathub e os apps Flatpak que já vêm (Heroic, Lutris, OBS, Kdenlive...).
systemctl enable matsu-flatpak-setup.service
# Central de jogos: o ajudante que liga o perfil gráfico e a sobreposição
# quando um jogo abre (e desfaz tudo quando ele fecha), na sessão de cada pessoa.
systemctl --global enable matsu-jogos.service
chmod 0755 /usr/libexec/matsu/matsu-jogos-placa

# ---------------------------------------------------------------------------
log "Tela de boot do Matsu"
# Tema próprio do Plymouth (visual/boot/gerar.py): o pinheiro do Matsu no fundo
# quase preto com três pontos pulsando, igual à tela que aparece depois da senha.
# Os ícones do teclado e do Caps Lock da senha do disco vêm do tema do Fedora.
for f in keyboard.png keymap-render.png capslock.png; do
  if [[ -f /usr/share/plymouth/themes/spinner/$f ]]; then
    cp "/usr/share/plymouth/themes/spinner/$f" /usr/share/plymouth/themes/matsu/
  fi
done
mkdir -p /etc/plymouth
printf '%s\n' \
  "# Matsu OS: tela de boot própria. O resto vem de /usr/share/plymouth/plymouthd.defaults." \
  "[Daemon]" "Theme=matsu" > /etc/plymouth/plymouthd.conf
# A tela de boot mora dentro do initramfs, então ele é refeito aqui com o tema
# novo (do mesmo jeito que o Bazzite e o Bluefin fazem).
for kdir in /usr/lib/modules/*/; do
  kver="$(basename "$kdir")"
  [[ -f ${kdir}vmlinuz ]] || continue
  DRACUT_NO_XATTR=1 dracut --no-hostonly --kver "$kver" --reproducible --zstd --add ostree \
    -f "${kdir}initramfs.img"
  chmod 0600 "${kdir}initramfs.img"
  echo "initramfs $kver: $(lsinitrd "${kdir}initramfs.img" 2>/dev/null | grep -c 'plymouth/themes/matsu/' || true) arquivos do tema matsu"
done

# ---------------------------------------------------------------------------
log "Telas de login, bloqueio e sair com a cara do Matsu"
# Essas telas vêm prontas dentro dos programas do KDE; o script troca só o
# desenho das peças que elas dividem (relógio, foto da pessoa e botões).
python3 "$CTX/build_files/telas-kde.py"

log "Limpando"
dnf5 clean all
rm -rf /var/lib/dnf /run/dnf /run/setrans

log "Imagem ${IMAGE_NAME} (${IMAGE_VARIANT}) montada"
