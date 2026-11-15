#!/usr/bin/env python3
"""Gera o tema Plasma do Matsu: o fundo das ilhas da barra, dos balões e das dicas.

Uso: gerar.py [--cor #rrggbb] [--transparencia mais|normal|menos|sem] <pasta do tema>

Sem opções sai o vidro padrão, que vai na imagem:
  python3 system_files/usr/share/matsu/vidro/gerar.py system_files/usr/share/plasma/desktoptheme/Matsu
Com opções sai o vidro que a pessoa escolheu ("matsu vidro roxo"), na pasta
dela (~/.local/share/plasma/desktoptheme/Matsu). O Plasma procura cada arquivo
do tema primeiro na pasta da pessoa e depois na do sistema.

O tema troca o fundo dos painéis (cantos bem redondos, vidro translúcido e uma
linha clara fina na borda) e o destaque dos apps na barra (pílula redonda).
Todo o resto vem do tema padrão do KDE.
São três versões do mesmo desenho, que o Plasma escolhe sozinho:
  translucent/  quando a placa de vídeo faz o desfoque atrás (vidro de verdade)
  widgets/      quando não há desfoque
  opaque/       quando não há efeitos de tela
E o vidro do estilo Mac (a doca e a barra de cima), em solid/ (o fundo que o
Plasma usa nas barras marcadas como opacas, e o "matsu barra" marca assim só
as do Mac) e translucent/solid/ (o mesmo com o desfoque).
"""
import argparse
import json
import os
import re

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


# Força da cor escolhida no vidro (0 = sem cor). Fica por cima do fundo do tema,
# então funciona igual no tema claro e no escuro.
FORCA_COR = 0.24
# Quanto o fundo cobre, por nível de transparência: (com desfoque, sem desfoque).
NIVEIS = {
    "mais":   {"ilha": (0.42, 0.80), "balao": (0.56, 0.88)},
    "normal": {"ilha": (0.62, 0.88), "balao": (0.74, 0.94)},
    "menos":  {"ilha": (0.82, 0.95), "balao": (0.90, 0.98)},
    # "Sem vidro" nos Ajustes: sólido mesmo com o desfoque ligado.
    "sem":    {"ilha": (1, 1), "balao": (1, 1)},
}
TINTA = None    # (cor, força) quando a pessoa escolheu uma cor


def camadas(opacidade):
    """Atributos do fundo e da cor por cima, somando a mesma transparência de antes."""
    if not TINTA:
        return 'class="ColorScheme-Background" fill="currentColor" opacity="%s"' % opacidade, None
    cor, forca = TINTA
    t = min(opacidade, forca)
    # Fundo com a cor por cima cobre 1-(1-a)(1-t): acerta "a" para dar a mesma opacidade.
    a = 1 - (1 - opacidade) / (1 - t) if t < 1 else 1
    return ('class="ColorScheme-Background" fill="currentColor" opacity="%s"' % round(a, 3),
            'fill="%s" opacity="%s"' % (cor, round(t, 3)))


