#!/usr/bin/env python3
"""Ícones de pasta e de tipo de arquivo do Matsu (Arquivos, diálogos, área de trabalho).

Dois jeitos de cada ícone, como no Windows e no Mac:
- pequeno (até 36 px, a lista em detalhes): desenho de traço colorido, pasta cheia
  em lavanda, igual à imagem escolhida do explorador;
- grande (de 37 px para cima, o modo de ícones): folha branca com um selo colorido
  no meio e o desenho em branco, no jeito dos ícones dos Ajustes; pasta lavanda
  com o desenho da pasta especial (Downloads, Imagens...) gravado na frente.

Aqui saem só os desenhos (matsu-tipo-*.svg e matsu-pasta*.svg). Os nomes que os
programas pedem (video-x-matroska, folder-download...) viram ligações para eles
na hora de montar a imagem: build_files/icones-de-arquivo.py.

Uso: python3 visual/icones/tipos.py [pasta dos temas]
     (padrão: system_files/usr/share/icons)
"""
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
TEMAS = Path(sys.argv[1]) if len(sys.argv) > 1 else RAIZ / "system_files/usr/share/icons"

# Cores do Matsu: as mesmas das abas e das partes do computador. No tema escuro
# o traço é claro; no claro, a versão mais forte (contraste no branco).
CORES = {
    "escuro": {"teal": "#45d0c1", "roxo": "#b18cf5", "rosa": "#f0729f", "laranja": "#f59f6b",
               "verde": "#7fcf6a", "amarelo": "#f2c861", "vermelho": "#f07272", "neutro": "#d6d6e0"},
    "claro": {"teal": "#0f9c8e", "roxo": "#7650dc", "rosa": "#d23f78", "laranja": "#d8692a",
              "verde": "#3d9533", "amarelo": "#c29213", "vermelho": "#d64545", "neutro": "#5c5c6a"},
}
# Selo dos ícones grandes (em cima da folha branca, nos dois temas).
SELO = {"teal": ("#2fbcae", "#12998b"), "roxo": ("#9a74f0", "#7650dc"), "rosa": ("#ec5f92", "#cf3a72"),
        "laranja": ("#f28a4e", "#d8692a"), "verde": ("#5cb84d", "#3d9533"), "amarelo": ("#ecb53a", "#cf9512"),
        "vermelho": ("#ec6060", "#cf3f3f"), "neutro": ("#7c7c8a", "#5c5c6a")}
# Pasta: lavanda (frente e fundo), igual à imagem escolhida.
PASTA = {"frente": ("#b1a4fb", "#988af4"), "fundo": "#7c6be0", "pequena_frente": "#a596f8", "pequena_fundo": "#8170e6"}

# Folha (grade de 24) usada pelos ícones pequenos de documento.
FOLHA = "M6.5 3h7.6l4.4 4.4V19a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2V5a2 2 0 0 1 2 -2z"
DOBRA = "M14 3.2v3.3a1 1 0 0 0 1 1h3.3"

# Desenhos de dentro (grade de 24, traço). Servem no ícone pequeno e no selo.
DESENHO = {
    "texto": "M8.5 11.5h7M8.5 14.5h7M8.5 17.5h4.5",
    "codigo": "M10 11.2l-2.6 2.8 2.6 2.8M14 11.2l2.6 2.8-2.6 2.8",
    "planilha": "M8 10.5h8v7.5h-8zM8 14.2h8M12 10.5v7.5",
    "apresentacao": "M9 17.5v-3M12 17.5v-6.5M15 17.5v-4.5",
    "zíper": "M12 3.5v1.6M12 6.6v1.6M12 9.7v1.6",
    "fonte": "M8.6 18l3.4-8.6 3.4 8.6M9.9 15h4.2",
}


def svg(tamanho, *partes, defs=""):
    cabeca = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{tamanho}" height="{tamanho}" '
              f'viewBox="0 0 {tamanho} {tamanho}">\n')
    return cabeca + (f"<defs>{defs}</defs>\n" if defs else "") + "".join(partes) + "</svg>\n"


def traco(d, cor, largura=1.6, extra=""):
    return (f'<path d="{d}" fill="none" stroke="{cor}" stroke-width="{largura}" '
            f'stroke-linecap="round" stroke-linejoin="round"{extra}/>\n')


