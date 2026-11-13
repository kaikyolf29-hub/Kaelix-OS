#!/usr/bin/python3
"""Central de jogos do Matsu: o ajudante.

A janela (os arquivos .qml desta pasta) só desenha. Quem lê a placa de vídeo, a
biblioteca da Steam e liga o modo jogo é este script. Só usa a biblioteca padrão
do Python e responde em JSON. As leituras do sistema (nome da placa, driver,
uso) são as mesmas do Gerenciador de tarefas: o ajudante dele é carregado aqui.

Uso:
  ajudante.py vigiar [segundos]   placa de vídeo, CPU, memória e o jogo aberto, uma linha JSON por intervalo
  ajudante.py biblioteca          os jogos da Steam, com capa, horas jogadas e quando jogou (JSON)
  ajudante.py config              a configuração da central (JSON)
  ajudante.py salvar <json>       grava a configuração e refaz a sobreposição
  ajudante.py jogar <appid>       abre o jogo pela Steam
  ajudante.py atualizacao [--agora]  se o sistema (e o driver junto) tem versão nova
  ajudante.py servico             fica rodando: liga o modo jogo e o perfil quando um jogo abre
  ajudante.py sobreposicao        refaz o arquivo da sobreposição (MangoHud) pela configuração
  ajudante.py fps [on|off|alternar] [--avisar]
                                  liga, desliga ou troca o FPS no jogo (a mesma chave da página
                                  Sobreposição, da Central de controle e do atalho Meta+Alt+F)
  ajudante.py controles           os controles pareados e ligados, com a bateria (JSON)
  ajudante.py controle desconectar|conectar|esquecer <MAC>
  ajudante.py bluetooth-ligar     tira o bloqueio e liga o Bluetooth
  ajudante.py parear [tipo] [segundos]
                                  procura um controle em modo de parear e pareia (uma linha JSON por etapa)
  ajudante.py testar <eventN> [tipo]
                                  os botões e os direcionais do controle, ao vivo (uma linha JSON por mudança)
  ajudante.py drivers [--agora]   as placas, o driver de cada uma, Mesa, Vulkan, OpenGL e a imagem (JSON)
  ajudante.py trocar-imagem [outra]  troca para a imagem do Matsu que combina com a placa (com ou sem NVIDIA);
                                     "outra" vai para a outra versão mesmo sem a placa pedir (o caminho de volta)
"""
import glob
import importlib.util
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time

AQUI = os.path.dirname(os.path.abspath(__file__))


def _carregar_tarefas():
    caminho = os.environ.get("MATSU_TAREFAS_AJUDANTE") or os.path.join(AQUI, "..", "tarefas", "ajudante.py")
    spec = importlib.util.spec_from_file_location("matsu_tarefas", caminho)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


def _carregar(nome, variavel):
    caminho = os.environ.get(variavel) or os.path.join(AQUI, nome + ".py")
    spec = importlib.util.spec_from_file_location("matsu_jogos_" + nome, caminho)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


T = _carregar_tarefas()
C = _carregar("controles", "MATSU_JOGOS_CONTROLES")
D = _carregar("drivers", "MATSU_JOGOS_DRIVERS")
ler, ler_int = T.ler, T.ler_int
PROC, SYS = T.PROC, T.SYS
MEU_UID = T.MEU_UID

# ----- os perfis gráficos -----
# energia: manter | economia | equilibrado | desempenho (o perfil de energia do sistema)
# placa:   auto | maximo | economia (o nível da placa AMD; na NVIDIA o driver cuida)
#          "economia" prende a placa na velocidade mais baixa: bom para jogo leve,
#          por isso o perfil Economia deixa no automático e segura o FPS (a placa
#          desce sozinha quando sobra folga).
# fps:     0 (sem limite) ou o limite
# vsync:   jogo (o que o jogo escolher) | ligada | desligada
# af:      0 (o do jogo) ou 2, 4, 8, 16 (filtro anisotrópico, texturas nítidas de lado)
# modo_jogo: liga o GameMode (prioridade para o jogo, tela não apaga)
# latencia: baixa latência (o "Anti-Lag" do jeito que existe no Linux): o DXVK
#          (jogos DirectX 9, 10 e 11 pelo Proton) segura só 1 quadro na fila
#          (dxgi/d3d9.maxFrameLatency = 1) e, com limite de FPS, o MangoHud segura
#          o quadro antes do jogo ler os comandos (fps_limit_method=early).
PERFIS = {
    "padrao": {"energia": "manter", "placa": "auto", "fps": 0, "vsync": "jogo", "af": 0, "modo_jogo": True,
               "latencia": False},
    "desempenho": {"energia": "desempenho", "placa": "maximo", "fps": 0, "vsync": "desligada", "af": 0,
                   "modo_jogo": True, "latencia": True},
    "qualidade": {"energia": "desempenho", "placa": "auto", "fps": 0, "vsync": "ligada", "af": 16,
                  "modo_jogo": True, "latencia": False},
    "economia": {"energia": "economia", "placa": "auto", "fps": 60, "vsync": "ligada", "af": 0,
                 "modo_jogo": False, "latencia": False},
}
NOMES_PERFIS = ("padrao", "desempenho", "qualidade", "economia", "personalizado")
ENERGIA_PPD = {"economia": "power-saver", "equilibrado": "balanced", "desempenho": "performance"}
NIVEL_AMD = {"auto": "auto", "maximo": "high", "economia": "low"}
FPS_VALIDOS = (0, 30, 40, 45, 60, 75, 90, 120, 144, 165, 240)
AF_VALIDOS = (0, 2, 4, 8, 16)

# As teclas que o MangoHud tem de fábrica (todas desligadas: veja texto_mangohud).
TECLAS_MANGOHUD = ("toggle_hud", "toggle_hud_position", "toggle_preset", "reset_fps_metrics", "toggle_fps_limit",
                   "toggle_logging", "reload_cfg", "upload_log", "upload_logs")
# O atalho do KDE que liga e desliga o FPS no jogo (build_files/jogos.sh registra).
ATALHO_FPS = "Meta+Alt+F"

# O que a sobreposição pode mostrar, na ordem em que aparece no jogo.
ITENS = ("fps", "grafico", "cpu", "gpu", "ram", "vram", "temperatura", "frequencia", "consumo", "hora")
POSICOES = ("top-left", "top-center", "top-right", "bottom-left", "bottom-right")
TAMANHOS = {"pequeno": 18, "medio": 22, "grande": 27}

PADRAO = {
    "perfil": "padrao",
    "personalizado": dict(PERFIS["padrao"]),
    "jogos": {},
    "automatico": True,
    "avisar": True,
    "sobreposicao": {"ligada": False, "itens": ["fps", "grafico", "cpu", "gpu", "ram"], "posicao": "top-left",
                     "tamanho": "medio", "compacta": False},
}

