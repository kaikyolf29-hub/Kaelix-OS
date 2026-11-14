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

# Apps do Matsu feitos em QML: som e vídeo (Música, Câmera, Relógio) vêm do Qt Multimedia.
dnf5 -y install --skip-unavailable qt6-qtmultimedia
rpm -q qt6-qtmultimedia || echo "AVISO: sem qt6-qtmultimedia, a Música e a Câmera do Matsu não abrem." >&2

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
# Durante o ano saem atualizações menores: 27.1, 27.2... A versão é a de cima do
# NOVIDADES.md (docs/VERSOES.md), que também vai para o sistema: a janela
# Atualizações e o aviso de atualização (atualizacoes/ajudante.py) mostram o que mudou.
VERSAO="$(python3 /usr/share/matsu/atualizacoes/ajudante.py --arquivo "${CTX}/NOVIDADES.md" versao)"
if [[ $VERSAO != "$EDICAO" && $VERSAO != "$EDICAO".* ]]; then
  echo "ERRO: a versão de cima do NOVIDADES.md ($VERSAO) não é da edição $EDICAO" >&2
  exit 1
fi
MESES=(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro)
HOJE="$(date -u +%-d) de ${MESES[$(( 10#$(date -u +%m) - 1 ))]} de $(date -u +%Y)"
# A versão ainda sem data ("Em preparação") ganha a data da montagem.
sed "0,/^_Em preparação_\$/s//_Montada em ${HOJE}_/" "${CTX}/NOVIDADES.md" > /usr/share/matsu/novidades.md
chmod 0644 /usr/share/matsu/novidades.md
python3 /usr/share/matsu/atualizacoes/ajudante.py --arquivo /usr/share/matsu/novidades.md resumo "$VERSAO" >/dev/null
OWNER="${IMAGE_REGISTRY#*/}"
REPO_URL="https://github.com/${OWNER}/Kaelix-OS"
# O nome do Fedora não aparece para a pessoa: o sistema se apresenta como
# Matsu em tudo (Sobre, menu de boot, terminal, nome do computador). O ID e o
# VERSION_ID continuam os do Fedora, porque programas como o dnf e o toolbox
# conferem a base por eles.
sed -i \
  -e 's/^NAME=.*/NAME="Matsu OS"/' \
  -e "s/^VERSION=.*/VERSION=\"${VERSAO} (Edição ${ANO})\"/" \
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
# Logo do Matsu (o bonsai no ensō) como logo do sistema, por exemplo em "Sobre este sistema".
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
echo "Versão: ${VERSAO} (novidades em /usr/share/matsu/novidades.md)"

mkdir -p /usr/share/matsu
jq -n \
  --arg name "${IMAGE_NAME}" \
  --arg variant "${IMAGE_VARIANT}" \
  --arg registry "${IMAGE_REGISTRY}" \
  --arg build "${BUILD_ID}" \
  --arg fedora "${FEDORA_VERSION}" \
  --arg edicao "${EDICAO}" \
  --arg versao "${VERSAO}" \
  '{"image-name":$name, "image-variant":$variant, "image-registry":$registry,
    "build-id":$build, "fedora-version":$fedora, "edicao":$edicao, "versao":$versao}' \
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
    # As Configurações rápidas e o ciclo dia-noite oferecem estes dois (e não o Breeze).
    kwriteconfig6 --file "$f" --group KDE --key DefaultLightLookAndFeel org.matsu.claro.desktop
    kwriteconfig6 --file "$f" --group KDE --key DefaultDarkLookAndFeel org.matsu.escuro.desktop
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
  cat /usr/share/matsu/barra/comum.js /usr/share/matsu/barra/fusao.js /usr/share/matsu/barra/todas-as-telas.js \
    /usr/share/matsu/barra/papel-de-parede.js \
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
# notificações e o calendário, Meta+B a setinha da bandeja. No KDE o Meta+A é
# de "percorrer as atividades" e o Meta+B de "trocar perfil de energia". O
# serviço de atalhos só lê o arquivo de cada pessoa, nunca o /etc/xdg, então o
# conserto fica no login (plasma-workspace/env/matsu-atalhos.sh) e na garantia
# do começo da sessão (autostart/matsu-atalhos.desktop -> libexec/matsu-atalhos).
test -x /usr/libexec/matsu/matsu-atalhos
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
# Janela de senha do sistema do Matsu (agente do polkit): a peça org.matsu.senha
# compilada na etapa "deco" e o serviço do KDE apontando para o matsu-senha-iniciar,
# que abre a do Matsu e, se ela não conseguir, a do KDE.
if [[ -s /deco/senha/libmatsusenha.so ]]; then
  install -Dm0755 /deco/senha/libmatsusenha.so /usr/lib64/qt6/qml/org/matsu/senha/libmatsusenha.so
  install -Dm0644 /deco/senha/qmldir /usr/lib64/qt6/qml/org/matsu/senha/qmldir
  install -Dm0644 /deco/senha/matsusenha.qmltypes /usr/lib64/qt6/qml/org/matsu/senha/matsusenha.qmltypes
  test -x /usr/libexec/matsu/matsu-senha-iniciar
  test -f /usr/lib/systemd/user/plasma-polkit-agent.service.d/matsu.conf
  echo "Janela de senha do Matsu instalada (agente do KDE fica de reserva)"
