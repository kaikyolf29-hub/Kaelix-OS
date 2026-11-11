#!/usr/bin/env python3
"""Testes do ajudante da Central de jogos (system_files/usr/share/kaelix/jogos/ajudante.py).

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
AJUDANTE = RAIZ / "system_files/usr/share/kaelix/jogos/ajudante.py"


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
            "KAELIX_STEAM": f"{self.steam}",
            "KAELIX_PROC": str(self.proc),
            "KAELIX_SYS": str(self.sys),
            "KAELIX_UID": str(self.uid),
            "KAELIX_JOGOS_ESTADO": str(self.raiz / "estado"),
            "KAELIX_FONTE_HUD": "/fontes/Inter-SemiBold.otf",
            "KAELIX_LANG": "pt_BR.UTF-8",
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
        with mock.patch.dict(os.environ, {"KAELIX_STEAM": str(self.mundo.raiz / "nada")}):
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
                         "font_file=/fontes/Inter-SemiBold.otf", "toggle_hud=Shift_R+F12"):
            self.assertIn(esperado, linhas)
        self.assertNotIn("ram", linhas)
        self.assertTrue(any(l.startswith("blacklist=") and "kaelix-janela" in l for l in linhas))
        # Ordem do jogo: FPS antes de GPU, GPU antes de CPU.
        self.assertLess(linhas.index("fps"), linhas.index("gpu_stats"))
        self.assertLess(linhas.index("gpu_stats"), linhas.index("cpu_stats"))

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
