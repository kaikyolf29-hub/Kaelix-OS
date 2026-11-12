#!/usr/bin/env python3
"""Testes do ajudante da Câmera (system_files/usr/share/matsu/camera/ajudante.py).

Tudo numa pasta pessoal de mentira, numa pasta temporária: as pastas Imagens e
Vídeos, a configuração do vidro e a língua. Nada de fora dela é tocado.

Uso: python3 tests/test_camera.py
"""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

AJUDANTE = Path(__file__).resolve().parents[1] / "system_files/usr/share/matsu/camera/ajudante.py"


def carregar():
    spec = importlib.util.spec_from_file_location("ajudante_camera", AJUDANTE)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


aj = carregar()


def escrever(caminho, conteudo=b"x", quando=None):
    caminho = Path(caminho)
    caminho.parent.mkdir(parents=True, exist_ok=True)
    caminho.write_bytes(conteudo)
    if quando is not None:
        os.utime(caminho, (quando, quando))
    return caminho


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.casa = Path(self.tmp.name) / "casa"
        self.casa.mkdir()
        self.env = mock.patch.dict(os.environ, {"HOME": str(self.casa), "LANG": "pt_BR.UTF-8", "LC_ALL": "",
                                                "LC_MESSAGES": "", "LANGUAGE": "", "MATSU_LANG": "",
                                                "XDG_CONFIG_HOME": str(self.casa / ".config"), "MATSU_STATE_DIR": ""})
        self.env.start()
        self.imagens = self.casa / "Imagens"
        self.videos = self.casa / "Vídeos"
        self.dados = self.casa / ".local/share/matsu/camera"

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def inicio(self):
        return aj.inicio(str(self.imagens), str(self.videos), str(self.dados))


class TestPastas(Base):
    def test_cria_as_pastas_da_camera(self):
        r = self.inicio()
        self.assertEqual(r["fotos"], str(self.imagens / "Câmera"))
        self.assertEqual(r["videos"], str(self.videos / "Câmera"))
        self.assertEqual(r["capas"], str(self.dados / "capas"))
        for p in ("fotos", "videos", "capas"):
            self.assertTrue(os.path.isdir(r[p]), p)
        self.assertTrue(r["pastasOk"])
        self.assertIsNone(r["ultima"])

    def test_pasta_ja_existente_continua_igual(self):
        foto = escrever(self.imagens / "Câmera" / "Foto 2026-11-12 03-40-12.jpg")
        r = self.inicio()
        self.assertTrue(foto.exists())
        self.assertEqual(r["ultima"]["caminho"], str(foto))

    def test_em_ingles_a_pasta_se_chama_camera(self):
        os.environ["LANG"] = "en_US.UTF-8"
        r = aj.inicio(str(self.casa / "Pictures"), str(self.casa / "Videos"), str(self.dados))
        self.assertEqual(r["idioma"], "en")
        self.assertEqual(r["fotos"], str(self.casa / "Pictures" / "Camera"))
        self.assertEqual(r["videos"], str(self.casa / "Videos" / "Camera"))

    def test_sem_pastas_usa_a_casa(self):
        r = aj.inicio("", "", "")
        self.assertEqual(r["fotos"], str(self.casa / "Imagens" / "Câmera"))
        self.assertEqual(r["videos"], str(self.casa / "Vídeos" / "Câmera"))
        self.assertTrue(os.path.isdir(r["capas"]))

    def test_pasta_que_nao_da_para_criar(self):
        # Um arquivo no lugar da pasta Imagens: não dá para criar Imagens/Câmera.
        escrever(self.imagens, b"nao sou pasta")
        r = self.inicio()
        self.assertFalse(r["pastasOk"])
        self.assertTrue(os.path.isdir(r["videos"]))


class TestUltima(Base):
    def test_a_mais_nova_entre_fotos_e_videos(self):
        agora = time.time()
        escrever(self.imagens / "Câmera" / "Foto a.jpg", quando=agora - 300)
        escrever(self.imagens / "Câmera" / "Foto b.png", quando=agora - 100)
        video = escrever(self.videos / "Câmera" / "Vídeo c.mp4", quando=agora - 50)
        capa = escrever(self.dados / "capas" / "Vídeo c.mp4.jpg")
        r = self.inicio()
        self.assertEqual(r["ultima"], {"caminho": str(video), "tipo": "video", "capa": str(capa)})

    def test_foto_mais_nova_que_o_video(self):
        agora = time.time()
        escrever(self.videos / "Câmera" / "Vídeo.mp4", quando=agora - 500)
        foto = escrever(self.imagens / "Câmera" / "Foto.JPG", quando=agora - 5)
        r = self.inicio()
        self.assertEqual(r["ultima"]["tipo"], "foto")
        self.assertEqual(r["ultima"]["caminho"], str(foto))
        self.assertEqual(r["ultima"]["capa"], "")

    def test_ignora_o_que_nao_e_foto_nem_video(self):
        agora = time.time()
        foto = escrever(self.imagens / "Câmera" / "Foto.jpg", quando=agora - 100)
        escrever(self.imagens / "Câmera" / "notas.txt", quando=agora)
        escrever(self.imagens / "Câmera" / ".escondida.jpg", quando=agora)
        escrever(self.imagens / "Câmera" / "sem extensao", quando=agora)
        (self.imagens / "Câmera" / "pasta.jpg").mkdir()
        r = self.inicio()
        self.assertEqual(r["ultima"]["caminho"], str(foto))

    def test_ignora_video_vazio(self):
        agora = time.time()
        foto = escrever(self.imagens / "Câmera" / "Foto.jpg", quando=agora - 100)
        escrever(self.videos / "Câmera" / "Vídeo cortado.mp4", b"", quando=agora)
        r = self.inicio()
        self.assertEqual(r["ultima"]["caminho"], str(foto))

    def test_nao_olha_subpastas(self):
        agora = time.time()
        foto = escrever(self.imagens / "Câmera" / "Foto.jpg", quando=agora - 100)
        escrever(self.imagens / "Câmera" / "Antigas" / "Foto nova.jpg", quando=agora)
        r = self.inicio()
        self.assertEqual(r["ultima"]["caminho"], str(foto))

    def test_video_sem_capa_e_sem_ffmpeg(self):
        escrever(self.videos / "Câmera" / "Vídeo.mp4", b"nao e video de verdade")
        with mock.patch.object(aj.shutil, "which", return_value=None):
            r = self.inicio()
            self.assertFalse(r["ffmpeg"])
        self.assertEqual(r["ultima"]["tipo"], "video")
        self.assertEqual(r["ultima"]["capa"], "")


