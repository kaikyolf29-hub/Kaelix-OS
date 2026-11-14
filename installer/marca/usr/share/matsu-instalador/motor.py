"""O motor do instalador do Matsu: tudo o que não é tela.

As telas (instalador.py) perguntam; este arquivo descobre os discos, cuida da
internet, escreve o kickstart com as respostas e acompanha o instalador do
Fedora (anaconda), que faz a instalação de verdade, sem tela, por baixo.

Nada aqui depende do GTK, para os testes (tests/test_instalador.py) rodarem em
qualquer máquina.
"""
import json
import math
import os
import re
import shlex
import subprocess
import threading
import time
import unicodedata

# ----- escolhas que a pessoa pode fazer -----

# (código do idioma, nome na tela)
IDIOMAS = [
    ("pt_BR.UTF-8", "Português (Brasil)"),
    ("en_US.UTF-8", "English (US)"),
    ("es_ES.UTF-8", "Español"),
    ("pt_PT.UTF-8", "Português (Portugal)"),
]

# (mapa do terminal, layout, variante, nome na tela)
TECLADOS = [
    ("br-abnt2", "br", "", "Português (Brasil, ABNT2)"),
    ("us", "us", "", "Inglês (EUA)"),
    ("us-acentos", "us", "intl", "Inglês internacional, com acentos"),
    ("es", "es", "", "Espanhol"),
    ("pt-latin1", "pt", "", "Português (Portugal)"),
]

# (fuso, nome na tela)
FUSOS = [
    ("America/Sao_Paulo", "Horário de Brasília"),
    ("America/Manaus", "Amazonas"),
    ("America/Cuiaba", "Mato Grosso"),
    ("America/Campo_Grande", "Mato Grosso do Sul"),
    ("America/Porto_Velho", "Rondônia"),
    ("America/Boa_Vista", "Roraima"),
    ("America/Rio_Branco", "Acre"),
    ("America/Noronha", "Fernando de Noronha"),
    ("Europe/Lisbon", "Portugal"),
    ("Europe/Madrid", "Espanha"),
    ("America/New_York", "Nova York"),
    ("UTC", "UTC"),
]

# O Matsu instalado ocupa uns 20 GB; com folga para apps e jogos, 40 GB é o mínimo.
MINIMO_BYTES = 40 * 1000 ** 3

# Nomes que o sistema já usa e não podem virar a conta da pessoa.
USUARIOS_RESERVADOS = {
    "root", "bin", "daemon", "adm", "lp", "sync", "shutdown", "halt", "mail",
    "operator", "games", "ftp", "nobody", "dbus", "polkitd", "sddm", "systemd",
    "admin", "wheel", "users", "usuario-teste",
}


# ----- textos -----

def tamanho(bytes_):
    """500107862016 -> '500 GB'; 1,5 TB com vírgula (como na caixa do disco)."""
    b = float(bytes_ or 0)
    for limite, sufixo in ((1000 ** 4, "TB"), (1000 ** 3, "GB"), (1000 ** 2, "MB")):
        if b >= limite:
            v = b / limite
            texto = f"{v:.1f}" if v < 10 and round(v, 1) != int(v) else f"{round(v):.0f}"
            return f"{texto.replace('.', ',')} {sufixo}"
    return f"{b / 1000:.0f} KB"


def sem_acento(texto):
    return "".join(c for c in unicodedata.normalize("NFKD", texto) if not unicodedata.combining(c))


def usuario_do_nome(nome):
    """'Kaiky Ólf' -> 'kaiky'. Só letras minúsculas, números, - e _."""
    primeiro = sem_acento(nome).strip().split(" ")[0].lower() if nome.strip() else ""
    usuario = re.sub(r"[^a-z0-9_-]", "", primeiro)
    usuario = re.sub(r"^[^a-z_]+", "", usuario)[:32]
    if not usuario or usuario in USUARIOS_RESERVADOS:
        return "usuario" if not usuario else usuario + "1"
    return usuario


