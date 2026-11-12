#!/usr/bin/env python3
"""Testes dos ajudantes da Música (system_files/usr/share/matsu/musica/ajudante.py e mpris.py).

Monta arquivos de música pequenos de mentira (MP3 com ID3v2.2/2.3/2.4 e ID3v1,
FLAC, Ogg Vorbis, Opus, M4A e WAV) numa pasta temporária e confere as etiquetas,
as durações, as capas, o cache da biblioteca e a onda. Do MPRIS, confere o que dá
para conferir fora do D-Bus (as propriedades, os pedidos e as linhas).

Uso: python3 tests/test_musica.py
"""
import base64
import importlib.util
import io
import json
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import wave
from pathlib import Path
from unittest import mock

PASTA = Path(__file__).resolve().parents[1] / "system_files/usr/share/matsu/musica"
JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00" + b"capa-de-teste" * 20 + b"\xff\xd9"
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" + b"png-de-teste" * 10


def carregar(nome, arquivo):
    spec = importlib.util.spec_from_file_location(nome, PASTA / arquivo)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


A = carregar("musica_ajudante", "ajudante.py")
M = carregar("musica_mpris", "mpris.py")


# ----- fabricar arquivos -----
def syncsafe(n):
    return bytes([(n >> 21) & 0x7F, (n >> 14) & 0x7F, (n >> 7) & 0x7F, n & 0x7F])


def quadro_id3(fid, corpo, versao):
    tamanho = syncsafe(len(corpo)) if versao == 4 else struct.pack(">I", len(corpo))
    return fid.encode() + tamanho + b"\x00\x00" + corpo


def id3(quadros, versao=3, preenchimento=64):
    corpo = b"".join(quadros) + b"\x00" * preenchimento
    return b"ID3" + bytes([versao, 0, 0]) + syncsafe(len(corpo)) + corpo


def texto3(fid, valor, versao=3, cod=1):
    if cod == 1:
        dados = b"\x01" + valor.encode("utf-16")
    elif cod == 3:
        dados = b"\x03" + valor.encode("utf-8")
    else:
        dados = b"\x00" + valor.encode("latin-1")
    return quadro_id3(fid, dados, versao)


def apic(imagem, mime="image/jpeg", tipo=3, versao=3):
    return quadro_id3("APIC", b"\x00" + mime.encode() + b"\x00" + bytes([tipo]) + b"capa\x00" + imagem, versao)


def quadros_mpeg(n, xing=None):
    """n quadros MPEG-1 Layer III, 128 kbps, 44,1 kHz, estéreo (417 bytes cada)."""
    cab = b"\xff\xfb\x90\x00"
    tamanho = 144 * 128000 // 44100
    saida = b""
    for i in range(n):
        corpo = bytearray(tamanho - 4)
        if i == 0 and xing is not None:
            corpo[32:32 + 12] = b"Xing" + struct.pack(">II", 1, xing)
        saida += cab + bytes(corpo)
    return saida


def bloco_flac(tipo, dados, ultimo=False):
    return bytes([(0x80 if ultimo else 0) | tipo]) + len(dados).to_bytes(3, "big") + dados


def comentarios(campos, vendedor=b"teste"):
    saida = struct.pack("<I", len(vendedor)) + vendedor + struct.pack("<I", len(campos))
    for c in campos:
        b = c.encode("utf-8") if isinstance(c, str) else c
        saida += struct.pack("<I", len(b)) + b
    return saida


def imagem_flac(imagem, mime="image/jpeg", tipo=3):
    return (struct.pack(">II", tipo, len(mime)) + mime.encode() + struct.pack(">I", 4) + b"capa"
            + struct.pack(">IIII", 500, 500, 24, 0) + struct.pack(">I", len(imagem)) + imagem)


def streaminfo(freq, amostras, canais=2, bits=16):
    x = (freq << 44) | ((canais - 1) << 41) | ((bits - 1) << 36) | amostras
    return b"\x00\x10\x00\x10" + b"\x00" * 6 + x.to_bytes(8, "big") + b"\x00" * 16


