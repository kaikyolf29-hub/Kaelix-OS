#!/usr/bin/bash
# Matsu OS — Central de segurança (parte do build.sh, roda dentro da montagem).
#
# Instala o antivírus (ClamAV do Fedora), deixa o firewall do Matsu como padrão
# (zonas próprias do firewalld, a "Rede pública" para toda rede nova), liga os
# serviços do escudo e confere os arquivos da Central (docs/SEGURANCA.md).
# Os arquivos em si (app, serviços, polkit, zonas) já foram copiados de
# system_files/ pelo build.sh antes desta parte.
set -euo pipefail
: "${CTX:?}" "${IMAGE_VARIANT:?}" "${IMAGE_REGISTRY:?}"

log() { printf '\n==> %s\n' "$*"; }
erro() { echo "ERRO: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
log "Segurança: antivírus (ClamAV)"
# clamav (o motor e o clamscan), clamd (o serviço, que o escudo usa pelo soquete)
# e clamav-update (o freshclam, que baixa a lista de ameaças; no Fedora 44 o
# pacote se chama clamav-freshclam e o dnf aceita os dois nomes). Sem o clamav-data:
# a lista (~230 MB) não vai dentro da imagem, ela é baixada no primeiro uso com
# internet e atualizada a cada 4 horas (matsu-escudo-atualizar.timer).
dnf5 -y install --setopt=install_weak_deps=False clamav clamd clamav-update
rpm -q clamav clamd
rpm -qf /usr/bin/freshclam || erro "o freshclam (clamav-update/clamav-freshclam) não entrou"
if rpm -q clamav-data >/dev/null 2>&1; then
  # Veio como dependência: a lista do pacote fica fora da imagem (o freshclam baixa a atual).
  echo "aviso: o clamav-data entrou junto; tirando a lista dele da imagem (ela é baixada no primeiro uso)"
  rm -f /var/lib/clamav/*.cvd /var/lib/clamav/*.cld
fi
for programa in /usr/sbin/clamd /usr/bin/freshclam /usr/bin/clamscan; do
  [[ -x $programa ]] || erro "falta $programa (ClamAV)"
done
echo "ClamAV: $(/usr/sbin/clamd --version 2>/dev/null || echo '?')"
# O freshclam roda como clamupdate (o usuário que o pacote do Fedora cria). O clamd
# do escudo usa um usuário criado na hora pelo systemd (DynamicUser), sem depender
# dos nomes do pacote.
if ! getent passwd clamupdate >/dev/null; then
  echo "aviso: o pacote não criou o usuário clamupdate; criando pelo sysusers do Matsu"
  printf '%s\n' "# Central de segurança do Matsu: dono da lista de ameaças (/var/lib/clamav)." \
    'u clamupdate - "ClamAV: lista de ameaças" /var/lib/clamav -' > /usr/lib/sysusers.d/matsu-escudo.conf
  systemd-sysusers /usr/lib/sysusers.d/matsu-escudo.conf
fi
getent passwd clamupdate
# Só o escudo do Matsu baixa a lista e liga o clamd (sob demanda): as unidades
# do Fedora ficam desligadas para não haver dois freshclam nem um clamd sempre ligado.
for unidade in clamav-freshclam.service clamav-clamonacc.service clamd@scan.service; do
  if systemctl list-unit-files "$unidade" >/dev/null 2>&1; then
    systemctl disable "$unidade" >/dev/null 2>&1 || true
  fi
done
for f in /usr/lib/systemd/system/clam*; do [[ -e $f ]] && echo "  unidade do Fedora: $f"; done
command -v setsebool >/dev/null || echo "aviso: sem setsebool; com SELinux o clamd usa o fluxo (INSTREAM) no lugar do descritor"

# ---------------------------------------------------------------------------
log "Segurança: firewall (firewalld) com as zonas do Matsu"
# O Fedora já usa o firewalld (nftables por baixo); o UFW junto quebraria os dois.
# A Kinoite vem com a zona FedoraWorkstation, que deixa as portas 1025-65535
# abertas para qualquer rede. No Matsu toda rede nova começa como "Rede pública"
# (matsu-publica: nada entra) e a pessoa troca para "Rede de casa" com um clique.
command -v firewall-offline-cmd >/dev/null || dnf5 -y install firewalld
for zona in matsu-publica matsu-casa; do
  arquivo=/usr/lib/firewalld/zones/$zona.xml
  [[ -f $arquivo ]] || erro "falta a zona $arquivo"
  python3 -c "import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])" "$arquivo"
  # Serviço que esta versão do firewalld não conhece derrubaria a zona inteira: sai da zona.
  while read -r servico; do
    if [[ ! -f /usr/lib/firewalld/services/$servico.xml ]]; then
      echo "aviso: o firewalld desta versão não tem o serviço $servico; ele sai da zona $zona"
      sed -i "/<service name=\"$servico\"\/>/d" "$arquivo"
    fi
  done < <(sed -n 's/.*<service name="\([^"]*\)".*/\1/p' "$arquivo")
done
echo "Zona padrão antes: $(sed -n 's/^DefaultZone=//p' /etc/firewalld/firewalld.conf 2>/dev/null || echo '?')"
firewall-offline-cmd --set-default-zone=matsu-publica || echo "aviso: firewall-offline-cmd não trocou a zona padrão"
zona_padrao() {
  firewall-offline-cmd --get-default-zone 2>/dev/null \
    || sed -n 's/^DefaultZone=//p' /etc/firewalld/firewalld.conf 2>/dev/null || true
}
if [[ "$(zona_padrao)" != matsu-publica ]]; then
  # Plano B: o firewalld.conf de /etc (copiado do padrão de /usr/lib, se o de /etc não existir).
  echo "aviso: trocando a zona padrão direto no /etc/firewalld/firewalld.conf"
  mkdir -p /etc/firewalld
  if [[ ! -f /etc/firewalld/firewalld.conf && -f /usr/lib/firewalld/firewalld.conf ]]; then
    cp /usr/lib/firewalld/firewalld.conf /etc/firewalld/firewalld.conf
  fi
  if grep -q '^DefaultZone=' /etc/firewalld/firewalld.conf 2>/dev/null; then
    sed -i 's/^DefaultZone=.*/DefaultZone=matsu-publica/' /etc/firewalld/firewalld.conf
  else
    echo 'DefaultZone=matsu-publica' >> /etc/firewalld/firewalld.conf
  fi
fi
[[ "$(zona_padrao)" == matsu-publica ]] || erro "a zona padrão ficou '$(zona_padrao)', não matsu-publica"
echo "Zona padrão agora: matsu-publica"
firewall-offline-cmd --info-zone=matsu-casa || true
systemctl enable firewalld.service

# ---------------------------------------------------------------------------
log "Segurança: serviços, polkit e o app"
# Lista de ameaças: 10 minutos depois de ligar e a cada 4 horas.
systemctl enable matsu-escudo-atualizar.timer
# Escudo em tempo real: um por pessoa, na sessão de cada uma.
systemctl --global enable matsu-escudo.service
for f in /usr/lib/systemd/system/matsu-escudo-clamd.service /usr/lib/systemd/system/matsu-escudo-atualizar.service \
         /usr/lib/systemd/system/matsu-escudo-atualizar.timer /usr/lib/systemd/user/matsu-escudo.service \
         /usr/share/matsu/seguranca/clamd.conf /usr/share/matsu/seguranca/freshclam.conf \
         /usr/share/polkit-1/rules.d/50-matsu-seguranca.rules /usr/share/polkit-1/actions/org.matsu.seguranca.policy \
         /usr/share/applications/org.matsu.seguranca.desktop /usr/share/applications/org.matsu.seguranca.aviso.desktop \
         /usr/share/plasma/plasmoids/org.matsu.seguranca/metadata.json; do
  [[ -f $f ]] || erro "falta $f"
done
for f in /usr/libexec/matsu/matsu-seguranca /usr/libexec/matsu/matsu-seguranca-fsck; do
  [[ -x $f ]] || erro "$f não é executável"
done
python3 -c "import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])" /usr/share/polkit-1/actions/org.matsu.seguranca.policy
for py in nucleo sistema ajudante escudo; do
  python3 -c "import ast, sys; ast.parse(open(sys.argv[1], encoding='utf-8').read(), sys.argv[1])" \
    "/usr/share/matsu/seguranca/$py.py"
done
# O ajudante responde mesmo sem o escudo rodando (é o que a bandeja chama).
HOME=/tmp/matsu-seguranca-teste python3 -I -S /usr/share/matsu/seguranca/ajudante.py estado \
  | python3 -c "import json, sys; print('Central de segurança: estado', json.load(sys.stdin)['geral'])" \
  || echo "aviso: o ajudante da Central de segurança não respondeu na montagem (conferir no sistema)"
rm -rf /tmp/matsu-seguranca-teste
if command -v systemd-analyze >/dev/null; then
  systemd-analyze verify --man=no \
    /usr/lib/systemd/system/matsu-escudo-clamd.service /usr/lib/systemd/system/matsu-escudo-atualizar.service 2>&1 | head -20 || true
fi
# O tratador dos executáveis baixados entra no cache de tipos de arquivo.
update-desktop-database -q /usr/share/applications 2>/dev/null || true
grep -q 'org.matsu.seguranca.aviso.desktop' /usr/share/applications/mimeinfo.cache \
  || echo "aviso: o tratador org.matsu.seguranca.aviso.desktop não entrou no mimeinfo.cache"
echo "Central de segurança pronta (zona padrão matsu-publica, escudo e lista de ameaças ligados)"
