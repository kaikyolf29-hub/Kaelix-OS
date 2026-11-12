#!/usr/bin/env python3
"""Testes do ajudante do app Fotos (system_files/usr/share/matsu/fotos/ajudante.py).

Monta arquivos de imagem pequenos à mão (só o cabeçalho que interessa), uma
pasta Imagens de mentira com subpastas e uma Lixeira de mentira, numa pasta
temporária. Nada de fora da pasta temporária é tocado.

Uso: python3 tests/test_fotos.py
"""
import calendar
import hashlib
import importlib.util
import json
import os
import stat
import struct
import subprocess
import sys
import tempfile
import time
import unittest
import zlib

sys.dont_write_bytecode = True
from pathlib import Path
from unittest import mock

AJUDANTE = Path(__file__).resolve().parents[1] / "system_files/usr/share/matsu/fotos/ajudante.py"


def carregar():
    spec = importlib.util.spec_from_file_location("ajudante_fotos", AJUDANTE)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


aj = carregar()


# ----- arquivos de imagem montados à mão -----

def png(largura, altura, textos=None):
    def pedaco(tipo, dados):
        return struct.pack(">I", len(dados)) + tipo + dados + struct.pack(">I", zlib.crc32(tipo + dados) & 0xFFFFFFFF)
    corpo = pedaco(b"IHDR", struct.pack(">IIBBBBB", largura, altura, 8, 2, 0, 0, 0))
    for chave, valor in (textos or {}).items():
        corpo += pedaco(b"tEXt", chave.encode() + b"\0" + valor.encode())
    corpo += pedaco(b"IDAT", zlib.compress(b"\0" * 4)) + pedaco(b"IEND", b"")
    return b"\x89PNG\r\n\x1a\n" + corpo


def tiff(entradas_ifd0, entradas_exif=None, e="<"):
    """Um bloco TIFF com IFD0 e, se tiver, o IFD do EXIF. Entradas: (tag, tipo, valor)."""
    def montar(entradas, inicio):
        n = len(entradas)
        extra_pos = inicio + 2 + 12 * n + 4
        corpo = struct.pack(e + "H", n)
        extra = b""
        for tag, tipo, valor in entradas:
            if tipo == 2:
                dado = valor.encode("ascii") + b"\0"
                if len(dado) <= 4:
                    corpo += struct.pack(e + "HHI", tag, tipo, len(dado)) + dado.ljust(4, b"\0")
                else:
                    corpo += struct.pack(e + "HHII", tag, tipo, len(dado), extra_pos + len(extra))
                    extra += dado
            elif tipo == 3:
                corpo += struct.pack(e + "HHIHH", tag, tipo, 1, valor, 0)
            else:
                corpo += struct.pack(e + "HHII", tag, tipo, 1, valor)
        return corpo + struct.pack(e + "I", 0) + extra

    entradas0 = list(entradas_ifd0)
    if entradas_exif is not None:
        tam0 = len(montar(entradas0 + [(0x8769, 4, 0)], 8))
        entradas0.append((0x8769, 4, 8 + tam0))
    bloco = (b"II" if e == "<" else b"MM") + struct.pack(e + "HI", 42, 8) + montar(entradas0, 8)
    if entradas_exif is not None:
        bloco += montar(entradas_exif, len(bloco))
    return bloco


def jpeg(largura, altura, exif=None):
    dados = b"\xff\xd8"
    dados += b"\xff\xe0" + struct.pack(">H", 16) + b"JFIF\0\x01\x01\0\0\x01\0\x01\0\0"
    if exif is not None:
        app1 = b"Exif\0\0" + exif
        dados += b"\xff\xe1" + struct.pack(">H", len(app1) + 2) + app1
    dados += b"\xff\xdb" + struct.pack(">H", 67) + b"\0" + b"\x01" * 64
    dados += b"\xff\xc0" + struct.pack(">HBHHB", 17, 8, altura, largura, 3) + b"\x01\x11\0\x02\x11\x01\x03\x11\x01"
    dados += b"\xff\xda" + struct.pack(">H", 12) + b"\x03\x01\0\x02\x11\x03\x11\0\x3f\0" + b"\x00" * 10 + b"\xff\xd9"
    return dados