def pagina_ogg(pacotes, granule, serie=7, seq=0, tipo=0):
    segs, corpo = [], b""
    for p in pacotes:
        n = len(p)
        while n >= 255:
            segs.append(255)
            n -= 255
        segs.append(n)
        corpo += p
    assert len(segs) <= 255
    return (b"OggS" + bytes([0, tipo]) + struct.pack("<qII", granule, serie, seq) + b"\x00" * 4
            + bytes([len(segs)]) + bytes(segs) + corpo)


def paginas_grandes(pacote, serie, seq):
    """Um pacote grande em várias páginas (como um comentário com capa)."""
    paginas = []
    partes = [pacote[i:i + 255 * 200] for i in range(0, len(pacote), 255 * 200)]
    for i, parte in enumerate(partes):
        ultimo = i == len(partes) - 1
        segs = [255] * (len(parte) // 255)
        if ultimo:
            segs.append(len(parte) % 255)
        paginas.append(b"OggS" + bytes([0, 1 if i else 0]) + struct.pack("<qII", -1 if not ultimo else 0, serie, seq + i)
                       + b"\x00" * 4 + bytes([len(segs)]) + bytes(segs) + parte)
    return b"".join(paginas)


def atomo(tipo, dados):
    return struct.pack(">I", 8 + len(dados)) + tipo + dados


def item_mp4(tipo, valor, classe=1):
    return atomo(tipo, atomo(b"data", struct.pack(">II", classe, 0) + valor))


def escrever_wav(caminho, segundos=1.0, freq=8000, info=None):
    Path(caminho).parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(caminho), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(freq)
        n = int(segundos * freq)
        amostras = [int(12000 * math.sin(2 * math.pi * 440 * i / freq) * (0.2 + 0.8 * i / n)) for i in range(n)]
        w.writeframes(struct.pack("<%dh" % n, *amostras))
    if info:
        dados = b"INFO"
        for chave, valor in info.items():
            v = valor.encode("utf-8") + b"\x00"
            if len(v) % 2:
                v += b"\x00"
            dados += chave.encode() + struct.pack("<I", len(v)) + v
        with open(caminho, "ab") as f:
            f.write(b"LIST" + struct.pack("<I", len(dados)) + dados)
        tamanho = os.path.getsize(caminho)
        with open(caminho, "r+b") as f:
            f.seek(4)
            f.write(struct.pack("<I", tamanho - 8))


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="matsu-musica-"))
        self.cache = self.tmp / "cache"
        self.pasta = self.tmp / "Música"
        self.pasta.mkdir()
        self.env = mock.patch.dict(os.environ, {"MATSU_MUSICA_CACHE": str(self.cache), "HOME": str(self.tmp)})
        self.env.start()

    def tearDown(self):
        self.env.stop()
        shutil.rmtree(self.tmp, ignore_errors=True)

    def arquivo(self, nome, dados):
        caminho = self.pasta / nome
        caminho.parent.mkdir(parents=True, exist_ok=True)
        caminho.write_bytes(dados)
        return str(caminho)


