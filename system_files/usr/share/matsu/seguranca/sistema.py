#!/usr/bin/python3
"""Central de segurança do Matsu: rede e firewall, permissões dos apps e integridade.

Tudo aqui lê ou muda o sistema pelos serviços que já existem e já pedem a
permissão certa pelo polkit:
  - firewalld e NetworkManager (trocar o tipo da rede, as portas da rede de casa)
  - Flatpak (as permissões de cada app, só na conta da pessoa: --user)
  - rpm-ostree / bootc, lsblk, a variável EFI do Secure Boot (só leitura)

As funções "ler_*" recebem o texto que o programa devolveu, para os testes
darem saídas de mentira sem precisar de firewalld, flatpak ou rpm-ostree.
"""
import configparser
import json
import os
import re
import xml.etree.ElementTree as ET

from nucleo import casa, ler, rodar, t

# ======================================================================
# Rede e firewall
# ======================================================================
FIREWALLD_ETC = os.environ.get("MATSU_FIREWALLD_ETC", "/etc/firewalld")
FIREWALLD_USR = os.environ.get("MATSU_FIREWALLD_USR", "/usr/lib/firewalld")
ZONA_CASA = "matsu-casa"
ZONA_PUBLICA = "matsu-publica"

# Os apps que podem receber conexões na rede de casa: o nome do serviço do
# firewalld, o nome e a explicação para a pessoa e o ícone (logo oficial quando o
# app instala uma; senão, um desenho genérico do Matsu).
SERVICOS_CASA = [
    {"id": "steam-streaming", "nome": "Steam Remote Play", "icone": "steam", "reserva": "jogos",
     "texto": ("Jogar no notebook, no celular ou na TV um jogo que roda neste computador",
               "Play a game running on this computer from your laptop, phone or TV")},
    {"id": "steam-lan-transfer", "nome": ("Steam: jogos pela rede", "Steam: games over the network"), "icone": "steam",
     "reserva": "jogos",
     "texto": ("Copiar jogos de outro computador da casa em vez de baixar de novo",
               "Copy games from another computer at home instead of downloading again")},
    {"id": "kdeconnect", "nome": "KDE Connect", "icone": "kdeconnect", "reserva": "celular",
     "texto": ("Celular e computador juntos: arquivos, avisos e a área de transferência",
               "Phone and computer together: files, notifications and clipboard")},
    {"id": "mdns", "nome": ("Achar aparelhos na rede", "Find devices on the network"), "icone": "", "reserva": "radar",
     "texto": ("Impressoras, TVs e outros computadores aparecem sozinhos",
               "Printers, TVs and other computers show up by themselves")},
    {"id": "ipp-client", "nome": ("Impressoras da rede", "Network printers"), "icone": "", "reserva": "impressora",
     "texto": ("Ver se a impressora da rede está pronta e mandar imprimir",
               "See if the network printer is ready and print to it")},
    {"id": "samba-client", "nome": ("Pastas compartilhadas", "Shared folders"), "icone": "", "reserva": "pasta",
     "texto": ("Abrir as pastas que outros computadores da casa compartilham",
               "Open folders shared by other computers at home")},
    {"id": "upnp-client", "nome": ("TV e aparelhos de mídia", "TV and media devices"), "icone": "", "reserva": "tv",
     "texto": ("Achar a TV e os aparelhos de mídia (UPnP) para transmitir",
               "Find the TV and media devices (UPnP) to cast to")},
    {"id": "spotify-sync", "nome": "Spotify Connect", "icone": "com.spotify.Client", "reserva": "musica",
     "texto": ("Tocar no computador pelo Spotify do celular", "Play on this computer from Spotify on your phone")},
    {"id": "samba", "nome": ("Compartilhar as suas pastas", "Share your folders"), "icone": "", "reserva": "compartilhar",
     "texto": ("Outros computadores abrem as pastas que você compartilhar (precisa do Samba)",
               "Other computers open the folders you share (needs Samba)")},
    {"id": "rdp", "nome": ("Área de trabalho remota", "Remote desktop"), "icone": "", "reserva": "tela",
     "texto": ("Usar este computador a distância, de outro computador (KRdp)",
               "Use this computer remotely from another computer (KRdp)")},
    {"id": "ssh", "nome": ("Acesso remoto pelo terminal (SSH)", "Remote terminal access (SSH)"), "icone": "",
     "reserva": "terminal",
     "texto": ("Entrar neste computador pelo terminal de outro. Só ligue se souber o que é.",
               "Log in to this computer from another one's terminal. Only turn on if you know what it is.")},
]
IDS_SERVICOS = {s["id"] for s in SERVICOS_CASA}


def _texto(valor):
    return t(valor[0], valor[1]) if isinstance(valor, tuple) else valor


def campos_nmcli(linha):
    """Separa uma linha do "nmcli -t" (":" separa, "\\:" é um dois-pontos de verdade)."""
    partes, atual, i = [], [], 0
    while i < len(linha):
        c = linha[i]
        if c == "\\" and i + 1 < len(linha):
            atual.append(linha[i + 1])
            i += 2
            continue
        if c == ":":
            partes.append("".join(atual))
            atual = []
        else:
            atual.append(c)
        i += 1
    partes.append("".join(atual))
    return partes


