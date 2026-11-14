#!/usr/bin/python3 -IS
# Matsu 27 OS: as telas (monitores), para a página Telas dos Ajustes do Matsu.
# Os Ajustes chamam: /usr/bin/python3 -I -S /usr/share/matsu/monitores/ajudante.py <comando>
#
#   ajudante.py estado                          uma linha de JSON com as telas
#   ajudante.py resolucao <tela> <LxA> [hz]     resolução (e taxa de atualização)
#   ajudante.py escala <tela> <1.25>            tamanho do texto e dos apps
#   ajudante.py girar <tela> normal|esquerda|direita|invertida
#   ajudante.py modo estender|duplicar|so <tela>
#   ajudante.py principal <tela>                a tela da barra com a bandeja
#   ajudante.py posicoes <tela>:<x>,<y> ...     onde fica cada tela (tudo de uma vez)
#   ajudante.py vrr <tela> on|off               sincronia adaptativa (FreeSync)
#   ajudante.py hdr <tela> on|off
#   ajudante.py identificar                     mostra em cada tela qual é qual
#   ajudante.py manter | voltar                 confirma ou desfaz a última mudança
#
# Quem mexe nas telas é o kscreen-doctor, do KDE. O que pode deixar a tela
# preta (resolução, taxa, escala, girar, modo e HDR) guarda antes o jeito de
# agora e volta sozinho em 15 s se a pessoa não confirmar, como no Mac e no
# Windows. Quem volta é um processo solto, que continua mesmo se os Ajustes
# fecharem. Várias mudanças seguidas voltam todas para o jeito de antes da
# primeira (com o que mais tiver mudado no meio, como a posição das telas).
# Os Ajustes só desenham: toda a lógica fica aqui, com teste (tests/test_monitores.py).
import json
import math
import os
import re
import subprocess
import sys
import time

KSCREEN = os.environ.get("MATSU_KSCREEN_DOCTOR") or "kscreen-doctor"
BUSCTL = os.environ.get("MATSU_BUSCTL") or "busctl"
SYS_DRM = os.environ.get("MATSU_SYS_DRM") or "/sys/class/drm"
# Nenhum programa pode prender o ajudante: todos têm prazo para responder.
TEMPO = 5
# O "replicationSource" da libkscreen: o KWin sabe espelhar uma tela na outra.
RECURSO_ESPELHO = 8

# Rotação na libkscreen (números) e no kscreen-doctor (palavras).
ROTACAO_NOME = {1: "normal", 2: "esquerda", 4: "invertida", 8: "direita",
                16: "normal", 32: "esquerda", 64: "invertida", 128: "direita"}
ROTACAO_DOCTOR = {1: "none", 2: "left", 4: "inverted", 8: "right",
                  16: "flipped", 32: "flipped90", 64: "flipped180", 128: "flipped270"}
GIRAR = {"normal": 1, "esquerda": 2, "direita": 8, "invertida": 4}

# Fabricantes pelo código de três letras do EDID (bytes 8 e 9).
FABRICANTES = {
    "ACI": "ASUS", "ACR": "Acer", "AOC": "AOC", "API": "Acer", "APP": "Apple",
    "AUO": "AU Optronics", "AUS": "ASUS", "BNQ": "BenQ", "BOE": "BOE",
    "CMN": "Innolux", "CMO": "Chi Mei", "CPQ": "Compaq", "DEL": "Dell",
    "EIZ": "EIZO", "ENC": "EIZO", "GBT": "Gigabyte", "GSM": "LG", "HEC": "Hisense",
    "HKC": "HKC", "HPN": "HP", "HSD": "HannStar", "HWP": "HP", "IVM": "iiyama",
    "LEN": "Lenovo", "LGD": "LG", "LPL": "LG", "MEI": "Panasonic", "MSI": "MSI",
    "NEC": "NEC", "PHL": "Philips", "SAM": "Samsung", "SDC": "Samsung",
    "SEC": "Samsung", "SHP": "Sharp", "SNY": "Sony", "TCL": "TCL", "TSB": "Toshiba",
    "VSC": "ViewSonic", "XMI": "Xiaomi",
}

# Nomes conhecidos de resolução.
NOMES_RESOLUCAO = {
    (7680, 4320): "8K", (5120, 2880): "5K", (5120, 1440): "Super ultrawide",
    (3840, 1080): "Super ultrawide", (4096, 2160): "4K (DCI)", (3840, 2160): "4K",
    (3840, 1600): "Ultrawide", (3440, 1440): "Ultrawide", (2560, 1080): "Ultrawide",
    (3200, 1800): "QHD+", (2560, 1600): "WQXGA", (2560, 1440): "2K (QHD)",
    (2048, 1080): "2K (DCI)", (1920, 1200): "WUXGA", (1920, 1080): "Full HD (1080p)",
    (1680, 1050): "WSXGA+", (1600, 900): "HD+", (1440, 900): "WXGA+",
    (1366, 768): "HD", (1360, 768): "HD", (1280, 1024): "SXGA",
    (1280, 800): "WXGA", (1280, 720): "HD (720p)", (1024, 768): "XGA",
    (800, 600): "SVGA", (640, 480): "VGA",
}

ANSI = re.compile(r"\x1b\[[0-9;]*m")
NOME_TELA = re.compile(r"^[A-Za-z0-9_-]+$")


class Erro(Exception):
    """Algo deu errado: a mensagem vai para a pessoa (em português simples)."""


class Uso(Exception):
    """O comando veio errado."""


# ---------------------------------------------------------------- utilidades

def rodar(args, tempo=TEMPO):
    """Roda um programa com prazo. Devolve (código, saída, erros)."""
    try:
        r = subprocess.run(args, stdin=subprocess.DEVNULL, capture_output=True,
                           text=True, timeout=tempo)
    except FileNotFoundError:
        return 127, "", "não achei " + args[0]
    except subprocess.TimeoutExpired:
        return 124, "", args[0] + " demorou demais"
    except OSError as e:
        return 126, "", str(e)
    return r.returncode, r.stdout, r.stderr


