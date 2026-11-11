#!/usr/bin/env python3
"""Logo do Matsu OS: o pinheiro japonês (matsu, 松) podado em nuvens, como um
niwaki ou um bonsai: tronco em S, raiz abrindo no chão, três galhos e quatro
almofadas de folhas com a parte de cima em lóbulos.

O desenho é feito de curvas e depois vira um contorno só (com o Shapely): as
frestas entre as folhas e a madeira são cortes de verdade, então o emblema
fica certo em cima de qualquer fundo, até transparente, e em qualquer
programa que leia SVG (o Plasma, o Plymouth, o instalador).

Uso: python3 visual/logo/gerar.py   (precisa do Shapely: pip install shapely)

Gera:
  visual/logo/matsu-logo.svg            logo com o fundo escuro arredondado
  visual/logo/matsu-emblema-claro.svg   só o pinheiro, branco (fundo escuro)
  visual/logo/matsu-emblema-escuro.svg  só o pinheiro, escuro (fundo claro)
e as cópias que o sistema usa (logo do sistema, botão do menu, tela de
carregar do Plasma).
"""
import math
from pathlib import Path

from shapely.geometry import Polygon, box
from shapely.geometry.polygon import orient
from shapely.ops import unary_union

RAIZ = Path(__file__).resolve().parents[2]
FUNDO = "#141517"     # quase preto neutro, o mesmo vidro escuro do sistema
DESENHO = "#F4F5F7"   # branco suave
CHAO = 452            # onde a raiz encosta
FRESTA = 5.5          # metade da largura das frestas entre as peças
E = 1.18              # espessura geral (tronco, galhos e folhas)


# ----- curvas -----
def cubica(p0, p1, p2, p3, n=48):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                    u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]))
    return pts


def quadratica(p0, p1, p2, n=24):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                    u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]))
    return pts


def _bez(c, t):
    u = 1 - t
    return (u**3 * c[0][0] + 3 * u * u * t * c[1][0] + 3 * u * t * t * c[2][0] + t**3 * c[3][0],
            u**3 * c[0][1] + 3 * u * u * t * c[1][1] + 3 * u * t * t * c[2][1] + t**3 * c[3][1])


# ----- peças -----
def largura(t, w0, w1):
    return w0 + (w1 - w0) * t ** 0.8


def tronco(c, w0, w1, n=160):
    """Tronco afinando ao longo da curva c (cúbica)."""
    esq, dir_ = [], []
    for i in range(n + 1):
        t = i / n
        a, b, m = _bez(c, max(0, t - 0.004)), _bez(c, min(1, t + 0.004)), _bez(c, t)
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        w = largura(t, w0, w1) / 2
        nx, ny = -dy / L, dx / L
        esq.append((m[0] + nx * w, m[1] + ny * w))
        dir_.append((m[0] - nx * w, m[1] - ny * w))
    return Polygon(esq + dir_[::-1]).buffer(0)


def no_y(c, y):
    """Ponto do meio do tronco na altura y, e o t da curva ali."""
    melhor, d = (0, 0), 1e9
    for i in range(1201):
        t = i / 1200
        q = _bez(c, t)
        if abs(q[1] - y) < d:
            d, melhor = abs(q[1] - y), (q[0], t)
    return melhor


def galho(a, b, wa, wb):
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    return Polygon([(a[0] + nx * wa / 2, a[1] + ny * wa / 2), (b[0] + nx * wb / 2, b[1] + ny * wb / 2),
                    (b[0] - nx * wb / 2, b[1] - ny * wb / 2), (a[0] - nx * wa / 2, a[1] - ny * wa / 2)])


def nuvem(cx, by, w, h, lobos, cusp=0.6, e=0.22):
    """Almofada de folhas: fundo reto com as pontas arredondadas e lóbulos lisos
    em cima. lobos: [(largura, altura), ...] da esquerda para a direita."""
    x1, x2, r = cx - w / 2, cx + w / 2, h * 0.34
    tot = sum(l[0] for l in lobos)
    xs = [x1]
    for l in lobos:
        xs.append(xs[-1] + l[0] / tot * w)
    ys = [by - h * e if i in (0, len(xs) - 1) else by - h * cusp for i in range(len(xs))]
    pts = quadratica((x1, by - h * e), (x1, by), (x1 + r, by))
    pts += quadratica((x2 - r, by), (x2, by), (x2, by - h * e))
    for i in range(len(lobos) - 1, -1, -1):
        xa, ya, xb, yb = xs[i + 1], ys[i + 1], xs[i], ys[i]
        pico = by - lobos[i][1] * h
        k = ((ya + yb) / 2 - pico) / 0.75
        lw = xa - xb
        pts += cubica((xa, ya), (xa + (lw * 0.02 if i == len(lobos) - 1 else 0), ya - k),
                      (xb - (lw * 0.02 if i == 0 else 0), yb - k), (xb, yb))[1:]
    return Polygon(pts).buffer(0)


D5 = [(0.9, 0.62), (1, 0.86), (1.2, 1), (1, 0.86), (0.9, 0.64)]
D4 = [(1, 0.7), (1.2, 1), (1.1, 0.9), (0.9, 0.66)]