TIPOS_REDE = {"802-11-wireless": "wifi", "802-3-ethernet": "cabo", "gsm": "celular", "bluetooth": "celular",
              "wifi": "wifi", "ethernet": "cabo"}


def ler_conexoes(texto):
    """As conexões ativas que são redes de verdade (Wi-Fi, cabo, celular)."""
    lista = []
    for linha in texto.splitlines():
        if not linha.strip():
            continue
        c = campos_nmcli(linha)
        if len(c) < 4:
            continue
        nome, uuid, tipo, dispositivo = c[:4]
        if tipo not in TIPOS_REDE or not re.fullmatch(r"[0-9a-fA-F-]{36}", uuid):
            continue
        lista.append({"nome": nome, "uuid": uuid.lower(), "tipo": TIPOS_REDE[tipo], "dispositivo": dispositivo})
    return lista


def ler_zona_xml(texto):
    """Os serviços e portas de uma zona do firewalld (o arquivo .xml)."""
    try:
        raiz = ET.fromstring(texto)
    except ET.ParseError:
        return None
    return {
        "alvo": raiz.get("target", "default"),
        "servicos": [s.get("name") for s in raiz.findall("service") if s.get("name")],
        "portas": ["%s/%s" % (p.get("port"), p.get("protocol")) for p in raiz.findall("port")],
    }


def zona(nome):
    """A zona como está agora: a cópia mudada em /etc ou a do Matsu em /usr/lib."""
    for base in (FIREWALLD_ETC, FIREWALLD_USR):
        texto = ler(os.path.join(base, "zones", nome + ".xml"))
        if texto:
            z = ler_zona_xml(texto)
            if z is not None:
                z["mudada"] = base == FIREWALLD_ETC
                return z
    return None


def ler_zona_padrao(texto):
    for linha in texto.splitlines():
        linha = linha.strip()
        if linha.startswith("DefaultZone="):
            return linha.split("=", 1)[1].strip()
    return ""


def firewall_diz(*args):
    """Uma pergunta ao firewalld pelo firewall-cmd (só leitura: a pessoa pode, sem senha).
    O /etc/firewalld só o administrador lê, então o que vale é a resposta do firewalld."""
    codigo, saida = rodar(["firewall-cmd", *args], 8)
    saida = (saida or "").strip()
    return saida if codigo == 0 and saida else None


def zona_padrao():
    nome = firewall_diz("--get-default-zone")
    if nome:
        return nome
    # Firewall desligado: pelos arquivos. O firewalld novo pode guardar o padrão em
    # /usr/lib; o de /etc, se der para ler, vale mais.
    for base in (FIREWALLD_ETC, FIREWALLD_USR):
        nome = ler_zona_padrao(ler(os.path.join(base, "firewalld.conf")))
        if nome:
            return nome
    return "public"


def estado_firewall():
    codigo, saida = rodar(["systemctl", "is-active", "firewalld.service"], 5)
    if codigo == 127:
        return "indisponivel"
    estado = saida.strip()
    if estado == "active":
        return "ligado"
    if not os.path.exists(os.path.join(FIREWALLD_USR, "zones")):
        return "indisponivel"
    return "desligado"


def tipo_da_zona(z):
    return {ZONA_CASA: "casa", ZONA_PUBLICA: "publica"}.get(z, "outra")


def rede():
    """Tudo da página Rede e firewall."""
    firewall = estado_firewall()
    padrao = zona_padrao()
    conexoes = []
    codigo, saida = rodar(["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show", "--active"], 8)
    if codigo == 0:
        for c in ler_conexoes(saida):
            _, z = rodar(["nmcli", "-g", "connection.zone", "connection", "show", c["uuid"]], 8)
            z = z.strip()
            c["zona"] = z
            # Sem zona própria, a rede fica na zona que o firewalld der ao aparelho dela.
            na_hora = firewall_diz("--get-zone-of-interface=" + c["dispositivo"]) if c["dispositivo"] and not z else None
            c["efetiva"] = z or na_hora or padrao
            c["rede"] = tipo_da_zona(c["efetiva"])
            conexoes.append(c)
    casa_z = zona(ZONA_CASA) or {"servicos": [], "mudada": False}
    # O que o firewalld guardou para a rede de casa (vale mais que os arquivos, que a
    # pessoa nem sempre pode ler).
    guardados = firewall_diz("--permanent", "--zone=" + ZONA_CASA, "--list-services")
    if guardados is not None:
        lista = guardados.split()
        original = (ler_zona_xml(ler(os.path.join(FIREWALLD_USR, "zones", ZONA_CASA + ".xml"))) or {}).get("servicos", [])
        casa_z = {"servicos": lista, "mudada": sorted(lista) != sorted(original)}
    servicos = []
    for s in SERVICOS_CASA:
        servicos.append({"id": s["id"], "nome": _texto(s["nome"]), "texto": _texto(s["texto"]),
                         "icone": s["icone"], "reserva": s["reserva"], "ligado": s["id"] in casa_z["servicos"]})
    return {
        "firewall": firewall,
        "padrao": padrao,
        "padraoMatsu": padrao == ZONA_PUBLICA,
        "zonasMatsu": zona(ZONA_CASA) is not None and zona(ZONA_PUBLICA) is not None,
        "nm": codigo != 127,
        "conexoes": conexoes,
        "servicos": servicos,
        "casaMudada": bool(casa_z.get("mudada")),
    }