def gif(largura, altura):
    return b"GIF89a" + struct.pack("<HH", largura, altura) + b"\0\0\0;"


def webp_vp8(largura, altura):
    quadro = b"\x9d\x01\x2a" + struct.pack("<HH", largura, altura)
    corpo = b"VP8 " + struct.pack("<I", 10 + len(quadro)) + b"\0\0\0" + quadro + b"\0" * 4
    return b"RIFF" + struct.pack("<I", 4 + len(corpo)) + b"WEBP" + corpo


def webp_vp8l(largura, altura):
    bits = (largura - 1) | ((altura - 1) << 14)
    corpo = b"VP8L" + struct.pack("<I", 5) + b"\x2f" + struct.pack("<I", bits) + b"\0" * 3
    return b"RIFF" + struct.pack("<I", 4 + len(corpo)) + b"WEBP" + corpo


def webp_vp8x(largura, altura):
    corpo = b"VP8X" + struct.pack("<I", 10) + b"\0\0\0\0" + (largura - 1).to_bytes(3, "little") + (altura - 1).to_bytes(3, "little")
    return b"RIFF" + struct.pack("<I", 4 + len(corpo)) + b"WEBP" + corpo


def bmp(largura, altura):
    return b"BM" + struct.pack("<IHHI", 70, 0, 0, 54) + struct.pack("<IiiHH", 40, largura, altura, 1, 24) + b"\0" * 30


def avif(largura, altura, girar=False):
    ftyp = struct.pack(">I", 20) + b"ftypavif" + b"\0\0\0\0" + b"mif1"
    miniatura = struct.pack(">I", 20) + b"ispe" + b"\0\0\0\0" + struct.pack(">II", 160, 120)
    principal = struct.pack(">I", 20) + b"ispe" + b"\0\0\0\0" + struct.pack(">II", largura, altura)
    rot = (struct.pack(">I", 9) + b"irot" + b"\x01") if girar else b""
    return ftyp + struct.pack(">I", 8) + b"meta" + miniatura + principal + rot


def ico(*lados):
    cab = struct.pack("<HHH", 0, 1, len(lados))
    for lado in lados:
        cab += bytes([lado % 256, lado % 256, 0, 0]) + struct.pack("<HHII", 1, 32, 100, 0)
    return cab + b"\0" * 64


def escrever(caminho, dados, quando=None):
    caminho = Path(caminho)
    caminho.parent.mkdir(parents=True, exist_ok=True)
    caminho.write_bytes(dados)
    if quando is not None:
        os.utime(caminho, (quando, quando))
    return str(caminho)


class TesteComPasta(unittest.TestCase):
    def setUp(self):
        self._temp = tempfile.TemporaryDirectory()
        self.raiz = Path(self._temp.name)
        self.ambiente = mock.patch.dict(os.environ, {
            "HOME": str(self.raiz / "casa"),
            "XDG_CACHE_HOME": str(self.raiz / "cache"),
            "XDG_DATA_HOME": str(self.raiz / "dados"),
            "XDG_CONFIG_HOME": str(self.raiz / "config"),
            "LANG": "pt_BR.UTF-8", "LC_ALL": "", "LANGUAGE": "", "MATSU_LANG": "",
        })
        self.ambiente.start()
        (self.raiz / "casa").mkdir()

    def tearDown(self):
        self.ambiente.stop()
        self._temp.cleanup()