else
  rm -f /usr/lib/systemd/user/plasma-polkit-agent.service.d/matsu.conf
  echo "AVISO: sem a peça da janela de senha; fica a do KDE" >&2
fi

# Terminal do Matsu (matsu-terminal), também compilado na etapa "deco": a janela
# de vidro com abas, e dentro dela o terminal do Konsole (a peça konsolepart).
if [[ -s /deco/matsu-terminal ]]; then
  install -Dm0755 /deco/matsu-terminal /usr/bin/matsu-terminal
  rpm -q konsole-part >/dev/null 2>&1 || dnf5 -y install konsole-part
  find /usr/lib64/qt6/plugins -path '*kf6/parts/konsolepart.so' | grep -q . \
    || { echo "ERRO: a peça do Konsole (konsolepart) não está na imagem." >&2; exit 1; }
  echo "matsu-terminal instalado"
else
  echo "ERRO: o matsu-terminal não foi compilado." >&2
  exit 1
fi
# Ele vira o terminal padrão (Ctrl+Alt+T, "Abrir terminal aqui" dos Arquivos...).
# O Konsole continua na imagem (é ele que roda dentro), mas sai do menu e larga o
# Ctrl+Alt+T, para não ter dois terminais iguais nem dois donos do atalho.
kwriteconfig6 --file /etc/xdg/kdeglobals --group General --key TerminalApplication matsu-terminal
kwriteconfig6 --file /etc/xdg/kdeglobals --group General --key TerminalService org.matsu.terminal.desktop
konsole_app=/usr/share/applications/org.kde.konsole.desktop
if [[ -f $konsole_app ]]; then
  sed -i --follow-symlinks '/^X-KDE-Shortcuts=/d' "$konsole_app"
  grep -q '^NoDisplay=' "$konsole_app" || sed -i --follow-symlinks '0,/^\[Desktop Entry\]$/s//[Desktop Entry]\nNoDisplay=true/' "$konsole_app"
fi
# Os atalhos globais de abrir app saem de /usr/share/kglobalaccel: o Konsole põe
# uma cópia dele lá com o Ctrl+Alt+T. Essa cópia sai e entra a do terminal do
# Matsu, senão o Ctrl+Alt+T continua abrindo o Konsole.
rm -f /usr/share/kglobalaccel/org.kde.konsole.desktop
install -d /usr/share/kglobalaccel
ln -sf ../applications/org.matsu.terminal.desktop /usr/share/kglobalaccel/org.matsu.terminal.desktop
grep -q '^X-KDE-Shortcuts=Ctrl+Alt+T$' /usr/share/kglobalaccel/org.matsu.terminal.desktop \
  || { echo "ERRO: o Ctrl+Alt+T do terminal do Matsu não ficou registrado." >&2; exit 1; }
if grep -Rls '^X-KDE-Shortcuts=.*Ctrl+Alt+T' /usr/share/kglobalaccel/ | grep -v org.matsu.terminal; then
  echo "ERRO: outro app ainda segura o Ctrl+Alt+T (acima)." >&2
  exit 1