def erro_polkit(codigo):
    return {"ok": False, "erro": t("A senha de administrador não foi confirmada.",
                                   "The administrator password was not confirmed.")} if codigo in (253, 13, 4) else None


def trocar_tipo(uuid, tipo):
    """Rede de casa ou rede pública para a conexão (a zona dela no NetworkManager)."""
    if tipo not in ("casa", "publica") or not re.fullmatch(r"[0-9a-fA-F-]{36}", uuid or ""):
        return {"ok": False, "erro": "pedido inválido"}
    nova = ZONA_CASA if tipo == "casa" else ZONA_PUBLICA
    codigo, _ = rodar(["nmcli", "connection", "modify", uuid, "connection.zone", nova], 120)
    if codigo != 0:
        return {"ok": False, "erro": t("O NetworkManager não deixou mudar esta rede.",
                                       "NetworkManager did not allow changing this network.")}
    # Vale na hora: reaplica no aparelho que usa a conexão (sem desconectar).
    _, saida = rodar(["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show", "--active"], 8)
    for c in ler_conexoes(saida):
        if c["uuid"] == uuid.lower() and c["dispositivo"]:
            if rodar(["nmcli", "device", "reapply", c["dispositivo"]], 30)[0] != 0:
                rodar(["nmcli", "connection", "up", uuid], 60)
    return {"ok": True, "zona": nova}


def servico_casa(ident, ligar):
    """Liga ou desliga um serviço na zona da rede de casa (pede a senha de administrador)."""
    if ident not in IDS_SERVICOS:
        return {"ok": False, "erro": "serviço desconhecido"}
    verbo = ("--add-service=" if ligar else "--remove-service=") + ident
    codigo, _ = rodar(["firewall-cmd", "--permanent", "--zone=" + ZONA_CASA, verbo], 180)
    if codigo not in (0, 11, 12):
        return erro_polkit(codigo) or {"ok": False, "erro": t("O firewall não aceitou a mudança.",
                                                             "The firewall did not accept the change.")}
    # Também agora, sem reiniciar o firewall (já autorizado há pouco: não pede de novo).
    rodar(["firewall-cmd", "--zone=" + ZONA_CASA, verbo], 60)
    return {"ok": True}


def usar_padrao_matsu():
    """Redes novas começam como rede pública (a zona padrão do firewall)."""
    codigo, _ = rodar(["firewall-cmd", "--set-default-zone=" + ZONA_PUBLICA], 180)
    if codigo not in (0, 11, 16):
        return erro_polkit(codigo) or {"ok": False, "erro": t("O firewall não aceitou a mudança.",
                                                             "The firewall did not accept the change.")}
    return {"ok": True}


def ligar_firewall():
    codigo, _ = rodar(["systemctl", "enable", "--now", "firewalld.service"], 180)
    return {"ok": codigo == 0} if codigo == 0 else {"ok": False, "erro": t(
        "Não deu para ligar o firewall (a senha de administrador foi confirmada?).",
        "Could not turn on the firewall (was the administrator password confirmed?).")}


# ======================================================================
# Permissões dos apps (Flatpak)
# ======================================================================
FLATPAK_SISTEMA = os.environ.get("MATSU_FLATPAK_SISTEMA", "/var/lib/flatpak")


def flatpak_usuario():
    return os.environ.get("MATSU_FLATPAK_USUARIO") or os.path.join(casa(), ".local", "share", "flatpak")


LISTAS = ("shared", "sockets", "devices", "features")
PASTAS_PESSOAIS = {"xdg-download": ("Downloads", "Downloads"), "xdg-documents": ("Documentos", "Documents"),
                   "xdg-music": ("Músicas", "Music"), "xdg-pictures": ("Imagens", "Pictures"),
                   "xdg-videos": ("Vídeos", "Videos"), "xdg-desktop": ("Área de trabalho", "Desktop"),
                   "xdg-public-share": ("Pública", "Public"), "xdg-templates": ("Modelos", "Templates")}


def contexto_vazio():
    return {"shared": {}, "sockets": {}, "devices": {}, "features": {}, "filesystems": {}, "sessao": {}, "sistema": {}}


def ler_contexto(texto):
    """As permissões de um metadata ou de um override do Flatpak (formato keyfile).
    Cada lista vira {nome: True/False} (False é o "!nome" de um override)."""
    ctx = contexto_vazio()
    cp = configparser.ConfigParser(interpolation=None, strict=False, delimiters=("=",))
    cp.optionxform = str
    try:
        cp.read_string(texto)
    except configparser.Error:
        return ctx
    if cp.has_section("Context"):
        for chave in LISTAS + ("filesystems",):
            valor = cp.get("Context", chave, fallback="")
            for item in valor.split(";"):
                item = item.strip()
                if not item:
                    continue
                negado = item.startswith("!")
                nome = item.lstrip("!")
                if chave == "filesystems":
                    nome = re.sub(r":(ro|rw|create)$", "", nome)
                ctx[chave][nome] = not negado
    for secao, destino in (("Session Bus Policy", "sessao"), ("System Bus Policy", "sistema")):
        if cp.has_section(secao):
            for nome, valor in cp.items(secao):
                ctx[destino][nome] = valor.strip()
    return ctx


