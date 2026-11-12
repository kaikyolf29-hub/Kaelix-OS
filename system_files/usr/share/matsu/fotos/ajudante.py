#!/usr/bin/python3
"""Fotos do Matsu: o ajudante que acha as fotos e mexe nos arquivos.

A janela (os arquivos .qml desta pasta) só desenha. Quem varre a pasta Imagens,
lê o tamanho de cada foto no cabeçalho do arquivo (PNG, JPEG, GIF, WebP, BMP,
TIFF, AVIF/HEIF, ICO, SVG) e a data em que ela foi tirada (EXIF do JPEG), manda
para a Lixeira e copia é este script. Só usa a biblioteca padrão do Python e
responde em JSON. O que ele já leu fica guardado num cache (só relê a foto que
mudou), em ~/.cache/matsu/fotos/indice.json.

Uso:
  ajudante.py listar <pasta das imagens> [<pasta dos vídeos>]
                                      as fotos (com subpastas), os álbuns e os vídeos
  ajudante.py vizinhas <arquivo>      as imagens da pasta do arquivo, em ordem de nome
                                      (para abrir uma imagem direto no visualizador)
  ajudante.py lixeira <arquivo>       manda para a Lixeira (gio trash; plano B: kioclient)
  ajudante.py restaurar <arquivo>     traz de volta da Lixeira (o "Desfazer")
  ajudante.py copiar <arquivo>        põe a imagem na área de transferência (wl-copy ou xclip)
  ajudante.py capas <vídeo> [...]     miniaturas dos vídeos (com o ffmpeg, se existir)
"""
import calendar
import hashlib
import io
import json
import mimetypes
import os
import re
import shutil
import struct
import subprocess
import sys
import time
import urllib.parse

VERSAO_CACHE = 2

IMAGENS = {
    "jpg", "jpeg", "jpe", "jfif", "png", "apng", "gif", "webp", "bmp", "dib", "svg", "svgz", "tif", "tiff",
    "avif", "heic", "heif", "ico", "cur", "jxl", "qoi", "tga", "psd", "xcf", "kra", "ora", "exr", "hdr",
    "pcx", "pbm", "pgm", "ppm", "pnm", "xbm", "xpm", "jp2", "dds", "ras", "dng", "cr2", "cr3", "nef", "arw",
    "orf", "rw2", "raf", "srw", "pef",
}
VIDEOS = {"mp4", "m4v", "mkv", "webm", "mov", "avi", "ogv", "wmv", "mpg", "mpeg", "3gp", "ts", "mts", "m2ts", "flv"}

# Onde ficam as capturas de tela (o Spectacle grava em "Imagens/Capturas de tela").
PASTAS_CAPTURA = {"capturas de tela", "capturas de ecrã", "capturas de ecra", "screenshots", "screenshot",
                  "capturas", "captures d'écran", "capturas de pantalla", "bildschirmfotos"}
NOME_CAPTURA = re.compile(r"^(captura de tela|captura de ecr[ãa]|captura|screenshot|screen ?shot|bildschirmfoto"
                          r"|spectacle|scrot|flameshot)", re.IGNORECASE)


# ----- o ambiente -----