class Cabecalhos(TesteComPasta):
    def medir(self, nome, dados):
        return aj.cabecalho(escrever(self.raiz / nome, dados))

    def test_png(self):
        self.assertEqual(self.medir("a.png", png(1920, 1080))[:2], (1920, 1080))

    def test_gif(self):
        self.assertEqual(self.medir("a.gif", gif(320, 200))[:2], (320, 200))

    def test_webp_tres_jeitos(self):
        self.assertEqual(self.medir("a.webp", webp_vp8(640, 480))[:2], (640, 480))
        self.assertEqual(self.medir("b.webp", webp_vp8l(1000, 750))[:2], (1000, 750))
        self.assertEqual(self.medir("c.webp", webp_vp8x(4000, 3000))[:2], (4000, 3000))

    def test_bmp_de_cabeca_para_baixo(self):
        self.assertEqual(self.medir("a.bmp", bmp(800, -600))[:2], (800, 600))

    def test_jpeg_sem_exif(self):
        self.assertEqual(self.medir("a.jpg", jpeg(4032, 3024)), (4032, 3024, 0, 1))

    def test_jpeg_com_data_exif_local(self):
        exif = tiff([(0x0112, 3, 1)], [(0x9003, 2, "2024:03:15 10:30:00")])
        l, a, data, orientacao = self.medir("a.jpg", jpeg(4032, 3024, exif))
        self.assertEqual((l, a, orientacao), (4032, 3024, 1))
        self.assertEqual(data, int(time.mktime((2024, 3, 15, 10, 30, 0, 0, 0, -1))))

    def test_jpeg_com_fuso_e_girado(self):
        # Orientação 6 (de pé): a largura e a altura trocam. Com o fuso, a hora é exata.
        exif = tiff([(0x0112, 3, 6)], [(0x9003, 2, "2024:03:15 10:30:00"), (0x9011, 2, "-03:00")], e=">")
        l, a, data, orientacao = self.medir("a.jpg", jpeg(4032, 3024, exif))
        self.assertEqual((l, a, orientacao), (3024, 4032, 6))
        self.assertEqual(data, calendar.timegm((2024, 3, 15, 13, 30, 0)))

    def test_jpeg_data_zerada_cai_na_data_comum(self):
        exif = tiff([(0x0132, 2, "2023:01:02 03:04:05")], [(0x9003, 2, "0000:00:00 00:00:00")])
        self.assertEqual(self.medir("a.jpg", jpeg(10, 10, exif))[2], int(time.mktime((2023, 1, 2, 3, 4, 5, 0, 0, -1))))

    def test_tiff(self):
        dados = tiff([(0x0100, 4, 2000), (0x0101, 3, 1500), (0x0112, 3, 8)], [(0x9003, 2, "2022:12:31 23:59:59")])
        l, a, data, orientacao = self.medir("a.tif", dados + b"\0" * 32)
        self.assertEqual((l, a, orientacao), (1500, 2000, 8))
        self.assertGreater(data, 0)

    def test_avif_pega_a_maior_e_gira(self):
        self.assertEqual(self.medir("a.avif", avif(3000, 2000))[:2], (3000, 2000))
        self.assertEqual(self.medir("b.avif", avif(3000, 2000, girar=True))[:2], (2000, 3000))

    def test_ico_pega_o_maior(self):
        self.assertEqual(self.medir("a.ico", ico(16, 48, 256))[:2], (256, 256))

    def test_svg(self):
        self.assertEqual(self.medir("a.svg", b'<?xml version="1.0"?>\n<svg xmlns="x" width="64px" height="32">')[:2], (64, 32))
        self.assertEqual(self.medir("b.svg", b'<svg viewBox="0 0 300 150" xmlns="x"></svg>')[:2], (300, 150))
        self.assertEqual(self.medir("c.svg", b'<svg width="100%" height="100%"></svg>')[:2], (0, 0))

    def test_arquivos_quebrados_nao_derrubam(self):
        for nome, dados in (("a.jpg", b"\xff\xd8\xff\xe1\x00"), ("b.png", b"\x89PNG\r\n"), ("c.webp", b"RIFF\0\0\0\0WEBPVP8L"),
                            ("d.tif", b"II*\0\xff\xff\xff\x7f"), ("e.jpg", jpeg(10, 10)[:30]), ("f.bin", b""),
                            ("g.jpg", b"\xff\xd8" + b"\xff\xe1\xff\xff" + b"Exif\0\0II*\0\x08\0\0\0\xff\xff")):
            with self.subTest(nome=nome):
                l, a, data, orientacao = self.medir(nome, dados)
                self.assertTrue(l >= 0 and a >= 0 and orientacao in range(1, 9))

    def test_arquivo_que_nao_existe(self):
        self.assertEqual(aj.cabecalho(str(self.raiz / "nada.jpg")), (0, 0, 0, 1))