def juntar(base, *sobre):
    """Aplica os overrides em cima das permissões do app (o último ganha)."""
    final = {k: dict(v) for k, v in base.items()}
    for s in sobre:
        for chave, valores in s.items():
            final.setdefault(chave, {}).update(valores)
    return final


def ligados(ctx, chave):
    return {k for k, v in ctx.get(chave, {}).items() if v is True or (isinstance(v, str) and v != "none")}


def pastas_pessoais(ctx):
    pastas = set()
    for fs in ligados(ctx, "filesystems"):
        if fs in ("host", "home") or fs.startswith(("~", "/home", "/var/home", "/run/media", "/media", "/mnt")) \
                or fs.split("/")[0] in PASTAS_PESSOAIS:
            pastas.add(fs)
    return pastas


def ler_permissoes_portal(texto):
    """"flatpak permission-show <app>": {"devices/camera": "yes", "location/location": "EXACT", ...}."""
    r = {}
    for linha in texto.splitlines():
        partes = linha.split("\t") if "\t" in linha else linha.split()
        partes = [p.strip() for p in partes]
        if len(partes) < 4 or partes[0] in ("Table", "Tabela"):
            continue
        tabela, objeto, _app, permissoes = partes[:4]
        r["%s/%s" % (tabela, objeto)] = permissoes.split(",")[0].strip()
    return r


def permissoes_efetivas(ctx, portal):
    """As seis chaves da página: câmera, microfone, localização, arquivos, rede, notificações."""
    aparelhos = ligados(ctx, "devices")
    camera_portal = portal.get("devices/camera", "")
    camera = ("all" in aparelhos and camera_portal != "no") or camera_portal == "yes"
    local_portal = portal.get("location/location", "")
    geoclue = ctx.get("sistema", {}).get("org.freedesktop.GeoClue2", "none") not in ("none", "")
    localizacao = (bool(local_portal) and local_portal.upper() != "NONE") or (geoclue and local_portal.upper() != "NONE")
    # Sem "no" no portal, o app consegue avisar (direto pelo D-Bus ou pelo portal, que deixa).
    notificacoes = portal.get("notifications/notification", "") != "no"
    pessoais = pastas_pessoais(ctx)
    if pessoais & {"host", "home"} or any(p.startswith("~") and p.strip("~/") == "" for p in pessoais):
        arquivos_texto = t("A pasta pessoal inteira", "Your whole home folder")
    elif pessoais:
        nomes = []
        for p in sorted(pessoais):
            base = p.split("/")[0]
            nomes.append(t(*PASTAS_PESSOAIS[base]) if base in PASTAS_PESSOAIS else p.replace(casa(), "~"))
        arquivos_texto = ", ".join(nomes)
    else:
        arquivos_texto = t("Só os arquivos que você escolher", "Only the files you pick")
    return {
        "camera": camera,
        "cameraTodos": "all" in aparelhos,
        "microfone": "pulseaudio" in ligados(ctx, "sockets"),
        "localizacao": localizacao,
        "localPergunta": not local_portal and not geoclue,
        "arquivos": bool(pessoais),
        "arquivosTexto": arquivos_texto,
        "rede": "network" in ligados(ctx, "shared"),
        "notificacoes": bool(notificacoes),
    }


def _ler_desktop(caminho):
    nome = nome_pt = ""
    for linha in ler(caminho).splitlines():
        if linha.startswith("[") and linha.strip() != "[Desktop Entry]" and (nome or nome_pt):
            break
        if linha.startswith("Name="):
            nome = nome or linha[5:].strip()
        elif linha.startswith("Name[pt_BR]="):
            nome_pt = linha[12:].strip()
    return nome_pt if (nome_pt and t("pt", "en") == "pt") else nome


def icone_flatpak(app):
    for base in (FLATPAK_SISTEMA, flatpak_usuario()):
        pasta = os.path.join(base, "exports", "share", "icons", "hicolor")
        for tam, ext in (("scalable", "svg"), ("128x128", "png"), ("256x256", "png"), ("512x512", "png"),
                         ("96x96", "png"), ("64x64", "png"), ("48x48", "png")):
            caminho = os.path.join(pasta, tam, "apps", "%s.%s" % (app, ext))
            if os.path.exists(caminho):
                return caminho
    return ""


def _ids(base):
    try:
        return [n for n in os.listdir(os.path.join(base, "app")) if os.path.isdir(os.path.join(base, "app", n, "current"))]
    except OSError:
        return []


def instalados():
    """[(id, instalação, pasta)] dos apps Flatpak (as duas instalações)."""
    lista = []
    for base, inst in ((FLATPAK_SISTEMA, "sistema"), (flatpak_usuario(), "usuario")):
        for app in _ids(base):
            lista.append((app, inst, base))
    return lista


