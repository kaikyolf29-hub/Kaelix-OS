#!/usr/bin/env python3
"""Testes do ajudante da Central de jogos (system_files/usr/share/matsu/jogos/ajudante.py).

Monta uma Steam de mentira (bibliotecas, jogos, horas jogadas e capas nos dois
jeitos de pasta da Steam) e um /proc de mentira com um jogo aberto.

Uso: python3 tests/test_jogos.py
"""
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

RAIZ = Path(__file__).resolve().parents[1]
AJUDANTE = RAIZ / "system_files/usr/share/matsu/jogos/ajudante.py"


def carregar(env):
    antigo = {k: os.environ.get(k) for k in env}
    os.environ.update(env)
    try:
        spec = importlib.util.spec_from_file_location("jogos_teste", AJUDANTE)
        modulo = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(modulo)
        return modulo
    finally:
        for k, v in antigo.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


def escrever(caminho, texto):
    caminho = Path(caminho)
    caminho.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(texto, bytes):
        caminho.write_bytes(texto)
    else:
        caminho.write_text(texto)


def manifesto(appid, nome, pasta, flags=4, tamanho=1000, ultima=0):
    return f'''"AppState"
{{
	"appid"		"{appid}"
	"Universe"		"1"
	"name"		"{nome}"
	"StateFlags"		"{flags}"
	"installdir"		"{pasta}"
	"LastPlayed"		"{ultima}"
	"SizeOnDisk"		"{tamanho}"
}}
'''


def stat_linha(pid, comm, ppid, rss_paginas=100):
    campos = ["S", str(ppid)] + ["0"] * 19 + [str(rss_paginas)] + ["0"] * 20
    return f"{pid} ({comm}) " + " ".join(campos) + "\n"


class Mundo:
    def __init__(self, raiz):
        self.raiz = Path(raiz)
        self.steam = self.raiz / "casa/.local/share/Steam"
        self.outra = self.raiz / "hd/SteamLibrary"
        s = self.steam
        escrever(s / "steamapps/libraryfolders.vdf", f'''"libraryfolders"
{{
	"0"
	{{
		"path"		"{s}"
		"apps" {{ "570" "1" }}
	}}
	"1"
	{{
		"path"		"{self.outra}"
	}}
}}
''')
        escrever(s / "steamapps/appmanifest_570.acf", manifesto(570, "Dota 2", "dota 2 beta", tamanho=40_000_000_000))
        escrever(s / "steamapps/appmanifest_1493710.acf", manifesto(1493710, "Proton Experimental", "Proton - Experimental"))
        escrever(s / "steamapps/appmanifest_1628350.acf", manifesto(1628350, "Steam Linux Runtime 3.0 (sniper)", "SteamLinuxRuntime_sniper"))
        escrever(self.outra / "steamapps/appmanifest_1145360.acf", manifesto(1145360, "Hades", "Hades", ultima=1700000000))
        escrever(self.outra / "steamapps/appmanifest_413150.acf", manifesto(413150, "Stardew Valley", "Stardew Valley", flags=6))
        # Quem entrou por último e as horas jogadas.
        escrever(s / "config/loginusers.vdf", '''"users"
{
	"76561198000000001"
	{
		"AccountName"		"kaiky"
		"MostRecent"		"1"
	}
}
''')
        escrever(s / "userdata/39734273/config/localconfig.vdf", '''"UserLocalConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"apps"
				{
					"570"
					{
						"LastPlayed"		"1731300000"
						"Playtime"		"5432"
					}
					"1145360"
					{
						"Playtime"		"610"
						"LastPlayed"		"1731000000"
					}
				}
			}
		}
	}
}
''')
        cache = s / "appcache/librarycache"
        # Steam antiga: tudo numa pasta só.
        escrever(cache / "570_library_600x900.jpg", b"capa")
        escrever(cache / "570_library_hero.jpg", b"heroi")
        escrever(cache / "570_logo.png", b"logo")
        escrever(cache / "570_icon.jpg", b"icone")
        # Steam nova: uma pasta por jogo, com subpasta de tradução e ícone com nome de código.
        escrever(cache / "1145360/library_600x900.jpg", b"capa")
        escrever(cache / "1145360/abcdef/library_hero.jpg", b"heroi")
        escrever(cache / "1145360/logo.png", b"logo")
        escrever(cache / "1145360" / ("a" * 40 + ".jpg"), b"icone")

        # /proc com a Steam aberta, o lançador dela e o jogo (o de mais memória).
        self.proc = self.raiz / "proc"
        uid = os.getuid()
        self.processos = {
            100: ("steam", 1, ["/casa/.local/share/Steam/ubuntu12_32/steam"], 5000),
            200: ("reaper", 100, [str(s / "ubuntu12_32/reaper"), "SteamLaunch", "AppId=570", "--",
                                  str(s / "steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point")], 50),
            201: ("pv-adverb", 200, ["pv-adverb", "--", "dota2.sh"], 300),
            202: ("dota2", 201, [str(s / "steamapps/common/dota 2 beta/game/bin/linuxsteamrt64/dota2")], 900000),
            203: ("python3", 201, ["python3", "/x/proton", "waitforexitandrun"], 2000),
        }
        for pid, (comm, ppid, cmd, rss) in self.processos.items():
            escrever(self.proc / str(pid) / "stat", stat_linha(pid, comm, ppid, rss))
            escrever(self.proc / str(pid) / "cmdline", "\0".join(cmd) + "\0")
        escrever(self.proc / "stat", "cpu  100 0 100 800 0 0 0 0 0 0\n")
        escrever(self.proc / "meminfo", "MemTotal: 16000000 kB\nMemAvailable: 8000000 kB\n")
        self.sys = self.raiz / "sys"
        (self.sys / "class/drm").mkdir(parents=True)
        self.uid = uid

    def env(self):
        return {
            "HOME": str(self.raiz / "casa"),
            "XDG_CONFIG_HOME": str(self.raiz / "casa/.config"),
            "XDG_CACHE_HOME": str(self.raiz / "casa/.cache"),
            "MATSU_STEAM": f"{self.steam}",
            "MATSU_PROC": str(self.proc),
            "MATSU_SYS": str(self.sys),
            "MATSU_UID": str(self.uid),
            "MATSU_JOGOS_ESTADO": str(self.raiz / "estado"),
            "MATSU_FONTE_HUD": "/fontes/Inter-SemiBold.otf",
            "MATSU_LANG": "pt_BR.UTF-8",
            "MATSU_UDEV": str(self.raiz / "udev"),
            "MATSU_DEV": str(self.raiz / "dev"),
            "MATSU_RAIZ": str(self.raiz / "raiz"),
            "MATSU_IMAGE_INFO": str(self.raiz / "image-info.json"),
        }