class Listar(TesteComPasta):
    def montar(self):
        img = self.raiz / "casa" / "Imagens"
        agora = time.time()
        escrever(img / "foto 10.jpg", jpeg(4000, 3000), agora - 86400 * 40)
        escrever(img / "foto 2.png", png(1000, 2000), agora - 86400 * 2)
        exif = tiff([], [(0x9003, 2, "2020:06:01 12:00:00")])
        escrever(img / "Viagem" / "praia.jpg", jpeg(1600, 1200, exif), agora)  # tirada em 2020
        escrever(img / "Viagem" / "Dia 1" / "trilha.webp", webp_vp8(800, 600), agora - 86400)
        escrever(img / "Capturas de tela" / "Captura de tela_20261112.png", png(1920, 1080), agora - 3600)
        escrever(img / "Screenshot_2026.png", png(1366, 768), agora - 7200)
        escrever(img / ".escondida" / "x.png", png(10, 10), agora)
        escrever(img / ".oculta.png", png(10, 10), agora)
        escrever(img / "notas.txt", b"oi", agora)
        escrever(img / "vazia.png", b"", agora)
        vid = self.raiz / "casa" / "Vídeos"
        escrever(vid / "aniversario.mp4", b"\0\0\0\x18ftypmp42" + b"\0" * 64, agora)
        escrever(vid / "leia.txt", b"x", agora)
        return img, vid

    def test_lista_tudo_em_ordem_de_data(self):
        img, vid = self.montar()
        r = aj.listar(str(img), str(vid))
        nomes = [f["nome"] for f in r["fotos"]]
        self.assertEqual(nomes, ["Captura de tela_20261112.png", "Screenshot_2026.png", "trilha.webp", "foto 2.png",
                                 "foto 10.jpg", "praia.jpg"])
        self.assertEqual(r["idioma"], "pt")
        self.assertTrue(r["existe"])
        praia = next(f for f in r["fotos"] if f["nome"] == "praia.jpg")
        self.assertTrue(praia["exif"])
        self.assertEqual(praia["data"], int(time.mktime((2020, 6, 1, 12, 0, 0, 0, 0, -1))))
        self.assertEqual((praia["largura"], praia["altura"], praia["album"]), (1600, 1200, "Viagem"))

    def test_albuns_e_capturas(self):
        img, vid = self.montar()
        r = aj.listar(str(img), str(vid))
        albuns = {a["nome"]: a for a in r["albuns"]}
        self.assertEqual(set(albuns), {"Viagem", "Capturas de tela"})
        self.assertEqual(albuns["Viagem"]["quantidade"], 2)  # a subpasta "Dia 1" conta no álbum
        self.assertTrue(albuns["Viagem"]["capa"].endswith("trilha.webp"))  # a mais nova pela data da foto
        self.assertTrue(albuns["Capturas de tela"]["capturas"])
        capturas = sorted(f["nome"] for f in r["fotos"] if f["captura"])
        self.assertEqual(capturas, ["Captura de tela_20261112.png", "Screenshot_2026.png"])

    def test_videos(self):
        img, vid = self.montar()
        r = aj.listar(str(img), str(vid))
        self.assertEqual([v["nome"] for v in r["videos"]], ["aniversario.mp4"])
        self.assertTrue(r["videos"][0]["video"])

    def test_pasta_que_nao_existe(self):
        r = aj.listar(str(self.raiz / "nada"), "")
        self.assertEqual((r["fotos"], r["albuns"], r["videos"], r["existe"]), ([], [], [], False))

    def test_sem_pasta_usa_imagens_da_casa(self):
        img, _ = self.montar()
        self.assertEqual(aj.listar("", "")["raiz"], str(img))

    def test_cache_so_rele_o_que_mudou(self):
        img, vid = self.montar()
        aj.listar(str(img), str(vid))
        self.assertTrue(os.path.isfile(aj.arquivo_cache()))
        with mock.patch.object(aj, "cabecalho", wraps=aj.cabecalho) as espiao:
            aj.listar(str(img), str(vid))
            self.assertEqual(espiao.call_count, 0)
            escrever(img / "foto 2.png", png(3000, 1000))
            r = aj.listar(str(img), str(vid))
            self.assertEqual(espiao.call_count, 1)
        foto2 = next(f for f in r["fotos"] if f["nome"] == "foto 2.png")
        self.assertEqual((foto2["largura"], foto2["altura"]), (3000, 1000))

    def test_cache_esquece_o_que_sumiu_e_aguenta_lixo(self):
        img, vid = self.montar()
        aj.listar(str(img), str(vid))
        os.remove(img / "foto 2.png")
        aj.listar(str(img), str(vid))
        self.assertNotIn(str(img / "foto 2.png"), aj.abrir_cache())
        Path(aj.arquivo_cache()).write_text("{quebrado")
        self.assertEqual(len(aj.listar(str(img), str(vid))["fotos"]), 5)

    def test_linha_de_comando(self):
        img, vid = self.montar()
        env = dict(os.environ)
        saida = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), "listar", str(img), str(vid)],
                               capture_output=True, text=True, env=env, check=True).stdout
        self.assertEqual(len(json.loads(saida)["fotos"]), 6)
        r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE)], capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 2)


