#!/usr/bin/env python3
"""Testes do ajudante das telas (system_files/usr/share/matsu/monitores/ajudante.py).

Um kscreen-doctor de mentira (um script num PATH de mentira) devolve o JSON
gravado, anota os comandos que recebe e aplica as mudanças no JSON, como o de
verdade. Um /sys/class/drm de mentira tem o EDID dos monitores. As telas: o
JSON de verdade do KWin aninhado (o Plasma de teste), o PC do Kaiky (RX 580 com
um AOC 1080p 144 Hz com FreeSync e um LG 1440p 60 Hz), um notebook e um
notebook ligado numa TV 4K.

Uso: python3 tests/test_monitores.py
"""
import copy
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.dont_write_bytecode = True  # nada de __pycache__ dentro de system_files

RAIZ = Path(__file__).resolve().parents[1]
AJUDANTE = RAIZ / "system_files/usr/share/matsu/monitores/ajudante.py"

_carregador = importlib.machinery.SourceFileLoader("monitores_ajudante", str(AJUDANTE))
_spec = importlib.util.spec_from_loader("monitores_ajudante", _carregador)
T = importlib.util.module_from_spec(_spec)
_carregador.exec_module(T)


# ------------------------------------------------------------ as telas

# "kscreen-doctor -j" de verdade, do KWin aninhado do Plasma 6.6 de teste
# (duas telas virtuais, sem EDID, sem modo preferido).
REAL_ANINHADO = json.loads("""{"features":255,"outputs":[{"clones":[],"connected":true,"currentModeId":"1",
"enabled":true,"followPreferredMode":false,"icon":"","id":1,"modes":[{"id":"1","name":"1920x1080@60",
"refreshRate":60,"size":{"height":1080,"width":1920}}],"name":"X11-0","pos":{"x":0,"y":0},
"preferredModes":[],"priority":1,"replicationSource":0,"rotation":1,"scale":1,"size":{"height":1080,
"width":1920},"sizeMM":{"height":-1,"width":-1},"type":0},{"clones":[],"connected":true,
"currentModeId":"2","enabled":true,"followPreferredMode":false,"icon":"","id":2,"modes":[{"id":"2",
"name":"1920x1080@60","refreshRate":60,"size":{"height":1080,"width":1920}}],"name":"X11-1",
"pos":{"x":1920,"y":0},"preferredModes":[],"priority":2,"replicationSource":0,"rotation":1,"scale":1,
"size":{"height":1080,"width":1920},"sizeMM":{"height":-1,"width":-1},"type":0}],
"screen":{"currentSize":{"height":1080,"width":3840},"id":0,"maxActiveOutputsCount":2,
"maxSize":{"height":64000,"width":64000},"minSize":{"height":0,"width":0}},
"tabletModeAvailable":false,"tabletModeEngaged":false}""")


def modo(ident, largura, altura, taxa):
    return {"id": str(ident), "name": "%dx%d@%g" % (largura, altura, taxa), "refreshRate": taxa,
            "size": {"width": largura, "height": altura}}


def saida(ident, nome, modos, atual, x=0, y=0, prioridade=1, escala=1.0, ligada=True, conectada=True,
          tipo=0, mm=(-1, -1), preferidos=(), rotacao=1, vrr=None, hdr=None):
    o = {"clones": [], "connected": conectada, "currentModeId": str(atual), "enabled": ligada,
         "followPreferredMode": False, "icon": "", "id": ident, "modes": modos, "name": nome,
         "pos": {"x": x, "y": y}, "preferredModes": [str(p) for p in preferidos], "priority": prioridade,
         "replicationSource": 0, "rotation": rotacao, "scale": escala,
         "sizeMM": {"width": mm[0], "height": mm[1]}, "type": tipo}
    # Só o kscreen-doctor de mentira usa (aparece no "-o", como no de verdade).
    o["_vrr"] = vrr
    o["_hdr"] = hdr
    return o


def pc_do_kaiky(recursos=255):
    """RX 580 com duas telas: AOC 24" 1080p 144 Hz (FreeSync) e LG 27" 1440p 60 Hz."""
    aoc = [modo(1, 1920, 1080, 144.001), modo(2, 1920, 1080, 119.982), modo(3, 1920, 1080, 99.93),
           modo(4, 1920, 1080, 60.0), modo(5, 1920, 1080, 59.94), modo(6, 1920, 1080, 50.0),
           modo(7, 1680, 1050, 59.954), modo(8, 1280, 720, 60.0), modo(9, 1280, 720, 59.94)]
    lg = [modo(20, 2560, 1440, 59.951), modo(21, 1920, 1080, 60.0), modo(22, 1920, 1080, 59.94),
          modo(23, 1920, 1080, 50.0), modo(24, 1280, 720, 60.0)]
    return {"features": recursos, "outputs": [
        saida(70, "HDMI-A-1", aoc, 1, 0, 0, 1, tipo=6, mm=(527, 296), preferidos=[1], vrr="Automatic"),
        saida(71, "DP-1", lg, 20, 1920, 0, 2, tipo=14, mm=(597, 336), preferidos=[20], vrr=None),
        saida(72, "DP-2", [], 0, 0, 0, 0, ligada=False, conectada=False, tipo=14),
    ]}


def notebook():
    painel = [modo(1, 1920, 1080, 165.0), modo(2, 1920, 1080, 60.0), modo(3, 1600, 900, 60.0),
              modo(4, 1366, 768, 60.0)]
    return {"features": 255, "outputs": [
        saida(1, "eDP-1", painel, 1, 0, 0, 1, escala=1.25, tipo=7, mm=(345, 194), preferidos=[1]),
        saida(2, "HDMI-A-1", [], 0, ligada=False, conectada=False, tipo=6),
    ]}


