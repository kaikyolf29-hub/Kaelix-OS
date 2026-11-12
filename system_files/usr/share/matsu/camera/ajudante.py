#!/usr/bin/env python3
"""Ajudante da Câmera do Matsu (Main.qml desta pasta).

O desenho e a câmera em si ficam no QML (QtMultimedia). Aqui só o que o QML não
faz sozinho: a língua e o vidro que a pessoa escolheu, as pastas onde as fotos e
os vídeos vão (criadas se faltarem), a última foto ou vídeo para a miniatura e a
foto de capa de um vídeo (com o ffmpeg, se existir; sem ele, fica sem capa).

Uso:
  ajudante.py inicio <pasta Imagens> <pasta Vídeos> <pasta de dados>
      {"idioma", "vidro", "fotos", "videos", "capas", "ultima": {caminho, tipo, capa} | null}
  ajudante.py capa <vídeo> <saída.jpg>
      {"ok": true | false}

Só a biblioteca padrão do Python.
"""
import json
import os
import re
import shutil
import subprocess
import sys

FOTOS = {"jpg", "jpeg", "png", "webp"}
VIDEOS = {"mp4", "mkv", "webm", "mov", "m4v"}

# As cores do vidro do Matsu (as mesmas do "matsu vidro").
CORES_VIDRO = {"azul": "#2f80ed", "roxo": "#8b5cf6", "rosa": "#ec4899", "vermelho": "#ef4444", "laranja": "#f97316",
               "amarelo": "#eab308", "verde": "#22c55e", "grafite": "#6b7280"}


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


def criar(pasta):
    """Cria a pasta (e as de cima). Devolve se ela existe no fim."""
    try:
        os.makedirs(pasta, exist_ok=True)
    except OSError:
        pass
    return os.path.isdir(pasta)


def mais_novo(pasta, tipos):
    """O arquivo mais novo da pasta (sem subpastas) com uma destas extensões: (mtime, caminho)."""
    melhor = None
    try:
        entradas = list(os.scandir(pasta))
    except OSError:
        return None
    for e in entradas:
        if e.name.startswith(".") or extensao(e.name) not in tipos:
            continue
        try:
            if not e.is_file():
                continue
            st = e.stat()
        except OSError:
            continue
        if st.st_size == 0:
            continue  # gravação interrompida no meio
        chave = (st.st_mtime, e.path)
        if melhor is None or chave > melhor:
            melhor = chave
    return melhor


def caminho_capa(capas, video):
    return os.path.join(capas, os.path.basename(video) + ".jpg")


def tem_ffmpeg():
    return shutil.which("ffmpeg") is not None


def fazer_capa(video, saida):
    """Uma foto do começo do vídeo, com o ffmpeg. Devolve se deu certo."""
    if not tem_ffmpeg() or not os.path.isfile(video):
        return False
    criar(os.path.dirname(saida) or ".")
    temporario = saida + ".parcial.jpg"
    for inicio in ("0.5", "0"):
        try:
            r = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-ss", inicio, "-i", video,
                                "-frames:v", "1", "-vf", "scale=480:-2", temporario],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        except (OSError, subprocess.TimeoutExpired):
            break
        if r.returncode == 0 and os.path.isfile(temporario) and os.path.getsize(temporario) > 0:
            os.replace(temporario, saida)
            return True
    try:
        os.remove(temporario)
    except OSError:
        pass
    return False


def inicio(imagens, videos, dados):
    lingua = idioma()
    nome = "Câmera" if lingua == "pt" else "Camera"
    fotos = os.path.join(imagens or os.path.join(casa(), "Imagens" if lingua == "pt" else "Pictures"), nome)
    pasta_videos = os.path.join(videos or os.path.join(casa(), "Vídeos" if lingua == "pt" else "Videos"), nome)
    capas = os.path.join(dados or os.path.join(casa(), ".local", "share", "matsu", "camera"), "capas")
    ok_fotos = criar(fotos)
    ok_videos = criar(pasta_videos)
    criar(capas)

    ultima = None
    candidatos = [c for c in ((mais_novo(fotos, FOTOS), "foto"), (mais_novo(pasta_videos, VIDEOS), "video")) if c[0]]
    if candidatos:
        (_, caminho), tipo = max(candidatos, key=lambda c: c[0])
        capa = ""
        if tipo == "video":
            capa = caminho_capa(capas, caminho)
            if not os.path.isfile(capa) and not fazer_capa(caminho, capa):
                capa = ""
        ultima = {"caminho": caminho, "tipo": tipo, "capa": capa}
    return {
        "idioma": lingua,
        "vidro": vidro(),
        "fotos": fotos,
        "videos": pasta_videos,
        "capas": capas,
        "pastasOk": ok_fotos and ok_videos,
        "ffmpeg": tem_ffmpeg(),
        "ultima": ultima,
    }


def principal(args):
    if len(args) >= 1 and args[0] == "inicio":
        resto = (args[1:] + ["", "", ""])[:3]
        print(json.dumps(inicio(*resto), ensure_ascii=False))
        return 0
    if len(args) == 3 and args[0] == "capa":
        print(json.dumps({"ok": fazer_capa(args[1], args[2])}))
        return 0
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
