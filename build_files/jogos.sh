#!/usr/bin/bash
# Matsu OS — parte "jogos" da montagem da imagem (o build.sh roda este arquivo
# depois de copiar o system_files e de configurar a assinatura).
#
# O que fica garantido aqui, cada coisa com a conferência no registro da montagem:
#   1. a camada gráfica: Mesa (AMD e Intel) e Vulkan em 64 e 32 bits, as
#      ferramentas que a Central de jogos usa para mostrar o driver (vulkaninfo,
#      glxinfo) e, na variante nvidia, as bibliotecas de 32 bits da NVIDIA;
#   2. o ntsync (Wine e Proton novos) carregado no boot, com acesso para a pessoa;
#   3. controles: regras de acesso (steam-devices, game-devices-udev) e o
#      Bluetooth do jeito que os controles gostam (/etc/bluetooth/main.conf);
#   4. o atalho Meta+Alt+F, que mostra e esconde o FPS no jogo;
#   5. a política de assinatura aceitando as duas imagens (com e sem NVIDIA),
#      porque a Central oferece a troca entre elas.
# Detalhes e o porquê de cada escolha: docs/JOGOS.md.
set -euo pipefail

: "${CTX:?}" "${IMAGE_VARIANT:?}" "${IMAGE_REGISTRY:?}"

passo() { printf '\n--> Jogos: %s\n' "$*"; }
aviso() { echo "AVISO: $*" >&2; }

# A versão de cada pacote (ou "não instalado"), uma linha cada, para o registro.
versoes() {
  local p v
  for p in "$@"; do
    v="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$p" 2>/dev/null)" || v="não instalado"
    printf '    %-28s %s\n' "$p" "$v"
  done
}

# ---------------------------------------------------------------------------
passo "Mesa e Vulkan, 64 e 32 bits"
# Os jogos do Windows (Proton) e muitos jogos antigos são de 32 bits: sem o
# Vulkan e o OpenGL de 32 bits eles nem abrem. A base (Kinoite) já traz quase
# tudo de 64 bits; o que faltar entra aqui. --skip-broken: se um pacote de 32
# bits não casar com a versão do de 64 (o Fedora às vezes publica um antes do
# outro), a montagem segue e o registro mostra o que ficou de fora.
dnf5 -y install --skip-unavailable --skip-broken \
  mesa-vulkan-drivers mesa-dri-drivers mesa-libGL mesa-libEGL vulkan-loader \
  mesa-vulkan-drivers.i686 mesa-dri-drivers.i686 mesa-libGL.i686 mesa-libEGL.i686 vulkan-loader.i686 \
  vulkan-tools glx-utils
versoes mesa-vulkan-drivers.x86_64 mesa-vulkan-drivers.i686 mesa-dri-drivers.x86_64 mesa-dri-drivers.i686 \
  vulkan-loader.x86_64 vulkan-loader.i686 vulkan-tools glx-utils
echo "    Drivers Vulkan (ICD): $(find /usr/share/vulkan/icd.d -name '*.json' -printf '%f ' 2>/dev/null)"
echo "    Camadas Vulkan automáticas: $(find /usr/share/vulkan/implicit_layer.d -name '*.json' -printf '%f ' 2>/dev/null)"
[[ -e /usr/lib/libvulkan.so.1 ]] || aviso "sem o Vulkan de 32 bits (/usr/lib/libvulkan.so.1): jogos de 32 bits não abrem"
compgen -G '/usr/share/vulkan/icd.d/*.i686.json' >/dev/null \
  || aviso "sem driver Vulkan de 32 bits do Mesa (*.i686.json em /usr/share/vulkan/icd.d)"
compgen -G '/usr/share/vulkan/implicit_layer.d/MangoHud*.json' >/dev/null \
  || aviso "o MangoHud não deixou a camada Vulkan: a sobreposição não vai aparecer nos jogos"
command -v vulkaninfo >/dev/null || aviso "sem o vulkaninfo: a página Drivers mostra o Vulkan pelos arquivos ICD"
# Para o registro: o anti-lag da AMD (VK_AMD_anti_lag) chega com o RADV do Mesa
# 26.3; o vkd3d-proton (DirectX 12 pelo Proton) usa sozinho quando o driver tem.
echo "    Mesa: $(rpm -q --qf '%{VERSION} (%{ARCH})\n' mesa-vulkan-drivers 2>/dev/null | paste -sd ' ' || echo '?')"

