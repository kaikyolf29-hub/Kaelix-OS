#!/usr/bin/python3
"""Gerenciador de tarefas do Matsu: o ajudante que lê o sistema.

A janela (os arquivos .qml desta pasta) só desenha. Quem lê /proc e /sys, junta
os processos por app e encerra o que a pessoa pedir é este script. Ele só usa
a biblioteca padrão do Python e responde em JSON.

Uso:
  ajudante.py vigiar [segundos]       uma linha JSON por intervalo, até a janela fechar
  ajudante.py amostra                 uma amostra só (lê duas vezes, para ter as taxas)
  ajudante.py finalizar <alvo> [...]  encerra apps e processos: "unidade:<nome>" ou o pid
  ajudante.py forcar <alvo> [...]     o mesmo, mas na hora (para o que travou)
  ajudante.py reiniciar-barra         reinicia a barra e a área de trabalho do Plasma
  ajudante.py inicializacao           os apps que abrem sozinhos ao entrar (JSON)
  ajudante.py inicializacao-ligar <arquivo.desktop> sim|nao
"""
import fcntl
import json
import os
import re
import shlex
import shutil
import signal
import socket
import struct
import subprocess
import sys
import time

# Pastas de onde o ajudante lê. Os testes trocam por pastas de mentira.
PROC = os.environ.get("MATSU_PROC", "/proc")
SYS = os.environ.get("MATSU_SYS", "/sys")
PCI_IDS = os.environ.get("MATSU_PCI_IDS", "/usr/share/hwdata/pci.ids")
MEU_UID = int(os.environ.get("MATSU_UID", os.getuid()))
PAGINA = os.sysconf("SC_PAGE_SIZE")

# Partes da sessão: encerrar uma delas fecharia a sessão inteira.
NUCLEO = {"kwin_wayland", "kwin_wayland_wrapper", "kwin_x11", "ksmserver", "plasma_session",
          "startplasma-wayland", "startplasma-x11", "Xwayland", "systemd", "dbus-broker",
          "dbus-broker-launch", "dbus-daemon", "plasmalogin", "matsu-janela-sessao"}

# Programas que abrem outros (shell, intérpretes, Flatpak, Wine...): o nome deles não diz
# qual é o app, então não servem para achar a logo.
GENERICOS = {"sh", "bash", "zsh", "fish", "dash", "env", "sudo", "pkexec", "sleep", "python", "python3", "perl",
             "ruby", "node", "java", "electron", "flatpak", "flatpak-session-helper", "flatpak-portal", "bwrap",
             "xdg-dbus-proxy", "systemd", "dbus-daemon", "dbus-broker", "wine", "wine64", "wineserver",
             "wine-preloader", "wine64-preloader", "kioworker", "kdeinit5", "xdg-open", "gio"}

# Nomes que a pessoa entende para os processos mais comuns do sistema.
NOMES = {
    "kwin_wayland": ("Janelas e efeitos (KWin)", "Windows and effects (KWin)"),
    "kwin_wayland_wrapper": ("Janelas e efeitos (KWin)", "Windows and effects (KWin)"),
    "plasmashell": ("Área de trabalho e barra", "Desktop and bar"),
    "ksmserver": ("Sessão do Plasma", "Plasma session"),
    "plasma_session": ("Sessão do Plasma", "Plasma session"),
    "Xwayland": ("Apps antigos (Xwayland)", "Legacy apps (Xwayland)"),
    "kded6": ("Serviços do KDE", "KDE services"),
    "pipewire": ("Som e vídeo (PipeWire)", "Sound and video (PipeWire)"),
    "pipewire-pulse": ("Som (PipeWire)", "Sound (PipeWire)"),
    "wireplumber": ("Som (WirePlumber)", "Sound (WirePlumber)"),
    "baloo_file": ("Busca de arquivos", "File search"),
    "baloo_file_extractor": ("Busca de arquivos", "File search"),
    "xdg-desktop-portal": ("Portais do sistema", "System portals"),
    "xdg-desktop-portal-kde": ("Portais do sistema (KDE)", "System portals (KDE)"),
    "NetworkManager": ("Rede (NetworkManager)", "Network (NetworkManager)"),
    "systemd": ("Inicializador do sistema (systemd)", "System manager (systemd)"),
    "systemd-journald": ("Registro do sistema", "System log"),
    "systemd-logind": ("Entrada e sessões", "Logins and sessions"),
    "systemd-udevd": ("Aparelhos ligados (udev)", "Devices (udev)"),
    "systemd-oomd": ("Proteção contra falta de memória", "Out-of-memory protection"),
    "dbus-broker": ("Mensagens entre apps (D-Bus)", "App messaging (D-Bus)"),
    "polkitd": ("Permissões de administrador", "Administrator permissions"),
    "polkit-kde-authentication-agent-1": ("Janela de senha de administrador", "Administrator password prompt"),
    "upowerd": ("Bateria e energia", "Battery and power"),
    "powerdevil": ("Energia do Plasma", "Plasma power"),
    "org_kde_powerdevil": ("Energia do Plasma", "Plasma power"),
    "bluetoothd": ("Bluetooth", "Bluetooth"),
    "firewalld": ("Firewall", "Firewall"),
    "chronyd": ("Hora certa (chrony)", "Time sync (chrony)"),
    "rpm-ostreed": ("Atualizações do sistema", "System updates"),
    "bootc": ("Atualizações do sistema", "System updates"),
    "flatpak-system-helper": ("Apps (Flatpak)", "Apps (Flatpak)"),
    "ksystemstats": ("Leitura do sistema do KDE", "KDE system statistics"),
    "kwalletd6": ("Carteira de senhas", "Password wallet"),
    "kglobalacceld": ("Atalhos de teclado", "Keyboard shortcuts"),
    "kactivitymanagerd": ("Atividades do KDE", "KDE activities"),
    "kaccess": ("Acessibilidade", "Accessibility"),
    "ModemManager": ("Modem (ModemManager)", "Modem (ModemManager)"),
    "cupsd": ("Impressão", "Printing"),
    "gamemoded": ("Modo jogo", "Game mode"),
}