fi
# Arquivos do Matsu (matsu-arquivos), compilado na etapa "deco": a janela de vidro
# da imagem escolhida, com a lista do Dolphin (a peça dolphinpart) dentro. Vira o
# app de pastas padrão, o "Mostrar na pasta" dos outros apps e o Meta+E; o nome
# Dolphin some do menu, da barra e das buscas.
if [[ -s /deco/matsu-arquivos ]]; then
  install -Dm0755 /deco/matsu-arquivos /usr/bin/matsu-arquivos
  find /usr/lib64/qt6/plugins -path '*kf6/parts/dolphinpart.so' | grep -q . \
    || { echo "ERRO: a peça do Dolphin (dolphinpart) não está na imagem." >&2; exit 1; }
  echo "matsu-arquivos instalado"
else
  echo "ERRO: o matsu-arquivos não foi compilado." >&2
  exit 1
fi
dolphin_app=/usr/share/applications/org.kde.dolphin.desktop
if [[ -f $dolphin_app ]]; then
  sed -i --follow-symlinks '/^X-KDE-Shortcuts=/d' "$dolphin_app"
  grep -q '^NoDisplay=' "$dolphin_app" || sed -i --follow-symlinks '0,/^\[Desktop Entry\]$/s//[Desktop Entry]\nNoDisplay=true/' "$dolphin_app"
fi
rm -f /usr/share/kglobalaccel/org.kde.dolphin.desktop
ln -sf ../applications/org.matsu.arquivos.desktop /usr/share/kglobalaccel/org.matsu.arquivos.desktop
# "Mostrar na pasta" (org.freedesktop.FileManager1): só o nosso atende.
rm -f /usr/share/dbus-1/services/org.kde.dolphin.FileManager1.service
test -f /usr/share/dbus-1/services/org.matsu.arquivos.FileManager1.service
# Loja do Matsu no lugar do Discover, e o Gerenciador de tarefas do Matsu no
# lugar do Monitor do sistema do KDE: os dois do KDE saem do menu, da barra e
# das buscas (continuam na imagem). Os links appstream:// dos outros apps e o
# .flatpakref do botão "Instalar" do site do Flathub abrem na Loja.
test -f /usr/share/applications/org.matsu.loja.desktop
python3 -c "import ast; ast.parse(open('/usr/share/matsu/loja/ajudante.py').read())"
for app in /usr/share/applications/org.kde.discover*.desktop /usr/share/applications/org.kde.plasma-systemmonitor.desktop; do
  [[ -f $app ]] || continue
  grep -q '^NoDisplay=' "$app" || sed -i --follow-symlinks '0,/^\[Desktop Entry\]$/s//[Desktop Entry]\nNoDisplay=true/' "$app"
done
# Apps do KDE que o Matsu já tem do jeito dele saem do menu, da barra e das
# buscas (continuam na imagem para quem chamar pelo nome): Gwenview (Fotos),
# Kate e KWrite (Bloco de notas), KCalc (Calculadora), Elisa (Música), KClock
# (Relógio), Merkuro/KOrganizer (Calendário), KNotes (Notas), Kamoso (Câmera) e
# o firewall-config (Central de segurança). Fica no registro quais existiam.
for nome in org.kde.gwenview org.kde.kate org.kde.kwrite org.kde.kcalc org.kde.elisa org.kde.kclock \
            org.kde.merkuro.calendar org.kde.korganizer org.kde.knotes org.kde.kamoso firewall-config; do
  app="/usr/share/applications/${nome}.desktop"
  [[ -f $app ]] || continue
  echo "Fora do menu (o Matsu tem o dele): ${nome}"
  sed -i --follow-symlinks '/^X-KDE-Shortcuts=/d' "$app"
  grep -q '^NoDisplay=' "$app" || sed -i --follow-symlinks '0,/^\[Desktop Entry\]$/s//[Desktop Entry]\nNoDisplay=true/' "$app"
  rm -f "/usr/share/kglobalaccel/${nome}.desktop"
done
# A tecla Calculadora do teclado abre a Calculadora do Matsu (X-KDE-Shortcuts no .desktop).
install -d /usr/share/kglobalaccel
ln -sf ../applications/org.matsu.calculadora.desktop /usr/share/kglobalaccel/org.matsu.calculadora.desktop
grep -q '^X-KDE-Shortcuts=Calculator$' /usr/share/kglobalaccel/org.matsu.calculadora.desktop \
  || { echo "ERRO: a tecla Calculadora não ficou ligada à Calculadora do Matsu." >&2; exit 1; }