class TestCapa(Base):
    def test_sem_ffmpeg_nao_faz_capa(self):
        video = escrever(self.casa / "v.mp4")
        with mock.patch.object(aj.shutil, "which", return_value=None):
            self.assertFalse(aj.fazer_capa(str(video), str(self.casa / "c.jpg")))
        self.assertFalse((self.casa / "c.jpg").exists())

    def test_video_que_nao_existe(self):
        self.assertFalse(aj.fazer_capa(str(self.casa / "nao.mp4"), str(self.casa / "c.jpg")))

    def test_video_estragado_nao_deixa_lixo(self):
        video = escrever(self.casa / "estragado.mp4", b"isto nao e um video")
        saida = self.dados / "capas" / "estragado.mp4.jpg"
        self.assertFalse(aj.fazer_capa(str(video), str(saida)))
        self.assertFalse(saida.exists())
        self.assertFalse(Path(str(saida) + ".parcial.jpg").exists())

    @unittest.skipUnless(shutil.which("ffmpeg"), "sem ffmpeg neste computador")
    def test_capa_de_um_video_de_verdade(self):
        video = self.videos / "Câmera" / "Vídeo 2026-11-12 03-40-12.mp4"
        video.parent.mkdir(parents=True)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc2=s=320x240:d=1",
                        "-pix_fmt", "yuv420p", str(video)], check=True)
        r = self.inicio()
        capa = r["ultima"]["capa"]
        self.assertEqual(capa, str(self.dados / "capas" / (video.name + ".jpg")))
        self.assertGreater(os.path.getsize(capa), 0)


class TestLinguaEVidro(Base):
    def test_lingua(self):
        os.environ["LANG"] = "pt_BR.UTF-8"
        self.assertEqual(aj.idioma(), "pt")
        os.environ["MATSU_LANG"] = "en_US"
        self.assertEqual(aj.idioma(), "en")
        os.environ["MATSU_LANG"] = ""
        os.environ["LANG"] = "C.UTF-8"
        escrever(self.casa / ".config" / "plasma-localerc", b"[Formats]\nLANG=pt_BR.UTF-8\n")
        self.assertEqual(aj.idioma(), "pt")

    def test_vidro(self):
        self.assertEqual(aj.vidro(), {"cor": "", "nivel": "normal"})
        escrever(self.casa / ".config" / "matsu" / "vidro", b"cor=rosa\ntransparencia=mais\n")
        self.assertEqual(aj.vidro(), {"cor": "#ec4899", "nivel": "mais"})
        escrever(self.casa / ".config" / "matsu" / "vidro", b"cor=#12ab34\ntransparencia=muita\n")
        self.assertEqual(aj.vidro(), {"cor": "#12ab34", "nivel": "normal"})
        escrever(self.casa / ".config" / "matsu" / "vidro", b"cor=javascript:alert(1)\n")
        self.assertEqual(aj.vidro()["cor"], "")


class TestLinhaDeComando(Base):
    def rodar(self, *args):
        env = dict(os.environ)
        return subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), *args], capture_output=True, text=True,
                              env=env, timeout=30)

    def test_inicio_pela_linha_de_comando(self):
        r = self.rodar("inicio", str(self.imagens), str(self.videos), str(self.dados))
        self.assertEqual(r.returncode, 0, r.stderr)
        d = json.loads(r.stdout)
        self.assertEqual(d["idioma"], "pt")
        self.assertTrue(os.path.isdir(d["fotos"]))
        self.assertIn("Câmera", r.stdout)  # sem â: o QML lê UTF-8 direto

    def test_capa_pela_linha_de_comando(self):
        r = self.rodar("capa", str(self.casa / "nao.mp4"), str(self.casa / "c.jpg"))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(json.loads(r.stdout), {"ok": False})

    def test_comando_errado(self):
        r = self.rodar("voar")
        self.assertEqual(r.returncode, 2)
        self.assertIn("Uso", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=1)