def notebook_com_tv():
    nb = notebook()
    tv = [modo(10, 3840, 2160, 60.0), modo(11, 3840, 2160, 30.0), modo(12, 1920, 1080, 60.0),
          modo(13, 1280, 720, 60.0)]
    nb["outputs"][1] = saida(2, "HDMI-A-1", tv, 10, 1536, 0, 2, escala=2.0, tipo=6, mm=(1210, 680),
                             preferidos=[10], hdr=False)
    return nb


def edid(pnp, modelo, cm):
    """Um EDID de 128 bytes com o fabricante, o nome (descritor 0xFC) e o tamanho."""
    b = bytearray(128)
    b[0:8] = b"\x00\xff\xff\xff\xff\xff\xff\x00"
    codigo = ((ord(pnp[0]) - 64) << 10) | ((ord(pnp[1]) - 64) << 5) | (ord(pnp[2]) - 64)
    b[8], b[9] = codigo >> 8, codigo & 0xFF
    b[21], b[22] = cm
    b[54], b[55] = 0x02, 0x3A  # o primeiro descritor é um modo, não texto
    b[72:77] = bytes([0, 0, 0, 0xFC, 0])
    texto = modelo.encode("ascii")[:13]
    texto = (texto + b"\x0a" + b"\x20" * 13)[:13]
    b[77:90] = texto
    b[127] = (-sum(b[:127])) % 256
    return bytes(b)


# O kscreen-doctor de mentira: devolve o JSON, anota cada chamada e aplica
# as mudanças no JSON (como o de verdade faz no KWin).
FALSO_KSCREEN = r'''
import json, os, sys
caminho = os.environ["FALSO_JSON"]
args = sys.argv[1:]
with open(os.environ["FALSO_LOG"], "a") as f:
    f.write(" ".join(args) + "\n")
if os.environ.get("FALSO_QUEBRADO"):
    print("isto não é json")
    sys.exit(0)
d = json.load(open(caminho))
V, A, F = "\x1b[01;32m", "\x1b[01;33m", "\x1b[0;0m"
if args == ["-j"]:
    limpo = json.loads(json.dumps(d))
    for o in limpo["outputs"]:
        for k in [k for k in o if k.startswith("_")]:
            del o[k]
    print(json.dumps(limpo, indent=4))
    sys.exit(0)
if args == ["-o"]:
    for o in d["outputs"]:
        print(V + "Output: " + F + "%d %s 1234-uuid" % (o["id"], o["name"]))
        print("\t" + V + ("enabled" if o["enabled"] else "disabled") + F)
        print("\t" + V + ("connected" if o["connected"] else "disconnected") + F)
        print("\t" + V + "priority %d" % o["priority"] + F)
        print(A + "\tScale: " + F + str(o["scale"]))
        print(A + "\tVrr: " + F + (o.get("_vrr") or "incapable"))
        hdr = o.get("_hdr")
        print(A + "\tHDR: " + F + ("incapable" if hdr is None else ("enabled" if hdr else "disabled")))
        print(A + "\tWide Color Gamut: " + F + "incapable")
    sys.exit(0)
uma_vez = os.environ.get("FALSO_RECUSA_UMA")
if os.environ.get("FALSO_RECUSA") or (uma_vez and os.path.exists(uma_vez)):
    if uma_vez and os.path.exists(uma_vez):
        os.unlink(uma_vez)
    print("applying config failed! ", file=sys.stderr)
    sys.exit(0)
por_nome = {o["name"]: o for o in d["outputs"]}
for a in args:
    p = a.split(".")
    o = por_nome.get(p[1]) if p[0] == "output" and len(p) > 2 else None
    if o is None:
        print("Output with name or uuid %s not found." % (p[1] if len(p) > 1 else a), file=sys.stderr)
        sys.exit(0)
    cmd, valor = p[2], ".".join(p[3:])
    if cmd == "enable":
        o["enabled"] = True
    elif cmd == "disable":
        o["enabled"] = False
    elif cmd == "mode":
        assert any(m["id"] == valor for m in o["modes"]), a
        o["currentModeId"] = valor
    elif cmd == "scale":
        o["scale"] = float(valor)
    elif cmd == "rotation":
        o["rotation"] = {"none": 1, "normal": 1, "left": 2, "inverted": 4, "right": 8}[valor]
    elif cmd == "position":
        x, y = valor.split(",")
        o["pos"] = {"x": int(x), "y": int(y)}
    elif cmd == "priority":
        o["priority"] = int(valor)
    elif cmd == "vrrpolicy":
        o["_vrr"] = {"never": "Never", "automatic": "Automatic", "always": "Always"}[valor]
    elif cmd == "hdr":
        o["_hdr"] = valor == "enable"
    elif cmd == "mirror":
        if not os.environ.get("FALSO_SEM_ESPELHO"):
            o["replicationSource"] = 0 if valor == "none" else por_nome[valor]["id"]
    else:
        print("Unable to parse arguments: " + a, file=sys.stderr)
        sys.exit(9)
json.dump(d, open(caminho, "w"))
'''