class Vizinhas(TesteComPasta):
    def test_ordem_natural_e_posicao(self):
        pasta = self.raiz / "Downloads"
        for nome in ("img10.png", "img2.png", "IMG1.png", "filme.mp4", "texto.txt", ".x.png"):
            escrever(pasta / nome, png(10, 10))
        r = aj.vizinhas(str(pasta / "img2.png"))
        self.assertEqual([f["nome"] for f in r["fotos"]], ["filme.mp4", "IMG1.png", "img2.png", "img10.png"])
        self.assertEqual(r["indice"], 2)
        self.assertTrue(r["fotos"][0]["video"])

    def test_aceita_endereco_file_e_arquivo_sem_extensao(self):
        pasta = self.raiz / "Área de trabalho"
        escrever(pasta / "a.png", png(10, 10))
        escrever(pasta / "sem extensão", png(20, 10))
        r = aj.vizinhas("file://" + str(pasta / "sem%20extens%C3%A3o"))
        self.assertEqual(r["fotos"][r["indice"]]["nome"], "sem extensão")
        self.assertEqual(r["fotos"][r["indice"]]["largura"], 20)


class Miniaturas(TesteComPasta):
    def test_usa_a_miniatura_do_kde_so_se_estiver_em_dia(self):
        foto = escrever(self.raiz / "casa" / "Imagens" / "Minha foto (1).jpg", jpeg(10, 10), 1700000000)
        nome = hashlib.md5(aj.uri(foto).encode()).hexdigest() + ".png"
        self.assertIn("Minha%20foto%20(1).jpg", aj.uri(foto))
        grande = escrever(self.raiz / "cache" / "thumbnails" / "large" / nome, png(256, 192, {"Thumb::MTime": "1700000000"}))
        self.assertEqual(aj.miniatura(foto, 1700000000), (grande, 256))
        self.assertEqual(aj.miniatura(foto, 1700000999), ("", 0))
        maior = escrever(self.raiz / "cache" / "thumbnails" / "x-large" / nome, png(512, 384, {"Thumb::MTime": "1700000000"}))
        self.assertEqual(aj.miniatura(foto, 1700000000), (maior, 512))

    def test_capas_sem_ffmpeg(self):
        with mock.patch.object(aj.shutil, "which", return_value=None):
            self.assertEqual(aj.fazer_capas(["/x.mp4"])["erro"], "sem-ffmpeg")


def programa(pasta, nome, corpo):
    caminho = Path(pasta) / nome
    # O PATH dos testes só tem a pasta dos programas de mentira; dentro deles, o do sistema.
    caminho.write_text("#!/bin/sh\nPATH=/usr/bin:/bin\n" + corpo)
    caminho.chmod(caminho.stat().st_mode | stat.S_IEXEC)