def contexto_do_app(app, base):
    """O metadata do app com os overrides do sistema e da pessoa por cima."""
    meta = ler(os.path.join(base, "app", app, "current", "active", "metadata"))
    if not meta:
        _, meta = rodar(["flatpak", "info", "--show-metadata", app], 10)
    padrao = ler_contexto(meta)
    camadas = []
    for pasta in (os.path.join(FLATPAK_SISTEMA, "overrides"), os.path.join(flatpak_usuario(), "overrides")):
        for nome in ("global", app):
            texto = ler(os.path.join(pasta, nome))
            if texto:
                camadas.append(ler_contexto(texto))
    usuario = ler(os.path.join(flatpak_usuario(), "overrides", app))
    return padrao, juntar(padrao, *camadas), bool(usuario.strip())


def apps():
    """A lista da página Permissões dos apps."""
    lista = []
    vistos = set()
    tem_flatpak = bool(rodar(["flatpak", "--version"], 5)[0] == 0) or bool(instalados())
    for app, inst, base in instalados():
        if app in vistos:
            continue
        vistos.add(app)
        desktop = os.path.join(base, "exports", "share", "applications", app + ".desktop")
        if not os.path.exists(desktop):
            continue  # sem atalho no menu (programa de linha de comando, extensão...)
        padrao, ctx, mudado = contexto_do_app(app, base)
        _, portal = rodar(["flatpak", "permission-show", app], 8)
        p = permissoes_efetivas(ctx, ler_permissoes_portal(portal))
        lista.append({"id": app, "nome": _ler_desktop(desktop) or app.rsplit(".", 1)[-1], "instalacao": inst,
                      "icone": icone_flatpak(app), "mudado": mudado, "permissoes": p,
                      "padrao": permissoes_efetivas(padrao, {})})
    lista.sort(key=lambda a: a["nome"].casefold())
    return {"flatpak": tem_flatpak, "apps": lista, "semCaixa": apps_sem_caixa()}


# Apps do sistema que vêm no Matsu sem caixa de areia (RPM): a página mostra sem esconder.
SEM_CAIXA = ("steam.desktop", "code.desktop", "firefox.desktop", "org.mozilla.firefox.desktop", "brave-browser.desktop",
             "google-chrome.desktop", "discord.desktop")


def apps_sem_caixa(pasta="/usr/share/applications"):
    nomes = []
    for arq in SEM_CAIXA:
        caminho = os.path.join(pasta, arq)
        if os.path.exists(caminho):
            nomes.append({"nome": _ler_desktop(caminho) or arq[:-8], "icone": arq[:-8]})
    return nomes


PERMISSOES = ("camera", "microfone", "localizacao", "arquivos", "rede", "notificacoes")


def comandos_permissao(app, perm, ligar, padrao, ctx):
    """Os comandos do Flatpak para ligar ou desligar uma permissão (na conta da pessoa)."""
    ov = ["flatpak", "override", "--user"]
    cmds = []
    if perm == "camera":
        cmds.append(["flatpak", "permission-set", "devices", "camera", app, "yes" if ligar else "no"])
        if ligar and "all" in ligados(padrao, "devices"):
            cmds.append(ov + ["--device=all", app])
        elif not ligar and "all" in ligados(ctx, "devices"):
            # Sem "all", o app perde a câmera e os outros aparelhos (controles);
            # a placa de vídeo continua (dri), senão o app fica lento.
            cmds.append(ov + ["--nodevice=all", "--device=dri", app])
    elif perm == "microfone":
        cmds.append(ov + ["--socket=pulseaudio" if ligar else "--nosocket=pulseaudio", app])
    elif perm == "localizacao":
        cmds.append(["flatpak", "permission-set", "location", "location", app, "EXACT" if ligar else "NONE", "0"])
        if not ligar and ctx.get("sistema", {}).get("org.freedesktop.GeoClue2", "none") != "none":
            cmds.append(ov + ["--system-no-talk-name=org.freedesktop.GeoClue2", app])
        elif ligar and padrao.get("sistema", {}).get("org.freedesktop.GeoClue2", "none") != "none":
            cmds.append(ov + ["--system-talk-name=org.freedesktop.GeoClue2", app])
    elif perm == "arquivos":
        if ligar:
            antes = sorted(pastas_pessoais(padrao)) or ["home"]
            cmds.append(ov + ["--filesystem=" + p for p in antes] + [app])
        else:
            agora = sorted(pastas_pessoais(ctx))
            if agora:
                cmds.append(ov + ["--nofilesystem=" + p for p in agora] + [app])
    elif perm == "rede":
        cmds.append(ov + ["--share=network" if ligar else "--unshare=network", app])
    elif perm == "notificacoes":
        cmds.append(["flatpak", "permission-set", "notifications", "notification", app, "yes" if ligar else "no"])
        if not ligar and ctx.get("sessao", {}).get("org.freedesktop.Notifications", "none") != "none":
            cmds.append(ov + ["--no-talk-name=org.freedesktop.Notifications", app])
        elif ligar and padrao.get("sessao", {}).get("org.freedesktop.Notifications", "none") != "none":
            cmds.append(ov + ["--talk-name=org.freedesktop.Notifications", app])
    return cmds