FALSO_BUSCTL = r'''
import os, sys
with open(os.environ["FALSO_LOG"], "a") as f:
    f.write("busctl " + " ".join(sys.argv[1:]) + "\n")
sys.exit(int(os.environ.get("FALSO_BUSCTL_RC", "0")))
'''


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        pasta_bin = self.dir / "bin"
        pasta_bin.mkdir()
        for nome, corpo in (("kscreen-doctor", FALSO_KSCREEN), ("busctl", FALSO_BUSCTL)):
            arquivo = pasta_bin / nome
            arquivo.write_text("#!" + sys.executable + "\n" + corpo, encoding="utf-8")
            arquivo.chmod(0o755)
        self.json = self.dir / "kscreen.json"
        self.log = self.dir / "chamadas.log"
        self.log.write_text("")
        self.drm = self.dir / "drm"
        self.drm.mkdir()
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("MATSU_", "FALSO_", "LC_", "LANG"))}
        self.env.update({
            "PATH": str(pasta_bin) + os.pathsep + os.environ.get("PATH", "/usr/bin:/bin"),
            "FALSO_JSON": str(self.json), "FALSO_LOG": str(self.log),
            "MATSU_SYS_DRM": str(self.drm), "MATSU_TELAS_DIR": str(self.dir / "estado"),
            "MATSU_LANG": "pt_BR", "HOME": str(self.dir), "XDG_CONFIG_HOME": str(self.dir / "config"),
        })

    def tearDown(self):
        # Uma volta solta que sobrou vê a pasta sumir e sai sozinha.
        self.tmp.cleanup()

    def telas(self, cfg):
        self.json.write_text(json.dumps(cfg), encoding="utf-8")

    def config(self):
        return json.loads(self.json.read_text(encoding="utf-8"))

    def monitor(self, conector, pnp, modelo, cm, placa=1):
        pasta = self.drm / ("card%d-%s" % (placa, conector))
        pasta.mkdir(parents=True, exist_ok=True)
        (pasta / "edid").write_bytes(edid(pnp, modelo, cm))
        (pasta / "status").write_text("connected\n")

    def rodar(self, *args, **extra):
        env = dict(self.env)
        env.update({k: str(v) for k, v in extra.items()})
        self.log.write_text("")
        r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE)] + list(args), env=env,
                           capture_output=True, text=True, timeout=30)
        return r.returncode, r.stdout, r.stderr

    def estado(self, **extra):
        codigo, saida, erros = self.rodar("estado", **extra)
        self.assertEqual(codigo, 0, erros)
        self.assertEqual(len(saida.strip().splitlines()), 1, "uma linha só de JSON")
        return json.loads(saida)

    def chamadas(self):
        """As mudanças mandadas ao kscreen-doctor (sem as leituras -j e -o)."""
        linhas = self.log.read_text().splitlines()
        return [l for l in linhas if l not in ("-j", "-o") and not l.startswith("busctl")]

    def saida(self, nome):
        for o in self.config()["outputs"]:
            if o["name"] == nome:
                return o
        raise KeyError(nome)

    def tela(self, est, nome):
        for t in est["telas"]:
            if t["nome"] == nome:
                return t
        raise KeyError(nome)

    def esperar(self, condicao, prazo=6.0):
        fim = time.time() + prazo
        while time.time() < fim:
            if condicao():
                return True
            time.sleep(0.1)
        return condicao()


# ---------------------------------------------------------------- estado

