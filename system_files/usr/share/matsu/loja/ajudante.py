#!/usr/bin/python3
"""Loja do Matsu: o ajudante.

A janela (os arquivos .qml desta pasta) só desenha. Quem lê o catálogo, instala,
remove e atualiza é este script. Só usa a biblioteca padrão do Python e responde
em JSON.

O catálogo vem de dois lugares:
  - o AppStream dos repositórios Flatpak ligados no sistema (o Flathub e, quando
    existir, o repositório do Matsu): nome, resumo, descrição, ícone, fotos e
    categorias de cada app, em português quando o app tem tradução;
  - o catalogo.json desta pasta, escolhido pelo Matsu: os destaques do Início, as
    seções (Essenciais, Para jogar...) e os sites que viram app (Instagram,
    TikTok, YouTube...).

Uso:
  ajudante.py catalogo             os apps (resumidos), as seções e os destaques (JSON)
  ajudante.py detalhes <id>        tudo de um app: descrição, fotos, versão, licença (JSON)
  ajudante.py instalados           os apps instalados (Flatpak e apps da web) (JSON)
  ajudante.py atualizacoes         os apps com versão nova (JSON; precisa de internet)
  ajudante.py atualizar-catalogo [--forcar]   baixa o catálogo novo do Flathub se tiver mais de um dia (JSON)
  ajudante.py instalar <id> [repositório]   instala; uma linha JSON por passo, com o progresso
  ajudante.py remover <id>         remove; uma linha JSON por passo
  ajudante.py atualizar <id>|--tudo        atualiza; uma linha JSON por passo
  ajudante.py web-icones           baixa a logo oficial de cada site do catálogo (JSON)
  ajudante.py web-instalar <id>    cria o app do site (abre no Brave ou no Chrome, sem barra)
  ajudante.py web-remover <id>     tira o app do site
  ajudante.py abrir <id>           abre o app (Flatpak, do sistema ou da web)
  ajudante.py ref <arquivo>        lê um .flatpakref (o "Instalar" dos sites) e diz qual app é (JSON)
"""
import gzip
import html
import importlib.util
import json
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

AQUI = os.path.dirname(os.path.abspath(__file__))


def _carregar_tarefas():
    caminho = os.environ.get("MATSU_TAREFAS_AJUDANTE") or os.path.join(AQUI, "..", "tarefas", "ajudante.py")
    spec = importlib.util.spec_from_file_location("matsu_tarefas", caminho)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


T = _carregar_tarefas()
ler = T.ler

# Versão do formato do cache: muda quando o que se guarda de cada app muda.
FORMATO = 3