# Pastas abrem nos Arquivos do Matsu, e os pedidos de app na Loja (em todos os
# mimeapps.list que o KDE lê). Os apps do dia a dia do Matsu abrem os arquivos
# deles (o MimeType= de cada .desktop): .ics no Calendário, músicas na Música,
# fotos no Fotos e textos no Bloco de notas.
pares=(inode/directory:org.matsu.arquivos.desktop x-scheme-handler/appstream:org.matsu.loja.desktop
       application/vnd.flatpak.ref:org.matsu.loja.desktop)
for app in calendario musica fotos blocodenotas; do
  atalho=/usr/share/applications/org.matsu.$app.desktop
  [[ -f $atalho ]] || continue
  IFS=';' read -ra tipos <<< "$(sed -n 's/^MimeType=//p' "$atalho" | head -n1)"
  for tipo in "${tipos[@]}"; do
    [[ -n $tipo ]] && pares+=("$tipo:org.matsu.$app.desktop")
  done
done
# Programas baixados (AppImage, programas do Linux e do Windows, .deb, .rpm,
# .jar) abrem pelo aviso da Central de segurança, que confere de onde vieram
# antes de abrir. Os scripts (.sh) continuam abrindo no Bloco de notas.
for tipo in application/vnd.appimage application/x-iso9660-appimage application/x-executable \
            application/x-sharedlib application/x-msdownload application/vnd.microsoft.portable-executable \
            application/x-ms-dos-executable application/x-dosexec application/x-ms-ne-executable \
            application/x-msi application/vnd.debian.binary-package application/x-rpm \
            application/java-archive application/x-makeself; do
  pares+=("$tipo:org.matsu.seguranca.aviso.desktop")
done
echo "Apps padrão do Matsu: ${#pares[@]} tipos de arquivo"
for f in /etc/xdg/mimeapps.list /etc/xdg/kde-mimeapps.list /usr/share/applications/mimeapps.list \
         /usr/share/kde-settings/kde-profile/default/xdg/mimeapps.list \
         /usr/share/kde-settings/kde-profile/default/xdg/kde-mimeapps.list; do
  if [[ $f == /etc/xdg/mimeapps.list || -e $f ]]; then
    for par in "${pares[@]}"; do
      kwriteconfig6 --file "$f" --group "Default Applications" --key "${par%%:*}" "${par#*:}"
      kwriteconfig6 --file "$f" --group "Added Associations" --key "${par%%:*}" "${par#*:};"
    done
    chmod 0644 "$f"
  fi
done
update-desktop-database -q /usr/share/applications 2>/dev/null || true
# Fixados do menu: o Fedora põe Discover, Dolphin, Konsole e KWrite na frente dos
# fixados de toda conta nova (kicker-extra-favoritesrc). No Matsu os fixados são só
# os do menu do Matsu (Arquivos, navegador, Terminal, Loja e Ajustes).
{ find /usr/share /etc -name 'kicker-extra-favoritesrc' 2>/dev/null; echo /etc/xdg/kicker-extra-favoritesrc; } | sort -u | while read -r f; do
  [[ -s $f ]] && echo "kicker-extra-favoritesrc do Fedora ($f): $(tr '\n' ' ' < "$f")"
  printf '[General]\nPrepend=\nAppend=\nIgnoreDefaults=false\n' > "$f"
  chmod 0644 "$f"
done
# Botões da janela do lado esquerdo, nesta ordem: fechar, minimizar, tela cheia.
kwriteconfig6 --file /etc/xdg/kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft XIA
kwriteconfig6 --file /etc/xdg/kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ""
# Alt+Tab como no Windows 11: as janelas em miniatura lado a lado, no vidro do Matsu.
kwriteconfig6 --file /etc/xdg/kwinrc --group TabBox --key LayoutName thumbnail_grid
chmod 0644 /etc/xdg/kdeglobals /etc/xdg/kwinrc

