#!/usr/bin/env python3
"""O primeiro uso (Plasma Setup) com a cara do Matsu.

Depois de instalar, a primeira tela é o assistente do KDE onde a pessoa escolhe o
idioma, o teclado, o Wi-Fi e cria a conta. Ele vem compilado, mas:

- os textos vêm do catálogo de tradução (org.kde.plasmasetup.mo): aqui trocamos
  só a frase grande da entrada ("Bem-vindo ao Plasma Desktop" vira "Bem-vindo ao
  Matsu") e a linha de baixo (só o nome do sistema, sem "Desenvolvido por");
- o fundo é o wallpapers/Default (o build.sh põe o papel do Matsu lá);
- as cores e a letra já são as do Matsu (padrões em /etc/xdg/kdeglobals).

O catálogo é lido e regravado aqui mesmo (formato .mo do gettext), sem mudar
nenhuma outra frase. Se a frase do KDE mudar, ela fica como veio (com aviso).

Uso: primeiro-uso.py [pasta dos idiomas]   (padrão: /usr/share/locale)
"""
import struct
import sys
from pathlib import Path

LOCALE = Path(sys.argv[1] if len(sys.argv) > 1 else "/usr/share/locale")
CATALOGO = "org.kde.plasmasetup.mo"

# (contexto, frase do KDE) -> frase do Matsu, por idioma.
TROCAS = {
    "pt_BR": {
        (None, "Welcome to<br/><b>Plasma Desktop</b>"): "Bem-vindo ao<br/><b>Matsu</b>",
        ("%1 is the distro name", "Powered by<br/><b>%1</b>"): "<b>%1</b>",
    },
    "pt": {
        (None, "Welcome to<br/><b>Plasma Desktop</b>"): "Bem-vindo ao<br/><b>Matsu</b>",
        ("%1 is the distro name", "Powered by<br/><b>%1</b>"): "<b>%1</b>",
    },
}


def ler_mo(dados):
    """Lista de (original, tradução) em bytes, como estão no arquivo."""
    magia = struct.unpack("<I", dados[:4])[0]
    ordem = "<" if magia == 0x950412DE else ">"
    if struct.unpack(ordem + "I", dados[:4])[0] != 0x950412DE:
        raise ValueError("não é um catálogo .mo")
    _, n, ini_orig, ini_trad = struct.unpack(ordem + "4I", dados[4:20])
    pares = []
    for i in range(n):
        tam_o, pos_o = struct.unpack(ordem + "2I", dados[ini_orig + 8 * i:ini_orig + 8 * i + 8])
        tam_t, pos_t = struct.unpack(ordem + "2I", dados[ini_trad + 8 * i:ini_trad + 8 * i + 8])
        pares.append((dados[pos_o:pos_o + tam_o], dados[pos_t:pos_t + tam_t]))
    return pares


def gravar_mo(pares):
    """Um .mo novo (sem tabela de dispersão, que é opcional), em ordem."""
    pares = sorted(pares, key=lambda par: par[0])
    n = len(pares)
    ini_orig = 28
    ini_trad = ini_orig + 8 * n
    pos = ini_trad + 8 * n
    tabela_o, tabela_t, corpo = [], [], b""
    for original, _ in pares:
        tabela_o.append((len(original), pos + len(corpo)))
        corpo += original + b"\0"
    for _, traducao in pares:
        tabela_t.append((len(traducao), pos + len(corpo)))
        corpo += traducao + b"\0"
    cabeca = struct.pack("<7I", 0x950412DE, 0, n, ini_orig, ini_trad, 0, pos)
    return (cabeca + b"".join(struct.pack("<2I", *t) for t in tabela_o)
            + b"".join(struct.pack("<2I", *t) for t in tabela_t) + corpo)


def chave(contexto, frase):
    texto = frase if contexto is None else contexto + "\x04" + frase
    return texto.encode("utf-8")


def trocar(arquivo, trocas):
    pares = ler_mo(arquivo.read_bytes())
    indice = {original: i for i, (original, _) in enumerate(pares)}
    feitas = 0
    for (contexto, frase), nova in trocas.items():
        i = indice.get(chave(contexto, frase))
        if i is None:
            print(f"AVISO: {arquivo}: a frase {frase!r} não está no catálogo; fica como veio")
            continue
        pares[i] = (pares[i][0], nova.encode("utf-8"))
        feitas += 1
    if feitas:
        arquivo.write_bytes(gravar_mo(pares))
    return feitas


def main():
    total = 0
    for idioma, trocas in TROCAS.items():
        arquivo = LOCALE / idioma / "LC_MESSAGES" / CATALOGO
        if not arquivo.is_file():
            continue
        try:
            feitas = trocar(arquivo, trocas)
        except (OSError, ValueError, struct.error) as erro:
            print(f"AVISO: {arquivo}: {erro}; fica como veio")
            continue
        print(f"Primeiro uso ({idioma}): {feitas} frases do Matsu")
        total += feitas
    if total == 0:
        print("AVISO: primeiro uso: nenhuma frase trocada (o assistente fica com os textos do KDE)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