def cheio(d, cor, opacidade=1.0):
    op = f' fill-opacity="{opacidade}"' if opacidade < 1 else ""
    return f'<path d="{d}" fill="{cor}"{op}/>\n'


def circulo(cx, cy, r, cor, traco_cor=None, largura=1.6, opacidade=1.0):
    if traco_cor:
        return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{cor}" fill-opacity="{opacidade}" '
                f'stroke="{traco_cor}" stroke-width="{largura}"/>\n')
    op = f' fill-opacity="{opacidade}"' if opacidade < 1 else ""
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{cor}"{op}/>\n'


def retangulo(x, y, w, h, r, cor, traco_cor=None, largura=1.6, opacidade=1.0):
    contorno = (f' stroke="{traco_cor}" stroke-width="{largura}" stroke-linejoin="round"' if traco_cor else "")
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{cor}" '
            f'fill-opacity="{opacidade}"{contorno}/>\n')


# --------------------------------------------------------------------------
# Desenhos que não são folha (imagem, vídeo, música, disco, app, pacote), na
# grade de 24. "c" é a cor do traço; no selo, branco.
def imagem(c, tinta=True):
    return (retangulo(3.2, 5, 17.6, 14, 2.6, c, c, 1.6, 0.16 if tinta else 0)
            + traco("M4 17.4l5-5 4 4 2.2-2.2 4.6 4.6", c) + circulo(15.6, 9.6, 1.7, c))


def video(c, tinta=True):
    return (retangulo(3.2, 5.4, 17.6, 13.2, 2.6, c, c, 1.6, 0.16 if tinta else 0)
            + f'<path d="M10.2 9.3v5.4l4.6-2.7z" fill="{c}" stroke="{c}" stroke-width="1.2" stroke-linejoin="round"/>\n')


def musica(c, tinta=True):
    return (traco("M9.6 17V6.9l9-2.3v10.1", c) + circulo(7.4, 17, 2.25, c) + circulo(16.4, 14.7, 2.25, c))


def disco(c, tinta=True):
    return (circulo(12, 12, 8.5, c, c, 1.6, 0.16 if tinta else 0) + circulo(12, 12, 2.4, "none", c, 1.6)
            + traco("M12 6.3a5.7 5.7 0 0 1 5.7 5.7", c, 1.4, ' opacity="0.6"'))


def app(c, tinta=True, pontos=None):
    # Janela com as três bolinhas do Matsu na barra de cima.
    pontos = pontos or ("#f0729f", "#9a8cf7", "#45d0c1")
    return (retangulo(3.2, 4.6, 17.6, 14.8, 2.6, c, c, 1.6, 0.16 if tinta else 0) + traco("M3.8 8.9h16.4", c, 1.4)
            + circulo(6.3, 6.8, 0.95, pontos[0]) + circulo(8.9, 6.8, 0.95, pontos[1]) + circulo(11.5, 6.8, 0.95, pontos[2]))


def pacote(c, tinta=True):
    caixa = "M12 3.2l8 4.4v8.8L12 20.8l-8-4.4V7.6z"
    return ((cheio(caixa, c, 0.16) if tinta else "") + traco(caixa, c) + traco("M4.2 7.7L12 12l7.8-4.3M12 12v8.6", c))


def controle(c):
    return traco("M7.5 8h9a4 4 0 0 1 3.9 3.1l.9 4.1a2.3 2.3 0 0 1 -4 1.9L15.5 15h-7l-1.8 2.1a2.3 2.3 0 0 1 -4 -1.9"
                 "l.9 -4.1A4 4 0 0 1 7.5 8zM8 10.6v2.8M6.6 12h2.8", c) + circulo(15.6, 11.1, 0.9, c) + circulo(17.2, 12.9, 0.9, c)


def cadeado(c, tinta=True):
    corpo = "M6.5 10.8h11a1.5 1.5 0 0 1 1.5 1.5v6.4a1.5 1.5 0 0 1 -1.5 1.5h-11a1.5 1.5 0 0 1 -1.5 -1.5v-6.4a1.5 1.5 0 0 1 1.5 -1.5z"
    return ((cheio(corpo, c, 0.16) if tinta else "") + traco(corpo, c) + traco("M8.3 10.8V8a3.7 3.7 0 0 1 7.4 0v2.8", c)
            + circulo(12, 15.4, 1.3, c))


