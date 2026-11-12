#!/usr/bin/python3
"""Música do Matsu: o ajudante que lê a biblioteca.

A janela (os arquivos .qml desta pasta) só desenha e toca. Quem procura as
músicas na pasta Música, lê as etiquetas (ID3, FLAC, Ogg/Opus, MP4, WAV), tira
as capas para o cache e calcula a onda de cada música é este script. Ele só usa
a biblioteca padrão do Python e responde em JSON.

Uso:
  ajudante.py biblioteca [pasta]      lê a pasta (com subpastas): linhas JSON de progresso
                                      e, no fim, {"tipo": "fim", "musicas": [...]}
  ajudante.py etiquetas <arquivo>...  as músicas destes arquivos (para abrir de fora da pasta)
  ajudante.py onda <arquivo> [n]      a onda da música: {"amostras": [n números de 0 a 1], "real": ...}
                                      Com o ffmpeg, os picos de verdade; sem ele, uma onda
                                      estimada (sempre a mesma para o mesmo arquivo).

O que já foi lido fica em ~/.cache/matsu/musica: biblioteca.json (as etiquetas de
cada arquivo, pela data e pelo tamanho), capas/<hash>.jpg e ondas/<hash>.json.
"""
import array
import base64
import hashlib
import json
import math
import os
import random
import re
import shutil
import struct
import subprocess
import sys
import time
import zlib

VERSAO_CACHE = 2
EXTENSOES = {".mp3", ".flac", ".ogg", ".oga", ".opus", ".m4a", ".mp4", ".wav"}
CAPAS_SOLTAS = ("cover", "folder", "front", "capa", "album", "albumart")


# ----- pastas -----
def casa():
    return os.environ.get("HOME") or os.path.expanduser("~")


def config_casa():
    return os.environ.get("XDG_CONFIG_HOME") or os.path.join(casa(), ".config")


def pasta_cache():
    pasta = os.environ.get("MATSU_MUSICA_CACHE")
    if not pasta:
        base = os.environ.get("XDG_CACHE_HOME") or os.path.join(casa(), ".cache")
        pasta = os.path.join(base, "matsu", "musica")
    return pasta


def pasta_musica():
    """A pasta Música da pessoa (XDG_MUSIC_DIR), como o matsu.pasta("musica")."""
    for linha in ler(os.path.join(config_casa(), "user-dirs.dirs")).splitlines():
        if linha.startswith("XDG_MUSIC_DIR="):
            valor = linha.split("=", 1)[1].strip().strip('"')
            return valor.replace("$HOME", casa())
    for nome in ("Música", "Musica", "Music"):
        caminho = os.path.join(casa(), nome)
        if os.path.isdir(caminho):
            return caminho
    return os.path.join(casa(), "Música")


