#!/usr/bin/env python3
"""Logo do Matsu OS: um bonsai dentro do ensō (o círculo de pincel zen), em rosa
de cerejeira sobre um fundo ameixa.

A árvore tem uma copa larga em nuvem no alto, uma almofada menor embaixo à
esquerda, presa por um galho, e o tronco em S que abre um pouco no pé. O anel
tem pontas redondas e fica aberto no alto, à direita. Nasceu da junção das duas
imagens de referência que o Kaiky mandou em 11/11/2026: a árvore da segunda com
o rosa e o acabamento da primeira.

O desenho é feito de formas (com o Shapely): as frestas entre as folhas e a
madeira são cortes de verdade, então o emblema fica certo em cima de qualquer
fundo, até transparente, e em qualquer programa que leia SVG (o Plasma, o
Plymouth, o instalador).

Uso: python3 visual/logo/gerar.py   (precisa do Shapely: pip install shapely)

Gera:
  visual/logo/matsu-logo.svg            logo com o fundo ameixa arredondado
  visual/logo/matsu-emblema-claro.svg   só o anel e a árvore, para fundo escuro
  visual/logo/matsu-emblema-escuro.svg  só o anel e a árvore, mais forte, para fundo claro
e as cópias que o sistema usa (logo do sistema, botão do menu, tela de
carregar do Plasma) e o desenho em letras do fastfetch.
"""
import math
from pathlib import Path

from shapely.affinity import scale, translate
from shapely.geometry import LineString, Point, Polygon, box
from shapely.geometry.polygon import orient
from shapely.ops import unary_union

RAIZ = Path(__file__).resolve().parents[2]
CX, CY = 256, 262     # meio do anel
CHAO = 414            # onde o pé do tronco encosta
FRESTA = 5.5          # largura da fresta entre as folhas e a madeira
ESCALA = 0.9          # a árvore um pouco menor que o desenho, com folga até o anel

# Degradês (do alto à esquerda para baixo à direita): (cor de cima, cor de baixo).
ROSA = {
    "fundo": ("#6a4862", "#1b1120"),
    "anel": ("#f0bfd6", "#b0668f"),
    "folhas": ("#fde6f1", "#f0a6cc"),
    "madeira": ("#e6b4cb", "#c98aac"),
}
# Para fundo claro: o mesmo rosa, mais fundo, para não sumir no branco.
ROSA_FORTE = {
    "anel": ("#d47ea8", "#8e3f6c"),
    "folhas": ("#f39cc6", "#d9659f"),
    "madeira": ("#c7819f", "#9a5577"),
}


# ----- formas -----
def cubica(p0, p1, p2, p3, n=96):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                    u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]))
    return pts


def traco(pts, larg):
    """Faixa ao longo da linha pts, com a largura larg(t) (t de 0 a 1)."""
    esq, dir_ = [], []
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L, dx / L
        w = larg(i / (n - 1)) / 2
        esq.append((x + nx * w, y + ny * w))
        dir_.append((x - nx * w, y - ny * w))
    return Polygon(esq + dir_[::-1]).buffer(0)


def bola(x, y, r):
    return Point(x, y).buffer(r, 64)


def macio(g, r):
    """Arredonda os vãos entre os lóbulos (curva lisa, sem bico)."""
    return g.buffer(r, 64).buffer(-r, 64)


def anel(abre=-92, fecha=-44, R=178, w=28):
    """O ensō: aberto entre os ângulos abre e fecha (graus, 0 = direita, sentido
    horário), largura w e pontas redondas."""
    a0, a1 = math.radians(fecha), math.radians(abre + 360)
    pts = [(CX + R * math.cos(a0 + (a1 - a0) * i / 400), CY + R * math.sin(a0 + (a1 - a0) * i / 400))
           for i in range(401)]
    return LineString(pts).buffer(w / 2, 64, cap_style=1)


