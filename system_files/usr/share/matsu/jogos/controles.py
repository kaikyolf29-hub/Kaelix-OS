"""Central de jogos do Matsu: os controles (PS4, PS5, Xbox, Switch...).

Carregado pelo ajudante.py (não roda sozinho). Só usa a biblioteca padrão do
Python e os programas do sistema (busctl, bluetoothctl, rfkill):

  listar()            os controles pareados pelo Bluetooth e os ligados agora (cabo ou Bluetooth),
                      com nome amigável, bateria e se estão conectados
  parear(...)         procura um controle em modo de parear e pareia, confia e conecta (bluetoothctl)
  testar(evento)      lê os botões e os direcionais ao vivo (/dev/input/event*, o evdev)
  acao(...)           desconectar, conectar ou esquecer um controle

O kernel do Fedora já tem os drivers (hid-sony, hid-playstation, hid-microsoft,
xpad, hid-nintendo) e a Steam lê os controles pelas regras do steam-devices.
Nada aqui instala driver: é só a tela de cada coisa.

Para as fotos (a prévia não tem Bluetooth): MATSU_CONTROLES_DEMO=1 inventa três
controles, um pareamento que dá certo e um teste com os direcionais mexendo.
"""
import errno
import fcntl
import json
import os
import re
import select
import shutil
import signal
import struct
import subprocess
import sys
import time

SYS = os.environ.get("MATSU_SYS", "/sys")
DEV = os.environ.get("MATSU_DEV", "/dev")
UDEV = os.environ.get("MATSU_UDEV", "/run/udev/data")


def demo():
    return os.environ.get("MATSU_CONTROLES_DEMO", "") not in ("", "0")