class TestEtiquetas(Base):
    def test_mp3_id3v23_com_xing_e_capa(self):
        tag = id3([texto3("TIT2", "Café da manhã"), texto3("TPE1", "Ana Sol"), texto3("TPE2", "Vários"),
                   texto3("TALB", "Dias leves"), texto3("TRCK", "3/12", cod=0), texto3("TYER", "2024", cod=0),
                   texto3("TPOS", "1/2", cod=0), apic(PNG, "image/png", tipo=4), apic(JPEG)])
        c = self.arquivo("a.mp3", tag + quadros_mpeg(20, xing=1000))
        r = A.ler_etiquetas(c)
        self.assertEqual((r["titulo"], r["artista"], r["artista_album"], r["album"]), ("Café da manhã", "Ana Sol", "Vários", "Dias leves"))
        self.assertEqual((r["faixa"], r["disco"], r["ano"], r["formato"]), (3, 1, 2024, "MP3"))
        self.assertAlmostEqual(r["duracao"], 1000 * 1152 / 44100, places=3)
        # A capa da frente (tipo 3) ganha da outra.
        self.assertEqual(r["capa"], ("image/jpeg", JPEG))

    def test_mp3_id3v24_utf8_e_cbr(self):
        tag = id3([texto3("TIT2", "Noite de neon", versao=4, cod=3), texto3("TPE1", "Cerejeira", versao=4, cod=3),
                   texto3("TDRC", "2023-05-01", versao=4, cod=3)], versao=4)
        audio = quadros_mpeg(100)
        c = self.arquivo("b.mp3", tag + audio)
        r = A.ler_etiquetas(c)
        self.assertEqual((r["titulo"], r["artista"], r["ano"]), ("Noite de neon", "Cerejeira", 2023))
        # Sem Xing: estima pelo tamanho (CBR 128 kbps).
        self.assertAlmostEqual(r["duracao"], len(audio) * 8 / 128000, places=2)

    def test_mp3_id3v22(self):
        quadro = lambda fid, corpo: fid.encode() + len(corpo).to_bytes(3, "big") + corpo  # noqa: E731
        corpo = (quadro("TT2", b"\x00Pinheiro") + quadro("TP1", b"\x00Matsu Trio")
                 + quadro("PIC", b"\x00JPG\x03capa\x00" + JPEG))
        tag = b"ID3\x02\x00\x00" + syncsafe(len(corpo)) + corpo
        r = A.ler_etiquetas(self.arquivo("c.mp3", tag + quadros_mpeg(5)))
        self.assertEqual((r["titulo"], r["artista"]), ("Pinheiro", "Matsu Trio"))
        self.assertEqual(r["capa"], ("image/jpeg", JPEG))

    def test_mp3_so_id3v1(self):
        v1 = b"TAG" + b"Lua cheia".ljust(30, b"\x00") + b"Matsu Trio".ljust(30, b"\x00") + b"Floresta".ljust(30, b"\x00") \
            + b"2021" + b"\x00" * 28 + b"\x00\x05" + b"\x0c"
        r = A.ler_etiquetas(self.arquivo("d.mp3", quadros_mpeg(10) + v1))
        self.assertEqual((r["titulo"], r["artista"], r["album"], r["ano"], r["faixa"]), ("Lua cheia", "Matsu Trio", "Floresta", 2021, 5))

    def test_flac(self):
        dados = (b"fLaC" + bloco_flac(0, streaminfo(44100, 441000))
                 + bloco_flac(4, comentarios(["TITLE=Pétalas", "ARTIST=Cerejeira", "ARTIST=Convidada", "ALBUMARTIST=Cerejeira",
                                              "ALBUM=Primavera", "TRACKNUMBER=2", "DATE=2022-01-01"]))
                 + bloco_flac(6, imagem_flac(JPEG), ultimo=True) + b"\xff\xf8" + b"\x00" * 100)
        r = A.ler_etiquetas(self.arquivo("e.flac", dados))
        self.assertEqual((r["titulo"], r["artista"], r["artista_album"], r["album"], r["faixa"], r["ano"]),
                         ("Pétalas", "Cerejeira, Convidada", "Cerejeira", "Primavera", 2, 2022))
        self.assertAlmostEqual(r["duracao"], 10.0)
        self.assertEqual(r["capa"], ("image/jpeg", JPEG))
        self.assertEqual(r["formato"], "FLAC")

    def test_ogg_vorbis_com_capa_em_varias_paginas(self):
        ident = b"\x01vorbis" + struct.pack("<IBI", 0, 2, 44100) + b"\x00" * 13
        capa = base64.b64encode(imagem_flac(JPEG * 300)).decode()
        coment = b"\x03vorbis" + comentarios(["TITLE=Estrada", "ARTIST=Ana Sol", "ALBUM=Dias leves",
                                               "METADATA_BLOCK_PICTURE=" + capa]) + b"\x01"
        self.assertGreater(len(coment), 255 * 200)
        dados = (pagina_ogg([ident], 0, tipo=2) + paginas_grandes(coment, 7, 1) + pagina_ogg([b"\x00" * 50], 44100 * 3, seq=50)
                 + pagina_ogg([b"\x00" * 50], 44100 * 7, seq=51, tipo=4))
        r = A.ler_etiquetas(self.arquivo("f.ogg", dados))
        self.assertEqual((r["titulo"], r["artista"], r["album"], r["formato"]), ("Estrada", "Ana Sol", "Dias leves", "Ogg Vorbis"))
        self.assertAlmostEqual(r["duracao"], 7.0)
        self.assertEqual(r["capa"], ("image/jpeg", JPEG * 300))

    def test_opus(self):
        head = b"OpusHead" + struct.pack("<BBHIhB", 1, 2, 312, 48000, 0, 0)
        tags = b"OpusTags" + comentarios(["TITLE=Voz", "ARTIST=Ana"])
        dados = pagina_ogg([head], 0, tipo=2) + pagina_ogg([tags], 0, seq=1) + pagina_ogg([b"\x00" * 30], 48000 * 5 + 312, seq=2, tipo=4)
        r = A.ler_etiquetas(self.arquivo("g.opus", dados))
        self.assertEqual((r["titulo"], r["artista"], r["formato"]), ("Voz", "Ana", "Opus"))
        self.assertAlmostEqual(r["duracao"], 5.0)

    def test_m4a(self):
        mvhd = atomo(b"mvhd", b"\x00\x00\x00\x00" + struct.pack(">IIII", 0, 0, 1000, 12500) + b"\x00" * 80)
        ilst = atomo(b"ilst", item_mp4(b"\xa9nam", "Mar".encode()) + item_mp4(b"\xa9ART", "Beto".encode())
                     + item_mp4(b"aART", "Beto".encode()) + item_mp4(b"\xa9alb", "Ondas".encode())
                     + item_mp4(b"trkn", struct.pack(">HHHH", 0, 4, 10, 0), classe=0)
                     + item_mp4(b"\xa9day", b"2020") + item_mp4(b"covr", PNG, classe=14))
        meta = atomo(b"meta", b"\x00\x00\x00\x00" + atomo(b"hdlr", b"\x00" * 25) + ilst)
        moov = atomo(b"moov", mvhd + atomo(b"udta", meta))
        dados = atomo(b"ftyp", b"M4A \x00\x00\x00\x00") + atomo(b"mdat", b"\x00" * 500) + moov
        r = A.ler_etiquetas(self.arquivo("h.m4a", dados))
        self.assertEqual((r["titulo"], r["artista"], r["artista_album"], r["album"], r["faixa"], r["ano"]),
                         ("Mar", "Beto", "Beto", "Ondas", 4, 2020))
        self.assertAlmostEqual(r["duracao"], 12.5)
        self.assertEqual(r["capa"], ("image/png", PNG))

    def test_wav_com_info(self):
        c = self.pasta / "i.wav"
        escrever_wav(c, 1.5, info={"INAM": "Teste", "IART": "Matsu", "IPRD": "Sons"})
        r = A.ler_etiquetas(str(c))
        self.assertEqual((r["titulo"], r["artista"], r["album"], r["formato"]), ("Teste", "Matsu", "Sons", "WAV"))
        self.assertAlmostEqual(r["duracao"], 1.5, places=3)

    def test_arquivos_quebrados_nao_travam(self):
        casos = {
            "lixo.mp3": os.urandom(3000),
            "id3-enorme.mp3": b"ID3\x03\x00\x00\x7f\x7f\x7f\x7f" + b"TIT2\xff\xff\xff\xff\x00\x00",
            "cortado.flac": b"fLaC" + bloco_flac(4, comentarios(["TITLE=x"]))[:20],
            "cortado.ogg": b"OggS\x00\x02" + b"\x00" * 10,
            "cortado.m4a": b"\x00\x00\x00\x10ftypM4A " + b"\x00\x00\xff\xffmoov",
            "vazio.wav": b"RIFF\x04\x00\x00\x00WAVE",
        }
        for nome, dados in casos.items():
            with self.subTest(nome=nome):
                r = A.ler_etiquetas(self.arquivo(nome, dados))
                self.assertIsInstance(r["duracao"], float)
                self.assertGreaterEqual(r["duracao"], 0)

    def test_nome_do_arquivo_quando_nao_ha_etiquetas(self):
        self.assertEqual(A.pelo_nome("/m/Ana Sol - Café da manhã.mp3"), ("Café da manhã", "Ana Sol"))
        self.assertEqual(A.pelo_nome("/m/03 - Estrada.flac"), ("Estrada", ""))
        self.assertEqual(A.pelo_nome("/m/so_um_nome.ogg"), ("so um nome", ""))