def problema_no_usuario(usuario):
    """Texto para a tela quando o nome de usuário não serve, ou "" quando serve."""
    if not usuario:
        return "Escolha um nome de usuário."
    if not re.fullmatch(r"[a-z_][a-z0-9_-]{0,31}", usuario):
        return "Use só letras minúsculas sem acento, números, - e _, começando por uma letra."
    if usuario in USUARIOS_RESERVADOS:
        return "Esse nome já é usado pelo sistema. Escolha outro."
    return ""


def problema_na_senha(senha, confirmacao):
    if len(senha) < 6:
        return "A senha precisa ter pelo menos 6 caracteres."
    if confirmacao and senha != confirmacao:
        return "As duas senhas não estão iguais."
    if not confirmacao:
        return "Digite a senha de novo para confirmar."
    return ""


def nome_do_computador(usuario):
    base = re.sub(r"[^a-z0-9-]", "", usuario.lower()).strip("-")[:40]
    if not base or base == "matsu" or base.startswith("matsu-"):
        return base or "matsu"  # nada de "matsu-matsu"
    return f"matsu-{base}"


# ----- senha -----

def cifrar_senha(senha):
    """A senha cifrada (SHA-512), como fica no /etc/shadow. None se não der.

    O Python 3.13 tirou o módulo crypt; a biblioteca do sistema (libxcrypt)
    faz o mesmo. O openssl fica de reserva.
    """
    try:
        import ctypes
        lib = None
        for nome in ("libcrypt.so.2", "libcrypt.so.1"):
            try:
                lib = ctypes.CDLL(nome)
                break
            except OSError:
                continue
        if lib is not None:
            lib.crypt_gensalt.restype = ctypes.c_char_p
            lib.crypt_gensalt.argtypes = [ctypes.c_char_p, ctypes.c_ulong, ctypes.c_char_p, ctypes.c_int]
            lib.crypt.restype = ctypes.c_char_p
            lib.crypt.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
            sal = lib.crypt_gensalt(b"$6$", 0, None, 0)
            if sal:
                cifrada = lib.crypt(senha.encode("utf-8"), sal)
                if cifrada and cifrada.startswith(b"$6$"):
                    return cifrada.decode()
    except Exception:  # noqa: BLE001 - qualquer falha cai no openssl
        pass
    try:
        r = subprocess.run(["openssl", "passwd", "-6", "-stdin"], input=senha + "\n",
                           capture_output=True, text=True, timeout=10)
        if r.returncode == 0 and r.stdout.startswith("$6$"):
            return r.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pass
    return None


# ----- discos -----

def ambiente_em_ingles():
    """As telas rodam em português; os comandos lidos aqui (nmcli, sfdisk, o
    anaconda) precisam responder sempre em inglês."""
    env = dict(os.environ)
    for k in ("LANGUAGE", "LC_ALL", "LC_MESSAGES"):
        env.pop(k, None)
    env["LANG"] = "C.UTF-8"
    return env


def rodar(cmd, tempo=20):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=tempo, env=ambiente_em_ingles())
        return r.returncode, r.stdout, r.stderr
    except (OSError, subprocess.SubprocessError) as e:
        return 127, "", str(e)


def rotulo_da_midia(cmdline):
    """O rótulo do pendrive do instalador, tirado do inst.stage2/inst.ks do boot."""
    for chave in ("inst.stage2", "inst.ks", "inst.repo"):
        m = re.search(chave + r"=hd:LABEL=([^\s:]+)", cmdline)
        if m:
            return m.group(1).replace("\\x20", " ")
    return ""