def jogo(c, tinta=True):
    return controle(c)


def casa(c):
    return traco("M4.6 11.2L12 4.8l7.4 6.4V19a1 1 0 0 1 -1 1h-3.9v-5.2h-5V20H5.6a1 1 0 0 1 -1 -1z", c)


def monitor(c):
    return retangulo(3.8, 5, 16.4, 11, 1.8, "none", c, 1.6) + traco("M9 20h6M12 16v4", c)


def baixar(c):
    return traco("M12 4.5v10.5M7.4 10.6L12 15.2l4.6-4.6M5.5 19.5h13", c)


def documento(c):
    return traco(FOLHA, c) + traco(DESENHO["texto"], c)


# Categorias de arquivo: cor, ícone pequeno e desenho do selo do ícone grande.
# Os nomes (sem "matsu-tipo-") são os que o build_files/icones-de-arquivo.py usa.
CATEGORIAS = {
    "generico": ("neutro", None),
    "texto": ("neutro", "texto"),
    "codigo": ("roxo", "codigo"),
    "planilha": ("verde", "planilha"),
    "apresentacao": ("laranja", "apresentacao"),
    "pdf": ("vermelho", "texto"),
    "compactado": ("amarelo", "zíper"),
    "fonte": ("roxo", "fonte"),
    "imagem": ("teal", imagem),
    "video": ("rosa", video),
    "audio": ("verde", musica),
    "disco": ("laranja", disco),
    "executavel": ("teal", app),
    "pacote": ("amarelo", pacote),
    "jogo": ("rosa", jogo),
    "seguranca": ("amarelo", cadeado),
}


def pequeno_de_arquivo(cat, cores):
    nome_cor, desenho = CATEGORIAS[cat]
    c = cores[nome_cor]
    if callable(desenho):
        return svg(24, desenho(c))
    partes = [cheio(FOLHA, c, 0.14), traco(FOLHA, c), traco(DOBRA, c, 1.4)]
    if cat == "pdf":
        partes.insert(1, cheio("M14 3.2v3.3a1 1 0 0 0 1 1h3.3z", c, 0.9))
    if cat == "compactado":
        partes.append(retangulo(10.6, 12.2, 2.8, 4.2, 1, c, c, 1.3, 0.3))
    if desenho:
        partes.append(traco(DESENHO[desenho], c))
    return svg(24, *partes)


