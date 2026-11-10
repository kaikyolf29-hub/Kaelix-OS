#!/usr/bin/env python3
"""Gera o tema Plasma do Kaelix: o fundo das ilhas da barra.

Uso: gerar.py <pasta do tema>   (ex.: system_files/usr/share/plasma/desktoptheme/Kaelix)

O tema troca o fundo dos painéis (cantos bem redondos, vidro translúcido e uma
linha clara fina na borda) e o destaque dos apps na barra (pílula redonda).
Todo o resto vem do tema padrão do KDE.
São três versões do mesmo desenho, que o Plasma escolhe sozinho:
  translucent/  quando a placa de vídeo faz o desfoque atrás (vidro de verdade)
  widgets/      quando não há desfoque
  opaque/       quando não há efeitos de tela
"""
import json
import os
import sys

R = 14      # raio do canto, em px
C = 32      # tamanho do miolo (estica)
S = 10      # quanto a sombra sai para fora
Y0 = 10     # o desenho começa um pouco abaixo do topo, como no tema do KDE

ESTILO = """<defs>
  <style type="text/css" id="current-color-scheme">
    .ColorScheme-Text { color:#232629; stop-color:#232629; }
    .ColorScheme-Background { color:#eff0f1; stop-color:#eff0f1; }
  </style>
  <linearGradient id="s-cima" x1="0" y1="0" x2="0" y2="1">%(lin)s</linearGradient>
  <linearGradient id="s-baixo" x1="0" y1="1" x2="0" y2="0">%(lin)s</linearGradient>
  <linearGradient id="s-esq" x1="0" y1="0" x2="1" y2="0">%(lin)s</linearGradient>
  <linearGradient id="s-dir" x1="1" y1="0" x2="0" y2="0">%(lin)s</linearGradient>
  <radialGradient id="s-tl" cx="1" cy="1" r="1">%(rad)s</radialGradient>
  <radialGradient id="s-tr" cx="0" cy="1" r="1">%(rad)s</radialGradient>
  <radialGradient id="s-bl" cx="1" cy="0" r="1">%(rad)s</radialGradient>
  <radialGradient id="s-br" cx="0" cy="0" r="1">%(rad)s</radialGradient>
</defs>"""


def paradas(pares):
    return "".join('<stop offset="%s" stop-color="#000" stop-opacity="%s"/>' % p for p in pares)


def fundo(opacidade, borda):
    """As nove peças do fundo (canto, lado, miolo), com a linha clara na borda."""
    f = 'class="ColorScheme-Background" fill="currentColor" opacity="%s"' % opacidade
    l = 'fill="#ffffff" opacity="%s"' % borda
    r, c, n = R, C, R - 1
    x1, x2, y1, y2 = r, r + c, Y0 + r, Y0 + r + c
    p = []
    # Cantos: um quarto de disco e, por cima, um anel fino claro (a borda).
    # Tudo desenhado com preenchimento, sem traço: o traço faz o Plasma medir a
    # peça maior do que ela é e aparece uma emenda no canto.
    cantos = {
        "topleft": (0, Y0, "M0,%d H%d V0 A%d,%d 0 0 0 0,%d Z" % (r, r, r, r, r),
                    "M0,%d A%d,%d 0 0 1 %d,0 V1 A%d,%d 0 0 0 1,%d Z" % (r, r, r, r, n, n, r)),
        "topright": (x2, Y0, "M0,0 V%d H%d A%d,%d 0 0 0 0,0 Z" % (r, r, r, r),
                     "M0,0 A%d,%d 0 0 1 %d,%d H%d A%d,%d 0 0 0 0,1 Z" % (r, r, r, r, n, n, n)),
        "bottomleft": (0, y2, "M0,0 H%d V%d A%d,%d 0 0 1 0,0 Z" % (r, r, r, r),
                       "M%d,%d A%d,%d 0 0 1 0,0 H1 A%d,%d 0 0 0 %d,%d Z" % (r, r, r, r, n, n, r, n)),
        "bottomright": (x2, y2, "M0,0 H%d A%d,%d 0 0 1 0,%d Z" % (r, r, r, r),
                        "M%d,0 A%d,%d 0 0 1 0,%d V%d A%d,%d 0 0 0 %d,0 Z" % (r, r, r, r, n, n, n, n)),
    }
    for nome, (x, y, disco, anel) in cantos.items():
        p.append('<g id="%s" transform="translate(%d,%d)"><rect fill="#000000" opacity="0.001" width="%d" height="%d"/><path %s d="%s"/><path %s d="%s"/></g>' % (nome, x, y, r, r, f, disco, l, anel))
    p.append('<g id="top" transform="translate(%d,%d)"><rect %s width="%d" height="%d"/><rect %s width="%d" height="1"/></g>' % (x1, Y0, f, c, r, l, c))
    p.append('<g id="bottom" transform="translate(%d,%d)"><rect %s width="%d" height="%d"/><rect %s y="%d" width="%d" height="1"/></g>' % (x1, y2, f, c, r, l, r - 1, c))
    p.append('<g id="left" transform="translate(0,%d)"><rect %s width="%d" height="%d"/><rect %s width="1" height="%d"/></g>' % (y1, f, r, c, l, c))
    p.append('<g id="right" transform="translate(%d,%d)"><rect %s width="%d" height="%d"/><rect %s x="%d" width="1" height="%d"/></g>' % (x2, y1, f, r, c, l, r - 1, c))
    p.append('<g id="center" transform="translate(%d,%d)"><rect %s width="%d" height="%d"/></g>' % (x1, y1, f, c, c))
    return p


