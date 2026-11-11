#!/usr/bin/env python3
"""Testes do ajudante do Gerenciador de tarefas (system_files/usr/share/matsu/tarefas/ajudante.py).

Usa um /proc e um /sys de mentira, montados numa pasta temporária, e no fim
uma leitura de verdade do computador onde o teste roda.

Uso: python3 tests/test_tarefas.py
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock
from pathlib import Path

AJUDANTE = Path(__file__).resolve().parents[1] / "system_files/usr/share/matsu/tarefas/ajudante.py"


def carregar(env):
    """Carrega o ajudante com estas variáveis de ambiente (ele lê as pastas ao carregar)."""
    antigo = {k: os.environ.get(k) for k in env}
    os.environ.update(env)
    try:
        spec = importlib.util.spec_from_file_location("ajudante_teste", AJUDANTE)
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
    caminho.parent.mkdir(parents=True, exist_ok=True)
    caminho.write_text(texto)


def stat_linha(pid, comm, ppid, ticks, threads=1, inicio=100, estado="S"):
    # Campos de /proc/<pid>/stat: depois de ")" vêm estado, ppid, ... utime(14), stime(15), num_threads(20), starttime(22).
    campos = [estado, str(ppid)] + ["0"] * 9 + [str(ticks), "0"] + ["0"] * 4 + [str(threads), "0", str(inicio)] + ["0"] * 20
    return f"{pid} ({comm}) " + " ".join(campos) + "\n"


class MundoFalso:
    """Um /proc e um /sys pequenos: 1 app (Arquivos), 1 serviço, 1 linha do kernel e 1 de outro usuário."""

    def __init__(self, raiz):
        self.raiz = Path(raiz)
        self.proc = self.raiz / "proc"
        self.sys = self.raiz / "sys"
        self.dados = self.raiz / "dados"
        app = self.dados / "applications"
        escrever(app / "org.kde.dolphin.desktop",
                 "[Desktop Entry]\nName=Dolphin\nName[pt_BR]=Arquivos\nIcon=system-file-manager\n")
        # Apps abertos fora do menu: a logo vem do .desktop pelo programa (Exec=) ou pelo D-Bus.
        escrever(app / "steam.desktop", "[Desktop Entry]\nName=Steam\nIcon=steam\nExec=env A=1 /usr/bin/steam %U\n")
        escrever(app / "org.telegram.desktop.desktop",
                 "[Desktop Entry]\nName=Telegram\nIcon=org.telegram.desktop\nExec=/usr/bin/telegram-desktop -- %u\n")
        escrever(app / "htop.desktop", "[Desktop Entry]\nName=Htop\nIcon=htop\nExec=htop\nTerminal=true\n")
        escrever(app / "org.kde.konsole.desktop", "[Desktop Entry]\nName=Konsole\nName[pt_BR]=Terminal\n"
                 "Icon=utilities-terminal\nExec=konsole\n")
        self.ticks_total = 1000
        self.processos(10)
        escrever(self.proc / "cpuinfo", "processor\t: 0\nmodel name\t: AMD Ryzen 5 5600 6-Core Processor\nphysical id\t: 0\n"
                 "core id\t: 0\ncpu MHz\t: 3900.000\nflags\t: fpu sse\n\nprocessor\t: 1\nphysical id\t: 0\ncore id\t: 0\n"
                 "cpu MHz\t: 4100.000\n")
        escrever(self.proc / "meminfo", "MemTotal: 16000000 kB\nMemFree: 6000000 kB\nMemAvailable: 10000000 kB\n"
                 "Buffers: 100000 kB\nCached: 4000000 kB\nSReclaimable: 200000 kB\nShmem: 300000 kB\n"
                 "SwapTotal: 8000000 kB\nSwapFree: 7800000 kB\n")
        escrever(self.proc / "uptime", "3725.5 1000.0\n")
        escrever(self.proc / "diskstats", "259 0 nvme0n1 100 0 2000 0 50 0 1000 0 0 500 0\n")
        escrever(self.proc / "net/dev", "Inter-|\n face |\n  wlp4s0: 1000 10 0 0 0 0 0 0 500 5 0 0 0 0 0 0\n"
                 "    lo: 99 1 0 0 0 0 0 0 99 1 0 0 0 0 0 0\n")
        escrever(self.proc / "self/mounts", "")
        escrever(self.sys / "block/nvme0n1/size", "1953525168\n")
        escrever(self.sys / "block/nvme0n1/queue/rotational", "0\n")
        escrever(self.sys / "block/nvme0n1/device/model", "Samsung SSD 980 1TB\n")
        escrever(self.sys / "block/loop0/size", "100\n")
        (self.sys / "class/net/wlp4s0/device").mkdir(parents=True)
        (self.sys / "class/net/wlp4s0/wireless").mkdir(parents=True)
        escrever(self.sys / "class/net/wlp4s0/operstate", "up\n")
        (self.sys / "class/net/lo").mkdir(parents=True)
        placa = self.sys / "class/drm/card0/device"
        escrever(placa / "vendor", "0x1002\n")
        escrever(placa / "device", "0x67df\n")
        escrever(placa / "subsystem_vendor", "0x1da2\n")
        escrever(placa / "subsystem_device", "0xe366\n")
        escrever(placa / "gpu_busy_percent", "37\n")
        escrever(placa / "mem_info_vram_used", str(1 << 30) + "\n")
        escrever(placa / "mem_info_vram_total", str(8 << 30) + "\n")
        escrever(placa / "hwmon/hwmon3/temp1_input", "48000\n")
        escrever(placa / "pp_dpm_sclk", "0: 300Mhz\n1: 1340Mhz *\n")
        (self.sys / "class/drm/card0-DP-1").mkdir(parents=True)
        escrever(self.raiz / "pci.ids", "# teste\n1002  Advanced Micro Devices, Inc. [AMD/ATI]\n"
                 "\t67df  Ellesmere [Radeon RX 470/480/570/570X/580/580X/590]\n"
                 "\t\t1da2 e366  Nitro+ Radeon RX 570/580/590\n"
                 "\t67ef  Baffin [Radeon RX 460/560D]\n10de  NVIDIA Corporation\n")

    def processos(self, passo):
        uid = os.getuid()
        user = f"/user.slice/user-{uid}.slice/user@{uid}.service"
        lista = [
            (2, "kthreadd", 0, 0, "", ""),
            (40, "kworker/0:1", 2, 5, "", ""),
            (1500, "dolphin", 1, 20 + passo * 3, f"0::{user}/app.slice/app-org.kde.dolphin-0123456789abcdef0123456789abcdef.scope",
             "/usr/bin/dolphin\0"),
            (1501, "kio-worker", 1500, 5 + passo, f"0::{user}/app.slice/app-org.kde.dolphin-0123456789abcdef0123456789abcdef.scope",
             "kioworker\0"),
            (1600, "pipewire", 1, 10, f"0::{user}/session.slice/pipewire.service", "/usr/bin/pipewire\0"),
            (1700, "kwin_wayland", 1, 50 + passo, f"0::{user}/session.slice/plasma-kwin_wayland.service", "/usr/bin/kwin_wayland\0"),
            (1800, "plasmashell", 1, 30, f"0::{user}/session.slice/plasma-plasmashell.service", "/usr/bin/plasmashell\0"),
            (1900, "kdeconnectd", 1, 3, f"0::{user}/app.slice/app-org.kde.kdeconnect.daemon@autostart.service",
             "/usr/bin/kdeconnectd\0"),
            (2000, "steam", 1, 4, f"0::{user}/app.slice/run-r0123abcd.scope", "/usr/bin/steam\0-silent\0"),
            (2100, "telegram-deskto", 1, 2, f"0::{user}/app.slice/app-dbus\\x2d:1.2\\x2dorg.telegram.desktop@0.service",
             "/usr/bin/telegram-desktop\0"),
            (2200, "konsole", 1, 2, f"0::{user}/app.slice/app-org.kde.konsole-0123456789abcdef0123456789abcdef.scope",
             "/usr/bin/konsole\0"),
            (2201, "htop", 2200, 1, f"0::{user}/app.slice/app-org.kde.konsole-0123456789abcdef0123456789abcdef.scope",
             "htop\0"),
        ]
        for pid, comm, ppid, ticks, cgroup, cmd in lista:
            base = self.proc / str(pid)
            escrever(base / "stat", stat_linha(pid, comm, ppid, ticks))
            escrever(base / "statm", "5000 3000 1000 10 0 2000 0\n")
            escrever(base / "cgroup", cgroup + "\n")
            escrever(base / "cmdline", cmd)
            escrever(base / "io", f"read_bytes: {passo * 4096}\nwrite_bytes: 0\n")
        self.ticks_total += 100
        escrever(self.proc / "stat", f"cpu  {self.ticks_total // 2} 0 0 {self.ticks_total // 2} 0 0 0 0 0 0\n"
                 f"cpu0 {self.ticks_total // 4} 0 0 {self.ticks_total // 4} 0 0 0 0 0 0\n"
                 f"cpu1 {self.ticks_total // 4} 0 0 {self.ticks_total // 4} 0 0 0 0 0 0\nprocs_running 1\n")

    def env(self):
        return {"MATSU_PROC": str(self.proc), "MATSU_SYS": str(self.sys), "MATSU_PCI_IDS": str(self.raiz / "pci.ids"),
                "MATSU_UID": str(os.getuid()), "XDG_DATA_HOME": str(self.dados), "XDG_DATA_DIRS": str(self.dados),
                "MATSU_LANG": "pt_BR.UTF-8", "HOME": str(self.raiz / "casa")}


class Nomes(unittest.TestCase):
    def setUp(self):
        self.a = carregar({})

    def test_app_da_unidade(self):
        f = self.a.app_da_unidade
        self.assertEqual(f("app-org.kde.dolphin-0123456789abcdef0123456789abcdef.scope"), ("org.kde.dolphin", False))
        self.assertEqual(f("app-org.kde.plasma\\x2dsystemmonitor-0123456789abcdef0123456789abcdef.scope"),
                         ("org.kde.plasma-systemmonitor", False))
        self.assertEqual(f("app-flatpak-com.spotify.Client-4411.scope"), ("com.spotify.Client", False))
        self.assertEqual(f("app-org.kde.kdeconnect.daemon@autostart.service"), ("org.kde.kdeconnect.daemon", True))
        self.assertEqual(f("app-brave\\x2dbrowser@0123456789abcdef0123456789abcdef.service"), ("brave-browser", False))
        self.assertEqual(f("app-dbus\\x2d:1.2\\x2dorg.kde.kded6@0.service")[0], None)
        self.assertEqual(f("pipewire.service"), (None, False))

    def test_nome_do_dbus_e_programa(self):
        a = self.a
        self.assertEqual(a.nome_do_dbus("app-dbus\\x2d:1.2\\x2dorg.telegram.desktop@0.service"), "org.telegram.desktop")
        self.assertIsNone(a.nome_do_dbus("pipewire.service"))
        p = a.programa_do_exec
        self.assertEqual(p("env A=1 /usr/bin/steam %U"), "steam")
        self.assertEqual(p("/usr/bin/flatpak run --branch=stable --command=spotify com.spotify.Client @@u %U @@"), "spotify")
        self.assertEqual(p("flatpak run org.exemplo.App"), "")
        self.assertEqual(p('"/opt/Meu App/app" --x'), "app")
        self.assertEqual(p("env"), "")

    def test_classificar(self):
        a = self.a
        eu = a.MEU_UID
        u = f"/user.slice/user-{eu}.slice/user@{eu}.service"
        self.assertEqual(a.classificar(u + "/app.slice/app-org.kde.dolphin-0123456789abcdef0123456789abcdef.scope", eu)[0], "app")
        self.assertEqual(a.classificar(u + "/session.slice/plasma-plasmashell.service", eu)[0], "sistema")
        self.assertEqual(a.classificar(u + "/init.scope", eu)[0], "sistema")
        self.assertEqual(a.classificar(f"/user.slice/user-{eu}.slice/session-2.scope", eu)[0], "sistema")
        self.assertEqual(a.classificar(u + "/app.slice/app-org.kde.kdeconnect.daemon@autostart.service", eu)[0], "fundo")
        self.assertEqual(a.classificar(u + "/background.slice/plasma-baloorunner.service", eu)[0], "fundo")
        self.assertEqual(a.classificar("/system.slice/NetworkManager.service", eu + 1), ("sistema", "NetworkManager.service"))

    def test_trocar_chave(self):
        t = self.a.trocar_chave
        texto = "[Desktop Entry]\nName=X\nHidden=false\n\n[Desktop Action a]\nName=Y\n"
        novo = t(texto, "Hidden", "true")
        self.assertIn("Hidden=true", novo)
        self.assertNotIn("Hidden=false", novo)
        self.assertLess(novo.index("Hidden=true"), novo.index("[Desktop Action a]"))
        self.assertIn("Hidden=true", t("[Desktop Entry]\nName=X\n", "Hidden", "true"))
        self.assertEqual(t("[Desktop Entry]\nName=X\n[Outro]\nA=1\n", "Hidden", "true").count("Hidden=true"), 1)


class Leitura(unittest.TestCase):
    def test_amostra(self):
        with tempfile.TemporaryDirectory() as pasta:
            mundo = MundoFalso(pasta)
            a = carregar(mundo.env())
            # O idioma e as pastas dos .desktop são lidos com o app rodando.
            with mock.patch.dict(os.environ, mundo.env()):
                leitor = a.Leitor()
                leitor.amostra()
                mundo.processos(20)
                d = leitor.amostra()
            self.assertEqual(d["idioma"], "pt")
            self.assertEqual(d["cpu"]["nome"], "AMD Ryzen 5 5600")
            self.assertEqual(d["cpu"]["logicos"], 2)
            self.assertEqual(d["cpu"]["ligado"], 3725)
            self.assertAlmostEqual(d["cpu"]["ghz"], 4.0, places=2)
            # Linhas do kernel não entram (kthreadd e kworker).
            self.assertEqual(d["cpu"]["processos"], 10)
            grupos = {g["id"]: g for g in d["grupos"]}
            dolphin = grupos["app-org.kde.dolphin-0123456789abcdef0123456789abcdef.scope"]
            self.assertEqual(dolphin["tipo"], "app")
            self.assertEqual(dolphin["nome"], "Arquivos")
            self.assertEqual(dolphin["icone"], "system-file-manager")
            self.assertEqual(dolphin["n"], 2)
            self.assertEqual(dolphin["acao"], "finalizar")
            # 30 + 10 ticks a mais, de 100 do sistema inteiro: 40%.
            self.assertAlmostEqual(dolphin["cpu"], 40.0, places=1)
            self.assertEqual(dolphin["mem"], 2 * 2000 * os.sysconf("SC_PAGE_SIZE"))
            self.assertGreater(dolphin["disco"], 0)
            kwin = grupos["plasma-kwin_wayland.service"]
            self.assertEqual((kwin["tipo"], kwin["acao"], kwin["motivo"]), ("sistema", "nenhuma", "sessao"))
            self.assertEqual(kwin["nome"], "Janelas e efeitos (KWin)")
            self.assertEqual(grupos["plasma-plasmashell.service"]["acao"], "reiniciar")
            kde = grupos["app-org.kde.kdeconnect.daemon@autostart.service"]
            self.assertEqual((kde["tipo"], kde["autostart"]), ("fundo", True))
            # Aberto fora do menu: a logo e o nome vêm do .desktop do programa.
            steam = grupos["run-r0123abcd.scope"]
            self.assertEqual((steam["tipo"], steam["nome"], steam["icone"]), ("fundo", "Steam", "steam"))
            # Aberto pelo D-Bus com janela: vai para Apps, com a logo do app.
            tg = grupos["app-dbus\\x2d:1.2\\x2dorg.telegram.desktop@0.service"]
            self.assertEqual((tg["tipo"], tg["nome"], tg["icone"]), ("app", "Telegram", "org.telegram.desktop"))
            # Cada processo do terminal com a própria logo (htop) ou nenhuma (o app inteiro usa a dele).
            term = grupos["app-org.kde.konsole-0123456789abcdef0123456789abcdef.scope"]
            self.assertEqual((term["nome"], term["icone"]), ("Terminal", "utilities-terminal"))
            self.assertEqual({p["exe"]: p["icone"] for p in term["procs"]}, {"konsole": "utilities-terminal", "htop": "htop"})
            # Serviços do sistema ficam com o nome amigável, sem logo de app.
            self.assertEqual(grupos["pipewire.service"]["icone"], "")
            self.assertEqual(d["memoria"]["total"], 16000000 * 1024)
            self.assertEqual(d["memoria"]["usada"], 6000000 * 1024)
            self.assertEqual([k["nome"] for k in d["discos"]], ["nvme0n1"])
            self.assertEqual(d["discos"][0]["tipo"], "nvme")
            self.assertEqual(d["discos"][0]["modelo"], "Samsung SSD 980 1TB")
            self.assertEqual([r["nome"] for r in d["redes"]], ["wlp4s0"])
            self.assertTrue(d["redes"][0]["wifi"])
            self.assertEqual(len(d["placas"]), 1)
            placa = d["placas"][0]
            self.assertEqual(placa["nome"], "AMD Nitro+ Radeon RX 570/580/590")
            self.assertEqual((placa["uso"], placa["temp"], placa["mhz"]), (37, 48, 1340))
            self.assertEqual(placa["vram_total"], 8 << 30)
            json.dumps(d)

    def test_placa_virtual_e_sem_subsistema(self):
        with tempfile.TemporaryDirectory() as pasta:
            mundo = MundoFalso(pasta)
            a = carregar(mundo.env())
            self.assertEqual(a.nome_da_placa("1002", "67ef", "", "", "pt"), "AMD Radeon RX 460/560D")
            self.assertEqual(a.nome_da_placa("1af4", "1050", "", "", "pt"), "Placa de vídeo virtual")
            self.assertEqual(a.nome_da_placa("1af4", "1050", "", "", "en"), "Virtual graphics")


class Inicializacao(unittest.TestCase):
    def test_listar_e_ligar(self):
        with tempfile.TemporaryDirectory() as pasta:
            raiz = Path(pasta)
            sistema = raiz / "etc/autostart"
            usuario = raiz / "config/autostart"
            escrever(sistema / "org.kde.kdeconnect.daemon.desktop",
                     "[Desktop Entry]\nType=Application\nName=KDE Connect\nIcon=kdeconnect\nComment=Celular\n")
            escrever(sistema / "polkit-kde-authentication-agent-1.desktop", "[Desktop Entry]\nType=Application\nName=Polkit\n")
            escrever(sistema / "xembed.desktop", "[Desktop Entry]\nType=Application\nName=Peça\nX-KDE-autostart-phase=1\n")
            escrever(sistema / "gnome-only.desktop", "[Desktop Entry]\nType=Application\nName=G\nOnlyShowIn=GNOME;\n")
            escrever(usuario / "steam.desktop", "[Desktop Entry]\nType=Application\nName=Steam\nIcon=steam\n")
            env = {"XDG_CONFIG_DIRS": str(raiz / "etc"), "XDG_CONFIG_HOME": str(raiz / "config"), "MATSU_LANG": "pt_BR"}
            a = carregar(env)
            os.environ.update(env)
            try:
                def listar():
                    r = subprocess.run([sys.executable, str(AJUDANTE), "inicializacao"], capture_output=True, text=True,
                                       env={**os.environ, **env}, check=True)
                    return {i["arquivo"]: i for i in json.loads(r.stdout)["itens"]}

                itens = listar()
                self.assertEqual(set(itens), {"org.kde.kdeconnect.daemon.desktop", "steam.desktop"})
                self.assertEqual(itens["steam.desktop"]["origem"], "seu")
                self.assertTrue(itens["org.kde.kdeconnect.daemon.desktop"]["ligado"])

                # Desligar um do sistema: cria a cópia "desligada" na pasta da pessoa.
                self.assertEqual(a.ligar_inicio("org.kde.kdeconnect.daemon.desktop", False), 0)
                copia = usuario / "org.kde.kdeconnect.daemon.desktop"
                self.assertIn("Hidden=true", copia.read_text())
                self.assertFalse(listar()["org.kde.kdeconnect.daemon.desktop"]["ligado"])
                # Ligar de novo: a cópia some e volta a valer o do sistema.
                a.ligar_inicio("org.kde.kdeconnect.daemon.desktop", True)
                self.assertFalse(copia.exists())
                self.assertTrue(listar()["org.kde.kdeconnect.daemon.desktop"]["ligado"])
                # Um da pessoa: troca o Hidden no próprio arquivo.
                a.ligar_inicio("steam.desktop", False)
                self.assertIn("Hidden=true", (usuario / "steam.desktop").read_text())
                a.ligar_inicio("steam.desktop", True)
                self.assertIn("Hidden=false", (usuario / "steam.desktop").read_text())
                # Nomes estranhos são recusados.
                self.assertEqual(a.ligar_inicio("../../etc/passwd", False), 1)
                self.assertEqual(a.ligar_inicio("nao-existe.desktop", False), 1)
            finally:
                for k in env:
                    os.environ.pop(k, None)


class Encerrar(unittest.TestCase):
    def test_encerra_processo_da_pessoa(self):
        a = carregar({})
        filho = subprocess.Popen(["sleep", "30"])
        try:
            a.encerrar([str(filho.pid)], espera=2)
            self.assertIsNotNone(filho.wait(timeout=5))
        finally:
            if filho.poll() is None:
                filho.kill()

    def test_encerra_na_hora_quem_ignora(self):
        a = carregar({})
        teimoso = subprocess.Popen([sys.executable, "-c", "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); print('ok', flush=True); time.sleep(30)"],
                                   stdout=subprocess.PIPE)
        teimoso.stdout.readline()
        try:
            inicio = time.monotonic()
            a.encerrar([str(teimoso.pid)], espera=1)
            self.assertEqual(teimoso.wait(timeout=5), -9)
            self.assertLess(time.monotonic() - inicio, 4)
        finally:
            if teimoso.poll() is None:
                teimoso.kill()

    def test_nao_encerra_peca_da_sessao(self):
        with tempfile.TemporaryDirectory() as pasta:
            mundo = MundoFalso(pasta)
            a = carregar(mundo.env())
            self.assertFalse(a.pode_encerrar(1700))   # kwin_wayland
            self.assertFalse(a.pode_encerrar(1800))   # plasmashell (esse reinicia, não fecha)
            self.assertTrue(a.pode_encerrar(1500))    # Arquivos
            self.assertFalse(a.pode_encerrar(1))


class DeVerdade(unittest.TestCase):
    def test_amostra_do_computador(self):
        r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), "amostra"], capture_output=True, text=True, timeout=30)
        self.assertEqual(r.returncode, 0, r.stderr)
        d = json.loads(r.stdout)
        for chave in ("cpu", "memoria", "discos", "redes", "placas", "grupos"):
            self.assertIn(chave, d)
        self.assertGreater(d["memoria"]["total"], 0)
        self.assertGreater(d["cpu"]["processos"], 0)
        self.assertTrue(any(p["pid"] for g in d["grupos"] for p in g["procs"]))

    def test_vigiar_manda_linhas(self):
        p = subprocess.Popen([sys.executable, "-I", "-S", str(AJUDANTE), "vigiar", "0.3"], stdout=subprocess.PIPE, text=True)
        try:
            linhas = [json.loads(p.stdout.readline()) for _ in range(2)]
            self.assertTrue(all("grupos" in l for l in linhas))
        finally:
            p.terminate()
            p.wait(timeout=5)


if __name__ == "__main__":
    unittest.main(verbosity=2)