def arvore():
    """Folhas e madeira do bonsai, já com a fresta entre elas."""
    # Copa de cima: larga e baixa, lóbulos em cima e embaixo.
    copa = macio(unary_union([
        bola(204, 226, 30), bola(246, 198, 40), bola(302, 184, 44), bola(354, 204, 34), bola(380, 234, 22),
        bola(214, 250, 22), bola(252, 256, 26), bola(302, 258, 26), bola(350, 250, 24),
        box(214, 214, 370, 252),
    ]), 16)
    # Almofada de baixo, à esquerda: dois lóbulos.
    baixa = macio(unary_union([
        bola(128, 302, 30), bola(170, 292, 34), bola(208, 306, 22), bola(120, 318, 18), bola(176, 322, 18),
        box(120, 300, 206, 324),
    ]), 14)
    # Tronco em S: sobe reto do pé, puxa para a direita e entra na copa.
    linha = cubica((214, CHAO + 10), (208, 352), (304, 352), (300, 240))
    tronco = traco(linha, lambda t: 26 + 30 * (1 - t) ** 1.4 + max(0, 0.08 - t) * 120)
    # Galho saindo do tronco por baixo da almofada da esquerda; a ponta de
    # dentro fica escondida no tronco e a emenda é arredondada.
    p0 = linha[int(len(linha) * 0.30)]
    galho = traco(cubica(p0, (p0[0] - 24, p0[1] - 6), (196, 346), (176, 322)), lambda t: 19 - 7 * t)
    pe = scale(Point(216, CHAO).buffer(1, 64), 40, 13)   # o pé abre um pouco no chão
    madeira = macio(unary_union([tronco, galho, bola(p0[0], p0[1], 10), pe]), 9).intersection(box(0, 0, 512, CHAO))
    folhas = unary_union([copa, baixa])
    madeira = madeira.difference(folhas.buffer(FRESTA, 64))
    ajusta = lambda g: translate(scale(g, ESCALA, ESCALA, origin=(256, 280)), 4, 0)
    return ajusta(folhas), ajusta(madeira)


def pecas():
    folhas, madeira = arvore()
    return {
        "anel": anel().simplify(0.06, preserve_topology=True),
        "madeira": madeira.simplify(0.06, preserve_topology=True),
        "folhas": folhas.simplify(0.06, preserve_topology=True),
    }


# ----- SVG -----
def caminho(geo):
    partes = []
    for p in (geo.geoms if hasattr(geo, "geoms") else [geo]):
        p = orient(p, 1.0)
        for anel_ in [p.exterior] + list(p.interiors):
            cs = list(anel_.coords)[:-1]
            partes.append("M" + "L".join(f"{x:.1f},{y:.1f}" for x, y in cs) + "Z")
    return "".join(partes)


def degrade(id_, cores, x1, y1, x2, y2):
    return (f'<linearGradient id="{id_}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
            f'<stop offset="0" stop-color="{cores[0]}"/><stop offset="1" stop-color="{cores[1]}"/></linearGradient>')


def desenho(p, cores, prefixo):
    """Anel, madeira e folhas, cada um com o seu degradê (ids com prefixo, para
    não brigarem quando dois SVGs vão parar na mesma página)."""
    defs = (degrade(f"{prefixo}-anel", cores["anel"], 120, 90, 400, 450) +
            degrade(f"{prefixo}-madeira", cores["madeira"], 230, 250, 290, 420) +
            degrade(f"{prefixo}-folhas", cores["folhas"], 130, 150, 390, 330))
    corpo = (f'  <path fill="url(#{prefixo}-anel)" d="{caminho(p["anel"])}"/>\n'
             f'  <path fill="url(#{prefixo}-madeira)" d="{caminho(p["madeira"])}"/>\n'
             f'  <path fill="url(#{prefixo}-folhas)" d="{caminho(p["folhas"])}"/>\n')
    return defs, corpo


def logo(p, comentario):
    defs, corpo = desenho(p, ROSA, "matsu")
    defs = degrade("matsu-fundo", ROSA["fundo"], 90, 0, 420, 512) + defs
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">\n  <!-- {comentario} -->\n'
            f'  <defs>{defs}</defs>\n'
            '  <rect width="512" height="512" rx="118" fill="url(#matsu-fundo)"/>\n'
            '  <rect x="1" y="1" width="510" height="510" rx="117" fill="none" stroke="#ffffff" stroke-opacity="0.1" stroke-width="2"/>\n'
            f'{corpo}</svg>\n')