def ler(caminho, padrao=""):
    try:
        with open(caminho, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return padrao


MAC = re.compile(r"^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$")
MAC_DENTRO = re.compile(r"([0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5})")


def mac_valido(texto):
    return bool(MAC.match(texto or ""))


# ----- nomes amigáveis -----
# (fabricante, modelo) do USB/Bluetooth -> (nome, tipo). O tipo escolhe o
# passo a passo de parear e o desenho do teste: playstation, xbox, nintendo, outro.
XBOX = ("Controle Xbox", "Xbox controller", "xbox")
XBOX_ELITE = ("Controle Xbox Elite", "Xbox Elite controller", "xbox")
CONHECIDOS = {
    ("054c", "0268"): ("DualShock 3", "DualShock 3", "playstation"),
    ("054c", "05c4"): ("DualShock 4", "DualShock 4", "playstation"),
    ("054c", "09cc"): ("DualShock 4", "DualShock 4", "playstation"),
    ("054c", "0ba0"): ("DualShock 4 (adaptador sem fio)", "DualShock 4 (wireless adapter)", "playstation"),
    ("054c", "0ce6"): ("DualSense", "DualSense", "playstation"),
    ("054c", "0df2"): ("DualSense Edge", "DualSense Edge", "playstation"),
    ("045e", "028e"): ("Controle Xbox 360", "Xbox 360 controller", "xbox"),
    ("045e", "02d1"): XBOX, ("045e", "02dd"): XBOX, ("045e", "02ea"): XBOX, ("045e", "02e0"): XBOX,
    ("045e", "02fd"): XBOX, ("045e", "0b12"): XBOX, ("045e", "0b13"): XBOX, ("045e", "0b20"): XBOX,
    ("045e", "0b21"): XBOX,
    ("045e", "02e3"): XBOX_ELITE, ("045e", "0b00"): XBOX_ELITE, ("045e", "0b05"): XBOX_ELITE,
    ("045e", "0b22"): XBOX_ELITE,
    ("057e", "2009"): ("Pro Controller (Switch)", "Switch Pro Controller", "nintendo"),
    ("057e", "2006"): ("Joy-Con (esquerdo)", "Joy-Con (L)", "nintendo"),
    ("057e", "2007"): ("Joy-Con (direito)", "Joy-Con (R)", "nintendo"),
    ("057e", "2008"): ("Joy-Con (par)", "Joy-Con (pair)", "nintendo"),
    ("28de", "1102"): ("Steam Controller", "Steam Controller", "outro"),
    ("28de", "1142"): ("Steam Controller", "Steam Controller", "outro"),
    ("28de", "1205"): ("Controles do Steam Deck", "Steam Deck controls", "outro"),
}
# Pelo nome que o controle anuncia (quando não dá para saber o modelo).
PELO_NOME = (
    (re.compile(r"dualsense edge", re.I), ("DualSense Edge", "DualSense Edge", "playstation")),
    (re.compile(r"dualsense", re.I), ("DualSense", "DualSense", "playstation")),
    (re.compile(r"^(sony computer entertainment )?wireless controller$", re.I), ("DualShock 4", "DualShock 4", "playstation")),
    (re.compile(r"playstation|dualshock|sony", re.I), ("Controle PlayStation", "PlayStation controller", "playstation")),
    (re.compile(r"xbox.*elite", re.I), XBOX_ELITE),
    (re.compile(r"xbox|x-box|microsoft", re.I), XBOX),
    (re.compile(r"pro controller", re.I), ("Pro Controller (Switch)", "Switch Pro Controller", "nintendo")),
    (re.compile(r"joy-?con", re.I), ("Joy-Con", "Joy-Con", "nintendo")),
)


def nome_amigavel(fabricante="", modelo="", nome="", pt=True):
    """(nome para a tela, tipo). Fabricante e modelo em hexa de 4 letras ("054c", "0ce6")."""
    chave = ((fabricante or "").lower()[-4:], (modelo or "").lower()[-4:])
    if chave in CONHECIDOS:
        n = CONHECIDOS[chave]
        return (n[0] if pt else n[1]), n[2]
    for padrao, n in PELO_NOME:
        if nome and padrao.search(nome):
            return (n[0] if pt else n[1]), n[2]
    if chave[0] == "054c":
        return ("Controle PlayStation" if pt else "PlayStation controller"), "playstation"
    if chave[0] == "045e":
        return XBOX[0 if pt else 1], "xbox"
    if chave[0] == "057e":
        return ("Controle Nintendo" if pt else "Nintendo controller"), "nintendo"
    return (nome or ("Controle" if pt else "Controller")), "outro"


def ids_do_modalias(modalias):
    """'usb:v054Cp0CE6d0100' (ou bluetooth:v...) -> ('054c', '0ce6')."""
    m = re.search(r"v([0-9A-Fa-f]{4})p([0-9A-Fa-f]{4})", modalias or "")
    return (m.group(1).lower(), m.group(2).lower()) if m else ("", "")


def eh_controle(icone="", classe=0, aparencia=0, nome="", modalias=""):
    """Se um aparelho Bluetooth é um controle de jogo."""
    if icone == "input-gaming":
        return True
    if aparencia in (0x03C3, 0x03C4):  # joystick e gamepad (Bluetooth LE)
        return True
    if classe and (classe >> 8) & 0x1F == 0x05 and (classe >> 2) & 0x0F in (0x01, 0x02):
        return True  # periférico: joystick ou gamepad (Bluetooth clássico)
    f, m = ids_do_modalias(modalias)
    if (f, m) in CONHECIDOS:
        return True
    return any(p.search(nome or "") for p, _ in PELO_NOME)


# ----- Bluetooth: o que o BlueZ sabe -----
def adaptador():
    """O nome do adaptador Bluetooth (hci0) ou vazio."""
    pasta = os.path.join(SYS, "class", "bluetooth")
    try:
        nomes = sorted(n for n in os.listdir(pasta) if re.fullmatch(r"hci\d+", n))
    except OSError:
        return ""
    return nomes[0] if nomes else ""


def _variante(v):
    """Tira o embrulho {"type": ..., "data": ...} que o busctl --json põe nos valores."""
    while isinstance(v, dict) and set(v) == {"type", "data"}:
        v = v["data"]
    return v


def ler_objetos_bluez(texto):
    """A saída de 'busctl --json=short call org.bluez / ...GetManagedObjects' como
    {caminho: {interface: {propriedade: valor}}}."""
    try:
        dados = json.loads(texto)
    except ValueError:
        return {}
    dados = dados.get("data", dados) if isinstance(dados, dict) else dados
    if isinstance(dados, list):
        dados = dados[0] if dados else {}
    objetos = {}
    if not isinstance(dados, dict):
        return objetos
    for caminho, interfaces in dados.items():
        if not isinstance(interfaces, dict):
            continue
        objetos[caminho] = {}
        for nome, props in interfaces.items():
            if isinstance(props, dict):
                objetos[caminho][nome] = {k: _variante(v) for k, v in props.items()}
    return objetos


def objetos_bluez():
    if not shutil.which("busctl"):
        return None
    try:
        r = subprocess.run(["busctl", "--system", "--json=short", "call", "org.bluez", "/",
                            "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"],
                           capture_output=True, text=True, timeout=4)
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    return ler_objetos_bluez(r.stdout)


def ler_info_bluetoothctl(texto):
    """A saída de 'bluetoothctl info <MAC>' como um dicionário simples."""
    d = {}
    m = re.search(r"Device ([0-9A-Fa-f:]{17})", texto)
    if m:
        d["Address"] = m.group(1).upper()
    for linha in texto.splitlines():
        chave, _, valor = linha.strip().partition(": ")
        if not valor:
            continue
        if chave in ("Name", "Alias", "Icon", "Modalias"):
            d[chave] = valor.strip()
        elif chave in ("Paired", "Connected", "Trusted", "Bonded"):
            d[chave] = valor.strip() == "yes"
        elif chave == "Class":
            try:
                d["Class"] = int(valor.split()[0], 16)
            except (ValueError, IndexError):
                pass
        elif chave == "Appearance":
            try:
                d["Appearance"] = int(valor.split()[0], 16)
            except (ValueError, IndexError):
                pass
        elif chave == "Battery Percentage":
            m = re.search(r"\((\d+)\)", valor)
            if m:
                d["Battery"] = int(m.group(1))
    return d


def rodar(args, tempo=8):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=tempo,
                           env=dict(os.environ, LC_ALL="C"))
        return r.returncode, r.stdout + r.stderr
    except (OSError, subprocess.SubprocessError) as e:
        return 1, str(e)