def fundo(opacidade, borda, r=R, pre="", oy=0, brilho=None):
    """As nove peças do fundo (canto, lado, miolo), com a linha clara na borda.

    borda é um número (a mesma linha em volta) ou (cima, lados, baixo): o vidro
    do Mac tem a linha mais clara em cima, como a luz batendo de cima. pre põe um
    prefixo no nome das peças (ex.: "north-", a barra de cima) e oy desce o
    desenho na folha, para não ficar por cima das outras peças. brilho é o id
    de um degradê branco que acende a faixa de cima (o canto e a beirada de
    cima), como a luz batendo no vidro."""
    f, k = camadas(opacidade)
    if not isinstance(borda, (tuple, list)):
        borda = (borda, borda, borda)
    b_cima, b_lado, b_baixo = borda

    def linha(op):
        return 'fill="#ffffff" opacity="%s"' % op
    l = linha(b_lado)

    def cheio(forma, *medidas):
        """A mesma forma pintada com o fundo e, se houver, com a cor escolhida."""
        if forma == "path":
            return "".join('<path %s d="%s"/>' % (a, medidas[0]) for a in (f, k) if a)
        extra = medidas[0]
        return "".join('<rect %s%s/>' % (a, extra) for a in (f, k) if a)
    c, n = C, r - 1
    y0 = Y0 + oy
    x1, x2, y1, y2 = r, r + c, y0 + r, y0 + r + c
    p = []
    # Cantos: um quarto de disco e, por cima, um anel fino claro (a borda).
    # Tudo desenhado com preenchimento, sem traço: o traço faz o Plasma medir a
    # peça maior do que ela é e aparece uma emenda no canto.
    # Os cantos de cima levam a linha de cima; os de baixo, a de baixo.
    cantos = {
        "topleft": (0, y0, b_cima, "M0,%d H%d V0 A%d,%d 0 0 0 0,%d Z" % (r, r, r, r, r),
                    "M0,%d A%d,%d 0 0 1 %d,0 V1 A%d,%d 0 0 0 1,%d Z" % (r, r, r, r, n, n, r)),
        "topright": (x2, y0, b_cima, "M0,0 V%d H%d A%d,%d 0 0 0 0,0 Z" % (r, r, r, r),
                     "M0,0 A%d,%d 0 0 1 %d,%d H%d A%d,%d 0 0 0 0,1 Z" % (r, r, r, r, n, n, n)),
        "bottomleft": (0, y2, b_baixo, "M0,0 H%d V%d A%d,%d 0 0 1 0,0 Z" % (r, r, r, r),
                       "M%d,%d A%d,%d 0 0 1 0,0 H1 A%d,%d 0 0 0 %d,%d Z" % (r, r, r, r, n, n, r, n)),
        "bottomright": (x2, y2, b_baixo, "M0,0 H%d A%d,%d 0 0 1 0,%d Z" % (r, r, r, r),
                        "M%d,0 A%d,%d 0 0 1 0,%d V%d A%d,%d 0 0 0 %d,0 Z" % (r, r, r, r, n, n, n, n)),
    }
    for nome, (x, y, op, disco, anel) in cantos.items():
        luz = '<path fill="url(#%s)" d="%s"/>' % (brilho, disco) if brilho and nome.startswith("top") else ""
        p.append('<g id="%s%s" transform="translate(%d,%d)"><rect fill="#000000" opacity="0.001" width="%d" height="%d"/>%s%s<path %s d="%s"/></g>' % (pre, nome, x, y, r, r, cheio("path", disco), luz, linha(op), anel))
    luz = '<rect fill="url(#%s)" width="%d" height="%d"/>' % (brilho, c, r) if brilho else ""
    p.append('<g id="%stop" transform="translate(%d,%d)">%s%s<rect %s width="%d" height="1"/></g>' % (pre, x1, y0, cheio("rect", ' width="%d" height="%d"' % (c, r)), luz, linha(b_cima), c))
    p.append('<g id="%sbottom" transform="translate(%d,%d)">%s<rect %s y="%d" width="%d" height="1"/></g>' % (pre, x1, y2, cheio("rect", ' width="%d" height="%d"' % (c, r)), linha(b_baixo), r - 1, c))
    p.append('<g id="%sleft" transform="translate(0,%d)">%s<rect %s width="1" height="%d"/></g>' % (pre, y1, cheio("rect", ' width="%d" height="%d"' % (r, c)), l, c))
    p.append('<g id="%sright" transform="translate(%d,%d)">%s<rect %s x="%d" width="1" height="%d"/></g>' % (pre, x2, y1, cheio("rect", ' width="%d" height="%d"' % (r, c)), l, r - 1, c))
    p.append('<g id="%scenter" transform="translate(%d,%d)">%s</g>' % (pre, x1, y1, cheio("rect", ' width="%d" height="%d"' % (c, c))))
    return p


def dicas(r=R, mv=4, mh=8, grosso=True, pre="", oy=0):
    """Margens de dentro (mv em cima e embaixo, mh dos lados) e as peças que o Plasma procura pelo nome."""
    y0 = Y0 + oy
    x1, y1 = r, y0 + r
    R = r
    pecas = [
        '<rect id="%shint-top-margin" x="%d" y="%d" width="4" height="%d" fill="#ff00ff"/>' % (pre, x1 + 8, y0, mv),
        '<rect id="%shint-bottom-margin" x="%d" y="%d" width="4" height="%d" fill="#ff00ff"/>' % (pre, x1 + 8, y0 + 2 * R + C - mv, mv),
        '<rect id="%shint-left-margin" x="0" y="%d" width="%d" height="4" fill="#ff00ff"/>' % (pre, y1 + 8, mh),
        '<rect id="%shint-right-margin" x="%d" y="%d" width="%d" height="4" fill="#ff00ff"/>' % (pre, 2 * R + C - mh, y1 + 8, mh),
        '<rect id="%shint-top-inset" x="%d" y="%d" width="4" height="0.00000001" fill="#00ff00"/>' % (pre, x1 + 16, y0),
        '<rect id="%shint-bottom-inset" x="%d" y="%d" width="4" height="0.00000001" fill="#00ff00"/>' % (pre, x1 + 16, y0 + 2 * R + C),
        '<rect id="%shint-left-inset" x="0" y="%d" width="0.00000001" height="4" fill="#00ff00"/>' % (pre, y1 + 16),
        '<rect id="%shint-right-inset" x="%d" y="%d" width="0.00000001" height="4" fill="#00ff00"/>' % (pre, 2 * R + C, y1 + 16),
    ]
    if pre:
        return pecas
    pecas.insert(0, '<rect id="hint-tile-center" width="5" height="5" fill="#ff6600"/>')
    if not grosso:
        return pecas
    return pecas + [
        '<rect id="thick-center" class="ColorScheme-Background" fill="currentColor" x="20" y="130" width="32" height="32"/>',
        '<rect id="thick-hint-top-margin" x="34" y="122" width="4" height="8" fill="#800080"/>',
        '<rect id="thick-hint-bottom-margin" x="34" y="162" width="4" height="8" fill="#800080"/>',
        '<rect id="thick-hint-left-margin" x="12" y="144" width="8" height="4" fill="#800080"/>',
        '<rect id="thick-hint-right-margin" x="52" y="144" width="8" height="4" fill="#800080"/>',
    ]


