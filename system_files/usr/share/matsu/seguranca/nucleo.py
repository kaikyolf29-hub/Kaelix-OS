#!/usr/bin/python3
"""Central de segurança do Matsu: o miolo dividido pelo ajudante e pelo escudo.

Aqui ficam as peças que não desenham nada: onde moram os arquivos da pessoa, a
quarentena, a lista de exceções (por SHA-256), o histórico, a pausa do escudo,
de onde veio um arquivo (o atributo que o navegador grava), o filtro dos
arquivos que ainda estão baixando e a conversa com o clamd pelo soquete local.

Quem usa:
  ajudante.py  a janela, o aviso de arquivo desconhecido e o ícone da bandeja
  escudo.py    o serviço do usuário que vigia Downloads, Área de trabalho e pendrives

Só a biblioteca padrão do Python. Nada aqui roda como root: o que precisa de
root passa pelo systemd (com a regra do polkit da Central de segurança).
"""
import errno
import fcntl
import hashlib
import json
import os
import re
import shutil
import socket
import stat
import struct
import subprocess
import time

# ----- onde estão as coisas (os testes trocam pelas variáveis) -----
CLAMAV_DB = os.environ.get("MATSU_CLAMAV_DB", "/var/lib/clamav")
CLAMD_BIN = os.environ.get("MATSU_CLAMD_BIN", "/usr/sbin/clamd")
SOCKET_CLAMD = os.environ.get("MATSU_CLAMD_SOCKET", "/run/matsu-escudo/clamd.sock")
UNIDADE_CLAMD = "matsu-escudo-clamd.service"
UNIDADE_ATUALIZAR = "matsu-escudo-atualizar.service"
UNIDADE_ESCUDO = "matsu-escudo.service"
MATSU_JANELA = "/usr/libexec/matsu/matsu-janela"
CENTRAL_QML = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Main.qml")
AVISO_QML = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Aviso.qml")
ID_APP = "org.matsu.seguranca"

# O clamd fica parado quando não tem nada para verificar (ele ocupa ~1 GB de RAM).
OCIOSO_SEGUNDOS = int(os.environ.get("MATSU_ESCUDO_OCIOSO", "600"))
# Até este tamanho o arquivo é verificado (o mesmo limite do clamd.conf).
MAIOR_ARQUIVO = 400 * 1024 * 1024
# Tamanho aproximado da lista de ameaças completa, para a barra do primeiro download.
TAMANHO_LISTA = 230 * 1024 * 1024

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


def dados_casa():
    return os.environ.get("XDG_DATA_HOME") or os.path.join(casa(), ".local", "share")


def pasta_dados():
    return os.environ.get("MATSU_SEGURANCA_DADOS") or os.path.join(dados_casa(), "matsu", "seguranca")


def pasta_quarentena():
    return os.path.join(pasta_dados(), "quarentena")


def arquivo_historico():
    return os.path.join(pasta_dados(), "historico.json")


def arquivo_excecoes():
    return os.path.join(pasta_dados(), "excecoes.json")


def arquivo_config():
    return os.environ.get("MATSU_SEGURANCA_CONFIG") or os.path.join(config_casa(), "matsu", "seguranca.json")


def pasta_execucao():
    base = os.environ.get("MATSU_SEGURANCA_EXECUCAO")
    if base:
        return base
    run = os.environ.get("XDG_RUNTIME_DIR")
    return os.path.join(run, "matsu-seguranca") if run else os.path.join(casa(), ".cache", "matsu-seguranca")


def arquivo_escudo():
    """O estado que o escudo (serviço) grava para a janela e a bandeja lerem."""
    return os.path.join(pasta_execucao(), "escudo.json")


def criar_pasta(caminho, modo=0o700):
    try:
        os.makedirs(caminho, mode=modo, exist_ok=True)
    except OSError:
        pass
    return os.path.isdir(caminho)


# ----- JSON gravado de uma vez, com trava (o escudo e a janela mexem juntos) -----
def ler_json(caminho, padrao=None):
    try:
        with open(caminho, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return padrao


def gravar_json(caminho, dados, modo=0o600):
    """Grava num arquivo novo e troca (ninguém lê pela metade)."""
    criar_pasta(os.path.dirname(caminho))
    temp = "%s.%d.tmp" % (caminho, os.getpid())
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, modo)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(dados, f, ensure_ascii=False, indent=1)
        f.flush()
        os.fsync(f.fileno())
    os.replace(temp, caminho)


class Trava:
    """Trava de arquivo para ler, mudar e gravar uma lista sem perder o que o outro gravou."""

    def __init__(self, nome):
        self.caminho = os.path.join(pasta_dados(), "." + nome + ".trava")
        self.fd = None

    def __enter__(self):
        criar_pasta(pasta_dados())
        self.fd = os.open(self.caminho, os.O_RDWR | os.O_CREAT, 0o600)
        fcntl.flock(self.fd, fcntl.LOCK_EX)
        return self

    def __exit__(self, *erro):
        try:
            fcntl.flock(self.fd, fcntl.LOCK_UN)
        finally:
            os.close(self.fd)