def aparelhos_bluetooth():
    """[{mac, nome_bruto, icone, classe, aparencia, modalias, pareado, conectado, confiavel, bateria}]
    pelo D-Bus (busctl) e, sem ele, pelo bluetoothctl."""
    lista = []
    objetos = objetos_bluez()
    if objetos is not None:
        for caminho, ifaces in objetos.items():
            d = ifaces.get("org.bluez.Device1")
            if not d:
                continue
            bat = ifaces.get("org.bluez.Battery1", {}).get("Percentage")
            lista.append({"mac": str(d.get("Address", "")).upper(), "nome_bruto": d.get("Alias") or d.get("Name") or "",
                          "icone": d.get("Icon", ""), "classe": int(d.get("Class", 0) or 0),
                          "aparencia": int(d.get("Appearance", 0) or 0), "modalias": d.get("Modalias", ""),
                          "pareado": bool(d.get("Paired")), "conectado": bool(d.get("Connected")),
                          "confiavel": bool(d.get("Trusted")), "bateria": int(bat) if bat is not None else -1})
        return lista
    if not shutil.which("bluetoothctl"):
        return lista
    _, saida = rodar(["bluetoothctl", "devices"], 4)
    for mac in re.findall(r"^Device ([0-9A-Fa-f:]{17}) ", saida, re.M):
        _, texto = rodar(["bluetoothctl", "info", mac], 4)
        d = ler_info_bluetoothctl(texto)
        lista.append({"mac": mac.upper(), "nome_bruto": d.get("Alias") or d.get("Name") or "",
                      "icone": d.get("Icon", ""), "classe": d.get("Class", 0), "aparencia": d.get("Appearance", 0),
                      "modalias": d.get("Modalias", ""), "pareado": d.get("Paired", False),
                      "conectado": d.get("Connected", False), "confiavel": d.get("Trusted", False),
                      "bateria": d.get("Battery", -1)})
    return lista


def estado_bluetooth():
    """{tem, ligado, programa}: se há adaptador, se está ligado e se o bluetoothctl existe."""
    hci = adaptador()
    ligado = False
    if hci and shutil.which("busctl"):
        _, saida = rodar(["busctl", "--system", "get-property", "org.bluez", f"/org/bluez/{hci}",
                          "org.bluez.Adapter1", "Powered"], 3)
        ligado = saida.strip() == "b true"
    return {"tem": bool(hci), "ligado": ligado, "programa": bool(shutil.which("bluetoothctl"))}


# ----- os controles ligados agora (evdev) -----
def bits(texto):
    """O mapa de bits do sysfs (palavras em hexa, a mais alta primeiro) como um número."""
    valor = 0
    for palavra in texto.split():
        try:
            valor = (valor << 64) | int(palavra, 16)
        except ValueError:
            return 0
    return valor


BTN_GAMEPAD = 0x130
ABS_X, ABS_Y, ABS_Z, ABS_RX, ABS_RY, ABS_RZ = 0x00, 0x01, 0x02, 0x03, 0x04, 0x05
ABS_GAS, ABS_BRAKE, ABS_HAT0X, ABS_HAT0Y = 0x09, 0x0A, 0x10, 0x11


def eh_joystick(evento):
    """Se /dev/input/<evento> é um controle: pela marca do udev (ID_INPUT_JOYSTICK) e,
    sem ela, pelos botões que ele tem (BTN_GAMEPAD e um direcional)."""
    pasta = os.path.join(SYS, "class", "input", evento)
    dev = ler(os.path.join(pasta, "dev")).strip()
    if dev and os.path.isdir(UDEV):
        dados = ler(os.path.join(UDEV, "c" + dev))
        if dados:
            return "E:ID_INPUT_JOYSTICK=1" in dados.splitlines()
    teclas = bits(ler(os.path.join(pasta, "device", "capabilities", "key")))
    eixos = bits(ler(os.path.join(pasta, "device", "capabilities", "abs")))
    return bool(teclas >> BTN_GAMEPAD & 1) and bool(eixos >> ABS_X & 1)


def joysticks():
    """[{evento, nome_bruto, fabricante, modelo, barramento, mac}] dos controles ligados agora."""
    pasta = os.path.join(SYS, "class", "input")
    try:
        eventos = sorted((n for n in os.listdir(pasta) if re.fullmatch(r"event\d+", n)), key=lambda n: int(n[5:]))
    except OSError:
        return []
    lista = []
    for ev in eventos:
        if not eh_joystick(ev):
            continue
        d = os.path.join(pasta, ev, "device")
        uniq = ler(os.path.join(d, "uniq")).strip()
        lista.append({"evento": ev, "nome_bruto": ler(os.path.join(d, "name")).strip(),
                      "fabricante": ler(os.path.join(d, "id", "vendor")).strip().lower(),
                      "modelo": ler(os.path.join(d, "id", "product")).strip().lower(),
                      "barramento": ler(os.path.join(d, "id", "bustype")).strip().lower(),
                      "mac": uniq.upper() if mac_valido(uniq) else ""})
    return lista