# Programas que não são jogo: a sobreposição nunca aparece neles.
NAO_JOGOS = ("matsu-janela", "plasmashell", "kwin_wayland", "kwin_x11", "krunner", "systemsettings", "dolphin",
             "konsole", "matsu-terminal", "brave", "brave-browser", "firefox", "chromium", "mpv", "celluloid", "vlc", "haruna",
             "zed", "zeditor", "code", "blender", "obs", "kdenlive", "gimp", "krita", "steam", "steamwebhelper",
             "corectrl", "lact")

# Peças da Steam que aparecem como "app" mas não são jogos.
FERRAMENTAS = re.compile(r"^(Proton\b|Steam Linux Runtime|Steamworks Common|SteamVR|Steam Audio|"
                         r"Steamworks Shared|Proton EasyAntiCheat|Proton BattlEye)", re.I)
FERRAMENTAS_IDS = {"228980", "1070560", "1391110", "1628350", "1493710", "2180100", "1826330", "250820",
                   "1161040", "1007020", "4183110"}

# Programas do Windows (Wine) que nunca são o jogo.
WINE_NAO_JOGOS = {"explorer.exe", "services.exe", "winedevice.exe", "plugplay.exe", "svchost.exe", "rpcss.exe",
                  "tabtip.exe", "conhost.exe", "start.exe", "wineboot.exe", "winemenubuilder.exe", "rundll32.exe",
                  "steam.exe", "steamwebhelper.exe", "regsvr32.exe", "msiexec.exe", "cmd.exe", "uninstaller.exe",
                  "epicgameslauncher.exe", "epicwebhelper.exe", "galaxyclient.exe", "eadesktop.exe",
                  "battle.net.exe", "ubisoftconnect.exe", "upc.exe", "crashhandler.exe", "unitycrashhandler64.exe",
                  "crashreportclient.exe", "easyanticheat.exe", "beservice.exe", "iexplore.exe", "mscorsvw.exe",
                  "winecfg.exe", "control.exe", "notepad.exe"}


# ----- pastas -----
def config_casa():
    return T.config_casa()


def arquivo_config():
    return os.environ.get("MATSU_JOGOS_CONFIG") or os.path.join(config_casa(), "matsu", "jogos.json")


def arquivo_mangohud():
    return os.environ.get("MATSU_MANGOHUD_CONF") or os.path.join(config_casa(), "MangoHud", "MangoHud.conf")


def pasta_estado():
    base = os.environ.get("MATSU_JOGOS_ESTADO") or os.path.join(
        os.environ.get("XDG_RUNTIME_DIR") or os.path.join(T.casa(), ".cache"), "matsu-jogos")
    return base


def arquivo_estado():
    return os.path.join(pasta_estado(), "agora.json")


def cache_casa():
    return os.environ.get("XDG_CACHE_HOME") or os.path.join(T.casa(), ".cache")


def gravar(caminho, texto):
    """Grava de uma vez (arquivo novo e troca), para ninguém ler pela metade."""
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    temp = f"{caminho}.{os.getpid()}.tmp"
    with open(temp, "w", encoding="utf-8") as f:
        f.write(texto)
    os.replace(temp, caminho)