# ----- língua e vidro (como os outros apps do Matsu) -----
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


def t(portugues, ingles):
    return portugues if idioma() == "pt" else ingles


def vidro():
    pasta = os.environ.get("MATSU_STATE_DIR") or os.path.join(config_casa(), "matsu")
    valores = {}
    for linha in ler(os.path.join(pasta, "vidro")).splitlines():
        chave, _, valor = linha.partition("=")
        valores[chave.strip()] = valor.strip().lower()
    cor = valores.get("cor", "")
    cor = CORES_VIDRO.get(cor, cor if re.fullmatch(r"#[0-9a-f]{6}", cor) else "")
    nivel = valores.get("transparencia", "normal")
    return {"cor": cor, "nivel": nivel if nivel in ("mais", "normal", "menos", "sem") else "normal"}


# ----- ajustes da pessoa e a pausa do escudo -----
PADRAO = {
    "ligado": True,          # escudo em tempo real
    "pausa_ate": 0,          # pausado até esta hora (segundos desde 1970)
    "pausa_boot": "",        # pausado até reiniciar: o boot_id de quando pausou
    "pendrive_auto": False,  # verificar pendrives sozinho, sem perguntar
    "esperar_jogo": True,    # com um jogo aberto, a verificação espera o jogo fechar
    "visto_ate": 0,          # ameaças até esta hora já foram vistas na central
}


def ler_config():
    c = dict(PADRAO)
    lido = ler_json(arquivo_config(), {})
    if isinstance(lido, dict):
        for chave, valor in lido.items():
            if chave in PADRAO and type(valor) is type(PADRAO[chave]):
                c[chave] = valor
    return c


def gravar_config(c):
    limpo = {k: c.get(k, v) for k, v in PADRAO.items()}
    gravar_json(arquivo_config(), limpo)
    return limpo


def boot_id():
    return (os.environ.get("MATSU_BOOT_ID") or ler("/proc/sys/kernel/random/boot_id")).strip()


def estado_pausa(c, agora=None):
    """{"pausado", "ate" (segundos, 0 se até reiniciar), "reiniciar"}."""
    agora = time.time() if agora is None else agora
    if c.get("pausa_boot"):
        if c["pausa_boot"] == boot_id():
            return {"pausado": True, "ate": 0, "reiniciar": True}
        return {"pausado": False, "ate": 0, "reiniciar": False}
    ate = float(c.get("pausa_ate") or 0)
    if ate > agora:
        return {"pausado": True, "ate": ate, "reiniciar": False}
    return {"pausado": False, "ate": 0, "reiniciar": False}


def pausar(c, quanto, agora=None):
    """quanto: minutos (15, 60...) ou "reiniciar". Devolve os ajustes novos (sem gravar)."""
    agora = time.time() if agora is None else agora
    novo = dict(c)
    if quanto == "reiniciar":
        novo["pausa_boot"] = boot_id() or "?"
        novo["pausa_ate"] = 0
    else:
        minutos = max(1, min(24 * 60, int(quanto)))
        novo["pausa_ate"] = int(agora + minutos * 60)
        novo["pausa_boot"] = ""
    return novo


def retomar(c):
    novo = dict(c)
    novo["pausa_ate"] = 0
    novo["pausa_boot"] = ""
    return novo


def pausa_venceu(c, agora=None):
    """A pausa tinha prazo e o prazo passou (o escudo volta e avisa)."""
    agora = time.time() if agora is None else agora
    if c.get("pausa_boot"):
        return c["pausa_boot"] != boot_id()
    return 0 < float(c.get("pausa_ate") or 0) <= agora


# ----- pastas da pessoa (os nomes de verdade, em português no Brasil) -----
def pastas_usuario():
    """{"downloads": ..., "area": ...} pelo user-dirs.dirs (o xdg-user-dir lê o mesmo arquivo)."""
    valores = {}
    for linha in ler(os.path.join(config_casa(), "user-dirs.dirs")).splitlines():
        m = re.match(r'\s*(XDG_[A-Z]+_DIR)\s*=\s*"(.*)"\s*$', linha)
        if m:
            valor = m.group(2).replace("$HOME", casa())
            valores[m.group(1)] = valor if valor.startswith("/") else os.path.join(casa(), valor)
    downloads = valores.get("XDG_DOWNLOAD_DIR") or os.path.join(casa(), "Downloads")
    area = valores.get("XDG_DESKTOP_DIR")
    if not area:
        area = next((os.path.join(casa(), n) for n in ("Área de trabalho", "Desktop")
                     if os.path.isdir(os.path.join(casa(), n))), os.path.join(casa(), "Desktop"))
    # A pasta pessoal não é "Área de trabalho" (o xdg usa $HOME quando não há a pasta).
    if os.path.normpath(area) == os.path.normpath(casa()):
        area = ""
    return {"downloads": downloads, "area": area}