def baterias():
    """{MAC: (carga, carregando)} das baterias que os drivers dos controles criam
    (ps-controller-battery-<mac>, sony_controller_battery_<mac>, xpadneo...)."""
    pasta = os.path.join(SYS, "class", "power_supply")
    achadas = {}
    try:
        nomes = os.listdir(pasta)
    except OSError:
        return achadas
    for nome in nomes:
        m = MAC_DENTRO.search(nome)
        if not m or ler(os.path.join(pasta, nome, "scope")).strip() not in ("Device", ""):
            continue
        try:
            carga = int(ler(os.path.join(pasta, nome, "capacity")).strip())
        except ValueError:
            continue
        estado = ler(os.path.join(pasta, nome, "status")).strip()
        achadas[m.group(1).upper()] = (carga, estado in ("Charging", "Full"))
    return achadas


def listar(pt=True):
    """Os controles: os pareados pelo Bluetooth (conectados ou não) e os ligados por cabo."""
    if demo():
        return dados_demo(pt)
    bt = estado_bluetooth()
    juntos = {}
    if bt["tem"] or shutil.which("bluetoothctl"):
        for a in aparelhos_bluetooth():
            if not (a["pareado"] or a["conectado"]) or not mac_valido(a["mac"]):
                continue
            if not eh_controle(a["icone"], a["classe"], a["aparencia"], a["nome_bruto"], a["modalias"]):
                continue
            f, m = ids_do_modalias(a["modalias"])
            nome, tipo = nome_amigavel(f, m, a["nome_bruto"], pt)
            juntos[a["mac"]] = {"id": a["mac"], "mac": a["mac"], "nome": nome, "tipo": tipo, "nome_bruto": a["nome_bruto"],
                                "via": "bluetooth", "conectado": a["conectado"], "pareado": a["pareado"],
                                "confiavel": a["confiavel"], "bateria": a["bateria"], "carregando": False, "evento": ""}
    for j in joysticks():
        nome, tipo = nome_amigavel(j["fabricante"], j["modelo"], j["nome_bruto"], pt)
        bluetooth = j["barramento"] == "0005"
        chave = j["mac"] if j["mac"] and bluetooth else "evento:" + j["evento"]
        if chave in juntos:
            juntos[chave].update(conectado=True, evento=juntos[chave]["evento"] or j["evento"])
            continue
        juntos[chave] = {"id": chave, "mac": j["mac"] if bluetooth else "", "nome": nome, "tipo": tipo,
                         "nome_bruto": j["nome_bruto"], "via": "bluetooth" if bluetooth else "cabo",
                         "conectado": True, "pareado": bluetooth, "confiavel": bluetooth, "bateria": -1,
                         "carregando": False, "evento": j["evento"], "uniq": j["mac"]}
    cargas = baterias()
    for c in juntos.values():
        # Por cabo, o DualShock e o DualSense também criam a bateria (com o MAC do controle).
        mac = c["mac"] or c.pop("uniq", "") or ""
        c.pop("uniq", None)
        if mac in cargas:
            c["bateria"], c["carregando"] = cargas[mac]
        if not c["conectado"]:
            c["bateria"] = -1
    lista = sorted(juntos.values(), key=lambda c: (not c["conectado"], c["nome"].lower()))
    return {"bluetooth": bt, "controles": lista}


def dados_demo(pt=True):
    estado = os.environ.get("MATSU_CONTROLES_DEMO", "1")
    if estado == "vazio":
        return {"bluetooth": {"tem": True, "ligado": True, "programa": True}, "controles": []}
    if estado == "sem-bluetooth":
        return {"bluetooth": {"tem": False, "ligado": False, "programa": True}, "controles": []}
    if estado == "desligado":
        return {"bluetooth": {"tem": True, "ligado": False, "programa": True}, "controles": []}
    return {"bluetooth": {"tem": True, "ligado": True, "programa": True}, "controles": [
        {"id": "A0:AB:51:10:22:33", "mac": "A0:AB:51:10:22:33", "nome": "DualSense", "tipo": "playstation",
         "nome_bruto": "DualSense Wireless Controller", "via": "bluetooth", "conectado": True, "pareado": True,
         "confiavel": True, "bateria": 78, "carregando": False, "evento": "event20"},
        {"id": "98:7A:14:55:66:77", "mac": "98:7A:14:55:66:77", "nome": XBOX[0 if pt else 1], "tipo": "xbox",
         "nome_bruto": "Xbox Wireless Controller", "via": "bluetooth", "conectado": True, "pareado": True,
         "confiavel": True, "bateria": 35, "carregando": True, "evento": "event21"},
        {"id": "1C:A0:B8:01:02:03", "mac": "1C:A0:B8:01:02:03", "nome": "DualShock 4", "tipo": "playstation",
         "nome_bruto": "Wireless Controller", "via": "bluetooth", "conectado": False, "pareado": True,
         "confiavel": True, "bateria": -1, "carregando": False, "evento": ""},
    ]}