if [[ $IMAGE_VARIANT == nvidia ]]; then
  passo "driver da NVIDIA (só conferência: ele vem da base kinoite-nvidia)"
  rpm -qa 2>/dev/null | grep -Ei '^(nvidia|kmod-nvidia|libnvidia|xorg-x11-drv-nvidia)' | sort | sed 's/^/    /' || true
  for f in /usr/lib64/libGLX_nvidia.so.0 /usr/lib/libGLX_nvidia.so.0 /usr/lib64/libnvidia-glcore.so.* \
           /usr/lib/libnvidia-glcore.so.* /usr/share/vulkan/icd.d/nvidia_icd*.json; do
    [[ -e $f ]] && echo "    ok: $f"
  done
  if [[ -e /usr/lib/libGLX_nvidia.so.0 ]]; then
    echo "    Bibliotecas de 32 bits da NVIDIA: presentes"
  else
    aviso "sem as bibliotecas de 32 bits da NVIDIA (/usr/lib/libGLX_nvidia.so.0): jogos de 32 bits não usam a placa"
  fi
fi

# ---------------------------------------------------------------------------
passo "ntsync (Wine e Proton novos)"
# O módulo existe desde o Linux 6.14. O arquivo de carregar no boot vem do
# system_files (usr/lib/modules-load.d/matsu-jogos-ntsync.conf) e a regra de
# acesso também (usr/lib/udev/rules.d/70-matsu-jogos-ntsync.rules). Se o
# kernel da imagem não tiver o módulo, o arquivo sai (senão o boot registra erro).
tem_ntsync=0
for kdir in /usr/lib/modules/*/; do
  kver="$(basename "$kdir")"
  if [[ -n "$(find "$kdir" -name 'ntsync.ko*' -print -quit 2>/dev/null)" ]] \
     || grep -qs '/ntsync\.ko' "${kdir}modules.builtin"; then
    tem_ntsync=1
    echo "    $kver: ntsync presente"
  else
    echo "    $kver: sem ntsync"
  fi
done
if (( tem_ntsync )); then
  test -f /usr/lib/modules-load.d/matsu-jogos-ntsync.conf
  test -f /usr/lib/udev/rules.d/70-matsu-jogos-ntsync.rules
else
  rm -f /usr/lib/modules-load.d/matsu-jogos-ntsync.conf
  aviso "o kernel da imagem não tem o ntsync; os jogos usam o jeito antigo (esync/fsync)"
fi

# ---------------------------------------------------------------------------
passo "controles (PlayStation, Xbox, Switch) e Bluetooth"
# Regras de acesso: a Steam lê os controles direto (hidraw) pelas regras do
# steam-devices (instalado no build.sh); o game-devices-udev cobre mais
# controles (8BitDo, Switch, clones), se o Fedora tiver.
dnf5 -y install --skip-unavailable game-devices-udev
versoes steam-devices game-devices-udev bluez
echo "    Regras: $(find /usr/lib/udev/rules.d \( -name '*steam*' -o -name '*game*' -o -name '*controller*' \) -printf '%f ' 2>/dev/null)"
rpm -q steam-devices >/dev/null 2>&1 || aviso "sem o steam-devices: a Steam pode não reconhecer os controles"
# Drivers de fora do kernel para os controles Xbox (só registro: o kernel já
# tem o xpad e o hid-microsoft; aqui nada é compilado).
rpm -qa 2>/dev/null | grep -Ei 'xpadneo|xone' | sed 's/^/    pacote: /' || true
for kdir in /usr/lib/modules/*/; do
  for m in xpadneo hid-xpadneo xone xone-gip xpad hid-playstation hid-sony hid-nintendo hid-microsoft; do
    f="$(find "$kdir" -name "${m}.ko*" -print -quit 2>/dev/null)"
    [[ -n $f ]] && echo "    $(basename "$kdir"): ${m}"
  done
done