class TestBiblioteca(Base):
    def montar(self):
        tag = lambda t, a, al: id3([texto3("TIT2", t), texto3("TPE1", a), texto3("TALB", al), apic(JPEG)])  # noqa: E731
        self.arquivo("Ana Sol/Dias leves/01.mp3", tag("Um", "Ana Sol", "Dias leves") + quadros_mpeg(30, xing=300))
        self.arquivo("Ana Sol/Dias leves/02.mp3", tag("Dois", "Ana Sol", "Dias leves") + quadros_mpeg(30, xing=400))
        self.arquivo("Beto - Sem etiqueta.mp3", quadros_mpeg(40))
        self.arquivo(".escondido.mp3", quadros_mpeg(5))
        self.arquivo(".pasta/oculta.mp3", quadros_mpeg(5))
        self.arquivo("notas.txt", b"nada")
        self.arquivo("vazio.mp3", b"")
        escrever_wav(self.pasta / "Gravações" / "voz.wav", 0.5)
        (self.pasta / "Gravações" / "cover.png").write_bytes(PNG)

    def ler(self):
        saida = io.StringIO()
        musicas = A.biblioteca(str(self.pasta), saida=saida, intervalo=0)
        linhas = [json.loads(l) for l in saida.getvalue().splitlines()]
        return musicas, linhas

    def test_le_subpastas_ignora_escondidos_e_tira_capas(self):
        self.montar()
        musicas, linhas = self.ler()
        self.assertEqual(linhas[0]["tipo"], "inicio")
        self.assertEqual(linhas[0]["total"], 5)
        self.assertEqual(linhas[-1]["tipo"], "fim")
        self.assertEqual(len(linhas[-1]["musicas"]), 4)
        por_titulo = {m["titulo"]: m for m in musicas}
        self.assertEqual(set(por_titulo), {"Um", "Dois", "Sem etiqueta", "voz"})
        self.assertEqual(por_titulo["Sem etiqueta"]["artista"], "Beto")
        # As duas faixas do álbum dividem a mesma capa, tirada para o cache.
        self.assertEqual(por_titulo["Um"]["capa"], por_titulo["Dois"]["capa"])
        self.assertTrue(por_titulo["Um"]["capa"].startswith(str(self.cache / "capas")))
        self.assertEqual(Path(por_titulo["Um"]["capa"]).read_bytes(), JPEG)
        self.assertEqual(len(list((self.cache / "capas").iterdir())), 1)
        # Sem capa dentro do arquivo: a cover.png da pasta.
        self.assertTrue(por_titulo["voz"]["capa"].endswith("Gravações/cover.png"))
        self.assertAlmostEqual(por_titulo["voz"]["duracao"], 0.5, places=3)

    def test_cache_reaproveita_e_percebe_mudanca(self):
        self.montar()
        _, linhas = self.ler()
        self.assertEqual(linhas[-1]["lidas"], 4)
        _, linhas = self.ler()
        self.assertEqual(linhas[-1]["lidas"], 0)
        caminho = self.pasta / "Ana Sol/Dias leves/01.mp3"
        caminho.write_bytes(id3([texto3("TIT2", "Um (novo)")]) + quadros_mpeg(10))
        os.utime(caminho, (1, 1))
        musicas, linhas = self.ler()
        self.assertEqual(linhas[-1]["lidas"], 1)
        self.assertIn("Um (novo)", [m["titulo"] for m in musicas])
        # Arquivo apagado some da lista.
        caminho.unlink()
        musicas, _ = self.ler()
        self.assertNotIn("Um (novo)", [m["titulo"] for m in musicas])

    def test_pasta_que_nao_existe(self):
        saida = io.StringIO()
        self.assertEqual(A.biblioteca(str(self.tmp / "nao-existe"), saida=saida, intervalo=0), [])
        self.assertEqual(json.loads(saida.getvalue().splitlines()[-1])["musicas"], [])

    def test_linha_de_comando(self):
        self.montar()
        env = dict(os.environ, MATSU_MUSICA_CACHE=str(self.cache), HOME=str(self.tmp))
        r = subprocess.run([sys.executable, "-I", "-S", str(PASTA / "ajudante.py"), "etiquetas",
                            "file://" + str(self.pasta / "Ana%20Sol/Dias%20leves/01.mp3").replace(" ", "%20")],
                           capture_output=True, text=True, env=env, timeout=30)
        d = json.loads(r.stdout)
        self.assertEqual(d["musicas"][0]["titulo"], "Um")
        r = subprocess.run([sys.executable, "-I", "-S", str(PASTA / "ajudante.py"), "biblioteca", str(self.pasta)],
                           capture_output=True, text=True, env=env, timeout=30)
        self.assertEqual(json.loads(r.stdout.splitlines()[-1])["tipo"], "fim")