def mascara(x0, r=R, pre="", oy=0):
    """A forma cheia do painel, que o Plasma usa para recortar o desfoque."""
    c = C
    y0 = Y0 + oy
    x1, x2, y1, y2 = x0 + r, x0 + r + c, y0 + r, y0 + r + c
    m = "mask-" + pre
    return [
        '<path id="%stopleft" d="M%d,%d H%d V%d A%d,%d 0 0 0 %d,%d Z"/>' % (m, x0, y1, x1, y0, r, r, x0, y1),
        '<path id="%stopright" d="M%d,%d V%d H%d A%d,%d 0 0 0 %d,%d Z"/>' % (m, x2, y0, y1, x2 + r, r, r, x2, y0),
        '<path id="%sbottomleft" d="M%d,%d H%d V%d A%d,%d 0 0 1 %d,%d Z"/>' % (m, x0, y2, x1, y2 + r, r, r, x0, y2),
        '<path id="%sbottomright" d="M%d,%d H%d A%d,%d 0 0 1 %d,%d Z"/>' % (m, x2, y2, x2 + r, r, r, x2, y2 + r),
        '<rect id="%stop" x="%d" y="%d" width="%d" height="%d"/>' % (m, x1, y0, c, r),
        '<rect id="%sbottom" x="%d" y="%d" width="%d" height="%d"/>' % (m, x1, y2, c, r),
        '<rect id="%sleft" x="%d" y="%d" width="%d" height="%d"/>' % (m, x0, y1, r, c),
        '<rect id="%sright" x="%d" y="%d" width="%d" height="%d"/>' % (m, x2, y1, r, c),
        '<rect id="%scenter" x="%d" y="%d" width="%d" height="%d"/>' % (m, x1, y1, c, c),
    ]