def ler(caminho, padrao=""):
    try:
        with open(caminho, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return padrao


def casa():
    return os.environ.get("HOME") or os.path.expanduser("~")


def config_casa():
    return os.environ.get("XDG_CONFIG_HOME") or os.path.join(casa(), ".config")


def cache_casa():
    return os.environ.get("XDG_CACHE_HOME") or os.path.join(casa(), ".cache")


def dados_casa():
    return os.environ.get("XDG_DATA_HOME") or os.path.join(casa(), ".local", "share")


# As cores do vidro do Matsu (as mesmas do "matsu vidro").
CORES_VIDRO = {"azul": "#2f80ed", "roxo": "#8b5cf6", "rosa": "#ec4899", "vermelho": "#ef4444", "laranja": "#f97316",
               "amarelo": "#eab308", "verde": "#22c55e", "grafite": "#6b7280"}


def vidro():
    """A cor e a transparência do vidro que a pessoa escolheu (matsu vidro / Ajustes)."""
    pasta = os.environ.get("MATSU_STATE_DIR") or os.path.join(config_casa(), "matsu")
    valores = {}
    for linha in ler(os.path.join(pasta, "vidro")).splitlines():
        chave, _, valor = linha.partition("=")
        valores[chave.strip()] = valor.strip().lower()
    cor = valores.get("cor", "")
    cor = CORES_VIDRO.get(cor, cor if re.fullmatch(r"#[0-9a-f]{6}", cor) else "")
    nivel = valores.get("transparencia", "normal")
    return {"cor": cor, "nivel": nivel if nivel in ("mais", "normal", "menos", "sem") else "normal"}


def idioma():
    """pt ou en, como a central de controle: o ambiente e, se faltar, o plasma-localerc."""
    primeiro = os.environ.get("LANGUAGE", "").split(":")[0]
    lingua = ""
    for valor in (os.environ.get("MATSU_LANG"), os.environ.get("LC_ALL"), os.environ.get("LC_MESSAGES"),
                  primeiro, os.environ.get("LANG")):
        if valor and not valor.startswith("C") and valor != "POSIX":
            lingua = valor
            break
    if not lingua:
        for arquivo in (os.path.join(config_casa(), "plasma-localerc"), "/etc/xdg/plasma-localerc"):
            for linha in ler(arquivo).splitlines():
                if linha.startswith(("LANGUAGE=", "LANG=")):
                    lingua = linha.split("=", 1)[1]
                    break
            if lingua:
                break
    return "pt" if lingua.startswith("pt") else "en"


def extensao(nome):
    return nome.rsplit(".", 1)[-1].lower() if "." in nome else ""


def ordem_natural(texto):
    """Chave para ordenar "foto 2" antes de "foto 10", sem ligar para maiúsculas."""
    return [int(p) if p.isdigit() else p for p in re.split(r"(\d+)", texto.casefold())]


# ----- o cabeçalho das imagens -----

def ler_ifd(f, base, posicao, e, tags):
    """Lê um diretório do TIFF/EXIF (as etiquetas que interessam) para o dicionário tags."""
    f.seek(base + posicao)
    bruto = f.read(2)
    if len(bruto) < 2:
        return
    n = struct.unpack(e + "H", bruto)[0]
    if n > 1000:
        return
    entradas = f.read(12 * n)
    for i in range(len(entradas) // 12):
        tag, tipo, conta = struct.unpack(e + "HHI", entradas[i * 12:i * 12 + 8])
        valor = entradas[i * 12 + 8:i * 12 + 12]
        if tag not in (0x0100, 0x0101, 0x0112, 0x0132, 0x8769, 0x9003, 0x9004, 0x9011, 0xA002, 0xA003):
            continue
        if tipo == 3:  # SHORT
            tags.setdefault(tag, struct.unpack(e + "H", valor[:2])[0])
        elif tipo == 4:  # LONG
            tags.setdefault(tag, struct.unpack(e + "I", valor)[0])
        elif tipo == 2:  # texto
            if conta <= 4:
                texto = valor[:conta]
            else:
                volta = f.tell()
                f.seek(base + struct.unpack(e + "I", valor)[0])
                texto = f.read(min(conta, 64))
                f.seek(volta)
            tags.setdefault(tag, texto.split(b"\0")[0].decode("ascii", "replace").strip())


def ler_tiff(f, base=0):
    """As etiquetas de um bloco TIFF (o arquivo .tif ou o EXIF de dentro do JPEG)."""
    f.seek(base)
    cab = f.read(8)
    if len(cab) < 8 or cab[:2] not in (b"II", b"MM"):
        return {}
    e = "<" if cab[:2] == b"II" else ">"
    if struct.unpack(e + "H", cab[2:4])[0] != 42:
        return {}
    tags = {}
    try:
        ler_ifd(f, base, struct.unpack(e + "I", cab[4:8])[0], e, tags)
        if isinstance(tags.get(0x8769), int):
            ler_ifd(f, base, tags[0x8769], e, tags)
    except (struct.error, OSError, ValueError):
        pass
    return tags


def data_exif(tags):
    """Quando a foto foi tirada (DateTimeOriginal), em segundos desde 1970; 0 se não tiver."""
    for tag in (0x9003, 0x9004, 0x0132):
        texto = tags.get(tag)
        if not isinstance(texto, str):
            continue
        m = re.match(r"(\d{4})[:\-](\d\d)[:\-](\d\d)[ T](\d\d):(\d\d):(\d\d)", texto)
        if not m or m.group(1) == "0000":
            continue
        partes = tuple(int(x) for x in m.groups())
        try:
            fuso = tags.get(0x9011) if tag == 0x9003 else None
            if isinstance(fuso, str) and re.fullmatch(r"[+-]\d\d:\d\d", fuso):
                sinal = -1 if fuso[0] == "-" else 1
                desvio = sinal * (int(fuso[1:3]) * 3600 + int(fuso[4:6]) * 60)
                return calendar.timegm(partes + (0, 0, 0)) - desvio
            return int(time.mktime(partes + (0, 0, -1)))
        except (ValueError, OverflowError):
            continue
    return 0


def cabecalho_jpeg(f):
    largura = altura = data = 0
    orientacao = 1
    f.seek(2)
    while True:
        marca = f.read(2)
        if len(marca) < 2 or marca[0] != 0xFF:
            break
        tipo = marca[1]
        while tipo == 0xFF:  # enchimento
            b = f.read(1)
            if not b:
                return largura, altura, data, orientacao
            tipo = b[0]
        if tipo in (0xD8, 0x01) or 0xD0 <= tipo <= 0xD7:
            continue
        if tipo in (0xD9, 0xDA):  # fim, começo da imagem em si
            break
        bruto = f.read(2)
        if len(bruto) < 2:
            break
        tam = struct.unpack(">H", bruto)[0]
        if tam < 2:
            break
        inicio = f.tell()
        if tipo == 0xE1 and not data:
            bloco = f.read(min(tam - 2, 65536))
            if bloco[:6] == b"Exif\0\0":
                tags = ler_tiff(io.BytesIO(bloco), 6)
                data = data_exif(tags)
                if isinstance(tags.get(0x0112), int):
                    orientacao = tags[0x0112]
        elif 0xC0 <= tipo <= 0xCF and tipo not in (0xC4, 0xC8, 0xCC):
            bloco = f.read(5)
            if len(bloco) == 5:
                altura, largura = struct.unpack(">HH", bloco[1:5])
            break
        f.seek(inicio + tam - 2)
    return largura, altura, data, orientacao


def cabecalho_isobmff(dados):
    """AVIF e HEIF: o maior "ispe" (a imagem principal; os menores são miniaturas)."""
    melhor = (0, 0)
    pos = dados.find(b"ispe")
    while pos >= 4 and pos + 16 <= len(dados):
        w, h = struct.unpack(">II", dados[pos + 8:pos + 16])
        if w * h > melhor[0] * melhor[1] and w < 100000 and h < 100000:
            melhor = (w, h)
        pos = dados.find(b"ispe", pos + 4)
    girar = 1
    pos = dados.find(b"irot")
    if pos >= 4 and pos + 5 <= len(dados) and dados[pos + 4] & 1:
        girar = 6  # 90 ou 270 graus: largura e altura trocam
    return melhor[0], melhor[1], girar


def medida_svg(valor):
    m = re.match(r"\s*([0-9.]+)\s*(px|pt|mm|cm|in)?\s*$", valor or "")
    if not m:
        return 0
    fator = {"pt": 1.333, "mm": 3.78, "cm": 37.8, "in": 96}.get(m.group(2), 1)
    try:
        return int(round(float(m.group(1)) * fator))
    except ValueError:
        return 0


def cabecalho_svg(dados):
    texto = dados.decode("utf-8", "replace")
    m = re.search(r"<svg\b[^>]*>", texto, re.S)
    if not m:
        return 0, 0
    tag = m.group(0)

    def atributo(nome):
        a = re.search(r"\s" + nome + r"\s*=\s*[\"']([^\"']*)[\"']", tag)
        return a.group(1) if a else ""

    w, h = medida_svg(atributo("width")), medida_svg(atributo("height"))
    if not (w and h):
        caixa = atributo("viewBox").replace(",", " ").split()
        if len(caixa) == 4:
            try:
                w, h = int(round(float(caixa[2]))), int(round(float(caixa[3])))
            except ValueError:
                pass
    return max(0, w), max(0, h)


def cabecalho(caminho):
    """(largura, altura, data da foto, orientação EXIF) do arquivo; zeros se não der para ler.
    A largura e a altura já vêm como a foto aparece (de pé, se o EXIF manda girar)."""
    largura = altura = data = 0
    orientacao = 1
    try:
        with open(caminho, "rb") as f:
            cab = f.read(32)
            if cab[:8] == b"\x89PNG\r\n\x1a\n" and cab[12:16] == b"IHDR":
                largura, altura = struct.unpack(">II", cab[16:24])
            elif cab[:2] == b"\xff\xd8":
                largura, altura, data, orientacao = cabecalho_jpeg(f)
            elif cab[:6] in (b"GIF87a", b"GIF89a"):
                largura, altura = struct.unpack("<HH", cab[6:10])
            elif cab[:4] == b"RIFF" and cab[8:12] == b"WEBP":
                pedaco = cab[12:16]
                if pedaco == b"VP8 ":
                    largura, altura = (v & 0x3FFF for v in struct.unpack("<HH", cab[26:30]))
                elif pedaco == b"VP8L":
                    b = cab[21:25]
                    bits = struct.unpack("<I", b)[0]
                    largura, altura = (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
                elif pedaco == b"VP8X":
                    largura = 1 + int.from_bytes(cab[24:27], "little")
                    altura = 1 + int.from_bytes(cab[27:30], "little")
            elif cab[:2] == b"BM" and len(cab) >= 26:
                largura, altura = struct.unpack("<ii", cab[18:26])
                altura = abs(altura)
            elif cab[:4] in (b"II*\0", b"MM\0*"):
                tags = ler_tiff(f, 0)
                largura, altura = tags.get(0x0100, 0), tags.get(0x0101, 0)
                data = data_exif(tags)
                orientacao = tags.get(0x0112, 1) if isinstance(tags.get(0x0112), int) else 1
            elif cab[4:8] == b"ftyp":
                f.seek(0)
                largura, altura, orientacao = cabecalho_isobmff(f.read(262144))
            elif cab[:4] == b"\0\0\1\0":
                n = struct.unpack("<H", cab[4:6])[0]
                f.seek(6)
                for _ in range(min(n, 64)):
                    entrada = f.read(16)
                    if len(entrada) < 16:
                        break
                    w, h = entrada[0] or 256, entrada[1] or 256
                    if w * h > largura * altura:
                        largura, altura = w, h
            elif extensao(caminho) in ("svg", "svgz") or cab.lstrip()[:5] in (b"<?xml", b"<svg ", b"<svg\n"):
                if cab[:2] == b"\x1f\x8b":
                    return 0, 0, 0, 1
                f.seek(0)
                largura, altura = cabecalho_svg(f.read(8192))
    except (OSError, struct.error, ValueError):
        return 0, 0, 0, 1
    if not isinstance(largura, int) or not isinstance(altura, int) or largura <= 0 or altura <= 0:
        largura = altura = 0
    if orientacao not in range(1, 9):
        orientacao = 1
    if orientacao >= 5:
        largura, altura = altura, largura
    return largura, altura, data, orientacao


# ----- as miniaturas que o KDE (Dolphin) já fez -----

def uri(caminho):
    return "file://" + urllib.parse.quote(caminho, safe="/!$&'()*+,;=:@~")


def mtime_da_miniatura(caminho):
    """O Thumb::MTime gravado no PNG da miniatura (a data do arquivo de quando ela foi feita)."""
    try:
        with open(caminho, "rb") as f:
            if f.read(8) != b"\x89PNG\r\n\x1a\n":
                return None
            for _ in range(32):
                cab = f.read(8)
                if len(cab) < 8:
                    return None
                tam, tipo = struct.unpack(">I4s", cab)
                if tipo == b"IDAT":
                    return None
                corpo = f.read(tam)
                f.seek(4, 1)
                if tipo == b"tEXt":
                    chave, _, valor = corpo.partition(b"\0")
                    if chave == b"Thumb::MTime":
                        return int(valor.decode("ascii", "replace").strip() or "0")
    except (OSError, ValueError, struct.error):
        pass
    return None


def miniatura(caminho, mtime):
    """A melhor miniatura do padrão freedesktop que já existe e está em dia: (arquivo, lado)."""
    nome = hashlib.md5(uri(caminho).encode("utf-8")).hexdigest() + ".png"
    pasta = os.path.join(cache_casa(), "thumbnails")
    for sub, lado in (("x-large", 512), ("large", 256), ("xx-large", 1024)):
        arquivo = os.path.join(pasta, sub, nome)
        if os.path.isfile(arquivo):
            marca = mtime_da_miniatura(arquivo)
            if marca is None or marca == int(mtime):
                return arquivo, lado
    return "", 0


# ----- o cache -----

def arquivo_cache():
    return os.path.join(cache_casa(), "matsu", "fotos", "indice.json")


def abrir_cache():
    try:
        with open(arquivo_cache(), "r", encoding="utf-8") as f:
            dados = json.load(f)
        if dados.get("versao") == VERSAO_CACHE and isinstance(dados.get("itens"), dict):
            return dados["itens"]
    except (OSError, ValueError, AttributeError):
        pass
    return {}


def gravar_cache(itens):
    destino = arquivo_cache()
    try:
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        temp = destino + ".%d.tmp" % os.getpid()
        with open(temp, "w", encoding="utf-8") as f:
            json.dump({"versao": VERSAO_CACHE, "itens": itens}, f, ensure_ascii=False, separators=(",", ":"))
        os.replace(temp, destino)
    except OSError:
        pass


# ----- uma foto -----

def eh_captura(nome, pasta_rel):
    partes = [p.casefold() for p in pasta_rel.split(os.sep) if p]
    if any(p in PASTAS_CAPTURA for p in partes):
        return True
    return bool(NOME_CAPTURA.match(nome))


def descrever(caminho, st, cache, raiz=""):
    """O dicionário de uma foto (usa o cache se o arquivo não mudou). Devolve (foto, mudou)."""
    nome = os.path.basename(caminho)
    pasta = os.path.dirname(caminho)
    chave = [st.st_size, st.st_mtime_ns]
    guardado = cache.get(caminho)
    mudou = False
    if isinstance(guardado, list) and len(guardado) == 6 and guardado[:2] == chave:
        largura, altura, data, orientacao = guardado[2:]
    else:
        largura, altura, data, orientacao = cabecalho(caminho)
        cache[caminho] = chave + [largura, altura, data, orientacao]
        mudou = True
    rel = os.path.relpath(pasta, raiz) if raiz else ""
    rel = "" if rel in (".", "") or rel.startswith("..") else rel
    mini, lado = miniatura(caminho, st.st_mtime)
    foto = {
        "caminho": caminho,
        "nome": nome,
        "pasta": pasta,
        "album": rel.split(os.sep)[0] if rel else "",
        "tamanho": st.st_size,
        "mtime": int(st.st_mtime),
        "data": int(data or st.st_mtime),
        "exif": bool(data),
        "largura": largura,
        "altura": altura,
        "orientacao": orientacao,
        "captura": eh_captura(nome, rel),
        "tipo": extensao(nome),
        "mini": mini,
        "miniLado": lado,
    }
    return foto, mudou


def varrer(raiz, tipos):
    """Os arquivos com estas extensões dentro da pasta e das subpastas (sem as escondidas)."""
    achados = []
    if not raiz or not os.path.isdir(raiz):
        return achados
    for pasta, subpastas, arquivos in os.walk(raiz):
        subpastas[:] = sorted(s for s in subpastas if not s.startswith("."))
        for nome in arquivos:
            if nome.startswith(".") or extensao(nome) not in tipos:
                continue
            caminho = os.path.join(pasta, nome)
            try:
                st = os.stat(caminho)
            except OSError:
                continue
            if st.st_size > 0:
                achados.append((caminho, st))
    return achados


def pasta_imagens(pedida):
    if pedida and os.path.isdir(pedida):
        return os.path.abspath(pedida)
    for nome in ("Imagens", "Pictures", "Fotos"):
        caminho = os.path.join(casa(), nome)
        if os.path.isdir(caminho):
            return caminho
    return os.path.abspath(pedida) if pedida else ""


def ordenar(fotos):
    fotos.sort(key=lambda f: (-f["data"], ordem_natural(f["nome"])))
    return fotos


def albuns_de(fotos, raiz):
    grupos = {}
    for f in fotos:
        if f["album"]:
            grupos.setdefault(f["album"], []).append(f)
    lista = []
    for nome, itens in grupos.items():
        capa = max(itens, key=lambda f: f["data"])
        lista.append({
            "nome": nome,
            "caminho": os.path.join(raiz, nome),
            "quantidade": len(itens),
            "tamanho": sum(f["tamanho"] for f in itens),
            "data": capa["data"],
            "capa": capa["caminho"],
            "capaMini": capa["mini"],
            "capaLado": capa["miniLado"],
            "capaLargura": capa["largura"],
            "capaAltura": capa["altura"],
            "capturas": all(f["captura"] for f in itens),
        })
    lista.sort(key=lambda a: -a["data"])
    return lista


# ----- vídeos -----

def pasta_capas():
    return os.path.join(cache_casa(), "matsu", "fotos", "videos")


def arquivo_capa(caminho, mtime):
    nome = hashlib.md5(("%s|%d" % (caminho, int(mtime))).encode("utf-8")).hexdigest()
    return os.path.join(pasta_capas(), nome + ".jpg")


def descrever_video(caminho, st):
    capa = arquivo_capa(caminho, st.st_mtime)
    if not os.path.isfile(capa):
        capa, _ = miniatura(caminho, st.st_mtime)
    return {
        "caminho": caminho,
        "nome": os.path.basename(caminho),
        "pasta": os.path.dirname(caminho),
        "tamanho": st.st_size,
        "mtime": int(st.st_mtime),
        "data": int(st.st_mtime),
        "tipo": extensao(caminho),
        "capa": capa,
        "video": True,
    }


def fazer_capas(caminhos):
    """Uma foto do começo de cada vídeo, com o ffmpeg (se não tiver, fica sem capa)."""
    resultado = {}
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        return {"ok": False, "erro": "sem-ffmpeg", "capas": resultado}
    os.makedirs(pasta_capas(), exist_ok=True)
    for caminho in caminhos:
        try:
            st = os.stat(caminho)
        except OSError:
            continue
        destino = arquivo_capa(caminho, st.st_mtime)
        if os.path.isfile(destino):
            resultado[caminho] = destino
            continue
        temp = destino + ".tmp.jpg"
        for inicio in ("1", "0"):
            try:
                r = subprocess.run([ffmpeg, "-nostdin", "-loglevel", "error", "-y", "-ss", inicio, "-i", caminho,
                                    "-frames:v", "1", "-vf", "scale='min(640,iw)':-2", temp],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
            except (OSError, subprocess.TimeoutExpired):
                break
            if r.returncode == 0 and os.path.isfile(temp) and os.path.getsize(temp) > 0:
                os.replace(temp, destino)
                resultado[caminho] = destino
                break
        if os.path.exists(temp):
            os.remove(temp)
    return {"ok": True, "capas": resultado}


# ----- os comandos -----

def listar(pasta, pasta_videos=""):
    raiz = pasta_imagens(pasta)
    cache = abrir_cache()
    mudou = False
    fotos = []
    vistos = set()
    for caminho, st in varrer(raiz, IMAGENS):
        foto, m = descrever(caminho, st, cache, raiz)
        fotos.append(foto)
        vistos.add(caminho)
        mudou = mudou or m
    # Esquece o que sumiu da pasta (o que é de fora, das "vizinhas", fica até o limite).
    for caminho in [c for c in cache if c not in vistos and (not raiz or c.startswith(raiz + os.sep))]:
        del cache[caminho]
        mudou = True
    if len(cache) > 60000:
        for caminho in [c for c in cache if c not in vistos][: len(cache) - 60000]:
            del cache[caminho]
        mudou = True
    if mudou:
        gravar_cache(cache)
    ordenar(fotos)
    videos = []
    if pasta_videos and os.path.isdir(pasta_videos):
        videos = [descrever_video(c, st) for c, st in varrer(pasta_videos, VIDEOS)]
        videos.sort(key=lambda v: (-v["data"], ordem_natural(v["nome"])))
    return {
        "idioma": idioma(),
        "vidro": vidro(),
        "raiz": raiz,
        "existe": bool(raiz) and os.path.isdir(raiz),
        "fotos": fotos,
        "albuns": albuns_de(fotos, raiz),
        "videos": videos,
        "temFfmpeg": bool(shutil.which("ffmpeg")),
    }


def vizinhas(arquivo):
    """As imagens (e vídeos) da pasta do arquivo, em ordem de nome, e a posição dele."""
    if arquivo.startswith("file://"):
        arquivo = urllib.parse.unquote(urllib.parse.urlparse(arquivo).path)
    arquivo = os.path.abspath(arquivo)
    pasta = os.path.dirname(arquivo)
    cache = abrir_cache()
    mudou = False
    itens = []
    try:
        nomes = os.listdir(pasta)
    except OSError:
        nomes = [os.path.basename(arquivo)] if os.path.isfile(arquivo) else []
    for nome in nomes:
        caminho = os.path.join(pasta, nome)
        tipo = extensao(nome)
        if caminho != arquivo and (nome.startswith(".") or tipo not in IMAGENS | VIDEOS):
            continue
        try:
            st = os.stat(caminho)
        except OSError:
            continue
        if not os.path.isfile(caminho):
            continue
        if tipo in VIDEOS:
            itens.append(descrever_video(caminho, st))
        else:
            foto, m = descrever(caminho, st, cache)
            itens.append(foto)
            mudou = mudou or m
    if mudou:
        gravar_cache(cache)
    itens.sort(key=lambda f: ordem_natural(f["nome"]))
    indice = next((i for i, f in enumerate(itens) if f["caminho"] == arquivo), -1)
    return {"idioma": idioma(), "vidro": vidro(), "pasta": pasta, "arquivo": arquivo, "indice": indice, "fotos": itens}


def pastas_lixeira(caminho):
    """As lixeiras onde o arquivo pode ter ido: a de casa e a do disco dele (padrão freedesktop)."""
    lista = [(os.path.join(dados_casa(), "Trash"), "")]
    topo = os.path.dirname(os.path.abspath(caminho))
    while topo != os.path.dirname(topo) and not os.path.ismount(topo):
        topo = os.path.dirname(topo)
    uid = os.getuid()
    for pasta in (os.path.join(topo, ".Trash", str(uid)), os.path.join(topo, ".Trash-%d" % uid)):
        if os.path.isdir(pasta):
            lista.append((pasta, topo))
    return lista


def achar_na_lixeira(caminho):
    """(arquivo na lixeira, .trashinfo) da última vez que este caminho foi para a Lixeira."""
    caminho = os.path.abspath(caminho)
    melhor = None
    for pasta, topo in pastas_lixeira(caminho):
        infos = os.path.join(pasta, "info")
        try:
            nomes = os.listdir(infos)
        except OSError:
            continue
        for nome in nomes:
            if not nome.endswith(".trashinfo"):
                continue
            info = os.path.join(infos, nome)
            original = data = ""
            for linha in ler(info).splitlines():
                if linha.startswith("Path="):
                    original = urllib.parse.unquote(linha[5:].strip())
                elif linha.startswith("DeletionDate="):
                    data = linha[13:].strip()
            if original and not original.startswith("/") and topo:
                original = os.path.join(topo, original)
            if os.path.abspath(original) != caminho:
                continue
            guardado = os.path.join(pasta, "files", nome[: -len(".trashinfo")])
            if os.path.lexists(guardado) and (melhor is None or data > melhor[2]):
                melhor = (guardado, info, data)
    return (melhor[0], melhor[1]) if melhor else (None, None)


def lixeira(caminho):
    if not os.path.lexists(caminho):
        return {"ok": False, "erro": "nao-existe"}
    tentativas = [["gio", "trash", "--", caminho]]
    for prog in ("kioclient", "kioclient6", "kioclient5"):
        tentativas.append([prog, "--noninteractive", "move", caminho, "trash:/"])
    erros = []
    for comando in tentativas:
        if not shutil.which(comando[0]):
            continue
        try:
            r = subprocess.run(comando, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=120)
        except (OSError, subprocess.TimeoutExpired) as erro:
            erros.append(str(erro))
            continue
        if r.returncode == 0 and not os.path.lexists(caminho):
            guardado, _ = achar_na_lixeira(caminho)
            return {"ok": True, "metodo": comando[0], "desfazer": guardado is not None}
        erros.append(r.stderr.decode("utf-8", "replace").strip())
    return {"ok": False, "erro": "sem-lixeira" if not erros else (erros[-1] or "falhou")}


def restaurar(caminho):
    caminho = os.path.abspath(caminho)
    if os.path.lexists(caminho):
        return {"ok": False, "erro": "ja-existe"}
    guardado, info = achar_na_lixeira(caminho)
    if not guardado:
        return {"ok": False, "erro": "nao-achou"}
    try:
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        try:
            os.rename(guardado, caminho)
        except OSError:
            shutil.move(guardado, caminho)
        os.remove(info)
    except OSError as erro:
        return {"ok": False, "erro": str(erro)}
    return {"ok": True}


def copiar(caminho):
    if not os.path.isfile(caminho):
        return {"ok": False, "erro": "nao-existe"}
    tipo = mimetypes.guess_type(caminho)[0] or "image/png"
    if os.environ.get("WAYLAND_DISPLAY") and shutil.which("wl-copy"):
        comando = ["wl-copy", "--type", tipo]
    elif os.environ.get("DISPLAY") and shutil.which("xclip"):
        comando = ["xclip", "-selection", "clipboard", "-t", tipo]
    else:
        return {"ok": False, "erro": "sem-programa"}
    try:
        with open(caminho, "rb") as entrada:
            # O wl-copy e o xclip ficam no fundo servindo a área de transferência.
            r = subprocess.run(comando, stdin=entrada, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               timeout=20, start_new_session=True)
    except (OSError, subprocess.TimeoutExpired) as erro:
        return {"ok": False, "erro": str(erro)}
    return {"ok": r.returncode == 0, "programa": comando[0]}


def main(args):
    if not args:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    acao, resto = args[0], args[1:]
    if acao == "listar":
        saida = listar(resto[0] if resto else "", resto[1] if len(resto) > 1 else "")
    elif acao == "vizinhas" and resto:
        saida = vizinhas(resto[0])
    elif acao == "lixeira" and resto:
        saida = lixeira(resto[0])
    elif acao == "restaurar" and resto:
        saida = restaurar(resto[0])
    elif acao == "copiar" and resto:
        saida = copiar(resto[0])
    elif acao == "capas":
        saida = fazer_capas(resto)
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    print(json.dumps(saida, ensure_ascii=False))
    return 0 if saida.get("ok", True) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