class TestOnda(Base):
    def test_wav_sem_ffmpeg_e_de_verdade(self):
        c = self.pasta / "voz.wav"
        escrever_wav(c, 2.0)
        with mock.patch.dict(os.environ, {"MATSU_MUSICA_SEM_FFMPEG": "1"}):
            d = A.onda(str(c), 50)
        self.assertEqual(d["fonte"], "wav")
        self.assertTrue(d["real"])
        self.assertEqual(len(d["amostras"]), 50)
        self.assertTrue(all(0 < v <= 1 for v in d["amostras"]))
        # O volume do teste sobe aos poucos: o fim é mais alto que o começo.
        self.assertGreater(sum(d["amostras"][-10:]), sum(d["amostras"][:10]))

    def test_estimada_sempre_igual_e_guardada(self):
        c = self.arquivo("x.mp3", quadros_mpeg(30))
        outro = self.arquivo("y.mp3", quadros_mpeg(31))
        with mock.patch.dict(os.environ, {"MATSU_MUSICA_SEM_FFMPEG": "1"}):
            a = A.onda(c, 80)
            b = A.onda(c, 80)
            o = A.onda(outro, 80)
        self.assertEqual(a["fonte"], "estimada")
        self.assertFalse(a["real"])
        self.assertEqual(a["amostras"], b["amostras"])
        self.assertNotEqual(a["amostras"], o["amostras"])
        self.assertEqual(len(a["amostras"]), 80)
        self.assertTrue((self.cache / "ondas").is_dir())

    @unittest.skipUnless(shutil.which("ffmpeg"), "sem ffmpeg")
    def test_ffmpeg(self):
        c = self.pasta / "voz.wav"
        escrever_wav(c, 1.0)
        d = A.onda(str(c), 40)
        self.assertEqual(d["fonte"], "ffmpeg")
        self.assertEqual(len(d["amostras"]), 40)

    def test_reducao(self):
        import array
        amostras = array.array("h", [0] * 100 + [1000] * 100 + [-20000, 20000] * 50)
        r = A.onda_de_amostras(amostras, 3)
        self.assertEqual(len(r), 3)
        self.assertLess(r[0], r[1])
        self.assertEqual(r[2], 1.0)