# O terminal do Matsu já nasce com o perfil dele (sem piscar o perfil do Konsole).
kwriteconfig6 --file /etc/xdg/matsu-terminalrc --group "Desktop Entry" --key DefaultProfile MatsuTerminal.profile
chmod 0644 /etc/xdg/matsu-terminalrc
# Konsole (se alguém abrir pelo comando): perfil próprio com vidro, sem barra de
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
# Lista em detalhes como no Windows: sem a setinha de abrir pasta dentro da lista
# (e sem as linhas de árvore que vêm com ela).
kwriteconfig6 --file /etc/xdg/dolphinrc --group DetailsMode --key ExpandableFolders false
# Linhas mais baixas, como na imagem escolhida: ícone pequeno também com miniatura.
kwriteconfig6 --file /etc/xdg/dolphinrc --group DetailsMode --key IconSize 22
kwriteconfig6 --file /etc/xdg/dolphinrc --group DetailsMode --key PreviewSize 22
# Menu do botão direito sem "Atividades" (o Matsu não usa atividades do Plasma).
kwriteconfig6 --file /etc/xdg/kservicemenurc --group Show --key kactivitymanagerd_fileitem_linking_plugin false
chmod 0644 /etc/xdg/kservicemenurc
# Tamanhos como no Windows: "1,2 GB" e "412 MB" (e não "GiB"/"MiB").
kwriteconfig6 --file /etc/xdg/kdeglobals --group Locale --key BinaryUnitDialect 1
chmod 0644 /etc/xdg/konsolerc /etc/xdg/dolphinrc
gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
# Pastas e tipos de arquivo no desenho do Matsu (lavanda, folha com selo): cada
# nome que o Breeze tem vira uma ligação para o desenho da categoria.
python3 "$CTX/build_files/icones-de-arquivo.py"
test -L /usr/share/icons/Matsu/mimetypes/pequeno/video-x-matroska.svg
test -L /usr/share/icons/Matsu-claro/places/scalable/folder-download.svg
# Ícones próprios dos apps do sistema (tema de ícones Matsu). Fica no registro
# qual nome de ícone cada app pede, para conferir que o nosso está cobrindo.
grep -H '^Icon=' /usr/share/applications/org.kde.{dolphin,konsole,discover,plasma-systemmonitor,kwrite,kate,spectacle,gwenview}.desktop \
  /usr/share/applications/{systemsettings,kdesystemsettings}.desktop 2>/dev/null || true
# Dois apps do KDE pedem um ícone que é de ação (tools-report-bug e debug-run
# aparecem no menu Ajuda de todo app): eles ganham o ícone do Matsu direto no
# .desktop, para o menu Ajuda dos outros apps continuar certo.
for par in org.kde.drkonqi.coredump.gui:matsu-ajuste-falhas org.kde.kdebugsettings:matsu-ajuste-depuracao; do
  app="/usr/share/applications/${par%%:*}.desktop"
  if [[ -f $app ]]; then sed -i --follow-symlinks "s/^Icon=.*/Icon=${par#*:}/" "$app"; fi
done
# Ícones das Configurações com nome de ação (visual/icones/ajustes.js): no
# tamanho de menu eles apontam para o original do Breeze. Se o Breeze tirar
# algum, a ligação quebrada sai (fica o quadrado do Matsu em todo tamanho).
for f in /usr/share/icons/Matsu{,-claro}/actions/16/*.svg; do
  if [[ -L $f && ! -e $f ]]; then echo "aviso: o Breeze não tem mais $(readlink "$f"), tirando a ligação"; rm -f "$f"; fi
done
test -f /usr/share/icons/Matsu/apps/scalable/matsu-ajuste-som.svg

# ---------------------------------------------------------------------------
# Partes com arquivo próprio: cada uma instala os pacotes, liga os serviços e
# confere o que precisa (build_files/<parte>.sh, rodada aqui com o mesmo CTX).
for parte in jogos seguranca; do
  roteiro="${CTX}/build_files/${parte}.sh"
  if [[ -f $roteiro ]]; then
    log "Parte: ${parte}"
    env CTX="$CTX" IMAGE_VARIANT="$IMAGE_VARIANT" IMAGE_REGISTRY="$IMAGE_REGISTRY" bash "$roteiro"
  fi
done

# ---------------------------------------------------------------------------
log "Ligando os serviços do Matsu"
# Flathub e os apps Flatpak que já vêm (Heroic, Lutris, OBS, Kdenlive...).
systemctl enable matsu-flatpak-setup.service
# Central de jogos: o ajudante que liga o perfil gráfico e a sobreposição
# quando um jogo abre (e desfaz tudo quando ele fecha), na sessão de cada pessoa.
systemctl --global enable matsu-jogos.service
chmod 0755 /usr/libexec/matsu/matsu-jogos-placa
# Barra em cada tela: no começo da sessão e sempre que um monitor é ligado (o
# script "matsu-telas" do KWin chama o serviço), põe a barra nas telas sem barra.
systemctl --global enable matsu-telas.service
kwriteconfig6 --file /etc/xdg/kwinrc --group Plugins --key matsu-telasEnabled true
# Apps do Matsu feitos em QML (Relógio, Calendário, Música...): cada pasta com
# Main.qml tem o atalho org.matsu.<app>.desktop, e os ajudantes em Python dela
# são lidos sem erro. Os alarmes e lembretes criam as unidades do systemd do
# próprio usuário na hora (nada global aqui).
for main in /usr/share/matsu/*/Main.qml; do
  app="$(basename "$(dirname "$main")")"
  if [[ ! -f /usr/share/applications/org.matsu.$app.desktop ]]; then
    echo "ERRO: /usr/share/matsu/$app não tem o atalho org.matsu.$app.desktop" >&2
    exit 1
  fi