class TestEstado(Base):
    def test_real_do_kwin_aninhado(self):
        self.telas(REAL_ANINHADO)
        est = self.estado()
        self.assertTrue(est["ok"])
        self.assertEqual(est["modo"], "estender")
        self.assertTrue(est["espelho"], "features 255 tem o espelho do KWin")
        self.assertEqual(est["confirmar"], 0)
        self.assertEqual([t["nome"] for t in est["telas"]], ["X11-0", "X11-1"])
        a, b = est["telas"]
        self.assertEqual((a["rotulo"], b["rotulo"]), ("Tela 1", "Tela 2"), "sem EDID e sem tipo: numeradas")
        self.assertTrue(a["principal"])
        self.assertFalse(b["principal"])
        self.assertEqual((b["x"], b["y"], b["largura"], b["altura"]), (1920, 0, 1920, 1080))
        self.assertEqual(a["modo"], {"largura": 1920, "altura": 1080, "hz": 60})
        self.assertEqual(a["resolucoes"], [{"largura": 1920, "altura": 1080, "nome": "Full HD (1080p)",
                                            "taxas": [60], "preferida": True, "taxa_preferida": 60}])
        self.assertEqual(a["escalas"], [1.0, 1.25, 1.5])
        self.assertFalse(a["vrr_tem"] or a["hdr_tem"] or a["interna"])

    def test_pc_com_duas_telas(self):
        self.telas(pc_do_kaiky())
        self.monitor("HDMI-A-1", "AOC", "24G2W1G4", (53, 30))
        self.monitor("DP-1", "GSM", "27QN600", (60, 34))
        est = self.estado()
        self.assertEqual(len(est["telas"]), 2, "a DP-2 sem cabo não aparece")
        aoc, lg = self.tela(est, "HDMI-A-1"), self.tela(est, "DP-1")
        self.assertEqual(aoc["rotulo"], "AOC 24G2W1G4")
        self.assertEqual(lg["rotulo"], "LG 27QN600")
        self.assertEqual((aoc["polegadas"], lg["polegadas"]), (24, 27))
        self.assertEqual((aoc["conexao"], lg["conexao"]), ("HDMI", "DisplayPort"))
        self.assertEqual((aoc["numero"], lg["numero"]), (1, 2))
        self.assertTrue(aoc["principal"])
        self.assertEqual(aoc["modo"]["hz"], 144)
        fullhd = aoc["resolucoes"][0]
        self.assertEqual((fullhd["largura"], fullhd["altura"]), (1920, 1080))
        self.assertEqual(fullhd["taxas"], [144, 120, 100, 60, 50], "59,94 e 60 viram um 60 só")
        self.assertTrue(fullhd["preferida"])
        self.assertEqual(fullhd["taxa_preferida"], 144)
        self.assertEqual([(r["largura"], r["altura"]) for r in aoc["resolucoes"]],
                         [(1920, 1080), (1680, 1050), (1280, 720)])
        self.assertEqual(lg["resolucoes"][0]["nome"], "2K (QHD)")
        self.assertEqual(lg["resolucoes"][0]["taxas"], [60])
        self.assertFalse(lg["resolucoes"][1]["preferida"])
        self.assertTrue(aoc["vrr_tem"] and aoc["vrr"], "FreeSync no AOC")
        self.assertFalse(lg["vrr_tem"])
        self.assertFalse(aoc["hdr_tem"])
        self.assertEqual(aoc["escalas"], [1.0, 1.25, 1.5])
        self.assertEqual(lg["escalas"], [1.0, 1.25, 1.5, 1.75])
        self.assertEqual(est["modo"], "estender")

    def test_notebook(self):
        self.telas(notebook())
        est = self.estado()
        self.assertEqual(len(est["telas"]), 1)
        nb = est["telas"][0]
        self.assertEqual(nb["rotulo"], "Tela do notebook")
        self.assertTrue(nb["interna"] and nb["principal"])
        self.assertEqual((nb["largura"], nb["altura"]), (1536, 864), "1920x1080 a 125%")
        self.assertEqual(nb["polegadas"], 15.6)
        self.assertEqual(nb["modo"]["hz"], 165)
        self.assertEqual(est["modo"], "uma")
        self.assertEqual(self.estado(MATSU_LANG="en_US")["telas"][0]["rotulo"], "Built-in display")

    def test_notebook_com_tv_4k(self):
        self.telas(notebook_com_tv())
        self.monitor("HDMI-A-1", "SAM", "SAMSUNG", (121, 68))
        est = self.estado()
        tv = self.tela(est, "HDMI-A-1")
        self.assertEqual(tv["rotulo"], "Samsung")
        self.assertEqual(tv["polegadas"], 55, "TV de 54,6\" é a de 55\"")
        self.assertEqual(tv["resolucoes"][0]["nome"], "4K")
        self.assertEqual(tv["resolucoes"][0]["taxas"], [60, 30])
        self.assertEqual((tv["largura"], tv["altura"]), (1920, 1080), "4K a 200%")
        self.assertEqual(tv["escalas"], [1.0, 1.25, 1.5, 1.75, 2.0], "TV grande: também 100% e 125%")
        self.assertTrue(tv["hdr_tem"])
        self.assertFalse(tv["hdr"])

    def test_rotulos_sem_edid_e_monitores_iguais(self):
        cfg = pc_do_kaiky()
        cfg["outputs"][1]["name"] = "HDMI-A-2"
        self.telas(cfg)
        est = self.estado()
        self.assertEqual([t["rotulo"] for t in est["telas"]], ["Tela HDMI (1)", "Tela HDMI (2)"])
        self.monitor("HDMI-A-1", "DEL", "DELL P2419H", (53, 30))
        self.monitor("HDMI-A-2", "DEL", "DELL P2419H", (53, 30))
        est = self.estado()
        self.assertEqual([t["rotulo"] for t in est["telas"]], ["Dell P2419H (1)", "Dell P2419H (2)"])

    def test_girada(self):
        cfg = pc_do_kaiky()
        cfg["outputs"][1]["rotation"] = 2
        self.telas(cfg)
        lg = self.tela(self.estado(), "DP-1")
        self.assertEqual(lg["rotacao"], "esquerda")
        self.assertEqual((lg["largura"], lg["altura"]), (1440, 2560))
        self.assertEqual(lg["escalas"], [1.0, 1.25, 1.5, 1.75], "girada não muda as escalas")

    def test_duplicadas_e_uma_so(self):
        cfg = pc_do_kaiky()
        cfg["outputs"][1]["replicationSource"] = 70
        self.telas(cfg)
        est = self.estado()
        self.assertEqual(est["modo"], "duplicar")
        self.assertEqual(self.tela(est, "DP-1")["espelho_de"], "HDMI-A-1")
        cfg = pc_do_kaiky()
        cfg["outputs"][0]["enabled"] = False
        self.telas(cfg)
        est = self.estado()
        self.assertEqual(est["modo"], "uma")
        self.assertTrue(self.tela(est, "DP-1")["principal"], "a única ligada é a principal")

    def test_sem_kscreen_doctor(self):
        self.telas(pc_do_kaiky())
        est = self.estado(MATSU_KSCREEN_DOCTOR=str(self.dir / "nao-existe"))
        self.assertFalse(est["ok"])
        self.assertEqual(est["erro"], "sem-kscreen-doctor")
        self.assertEqual(est["telas"], [])

    def test_kscreen_doctor_quebrado(self):
        self.telas(pc_do_kaiky())
        est = self.estado(FALSO_QUEBRADO=1)
        self.assertFalse(est["ok"])
        self.assertEqual(est["erro"], "kscreen-doctor-falhou")