def mudar_permissao(app, perm, ligar):
    if perm not in PERMISSOES or not re.fullmatch(r"[A-Za-z0-9_.-]+", app or ""):
        return {"ok": False, "erro": "pedido inválido"}
    achado = next(((a, b) for a, _i, b in instalados() if a == app), None)
    if not achado:
        return {"ok": False, "erro": t("O app não está instalado.", "The app is not installed.")}
    padrao, ctx, _ = contexto_do_app(app, achado[1])
    for cmd in comandos_permissao(app, perm, ligar, padrao, ctx):
        if rodar(cmd, 30)[0] != 0:
            return {"ok": False, "erro": t("O Flatpak não aceitou a mudança.", "Flatpak did not accept the change.")}
    return {"ok": True}


def voltar_padrao(app):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", app or ""):
        return {"ok": False, "erro": "pedido inválido"}
    rodar(["flatpak", "override", "--user", "--reset", app], 30)
    for tabela, objeto in (("devices", "camera"), ("location", "location"), ("notifications", "notification")):
        rodar(["flatpak", "permission-remove", tabela, objeto, app], 15)
    return {"ok": True}


# ======================================================================
# Integridade do sistema
# ======================================================================
EFIVARS = os.environ.get("MATSU_EFIVARS", "/sys/firmware/efi/efivars")
POLICY_JSON = os.environ.get("MATSU_POLICY_JSON", "/etc/containers/policy.json")
RPM_OSTREED_CONF = os.environ.get("MATSU_RPM_OSTREED_CONF", "/etc/rpm-ostreed.conf")


def item(ident, estado, titulo, texto, detalhe=""):
    """estado: "ok" (verde), "atencao" (âmbar), "desligado" (cinza: escolha da pessoa) ou "?" (não deu para conferir)."""
    return {"id": ident, "estado": estado, "titulo": titulo, "texto": texto, "detalhe": detalhe}


def ler_status_ostree(texto):
    """A imagem em uso pelo "rpm-ostree status --json": (referência, assinada?)."""
    try:
        dados = json.loads(texto)
    except ValueError:
        return None
    for d in dados.get("deployments", []):
        if d.get("booted"):
            ref = d.get("container-image-reference") or ""
            return {"referencia": ref, "assinada": ref.startswith("ostree-image-signed:"),
                    "verificada": ref.startswith(("ostree-image-signed:", "ostree-remote-image:",
                                                  "ostree-remote-registry:")),
                    "versao": d.get("version") or ""}
    return None


def ler_status_bootc(texto):
    try:
        dados = json.loads(texto)
    except ValueError:
        return None
    imagem = ((dados.get("status") or {}).get("booted") or {}).get("image") or {}
    ref = (imagem.get("image") or {}).get("image") or ""
    spec = dados.get("spec") if isinstance(dados.get("spec"), dict) else {}
    assinatura = (spec.get("image") or {}).get("signature")
    if not ref:
        return None
    # "containerPolicy" (o policy.json com a chave do Matsu) ou {"ostreeRemote": ...}.
    assinada = assinatura == "containerPolicy" or (isinstance(assinatura, dict) and bool(
        {"containerPolicy", "ostreeRemote"} & set(assinatura)))
    return {"referencia": ref, "assinada": bool(assinada), "verificada": bool(assinada), "versao": imagem.get("version") or ""}


def politica_tem_chave(referencia, texto):
    """O policy.json exige a assinatura (sigstoreSigned) para o repositório da imagem."""
    try:
        politica = json.loads(texto)
    except ValueError:
        return False
    repo = re.sub(r"^ostree-[a-z-]+:(docker://)?", "", referencia or "")
    repo = repo.split("@", 1)[0]
    if ":" in repo.rsplit("/", 1)[-1]:
        repo = repo.rsplit(":", 1)[0]
    regras = (politica.get("transports") or {}).get("docker") or {}
    for escopo, lista in regras.items():
        if repo == escopo or repo.startswith(escopo.rstrip("/") + "/"):
            return any(r.get("type") == "sigstoreSigned" for r in lista if isinstance(r, dict))
    return False


def ler_secure_boot(dados):
    """O conteúdo da variável EFI SecureBoot (4 bytes de atributos e 1 de valor)."""
    if len(dados) >= 5:
        return dados[4] == 1
    if len(dados) == 1:
        return dados[0] == 1
    return None


def ler_lsblk(texto):
    """O que está cifrado: {"raiz": True/False/None, "casa": ..., "mesmoDisco": bool}."""
    try:
        dados = json.loads(texto)
    except ValueError:
        return None
    achados = {}

    def andar(no, pais):
        pontos = [p for p in (no.get("mountpoints") or [no.get("mountpoint")]) if p]
        cifrado = no.get("type") == "crypt" or any(p.get("fstype") == "crypto_LUKS" or p.get("type") == "crypt"
                                                     for p in pais)
        for p in pontos:
            achados[p] = {"cifrado": cifrado, "nome": no.get("name", "")}
        for filho in no.get("children") or []:
            andar(filho, pais + [no])

    for no in dados.get("blockdevices") or []:
        andar(no, [])
    raiz = next((achados[p] for p in ("/sysroot", "/") if p in achados), None)
    casa_ = next((achados[p] for p in ("/var/home", "/home", "/var") if p in achados), None)
    return {"raiz": raiz["cifrado"] if raiz else None, "casa": casa_["cifrado"] if casa_ else None,
            "mesmoDisco": bool(raiz and casa_ and raiz["nome"] == casa_["nome"])}


