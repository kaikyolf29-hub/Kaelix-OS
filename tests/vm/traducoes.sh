#!/usr/bin/bash
# Inventário das traduções da imagem (roda dentro da imagem do Matsu, no GitHub):
# o que falta em português do Brasil. Serve para achar texto em inglês sobrando
# nos apps do KDE e do sistema.
set -u

echo "== Idiomas"
echo "rpm %_install_langs: $(rpm --eval '%{?_install_langs}')"
find /etc/rpm -iname '*lang*' 2>/dev/null
grep -rs "_install_langs" /etc/rpm/ /usr/lib/rpm/macros.d/ 2>/dev/null || true
locale -a 2>/dev/null | grep -i '^pt' || echo "sem locale pt (glibc-langpack-pt?)"
cat /etc/locale.conf 2>/dev/null
echo

echo "== Domínios de tradução que existem em outro idioma e faltam em pt_BR"
# Compara com o alemão e o espanhol (os mais completos no KDE).
find /usr/share/locale/de/LC_MESSAGES /usr/share/locale/es/LC_MESSAGES -name '*.mo' -printf '%f\n' 2>/dev/null | sort -u > /tmp/ref.txt
find /usr/share/locale/pt_BR/LC_MESSAGES -name '*.mo' -printf '%f\n' 2>/dev/null | sort -u > /tmp/ptbr.txt
echo "referência: $(wc -l < /tmp/ref.txt) domínios; pt_BR: $(wc -l < /tmp/ptbr.txt)"
comm -23 /tmp/ref.txt /tmp/ptbr.txt | while read -r mo; do
  dono="$(rpm -qf "/usr/share/locale/de/LC_MESSAGES/$mo" 2>/dev/null || rpm -qf "/usr/share/locale/es/LC_MESSAGES/$mo" 2>/dev/null)"
  printf 'FALTA pt_BR: %s (%s)\n' "$mo" "$dono"
done
echo

echo "== Tipos de arquivo (shared-mime-info)"
for t in inode/directory text/plain image/png application/pdf; do
  f="/usr/share/mime/$t.xml"
  if [[ -f $f ]]; then
    printf '%s: %s\n' "$t" "$(grep -o '<comment xml:lang="pt_BR">[^<]*' "$f" | sed 's/.*>//' || echo 'SEM pt_BR')"
  else
    echo "$t: arquivo $f não existe"
  fi
done
ls /usr/share/mime/packages/ 2>/dev/null
grep -c 'xml:lang="pt_BR"' /usr/share/mime/packages/freedesktop.org.xml 2>/dev/null || echo "freedesktop.org.xml sem pt_BR"
echo

echo "== Frases que apareceram em inglês nas prints (domínio | frase | tradução)"
python3 - <<'PY'
import glob, os, struct

def ler_mo(caminho):
    dados = open(caminho, "rb").read()
    magia = struct.unpack("<I", dados[:4])[0]
    fmt = "<" if magia == 0x950412de else ">"
    _, n, orig, trad = struct.unpack(fmt + "4I", dados[4:20])
    tabela = {}
    for i in range(n):
        lo, oo = struct.unpack(fmt + "2I", dados[orig + 8 * i: orig + 8 * i + 8])
        lt, ot = struct.unpack(fmt + "2I", dados[trad + 8 * i: trad + 8 * i + 8])
        chave = dados[oo:oo + lo].decode("utf-8", "replace")
        if "\x04" in chave:
            chave = chave.split("\x04", 1)[1]
        chave = chave.split("\x00")[0]
        tabela.setdefault(chave, dados[ot:ot + lt].decode("utf-8", "replace").split("\x00")[0])
    return tabela

frases = ["System Settings", "Animation speed:", "Theme:", "Clicking files or folders:", "Selects them",
          "More appearance settings:", "More behavior settings:", "Dolphin", "Folder", "Restore", "Apply",
          "Automatic", "Slow", "Instant"]
achou = {f: [] for f in frases}
for mo in sorted(glob.glob("/usr/share/locale/pt_BR/LC_MESSAGES/*.mo")):
    try:
        t = ler_mo(mo)
    except Exception as e:
        print("não li", mo, e)
        continue
    for f in frases:
        if f in t:
            achou[f].append((os.path.basename(mo), t[f]))
for f in frases:
    if not achou[f]:
        print(f"{f!r}: NENHUM domínio traduz")
    for dom, tr in achou[f][:6]:
        print(f"{f!r} | {dom} | {tr!r}")
PY
echo
echo "== Arquivos de tradução das Configurações e da página inicial"
find /usr/share/locale/pt_BR/LC_MESSAGES -regextype egrep -regex '.*(systemsettings|landingpage|kcm_lookandfeel|dolphin|kio6|plasmashell).*' -printf '%f %s\n' 2>/dev/null
rpm -q plasma-desktop plasma-systemsettings dolphin kf6-kio-core shared-mime-info 2>/dev/null
