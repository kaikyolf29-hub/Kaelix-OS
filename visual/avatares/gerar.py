#!/usr/bin/env python3
"""Fotos prontas do Matsu para a conta da pessoa (Ajustes > Sua conta).

Pixel art no clima do papel de parede (o pôr do sol no lago): seis desenhos numa
grade de 32x32, aumentados para 512x512 sem borrar. Saem em PNG (o AccountsService,
que guarda a foto da tela de login, só aceita imagem comum) em
system_files/usr/share/matsu/avatares/. Sem bibliotecas de fora: o PNG é escrito aqui.

Uso: python3 visual/avatares/gerar.py
"""
import struct
import zlib
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
DESTINO = RAIZ / "system_files/usr/share/matsu/avatares"
N = 32
ESCALA = 16


def cor(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mistura(a, b, t):
    a, b = cor(a), cor(b)
    return "#%02x%02x%02x" % tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


class Tela:
    def __init__(self):
        self.p = [["#000000"] * N for _ in range(N)]

    def px(self, x, y, c):
        if 0 <= x < N and 0 <= y < N:
            self.p[y][x] = c

    def degrade(self, de, ate, faixas=8, y0=0, y1=N):
        altura = y1 - y0
        for y in range(y0, y1):
            t = min(faixas - 1, int((y - y0) * faixas / altura)) / max(1, faixas - 1)
            c = mistura(de, ate, t)
            for x in range(N):
                self.p[y][x] = c

    def circulo(self, cx, cy, r, c, so=None):
        for y in range(N):
            for x in range(N):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r and (so is None or so(x, y)):
                    self.p[y][x] = c

    def retangulo(self, x0, y0, x1, y1, c):
        for y in range(max(0, y0), min(N, y1)):
            for x in range(max(0, x0), min(N, x1)):
                self.p[y][x] = c

    def triangulo(self, cx, topo, base, meia, c):
        """Triângulo em pé: ponta em (cx, topo), base de largura 2*meia na linha base."""
        for y in range(topo, base + 1):
            t = (y - topo) / max(1, base - topo)
            m = round(meia * t)
            for x in range(cx - m, cx + m + 1):
                self.px(x, y, c)

    def pinheiro(self, cx, topo, altura, c, claro=None):
        andares = 3
        alto = altura // andares
        for i in range(andares):
            t0 = topo + i * (alto - 1)
            self.triangulo(cx, t0, t0 + alto + 1, 2 + i * 2 * altura // 14, c)
            if claro:
                self.triangulo(cx - 1, t0 + 1, t0 + alto, 1 + i * altura // 14, claro)
                self.triangulo(cx, t0, t0 + alto + 1, 0, c)
        self.retangulo(cx - 1 + (altura < 12), topo + altura, cx + 1, topo + altura + 2, mistura(c, "#000000", 0.4))

    def png(self, caminho):
        linhas = b""
        for y in range(N):
            linha = b"".join(bytes(cor(self.p[y][x])) * ESCALA for x in range(N))
            linhas += (b"\x00" + linha) * ESCALA
        lado = N * ESCALA

        def bloco(tipo, dados):
            return struct.pack(">I", len(dados)) + tipo + dados + struct.pack(">I", zlib.crc32(tipo + dados) & 0xffffffff)

        dados = (b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", struct.pack(">IIBBBBB", lado, lado, 8, 2, 0, 0, 0))
                 + bloco(b"IDAT", zlib.compress(linhas, 9)) + bloco(b"IEND", b""))
        caminho.write_bytes(dados)


def lago():
    t = Tela()
    t.degrade("#2a1f5c", "#f08a6c", faixas=9, y0=0, y1=20)
    for x, y in ((4, 2), (25, 3), (12, 1), (29, 7), (7, 6)):
        t.px(x, y, "#fff3d6")
    t.circulo(16, 19, 7.5, "#ffd27a", so=lambda x, y: y < 19)
    t.circulo(16, 19, 5.5, "#ffe7a8", so=lambda x, y: y < 19)
    # Montanhas atrás.
    t.triangulo(3, 14, 19, 8, "#6a4a8c")
    t.triangulo(29, 13, 19, 8, "#5b3f80")
    # O lago com o reflexo.
    t.degrade("#3a2f6e", "#1d1838", faixas=5, y0=19, y1=N)
    for y, meia in ((20, 6), (22, 4), (24, 3), (26, 2), (28, 1)):
        for x in range(16 - meia, 16 + meia):
            t.px(x, y, "#f5b971" if y < 23 else "#d99a6a")
    # Pinheiros dos lados.
    t.pinheiro(2, 12, 16, "#171330")
    t.pinheiro(29, 10, 18, "#171330")
    t.pinheiro(6, 17, 11, "#1d1838")
    return t


def pinheiro():
    t = Tela()
    t.degrade("#4a1d4f", "#c0587e", faixas=8)
    t.circulo(24.5, 7.5, 3.5, "#ffe7a8")
    t.circulo(26, 6.5, 3, mistura("#4a1d4f", "#c0587e", 0.15))
    for x, y in ((5, 4), (10, 2), (19, 3), (3, 11), (29, 13)):
        t.px(x, y, "#ffd9e8")
    # Chão com neve.
    t.retangulo(0, 27, N, N, "#f3e8f5")
    t.retangulo(0, 27, N, 28, "#ffffff")
    for x in range(0, N, 3):
        t.px(x, 28, "#e4d3ea")
    # O pinheiro grande, com luz de um lado.
    for i, (topo, meia) in enumerate(((5, 4), (10, 6), (15, 8), (20, 10))):
        t.triangulo(16, topo, topo + 7, meia, "#1f6b4f")
        t.triangulo(15, topo + 1, topo + 7, max(1, meia - 3), "#2f8f63")
        # Neve na ponta de cada andar.
        for x in range(16 - meia, 16 + meia + 1, 2):
            t.px(x, topo + 7, "#ffffff")
    t.retangulo(15, 28, 18, 30, "#6b3f2a")
    t.px(16, 4, "#ffd27a")
    t.px(16, 3, "#ffe7a8")
    return t


def lua():
    t = Tela()
    t.degrade("#161433", "#3d2e6e", faixas=8)
    t.circulo(16, 15, 9, "#ffe08a")
    t.circulo(20.5, 12, 8.2, "#000001")
    for y in range(N):
        for x in range(N):
            if t.p[y][x] == "#000001":
                t.p[y][x] = mistura("#161433", "#3d2e6e", min(7, int(y * 8 / N)) / 7)
    # Crateras.
    t.px(10, 16, "#f2c96a"); t.px(11, 20, "#f2c96a"); t.px(13, 22, "#f2c96a")
    # Estrelas em cruz.
    for cx, cy, g in ((24, 22, 1), (25, 6, 1), (6, 5, 0), (28, 15, 0), (5, 26, 0), (18, 27, 1), (14, 3, 0)):
        t.px(cx, cy, "#fff7d6")
        if g:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                t.px(cx + dx, cy + dy, "#cdbcf5")
    return t


def gato():
    t = Tela()
    t.degrade("#5eead4", "#0f766e", faixas=8)
    laranja, escuro, claro = "#f59e0b", "#c2410c", "#fde68a"
    # Orelhas.
    t.triangulo(9, 5, 12, 4, laranja)
    t.triangulo(23, 5, 12, 4, laranja)
    t.triangulo(9, 8, 12, 2, "#fb7185")
    t.triangulo(23, 8, 12, 2, "#fb7185")
    # Cabeça.
    t.circulo(16, 18, 10.5, laranja)
    t.retangulo(7, 26, 26, 30, laranja)
    # Listras.
    for x0 in (13, 16, 19):
        t.retangulo(x0, 8, x0 + 1, 12, escuro)
    t.retangulo(6, 17, 9, 18, escuro); t.retangulo(6, 20, 9, 21, escuro)
    t.retangulo(23, 17, 26, 18, escuro); t.retangulo(23, 20, 26, 21, escuro)
    # Focinho claro.
    t.circulo(16, 22.5, 4.5, claro)
    # Olhos com brilho.
    for ox in (11, 20):
        t.retangulo(ox, 15, ox + 2, 19, "#1f2937")
        t.px(ox, 15, "#ffffff")
    # Nariz e boca.
    t.retangulo(15, 20, 17, 21, "#fb7185")
    t.px(14, 22, "#7c2d12"); t.px(17, 22, "#7c2d12"); t.px(15, 23, "#7c2d12"); t.px(16, 23, "#7c2d12")
    return t


def sakura():
    t = Tela()
    t.degrade("#fde2ef", "#f472b6", faixas=8)
    petala, sombra, miolo = "#fff5fa", "#f9c5dc", "#be185d"
    import math
    fundo = [linha[:] for linha in t.p]
    for i in range(5):
        a = -math.pi / 2 + i * 2 * math.pi / 5
        cx, cy = 16 + 6.6 * math.cos(a), 16 + 6.6 * math.sin(a)
        t.circulo(cx, cy, 4.4, petala)
        t.circulo(16 + 7.6 * math.cos(a), 16 + 7.6 * math.sin(a), 2.2, sombra, so=lambda x, y: t.p[y][x] == petala)
        # O cortezinho na ponta de cada pétala.
        nx, ny = round(16 + 10.6 * math.cos(a) - 0.5), round(16 + 10.6 * math.sin(a) - 0.5)
        t.px(nx, ny, fundo[max(0, min(N - 1, ny))][max(0, min(N - 1, nx))])
    t.circulo(16, 16, 3.2, "#f9a8d4")
    t.circulo(16, 16, 1.8, miolo)
    for i in range(5):
        a = -math.pi / 2 + (i + 0.5) * 2 * math.pi / 5
        t.px(round(16 + 3.6 * math.cos(a)), round(16 + 3.6 * math.sin(a)), "#fbbf24")
    # Pétalas caindo.
    for cx, cy in ((4, 5), (27, 4), (5, 26), (27, 27), (25, 15)):
        t.px(cx, cy, petala); t.px(cx + 1, cy, sombra); t.px(cx, cy + 1, sombra)
    return t


def controle():
    t = Tela()
    t.degrade("#fbbf24", "#e11d48", faixas=8)
    corpo, sombra = "#f4f4f5", "#a1a1aa"
    # Corpo do controle: um retângulo arredondado e as duas alças.
    t.circulo(9, 17, 6.5, corpo)
    t.circulo(23, 17, 6.5, corpo)
    t.retangulo(9, 11, 24, 23, corpo)
    t.circulo(8, 21, 4.5, corpo)
    t.circulo(24, 21, 4.5, corpo)
    for x in range(4, 29):
        if t.p[24][x] == corpo or t.p[25][x] == corpo:
            pass
    t.circulo(8, 22.5, 3.5, corpo, so=lambda x, y: y > 22)
    t.circulo(8, 25, 3, sombra, so=lambda x, y: y > 25 and t.p[y - 1][x] == corpo)
    # Cruz do lado esquerdo.
    t.retangulo(7, 14, 9, 20, "#3f3f46")
    t.retangulo(5, 16, 11, 18, "#3f3f46")
    # Botões do lado direito.
    for (bx, by, c) in ((24, 14, "#22c55e"), (26, 16, "#ef4444"), (22, 16, "#3b82f6"), (24, 18, "#eab308")):
        t.retangulo(bx, by, bx + 2, by + 2, c)
    # Botões do meio.
    t.retangulo(14, 15, 16, 16, sombra)
    t.retangulo(17, 15, 19, 16, sombra)
    # Contorno de baixo.
    for x in range(N):
        for y in range(N - 1, 0, -1):
            if t.p[y - 1][x] == corpo and t.p[y][x] not in (corpo, sombra, "#3f3f46"):
                t.p[y][x] = mistura(t.p[y][x], "#000000", 0.25)
                break
    return t


AVATARES = {"lago": lago, "pinheiro": pinheiro, "lua": lua, "gato": gato, "sakura": sakura, "controle": controle}


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    for nome, fazer in AVATARES.items():
        fazer().png(DESTINO / f"{nome}.png")
    print(f"{len(AVATARES)} fotos em {DESTINO.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
