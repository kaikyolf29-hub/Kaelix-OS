#!/usr/bin/bash
# Junta numa pasta tudo o que entra no updates.img da ISO: a cara do Matsu no
# instalador avançado (installer/marca) e as telas do instalador do Matsu, com
# os ícones e o logo tirados do próprio sistema (assim ficam sempre iguais).
#
# Uso: installer/montar-updates.sh <pasta>
# O fluxo "Montar ISO" ainda põe na pasta o .buildstamp, as fontes e o
# imagem.json (o tamanho da imagem, para a barra do download).
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DESTINO="$1"
TELAS="$DESTINO/usr/share/matsu-instalador"
ICONES="$RAIZ/system_files/usr/share/icons/Matsu-claro"

rm -rf "$DESTINO"
cp -a "$RAIZ/installer/marca" "$DESTINO"
mkdir -p "$TELAS/icones"
for nome in certo voltar disco rede-cabo rede-desconectada wifi-0 wifi-1 wifi-2 wifi-3 \
            alerta info perfil-padrao recarregar engrenagem; do
  arquivo="$(find "$ICONES" -name "matsu-$nome-symbolic.svg" | head -1)"
  [[ -n $arquivo ]] || { echo "falta o ícone matsu-$nome-symbolic.svg" >&2; exit 1; }
  cp "$arquivo" "$TELAS/icones/"
done
cp "$RAIZ/system_files/usr/share/pixmaps/matsu-logo.svg" "$TELAS/icones/logo.svg"
tr -dc '0-9' < "$RAIZ/EDICAO" > "$TELAS/edicao"
find "$DESTINO" -name '__pycache__' -prune -exec rm -rf {} +