class TestPartes(unittest.TestCase):
    def test_edid(self):
        info = T.ler_edid(edid("AOC", "24G2W1G4", (53, 30)))
        self.assertEqual(info, {"pnp": "AOC", "fabricante": "AOC", "modelo": "24G2W1G4", "polegadas": 24})
        self.assertEqual(T.ler_edid(edid("GSM", "LG ULTRAGEAR", (60, 34)))["fabricante"], "LG")
        self.assertEqual(T.ler_edid(b"lixo" * 40), {})
        self.assertEqual(T.ler_edid(b""), {})

    def test_rotulos(self):
        self.assertEqual(T.nome_do_modelo("Dell", "DELL P2419H"), "Dell P2419H")
        self.assertEqual(T.nome_do_modelo("Samsung", "SAMSUNG"), "Samsung")
        self.assertEqual(T.nome_do_modelo("LG", "LG ULTRAGEAR"), "LG ULTRAGEAR")
        self.assertEqual(T.nome_do_modelo("ASUS", "VG248"), "ASUS VG248")
        self.assertEqual(T.rotulo_de("HDMI", {}, True), "Tela HDMI")
        self.assertEqual(T.rotulo_de("DisplayPort", {}, True), "Tela DisplayPort")
        self.assertEqual(T.rotulo_de("DisplayPort", {}, False), "DisplayPort display")
        self.assertEqual(T.rotulo_de("interna", {"modelo": "LP156WF9"}, True), "Tela do notebook")
        self.assertEqual(T.rotulo_de("HDMI", {"fabricante": "Philips", "modelo": "", "polegadas": 22}, True),
                         "Philips 22″")
        self.assertEqual(T.conexao_de("eDP-1"), "interna")
        self.assertEqual(T.conexao_de("LVDS-1"), "interna")
        self.assertEqual(T.conexao_de("DP-3"), "DisplayPort")
        self.assertEqual(T.conexao_de("DVI-D-1"), "DVI")
        self.assertEqual(T.conexao_de("X11-0"), "")

    def test_nomes_de_resolucao(self):
        self.assertEqual(T.nome_resolucao(3840, 2160), "4K")
        self.assertEqual(T.nome_resolucao(2560, 1440), "2K (QHD)")
        self.assertEqual(T.nome_resolucao(1920, 1080), "Full HD (1080p)")
        self.assertEqual(T.nome_resolucao(1080, 1920), "Full HD (1080p)")
        self.assertEqual(T.nome_resolucao(1366, 768), "HD")
        self.assertEqual(T.nome_resolucao(3440, 1440), "Ultrawide")
        self.assertEqual(T.nome_resolucao(1234, 567), "")

    def test_escalas_sugeridas(self):
        self.assertEqual(T.escalas_sugeridas(1920, 1080, 1.0), [1.0, 1.25, 1.5])
        self.assertEqual(T.escalas_sugeridas(2560, 1440, 1.0), [1.0, 1.25, 1.5, 1.75])
        self.assertEqual(T.escalas_sugeridas(3840, 2160, 2.0), [1.5, 1.75, 2.0, 2.25, 2.5])
        self.assertEqual(T.escalas_sugeridas(3840, 2160, 1.0), [1.0, 1.5, 1.75, 2.0, 2.25, 2.5], "a de agora sempre")
        self.assertEqual(T.escalas_sugeridas(1920, 1080, 1.1), [1.0, 1.1, 1.25, 1.5])
        self.assertEqual(T.escalas_sugeridas(1366, 768, 1.0), [1.0])
        self.assertEqual(T.escalas_sugeridas(1080, 1920, 1.0), [1.0, 1.25, 1.5])

    def test_logico(self):
        self.assertEqual(T.logico(1920, 1080, 1.25, 1), (1536, 864))
        self.assertEqual(T.logico(2560, 1440, 1.0, 8), (1440, 2560))
        self.assertEqual(T.logico(3840, 2160, 1.5, 4), (2560, 1440))

    def test_normalizar_e_rearrumar(self):
        self.assertEqual(T.normalizar({"a": (-1920, 100), "b": (0, 0)}), {"a": (0, 100), "b": (1920, 0)})
        # Lado a lado: a da esquerda diminui, a da direita vem junto.
        antes = {"a": (0, 0, 1920, 1080), "b": (1920, 0, 2560, 1440)}
        self.assertEqual(T.rearrumar(antes, {"a": (1280, 720), "b": (2560, 1440)}), {"a": (0, 0), "b": (1280, 0)})
        # Uma em cima da outra.
        antes = {"a": (0, 0, 1920, 1080), "b": (0, 1080, 1920, 1080)}
        self.assertEqual(T.rearrumar(antes, {"a": (1536, 864), "b": (1920, 1080)}), {"a": (0, 0), "b": (0, 864)})
        # Três em fila: a do meio cresce.
        antes = {"a": (0, 0, 1000, 500), "b": (1000, 0, 1000, 500), "c": (2000, 0, 1000, 500)}
        self.assertEqual(T.rearrumar(antes, {"a": (1000, 500), "b": (1500, 500), "c": (1000, 500)}),
                         {"a": (0, 0), "b": (1000, 0), "c": (2500, 0)})

    def test_extras_do_o(self):
        texto = ("\x1b[01;32mOutput: \x1b[0;0m70 HDMI-A-1 uuid\n\x1b[01;33m\tVrr: \x1b[0;0mAutomatic\n"
                 "\x1b[01;33m\tHDR: \x1b[0;0mincapable\n\x1b[01;32mOutput: \x1b[0;0m71 DP-1 uuid\n"
                 "\x1b[01;33m\tVrr: \x1b[0;0mincapable\n\x1b[01;33m\tHDR: \x1b[0;0menabled\n")
        extras = T.ler_extras(texto)
        self.assertEqual(extras["HDMI-A-1"], {"id": 70, "vrr": "automatic", "hdr": "incapable"})
        self.assertEqual(T.hdr_de({"_extras": extras["DP-1"]}), (True, True))
        self.assertEqual(T.vrr_de({"_extras": extras["DP-1"]}), (False, False))
        self.assertEqual(T.vrr_de({"_extras": extras["HDMI-A-1"]}), (True, True))

    def test_escolha_do_modo(self):
        o = pc_do_kaiky()["outputs"][0]
        self.assertEqual(T.achar_modo(o, 1920, 1080, 60), "4", "60,00 ganha de 59,94")
        self.assertEqual(T.achar_modo(o, 1920, 1080, 144), "1")
        self.assertEqual(T.achar_modo(o, 1920, 1080), "1", "sem taxa: a do monitor")
        self.assertEqual(T.achar_modo(o, 1280, 720), "8", "sem preferida: a maior taxa")
        self.assertIsNone(T.achar_modo(o, 3840, 2160))