class Base(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.mundo = Mundo(self.temp.name)
        self.env = mock.patch.dict(os.environ, self.mundo.env())
        self.env.start()
        self.a = carregar(self.mundo.env())

    def tearDown(self):
        self.env.stop()
        self.temp.cleanup()


class Steam(Base):
    def test_vdf(self):
        d = self.a.ler_vdf('"A" { "Chave" "valor \\"x\\"" "B" { "c" "1" } }')
        self.assertEqual(d, {"a": {"chave": 'valor "x"', "b": {"c": "1"}}})

    def test_biblioteca(self):
        b = self.a.biblioteca()
        self.assertTrue(b["steam"])
        nomes = [j["nome"] for j in b["jogos"]]
        # Proton e o Steam Linux Runtime não são jogos; o último jogado vem primeiro.
        self.assertEqual(nomes, ["Dota 2", "Hades", "Stardew Valley"])
        dota, hades, stardew = b["jogos"]
        self.assertEqual(dota["minutos"], 5432)
        self.assertEqual(dota["ultima"], 1731300000)
        self.assertEqual(dota["tamanho"], 40_000_000_000)
        self.assertTrue(dota["capa"].endswith("570_library_600x900.jpg"))
        self.assertTrue(dota["heroi"].endswith("570_library_hero.jpg"))
        self.assertTrue(dota["logo"].endswith("570_logo.png"))
        self.assertTrue(dota["icone"].endswith("570_icon.jpg"))
        self.assertTrue(hades["capa"].endswith("1145360/library_600x900.jpg"))
        self.assertTrue(hades["heroi"].endswith("abcdef/library_hero.jpg"))
        self.assertTrue(hades["icone"].endswith("a" * 40 + ".jpg"))
        self.assertEqual(hades["minutos"], 610)
        self.assertTrue(hades["pronto"])
        self.assertFalse(stardew["pronto"])  # atualizando
        self.assertNotIn("capa", stardew)

    def test_sem_steam(self):
        with mock.patch.dict(os.environ, {"MATSU_STEAM": str(self.mundo.raiz / "nada")}):
            with mock.patch.object(self.a.shutil, "which", return_value=None):
                self.assertEqual(self.a.biblioteca(), {"steam": False, "jogos": []})


class Config(Base):
    def test_padrao_e_limpeza(self):
        c = self.a.carregar_config()
        self.assertEqual(c["perfil"], "padrao")
        self.assertFalse(c["sobreposicao"]["ligada"])
        suja = {"perfil": "turbo", "jogos": {"570": "desempenho", "../x": "economia", "1": "nada"},
                "personalizado": {"fps": 61, "af": 16, "energia": "desempenho", "vsync": "ligada"},
                "sobreposicao": {"ligada": True, "itens": ["ram", "fps", "virus"], "posicao": "meio"}}
        c = self.a.salvar_config(suja)
        self.assertEqual(c["perfil"], "padrao")
        self.assertEqual(c["jogos"], {"570": "desempenho"})
        self.assertEqual(c["personalizado"]["fps"], 0)
        self.assertEqual(c["personalizado"]["af"], 16)
        self.assertEqual(c["sobreposicao"]["itens"], ["fps", "ram"])  # na ordem da tela
        self.assertEqual(c["sobreposicao"]["posicao"], "top-left")
        self.assertEqual(self.a.carregar_config(), c)

    def test_perfil_do_jogo(self):
        c = self.a.salvar_config({"perfil": "qualidade", "jogos": {"570": "economia"}})
        self.assertEqual(self.a.perfil_do_jogo(c, "570"), "economia")
        self.assertEqual(self.a.perfil_do_jogo(c, "1145360"), "qualidade")
        self.assertEqual(self.a.ajustes_do_perfil(c, "economia")["fps"], 60)


class Sobreposicao(Base):
    def test_texto(self):
        c = self.a.salvar_config({"sobreposicao": {"ligada": True, "itens": ["fps", "grafico", "cpu", "temperatura"],
                                                   "posicao": "top-right", "tamanho": "grande"}})
        sem_jogo = self.a.texto_mangohud(c, None, mostrar=False)
        self.assertIn("no_display", sem_jogo.splitlines())  # só aparece com jogo aberto
        self.assertIn("legacy_layout=0", sem_jogo)
        texto = self.a.texto_mangohud(c, self.a.PERFIS["economia"], mostrar=True)
        linhas = texto.splitlines()
        self.assertNotIn("no_display", linhas)
        for esperado in ("fps", "frametime", "frame_timing", "cpu_stats", "cpu_temp", "gpu_stats", "gpu_temp",
                         "position=top-right", "font_size=27", "fps_limit=60", "vsync=3", "gl_vsync=1",
                         "font_file=/fontes/Inter-SemiBold.otf", "toggle_hud=", "toggle_fps_limit=",
                         "upload_log=", "fps_limit_method=late"):
            self.assertIn(esperado, linhas)
        self.assertNotIn("ram", linhas)
        self.assertTrue(any(l.startswith("blacklist=") and "matsu-janela" in l for l in linhas))
        # Ordem do jogo: FPS antes de GPU, GPU antes de CPU.
        self.assertLess(linhas.index("fps"), linhas.index("gpu_stats"))
        self.assertLess(linhas.index("gpu_stats"), linhas.index("cpu_stats"))

    PC = {"cpu": "AMD Ryzen 7 5700X3D", "gpu": "AMD Radeon RX 6700 XT", "pci": "", "cpu_watts": True}

    def completa(self, pc=None, **extra):
        s = {"ligada": True, "itens": self.a.MODELOS["completa"]}
        s.update(extra)
        c = self.a.salvar_config({"sobreposicao": s})
        return self.a.texto_mangohud(c, None, mostrar=True, pc=pc or self.PC).splitlines()

    def test_completa_em_pe(self):
        linhas = self.completa()
        # Em pé, em blocos: FPS (com média, 1% e gráfico), placa (com a memória de
        # vídeo) e processador (com a memória), cada um com o nome em cima.
        ordem = ["fps", "fps_metrics=avg,0.01", "frame_timing", "custom_text=AMD Radeon RX 6700 XT", "gpu_stats",
                 "vram", "gpu_mem_clock", "custom_text=AMD Ryzen 7 5700X3D", "cpu_stats", "ram"]
        posicoes = [linhas.index(item) for item in ordem]
        self.assertEqual(posicoes, sorted(posicoes))
        self.assertEqual(linhas.count("custom_text="), 2)  # o respiro entre os três blocos
        for esperado in ("dx_api", "frametime", "gpu_temp", "gpu_core_clock", "gpu_power", "gpu_fan", "cpu_temp",
                         "cpu_mhz", "cpu_power", "table_columns=3", "font_size_secondary=15"):
            self.assertIn(esperado, linhas)
        # Com a API ligada, o nome dela fica no lugar de "FPS" (e o "FPS" pequeno volta).
        self.assertFalse(any(l.startswith("fps_text") for l in linhas))
        self.assertNotIn("hide_fps_superscript", linhas)
        self.assertFalse(any(l.startswith(("width=", "pci_dev=")) for l in linhas))
        # Só opções que o MangoHud 0.8.3 do Fedora conhece.
        conhecidas = {"legacy_layout", "fps", "dx_api", "frametime", "fps_metrics", "frame_timing", "custom_text",
                      "gpu_stats", "gpu_text", "gpu_temp", "gpu_core_clock", "gpu_power", "gpu_fan", "vram",
                      "gpu_mem_clock", "cpu_stats", "cpu_text", "cpu_temp", "cpu_mhz", "cpu_power", "ram",
                      "position", "font_size", "font_size_secondary", "round_corners", "background_alpha",
                      "background_color", "text_color", "text_outline", "cpu_color", "gpu_color", "ram_color",
                      "vram_color", "engine_color", "frametime_color", "fps_color_change", "fps_value", "fps_color",
                      "offset_x", "offset_y", "table_columns", "cellpadding_y", "font_file", "blacklist", "time",
                      "time_no_label", "time_format", "fps_text", "hide_fps_superscript", "engine_short_names",
                      "horizontal", "horizontal_stretch", "horizontal_separator_color", "hud_compact", "width",
                      "pci_dev", "no_display", "fps_limit", "fps_limit_method", "vsync", "gl_vsync", "af",
                      *self.a.TECLAS_MANGOHUD}
        for linha in linhas:
            if linha and not linha.startswith("#"):
                self.assertIn(linha.split("=", 1)[0], conhecidas, linha)

    def test_consumo_do_processador_so_quando_da_para_ler(self):
        linhas = self.completa(pc=dict(self.PC, cpu_watts=False))
        self.assertNotIn("cpu_power", linhas)  # sem "0 W" parado na tela
        self.assertIn("gpu_power", linhas)

    def test_nome_sem_cerquilha(self):
        linhas = self.completa(pc=dict(self.PC, gpu="Placa #1"))
        self.assertIn("custom_text=Placa 1", linhas)  # o MangoHud corta a linha no "#"

    def test_duas_placas_mostra_a_de_jogo(self):
        linhas = self.completa(pc=dict(self.PC, pci="0000:03:00.0"))
        self.assertIn("pci_dev=0000:03:00.0", linhas)

    def test_em_linha(self):
        linhas = self.completa(compacta=True)
        for esperado in ("horizontal", "hud_compact", "engine_short_names", "frametime=0"):
            self.assertIn(esperado, linhas)
        self.assertFalse(any(l.startswith("custom_text") for l in linhas))
        self.assertNotIn("frame_timing", linhas)

    def test_so_o_fps_fica_estreito(self):
        c = self.a.salvar_config({"sobreposicao": {"ligada": True, "itens": ["fps"]}})
        linhas = self.a.texto_mangohud(c, None, mostrar=True, pc=self.PC).splitlines()
        self.assertIn("width=253", linhas)
        self.assertIn("fps_text=FPS", linhas)
        self.assertIn("hide_fps_superscript", linhas)
        self.assertNotIn("custom_text=", linhas)

    def test_modelos_e_padrao(self):
        for itens in self.a.MODELOS.values():
            self.assertTrue(set(itens) <= set(self.a.ITENS))
        padrao = self.a.carregar_config()["sobreposicao"]["itens"]
        for item in ("fps", "fps_baixo", "grafico", "nomes", "gpu", "vram", "cpu", "ram", "temperatura"):
            self.assertIn(item, padrao)
        # Itens desconhecidos caem fora; a ordem é a do jogo.
        c = self.a.salvar_config({"sobreposicao": {"itens": ["ram", "inventado", "api", "fps"]}})
        self.assertEqual(c["sobreposicao"]["itens"], ["fps", "api", "ram"])

    def test_nomes_das_pecas(self):
        nome = self.a.nome_curto_cpu
        self.assertEqual(nome("12th Gen Intel Core i5-12400F"), "Intel Core i5-12400F")
        self.assertEqual(nome("Intel Core i7-8700 CPU @ 3.20GHz"), "Intel Core i7-8700")
        self.assertEqual(nome("AMD Ryzen 5 5600G with Radeon Graphics"), "AMD Ryzen 5 5600G")
        self.assertEqual(nome("AMD Ryzen 7 5700X3D"), "AMD Ryzen 7 5700X3D")
        placas = [{"nome": "Intel UHD 630", "driver": "i915", "caminho": "/x"},
                  {"nome": "NVIDIA GeForce RTX 2060 SUPER", "driver": "nvidia", "caminho": "/y"}]
        self.assertEqual(self.a.placa_principal(placas)["nome"], "NVIDIA GeForce RTX 2060 SUPER")
        self.assertIsNone(self.a.placa_principal([]))

    def test_consumo_cpu_legivel(self):
        sys_ = self.mundo.sys
        self.assertFalse(self.a.consumo_cpu_legivel())
        escrever(sys_ / "class/powercap/intel-rapl:0/name", "package-0\n")
        energia = sys_ / "class/powercap/intel-rapl:0/energy_uj"
        escrever(energia, "123\n")
        self.assertTrue(self.a.consumo_cpu_legivel())
        if os.getuid() != 0:  # o administrador lê tudo
            energia.chmod(0o000)
            self.assertFalse(self.a.consumo_cpu_legivel())
        escrever(sys_ / "class/hwmon/hwmon2/name", "zenpower\n")
        self.assertTrue(self.a.consumo_cpu_legivel())

    def test_desligada_nunca_mostra(self):
        c = self.a.carregar_config()
        self.assertIn("no_display", self.a.texto_mangohud(c, None, mostrar=True).splitlines())

    def test_qualidade(self):
        c = self.a.carregar_config()
        linhas = self.a.texto_mangohud(c, self.a.PERFIS["qualidade"], mostrar=True).splitlines()
        self.assertIn("af=16", linhas)
        self.assertNotIn("fps_limit=0", linhas)

    def test_escreve_no_lugar(self):
        self.a.escrever_mangohud()
        arquivo = Path(self.a.arquivo_mangohud())
        self.assertTrue(arquivo.exists())
        self.assertEqual(arquivo, self.mundo.raiz / "casa/.config/MangoHud/MangoHud.conf")


class Jogo(Base):
    def test_acha_o_jogo_da_steam(self):
        jogo = self.a.achar_jogo(nomes={"570": "Dota 2"})
        self.assertEqual(jogo["id"], "570")
        self.assertEqual(jogo["nome"], "Dota 2")
        self.assertEqual(jogo["lancador"], 200)
        self.assertEqual(jogo["pid"], 202)  # o jogo de verdade, não o python do Proton

    def test_jogo_do_windows_fora_da_steam(self):
        lista = {
            10: (1, ["/usr/bin/heroic"], 300 * 1048576),
            11: (10, ["C:\\windows\\system32\\explorer.exe"], 500 * 1048576),
            12: (10, ["Z:\\jogos\\Cyberpunk2077\\bin\\x64\\Cyberpunk2077.exe"], 6000 * 1048576),
            13: (10, ["C:\\x\\EpicGamesLauncher.exe"], 900 * 1048576),
        }
        jogo = self.a.achar_jogo(lista)
        self.assertEqual(jogo["nome"], "Cyberpunk2077")
        self.assertEqual(jogo["pid"], 12)
        self.assertEqual(jogo["origem"], "wine")

    def test_nada_aberto(self):
        self.assertIsNone(self.a.achar_jogo({1: (0, ["/usr/lib/systemd/systemd"], 1000)}))

    def test_servico_liga_e_desliga(self):
        self.a.salvar_config({"perfil": "desempenho", "sobreposicao": {"ligada": True}})
        chamadas = []
        with mock.patch.object(self.a, "energia_atual", return_value="balanced"), \
                mock.patch.object(self.a, "trocar_energia", side_effect=lambda p: chamadas.append(("energia", p)) or True), \
                mock.patch.object(self.a, "trocar_nivel_placa", side_effect=lambda n: chamadas.append(("placa", n)) or True), \
                mock.patch.object(self.a, "gamemode", side_effect=lambda m, p: chamadas.append((m, p)) or True), \
                mock.patch.object(self.a, "avisar", side_effect=lambda t, x: chamadas.append(("aviso", t, x))):
            s = self.a.Servico()
            s.passo()
            estado = json.loads(Path(self.a.arquivo_estado()).read_text())
            self.assertEqual(estado["jogo"]["id"], "570")
            self.assertEqual(estado["jogo"]["perfil"], "desempenho")
            self.assertIn(("energia", "performance"), chamadas)
            self.assertIn(("placa", "high"), chamadas)
            # Desempenho liga a baixa latência: o DXVK segura só 1 quadro.
            dxvk = Path(self.a.arquivo_dxvk()).read_text().splitlines()
            self.assertIn("dxgi.maxFrameLatency = 1", dxvk)
            self.assertIn("d3d9.maxFrameLatency = 1", dxvk)
            self.assertIn(("RegisterGame", 202), chamadas)
            self.assertIn(("aviso", "Dota 2", "Modo jogo ligado · perfil Desempenho"), chamadas)
            hud = Path(self.a.arquivo_mangohud()).read_text().splitlines()
            self.assertNotIn("no_display", hud)
            self.assertIn("vsync=1", hud)
            # O jogo fecha: volta tudo como estava.
            for pid in (200, 201, 202, 203):
                for arquivo in ("stat", "cmdline"):
                    (self.mundo.proc / str(pid) / arquivo).unlink()
                (self.mundo.proc / str(pid)).rmdir()
            chamadas.clear()
            s.passo()
            self.assertIn(("energia", "balanced"), chamadas)
            self.assertIn(("placa", "auto"), chamadas)
            self.assertIn(("UnregisterGame", 202), chamadas)
            self.assertIsNone(json.loads(Path(self.a.arquivo_estado()).read_text())["jogo"])
            self.assertIn("no_display", Path(self.a.arquivo_mangohud()).read_text().splitlines())
            self.assertNotIn("dxgi.maxFrameLatency = 1", Path(self.a.arquivo_dxvk()).read_text())

    def test_servico_desligado_nao_mexe(self):
        self.a.salvar_config({"automatico": False})
        with mock.patch.object(self.a, "trocar_energia") as energia, mock.patch.object(self.a, "gamemode") as gm:
            s = self.a.Servico()
            s.passo()
            energia.assert_not_called()
            gm.assert_not_called()


class Leitura(Base):
    def test_amostra(self):
        with mock.patch.object(self.a, "energia_atual", return_value="balanced"):
            leitor = self.a.Leitor()
            leitor.amostra()
            d = leitor.amostra()
        self.assertEqual(d["idioma"], "pt")
        self.assertEqual(d["memoria"]["total"], 16000000 * 1024)
        self.assertEqual(d["memoria"]["usada"], 8000000 * 1024)
        self.assertEqual(d["placas"], [])
        self.assertEqual(d["energia"], "balanced")
        self.assertIsNone(d["jogo"])

    def test_placa_amd(self):
        pasta = self.mundo.sys / "devices/pci0000:00/0000:03:00.0"
        escrever(pasta / "vendor", "0x1002\n")
        escrever(pasta / "device", "0x73df\n")
        escrever(pasta / "subsystem_vendor", "0x1849\n")
        escrever(pasta / "subsystem_device", "0x5219\n")
        escrever(pasta / "gpu_busy_percent", "57\n")
        escrever(pasta / "mem_info_vram_used", str(3 * 1024 ** 3) + "\n")
        escrever(pasta / "mem_info_vram_total", str(12 * 1024 ** 3) + "\n")
        escrever(pasta / "power_dpm_force_performance_level", "auto\n")
        escrever(pasta / "pp_dpm_sclk", "0: 500Mhz\n1: 2581Mhz *\n")
        escrever(pasta / "pp_dpm_mclk", "0: 96Mhz\n3: 1000Mhz *\n")
        hw = pasta / "hwmon/hwmon3"
        escrever(hw / "temp1_input", "61000\n")
        escrever(hw / "temp2_label", "junction\n")
        escrever(hw / "temp2_input", "74000\n")
        escrever(hw / "power1_average", "187000000\n")
        escrever(hw / "power1_cap", "230000000\n")
        escrever(hw / "fan1_input", "1450\n")
        escrever(hw / "pwm1", "102\n")
        driver = self.mundo.sys / "bus/pci/drivers/amdgpu"
        driver.mkdir(parents=True)
        (pasta / "driver").symlink_to(driver)
        (self.mundo.sys / "class/drm/card1").mkdir()
        (self.mundo.sys / "class/drm/card1/device").symlink_to(pasta)
        a = carregar(self.mundo.env())
        with mock.patch.object(a.T.Leitor, "versao_driver", staticmethod(lambda d: "Mesa 26.3.1")):
            placas = a.Leitor().placas()
        self.assertEqual(len(placas), 1)
        p = placas[0]
        self.assertEqual(p["marca"], "AMD")
        self.assertEqual(p["uso"], 57)
        self.assertEqual(p["temp"], 61)
        self.assertEqual(p["temp_junc"], 74)
        self.assertEqual(p["mhz"], 2581)
        self.assertEqual(p["mhz_mem"], 1000)
        self.assertEqual(p["watts"], 187.0)
        self.assertEqual(p["watts_max"], 230.0)
        self.assertEqual(p["rpm"], 1450)
        self.assertEqual(p["ventoinha"], 40)
        self.assertEqual(p["nivel"], "auto")
        self.assertTrue(p["nivel_mudavel"])
        self.assertEqual(len(a.placas_amd()), 1)


class Latencia(Base):
    def test_perfis(self):
        self.assertTrue(self.a.PERFIS["desempenho"]["latencia"])
        for p in ("padrao", "qualidade", "economia"):
            self.assertFalse(self.a.PERFIS[p]["latencia"])
        # Economia não prende a placa na velocidade mais baixa: o limite de FPS faz ela descer.
        self.assertEqual(self.a.PERFIS["economia"]["placa"], "auto")
        c = self.a.salvar_config({"personalizado": {"latencia": 1, "fps": 60}})
        self.assertIs(c["personalizado"]["latencia"], True)
        self.assertFalse(self.a.carregar_config()["personalizado"]["latencia"] is None)

    def test_mangohud_espera_antes(self):
        c = self.a.carregar_config()
        ajustes = dict(self.a.PERFIS["padrao"], fps=60, latencia=True)
        linhas = self.a.texto_mangohud(c, ajustes, mostrar=True).splitlines()
        self.assertIn("fps_limit=60", linhas)
        self.assertIn("fps_limit_method=early", linhas)
        sem_limite = self.a.texto_mangohud(c, dict(ajustes, fps=0), mostrar=True).splitlines()
        self.assertFalse([l for l in sem_limite if l.startswith(("fps_limit=", "fps_limit_method="))])

    def test_dxvk(self):
        self.assertIn("dxgi.maxFrameLatency = 1", self.a.texto_dxvk({"latencia": True}))
        self.assertIn("d3d9.maxFrameLatency = 1", self.a.texto_dxvk({"latencia": True}))
        self.assertNotIn("maxFrameLatency", self.a.texto_dxvk({"latencia": False}))
        self.assertNotIn("maxFrameLatency", self.a.texto_dxvk(None))
        casa = self.mundo.raiz / "casa/.config"
        self.assertEqual(Path(self.a.arquivo_dxvk()), casa / "matsu/jogos/dxvk.conf")
        # O DXVK_CONFIG_FILE do environment.d do Matsu vale; um da pessoa, fora de ~/.config/matsu, não é mexido.
        with mock.patch.dict(os.environ, {"DXVK_CONFIG_FILE": str(casa / "matsu/jogos/outro.conf")}):
            self.assertEqual(Path(self.a.arquivo_dxvk()), casa / "matsu/jogos/outro.conf")
        with mock.patch.dict(os.environ, {"DXVK_CONFIG_FILE": str(self.mundo.raiz / "jogo/dxvk.conf")}):
            self.assertEqual(Path(self.a.arquivo_dxvk()), casa / "matsu/jogos/dxvk.conf")

    def test_ambiente_aponta_para_o_mesmo_arquivo(self):
        texto = (RAIZ / "system_files/usr/lib/environment.d/60-matsu-jogos.conf").read_text()
        self.assertIn("MANGOHUD=1", texto.splitlines())
        self.assertIn("DXVK_CONFIG_FILE=${HOME}/.config/matsu/jogos/dxvk.conf", texto.splitlines())
        for chave in ("MESA_SHADER_CACHE_MAX_SIZE=", "__GL_SHADER_DISK_CACHE_SIZE=", "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1"):
            self.assertTrue(any(l.startswith(chave) for l in texto.splitlines()), chave)
        # Nada de vkBasalt global (mexeria em todo app Vulkan).
        self.assertNotIn("ENABLE_VKBASALT", texto)


class Fps(Base):
    def test_liga_desliga_e_alterna(self):
        self.assertEqual(self.a.fps(), {"ligada": False})
        self.assertEqual(self.a.fps("on"), {"ligada": True})
        self.assertTrue(self.a.carregar_config()["sobreposicao"]["ligada"])
        self.assertTrue(Path(self.a.arquivo_mangohud()).exists())
        self.assertEqual(self.a.fps("alternar"), {"ligada": False})
        self.assertFalse(self.a.carregar_config()["sobreposicao"]["ligada"])

    def test_com_jogo_aberto_aparece_na_hora(self):
        estado = {"jogo": {"id": "570", "nome": "Dota 2", "pid": 202, "perfil": "padrao",
                           "ajustes": dict(self.a.PERFIS["padrao"])}}
        self.a.gravar(self.a.arquivo_estado(), json.dumps(estado))
        self.a.fps("on")
        self.assertNotIn("no_display", Path(self.a.arquivo_mangohud()).read_text().splitlines())
        self.a.fps("off")
        self.assertIn("no_display", Path(self.a.arquivo_mangohud()).read_text().splitlines())

    def test_amostra_acompanha_o_atalho(self):
        """O atalho e a Central de controle mudam o arquivo; a janela vê na amostra seguinte."""
        with mock.patch.object(self.a, "energia_atual", return_value="balanced"):
            leitor = self.a.Leitor()
            self.assertFalse(leitor.amostra()["fps"])
            self.a.fps("on")
            os.utime(self.a.arquivo_config(), (1, 1))
            self.assertTrue(leitor.amostra()["fps"])
            self.assertEqual(leitor.amostra()["atalho"], self.a.ATALHO_FPS)

    def test_central_de_controle(self):
        """O item "FPS no jogo" da Central de controle lê e muda a mesma chave."""
        import subprocess
        central = RAIZ / "system_files/usr/libexec/matsu/matsu-central"
        falsos = self.mundo.raiz / "bin"
        falsos.mkdir()
        for nome in ("mangohud", "busctl", "kreadconfig6", "nmcli", "wpctl"):
            (falsos / nome).write_text("#!/bin/sh\nexit 0\n")
            (falsos / nome).chmod(0o755)
        env = dict(os.environ, **self.mundo.env(), PATH=f"{falsos}:{os.environ['PATH']}",
                   MATSU_JOGOS_AJUDANTE=str(AJUDANTE), MATSU_SYS_BLUETOOTH=str(self.mundo.raiz / "bt"),
                   MATSU_SYS_POWER=str(self.mundo.raiz / "pw"), MATSU_SYS_BACKLIGHT=str(self.mundo.raiz / "bl"))

        def central_(*args):
            r = subprocess.run(["bash", str(central), *args], capture_output=True, text=True, env=env, timeout=30)
            return r.stdout.splitlines()
        linhas = central_("estado")
        self.assertIn("fps_tem=1", linhas)
        self.assertIn("fps_ligado=0", linhas)
        central_("fps", "on")
        self.assertTrue(self.a.carregar_config()["sobreposicao"]["ligada"])
        self.assertIn("fps_ligado=1", central_("estado"))
        central_("fps", "off")
        self.assertIn("fps_ligado=0", central_("estado"))
        # Sem o MangoHud no sistema, o item não aparece.
        (falsos / "mangohud").unlink()
        env["PATH"] = f"{falsos}:/usr/bin:/bin"
        if not Path("/usr/bin/mangohud").exists():
            self.assertIn("fps_tem=0", central_("estado"))


class NivelDaPlaca(Base):
    def rodar_jogo(self, nivel_antes):
        self.a.salvar_config({"perfil": "desempenho"})
        chamadas = []
        with mock.patch.object(self.a, "energia_atual", return_value=""), \
                mock.patch.object(self.a, "nivel_placa", return_value=nivel_antes), \
                mock.patch.object(self.a, "trocar_nivel_placa", side_effect=lambda n: chamadas.append(n) or True), \
                mock.patch.object(self.a, "gamemode", return_value=True), \
                mock.patch.object(self.a, "avisar"):
            s = self.a.Servico()
            s.passo()
            s.terminar()
        return chamadas

    def test_volta_ao_nivel_de_antes(self):
        self.assertEqual(self.rodar_jogo("low"), ["high", "low"])
        self.assertEqual(self.rodar_jogo("auto"), ["high", "auto"])

    def test_respeita_o_ajuste_fino(self):
        # LACT ou CoreCtrl no comando: a Central não mexe na placa.
        self.assertEqual(self.rodar_jogo("manual"), [])


class Controles(Base):
    def setUp(self):
        super().setUp()
        self.C = self.a.C

    def test_nomes(self):
        self.assertEqual(self.C.nome_amigavel("054c", "0ce6"), ("DualSense", "playstation"))
        self.assertEqual(self.C.nome_amigavel("054c", "0df2"), ("DualSense Edge", "playstation"))
        self.assertEqual(self.C.nome_amigavel("045e", "0b13"), ("Controle Xbox", "xbox"))
        self.assertEqual(self.C.nome_amigavel("045e", "0b13", pt=False), ("Xbox controller", "xbox"))
        self.assertEqual(self.C.nome_amigavel("", "", "Wireless Controller"), ("DualShock 4", "playstation"))
        self.assertEqual(self.C.nome_amigavel("", "", "Xbox Wireless Controller"), ("Controle Xbox", "xbox"))
        self.assertEqual(self.C.nome_amigavel("057e", "2009")[1], "nintendo")
        self.assertEqual(self.C.nome_amigavel("2dc8", "6001", "8BitDo SN30 Pro"), ("8BitDo SN30 Pro", "outro"))
        self.assertEqual(self.C.ids_do_modalias("usb:v054Cp0CE6d0100"), ("054c", "0ce6"))

    def test_eh_controle(self):
        C = self.C
        self.assertTrue(C.eh_controle(icone="input-gaming"))
        self.assertTrue(C.eh_controle(classe=0x002508))      # periférico, gamepad
        self.assertTrue(C.eh_controle(aparencia=0x03C4))     # Bluetooth LE, gamepad
        self.assertTrue(C.eh_controle(modalias="usb:v045Ep0B13d0509"))
        self.assertFalse(C.eh_controle(icone="input-keyboard", classe=0x002540, nome="Teclado K380"))
        self.assertFalse(C.eh_controle(icone="audio-headphones", nome="Fone JBL"))

    def test_bluez_pelo_busctl(self):
        def v(t, d):
            return {"type": t, "data": d}
        saida = json.dumps({"type": "a{oa{sa{sv}}}", "data": [{
            "/org/bluez/hci0": {"org.bluez.Adapter1": {"Powered": v("b", True)}},
            "/org/bluez/hci0/dev_A0_AB_51_10_22_33": {
                "org.bluez.Device1": {"Address": v("s", "A0:AB:51:10:22:33"), "Alias": v("s", "DualSense Wireless Controller"),
                                      "Icon": v("s", "input-gaming"), "Paired": v("b", True), "Connected": v("b", True),
                                      "Modalias": v("s", "usb:v054Cp0CE6d0100")},
                "org.bluez.Battery1": {"Percentage": v("y", 64)}},
        }]})
        objetos = self.C.ler_objetos_bluez(saida)
        d = objetos["/org/bluez/hci0/dev_A0_AB_51_10_22_33"]
        self.assertEqual(d["org.bluez.Device1"]["Address"], "A0:AB:51:10:22:33")
        self.assertEqual(d["org.bluez.Battery1"]["Percentage"], 64)
        self.assertEqual(self.C.ler_objetos_bluez("lixo"), {})

    def test_info_do_bluetoothctl(self):
        texto = """Device 1C:A0:B8:01:02:03 (public)
\tName: Wireless Controller
\tAlias: Wireless Controller
\tClass: 0x00002508 (9480)
\tIcon: input-gaming
\tPaired: yes
\tBonded: yes
\tTrusted: yes
\tConnected: no
\tModalias: usb:v054Cp09CCd0100
\tBattery Percentage: 0x5a (90)
"""
        d = self.C.ler_info_bluetoothctl(texto)
        self.assertEqual(d["Address"], "1C:A0:B8:01:02:03")
        self.assertEqual(d["Class"], 0x2508)
        self.assertTrue(d["Paired"])
        self.assertFalse(d["Connected"])
        self.assertEqual(d["Battery"], 90)

    def montar_evdev(self, n, nome, vendor, product, bus, uniq):
        sysi = self.mundo.sys / f"class/input/event{n}"
        escrever(sysi / "dev", f"13:{64 + n}\n")
        escrever(sysi / "device/name", nome + "\n")
        escrever(sysi / "device/uniq", uniq + "\n")
        escrever(sysi / "device/id/vendor", vendor + "\n")
        escrever(sysi / "device/id/product", product + "\n")
        escrever(sysi / "device/id/bustype", bus + "\n")
        escrever(self.mundo.raiz / f"udev/c13:{64 + n}", "E:ID_INPUT=1\nE:ID_INPUT_JOYSTICK=1\n")

    def test_listar(self):
        C = self.C
        escrever(self.mundo.sys / "class/bluetooth/hci0/x", "")
        self.montar_evdev(5, "DualSense Wireless Controller", "054c", "0ce6", "0005", "a0:ab:51:10:22:33")
        self.montar_evdev(6, "Microsoft Xbox Series S|X Controller", "045e", "0b12", "0003", "")
        # O touchpad do DualSense é outro evento, sem a marca de controle.
        escrever(self.mundo.sys / "class/input/event7/dev", "13:71\n")
        escrever(self.mundo.sys / "class/input/event7/device/name", "DualSense Wireless Controller Touchpad\n")
        escrever(self.mundo.raiz / "udev/c13:71", "E:ID_INPUT=1\nE:ID_INPUT_TOUCHPAD=1\n")
        bat = self.mundo.sys / "class/power_supply/ps-controller-battery-a0:ab:51:10:22:33"
        escrever(bat / "capacity", "78\n")
        escrever(bat / "status", "Discharging\n")
        escrever(bat / "scope", "Device\n")
        aparelhos = [
            {"mac": "A0:AB:51:10:22:33", "nome_bruto": "DualSense Wireless Controller", "icone": "input-gaming",
             "classe": 0x2508, "aparencia": 0, "modalias": "usb:v054Cp0CE6d0100", "pareado": True, "conectado": True,
             "confiavel": True, "bateria": -1},
            {"mac": "98:7A:14:55:66:77", "nome_bruto": "Xbox Wireless Controller", "icone": "input-gaming",
             "classe": 0, "aparencia": 0x03C4, "modalias": "usb:v045Ep0B13d0509", "pareado": True, "conectado": False,
             "confiavel": True, "bateria": 50},
            {"mac": "11:22:33:44:55:66", "nome_bruto": "Teclado", "icone": "input-keyboard", "classe": 0x2540,
             "aparencia": 0, "modalias": "", "pareado": True, "conectado": True, "confiavel": True, "bateria": 80},
        ]
        with mock.patch.object(C, "estado_bluetooth", return_value={"tem": True, "ligado": True, "programa": True}), \
                mock.patch.object(C, "aparelhos_bluetooth", return_value=aparelhos):
            r = C.listar(pt=True)
        nomes = [(c["nome"], c["via"], c["conectado"]) for c in r["controles"]]
        self.assertEqual(nomes, [("Controle Xbox", "cabo", True), ("DualSense", "bluetooth", True),
                                 ("Controle Xbox", "bluetooth", False)])
        ds = r["controles"][1]
        self.assertEqual(ds["bateria"], 78)
        self.assertEqual(ds["evento"], "event5")
        self.assertFalse(ds["carregando"])
        self.assertEqual(r["controles"][2]["bateria"], -1)  # desconectado: a bateria não vale
        self.assertEqual(r["controles"][0]["evento"], "event6")

    def test_demo(self):
        with mock.patch.dict(os.environ, {"MATSU_CONTROLES_DEMO": "1"}):
            r = self.C.listar()
        self.assertEqual(len(r["controles"]), 3)
        with mock.patch.dict(os.environ, {"MATSU_CONTROLES_DEMO": "sem-bluetooth"}):
            self.assertFalse(self.C.listar()["bluetooth"]["tem"])

    def test_acao(self):
        C = self.C
        self.assertEqual(C.acao("esquecer", "nao-e-mac")["erro"], "pedido")
        self.assertEqual(C.acao("formatar", "A0:AB:51:10:22:33")["erro"], "pedido")
        with mock.patch.object(C.shutil, "which", return_value="/usr/bin/bluetoothctl"), \
                mock.patch.object(C, "rodar", return_value=(0, "Device has been removed")) as rodar:
            self.assertTrue(C.acao("esquecer", "a0:ab:51:10:22:33")["ok"])
        self.assertEqual(rodar.call_args[0][0], ["bluetoothctl", "remove", "A0:AB:51:10:22:33"])
        with mock.patch.object(C.shutil, "which", return_value="/usr/bin/bluetoothctl"), \
                mock.patch.object(C, "rodar", return_value=(1, "Failed to connect: org.bluez.Error.Failed br-connection-page-timeout")):
            self.assertFalse(C.acao("conectar", "A0:AB:51:10:22:33")["ok"])
        self.assertEqual(C.erro_bluez("Failed to pair: org.bluez.Error.AuthenticationFailed"), "autenticacao")
        self.assertEqual(C.erro_bluez("No default controller available"), "sem-adaptador")


class SessaoFalsa:
    """Um bluetoothctl de mentira: cada comando devolve as linhas do roteiro (com o prompt e as cores)."""

    def __init__(self, roteiro, relogio, inicio=(), limpar=lambda l: l):
        self.roteiro = roteiro
        self.relogio = relogio
        self.limpar = limpar
        self.fila = list(inicio)
        self.enviados = []

    def enviar(self, linha):
        self.enviados.append(linha)
        resposta = self.roteiro.get(linha, [])
        self.fila += list(resposta() if callable(resposta) else resposta)

    def ler(self, tempo):
        self.relogio.t += max(tempo, 0.01)
        if self.fila:
            return [self.limpar(self.fila.pop(0))]  # como a Sessao de verdade: sem cores e sem o prompt
        return []

    def fechar(self):
        self.enviados.append("<fim>")


class Relogio:
    def __init__(self):
        self.t = 0.0

    def __call__(self):
        return self.t


class Parear(Base):
    DS4 = "1C:A0:B8:01:02:03"
    XBOX = "98:7A:14:55:66:77"

    def info(self, mac):
        return {self.DS4: {"Name": "Wireless Controller", "Icon": "input-gaming", "Modalias": "usb:v054Cp09CCd0100",
                           "Connected": True},
                self.XBOX: {"Name": "Xbox Wireless Controller", "Icon": "input-gaming", "Modalias": "usb:v045Ep0B13d0509"},
                "11:22:33:44:55:66": {"Name": "Fone", "Icon": "audio-headphones"}}.get(mac, {})

    def rodar(self, roteiro, tipo="playstation", inicio=()):
        relogio = Relogio()
        etapas = []
        sessao = SessaoFalsa(roteiro, relogio, inicio, self.a.C.limpar_linha)
        ok = self.a.C.Pareamento(tipo, 20, etapas.append, sessao=sessao, consultar=self.info, relogio=relogio).rodar()
        return ok, etapas, sessao

    def test_liga_o_bluetooth_e_pareia(self):
        cor = "\x1b[0;92m"
        roteiro = {
            "show": ["Controller 00:1A:7D:DA:71:13 (public)", "\tPowered: no"],
            "power on": ["\x01\x1b[0;94m\x02[bluetooth]\x01\x1b[0m\x02# Changing power on succeeded"],
            "scan on": ["Discovery started", "[CHG] Controller 00:1A:7D:DA:71:13 Discovering: yes",
                        f"[{cor}NEW\x1b[0m] Device 11:22:33:44:55:66 Fone",
                        f"[{cor}NEW\x1b[0m] Device {self.DS4} Wireless Controller"],
            f"pair {self.DS4}": [f"Attempting to pair with {self.DS4}", f"[CHG] Device {self.DS4} Connected: yes",
                                 "Pairing successful"],
            f"trust {self.DS4}": [f"Changing {self.DS4} trust succeeded"],
            f"connect {self.DS4}": [f"Attempting to connect to {self.DS4}", "Connection successful"],
        }
        ok, etapas, sessao = self.rodar(roteiro)
        self.assertTrue(ok)
        nomes = [e["etapa"] for e in etapas]
        self.assertEqual(nomes[:3], ["comecando", "ligando", "procurando"])
        self.assertEqual([n for n in nomes if n != "procurando"][-5:], ["achou", "pareando", "confiando", "conectando", "pronto"])
        self.assertEqual(etapas[-1]["nome"], "DualShock 4")
        self.assertIn("scan off", sessao.enviados)
        self.assertEqual(sessao.enviados[-1], "<fim>")

    def test_tempo_esgotado(self):
        roteiro = {"show": ["\tPowered: yes"], "scan on": ["Discovery started"]}
        ok, etapas, _ = self.rodar(roteiro)
        self.assertFalse(ok)
        self.assertEqual(etapas[-1]["etapa"], "erro")
        self.assertEqual(etapas[-1]["erro"], "tempo")
        restam = [e["restam"] for e in etapas if e["etapa"] == "procurando"]
        self.assertEqual(restam[0], 20)
        self.assertLess(restam[-1], 3)

    def test_sem_adaptador(self):
        ok, etapas, _ = self.rodar({"show": ["No default controller available"]})
        self.assertFalse(ok)
        self.assertEqual(etapas[-1]["erro"], "sem-adaptador")

    def test_bluetooth_bloqueado(self):
        roteiro = {"show": ["\tPowered: no"],
                   "power on": ["Failed to set power on: org.bluez.Error.Blocked"]}
        ok, etapas, _ = self.rodar(roteiro)
        self.assertFalse(ok)
        self.assertEqual(etapas[-1]["erro"], "desligado")

    def test_so_o_tipo_escolhido_e_falha_ao_parear(self):
        roteiro = {
            "show": ["\tPowered: yes"],
            "scan on": [f"[NEW] Device {self.DS4} Wireless Controller", f"[NEW] Device {self.XBOX} Xbox Wireless Controller"],
            f"pair {self.XBOX}": ["Failed to pair: org.bluez.Error.AuthenticationFailed"],
        }
        ok, etapas, sessao = self.rodar(roteiro, tipo="xbox")
        self.assertFalse(ok)
        achou = [e for e in etapas if e["etapa"] == "achou"]
        self.assertEqual(achou[0]["mac"], self.XBOX)  # o DualShock foi ignorado: a pessoa escolheu Xbox
        self.assertEqual(etapas[-1]["erro"], "autenticacao")
        self.assertNotIn(f"pair {self.DS4}", sessao.enviados)

    def test_agente_pergunta_e_ja_conectado(self):
        roteiro = {
            "show": ["\tPowered: yes"],
            "scan on": [f"[NEW] Device {self.DS4} Wireless Controller"],
            f"pair {self.DS4}": ["[agent] Authorize service 00001124-0000-1000-8000-00805f9b34fb (yes/no):"],
            "yes": ["Pairing successful"],
            f"connect {self.DS4}": ["Failed to connect: org.bluez.Error.InProgress"],
        }
        ok, etapas, sessao = self.rodar(roteiro)
        self.assertTrue(ok)  # o controle já tinha se conectado sozinho (info diz Connected: yes)
        self.assertIn("yes", sessao.enviados)

    def test_demo_sem_controle_por_perto(self):
        """Na prévia com MATSU_CONTROLES_DEMO=vazio, a busca termina em "nenhum controle apareceu"."""
        etapas = []
        with mock.patch.dict(os.environ, {"MATSU_CONTROLES_DEMO": "vazio"}), \
                mock.patch.object(self.a.C.time, "sleep"):
            self.a.C.parear_demo("xbox", etapas.append)
        self.assertEqual(etapas[-1]["etapa"], "erro")
        self.assertEqual(etapas[-1]["erro"], "tempo")

    def test_limpar_linha(self):
        C = self.a.C
        self.assertEqual(C.limpar_linha("\x01\x1b[0;94m\x02[DualSense Wireless Controller]\x01\x1b[0m\x02# Connection successful"),
                         "Connection successful")


class Teste(Base):
    def test_leitura_playstation(self):
        C = self.a.C
        faixas = {c: (0, 255) for c in (0, 1, 2, 3, 4, 5)}
        faixas.update({0x10: (-1, 1), 0x11: (-1, 1)})
        l = C.Leitura(faixas, set(faixas), "playstation")
        self.assertTrue(l.evento(C.EV_ABS, 0, 255))
        l.evento(C.EV_ABS, 1, 0)
        l.evento(C.EV_ABS, 3, 129)   # quase no meio: fica no zero (zona morta)
        l.evento(C.EV_KEY, 0x130, 1)
        l.evento(C.EV_ABS, 0x11, -1)
        l.evento(C.EV_ABS, 2, 255)
        e = l.estado()
        self.assertEqual(e["eixos"]["lx"], 1.0)
        self.assertEqual(e["eixos"]["ly"], -1.0)
        self.assertEqual(e["eixos"]["rx"], 0.0)
        self.assertEqual(e["eixos"]["l2"], 1.0)
        self.assertEqual(e["botoes"]["sul"], 1)
        self.assertEqual(e["botoes"]["cima"], 1)
        self.assertEqual(e["botoes"]["l2b"], 1)
        self.assertFalse(l.evento(C.EV_KEY, 0x130, 1))  # sem mudança, sem linha nova

    def test_leitura_xbox_pelo_bluetooth_le(self):
        C = self.a.C
        faixas = {0: (0, 65535), 1: (0, 65535), 2: (0, 65535), 5: (0, 65535), 9: (0, 1023), 10: (0, 1023)}
        l = C.Leitura(faixas, set(faixas), "xbox")
        l.evento(C.EV_ABS, 2, 65535)   # direcional direito em Z
        l.evento(C.EV_ABS, 10, 1023)   # gatilho esquerdo no freio
        l.evento(C.EV_KEY, 0x133, 1)   # o X do Xbox chega como "norte"
        e = l.estado()
        self.assertEqual(e["eixos"]["rx"], 1.0)
        self.assertEqual(e["eixos"]["l2"], 1.0)
        self.assertEqual(e["botoes"]["oeste"], 1)
        self.assertEqual(e["botoes"]["norte"], 0)

    def test_eviocgabs(self):
        self.assertEqual(self.a.C.eviocgabs(0), 0x80184540)
        self.assertEqual(self.a.C.eviocgabs(5), 0x80184545)

    def test_le_o_evdev_de_verdade(self):
        """O ajudante lê os eventos no formato do kernel (struct input_event) e escreve o estado."""
        import struct
        import subprocess
        import time as tempo
        ev = self.mundo.raiz / "dev/input/event9"
        fmt = struct.Struct("llHHi")
        dados = fmt.pack(0, 0, 3, 0, 255) + fmt.pack(0, 0, 1, 0x131, 1) + fmt.pack(0, 0, 0, 0, 0)
        escrever(ev, dados)
        escrever(self.mundo.sys / "class/input/event9/device/capabilities/abs", "3\n")
        env = dict(os.environ, **self.mundo.env())
        p = subprocess.Popen(["python3", "-I", "-S", str(AJUDANTE), "testar", "event9"], stdout=subprocess.PIPE,
                             text=True, env=env)
        achou = None
        fim = tempo.monotonic() + 10
        try:
            while tempo.monotonic() < fim:
                linha = p.stdout.readline()
                if not linha:
                    break
                d = json.loads(linha)
                if d.get("botoes", {}).get("leste") == 1:
                    achou = d
                    break
        finally:
            p.kill()
            p.wait()
        self.assertIsNotNone(achou)
        self.assertEqual(achou["eixos"]["lx"], 1.0)

    def test_evento_invalido(self):
        self.assertEqual(self.a.C.caminho_evento("../../etc/passwd"), "")
        self.assertTrue(self.a.C.caminho_evento("event3").endswith("/input/event3"))


VULKANINFO = """==========
VULKANINFO
==========

Vulkan Instance Version: 1.4.321


Devices:
========
GPU0:
\tapiVersion         = 1.4.318
\tdriverVersion      = 25.2.4
\tvendorID           = 0x1002
\tdeviceID           = 0x73df
\tdeviceType         = PHYSICAL_DEVICE_TYPE_DISCRETE_GPU
\tdeviceName         = AMD Radeon RX 6700 XT (RADV NAVI22)
\tdriverID           = DRIVER_ID_MESA_RADV
\tdriverName         = radv
\tdriverInfo         = Mesa 25.2.4
GPU1:
\tapiVersion         = 1.4.318
\tdriverVersion      = 0.0.1
\tvendorID           = 0x10005
\tdeviceType         = PHYSICAL_DEVICE_TYPE_CPU
\tdeviceName         = llvmpipe (LLVM 20.1.8, 256 bits)
\tdriverName         = llvmpipe
\tdriverInfo         = Mesa 25.2.4 (LLVM 20.1.8)
"""


class Drivers(Base):
    def setUp(self):
        super().setUp()
        self.D = self.a.D

    def placa_pci(self, endereco, vendor, device, driver, boot_vga, vram=0):
        pasta = self.mundo.sys / "bus/pci/devices" / endereco
        escrever(pasta / "class", "0x030000\n")
        escrever(pasta / "vendor", f"0x{vendor}\n")
        escrever(pasta / "device", f"0x{device}\n")
        escrever(pasta / "boot_vga", f"{boot_vga}\n")
        if vram:
            escrever(pasta / "mem_info_vram_total", f"{vram}\n")
        alvo = self.mundo.sys / "bus/pci/drivers" / driver
        alvo.mkdir(parents=True, exist_ok=True)
        (pasta / "driver").symlink_to(alvo)

    def test_vulkaninfo(self):
        d = self.D.ler_vulkaninfo(VULKANINFO)
        self.assertEqual(d["instancia"], "1.4.321")
        self.assertEqual(len(d["gpus"]), 2)
        g = d["gpus"][0]
        self.assertEqual((g["driver"], g["api"], g["info"], g["tipo"], g["fornecedor"]),
                         ("radv", "1.4.318", "Mesa 25.2.4", "dedicada", "1002"))
        self.assertEqual(d["gpus"][1]["tipo"], "processador")
        self.assertTrue(self.D.anti_lag("...\n\tVK_AMD_anti_lag : extension revision 1\n"))
        self.assertFalse(self.D.anti_lag(VULKANINFO))

    def test_glxinfo(self):
        d = self.D.ler_glxinfo("OpenGL renderer string: AMD Radeon RX 6700 XT (radeonsi, navi22, LLVM 20.1.8)\n"
                               "OpenGL core profile version string: 4.6 (Core Profile) Mesa 25.2.4\n")
        self.assertEqual(d["api"], "4.6")
        self.assertEqual(d["mesa"], "25.2.4")

    def icd(self, nome, biblioteca, criar=True):
        raiz = self.mundo.raiz / "raiz"
        escrever(raiz / "usr/share/vulkan/icd.d" / nome,
                 json.dumps({"file_format_version": "1.0.1", "ICD": {"library_path": biblioteca, "api_version": "1.4.318"}}))
        if criar and biblioteca.startswith("/"):
            escrever(raiz / biblioteca.lstrip("/"), b"")

    def test_vulkan_32_bits(self):
        raiz = self.mundo.raiz / "raiz"
        self.icd("radeon_icd.x86_64.json", "/usr/lib64/libvulkan_radeon.so")
        self.assertFalse(self.D.vulkan32()["ok"])  # só 64 bits
        self.icd("radeon_icd.i686.json", "/usr/lib/libvulkan_radeon.so")
        self.assertFalse(self.D.vulkan32()["ok"])  # falta o carregador de 32 bits
        escrever(raiz / "usr/lib/libvulkan.so.1", b"")
        v = self.D.vulkan32()
        self.assertTrue(v["ok"])
        self.assertEqual(v["drivers"], ["RADV (Mesa)"])
        nomes = {(i["nome"], i["bits"]) for i in self.D.icds()}
        self.assertEqual(nomes, {("RADV (Mesa)", 64), ("RADV (Mesa)", 32)})

    def test_vulkan_32_bits_nvidia(self):
        raiz = self.mundo.raiz / "raiz"
        self.icd("nvidia_icd.json", "libGLX_nvidia.so.0")
        escrever(raiz / "usr/lib64/libGLX_nvidia.so.0", b"")
        escrever(raiz / "usr/lib/libvulkan.so.1", b"")
        self.assertFalse(self.D.vulkan32()["ok"])
        escrever(raiz / "usr/lib/libGLX_nvidia.so.0", b"")
        self.assertEqual(self.D.vulkan32()["drivers"], ["NVIDIA"])

    def test_placas_e_notebook_com_duas(self):
        self.placa_pci("0000:00:02.0", "8086", "a7a0", "i915", 1)
        self.placa_pci("0000:01:00.0", "10de", "28e0", "nvidia", 0)
        lista = self.D.placas(lambda f, a, sf, sa, l: {"8086": "Intel Iris Xe", "10de": "NVIDIA GeForce RTX 4060"}[f])
        self.assertEqual([(p["marca"], p["driver"], p["principal"]) for p in lista],
                         [("Intel", "i915", True), ("NVIDIA", "nvidia", False)])
        self.assertEqual([self.D.tipo_placa(p) for p in lista], ["integrada", "dedicada"])
        # A integrada da AMD (Ryzen) fica fora do barramento 00, mas tem pouca memória própria.
        self.placa_pci("0000:0e:00.0", "1002", "164e", "amdgpu", 0, vram=512 * 1024 ** 2)
        amd = [p for p in self.D.placas() if p["fornecedor"] == "1002"][0]
        self.assertEqual(self.D.tipo_placa(amd), "integrada")
        # A placa da máquina virtual (virtio-gpu do QEMU) não é "dedicada".
        self.placa_pci("0000:00:01.0", "1af4", "1050", "virtio-pci", 1)
        vm = [p for p in self.D.placas() if p["fornecedor"] == "1af4"][0]
        self.assertEqual(self.D.tipo_placa(vm), "virtual")

    def test_versao_mesa_com_32_e_64_bits(self):
        with mock.patch.object(self.D, "rodar", lambda args, tempo=30: "26.2.6\n26.2.6\n"):
            self.assertEqual(self.D.versao_mesa(), "26.2.6")

    def test_vulkan_32_bits_so_os_drivers_de_pc_na_tela(self):
        raiz = self.mundo.raiz / "raiz"
        escrever(raiz / "usr/lib/libvulkan.so.1", b"")
        for chave in ("radeon", "intel", "broadcom", "freedreno", "powervr_mesa"):
            self.icd(f"{chave}_icd.i686.json", f"/usr/lib/libvulkan_{chave}.so")
        self.assertEqual(self.D.vulkan32()["drivers"], ["ANV (Mesa)", "RADV (Mesa)"])

    def test_imagem_e_troca(self):
        D = self.D
        escrever(self.mundo.raiz / "image-info.json",
                 json.dumps({"image-name": "matsu-os", "image-variant": "main", "image-registry": "ghcr.io/kaikyolf29-hub"}))
        status = {"deployments": [{"booted": True, "container-image-reference":
                                   "ostree-image-signed:docker://ghcr.io/kaikyolf29-hub/matsu-os:estavel"}]}
        img = D.ler_imagem(status)
        self.assertEqual((img["variante"], img["tag"], img["registro"]), ("main", "estavel", "ghcr.io/kaikyolf29-hub"))
        rtx = {"fornecedor": "10de", "modelo_id": "2684"}
        gtx1050 = {"fornecedor": "10de", "modelo_id": "1c82"}
        radeon = {"fornecedor": "1002", "modelo_id": "73df"}
        t = D.troca_de_imagem([rtx], img)
        self.assertEqual(t["acao"], "instalar-nvidia")
        self.assertEqual(t["alvo"], "ghcr.io/kaikyolf29-hub/matsu-os-nvidia:estavel")
        self.assertEqual(t["aviso"], "")
        self.assertEqual(D.troca_de_imagem([gtx1050], img)["aviso"], "antiga")
        self.assertIsNone(D.troca_de_imagem([radeon], img))
        nvidia = dict(img, variante="nvidia", nome="matsu-os-nvidia")
        t = D.troca_de_imagem([radeon], nvidia)
        self.assertEqual((t["acao"], t["alvo"]), ("tirar-nvidia", "ghcr.io/kaikyolf29-hub/matsu-os:estavel"))
        self.assertIsNone(D.troca_de_imagem([rtx, radeon], nvidia))
        # O caminho de volta existe mesmo quando a placa não pede a troca.
        self.assertEqual(D.outra_imagem(nvidia), {"acao": "tirar-nvidia", "nome": "matsu-os", "aviso": "",
                                                  "alvo": "ghcr.io/kaikyolf29-hub/matsu-os:estavel"})
        self.assertEqual(D.outra_imagem(img)["alvo"], "ghcr.io/kaikyolf29-hub/matsu-os-nvidia:estavel")
        self.assertIsNone(D.outra_imagem({"registro": ""}))
        self.assertEqual(D.comando_troca(t["alvo"]),
                         ["pkexec", "bootc", "switch", "--enforce-container-sigpolicy", "ghcr.io/kaikyolf29-hub/matsu-os:estavel"])
        self.assertIsNone(D.comando_troca("ghcr.io/x/matsu-os:estavel; rm -rf /"))
        # Sem image-info: pelo nome da imagem do rpm-ostree; com digest, o canal padrão.
        (self.mundo.raiz / "image-info.json").unlink()
        img = D.ler_imagem({"deployments": [{"booted": True, "container-image-reference":
                                              "ostree-unverified-registry:ghcr.io/k/matsu-os-nvidia@sha256:abc"}]})
        self.assertEqual((img["nome"], img["variante"], img["tag"], img["registro"]),
                         ("matsu-os-nvidia", "nvidia", "", "ghcr.io/k"))
        self.assertTrue(D.troca_de_imagem([radeon], img)["alvo"].endswith("/matsu-os:estavel"))

    def test_tudo_sem_programas(self):
        D = self.D
        self.placa_pci("0000:01:00.0", "10de", "2684", "nvidia", 1)
        escrever(self.mundo.proc / "driver/nvidia/version",
                 "NVRM version: NVIDIA UNIX Open Kernel Module for x86_64  580.95.05  Release Build\n")
        self.icd("nvidia_icd.json", "libGLX_nvidia.so.0")
        with mock.patch.object(D, "rodar", return_value=None):
            d = D.tudo(lambda *a: "NVIDIA GeForce RTX 4090")
        p = d["placas"][0]
        self.assertEqual(p["versao"], "NVIDIA 580.95.05")
        self.assertEqual(d["nvidia"], "580.95.05")
        self.assertIsNone(p["vulkan"])
        self.assertFalse(d["vulkan"]["tem_vulkaninfo"])
        self.assertEqual(d["vulkan"]["icds"][0]["nome"], "NVIDIA")
        self.assertFalse(d["anti_lag"])
        self.assertIn("kernel", d)

    def test_trocar_para_a_outra_versao(self):
        """trocar-imagem outra: o caminho de volta, mesmo sem a placa pedir."""
        import contextlib
        import io
        img = {"nome": "matsu-os-nvidia", "variante": "nvidia", "registro": "ghcr.io/k", "tag": "estavel"}
        saida = io.StringIO()
        with mock.patch.object(self.D, "ler_imagem", return_value=img), \
                mock.patch.object(self.D, "placas", return_value=[{"fornecedor": "10de", "modelo_id": "2684"}]), \
                mock.patch.object(self.a.subprocess, "Popen", side_effect=OSError("sem bootc")), \
                contextlib.redirect_stdout(saida):
            self.assertEqual(self.a.trocar_imagem("outra"), 127)
        linhas = [json.loads(l) for l in saida.getvalue().splitlines()]
        self.assertEqual(linhas[0], {"alvo": "ghcr.io/k/matsu-os:estavel"})
        # Sem "outra", com placa NVIDIA na versão NVIDIA, não há o que trocar.
        saida = io.StringIO()
        with mock.patch.object(self.D, "ler_imagem", return_value=img), \
                mock.patch.object(self.D, "placas", return_value=[{"fornecedor": "10de", "modelo_id": "2684"}]), \
                contextlib.redirect_stdout(saida):
            self.assertEqual(self.a.trocar_imagem(), 3)
        self.assertEqual(json.loads(saida.getvalue().splitlines()[-1])["erro"], "nada")

    def test_demo(self):
        d = self.D.demo()
        self.assertEqual(len(d["placas"]), 2)
        self.assertIsNone(d["troca"])
        self.assertEqual(d["outra"]["acao"], "instalar-nvidia")
        with mock.patch.dict(os.environ, {"MATSU_DRIVERS_DEMO": "nvidia"}):
            self.assertEqual(self.D.demo()["troca"]["acao"], "instalar-nvidia")


class Janela(unittest.TestCase):
    """O desenho (QML) combina com o ajudante: os mesmos perfis, as páginas e os ícones."""
    PASTA = RAIZ / "system_files/usr/share/matsu/jogos"

    def setUp(self):
        self.main = (self.PASTA / "Main.qml").read_text()

    def test_perfis_iguais_aos_do_ajudante(self):
        import re
        a = carregar({})
        bloco = self.main.split("readonly property var ajustesProntos: ({", 1)[1].split("})", 1)[0]
        achados = {}
        for nome, corpo in re.findall(r"(\w+): \{([^}]*)\}", bloco):
            valores = {}
            for chave, valor in re.findall(r"(\w+): (\"[^\"]*\"|true|false|\d+)", corpo):
                valores[chave] = json.loads(valor)
            achados[nome] = valores
        self.assertEqual(achados, a.PERFIS)

    def test_paginas_e_arquivos(self):
        import re
        for pagina, arquivo in (("controles", "PaginaControles.qml"), ("drivers", "PaginaDrivers.qml")):
            self.assertIn(f'id: "{pagina}"', self.main)
            self.assertIn(f'{pagina}: "{arquivo}"', self.main)
            self.assertTrue((self.PASTA / arquivo).exists())
        self.assertIn("trocaSuave: true", self.main)
        # Os ícones próprios no jeito do Matsu (grade 24, traço 1.9, cor do tema).
        for icone in set(re.findall(r'icones/([\w-]+\.svg)', "".join(p.read_text() for p in self.PASTA.glob("*.qml")))):
            svg = (self.PASTA / "icones" / icone).read_text()
            self.assertIn('viewBox="0 0 24 24"', svg, icone)
            self.assertIn('class="ColorScheme-Text"', svg, icone)
            self.assertIn('stroke-width="1.9"', svg, icone)

    def test_nada_do_atalho_antigo(self):
        for qml in self.PASTA.glob("*.qml"):
            self.assertNotIn("F12", qml.read_text(), qml.name)

    def test_comandos_que_a_janela_usa(self):
        """Cada comando do ajudante chamado pelo QML existe no main()."""
        import re
        aj = (self.PASTA / "ajudante.py").read_text()
        usados = set(re.findall(r'comando\([^"\n]*"([\w-]+)"', "".join(p.read_text() for p in self.PASTA.glob("*.qml"))))
        self.assertTrue({"controles", "controle", "parear", "testar", "drivers", "trocar-imagem", "bluetooth-ligar"} <= usados)
        for c in usados:
            self.assertIn(f'comando == "{c}"', aj, c)


class Montagem(unittest.TestCase):
    """O que o build_files/jogos.sh garante na imagem (lido do arquivo, sem montar)."""

    def setUp(self):
        self.sh = (RAIZ / "build_files/jogos.sh").read_text()

    def test_cabecalho_e_sintaxe(self):
        import subprocess
        self.assertTrue(self.sh.startswith("#!/usr/bin/bash\n"))
        self.assertIn("set -euo pipefail", self.sh)
        self.assertEqual(subprocess.run(["bash", "-n", str(RAIZ / "build_files/jogos.sh")]).returncode, 0)

    def test_pacotes_e_conferencias(self):
        for pacote in ("mesa-vulkan-drivers", "mesa-vulkan-drivers.i686", "vulkan-loader.i686", "mesa-dri-drivers.i686",
                       "vulkan-tools", "game-devices-udev", "glx-utils"):
            self.assertIn(pacote, self.sh)
        self.assertIn("--skip-unavailable", self.sh)
        for coisa in ("xpadneo", "xone", "steam-devices", "IMAGE_VARIANT", "matsu-os-nvidia", "libGLX_nvidia"):
            self.assertIn(coisa, self.sh)

    def test_bluetooth(self):
        for chave in ("FastConnectable", "JustWorksRepairing", "ReconnectAttempts", "/etc/bluetooth/main.conf"):
            self.assertIn(chave, self.sh)

    def test_ntsync(self):
        carregar = (RAIZ / "system_files/usr/lib/modules-load.d/matsu-jogos-ntsync.conf").read_text()
        self.assertIn("ntsync", carregar.split())
        regra = (RAIZ / "system_files/usr/lib/udev/rules.d/70-matsu-jogos-ntsync.rules").read_text()
        self.assertIn('KERNEL=="ntsync"', regra)
        self.assertIn('MODE="0666"', regra)
        self.assertIn("ntsync", self.sh)

    def test_atalho_do_fps(self):
        a = carregar({})
        self.assertIn(f"X-KDE-Shortcuts={a.ATALHO_FPS}", self.sh)
        self.assertIn("ajudante.py fps alternar --avisar", self.sh)
        self.assertIn("/usr/share/kglobalaccel", self.sh)


if __name__ == "__main__":
    unittest.main(verbosity=2)
