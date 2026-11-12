#!/usr/bin/python3
"""Bloco de notas do Matsu: o ajudante que olha os arquivos antes de abrir.

A janela (os arquivos .qml desta pasta) lê e grava arquivos UTF-8 sozinha
(matsu.ler e matsu.gravar). Este script responde o que ela não sabe: o tamanho,
se o arquivo é binário, a codificação (UTF-8, UTF-16, Windows-1252...) e o fim
de linha. Também lê e grava os arquivos que não são UTF-8, sem trocar a
codificação deles. Só usa a biblioteca padrão do Python e responde em JSON.

Uso:
  ajudante.py ambiente                         idioma e vidro (JSON)
  ajudante.py examinar <arquivo>               tamanho, binário, codificação, fim de linha (JSON)
  ajudante.py ler <arquivo> <codificação>      o texto, numa linha JSON {"texto": ...}
  ajudante.py gravar <origem> <destino> <codificação>
                                               grava no destino o texto UTF-8 da origem, na
                                               codificação pedida, sem deixar o arquivo pela
                                               metade; apaga a origem
"""
import codecs
import json
import os
import re
import signal
import sys
import tempfile

# Acima disso a janela avisa antes de abrir (o editor fica lento com arquivos enormes).
LIMITE_GRANDE = 20 * 1024 * 1024
# Quanto do arquivo é olhado para achar a codificação e o fim de linha.
AMOSTRA = 4 * 1024 * 1024
# Para dizer se é binário basta o começo.
AMOSTRA_BINARIO = 64 * 1024

# Como cada codificação é lida e gravada pelo Python.
CODECS = {
    "utf-8": "utf-8",
    "utf-8-bom": "utf-8-sig",
    "utf-16-le": "utf-16-le",
    "utf-16-be": "utf-16-be",
    "windows-1252": "cp1252",
    "iso-8859-1": "latin-1",
}
BOMS = {
    "utf-8-bom": codecs.BOM_UTF8,
    "utf-16-le": codecs.BOM_UTF16_LE,
    "utf-16-be": codecs.BOM_UTF16_BE,
}


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


# ----- o que tem dentro do arquivo -----

def codificacao(dados, inteiro=True):
    """A codificação dos bytes: pela marca do começo (BOM) ou tentando o UTF-8.

    "inteiro" diz se os bytes são o arquivo todo; numa amostra, um caractere
    cortado no fim não conta como erro."""
    if dados.startswith(codecs.BOM_UTF8):
        return "utf-8-bom"
    if dados.startswith(codecs.BOM_UTF16_LE) and not dados.startswith(codecs.BOM_UTF32_LE):
        return "utf-16-le"
    if dados.startswith(codecs.BOM_UTF16_BE):
        return "utf-16-be"
    decodificador = codecs.getincrementaldecoder("utf-8")()
    try:
        decodificador.decode(dados, final=inteiro)
        return "utf-8"
    except UnicodeDecodeError:
        pass
    # Texto antigo do Windows (acentos em um byte só). Os cinco bytes que o
    # Windows-1252 não usa só existem no ISO-8859-1.
    if any(b in dados for b in (0x81, 0x8D, 0x8F, 0x90, 0x9D)):
        return "iso-8859-1"
    return "windows-1252"


def binario(dados, cod):
    """Se os bytes parecem de um programa, imagem ou outro formato que não é texto."""
    if cod in ("utf-16-le", "utf-16-be"):
        return False
    amostra = dados[:AMOSTRA_BINARIO]
    if not amostra:
        return False
    if b"\x00" in amostra:
        return True
    # Caracteres de controle que texto não usa (tab, quebras, form feed, ESC e backspace podem).
    permitidos = {8, 9, 10, 12, 13, 27}
    estranhos = sum(1 for b in amostra if b < 32 and b not in permitidos)
    return estranhos / len(amostra) > 0.1


def fim_de_linha(texto):
    """O fim de linha que o texto usa mais: crlf, lf, cr, ou "" sem nenhuma quebra."""
    crlf = texto.count("\r\n")
    cr = texto.count("\r") - crlf
    lf = texto.count("\n") - crlf
    if crlf == lf == cr == 0:
        return ""
    if crlf >= lf and crlf >= cr:
        return "crlf"
    return "lf" if lf >= cr else "cr"


def decodificar(dados, cod):
    texto = dados.decode(CODECS.get(cod, "utf-8"), errors="replace")
    # O utf-16 com a marca do começo (BOM): a marca não faz parte do texto.
    if texto.startswith("﻿"):
        texto = texto[1:]
    return texto