# ---------------------------------------------------------------- ações

class TestAcoes(Base):
    def setUp(self):
        super().setUp()
        self.telas(pc_do_kaiky())

    def test_resolucao_mantem_vizinha_encostada(self):
        codigo, _, erros = self.rodar("resolucao", "HDMI-A-1", "1280x720")
        self.assertEqual(codigo, 0, erros)
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.mode.8 output.DP-1.position.1280,0"])
        est = self.estado()
        self.assertEqual(self.tela(est, "HDMI-A-1")["modo"], {"largura": 1280, "altura": 720, "hz": 60})
        self.assertEqual(self.tela(est, "DP-1")["x"], 1280)
        self.assertGreater(est["confirmar"], 10, "pede confirmação")
        self.assertLessEqual(est["confirmar"], 15)
        self.rodar("manter")

    def test_taxa(self):
        self.rodar("resolucao", "HDMI-A-1", "1920x1080", "60")
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.mode.4"])
        self.rodar("resolucao", "HDMI-A-1", "1920×1080", "120")
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.mode.2"])
        self.rodar("manter")

    def test_resolucao_mantem_a_taxa_quando_da(self):
        self.rodar("resolucao", "DP-1", "1920x1080")
        self.assertEqual(self.chamadas(), ["output.DP-1.mode.21"], "60 Hz de antes, 60,00 e não 59,94")
        self.rodar("manter")

    def test_resolucao_ajusta_escala_grande_demais(self):
        self.telas(notebook_com_tv())
        self.rodar("resolucao", "HDMI-A-1", "1920x1080")
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.mode.12 output.HDMI-A-1.scale.1.5"],
                         "4K a 200% vira 1080p a 150%, não 1080p a 200%")
        self.rodar("manter")

    def test_taxa_nao_mexe_na_escala_da_pessoa(self):
        cfg = pc_do_kaiky()
        cfg["outputs"][0]["scale"] = 1.1
        self.telas(cfg)
        self.rodar("resolucao", "HDMI-A-1", "1920x1080", "60")
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.mode.4"])
        self.rodar("manter")

    def test_resolucao_errada(self):
        self.assertEqual(self.rodar("resolucao", "HDMI-A-1", "3840x2160")[0], 1)
        self.assertEqual(self.rodar("resolucao", "HDMI-A-1", "grande")[0], 2)
        self.assertEqual(self.rodar("resolucao", "HDMI-9", "1920x1080")[0], 1)
        self.assertEqual(self.rodar("resolucao", "HDMI;rm", "1920x1080")[0], 2)
        self.assertEqual(self.chamadas(), [])
        self.assertFalse((self.dir / "estado" / "telas-volta.json").exists())

    def test_escala(self):
        self.rodar("escala", "DP-1", "1.25")
        self.assertEqual(self.chamadas(), ["output.DP-1.scale.1.25"], "a da direita não empurra ninguém")
        self.rodar("escala", "HDMI-A-1", "125%")
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.scale.1.25 output.DP-1.position.1536,0"])
        self.assertEqual(self.rodar("escala", "HDMI-A-1", "9")[0], 2)
        self.rodar("manter")

    def test_girar(self):
        self.rodar("girar", "DP-1", "esquerda")
        self.assertEqual(self.chamadas(), ["output.DP-1.rotation.left"])
        lg = self.tela(self.estado(), "DP-1")
        self.assertEqual((lg["largura"], lg["altura"], lg["rotacao"]), (1440, 2560, "esquerda"))
        self.rodar("girar", "HDMI-A-1", "direita")
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.rotation.right output.DP-1.position.1080,0"])
        self.rodar("girar", "HDMI-A-1", "invertida")
        self.assertIn("output.HDMI-A-1.rotation.inverted", self.chamadas()[0])
        self.rodar("girar", "HDMI-A-1", "normal")
        self.assertIn("output.HDMI-A-1.rotation.none", self.chamadas()[0])
        self.assertEqual(self.rodar("girar", "HDMI-A-1", "torta")[0], 2)
        self.rodar("manter")

    def test_duplicar_com_espelho(self):
        self.rodar("modo", "duplicar")
        self.assertEqual(self.chamadas()[0], "output.HDMI-A-1.enable output.DP-1.enable output.DP-1.mirror.HDMI-A-1")
        self.assertEqual(len(self.chamadas()), 1)
        est = self.estado()
        self.assertEqual(est["modo"], "duplicar")
        self.assertEqual(self.tela(est, "DP-1")["espelho_de"], "HDMI-A-1")
        self.assertGreater(est["confirmar"], 0)
        # E volta a estender: sem espelho, lado a lado.
        self.rodar("modo", "estender")
        cmd = self.chamadas()[0]
        self.assertIn("output.DP-1.mirror.none", cmd)
        self.assertIn("output.HDMI-A-1.position.0,0", cmd)
        self.assertIn("output.DP-1.position.1920,0", cmd)
        self.assertEqual(self.estado()["modo"], "estender")
        self.rodar("manter")

    def test_duplicar_sem_espelho(self):
        self.telas(pc_do_kaiky(recursos=255 & ~8))
        self.rodar("modo", "duplicar")
        self.assertEqual(self.chamadas(), [
            "output.HDMI-A-1.enable output.HDMI-A-1.mode.1 output.HDMI-A-1.scale.1 output.HDMI-A-1.rotation.none "
            "output.HDMI-A-1.position.0,0 output.DP-1.enable output.DP-1.mode.21 output.DP-1.scale.1 "
            "output.DP-1.rotation.none output.DP-1.position.0,0"])
        est = self.estado()
        self.assertEqual(est["modo"], "duplicar")
        self.assertEqual(self.tela(est, "DP-1")["modo"]["largura"], 1920, "a mesma resolução nas duas")
        # Estender volta o LG para 1440p (a que ele tinha antes de duplicar).
        self.rodar("modo", "estender")
        cmd = self.chamadas()[0]
        self.assertIn("output.DP-1.mode.20", cmd)
        self.assertIn("output.DP-1.position.1920,0", cmd)
        est = self.estado()
        self.assertEqual(est["modo"], "estender")
        self.assertEqual(self.tela(est, "DP-1")["modo"]["largura"], 2560)
        self.rodar("manter")

    def test_duplicar_quando_o_kwin_nao_espelha(self):
        self.rodar("modo", "duplicar", FALSO_SEM_ESPELHO=1)
        cmds = self.chamadas()
        self.assertEqual(len(cmds), 2, "tenta o espelho e depois vai pelo jeito simples")
        self.assertIn("mirror", cmds[0])
        self.assertIn("output.DP-1.position.0,0", cmds[1])
        self.assertEqual(self.estado()["modo"], "duplicar")
        self.rodar("manter")

    def test_so_uma_tela_e_estender_de_novo(self):
        self.rodar("modo", "so", "DP-1")
        self.assertEqual(self.chamadas(), ["output.DP-1.enable output.DP-1.priority.1 output.DP-1.position.0,0 "
                                           "output.HDMI-A-1.disable"])
        est = self.estado()
        self.assertEqual(est["modo"], "uma")
        self.assertTrue(self.tela(est, "DP-1")["principal"])
        self.assertFalse(self.tela(est, "HDMI-A-1")["ligada"])
        self.rodar("modo", "estender")
        cmd = self.chamadas()[0]
        self.assertIn("output.HDMI-A-1.enable", cmd)
        self.assertIn("output.DP-1.priority.1", cmd)
        self.assertIn("output.HDMI-A-1.priority.2", cmd)
        self.assertIn("output.HDMI-A-1.position.2560,0", cmd, "a que estava desligada vai para a direita")
        self.assertEqual(self.estado()["modo"], "estender")
        self.assertEqual(self.rodar("modo", "so")[0], 2)
        self.assertEqual(self.rodar("modo", "torto")[0], 2)
        self.rodar("manter")

    def test_principal_sem_confirmacao(self):
        self.rodar("principal", "DP-1")
        self.assertEqual(self.chamadas(), ["output.DP-1.priority.1 output.HDMI-A-1.priority.2"])
        est = self.estado()
        self.assertTrue(self.tela(est, "DP-1")["principal"])
        self.assertEqual(est["confirmar"], 0, "trocar a principal não deixa a tela preta")

    def test_posicoes_normalizadas_numa_chamada(self):
        self.rodar("posicoes", "HDMI-A-1:0,200", "DP-1:1920,100")
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.position.0,100 output.DP-1.position.1920,0"])
        self.rodar("posicoes", "DP-1:-2560,0", "HDMI-A-1:0,100")
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.position.2560,100 output.DP-1.position.0,0"])
        self.assertEqual(self.estado()["confirmar"], 0)
        self.assertEqual(self.rodar("posicoes", "DP-1:1,2", "HDMI-9:0,0")[0], 1)
        self.assertEqual(self.rodar("posicoes", "DP-1=1,2")[0], 2)
        self.assertEqual(self.rodar("posicoes")[0], 2)

    def test_vrr(self):
        self.rodar("vrr", "HDMI-A-1", "off")
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.vrrpolicy.never"])
        self.assertFalse(self.tela(self.estado(), "HDMI-A-1")["vrr"])
        self.rodar("vrr", "HDMI-A-1", "on")
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.vrrpolicy.automatic"])
        self.assertEqual(self.rodar("vrr", "DP-1", "on")[0], 1, "o LG não tem FreeSync")
        self.assertEqual(self.rodar("vrr", "HDMI-A-1", "talvez")[0], 2)

    def test_hdr(self):
        self.assertEqual(self.rodar("hdr", "DP-1", "on")[0], 1, "sem HDR nesta tela")
        self.telas(notebook_com_tv())
        self.rodar("hdr", "HDMI-A-1", "on")
        self.assertEqual(self.chamadas(), ["output.HDMI-A-1.hdr.enable"])
        est = self.estado()
        self.assertTrue(self.tela(est, "HDMI-A-1")["hdr"])
        self.assertGreater(est["confirmar"], 0, "HDR pode deixar a tela preta")
        self.rodar("manter")

    def test_identificar(self):
        codigo, _, _ = self.rodar("identificar")
        self.assertEqual(codigo, 0)
        linhas = self.log.read_text().splitlines()
        self.assertEqual(len(linhas), 1)
        self.assertIn("call org.kde.KWin /org/kde/KWin/Effect/OutputLocator1 org.kde.KWin.Effect.OutputLocator1 show",
                      linhas[0], "o mesmo efeito do Identificar dos ajustes do KDE")
        codigo, _, _ = self.rodar("identificar", FALSO_BUSCTL_RC=1)
        self.assertEqual(codigo, 0, "sem o efeito, não faz nada e sai 0")
        linhas = self.log.read_text().splitlines()
        self.assertIn("loadEffect s outputlocator", linhas[1])
        self.assertIn("showOutputIdentifiers", linhas[-1])
        self.assertEqual(self.rodar("identificar", MATSU_BUSCTL=str(self.dir / "nada"))[0], 0)

    def test_kscreen_doctor_recusa(self):
        codigo, _, erros = self.rodar("resolucao", "HDMI-A-1", "1280x720", FALSO_RECUSA=1)
        self.assertEqual(codigo, 1)
        self.assertIn("não aceitou", erros)
        self.assertFalse((self.dir / "estado" / "telas-volta.json").exists(), "sem volta pendente")
        self.assertEqual(self.estado()["confirmar"], 0)

    def test_comando_desconhecido(self):
        self.assertEqual(self.rodar("explodir")[0], 2)
        self.assertEqual(self.rodar("escala", "DP-1")[0], 2)