# Um "gio trash" de mentira que segue o padrão freedesktop (como o de verdade).
GIO_FALSO = r'''
[ "$1" = trash ] || exit 1
[ "$2" = -- ] && shift
f="$2"; lixo="$XDG_DATA_HOME/Trash"; mkdir -p "$lixo/files" "$lixo/info"
b=$(basename "$f"); n="$b"; i=1
while [ -e "$lixo/files/$n" ]; do i=$((i+1)); n="$b.$i"; done
printf '[Trash Info]\nPath=%s\nDeletionDate=2026-11-12T10:00:0%s\n' "$(printf %s "$f" | sed 's/ /%20/g')" "$i" > "$lixo/info/$n.trashinfo"
mv "$f" "$lixo/files/$n"
'''


class Lixeira(TesteComPasta):
    def setUp(self):
        super().setUp()
        self.bin = self.raiz / "bin"
        self.bin.mkdir()
        self.caminho = mock.patch.dict(os.environ, {"PATH": str(self.bin)})
        self.caminho.start()

    def tearDown(self):
        self.caminho.stop()
        super().tearDown()

    def test_manda_e_desfaz(self):
        programa(self.bin, "gio", GIO_FALSO)
        foto = escrever(self.raiz / "casa" / "Imagens" / "minha foto.jpg", jpeg(10, 10))
        r = aj.lixeira(foto)
        self.assertEqual((r["ok"], r["metodo"], r["desfazer"]), (True, "gio", True))
        self.assertFalse(os.path.exists(foto))
        self.assertEqual(aj.restaurar(foto), {"ok": True})
        self.assertTrue(os.path.exists(foto))
        self.assertEqual(os.listdir(self.raiz / "dados" / "Trash" / "info"), [])

    def test_desfaz_a_ultima_de_duas_com_o_mesmo_nome(self):
        programa(self.bin, "gio", GIO_FALSO)
        foto = escrever(self.raiz / "casa" / "a.png", png(1, 1))
        aj.lixeira(foto)
        escrever(foto, png(2, 2))
        aj.lixeira(foto)
        self.assertTrue(aj.restaurar(foto)["ok"])
        self.assertEqual(aj.cabecalho(foto)[:2], (2, 2))
        self.assertEqual(aj.restaurar(foto)["erro"], "ja-existe")

    def test_plano_b_kioclient(self):
        programa(self.bin, "gio", "exit 1\n")
        programa(self.bin, "kioclient", '[ "$2" = move ] && [ "$4" = trash:/ ] && rm -f "$3"\n')
        foto = escrever(self.raiz / "casa" / "b.png", png(1, 1))
        r = aj.lixeira(foto)
        self.assertEqual((r["ok"], r["metodo"], r["desfazer"]), (True, "kioclient", False))

    def test_sem_programa_nenhum(self):
        foto = escrever(self.raiz / "casa" / "c.png", png(1, 1))
        self.assertEqual(aj.lixeira(foto), {"ok": False, "erro": "sem-lixeira"})
        self.assertTrue(os.path.exists(foto))
        self.assertEqual(aj.lixeira(str(self.raiz / "nada.png"))["erro"], "nao-existe")
        self.assertEqual(aj.restaurar(str(self.raiz / "nada.png"))["erro"], "nao-achou")

    def test_copiar(self):
        foto = escrever(self.raiz / "casa" / "d.png", png(1, 1))
        with mock.patch.dict(os.environ, {"WAYLAND_DISPLAY": "", "DISPLAY": ""}):
            self.assertEqual(aj.copiar(foto)["erro"], "sem-programa")
        saida = self.raiz / "copiado"
        programa(self.bin, "wl-copy", 'echo "$2" > "%s.tipo"; cat > "%s"\n' % (saida, saida))
        with mock.patch.dict(os.environ, {"WAYLAND_DISPLAY": "wayland-0"}):
            self.assertTrue(aj.copiar(foto)["ok"])
        self.assertEqual(saida.read_bytes(), png(1, 1))
        self.assertEqual(Path(str(saida) + ".tipo").read_text().strip(), "image/png")


if __name__ == "__main__":
    unittest.main()