def sombra(x0, r=R, s=S, pre="shadow-", g="s-", oy=0):
    """Sombra suave em volta da ilha. Por baixo da ilha ela é invisível.

    s é quanto ela sai para fora, pre o prefixo das peças, g o dos degradês
    (veja degrades_sombra) e oy desce o desenho na folha."""
    R, S = r, s
    t = S + R
    x1, x2, y0, y1, y2 = x0 + t, x0 + t + C, oy, oy + t, oy + t + C
    inv = 'fill="#000000" opacity="0.001"'
    p, d = pre, g
    return [
        '<rect id="%stopleft" x="%d" y="%d" width="%d" height="%d" fill="url(#%stl)"/>' % (p, x0, y0, t, t, d),
        '<rect id="%stopright" x="%d" y="%d" width="%d" height="%d" fill="url(#%str)"/>' % (p, x2, y0, t, t, d),
        '<rect id="%sbottomleft" x="%d" y="%d" width="%d" height="%d" fill="url(#%sbl)"/>' % (p, x0, y2, t, t, d),
        '<rect id="%sbottomright" x="%d" y="%d" width="%d" height="%d" fill="url(#%sbr)"/>' % (p, x2, y2, t, t, d),
        '<g id="%stop"><rect x="%d" y="%d" width="%d" height="%d" fill="url(#%scima)"/><rect %s x="%d" y="%d" width="%d" height="%d"/></g>' % (p, x1, y0, C, S, d, inv, x1, y0 + S, C, R),
        '<g id="%sbottom"><rect %s x="%d" y="%d" width="%d" height="%d"/><rect x="%d" y="%d" width="%d" height="%d" fill="url(#%sbaixo)"/></g>' % (p, inv, x1, y2, C, R, x1, y2 + R, C, S, d),
        '<g id="%sleft"><rect x="%d" y="%d" width="%d" height="%d" fill="url(#%sesq)"/><rect %s x="%d" y="%d" width="%d" height="%d"/></g>' % (p, x0, y1, S, C, d, inv, x0 + S, y1, R, C),
        '<g id="%sright"><rect %s x="%d" y="%d" width="%d" height="%d"/><rect x="%d" y="%d" width="%d" height="%d" fill="url(#%sdir)"/></g>' % (p, inv, x2, y1, R, C, x2 + R, y1, S, C, d),
        '<rect id="%scenter" %s x="%d" y="%d" width="%d" height="%d"/>' % (p, inv, x1, y1, C, C),
        '<rect id="%shint-top-margin" x="%d" y="%d" width="2" height="%d" fill="#ff00ff"/>' % (p, x1 + 8, y0, S),
        '<rect id="%shint-bottom-margin" x="%d" y="%d" width="2" height="%d" fill="#ff00ff"/>' % (p, x1 + 8, y2 + R, S),
        '<rect id="%shint-left-margin" x="%d" y="%d" width="%d" height="2" fill="#ff00ff"/>' % (p, x0, y1 + 8, S),
        '<rect id="%shint-right-margin" x="%d" y="%d" width="%d" height="2" fill="#ff00ff"/>' % (p, x2 + R, y1 + 8, S),
        '<rect id="%shint-top-inset" x="%d" y="%d" width="2" height="%d" fill="#00ff00"/>' % (p, x1 + 16, y0, S),
        '<rect id="%shint-bottom-inset" x="%d" y="%d" width="2" height="%d" fill="#00ff00"/>' % (p, x1 + 16, y2 + R, S),
        '<rect id="%shint-left-inset" x="%d" y="%d" width="%d" height="2" fill="#00ff00"/>' % (p, x0, y1 + 16, S),
        '<rect id="%shint-right-inset" x="%d" y="%d" width="%d" height="2" fill="#00ff00"/>' % (p, x2 + R, y1 + 16, S),
    ]


def degrades_sombra(g, forca, r=R, s=S):
    """Os degradês de uma sombra (veja sombra): de "forca" na borda até sumir."""
    k = r / float(s + r)
    lin = paradas([(0, 0), (0.45, round(forca * 0.12, 3)), (0.75, round(forca * 0.4, 3)), (1, forca)])
    rad = paradas([(0, 0), (round(k, 4), 0), (round(k + 0.0001, 4), forca), (round(k + (1 - k) * 0.25, 4), round(forca * 0.4, 3)),
                   (round(k + (1 - k) * 0.55, 4), round(forca * 0.12, 3)), (1, 0)])
    return ("<defs>"
            '<linearGradient id="%scima" x1="0" y1="0" x2="0" y2="1">%s</linearGradient>' % (g, lin)
            + '<linearGradient id="%sbaixo" x1="0" y1="1" x2="0" y2="0">%s</linearGradient>' % (g, lin)
            + '<linearGradient id="%sesq" x1="0" y1="0" x2="1" y2="0">%s</linearGradient>' % (g, lin)
            + '<linearGradient id="%sdir" x1="1" y1="0" x2="0" y2="0">%s</linearGradient>' % (g, lin)
            + '<radialGradient id="%stl" cx="1" cy="1" r="1">%s</radialGradient>' % (g, rad)
            + '<radialGradient id="%str" cx="0" cy="1" r="1">%s</radialGradient>' % (g, rad)
            + '<radialGradient id="%sbl" cx="1" cy="0" r="1">%s</radialGradient>' % (g, rad)
            + '<radialGradient id="%sbr" cx="0" cy="0" r="1">%s</radialGradient>' % (g, rad)
            + "</defs>")