done
for py in /usr/share/matsu/*/*.py; do
  python3 -c "import ast, sys; ast.parse(open(sys.argv[1], encoding='utf-8').read(), sys.argv[1])" "$py"
done
find /usr/share/matsu -name __pycache__ -type d -prune -exec rm -rf {} +
for pacote in libnotify pipewire-utils sound-theme-freedesktop python3-dbus python3-gobject ffmpeg; do
  rpm -q "$pacote" >/dev/null 2>&1 || rpm -q --whatprovides "$pacote" >/dev/null 2>&1 \
    || echo "aviso: falta $pacote (som, avisos, controles de mídia ou a onda da Música ficam mais simples)"
done

# Aviso de atualização do Matsu: depois de atualizar mostra o que mudou, avisa
# quando sai versão nova no canal (com o botão "Atualizar") e quando há apps da
# Loja com atualização. O aviso do Discover (que abre o Discover escondido) sai.
test -f /usr/share/applications/org.matsu.atualizacoes.desktop
test -f /usr/share/matsu/atualizacoes/Main.qml
command -v skopeo >/dev/null || echo "aviso: sem o skopeo, o aviso de versão nova não consegue ler o canal"
systemctl --global enable matsu-novidades.timer
aviso_discover=/etc/xdg/autostart/org.kde.discover.notifier.desktop
if [[ -f $aviso_discover ]] && ! grep -q '^Hidden=true' "$aviso_discover"; then
  sed -i --follow-symlinks '0,/^\[Desktop Entry\]$/s//[Desktop Entry]\nHidden=true/' "$aviso_discover"
fi

# ---------------------------------------------------------------------------
log "Tela de boot do Matsu"
# Tema próprio do Plymouth (visual/boot/gerar.py): o logo do Matsu no fundo
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
# A tela de bloqueio inteira no jeito do Mac (hora grande, foto, senha em pílula):
# o MatsuBloco.qml veio do system_files; o script liga ele no LockScreenUi do KDE.
# O mesmo script põe a tela de sair do Matsu (Desligar, Reiniciar, Sair).
python3 "$CTX/build_files/telas-matsu.py"

log "Tipos de arquivo em português"
# Depois de todos os pacotes (cada um pode trazer tipos novos).
# Nomes dos tipos de arquivo em português ("Pasta", e não "Folder"): o
# shared-mime-info grava "pt-BR" e o Qt procura "pt_BR" (tipos-pt-br.py).
python3 "$CTX/build_files/tipos-pt-br.py"
update-mime-database /usr/share/mime
grep -q 'xml:lang="pt_BR">Pasta<' /usr/share/mime/inode/directory.xml \
  || { echo "ERRO: o tipo pasta continua sem nome em português." >&2; exit 1; }

log "Limpando"
dnf5 clean all
rm -rf /var/lib/dnf /run/dnf /run/setrans

log "Imagem ${IMAGE_NAME} (${IMAGE_VARIANT}) montada"
