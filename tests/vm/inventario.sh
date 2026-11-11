#!/usr/bin/bash
# Inventário dos ícones da imagem (roda dentro da imagem do Matsu, no GitHub):
# cada app que aparece no menu, o ícone que ele pede e de qual tema o ícone vem;
# e os ícones das Configurações do sistema (categorias e páginas). Serve para
# achar ícone genérico ou feio que ainda não tem a versão do Matsu.
set -u

# De qual tema vem um ícone: Matsu, breeze, hicolor ou "FALTA".
tema_do_icone() {
  local nome="$1" t
  [[ $nome == /* ]] && { echo "caminho"; return; }
  for t in Matsu breeze breeze-dark hicolor; do
    if find "/usr/share/icons/$t" \( -name "$nome.svg" -o -name "$nome.png" -o -name "$nome.svgz" \) -print -quit 2>/dev/null | grep -q .; then
      echo "$t"; return
    fi
  done
  [[ -n $(find /usr/share/pixmaps -name "$nome.*" -print -quit 2>/dev/null) ]] && { echo pixmaps; return; }
  echo "FALTA"
}

echo "== Apps que aparecem no menu (arquivo | nome | ícone | tema)"
for f in /usr/share/applications/*.desktop; do
  awk -F= '
    /^\[/ { sec = $0; next }
    sec != "[Desktop Entry]" { next }
    $1 == "Name" { n = substr($0, 6) } $1 == "Name[pt_BR]" { p = substr($0, 13) }
    $1 == "Icon" { i = substr($0, 6) } $1 == "NoDisplay" { nd = $2 } $1 == "Hidden" { h = $2 }
    $1 == "OnlyShowIn" { o = $2 } $1 == "NotShowIn" { x = $2 } $1 == "Type" { t = $2 }
    END {
      if (t != "Application" || nd == "true" || h == "true") exit
      if (o != "" && o !~ /KDE/) exit
      if (x ~ /KDE/) exit
      print (p != "" ? p : n) "|" i
    }' "$f" | while IFS='|' read -r nome icone; do
      printf '%s | %s | %s | %s\n' "${f##*/}" "$nome" "$icone" "$(tema_do_icone "$icone")"
    done
done

echo
echo "== Categorias das Configurações do sistema (arquivo | nome | ícone | tema)"
for f in /usr/share/systemsettings/categories/*.desktop; do
  [[ -f $f ]] || continue
  nome="$(sed -n 's/^Name\[pt_BR\]=//p' "$f" | head -n1)"; [[ -n $nome ]] || nome="$(sed -n 's/^Name=//p' "$f" | head -n1)"
  icone="$(sed -n 's/^Icon=//p' "$f" | head -n1)"
  printf '%s | %s | %s | %s\n' "${f##*/}" "$nome" "$icone" "$(tema_do_icone "$icone")"
done

echo
echo "== Páginas das Configurações do sistema (plugin | nome | ícone | tema)"
# Os dados de cada página ficam dentro do plugin, em CBOR (formato do Qt 6).
python3 - <<'PY' | sort -u | while IFS='|' read -r plugin nome icone; do
import glob, os

def le(b, i):
    ib = b[i]; mt, ai = ib >> 5, ib & 31; i += 1
    if ai < 24: n = ai
    elif ai == 24: n = b[i]; i += 1
    elif ai == 25: n = int.from_bytes(b[i:i+2], 'big'); i += 2
    elif ai == 26: n = int.from_bytes(b[i:i+4], 'big'); i += 4
    elif ai == 27: n = int.from_bytes(b[i:i+8], 'big'); i += 8
    else: n = None
    if mt in (0, 1): return (n if mt == 0 else -1 - n), i
    if mt in (2, 3):
        s = b[i:i+n]; i += n
        return (s.decode('utf-8', 'replace') if mt == 3 else s), i
    if mt == 4:
        out = []
        while (n is None and b[i] != 0xff) or (n is not None and len(out) < n):
            v, i = le(b, i); out.append(v)
        return out, (i + 1 if n is None else i)
    if mt == 5:
        out = {}
        while (n is None and b[i] != 0xff) or (n is not None and len(out) < n):
            k, i = le(b, i); v, i = le(b, i); out[k] = v
        return out, (i + 1 if n is None else i)
    if mt == 6: return le(b, i)
    if mt == 7: return {20: False, 21: True, 22: None}.get(ai), i
    raise ValueError

pastas = glob.glob('/usr/lib64/qt6/plugins/plasma/kcms/**/*.so', recursive=True) + glob.glob('/usr/lib/*/qt6/plugins/plasma/kcms/**/*.so', recursive=True)
for so in pastas:
    b = open(so, 'rb').read()
    # Qt 6: uma nota "qt-project!" com 4 bytes de cabeçalho e o CBOR (chave 4 = dados).
    p = b.find(b'qt-project!\x00')
    if p < 0: continue
    i = p + 12 + 4
    try:
        meta, _ = le(b, i)
    except Exception:
        continue
    dados = meta.get(4) if isinstance(meta, dict) else None
    kp = dados.get('KPlugin', {}) if isinstance(dados, dict) else {}
    nome = kp.get('Name[pt_BR]') or kp.get('Name') or ''
    print(f"{os.path.basename(so)}|{nome}|{kp.get('Icon', '')}")
PY
  printf '%s | %s | %s | %s\n' "$plugin" "$nome" "$icone" "$(tema_do_icone "$icone")"
done

echo
echo "== Temas de ícones instalados"
ls /usr/share/icons
grep -h '^Inherits' /usr/share/icons/Matsu/index.theme 2>/dev/null