def pasta_estado():
    pasta = os.environ.get("MATSU_TELAS_DIR")
    if not pasta:
        base = (os.environ.get("XDG_RUNTIME_DIR") or os.environ.get("XDG_CONFIG_HOME")
                or os.path.join(os.path.expanduser("~"), ".config"))
        pasta = os.path.join(base, "matsu")
    os.makedirs(pasta, mode=0o700, exist_ok=True)
    return pasta


def arquivo_volta():
    return os.path.join(pasta_estado(), "telas-volta.json")


def arquivo_antes_duplicar():
    return os.path.join(pasta_estado(), "telas-antes-de-duplicar.json")


def espera_volta():
    """Quantos segundos a pessoa tem para confirmar (nos testes, bem menos)."""
    try:
        return max(0.2, float(os.environ.get("MATSU_TELAS_ESPERA", "15")))
    except ValueError:
        return 15.0


def ler_json(caminho):
    try:
        with open(caminho, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def gravar_json(caminho, dados):
    novo = caminho + ".novo"
    with open(novo, "w", encoding="utf-8") as f:
        json.dump(dados, f)
    os.replace(novo, caminho)


def idioma_pt():
    """Português quando o sistema está em português (o mesmo jeito da central)."""
    ambiente = os.environ
    lingua = (ambiente.get("MATSU_LANG") or ambiente.get("LC_ALL") or ambiente.get("LC_MESSAGES")
              or (ambiente.get("LANGUAGE") or "").split(":")[0] or ambiente.get("LANG") or "")
    if not lingua or lingua.startswith("C") or lingua == "POSIX":
        config = ambiente.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
        for arquivo in (os.path.join(config, "plasma-localerc"), "/etc/xdg/plasma-localerc"):
            try:
                with open(arquivo, encoding="utf-8") as f:
                    for linha in f:
                        if linha.startswith(("LANGUAGE=", "LANG=")):
                            lingua = linha.split("=", 1)[1].strip()
                            break
            except OSError:
                continue
            if lingua:
                break
    return lingua.startswith("pt")


def numero_escala(texto):
    """'1.25', '1,25' ou '125%' viram 1.25."""
    t = str(texto).strip().rstrip("%").replace(",", ".")
    try:
        valor = float(t)
    except ValueError:
        raise Uso("escala inválida: " + str(texto))
    if valor > 5:
        valor = valor / 100
    if not 0.5 <= valor <= 4:
        raise Uso("escala fora do limite: " + str(texto))
    return round(valor, 4)


def texto_escala(valor):
    return ("%.4f" % valor).rstrip("0").rstrip(".")


# ------------------------------------------------------ leitura das telas

def ler_extras(texto):
    """Do 'kscreen-doctor -o' (o JSON não traz): sincronia adaptativa e HDR."""
    extras = {}
    atual = None
    for linha in ANSI.sub("", texto or "").splitlines():
        s = linha.strip()
        m = re.match(r"Output:\s*(\d+)\s+(\S+)", s)
        if m:
            atual = extras.setdefault(m.group(2), {"id": int(m.group(1))})
            continue
        if atual is None or ":" not in s:
            continue
        chave, _, valor = s.partition(":")
        chave = chave.strip().lower()
        if chave in ("vrr", "hdr"):
            atual[chave] = valor.strip().lower()
    return extras


def ler_config():
    """O jeito das telas agora: o JSON do kscreen-doctor e os extras do '-o'."""
    # As duas leituras ao mesmo tempo, para a página não esperar o dobro.
    processos = []
    try:
        for opcao in ("-j", "-o"):
            processos.append(subprocess.Popen([KSCREEN, opcao], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                              stderr=subprocess.DEVNULL, text=True))
        saida_j = processos[0].communicate(timeout=TEMPO)[0]
        saida_o = processos[1].communicate(timeout=TEMPO)[0]
    except OSError:
        for p in processos:
            p.kill()
        raise Erro("sem-kscreen-doctor")
    except subprocess.TimeoutExpired:
        for p in processos:
            p.kill()
        raise Erro("kscreen-doctor-demorou")
    inicio = saida_j.find("{")
    try:
        cfg = json.loads(saida_j[inicio:]) if inicio >= 0 else None
    except ValueError:
        cfg = None
    if not isinstance(cfg, dict) or not isinstance(cfg.get("outputs"), list):
        raise Erro("kscreen-doctor-falhou")
    extras = ler_extras(saida_o)
    for saida in cfg["outputs"]:
        saida["_extras"] = extras.get(saida.get("name"), {})
    return cfg


def conectadas(cfg):
    lista = [o for o in cfg.get("outputs", []) if o.get("connected")]
    return sorted(lista, key=lambda o: int(o.get("id") or 0))


def achar(cfg, nome):
    if not NOME_TELA.match(str(nome)):
        raise Uso("nome de tela inválido: " + str(nome))
    for o in conectadas(cfg):
        if o.get("name") == nome:
            return o
    raise Erro("não achei a tela " + nome)


def tamanho(modo):
    s = (modo or {}).get("size") or {}
    return int(s.get("width") or 0), int(s.get("height") or 0)


def taxa(modo):
    return float((modo or {}).get("refreshRate") or 0)


def hz(modo):
    return int(round(taxa(modo)))


def modo_atual(o):
    for m in o.get("modes") or []:
        if str(m.get("id")) == str(o.get("currentModeId")):
            return m
    return None


def girada(rotacao):
    return int(rotacao or 1) in (2, 8, 32, 128)


def logico(largura, altura, escala, rotacao):
    """O tamanho que os apps enxergam: o do modo ÷ escala, trocado se girada."""
    if girada(rotacao):
        largura, altura = altura, largura
    e = escala if escala and escala > 0 else 1.0
    return int(round(largura / e)), int(round(altura / e))


def retangulo(o, largura=None, altura=None, escala=None, rotacao=None):
    """(x, y, largura, altura) lógicos de uma tela, com o que for mudar."""
    w, h = tamanho(modo_atual(o))
    lw, lh = logico(largura or w, altura or h,
                    escala if escala is not None else float(o.get("scale") or 1),
                    rotacao if rotacao is not None else o.get("rotation"))
    pos = o.get("pos") or {}
    return int(pos.get("x") or 0), int(pos.get("y") or 0), lw, lh


def recursos(cfg):
    try:
        return int(cfg.get("features") or 0)
    except (TypeError, ValueError):
        return 0


def tem_espelho(cfg):
    return bool(recursos(cfg) & RECURSO_ESPELHO)


def vrr_de(o):
    """(tem, ligada) da sincronia adaptativa."""
    valor = o.get("_extras", {}).get("vrr")
    if valor is None and "vrrPolicy" in o:
        tem = bool(int(o.get("capabilities") or 0) & 2)
        return tem, tem and int(o.get("vrrPolicy") or 0) != 0
    if not valor or valor == "incapable":
        return False, False
    return True, valor in ("automatic", "always")


def hdr_de(o):
    valor = o.get("_extras", {}).get("hdr")
    if valor is None and "hdr" in o:
        tem = bool(int(o.get("capabilities") or 0) & 8)
        return tem, tem and bool(o.get("hdr"))
    if not valor or valor in ("incapable", "unsupported"):
        return False, False
    return True, valor == "enabled"


def principal_de(cfg):
    """A tela principal: a ligada com a prioridade mais baixa (1 = principal)."""
    ligadas = [o for o in conectadas(cfg) if o.get("enabled")]
    if not ligadas:
        return None
    return min(ligadas, key=lambda o: (int(o.get("priority") or 99) or 99, int(o.get("id") or 0)))


# ------------------------------------------------------------ rótulos

def ler_edid(dados):
    """Fabricante, nome do monitor e polegadas, direto do EDID."""
    if len(dados) < 128 or dados[:8] != b"\x00\xff\xff\xff\xff\xff\xff\x00":
        return {}
    codigo = (dados[8] << 8) | dados[9]
    letras = [((codigo >> s) & 0x1F) for s in (10, 5, 0)]
    pnp = "".join(chr(64 + c) for c in letras) if all(1 <= c <= 26 for c in letras) else ""
    nome = ""
    for i in (54, 72, 90, 108):
        bloco = dados[i:i + 18]
        if bloco[0] == 0 and bloco[1] == 0 and bloco[3] == 0xFC:
            nome = bloco[5:18].split(b"\x0a")[0].decode("latin-1").strip()
            break
    largura_cm, altura_cm = dados[21], dados[22]
    polegadas = int(round(math.hypot(largura_cm, altura_cm) / 2.54)) if largura_cm and altura_cm else 0
    return {"pnp": pnp, "fabricante": FABRICANTES.get(pnp, pnp), "modelo": nome, "polegadas": polegadas}


def edid_de(conector):
    """O EDID em /sys/class/drm/card*-<conector>/edid (vazio se não tiver)."""
    try:
        entradas = sorted(os.listdir(SYS_DRM))
    except OSError:
        return b""
    for entrada in entradas:
        if re.fullmatch(r"card\d+-" + re.escape(conector), entrada):
            try:
                with open(os.path.join(SYS_DRM, entrada, "edid"), "rb") as f:
                    dados = f.read()
            except OSError:
                continue
            if dados:
                return dados
    return b""


def polegadas_de(o, info=None, interna=False):
    """O tamanho da tela: em milímetros pelo KDE, ou em centímetros pelo EDID.

    Monitor e TV saem inteiros, como são vendidos (23,8" vira 24", 54,6" vira
    55"); a tela do notebook sai com a casa decimal (15,6")."""
    mm = o.get("sizeMM") or {}
    if int(mm.get("width") or 0) > 0 and int(mm.get("height") or 0) > 0:
        diagonal = math.hypot(mm["width"], mm["height"]) / 25.4
        inteiro = int(round(diagonal))
        if not interna or abs(diagonal - inteiro) < 0.05:
            return inteiro
        return round(diagonal, 1)
    if info is None:
        info = ler_edid(edid_de(o.get("name", "")))
    return info.get("polegadas") or 0


def conexao_de(nome, tipo=0):
    n = str(nome).upper()
    if n.startswith(("EDP", "LVDS", "DSI")) or tipo == 7:
        return "interna"
    if n.startswith("HDMI") or tipo == 6:
        return "HDMI"
    if n.startswith("DP") or "DISPLAYPORT" in n or tipo == 14:
        return "DisplayPort"
    if n.startswith("DVI") or tipo in (2, 3, 4, 5):
        return "DVI"
    if n.startswith("VGA") or tipo == 1:
        return "VGA"
    return ""


def nome_do_modelo(fabricante, modelo):
    """'DELL P2419H' vira 'Dell P2419H'; '24G2W1G4' vira 'AOC 24G2W1G4'."""
    if not modelo:
        return ""
    if not fabricante:
        return modelo
    if modelo.lower().startswith(fabricante.lower()):
        return fabricante + modelo[len(fabricante):]
    return fabricante + " " + modelo


def rotulo_de(conexao, info, pt):
    if conexao == "interna":
        return "Tela do notebook" if pt else "Built-in display"
    nome = nome_do_modelo(info.get("fabricante", ""), info.get("modelo", ""))
    if nome:
        return nome
    if info.get("fabricante"):
        polegadas = info.get("polegadas") or 0
        return info["fabricante"] + (" %d″" % polegadas if polegadas else "")
    if conexao:
        return ("Tela " if pt else "") + conexao + ("" if pt else " display")
    return ""


def nome_resolucao(largura, altura):
    return NOMES_RESOLUCAO.get((largura, altura)) or NOMES_RESOLUCAO.get((altura, largura), "")


def escalas_sugeridas(largura, altura, atual=None, polegadas=0):
    """As escalas que fazem sentido para a resolução (sempre com a de agora)."""
    curto = min(largura, altura)
    if curto <= 800:
        lista = [1.0]
    elif curto <= 900:
        lista = [1.0, 1.25]
    elif curto <= 1200:
        lista = [1.0, 1.25, 1.5]
    elif curto <= 1600:
        lista = [1.0, 1.25, 1.5, 1.75]
    elif curto <= 1800:
        lista = [1.0, 1.25, 1.5, 1.75, 2.0]
    elif curto <= 2160:
        # Uma TV ou monitor enorme em 4K também fica bom em 100% e 125%.
        lista = [1.0, 1.25, 1.5, 1.75, 2.0] if polegadas >= 40 else [1.5, 1.75, 2.0, 2.25, 2.5]
    else:
        lista = [2.0, 2.5, 3.0]
    if atual:
        a = round(float(atual), 2)
        if all(abs(a - e) > 0.001 for e in lista):
            lista.append(a)
    return sorted(lista)


def resolucoes_de(o):
    """Cada resolução com as taxas (Hz, sem repetir, da maior para a menor)."""
    preferidas = {str(i) for i in (o.get("preferredModes") or [])}
    grupos = {}
    for m in o.get("modes") or []:
        w, h = tamanho(m)
        if w <= 0 or h <= 0:
            continue
        g = grupos.setdefault((w, h), {"largura": w, "altura": h, "nome": nome_resolucao(w, h),
                                       "taxas": set(), "preferida": False, "taxa_preferida": 0})
        g["taxas"].add(hz(m))
        if str(m.get("id")) in preferidas:
            g["preferida"] = True
            g["taxa_preferida"] = max(g["taxa_preferida"], hz(m))
    lista = sorted(grupos.values(), key=lambda g: (g["largura"] * g["altura"], g["largura"]), reverse=True)
    # Sem a preferida (o KWin aninhado não diz), a maior é a do próprio monitor.
    if lista and not any(g["preferida"] for g in lista):
        lista[0]["preferida"] = True
        lista[0]["taxa_preferida"] = max(lista[0]["taxas"])
    for g in lista:
        g["taxas"] = sorted(g["taxas"], reverse=True)
    return lista


# -------------------------------------------------------------- estado

def tela_para_estado(o, numero, nomes_por_id, pt):
    conexao = conexao_de(o.get("name", ""), int(o.get("type") or 0))
    info = ler_edid(edid_de(o.get("name", ""))) if conexao != "interna" else {}
    m = modo_atual(o)
    w, h = tamanho(m)
    escala = float(o.get("scale") or 1)
    x, y, lw, lh = retangulo(o)
    polegadas = polegadas_de(o, info, conexao == "interna")
    vrr_tem, vrr = vrr_de(o)
    hdr_tem, hdr = hdr_de(o)
    return {
        "nome": o.get("name", ""), "numero": numero,
        "rotulo": rotulo_de(conexao, info, pt),
        "fabricante": info.get("fabricante", ""), "modelo": info.get("modelo", ""),
        "polegadas": polegadas, "conexao": conexao, "interna": conexao == "interna",
        "ligada": bool(o.get("enabled")), "conectada": bool(o.get("connected")), "principal": False,
        "x": x, "y": y, "largura": lw, "altura": lh,
        "modo": {"largura": w, "altura": h, "hz": hz(m)},
        "resolucoes": resolucoes_de(o),
        "escala": round(escala, 4),
        "escalas": escalas_sugeridas(w, h, escala, polegadas),
        "rotacao": ROTACAO_NOME.get(int(o.get("rotation") or 1), "normal"),
        "vrr_tem": vrr_tem, "vrr": vrr, "hdr_tem": hdr_tem, "hdr": hdr,
        "espelho_de": nomes_por_id.get(int(o.get("replicationSource") or 0), ""),
    }


def modo_da_config(cfg):
    return modo_geral([{"ligada": bool(o.get("enabled")), "x": retangulo(o)[0], "y": retangulo(o)[1],
                        "espelho_de": "s" if int(o.get("replicationSource") or 0) else ""}
                       for o in conectadas(cfg)])


def modo_geral(telas):
    ligadas = [t for t in telas if t["ligada"]]
    if len(ligadas) <= 1:
        return "uma"
    if any(t["espelho_de"] for t in ligadas):
        return "duplicar"
    if len({(t["x"], t["y"]) for t in ligadas}) == 1:
        return "duplicar"
    return "estender"


def estado(cfg=None):
    pt = idioma_pt()
    pendente = conferir_volta()
    try:
        cfg = cfg or ler_config()
    except Erro as e:
        return {"ok": False, "erro": str(e), "telas": [], "modo": "uma", "confirmar": pendente,
                "espera": espera_volta()}
    lista = conectadas(cfg)
    nomes_por_id = {int(o.get("id") or 0): o.get("name", "") for o in lista}
    telas = [tela_para_estado(o, i + 1, nomes_por_id, pt) for i, o in enumerate(lista)]
    principal = principal_de(cfg)
    for t in telas:
        t["principal"] = principal is not None and t["nome"] == principal.get("name")
    # Sem nome nenhum: "Tela 1", "Tela 2". Dois monitores iguais: o número no
    # fim, para não confundir.
    vistos = {}
    for t in telas:
        if not t["rotulo"]:
            t["rotulo"] = ("Tela %d" if pt else "Display %d") % t["numero"]
        vistos.setdefault(t["rotulo"], []).append(t)
    for iguais in vistos.values():
        if len(iguais) > 1:
            for t in iguais:
                t["rotulo"] = "%s (%d)" % (t["rotulo"], t["numero"])
    return {"ok": True, "modo": modo_geral(telas), "espelho": tem_espelho(cfg),
            "confirmar": pendente, "espera": espera_volta(), "telas": telas}


# ------------------------------------------------------------- mudanças

def aplicar(args):
    """Manda tudo numa chamada só do kscreen-doctor (ele aplica de uma vez)."""
    if not args:
        return
    codigo, saida, erros = rodar([KSCREEN] + list(args))
    # O kscreen-doctor sai com 0 mesmo quando não acha a tela: confere o texto.
    texto = (saida + "\n" + erros).lower()
    if codigo != 0 or any(f in texto for f in ("not found", "applying config failed", "invalid config")):
        raise Erro("o kscreen-doctor não aceitou a mudança: " + ((erros or saida).strip().splitlines() or ["?"])[-1])


def achar_modo(o, largura, altura, hz_pedido=None, id_preferido=None):
    """O id do modo com esse tamanho e essa taxa (ou a melhor taxa)."""
    candidatos = [m for m in o.get("modes") or [] if tamanho(m) == (largura, altura)]
    if not candidatos:
        return None
    preferidas = {str(i) for i in (o.get("preferredModes") or [])}
    if id_preferido is not None:
        for m in candidatos:
            if str(m.get("id")) == str(id_preferido) and (hz_pedido is None or abs(taxa(m) - hz_pedido) < 0.5):
                return str(m.get("id"))
    if hz_pedido is not None:
        iguais = [m for m in candidatos if hz(m) == int(round(hz_pedido))]
        if iguais:
            # 60,00 ganha de 59,94; a do monitor ganha de todas.
            iguais.sort(key=lambda m: (str(m.get("id")) not in preferidas, abs(taxa(m) - hz_pedido)))
            return str(iguais[0].get("id"))
        return str(min(candidatos, key=lambda m: abs(taxa(m) - hz_pedido)).get("id"))
    for m in candidatos:
        if str(m.get("id")) in preferidas:
            return str(m.get("id"))
    return str(max(candidatos, key=taxa).get("id"))


def rearrumar(antes, depois):
    """Depois de uma tela mudar de tamanho, as vizinhas continuam encostadas.

    antes: {nome: (x, y, largura, altura)}; depois: {nome: (largura, altura)}.
    Devolve {nome: (x, y)} já com o canto de cima à esquerda em 0,0."""
    novo = {n: [r[0], r[1]] for n, r in antes.items()}
    for n in sorted(antes, key=lambda n: (antes[n][0], antes[n][1])):
        x, y, w, h = antes[n]
        vizinhas = [m for m in antes if m != n and antes[m][0] + antes[m][2] == x
                    and antes[m][1] < y + h and y < antes[m][1] + antes[m][3]]
        if vizinhas:
            novo[n][0] = max(novo[m][0] + depois[m][0] for m in vizinhas)
    for n in sorted(antes, key=lambda n: (antes[n][1], antes[n][0])):
        x, y, w, h = antes[n]
        vizinhas = [m for m in antes if m != n and antes[m][1] + antes[m][3] == y
                    and antes[m][0] < x + w and x < antes[m][0] + antes[m][2]]
        if vizinhas:
            novo[n][1] = max(novo[m][1] + depois[m][1] for m in vizinhas)
    return normalizar({n: tuple(p) for n, p in novo.items()})


def normalizar(posicoes):
    """O canto de cima à esquerda de todas as telas vai para 0,0."""
    if not posicoes:
        return {}
    menor_x = min(p[0] for p in posicoes.values())
    menor_y = min(p[1] for p in posicoes.values())
    return {n: (int(p[0]) - menor_x, int(p[1]) - menor_y) for n, p in posicoes.items()}


def args_posicoes(cfg, novas, todas=False):
    """As posições das telas ligadas (só as que mudaram, ou todas)."""
    args = []
    for o in conectadas(cfg):
        n = o.get("name")
        if n in novas and o.get("enabled"):
            pos = o.get("pos") or {}
            if todas or (int(pos.get("x") or 0), int(pos.get("y") or 0)) != tuple(novas[n]):
                args.append("output.%s.position.%d,%d" % (n, novas[n][0], novas[n][1]))
    return args


def args_com_rearrumo(cfg, alvo, largura=None, altura=None, escala=None, rotacao=None):
    """Posições novas de todas as telas ligadas, com o tamanho novo do alvo."""
    ligadas = [o for o in conectadas(cfg) if o.get("enabled")]
    if len(ligadas) < 2 or any(int(o.get("replicationSource") or 0) for o in ligadas):
        return []
    antes = {o["name"]: retangulo(o) for o in ligadas}
    if len({(r[0], r[1]) for r in antes.values()}) == 1:
        return []  # duplicadas pelo jeito simples: todas em 0,0
    depois = {n: (r[2], r[3]) for n, r in antes.items()}
    depois[alvo["name"]] = retangulo(alvo, largura, altura, escala, rotacao)[2:]
    return args_posicoes(cfg, rearrumar(antes, depois))


def foto_de(cfg):
    """O jeito de agora, para voltar se a pessoa não confirmar."""
    lista = conectadas(cfg)
    nomes_por_id = {int(o.get("id") or 0): o.get("name", "") for o in lista}
    telas = []
    for o in lista:
        m = modo_atual(o)
        w, h = tamanho(m)
        hdr_tem, hdr = hdr_de(o)
        pos = o.get("pos") or {}
        telas.append({
            "nome": o.get("name"), "ligada": bool(o.get("enabled")), "modo": str(o.get("currentModeId")),
            "largura": w, "altura": h, "taxa": taxa(m), "escala": float(o.get("scale") or 1),
            "rotacao": int(o.get("rotation") or 1), "x": int(pos.get("x") or 0), "y": int(pos.get("y") or 0),
            "prioridade": int(o.get("priority") or 0),
            "espelho": nomes_por_id.get(int(o.get("replicationSource") or 0), ""),
            "hdr_tem": hdr_tem, "hdr": hdr,
        })
    return {"telas": telas}


def args_restaurar(foto, cfg):
    atuais = {o.get("name"): o for o in conectadas(cfg)}
    espelho = tem_espelho(cfg)
    nomes_por_id = {int(o.get("id") or 0): o.get("name", "") for o in atuais.values()}
    args = []
    for t in foto.get("telas", []):
        o = atuais.get(t.get("nome"))
        if o is None:
            continue  # a tela foi desligada do cabo no meio tempo
        n = t["nome"]
        if not t.get("ligada"):
            args.append("output.%s.disable" % n)
            continue
        args.append("output.%s.enable" % n)
        mid = achar_modo(o, t.get("largura"), t.get("altura"), t.get("taxa"), t.get("modo"))
        if mid:
            args.append("output.%s.mode.%s" % (n, mid))
        args.append("output.%s.scale.%s" % (n, texto_escala(float(t.get("escala") or 1))))
        args.append("output.%s.rotation.%s" % (n, ROTACAO_DOCTOR.get(int(t.get("rotacao") or 1), "none")))
        args.append("output.%s.position.%d,%d" % (n, int(t.get("x") or 0), int(t.get("y") or 0)))
        if int(t.get("prioridade") or 0) >= 1:
            args.append("output.%s.priority.%d" % (n, int(t["prioridade"])))
        espelho_agora = nomes_por_id.get(int(o.get("replicationSource") or 0), "")
        if espelho and espelho_agora != (t.get("espelho") or ""):
            args.append("output.%s.mirror.%s" % (n, t.get("espelho") or "none"))
        hdr_tem, hdr_agora = hdr_de(o)
        if hdr_tem and t.get("hdr_tem") and bool(t.get("hdr")) != hdr_agora:
            args.append("output.%s.hdr.%s" % (n, "enable" if t.get("hdr") else "disable"))
    return args


def restaurar(foto):
    aplicar(args_restaurar(foto, ler_config()))


def soltar_volta(token):
    """O 'volta sozinho': um processo solto (setsid), fora dos Ajustes."""
    subprocess.Popen([sys.executable, "-I", "-S", os.path.abspath(__file__), "_volta", token],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True, close_fds=True, cwd="/")


def pendente_valido(dados):
    """Uma volta esquecida (o processo morreu) não vale como 'jeito de antes'."""
    return isinstance(dados, dict) and isinstance(dados.get("foto"), dict) and \
        float(dados.get("prazo") or 0) > time.time() - 5


def mudar_com_volta(cfg, args):
    """Muda o que pode deixar a tela preta, e volta em 15 s sem confirmação."""
    if not args:
        return
    caminho = arquivo_volta()
    antes = ler_json(caminho)
    # Mudanças em seguida voltam todas para o jeito de antes da primeira.
    foto = antes["foto"] if pendente_valido(antes) else foto_de(cfg)
    token = "%d-%d" % (os.getpid(), time.time_ns())
    gravar_json(caminho, {"foto": foto, "token": token, "prazo": time.time() + espera_volta()})
    try:
        aplicar(args)
    except Erro:
        if pendente_valido(antes):
            # A volta de antes pode já ter saído ao ver o token novo: solta outra
            # com o prazo de antes, para a mudança anterior ainda voltar.
            antes["token"] = token
            gravar_json(caminho, antes)
            soltar_volta(token)
        else:
            tirar(caminho)
        raise
    # Se havia uma volta esperando, o processo dela vê o token novo e sai sozinho.
    soltar_volta(token)


def tirar(caminho):
    try:
        os.unlink(caminho)
        return True
    except FileNotFoundError:
        return False


def pegar_volta():
    """Pega a volta pendente só para si (manter e voltar ao mesmo tempo: um ganha)."""
    caminho = arquivo_volta()
    meu = "%s.%d" % (caminho, os.getpid())
    try:
        os.rename(caminho, meu)
    except OSError:
        return None
    dados = ler_json(meu)
    tirar(meu)
    return dados if isinstance(dados, dict) and isinstance(dados.get("foto"), dict) else None


def conferir_volta():
    """Quantos segundos faltam para voltar (0 = nada para confirmar).

    Se o processo da volta tiver morrido e o prazo passou faz tempo, volta aqui."""
    dados = ler_json(arquivo_volta())
    if not isinstance(dados, dict):
        return 0
    falta = float(dados.get("prazo") or 0) - time.time()
    if falta > 0:
        return round(falta, 1)
    if falta < -3:
        pegos = pegar_volta()
        if pegos:
            try:
                restaurar(pegos["foto"])
            except Erro:
                pass
    return 0


def cmd_volta_espera(token):
    caminho = arquivo_volta()
    while True:
        dados = ler_json(caminho)
        if not isinstance(dados, dict) or dados.get("token") != token:
            return 0  # confirmou, voltou ou veio outra mudança (que tem a própria volta)
        falta = float(dados.get("prazo") or 0) - time.time()
        if falta <= 0:
            break
        time.sleep(min(falta, 0.2))
    meu = "%s.%s" % (caminho, token)
    try:
        os.rename(caminho, meu)
    except OSError:
        return 0
    dados = ler_json(meu)
    if not isinstance(dados, dict) or dados.get("token") != token:
        # Uma mudança nova chegou bem nessa hora: ela fica com a volta dela.
        try:
            os.rename(meu, caminho)
        except OSError:
            pass
        return 0
    tirar(meu)
    restaurar(dados["foto"])
    return 0


def cmd_manter():
    tirar(arquivo_volta())
    return 0


def cmd_voltar():
    dados = pegar_volta()
    if dados:
        restaurar(dados["foto"])
    return 0


def ligada(o):
    if not o.get("enabled"):
        raise Erro("a tela %s está desligada" % o.get("name"))


def cmd_resolucao(nome, texto, hz_texto=None):
    cfg = ler_config()
    o = achar(cfg, nome)
    ligada(o)
    m = re.fullmatch(r"(\d+)\s*[x×]\s*(\d+)", str(texto).strip())
    if not m:
        raise Uso("resolução inválida: " + str(texto))
    largura, altura = int(m.group(1)), int(m.group(2))
    pedido = None
    if hz_texto is not None:
        try:
            pedido = float(str(hz_texto).replace(",", "."))
        except ValueError:
            raise Uso("taxa inválida: " + str(hz_texto))
    elif hz(modo_atual(o)) in {hz(x) for x in o.get("modes") or [] if tamanho(x) == (largura, altura)}:
        pedido = float(hz(modo_atual(o)))  # muda só a resolução e mantém a taxa
    mid = achar_modo(o, largura, altura, pedido)
    if mid is None:
        raise Erro("a tela %s não tem %dx%d" % (nome, largura, altura))
    args = ["output.%s.mode.%s" % (nome, mid)]
    # A escala de agora pode não servir na resolução nova (4K a 200% vira
    # 1080p a 200%, enorme): vai para a sugerida mais perto. Mudando só a
    # taxa, a escala fica como está.
    escala = float(o.get("scale") or 1)
    sugeridas = escalas_sugeridas(largura, altura, None, polegadas_de(o))
    mudou_tamanho = tamanho(modo_atual(o)) != (largura, altura)
    if mudou_tamanho and all(abs(escala - e) > 0.001 for e in sugeridas):
        nova = min(sugeridas, key=lambda e: (abs(e - escala), e))
        if abs(nova - escala) > 0.001:
            args.append("output.%s.scale.%s" % (nome, texto_escala(nova)))
            escala = nova
    args += args_com_rearrumo(cfg, o, largura, altura, escala)
    mudar_com_volta(cfg, args)
    return 0


def cmd_escala(nome, texto):
    cfg = ler_config()
    o = achar(cfg, nome)
    ligada(o)
    valor = numero_escala(texto)
    args = ["output.%s.scale.%s" % (nome, texto_escala(valor))] + args_com_rearrumo(cfg, o, escala=valor)
    mudar_com_volta(cfg, args)
    return 0


def cmd_girar(nome, lado):
    cfg = ler_config()
    o = achar(cfg, nome)
    ligada(o)
    if lado not in GIRAR:
        raise Uso("use: girar <tela> normal|esquerda|direita|invertida")
    rotacao = GIRAR[lado]
    args = ["output.%s.rotation.%s" % (nome, ROTACAO_DOCTOR[rotacao])] + args_com_rearrumo(cfg, o, rotacao=rotacao)
    mudar_com_volta(cfg, args)
    return 0


def em_fila(ordem, tamanhos=None):
    """Põe as telas uma ao lado da outra, da esquerda para a direita."""
    tamanhos = tamanhos or {}
    x = 0
    posicoes = {}
    for o in ordem:
        posicoes[o["name"]] = (x, 0)
        x += tamanhos.get(o["name"], retangulo(o)[2:])[0]
    return posicoes


def cmd_modo(qual, nome=None):
    cfg = ler_config()
    lista = conectadas(cfg)
    if qual == "so":
        if not nome:
            raise Uso("use: modo so <tela>")
        alvo = achar(cfg, nome)
        args = ["output.%s.enable" % nome, "output.%s.priority.1" % nome, "output.%s.position.0,0" % nome]
        if tem_espelho(cfg) and int(alvo.get("replicationSource") or 0):
            args.append("output.%s.mirror.none" % nome)
        args += ["output.%s.disable" % o["name"] for o in lista if o["name"] != nome]
        mudar_com_volta(cfg, args)
        return 0
    if len(lista) < 2:
        raise Erro("só há uma tela ligada no cabo")
    principal = principal_de(cfg) or lista[0]
    if qual == "estender":
        memoria = ler_json(arquivo_antes_duplicar()) or {}
        args = []
        tamanhos = {}
        ligadas = sorted([o for o in lista if o.get("enabled")],
                         key=lambda o: (o["name"] != principal["name"], retangulo(o)[0], int(o.get("id") or 0)))
        ordem = ligadas + [o for o in lista if not o.get("enabled")]
        duplicadas = modo_da_config(cfg) == "duplicar"
        if duplicadas:
            ordem = [principal] + [o for o in lista if o["name"] != principal["name"]]
        for o in ordem:
            n = o["name"]
            args.append("output.%s.enable" % n)
            if tem_espelho(cfg) and int(o.get("replicationSource") or 0):
                args.append("output.%s.mirror.none" % n)
            guardado = memoria.get(n) if isinstance(memoria, dict) else None
            w, h = tamanho(modo_atual(o))
            escala = float(o.get("scale") or 1)
            if guardado and duplicadas:
                # Volta à resolução que a tela tinha antes de duplicar.
                mid = achar_modo(o, guardado.get("largura"), guardado.get("altura"), guardado.get("taxa"), guardado.get("modo"))
                if mid:
                    args.append("output.%s.mode.%s" % (n, mid))
                    w, h = guardado.get("largura"), guardado.get("altura")
                escala = float(guardado.get("escala") or escala)
                args.append("output.%s.scale.%s" % (n, texto_escala(escala)))
            elif not o.get("enabled") and modo_atual(o) is None:
                pref = resolucoes_de(o)
                if pref:
                    g = next((g for g in pref if g["preferida"]), pref[0])
                    mid = achar_modo(o, g["largura"], g["altura"])
                    args.append("output.%s.mode.%s" % (n, mid))
                    w, h = g["largura"], g["altura"]
            tamanhos[n] = logico(w, h, escala, o.get("rotation"))
        for i, o in enumerate(ligadas + [o for o in ordem if o not in ligadas]):
            args.append("output.%s.priority.%d" % (o["name"], i + 1))
        for n, (x, y) in em_fila(ordem, tamanhos).items():
            args.append("output.%s.position.%d,%d" % (n, x, y))
        tirar(arquivo_antes_duplicar())
        mudar_com_volta(cfg, args)
        return 0
    if qual == "duplicar":
        outras = [o for o in lista if o["name"] != principal["name"]]
        if tem_espelho(cfg) and os.environ.get("MATSU_TELAS_SEM_ESPELHO") != "1":
            args = ["output.%s.enable" % principal["name"]]
            for o in outras:
                args += ["output.%s.enable" % o["name"], "output.%s.mirror.%s" % (o["name"], principal["name"])]
            mudar_com_volta(cfg, args)
            depois = {o.get("name"): o for o in conectadas(ler_config())}
            pega = all(int(depois.get(o["name"], {}).get("replicationSource") or 0) == int(principal.get("id") or -1)
                       for o in outras)
            if pega:
                return 0
            cfg = ler_config()  # o KWin não espelhou: vai pelo jeito simples
        duplicar_simples(cfg, principal, [o for o in conectadas(cfg) if o["name"] != principal["name"]])
        return 0
    raise Uso("use: modo estender|duplicar|so <tela>")


def duplicar_simples(cfg, principal, outras):
    """Sem espelho no KWin: a mesma resolução nas telas, todas em 0,0."""
    todas = [principal] + outras
    comuns = None
    for o in todas:
        tamanhos = {tamanho(m) for m in o.get("modes") or []}
        comuns = tamanhos if comuns is None else comuns & tamanhos
    comuns = {t for t in (comuns or set()) if t[0] > 0 and t[1] > 0}
    if not comuns:
        raise Erro("as telas não têm nenhuma resolução em comum")
    atual = tamanho(modo_atual(principal))
    w, h = atual if atual in comuns else max(comuns, key=lambda t: (t[0] * t[1], t[0]))
    memoria = {}
    for o in todas:
        m = modo_atual(o)
        mw, mh = tamanho(m)
        memoria[o["name"]] = {"modo": str(o.get("currentModeId")), "largura": mw, "altura": mh,
                              "taxa": taxa(m), "escala": float(o.get("scale") or 1)}
    escala = texto_escala(float(principal.get("scale") or 1))
    rotacao = ROTACAO_DOCTOR.get(int(principal.get("rotation") or 1), "none")
    args = []
    for o in todas:
        n = o["name"]
        mid = achar_modo(o, w, h, float(hz(modo_atual(o))) if modo_atual(o) else None)
        args += ["output.%s.enable" % n, "output.%s.mode.%s" % (n, mid), "output.%s.scale.%s" % (n, escala),
                 "output.%s.rotation.%s" % (n, rotacao), "output.%s.position.0,0" % n]
    gravar_json(arquivo_antes_duplicar(), memoria)
    mudar_com_volta(cfg, args)


def cmd_principal(nome):
    cfg = ler_config()
    alvo = achar(cfg, nome)
    ligada(alvo)
    outras = sorted([o for o in conectadas(cfg) if o.get("enabled") and o["name"] != nome],
                    key=lambda o: (int(o.get("priority") or 99) or 99, int(o.get("id") or 0)))
    args = ["output.%s.priority.1" % nome]
    args += ["output.%s.priority.%d" % (o["name"], i + 2) for i, o in enumerate(outras)]
    aplicar(args)
    return 0


def cmd_posicoes(pedidos):
    if not pedidos:
        raise Uso("use: posicoes <tela>:<x>,<y> [...]")
    cfg = ler_config()
    novas = {}
    for p in pedidos:
        m = re.fullmatch(r"([A-Za-z0-9_-]+):(-?\d+),(-?\d+)", p)
        if not m:
            raise Uso("posição inválida: " + p)
        o = achar(cfg, m.group(1))
        ligada(o)
        novas[o["name"]] = (int(m.group(2)), int(m.group(3)))
    # As que não vieram ficam onde estão (e entram na conta do 0,0).
    for o in conectadas(cfg):
        if o.get("enabled") and o["name"] not in novas:
            novas[o["name"]] = retangulo(o)[:2]
    aplicar(args_posicoes(cfg, normalizar(novas), todas=True))
    return 0


def cmd_vrr(nome, valor):
    if valor not in ("on", "off"):
        raise Uso("use: vrr <tela> on|off")
    cfg = ler_config()
    o = achar(cfg, nome)
    if not vrr_de(o)[0]:
        raise Erro("a tela %s não tem sincronia adaptativa" % nome)
    # "Automático" é o jeito do KDE: liga nos jogos e vídeos em tela cheia.
    aplicar(["output.%s.vrrpolicy.%s" % (nome, "automatic" if valor == "on" else "never")])
    return 0


def cmd_hdr(nome, valor):
    if valor not in ("on", "off"):
        raise Uso("use: hdr <tela> on|off")
    cfg = ler_config()
    o = achar(cfg, nome)
    ligada(o)
    if not hdr_de(o)[0]:
        raise Erro("a tela %s não tem HDR" % nome)
    mudar_com_volta(cfg, ["output.%s.hdr.%s" % (nome, "enable" if valor == "on" else "disable")])
    return 0


def cmd_identificar():
    """O nome do conector (HDMI-A-1...) em cima de cada tela por uns segundos:
    o efeito do KWin que o "Identificar" dos ajustes do KDE usa. Se o efeito
    estiver desligado, liga e tenta de novo; no Plasma antigo, o OSD do KScreen.
    Se nada disso houver, não faz nada."""
    mostrar = ["call", "org.kde.KWin", "/org/kde/KWin/Effect/OutputLocator1",
               "org.kde.KWin.Effect.OutputLocator1", "show"]
    tentativas = [
        mostrar,
        ["call", "org.kde.KWin", "/Effects", "org.kde.kwin.Effects", "loadEffect", "s", "outputlocator"],
        mostrar,
        ["call", "org.kde.kscreen.osdService", "/org/kde/kscreen/osdService",
         "org.kde.kscreen.osdService", "showOutputIdentifiers"],
    ]
    for i, t in enumerate(tentativas):
        codigo, _, _ = rodar([BUSCTL, "--user", "--timeout=3"] + t)
        if codigo == 0 and i != 1:
            return 0
    return 0


USO = """use: ajudante.py estado
       ajudante.py resolucao <tela> <LxA> [hz]
       ajudante.py escala <tela> <1.25>
       ajudante.py girar <tela> normal|esquerda|direita|invertida
       ajudante.py modo estender|duplicar|so <tela>
       ajudante.py principal <tela>
       ajudante.py posicoes <tela>:<x>,<y> [<tela>:<x>,<y>...]
       ajudante.py vrr <tela> on|off
       ajudante.py hdr <tela> on|off
       ajudante.py identificar | manter | voltar"""


def main(argv):
    cmd = argv[0] if argv else "estado"
    args = argv[1:]

    def precisa(n_min, n_max=None):
        if len(args) < n_min or len(args) > (n_max if n_max is not None else n_min):
            raise Uso(USO)

    try:
        if cmd == "estado":
            print(json.dumps(estado(), separators=(",", ":")))
            return 0
        if cmd == "resolucao":
            precisa(2, 3)
            return cmd_resolucao(*args)
        if cmd == "escala":
            precisa(2)
            return cmd_escala(*args)
        if cmd == "girar":
            precisa(2)
            return cmd_girar(*args)
        if cmd == "modo":
            precisa(1, 2)
            return cmd_modo(*args)
        if cmd == "principal":
            precisa(1)
            return cmd_principal(*args)
        if cmd == "posicoes":
            return cmd_posicoes(args)
        if cmd == "vrr":
            precisa(2)
            return cmd_vrr(*args)
        if cmd == "hdr":
            precisa(2)
            return cmd_hdr(*args)
        if cmd == "identificar":
            return cmd_identificar()
        if cmd == "manter":
            return cmd_manter()
        if cmd == "voltar":
            return cmd_voltar()
        if cmd == "_volta":
            precisa(1)
            return cmd_volta_espera(args[0])
        if cmd in ("-h", "--help", "ajuda"):
            print(USO)
            return 0
        raise Uso(USO)
    except Uso as e:
        print(str(e), file=sys.stderr)
        return 2
    except Erro as e:
        print("monitores: " + str(e), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