def dentro_de(caminho, pasta):
    if not pasta:
        return False
    try:
        caminho = os.path.realpath(caminho)
        pasta = os.path.realpath(pasta)
    except OSError:
        return False
    return caminho == pasta or caminho.startswith(pasta.rstrip("/") + "/")


# ----- arquivos que ainda estão baixando -----
# O navegador baixa com outro nome e troca para o nome final no fim: o escudo só
# olha o arquivo final (Chrome/Brave .crdownload, Firefox .part, qBittorrent .!qB...).
SUFIXOS_TEMPORARIOS = (".crdownload", ".part", ".partial", ".tmp", ".temp", ".download", ".opdownload",
                       ".!qb", ".!ut", ".aria2", ".filepart", ".swp", ".swx", ".kate-swp", ".crswap", "~")


def e_temporario(nome):
    nome = os.path.basename(nome)
    baixo = nome.lower()
    if not nome or nome.startswith("."):
        # Arquivos escondidos: o Chrome baixa em ".com.google.Chrome.XXXX", o GTK em ".goutputstream-...".
        return True
    if baixo.endswith(SUFIXOS_TEMPORARIOS):
        return True
    # Firefox: "foto.jpg.part" e às vezes "foto.jpg.XXXXXX.part".
    if re.search(r"\.part$|\.[a-z0-9]{6,8}\.part$", baixo):
        return True
    return baixo.startswith(("~$", ".~lock."))


# ----- de onde veio um arquivo -----
def _atributo(caminho, nome):
    try:
        valor = os.getxattr(caminho, nome)
    except (OSError, AttributeError):
        return ""
    return valor.decode("utf-8", "replace").strip("\0").strip()


def site_de(url):
    m = re.match(r"^[a-z][a-z0-9+.-]*://(?:[^/@]*@)?([^/:?#]+)", url or "", re.I)
    if not m:
        return ""
    host = m.group(1).lower()
    return host[4:] if host.startswith("www.") else host


def origem(caminho):
    """De onde veio: o endereço que o navegador gravou no arquivo (Brave, Chrome e os
    Arquivos do KDE gravam "user.xdg.origin.url") ou, sem ele, se está em Downloads."""
    url = _atributo(caminho, "user.xdg.origin.url")
    referencia = _atributo(caminho, "user.xdg.referrer.url")
    em_downloads = dentro_de(caminho, pastas_usuario()["downloads"])
    internet = bool(url or referencia or em_downloads)
    return {
        "url": url,
        "referencia": referencia,
        "site": site_de(url) or site_de(referencia),
        "downloads": em_downloads,
        "internet": internet,
    }


# ----- impressão digital do arquivo -----
def sha256_arquivo(caminho, parar=None):
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        while True:
            bloco = f.read(1024 * 1024)
            if not bloco:
                break
            h.update(bloco)
            if parar and parar():
                raise InterruptedError()
    return h.hexdigest()


# ----- lista de exceções (arquivos liberados pela pessoa, pelo SHA-256) -----
def ler_excecoes():
    lista = ler_json(arquivo_excecoes(), [])
    return [e for e in lista if isinstance(e, dict) and re.fullmatch(r"[0-9a-f]{64}", str(e.get("sha256", "")))] \
        if isinstance(lista, list) else []


def tem_excecao(sha):
    sha = (sha or "").lower()
    return any(e["sha256"] == sha for e in ler_excecoes())


def por_excecao(sha, nome="", url="", motivo="liberado", agora=None):
    sha = (sha or "").lower()
    if not re.fullmatch(r"[0-9a-f]{64}", sha):
        raise ValueError("SHA-256 inválido")
    with Trava("excecoes"):
        lista = [e for e in ler_excecoes() if e["sha256"] != sha]
        lista.insert(0, {"sha256": sha, "nome": os.path.basename(nome), "url": url, "motivo": motivo,
                         "data": int(time.time() if agora is None else agora)})
        gravar_json(arquivo_excecoes(), lista[:500])
    return lista[0]


def tirar_excecao(sha):
    sha = (sha or "").lower()
    with Trava("excecoes"):
        antes = ler_excecoes()
        lista = [e for e in antes if e["sha256"] != sha]
        gravar_json(arquivo_excecoes(), lista)
    return len(lista) != len(antes)


# ----- histórico -----
MAX_HISTORICO = 400


def ler_historico():
    lista = ler_json(arquivo_historico(), [])
    return [e for e in lista if isinstance(e, dict) and e.get("tipo")] if isinstance(lista, list) else []


def registrar(tipo, nome="", detalhe="", agora=None, **extra):
    """Um acontecimento no histórico: ameaça, quarentena, verificação, aviso..."""
    item = {"id": "%x%04x" % (int(time.time() * 1000), int.from_bytes(os.urandom(2), "big")),
            "tipo": tipo, "nome": os.path.basename(nome) if nome.startswith("/") else nome,
            "detalhe": detalhe, "data": int(time.time() if agora is None else agora)}
    item.update({k: v for k, v in extra.items() if v not in (None, "")})
    with Trava("historico"):
        lista = ler_historico()
        lista.insert(0, item)
        gravar_json(arquivo_historico(), lista[:MAX_HISTORICO])
    return item