# ----- desconectar, conectar, esquecer, ligar o Bluetooth -----
def ligar_bluetooth():
    """Tira o bloqueio (rfkill) e liga o adaptador. True se ficou ligado."""
    if shutil.which("rfkill"):
        rodar(["rfkill", "unblock", "bluetooth"], 4)
    if shutil.which("bluetoothctl"):
        codigo, saida = rodar(["bluetoothctl", "power", "on"], 8)
        if codigo == 0 and "succeeded" in saida:
            return True
    hci = adaptador()
    if hci and shutil.which("busctl"):
        codigo, _ = rodar(["busctl", "--system", "set-property", "org.bluez", f"/org/bluez/{hci}",
                           "org.bluez.Adapter1", "Powered", "b", "true"], 6)
        return codigo == 0
    return False


def acao(qual, mac):
    """desconectar | conectar | esquecer um controle pelo bluetoothctl. {ok, erro}."""
    if demo():
        time.sleep(0.6)
        return {"ok": True, "erro": ""}
    comandos = {"desconectar": "disconnect", "conectar": "connect", "esquecer": "remove"}
    if qual not in comandos or not mac_valido(mac):
        return {"ok": False, "erro": "pedido"}
    if not shutil.which("bluetoothctl"):
        return {"ok": False, "erro": "sem-programa"}
    codigo, saida = rodar(["bluetoothctl", comandos[qual], mac.upper()], 20)
    ok = codigo == 0 and not re.search(r"Failed|not available|Error", saida)
    if qual == "conectar" and "AlreadyConnected" in saida:
        ok = True
    return {"ok": ok, "erro": "" if ok else erro_bluez(saida)}


def erro_bluez(texto):
    """A causa de um erro do BlueZ, numa palavra que a tela traduz."""
    if "No default controller" in texto:
        return "sem-adaptador"
    if "NotReady" in texto or "Blocked" in texto or "not powered" in texto.lower():
        return "desligado"
    if "AuthenticationFailed" in texto or "AuthenticationRejected" in texto or "AuthenticationCanceled" in texto:
        return "autenticacao"
    if "Page Timeout" in texto or "ConnectionAttemptFailed" in texto or "Timeout" in texto:
        return "tempo"
    if "DoesNotExist" in texto or "not available" in texto:
        return "sumiu"
    return "falhou"


# ----- parear (bluetoothctl de verdade, conversando pela entrada e saída) -----
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|[\x01\x02]")
PROMPT = re.compile(r"^\s*(\[[^\]]*\][#>]\s*)+")


def limpar_linha(texto):
    """Tira as cores, os marcadores do readline e o "[bluetooth]# " do começo."""
    return PROMPT.sub("", ANSI.sub("", texto)).strip()