# As categorias da loja e as do freedesktop que caem em cada uma (a primeira que
# bater vale como a principal do app).
CATEGORIAS = [
    ("jogos", ("Game",)),
    ("internet", ("Network", "Chat", "WebBrowser", "Email", "InstantMessaging", "P2P", "FileTransfer")),
    ("audio-video", ("AudioVideo", "Audio", "Video", "Music", "Player", "Recorder")),
    ("graficos", ("Graphics", "Photography", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics")),
    ("escritorio", ("Office", "WordProcessor", "Spreadsheet", "Presentation", "Finance")),
    ("desenvolvimento", ("Development", "IDE", "TextEditor")),
    ("educacao", ("Education", "Science", "Math")),
    ("utilitarios", ("Utility", "Accessibility", "Archiving", "Compression")),
    ("sistema", ("System", "Settings", "Monitor", "Security")),
]
TIPOS_DE_APP = ("desktop-application", "desktop", "console-application", "web-application")
ARQ = os.environ.get("MATSU_LOJA_ARQ") or {"x86_64": "x86_64", "aarch64": "aarch64"}.get(os.uname().machine, "x86_64")
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"


# ----- caminhos -----
def casa():
    return T.casa()


def pasta_cache():
    base = os.environ.get("MATSU_LOJA_CACHE") or os.path.join(
        os.environ.get("XDG_CACHE_HOME") or os.path.join(casa(), ".cache"), "matsu", "loja")
    os.makedirs(base, exist_ok=True)
    return base


def pasta_dados():
    return os.environ.get("XDG_DATA_HOME") or os.path.join(casa(), ".local", "share")


def arquivo_catalogo():
    return os.environ.get("MATSU_LOJA_CATALOGO") or os.path.join(AQUI, "catalogo.json")


def pastas_appstream():
    """As pastas "active" do AppStream de cada repositório Flatpak (do sistema e da pessoa)."""
    extra = os.environ.get("MATSU_LOJA_APPSTREAM")
    if extra:
        bases = [(p, "sistema") for p in extra.split(":") if p]
    else:
        bases = [("/var/lib/flatpak/appstream", "sistema"),
                 (os.path.join(pasta_dados(), "flatpak", "appstream"), "pessoa")]
    achadas = []
    for base, instalacao in bases:
        try:
            remotos = sorted(os.listdir(base))
        except OSError:
            continue
        for remoto in remotos:
            ativa = os.path.join(base, remoto, ARQ, "active")
            if os.path.isdir(ativa):
                achadas.append((remoto, instalacao, ativa))
    return achadas


# ----- textos -----
def simples(texto):
    """Sem acento e em minúsculas, para a busca."""
    t = unicodedata.normalize("NFD", texto or "")
    return "".join(c for c in t if unicodedata.category(c) != "Mn").lower()


def idioma():
    return T.idioma()


LANG_ATTR = "{http://www.w3.org/XML/1998/namespace}lang"


def _lingua_de(el):
    return el.get(LANG_ATTR) or el.get("lang") or ""


def _melhor(elementos, pt):
    """De vários <name>/<summary> com xml:lang, o da língua da pessoa (pt_BR, pt) ou o sem língua."""
    sem, achado = None, {}
    for el in elementos:
        lingua = _lingua_de(el)
        texto = (el.text or "").strip()
        if not lingua:
            sem = texto
        else:
            achado[lingua] = texto
    if pt:
        for chave in ("pt_BR", "pt-BR", "pt"):
            if achado.get(chave):
                return achado[chave]
    return sem if sem is not None else next(iter(achado.values()), "")


def _texto_inline(el):
    """Texto de um <p> ou <li>, com <em> e <code> viram texto simples."""
    partes = [el.text or ""]
    for filho in el:
        partes.append("".join(filho.itertext()))
        partes.append(filho.tail or "")
    return re.sub(r"\s+", " ", "".join(partes)).strip()


def _descricao(desc, pt):
    """A descrição do AppStream em texto rico simples (o StyledText do QML):
    parágrafos e listas, na língua da pessoa quando o app tem tradução."""
    if desc is None:
        return ""
    linguas = {_lingua_de(el) for el in desc.iter() if el is not desc}
    alvo = ""
    if pt:
        for chave in ("pt_BR", "pt-BR", "pt"):
            if chave in linguas:
                alvo = chave
                break
    blocos = []
    for el in desc:
        if el.tag == "p":
            if _lingua_de(el) == alvo:
                blocos.append(html.escape(_texto_inline(el)))
        elif el.tag in ("ul", "ol"):
            itens = [html.escape(_texto_inline(li)) for li in el if li.tag == "li" and _lingua_de(li) == alvo]
            if itens:
                blocos.append("<br>".join("•  " + i for i in itens))
    return "<br><br>".join(b for b in blocos if b)


def _categoria(cats):
    for nome, chaves in CATEGORIAS:
        if any(c in chaves for c in cats):
            return nome
    return "utilitarios"


def _fotos(comp, pt):
    """As fotos do app: a maior miniatura até ~1600 px de largura (ou a original)."""
    fotos = []
    caixa = comp.find("screenshots")
    if caixa is None:
        return fotos
    for tela in caixa.findall("screenshot"):
        melhor, larg_melhor, original = "", 0, ""
        for img in tela.findall("image"):
            url = (img.text or "").strip()
            if not url:
                continue
            if img.get("type") == "source":
                original = url
                continue
            try:
                larg = int(img.get("width") or 0)
            except ValueError:
                larg = 0
            if larg <= 1600 and larg > larg_melhor:
                melhor, larg_melhor = url, larg
        url = melhor or original
        if url:
            legenda = _melhor(tela.findall("caption"), pt)
            fotos.append({"url": url, "legenda": legenda, "padrao": tela.get("type") == "default"})
    fotos.sort(key=lambda f: not f["padrao"])
    return fotos[:8]


def _icone(comp, ativa):
    melhor, tam_melhor, remoto = "", 0, ""
    for ic in comp.findall("icon"):
        tipo = ic.get("type")
        nome = (ic.text or "").strip()
        if not nome:
            continue
        if tipo == "cached":
            try:
                tam = int(ic.get("width") or 64)
            except ValueError:
                tam = 64
            caminho = os.path.join(ativa, "icons", f"{tam}x{tam}", nome)
            if tam > tam_melhor and os.path.exists(caminho):
                melhor, tam_melhor = caminho, tam
        elif tipo == "remote" and not remoto:
            remoto = nome
    if not melhor:
        # Alguns repositórios guardam os ícones só por tamanho, sem dizer no XML.
        ident = comp.findtext("id", "").strip()
        ident = ident[:-8] if ident.endswith(".desktop") else ident
        for tam in (128, 64):
            for ext in (".png", ".svg"):
                caminho = os.path.join(ativa, "icons", f"{tam}x{tam}", ident + ext)
                if os.path.exists(caminho):
                    return caminho
    return melhor or remoto


def _valor(comp, chave):
    for bloco in ("custom", "metadata"):
        caixa = comp.find(bloco)
        if caixa is None:
            continue
        for v in caixa.findall("value"):
            if v.get("key") == chave:
                return (v.text or "").strip()
    return ""


def ler_componente(comp, remoto, instalacao, ativa, pt):
    tipo = comp.get("type", "")
    if tipo not in TIPOS_DE_APP:
        return None
    ident = (comp.findtext("id") or "").strip()
    if ident.endswith(".desktop"):
        ident = ident[:-8]
    if not ident:
        return None
    cats = [c.text.strip() for c in comp.findall("categories/category") if c.text]
    nome = _melhor(comp.findall("name"), pt) or ident
    dev = _melhor(comp.findall("developer/name"), pt) or _melhor(comp.findall("developer_name"), pt)
    palavras = [k.text.strip() for k in comp.findall("keywords/keyword") if k.text and (not _lingua_de(k) or _lingua_de(k).startswith("pt"))]
    urls = {u.get("type"): (u.text or "").strip() for u in comp.findall("url")}
    versao, data = "", 0
    rel = comp.find("releases/release")
    if rel is not None:
        versao = rel.get("version", "")
        try:
            data = int(rel.get("timestamp") or 0)
        except ValueError:
            data = 0
    resumo = _melhor(comp.findall("summary"), pt)
    return {
        "id": ident,
        "nome": nome,
        "resumo": resumo,
        "dev": dev,
        "icone": _icone(comp, ativa),
        "categoria": "jogos" if "Game" in cats else _categoria(cats),
        "categorias": cats,
        "verificado": _valor(comp, "flathub::verification::verified") == "true",
        "remoto": remoto,
        "instalacao": instalacao,
        "busca": simples(" ".join([nome, resumo, dev, ident] + palavras)),
        # só nos detalhes:
        "descricao": _descricao(comp.find("description"), pt),
        "fotos": _fotos(comp, pt),
        "licenca": (comp.findtext("project_license") or "").strip(),
        "site": urls.get("homepage", ""),
        "ajuda": urls.get("help", "") or urls.get("bugtracker", ""),
        "doacao": urls.get("donation", ""),
        "versao": versao,
        "data": data,
    }


def ler_appstream(caminho_xml, remoto, instalacao, ativa, pt):
    abrir = gzip.open if caminho_xml.endswith(".gz") else open
    apps = []
    with abrir(caminho_xml, "rb") as f:
        for _evento, el in ET.iterparse(f, events=("end",)):
            if el.tag != "component":
                continue
            app = ler_componente(el, remoto, instalacao, ativa, pt)
            if app:
                apps.append(app)
            el.clear()
    return apps


def _xml_de(ativa):
    for nome in ("appstream.xml.gz", "appstream.xml"):
        caminho = os.path.join(ativa, nome)
        if os.path.exists(caminho):
            return caminho
    return ""


def todos_os_apps():
    """Todos os apps de todos os repositórios, do cache quando o AppStream não mudou."""
    pt = idioma() == "pt"
    apps = {}
    for remoto, instalacao, ativa in pastas_appstream():
        xml = _xml_de(ativa)
        if not xml:
            continue
        marca = f"{FORMATO}:{os.path.getmtime(xml):.0f}:{os.path.getsize(xml)}:{'pt' if pt else 'en'}"
        cache = os.path.join(pasta_cache(), f"appstream-{instalacao}-{remoto}.json")
        lista = None
        try:
            with open(cache, encoding="utf-8") as f:
                guardado = json.load(f)
            if guardado.get("marca") == marca:
                lista = guardado["apps"]
        except (OSError, ValueError, KeyError):
            pass
        if lista is None:
            try:
                lista = ler_appstream(xml, remoto, instalacao, ativa, pt)
            except (OSError, ET.ParseError, EOFError):
                continue
            try:
                with open(cache + ".novo", "w", encoding="utf-8") as f:
                    json.dump({"marca": marca, "apps": lista}, f, ensure_ascii=False)
                os.replace(cache + ".novo", cache)
            except OSError:
                pass
        for app in lista:
            # O mesmo app em dois repositórios: vale o primeiro (o do sistema, o Flathub).
            apps.setdefault(app["id"], app)
    return apps


# ----- o catálogo do Matsu -----
def catalogo_matsu():
    try:
        with open(arquivo_catalogo(), encoding="utf-8") as f:
            cat = json.load(f)
    except (OSError, ValueError):
        cat = {}
    for chave in ("destaques", "secoes", "web", "no_sistema"):
        cat.setdefault(chave, [] if chave != "no_sistema" else {})
    return cat


def _texto(valor, pt):
    """Os textos do catálogo podem ser {"pt": ..., "en": ...} ou um texto só."""
    if isinstance(valor, dict):
        return valor.get("pt" if pt else "en") or valor.get("pt") or valor.get("en") or ""
    return valor or ""


def resumido(app):
    return {k: app[k] for k in ("id", "nome", "resumo", "dev", "icone", "categoria", "verificado", "remoto", "busca")}


def pastas_de_aplicativos():
    extra = os.environ.get("MATSU_LOJA_APPS_SISTEMA")
    if extra:
        return extra.split(":")
    return ["/usr/share/applications", "/usr/local/share/applications"]


def no_sistema(app_id, cat):
    """O .desktop do app que já vem no Matsu (Firefox, Steam, VS Code em pacote do sistema)."""
    nomes = [cat["no_sistema"].get(app_id, ""), app_id + ".desktop"]
    for pasta in pastas_de_aplicativos():
        for nome in nomes:
            if nome and os.path.exists(os.path.join(pasta, nome)):
                return nome
    return ""


def cmd_catalogo():
    pt = idioma() == "pt"
    cat = catalogo_matsu()
    apps = todos_os_apps()

    def existe(i):
        return i in apps

    destaques = []
    for d in cat["destaques"]:
        if existe(d.get("id", "")):
            destaques.append({"id": d["id"], "titulo": _texto(d.get("titulo"), pt) or apps[d["id"]]["nome"],
                              "texto": _texto(d.get("texto"), pt) or apps[d["id"]]["resumo"],
                              "cores": d.get("cores") or ["#6b7280", "#374151"]})
    secoes = []
    for s in cat["secoes"]:
        ids = [i for i in s.get("apps", []) if existe(i)]
        if ids:
            secoes.append({"id": s.get("id", ""), "titulo": _texto(s.get("titulo"), pt),
                           "texto": _texto(s.get("texto"), pt), "apps": ids})
    web = []
    for w in cat["web"]:
        web.append({"id": w["id"], "nome": w.get("nome", w["id"]), "resumo": _texto(w.get("resumo"), pt),
                    "url": w.get("url", ""), "cor": w.get("cor", "#6b7280"),
                    "icone": icone_web(w["id"]), "categoria": w.get("categoria", "internet")})
    contagem = {}
    for a in apps.values():
        contagem[a["categoria"]] = contagem.get(a["categoria"], 0) + 1
    sistema = {i: no_sistema(i, cat) for i in apps if no_sistema(i, cat)}
    print(json.dumps({
        "idioma": "pt" if pt else "en",
        "vidro": T.vidro(),
        "apps": [resumido(a) for a in sorted(apps.values(), key=lambda a: simples(a["nome"]))],
        "destaques": destaques,
        "secoes": secoes,
        "web": web,
        "categorias": contagem,
        "no_sistema": sistema,
        "repositorios": sorted({a["remoto"] for a in apps.values()}),
    }, ensure_ascii=False))
    return 0


def cmd_detalhes(app_id):
    apps = todos_os_apps()
    app = apps.get(app_id)
    if not app:
        print(json.dumps({"id": app_id, "erro": "nao-achado"}))
        return 1
    saida = dict(app)
    saida.pop("busca", None)
    saida["no_sistema"] = no_sistema(app_id, catalogo_matsu())
    print(json.dumps(saida, ensure_ascii=False))
    return 0


# ----- Flatpak -----
def flatpak(*args, tempo=60):
    try:
        r = subprocess.run(["flatpak", *args], capture_output=True, text=True, timeout=tempo,
                           env=dict(os.environ, LC_ALL="C.UTF-8", LANG="C.UTF-8", LANGUAGE=""))
        return r.returncode, r.stdout, r.stderr
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, "", str(e)


def instalados_flatpak():
    codigo, saida, _ = flatpak("list", "--app", "--columns=application,name,version,origin,installation,size")
    apps = []
    if codigo != 0:
        return apps
    for linha in saida.splitlines():
        partes = linha.split("\t")
        if len(partes) < 5 or not partes[0] or partes[0] == "Application ID":
            continue
        apps.append({"id": partes[0], "nome": partes[1], "versao": partes[2], "remoto": partes[3],
                     "instalacao": "pessoa" if partes[4] == "user" else "sistema",
                     "tamanho": partes[5] if len(partes) > 5 else ""})
    return apps


def cmd_instalados():
    print(json.dumps({"apps": instalados_flatpak(), "web": instalados_web()}, ensure_ascii=False))
    return 0


def cmd_atualizacoes():
    novos = []
    vistos = set()
    for onde in ("--system", "--user"):
        codigo, saida, _ = flatpak("remote-ls", onde, "--updates", "--app", "--columns=application,version,origin",
                                   tempo=120)
        if codigo != 0:
            continue
        for linha in saida.splitlines():
            partes = linha.split("\t")
            if partes and partes[0] and partes[0] not in vistos and partes[0] != "Application ID":
                vistos.add(partes[0])
                novos.append({"id": partes[0], "versao": partes[1] if len(partes) > 1 else ""})
    print(json.dumps({"atualizacoes": novos, "quando": int(time.time())}, ensure_ascii=False))
    return 0


def _marcas_appstream():
    marcas = {}
    for remoto, instalacao, ativa in pastas_appstream():
        xml = _xml_de(ativa)
        if xml:
            marcas[f"{instalacao}:{remoto}"] = os.path.getmtime(xml)
    return marcas


def cmd_atualizar_catalogo(forcar=False):
    """Baixa o AppStream de novo (nome, fotos e versões dos apps) quando nunca veio ou tem
    mais de um dia. Num Matsu recém-instalado é isto que enche a loja na primeira vez.
    Não pede senha: a regra do Flatpak deixa qualquer pessoa da sessão atualizar o catálogo."""
    antes = _marcas_appstream()
    velho = forcar or not antes or min(antes.values()) < time.time() - 86400
    ok = True
    if velho:
        codigos = [flatpak("update", "--appstream", "--system", "--noninteractive", tempo=300)[0]]
        codigo, saida, _ = flatpak("remotes", "--user", "--columns=name")
        if codigo == 0 and saida.strip():
            codigos.append(flatpak("update", "--appstream", "--user", "--noninteractive", tempo=300)[0])
        ok = 0 in codigos
    depois = _marcas_appstream()
    print(json.dumps({"ok": ok, "baixou": velho, "mudou": depois != antes, "vazio": not depois}))
    return 0 if ok else 1


ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07")


def _linha(**d):
    print(json.dumps(d, ensure_ascii=False), flush=True)


def _erro_amigavel(texto, pt):
    t = texto.lower()
    if "not installed" in t:
        return "Esse app não está instalado." if pt else "This app is not installed."
    if "already installed" in t:
        return "Esse app já está instalado." if pt else "This app is already installed."
    if "nothing matches" in t or "no remote refs" in t or "not found" in t:
        return "Não achei esse app no repositório." if pt else "This app was not found in the repository."
    if "could not resolve" in t or "unable to connect" in t or "network" in t or "timeout" in t or "curl" in t:
        return "Sem internet agora. Confira a conexão e tente de novo." if pt else "No internet right now. Check the connection and try again."
    if "not allowed" in t or "authoriz" in t or "polkit" in t or "permission" in t:
        return "O sistema não deu permissão para instalar." if pt else "The system did not allow the installation."
    if "no space" in t or "espaço" in t:
        return "Falta espaço no disco." if pt else "Not enough disk space."
    ultima = [l for l in texto.strip().splitlines() if l.strip()]
    return (ultima[-1] if ultima else ("Não deu certo." if pt else "It did not work."))[:200]


def acompanhar(acao, app_id, comando):
    """Roda o flatpak num terminal de mentira (assim ele mostra a porcentagem) e manda
    uma linha JSON a cada mudança: {"acao", "id", "progresso", "passo", "de"} e no fim
    {"fim": true, "ok": ...}."""
    import pty
    pt = idioma() == "pt"
    _linha(acao=acao, id=app_id, progresso=0, passo=0, de=0, comeco=True)
    mestre, escravo = pty.openpty()
    env = dict(os.environ, LC_ALL="C.UTF-8", LANG="C.UTF-8", LANGUAGE="", COLUMNS="160", TERM="xterm")
    try:
        proc = subprocess.Popen(comando, stdin=subprocess.DEVNULL, stdout=escravo, stderr=escravo, env=env,
                                start_new_session=True)
    except OSError as e:
        os.close(escravo)
        os.close(mestre)
        _linha(acao=acao, id=app_id, fim=True, ok=False, erro=_erro_amigavel(str(e), pt))
        return 1
    os.close(escravo)

    def parar(_sinal, _quadro):
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except OSError:
            pass
        _linha(acao=acao, id=app_id, fim=True, ok=False, cancelado=True)
        sys.exit(130)

    signal.signal(signal.SIGTERM, parar)
    signal.signal(signal.SIGINT, parar)
    texto, resto, ultimo = "", "", (-1, -1, -1)
    passo_atual = (0, 0)
    while True:
        try:
            pronto, _, _ = select.select([mestre], [], [], 0.5)
        except InterruptedError:
            continue
        if pronto:
            try:
                bloco = os.read(mestre, 4096)
            except OSError:
                bloco = b""
            if not bloco:
                break
            pedaco = ANSI.sub("", bloco.decode("utf-8", "replace"))
            texto += pedaco
            resto += pedaco
            partes = re.split(r"[\r\n]", resto)
            resto = partes.pop()
            for p in partes + [resto]:
                # "Installing 2/3… ███▌ 45%": o passo (o app e o que ele usa) e a porcentagem.
                passo = re.search(r"\b(\d+)/(\d+)\b", p)
                if passo and 0 < int(passo.group(1)) <= int(passo.group(2)) <= 50:
                    passo_atual = (int(passo.group(1)), int(passo.group(2)))
                pct = re.findall(r"(\d{1,3})%", p)
                if pct:
                    atual = (passo_atual[0], passo_atual[1], min(100, int(pct[-1])))
                    if atual != ultimo:
                        ultimo = atual
                        # Vários passos (o app e o que ele usa): a barra anda por todos.
                        total = atual[2] if not atual[1] else round(((atual[0] - 1) * 100 + atual[2]) / atual[1])
                        _linha(acao=acao, id=app_id, progresso=max(0, min(100, total)), passo=atual[0], de=atual[1])
        elif proc.poll() is not None:
            break
    codigo = proc.wait()
    os.close(mestre)
    if codigo == 0:
        _linha(acao=acao, id=app_id, progresso=100, fim=True, ok=True)
        return 0
    _linha(acao=acao, id=app_id, fim=True, ok=False, erro=_erro_amigavel(texto, pt))
    return 1


def remoto_do_app(app_id):
    app = todos_os_apps().get(app_id)
    return app["remoto"] if app else "flathub"


def cmd_instalar(app_id, remoto=""):
    if not re.fullmatch(r"[A-Za-z0-9._-]+", app_id):
        return 2
    remoto = remoto or remoto_do_app(app_id)
    return acompanhar("instalar", app_id, ["flatpak", "install", "--system", "-y", "--noninteractive", remoto, app_id])


def cmd_remover(app_id):
    if not re.fullmatch(r"[A-Za-z0-9._-]+", app_id):
        return 2
    onde = "--system"
    for a in instalados_flatpak():
        if a["id"] == app_id and a["instalacao"] == "pessoa":
            onde = "--user"
    return acompanhar("remover", app_id, ["flatpak", "uninstall", onde, "-y", "--noninteractive", app_id])


def cmd_atualizar(alvo):
    if alvo == "--tudo":
        return acompanhar("atualizar", "--tudo", ["flatpak", "update", "-y", "--noninteractive"])
    if not re.fullmatch(r"[A-Za-z0-9._-]+", alvo):
        return 2
    onde = "--system"
    for a in instalados_flatpak():
        if a["id"] == alvo and a["instalacao"] == "pessoa":
            onde = "--user"
    return acompanhar("atualizar", alvo, ["flatpak", "update", onde, "-y", "--noninteractive", alvo])


# ----- apps da web (sites que viram app) -----
NAVEGADORES = [
    # (id do Flatpak ou comando, nome da janela no Wayland/X11)
    ("com.brave.Browser", "brave"),
    ("brave-browser", "brave"),
    ("com.google.Chrome", "chrome"),
    ("google-chrome-stable", "chrome"),
    ("org.chromium.Chromium", "chromium"),
    ("chromium-browser", "chromium"),
    ("com.microsoft.Edge", "msedge"),
]


def navegador():
    """O navegador que abre os apps da web: Brave, Chrome, Chromium ou Edge (o que tiver)."""
    forcado = os.environ.get("MATSU_LOJA_NAVEGADOR")
    if forcado:
        return forcado.split(), "chrome"
    instalados = {a["id"] for a in instalados_flatpak()}
    for nome, classe in NAVEGADORES:
        if "." in nome and nome.count(".") >= 2 and nome in instalados:
            return ["flatpak", "run", nome], classe
        if "." not in nome and shutil.which(nome):
            return [nome], classe
    return None, ""


def pasta_icones_web():
    p = os.path.join(pasta_cache(), "web")
    os.makedirs(p, exist_ok=True)
    return p


def icone_web(web_id):
    for ext in (".png", ".svg", ".ico"):
        caminho = os.path.join(pasta_icones_web(), web_id + ext)
        if os.path.exists(caminho) and os.path.getsize(caminho) > 0:
            return caminho
    return ""


def _baixar(url, limite=4 * 1024 * 1024):
    pedido = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.5"})
    with urllib.request.urlopen(pedido, timeout=12) as r:
        dados = r.read(limite + 1)
        if len(dados) > limite:
            raise ValueError("grande demais")
        return dados, r.headers.get_content_type(), r.geturl()


def _icones_da_pagina(url):
    """Os ícones que o próprio site diz ter (manifesto e apple-touch-icon), maiores primeiro."""
    achados = []
    try:
        dados, _tipo, final = _baixar(url, 3 * 1024 * 1024)
    except Exception:  # noqa: BLE001 - sem internet ou site fora do ar: fica sem
        return achados
    pagina = dados.decode("utf-8", "replace")
    for tag in re.findall(r"<link\b[^>]*>", pagina, re.I):
        rel = re.search(r'rel=["\']([^"\']+)["\']', tag, re.I)
        href = re.search(r'href=["\']([^"\']+)["\']', tag, re.I)
        if not rel or not href:
            continue
        rel = rel.group(1).lower()
        endereco = urllib.parse.urljoin(final, html.unescape(href.group(1)))
        tam = re.search(r'sizes=["\'](\d+)x\d+', tag, re.I)
        tam = int(tam.group(1)) if tam else 0
        if "manifest" in rel:
            try:
                man, _t, man_final = _baixar(endereco, 512 * 1024)
                for ic in json.loads(man.decode("utf-8", "replace")).get("icons", []):
                    m = re.match(r"(\d+)x", ic.get("sizes", "") or "")
                    if ic.get("src") and "monochrome" not in (ic.get("purpose") or ""):
                        achados.append((int(m.group(1)) if m else 0, urllib.parse.urljoin(man_final, ic["src"])))
            except Exception:  # noqa: BLE001
                pass
        elif "apple-touch-icon" in rel:
            achados.append((tam or 180, endereco))
        elif "icon" in rel and (tam >= 96 or endereco.endswith(".svg")):
            achados.append((512 if endereco.endswith(".svg") and not tam else tam, endereco))
    achados.sort(key=lambda a: -a[0])
    return [u for _t, u in achados]


def baixar_icone_web(w):
    """A logo oficial do site, do próprio site (ou do serviço de ícones do Google)."""
    if icone_web(w["id"]):
        return icone_web(w["id"])
    url = w.get("url", "")
    dominio = urllib.parse.urlparse(url).hostname or ""
    candidatos = ([w["icone"]] if w.get("icone") else []) + _icones_da_pagina(url) + \
        [f"https://www.google.com/s2/favicons?domain={dominio}&sz=256"]
    for c in candidatos:
        try:
            dados, tipo, _final = _baixar(c)
        except Exception:  # noqa: BLE001
            continue
        if len(dados) < 200:
            continue
        ext = ".svg" if "svg" in tipo or c.endswith(".svg") else ".png" if dados[:8] == b"\x89PNG\r\n\x1a\n" else ""
        if not ext:
            continue
        destino = os.path.join(pasta_icones_web(), w["id"] + ext)
        with open(destino + ".novo", "wb") as f:
            f.write(dados)
        os.replace(destino + ".novo", destino)
        return destino
    return ""


def web_do_catalogo(web_id):
    for w in catalogo_matsu()["web"]:
        if w.get("id") == web_id:
            return w
    return None


def cmd_web_icones():
    feitos = {}
    for w in catalogo_matsu()["web"]:
        feitos[w["id"]] = baixar_icone_web(w)
    print(json.dumps({"icones": feitos}, ensure_ascii=False))
    return 0


def pasta_apps_pessoa():
    p = os.path.join(pasta_dados(), "applications")
    os.makedirs(p, exist_ok=True)
    return p


def desktop_web(web_id):
    return os.path.join(pasta_apps_pessoa(), f"matsu-web-{web_id}.desktop")


def instalados_web():
    feitos = []
    for w in catalogo_matsu()["web"]:
        if os.path.exists(desktop_web(w["id"])):
            feitos.append(w["id"])
    return feitos


def cmd_web_instalar(web_id):
    pt = idioma() == "pt"
    w = web_do_catalogo(web_id)
    if not w:
        print(json.dumps({"ok": False, "erro": "Site fora do catálogo." if pt else "Site not in the catalog."}))
        return 1
    nav, classe = navegador()
    if not nav:
        print(json.dumps({"ok": False, "sem_navegador": True,
                          "erro": "Para abrir sites como app, instale o Brave ou o Chrome (comando: matsu navegador)."
                          if pt else "To open sites as apps, install Brave or Chrome (command: matsu navegador)."},
                         ensure_ascii=False))
        return 1
    icone = baixar_icone_web(w)
    nome_icone = f"matsu-web-{web_id}"
    if icone:
        ext = os.path.splitext(icone)[1]
        pasta = os.path.join(pasta_dados(), "icons", "hicolor", "scalable" if ext == ".svg" else "256x256", "apps")
        os.makedirs(pasta, exist_ok=True)
        shutil.copyfile(icone, os.path.join(pasta, nome_icone + ext))
    url = w["url"]
    partes = urllib.parse.urlparse(url)
    # O nome que o Chrome/Brave dá à janela de um site aberto como app (assim a barra
    # junta a janela com o ícone certo).
    janela = f"{classe}-{partes.hostname}{(partes.path or '/').replace('/', '_')}-Default"
    resumo = _texto(w.get("resumo"), pt)
    exec_ = " ".join(nav + [f"--app={url}"])
    conteudo = "\n".join([
        "[Desktop Entry]",
        "Type=Application",
        f"Name={w.get('nome', web_id)}",
        f"Comment={resumo}",
        f"Exec={exec_}",
        f"Icon={nome_icone if icone else 'internet-web-browser'}",
        "Terminal=false",
        f"Categories={'Network;' if w.get('categoria', 'internet') == 'internet' else 'AudioVideo;'}",
        f"StartupWMClass={janela}",
        f"X-Matsu-Web={web_id}",
        "",
    ])
    destino = desktop_web(web_id)
    with open(destino + ".novo", "w", encoding="utf-8") as f:
        f.write(conteudo)
    os.chmod(destino + ".novo", 0o755)
    os.replace(destino + ".novo", destino)
    if shutil.which("update-desktop-database"):
        subprocess.run(["update-desktop-database", pasta_apps_pessoa()], capture_output=True, check=False)
    print(json.dumps({"ok": True, "id": web_id, "desktop": destino}, ensure_ascii=False))
    return 0


def cmd_web_remover(web_id):
    if not re.fullmatch(r"[a-z0-9-]+", web_id):
        return 2
    for caminho in (desktop_web(web_id),
                    os.path.join(pasta_dados(), "icons", "hicolor", "256x256", "apps", f"matsu-web-{web_id}.png"),
                    os.path.join(pasta_dados(), "icons", "hicolor", "scalable", "apps", f"matsu-web-{web_id}.svg")):
        try:
            os.remove(caminho)
        except OSError:
            pass
    print(json.dumps({"ok": True, "id": web_id}))
    return 0


def cmd_abrir(alvo):
    """Abre o app: site da loja, app do sistema ou Flatpak."""
    if alvo.startswith("web:"):
        caminho = desktop_web(alvo[4:])
        comando = ["gtk-launch", os.path.basename(caminho)[:-8]] if shutil.which("gtk-launch") else ["kioclient", "exec", caminho]
    else:
        desktop = no_sistema(alvo, catalogo_matsu())
        if desktop and not any(a["id"] == alvo for a in instalados_flatpak()):
            comando = ["kstart", "--application", desktop[:-8]] if shutil.which("kstart") else ["gtk-launch", desktop[:-8]]
        else:
            comando = ["flatpak", "run", alvo]
    try:
        subprocess.Popen(comando, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    except OSError:
        return 1
    return 0


def cmd_ref(caminho):
    """O botão "Instalar" do site do Flathub baixa um .flatpakref: a Loja abre na
    página do app que ele pede, em vez do Discover."""
    if caminho.startswith("file://"):
        caminho = urllib.parse.unquote(urllib.parse.urlparse(caminho).path)
    try:
        with open(caminho, encoding="utf-8", errors="replace") as f:
            texto = f.read(64 * 1024)
    except OSError:
        print(json.dumps({"ok": False}))
        return 1
    secao = ""
    for linha in texto.splitlines():
        linha = linha.strip()
        if linha.startswith("[") and linha.endswith("]"):
            secao = linha[1:-1]
        elif secao == "Flatpak Ref" and linha.startswith("Name="):
            app_id = linha[5:].strip()
            if re.fullmatch(r"[A-Za-z0-9._-]+", app_id):
                print(json.dumps({"ok": True, "id": app_id}))
                return 0
    print(json.dumps({"ok": False}))
    return 1


def main(args):
    if not args:
        print(__doc__.strip())
        return 2
    cmd, resto = args[0], args[1:]
    if cmd == "catalogo":
        return cmd_catalogo()
    if cmd == "detalhes" and resto:
        return cmd_detalhes(resto[0])
    if cmd == "instalados":
        return cmd_instalados()
    if cmd == "atualizacoes":
        return cmd_atualizacoes()
    if cmd == "atualizar-catalogo":
        return cmd_atualizar_catalogo("--forcar" in resto)
    if cmd == "instalar" and resto:
        return cmd_instalar(resto[0], resto[1] if len(resto) > 1 else "")
    if cmd == "remover" and resto:
        return cmd_remover(resto[0])
    if cmd == "atualizar" and resto:
        return cmd_atualizar(resto[0])
    if cmd == "web-icones":
        return cmd_web_icones()
    if cmd == "web-instalar" and resto:
        return cmd_web_instalar(resto[0])
    if cmd == "web-remover" and resto:
        return cmd_web_remover(resto[0])
    if cmd == "abrir" and resto:
        return cmd_abrir(resto[0])
    if cmd == "ref" and resto:
        return cmd_ref(resto[0])
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