def folha_grande(gid):
    defs = (f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#ebebf1"/></linearGradient>')
    corpo = "M15 4h24.5L54 18.5V56a4 4 0 0 1 -4 4H15a4 4 0 0 1 -4 -4V8a4 4 0 0 1 4 -4z"
    partes = (f'<path d="{corpo}" fill="url(#{gid})" stroke="#000000" stroke-opacity="0.14" stroke-width="1"/>\n'
              '<path d="M39.5 4L54 18.5H43.5a4 4 0 0 1 -4 -4z" fill="#d6d6e1"/>\n')
    return defs, partes


def grande_de_arquivo(cat):
    nome_cor, desenho = CATEGORIAS[cat]
    defs, partes = folha_grande("folha")
    if desenho is None or cat == "texto":
        if cat == "texto":
            partes += traco("M20 28h24M20 35h24M20 42h24M20 49h15", "#9a9aa8", 2.6)
        return svg(64, partes, defs=defs)
    claro, escuro = SELO[nome_cor]
    defs += (f'<linearGradient id="selo" x1="0" y1="0" x2="0" y2="1">'
             f'<stop offset="0" stop-color="{claro}"/><stop offset="1" stop-color="{escuro}"/></linearGradient>')
    partes += retangulo(18, 26, 28, 28, 8, "url(#selo)")
    # O desenho de 24 encaixa no selo (28 px), com traço branco.
    branco = "#ffffff"
    if callable(desenho):
        dentro = desenho(branco, tinta=False) if desenho is not app else app(branco, False, (branco, branco, branco))
    elif desenho == "zíper":
        # Zíper: dentes alternados e o puxador embaixo.
        dentro = (traco("M10.4 4h1.6M12 6.2h1.6M10.4 8.4h1.6M12 10.6h1.6M10.4 12.8h1.6", branco, 1.7)
                  + retangulo(10.1, 14.6, 3.8, 5.2, 1.3, "none", branco, 1.7))
    else:
        dentro = traco(DESENHO[desenho], branco, 1.9)
        if desenho in ("texto", "codigo", "planilha", "apresentacao", "fonte"):
            # Os desenhos de folha ficam mais embaixo na grade: sobe para o meio.
            dentro = f'<g transform="translate(0 -2.2)">{dentro}</g>\n'
    partes += f'<g transform="translate(18.5 26.5) scale(1.125)">\n{dentro}</g>\n'
    return svg(64, partes, defs=defs)


# --------------------------------------------------------------------------
# Pastas. As especiais ganham um desenho na frente (só no ícone grande).
PASTAS = {
    "": None,
    "-downloads": baixar,
    "-documentos": documento,
    "-imagens": lambda c: imagem(c, tinta=False),
    "-videos": lambda c: video(c, tinta=False),
    "-musica": lambda c: musica(c),
    "-area-de-trabalho": monitor,
    "-pessoal": casa,
    "-jogos": controle,
}


def pasta_pequena():
    fundo = "M2.6 6.2a2 2 0 0 1 2 -2h4.6l2.1 2.1h8.1a2 2 0 0 1 2 2v9.6a2 2 0 0 1 -2 2H4.6a2 2 0 0 1 -2 -2z"
    frente = "M2.6 9.6a1.6 1.6 0 0 1 1.6 -1.6h15.6a1.6 1.6 0 0 1 1.6 1.6v8.3a2 2 0 0 1 -2 2H4.6a2 2 0 0 1 -2 -2z"
    return svg(24, cheio(fundo, PASTA["pequena_fundo"]), cheio(frente, PASTA["pequena_frente"]))


def pasta_grande(desenho):
    claro, escuro = PASTA["frente"]
    defs = (f'<linearGradient id="frente" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{claro}"/><stop offset="1" stop-color="{escuro}"/></linearGradient>')
    fundo = "M4 13a4 4 0 0 1 4 -4h14.3a4 4 0 0 1 2.9 1.2l3.6 3.8H56a4 4 0 0 1 4 4v33a4 4 0 0 1 -4 4H8a4 4 0 0 1 -4 -4z"
    frente = "M4 23a4 4 0 0 1 4 -4h48a4 4 0 0 1 4 4v27a4 4 0 0 1 -4 4H8a4 4 0 0 1 -4 -4z"
    partes = (cheio(fundo, PASTA["fundo"]) + cheio(frente, "url(#frente)")
              + '<path d="M8 19.5h48" stroke="#ffffff" stroke-opacity="0.35" stroke-width="1"/>\n')
    if desenho:
        gravado = desenho("#ffffff").replace('stroke-width="1.6"', 'stroke-width="2.2"')
        partes += f'<g transform="translate(22.4 26.6) scale(0.8)" opacity="0.92">\n{gravado}</g>\n'
    return svg(64, partes, defs=defs)


def gravar(pasta, nome, conteudo):
    pasta.mkdir(parents=True, exist_ok=True)
    (pasta / f"{nome}.svg").write_text(conteudo)


def main():
    for tema, jeito in (("Matsu", "escuro"), ("Matsu-claro", "claro")):
        base = TEMAS / tema
        for cat in CATEGORIAS:
            gravar(base / "mimetypes/pequeno", f"matsu-tipo-{cat}", pequeno_de_arquivo(cat, CORES[jeito]))
            gravar(base / "mimetypes/scalable", f"matsu-tipo-{cat}", grande_de_arquivo(cat))
        for sufixo, desenho in PASTAS.items():
            gravar(base / "places/pequeno", f"matsu-pasta{sufixo}", pasta_pequena())
            gravar(base / "places/scalable", f"matsu-pasta{sufixo}", pasta_grande(desenho))
        # No HiDPI (escala 2) a lista pede 22 px "em dobro": a mesma pasta serve.
        for ctx in ("mimetypes", "places"):
            ligacao = base / ctx / "pequeno@2x"
            if not ligacao.is_symlink():
                ligacao.symlink_to("pequeno")
    print(f"ícones de tipo: {len(CATEGORIAS)} tipos e {len(PASTAS)} pastas em {TEMAS}")


if __name__ == "__main__":
    main()
