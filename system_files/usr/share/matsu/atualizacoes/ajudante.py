#!/usr/bin/python3
"""Novidades e aviso de atualização do Matsu OS.

O arquivo NOVIDADES.md do repositório vai para /usr/share/matsu/novidades.md e diz o
que mudou em cada versão (27, 27.1, 27.2...; a mais nova em cima). Este programa:

  verificar            (o timer matsu-novidades.timer, depois do login e a cada 6 h)
                       1. Se o sistema foi atualizado desde o último login, avisa
                          "O Matsu foi atualizado para a 27.1" com o que mudou.
                       2. Procura uma versão nova no canal do sistema (o rótulo
                          org.matsu.versao da imagem, lido com o skopeo, sem baixar
                          nada) e avisa uma vez por versão, com o botão "Atualizar".
                       3. Avisa quando há apps da Loja (Flatpak) com atualização.
  janela [versao]      abre a janela Atualizações (o que mudou e se há versão nova)
  json [--procurar]    o que a janela mostra (com --procurar, também a versão nova)
  versao               a versão deste sistema
  notas <versao>       o texto da versão em Markdown (notas do Release no GitHub)
  resumo <versao>      os assuntos da versão em JSON (rótulo da imagem)

--arquivo <caminho> lê outro NOVIDADES.md (a montagem da imagem usa o do repositório).
Uso: python3 -I /usr/share/matsu/atualizacoes/ajudante.py <comando>. Só a biblioteca
padrão do Python.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time

ARQUIVO = os.environ.get("MATSU_NOVIDADES", "/usr/share/matsu/novidades.md")
INFO = os.environ.get("MATSU_IMAGE_INFO", "/usr/share/matsu/image-info.json")
JANELA_QML = "/usr/share/matsu/atualizacoes/Main.qml"
LOJA_QML = "/usr/share/matsu/loja/Main.qml"
MATSU_JANELA = "/usr/libexec/matsu/matsu-janela"
CENTRAL = "/usr/libexec/matsu/matsu-central"
# O que já foi avisado (a versão vista no último login, a versão nova já avisada...).
ESTADO = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state"),
                      "matsu", "novidades.json")


# ---------------------------------------------------------------- língua
def _portugues():
    primeiro = os.environ.get("LANGUAGE", "").split(":")[0]
    for valor in (os.environ.get("MATSU_LANG"), os.environ.get("LC_ALL"), os.environ.get("LC_MESSAGES"),
                  primeiro, os.environ.get("LANG")):
        if valor and not valor.startswith("C") and valor != "POSIX":
            return valor.startswith("pt")
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    for arquivo in (os.path.join(base, "plasma-localerc"), "/etc/xdg/plasma-localerc"):
        try:
            with open(arquivo, encoding="utf-8") as f:
                for linha in f:
                    if linha.startswith(("LANGUAGE=", "LANG=")):
                        return linha.split("=", 1)[1].strip().startswith("pt")
        except OSError:
            pass
    return True


PT = _portugues()


def t(portugues, ingles):
    return portugues if PT else ingles


# ---------------------------------------------------------------- o arquivo
def _limpar(texto):
    """Tira o Markdown de um trecho: **negrito**, `código` e [link](endereço)."""
    texto = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", texto)
    texto = texto.replace("**", "").replace("`", "")
    texto = re.sub(r"(?<!\w)_([^_]+)_(?!\w)", r"\1", texto)
    return re.sub(r"\s+", " ", texto).strip()


def ler_versoes(texto):
    """As versões do NOVIDADES.md, a mais nova primeiro.

    Cada uma: {versao, titulo, data, resumo, itens: [{assunto, texto}], markdown}.
    """
    versoes = []
    atual = None
    item = None
    for linha in texto.splitlines():
        if linha.startswith("## "):
            titulo = linha[3:].strip()
            m = re.match(r"v?(\d+(?:\.\d+)*)\b", titulo)
            if not m:
                atual = None
                continue
            atual = {"versao": m.group(1), "titulo": _limpar(titulo), "data": "", "resumo": "",
                     "itens": [], "linhas": []}
            versoes.append(atual)
            item = None
            continue
        if linha.startswith("# "):
            atual = None
            continue
        if atual is None:
            continue
        atual["linhas"].append(linha)
        limpa = linha.strip()
        m = re.match(r"^[-*]\s+(.*)$", limpa)
        if m:
            item = m.group(1)
            atual["itens"].append(item)
        elif limpa and item is not None and linha[:1].isspace():
            atual["itens"][-1] += " " + limpa
        elif re.match(r"^_[^_].*_$", limpa) and not atual["data"] and not atual["itens"]:
            atual["data"] = _limpar(limpa[1:-1])
            item = None
        elif limpa:
            atual["resumo"] = (atual["resumo"] + " " + _limpar(limpa)).strip()
            item = None
        else:
            item = None
    for v in versoes:
        itens = []
        for bruto in v["itens"]:
            m = re.match(r"^\*\*(.+?)\*\*\s*[:—–-]?\s*(.*)$", bruto)
            if m:
                texto = _limpar(m.group(2))
                itens.append({"assunto": _limpar(m.group(1)), "texto": texto[:1].upper() + texto[1:]})
            else:
                itens.append({"assunto": "", "texto": _limpar(bruto)})
        v["itens"] = itens
        v["markdown"] = "\n".join(v.pop("linhas")).strip()
    return versoes


def ler_arquivo(caminho):
    try:
        with open(caminho, encoding="utf-8") as f:
            return ler_versoes(f.read())
    except OSError:
        return []


def chave(versao):
    """27 < 27.1 < 27.2 < 27.10 < 28. Uma versão estranha fica no começo."""
    try:
        return tuple(int(p) for p in str(versao).strip().lstrip("v").split("."))
    except ValueError:
        return ()


def achar(versoes, versao):
    for v in versoes:
        if chave(v["versao"]) == chave(versao):
            return v
    return None


def edicao(versao):
    return str(versao).split(".")[0]


def info_imagem():
    try:
        with open(INFO, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def versao_local(versoes):
    v = str(info_imagem().get("versao") or "").strip()
    if chave(v):
        return v
    return versoes[0]["versao"] if versoes else ""


# ---------------------------------------------------------------- o estado
def ler_estado():
    try:
        with open(ESTADO, encoding="utf-8") as f:
            dados = json.load(f)
            return dados if isinstance(dados, dict) else {}
    except (OSError, ValueError):
        return {}


def gravar_estado(estado):
    caminho = ESTADO
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    tmp = caminho + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(estado, f, ensure_ascii=False, indent=1)
    os.replace(tmp, caminho)


# ---------------------------------------------------------------- o sistema
def rodar(args, tempo=60):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=tempo)
        return r.returncode, r.stdout
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""


def implantacoes():
    """(imagem em uso, se há uma versão baixada esperando reiniciar)."""
    codigo, saida = rodar(["rpm-ostree", "status", "--json"], 30)
    ref, baixada = "", False
    if codigo == 0:
        try:
            for d in json.loads(saida).get("deployments", []):
                if d.get("booted"):
                    ref = d.get("container-image-reference", "") or ""
                if d.get("staged"):
                    baixada = True
        except ValueError:
            pass
    if "docker://" in ref:
        ref = ref.split("docker://", 1)[1]
    elif ref:
        ref = ref.split(":", 1)[1] if ref.startswith("ostree-") else ref
    if not ref:
        info = info_imagem()
        if info.get("image-registry") and info.get("image-name"):
            ref = "%s/%s:estavel" % (info["image-registry"], info["image-name"])
    return ref, baixada


def remota(ref):
    """A versão do canal (rótulos da imagem), sem baixar a imagem."""
    if not ref or not shutil.which("skopeo"):
        return None
    codigo, saida = rodar(["skopeo", "inspect", "--no-tags", "--retry-times", "2", "docker://" + ref], 90)
    if codigo != 0:
        return None
    try:
        rotulos = json.loads(saida).get("Labels") or {}
    except ValueError:
        return None
    versao = str(rotulos.get("org.matsu.versao") or "").strip()
    if not chave(versao):
        return None
    try:
        novidades = json.loads(rotulos.get("org.matsu.novidades") or "[]")
        novidades = [str(n) for n in novidades if str(n).strip()][:12]
    except ValueError:
        novidades = []
    return {"versao": versao, "novidades": novidades}


def apps_com_atualizacao():
    """Nomes dos apps da Loja com atualização (as duas instalações do Flatpak)."""
    if not shutil.which("flatpak"):
        return []
    codigo, saida = rodar(["flatpak", "remote-ls", "--updates", "--app", "--columns=application"], 120)
    if codigo != 0:
        return []
    ids = sorted({l.strip() for l in saida.splitlines() if l.strip() and "." in l})
    if not ids:
        return []
    nomes = {}
    _, lista = rodar(["flatpak", "list", "--app", "--columns=application,name"], 30)
    for linha in lista.splitlines():
        partes = linha.split("\t")
        if len(partes) >= 2:
            nomes[partes[0].strip()] = partes[1].strip()
    return sorted((nomes.get(i) or i.rsplit(".", 1)[-1] for i in ids), key=str.casefold)


def avisar(titulo, corpo, acoes, espera=3600):
    """Notificação do Plasma; devolve o id do botão escolhido (ou "")."""
    if not shutil.which("notify-send"):
        return ""
    args = ["notify-send", "--app-name=" + t("Matsu OS", "Matsu OS"), "--icon=matsu-logo",
            "--hint=string:desktop-entry:org.matsu.atualizacoes"]
    for ident, nome in acoes:
        args.append("--action=%s=%s" % (ident, nome))
    args += [titulo, corpo]
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=espera if acoes else 30)
        return r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    except (OSError, subprocess.TimeoutExpired):
        return ""


def soltar(args):
    try:
        subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass


def fazer(acao, versao=""):
    if acao == "atualizar":
        soltar([CENTRAL, "abrir", "atualizar"])
    elif acao == "ver":
        abrir_janela(versao)
    elif acao == "reiniciar":
        # A pergunta do Plasma ("Reiniciar agora?"), que deixa a pessoa desistir.
        soltar(["gdbus", "call", "--session", "--dest", "org.kde.LogoutPrompt", "--object-path",
                "/LogoutPrompt", "--method", "org.kde.LogoutPrompt.promptReboot"])
    elif acao == "loja":
        soltar([MATSU_JANELA, "org.matsu.loja", LOJA_QML, "biblioteca"])


def abrir_janela(versao=""):
    args = [MATSU_JANELA, "org.matsu.atualizacoes", JANELA_QML]
    if versao:
        args.append(versao)
    soltar(args)


# ---------------------------------------------------------------- os textos
def lista_curta(assuntos, maximo=3):
    """• Relógio\n• Calendário\n• Notas\ne mais 4 novidades."""
    assuntos = [a for a in assuntos if a]
    linhas = ["• " + a for a in assuntos[:maximo]]
    resto = len(assuntos) - maximo
    if resto == 1:
        linhas.append(t("e mais 1 novidade.", "and 1 more change."))
    elif resto > 1:
        linhas.append(t("e mais %d novidades." % resto, "and %d more changes." % resto))
    return "\n".join(linhas)


def assuntos_de(v):
    return [i["assunto"] or i["texto"] for i in v["itens"]] if v else []


def texto_atualizado(local, anterior, versoes):
    v = achar(versoes, local)
    if edicao(local) != edicao(anterior):
        titulo = t("Bem-vindo ao Matsu %s OS" % edicao(local), "Welcome to Matsu %s OS" % edicao(local))
    else:
        titulo = t("O Matsu foi atualizado para a %s" % local, "Matsu was updated to %s" % local)
    corpo = lista_curta(assuntos_de(v)) or t("Veja o que mudou nesta versão.", "See what changed in this version.")
    return titulo, corpo


def texto_disponivel(r, baixada):
    if baixada:
        titulo = t("A versão %s já foi baixada" % r["versao"], "Version %s is ready" % r["versao"])
        primeira = t("Ela entra quando você reiniciar o computador.", "It takes effect when you restart.")
    else:
        titulo = t("Matsu %s disponível" % r["versao"], "Matsu %s is available" % r["versao"])
        primeira = t("O que muda:", "What changes:") if r["novidades"] else \
            t("Uma versão nova do sistema está pronta para baixar.", "A new system version is ready to download.")
    corpo = primeira
    if r["novidades"]:
        corpo += "\n" + lista_curta(r["novidades"])
    return titulo, corpo


# ---------------------------------------------------------------- comandos
def verificar(versoes, so_local=False):
    estado = ler_estado()
    local = versao_local(versoes)
    tarefas = []
    mudou = False

    vista = str(estado.get("vista") or "")
    if local and not chave(vista):
        # Primeiro login: nada de aviso (o "Boas-vindas" já apresenta o sistema).
        estado["vista"] = local
        mudou = True
    elif local and chave(local) > chave(vista):
        titulo, corpo = texto_atualizado(local, vista, versoes)
        estado["vista"] = local
        mudou = True
        tarefas.append((titulo, corpo, [("ver", t("Ver novidades", "See what's new"))], local))
    elif local and chave(local) < chave(vista):
        # Voltou para a versão anterior (matsu voltar): só lembra, sem aviso.
        estado["vista"] = local
        mudou = True

    if not so_local and local:
        ref, baixada = implantacoes()
        r = remota(ref)
        if r and chave(r["versao"]) > chave(local):
            marca = r["versao"] + (":baixada" if baixada else "")
            if estado.get("avisada") != marca:
                titulo, corpo = texto_disponivel(r, baixada)
                if baixada:
                    acoes = [("reiniciar", t("Reiniciar agora", "Restart now"))]
                else:
                    acoes = [("atualizar", t("Atualizar", "Update")), ("ver", t("Ver novidades", "See what's new"))]
                estado["avisada"] = marca
                mudou = True
                tarefas.append((titulo, corpo, acoes, r["versao"]))
        estado["procurado"] = int(time.time())
        mudou = True

        apps = apps_com_atualizacao()
        marca_apps = ",".join(apps)
        if apps and estado.get("apps") != marca_apps:
            n = len(apps)
            titulo = t("1 app tem atualização" if n == 1 else "%d apps têm atualização" % n,
                       "1 app has an update" if n == 1 else "%d apps have updates" % n)
            tarefas.append((titulo, lista_curta(apps), [("loja", t("Abrir a Loja", "Open the Store"))], ""))
        if estado.get("apps") != marca_apps:
            estado["apps"] = marca_apps
            mudou = True

    # Grava antes de esperar pelos cliques: um aviso aparece uma vez só.
    if mudou:
        try:
            gravar_estado(estado)
        except OSError:
            pass

    def um(titulo, corpo, acoes, versao):
        escolha = avisar(titulo, corpo, acoes)
        if escolha:
            fazer(escolha, versao)

    fios = [threading.Thread(target=um, args=tarefa) for tarefa in tarefas]
    for fio in fios:
        fio.start()
        time.sleep(0.4)
    for fio in fios:
        fio.join()
    return 0


def para_janela(versoes, procurar):
    info = info_imagem()
    local = versao_local(versoes)
    dados = {
        "versao": local,
        "edicao": edicao(local) if local else "",
        "build": str(info.get("build-id") or ""),
        "versoes": [{k: v[k] for k in ("versao", "titulo", "data", "resumo", "itens")} for v in versoes],
        "remota": None,
        "baixada": False,
        "procurado": ler_estado().get("procurado") or 0,
    }
    if procurar:
        ref, baixada = implantacoes()
        r = remota(ref)
        dados["procurado"] = int(time.time())
        dados["baixada"] = baixada
        if r and chave(r["versao"]) > chave(local):
            dados["remota"] = r
        dados["conseguiu"] = r is not None
    return dados


def principal(argv):
    arquivo = ARQUIVO
    if len(argv) >= 2 and argv[0] == "--arquivo":
        arquivo, argv = argv[1], argv[2:]
    comando = argv[0] if argv else "verificar"
    resto = argv[1:]
    versoes = ler_arquivo(arquivo)

    if comando == "versao":
        v = versoes[0]["versao"] if arquivo != ARQUIVO and versoes else versao_local(versoes)
        if not v:
            print(t("não achei a versão em %s" % arquivo, "no version found in %s" % arquivo), file=sys.stderr)
            return 1
        print(v)
        return 0
    if comando in ("notas", "resumo"):
        v = achar(versoes, resto[0]) if resto else (versoes[0] if versoes else None)
        if not v:
            print(t("a versão não está em %s" % arquivo, "version not in %s" % arquivo), file=sys.stderr)
            return 1
        if comando == "notas":
            print(v["markdown"])
        else:
            print(json.dumps(assuntos_de(v), ensure_ascii=False))
        return 0
    if comando == "json":
        print(json.dumps(para_janela(versoes, "--procurar" in resto), ensure_ascii=False))
        return 0
    if comando == "verificar":
        return verificar(versoes, so_local="--so-local" in resto)
    if comando == "janela":
        abrir_janela(resto[0] if resto else "")
        return 0
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