def pinheiro():
    """O pinheiro inteiro, num contorno só (coordenadas de 0 a 512)."""
    c = [(228, 456), (248, 384), (118, 330), (276, 152)]
    w0, w1 = 50 * E, 11 * E
    madeira = tronco(c, w0, w1).intersection(box(0, 0, 512, CHAO))
    # Raiz: nasce de dentro do tronco, desce colada na borda dele e abre em
    # curva até o chão, sem degrau.
    H = 34
    xa, ta = no_y(c, CHAO - H)
    xc, _ = no_y(c, CHAO)
    hw = largura(ta, w0, w1) / 2 - 4
    L = math.hypot(c[0][0] - c[1][0], c[0][1] - c[1][1])
    dx, dy = (c[0][0] - c[1][0]) / L, (c[0][1] - c[1][1]) / L
    k = H * 0.55
    l1, r1 = (xa - hw, CHAO - H), (xa + hw, CHAO - H)
    l0, r0 = (xc - hw - 44, CHAO), (xc + hw + 50, CHAO)
    raiz = cubica(l1, (l1[0] + dx * k, l1[1] + dy * k), (l1[0] + dx * k - 6, CHAO), l0)
    raiz += cubica(r0, (r1[0] + dx * k + 8, CHAO), (r1[0] + dx * k, r1[1] + dy * k), r1)
    madeira = unary_union([madeira, Polygon(raiz).buffer(0)])
    # Galhos nascendo do meio do tronco (a ponta de dentro fica escondida nele).
    for y, b, wa, wb in ((330, (352, 296), 19, 8), (276, (140, 262), 17, 7), (222, (326, 198), 14, 6)):
        madeira = unary_union([madeira, galho((no_y(c, y)[0], y), b, wa * E, wb * E)])
    # Folhas, de trás para a frente: cada uma abre uma fresta no que está atrás.
    folhas = [nuvem(158, 268, 184, 50 * E, D5), nuvem(364, 302, 176, 50 * E, D5),
              nuvem(336, 202, 150, 46 * E, D4), nuvem(258, 150, 140, 60 * E, D5)]
    pecas = [madeira] + folhas
    for i in range(len(pecas)):
        frente = [f.buffer(FRESTA, join_style="round") for f in folhas[max(0, i):] if f is not pecas[i]]
        if frente:
            pecas[i] = pecas[i].difference(unary_union(frente))
    return unary_union(pecas)


# ----- SVG -----
def caminho(geo, escala=1.0, dx=0.0, dy=0.0):
    geo = orient(geo, 1.0) if geo.geom_type == "Polygon" else type(geo)([orient(g, 1.0) for g in geo.geoms])
    partes = []
    for p in (geo.geoms if hasattr(geo, "geoms") else [geo]):
        for anel in [p.exterior] + list(p.interiors):
            cs = list(anel.coords)[:-1]
            partes.append("M" + "L".join(f"{x * escala + dx:.1f},{y * escala + dy:.1f}" for x, y in cs) + "Z")
    return "".join(partes)


def logo(geo, comentario, fundo=FUNDO, desenho=DESENHO, ocupa=0.66):
    x0, y0, x1, y1 = geo.bounds
    s = 512 * ocupa / max(x1 - x0, y1 - y0)
    dx = 256 - (x0 + x1) / 2 * s
    dy = 256 - (y0 + y1) / 2 * s + 6   # um tico abaixo do meio: o peso visual fica no alto
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">\n  <!-- {comentario} -->\n'
            f'  <rect width="512" height="512" rx="118" fill="{fundo}"/>\n'
            f'  <path fill="{desenho}" d="{caminho(geo, s, dx, dy)}"/>\n</svg>\n')


def emblema(geo, cor, comentario):
    x0, y0, x1, y1 = geo.bounds
    lado = max(x1 - x0, y1 - y0) * 1.04
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    vb = f"{cx - lado / 2:.1f} {cy - lado / 2:.1f} {lado:.1f} {lado:.1f}"
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}">\n  <!-- {comentario} -->\n'
            f'  <path fill="{cor}" d="{caminho(geo)}"/>\n</svg>\n')


def main():
    geo = pinheiro().simplify(0.08, preserve_topology=True)
    aqui = RAIZ / "visual/logo"
    sistema = RAIZ / "system_files/usr/share"
    nota = "Logo do Matsu OS: o pinheiro japonês (matsu) podado em nuvens. Gerado por visual/logo/gerar.py."
    arquivos = {
        aqui / "matsu-logo.svg": logo(geo, nota),
        aqui / "matsu-emblema-claro.svg": emblema(geo, DESENHO, nota + " Branco, para fundo escuro."),
        aqui / "matsu-emblema-escuro.svg": emblema(geo, FUNDO, nota + " Escuro, para fundo claro."),
        sistema / "icons/hicolor/scalable/apps/matsu-logo.svg": logo(geo, nota),
        sistema / "icons/hicolor/scalable/apps/matsu-menu.svg": logo(geo, nota + " Botão do menu.", ocupa=0.7),
        sistema / "pixmaps/matsu-logo.svg": logo(geo, nota),
        sistema / "plasma/look-and-feel/org.matsu.escuro.desktop/contents/splash/images/emblema.svg":
            emblema(geo, DESENHO, nota + " Tela de carregar do Plasma."),
    }
    for caminho_, texto in arquivos.items():
        caminho_.parent.mkdir(parents=True, exist_ok=True)
        caminho_.write_text(texto)
        print(caminho_.relative_to(RAIZ), len(texto), "bytes")


if __name__ == "__main__":
    main()