def ler(caminho, padrao=""):
    try:
        with open(caminho, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return padrao


def gravar_atomico(caminho, dados):
    """Grava de uma vez (num arquivo ao lado e depois troca), para nunca ficar pela metade."""
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    temp = f"{caminho}.{os.getpid()}.tmp"
    modo = "wb" if isinstance(dados, bytes) else "w"
    with open(temp, modo, **({} if modo == "wb" else {"encoding": "utf-8"})) as f:
        f.write(dados)
    os.replace(temp, caminho)


# ----- idioma e vidro (os mesmos dos outros apps do Matsu) -----
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
    """pt ou en: o ambiente e, se faltar, o plasma-localerc."""
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


def tem_ffmpeg():
    if os.environ.get("MATSU_MUSICA_SEM_FFMPEG"):
        return None
    return shutil.which("ffmpeg")


# ----- números das etiquetas -----
def numero(texto):
    """'3/12' -> 3; '' -> 0."""
    m = re.match(r"\s*(\d+)", texto or "")
    return int(m.group(1)) if m else 0


def ano(texto):
    m = re.search(r"(\d{4})", texto or "")
    return int(m.group(1)) if m else 0


def limpo(texto):
    return (texto or "").replace("\x00", "").replace("﻿", "").strip()


def juntar(valores):
    vistos = []
    for v in valores:
        v = limpo(v)
        if v and v not in vistos:
            vistos.append(v)
    return ", ".join(vistos)


def novo_resultado():
    return {"titulo": "", "artista": "", "artista_album": "", "album": "", "faixa": 0, "disco": 0, "ano": 0,
            "duracao": 0.0, "capa": None, "formato": ""}


# ----- ID3v2 (MP3, e às vezes WAV e FLAC) -----
def _syncsafe(b):
    return (b[0] & 0x7F) << 21 | (b[1] & 0x7F) << 14 | (b[2] & 0x7F) << 7 | (b[3] & 0x7F)


def _sem_unsync(dados):
    return dados.replace(b"\xff\x00", b"\xff")


def _texto_id3(dados):
    if not dados:
        return ""
    cod, corpo = dados[0], dados[1:]
    try:
        if cod == 0:
            texto = corpo.decode("latin-1")
        elif cod == 1:
            if corpo[:2] in (b"\xff\xfe", b"\xfe\xff"):
                texto = corpo.decode("utf-16", "replace")
            else:
                texto = corpo.decode("utf-16-le", "replace")
        elif cod == 2:
            texto = corpo.decode("utf-16-be", "replace")
        else:
            texto = corpo.decode("utf-8", "replace")
    except (UnicodeDecodeError, LookupError):
        texto = corpo.decode("latin-1", "replace")
    return juntar(texto.replace("﻿", "").split("\x00"))


def _fim_texto(dados, inicio, cod):
    """Onde termina um texto terminado em zero (dois zeros alinhados no UTF-16)."""
    if cod in (1, 2):
        i = inicio
        while i + 1 < len(dados):
            if dados[i] == 0 and dados[i + 1] == 0:
                return i, i + 2
            i += 2
        return len(dados), len(dados)
    i = dados.find(b"\x00", inicio)
    return (i, i + 1) if i >= 0 else (len(dados), len(dados))


def _imagem_id3(dados, v22):
    """APIC (ou PIC no ID3v2.2): (tipo da imagem, mime, bytes)."""
    if len(dados) < 4:
        return None
    cod = dados[0]
    if v22:
        formato = dados[1:4].decode("latin-1", "replace").upper()
        mime = "image/png" if formato == "PNG" else "image/jpeg"
        pos = 4
    else:
        fim = dados.find(b"\x00", 1)
        if fim < 0:
            return None
        mime = dados[1:fim].decode("latin-1", "replace").lower() or "image/jpeg"
        pos = fim + 1
    if pos >= len(dados):
        return None
    tipo = dados[pos]
    _, pos = _fim_texto(dados, pos + 1, cod)
    imagem = dados[pos:]
    if not imagem:
        return None
    if "/" not in mime:
        mime = "image/png" if "png" in mime else "image/jpeg"
    return tipo, mime, imagem


def ler_id3v2(f, r):
    """Lê a etiqueta ID3v2 no ponto atual do arquivo. Devolve o tamanho dela (0 se não houver)."""
    inicio = f.tell()
    cab = f.read(10)
    if len(cab) < 10 or cab[:3] != b"ID3" or cab[3] > 4 or 0xFF in cab[6:10]:
        f.seek(inicio)
        return 0
    versao, flags = cab[3], cab[5]
    tamanho = _syncsafe(cab[6:10])
    total = 10 + tamanho + (10 if flags & 0x10 else 0)
    dados = f.read(tamanho)
    if versao < 4 and flags & 0x80:
        dados = _sem_unsync(dados)
    pos = 0
    if flags & 0x40 and len(dados) >= 4:
        pos = (_syncsafe(dados[:4]) if versao == 4 else struct.unpack(">I", dados[:4])[0] + 4)
    v22 = versao == 2
    imagens = []
    textos = {}
    while pos < len(dados):
        if v22:
            if pos + 6 > len(dados):
                break
            fid = dados[pos:pos + 3]
            tam = int.from_bytes(dados[pos + 3:pos + 6], "big")
            fflags = 0
            pos += 6
        else:
            if pos + 10 > len(dados):
                break
            fid = dados[pos:pos + 4]
            bruto = dados[pos + 4:pos + 8]
            if versao == 4:
                tam = _syncsafe(bruto)
                # Alguns programas antigos gravaram o tamanho sem o "syncsafe" no v2.4.
                normal = struct.unpack(">I", bruto)[0]
                if normal != tam and pos + 10 + normal <= len(dados):
                    prox = dados[pos + 10 + tam:pos + 14 + tam]
                    if prox and not re.fullmatch(rb"[A-Z0-9]{4}", prox) and prox != b"\x00" * len(prox):
                        tam = normal
            else:
                tam = struct.unpack(">I", bruto)[0]
            fflags = int.from_bytes(dados[pos + 8:pos + 10], "big")
            pos += 10
        if not fid.strip(b"\x00") or not re.fullmatch(rb"[A-Z0-9]{3,4}", fid):
            break
        corpo = dados[pos:pos + tam]
        pos += tam
        if not v22:
            if versao == 4:
                if fflags & 0x0004:  # cifrado: não dá para ler
                    continue
                if fflags & 0x0001:
                    corpo = corpo[4:]
                if fflags & 0x0002:
                    corpo = _sem_unsync(corpo)
                if fflags & 0x0008:
                    try:
                        corpo = zlib.decompress(corpo)
                    except zlib.error:
                        continue
            else:
                if fflags & 0x0040:
                    continue
                if fflags & 0x0020:
                    corpo = corpo[1:]
                if fflags & 0x0080:
                    try:
                        corpo = zlib.decompress(corpo[4:])
                    except zlib.error:
                        continue
        nome = fid.decode("latin-1")
        if nome in ("APIC", "PIC"):
            img = _imagem_id3(corpo, nome == "PIC")
            if img:
                imagens.append(img)
        elif nome[0] == "T" and nome not in ("TXXX", "TXX"):
            textos.setdefault(nome, _texto_id3(corpo))
    pega = lambda *ids: next((textos[i] for i in ids if textos.get(i)), "")  # noqa: E731
    r["titulo"] = r["titulo"] or pega("TIT2", "TT2")
    r["artista"] = r["artista"] or pega("TPE1", "TP1")
    r["artista_album"] = r["artista_album"] or pega("TPE2", "TP2")
    r["album"] = r["album"] or pega("TALB", "TAL")
    r["faixa"] = r["faixa"] or numero(pega("TRCK", "TRK"))
    r["disco"] = r["disco"] or numero(pega("TPOS", "TPA"))
    r["ano"] = r["ano"] or ano(pega("TDRC", "TYER", "TYE", "TDOR", "TORY"))
    if imagens and not r["capa"]:
        frente = [i for i in imagens if i[0] == 3]
        _, mime, imagem = (frente or imagens)[0]
        r["capa"] = (mime, imagem)
    f.seek(inicio + total)
    return total


def ler_id3v1(f, tamanho_arquivo, r):
    if tamanho_arquivo < 128:
        return False
    f.seek(tamanho_arquivo - 128)
    dados = f.read(128)
    if dados[:3] != b"TAG":
        return False

    def campo(a, b):
        return dados[a:b].split(b"\x00")[0].decode("latin-1").strip()
    r["titulo"] = r["titulo"] or campo(3, 33)
    r["artista"] = r["artista"] or campo(33, 63)
    r["album"] = r["album"] or campo(63, 93)
    r["ano"] = r["ano"] or ano(campo(93, 97))
    if not r["faixa"] and dados[125] == 0 and dados[126]:
        r["faixa"] = dados[126]
    return True


# ----- MP3: a duração pelos quadros (Xing/Info, VBRI ou CBR) -----
TAXAS = {
    (1, 1): [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448],
    (1, 2): [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384],
    (1, 3): [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
    (2, 1): [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256],
    (2, 2): [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
    (2, 3): [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
}
FREQUENCIAS = {3: [44100, 48000, 32000], 2: [22050, 24000, 16000], 0: [11025, 12000, 8000]}


def quadro_mp3(cab):
    """Os dados de um cabeçalho de quadro MPEG de 4 bytes, ou None se não for um."""
    if len(cab) < 4 or cab[0] != 0xFF or (cab[1] & 0xE0) != 0xE0:
        return None
    versao = (cab[1] >> 3) & 3
    camada = 4 - ((cab[1] >> 1) & 3)
    i_taxa = cab[2] >> 4
    i_freq = (cab[2] >> 2) & 3
    if versao == 1 or camada == 4 or i_taxa in (0, 15) or i_freq == 3:
        return None
    taxa = TAXAS[(1 if versao == 3 else 2, camada)][i_taxa] * 1000
    freq = FREQUENCIAS[versao][i_freq]
    enchimento = (cab[2] >> 1) & 1
    mono = (cab[3] >> 6) == 3
    if camada == 1:
        amostras = 384
        tamanho = (12 * taxa // freq + enchimento) * 4
    else:
        amostras = 1152 if (camada == 2 or versao == 3) else 576
        tamanho = (amostras // 8) * taxa // freq + enchimento
    return {"versao": versao, "camada": camada, "taxa": taxa, "freq": freq, "mono": mono,
            "amostras": amostras, "tamanho": tamanho}


def duracao_mp3(f, inicio, tamanho_arquivo, tem_v1):
    f.seek(inicio)
    bloco = f.read(256 * 1024)
    pos = 0
    q = None
    while True:
        pos = bloco.find(b"\xff", pos)
        if pos < 0 or pos + 4 > len(bloco):
            return 0.0
        q = quadro_mp3(bloco[pos:pos + 4])
        if q:
            # Confere o quadro seguinte, para não confundir um byte 0xFF qualquer.
            seguinte = pos + q["tamanho"]
            if seguinte + 4 > len(bloco) or quadro_mp3(bloco[seguinte:seguinte + 4]):
                break
        pos += 1
    lado = (32 if not q["mono"] else 17) if q["versao"] == 3 else (17 if not q["mono"] else 9)
    xing = bloco[pos + 4 + lado:pos + 4 + lado + 16]
    if xing[:4] in (b"Xing", b"Info") and len(xing) >= 12:
        flags = struct.unpack(">I", xing[4:8])[0]
        if flags & 1:
            quadros = struct.unpack(">I", xing[8:12])[0]
            if quadros:
                return quadros * q["amostras"] / q["freq"]
    vbri = bloco[pos + 36:pos + 36 + 18]
    if vbri[:4] == b"VBRI" and len(vbri) >= 18:
        quadros = struct.unpack(">I", vbri[14:18])[0]
        if quadros:
            return quadros * q["amostras"] / q["freq"]
    dados = tamanho_arquivo - (inicio + pos) - (128 if tem_v1 else 0)
    return max(0.0, dados * 8 / q["taxa"])


def ler_mp3(f, tamanho, r):
    r["formato"] = "MP3"
    inicio = ler_id3v2(f, r)
    tem_v1 = ler_id3v1(f, tamanho, r)
    r["duracao"] = duracao_mp3(f, inicio, tamanho, tem_v1)


# ----- comentários Vorbis (FLAC, Ogg Vorbis, Opus) -----
def imagem_flac(dados):
    """O bloco PICTURE do FLAC (também vem em base64 no METADATA_BLOCK_PICTURE do Ogg)."""
    try:
        tipo, n = struct.unpack(">II", dados[:8])
        mime = dados[8:8 + n].decode("ascii", "replace").lower()
        p = 8 + n
        n = struct.unpack(">I", dados[p:p + 4])[0]
        p += 4 + n + 16
        n = struct.unpack(">I", dados[p:p + 4])[0]
        imagem = dados[p + 4:p + 4 + n]
    except struct.error:
        return None
    if not imagem:
        return None
    return tipo, mime or "image/jpeg", imagem


def comentarios_vorbis(dados, r):
    try:
        p = 0
        n = struct.unpack("<I", dados[p:p + 4])[0]
        p += 4 + n
        quantos = struct.unpack("<I", dados[p:p + 4])[0]
        p += 4
    except struct.error:
        return
    campos = {}
    imagens = []
    for _ in range(min(quantos, 10000)):
        if p + 4 > len(dados):
            break
        n = struct.unpack("<I", dados[p:p + 4])[0]
        bruto = dados[p + 4:p + 4 + n]
        p += 4 + n
        chave, sep, valor = bruto.partition(b"=")
        if not sep:
            continue
        chave = chave.decode("ascii", "replace").upper()
        if chave == "METADATA_BLOCK_PICTURE":
            try:
                img = imagem_flac(base64.b64decode(valor))
            except ValueError:
                img = None
            if img:
                imagens.append(img)
        elif chave == "COVERART":
            try:
                imagens.append((3, "image/jpeg", base64.b64decode(valor)))
            except ValueError:
                pass
        else:
            campos.setdefault(chave, []).append(valor.decode("utf-8", "replace"))
    pega = lambda *ks: juntar(next((campos[k] for k in ks if campos.get(k)), []))  # noqa: E731
    r["titulo"] = r["titulo"] or pega("TITLE")
    r["artista"] = r["artista"] or pega("ARTIST")
    r["artista_album"] = r["artista_album"] or pega("ALBUMARTIST", "ALBUM ARTIST", "ALBUM_ARTIST")
    r["album"] = r["album"] or pega("ALBUM")
    r["faixa"] = r["faixa"] or numero(pega("TRACKNUMBER", "TRACK"))
    r["disco"] = r["disco"] or numero(pega("DISCNUMBER", "DISC"))
    r["ano"] = r["ano"] or ano(pega("DATE", "YEAR", "ORIGINALDATE"))
    if imagens and not r["capa"]:
        frente = [i for i in imagens if i[0] == 3]
        _, mime, imagem = (frente or imagens)[0]
        r["capa"] = (mime, imagem)


def ler_flac(f, tamanho, r):
    r["formato"] = "FLAC"
    ler_id3v2(f, r)
    if f.read(4) != b"fLaC":
        return
    imagens = []
    while True:
        cab = f.read(4)
        if len(cab) < 4:
            break
        ultimo, tipo = cab[0] & 0x80, cab[0] & 0x7F
        n = int.from_bytes(cab[1:4], "big")
        if tipo in (0, 4, 6):
            dados = f.read(n)
            if tipo == 0 and len(dados) >= 18:
                x = int.from_bytes(dados[10:18], "big")
                freq, amostras = x >> 44, x & ((1 << 36) - 1)
                if freq:
                    r["duracao"] = amostras / freq
            elif tipo == 4:
                comentarios_vorbis(dados, r)
            elif tipo == 6:
                img = imagem_flac(dados)
                if img:
                    imagens.append(img)
        else:
            f.seek(n, 1)
        if ultimo:
            break
    if imagens and not r["capa"]:
        frente = [i for i in imagens if i[0] == 3]
        _, mime, imagem = (frente or imagens)[0]
        r["capa"] = (mime, imagem)


# ----- Ogg (Vorbis e Opus) -----
def pacotes_ogg(f, quantos, limite=32 * 1024 * 1024):
    """Os primeiros pacotes do primeiro fluxo do Ogg (juntando as páginas)."""
    pacotes, atual, serie, lidos = [], b"", None, 0
    while len(pacotes) < quantos and lidos < limite:
        cab = f.read(27)
        if len(cab) < 27 or cab[:4] != b"OggS":
            break
        num_serie = struct.unpack("<I", cab[14:18])[0]
        segs = f.read(cab[26])
        corpo = f.read(sum(segs))
        lidos += 27 + len(segs) + len(corpo)
        if serie is None:
            serie = num_serie
        if num_serie != serie:
            continue
        p = 0
        for s in segs:
            atual += corpo[p:p + s]
            p += s
            if s < 255:
                pacotes.append(atual)
                atual = b""
                if len(pacotes) >= quantos:
                    break
    return pacotes, serie


def ultima_posicao_ogg(f, tamanho, serie):
    """A posição (granule) da última página do fluxo: dá a duração."""
    janela = 65536
    while True:
        inicio = max(0, tamanho - janela)
        f.seek(inicio)
        bloco = f.read(tamanho - inicio)
        pos = len(bloco)
        while True:
            pos = bloco.rfind(b"OggS", 0, pos)
            if pos < 0 or pos + 27 > len(bloco):
                break
            granule = struct.unpack("<q", bloco[pos + 6:pos + 14])[0]
            num_serie = struct.unpack("<I", bloco[pos + 14:pos + 18])[0]
            if (serie is None or num_serie == serie) and granule >= 0:
                return granule
        if inicio == 0 or janela >= 4 * 1024 * 1024:
            return 0
        janela *= 4


def ler_ogg(f, tamanho, r):
    pacotes, serie = pacotes_ogg(f, 2)
    if not pacotes:
        return
    ident = pacotes[0]
    comentario = pacotes[1] if len(pacotes) > 1 else b""
    if ident[:7] == b"\x01vorbis":
        r["formato"] = "Ogg Vorbis"
        freq = struct.unpack("<I", ident[12:16])[0] if len(ident) >= 16 else 0
        if comentario[:7] == b"\x03vorbis":
            comentarios_vorbis(comentario[7:], r)
        if freq:
            r["duracao"] = ultima_posicao_ogg(f, tamanho, serie) / freq
    elif ident[:8] == b"OpusHead":
        r["formato"] = "Opus"
        pre = struct.unpack("<H", ident[10:12])[0] if len(ident) >= 12 else 0
        if comentario[:8] == b"OpusTags":
            comentarios_vorbis(comentario[8:], r)
        r["duracao"] = max(0, ultima_posicao_ogg(f, tamanho, serie) - pre) / 48000
    elif ident[:5] == b"\x7fFLAC":
        r["formato"] = "FLAC"
        if len(ident) >= 13 + 4 + 18 and ident[13:17] == b"fLaC":
            x = int.from_bytes(ident[17 + 4 + 10:17 + 4 + 18], "big")
            freq = x >> 44
            if comentario and (comentario[0] & 0x7F) == 4:
                comentarios_vorbis(comentario[4:], r)
            if freq:
                r["duracao"] = ultima_posicao_ogg(f, tamanho, serie) / freq


# ----- MP4 / M4A -----
def atomos(dados, inicio=0, fim=None):
    """(tipo, início do conteúdo, fim) de cada átomo entre inicio e fim."""
    fim = len(dados) if fim is None else fim
    p = inicio
    while p + 8 <= fim:
        n, tipo = struct.unpack(">I4s", dados[p:p + 8])
        cab = 8
        if n == 1:
            if p + 16 > fim:
                break
            n = struct.unpack(">Q", dados[p + 8:p + 16])[0]
            cab = 16
        elif n == 0:
            n = fim - p
        if n < cab or p + n > fim:
            break
        yield tipo, p + cab, p + n
        p += n


def ler_mp4(f, tamanho, r):
    r["formato"] = "AAC"
    # Acha o "moov" pulando o resto (o áudio, "mdat", pode vir antes e ser grande).
    p = 0
    moov = None
    while p + 8 <= tamanho:
        f.seek(p)
        cab = f.read(16)
        if len(cab) < 8:
            break
        n, tipo = struct.unpack(">I4s", cab[:8])
        cab_t = 8
        if n == 1 and len(cab) >= 16:
            n = struct.unpack(">Q", cab[8:16])[0]
            cab_t = 16
        elif n == 0:
            n = tamanho - p
        if n < 8:
            break
        if tipo == b"moov":
            if n > 64 * 1024 * 1024:
                return
            f.seek(p + cab_t)
            moov = f.read(n - cab_t)
            break
        p += n
    if not moov:
        return
    escala = 0
    for tipo, a, b in atomos(moov):
        if tipo == b"mvhd":
            v = moov[a]
            if v == 1:
                escala, dur = struct.unpack(">IQ", moov[a + 20:a + 32])
            else:
                escala, dur = struct.unpack(">II", moov[a + 12:a + 20])
            if escala:
                r["duracao"] = dur / escala
        elif tipo == b"trak" and b"alac" in moov[a:b][:4096]:
            r["formato"] = "ALAC"
        elif tipo == b"udta":
            for t2, a2, b2 in atomos(moov, a, b):
                if t2 != b"meta":
                    continue
                # "meta" é um "full box" (4 bytes de versão) no MP4; no QuickTime, não.
                inicio_meta = a2 + 4 if moov[a2:a2 + 4] == b"\x00\x00\x00\x00" else a2
                for t3, a3, b3 in atomos(moov, inicio_meta, b2):
                    if t3 == b"ilst":
                        _ilst(moov, a3, b3, r)


def _ilst(dados, a, b, r):
    for tipo, a2, b2 in atomos(dados, a, b):
        for t3, a3, b3 in atomos(dados, a2, b2):
            if t3 != b"data" or b3 - a3 < 8:
                continue
            classe = struct.unpack(">I", dados[a3:a3 + 4])[0] & 0xFFFFFF
            valor = dados[a3 + 8:b3]
            if tipo == b"covr":
                if not r["capa"] and valor:
                    r["capa"] = ("image/png" if classe == 14 or valor[:4] == b"\x89PNG" else "image/jpeg", valor)
            elif tipo in (b"trkn", b"disk"):
                if len(valor) >= 4:
                    n = struct.unpack(">H", valor[2:4])[0]
                    chave = "faixa" if tipo == b"trkn" else "disco"
                    r[chave] = r[chave] or n
            else:
                texto = limpo(valor.decode("utf-8", "replace"))
                chave = {b"\xa9nam": "titulo", b"\xa9ART": "artista", b"aART": "artista_album",
                         b"\xa9alb": "album"}.get(tipo)
                if chave and not r[chave]:
                    r[chave] = texto
                elif tipo == b"\xa9day" and not r["ano"]:
                    r["ano"] = ano(texto)
            break


# ----- WAV -----
def ler_wav(f, tamanho, r):
    r["formato"] = "WAV"
    cab = f.read(12)
    if cab[:4] != b"RIFF" or cab[8:12] != b"WAVE":
        return
    taxa_bytes = 0
    dados_n = 0
    while True:
        c = f.read(8)
        if len(c) < 8:
            break
        nome, n = c[:4], struct.unpack("<I", c[4:8])[0]
        inicio = f.tell()
        if nome == b"fmt " and n >= 16:
            fmt = f.read(16)
            taxa_bytes = struct.unpack("<I", fmt[8:12])[0]
        elif nome == b"data":
            dados_n = min(n, tamanho - inicio)
        elif nome == b"LIST" and n < 1024 * 1024:
            lista = f.read(n)
            if lista[:4] == b"INFO":
                p = 4
                while p + 8 <= len(lista):
                    sub, m = lista[p:p + 4], struct.unpack("<I", lista[p + 4:p + 8])[0]
                    texto = limpo(lista[p + 8:p + 8 + m].decode("utf-8", "replace"))
                    chave = {b"INAM": "titulo", b"IART": "artista", b"IPRD": "album"}.get(sub)
                    if chave and not r[chave]:
                        r[chave] = texto
                    elif sub == b"ICRD" and not r["ano"]:
                        r["ano"] = ano(texto)
                    elif sub in (b"ITRK", b"IPRT") and not r["faixa"]:
                        r["faixa"] = numero(texto)
                    p += 8 + m + (m & 1)
        elif nome in (b"id3 ", b"ID3 "):
            ler_id3v2(f, r)
        f.seek(inicio + n + (n & 1))
    if taxa_bytes:
        r["duracao"] = dados_n / taxa_bytes


# ----- uma música -----
def ler_etiquetas(caminho):
    """As etiquetas e a duração de um arquivo de música (o que der para ler, sem travar)."""
    r = novo_resultado()
    try:
        tamanho = os.path.getsize(caminho)
        with open(caminho, "rb") as f:
            cab = f.read(12)
            f.seek(0)
            if cab[:4] == b"fLaC":
                ler_flac(f, tamanho, r)
            elif cab[:4] == b"OggS":
                ler_ogg(f, tamanho, r)
            elif cab[:4] == b"RIFF" and cab[8:12] == b"WAVE":
                ler_wav(f, tamanho, r)
            elif cab[4:8] == b"ftyp":
                ler_mp4(f, tamanho, r)
            elif cab[:3] == b"ID3":
                # ID3 na frente de um FLAC (raro) ou, o normal, de um MP3.
                pulo = ler_id3v2(f, novo_resultado())
                f.seek(pulo)
                if f.read(4) == b"fLaC":
                    f.seek(0)
                    ler_flac(f, tamanho, r)
                else:
                    f.seek(0)
                    ler_mp3(f, tamanho, r)
            else:
                ext = os.path.splitext(caminho)[1].lower()
                if ext == ".mp3" or quadro_mp3(cab[:4]):
                    ler_mp3(f, tamanho, r)
    except (OSError, ValueError, struct.error, IndexError, MemoryError, OverflowError, KeyError,
            ZeroDivisionError):
        pass
    if not r["formato"]:
        r["formato"] = os.path.splitext(caminho)[1].lstrip(".").upper()
    for chave in ("titulo", "artista", "artista_album", "album"):
        r[chave] = limpo(r[chave])
    return r


def pelo_nome(caminho):
    """Título e artista pelo nome do arquivo, quando não há etiquetas: "Artista - Título.mp3"."""
    nome = os.path.splitext(os.path.basename(caminho))[0]
    nome = re.sub(r"^\d{1,3}\s*[-._)]\s*", "", nome).replace("_", " ").strip()
    partes = [p.strip() for p in re.split(r"\s+-\s+", nome, maxsplit=1)]
    if len(partes) == 2 and all(partes):
        return partes[1], partes[0]
    return nome or os.path.basename(caminho), ""


def salvar_capa(mime, imagem):
    """Guarda a capa no cache (uma vez por imagem: as faixas do álbum dividem o arquivo)."""
    ext = ".png" if imagem[:8] == b"\x89PNG\r\n\x1a\n" or "png" in mime else ".jpg"
    if imagem[:4] == b"RIFF" and imagem[8:12] == b"WEBP":
        ext = ".webp"
    nome = hashlib.sha1(imagem).hexdigest()[:24] + ext
    caminho = os.path.join(pasta_cache(), "capas", nome)
    if not os.path.exists(caminho):
        try:
            gravar_atomico(caminho, imagem)
        except OSError:
            return ""
    return caminho


def capa_da_pasta(pasta, memoria):
    """cover.jpg, folder.jpg, capa.png... ao lado das músicas."""
    if pasta in memoria:
        return memoria[pasta]
    achada = ""
    try:
        nomes = os.listdir(pasta)
    except OSError:
        nomes = []
    candidatas = {}
    for n in nomes:
        base, ext = os.path.splitext(n)
        if ext.lower() in (".jpg", ".jpeg", ".png", ".webp") and base.lower() in CAPAS_SOLTAS:
            candidatas[base.lower()] = os.path.join(pasta, n)
    for preferida in CAPAS_SOLTAS:
        if preferida in candidatas:
            achada = candidatas[preferida]
            break
    memoria[pasta] = achada
    return achada


def musica(caminho, st, memoria_capas=None):
    """A música como a janela usa."""
    r = ler_etiquetas(caminho)
    titulo, artista = pelo_nome(caminho)
    capa = ""
    if r["capa"]:
        capa = salvar_capa(*r["capa"])
    if not capa:
        capa = capa_da_pasta(os.path.dirname(caminho), memoria_capas if memoria_capas is not None else {})
    return {
        "caminho": caminho,
        "titulo": r["titulo"] or titulo,
        "artista": r["artista"] or artista or r["artista_album"],
        "artistaAlbum": r["artista_album"],
        "album": r["album"],
        "faixa": r["faixa"],
        "disco": r["disco"],
        "ano": r["ano"],
        "duracao": round(r["duracao"], 3),
        "capa": capa,
        "formato": r["formato"],
        "adicionada": int(st.st_mtime),
        "tamanho": st.st_size,
    }


# ----- a biblioteca -----
def arquivos_de(pasta):
    """Os arquivos de música da pasta e das subpastas (sem os escondidos, sem dar volta em atalhos)."""
    vistos = set()
    achados = []
    for raiz, pastas, arquivos in os.walk(pasta, followlinks=True):
        try:
            st = os.stat(raiz)
        except OSError:
            pastas[:] = []
            continue
        if (st.st_dev, st.st_ino) in vistos:
            pastas[:] = []
            continue
        vistos.add((st.st_dev, st.st_ino))
        pastas[:] = sorted(p for p in pastas if not p.startswith("."))
        for nome in arquivos:
            if nome.startswith("."):
                continue
            if os.path.splitext(nome)[1].lower() in EXTENSOES:
                achados.append(os.path.join(raiz, nome))
    return sorted(achados)


def ler_cache():
    try:
        with open(os.path.join(pasta_cache(), "biblioteca.json"), encoding="utf-8") as f:
            dados = json.load(f)
        if dados.get("versao") == VERSAO_CACHE and isinstance(dados.get("musicas"), dict):
            return dados["musicas"]
    except (OSError, ValueError, AttributeError):
        pass
    return {}


def gravar_cache(musicas):
    try:
        gravar_atomico(os.path.join(pasta_cache(), "biblioteca.json"),
                       json.dumps({"versao": VERSAO_CACHE, "musicas": musicas}, ensure_ascii=False))
    except OSError:
        pass


def biblioteca(pasta, saida=None, intervalo=0.25):
    """Lê a pasta toda; manda o progresso em linhas e devolve a lista de músicas."""
    saida = saida or sys.stdout

    def mandar(obj):
        saida.write(json.dumps(obj, ensure_ascii=False) + "\n")
        saida.flush()

    arquivos = arquivos_de(pasta) if os.path.isdir(pasta) else []
    mandar({"tipo": "inicio", "idioma": idioma(), "vidro": vidro(), "pasta": pasta, "total": len(arquivos)})
    cache = ler_cache()
    novo = {}
    musicas = []
    memoria_capas = {}
    ultimo = time.monotonic()
    lidas = 0
    for n, caminho in enumerate(arquivos, 1):
        try:
            st = os.stat(caminho)
        except OSError:
            continue
        if st.st_size == 0:
            continue
        guardada = cache.get(caminho)
        m = None
        if (guardada and guardada.get("mtime") == st.st_mtime and guardada.get("tamanho") == st.st_size
                and (not guardada["dados"].get("capa") or os.path.exists(guardada["dados"]["capa"]))):
            m = guardada["dados"]
        if m is None:
            m = musica(caminho, st, memoria_capas)
            lidas += 1
        novo[caminho] = {"mtime": st.st_mtime, "tamanho": st.st_size, "dados": m}
        musicas.append(m)
        agora = time.monotonic()
        if agora - ultimo >= intervalo:
            ultimo = agora
            mandar({"tipo": "progresso", "feitos": n, "total": len(arquivos)})
    if novo != cache:
        gravar_cache(novo)
    mandar({"tipo": "fim", "idioma": idioma(), "vidro": vidro(), "pasta": pasta, "ffmpeg": bool(tem_ffmpeg()),
            "lidas": lidas, "musicas": musicas})
    return musicas


# ----- a onda -----
def _arredondar(valores):
    return [round(max(0.04, min(1.0, v)), 3) for v in valores]


def onda_de_amostras(amostras, n):
    """Reduz as amostras (inteiros com sinal) a n barras de 0 a 1: a média e o pico de cada pedaço."""
    total = len(amostras)
    if total == 0:
        return []
    medias, picos = [], []
    for i in range(n):
        a = i * total // n
        b = max(a + 1, (i + 1) * total // n)
        pedaco = amostras[a:b]
        if not len(pedaco):
            medias.append(0.0)
            picos.append(0.0)
            continue
        picos.append(float(max(max(pedaco), -min(pedaco))))
        medias.append(sum(map(abs, pedaco)) / len(pedaco))
    maior_media = max(medias) or 1.0
    maior_pico = max(picos) or 1.0
    # A média dá o desenho (mais variado); o pico, a força das batidas.
    valores = [0.7 * m / maior_media + 0.3 * p / maior_pico for m, p in zip(medias, picos)]
    # Música muito comprimida dá uma onda quase reta: estica a diferença entre o
    # mais baixo e o mais alto (o desenho continua o do som, só com mais contraste).
    base = min(0.8, 0.85 * min(valores))
    return _arredondar([0.1 + 0.9 * ((v - base) / (1 - base)) ** 1.2 if v > base else 0.1 for v in valores])


def onda_ffmpeg(caminho, n, ffmpeg):
    try:
        proc = subprocess.run([ffmpeg, "-v", "error", "-nostdin", "-i", caminho, "-vn", "-ac", "1", "-ar", "4000",
                               "-f", "s16le", "-"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=90)
    except (OSError, subprocess.TimeoutExpired):
        return None
    dados = proc.stdout
    if len(dados) < 4:
        return None
    amostras = array.array("h")
    amostras.frombytes(dados[:len(dados) - len(dados) % 2])
    if sys.byteorder == "big":
        amostras.byteswap()
    return onda_de_amostras(amostras, n)


def onda_wav(caminho, n):
    """WAV em PCM dá para ler sem o ffmpeg (o primeiro canal basta para o desenho)."""
    import wave
    try:
        with wave.open(caminho, "rb") as w:
            canais, largura, quadros = w.getnchannels(), w.getsampwidth(), w.getnframes()
            if largura not in (1, 2, 4) or quadros == 0:
                return None
            passo = max(1, quadros // (n * 200))  # no máximo ~200 amostras por barra
            tipo = {1: "B", 2: "h", 4: "i"}[largura]
            amostras = array.array(tipo)
            restam = quadros
            while restam > 0:
                bloco = w.readframes(min(restam, 65536))
                if not bloco:
                    break
                restam -= len(bloco) // (largura * canais)
                parte = array.array(tipo)
                parte.frombytes(bloco[:len(bloco) - len(bloco) % largura])
                if sys.byteorder == "big" and largura > 1:
                    parte.byteswap()
                amostras.extend(parte[::canais * passo])
    except (OSError, EOFError, ValueError, wave.Error):
        return None
    if largura == 1:
        amostras = array.array("h", (s - 128 for s in amostras))
    return onda_de_amostras(amostras, n)


def onda_estimada(caminho, n):
    """Sem o ffmpeg: uma onda bonita e sempre igual para o mesmo arquivo (não é o som de verdade)."""
    try:
        st = os.stat(caminho)
        semente = f"{os.path.basename(caminho)}:{st.st_size}"
    except OSError:
        semente = caminho
    rnd = random.Random(int(hashlib.sha1(semente.encode("utf-8", "replace")).hexdigest()[:12], 16))
    ondas = [(rnd.uniform(0.6, 2.4), rnd.uniform(0, 6.3), rnd.uniform(0.15, 0.35)) for _ in range(3)]
    valores = []
    suave = 0.5
    for i in range(n):
        x = i / max(1, n - 1)
        base = 0.55 + sum(a * math.sin(f * x * 6.283 + fase) for f, fase, a in ondas)
        suave = 0.6 * suave + 0.4 * (base + rnd.uniform(-0.28, 0.28))
        envelope = min(1.0, x / 0.05, (1 - x) / 0.07 + 0.15)
        valores.append(max(0.08, suave * envelope))
    maior = max(valores) or 1
    return _arredondar([v / maior for v in valores])


def onda(caminho, n=200):
    n = max(8, min(2000, int(n)))
    try:
        st = os.stat(caminho)
    except OSError:
        return {"amostras": onda_estimada(caminho, n), "real": False, "fonte": "estimada"}
    ffmpeg = tem_ffmpeg()
    chave = hashlib.sha1(f"v2|{caminho}|{st.st_mtime}|{st.st_size}|{n}".encode("utf-8", "replace")).hexdigest()[:24]
    guardada = os.path.join(pasta_cache(), "ondas", chave + ".json")
    try:
        with open(guardada, encoding="utf-8") as f:
            dados = json.load(f)
        # Uma onda estimada é refeita quando o ffmpeg aparece.
        if dados.get("real") or not ffmpeg:
            return dados
    except (OSError, ValueError):
        pass
    amostras, fonte = None, "estimada"
    if ffmpeg:
        amostras, fonte = onda_ffmpeg(caminho, n, ffmpeg), "ffmpeg"
    if not amostras and caminho.lower().endswith(".wav"):
        amostras, fonte = onda_wav(caminho, n), "wav"
    if not amostras:
        amostras, fonte = onda_estimada(caminho, n), "estimada"
    dados = {"amostras": amostras, "real": fonte != "estimada", "fonte": fonte}
    try:
        gravar_atomico(guardada, json.dumps(dados))
    except OSError:
        pass
    return dados


def main(args):
    if not args:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    acao = args[0]
    if acao == "biblioteca":
        biblioteca(args[1] if len(args) > 1 and args[1] else pasta_musica())
    elif acao == "etiquetas":
        lista = []
        memoria = {}
        for a in args[1:]:
            caminho = a[7:] if a.startswith("file://") else a
            if caminho.startswith("/") and a.startswith("file://"):
                from urllib.parse import unquote
                caminho = unquote(caminho)
            try:
                st = os.stat(caminho)
            except OSError:
                continue
            if os.path.isfile(caminho):
                lista.append(musica(os.path.abspath(caminho), st, memoria))
        print(json.dumps({"idioma": idioma(), "musicas": lista}, ensure_ascii=False))
    elif acao == "onda" and len(args) > 1:
        print(json.dumps(onda(args[1], int(args[2]) if len(args) > 2 else 200)))
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except BrokenPipeError:
        sys.exit(0)