def ler_remotos(textos):
    """Os remotos do Flatpak e se conferem a assinatura (GPG): {nome: True/False}."""
    remotos = {}
    for texto in textos:
        nome = None
        for linha in texto.splitlines():
            linha = linha.strip()
            m = re.match(r'^\[remote "(.+)"\]$', linha)
            if m:
                nome = m.group(1)
                remotos.setdefault(nome, True)
                continue
            if linha.startswith("["):
                nome = None
            elif nome and linha.replace(" ", "").lower() == "gpg-verify=false":
                remotos[nome] = False
    return remotos


def ler_politica_rpm_ostree(texto):
    for linha in texto.splitlines():
        linha = linha.strip()
        if linha.lower().startswith("automaticupdatepolicy="):
            return linha.split("=", 1)[1].strip().lower()
    return ""


def atualizacoes_automaticas():
    """O jeito que a imagem base atualiza sozinha (uupd, rpm-ostreed-automatic ou bootc)."""
    achados = []
    for unidade, nome in (("uupd.timer", "uupd"), ("rpm-ostreed-automatic.timer", "rpm-ostree"),
                          ("bootc-fetch-apply-updates.timer", "bootc"), ("ublue-update.timer", "ublue-update")):
        codigo, saida = rodar(["systemctl", "is-enabled", unidade], 5)
        if codigo == 127:
            return None
        if saida.strip() in ("enabled", "static", "alias", "enabled-runtime"):
            achados.append(nome)
    politica = ler_politica_rpm_ostree(ler(RPM_OSTREED_CONF))
    if achados == ["rpm-ostree"] and politica in ("none", "off", ""):
        achados = []
    return {"ligadas": bool(achados), "quem": achados, "politica": politica}