def emblema(p, cores, comentario):
    """Só o anel e a árvore, recortado bem rente ao anel."""
    x0, y0, x1, y1 = p["anel"].bounds
    lado = max(x1 - x0, y1 - y0) * 1.02
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    vb = f"{cx - lado / 2:.1f} {cy - lado / 2:.1f} {lado:.1f} {lado:.1f}"
    defs, corpo = desenho(p, cores, "matsu")
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}">\n  <!-- {comentario} -->\n'
            f'  <defs>{defs}</defs>\n{corpo}</svg>\n')


# ----- fastfetch -----
QUADRANTES = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"   # índice: 1 alto-esq, 2 alto-dir, 4 baixo-esq, 8 baixo-dir


def letras(p, colunas=34):
    """O logo em caracteres de bloco (2x2 pontos por letra), para o fastfetch.
    Uma letra do terminal é duas vezes mais alta que larga, então cada ponto
    mede w x 2w e acende quando mais da metade dele está pintada. As frestas
    somem (não cabem em letras): o anel sai na cor $1, as folhas na $2 e a
    madeira na $3."""
    x0, y0, x1, y1 = p["anel"].bounds
    w = (x1 - x0) / (colunas * 2)
    y0 -= w   # meio ponto para cima: assim o fundo do anel cai inteiro numa linha
    linhas_n = math.ceil((y1 - y0) / (w * 4))
    folhas = p["folhas"].buffer(FRESTA * 0.7, 32)
    formas = (("$1", p["anel"]), ("$2", folhas), ("$3", p["madeira"].difference(folhas)))
    amostras = [((i + 0.5) / 3, (j + 0.5) / 3) for i in range(3) for j in range(3)]
    linhas = []
    for li in range(linhas_n):
        texto, cor_atual = "", None
        for co in range(colunas):
            bits, votos = 0, {}
            for k, (dx, dy) in enumerate(((0, 0), (1, 0), (0, 1), (1, 1))):
                conta = {}
                for ax, ay in amostras:
                    ponto = Point(x0 + (co * 2 + dx + ax) * w, y0 + (li * 2 + dy + ay) * w * 2)
                    for cor, forma in formas:
                        if forma.contains(ponto):
                            conta[cor] = conta.get(cor, 0) + 1
                            votos[cor] = votos.get(cor, 0) + 1
                            break
                # o anel acende com um pouco menos, para não abrir buracos nele
                if conta.get("$1", 0) >= 4 or conta.get("$2", 0) + conta.get("$3", 0) >= 5:
                    bits |= 1 << k
            if bits:
                cor = max(votos, key=votos.get)
                if cor != cor_atual:
                    texto += cor
                    cor_atual = cor
            texto += QUADRANTES[bits]
        linhas.append(texto.rstrip())
    while linhas and not linhas[-1].strip():
        linhas.pop()
    return "\n".join(linhas) + "\n"


def main():
    p = pecas()
    aqui = RAIZ / "visual/logo"
    sistema = RAIZ / "system_files/usr/share"
    nota = "Logo do Matsu OS: o bonsai no ensō, em rosa de cerejeira. Gerado por visual/logo/gerar.py."
    arquivos = {
        aqui / "matsu-logo.svg": logo(p, nota),
        aqui / "matsu-emblema-claro.svg": emblema(p, ROSA, nota + " Para fundo escuro."),
        aqui / "matsu-emblema-escuro.svg": emblema(p, ROSA_FORTE, nota + " Para fundo claro."),
        sistema / "icons/hicolor/scalable/apps/matsu-logo.svg": logo(p, nota),
        sistema / "icons/hicolor/scalable/apps/matsu-menu.svg": logo(p, nota + " Botão do menu."),
        sistema / "pixmaps/matsu-logo.svg": logo(p, nota),
        sistema / "plasma/look-and-feel/org.matsu.escuro.desktop/contents/splash/images/emblema.svg":
            emblema(p, ROSA, nota + " Tela de carregar do Plasma."),
        sistema / "matsu/fastfetch/logo.txt": letras(p),
    }
    for caminho_, texto in arquivos.items():
        caminho_.parent.mkdir(parents=True, exist_ok=True)
        caminho_.write_text(texto)
        print(caminho_.relative_to(RAIZ), len(texto), "bytes")


if __name__ == "__main__":
    main()