def dicas():
    """Margens de dentro do painel e as peças que o Plasma procura pelo nome."""
    x1, y1 = R, Y0 + R
    return [
        '<rect id="hint-tile-center" width="5" height="5" fill="#ff6600"/>',
        '<rect id="hint-top-margin" x="%d" y="%d" width="4" height="4" fill="#ff00ff"/>' % (x1 + 8, Y0),
        '<rect id="hint-bottom-margin" x="%d" y="%d" width="4" height="4" fill="#ff00ff"/>' % (x1 + 8, Y0 + 2 * R + C - 4),
        '<rect id="hint-left-margin" x="0" y="%d" width="8" height="4" fill="#ff00ff"/>' % (y1 + 8),
        '<rect id="hint-right-margin" x="%d" y="%d" width="8" height="4" fill="#ff00ff"/>' % (2 * R + C - 8, y1 + 8),
        '<rect id="hint-top-inset" x="%d" y="%d" width="4" height="0.00000001" fill="#00ff00"/>' % (x1 + 16, Y0),
        '<rect id="hint-bottom-inset" x="%d" y="%d" width="4" height="0.00000001" fill="#00ff00"/>' % (x1 + 16, Y0 + 2 * R + C),
        '<rect id="hint-left-inset" x="0" y="%d" width="0.00000001" height="4" fill="#00ff00"/>' % (y1 + 16),
        '<rect id="hint-right-inset" x="%d" y="%d" width="0.00000001" height="4" fill="#00ff00"/>' % (2 * R + C, y1 + 16),
        '<rect id="thick-center" class="ColorScheme-Background" fill="currentColor" x="20" y="130" width="32" height="32"/>',
        '<rect id="thick-hint-top-margin" x="34" y="122" width="4" height="8" fill="#800080"/>',
        '<rect id="thick-hint-bottom-margin" x="34" y="162" width="4" height="8" fill="#800080"/>',
        '<rect id="thick-hint-left-margin" x="12" y="144" width="8" height="4" fill="#800080"/>',
        '<rect id="thick-hint-right-margin" x="52" y="144" width="8" height="4" fill="#800080"/>',
    ]