def painel(opacidade, borda, forca_sombra, r=R, mv=4, mh=8, grosso=True, nome="Fundo das ilhas da barra", extras=(), soltas=(), brilho=0):
    """Uma folha completa: fundo, margens, sombra e máscara. Serve para a barra, os balões e as dicas.

    extras são desenhos a mais na mesma folha, cada um (prefixo, opacidade,
    borda): o Plasma usa "north-" nas barras presas no alto da tela e "west-" e
    "east-" nas de pé, nos lados (veja painel_mac). soltas são peças prontas
    que vão embaixo de tudo, numa faixa a mais da folha (veja doca_mac).
    brilho acende a faixa de cima do fundo (a força da luz; 0 = sem)."""
    R = r
    k = R / float(S + R)
    estilo = ESTILO % {
        "lin": paradas([(0, 0), (0.45, round(forca_sombra * 0.12, 3)), (0.75, round(forca_sombra * 0.4, 3)), (1, forca_sombra)]),
        "rad": paradas([(0, 0), (round(k, 4), 0), (round(k + 0.0001, 4), forca_sombra), (round(k + (1 - k) * 0.25, 4), round(forca_sombra * 0.4, 3)), (round(k + (1 - k) * 0.55, 4), round(forca_sombra * 0.12, 3)), (1, 0)]),
    }
    luz = [degrade_brilho("brilho", brilho)] if brilho else []
    pecas = luz + fundo(opacidade, borda, r, brilho="brilho" if brilho else None) + dicas(r, mv, mh, grosso) + sombra(80, r) + mascara(200, r)
    for i, (pre, op, b) in enumerate(extras):
        oy = OY_TOPO * (i + 1)
        pecas += fundo(op, b, r, pre=pre, oy=oy) + dicas(r, mv, mh, pre=pre, oy=oy) + mascara(200, r, pre=pre, oy=oy)
    pecas += list(soltas)
    altura = 180 + OY_TOPO * (len(extras) + (1 if soltas else 0))
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!-- %s do Matsu. Gerado por usr/share/matsu/vidro/gerar.py: não editar à mão. -->\n' % nome
            + '<svg xmlns="http://www.w3.org/2000/svg" id="svg2" version="1.1" width="280" height="%d" viewBox="0 0 280 %d">\n' % (altura, altura)
            + estilo + "\n" + "\n".join(pecas) + "\n</svg>\n")


# O vidro do estilo Mac (a doca e a barra de cima): mais fino e transparente que
# o das ilhas, com a linha clara mais forte em cima, como a luz batendo de cima.
# Quanto o fundo cobre, por nível: (com desfoque, sem desfoque).
NIVEIS_MAC = {
    "mais":   {"doca": (0.26, 0.58), "topo": (0.30, 0.62)},
    "normal": {"doca": (0.40, 0.70), "topo": (0.45, 0.74)},
    "menos":  {"doca": (0.62, 0.84), "topo": (0.66, 0.86)},
    "sem":    {"doca": (1, 1), "topo": (1, 1)},
}
# Quanto desce, na folha, cada desenho a mais (a barra de cima, a doca de pé).
OY_TOPO = 200


# A doca do estilo Mac desenha o próprio vidro (a peça org.matsu.doca desliga o
# fundo da barra): assim o vidro cresce junto com a lupa, como no Mac. Ela usa
# as peças "doca-" (o vidro) e "doca-sombra-" (a sombra em volta) desta folha.
# Sem o fundo da barra não há desfoque atrás (nem no PC com placa de vídeo),
# então é o mesmo desenho com e sem o efeito: o vidro claro do macOS 26, bem
# transparente, com a borda acesa e um brilho na faixa de cima.
R_DOCA = 18     # raio do canto
S_DOCA = 8      # quanto a sombra sai (cabe na folga da barra flutuante)
NIVEIS_DOCA = {"mais": 0.20, "normal": 0.32, "menos": 0.52, "sem": 1}
BORDA_DOCA = (0.80, 0.42, 0.55)     # a linha clara: cima, lados, baixo
BRILHO_DOCA = 0.34                  # a luz na faixa de cima, que some para baixo
SOMBRA_DOCA = 0.20


def degrade_brilho(nome, forca):
    """O degradê branco da luz na faixa de cima do vidro: de "forca" até sumir."""
    return ('<defs><linearGradient id="%s" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#ffffff" stop-opacity="%s"/>'
            '<stop offset="1" stop-color="#ffffff" stop-opacity="0"/></linearGradient></defs>' % (nome, forca))


def doca_mac(opacidade, oy):
    """O vidro da doca do Mac ("doca-") e a sombra em volta ("doca-sombra-")."""
    return ([degrade_brilho("brilho-doca", BRILHO_DOCA), degrades_sombra("ds-", SOMBRA_DOCA, R_DOCA, S_DOCA)]
            + fundo(opacidade, BORDA_DOCA, R_DOCA, pre="doca-", oy=oy, brilho="brilho-doca")
            + sombra(100, R_DOCA, S_DOCA, pre="doca-sombra-", g="ds-", oy=oy))