def integridade():
    """Os itens da página Integridade, cada um com o que significa em português simples."""
    itens = []

    # 1. Imagem assinada e conferida.
    status = None
    codigo, saida = rodar(["rpm-ostree", "status", "--json"], 30)
    if codigo == 0:
        status = ler_status_ostree(saida)
    if status is None:
        codigo2, saida2 = rodar(["bootc", "status", "--json"], 30)
        if codigo2 == 0:
            status = ler_status_bootc(saida2)
    if status is None:
        itens.append(item("assinatura", "?", t("Sistema assinado", "Signed system"),
                          t("Não foi possível conferir: o rpm-ostree e o bootc não responderam.",
                            "Could not check: rpm-ostree and bootc did not answer.")))
    else:
        chave = politica_tem_chave(status["referencia"], ler(POLICY_JSON))
        if status["assinada"] and chave:
            itens.append(item("assinatura", "ok", t("Sistema assinado e conferido", "Signed and verified system"),
                              t("Cada atualização só entra se tiver a assinatura do Matsu. Uma versão mexida no caminho seria recusada.",
                                "Each update only goes in with Matsu's signature. A version tampered with on the way would be refused."),
                              status["referencia"].split("docker://")[-1]))
        elif status["verificada"]:
            itens.append(item("assinatura", "ok", t("Sistema assinado", "Signed system"),
                              t("As atualizações são conferidas antes de entrar.", "Updates are checked before going in."),
                              status["referencia"]))
        else:
            itens.append(item("assinatura", "atencao", t("Assinatura ainda não exigida", "Signature not enforced yet"),
                              t("Este computador ainda aceita atualizações sem conferir a assinatura. Rode \"matsu atualizar\" uma vez para ligar a conferência.",
                                "This computer still accepts updates without checking the signature. Run \"matsu update\" once to turn checking on."),
                              status["referencia"]))

    # 2. Arquivos do sistema só de leitura.
    try:
        so_leitura = bool(os.statvfs("/usr").f_flag & os.ST_RDONLY)
    except OSError:
        so_leitura = None
    atomico = os.path.exists("/run/ostree-booted")
    if so_leitura:
        itens.append(item("leitura", "ok", t("Arquivos do sistema protegidos", "System files protected"),
                          t("A pasta do sistema só pode ser lida. Nenhum programa consegue mudar o Matsu por dentro: o que muda vem pela atualização assinada.",
                            "The system folder is read-only. No program can change Matsu from the inside: changes only come through the signed update.")))
    elif so_leitura is False and atomico:
        itens.append(item("leitura", "atencao", t("Arquivos do sistema liberados", "System files unlocked"),
                          t("A pasta do sistema está aberta para mudanças (alguém rodou \"rpm-ostree usroverlay\"?). Reinicie para voltar a proteger.",
                            "The system folder is open for changes (did someone run \"rpm-ostree usroverlay\"?). Restart to protect it again.")))
    else:
        itens.append(item("leitura", "?", t("Arquivos do sistema", "System files"),
                          t("Não foi possível conferir: este não parece ser o Matsu instalado.",
                            "Could not check: this does not look like an installed Matsu.")))

    # 3. Secure Boot.
    sb = None
    if os.path.isdir(EFIVARS):
        try:
            with open(os.path.join(EFIVARS, "SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"), "rb") as f:
                sb = ler_secure_boot(f.read())
        except OSError:
            sb = None
        if sb is None:
            codigo, saida = rodar(["mokutil", "--sb-state"], 5)
            if codigo == 0 or "SecureBoot" in saida:
                sb = "enabled" in saida.lower()
        if sb is True:
            itens.append(item("secureboot", "ok", "Secure Boot",
                              t("O computador só liga com um sistema assinado: um programa malicioso não consegue se esconder antes do Matsu começar.",
                                "The computer only starts a signed system: malware cannot hide before Matsu starts.")))
        elif sb is False:
            itens.append(item("secureboot", "desligado", t("Secure Boot desligado", "Secure Boot off"),
                              t("Está desligado no BIOS. O Matsu funciona assim, mas ligado protege a partida do computador. Alguns drivers (NVIDIA) pedem um passo a mais.",
                                "It is off in the BIOS. Matsu works like this, but turning it on protects startup. Some drivers (NVIDIA) need one extra step.")))
        else:
            itens.append(item("secureboot", "?", "Secure Boot", t("Não foi possível conferir.", "Could not check.")))
    else:
        itens.append(item("secureboot", "desligado", t("Secure Boot indisponível", "Secure Boot unavailable"),
                          t("O computador ligou no modo antigo (BIOS/Legacy), que não tem Secure Boot.",
                            "The computer started in legacy (BIOS) mode, which has no Secure Boot.")))

    # 4. Disco criptografado.
    codigo, saida = rodar(["lsblk", "-J", "-o", "NAME,TYPE,FSTYPE,MOUNTPOINTS"], 10)
    disco = ler_lsblk(saida) if codigo == 0 else None
    if disco is None or disco["raiz"] is None:
        itens.append(item("disco", "?", t("Disco criptografado", "Encrypted disk"),
                          t("Não foi possível conferir os discos.", "Could not check the disks.")))
    elif disco["raiz"] and (disco["casa"] is not False):
        itens.append(item("disco", "ok", t("Disco criptografado", "Encrypted disk"),
                          t("Se o computador for roubado, ninguém lê os seus arquivos sem a senha do disco.",
                            "If the computer is stolen, nobody can read your files without the disk password.")))
    else:
        itens.append(item("disco", "desligado", t("Disco sem criptografia", "Disk not encrypted"),
                          t("Quem tirar o disco deste computador consegue ler os arquivos. A criptografia só pode ser ligada ao instalar o Matsu.",
                            "Whoever removes this computer's disk can read the files. Encryption can only be turned on when installing Matsu.")))

    # 5. Atualizações automáticas.
    auto = atualizacoes_automaticas()
    if auto is None:
        itens.append(item("atualizacoes", "?", t("Atualizações automáticas", "Automatic updates"),
                          t("Não foi possível conferir (sem o systemd).", "Could not check (no systemd).")))
    elif auto["ligadas"]:
        itens.append(item("atualizacoes", "ok", t("Atualizações automáticas ligadas", "Automatic updates on"),
                          t("O Matsu baixa as correções sozinho e elas entram quando você reinicia.",
                            "Matsu downloads fixes by itself and they apply when you restart."), ", ".join(auto["quem"])))
    else:
        itens.append(item("atualizacoes", "atencao", t("Atualizações automáticas desligadas", "Automatic updates off"),
                          t("As correções de segurança só entram quando você atualizar pelo app Atualizações ou por \"matsu atualizar\".",
                            "Security fixes only arrive when you update from the Updates app or with \"matsu update\".")))

    # 6. Remotos do Flatpak com assinatura.
    textos = [ler(os.path.join(FLATPAK_SISTEMA, "repo", "config")), ler(os.path.join(flatpak_usuario(), "repo", "config"))]
    remotos = ler_remotos([x for x in textos if x])
    if not remotos:
        itens.append(item("flatpak", "?", t("Lojas de apps", "App sources"),
                          t("Não foi possível conferir (nenhuma loja do Flatpak encontrada).",
                            "Could not check (no Flatpak source found).")))
    else:
        sem = sorted(n for n, ok in remotos.items() if not ok)
        if sem:
            itens.append(item("flatpak", "atencao", t("Loja de apps sem assinatura", "App source without signature"),
                              t("Os apps destas lojas não são conferidos: %s.", "Apps from these sources are not checked: %s.") % ", ".join(sem)))
        else:
            itens.append(item("flatpak", "ok", t("Lojas de apps conferidas", "App sources verified"),
                              t("Todo app que vem da Loja tem a assinatura conferida (GPG) antes de instalar.",
                                "Every app from the Store has its signature (GPG) checked before installing."),
                              ", ".join(sorted(remotos))))
    nivel = "ok"
    if any(i["estado"] == "atencao" for i in itens):
        nivel = "atencao"
    return {"itens": itens, "nivel": nivel, "atomico": atomico}