def examinar(caminho):
    # "./notas.txt" da linha de comando vira o caminho inteiro (a janela não sabe a pasta de onde foi aberta).
    caminho = os.path.abspath(os.path.expanduser(caminho))
    r = {"caminho": caminho, "existe": False, "pasta": False, "legivel": False, "tamanho": 0,
         "grande": False, "binario": False, "codificacao": "utf-8", "fim": ""}
    if not os.path.exists(caminho):
        return r
    r["existe"] = True
    if os.path.isdir(caminho):
        r["pasta"] = True
        return r
    try:
        r["tamanho"] = os.path.getsize(caminho)
        with open(caminho, "rb") as f:
            dados = f.read(AMOSTRA + 1)
    except OSError:
        return r
    r["legivel"] = True
    r["grande"] = r["tamanho"] > LIMITE_GRANDE
    inteiro = len(dados) <= AMOSTRA
    dados = dados[:AMOSTRA]
    cod = codificacao(dados, inteiro)
    r["codificacao"] = cod
    r["binario"] = binario(dados, cod)
    r["fim"] = fim_de_linha(decodificar(dados, cod))
    return r


def ler_arquivo(caminho, cod):
    with open(caminho, "rb") as f:
        return decodificar(f.read(), cod)


class CaractereForaError(Exception):
    """O texto tem um caractere que a codificação do arquivo não tem."""

    def __init__(self, caractere):
        super().__init__(caractere)
        self.caractere = caractere


def codificar(texto, cod):
    if cod in BOMS:
        # O BOM vai uma vez só, mesmo que o texto já comece com ele.
        corpo = texto[1:] if texto.startswith("﻿") else texto
        python = {"utf-8-bom": "utf-8", "utf-16-le": "utf-16-le", "utf-16-be": "utf-16-be"}[cod]
        return BOMS[cod] + corpo.encode(python)
    try:
        return texto.encode(CODECS.get(cod, "utf-8"))
    except UnicodeEncodeError as e:
        raise CaractereForaError(texto[e.start:e.end]) from e


def gravar_atomico(destino, dados):
    """Grava num arquivo ao lado e troca de uma vez: nunca fica pela metade.
    Mantém as permissões do arquivo que já existia (e segue o link, se for um)."""
    alvo = os.path.realpath(destino)
    pasta = os.path.dirname(alvo) or "."
    modo = None
    try:
        modo = os.stat(alvo).st_mode & 0o7777
    except OSError:
        pass
    fd, temporario = tempfile.mkstemp(prefix=".matsu-", dir=pasta)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(dados)
            f.flush()
            os.fsync(f.fileno())
        if modo is not None:
            os.chmod(temporario, modo)
        else:
            umask = os.umask(0)
            os.umask(umask)
            os.chmod(temporario, 0o666 & ~umask)
        os.replace(temporario, alvo)
    except BaseException:
        try:
            os.unlink(temporario)
        except OSError:
            pass
        raise


def gravar(origem, destino, cod):
    try:
        with open(origem, "r", encoding="utf-8", newline="") as f:
            texto = f.read()
    except OSError as e:
        return {"ok": False, "erro": "origem", "detalhe": str(e)}
    try:
        try:
            dados = codificar(texto, cod)
        except CaractereForaError as e:
            return {"ok": False, "erro": "caracteres", "caractere": e.caractere}
        try:
            gravar_atomico(destino, dados)
        except PermissionError as e:
            return {"ok": False, "erro": "permissao", "detalhe": str(e)}
        except OSError as e:
            return {"ok": False, "erro": "gravar", "detalhe": str(e)}
        return {"ok": True}
    finally:
        try:
            os.unlink(origem)
        except OSError:
            pass


def responder(dados):
    print(json.dumps(dados, ensure_ascii=False))


def main(args):
    if not args:
        print(__doc__)
        return 2
    comando, resto = args[0], args[1:]
    if comando == "ambiente":
        responder({"idioma": idioma(), "vidro": vidro()})
        return 0
    if comando == "examinar" and len(resto) == 1:
        responder(examinar(resto[0]))
        return 0
    if comando == "ler" and len(resto) == 2:
        try:
            responder({"texto": ler_arquivo(resto[0], resto[1]), "codificacao": resto[1]})
        except OSError as e:
            responder({"erro": str(e)})
            return 1
        return 0
    if comando == "gravar" and len(resto) == 3:
        r = gravar(resto[0], resto[1], resto[2])
        responder(r)
        return 0 if r["ok"] else 1
    print(__doc__)
    return 2


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    sys.exit(main(sys.argv[1:]))