def painel_mac(op_doca, op_topo, borda_doca, borda_topo, forca_sombra, op_vidro_doca):
    """A folha do vidro do Mac: a doca (sem prefixo e de pé, "west-" e "east-"),
    a barra de cima ("north-") e o vidro que a própria doca desenha ("doca-").

    O Plasma usa esta folha (solid/widgets/panel-background) nas barras marcadas
    como opacas; o comando "matsu barra" marca assim só as do estilo Mac, então
    as ilhas da fusão e a barra do Windows continuam com o vidro de sempre. As
    peças sem prefixo só aparecem enquanto a doca ainda não desligou o fundo da
    barra (no primeiro instante); a barra de cima também desliga o dela."""
    extras = (("north-", op_topo, borda_topo), ("west-", op_doca, borda_doca), ("east-", op_doca, borda_doca))
    return painel(op_doca, borda_doca, forca_sombra, nome="Vidro do estilo Mac (doca e barra de cima)",
                  extras=extras, soltas=doca_mac(op_vidro_doca, OY_TOPO * (len(extras) + 1)))


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
            '<!-- Destaque dos apps na barra do Matsu. Gerado por usr/share/matsu/vidro/gerar.py: não editar à mão. -->\n'
            '<svg xmlns="http://www.w3.org/2000/svg" id="svg2" version="1.1" width="340" height="184" viewBox="0 0 340 184">\n'
            + ESTILO_TAREFAS + "\n" + "\n".join(pecas) + "\n</svg>\n")


RB = 12     # raio do canto dos balões (menu, bandeja, avisos, escolha de telas do Meta+P)
RD = 8      # raio do canto das dicas (o texto que aparece ao parar o mouse)

# Os balões no estilo Mac (--mac): os avisos dos apps, a bandeja, o calendário,
# o volume... com o vidro do macOS 26: mais redondos, mais transparentes com o
# desfoque, a borda acesa (mais em cima, como a luz batendo de cima) e um brilho
# leve na faixa de cima. "matsu barra mac" gera o tema da pessoa com --mac; nos
# outros estilos os balões continuam como os das ilhas.
RB_MAC = 16
# Quanto o fundo cobre, por nível: (com desfoque, sem desfoque).
NIVEIS_BALAO_MAC = {"mais": (0.50, 0.86), "normal": (0.64, 0.92), "menos": (0.82, 0.96), "sem": (1, 1)}
BORDA_BALAO_MAC = (0.46, 0.22, 0.26)    # a linha clara: cima, lados, baixo
BRILHO_BALAO_MAC = 0.12
MARGEM_BALAO_MAC = 6                    # o canto mais redondo pede um pouco mais de folga dentro


def cabecalho(r=RB, cobre=0.75):
    """Faixa de cima e de baixo dos balões, com os cantos acompanhando o canto redondo.

    r é o raio do canto dos balões e cobre, quanto a faixa cobre (no Mac, só
    um véu leve: o vidro aparece por baixo)."""
    c = 32
    f = 'class="ColorScheme-Background" fill="currentColor" opacity="%s"' % cobre
    lin = 'class="ColorScheme-Text" fill="currentColor" opacity="0.14"'
    inv = 'fill="#000000" opacity="0.001"'
    pecas = ['<rect id="hint-stretch-borders" x="0" y="0" width="5" height="5" opacity="0.6"/>']

    def peca(nome, x, y, w, h, desenho):
        pecas.append('<g id="%s" transform="translate(%d,%d)"><rect %s width="%d" height="%d"/>%s</g>' % (nome, x, y, inv, w, h, desenho))

    def cheio(w, h):
        return '<rect %s width="%d" height="%d"/>' % (f, w, h)

    for pre, x0, redondo_em_cima in (("header", 10, True), ("footer", 80, False)):
        y0 = 10
        x1, x2, y1, y2 = x0 + r, x0 + r + c, y0 + r, y0 + r + c
        risco_baixo = '<rect %s y="%d" width="%%d" height="1"/>' % (lin, r - 1)
        risco_cima = '<rect %s y="0" width="%%d" height="1"/>' % lin
        if redondo_em_cima:
            peca(pre + "-topleft", x0, y0, r, r, '<path %s d="M0,%d H%d V0 A%d,%d 0 0 0 0,%d Z"/>' % (f, r, r, r, r, r))
            peca(pre + "-topright", x2, y0, r, r, '<path %s d="M0,0 V%d H%d A%d,%d 0 0 0 0,0 Z"/>' % (f, r, r, r, r))
            peca(pre + "-top", x1, y0, c, r, cheio(c, r))
            peca(pre + "-bottomleft", x0, y2, r, r, cheio(r, r) + risco_baixo % r)
            peca(pre + "-bottomright", x2, y2, r, r, cheio(r, r) + risco_baixo % r)
            peca(pre + "-bottom", x1, y2, c, r, cheio(c, r) + risco_baixo % c)
        else:
            peca(pre + "-topleft", x0, y0, r, r, cheio(r, r) + risco_cima % r)
            peca(pre + "-topright", x2, y0, r, r, cheio(r, r) + risco_cima % r)
            peca(pre + "-top", x1, y0, c, r, cheio(c, r) + risco_cima % c)
            peca(pre + "-bottomleft", x0, y2, r, r, '<path %s d="M0,0 H%d V%d A%d,%d 0 0 1 0,0 Z"/>' % (f, r, r, r, r))
            peca(pre + "-bottomright", x2, y2, r, r, '<path %s d="M0,0 H%d A%d,%d 0 0 1 0,%d Z"/>' % (f, r, r, r, r))
            peca(pre + "-bottom", x1, y2, c, r, cheio(c, r))
        peca(pre + "-left", x0, y1, r, c, cheio(r, c))
        peca(pre + "-right", x2, y1, r, c, cheio(r, c))
        peca(pre + "-center", x1, y1, c, c, cheio(c, c))
    # mesmas margens de dentro do tema do KDE (6), para o conteúdo não mudar de lugar
    pecas += [
        '<rect id="hint-top-margin" x="30" y="10" width="4" height="6" fill="#ff00ff"/>',
        '<rect id="hint-bottom-margin" x="30" y="60" width="4" height="6" fill="#ff00ff"/>',
        '<rect id="hint-left-margin" x="10" y="30" width="6" height="4" fill="#ff00ff"/>',
        '<rect id="hint-right-margin" x="60" y="30" width="6" height="4" fill="#ff00ff"/>',
    ]
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!-- Faixas dos balões do Matsu. Gerado por usr/share/matsu/vidro/gerar.py: não editar à mão. -->\n'
            '<svg xmlns="http://www.w3.org/2000/svg" id="svg2" version="1.1" width="150" height="80" viewBox="0 0 150 80">\n'
            + ESTILO_TAREFAS + "\n" + "\n".join(pecas) + "\n</svg>\n")