def ler_json(caminho, padrao=None):
    try:
        with open(caminho, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return padrao


# ----- configuração -----
def _escolha(valor, validos, padrao):
    return valor if valor in validos else padrao


def limpar_ajustes(a, base=None):
    base = base or PERFIS["padrao"]
    a = a if isinstance(a, dict) else {}
    try:
        fps = int(a.get("fps", base["fps"]))
    except (TypeError, ValueError):
        fps = base["fps"]
    try:
        af = int(a.get("af", base["af"]))
    except (TypeError, ValueError):
        af = base["af"]
    return {
        "energia": _escolha(a.get("energia"), ("manter", "economia", "equilibrado", "desempenho"), base["energia"]),
        "placa": _escolha(a.get("placa"), tuple(NIVEL_AMD), base["placa"]),
        "fps": fps if fps in FPS_VALIDOS else base["fps"],
        "vsync": _escolha(a.get("vsync"), ("jogo", "ligada", "desligada"), base["vsync"]),
        "af": af if af in AF_VALIDOS else base["af"],
        "modo_jogo": bool(a.get("modo_jogo", base["modo_jogo"])),
        "latencia": bool(a.get("latencia", base["latencia"])),
    }


def limpar_config(c):
    """A configuração só com chaves e valores conhecidos (o resto cai no padrão)."""
    c = c if isinstance(c, dict) else {}
    s = c.get("sobreposicao") if isinstance(c.get("sobreposicao"), dict) else {}
    ps = PADRAO["sobreposicao"]
    itens = [i for i in s.get("itens", ps["itens"]) if i in ITENS] if isinstance(s.get("itens"), list) else ps["itens"]
    jogos = {}
    if isinstance(c.get("jogos"), dict):
        for chave, perfil in c["jogos"].items():
            if re.fullmatch(r"[\w.-]{1,64}", str(chave)) and perfil in NOMES_PERFIS:
                jogos[str(chave)] = perfil
    return {
        "perfil": _escolha(c.get("perfil"), NOMES_PERFIS, "padrao"),
        "personalizado": limpar_ajustes(c.get("personalizado")),
        "jogos": jogos,
        "automatico": bool(c.get("automatico", True)),
        "avisar": bool(c.get("avisar", True)),
        "sobreposicao": {
            "ligada": bool(s.get("ligada", ps["ligada"])),
            "itens": [i for i in ITENS if i in itens],
            "posicao": _escolha(s.get("posicao"), POSICOES, ps["posicao"]),
            "tamanho": _escolha(s.get("tamanho"), tuple(TAMANHOS), ps["tamanho"]),
            "compacta": bool(s.get("compacta", ps["compacta"])),
        },
    }


def carregar_config():
    return limpar_config(ler_json(arquivo_config(), {}))


def salvar_config(c):
    c = limpar_config(c)
    gravar(arquivo_config(), json.dumps(c, ensure_ascii=False, indent=2) + "\n")
    return c


def ajustes_do_perfil(c, perfil):
    if perfil == "personalizado":
        return dict(c["personalizado"])
    return dict(PERFIS.get(perfil, PERFIS["padrao"]))


def perfil_do_jogo(c, jogo_id):
    return c["jogos"].get(str(jogo_id)) or c["perfil"]


# ----- a sobreposição (MangoHud) no visual do Matsu -----
def fonte_matsu():
    """A Inter (a letra do Matsu), num arquivo que o MangoHud consiga ler."""
    if os.environ.get("MATSU_FONTE_HUD") is not None:
        return os.environ["MATSU_FONTE_HUD"]
    for padrao in ("/usr/share/fonts/rsms-inter*/Inter-SemiBold.otf", "/usr/share/fonts/rsms-inter*/Inter-SemiBold.ttf",
                   "/usr/share/fonts/rsms-inter*/Inter-Medium.otf", "/usr/share/fonts/*/Inter-SemiBold.*",
                   "/usr/share/fonts/rsms-inter*/Inter*.ttf", "/usr/share/fonts/rsms-inter*/Inter*.otf"):
        achados = sorted(glob.glob(padrao))
        if achados:
            return achados[0]
    return ""


def texto_mangohud(c, ajustes=None, mostrar=False):
    """O MangoHud.conf do Matsu. "mostrar": se a sobreposição aparece agora (só com jogo aberto)."""
    s = c["sobreposicao"]
    itens = s["itens"]
    linhas = [
        "# Sobreposição do Matsu (MangoHud). Quem escreve este arquivo é a Central de jogos:",
        "# mude por ela, porque o que for mudado aqui à mão volta ao jeito dela.",
        "legacy_layout=0",
    ]
    # Na ordem em que aparece no jogo (com legacy_layout=0, só o que está listado aparece).
    if "hora" in itens:
        linhas += ["time", "time_no_label", "time_format=%H:%M"]
    if "fps" in itens:
        linhas += ["fps", "fps_text=FPS", "hide_fps_superscript"]
        if not s["compacta"]:
            linhas.append("frametime")
    if "grafico" in itens and not s["compacta"]:
        linhas.append("frame_timing")
    if "gpu" in itens or "temperatura" in itens or "frequencia" in itens or "consumo" in itens:
        linhas += ["gpu_stats", "gpu_text=GPU"]
        if "temperatura" in itens:
            linhas.append("gpu_temp")
        if "frequencia" in itens:
            linhas.append("gpu_core_clock")
        if "consumo" in itens:
            linhas.append("gpu_power")
    if "cpu" in itens or "temperatura" in itens or "frequencia" in itens:
        linhas += ["cpu_stats", "cpu_text=CPU"]
        if "temperatura" in itens:
            linhas.append("cpu_temp")
        if "frequencia" in itens:
            linhas.append("cpu_mhz")
    if "vram" in itens:
        linhas.append("vram")
    if "ram" in itens:
        linhas.append("ram")
    tamanho = TAMANHOS[s["tamanho"]]
    fonte = fonte_matsu()
    linhas += [
        f"position={s['posicao']}",
        f"font_size={tamanho}",
        "round_corners=10",
        "background_alpha=0.55",
        "background_color=1c1c1f",
        "text_color=ffffff",
        "text_outline=0",
        # As cores das partes do computador, as mesmas do Gerenciador de tarefas.
        "cpu_color=45d0c1",
        "gpu_color=f0729f",
        "ram_color=b18cf5",
        "vram_color=f59f6b",
        "engine_color=ffffff",
        "frametime_color=45d0c1",
        "fps_color_change",
        "fps_value=30,60",
        "fps_color=f0609e,f5c36b,ffffff",
        "offset_x=12",
        "offset_y=12",
        # Sem as teclas próprias do MangoHud (Shift+F12 só esconderia neste jogo e
        # deixaria a chave da Central mentindo; Shift+F1 trocaria o limite de FPS do
        # perfil; Shift+F3 mandaria o registro para a internet): quem mostra e
        # esconde é o atalho Meta+Alt+F do KDE, que muda este arquivo, e o MangoHud
        # do jogo aberto relê na hora.
    ] + [f"{tecla}=" for tecla in TECLAS_MANGOHUD]
    if s["compacta"]:
        # Uma pílula só do tamanho do texto (sem esticar até a ponta da tela).
        linhas += ["horizontal", "horizontal_stretch=0", "horizontal_separator_color=55555c",
                   "hud_compact", "table_columns=14"]
    else:
        linhas += ["table_columns=3", "cellpadding_y=0.05"]
    if fonte:
        linhas.append(f"font_file={fonte}")
    if not mostrar or not s["ligada"] or not itens:
        linhas.append("no_display")
    if ajustes:
        if ajustes["fps"]:
            linhas.append(f"fps_limit={ajustes['fps']}")
            # Baixa latência: espera antes do jogo ler os comandos, não depois.
            linhas.append("fps_limit_method=" + ("early" if ajustes.get("latencia") else "late"))
        if ajustes["vsync"] == "ligada":
            linhas += ["vsync=3", "gl_vsync=1"]
        elif ajustes["vsync"] == "desligada":
            linhas += ["vsync=1", "gl_vsync=0"]
        if ajustes["af"]:
            linhas.append(f"af={ajustes['af']}")
    linhas.append("blacklist=" + ",".join(NAO_JOGOS))
    return "\n".join(linhas) + "\n"


def escrever_mangohud(c=None, estado=None):
    c = c or carregar_config()
    estado = estado if estado is not None else ler_json(arquivo_estado(), {}) or {}
    jogo = estado.get("jogo")
    ajustes = jogo.get("ajustes") if jogo else None
    texto = texto_mangohud(c, ajustes, mostrar=bool(jogo))
    caminho = arquivo_mangohud()
    if ler(caminho) != texto:
        # Escreve no mesmo arquivo (sem trocar), porque o MangoHud de quem já está
        # aberto fica de olho nele e recarrega na hora.
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        with open(caminho, "w", encoding="utf-8") as f:
            f.write(texto)
    return texto


# ----- baixa latência nos jogos DirectX pelo Proton (DXVK) -----
def arquivo_dxvk():
    """O dxvk.conf da pessoa, o mesmo do DXVK_CONFIG_FILE do environment.d do Matsu.
    Um DXVK_CONFIG_FILE escolhido pela pessoa fora de ~/.config/matsu não é mexido."""
    if os.environ.get("MATSU_DXVK_CONF"):
        return os.environ["MATSU_DXVK_CONF"]
    nosso = os.path.join(config_casa(), "matsu", "jogos", "dxvk.conf")
    escolhido = os.environ.get("DXVK_CONFIG_FILE", "")
    if escolhido and os.path.realpath(escolhido).startswith(os.path.realpath(os.path.join(config_casa(), "matsu")) + os.sep):
        return escolhido
    return nosso


def texto_dxvk(ajustes=None):
    linhas = ["# Matsu: o DXVK (jogos DirectX 9, 10 e 11 pelo Proton) lê este arquivo quando o jogo abre.",
              "# Quem escreve é a Central de jogos, com o perfil do jogo aberto (Baixa latência)."]
    if ajustes and ajustes.get("latencia"):
        linhas += ["dxgi.maxFrameLatency = 1", "d3d9.maxFrameLatency = 1"]
    return "\n".join(linhas) + "\n"


def escrever_dxvk(estado=None):
    estado = estado if estado is not None else ler_json(arquivo_estado(), {}) or {}
    jogo = estado.get("jogo")
    texto = texto_dxvk(jogo.get("ajustes") if jogo else None)
    caminho = arquivo_dxvk()
    if ler(caminho) != texto:
        gravar(caminho, texto)
    return texto


# ----- o FPS no jogo: a mesma chave em três lugares -----
def fps(acao="", avisar_mudanca=False):
    """Liga (on), desliga (off) ou troca (alternar) a sobreposição; sem ação, só diz como está."""
    c = carregar_config()
    ligada = c["sobreposicao"]["ligada"]
    nova = {"on": True, "ligar": True, "off": False, "desligar": False, "alternar": not ligada}.get(acao, ligada)
    if acao and nova != ligada:
        c["sobreposicao"]["ligada"] = nova
        c = salvar_config(c)
        escrever_mangohud(c)
        if avisar_mudanca:
            pt = T.idioma() == "pt"
            avisar("FPS no jogo" if pt else "In-game FPS",
                   ("Ligado: aparece em cima do jogo" if nova else "Desligado") if pt
                   else ("On: shows on top of the game" if nova else "Off"))
    elif acao:
        escrever_mangohud(c)
    return {"ligada": c["sobreposicao"]["ligada"]}


# ----- Steam -----
def ler_vdf(texto):
    """O formato de texto da Steam (VDF) como dicionários. As chaves ficam em minúsculas."""
    fichas = re.findall(r'"((?:[^"\\]|\\.)*)"|([{}])', texto)
    raiz = {}
    pilha = [raiz]
    chave = None
    for texto_ficha, chave_ficha in fichas:
        if chave_ficha == "{":
            novo = {}
            if chave is not None:
                pilha[-1][chave.lower()] = novo
            pilha.append(novo)
            chave = None
        elif chave_ficha == "}":
            if len(pilha) > 1:
                pilha.pop()
            chave = None
        else:
            valor = texto_ficha.replace('\\"', '"').replace("\\\\", "\\")
            if chave is None:
                chave = valor
            else:
                pilha[-1][chave.lower()] = valor
                chave = None
    return raiz


def raizes_steam():
    """As pastas da Steam (a normal e a do Flatpak) que existem neste computador."""
    if os.environ.get("MATSU_STEAM"):
        candidatas = os.environ["MATSU_STEAM"].split(":")
    else:
        casa = T.casa()
        candidatas = [os.path.join(casa, ".local/share/Steam"), os.path.join(casa, ".steam/steam"),
                      os.path.join(casa, ".var/app/com.valvesoftware.Steam/.local/share/Steam"),
                      os.path.join(casa, ".var/app/com.valvesoftware.Steam/data/Steam")]
    vistas, raizes = set(), []
    for c in candidatas:
        if os.path.isdir(os.path.join(c, "steamapps")):
            real = os.path.realpath(c)
            if real not in vistas:
                vistas.add(real)
                raizes.append(c)
    return raizes


def bibliotecas(raiz):
    pastas = [raiz]
    dados = ler_vdf(ler(os.path.join(raiz, "steamapps", "libraryfolders.vdf")))
    for item in (dados.get("libraryfolders") or {}).values():
        if isinstance(item, dict) and item.get("path"):
            pastas.append(item["path"])
    vistas, unicas = set(), []
    for p in pastas:
        real = os.path.realpath(p)
        if real not in vistas and os.path.isdir(os.path.join(p, "steamapps")):
            vistas.add(real)
            unicas.append(p)
    return unicas


def usuario_steam(raiz):
    """A pasta userdata de quem entrou por último na Steam."""
    contas = ler_vdf(ler(os.path.join(raiz, "config", "loginusers.vdf"))).get("users") or {}
    for id64, info in contas.items():
        if isinstance(info, dict) and info.get("mostrecent") == "1" and id64.isdigit():
            pasta = os.path.join(raiz, "userdata", str(int(id64) - 76561197960265728))
            if os.path.isdir(pasta):
                return pasta
    melhores = []
    for p in glob.glob(os.path.join(raiz, "userdata", "*")):
        if os.path.basename(p).isdigit() and os.path.basename(p) != "0":
            arquivo = os.path.join(p, "config", "localconfig.vdf")
            melhores.append((os.path.getmtime(arquivo) if os.path.exists(arquivo) else 0, p))
    return max(melhores)[1] if melhores else ""


def tempo_de_jogo(raiz):
    """{appid: (minutos, último dia jogado)} do localconfig.vdf."""
    pasta = usuario_steam(raiz)
    if not pasta:
        return {}
    dados = ler_vdf(ler(os.path.join(pasta, "config", "localconfig.vdf")))
    apps = dados.get("userlocalconfigstore", {}).get("software", {}).get("valve", {}).get("steam", {}).get("apps", {})
    tempos = {}
    for appid, info in apps.items():
        if isinstance(info, dict):
            try:
                minutos = int(info.get("playtime", 0) or 0)
                ultima = int(info.get("lastplayed", 0) or 0)
            except ValueError:
                continue
            tempos[appid] = (minutos, ultima)
    return tempos


ARTES = {
    "capa": ("library_600x900_2x.jpg", "library_600x900.jpg", "library_capsule.jpg"),
    "heroi": ("library_hero_2x.jpg", "library_hero.jpg"),
    "logo": ("logo_2x.png", "logo.png"),
    "cabecalho": ("header_2x.jpg", "header.jpg", "library_header.jpg"),
}


def artes(raiz, appid):
    """As imagens que a Steam guarda de cada jogo (capa, fundo grande, logo): as de verdade."""
    cache = os.path.join(raiz, "appcache", "librarycache")
    achadas = {}
    pasta = os.path.join(cache, appid)
    nomes = {}
    if os.path.isdir(pasta):
        # Steam nova: uma pasta por jogo, às vezes com subpastas (traduções).
        for atual, _, arquivos in os.walk(pasta):
            for a in arquivos:
                nomes.setdefault(a.lower(), os.path.join(atual, a))
    for tipo, opcoes in ARTES.items():
        for nome in opcoes:
            if nome in nomes:
                achadas[tipo] = nomes[nome]
                break
            antigo = os.path.join(cache, f"{appid}_{nome}")  # Steam antiga: tudo numa pasta só
            if os.path.exists(antigo):
                achadas[tipo] = antigo
                break
    # O ícone pequeno: na Steam nova é um .jpg com nome de código, sozinho na pasta do jogo.
    icone = os.path.join(cache, f"{appid}_icon.jpg")
    if os.path.exists(icone):
        achadas["icone"] = icone
    elif os.path.isdir(pasta):
        for a in sorted(os.listdir(pasta)):
            if re.fullmatch(r"[0-9a-f]{40}\.jpg", a):
                achadas["icone"] = os.path.join(pasta, a)
                break
    return achadas


def biblioteca():
    raizes = raizes_steam()
    jogos = {}
    for raiz in raizes:
        tempos = tempo_de_jogo(raiz)
        for pasta in bibliotecas(raiz):
            for manifesto in glob.glob(os.path.join(pasta, "steamapps", "appmanifest_*.acf")):
                estado = ler_vdf(ler(manifesto)).get("appstate") or {}
                appid = estado.get("appid", "")
                nome = estado.get("name", "")
                if not appid.isdigit() or not nome or appid in jogos:
                    continue
                if appid in FERRAMENTAS_IDS or FERRAMENTAS.match(nome):
                    continue
                try:
                    bandeiras = int(estado.get("stateflags", "4") or 4)
                except ValueError:
                    bandeiras = 4
                minutos, ultima = tempos.get(appid, (0, 0))
                try:
                    ultima = max(ultima, int(estado.get("lastplayed", 0) or 0))
                    tamanho = int(estado.get("sizeondisk", 0) or 0)
                except ValueError:
                    tamanho = 0
                jogo = {
                    "id": appid, "nome": nome, "origem": "steam",
                    "minutos": minutos, "ultima": ultima, "tamanho": tamanho,
                    "pronto": bool(bandeiras & 4) and not bandeiras & 2,  # 4 = instalado, 2 = atualizando
                    "pasta": os.path.join(pasta, "steamapps", "common", estado.get("installdir", "")),
                }
                jogo.update(artes(raiz, appid))
                jogos[appid] = jogo
    lista = sorted(jogos.values(), key=lambda j: (-j["ultima"], j["nome"].lower()))
    return {"steam": bool(raizes) or bool(shutil.which("steam")), "jogos": lista}


def nomes_dos_jogos():
    try:
        return {j["id"]: j["nome"] for j in biblioteca()["jogos"]}
    except OSError:
        return {}


# ----- a placa de vídeo, a CPU e a memória -----
class Leitor:
    def __init__(self):
        self.tarefas = T.Leitor()
        self.cpu_ant = None
        self.servico = (0.0, None)
        self.energia = (0.0, None)
        self.ajuste = ajuste_avancado()
        self.conf = (None, False)

    def fps_ligada(self):
        """Se o FPS no jogo está ligado (o atalho e a Central de controle também mudam)."""
        try:
            tempo = os.path.getmtime(arquivo_config())
        except OSError:
            return False
        if tempo != self.conf[0]:
            self.conf = (tempo, bool(carregar_config()["sobreposicao"]["ligada"]))
        return self.conf[1]

    def cpu(self):
        campos = ler(PROC + "/stat").split("\n", 1)[0].split()[1:]
        try:
            valores = [int(v) for v in campos[:8]]
        except ValueError:
            return 0.0
        ocioso = valores[3] + (valores[4] if len(valores) > 4 else 0)
        total = sum(valores)
        uso = 0.0
        if self.cpu_ant and total > self.cpu_ant[1]:
            uso = 100.0 * (1 - (ocioso - self.cpu_ant[0]) / (total - self.cpu_ant[1]))
        self.cpu_ant = (ocioso, total)
        return round(max(0.0, min(100.0, uso)), 1)

    def memoria(self):
        info = {}
        for linha in ler(PROC + "/meminfo").splitlines():
            chave, _, valor = linha.partition(":")
            try:
                info[chave] = int(valor.split()[0]) * 1024
            except (ValueError, IndexError):
                pass
        total = info.get("MemTotal", 0)
        return {"total": total, "usada": max(0, total - info.get("MemAvailable", 0))}

    def placas(self):
        if os.environ.get("MATSU_JOGOS_DEMO"):
            return [placa_demo()]
        fixos = self.tarefas.dados_fixos()
        placas = self.tarefas.ler_placas(fixos)
        for placa, p in zip(placas, fixos["placas"]):
            placa["marca"] = T.MARCAS.get(p["fornecedor"], "")
            placa["fabricante"] = p["driver"]
            extra = {"temp_junc": 0, "mhz_mem": 0, "watts": 0.0, "watts_max": 0.0, "rpm": 0, "ventoinha": -1,
                     "nivel": "", "nivel_mudavel": False}
            if p["driver"] == "amdgpu":
                caminho = p["caminho"]
                nivel = ler(caminho + "/power_dpm_force_performance_level").strip()
                extra["nivel"] = nivel
                extra["nivel_mudavel"] = bool(nivel)
                for linha in ler(caminho + "/pp_dpm_mclk").splitlines():
                    if linha.strip().endswith("*"):
                        m = re.search(r"(\d+)\s*[Mm][Hh]z", linha)
                        if m:
                            extra["mhz_mem"] = int(m.group(1))
                hw = sorted(glob.glob(caminho + "/hwmon/hwmon*"))
                if hw:
                    h = hw[0]
                    for i in (1, 2, 3):
                        if ler(f"{h}/temp{i}_label").strip() == "junction":
                            extra["temp_junc"] = round(ler_int(f"{h}/temp{i}_input") / 1000)
                    micro = ler_int(h + "/power1_average") or ler_int(h + "/power1_input")
                    extra["watts"] = round(micro / 1e6, 1)
                    extra["watts_max"] = round(ler_int(h + "/power1_cap") / 1e6, 1)
                    extra["rpm"] = ler_int(h + "/fan1_input")
                    pwm = ler(h + "/pwm1").strip()
                    if pwm.isdigit():
                        extra["ventoinha"] = round(int(pwm) * 100 / 255)
            elif p["driver"] == "nvidia":
                extra.update(self.nvidia_extra(placa.get("indice", 0)))
            placa.update(extra)
        return placas

    def nvidia_extra(self, indice):
        if not shutil.which("nvidia-smi"):
            return {}
        try:
            r = subprocess.run(["nvidia-smi", "-i", str(indice), "--query-gpu=power.draw,power.limit,fan.speed,"
                                "clocks.mem", "--format=csv,noheader,nounits"],
                               capture_output=True, text=True, timeout=2)
        except (OSError, subprocess.SubprocessError):
            return {}
        campos = [c.strip() for c in r.stdout.strip().split(",")]
        if r.returncode != 0 or len(campos) < 4:
            return {}

        def num(texto):
            try:
                return float(texto)
            except ValueError:
                return 0.0
        return {"watts": round(num(campos[0]), 1), "watts_max": round(num(campos[1]), 1),
                "ventoinha": int(num(campos[2])) if campos[2] not in ("[N/A]", "N/A") else -1,
                "mhz_mem": int(num(campos[3]))}

    def servico_ativo(self):
        if time.monotonic() - self.servico[0] > 5:
            ativo = None
            if shutil.which("systemctl"):
                try:
                    r = subprocess.run(["systemctl", "--user", "is-active", "matsu-jogos.service"],
                                       capture_output=True, text=True, timeout=2)
                    ativo = r.stdout.strip() == "active"
                except (OSError, subprocess.SubprocessError):
                    ativo = None
            self.servico = (time.monotonic(), ativo)
        return self.servico[1]

    def perfil_energia(self):
        if time.monotonic() - self.energia[0] > 3:
            self.energia = (time.monotonic(), energia_atual())
        return self.energia[1]

    def amostra(self):
        temp_cpu = self.tarefas.dados_fixos().get("temp_cpu")
        estado = ler_json(arquivo_estado(), {}) or {}
        return {
            "idioma": self.tarefas.lingua,
            "vidro": T.vidro(),
            "cpu": {"uso": self.cpu(), "temp": round(ler_int(temp_cpu) / 1000) if temp_cpu else 0,
                    "nome": self.tarefas.dados_fixos()["cpu_nome"]},
            "memoria": self.memoria(),
            "placas": self.placas(),
            "jogo": estado.get("jogo"),
            "energia": self.perfil_energia(),
            "servico": self.servico_ativo(),
            "ajuste": self.ajuste,
            "atalho": ATALHO_FPS,
            "fps": self.fps_ligada(),
        }


def placa_demo():
    """Uma RX 6700 XT trabalhando, para as fotos da prévia (MATSU_JOGOS_DEMO=1)."""
    import math
    t = time.time()
    uso = round(62 + 25 * math.sin(t / 3.1) + 6 * math.sin(t * 1.7))
    return {"indice": 0, "nome": "AMD Radeon RX 6700 XT", "driver": "Mesa 26.0.4", "marca": "AMD", "fabricante": "amdgpu",
            "uso": max(0, min(100, uso)), "vram_usada": int((6.2 + math.sin(t / 7)) * 1024 ** 3), "vram_total": 12 * 1024 ** 3,
            "temp": round(64 + 6 * math.sin(t / 5)), "temp_junc": round(78 + 7 * math.sin(t / 5)),
            "mhz": round(2400 + 180 * math.sin(t / 2.3)), "mhz_mem": 1000, "watts": round(168 + 30 * math.sin(t / 3.1), 1),
            "watts_max": 230.0, "rpm": round(1450 + 200 * math.sin(t / 6)), "ventoinha": 42, "nivel": "auto",
            "nivel_mudavel": True}


def ajuste_avancado():
    """O app de ajuste fino da placa que veio no sistema (LACT ou CoreCtrl), com a logo dele."""
    for pasta in T.pastas_de_dados():
        apps = os.path.join(pasta, "applications")
        if not os.path.isdir(apps):
            continue
        for nome in sorted(os.listdir(apps)):
            baixo = nome.lower()
            if baixo.endswith(".desktop") and ("lact" in baixo or "corectrl" in baixo):
                dados = T.ler_desktop(os.path.join(apps, nome))
                if dados.get("Name") and dados.get("NoDisplay", "").lower() != "true":
                    return {"nome": dados["Name"], "icone": dados.get("Icon", ""),
                            "arquivo": os.path.join(apps, nome)}
    return None


# ----- energia, placa e GameMode -----
PPD = (("org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles"),
       ("net.hadess.PowerProfiles", "/net/hadess/PowerProfiles"))


def energia_atual():
    """O perfil de energia do sistema agora (power-saver, balanced, performance) ou vazio."""
    if not shutil.which("busctl"):
        return ""
    for nome, objeto in PPD:
        try:
            r = subprocess.run(["busctl", "--system", "get-property", nome, objeto, nome, "ActiveProfile"],
                               capture_output=True, text=True, timeout=2)
        except (OSError, subprocess.SubprocessError):
            return ""
        m = re.match(r's "([\w-]+)"', r.stdout.strip())
        if r.returncode == 0 and m:
            return m.group(1)
    return ""


def trocar_energia(perfil):
    if perfil not in ENERGIA_PPD.values() or not shutil.which("busctl"):
        return False
    for nome, objeto in PPD:
        try:
            r = subprocess.run(["busctl", "--system", "set-property", nome, objeto, nome, "ActiveProfile", "s", perfil],
                               capture_output=True, text=True, timeout=5)
        except (OSError, subprocess.SubprocessError):
            return False
        if r.returncode == 0:
            return True
    return False


def placas_amd():
    return [p for p in glob.glob(SYS + "/class/drm/card*/device/power_dpm_force_performance_level")
            if re.search(r"/card\d+/device/", p)
            and os.path.basename(os.path.realpath(os.path.join(os.path.dirname(p), "driver"))) == "amdgpu"]


def nivel_placa():
    """O nível da primeira placa AMD agora (auto, high, low, manual...) ou vazio."""
    for p in placas_amd():
        return ler(p).strip()
    return ""


def trocar_nivel_placa(nivel):
    """auto, high ou low nas placas AMD (precisa do ajudante de sistema, sem pedir senha)."""
    if nivel not in NIVEL_AMD.values() or not placas_amd():
        return False
    if all(ler(p).strip() == nivel for p in placas_amd()):
        return True
    raiz = os.environ.get("MATSU_JOGOS_RAIZ", "/usr/libexec/matsu/matsu-jogos-placa")
    comando = [raiz, nivel] if os.geteuid() == 0 or os.environ.get("MATSU_JOGOS_RAIZ") else ["pkexec", raiz, nivel]
    try:
        return subprocess.run(comando, capture_output=True, timeout=20).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def gamemode(metodo, pid):
    if not shutil.which("busctl"):
        return False
    try:
        r = subprocess.run(["busctl", "--user", "call", "com.feralinteractive.GameMode", "/com/feralinteractive/GameMode",
                            "com.feralinteractive.GameMode", metodo, "i", str(pid)],
                           capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return False
    return r.returncode == 0 and r.stdout.strip().endswith(" 0")


def avisar(titulo, texto):
    """Um aviso pequeno do sistema (o KDE não mostra em cima do jogo em tela cheia)."""
    if not shutil.which("gdbus"):
        return
    try:
        subprocess.run(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                        "--object-path", "/org/freedesktop/Notifications", "--method",
                        "org.freedesktop.Notifications.Notify", "Central de jogos", "0", "org.matsu.jogos",
                        titulo, texto, "[]", "{'desktop-entry': <'org.matsu.jogos'>, 'urgency': <byte 0>}", "4000"],
                       capture_output=True, timeout=3)
    except (OSError, subprocess.SubprocessError):
        pass


# ----- achar o jogo aberto -----
def processos():
    """{pid: (ppid, cmdline, rss em bytes)} dos processos desta pessoa."""
    lista = {}
    try:
        pids = [p for p in os.listdir(PROC) if p.isdigit()]
    except OSError:
        return lista
    for pid in pids:
        pasta = f"{PROC}/{pid}"
        try:
            if os.stat(pasta).st_uid != MEU_UID:
                continue
        except OSError:
            continue
        stat = ler(pasta + "/stat")
        fim = stat.rfind(")")
        if fim < 0:
            continue
        campos = stat[fim + 2:].split()
        try:
            ppid = int(campos[1])
            rss = int(campos[21]) * T.PAGINA
        except (IndexError, ValueError):
            continue
        cmd = ler(pasta + "/cmdline").split("\0")
        lista[int(pid)] = (ppid, [c for c in cmd if c], rss)
    return lista


def descendentes(lista, raiz):
    filhos = {}
    for pid, (ppid, _, _) in lista.items():
        filhos.setdefault(ppid, []).append(pid)
    vistos, fila = [], [raiz]
    while fila:
        atual = fila.pop()
        for f in filhos.get(atual, []):
            if f not in vistos:
                vistos.append(f)
                fila.append(f)
    return vistos


AJUDANTES_STEAM = re.compile(r"(^|/)(reaper|pressure-vessel[\w-]*|pv-[\w-]+|srt-bwrap|bwrap|steam-runtime[\w-]*|"
                             r"wineserver|python3?|sh|bash|steam-launch-wrapper|gamemoderun|mangohud|"
                             r"proton|_v2-entry-point|steam\.sh|steam|steamwebhelper|"
                             r"services\.exe|winedevice\.exe|plugplay\.exe|svchost\.exe|explorer\.exe|"
                             r"rpcss\.exe|tabtip\.exe|conhost\.exe|steam\.exe)$")


def principal_do_jogo(lista, raiz):
    """O processo que mais usa memória entre os filhos do lançador (o jogo de verdade)."""
    melhor, maior = raiz, -1
    for pid in descendentes(lista, raiz):
        _, cmd, rss = lista[pid]
        if not cmd:
            continue
        exe = cmd[0].replace("\\", "/")
        if AJUDANTES_STEAM.search(exe) and not exe.lower().endswith(".exe") or \
                os.path.basename(exe).lower() in WINE_NAO_JOGOS:
            continue
        if rss > maior:
            melhor, maior = pid, rss
    return melhor


def achar_jogo(lista=None, nomes=None):
    """O jogo aberto agora: {id, nome, pid, origem} ou None."""
    lista = processos() if lista is None else lista
    # Steam: o lançador dela ("reaper SteamLaunch AppId=123 -- ...") fica de pai do jogo.
    for pid, (_, cmd, _) in sorted(lista.items()):
        if "SteamLaunch" in cmd[:4] or (cmd and os.path.basename(cmd[0]) == "reaper" and "SteamLaunch" in cmd):
            appid = ""
            for parte in cmd:
                m = re.fullmatch(r"AppId=(\d+)", parte)
                if m:
                    appid = m.group(1)
                    break
            if not appid or appid in FERRAMENTAS_IDS:
                continue
            nome = (nomes or {}).get(appid, "")
            return {"id": appid, "nome": nome or f"Steam {appid}", "pid": principal_do_jogo(lista, pid),
                    "lancador": pid, "origem": "steam"}
    # Jogos do Windows abertos fora da Steam (Heroic, Lutris, Bottles): o .exe que mais usa memória.
    melhor = None
    for pid, (_, cmd, rss) in lista.items():
        if not cmd or rss < 200 * 1048576:
            continue
        exe = ""
        for parte in cmd[:2]:
            if parte.lower().endswith(".exe"):
                exe = parte.replace("\\", "/")
                break
        nome_exe = os.path.basename(exe).lower()
        if not exe or nome_exe in WINE_NAO_JOGOS:
            continue
        if melhor is None or rss > melhor[1]:
            melhor = (pid, rss, os.path.basename(exe))
    if melhor:
        nome = re.sub(r"(?i)(-win64-shipping|-win32-shipping|_dx12|_dx11|x64|\.exe)$", "", melhor[2])
        return {"id": "exe:" + nome.lower(), "nome": nome, "pid": melhor[0], "lancador": melhor[0], "origem": "wine"}
    return None


# ----- o serviço: liga o modo jogo quando um jogo abre -----
class Servico:
    def __init__(self):
        self.c = carregar_config()
        self.c_mtime = self.mtime()
        self.nomes = {}
        self.nomes_quando = 0.0
        self.estado = ler_json(arquivo_estado(), {}) or {}
        self.registrados = set()

    @staticmethod
    def mtime():
        try:
            return os.path.getmtime(arquivo_config())
        except OSError:
            return 0.0

    def guardar(self):
        gravar(arquivo_estado(), json.dumps(self.estado, ensure_ascii=False) + "\n")

    def nomes_atualizados(self):
        if time.monotonic() - self.nomes_quando > 60 or not self.nomes:
            self.nomes = nomes_dos_jogos()
            self.nomes_quando = time.monotonic()
        return self.nomes

    def comecar(self, jogo):
        perfil = perfil_do_jogo(self.c, jogo["id"])
        ajustes = ajustes_do_perfil(self.c, perfil)
        antes = {}
        if ajustes["energia"] != "manter":
            agora = energia_atual()
            if agora and trocar_energia(ENERGIA_PPD[ajustes["energia"]]):
                antes["energia"] = agora
        if ajustes["placa"] != "auto":
            # Se o LACT ou o CoreCtrl estão no comando (nível "manual" ou de perfil),
            # a Central não mexe: o ajuste fino da pessoa vale mais.
            agora = nivel_placa()
            if agora in ("", "auto", "high", "low") and trocar_nivel_placa(NIVEL_AMD[ajustes["placa"]]):
                antes["placa"] = agora or "auto"
        jogo = dict(jogo, perfil=perfil, ajustes=ajustes, desde=int(time.time()))
        self.estado = {"jogo": jogo, "antes": antes}
        self.registrados = set()
        if ajustes["modo_jogo"]:
            self.registrar(jogo["pid"])
        self.guardar()
        escrever_mangohud(self.c, self.estado)
        escrever_dxvk(self.estado)
        if self.c["avisar"]:
            nomes = {"padrao": ("Padrão", "Default"), "desempenho": ("Desempenho", "Performance"),
                     "qualidade": ("Qualidade", "Quality"), "economia": ("Economia", "Power saving"),
                     "personalizado": ("Personalizado", "Custom")}
            pt = T.idioma() == "pt"
            n = nomes.get(perfil, nomes["padrao"])[0 if pt else 1]
            avisar(jogo["nome"], f"Modo jogo ligado · perfil {n}" if pt else f"Game mode on · {n} profile")

    def registrar(self, pid):
        if pid and pid not in self.registrados and gamemode("RegisterGame", pid):
            self.registrados.add(pid)

    def terminar(self):
        antes = self.estado.get("antes") or {}
        if antes.get("energia"):
            trocar_energia(antes["energia"])
        if antes.get("placa"):
            trocar_nivel_placa(antes["placa"] if antes["placa"] in NIVEL_AMD.values() else "auto")
        for pid in self.registrados:
            gamemode("UnregisterGame", pid)
        self.registrados = set()
        self.estado = {"jogo": None}
        self.guardar()
        escrever_mangohud(self.c, self.estado)
        escrever_dxvk(self.estado)

    def passo(self):
        if self.mtime() != self.c_mtime:
            self.c = carregar_config()
            self.c_mtime = self.mtime()
            escrever_mangohud(self.c, self.estado)
        lista = processos()
        jogo = achar_jogo(lista, self.nomes_atualizados()) if self.c["automatico"] else None
        atual = self.estado.get("jogo")
        if jogo and atual and jogo["id"] == atual["id"]:
            # O jogo de verdade às vezes só aparece depois do lançador: registra também.
            if atual["ajustes"]["modo_jogo"] and jogo["pid"] != atual["pid"]:
                atual["pid"] = jogo["pid"]
                self.registrar(jogo["pid"])
                self.guardar()
            return
        if atual:
            self.terminar()
        if jogo:
            self.comecar(jogo)

    def rodar(self):
        # Se o serviço caiu no meio de um jogo, desfaz o que tinha ligado.
        if self.estado.get("jogo"):
            self.terminar()
        else:
            self.estado = {"jogo": None}
            self.guardar()
            escrever_mangohud(self.c, self.estado)
            escrever_dxvk(self.estado)

        def sair(*_):
            if self.estado.get("jogo"):
                self.terminar()
            sys.exit(0)
        signal.signal(signal.SIGTERM, sair)
        signal.signal(signal.SIGINT, sair)
        while True:
            try:
                self.passo()
            except Exception as erro:  # o serviço não pode cair por causa de um processo estranho
                print(f"matsu-jogos: {erro!r}", file=sys.stderr, flush=True)
            time.sleep(1.5 if self.estado.get("jogo") is None else 3)


# ----- atualização do driver (vem com o sistema) -----
def atualizacao(agora=False):
    cache = os.path.join(cache_casa(), "matsu", "jogos-atualizacao.json")
    guardado = ler_json(cache)
    if guardado and not agora and time.time() - guardado.get("quando", 0) < 6 * 3600:
        return guardado
    r = {"quando": int(time.time()), "tem": None, "pronta": False, "imagem": "", "erro": ""}
    try:
        st = subprocess.run(["rpm-ostree", "status", "--json"], capture_output=True, text=True, timeout=20)
        dados = json.loads(st.stdout) if st.returncode == 0 else {}
    except (OSError, subprocess.SubprocessError, ValueError):
        dados = {}
    implantacoes = dados.get("deployments") or []
    atual = next((d for d in implantacoes if d.get("booted")), None)
    r["pronta"] = any(d.get("staged") for d in implantacoes)
    if not atual:
        r["erro"] = "sem-sistema"
    else:
        ref = re.sub(r"^ostree-[a-z-]+:(docker://)?", "", atual.get("container-image-reference", ""))
        r["imagem"] = ref
        digest = atual.get("container-image-reference-digest", "")
        if ref and digest and shutil.which("skopeo"):
            try:
                sk = subprocess.run(["skopeo", "inspect", "--no-tags", "docker://" + ref],
                                    capture_output=True, text=True, timeout=40)
                remoto = json.loads(sk.stdout).get("Digest", "") if sk.returncode == 0 else ""
            except (OSError, subprocess.SubprocessError, ValueError):
                remoto = ""
            if remoto:
                r["tem"] = remoto != digest
            else:
                r["erro"] = "sem-internet"
        else:
            r["erro"] = "sem-skopeo"
    try:
        gravar(cache, json.dumps(r) + "\n")
    except OSError:
        pass
    return r


# ----- trocar a imagem (com ou sem o driver da NVIDIA) -----
def trocar_imagem(qual=""):
    """Troca para a imagem que combina com a placa (o mesmo canal), mostrando o que o
    bootc escreve. Uma linha JSON por linha dele; no fim {"fim": código}.
    Com qual="outra", vai para a outra versão (com ou sem o driver da NVIDIA) mesmo
    que a placa não peça: é o caminho de volta."""
    def emitir(d):
        sys.stdout.write(json.dumps(d, ensure_ascii=False) + "\n")
        sys.stdout.flush()
    if os.environ.get("MATSU_DRIVERS_DEMO"):
        for linha in ("Conferindo a assinatura da imagem", "Baixando: 12 de 48 partes", "Baixando: 48 de 48 partes",
                      "Preparando o sistema novo"):
            emitir({"linha": linha})
            time.sleep(0.8)
        emitir({"fim": 0})
        return 0
    imagem = D.ler_imagem()
    troca = D.outra_imagem(imagem) if qual == "outra" else D.troca_de_imagem(D.placas(), imagem)
    comando = D.comando_troca(troca["alvo"]) if troca else None
    if not comando:
        emitir({"fim": 3, "erro": "nada"})
        return 3
    emitir({"alvo": troca["alvo"]})
    try:
        p = subprocess.Popen(comando, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,
                             env=dict(os.environ, LC_ALL="C"))
    except OSError as e:
        emitir({"fim": 127, "erro": str(e)})
        return 127
    for linha in p.stdout:
        linha = linha.strip()
        if linha:
            emitir({"linha": linha[-160:]})
    codigo = p.wait()
    # 126/127: o pkexec não deixou (senha errada ou cancelada).
    emitir({"fim": codigo, "erro": "" if codigo == 0 else ("cancelado" if codigo in (126, 127) else "falhou")})
    return codigo


# ----- a janela -----
def vigiar(intervalo):
    leitor = Leitor()
    pai = os.getppid()
    leitor.amostra()
    time.sleep(0.3)
    while True:
        try:
            sys.stdout.write(json.dumps(leitor.amostra(), ensure_ascii=False, separators=(",", ":")) + "\n")
            sys.stdout.flush()
        except BrokenPipeError:
            return 0
        if os.getppid() != pai:
            return 0
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
    if comando == "biblioteca":
        print(json.dumps(biblioteca(), ensure_ascii=False))
        return 0
    if comando == "config":
        print(json.dumps(carregar_config(), ensure_ascii=False))
        return 0
    if comando == "salvar" and len(resto) == 1:
        try:
            nova = json.loads(resto[0])
        except ValueError:
            return 2
        c = salvar_config(nova)
        escrever_mangohud(c)
        print(json.dumps(c, ensure_ascii=False))
        return 0
    if comando == "sobreposicao":
        escrever_mangohud()
        return 0
    if comando == "jogar" and len(resto) == 1 and resto[0].isdigit():
        return subprocess.call(["xdg-open", f"steam://rungameid/{resto[0]}"])
    if comando == "atualizacao":
        print(json.dumps(atualizacao(agora="--agora" in resto)))
        return 0
    if comando == "servico":
        Servico().rodar()
        return 0
    if comando == "fps":
        acao = next((a for a in resto if a in ("on", "off", "ligar", "desligar", "alternar")), "")
        print(json.dumps(fps(acao, "--avisar" in resto)))
        return 0
    pt = T.idioma() == "pt"
    if comando == "controles":
        print(json.dumps(C.listar(pt), ensure_ascii=False))
        return 0
    if comando == "controle" and len(resto) == 2:
        r = C.acao(resto[0], resto[1])
        print(json.dumps(r))
        return 0 if r["ok"] else 1
    if comando == "bluetooth-ligar":
        ok = True if C.demo() else C.ligar_bluetooth()
        print(json.dumps({"ok": ok}))
        return 0 if ok else 1
    if comando == "parear":
        tipo = resto[0] if resto else "outro"
        try:
            segundos = int(resto[1]) if len(resto) > 1 else 30
        except ValueError:
            segundos = 30
        return C.parear(tipo, segundos, pt)
    if comando == "testar" and resto:
        return C.testar(resto[0], resto[1] if len(resto) > 1 else "outro")
    if comando == "drivers":
        if os.environ.get("MATSU_DRIVERS_DEMO"):
            d = D.demo()
        else:
            cache = os.path.join(cache_casa(), "matsu", "jogos-drivers.json")
            d = D.tudo(T.nome_da_placa, "pt" if pt else "en", cache, agora="--agora" in resto)
        print(json.dumps(d, ensure_ascii=False))
        return 0
    if comando == "trocar-imagem":
        return trocar_imagem("outra" if "outra" in resto else "")
    print(__doc__)
    return 2


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    sys.exit(main(sys.argv[1:]))