# Itens de "abrir ao entrar" que são peças do sistema: desligar quebraria algo.
INICIO_ESCONDIDO = {
    "at-spi-dbus-bus", "baloo_file", "geoclue-demo-agent", "gmenudbusmenuproxy", "imsettings-start",
    "kaccess", "matsu-primeiro-login", "org.kde.plasma-fallback-session-restore", "org.kde.plasmashell",
    "pam_kwallet_init", "polkit-kde-authentication-agent-1", "powerdevil", "spice-vdagent",
    "user-dirs-update-gtk", "vmware-user", "xdg-user-dirs", "xdg-user-dirs-kde", "xembedsniproxy",
    "org.kde.xwaylandvideobridge", "nvidia-settings-user", "ibus-autostart", "kde-systemd-start-condition",
}

VIRTUAIS = {"1af4", "1234", "15ad", "1b36", "80ee", "1414"}
MARCAS = {"1002": "AMD", "10de": "NVIDIA", "8086": "Intel"}


def ler(caminho, padrao=""):
    try:
        with open(caminho, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return padrao


def ler_int(caminho, padrao=0):
    try:
        return int(ler(caminho).split()[0])
    except (ValueError, IndexError):
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
    return {"cor": cor, "nivel": nivel if nivel in ("mais", "normal", "menos") else "normal"}


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


def ler_desktop(caminho):
    """O grupo [Desktop Entry] de um arquivo .desktop, como {chave: valor}."""
    dados = {}
    dentro = False
    for linha in ler(caminho).splitlines():
        linha = linha.strip()
        if linha.startswith("["):
            dentro = linha == "[Desktop Entry]"
        elif dentro and "=" in linha and not linha.startswith("#"):
            chave, valor = linha.split("=", 1)
            dados[chave.strip()] = valor.strip()
    return dados


def traduzido(dados, chave, lingua):
    if lingua == "pt":
        for k in (f"{chave}[pt_BR]", f"{chave}[pt]"):
            if dados.get(k):
                return dados[k]
    return dados.get(chave, "")


def pastas_de_dados():
    pastas = [os.environ.get("XDG_DATA_HOME") or os.path.join(casa(), ".local/share")]
    pastas += (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    pastas += [os.path.join(casa(), ".local/share/flatpak/exports/share"), "/var/lib/flatpak/exports/share"]
    vistas = []
    for p in pastas:
        if p and p not in vistas:
            vistas.append(p)
    return vistas


def pastas_de_autostart():
    config = os.environ.get("XDG_CONFIG_HOME") or os.path.join(casa(), ".config")
    outras = (os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg").split(":")
    return [os.path.join(config, "autostart")] + [os.path.join(p, "autostart") for p in outras if p]


def desescapar(texto):
    """Desfaz o escape do systemd nos nomes das unidades ("\\x2d" vira "-")."""
    return re.sub(r"\\x([0-9a-fA-F]{2})", lambda m: chr(int(m.group(1), 16)), texto)


def app_da_unidade(unidade):
    """Qual app (arquivo .desktop) abriu esta unidade do systemd.

    O KDE abre cada app numa unidade própria: "app-org.kde.dolphin-<uuid>.scope".
    Flatpak: "app-flatpak-org.mozilla.firefox-1234.scope". Os que abrem sozinhos
    ao entrar: "app-org.kde.kdeconnect.daemon@autostart.service".
    Devolve (id do app ou None, se é de abrir ao entrar).
    """
    if not unidade.startswith("app-"):
        return None, False
    resto = unidade[4:]
    if resto.endswith(".scope"):
        resto = resto[:-6]
        if resto.startswith("flatpak-"):
            return desescapar(re.sub(r"-\d+$", "", resto[8:])), False
        resto = re.sub(r"-[0-9a-f]{32}$", "", resto)
        resto = re.sub(r"-\d+$", "", resto)
        return (desescapar(resto) or None), False
    if resto.endswith(".service"):
        base, _, instancia = resto[:-8].partition("@")
        base = desescapar(base)
        # Serviços abertos pelo D-Bus ("app-dbus\x2d:1.2\x2dorg.kde.kded6@0") não são apps.
        if base.startswith("dbus-"):
            return None, False
        return (base or None), instancia == "autostart"
    return None, False


def nome_do_dbus(unidade):
    """Apps que o sistema abriu pelo D-Bus: "app-dbus\\x2d:1.2\\x2dorg.telegram.desktop@0.service"
    vira "org.telegram.desktop" (muitas vezes é o mesmo nome do .desktop do app)."""
    m = re.match(r"app-dbus-:[\d.]+-(.+?)(@\d+)?\.service$", desescapar(unidade))
    return m.group(1) if m else None


def programa_do_exec(linha):
    """O programa que a linha Exec= de um .desktop abre: "env A=1 /usr/bin/steam %U" vira "steam";
    "flatpak run --command=spotify com.spotify.Client" vira "spotify"."""
    try:
        partes = shlex.split(linha)
    except ValueError:
        partes = linha.split()
    i = 0
    while i < len(partes) and (os.path.basename(partes[i]) == "env" or
                               ("=" in partes[i] and not partes[i].startswith("-"))):
        i += 1
    if i >= len(partes):
        return ""
    programa = os.path.basename(partes[i])
    if programa == "flatpak":
        for p in partes[i + 1:]:
            if p.startswith("--command="):
                return os.path.basename(p.split("=", 1)[1])
        return ""
    return programa


def classificar(cgroup, uid):
    """Em que lista o processo entra: app, fundo (segundo plano) ou sistema."""
    partes = [p for p in cgroup.split("/") if p]
    unidade = partes[-1] if partes else ""
    if uid != MEU_UID:
        return "sistema", unidade
    app, _ = app_da_unidade(unidade)
    if app and unidade.endswith(".scope"):
        return "app", unidade
    if unidade == "init.scope" or "session.slice" in partes or any(p.startswith("session-") for p in partes):
        return "sistema", unidade
    return "fundo", unidade


def nome_pci(fornecedor, aparelho, sub_fornecedor="", sub_aparelho=""):
    """Nome da placa no pci.ids (do pacote hwdata)."""
    nome_f = nome_a = nome_sub = None
    try:
        with open(PCI_IDS, encoding="utf-8", errors="replace") as f:
            for linha in f:
                if not linha.strip() or linha.startswith("#"):
                    continue
                if not linha.startswith("\t"):
                    if nome_f is not None:
                        break
                    if linha[:4].lower() == fornecedor:
                        nome_f = linha[4:].strip()
                    continue
                if nome_f is None:
                    continue
                if linha.startswith("\t\t"):
                    if nome_a is not None and sub_fornecedor:
                        partes = linha.split(None, 2)
                        if len(partes) == 3 and partes[0].lower() == sub_fornecedor and partes[1].lower() == sub_aparelho:
                            nome_sub = partes[2].strip()
                            break
                    continue
                if nome_a is not None:
                    break
                if linha[1:5].lower() == aparelho:
                    nome_a = linha[5:].strip()
    except OSError:
        pass
    return nome_f, nome_a, nome_sub


def nome_da_placa(fornecedor, aparelho, sub_f, sub_a, lingua):
    if fornecedor in VIRTUAIS:
        return "Placa de vídeo virtual" if lingua == "pt" else "Virtual graphics"
    nome_f, nome_a, nome_sub = nome_pci(fornecedor, aparelho, sub_f, sub_a)
    marca = MARCAS.get(fornecedor, (nome_f or "").split(" ")[0])
    modelo = nome_sub or nome_a or ""
    colchete = re.search(r"\[([^\]]+)\]", modelo)
    if colchete:
        modelo = colchete.group(1)
    if not modelo:
        return marca or ("Placa de vídeo" if lingua == "pt" else "Graphics card")
    return modelo if modelo.startswith(marca) else f"{marca} {modelo}".strip()


def ip_da_interface(nome):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        resposta = fcntl.ioctl(s.fileno(), 0x8915, struct.pack("256s", nome[:15].encode()))
        return socket.inet_ntoa(resposta[20:24])
    except OSError:
        return ""
    finally:
        s.close()


class Leitor:
    """Lê o sistema e guarda a leitura anterior, para calcular as taxas."""

    def __init__(self):
        self.lingua = idioma()
        self.ant = None
        self.cache = {}       # pid -> o que não muda enquanto o processo vive
        self.apps = {}        # id do app -> {nome, icone} (ou None)
        self.programas = {}   # programa (do Exec= ou StartupWMClass) -> {nome, icone}
        self.programas_lidos = None
        self.fixos = None     # dados que não mudam (nome da CPU, das placas...)
        self.nvidia = (0.0, None)
        self.ips = (0.0, {})
        self.minha_unidade = ""

    # ----- o que não muda -----
    def dados_fixos(self):
        if self.fixos is not None:
            return self.fixos
        info = ler(PROC + "/cpuinfo")
        nome_cpu = ""
        nucleos = set()
        logicos = 0
        fisico = nucleo = ""
        virtual = False
        for linha in info.splitlines():
            chave, _, valor = linha.partition(":")
            chave, valor = chave.strip(), valor.strip()
            if chave == "model name" and not nome_cpu:
                nome_cpu = valor
            elif chave == "processor":
                logicos += 1
            elif chave == "physical id":
                fisico = valor
            elif chave == "core id":
                nucleo = valor
                nucleos.add((fisico, nucleo))
            elif chave == "flags" and " hypervisor" in f" {valor}":
                virtual = True
        nome_cpu = re.sub(r"\((R|TM|tm|r)\)", "", nome_cpu)
        nome_cpu = re.sub(r"\s+\d+-Core Processor$", "", nome_cpu)
        nome_cpu = re.sub(r"\s+", " ", nome_cpu).strip()
        base = ler_int(SYS + "/devices/system/cpu/cpu0/cpufreq/base_frequency") or \
            ler_int(SYS + "/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")
        temp_cpu = ""
        for hw in sorted(os.listdir(SYS + "/class/hwmon")) if os.path.isdir(SYS + "/class/hwmon") else []:
            pasta = f"{SYS}/class/hwmon/{hw}"
            if ler(pasta + "/name").strip() in ("k10temp", "zenpower", "coretemp", "cpu_thermal"):
                temp_cpu = pasta + "/temp1_input"
                break
        placas = []
        drm = SYS + "/class/drm"
        for carta in sorted(os.listdir(drm)) if os.path.isdir(drm) else []:
            if not re.fullmatch(r"card\d+", carta):
                continue
            aparelho = f"{drm}/{carta}/device"
            fornecedor = ler(aparelho + "/vendor").strip().replace("0x", "")
            if not fornecedor:
                continue
            driver = os.path.basename(os.path.realpath(aparelho + "/driver")) if os.path.exists(aparelho + "/driver") else ""
            hwmon = ""
            if os.path.isdir(aparelho + "/hwmon"):
                for hw in sorted(os.listdir(aparelho + "/hwmon")):
                    if os.path.exists(f"{aparelho}/hwmon/{hw}/temp1_input"):
                        hwmon = f"{aparelho}/hwmon/{hw}/temp1_input"
                        break
            placas.append({
                "caminho": aparelho,
                "nome": nome_da_placa(fornecedor, ler(aparelho + "/device").strip().replace("0x", ""),
                                      ler(aparelho + "/subsystem_vendor").strip().replace("0x", ""),
                                      ler(aparelho + "/subsystem_device").strip().replace("0x", ""), self.lingua),
                "fornecedor": fornecedor,
                "driver": driver,
                "temp": hwmon,
                "versao": self.versao_driver(driver),
            })
        self.fixos = {"cpu_nome": nome_cpu, "nucleos": len(nucleos) or logicos, "logicos": logicos,
                      "base": round(base / 1e6, 2) if base else 0, "virtual": virtual,
                      "temp_cpu": temp_cpu, "placas": placas}
        return self.fixos

    @staticmethod
    def versao_driver(driver):
        if driver == "nvidia":
            m = re.search(r"Kernel Module\s+(?:for\s+\S+\s+)?([\d.]+)", ler("/proc/driver/nvidia/version"))
            return f"NVIDIA {m.group(1)}" if m else "NVIDIA"
        if driver in ("amdgpu", "radeon", "i915", "xe", "nouveau"):
            try:
                r = subprocess.run(["rpm", "-q", "--qf", "%{VERSION}", "mesa-dri-drivers"],
                                   capture_output=True, text=True, timeout=3)
                if r.returncode == 0 and r.stdout.strip():
                    return f"Mesa {r.stdout.strip()}"
            except (OSError, subprocess.SubprocessError):
                pass
            return "Mesa"
        return driver

    # ----- processos -----
    def info_do_pid(self, pid, inicio, comm):
        base = f"{PROC}/{pid}"
        try:
            uid = os.stat(base).st_uid
        except OSError:
            return None
        cgroup = ""
        for linha in ler(base + "/cgroup").splitlines():
            if linha.startswith("0::"):
                cgroup = linha[3:]
        cmd = [p for p in ler(base + "/cmdline").split("\0") if p]
        nome = comm
        if len(comm) >= 15 and cmd:
            nome = os.path.basename(cmd[0]) or comm
        tipo, unidade = classificar(cgroup, uid)
        return {"inicio": inicio, "uid": uid, "unidade": unidade, "tipo": tipo, "nome": nome}

    def nome_amigavel(self, nome):
        par = NOMES.get(nome)
        if not par:
            return nome
        return par[0] if self.lingua == "pt" else par[1]

    def app(self, app_id):
        """Nome e logo do app pelo .desktop dele (nos apps instalados e, se não achar, nos que
        abrem ao entrar)."""
        if app_id in self.apps:
            return self.apps[app_id]
        achado = None
        lugares = [os.path.join(p, "applications") for p in pastas_de_dados()] + pastas_de_autostart()
        for pasta in lugares:
            arquivo = os.path.join(pasta, app_id + ".desktop")
            if os.path.isfile(arquivo):
                dados = ler_desktop(arquivo)
                achado = {"nome": traduzido(dados, "Name", self.lingua) or app_id, "icone": dados.get("Icon", ""),
                          "oculto": dados.get("NoDisplay", "").lower() == "true"}
                break
        self.apps[app_id] = achado
        return achado

    def indice_programas(self):
        """Todos os .desktop, por programa que abrem e por StartupWMClass. Serve para dar a logo
        certa a apps que não abriram pelo menu (pelo terminal, por outro app, pelo systemd-run).
        Lido de novo a cada minuto, para pegar apps instalados com o gerenciador aberto."""
        agora = time.monotonic()
        if self.programas_lidos is not None and agora - self.programas_lidos < 60:
            return self.programas
        indice = {}
        for pasta in pastas_de_dados():
            dir_apps = os.path.join(pasta, "applications")
            try:
                arquivos = sorted(os.listdir(dir_apps))
            except OSError:
                continue
            for arq in arquivos:
                if not arq.endswith(".desktop"):
                    continue
                dados = ler_desktop(os.path.join(dir_apps, arq))
                if not dados.get("Icon") or dados.get("Type", "Application") != "Application":
                    continue
                item = {"nome": traduzido(dados, "Name", self.lingua) or arq[:-8], "icone": dados["Icon"]}
                for chave in (programa_do_exec(dados.get("Exec", "")), dados.get("StartupWMClass", "")):
                    chave = chave.lower()
                    if chave and chave not in GENERICOS:
                        indice.setdefault(chave, item)
        self.programas, self.programas_lidos = indice, agora
        return indice

    def app_do_programa(self, exe):
        """O app (nome e logo) de um programa pelo nome dele, ou None. Os serviços do sistema
        (os da lista NOMES) ficam com o nome amigável e a engrenagem."""
        exe = (exe or "").lower()
        if not exe or exe in GENERICOS or exe in NOMES or exe in NUCLEO:
            return None
        return self.indice_programas().get(exe)

    # ----- leitura completa -----
    def amostra(self):
        agora = time.monotonic()
        fixos = self.dados_fixos()

        # CPU do sistema inteiro e de cada núcleo.
        cpus = {}
        for linha in ler(PROC + "/stat").splitlines():
            if linha.startswith("cpu"):
                partes = linha.split()
                valores = [int(v) for v in partes[1:9]]
                cpus[partes[0]] = (sum(valores), valores[3] + valores[4])
        ant = self.ant or {}
        ant_cpus = ant.get("cpus", {})

        def uso(nome):
            if nome not in ant_cpus or nome not in cpus:
                return 0.0
            total = cpus[nome][0] - ant_cpus[nome][0]
            ocioso = cpus[nome][1] - ant_cpus[nome][1]
            return max(0.0, min(100.0, 100.0 * (total - ocioso) / total)) if total > 0 else 0.0

        dt_cpu = cpus.get("cpu", (0, 0))[0] - ant_cpus.get("cpu", (0, 0))[0]
        dt = agora - ant["tempo"] if "tempo" in ant else 0.0

        # Processos.
        procs = {}
        ant_procs = ant.get("procs", {})
        n_threads = 0
        vivos = set()
        try:
            nomes = os.listdir(PROC)
        except OSError:
            nomes = []
        for nome in nomes:
            if not nome.isdigit():
                continue
            pid = int(nome)
            stat = ler(f"{PROC}/{nome}/stat")
            a, b = stat.find("("), stat.rfind(")")
            if a < 0 or b < 0:
                continue
            comm = stat[a + 1:b]
            campos = stat[b + 2:].split()
            if len(campos) < 22:
                continue
            ppid = int(campos[1])
            if pid == 2 or ppid == 2 or campos[0] == "Z":
                continue  # linhas do próprio kernel e processos já mortos
            ticks = int(campos[11]) + int(campos[12])
            inicio = int(campos[19])
            n_threads += int(campos[17])
            info = self.cache.get(pid)
            if not info or info["inicio"] != inicio:
                info = self.info_do_pid(pid, inicio, comm)
                if not info:
                    continue
                self.cache[pid] = info
            vivos.add(pid)
            statm = ler(f"{PROC}/{nome}/statm").split()
            mem = (int(statm[1]) - int(statm[2])) * PAGINA if len(statm) > 2 else 0
            lido = escrito = 0
            if info["uid"] == MEU_UID:
                for linha in ler(f"{PROC}/{nome}/io").splitlines():
                    if linha.startswith("read_bytes:"):
                        lido = int(linha.split()[1])
                    elif linha.startswith("write_bytes:"):
                        escrito = int(linha.split()[1])
            antes = ant_procs.get(pid)
            cpu = disco = 0.0
            if antes and antes[0] == inicio:
                if dt_cpu > 0:
                    cpu = max(0.0, 100.0 * (ticks - antes[1]) / dt_cpu)
                if dt > 0:
                    disco = max(0.0, (lido + escrito - antes[2]) / dt)
            procs[pid] = (inicio, ticks, lido + escrito, cpu, mem, disco, info)
        for pid in list(self.cache):
            if pid not in vivos:
                del self.cache[pid]

        # Junta os processos por app (ou por serviço).
        grupos = {}
        eu = os.getpid()
        for pid, (_, _, _, cpu, mem, disco, info) in procs.items():
            chave = info["unidade"] or f"pid-{pid}"
            if info["tipo"] == "sistema" and info["uid"] != MEU_UID and not info["unidade"]:
                chave = f"pid-{pid}"
            g = grupos.get(chave)
            if g is None:
                g = grupos[chave] = {"id": chave, "tipo": info["tipo"], "unidade": info["unidade"],
                                     "cpu": 0.0, "mem": 0, "disco": 0.0, "procs": [], "uid": info["uid"]}
            g["cpu"] += cpu
            g["mem"] += mem
            g["disco"] += disco
            nucleo = info["nome"] in NUCLEO
            pode = info["uid"] == MEU_UID and not nucleo and info["nome"] != "plasmashell"
            proprio = self.app_do_programa(info["nome"]) if info["tipo"] != "sistema" else None
            g["procs"].append({"pid": pid, "nome": self.nome_amigavel(info["nome"]), "exe": info["nome"],
                               "icone": proprio["icone"] if proprio else "",
                               "cpu": round(cpu, 1), "mem": mem, "disco": round(disco),
                               "acao": "finalizar" if pode else "nenhuma"})
            if pid == eu:
                self.minha_unidade = chave

        lista = []
        for g in grupos.values():
            g["procs"].sort(key=lambda p: p["pid"])
            principal = g["procs"][0]
            exes = {p["exe"] for p in g["procs"]}
            app_id, inicio_auto = app_da_unidade(g["unidade"])
            achado = self.app(app_id) if app_id else None
            if not achado and g["uid"] == MEU_UID:
                # Aberto pelo D-Bus: o nome no D-Bus costuma ser o do .desktop. Se o app
                # aparece no menu, a pessoa abriu uma janela dele: vai para Apps.
                pelo_dbus = nome_do_dbus(g["unidade"])
                achado = self.app(pelo_dbus) if pelo_dbus else None
                if achado:
                    app_id = pelo_dbus
                    if not achado["oculto"] and g["tipo"] == "fundo":
                        g["tipo"] = "app"
            if not achado and g["tipo"] != "sistema":
                # Aberto fora do menu: acha o app pelo nome do programa principal.
                achado = next((a for a in (self.app_do_programa(p["exe"]) for p in g["procs"]) if a), None)
            if achado:
                g["nome"], g["icone"] = achado["nome"], achado["icone"]
            else:
                g["nome"], g["icone"] = principal["nome"], (app_id or "")
            g["app"] = app_id or ""
            if g["uid"] != MEU_UID or any(p["pid"] == 1 for p in g["procs"]):
                g["acao"], g["motivo"] = "nenhuma", "outro-usuario"
            elif "plasmashell" in exes:
                g["acao"], g["motivo"] = "reiniciar", ""
            elif exes & NUCLEO or g["tipo"] == "sistema":
                g["acao"], g["motivo"] = "nenhuma", "sessao"
            else:
                g["acao"], g["motivo"] = "finalizar", ""
            g["n"] = len(g["procs"])
            g["cpu"] = round(g["cpu"], 1)
            g["disco"] = round(g["disco"])
            g["autostart"] = inicio_auto
            del g["uid"]
            lista.append(g)

        # Memória.
        mem = {}
        for linha in ler(PROC + "/meminfo").splitlines():
            chave, _, valor = linha.partition(":")
            try:
                mem[chave] = int(valor.split()[0]) * 1024
            except (ValueError, IndexError):
                pass
        total = mem.get("MemTotal", 0)
        disponivel = mem.get("MemAvailable", mem.get("MemFree", 0))
        cache = max(0, mem.get("Cached", 0) + mem.get("Buffers", 0) + mem.get("SReclaimable", 0) - mem.get("Shmem", 0))
        memoria = {"total": total, "usada": max(0, total - disponivel), "disponivel": disponivel,
                   "cache": cache, "livre": mem.get("MemFree", 0),
                   "swap_total": mem.get("SwapTotal", 0),
                   "swap_usada": max(0, mem.get("SwapTotal", 0) - mem.get("SwapFree", 0))}

        # Discos.
        discos, discos_ant = self.ler_discos(agora, ant.get("discos", {}), dt)

        # Rede.
        redes, redes_ant = self.ler_redes(agora, ant.get("redes", {}), dt)

        # Placas de vídeo.
        placas = self.ler_placas(fixos)

        # Frequência média da CPU agora.
        freqs = []
        for linha in ler(PROC + "/cpuinfo").splitlines():
            if linha.startswith("cpu MHz"):
                try:
                    freqs.append(float(linha.split(":")[1]))
                except (ValueError, IndexError):
                    pass
        if not freqs:
            pasta = SYS + "/devices/system/cpu"
            for nome in os.listdir(pasta) if os.path.isdir(pasta) else []:
                if re.fullmatch(r"cpu\d+", nome):
                    f = ler_int(f"{pasta}/{nome}/cpufreq/scaling_cur_freq")
                    if f:
                        freqs.append(f / 1000)
        nucleos = []
        i = 0
        while f"cpu{i}" in cpus:
            nucleos.append(round(uso(f"cpu{i}"), 1))
            i += 1
        temp = ler_int(fixos["temp_cpu"]) / 1000 if fixos["temp_cpu"] else 0

        self.ant = {"tempo": agora, "cpus": cpus, "discos": discos_ant, "redes": redes_ant,
                    "procs": {pid: (v[0], v[1], v[2]) for pid, v in procs.items()}}

        return {
            "idioma": self.lingua,
            "vidro": vidro(),
            "eu": self.minha_unidade,
            "cpu": {"uso": round(uso("cpu"), 1), "nucleos_uso": nucleos, "nome": fixos["cpu_nome"],
                    "nucleos": fixos["nucleos"], "logicos": fixos["logicos"], "base": fixos["base"],
                    "ghz": round(sum(freqs) / len(freqs) / 1000, 2) if freqs else 0,
                    "temp": round(temp), "virtual": fixos["virtual"],
                    "processos": len(procs), "threads": n_threads,
                    "ligado": int(float((ler(PROC + "/uptime") or "0").split()[0]))},
            "memoria": memoria,
            "discos": discos,
            "redes": redes,
            "placas": placas,
            "grupos": lista,
        }

    def ler_discos(self, agora, ant, dt):
        nomes = []
        bloco = SYS + "/block"
        for nome in sorted(os.listdir(bloco)) if os.path.isdir(bloco) else []:
            if re.match(r"(loop|ram|zram|dm-|sr|md|nbd|fd)", nome):
                continue
            if ler_int(f"{bloco}/{nome}/size") == 0:
                continue
            nomes.append(nome)
        estat = {}
        for linha in ler(PROC + "/diskstats").splitlines():
            p = linha.split()
            if len(p) >= 13 and p[2] in nomes:
                estat[p[2]] = (int(p[5]) * 512, int(p[9]) * 512, int(p[12]))
        usados = self.espaco_usado(nomes)
        discos, novos = [], {}
        for indice, nome in enumerate(nomes):
            lido, escrito, ativo_ms = estat.get(nome, (0, 0, 0))
            novos[nome] = (lido, escrito, ativo_ms)
            leitura = gravacao = ativo = 0.0
            if nome in ant and dt > 0:
                leitura = max(0.0, (lido - ant[nome][0]) / dt)
                gravacao = max(0.0, (escrito - ant[nome][1]) / dt)
                ativo = max(0.0, min(100.0, (ativo_ms - ant[nome][2]) / (dt * 10)))
            modelo = (ler(f"{SYS}/block/{nome}/device/model") or ler(f"{SYS}/block/{nome}/device/name")).strip()
            rotativo = ler_int(f"{SYS}/block/{nome}/queue/rotational")
            if nome.startswith("vd"):
                tipo = "virtual"
            elif rotativo:
                tipo = "hd"
            elif nome.startswith("nvme"):
                tipo = "nvme"
            else:
                tipo = "ssd"
            removivel = ler_int(f"{SYS}/block/{nome}/removable") == 1
            discos.append({"nome": nome, "indice": indice, "modelo": modelo, "tipo": tipo,
                           "removivel": removivel, "total": ler_int(f"{SYS}/block/{nome}/size") * 512,
                           "usado": min(usados.get(nome, 0), ler_int(f"{SYS}/block/{nome}/size") * 512), "leitura": round(leitura), "gravacao": round(gravacao),
                           "ativo": round(ativo, 1)})
        return discos, novos

    def espaco_usado(self, discos):
        """Quanto cada disco tem ocupado, somando os sistemas de arquivos montados nele."""
        def disco_de(nome, profundidade=0):
            if profundidade > 6:
                return set()
            if nome in discos:
                return {nome}
            pasta = f"{SYS}/class/block/{nome}"
            if os.path.exists(pasta + "/partition"):
                pai = os.path.basename(os.path.dirname(os.path.realpath(pasta)))
                return disco_de(pai, profundidade + 1)
            achados = set()
            if os.path.isdir(pasta + "/slaves"):
                for escravo in os.listdir(pasta + "/slaves"):
                    achados |= disco_de(escravo, profundidade + 1)
            return achados

        usados, vistos = {}, set()
        for linha in ler(PROC + "/self/mounts").splitlines():
            p = linha.split()
            if len(p) < 2 or not p[0].startswith("/dev/"):
                continue
            dispositivo = os.path.basename(os.path.realpath(p[0]))
            if dispositivo in vistos:
                continue
            vistos.add(dispositivo)
            try:
                st = os.statvfs(p[1].replace("\\040", " "))
            except OSError:
                continue
            ocupado = (st.f_blocks - st.f_bfree) * st.f_frsize
            for d in disco_de(dispositivo):
                usados[d] = usados.get(d, 0) + ocupado
        return usados

    def ler_redes(self, agora, ant, dt):
        if agora - self.ips[0] > 5:
            self.ips = (agora, {})
        redes, novos = [], {}
        for linha in ler(PROC + "/net/dev").splitlines()[2:]:
            nome, _, resto = linha.partition(":")
            nome = nome.strip()
            if not os.path.exists(f"{SYS}/class/net/{nome}/device"):
                continue  # só placas de verdade (sem lo, docker, ponte...)
            p = resto.split()
            if len(p) < 9:
                continue
            recebido, enviado = int(p[0]), int(p[8])
            novos[nome] = (recebido, enviado)
            rec = env = 0.0
            if nome in ant and dt > 0:
                rec = max(0.0, (recebido - ant[nome][0]) / dt)
                env = max(0.0, (enviado - ant[nome][1]) / dt)
            if nome not in self.ips[1]:
                self.ips[1][nome] = ip_da_interface(nome)
            velocidade = ler_int(f"{SYS}/class/net/{nome}/speed", 0)
            redes.append({"nome": nome, "wifi": os.path.isdir(f"{SYS}/class/net/{nome}/wireless"),
                          "ligada": ler(f"{SYS}/class/net/{nome}/operstate").strip() == "up",
                          "rec": round(rec), "env": round(env), "ip": self.ips[1][nome],
                          "velocidade": velocidade if velocidade > 0 else 0})
        return redes, novos

    def ler_placas(self, fixos):
        placas = []
        dados_nvidia = None
        if any(p["driver"] == "nvidia" for p in fixos["placas"]) and shutil.which("nvidia-smi"):
            if time.monotonic() - self.nvidia[0] > 1.8:
                try:
                    r = subprocess.run(["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,"
                                        "temperature.gpu,clocks.gr", "--format=csv,noheader,nounits"],
                                       capture_output=True, text=True, timeout=2)
                    self.nvidia = (time.monotonic(), r.stdout.splitlines() if r.returncode == 0 else None)
                except (OSError, subprocess.SubprocessError):
                    self.nvidia = (time.monotonic(), None)
            dados_nvidia = self.nvidia[1]
        n_nvidia = 0
        for indice, p in enumerate(fixos["placas"]):
            placa = {"indice": indice, "nome": p["nome"], "driver": p["versao"], "uso": -1, "vram_usada": 0,
                     "vram_total": 0, "temp": 0, "mhz": 0}
            if p["driver"] == "nvidia" and dados_nvidia and n_nvidia < len(dados_nvidia):
                campos = [c.strip() for c in dados_nvidia[n_nvidia].split(",")]
                n_nvidia += 1
                if len(campos) >= 6:
                    def num(texto):
                        try:
                            return float(texto)
                        except ValueError:
                            return 0.0
                    placa.update(nome=campos[0], uso=num(campos[1]), vram_usada=int(num(campos[2]) * 1048576),
                                 vram_total=int(num(campos[3]) * 1048576), temp=num(campos[4]), mhz=num(campos[5]))
            else:
                caminho = p["caminho"]
                if os.path.exists(caminho + "/gpu_busy_percent"):
                    placa["uso"] = ler_int(caminho + "/gpu_busy_percent", -1)
                placa["vram_usada"] = ler_int(caminho + "/mem_info_vram_used")
                placa["vram_total"] = ler_int(caminho + "/mem_info_vram_total")
                if p["temp"]:
                    placa["temp"] = round(ler_int(p["temp"]) / 1000)
                for linha in ler(caminho + "/pp_dpm_sclk").splitlines():
                    if linha.strip().endswith("*"):
                        m = re.search(r"(\d+)\s*[Mm][Hh]z", linha)
                        if m:
                            placa["mhz"] = int(m.group(1))
            placas.append(placa)
        return placas


# ----- encerrar -----
def pids_da_unidade(unidade):
    pids = []
    for nome in os.listdir(PROC):
        if nome.isdigit():
            for linha in ler(f"{PROC}/{nome}/cgroup").splitlines():
                if linha.startswith("0::") and linha.rstrip().endswith("/" + unidade):
                    pids.append(int(nome))
    return pids


def pode_encerrar(pid):
    """Só processos da pessoa, e nunca as partes que seguram a sessão."""
    try:
        if os.stat(f"{PROC}/{pid}").st_uid != MEU_UID:
            return False
    except OSError:
        return False
    stat = ler(f"{PROC}/{pid}/stat")
    nome = stat[stat.find("(") + 1:stat.rfind(")")]
    cmd = [p for p in ler(f"{PROC}/{pid}/cmdline").split("\0") if p]
    exe = os.path.basename(cmd[0]) if cmd else nome
    return pid > 1 and nome not in NUCLEO and exe not in NUCLEO and nome != "plasmashell" and exe != "plasmashell"


def inicio_do_pid(pid):
    stat = ler(f"{PROC}/{pid}/stat")
    campos = stat[stat.rfind(")") + 2:].split()
    return campos[19] if len(campos) > 19 else None


def encerrar(alvos, na_hora=False, espera=3.0):
    pids = []
    for alvo in alvos:
        if alvo.startswith("unidade:"):
            unidade = alvo[8:]
            if re.fullmatch(r"[A-Za-z0-9@._:\\-]+", unidade):
                pids += pids_da_unidade(unidade)
        elif alvo.isdigit():
            pids.append(int(alvo))
    eu = {os.getpid(), os.getppid()}
    marcados = {}
    for pid in dict.fromkeys(pids):
        if pid in eu or not pode_encerrar(pid):
            continue
        marcados[pid] = inicio_do_pid(pid)
        try:
            os.kill(pid, signal.SIGKILL if na_hora else signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            marcados.pop(pid, None)
    if not na_hora and marcados:
        limite = time.monotonic() + espera
        while time.monotonic() < limite and any(inicio_do_pid(p) == i for p, i in marcados.items()):
            time.sleep(0.1)
        for pid, inicio in marcados.items():
            if inicio_do_pid(pid) == inicio:  # ainda é o mesmo processo e não fechou: na hora
                try:
                    os.kill(pid, signal.SIGKILL)
                except (ProcessLookupError, PermissionError):
                    pass
    # O próprio gerenciador (se a pessoa pediu para fechar ele) fecha por último.
    for pid in dict.fromkeys(pids):
        if pid in eu and pode_encerrar(pid) and pid != os.getpid():
            try:
                os.kill(pid, signal.SIGTERM)
            except (ProcessLookupError, PermissionError):
                pass
    print(f"encerrados={len(marcados)}")


def reiniciar_barra():
    r = subprocess.run(["systemctl", "--user", "restart", "plasma-plasmashell.service"], capture_output=True)
    if r.returncode != 0:
        subprocess.run(["kquitapp6", "plasmashell"], capture_output=True)
        subprocess.Popen(["kstart", "plasmashell"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("ok")


# ----- abrir ao entrar -----
def pastas_inicio_sistema():
    pastas = (os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg").split(":")
    return [os.path.join(p, "autostart") for p in pastas if p]


def pasta_inicio_usuario():
    return os.path.join(config_casa(), "autostart")


def aparece_no_kde(dados):
    so = [x for x in dados.get("OnlyShowIn", "").split(";") if x]
    nao = [x for x in dados.get("NotShowIn", "").split(";") if x]
    return (not so or "KDE" in so) and "KDE" not in nao


def inicializacao():
    lingua = idioma()
    usuario = pasta_inicio_usuario()
    arquivos = {}
    for pasta in reversed(pastas_inicio_sistema()):
        for nome in sorted(os.listdir(pasta)) if os.path.isdir(pasta) else []:
            if nome.endswith(".desktop"):
                arquivos[nome] = ("sistema", os.path.join(pasta, nome))
    for nome in sorted(os.listdir(usuario)) if os.path.isdir(usuario) else []:
        if nome.endswith(".desktop"):
            origem = arquivos.get(nome, ("seu",))[0]
            arquivos[nome] = (origem, os.path.join(usuario, nome))
    lista = []
    for nome, (origem, caminho) in arquivos.items():
        base = nome[:-8]
        if base in INICIO_ESCONDIDO:
            continue
        dados = ler_desktop(caminho)
        if not dados or not aparece_no_kde(dados) or dados.get("Type", "Application") != "Application":
            continue
        if origem == "sistema" and (dados.get("NoDisplay", "").lower() == "true" or "X-KDE-autostart-phase" in dados):
            continue
        ligado = dados.get("Hidden", "").lower() != "true" and \
            dados.get("X-GNOME-Autostart-enabled", "true").lower() != "false"
        lista.append({"arquivo": nome, "nome": traduzido(dados, "Name", lingua) or base,
                      "icone": dados.get("Icon", ""), "descricao": traduzido(dados, "Comment", lingua),
                      "ligado": ligado, "origem": origem})
    lista.sort(key=lambda x: x["nome"].lower())
    print(json.dumps({"idioma": lingua, "itens": lista}, ensure_ascii=False))


def trocar_chave(texto, chave, valor):
    """Põe chave=valor no grupo [Desktop Entry], trocando se já existir."""
    linhas = texto.splitlines()
    saida, dentro, feito = [], False, False
    for linha in linhas:
        limpa = linha.strip()
        if limpa.startswith("["):
            if dentro and not feito:
                saida.append(f"{chave}={valor}")
                feito = True
            dentro = limpa == "[Desktop Entry]"
            saida.append(linha)
            continue
        if dentro and limpa.split("=", 1)[0].strip() == chave:
            if not feito:
                saida.append(f"{chave}={valor}")
                feito = True
            continue
        saida.append(linha)
    if not feito:
        if not any(linha.strip() == "[Desktop Entry]" for linha in linhas):
            saida.insert(0, "[Desktop Entry]")
            saida.insert(1, f"{chave}={valor}")
        else:
            saida.append(f"{chave}={valor}")
    return "\n".join(saida) + "\n"


def ligar_inicio(arquivo, ligar):
    if "/" in arquivo or not arquivo.endswith(".desktop") or arquivo.startswith("."):
        print("erro=nome")
        return 1
    usuario = os.path.join(pasta_inicio_usuario(), arquivo)
    sistema = next((os.path.join(p, arquivo) for p in pastas_inicio_sistema()
                    if os.path.isfile(os.path.join(p, arquivo))), None)
    if os.path.isfile(usuario):
        texto = ler(usuario)
        if ligar and sistema and "X-Matsu-Desligado=true" in texto:
            os.remove(usuario)  # era só o nosso "desligado": volta a valer o do sistema
        else:
            texto = trocar_chave(texto, "Hidden", "false" if ligar else "true")
            with open(usuario, "w", encoding="utf-8") as f:
                f.write(texto)
    elif sistema:
        if not ligar:
            os.makedirs(os.path.dirname(usuario), exist_ok=True)
            texto = trocar_chave(ler(sistema), "Hidden", "true")
            texto = trocar_chave(texto, "X-Matsu-Desligado", "true")
            with open(usuario, "w", encoding="utf-8") as f:
                f.write(texto)
    else:
        print("erro=nao-existe")
        return 1
    print("ok")
    return 0


def vigiar(intervalo):
    leitor = Leitor()
    pai = os.getppid()
    leitor.amostra()
    time.sleep(0.4)
    while True:
        dados = leitor.amostra()
        try:
            sys.stdout.write(json.dumps(dados, ensure_ascii=False, separators=(",", ":")) + "\n")
            sys.stdout.flush()
        except BrokenPipeError:
            return 0
        if os.getppid() != pai:
            return 0  # a janela fechou
        time.sleep(intervalo)


def main(args):
    if not args:
        print(__doc__)
        return 2
    comando, resto = args[0], args[1:]
    if comando == "vigiar":
        try:
            intervalo = float(resto[0]) if resto else 1.0
        except ValueError:
            intervalo = 1.0
        return vigiar(max(0.25, min(10.0, intervalo)))
    if comando == "amostra":
        leitor = Leitor()
        leitor.amostra()
        time.sleep(0.4)
        print(json.dumps(leitor.amostra(), ensure_ascii=False))
        return 0
    if comando in ("finalizar", "forcar"):
        encerrar(resto, na_hora=comando == "forcar")
        return 0
    if comando == "reiniciar-barra":
        reiniciar_barra()
        return 0
    if comando == "inicializacao":
        inicializacao()
        return 0
    if comando == "inicializacao-ligar" and len(resto) == 2 and resto[1] in ("sim", "nao"):
        return ligar_inicio(resto[0], resto[1] == "sim")
    print(__doc__)
    return 2


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    sys.exit(main(sys.argv[1:]))