def mascara(x0):
    """A forma cheia do painel, que o Plasma usa para recortar o desfoque."""
    r, c = R, C
    x1, x2, y1, y2 = x0 + r, x0 + r + c, Y0 + r, Y0 + r + c
    return [
        '<path id="mask-topleft" d="M%d,%d H%d V%d A%d,%d 0 0 0 %d,%d Z"/>' % (x0, y1, x1, Y0, r, r, x0, y1),
        '<path id="mask-topright" d="M%d,%d V%d H%d A%d,%d 0 0 0 %d,%d Z"/>' % (x2, Y0, y1, x2 + r, r, r, x2, Y0),
        '<path id="mask-bottomleft" d="M%d,%d H%d V%d A%d,%d 0 0 1 %d,%d Z"/>' % (x0, y2, x1, y2 + r, r, r, x0, y2),
        '<path id="mask-bottomright" d="M%d,%d H%d A%d,%d 0 0 1 %d,%d Z"/>' % (x2, y2, x2 + r, r, r, x2, y2 + r),
        '<rect id="mask-top" x="%d" y="%d" width="%d" height="%d"/>' % (x1, Y0, c, r),
        '<rect id="mask-bottom" x="%d" y="%d" width="%d" height="%d"/>' % (x1, y2, c, r),
        '<rect id="mask-left" x="%d" y="%d" width="%d" height="%d"/>' % (x0, y1, r, c),
        '<rect id="mask-right" x="%d" y="%d" width="%d" height="%d"/>' % (x2, y1, r, c),
        '<rect id="mask-center" x="%d" y="%d" width="%d" height="%d"/>' % (x1, y1, c, c),
    ]


def sombra(x0):
    """Sombra suave em volta da ilha. Por baixo da ilha ela é invisível."""
    t = S + R
    x1, x2, y1, y2 = x0 + t, x0 + t + C, t, t + C
    inv = 'fill="#000000" opacity="0.001"'
    return [
        '<rect id="shadow-topleft" x="%d" y="0" width="%d" height="%d" fill="url(#s-tl)"/>' % (x0, t, t),
        '<rect id="shadow-topright" x="%d" y="0" width="%d" height="%d" fill="url(#s-tr)"/>' % (x2, t, t),
        '<rect id="shadow-bottomleft" x="%d" y="%d" width="%d" height="%d" fill="url(#s-bl)"/>' % (x0, y2, t, t),
        '<rect id="shadow-bottomright" x="%d" y="%d" width="%d" height="%d" fill="url(#s-br)"/>' % (x2, y2, t, t),
        '<g id="shadow-top"><rect x="%d" y="0" width="%d" height="%d" fill="url(#s-cima)"/><rect %s x="%d" y="%d" width="%d" height="%d"/></g>' % (x1, C, S, inv, x1, S, C, R),
        '<g id="shadow-bottom"><rect %s x="%d" y="%d" width="%d" height="%d"/><rect x="%d" y="%d" width="%d" height="%d" fill="url(#s-baixo)"/></g>' % (inv, x1, y2, C, R, x1, y2 + R, C, S),
        '<g id="shadow-left"><rect x="%d" y="%d" width="%d" height="%d" fill="url(#s-esq)"/><rect %s x="%d" y="%d" width="%d" height="%d"/></g>' % (x0, y1, S, C, inv, x0 + S, y1, R, C),
        '<g id="shadow-right"><rect %s x="%d" y="%d" width="%d" height="%d"/><rect x="%d" y="%d" width="%d" height="%d" fill="url(#s-dir)"/></g>' % (inv, x2, y1, R, C, x2 + R, y1, S, C),
        '<rect id="shadow-center" %s x="%d" y="%d" width="%d" height="%d"/>' % (inv, x1, y1, C, C),
        '<rect id="shadow-hint-top-margin" x="%d" y="0" width="2" height="%d" fill="#ff00ff"/>' % (x1 + 8, S),
        '<rect id="shadow-hint-bottom-margin" x="%d" y="%d" width="2" height="%d" fill="#ff00ff"/>' % (x1 + 8, y2 + R, S),
        '<rect id="shadow-hint-left-margin" x="%d" y="%d" width="%d" height="2" fill="#ff00ff"/>' % (x0, y1 + 8, S),
        '<rect id="shadow-hint-right-margin" x="%d" y="%d" width="%d" height="2" fill="#ff00ff"/>' % (x2 + R, y1 + 8, S),
        '<rect id="shadow-hint-top-inset" x="%d" y="0" width="2" height="%d" fill="#00ff00"/>' % (x1 + 16, S),
        '<rect id="shadow-hint-bottom-inset" x="%d" y="%d" width="2" height="%d" fill="#00ff00"/>' % (x1 + 16, y2 + R, S),
        '<rect id="shadow-hint-left-inset" x="%d" y="%d" width="%d" height="2" fill="#00ff00"/>' % (x0, y1 + 16, S),
        '<rect id="shadow-hint-right-inset" x="%d" y="%d" width="%d" height="2" fill="#00ff00"/>' % (x2 + R, y1 + 16, S),
    ]