# O jeito do Bluetooth que os controles gostam. O BlueZ não tem pasta de
# arquivos extras, então as chaves vão no próprio main.conf (a linha comentada
# do Fedora vira a ativa):
#   FastConnectable     o controle ligado acha o computador mais rápido (gasta
#                       um pouco mais de energia no adaptador);
#   JustWorksRepairing  o controle que perdeu o pareamento (usado no console e
#                       trazido de volta) pareia de novo sem pedir confirmação;
#   Reconnect*          o controle que caiu tenta voltar sozinho (7 tentativas,
#                       cada vez esperando mais).
ini() { # ini <arquivo> <seção> <chave> <valor>
  python3 - "$@" <<'PY'
import re
import sys

arquivo, secao, chave, valor = sys.argv[1:]
try:
    linhas = open(arquivo, encoding="utf-8").read().splitlines()
except FileNotFoundError:
    linhas = []
nova = f"{chave} = {valor}"
inicio = next((i for i, l in enumerate(linhas) if l.strip() == f"[{secao}]"), None)
if inicio is None:
    linhas += ["", f"[{secao}]", nova]
else:
    fim = next((i for i in range(inicio + 1, len(linhas)) if re.match(r"\s*\[", linhas[i])), len(linhas))
    ativa = [i for i in range(inicio + 1, fim) if re.match(rf"\s*{re.escape(chave)}\s*=", linhas[i])]
    comentada = [i for i in range(inicio + 1, fim) if re.match(rf"\s*#\s*{re.escape(chave)}\s*=", linhas[i])]
    if ativa:
        linhas[ativa[0]] = nova
    elif comentada:
        linhas[comentada[-1]] = nova
    else:
        linhas.insert(inicio + 1, nova)
with open(arquivo, "w", encoding="utf-8") as f:
    f.write("\n".join(linhas) + "\n")
PY
}
bt=/etc/bluetooth/main.conf
mkdir -p /etc/bluetooth
ini "$bt" General FastConnectable true
ini "$bt" General JustWorksRepairing always
ini "$bt" Policy AutoEnable true
ini "$bt" Policy ReconnectAttempts 7
ini "$bt" Policy ReconnectIntervals 1,2,4,8,16,32,64
chmod 0644 "$bt"
grep -E '^(FastConnectable|JustWorksRepairing|AutoEnable|ReconnectAttempts|ReconnectIntervals) =' "$bt" | sed 's/^/    /'
[[ "$(grep -c '^FastConnectable = true$' "$bt")" == 1 ]] || { echo "ERRO: o main.conf do Bluetooth não ficou certo." >&2; exit 1; }

# ---------------------------------------------------------------------------
passo "atalho do FPS no jogo (Meta+Alt+F)"
# O mesmo liga e desliga da página Sobreposição e da Central de controle: muda a
# configuração e o MangoHud do jogo aberto relê o arquivo na hora. É um atalho
# do KDE (funciona com o jogo em tela cheia) e a pessoa pode trocar a tecla nas
# Configurações do sistema > Atalhos. Os atalhos de abrir programa saem de
# /usr/share/kglobalaccel (como o Ctrl+Alt+T do terminal, no build.sh).
test -f /usr/share/matsu/jogos/ajudante.py
cat > /usr/share/applications/org.matsu.jogos.fps.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Show or hide in-game FPS
Name[pt_BR]=Mostrar ou esconder o FPS no jogo
Name[pt]=Mostrar ou esconder o FPS no jogo
Comment=The Game Center overlay (FPS, CPU, GPU) on top of the game
Comment[pt_BR]=A sobreposição da Central de jogos (FPS, CPU, GPU) em cima do jogo
Comment[pt]=A sobreposição da Central de jogos (FPS, CPU, GPU) em cima do jogo
Icon=org.matsu.jogos
Exec=/usr/bin/python3 -I -S /usr/share/matsu/jogos/ajudante.py fps alternar --avisar
Terminal=false
NoDisplay=true
StartupNotify=false
X-KDE-Shortcuts=Meta+Alt+F
EOF
chmod 0644 /usr/share/applications/org.matsu.jogos.fps.desktop
install -d /usr/share/kglobalaccel
ln -sf ../applications/org.matsu.jogos.fps.desktop /usr/share/kglobalaccel/org.matsu.jogos.fps.desktop
grep -q '^X-KDE-Shortcuts=Meta+Alt+F$' /usr/share/kglobalaccel/org.matsu.jogos.fps.desktop \
  || { echo "ERRO: o atalho Meta+Alt+F do FPS não ficou registrado." >&2; exit 1; }
if grep -RlsE '^X-KDE-Shortcuts=(.*,)?Meta\+Alt\+F(,|$)' /usr/share/kglobalaccel/ | grep -v org.matsu.jogos.fps; then
  echo "ERRO: outro app já segura o Meta+Alt+F (acima)." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
passo "assinatura das duas imagens (com e sem NVIDIA)"
# A página Drivers oferece trocar de matsu-os para matsu-os-nvidia (e voltar)
# no mesmo canal; a troca só passa se a política aceitar as duas, assinadas.
for img in matsu-os matsu-os-nvidia; do
  if jq -e --arg s "${IMAGE_REGISTRY}/${img}" '.transports.docker[$s][0].type == "sigstoreSigned"' \
       /etc/containers/policy.json >/dev/null; then
    echo "    ${IMAGE_REGISTRY}/${img}: assinatura exigida"
  else
    echo "ERRO: a política de assinatura não cobre ${IMAGE_REGISTRY}/${img}." >&2
    exit 1
  fi
done

passo "pronto (variante ${IMAGE_VARIANT})"
