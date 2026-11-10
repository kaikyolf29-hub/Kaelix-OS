#!/usr/bin/bash
# Kaelix OS — script que monta a imagem (roda dentro do Containerfile).
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
log "Copiando os arquivos próprios do Kaelix para o sistema"
cp -a "${CTX}/system_files/." /
chmod 0755 /usr/bin/kaelix /usr/libexec/kaelix/*

# ---------------------------------------------------------------------------
log "Instalando pacotes"
# Jogos: GameMode (desempenho) e MangoHud (números na tela), 64 e 32 bits.
# Programação: compiladores, Node, Python e Distrobox.
# Utilidades usadas pelo comando kaelix: jq, pciutils e kdialog.
dnf5 -y install \
  gamemode mangohud \
  distrobox podman \
  git gcc gcc-c++ make cmake \
  nodejs npm python3 python3-pip \
  jq pciutils kdialog \
  fastfetch

dnf5 -y install --skip-unavailable gamemode.i686 mangohud.i686

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
log "Colocando o nome Kaelix OS no sistema"
OWNER="${IMAGE_REGISTRY#*/}"
REPO_URL="https://github.com/${OWNER}/kaelix-os"
# O ID continua "fedora" para não quebrar programas que conferem a base.
sed -i \
  -e 's/^NAME=.*/NAME="Kaelix OS"/' \
  -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Kaelix OS (base Fedora ${FEDORA_VERSION})\"/" \
  -e 's/^VARIANT=.*/VARIANT="Kaelix OS"/' \
  -e 's/^VARIANT_ID=.*/VARIANT_ID=kaelix/' \
  -e "s|^HOME_URL=.*|HOME_URL=\"${REPO_URL}\"|" \
  -e "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"${REPO_URL}/issues\"|" \
  /usr/lib/os-release
grep -q '^VARIANT_ID=' /usr/lib/os-release || echo 'VARIANT_ID=kaelix' >> /usr/lib/os-release

mkdir -p /usr/share/kaelix
jq -n \
  --arg name "${IMAGE_NAME}" \
  --arg variant "${IMAGE_VARIANT}" \
  --arg registry "${IMAGE_REGISTRY}" \
  --arg build "${BUILD_ID}" \
  --arg fedora "${FEDORA_VERSION}" \
  '{"image-name":$name, "image-variant":$variant, "image-registry":$registry,
    "build-id":$build, "fedora-version":$fedora}' \
  > /usr/share/kaelix/image-info.json

# ---------------------------------------------------------------------------
log "Configurando a verificação de assinatura das atualizações"
# A máquina só aceita imagens do Kaelix assinadas com a chave do criador.
install -Dm0644 "${CTX}/cosign.pub" /etc/pki/containers/kaelix-os.pub

for img in kaelix-os kaelix-os-nvidia; do
  tmp=$(mktemp)
  jq --arg scope "${IMAGE_REGISTRY}/${img}" \
    '.transports.docker[$scope] = [{
        "type": "sigstoreSigned",
        "keyPath": "/etc/pki/containers/kaelix-os.pub",
        "signedIdentity": {"type": "matchRepository"}
     }]' /etc/containers/policy.json > "${tmp}"
  install -m0644 "${tmp}" /etc/containers/policy.json
  rm -f "${tmp}"
done

cat > /etc/containers/registries.d/kaelix-os.yaml <<EOF
docker:
  ${IMAGE_REGISTRY}:
    use-sigstore-attachments: true
EOF

# ---------------------------------------------------------------------------
log "Ligando os serviços do Kaelix"
# Flathub e os apps Flatpak que já vêm (Heroic, Lutris, OBS, Kdenlive...).
systemctl enable kaelix-flatpak-setup.service

# ---------------------------------------------------------------------------
log "Limpando"
dnf5 clean all
rm -rf /var/lib/dnf

log "Imagem ${IMAGE_NAME} (${IMAGE_VARIANT}) montada"