class TestMpris(unittest.TestCase):
    def setUp(self):
        self.agora = [100.0]
        self.e = M.Estado(relogio=lambda: self.agora[0])

    def test_metadados_e_propriedades(self):
        mudou, buscou = self.e.atualizar({"estado": "Playing", "titulo": "Café", "artista": "Ana Sol", "album": "Dias",
                                          "capa": "/tmp/capa x.jpg", "id": "/home/k/Música/a b.mp3", "duracao": 68049,
                                          "posicao": 1000, "volume": 0.8, "repetir": "tudo", "proxima": True})
        self.assertFalse(buscou)
        self.assertEqual(mudou["PlaybackStatus"], "Playing")
        self.assertEqual(mudou["LoopStatus"], "Playlist")
        m = self.e.metadados()
        self.assertEqual(m["xesam:title"], "Café")
        self.assertEqual(m["xesam:artist"], ["Ana Sol"])
        self.assertEqual(m["mpris:length"], 68049000)
        self.assertEqual(m["mpris:artUrl"], "file:///tmp/capa%20x.jpg")
        self.assertEqual(m["xesam:url"], "file:///home/k/M%C3%BAsica/a%20b.mp3")
        self.assertRegex(m["mpris:trackid"], r"^/org/matsu/musica/faixa/m[0-9a-f]{16}$")
        p = self.e.player()
        self.assertTrue(p["CanSeek"] and p["CanGoNext"] and p["CanPause"])
        self.assertEqual(p["Volume"], 0.8)

    def test_posicao_anda_tocando_e_para_pausada(self):
        self.e.atualizar({"estado": "Playing", "id": "/a.mp3", "duracao": 10000, "posicao": 2000})
        self.agora[0] += 1.5
        self.assertEqual(self.e.posicao_agora(), 3500000)
        self.agora[0] += 100
        self.assertEqual(self.e.posicao_agora(), 10000000)
        self.e.atualizar({"estado": "Paused", "posicao": 4000, "buscou": True})
        self.agora[0] += 5
        self.assertEqual(self.e.posicao_agora(), 4000000)

    def test_so_avisa_o_que_mudou(self):
        self.e.atualizar({"estado": "Paused", "id": "/a.mp3", "titulo": "A"})
        mudou, _ = self.e.atualizar({"estado": "Paused", "id": "/a.mp3", "titulo": "A", "posicao": 5})
        self.assertEqual(mudou, {})
        mudou, buscou = self.e.atualizar({"aleatorio": True, "buscou": True})
        self.assertEqual(mudou, {"Shuffle": True})
        self.assertTrue(buscou)

    def test_sem_musica(self):
        m = self.e.metadados()
        self.assertEqual(m, {"mpris:trackid": M.SEM_FAIXA})
        self.assertFalse(self.e.player()["CanPlay"])

    def test_pedidos(self):
        self.assertEqual(json.loads(M.pedido("Seek", offset=5000)), {"cmd": "Seek", "offset": 5000})
        self.assertEqual(json.loads(M.pedido_set(M.PLAYER, "Volume", 1.7)), {"cmd": "Volume", "valor": 1.0})
        self.assertEqual(json.loads(M.pedido_set(M.PLAYER, "LoopStatus", "Track")), {"cmd": "Repetir", "valor": "uma"})
        self.assertEqual(json.loads(M.pedido_set(M.PLAYER, "Shuffle", 1)), {"cmd": "Shuffle", "valor": True})
        self.assertIsNone(M.pedido_set(M.PLAYER, "Rate", 2.0))
        self.assertIsNone(M.pedido_set(M.RAIZ, "Fullscreen", True))

    def test_linhas_partidas(self):
        linhas, sobra = M.ler_linhas(b"", b'{"a": 1}\n{"b"')
        self.assertEqual(linhas, ['{"a": 1}'])
        linhas, sobra = M.ler_linhas(sobra, b': 2}\n\n')
        self.assertEqual(linhas, ['{"b": 2}'])
        self.assertEqual(sobra, b"")

    def test_lingua(self):
        self.assertTrue(M.em_portugues({"LANG": "pt_BR.UTF-8"}))
        self.assertFalse(M.em_portugues({"LANGUAGE": "en_US:pt_BR", "LANG": "pt_BR.UTF-8"}))
        self.assertFalse(M.em_portugues({"LANG": "C"}))

    def test_sem_dbus_sai_com_codigo_3(self):
        # Sem o dbus-python (ou o PyGObject), avisa e sai: o app segue sem os controles.
        r = subprocess.run([sys.executable, "-I", "-S", str(PASTA / "mpris.py")], input="", capture_output=True,
                           text=True, timeout=20)
        if r.returncode == 3:
            self.assertEqual(json.loads(r.stdout.splitlines()[0])["ok"], False)
        else:
            self.skipTest("este Python tem o dbus-python sem o -S")


if __name__ == "__main__":
    unittest.main(verbosity=1)