# ------------------------------------------------------- a volta sozinha

class TestVolta(Base):
    def setUp(self):
        super().setUp()
        self.telas(pc_do_kaiky())
        self.original = copy.deepcopy(self.config())

    def jeito(self, cfg=None):
        cfg = cfg or self.config()
        return [(o["name"], o["enabled"], o["currentModeId"], o["scale"], o["rotation"], o["pos"],
                 o["replicationSource"]) for o in cfg["outputs"] if o["connected"]]

    def test_volta_sozinha_sem_confirmar(self):
        self.rodar("resolucao", "HDMI-A-1", "1280x720", MATSU_TELAS_ESPERA=0.8)
        self.assertNotEqual(self.jeito(), self.jeito(self.original))
        self.assertGreater(self.estado()["confirmar"], 0)
        self.assertTrue(self.esperar(lambda: self.jeito() == self.jeito(self.original)),
                        "voltou sozinha para 1080p 144 Hz e a LG para o lugar")
        self.assertEqual(self.estado()["confirmar"], 0)

    def test_manter(self):
        self.rodar("escala", "HDMI-A-1", "1.5", MATSU_TELAS_ESPERA=0.8)
        self.assertEqual(self.rodar("manter")[0], 0)
        self.assertEqual(self.estado()["confirmar"], 0)
        time.sleep(1.5)
        self.assertEqual(self.saida("HDMI-A-1")["scale"], 1.5, "confirmou: fica")

    def test_voltar_na_hora(self):
        self.rodar("girar", "DP-1", "direita")
        self.assertEqual(self.saida("DP-1")["rotation"], 8)
        self.assertEqual(self.rodar("voltar")[0], 0)
        self.assertEqual(self.jeito(), self.jeito(self.original))
        self.assertEqual(self.estado()["confirmar"], 0)
        self.assertEqual(self.rodar("voltar")[0], 0, "voltar sem nada pendente não faz nada")

    def test_varias_mudancas_voltam_para_o_comeco(self):
        self.rodar("escala", "HDMI-A-1", "1.25", MATSU_TELAS_ESPERA=1.2)
        self.rodar("resolucao", "DP-1", "1920x1080", MATSU_TELAS_ESPERA=1.2)
        self.rodar("modo", "so", "DP-1", MATSU_TELAS_ESPERA=1.2)
        self.assertFalse(self.saida("HDMI-A-1")["enabled"])
        self.assertTrue(self.esperar(lambda: self.jeito() == self.jeito(self.original)),
                        "volta para antes da primeira mudança")

    def test_mudanca_recusada_no_meio_nao_perde_a_volta(self):
        self.rodar("escala", "HDMI-A-1", "1.5", MATSU_TELAS_ESPERA=1.5)
        # Só esta mudança é recusada (a volta, que herda o ambiente, passa).
        recusa = self.dir / "recusa"
        recusa.write_text("1")
        codigo, _, _ = self.rodar("resolucao", "DP-1", "1920x1080", FALSO_RECUSA_UMA=recusa, MATSU_TELAS_ESPERA=1.5)
        self.assertEqual(codigo, 1)
        self.assertGreater(self.estado()["confirmar"], 0, "a primeira mudança ainda espera confirmação")
        self.assertTrue(self.esperar(lambda: self.jeito() == self.jeito(self.original)))

    def test_duplicar_volta_sozinho(self):
        self.rodar("modo", "duplicar", MATSU_TELAS_ESPERA=0.8)
        self.assertEqual(self.saida("DP-1")["replicationSource"], 70)
        self.assertTrue(self.esperar(lambda: self.jeito() == self.jeito(self.original)))
        self.assertEqual(self.estado()["modo"], "estender")

    def test_volta_esquecida_nao_vale(self):
        pasta = self.dir / "estado"
        pasta.mkdir(parents=True, exist_ok=True)
        velha = {"foto": {"telas": []}, "token": "velho", "prazo": time.time() - 600}
        (pasta / "telas-volta.json").write_text(json.dumps(velha))
        self.rodar("escala", "HDMI-A-1", "1.25", MATSU_TELAS_ESPERA=0.8)
        self.assertTrue(self.esperar(lambda: self.jeito() == self.jeito(self.original)),
                        "a volta usa o jeito de agora, não a foto esquecida")

    def test_estado_volta_se_o_processo_morreu(self):
        pasta = self.dir / "estado"
        pasta.mkdir(parents=True, exist_ok=True)
        foto = T.foto_de(self.original)
        self.rodar("girar", "DP-1", "esquerda")
        self.rodar("manter")
        (pasta / "telas-volta.json").write_text(json.dumps({"foto": foto, "token": "morto",
                                                            "prazo": time.time() - 10}))
        est = self.estado()
        self.assertEqual(est["confirmar"], 0)
        self.assertEqual(self.jeito(), self.jeito(self.original), "o estado fez a volta que faltou")


if __name__ == "__main__":
    unittest.main(verbosity=1)