class Sessao:
    """Um bluetoothctl aberto: manda comandos e lê as linhas que ele escreve."""

    def __init__(self):
        self.p = subprocess.Popen(["bluetoothctl"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, env=dict(os.environ, LC_ALL="C"), bufsize=0)
        self.resto = b""

    def enviar(self, linha):
        try:
            self.p.stdin.write((linha + "\n").encode())
            self.p.stdin.flush()
        except (OSError, ValueError):
            pass

    def ler(self, tempo):
        """As linhas que chegaram em até "tempo" segundos (pode ser lista vazia)."""
        fd = self.p.stdout.fileno()
        pronto, _, _ = select.select([fd], [], [], max(0.0, tempo))
        if not pronto:
            return []
        try:
            bloco = os.read(fd, 65536)
        except OSError:
            bloco = b""
        if not bloco:
            raise EOFError
        self.resto += bloco
        partes = re.split(rb"[\r\n]+", self.resto)
        self.resto = partes.pop()
        linhas = [limpar_linha(p.decode("utf-8", "replace")) for p in partes]
        # Uma pergunta do agente ("(yes/no):") não termina com fim de linha.
        if b"(yes/no)" in self.resto:
            linhas.append(limpar_linha(self.resto.decode("utf-8", "replace")))
            self.resto = b""
        return [l for l in linhas if l]

    def fechar(self):
        self.enviar("scan off")
        self.enviar("quit")
        try:
            self.p.wait(timeout=2)
        except subprocess.SubprocessError:
            self.p.kill()


def info_do_aparelho(mac):
    _, texto = rodar(["bluetoothctl", "info", mac], 4)
    return ler_info_bluetoothctl(texto)


TIPOS_PAREAR = ("playstation", "xbox", "nintendo", "outro")


class Pareamento:
    """O passo a passo: Bluetooth ligado, procurar, parear, confiar e conectar.

    "emitir" recebe cada etapa ({"etapa": ...}); a sessão e a consulta de cada
    aparelho são trocáveis nos testes. Termina com {"etapa": "pronto"} ou
    {"etapa": "erro", "erro": "sem-adaptador|sem-programa|sem-servico|desligado|tempo|autenticacao|conectar|falhou"}.
    """

    def __init__(self, tipo, segundos, emitir, sessao=None, consultar=None, relogio=time.monotonic, pt=True):
        self.tipo = tipo if tipo in TIPOS_PAREAR else "outro"
        self.segundos = max(10, min(120, int(segundos)))
        self.emitir = emitir
        self.sessao = sessao
        self.consultar = consultar or info_do_aparelho
        self.relogio = relogio
        self.pt = pt
        self.linhas = []

    # Lê até achar uma linha que case com algum padrão (ou o tempo acabar).
    def esperar(self, padroes, tempo):
        fim = self.relogio() + tempo
        while True:
            for i, linha in enumerate(self.linhas):
                if "(yes/no)" in linha:
                    self.sessao.enviar("yes")  # o agente pergunta: é o controle que pedimos
                    self.linhas[i] = ""
                    continue
                for nome, padrao in padroes:
                    m = re.search(padrao, linha)
                    if m:
                        del self.linhas[:i + 1]
                        return nome, linha
            self.linhas = [l for l in self.linhas if l]
            restam = fim - self.relogio()
            if restam <= 0:
                return None, ""
            self.linhas += self.sessao.ler(min(restam, 0.5))

    def erro(self, qual, detalhe=""):
        self.emitir({"etapa": "erro", "erro": qual, "detalhe": detalhe})
        return False

    def serve(self, mac, nome):
        """Se o aparelho achado é um controle do tipo que a pessoa escolheu."""
        info = self.consultar(mac) or {}
        nome = info.get("Alias") or info.get("Name") or nome
        if not eh_controle(info.get("Icon", ""), info.get("Class", 0), info.get("Appearance", 0), nome,
                           info.get("Modalias", "")):
            return None
        f, m = ids_do_modalias(info.get("Modalias", ""))
        amigavel, tipo = nome_amigavel(f, m, nome, self.pt)
        if self.tipo != "outro" and tipo not in (self.tipo, "outro"):
            return None
        return {"mac": mac, "nome": amigavel, "tipo": tipo, "pareado": bool(info.get("Paired"))}

    def rodar(self):
        if not shutil.which("bluetoothctl") and self.sessao is None:
            return self.erro("sem-programa")
        if not adaptador() and self.sessao is None:
            return self.erro("sem-adaptador")
        self.emitir({"etapa": "comecando"})
        if self.sessao is None:
            try:
                self.sessao = Sessao()
            except OSError as e:
                return self.erro("sem-programa", str(e))
        try:
            return self._rodar()
        except EOFError:
            return self.erro("falhou", "bluetoothctl")
        finally:
            self.sessao.fechar()

    def _rodar(self):
        s = self.sessao
        s.enviar("show")
        qual, linha = self.esperar([("sem", r"No default controller"), ("ligado", r"Powered: yes"),
                                    ("desligado", r"Powered: no"), ("espera", r"Waiting to connect to bluetoothd")], 6)
        if qual == "espera":
            qual, linha = self.esperar([("ligado", r"Powered: yes"), ("desligado", r"Powered: no")], 6)
            if qual is None:
                return self.erro("sem-servico")
        if qual == "sem":
            return self.erro("sem-adaptador")
        if qual is None:
            return self.erro("sem-servico")
        if qual == "desligado":
            # Liga o Bluetooth (a tela mostra "Ligando o Bluetooth").
            self.emitir({"etapa": "ligando"})
            if shutil.which("rfkill"):
                rodar(["rfkill", "unblock", "bluetooth"], 4)
            s.enviar("power on")
            qual, linha = self.esperar([("ok", r"power on succeeded|Powered: yes"), ("falhou", r"Failed to set power")], 8)
            if qual != "ok":
                return self.erro("desligado", linha)
        s.enviar("scan on")
        self.emitir({"etapa": "procurando", "restam": self.segundos, "total": self.segundos})
        fim = self.relogio() + self.segundos
        vistos = {}
        conferidos = set()
        ultimo = self.segundos
        achado = None
        while achado is None:
            restam = fim - self.relogio()
            if restam <= 0:
                return self.erro("tempo")
            if int(restam) != ultimo:
                ultimo = int(restam)
                self.emitir({"etapa": "procurando", "restam": ultimo, "total": self.segundos})
            self.linhas += s.ler(min(restam, 0.5))
            while self.linhas and achado is None:
                linha = self.linhas.pop(0)
                if "(yes/no)" in linha:
                    s.enviar("yes")
                    continue
                if re.search(r"Failed to start discovery", linha):
                    return self.erro(erro_bluez(linha), linha)
                m = re.search(r"\[NEW\] Device ([0-9A-Fa-f:]{17}) ?(.*)$", linha)
                c = re.search(r"\[CHG\] Device ([0-9A-Fa-f:]{17}) (Name|Alias|RSSI|ManufacturerData|Class|Icon)", linha)
                mac = (m or c).group(1).upper() if (m or c) else ""
                if not mac:
                    continue
                if m:
                    vistos[mac] = m.group(2).strip()
                nome_mudou = c and c.group(2) in ("Name", "Alias", "Class", "Icon")
                if mac in conferidos and not nome_mudou:
                    continue
                conferidos.add(mac)
                achado = self.serve(mac, vistos.get(mac, ""))
        s.enviar("scan off")
        mac = achado["mac"]
        self.emitir(dict(achado, etapa="achou"))
        self.emitir({"etapa": "pareando", "mac": mac, "nome": achado["nome"]})
        s.enviar(f"pair {mac}")
        qual, linha = self.esperar([("ok", r"Pairing successful|Paired: yes|AlreadyExists"),
                                    ("falhou", r"Failed to pair")], 25)
        if qual != "ok":
            return self.erro(erro_bluez(linha) if linha else "tempo", linha)
        self.emitir({"etapa": "confiando", "mac": mac, "nome": achado["nome"]})
        s.enviar(f"trust {mac}")
        self.esperar([("ok", r"trust succeeded|Trusted: yes"), ("falhou", r"Failed")], 5)
        self.emitir({"etapa": "conectando", "mac": mac, "nome": achado["nome"]})
        s.enviar(f"connect {mac}")
        qual, linha = self.esperar([("ok", r"Connection successful|Connected: yes|AlreadyConnected"),
                                    ("falhou", r"Failed to connect")], 15)
        if qual != "ok":
            # O DualShock e o DualSense às vezes conectam sozinhos logo depois de parear.
            if not (self.consultar(mac) or {}).get("Connected"):
                return self.erro("conectar", linha)
        self.emitir({"etapa": "pronto", "mac": mac, "nome": achado["nome"], "tipo": achado["tipo"]})
        return True


def parear_demo(tipo, emitir, pt=True):
    nomes = {"playstation": ("DualSense", "DualSense"), "xbox": XBOX[:2], "nintendo": ("Pro Controller (Switch)", "Switch Pro Controller"),
             "outro": ("Controle", "Controller")}
    nome = nomes.get(tipo, nomes["outro"])[0 if pt else 1]
    emitir({"etapa": "comecando"})
    time.sleep(0.4)
    for restam in range(30, 24, -1):
        emitir({"etapa": "procurando", "restam": restam, "total": 30})
        time.sleep(1)
    if os.environ.get("MATSU_CONTROLES_DEMO") == "vazio":
        emitir({"etapa": "erro", "erro": "tempo", "detalhe": ""})
        return
    mac = "A0:AB:51:44:55:66"
    emitir({"etapa": "achou", "mac": mac, "nome": nome, "tipo": tipo})
    for etapa in ("pareando", "confiando", "conectando"):
        emitir({"etapa": etapa, "mac": mac, "nome": nome})
        time.sleep(0.9)
    emitir({"etapa": "pronto", "mac": mac, "nome": nome, "tipo": tipo})


def parear(tipo="outro", segundos=30, pt=True):
    def emitir(d):
        try:
            sys.stdout.write(json.dumps(d, ensure_ascii=False) + "\n")
            sys.stdout.flush()
        except BrokenPipeError:
            sys.exit(0)
    # Cancelar na tela (o app manda SIGTERM) fecha o bluetoothctl direito e para a busca.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    if demo():
        parear_demo(tipo, emitir, pt)
        return 0
    return 0 if Pareamento(tipo, segundos, emitir, pt=pt).rodar() else 1


# ----- testar: os botões e os direcionais ao vivo -----
EV_SYN, EV_KEY, EV_ABS = 0x00, 0x01, 0x03
EVENTO = struct.Struct("llHHi")  # struct input_event (timeval, tipo, código, valor)
BOTOES = {0x130: "sul", 0x131: "leste", 0x133: "norte", 0x134: "oeste", 0x136: "l1", 0x137: "r1",
          0x138: "l2b", 0x139: "r2b", 0x13A: "select", 0x13B: "start", 0x13C: "guia", 0x13D: "l3", 0x13E: "r3",
          0x220: "cima", 0x221: "baixo", 0x222: "esquerda", 0x223: "direita"}


def eviocgabs(codigo):
    """O pedido EVIOCGABS(código): _IOR('E', 0x40 + código, struct input_absinfo)."""
    return 0x80000000 | (24 << 16) | (ord("E") << 8) | (0x40 + codigo)


class Leitura:
    """Transforma os eventos do evdev no estado do controle, de -1 a 1 (direcionais) e 0 a 1 (gatilhos)."""

    def __init__(self, faixas, eixos_presentes, tipo="outro", driver=""):
        self.faixas = faixas  # {código: (mínimo, máximo)}
        self.botoes = {n: 0 for n in BOTOES.values()}
        self.valores = {}
        tem = eixos_presentes
        if ABS_RX in tem or ABS_RY in tem:
            self.mapa = {ABS_X: "lx", ABS_Y: "ly", ABS_RX: "rx", ABS_RY: "ry", ABS_Z: "l2", ABS_RZ: "r2"}
        else:  # controles Xbox pelo Bluetooth LE (hid-generic): direito em Z/RZ, gatilhos em freio e acelerador
            self.mapa = {ABS_X: "lx", ABS_Y: "ly", ABS_Z: "rx", ABS_RZ: "ry", ABS_BRAKE: "l2", ABS_GAS: "r2"}
        self.mapa.update({ABS_HAT0X: "hx", ABS_HAT0Y: "hy"})
        # No Xbox o kernel chama o X de "norte" e o Y de "oeste" (xpad e hid-generic);
        # na tela, cada botão acende no lugar dele.
        self.trocar_xy = tipo == "xbox" and driver != "xpadneo"

    def normal(self, codigo, valor):
        nome = self.mapa.get(codigo)
        minimo, maximo = self.faixas.get(codigo, (0, 255))
        if maximo <= minimo:
            return nome, 0.0
        if nome in ("l2", "r2"):
            return nome, round(max(0.0, min(1.0, (valor - minimo) / (maximo - minimo))), 3)
        if nome in ("hx", "hy"):
            return nome, float((valor > 0) - (valor < 0))
        meio = (maximo + minimo) / 2
        v = (valor - meio) / ((maximo - minimo) / 2)
        if abs(v) < 0.06:
            v = 0.0
        return nome, round(max(-1.0, min(1.0, v)), 3)

    def evento(self, tipo, codigo, valor):
        """True se mudou algo que aparece na tela."""
        if tipo == EV_KEY and codigo in BOTOES:
            nome = BOTOES[codigo]
            if self.trocar_xy and nome in ("norte", "oeste"):
                nome = "oeste" if nome == "norte" else "norte"
            novo = 1 if valor else 0
            mudou = self.botoes.get(nome) != novo
            self.botoes[nome] = novo
            return mudou
        if tipo == EV_ABS and codigo in self.mapa:
            nome, v = self.normal(codigo, valor)
            if nome == "hx":
                self.botoes["esquerda"], self.botoes["direita"] = int(v < 0), int(v > 0)
            elif nome == "hy":
                self.botoes["cima"], self.botoes["baixo"] = int(v < 0), int(v > 0)
            mudou = self.valores.get(nome) != v
            self.valores[nome] = v
            return mudou
        return False

    def estado(self):
        e = {k: self.valores.get(k, 0.0) for k in ("lx", "ly", "rx", "ry", "l2", "r2")}
        b = dict(self.botoes)
        # Gatilho apertado até o fim também conta como botão.
        b["l2b"] = b["l2b"] or int(e["l2"] > 0.5)
        b["r2b"] = b["r2b"] or int(e["r2"] > 0.5)
        return {"botoes": b, "eixos": e}


def caminho_evento(evento):
    if not re.fullmatch(r"event\d+", evento or ""):
        return ""
    return os.path.join(DEV, "input", evento)


def testar(evento, tipo="outro", intervalo=1 / 30):
    """Escreve o estado do controle (JSON, uma linha) a cada mudança, até a janela fechar."""
    def emitir(d):
        sys.stdout.write(json.dumps(d, separators=(",", ":")) + "\n")
        sys.stdout.flush()
    pai = os.getppid()
    if demo():
        return testar_demo(emitir, pai)
    caminho = caminho_evento(evento)
    if not caminho:
        emitir({"erro": "pedido"})
        return 2
    try:
        fd = os.open(caminho, os.O_RDONLY | os.O_NONBLOCK)
    except OSError as e:
        emitir({"erro": "acesso" if e.errno in (errno.EACCES, errno.EPERM) else "sumiu"})
        return 1
    pasta = os.path.join(SYS, "class", "input", evento, "device")
    presentes = bits(ler(os.path.join(pasta, "capabilities", "abs")))
    codigos = [c for c in range(0x20) if presentes >> c & 1]
    faixas = {}
    for c in codigos:
        try:
            dados = fcntl.ioctl(fd, eviocgabs(c), bytes(24))
            _, minimo, maximo, _, _, _ = struct.unpack("6i", dados)
            faixas[c] = (minimo, maximo)
        except OSError:
            pass
    driver = os.path.basename(os.path.realpath(os.path.join(pasta, "device", "driver")))
    leitura = Leitura(faixas, set(codigos), tipo, driver)
    emitir(dict(leitura.estado(), pronto=True))
    ultimo = 0.0
    pendente = False
    try:
        while True:
            pronto, _, _ = select.select([fd], [], [], 0.5)
            if os.getppid() != pai:
                return 0
            if pronto:
                try:
                    dados = os.read(fd, EVENTO.size * 64)
                except BlockingIOError:
                    dados = b""
                except OSError:
                    emitir({"erro": "sumiu"})
                    return 1
                for i in range(0, len(dados) - EVENTO.size + 1, EVENTO.size):
                    _, _, t, codigo, valor = EVENTO.unpack_from(dados, i)
                    if leitura.evento(t, codigo, valor):
                        pendente = True
            agora = time.monotonic()
            if pendente and agora - ultimo >= intervalo:
                emitir(leitura.estado())
                ultimo, pendente = agora, False
    except BrokenPipeError:
        return 0
    finally:
        os.close(fd)


def testar_demo(emitir, pai):
    """Os direcionais girando e os botões acendendo em roda (para as fotos)."""
    import math
    t0 = time.monotonic()
    ordem = ["sul", "leste", "norte", "oeste", "r1", "l1", "cima", "direita"]
    while os.getppid() == pai:
        t = time.monotonic() - t0
        b = {n: 0 for n in BOTOES.values()}
        b[ordem[int(t * 1.5) % len(ordem)]] = 1
        e = {"lx": round(math.cos(t * 1.7) * 0.8, 3), "ly": round(math.sin(t * 1.7) * 0.8, 3),
             "rx": round(math.sin(t * 1.1) * 0.6, 3), "ry": round(-0.4 + math.cos(t * 2.3) * 0.3, 3),
             "l2": round((math.sin(t * 1.3) + 1) / 2, 3), "r2": 0.82}
        try:
            emitir({"botoes": b, "eixos": e})
        except BrokenPipeError:
            return 0
        time.sleep(1 / 20)
    return 0