def painel(opacidade, borda, forca_sombra):
    k = R / float(S + R)
    estilo = ESTILO % {
        "lin": paradas([(0, 0), (0.45, round(forca_sombra * 0.12, 3)), (0.75, round(forca_sombra * 0.4, 3)), (1, forca_sombra)]),
        "rad": paradas([(0, 0), (round(k, 4), 0), (round(k + 0.0001, 4), forca_sombra), (round(k + (1 - k) * 0.25, 4), round(forca_sombra * 0.4, 3)), (round(k + (1 - k) * 0.55, 4), round(forca_sombra * 0.12, 3)), (1, 0)]),
    }
    pecas = fundo(opacidade, borda) + dicas() + sombra(80) + mascara(200)
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!-- Fundo das ilhas da barra do Kaelix. Gerado por visual/tema-plasma/gerar.py: não editar à mão. -->\n'
            '<svg xmlns="http://www.w3.org/2000/svg" id="svg2" version="1.1" width="280" height="180" viewBox="0 0 280 180">\n'
            + estilo + "\n" + "\n".join(pecas) + "\n</svg>\n")


ESTILO_TAREFAS = """<defs>
  <style type="text/css" id="current-color-scheme">
    .ColorScheme-Text { color:#232629; }
    .ColorScheme-Background { color:#eff0f1; }
    .ColorScheme-ButtonFocus { color:#3daee9; }
    .ColorScheme-PositiveText { color:#27ae60; }
    .ColorScheme-NeutralText { color:#f67400; }
  </style>
</defs>"""

# estado: (cor, opacidade). "normal" é o app aberto sem foco.
ESTADOS = [
    ("normal", "Text", 0.09),
    ("hover", "Text", 0.17),
    ("focus", "ButtonFocus", 0.42),
    ("attention", "NeutralText", 0.5),
    ("minimized", "Text", 0.04),
    ("progress", "PositiveText", 0.34),
]