def espaco_livre(tabela, tamanho_disco):
    """Maior pedaço livre (em bytes) de uma tabela do 'sfdisk -J'."""
    pt = tabela.get("partitiontable", {})
    setor = int(pt.get("sectorsize", 512))
    primeiro = int(pt.get("firstlba", 2048))
    ultimo = int(pt.get("lastlba", tamanho_disco // setor - 1))
    ocupados = sorted((int(p["start"]), int(p["start"]) + int(p["size"])) for p in pt.get("partitions", []))
    maior, cursor = 0, primeiro
    for inicio, fim in ocupados:
        if inicio > cursor:
            maior = max(maior, inicio - cursor)
        cursor = max(cursor, fim)
    maior = max(maior, ultimo + 1 - cursor)
    # Deixa 1 MB de margem para o alinhamento das partições novas.
    return max(0, maior * setor - 1024 ** 2)


SISTEMAS = {"ntfs": "Windows", "apfs": "macOS", "hfsplus": "macOS",
            "ext4": "Linux", "ext3": "Linux", "xfs": "Linux", "btrfs": "Linux"}


def ler_discos(lsblk_json, cmdline="", tabelas=None):
    """Os discos onde dá para instalar, a partir do 'lsblk -J -b'.

    tabelas: {"/dev/sda": saída do sfdisk -J (dict) ou None se o disco não tem tabela}
    Deixa de fora o pendrive do instalador, discos só de leitura, zram e afins.
    """
    tabelas = tabelas or {}
    rotulo = rotulo_da_midia(cmdline)
    discos = []
    for d in json.loads(lsblk_json).get("blockdevices", []):
        if d.get("type") != "disk" or d.get("ro") in (True, "1", 1):
            continue
        nome = d.get("name", "")
        if nome.startswith(("zram", "loop", "sr", "ram")):
            continue
        filhos = d.get("children") or []
        todos = [d] + filhos
        pontos = [p for x in todos for p in (x.get("mountpoints") or []) if p]
        if any(p.startswith("/run/install") for p in pontos):
            continue
        if rotulo and any((x.get("label") or "") == rotulo for x in todos):
            continue
        if (d.get("fstype") or "") == "iso9660":
            continue
        caminho = d.get("path") or f"/dev/{nome}"
        tam = int(d.get("size") or 0)
        sistemas = []
        for f in filhos:
            s = SISTEMAS.get((f.get("fstype") or "").lower())
            if s and s not in sistemas:
                sistemas.append(s)
        tabela = tabelas.get(caminho)
        vazio = not filhos and tabela is None
        livre = tam if vazio else (espaco_livre(tabela, tam) if tabela else 0)
        tran = (d.get("tran") or "").lower()
        if tran == "nvme" or nome.startswith("nvme"):
            tipo = "NVMe"
        elif tran == "usb" or d.get("rm") in (True, "1", 1):
            tipo = "USB"
        elif d.get("rota") in (True, "1", 1) and not nome.startswith("vd"):
            tipo = "HD"
        elif nome.startswith("vd"):
            tipo = "Disco virtual"
        else:
            tipo = "SSD"
        modelo = " ".join((d.get("model") or "").split()) or ("Disco " + nome)
        discos.append({
            "nome": nome, "caminho": caminho, "tamanho": tam, "modelo": modelo,
            "tipo": tipo, "sistemas": sistemas, "vazio": vazio, "livre": livre,
            "particoes": len(filhos),
        })
    # Disco interno primeiro, pendrives e HDs externos no fim.
    discos.sort(key=lambda x: (x["tipo"] == "USB", -x["tamanho"]))
    return discos


def descobrir_discos():
    cod, saida, _ = rodar(["lsblk", "-J", "-b", "-o",
                           "NAME,PATH,SIZE,TYPE,MODEL,TRAN,RM,RO,ROTA,FSTYPE,LABEL,MOUNTPOINTS"])
    if cod != 0:
        return []
    try:
        cmdline = open("/proc/cmdline", encoding="utf-8").read()
    except OSError:
        cmdline = ""
    tabelas = {}
    for d in json.loads(saida).get("blockdevices", []):
        if d.get("type") != "disk":
            continue
        caminho = d.get("path") or "/dev/" + d.get("name", "")
        c, s, _ = rodar(["sfdisk", "-J", caminho])
        try:
            tabelas[caminho] = json.loads(s) if c == 0 and s.strip() else None
        except ValueError:
            tabelas[caminho] = None
    return ler_discos(saida, cmdline, tabelas)


def descricao_do_disco(d):
    partes = [tamanho(d["tamanho"]), d["tipo"]]
    if d["sistemas"]:
        partes.append("tem " + " e ".join(d["sistemas"]))
    elif d["vazio"]:
        partes.append("vazio")
    return " · ".join(partes)


# ----- internet -----

def _campos(linha):
    """Separa uma linha do 'nmcli -t' (os ':' dentro dos campos vêm como '\\:')."""
    return [c.replace("\\:", ":").replace("\\\\", "\\") for c in re.split(r"(?<!\\):", linha)]


def estado_da_rede():
    """{'conectado': bool, 'tipo': 'cabo'|'wifi'|'', 'nome': str, 'tem_wifi': bool}"""
    estado = {"conectado": False, "tipo": "", "nome": "", "tem_wifi": False}
    cod, saida, _ = rodar(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"], 10)
    if cod != 0:
        return estado
    for linha in saida.splitlines():
        c = _campos(linha)
        if len(c) < 4:
            continue
        _, tipo, st, conexao = c[:4]
        if tipo == "wifi":
            estado["tem_wifi"] = True
        if st == "connected" and tipo in ("ethernet", "wifi") and not estado["conectado"]:
            estado.update(conectado=True, tipo="cabo" if tipo == "ethernet" else "wifi", nome=conexao)
    if estado["conectado"]:
        cod, saida, _ = rodar(["nmcli", "-t", "-f", "CONNECTIVITY", "general"], 10)
        if cod == 0 and saida.strip() in ("none", "limited", "portal"):
            estado["conectado"] = False
    return estado


def redes_wifi(procurar=False):
    """[{'nome', 'sinal' (0-100), 'senha' (bool), 'ativa'}], a mais forte primeiro."""
    cmd = ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
    if procurar:
        cmd += ["--rescan", "yes"]
    cod, saida, _ = rodar(cmd, 25)
    if cod != 0:
        return []
    redes = {}
    for linha in saida.splitlines():
        c = _campos(linha)
        if len(c) < 4 or not c[1]:
            continue
        uso, nome, sinal, seg = c[:4]
        try:
            sinal = int(sinal)
        except ValueError:
            sinal = 0
        atual = redes.get(nome)
        if not atual or sinal > atual["sinal"]:
            redes[nome] = {"nome": nome, "sinal": sinal, "senha": seg not in ("", "--"),
                           "ativa": uso.strip() == "*" or (atual or {}).get("ativa", False)}
    return sorted(redes.values(), key=lambda r: (not r["ativa"], -r["sinal"]))


def conectar_wifi(nome, senha):
    """(True, "") ou (False, motivo para a tela)."""
    cmd = ["nmcli", "--wait", "40", "device", "wifi", "connect", nome]
    if senha:
        cmd += ["password", senha]
    cod, saida, erro = rodar(cmd, 50)
    if cod == 0:
        return True, ""
    texto = (erro or saida).lower()
    if "secrets were required" in texto or "password" in texto or "802-11-wireless-security" in texto:
        return False, "A senha não confere. Tente de novo."
    if "no network with ssid" in texto:
        return False, "Essa rede sumiu. Atualize a lista."
    return False, "Não deu para conectar nessa rede."


# ----- kickstart -----

def _aspas(texto):
    return '"' + re.sub(r'["\\:\n\r]', "", texto).strip() + '"'


def linhas_da_base(base_ks):
    """Do kickstart que vem na ISO, só o que diz de onde vem o sistema e o %post."""
    guardar, dentro = [], False
    for linha in base_ks.splitlines():
        s = linha.strip()
        if dentro:
            guardar.append(linha)
            dentro = not s.startswith("%end")
        elif s.startswith("%"):
            guardar.append(linha)
            dentro = True
        elif s.startswith(("ostreecontainer", "bootc ")):
            guardar.append(linha)
    return "\n".join(guardar).strip() + "\n"


def gerar_kickstart(base_ks, escolhas, senha_cifrada):
    """O kickstart completo com as respostas da pessoa.

    escolhas: idioma, teclado (mapa do terminal), fuso, disco (caminho), modo
    ("apagar" ou "lado"), nome, usuario.

    O instalador roda em inglês ('lang en_US'): assim as mensagens dele (que
    viram a barra de progresso) são sempre as mesmas. O idioma escolhido vai para o
    sistema instalado pelo %post do fim.
    """
    teclado = next(t for t in TECLADOS if t[0] == escolhas["teclado"])
    xlayout = teclado[1] + (f" ({teclado[2]})" if teclado[2] else "")
    disco = escolhas["disco"].replace("/dev/", "")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", disco):
        raise ValueError("disco inválido: " + escolhas["disco"])
    idioma = escolhas["idioma"]
    if idioma not in [i[0] for i in IDIOMAS]:
        raise ValueError("idioma inválido: " + idioma)
    fuso = escolhas["fuso"]
    if fuso not in [f[0] for f in FUSOS]:
        raise ValueError("fuso inválido: " + fuso)
    if problema_no_usuario(escolhas["usuario"]):
        raise ValueError("usuário inválido: " + escolhas["usuario"])

    linhas = [
        "# Gerado pelo instalador do Matsu com as escolhas da tela.",
        "lang en_US.UTF-8",
        f"keyboard --vckeymap={teclado[0]} --xlayouts='{xlayout}'",
        f"timezone {fuso} --utc",
        f"ignoredisk --only-use={disco}",
    ]
    if escolhas["modo"] == "apagar":
        linhas += ["zerombr", f"clearpart --all --initlabel --drives={disco}"]
    else:
        linhas += [f"clearpart --none --drives={disco}"]
    linhas += [
        "autopart --type=btrfs --noswap",
        "rootpw --lock",
    ]
    gecos = _aspas(escolhas["nome"] or escolhas["usuario"])
    if senha_cifrada:
        linhas.append(f"user --name={escolhas['usuario']} --gecos={gecos} --groups=wheel "
                      f"--iscrypted --password='{senha_cifrada}'")
    else:
        raise ValueError("sem senha cifrada")
    linhas.append(f"network --hostname={nome_do_computador(escolhas['usuario'])}")
    texto = "\n".join(linhas) + "\n\n" + linhas_da_base(base_ks)
    texto += (
        "\n%post --erroronfail\n"
        "# O idioma escolhido na tela (o instalador rodou em inglês).\n"
        f"printf 'LANG=%s\\n' {shlex.quote(idioma)} > /etc/locale.conf\n"
        "%end\n"
    )
    return texto


# ----- acompanhando a instalação -----

# Mensagem do instalador do Fedora (em inglês) -> (etapa, quanto já foi).
ETAPAS = [
    ("Setting up the installation environment", "preparando", 0.02),
    ("Configuring storage", "disco", 0.05),
    ("Creating ", "disco", 0.07),
    ("Running pre-installation scripts", "disco", 0.10),
    ("Running pre-installation tasks", "disco", 0.11),
    ("Installing the software", "baixando", 0.12),
    ("Deployment starting", "baixando", 0.13),
    ("Deployment complete", "configurando", 0.80),
    ("Installing boot loader", "boot", 0.83),
    ("Performing post-installation setup tasks", "configurando", 0.86),
    ("Configuring installed system", "configurando", 0.88),
    ("Writing network configuration", "configurando", 0.90),
    ("Creating users", "conta", 0.91),
    ("Configuring addons", "configurando", 0.92),
    ("Generating initramfs", "configurando", 0.93),
    ("Storing configuration files and kickstarts", "finalizando", 0.95),
    ("Running post-installation scripts", "finalizando", 0.96),
    ("Complete!", "finalizando", 0.99),
]

TEXTO_DA_ETAPA = {
    "comecando": "Começando",
    "preparando": "Preparando a instalação",
    "disco": "Preparando o disco",
    "baixando": "Baixando o Matsu",
    "configurando": "Configurando o sistema",
    "boot": "Deixando o computador pronto para ligar no Matsu",
    "conta": "Criando a sua conta",
    "finalizando": "Finalizando",
    "pronto": "Pronto",
}

# Parte da barra que é do download (entre "Deployment starting" e "complete").
DOWNLOAD_INICIO, DOWNLOAD_FIM = 0.13, 0.76


class Progresso:
    """Lê as linhas do anaconda e diz em que pé está a instalação."""

    def __init__(self, bytes_da_imagem=0):
        self.etapa = "comecando"
        self.fracao = 0.0
        self.pronto = False
        self.erro = ""
        self.bytes_da_imagem = bytes_da_imagem
        self.baixado = 0
        self.inicio_download = None
        self._lendo_erro = False

    def linha(self, texto):
        """Uma linha da saída do anaconda. Devolve True se algo mudou."""
        t = texto.strip()
        if not t:
            return False
        if self._lendo_erro:
            if "will now terminate" in t:
                self._lendo_erro = False
            else:
                self.erro = (self.erro + "\n" + t).strip()
            return True
        if t.startswith("Installation complete"):
            self.pronto, self.etapa, self.fracao = True, "pronto", 1.0
            return True
        if ("The installation was stopped" in t or "no interactive debugging" in t
                or "An unknown error has occured" in t or "Traceback (most recent call last)" in t):
            self.erro = self.erro or "O instalador do Fedora parou com um erro."
            return True
        if "The exact error message is" in t:
            self.erro = ""
            self._lendo_erro = True
            return True
        if t.startswith("The following mandatory spokes are not completed"):
            self.erro = "Faltou alguma escolha para o instalador do Fedora."
            return True
        for comeco, etapa, fracao in ETAPAS:
            if t.startswith(comeco) and fracao > self.fracao:
                self.etapa, self.fracao = etapa, fracao
                if etapa == "baixando" and comeco.startswith("Deployment"):
                    self.inicio_download = time.monotonic()
                return True
        return False

    def bytes_recebidos(self, total_da_placa, no_comeco):
        """Atualiza o download pelo que a placa de rede recebeu desde o começo dele."""
        if self.etapa != "baixando" or self.inicio_download is None:
            return False
        self.baixado = max(0, total_da_placa - no_comeco)
        if self.bytes_da_imagem > 0:
            parte = min(self.baixado / self.bytes_da_imagem, 1.0)
        else:
            # Sem saber o tamanho: anda devagar, sem nunca chegar no fim.
            parte = 1 - math.exp(-(time.monotonic() - self.inicio_download) / 420)
        nova = DOWNLOAD_INICIO + (DOWNLOAD_FIM - DOWNLOAD_INICIO) * parte * 0.98
        if nova > self.fracao:
            self.fracao = nova
            return True
        return False

    def texto(self):
        base = TEXTO_DA_ETAPA.get(self.etapa, "Instalando")
        if self.etapa == "baixando" and self.baixado > 0:
            if self.bytes_da_imagem > 0:
                feito = min(self.baixado, self.bytes_da_imagem)
                return f"{base} · {tamanho(feito)} de {tamanho(self.bytes_da_imagem)}"
            return f"{base} · {tamanho(self.baixado)}"
        return base


def bytes_da_rede():
    """Tudo o que as placas de rede (menos a de loopback) já receberam."""
    total = 0
    try:
        for placa in os.listdir("/sys/class/net"):
            if placa == "lo":
                continue
            try:
                with open(f"/sys/class/net/{placa}/statistics/rx_bytes", encoding="ascii") as f:
                    total += int(f.read().strip() or 0)
            except (OSError, ValueError):
                continue
    except OSError:
        pass
    return total


class Instalacao:
    """Roda o anaconda sem tela com o kickstart e avisa as telas a cada novidade.

    aviso(progresso) é chamado de outra linha de execução: quem usa o GTK passa
    a chamada para o laço principal (GLib.idle_add).
    """

    COMANDO = ["anaconda", "--cmdline", "--kickstart"]

    def __init__(self, ks_texto, aviso, bytes_da_imagem=0, pasta="/run/matsu", registro="/tmp/matsu-instalador.log"):
        self.ks_texto = ks_texto
        self.aviso = aviso
        self.progresso = Progresso(bytes_da_imagem)
        self.pasta = pasta
        self.registro = registro
        self.processo = None
        self.saida = []

    def comecar(self):
        os.makedirs(self.pasta, exist_ok=True)
        ks = os.path.join(self.pasta, "instalar.ks")
        fd = os.open(ks, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(self.ks_texto)
        env = ambiente_em_ingles()
        # Sem tela para o anaconda: se ele achar a do instalador, abre as janelas dele nela.
        for k in ("WAYLAND_DISPLAY", "DISPLAY", "GDK_BACKEND"):
            env.pop(k, None)
        env["LANG"] = "en_US.UTF-8"
        self.processo = subprocess.Popen(self.COMANDO + [ks], stdin=subprocess.PIPE,
                                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                         env=env, start_new_session=True)
        threading.Thread(target=self._ler, daemon=True).start()
        threading.Thread(target=self._medir_download, daemon=True).start()

    def _ler(self):
        pedaco = b""
        with open(self.registro, "ab") as reg:
            while True:
                dado = self.processo.stdout.read1(4096) if hasattr(self.processo.stdout, "read1") \
                    else self.processo.stdout.read(1)
                if not dado:
                    break
                reg.write(dado)
                reg.flush()
                pedaco += dado
                *linhas, pedaco = pedaco.replace(b"\r", b"\n").split(b"\n")
                for bruta in linhas:
                    texto = bruta.decode("utf-8", "replace")
                    self.saida.append(texto)
                    del self.saida[:-400]
                    if self.progresso.linha(texto):
                        self.aviso(self.progresso)
                # A última frase do anaconda ("Installation complete. Press ENTER
                # to quit: ") é uma pergunta e não termina a linha: confere o resto.
                resto = pedaco.decode("utf-8", "replace")
                if not self.progresso.pronto and resto.lstrip().startswith("Installation complete"):
                    self.saida.append(resto.strip())
                    pedaco = b""
                    if self.progresso.linha(resto):
                        self.aviso(self.progresso)
        codigo = self.processo.wait()
        if not self.progresso.pronto and not self.progresso.erro:
            self.progresso.erro = f"O instalador do Fedora fechou antes do fim (código {codigo})."
        self.aviso(self.progresso)

    def _medir_download(self):
        no_comeco = None
        while self.processo and self.processo.poll() is None and not self.progresso.pronto:
            if self.progresso.etapa == "baixando" and self.progresso.inicio_download is not None:
                if no_comeco is None:
                    no_comeco = bytes_da_rede()
                if self.progresso.bytes_recebidos(bytes_da_rede(), no_comeco):
                    self.aviso(self.progresso)
            time.sleep(1)

    def parar(self):
        """Fecha o anaconda (e o que ele abriu), se ainda estiver rodando."""
        if not self.processo or self.processo.poll() is not None:
            return
        try:
            os.killpg(self.processo.pid, 15)
            self.processo.wait(timeout=15)
        except (OSError, subprocess.TimeoutExpired):
            try:
                os.killpg(self.processo.pid, 9)
            except OSError:
                pass

    def ultimas_linhas(self, n=40):
        return "\n".join(self.saida[-n:])