# ----- quarentena -----
# O arquivo vai embaralhado (cada byte trocado por XOR): não roda, não abre por
# engano e outro antivírus não acusa de novo. Fica sem permissão de execução, numa
# pasta só da pessoa, com um .json ao lado dizendo de onde veio.
_EMBARALHAR = bytes(b ^ 0x5A for b in range(256))


def _copiar_embaralhado(origem_fd, destino_fd):
    while True:
        bloco = os.read(origem_fd, 1024 * 1024)
        if not bloco:
            break
        dados = bloco.translate(_EMBARALHAR)
        while dados:
            n = os.write(destino_fd, dados)
            dados = dados[n:]


def quarentenar(caminho, ameaca="", url="", sha=None, agora=None):
    """Tira o arquivo do lugar e guarda na quarentena. Devolve o registro (dict)."""
    caminho = os.path.abspath(caminho)
    st = os.lstat(caminho)
    if not stat.S_ISREG(st.st_mode):
        raise OSError(errno.EINVAL, "não é um arquivo comum", caminho)
    pasta = pasta_quarentena()
    criar_pasta(pasta)
    os.chmod(pasta, 0o700)
    if not url:
        url = origem(caminho)["url"]
    agora = time.time() if agora is None else agora
    ident = "%x%04x" % (int(agora * 1000), int.from_bytes(os.urandom(2), "big"))
    destino = os.path.join(pasta, ident + ".bin")
    fd_origem = os.open(caminho, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        if sha is None:
            h = hashlib.sha256()
            while True:
                bloco = os.read(fd_origem, 1024 * 1024)
                if not bloco:
                    break
                h.update(bloco)
            sha = h.hexdigest()
            os.lseek(fd_origem, 0, os.SEEK_SET)
        fd_destino = os.open(destino, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        try:
            _copiar_embaralhado(fd_origem, fd_destino)
            os.fsync(fd_destino)
        finally:
            os.close(fd_destino)
    finally:
        os.close(fd_origem)
    os.chmod(destino, 0o400)
    registro = {"id": ident, "nome": os.path.basename(caminho), "origem": caminho, "url": url,
                "sha256": sha, "ameaca": ameaca, "data": int(agora), "tamanho": st.st_size,
                "modo": stat.S_IMODE(st.st_mode)}
    gravar_json(os.path.join(pasta, ident + ".json"), registro)
    try:
        os.unlink(caminho)
    except OSError:
        # Não deu para tirar do lugar (pendrive só de leitura): desfaz e avisa.
        for f in (destino, os.path.join(pasta, ident + ".json")):
            try:
                os.chmod(f, 0o600)
                os.unlink(f)
            except OSError:
                pass
        raise
    registrar("quarentena", registro["nome"], ameaca, agora=agora, origem=caminho, sha256=sha, url=url)
    return registro


def listar_quarentena():
    pasta = pasta_quarentena()
    itens = []
    try:
        nomes = os.listdir(pasta)
    except OSError:
        return []
    for nome in nomes:
        if not nome.endswith(".json"):
            continue
        r = ler_json(os.path.join(pasta, nome))
        if isinstance(r, dict) and r.get("id") and os.path.exists(os.path.join(pasta, r["id"] + ".bin")):
            itens.append(r)
    itens.sort(key=lambda r: r.get("data", 0), reverse=True)
    return itens


def _ident_valido(ident):
    return bool(re.fullmatch(r"[0-9a-f]{6,24}", ident or ""))


def _livre(caminho):
    """Um nome livre: "foto.exe" vira "foto (restaurado).exe", "foto (restaurado 2).exe"..."""
    if not os.path.lexists(caminho):
        return caminho
    base, ext = os.path.splitext(caminho)
    if base.endswith(".tar"):
        base, ext = base[:-4], ".tar" + ext
    for n in range(1, 1000):
        sufixo = " (restaurado)" if n == 1 else " (restaurado %d)" % n
        novo = base + sufixo + ext
        if not os.path.lexists(novo):
            return novo
    raise OSError(errno.EEXIST, "sem nome livre", caminho)


def restaurar(ident, agora=None):
    """Põe o arquivo de volta (com outro nome se o lugar estiver ocupado) e libera o
    SHA-256 dele, para o escudo não pegar de novo."""
    if not _ident_valido(ident):
        raise ValueError("item inválido")
    pasta = pasta_quarentena()
    meta = os.path.join(pasta, ident + ".json")
    guardado = os.path.join(pasta, ident + ".bin")
    r = ler_json(meta)
    if not isinstance(r, dict) or not os.path.exists(guardado):
        raise FileNotFoundError(ident)
    alvo = r.get("origem") or ""
    if not alvo.startswith("/") or not os.path.isdir(os.path.dirname(alvo)) \
            or not os.access(os.path.dirname(alvo), os.W_OK):
        # A pasta de antes sumiu (pendrive tirado): volta para Downloads.
        downloads = pastas_usuario()["downloads"]
        criar_pasta(downloads, 0o755)
        alvo = os.path.join(downloads, r.get("nome") or ident)
    alvo = _livre(alvo)
    modo = int(r.get("modo", 0o644)) & 0o777
    fd_origem = os.open(guardado, os.O_RDONLY)
    try:
        fd_destino = os.open(alvo, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        try:
            _copiar_embaralhado(fd_origem, fd_destino)
            os.fsync(fd_destino)
        finally:
            os.close(fd_destino)
    finally:
        os.close(fd_origem)
    os.chmod(alvo, modo or 0o644)
    if r.get("sha256"):
        por_excecao(r["sha256"], r.get("nome", ""), r.get("url", ""), "restaurado", agora=agora)
    for f in (guardado, meta):
        try:
            os.chmod(f, 0o600)
            os.unlink(f)
        except OSError:
            pass
    registrar("restaurado", r.get("nome", ""), r.get("ameaca", ""), agora=agora, origem=alvo)
    return {"ok": True, "caminho": alvo}


def apagar_quarentena(ident, agora=None):
    if not _ident_valido(ident):
        raise ValueError("item inválido")
    pasta = pasta_quarentena()
    r = ler_json(os.path.join(pasta, ident + ".json")) or {}
    achou = False
    for f in (os.path.join(pasta, ident + ".bin"), os.path.join(pasta, ident + ".json")):
        try:
            os.chmod(f, 0o600)
            os.unlink(f)
            achou = True
        except OSError:
            pass
    if achou:
        registrar("apagado", r.get("nome", ""), r.get("ameaca", ""), agora=agora)
    return achou


# ----- o clamd (o antivírus), pelo soquete local -----
def lista_presente(db=None):
    """A lista de ameaças (main e daily) já foi baixada."""
    db = db or CLAMAV_DB
    try:
        nomes = set(os.listdir(db))
    except OSError:
        return False
    tem = lambda base: any(base + ext in nomes for ext in (".cvd", ".cld")) or (base + ".inc") in nomes  # noqa: E731
    return tem("main") and tem("daily")


def info_lista(db=None):
    """Versão e data da lista de ameaças (o cabeçalho de 512 bytes do daily)."""
    db = db or CLAMAV_DB
    melhor = None
    for nome in ("daily.cld", "daily.cvd"):
        caminho = os.path.join(db, nome)
        try:
            with open(caminho, "rb") as f:
                cabeca = f.read(512).decode("ascii", "replace")
            quando = os.stat(caminho).st_mtime
        except OSError:
            continue
        partes = cabeca.split(":")
        if len(partes) >= 4 and partes[0] == "ClamAV-VDB":
            try:
                versao = int(partes[2])
            except ValueError:
                versao = 0
            if not melhor or versao > melhor["versao"]:
                melhor = {"versao": versao, "assinaturas": int(partes[3]) if partes[3].isdigit() else 0,
                          "data": int(quando)}
    return melhor


def clamav_instalado():
    return os.path.exists(CLAMD_BIN)


class SemLista(Exception):
    """A lista de ameaças ainda não foi baixada."""


class EscudoIndisponivel(Exception):
    pass


def ler_resposta(texto):
    """'fd[10]: Win.Test.EICAR_HDB-1 FOUND' -> ("FOUND", "Win.Test.EICAR_HDB-1")."""
    texto = texto.strip("\0").strip()
    if ": " in texto and texto.split(": ", 1)[0].startswith(("fd[", "stream", "/")):
        texto = texto.split(": ", 1)[1]
    if texto == "OK" or texto.endswith(": OK"):
        return "OK", ""
    if texto.endswith(" FOUND"):
        return "FOUND", texto[:-6].strip()
    if texto.endswith(" ERROR"):
        return "ERROR", texto[:-6].strip()
    return "ERROR", texto


class Clamd:
    """Conversa com o clamd. O arquivo é aberto aqui, com a permissão da pessoa, e só
    o descritor vai pelo soquete (FILDES): o clamd roda como outro usuário e não
    consegue (nem precisa) ler a pasta pessoal."""

    # Depois que o descritor falhar uma vez, vai direto pelo fluxo.
    so_fluxo = False

    def __init__(self, caminho=None, tempo=120):
        self.caminho = caminho or SOCKET_CLAMD
        self.tempo = tempo

    def _conectar(self, tempo=None):
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(tempo or self.tempo)
        s.connect(self.caminho)
        return s

    @staticmethod
    def _ler_tudo(s):
        partes = []
        while True:
            bloco = s.recv(4096)
            if not bloco:
                break
            partes.append(bloco)
            if bloco.endswith(b"\0"):
                break
        return b"".join(partes).decode("utf-8", "replace")

    def comando(self, cmd, tempo=None):
        s = self._conectar(tempo)
        try:
            s.sendall(b"z" + cmd.encode() + b"\0")
            return self._ler_tudo(s).strip("\0").strip()
        finally:
            s.close()

    def pronto(self):
        try:
            return self.comando("PING", 3) == "PONG"
        except OSError:
            return False

    def versao(self):
        try:
            return self.comando("VERSION", 3)
        except OSError:
            return ""

    def verificar_fd(self, fd):
        s = self._conectar()
        try:
            s.sendall(b"zFILDES\0")
            socket.send_fds(s, [b"\0"], [fd])
            return ler_resposta(self._ler_tudo(s))
        finally:
            s.close()

    def verificar_fluxo(self, fd):
        """INSTREAM: manda o conteúdo pelo soquete (quando o clamd não pode usar o
        descritor, por exemplo se o SELinux não deixar)."""
        s = self._conectar()
        try:
            s.sendall(b"zINSTREAM\0")
            os.lseek(fd, 0, os.SEEK_SET)
            while True:
                bloco = os.read(fd, 256 * 1024)
                if not bloco:
                    break
                s.sendall(struct.pack(">I", len(bloco)) + bloco)
            s.sendall(struct.pack(">I", 0))
            return ler_resposta(self._ler_tudo(s))
        finally:
            s.close()

    def verificar(self, caminho):
        """("OK" | "FOUND" | "ERROR", nome da ameaça ou o erro)."""
        try:
            fd = os.open(caminho, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        except OSError as e:
            return "ERROR", e.strerror or str(e)
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode):
                return "ERROR", "não é um arquivo comum"
            if not Clamd.so_fluxo:
                resultado = self.verificar_fd(fd)
                if resultado[0] != "ERROR":
                    return resultado
                Clamd.so_fluxo = True
            return self.verificar_fluxo(fd)
        finally:
            os.close(fd)

    def desligar(self):
        try:
            s = self._conectar(3)
            s.sendall(b"zSHUTDOWN\0")
            s.close()
            return True
        except OSError:
            return False


def rodar(args, tempo=30, entrada=None):
    """(código, saída). Sem o programa: (127, "")."""
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=tempo, input=entrada)
        return r.returncode, r.stdout
    except FileNotFoundError:
        return 127, ""
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""


def estado_unidade(nome, usuario=False):
    """O que o systemd diz da unidade: {"ativo": "active|inactive|failed|activating...", "resultado", ...}."""
    args = ["systemctl"] + (["--user"] if usuario else []) + [
        "show", "--property=ActiveState,SubState,Result,ExecMainStatus,LoadState,IPIngressBytes,ActiveEnterTimestampMonotonic",
        nome]
    codigo, saida = rodar(args, 5)
    valores = {}
    for linha in saida.splitlines():
        chave, _, valor = linha.partition("=")
        valores[chave] = valor
    return {
        "existe": codigo == 0 and valores.get("LoadState") == "loaded",
        "ativo": valores.get("ActiveState", "") if codigo == 0 else "",
        "sub": valores.get("SubState", ""),
        "resultado": valores.get("Result", ""),
        "baixado": int(valores["IPIngressBytes"]) if valores.get("IPIngressBytes", "").isdigit() else 0,
    }


def iniciar_unidade(nome, esperar=False):
    """Pede ao systemd (a regra do polkit da Central deixa, sem senha, só estas unidades)."""
    args = ["systemctl", "start", "--no-ask-password"] + ([] if esperar else ["--no-block"]) + [nome]
    return rodar(args, 600 if esperar else 15)[0] == 0


def parar_unidade(nome):
    return rodar(["systemctl", "stop", "--no-ask-password", "--no-block", nome], 15)[0] == 0


def marcar_uso():
    """Toda verificação marca a hora: o escudo só desliga o clamd depois de 10 min parado."""
    caminho = os.path.join(pasta_execucao(), "uso")
    criar_pasta(pasta_execucao())
    try:
        with open(caminho, "a"):
            pass
        os.utime(caminho, None)
    except OSError:
        pass


def ultimo_uso():
    try:
        return os.stat(os.path.join(pasta_execucao(), "uso")).st_mtime
    except OSError:
        return 0


def ligar_clamd(avisar=None, parar=None, tempo=420):
    """Sobe o clamd se estiver parado e espera ele ficar pronto (carregar a lista
    de ameaças leva de 10 a 40 segundos). Devolve um Clamd pronto."""
    c = Clamd()
    marcar_uso()
    if c.pronto():
        return c
    if not clamav_instalado():
        raise EscudoIndisponivel(t("O antivírus não está instalado.", "The antivirus is not installed."))
    if not lista_presente():
        raise SemLista()
    if avisar:
        avisar(t("Preparando o escudo...", "Getting the shield ready..."))
    iniciar_unidade(UNIDADE_CLAMD)
    inicio = time.time()
    while time.time() - inicio < tempo:
        if parar and parar():
            raise InterruptedError()
        if c.pronto():
            marcar_uso()
            return c
        u = estado_unidade(UNIDADE_CLAMD)
        if u["ativo"] == "failed" or (u["ativo"] == "inactive" and time.time() - inicio > 8):
            raise EscudoIndisponivel(t("O escudo não conseguiu começar.", "The shield could not start."))
        time.sleep(0.5)
    raise EscudoIndisponivel(t("O escudo demorou demais para começar.", "The shield took too long to start."))


# ----- o que a verificação pula -----
# Caminhos a partir da pasta pessoal. Jogos e lojas de jogos ficam de fora (são
# muitos gigabytes e verificar deixaria o computador lento sem ganho); caches e
# lixeira também. A quarentena, claro, também.
PULAR_CASA = (
    ".steam", ".local/share/Steam", ".var/app/com.valvesoftware.Steam",
    ".local/share/lutris", ".var/app/net.lutris.Lutris", ".var/app/com.heroicgameslauncher.hgl",
    "Games", "Jogos", ".local/share/umu", ".cache", ".local/share/Trash", ".local/share/flatpak",
    ".local/share/containers", ".local/share/matsu/seguranca", ".var/app/com.usebottles.bottles/cache",
    ".npm", ".cargo/registry", ".rustup", "go/pkg/mod", ".gradle/caches", ".m2/repository",
    ".local/share/baloo", ".local/share/waydroid",
)
# Nomes de pasta que ficam de fora em qualquer lugar.
PULAR_NOMES = {"node_modules", ".git", ".hg", ".svn", "steamapps", "compatdata", "shadercache", "__pycache__",
               "SteamLibrary", ".Trash-1000", "cache", "Cache", "GPUCache", "ShaderCache", "Code Cache"}


def pastas_puladas():
    base = casa()
    lista = [os.path.join(base, p) for p in PULAR_CASA]
    # .var/app/<app>/cache de todos os apps Flatpak.
    try:
        for app in os.listdir(os.path.join(base, ".var", "app")):
            lista.append(os.path.join(base, ".var", "app", app, "cache"))
    except OSError:
        pass
    return lista


def arquivos_de(raizes, parar=None, pular=None, mesmo_disco=True):
    """Anda pelas pastas (sem seguir atalhos, sem entrar em outro disco montado
    dentro delas) e devolve (caminho, tamanho) de cada arquivo comum."""
    pular = set(os.path.normpath(p) for p in (pastas_puladas() if pular is None else pular))
    vistos = set()
    for raiz in raizes:
        try:
            st_raiz = os.lstat(raiz)
        except OSError:
            continue
        if stat.S_ISREG(st_raiz.st_mode):
            yield raiz, st_raiz.st_size
            continue
        if not stat.S_ISDIR(st_raiz.st_mode):
            continue
        pilha = [raiz]
        while pilha:
            if parar and parar():
                return
            pasta = pilha.pop()
            if pasta in vistos:
                continue
            vistos.add(pasta)
            try:
                entradas = list(os.scandir(pasta))
            except OSError:
                continue
            for e in entradas:
                try:
                    if e.is_symlink():
                        continue
                    if e.is_dir(follow_symlinks=False):
                        caminho = os.path.normpath(e.path)
                        if e.name in PULAR_NOMES or caminho in pular:
                            continue
                        if mesmo_disco and e.stat(follow_symlinks=False).st_dev != st_raiz.st_dev:
                            continue
                        pilha.append(caminho)
                    elif e.is_file(follow_symlinks=False):
                        yield e.path, e.stat(follow_symlinks=False).st_size
                except OSError:
                    continue


def raizes_rapida():
    """A verificação rápida: Downloads, Área de trabalho e os lugares onde um programa
    se instala para abrir sozinho (início automático, atalhos e programas da pessoa)."""
    p = pastas_usuario()
    base = casa()
    lista = [p["downloads"], p["area"], os.path.join(config_casa(), "autostart"),
             os.path.join(dados_casa(), "applications"), os.path.join(base, ".local", "bin"), os.path.join(base, "bin")]
    return [r for r in lista if r and os.path.isdir(r)]


def raizes_completa():
    return [casa()]


# ----- avisos (notificações do Plasma) -----
def avisar(titulo, texto, acoes=(), urgente=False, espera=900, icone="org.matsu.seguranca"):
    """Notificação com botões; devolve o id do botão escolhido ("" se nenhum)."""
    if not shutil.which("notify-send"):
        return ""
    args = ["notify-send", "--app-name=" + t("Segurança", "Security"), "--icon=" + icone,
            "--hint=string:desktop-entry:" + ID_APP]
    if urgente:
        args.append("--urgency=critical")
    for ident, nome in acoes:
        args.append("--action=%s=%s" % (ident, nome))
    args += [titulo, texto]
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=espera if acoes else 20)
        linhas = r.stdout.strip().splitlines()
        return linhas[-1].strip() if linhas else ""
    except (OSError, subprocess.TimeoutExpired):
        return ""


def soltar(args, pasta=None, ambiente=None):
    """Abre um programa que continua aberto sozinho."""
    try:
        subprocess.Popen(args, cwd=pasta, env=ambiente, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
        return True
    except OSError:
        return False


def abrir_central(*args):
    return soltar([MATSU_JANELA, ID_APP, CENTRAL_QML] + list(args))


# ----- jogo aberto (a Central de jogos grava quando um jogo abre) -----
def jogo_aberto():
    base = os.environ.get("MATSU_JOGOS_ESTADO") or os.path.join(
        os.environ.get("XDG_RUNTIME_DIR") or os.path.join(casa(), ".cache"), "matsu-jogos")
    estado = ler_json(os.path.join(base, "agora.json"), {}) or {}
    return bool(isinstance(estado, dict) and estado.get("jogo"))


# ----- tipos de arquivo que o aviso conhece -----
def _cabeca(caminho, n=64):
    try:
        with open(caminho, "rb") as f:
            return f.read(n)
    except OSError:
        return b""


def tipo_arquivo(caminho):
    """appimage, elf, biblioteca, script, instalador (.run), deb, rpm, windows, java ou ""."""
    nome = os.path.basename(caminho).lower()
    cabeca = _cabeca(caminho)
    elf = cabeca[:4] == b"\x7fELF"
    if nome.endswith(".appimage") or (elf and cabeca[8:11] == b"AI\x02"):
        return "appimage"
    if nome.endswith((".deb", ".udeb")):
        return "deb"
    if nome.endswith(".rpm") or cabeca[:4] == b"\xed\xab\xee\xdb":
        return "rpm"
    if nome.endswith(".jar"):
        return "java"
    if nome.endswith((".exe", ".msi", ".com", ".scr", ".bat", ".cmd", ".cpl", ".msix", ".appx")) or cabeca[:2] == b"MZ":
        return "windows"
    if nome.endswith(".run"):
        return "instalador"
    if elf:
        if re.search(r"\.so(\.\d+)*$", nome):
            return "biblioteca"
        return "elf"
    if nome.endswith((".sh", ".bash", ".zsh", ".command")) or cabeca[:2] == b"#!":
        return "script"
    return ""


def _secoes_elf(caminho):
    """Nomes e tamanhos das seções de um ELF de 64 bits (para achar a assinatura do AppImage)."""
    try:
        with open(caminho, "rb") as f:
            cab = f.read(64)
            if cab[:4] != b"\x7fELF" or cab[4] != 2:
                return {}
            ordem = "<" if cab[5] == 1 else ">"
            shoff = struct.unpack(ordem + "Q", cab[0x28:0x30])[0]
            shentsize, shnum, shstrndx = struct.unpack(ordem + "HHH", cab[0x3A:0x40])
            if not shoff or shnum == 0 or shnum > 512 or shentsize < 64:
                return {}
            f.seek(shoff)
            tabela = f.read(shentsize * shnum)
            secoes = [struct.unpack(ordem + "IIQQQQIIQQ", tabela[i * shentsize:i * shentsize + 64]) for i in range(shnum)]
            nomes_off, nomes_tam = secoes[shstrndx][4], secoes[shstrndx][5]
            f.seek(nomes_off)
            nomes = f.read(min(nomes_tam, 65536))
            resultado = {}
            for s in secoes:
                fim = nomes.find(b"\0", s[0])
                nome = nomes[s[0]:fim if fim >= 0 else None].decode("ascii", "replace")
                if nome in (".sha256_sig", ".sig_key"):
                    f.seek(s[4])
                    conteudo = f.read(min(s[5], 4096))
                    resultado[nome] = len(conteudo.strip(b"\0"))
            return resultado
    except (OSError, struct.error, IndexError):
        return {}


def assinatura(caminho, tipo):
    """"sim" (tem assinatura, que o Matsu não confere), "nao" ou "" (não se aplica)."""
    if tipo == "appimage":
        s = _secoes_elf(caminho)
        return "sim" if s.get(".sha256_sig") else "nao"
    if tipo == "windows":
        nome = caminho.lower()
        if nome.endswith(".msi"):
            # O MSI guarda a assinatura num fluxo chamado "\x05DigitalSignature".
            marca = "\x05DigitalSignature".encode("utf-16-le")
            try:
                with open(caminho, "rb") as f:
                    return "sim" if marca in f.read(8 * 1024 * 1024) else "nao"
            except OSError:
                return ""
        try:
            with open(caminho, "rb") as f:
                cab = f.read(4096)
            if cab[:2] != b"MZ":
                return "nao"
            pe = struct.unpack("<I", cab[0x3C:0x40])[0]
            if cab[pe:pe + 4] != b"PE\0\0":
                return "nao"
            opcional = pe + 24
            magica = struct.unpack("<H", cab[opcional:opcional + 2])[0]
            diretorios = opcional + (96 if magica == 0x10B else 112)
            # O 5º diretório (índice 4) é o da assinatura (Authenticode).
            _, tamanho = struct.unpack("<II", cab[diretorios + 32:diretorios + 40])
            return "sim" if tamanho > 0 else "nao"
        except (OSError, struct.error):
            return ""
    if tipo in ("elf", "script", "instalador", "java"):
        return "nao"
    return ""