def tarefas():
    """Destaque dos apps na barra: uma pílula de cantos redondos em vez do bloco quadrado."""
    b, folga, c = 8, 2, 16          # borda da peça, respiro transparente, miolo
    q = b - folga                   # raio do canto da pílula
    pecas = []
    for li, lado in enumerate(["", "north-", "west-", "east-"]):
        for ei, (estado, cor, op) in enumerate(ESTADOS):
            pre = lado + estado
            x0, y0 = 4 + ei * 44, 4 + li * 44
            f = 'class="ColorScheme-%s" fill="currentColor" opacity="%s"' % (cor, op)
            inv = 'fill="#000000" opacity="0.001"'
            x1, x2, y1, y2 = x0 + b, x0 + b + c, y0 + b, y0 + b + c

            def peca(nome, x, y, w, h, desenho):
                pecas.append('<g id="%s-%s" transform="translate(%d,%d)"><rect %s width="%d" height="%d"/>%s</g>' % (pre, nome, x, y, inv, w, h, desenho))

            peca("topleft", x0, y0, b, b, '<path %s d="M%d,%d H%d V%d A%d,%d 0 0 0 %d,%d Z"/>' % (f, folga, b, b, folga, q, q, folga, b))
            peca("topright", x2, y0, b, b, '<path %s d="M0,%d V%d H%d A%d,%d 0 0 0 0,%d Z"/>' % (f, folga, b, q, q, q, folga))
            peca("bottomleft", x0, y2, b, b, '<path %s d="M%d,0 H%d V%d A%d,%d 0 0 1 %d,0 Z"/>' % (f, folga, b, q, q, q, folga))
            peca("bottomright", x2, y2, b, b, '<path %s d="M0,0 H%d A%d,%d 0 0 1 0,%d Z"/>' % (f, q, q, q, q))
            peca("top", x1, y0, c, b, '<rect %s y="%d" width="%d" height="%d"/>' % (f, folga, c, q))
            peca("bottom", x1, y2, c, b, '<rect %s width="%d" height="%d"/>' % (f, c, q))
            peca("left", x0, y1, b, c, '<rect %s x="%d" width="%d" height="%d"/>' % (f, folga, q, c))
            peca("right", x2, y1, b, c, '<rect %s width="%d" height="%d"/>' % (f, q, c))
            peca("center", x1, y1, c, c, '<rect %s width="%d" height="%d"/>' % (f, c, c))
            # mesmas margens de dentro do tema do KDE, para os ícones não mudarem de tamanho
            pecas.append('<rect id="%s-hint-top-margin" x="%d" y="%d" width="4" height="4" fill="#ff00ff"/>' % (pre, x1 + 6, y0))
            pecas.append('<rect id="%s-hint-bottom-margin" x="%d" y="%d" width="4" height="4" fill="#ff00ff"/>' % (pre, x1 + 6, y2 + b - 4))
            pecas.append('<rect id="%s-hint-left-margin" x="%d" y="%d" width="4" height="4" fill="#ff00ff"/>' % (pre, x0, y1 + 6))
            pecas.append('<rect id="%s-hint-right-margin" x="%d" y="%d" width="4" height="4" fill="#ff00ff"/>' % (pre, x2 + b - 4, y1 + 6))
    # bolinha com "+" que marca um grupo de janelas do mesmo app
    for i, lado in enumerate(["top", "bottom", "left", "right"]):
        x, y = 280 + i * 14, 6
        pecas.append('<g id="group-expander-%s" transform="translate(%d,%d)"><circle class="ColorScheme-ButtonFocus" fill="currentColor" cx="5" cy="5" r="5"/>'
                     '<path fill="#ffffff" d="M4,2 H6 V4 H8 V6 H6 V8 H4 V6 H2 V4 H4 Z"/></g>' % (lado, x, y))
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!-- Destaque dos apps na barra do Kaelix. Gerado por visual/tema-plasma/gerar.py: não editar à mão. -->\n'
            '<svg xmlns="http://www.w3.org/2000/svg" id="svg2" version="1.1" width="340" height="184" viewBox="0 0 340 184">\n'
            + ESTILO_TAREFAS + "\n" + "\n".join(pecas) + "\n</svg>\n")


def main():
    if len(sys.argv) != 2:
        sys.exit("uso: gerar.py <pasta do tema>")
    raiz = sys.argv[1]
    versoes = {"translucent/widgets": (0.62, 0.20, 0.22), "widgets": (0.88, 0.16, 0.22), "opaque/widgets": (1, 0.12, 0)}
    for pasta, (op, borda, somb) in versoes.items():
        os.makedirs(os.path.join(raiz, pasta), exist_ok=True)
        with open(os.path.join(raiz, pasta, "panel-background.svg"), "w") as f:
            f.write(painel(op, borda, somb))
    with open(os.path.join(raiz, "widgets", "tasks.svg"), "w") as f:
        f.write(tarefas())
    meta = {
        "KPlugin": {
            "Authors": [{"Name": "Kaelix OS"}],
            "Category": "",
            "Description": "Ilhas de vidro com cantos redondos, a cara do Kaelix OS",
            "EnabledByDefault": True,
            "Id": "Kaelix",
            "License": "MIT",
            "Name": "Kaelix",
            "Version": "1.0",
        },
        "X-Plasma-API": "5.0",
    }
    with open(os.path.join(raiz, "metadata.json"), "w") as f:
        json.dump(meta, f, indent=4, ensure_ascii=False)
        f.write("\n")
    with open(os.path.join(raiz, "plasmarc"), "w") as f:
        f.write("[AdaptiveTransparency]\nenabled=true\n")
    print("tema Plasma do Kaelix em", raiz)


if __name__ == "__main__":
    main()