def main():
    global TINTA
    args = argparse.ArgumentParser(description="Gera o vidro do Matsu (tema Plasma).")
    args.add_argument("--cor", help="cor do vidro, #rrggbb (sem ela, vidro sem cor)")
    args.add_argument("--transparencia", choices=sorted(NIVEIS), default="normal")
    args.add_argument("--mac", action="store_true", help="balões com o vidro do Mac (o estilo Mac da barra)")
    args.add_argument("pasta", help="pasta do tema")
    opcoes = args.parse_args()
    if opcoes.cor:
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", opcoes.cor):
            args.error("cor precisa ser #rrggbb")
        TINTA = (opcoes.cor.lower(), FORCA_COR)
    nivel = NIVEIS[opcoes.transparencia]
    raiz = opcoes.pasta
    (ilha_vidro, ilha_sem), (balao_vidro, balao_sem) = nivel["ilha"], nivel["balao"]

    # O vidro do Mac: a doca e a barra de cima do estilo Mac (veja painel_mac).
    mac = NIVEIS_MAC[opcoes.transparencia]
    (doca_vidro, doca_sem), (topo_vidro, topo_sem) = mac["doca"], mac["topo"]
    # Só o estilo Mac tem barra no alto e doca de pé: na folha de sempre, esses
    # lugares já levam o vidro do Mac (mesmo se o Plasma não usar a folha "solid").
    versoes = {"translucent/widgets": (ilha_vidro, 0.20, 0.22, topo_vidro, doca_vidro, (0, 0, 0.12), (0.34, 0.22, 0.14)),
               "widgets": (ilha_sem, 0.16, 0.22, topo_sem, doca_sem, (0, 0, 0.10), (0.28, 0.18, 0.12)),
               "opaque/widgets": (1, 0.12, 0, 1, 1, 0.12, 0.12)}
    for pasta, (op, borda, somb, op_topo, op_pe, borda_topo, borda_pe) in versoes.items():
        os.makedirs(os.path.join(raiz, pasta), exist_ok=True)
        with open(os.path.join(raiz, pasta, "panel-background.svg"), "w") as f:
            f.write(painel(op, borda, somb, extras=(("north-", op_topo, borda_topo), ("west-", op_pe, borda_pe), ("east-", op_pe, borda_pe))))
    versoes_mac = {
        "translucent/solid/widgets": (doca_vidro, topo_vidro, (0.34, 0.22, 0.14), (0, 0, 0.12)),
        "solid/widgets": (doca_sem, topo_sem, (0.28, 0.18, 0.12), (0, 0, 0.10)),
    }
    for pasta, (op_doca, op_topo, borda_doca, borda_topo) in versoes_mac.items():
        os.makedirs(os.path.join(raiz, pasta), exist_ok=True)
        with open(os.path.join(raiz, pasta, "panel-background.svg"), "w") as f:
            f.write(painel_mac(op_doca, op_topo, borda_doca, borda_topo, 0.18, NIVEIS_DOCA[opcoes.transparencia]))
    with open(os.path.join(raiz, "widgets", "tasks.svg"), "w") as f:
        f.write(tarefas())
    # Balões (menu, bandeja, avisos, a escolha de telas do Meta+P): mesmos cantos e borda das ilhas.
    # Os balões que saem das barras do Mac (marcadas como opacas) o Plasma pede
    # "sólidos": aqui eles também são de vidro (sólidos só sem o efeito vidro).
    baloes = {"translucent/dialogs": (balao_vidro, 0.18, 0.26), "dialogs": (balao_sem, 0.14, 0.26),
              "translucent/solid/dialogs": (balao_vidro, 0.18, 0.26), "solid/dialogs": (balao_sem, 0.14, 0.26),
              "opaque/dialogs": (1, 0.12, 0)}
    rb, margem, luz, nome_balao, cobre = RB, 4, 0, "Fundo dos balões", 0.75
    if opcoes.mac:
        # Os avisos dos apps não saem de barra nenhuma (usam "dialogs"); os da
        # bandeja e do calendário saem da barra de cima (usam "solid/dialogs"):
        # todos com o mesmo vidro do Mac.
        vidro_mac, sem_mac = NIVEIS_BALAO_MAC[opcoes.transparencia]
        if TINTA:
            # Com uma cor escolhida, o vidro não fica mais claro que o das ilhas.
            vidro_mac, sem_mac = max(vidro_mac, balao_vidro - 0.06), max(sem_mac, balao_sem - 0.02)
        baloes = {"translucent/dialogs": (vidro_mac, BORDA_BALAO_MAC, 0.26), "dialogs": (sem_mac, BORDA_BALAO_MAC, 0.26),
                  "translucent/solid/dialogs": (vidro_mac, BORDA_BALAO_MAC, 0.26), "solid/dialogs": (sem_mac, BORDA_BALAO_MAC, 0.26),
                  "opaque/dialogs": (1, 0.12, 0)}
        rb, margem, luz, nome_balao, cobre = RB_MAC, MARGEM_BALAO_MAC, BRILHO_BALAO_MAC, "Fundo dos balões (vidro do Mac)", 0.30
    for pasta, (op, borda, somb) in baloes.items():
        os.makedirs(os.path.join(raiz, pasta), exist_ok=True)
        brilho = luz if op < 1 else 0
        with open(os.path.join(raiz, pasta, "background.svg"), "w") as f:
            f.write(painel(op, borda, somb, r=rb, mv=margem, mh=margem, grosso=False, nome=nome_balao, brilho=brilho))
    with open(os.path.join(raiz, "widgets", "plasmoidheading.svg"), "w") as f:
        f.write(cabecalho(rb, cobre))
    with open(os.path.join(raiz, "widgets", "tooltip.svg"), "w") as f:
        f.write(painel(0.97, 0.14, 0.22, r=RD, mv=4, mh=4, grosso=False, nome="Fundo das dicas"))
    meta = {
        "KPlugin": {
            "Authors": [{"Name": "Matsu OS"}],
            "Category": "",
            "Description": "Ilhas de vidro com cantos redondos, a cara do Matsu OS",
            "EnabledByDefault": True,
            "Id": "Matsu",
            "License": "MIT",
            "Name": "Matsu",
            "Version": "1.0",
        },
        "X-Plasma-API": "5.0",
    }
    with open(os.path.join(raiz, "metadata.json"), "w") as f:
        json.dump(meta, f, indent=4, ensure_ascii=False)
        f.write("\n")
    with open(os.path.join(raiz, "plasmarc"), "w") as f:
        f.write("[AdaptiveTransparency]\nenabled=true\n")
        # As cores atrás do vidro ficam mais vivas, como no Mac (só com o efeito
        # vidro; contraste e brilho 1 = sem mudar, só a saturação sobe).
        if opcoes.transparencia != "sem":
            f.write("\n[ContrastEffect]\nenabled=true\ncontrast=1\nintensity=1\nsaturation=1.5\n")
    print("tema Plasma do Matsu em", raiz)


if __name__ == "__main__":
    main()
