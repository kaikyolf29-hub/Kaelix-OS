#!/usr/bin/env python3
"""Gera o papel de parede do Matsu OS em pixel art.

Desenha um pôr do sol num lago, em 640x360, e amplia 6 vezes (3840x2160) sem
borrar. Tudo é feito por código, com sorteio fixo: rodar de novo dá a mesma imagem.

Uso: gerar.py <pasta-de-saida>   (cria escuro.png e claro.png)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

W, H, ESCALA = 640, 360, 6
HORIZONTE = 214
SOL_X, SOL_Y, SOL_R = 432, HORIZONTE - 26, 58

BAYER = np.array([
    [0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
    [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
    [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]]) / 64.0


def cor(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32)


TEMAS = {
    "escuro": dict(
        ceu=["#1C2142", "#20264A", "#283058", "#343A72", "#4A428E", "#6E4C9E", "#A0569E", "#D46A90", "#F08E78", "#F6B468", "#F9D288"],
        sol=["#FCE9A0", "#FAD080", "#F6B066", "#F28C66", "#EC6C80"],
        montes=["#6A4E9C", "#4A4590", "#353A78"], brilho="#F08E78",
        agua=["#3A3F7E", "#2B3360", "#222848", "#1E2444"], reflexo=["#F9D288", "#F6B468", "#F08E78", "#D46A90"],
        margem="#1C2142", pinheiro=["#191D3A", "#242A52"], nuvem=["#5A4A96", "#8A559E", "#D46A90", "#F6A070"],
        estrelas=["#F1F3FA", "#B9C0DA", "#8FA2FF", "#F9D288"], n_estrelas=230),
    "claro": dict(
        ceu=["#A9BCF2", "#B9C9F5", "#C9D6F8", "#D9E2FA", "#E6EAFB", "#F1EBF6", "#F8E6E6", "#FBDFCB", "#FCD6A8", "#FDD08E", "#FEE0A6"],
        sol=["#FFF6D2", "#FFE9AE", "#FDD88E", "#FAC27A", "#F6AE78"],
        montes=["#B7B4EC", "#98A4E4", "#7C8CD6"], brilho="#FCE2C4",
        agua=["#C3CEF6", "#AEBCF0", "#9AAAE8", "#8A9BE0"], reflexo=["#FFF6D2", "#FFE9AE", "#FDD08E", "#FBDFCB"],
        margem="#5F6EC0", pinheiro=["#3F4A92", "#5565B4"], nuvem=["#FFFFFF", "#F6F2FB", "#FBE4DC", "#FCD6B4"],
        estrelas=[], n_estrelas=0),
}


def pintar(nome):
    t = TEMAS[nome]
    rng = np.random.default_rng(2026)
    img = np.zeros((H, W, 3), dtype=np.float32)
    yy, xx = np.mgrid[0:H, 0:W]
    bay = BAYER[yy % 8, xx % 8]

    def faixas(paleta, pos):
        """Escolhe a cor da paleta para cada ponto, com pontilhado entre faixas vizinhas."""
        pal = np.array([cor(c) for c in paleta])
        p = np.clip(pos, 0, 1) * (len(pal) - 1)
        i = np.floor(p).astype(int)
        i = np.where((p - i) > bay, i + 1, i)
        return pal[np.clip(i, 0, len(pal) - 1)]

    # Céu: mais escuro em cima, quente perto do horizonte e em volta do sol.
    dist = np.hypot(xx - SOL_X, (yy - SOL_Y) * 1.25)
    pos_ceu = (yy / HORIZONTE) ** 1.55 * 0.9 + 0.2 * np.exp(-(dist / 120.0) ** 2) * (yy / HORIZONTE)
    ceu = faixas(t["ceu"], pos_ceu)
    img[:] = ceu

    # Estrelas.
    pal_e = [cor(c) for c in t["estrelas"]]
    for _ in range(t["n_estrelas"]):
        x, y = int(rng.integers(0, W)), int(rng.integers(0, int(HORIZONTE * 0.62)))
        if rng.random() < (y / (HORIZONTE * 0.62)) ** 2 or abs(x - SOL_X) < 90 and y > 70:
            continue
        c = pal_e[int(rng.integers(0, len(pal_e)))]
        img[y, x] = c
        if rng.random() < 0.07 and 2 < x < W - 2 and y > 2:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img[y + dy, x + dx] = c * 0.6 + img[y + dy, x + dx] * 0.4

    # Sol com cortes na parte de baixo.
    ds = np.hypot(xx - SOL_X, yy - SOL_Y)
    dentro = ds <= SOL_R
    alt = (yy - (SOL_Y - SOL_R)) / (2.0 * SOL_R)
    sol = faixas(t["sol"], alt * 1.25)
    corte = np.zeros((H, W), dtype=bool)
    y0, k = SOL_Y - 8, 0
    while y0 < SOL_Y + SOL_R:
        esp = 1 + k // 2
        corte |= (yy >= y0) & (yy < y0 + esp)
        y0 += esp + max(8 - k, 3)
        k += 1
    img[dentro & ~corte] = sol[dentro & ~corte]

    # Nuvens baixas, em tiras.
    pal_n = [cor(c) for c in t["nuvem"]]
    for cx, cy, larg in ((120, 150, 70), (250, 172, 110), (560, 160, 80), (360, 128, 60), (40, 186, 90), (600, 192, 70), (500, 110, 44)):
        linhas = 5 if larg > 60 else 4
        for r in range(linhas):
            fr = 1 - abs(r - (linhas - 1) / 2) / (linhas / 2)
            meia = int(larg * (0.35 + 0.65 * fr) / 2 + rng.integers(-6, 7))
            desl = int(rng.integers(-8, 9))
            y = cy + r
            tom = pal_n[min(len(pal_n) - 1, int(r / linhas * len(pal_n) + (y / HORIZONTE) * 0.8))]
            x0, x1 = max(0, cx - meia + desl), min(W, cx + meia + desl)
            if nome == "escuro":
                img[y, x0:x1] = img[y, x0:x1] * 0.35 + tom * 0.65
            else:
                img[y, x0:x1] = img[y, x0:x1] * 0.15 + tom * 0.85

    # Montanhas em três camadas.
    def serra(base, amp, semente, passo):
        r = np.random.default_rng(semente)
        x = np.arange(W)
        y = np.zeros(W)
        for f, a in ((1.3, 1.0), (2.9, 0.5), (6.1, 0.26), (13.7, 0.12)):
            y += a * np.sin(x / W * 2 * np.pi * f + r.random() * 6.28)
        y = base - amp * (y / 1.9 * 0.5 + 0.5)
        return (np.round(y / passo) * passo).astype(int)

    brilho = cor(t["brilho"])
    for n, (base, amp, sem, passo) in enumerate(((HORIZONTE + 4, 52, 11, 2), (HORIZONTE + 8, 40, 23, 2), (HORIZONTE + 10, 26, 37, 1))):
        topo = serra(base, amp, sem, passo)
        c = cor(t["montes"][n])
        for x in range(W):
            y0 = max(0, topo[x])
            img[y0:HORIZONTE + 12, x] = c
            # Luz do sol na encosta virada para ele.
            vira = (topo[min(W - 1, x + 3)] - topo[max(0, x - 3)]) * (1 if x < SOL_X else -1)
            if vira < 0:
                forca = 0.55 * np.exp(-abs(x - SOL_X) / 260.0) * (1 - n * 0.22)
                for d in range(0, 5):
                    if y0 + d < H and BAYER[(y0 + d) % 8, x % 8] > d / 5.0:
                        img[y0 + d, x] = c * (1 - forca) + brilho * forca

    # Lago: reflete o céu, com ondas em tiras.
    borda = HORIZONTE + 12
    agua = faixas(t["agua"], (yy - borda) / (H - borda) * 1.15)
    for y in range(borda, H):
        prof = (y - borda) / (H - borda)
        origem = int(np.clip(HORIZONTE - 2 - (y - borda) * 1.9, 0, HORIZONTE - 1))
        onda = int(np.round(3 * np.sin(y * 0.9) + 2 * np.sin(y * 0.37 + 1.3)))
        linha = np.roll(ceu[origem], onda, axis=0)
        mistura = 0.62 * (1 - prof) ** 1.6
        img[y] = agua[y] * (1 - mistura) + linha * mistura
        # Tiras quebradas do reflexo do sol.
        pal_r = [cor(c) for c in t["reflexo"]]
        alcance = 10 + (y - borda) * 0.95
        n_tiras = int(7 - 5 * prof) if (y % 2 == 0 or prof < 0.25) else 0
        for _ in range(max(0, n_tiras)):
            cxr = SOL_X + rng.normal(0, alcance * 0.42)
            comp = int(rng.integers(3, 6 + int(16 * (1 - prof))))
            x0, x1 = int(max(0, cxr - comp / 2)), int(min(W, cxr + comp / 2))
            tom = pal_r[min(len(pal_r) - 1, int(prof * len(pal_r) * 1.3 + rng.random() * 0.8))]
            f = 0.95 - 0.5 * prof
            img[y, x0:x1] = img[y, x0:x1] * (1 - f) + tom * f

    # Margem escura embaixo, onde ficam as ilhas da barra, e pinheiros nos cantos.
    margem = cor(t["margem"])
    chao = serra(H - 26, 16, 51, 1)
    chao = np.maximum(chao, H - 46)
    for x in range(W):
        afasta = min(1.0, abs(x - W / 2) / (W / 2))
        y0 = int(chao[x] + 22 * (1 - afasta) ** 2)
        img[min(H, y0):, x] = margem

    p_esc, p_luz = cor(t["pinheiro"][0]), cor(t["pinheiro"][1])

    def pinheiro(xb, yb, alt):
        larg = alt * 0.2
        for i in range(alt):
            y = yb - alt + i
            if not 0 <= y < H:
                continue
            frac = i / alt
            dente = (i % 7) / 7.0
            meia = int(1 + larg * frac * (0.45 + 0.55 * dente))
            if i > alt * 0.93:
                meia = 1
            for x in range(xb - meia, xb + meia + 1):
                if 0 <= x < W:
                    lado_sol = (x - xb) * (1 if xb < SOL_X else -1) > meia * 0.35
                    img[y, x] = p_luz if (lado_sol and BAYER[y % 8, x % 8] > 0.45) else p_esc

    arvores = [(18, 338, 150), (52, 344, 118), (86, 348, 90), (120, 350, 62), (150, 352, 44), (-4, 346, 110), (36, 352, 76),
               (622, 338, 158), (590, 344, 124), (556, 348, 92), (524, 350, 66), (496, 352, 46), (644, 348, 112), (606, 352, 80)]
    for xb, yb, alt in sorted(arvores, key=lambda a: a[2], reverse=True):
        pinheiro(xb, yb, alt)

    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def main():
    saida = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    saida.mkdir(parents=True, exist_ok=True)
    for nome in TEMAS:
        pequeno = pintar(nome)
        grande = pequeno.resize((W * ESCALA, H * ESCALA), Image.NEAREST)
        grande = grande.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        grande.save(saida / f"{nome}.png", optimize=True)
        pequeno.resize((W * 2, H * 2), Image.NEAREST).save(saida / f"previa-{nome}.png")
        print(nome, (saida / f"{nome}.png").stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
