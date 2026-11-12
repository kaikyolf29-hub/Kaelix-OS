#!/usr/bin/python3
"""Relógio do Matsu: o ajudante (alarmes, systemd, fusos e o toque).

A janela (os arquivos .qml desta pasta) só desenha. Quem guarda os alarmes, grava
as unidades do systemd do usuário (para o alarme tocar com o app fechado e depois
de reiniciar o computador), calcula a hora de cada cidade e toca o alarme é este
script. Só usa a biblioteca padrão do Python e responde em JSON.

Uso:
  ajudante.py estado                      idioma, vidro, systemd, fuso local e os alarmes
  ajudante.py salvar-alarme '<json>'      cria ou muda um alarme (e o timer do systemd)
  ajudante.py ligar-alarme <id> sim|nao   liga ou desliga
  ajudante.py apagar-alarme <id>          apaga (devolve o alarme, para o Desfazer)
  ajudante.py sincronizar                 deixa as unidades do systemd iguais à lista
  ajudante.py cidades                     as cidades que dá para pôr, com o desvio agora
  ajudante.py fusos <fuso> [...]          desvio agora, a próxima mudança e o desvio depois
  ajudante.py temporizador <id> <fim> <nome>  agenda o fim (fim em segundos desde 1970)
  ajudante.py cancelar-temporizador <id>
  ajudante.py ouvir <som>                 toca o som uma vez (para escolher)
  ajudante.py tocar alarme <id> [--soneca]
  ajudante.py tocar temporizador <id> <nome>

O toque (quem o systemd chama) é o tocar.py, que só chama "tocar" daqui.
"""
import contextlib
import datetime as dt
import fcntl
import json
import os
import re
import secrets
import shutil
import signal
import subprocess
import sys
import threading
import time

try:
    import zoneinfo
except ImportError:  # Python sem zoneinfo: as cidades ficam sem hora
    zoneinfo = None

AQUI = os.path.dirname(os.path.abspath(__file__))
TOCAR = os.path.join(AQUI, "tocar.py")
PYTHON = "/usr/bin/python3" if os.path.exists("/usr/bin/python3") else (sys.executable or "python3")
APP_ID = "org.matsu.relogio"

# Dias como o Python conta (0 = segunda ... 6 = domingo) e os nomes do systemd.
DIAS_SYSTEMD = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
SONECAS = (0, 5, 10, 15)
LIMITE_TOQUE = 300  # o alarme toca no máximo 5 minutos

# Sons: um nome do tema de sons (freedesktop) para cada escolha, e onde procurar.
SONS = {
    "alarme": ["alarm-clock-elapsed", "phone-incoming-call", "bell"],
    "sino": ["bell", "complete", "alarm-clock-elapsed"],
    "campainha": ["phone-incoming-call", "alarm-clock-elapsed", "bell"],
    "suave": ["message-new-instant", "complete", "message", "bell"],
}
TEMAS_SOM = ["freedesktop", "ocean", "oxygen"]
PASTAS_SOM = ["/usr/share/sounds", "/usr/local/share/sounds"]
# Sons antigos do Oxygen, para quando os do tema freedesktop faltarem.
OXYGEN = {
    "alarm-clock-elapsed": "Oxygen-Im-Phone-Ring.ogg",
    "phone-incoming-call": "Oxygen-Im-Phone-Ring.ogg",
    "bell": "Oxygen-Sys-App-Message.ogg",
    "complete": "Oxygen-Sys-App-Positive.ogg",
    "message-new-instant": "Oxygen-Im-Message-In.ogg",
    "message": "Oxygen-Im-Message-In.ogg",
}


# ----------------------------------------------------------------------------
# Pastas e o jeito da pessoa (idioma e vidro, como nos outros apps do Matsu)

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


def pasta_dados():
    """~/.local/share/matsu/relogio (a mesma pasta "dados" do matsu-janela)."""
    if os.environ.get("MATSU_RELOGIO_DADOS"):
        return os.environ["MATSU_RELOGIO_DADOS"]
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(casa(), ".local/share")
    return os.path.join(base, "matsu", "relogio")


def pasta_unidades():
    """~/.config/systemd/user, onde ficam os timers dos alarmes."""
    return os.environ.get("MATSU_SYSTEMD_USER") or os.path.join(config_casa(), "systemd", "user")


def arquivo_alarmes():
    return os.path.join(pasta_dados(), "alarmes.json")


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
    return "pt" if (lingua or "pt").startswith("pt") else "en"


def t(pt, en):
    return pt if idioma() == "pt" else en


# ----------------------------------------------------------------------------
# Os alarmes: a lista em alarmes.json

def novo_id():
    return secrets.token_hex(4)


def limpar_nome(texto):
    texto = re.sub(r"[\x00-\x1f\x7f]", " ", str(texto or ""))
    return re.sub(r"\s+", " ", texto).strip()[:60]


def data_valida(texto):
    try:
        return dt.date.fromisoformat(str(texto)).isoformat()
    except (TypeError, ValueError):
        return ""


def normalizar(a):
    """Um alarme com todos os campos certos. Erra (ValueError) se a hora não for número."""
    if not isinstance(a, dict):
        raise ValueError("alarme precisa ser um objeto")
    ident = str(a.get("id") or novo_id()).lower()
    if not re.fullmatch(r"[a-z0-9]{1,32}", ident):
        raise ValueError("id inválido")
    hora = max(0, min(23, int(a.get("hora", 7))))
    minuto = max(0, min(59, int(a.get("minuto", 0))))
    dias = set()
    for d in a.get("dias") or []:
        try:
            d = int(d)
        except (TypeError, ValueError):
            continue
        if 0 <= d <= 6:
            dias.add(d)
    som = a.get("som") if a.get("som") in SONS else "alarme"
    try:
        soneca = int(a.get("soneca", 10))
    except (TypeError, ValueError):
        soneca = 10
    return {
        "id": ident,
        "nome": limpar_nome(a.get("nome")),
        "hora": hora,
        "minuto": minuto,
        "dias": sorted(dias),
        "ligado": bool(a.get("ligado", True)),
        "som": som,
        "soneca": soneca if soneca in SONECAS else 10,
        "data": data_valida(a.get("data")) if not dias else "",
    }


def ler_alarmes():
    texto = ler(arquivo_alarmes())
    if not texto.strip():
        return []
    try:
        dados = json.loads(texto)
    except ValueError:
        # Arquivo estragado: guarda uma cópia para não perder de vez e começa de novo.
        with contextlib.suppress(OSError):
            os.replace(arquivo_alarmes(), arquivo_alarmes() + ".estragado")
        return []
    lista = dados.get("alarmes", []) if isinstance(dados, dict) else dados
    saida, vistos = [], set()
    for a in lista if isinstance(lista, list) else []:
        try:
            n = normalizar(a)
        except (ValueError, TypeError):
            continue
        if n["id"] not in vistos:
            vistos.add(n["id"])
            saida.append(n)
    return saida


def gravar_texto(caminho, texto):
    """Grava sem deixar o arquivo pela metade (um temporário e depois a troca)."""
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    tmp = f"{caminho}.{os.getpid()}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(texto)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, caminho)


def ordenar(lista):
    return sorted(lista, key=lambda a: (a["hora"], a["minuto"], a["nome"].lower(), a["id"]))


def gravar_alarmes(lista):
    texto = json.dumps({"versao": 1, "alarmes": ordenar(lista)}, ensure_ascii=False, indent=2) + "\n"
    gravar_texto(arquivo_alarmes(), texto)


@contextlib.contextmanager
def trava():
    """Só um por vez mexe na lista (o app e o toque podem querer ao mesmo tempo)."""
    os.makedirs(pasta_dados(), exist_ok=True)
    with open(os.path.join(pasta_dados(), ".trava"), "w") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


# ----------------------------------------------------------------------------
# Quando toca

def proxima_data(hora, minuto, agora):
    """O dia em que hora:minuto chega primeiro (hoje, se ainda não passou)."""
    alvo = agora.replace(hour=hora, minute=minuto, second=0, microsecond=0)
    if alvo <= agora:
        alvo += dt.timedelta(days=1)
    return alvo.date().isoformat()


def proximo_toque(a, agora):
    """O próximo toque (datetime local, sem fuso), ou None se não vai tocar."""
    if not a["ligado"]:
        return None
    hm = dt.time(a["hora"], a["minuto"])
    if not a["dias"]:
        if a.get("data"):
            alvo = dt.datetime.combine(dt.date.fromisoformat(a["data"]), hm)
            return alvo if alvo > agora else None
        return dt.datetime.combine(dt.date.fromisoformat(proxima_data(a["hora"], a["minuto"], agora)), hm)
    for k in range(8):
        dia = agora.date() + dt.timedelta(days=k)
        if dia.weekday() in a["dias"]:
            alvo = dt.datetime.combine(dia, hm)
            if alvo > agora:
                return alvo
    return None


def oncalendar(a):
    """A linha OnCalendar= do timer do alarme."""
    hm = f"{a['hora']:02d}:{a['minuto']:02d}:00"
    if not a["dias"]:
        return f"{a['data']} {hm}"
    if len(a["dias"]) == 7:
        return f"*-*-* {hm}"
    return ",".join(DIAS_SYSTEMD[d] for d in a["dias"]) + f" *-*-* {hm}"


# ----------------------------------------------------------------------------
# As unidades do systemd do usuário

def nome_unidade(ident, tipo):
    return f"matsu-alarme-{ident}.{tipo}"


def descricao(a):
    nome = a["nome"] or t("Alarme", "Alarm")
    # "%" é especial nos arquivos do systemd.
    return f"{t('Relógio do Matsu', 'Matsu Clock')}: {a['hora']:02d}:{a['minuto']:02d} {nome}".replace("%", "%%")


def citar(arg):
    """Um argumento de ExecStart= (com aspas se tiver espaço)."""
    arg = arg.replace("%", "%%")
    if re.search(r"[\s\"'\\;]", arg):
        return '"' + arg.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return arg


def texto_timer(a):
    return (
        "# Alarme do Relógio do Matsu (org.matsu.relogio). O app regrava este arquivo:\n"
        "# mude o alarme pelo Relógio.\n"
        "[Unit]\n"
        f"Description={descricao(a)}\n"
        "\n"
        "[Timer]\n"
        f"OnCalendar={oncalendar(a)}\n"
        "Persistent=false\n"
        "AccuracySec=1s\n"
        f"Unit={nome_unidade(a['id'], 'service')}\n"
        "\n"
        "[Install]\n"
        "WantedBy=timers.target\n"
    )


def texto_servico(a):
    comando = " ".join(citar(x) for x in (PYTHON, "-I", "-S", TOCAR, "alarme", a["id"]))
    return (
        "# Alarme do Relógio do Matsu (org.matsu.relogio): mostra o aviso e toca o som.\n"
        "[Unit]\n"
        f"Description={descricao(a)}\n"
        "\n"
        "[Service]\n"
        "Type=simple\n"
        f"ExecStart={comando}\n"
        "TimeoutStopSec=5\n"
    )


_SYSTEMD = None


def systemd_ok():
    """Se o systemd do usuário responde (na prévia em contêiner, não responde)."""
    global _SYSTEMD
    forcado = os.environ.get("MATSU_RELOGIO_SYSTEMD")
    if forcado in ("sim", "nao"):
        return forcado == "sim"
    if _SYSTEMD is None:
        _SYSTEMD = False
        if shutil.which("systemctl"):
            try:
                r = subprocess.run(["systemctl", "--user", "show-environment"], stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL, timeout=5)
                _SYSTEMD = r.returncode == 0
            except (OSError, subprocess.SubprocessError):
                _SYSTEMD = False
    return _SYSTEMD


def systemctl(*args):
    """Roda systemctl --user; devolve (deu certo, mensagem de erro)."""
    try:
        r = subprocess.run(["systemctl", "--user", *args], capture_output=True, text=True, timeout=20)
        return r.returncode == 0, r.stderr.strip()
    except (OSError, subprocess.SubprocessError) as e:
        return False, str(e)


def rodar(comando, espera=20):
    try:
        r = subprocess.run(comando, capture_output=True, text=True, timeout=espera)
        return r.returncode == 0, (r.stdout or "").strip(), (r.stderr or "").strip()
    except (OSError, subprocess.SubprocessError) as e:
        return False, "", str(e)


def escrever_se_mudou(caminho, texto):
    if ler(caminho, None) == texto:
        return False
    gravar_texto(caminho, texto)
    return True


def sincronizar(lista, agora=None):
    """Deixa ~/.config/systemd/user igual à lista: um .timer e um .service por alarme
    ligado (habilitado em timers.target, para valer depois de reiniciar); nada para os
    desligados. Devolve {"systemd": bool, "erros": [...]}."""
    agora = agora or dt.datetime.now()
    pasta = pasta_unidades()
    querer = pasta_querer()
    com_systemd = systemd_ok()
    erros = []
    ligar, mudados, desligar, remover = [], [], [], []
    ids = set()
    for a in lista:
        ids.add(a["id"])
        caminho_t = os.path.join(pasta, nome_unidade(a["id"], "timer"))
        caminho_s = os.path.join(pasta, nome_unidade(a["id"], "service"))
        if proximo_toque(a, agora) is not None:
            mudou = escrever_se_mudou(caminho_s, texto_servico(a))
            mudou = escrever_se_mudou(caminho_t, texto_timer(a)) or mudou
            ligar.append(nome_unidade(a["id"], "timer"))
            if mudou:
                mudados.append(nome_unidade(a["id"], "timer"))
        elif os.path.exists(caminho_t) or os.path.exists(caminho_s):
            desligar.append(nome_unidade(a["id"], "timer"))
            remover.append(a["id"])
    # Unidades de alarmes que não existem mais.
    if os.path.isdir(pasta):
        for arq in sorted(os.listdir(pasta)):
            m = re.fullmatch(r"matsu-alarme-([a-z0-9]+)\.(timer|service)", arq)
            if m and m.group(1) not in ids and m.group(1) not in remover:
                desligar.append(nome_unidade(m.group(1), "timer"))
                remover.append(m.group(1))
    if com_systemd and desligar:
        ok, erro = systemctl("disable", "--now", *desligar)
        if not ok and erro:
            erros.append(erro)
    for ident in remover:
        for tipo in ("timer", "service"):
            with contextlib.suppress(FileNotFoundError):
                os.remove(os.path.join(pasta, nome_unidade(ident, tipo)))
        with contextlib.suppress(FileNotFoundError):
            os.remove(os.path.join(querer, nome_unidade(ident, "timer")))
    if com_systemd:
        if mudados or remover:
            ok, erro = systemctl("daemon-reload")
            if not ok:
                erros.append(erro)
        if ligar:
            ok, erro = systemctl("enable", "--now", *ligar)
            if not ok:
                erros.append(erro)
        # Timer que já estava ligado e mudou de hora: reinicia para valer a hora nova.
        if mudados:
            ok, erro = systemctl("restart", *mudados)
            if not ok:
                erros.append(erro)
    else:
        # Sem o systemd agora (sessão sem ele): deixa habilitado do mesmo jeito que o
        # "systemctl enable" faria, e na próxima entrada o timer já vale.
        for nome in ligar:
            link = os.path.join(querer, nome)
            if not os.path.islink(link):
                os.makedirs(querer, exist_ok=True)
                with contextlib.suppress(FileExistsError):
                    os.symlink(os.path.join(pasta, nome), link)
    return {"systemd": com_systemd, "erros": [e for e in erros if e]}


def pasta_querer():
    return os.path.join(pasta_unidades(), "timers.target.wants")


def parar_toque(ident):
    """Para o toque e as sonecas pendentes de um alarme (ao apagar ou desligar)."""
    if systemd_ok():
        systemctl("stop", nome_unidade(ident, "service"), f"matsu-soneca-{ident}-*.timer",
                  f"matsu-soneca-{ident}-*.service")


# ----------------------------------------------------------------------------
# Fusos e cidades

# (id, nome, nome em inglês, país, país em inglês, fuso)
CIDADES = [
    ("sao-paulo", "São Paulo", "São Paulo", "Brasil", "Brazil", "America/Sao_Paulo"),
    ("rio-de-janeiro", "Rio de Janeiro", "Rio de Janeiro", "Brasil", "Brazil", "America/Sao_Paulo"),
    ("brasilia", "Brasília", "Brasília", "Brasil", "Brazil", "America/Sao_Paulo"),
    ("belo-horizonte", "Belo Horizonte", "Belo Horizonte", "Brasil", "Brazil", "America/Sao_Paulo"),
    ("curitiba", "Curitiba", "Curitiba", "Brasil", "Brazil", "America/Sao_Paulo"),
    ("porto-alegre", "Porto Alegre", "Porto Alegre", "Brasil", "Brazil", "America/Sao_Paulo"),
    ("florianopolis", "Florianópolis", "Florianópolis", "Brasil", "Brazil", "America/Sao_Paulo"),
    ("goiania", "Goiânia", "Goiânia", "Brasil", "Brazil", "America/Sao_Paulo"),
    ("vitoria", "Vitória", "Vitória", "Brasil", "Brazil", "America/Sao_Paulo"),
    ("salvador", "Salvador", "Salvador", "Brasil", "Brazil", "America/Bahia"),
    ("recife", "Recife", "Recife", "Brasil", "Brazil", "America/Recife"),
    ("fortaleza", "Fortaleza", "Fortaleza", "Brasil", "Brazil", "America/Fortaleza"),
    ("natal", "Natal", "Natal", "Brasil", "Brazil", "America/Fortaleza"),
    ("joao-pessoa", "João Pessoa", "João Pessoa", "Brasil", "Brazil", "America/Fortaleza"),
    ("maceio", "Maceió", "Maceió", "Brasil", "Brazil", "America/Maceio"),
    ("aracaju", "Aracaju", "Aracaju", "Brasil", "Brazil", "America/Maceio"),
    ("teresina", "Teresina", "Teresina", "Brasil", "Brazil", "America/Fortaleza"),
    ("sao-luis", "São Luís", "São Luís", "Brasil", "Brazil", "America/Fortaleza"),
    ("belem", "Belém", "Belém", "Brasil", "Brazil", "America/Belem"),
    ("macapa", "Macapá", "Macapá", "Brasil", "Brazil", "America/Belem"),
    ("palmas", "Palmas", "Palmas", "Brasil", "Brazil", "America/Araguaina"),
    ("manaus", "Manaus", "Manaus", "Brasil", "Brazil", "America/Manaus"),
    ("boa-vista", "Boa Vista", "Boa Vista", "Brasil", "Brazil", "America/Boa_Vista"),
    ("porto-velho", "Porto Velho", "Porto Velho", "Brasil", "Brazil", "America/Porto_Velho"),
    ("cuiaba", "Cuiabá", "Cuiabá", "Brasil", "Brazil", "America/Cuiaba"),
    ("campo-grande", "Campo Grande", "Campo Grande", "Brasil", "Brazil", "America/Campo_Grande"),
    ("rio-branco", "Rio Branco", "Rio Branco", "Brasil", "Brazil", "America/Rio_Branco"),
    ("noronha", "Fernando de Noronha", "Fernando de Noronha", "Brasil", "Brazil", "America/Noronha"),
    ("lisboa", "Lisboa", "Lisbon", "Portugal", "Portugal", "Europe/Lisbon"),
    ("porto", "Porto", "Porto", "Portugal", "Portugal", "Europe/Lisbon"),
    ("funchal", "Funchal", "Funchal", "Portugal (Madeira)", "Portugal (Madeira)", "Atlantic/Madeira"),
    ("ponta-delgada", "Ponta Delgada", "Ponta Delgada", "Portugal (Açores)", "Portugal (Azores)", "Atlantic/Azores"),
    ("luanda", "Luanda", "Luanda", "Angola", "Angola", "Africa/Luanda"),
    ("maputo", "Maputo", "Maputo", "Moçambique", "Mozambique", "Africa/Maputo"),
    ("praia", "Praia", "Praia", "Cabo Verde", "Cape Verde", "Atlantic/Cape_Verde"),
    ("bissau", "Bissau", "Bissau", "Guiné-Bissau", "Guinea-Bissau", "Africa/Bissau"),
    ("sao-tome", "São Tomé", "São Tomé", "São Tomé e Príncipe", "São Tomé and Príncipe", "Africa/Sao_Tome"),
    ("dili", "Díli", "Dili", "Timor-Leste", "Timor-Leste", "Asia/Dili"),
    ("macau", "Macau", "Macau", "China", "China", "Asia/Macau"),
    ("nova-york", "Nova York", "New York", "Estados Unidos", "United States", "America/New_York"),
    ("washington", "Washington", "Washington", "Estados Unidos", "United States", "America/New_York"),
    ("miami", "Miami", "Miami", "Estados Unidos", "United States", "America/New_York"),
    ("orlando", "Orlando", "Orlando", "Estados Unidos", "United States", "America/New_York"),
    ("boston", "Boston", "Boston", "Estados Unidos", "United States", "America/New_York"),
    ("chicago", "Chicago", "Chicago", "Estados Unidos", "United States", "America/Chicago"),
    ("houston", "Houston", "Houston", "Estados Unidos", "United States", "America/Chicago"),
    ("denver", "Denver", "Denver", "Estados Unidos", "United States", "America/Denver"),
    ("los-angeles", "Los Angeles", "Los Angeles", "Estados Unidos", "United States", "America/Los_Angeles"),
    ("sao-francisco", "São Francisco", "San Francisco", "Estados Unidos", "United States", "America/Los_Angeles"),
    ("las-vegas", "Las Vegas", "Las Vegas", "Estados Unidos", "United States", "America/Los_Angeles"),
    ("seattle", "Seattle", "Seattle", "Estados Unidos", "United States", "America/Los_Angeles"),
    ("anchorage", "Anchorage", "Anchorage", "Estados Unidos (Alasca)", "United States (Alaska)", "America/Anchorage"),
    ("honolulu", "Honolulu", "Honolulu", "Estados Unidos (Havaí)", "United States (Hawaii)", "Pacific/Honolulu"),
    ("toronto", "Toronto", "Toronto", "Canadá", "Canada", "America/Toronto"),
    ("montreal", "Montreal", "Montreal", "Canadá", "Canada", "America/Toronto"),
    ("vancouver", "Vancouver", "Vancouver", "Canadá", "Canada", "America/Vancouver"),
    ("cidade-do-mexico", "Cidade do México", "Mexico City", "México", "Mexico", "America/Mexico_City"),
    ("cancun", "Cancún", "Cancún", "México", "Mexico", "America/Cancun"),
    ("havana", "Havana", "Havana", "Cuba", "Cuba", "America/Havana"),
    ("panama", "Cidade do Panamá", "Panama City", "Panamá", "Panama", "America/Panama"),
    ("bogota", "Bogotá", "Bogotá", "Colômbia", "Colombia", "America/Bogota"),
    ("caracas", "Caracas", "Caracas", "Venezuela", "Venezuela", "America/Caracas"),
    ("quito", "Quito", "Quito", "Equador", "Ecuador", "America/Guayaquil"),
    ("lima", "Lima", "Lima", "Peru", "Peru", "America/Lima"),
    ("la-paz", "La Paz", "La Paz", "Bolívia", "Bolivia", "America/La_Paz"),
    ("santiago", "Santiago", "Santiago", "Chile", "Chile", "America/Santiago"),
    ("buenos-aires", "Buenos Aires", "Buenos Aires", "Argentina", "Argentina", "America/Argentina/Buenos_Aires"),
    ("montevideu", "Montevidéu", "Montevideo", "Uruguai", "Uruguay", "America/Montevideo"),
    ("assuncao", "Assunção", "Asunción", "Paraguai", "Paraguay", "America/Asuncion"),
    ("londres", "Londres", "London", "Reino Unido", "United Kingdom", "Europe/London"),
    ("dublin", "Dublin", "Dublin", "Irlanda", "Ireland", "Europe/Dublin"),
    ("reykjavik", "Reykjavík", "Reykjavík", "Islândia", "Iceland", "Atlantic/Reykjavik"),
    ("paris", "Paris", "Paris", "França", "France", "Europe/Paris"),
    ("madri", "Madri", "Madrid", "Espanha", "Spain", "Europe/Madrid"),
    ("barcelona", "Barcelona", "Barcelona", "Espanha", "Spain", "Europe/Madrid"),
    ("roma", "Roma", "Rome", "Itália", "Italy", "Europe/Rome"),
    ("milao", "Milão", "Milan", "Itália", "Italy", "Europe/Rome"),
    ("berlim", "Berlim", "Berlin", "Alemanha", "Germany", "Europe/Berlin"),
    ("munique", "Munique", "Munich", "Alemanha", "Germany", "Europe/Berlin"),
    ("amsterda", "Amsterdã", "Amsterdam", "Países Baixos", "Netherlands", "Europe/Amsterdam"),
    ("bruxelas", "Bruxelas", "Brussels", "Bélgica", "Belgium", "Europe/Brussels"),
    ("zurique", "Zurique", "Zurich", "Suíça", "Switzerland", "Europe/Zurich"),
    ("viena", "Viena", "Vienna", "Áustria", "Austria", "Europe/Vienna"),
    ("praga", "Praga", "Prague", "Tchéquia", "Czechia", "Europe/Prague"),
    ("varsovia", "Varsóvia", "Warsaw", "Polônia", "Poland", "Europe/Warsaw"),
    ("copenhague", "Copenhague", "Copenhagen", "Dinamarca", "Denmark", "Europe/Copenhagen"),
    ("estocolmo", "Estocolmo", "Stockholm", "Suécia", "Sweden", "Europe/Stockholm"),
    ("oslo", "Oslo", "Oslo", "Noruega", "Norway", "Europe/Oslo"),
    ("helsinque", "Helsinque", "Helsinki", "Finlândia", "Finland", "Europe/Helsinki"),
    ("atenas", "Atenas", "Athens", "Grécia", "Greece", "Europe/Athens"),
    ("istambul", "Istambul", "Istanbul", "Turquia", "Turkey", "Europe/Istanbul"),
    ("kiev", "Kiev", "Kyiv", "Ucrânia", "Ukraine", "Europe/Kyiv"),
    ("moscou", "Moscou", "Moscow", "Rússia", "Russia", "Europe/Moscow"),
    ("cairo", "Cairo", "Cairo", "Egito", "Egypt", "Africa/Cairo"),
    ("casablanca", "Casablanca", "Casablanca", "Marrocos", "Morocco", "Africa/Casablanca"),
    ("lagos", "Lagos", "Lagos", "Nigéria", "Nigeria", "Africa/Lagos"),
    ("nairobi", "Nairóbi", "Nairobi", "Quênia", "Kenya", "Africa/Nairobi"),
    ("joanesburgo", "Joanesburgo", "Johannesburg", "África do Sul", "South Africa", "Africa/Johannesburg"),
    ("cidade-do-cabo", "Cidade do Cabo", "Cape Town", "África do Sul", "South Africa", "Africa/Johannesburg"),
    ("jerusalem", "Jerusalém", "Jerusalem", "Israel", "Israel", "Asia/Jerusalem"),
    ("tel-aviv", "Tel Aviv", "Tel Aviv", "Israel", "Israel", "Asia/Jerusalem"),
    ("dubai", "Dubai", "Dubai", "Emirados Árabes Unidos", "United Arab Emirates", "Asia/Dubai"),
    ("doha", "Doha", "Doha", "Catar", "Qatar", "Asia/Qatar"),
    ("riad", "Riad", "Riyadh", "Arábia Saudita", "Saudi Arabia", "Asia/Riyadh"),
    ("teera", "Teerã", "Tehran", "Irã", "Iran", "Asia/Tehran"),
    ("carachi", "Carachi", "Karachi", "Paquistão", "Pakistan", "Asia/Karachi"),
    ("nova-delhi", "Nova Délhi", "New Delhi", "Índia", "India", "Asia/Kolkata"),
    ("mumbai", "Mumbai", "Mumbai", "Índia", "India", "Asia/Kolkata"),
    ("catmandu", "Catmandu", "Kathmandu", "Nepal", "Nepal", "Asia/Kathmandu"),
    ("daca", "Daca", "Dhaka", "Bangladesh", "Bangladesh", "Asia/Dhaka"),
    ("bangkok", "Bangkok", "Bangkok", "Tailândia", "Thailand", "Asia/Bangkok"),
    ("hanoi", "Hanói", "Hanoi", "Vietnã", "Vietnam", "Asia/Bangkok"),
    ("jacarta", "Jacarta", "Jakarta", "Indonésia", "Indonesia", "Asia/Jakarta"),
    ("bali", "Bali", "Bali", "Indonésia", "Indonesia", "Asia/Makassar"),
    ("singapura", "Singapura", "Singapore", "Singapura", "Singapore", "Asia/Singapore"),
    ("kuala-lumpur", "Kuala Lumpur", "Kuala Lumpur", "Malásia", "Malaysia", "Asia/Kuala_Lumpur"),
    ("manila", "Manila", "Manila", "Filipinas", "Philippines", "Asia/Manila"),
    ("hong-kong", "Hong Kong", "Hong Kong", "China", "China", "Asia/Hong_Kong"),
    ("pequim", "Pequim", "Beijing", "China", "China", "Asia/Shanghai"),
    ("xangai", "Xangai", "Shanghai", "China", "China", "Asia/Shanghai"),
    ("taipe", "Taipé", "Taipei", "Taiwan", "Taiwan", "Asia/Taipei"),
    ("seul", "Seul", "Seoul", "Coreia do Sul", "South Korea", "Asia/Seoul"),
    ("toquio", "Tóquio", "Tokyo", "Japão", "Japan", "Asia/Tokyo"),
    ("osaka", "Osaka", "Osaka", "Japão", "Japan", "Asia/Tokyo"),
    ("sydney", "Sydney", "Sydney", "Austrália", "Australia", "Australia/Sydney"),
    ("melbourne", "Melbourne", "Melbourne", "Austrália", "Australia", "Australia/Melbourne"),
    ("brisbane", "Brisbane", "Brisbane", "Austrália", "Australia", "Australia/Brisbane"),
    ("adelaide", "Adelaide", "Adelaide", "Austrália", "Australia", "Australia/Adelaide"),
    ("perth", "Perth", "Perth", "Austrália", "Australia", "Australia/Perth"),
    ("auckland", "Auckland", "Auckland", "Nova Zelândia", "New Zealand", "Pacific/Auckland"),
    ("fiji", "Suva", "Suva", "Fiji", "Fiji", "Pacific/Fiji"),
]

# Nomes que a pessoa conhece para os fusos do Brasil (o resto usa o nome da cidade).
FUSOS_BR = {
    "America/Sao_Paulo": ("Horário de Brasília", "Brasília time"),
    "America/Bahia": ("Horário de Brasília", "Brasília time"),
    "America/Recife": ("Horário de Brasília", "Brasília time"),
    "America/Fortaleza": ("Horário de Brasília", "Brasília time"),
    "America/Maceio": ("Horário de Brasília", "Brasília time"),
    "America/Belem": ("Horário de Brasília", "Brasília time"),
    "America/Araguaina": ("Horário de Brasília", "Brasília time"),
    "America/Santarem": ("Horário de Brasília", "Brasília time"),
    "America/Manaus": ("Horário do Amazonas", "Amazon time"),
    "America/Boa_Vista": ("Horário do Amazonas", "Amazon time"),
    "America/Porto_Velho": ("Horário do Amazonas", "Amazon time"),
    "America/Cuiaba": ("Horário do Amazonas", "Amazon time"),
    "America/Campo_Grande": ("Horário do Amazonas", "Amazon time"),
    "America/Rio_Branco": ("Horário do Acre", "Acre time"),
    "America/Eirunepe": ("Horário do Acre", "Acre time"),
    "America/Noronha": ("Horário de Fernando de Noronha", "Fernando de Noronha time"),
}
FUSO_PADRAO = "America/Sao_Paulo"


def fuso_valido(nome):
    if not nome or zoneinfo is None or not re.fullmatch(r"[A-Za-z0-9_+\-]+(/[A-Za-z0-9_+\-]+)*", nome):
        return False
    try:
        zoneinfo.ZoneInfo(nome)
        return True
    except (zoneinfo.ZoneInfoNotFoundError, ValueError, OSError):
        return False


def fuso_local():
    """O fuso do computador (TZ, /etc/localtime ou o timedatectl). Sem nada: Brasília."""
    tz = os.environ.get("TZ", "").lstrip(":")
    if tz.startswith("/"):
        tz = tz.split("zoneinfo/", 1)[1] if "zoneinfo/" in tz else ""
    if fuso_valido(tz):
        return tz
    alvo = ""
    with contextlib.suppress(OSError):
        alvo = os.path.realpath(os.environ.get("MATSU_LOCALTIME", "/etc/localtime"))
    if "zoneinfo/" in alvo:
        nome = alvo.split("zoneinfo/", 1)[1]
        for prefixo in ("posix/", "right/"):
            if nome.startswith(prefixo):
                nome = nome[len(prefixo):]
        if fuso_valido(nome):
            return nome
    nome = ler("/etc/timezone").strip()
    if fuso_valido(nome):
        return nome
    if shutil.which("timedatectl") and not os.environ.get("MATSU_LOCALTIME"):
        ok, saida, _ = rodar(["timedatectl", "show", "-p", "Timezone", "--value"], espera=3)
        if ok and fuso_valido(saida):
            return saida
    return FUSO_PADRAO


def nome_fuso(tz):
    if tz in FUSOS_BR:
        return FUSOS_BR[tz]
    for c in CIDADES:
        if c[5] == tz:
            return (c[1], c[2])
    nome = tz.rsplit("/", 1)[-1].replace("_", " ")
    return (nome, nome)


def desvio(tz, instante):
    """Segundos a leste de UTC no fuso tz, no instante (segundos desde 1970)."""
    if zoneinfo is None:
        return 0
    quando = dt.datetime.fromtimestamp(instante, zoneinfo.ZoneInfo(tz))
    return int(quando.utcoffset().total_seconds())


def proxima_mudanca(tz, instante, dias=400):
    """(instante da próxima troca de desvio, desvio depois) ou (0, desvio agora) se não muda."""
    agora = desvio(tz, instante)
    passo = 86400
    anterior = instante
    for k in range(1, dias + 1):
        t2 = instante + k * passo
        if desvio(tz, t2) != agora:
            # Acha o minuto da troca, dividindo o dia ao meio.
            baixo, alto = anterior, t2
            while alto - baixo > 1:
                meio = (baixo + alto) // 2
                if desvio(tz, meio) == agora:
                    baixo = meio
                else:
                    alto = meio
            return int(alto), desvio(tz, alto)
        anterior = t2
    return 0, agora


def info_fuso(tz, instante):
    ate, depois = proxima_mudanca(tz, instante)
    return {"fuso": tz, "desvio": desvio(tz, instante), "ate": ate, "depois": depois}


def catalogo(instante=None):
    instante = instante or time.time()
    lingua = idioma()
    saida = []
    cache = {}
    for ident, nome, nome_en, pais, pais_en, tz in CIDADES:
        if not fuso_valido(tz):
            continue
        if tz not in cache:
            cache[tz] = desvio(tz, instante)
        saida.append({"id": ident, "nome": nome if lingua == "pt" else nome_en, "pais": pais if lingua == "pt" else pais_en,
                      "fuso": tz, "desvio": cache[tz]})
    return saida


# ----------------------------------------------------------------------------
# Temporizadores (o fim agendado no systemd, para tocar com o app fechado)

def agendar_temporizador(ident, fim, nome):
    if not re.fullmatch(r"[a-z0-9]{1,32}", ident):
        return {"ok": False, "erro": "id"}
    cancelar_temporizador(ident)
    if not systemd_ok() or not shutil.which("systemd-run"):
        return {"ok": False, "erro": "sem-systemd"}
    fim = max(float(fim), time.time() + 1)
    quando = dt.datetime.fromtimestamp(int(fim + 0.999), dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    nome = limpar_nome(nome) or t("Temporizador", "Timer")
    unidade = f"matsu-temporizador-{ident}-{int(time.time())}"
    ok, _, erro = rodar(["systemd-run", "--user", "--collect", "--quiet", f"--unit={unidade}",
                         f"--description={t('Relógio do Matsu', 'Matsu Clock')}: {nome}",
                         f"--on-calendar={quando}", "--timer-property=AccuracySec=1s",
                         PYTHON, "-I", "-S", TOCAR, "temporizador", ident, nome])
    return {"ok": ok, "erro": "" if ok else erro, "unidade": unidade}


def cancelar_temporizador(ident):
    if not re.fullmatch(r"[a-z0-9]{1,32}", ident):
        return {"ok": False}
    if systemd_ok():
        systemctl("stop", f"matsu-temporizador-{ident}-*.timer", f"matsu-temporizador-{ident}-*.service")
    return {"ok": True}


# ----------------------------------------------------------------------------
# O som

def achar_som(escolha):
    """O arquivo do som escolhido (o primeiro que existir), ou ""."""
    nomes = SONS.get(escolha, SONS["alarme"]) + SONS["alarme"]
    raizes = os.environ.get("MATSU_SONS", "").split(":") if os.environ.get("MATSU_SONS") else PASTAS_SOM
    for nome in nomes:
        for raiz in raizes:
            for tema in TEMAS_SOM:
                for ext in ("oga", "ogg", "wav"):
                    caminho = os.path.join(raiz, tema, "stereo", f"{nome}.{ext}")
                    if os.path.isfile(caminho):
                        return caminho
            if nome in OXYGEN and os.path.isfile(os.path.join(raiz, OXYGEN[nome])):
                return os.path.join(raiz, OXYGEN[nome])
    return ""


def comando_som(arquivo):
    """Como tocar um arquivo uma vez, com o que houver no sistema."""
    if not arquivo:
        return None
    if shutil.which("pw-play"):
        return ["pw-play", arquivo]
    if shutil.which("paplay"):
        return ["paplay", arquivo]
    if shutil.which("canberra-gtk-play"):
        return ["canberra-gtk-play", "-f", arquivo]
    if shutil.which("ffplay"):
        return ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", arquivo]
    return None


def ouvir(escolha):
    comando = comando_som(achar_som(escolha))
    if not comando:
        print(json.dumps({"ok": False, "erro": "sem-som"}))
        return 1
    try:
        subprocess.run(comando, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=8)
    except (OSError, subprocess.SubprocessError):
        pass
    print(json.dumps({"ok": True}))
    return 0


# ----------------------------------------------------------------------------
# O aviso na tela (notificação com os botões "Soneca" e "Parar")

def gvariant_texto(s):
    return "'" + str(s).replace("\\", "\\\\").replace("'", "\\'") + "'"


class Aviso:
    """Uma notificação que espera a resposta: notify-send --wait e, se faltar, gdbus."""

    def __init__(self, titulo, corpo, acoes, urgente=True):
        self.titulo, self.corpo, self.acoes, self.urgente = titulo, corpo, acoes, urgente
        self.ident = 0
        self.resposta = None   # a ação escolhida ("" = fechou sem escolher)
        self.processo = None
        self.monitor = None
        self._fim = threading.Event()

    @property
    def terminou(self):
        return self._fim.is_set()

    def abrir(self):
        if shutil.which("notify-send") and self._notify_send():
            return True
        if shutil.which("gdbus") and self._gdbus():
            return True
        return False

    def _notify_send(self):
        comando = ["notify-send", f"--app-name={t('Relógio', 'Clock')}", f"--icon={APP_ID}",
                   f"--urgency={'critical' if self.urgente else 'normal'}",
                   f"--hint=string:desktop-entry:{APP_ID}", "--hint=boolean:suppress-sound:true",
                   "--print-id", "--wait"]
        comando += [f"--action={chave}={rotulo}" for chave, rotulo in self.acoes]
        comando += [self.titulo, self.corpo]
        try:
            self.processo = subprocess.Popen(comando, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        except OSError:
            return False

        def ler_saida():
            escolha = ""
            for linha in self.processo.stdout:
                linha = linha.strip()
                if linha.isdigit() and not self.ident:
                    self.ident = int(linha)
                elif linha:
                    escolha = linha
            self.processo.wait()
            self.resposta = escolha
            self._fim.set()

        threading.Thread(target=ler_saida, daemon=True).start()
        # notify-send antigo (sem --action/--wait) sai na hora com erro: aí vai o gdbus.
        if self._fim.wait(0.8) and self.processo.returncode not in (0, None) and not self.ident:
            self._fim.clear()
            return False
        return True

    def _gdbus(self):
        try:
            self.monitor = subprocess.Popen(
                ["gdbus", "monitor", "--session", "--dest", "org.freedesktop.Notifications",
                 "--object-path", "/org/freedesktop/Notifications"],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        except OSError:
            return False
        acoes = "[" + ", ".join(gvariant_texto(x) for par in self.acoes for x in par) + "]"
        dicas = "{'urgency': <byte %d>, 'desktop-entry': <'%s'>, 'suppress-sound': <true>}" % (
            2 if self.urgente else 1, APP_ID)
        ok, saida, _ = rodar(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                              "--object-path", "/org/freedesktop/Notifications",
                              "--method", "org.freedesktop.Notifications.Notify",
                              gvariant_texto(t("Relógio", "Clock")), "0", gvariant_texto(APP_ID),
                              gvariant_texto(self.titulo), gvariant_texto(self.corpo), acoes, dicas, "0"], espera=5)
        m = re.search(r"uint32 (\d+)", saida)
        if not ok or not m:
            self.monitor.terminate()
            return False
        self.ident = int(m.group(1))

        def vigiar():
            for linha in self.monitor.stdout:
                a = re.search(r"ActionInvoked \(uint32 (\d+), '([^']*)'\)", linha)
                f = re.search(r"NotificationClosed \(uint32 (\d+),", linha)
                if a and int(a.group(1)) == self.ident:
                    self.resposta = a.group(2)
                    break
                if f and int(f.group(1)) == self.ident:
                    self.resposta = self.resposta or ""
                    break
            self._fim.set()
            with contextlib.suppress(OSError):
                self.monitor.terminate()

        threading.Thread(target=vigiar, daemon=True).start()
        return True

    def fechar(self):
        if self.ident and shutil.which("gdbus"):
            rodar(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                   "--object-path", "/org/freedesktop/Notifications",
                   "--method", "org.freedesktop.Notifications.CloseNotification", str(self.ident)], espera=3)
        for p in (self.processo, self.monitor):
            if p and p.poll() is None:
                with contextlib.suppress(OSError):
                    p.terminate()


def avisar_simples(titulo, corpo):
    """Uma notificação comum, sem esperar (ex.: alarme perdido)."""
    if shutil.which("notify-send"):
        rodar(["notify-send", f"--app-name={t('Relógio', 'Clock')}", f"--icon={APP_ID}",
               f"--hint=string:desktop-entry:{APP_ID}", titulo, corpo], espera=5)
    elif shutil.which("gdbus"):
        rodar(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
               "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify",
               gvariant_texto(t("Relógio", "Clock")), "0", gvariant_texto(APP_ID), gvariant_texto(titulo),
               gvariant_texto(corpo), "[]", "{'desktop-entry': <'%s'>}" % APP_ID, "-1"], espera=5)


class Toque:
    """O aviso e o som em repetição, até a pessoa responder ou o limite passar."""

    def __init__(self, titulo, corpo, acoes, som, limite=LIMITE_TOQUE):
        self.aviso = Aviso(titulo, corpo, acoes)
        self.comando = comando_som(achar_som(som))
        self.limite = limite
        self.parar = threading.Event()
        self.tocando = None

    def executar(self):
        """Devolve a ação escolhida, "" se fechou o aviso, ou None se ninguém respondeu."""
        tem_aviso = self.aviso.abrir()
        # Sem aviso na tela não há como parar: o som toca só um pouco.
        limite = self.limite if tem_aviso else min(self.limite, 30)
        inicio = time.monotonic()
        while not self.parar.is_set() and not self.aviso.terminou and time.monotonic() - inicio < limite:
            if self.comando:
                try:
                    self.tocando = subprocess.Popen(self.comando, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                except OSError:
                    self.comando = None
                    continue
                while self.tocando.poll() is None:
                    if self.parar.is_set() or self.aviso.terminou or time.monotonic() - inicio >= limite:
                        self.tocando.terminate()
                        break
                    time.sleep(0.1)
                self.parar.wait(0.35)
            else:
                self.parar.wait(0.25)
        if self.tocando and self.tocando.poll() is None:
            self.tocando.terminate()
        if self.aviso.terminou:
            return self.aviso.resposta or ""
        self.aviso.fechar()
        return None

    def interromper(self, *_):
        self.parar.set()
        if self.tocando and self.tocando.poll() is None:
            with contextlib.suppress(OSError):
                self.tocando.terminate()


def agendar_soneca(a):
    minutos = a["soneca"] or 10
    unidade = f"matsu-soneca-{a['id']}-{int(time.time())}"
    ok = False
    if systemd_ok() and shutil.which("systemd-run"):
        ok, _, _ = rodar(["systemd-run", "--user", "--collect", "--quiet", f"--unit={unidade}",
                          f"--description={descricao(a)} ({t('soneca', 'snooze')})",
                          f"--on-active={minutos * 60}", "--timer-property=AccuracySec=1s",
                          PYTHON, "-I", "-S", TOCAR, "alarme", a["id"], "--soneca"])
    return ok


def tocar(tipo, ident, nome="", soneca=False):
    """O toque: chamado pelo systemd (tocar.py) quando o alarme ou o temporizador chega."""
    if tipo == "alarme":
        with trava():
            lista = ler_alarmes()
            a = next((x for x in lista if x["id"] == ident), None)
            if a is None:
                return 0
            if not soneca and not a["ligado"]:
                return 0
            if not soneca and not a["dias"]:
                # Alarme de uma vez só: desliga depois de tocar.
                a["ligado"] = False
                gravar_alarmes(lista)
                sincronizar(lista)
        hora = f"{a['hora']:02d}:{a['minuto']:02d}"
        titulo = a["nome"] or t("Alarme", "Alarm")
        corpo = f"{hora} · {t('Alarme', 'Alarm')}" if a["nome"] else hora
        acoes = []
        if a["soneca"]:
            acoes.append(("soneca", t(f"Soneca ({a['soneca']} min)", f"Snooze ({a['soneca']} min)")))
        acoes.append(("parar", t("Parar", "Stop")))
        toque = Toque(titulo, corpo, acoes, a["som"])
    else:
        nome = limpar_nome(nome) or t("Temporizador", "Timer")
        titulo = t("Tempo esgotado", "Time's up")
        corpo = t(f"O temporizador “{nome}” terminou.", f"The “{nome}” timer is done.")
        toque = Toque(titulo, corpo, [("parar", t("Parar", "Stop"))], "alarme")
        a = None
    signal.signal(signal.SIGTERM, lambda *x: (toque.interromper(), toque.aviso.fechar(), sys.exit(0)))
    resposta = toque.executar()
    if resposta == "soneca" and a is not None:
        if not agendar_soneca(a):
            # Sem o systemd: espera aqui mesmo e toca de novo.
            time.sleep(a["soneca"] * 60)
            return tocar("alarme", ident, soneca=True)
    elif resposta is None and a is not None:
        hora = f"{a['hora']:02d}:{a['minuto']:02d}"
        avisar_simples(t("Alarme perdido", "Missed alarm"),
                       f"{a['nome'] or t('Alarme', 'Alarm')} · {hora}")
    return 0


# ----------------------------------------------------------------------------
# Comandos

def estado(agora=None):
    """Lê a lista, desliga o alarme de uma vez que já passou e acerta o systemd."""
    agora = agora or dt.datetime.now()
    with trava():
        lista = ler_alarmes()
        mudou = False
        for a in lista:
            if a["ligado"] and not a["dias"] and proximo_toque(a, agora) is None:
                a["ligado"] = False   # era para tocar enquanto o computador estava desligado
                mudou = True
        if mudou:
            gravar_alarmes(lista)
        r = sincronizar(lista, agora)
    tz = fuso_local()
    nome, nome_en = nome_fuso(tz)
    return {
        "idioma": idioma(),
        "vidro": vidro(),
        "systemd": r["systemd"],
        "erros": r["erros"],
        "fuso": {"id": tz, "nome": nome if idioma() == "pt" else nome_en,
                 **info_fuso(tz, agora.timestamp())} if zoneinfo else {"id": tz, "nome": nome, "desvio": 0},
        "alarmes": ordenar(lista),
        "arquivo": arquivo_alarmes(),
    }


def salvar_alarme(dados, agora=None):
    agora = agora or dt.datetime.now()
    a = normalizar(dados)
    if not a["dias"] and a["ligado"]:
        a["data"] = proxima_data(a["hora"], a["minuto"], agora)
    with trava():
        lista = [x for x in ler_alarmes() if x["id"] != a["id"]]
        lista.append(a)
        gravar_alarmes(lista)
        r = sincronizar(lista, agora)
    return {"ok": True, "alarme": a, "alarmes": ordenar(lista), "systemd": r["systemd"], "erros": r["erros"]}


def ligar_alarme(ident, ligar, agora=None):
    agora = agora or dt.datetime.now()
    with trava():
        lista = ler_alarmes()
        a = next((x for x in lista if x["id"] == ident), None)
        if a is None:
            return {"ok": False, "erro": "nao-existe", "alarmes": ordenar(lista)}
        a["ligado"] = ligar
        if ligar and not a["dias"]:
            a["data"] = proxima_data(a["hora"], a["minuto"], agora)
        gravar_alarmes(lista)
        r = sincronizar(lista, agora)
    if not ligar:
        parar_toque(ident)
    return {"ok": True, "alarme": a, "alarmes": ordenar(lista), "systemd": r["systemd"], "erros": r["erros"]}


def apagar_alarme(ident, agora=None):
    with trava():
        lista = ler_alarmes()
        a = next((x for x in lista if x["id"] == ident), None)
        lista = [x for x in lista if x["id"] != ident]
        gravar_alarmes(lista)
        r = sincronizar(lista, agora)
    parar_toque(ident)
    return {"ok": a is not None, "apagado": a, "alarmes": ordenar(lista), "systemd": r["systemd"], "erros": r["erros"]}


def imprimir(dados):
    sys.stdout.write(json.dumps(dados, ensure_ascii=False) + "\n")


def main(args):
    if not args:
        print(__doc__)
        return 2
    comando, resto = args[0], args[1:]
    try:
        if comando == "estado":
            imprimir(estado())
        elif comando == "salvar-alarme" and len(resto) == 1:
            imprimir(salvar_alarme(json.loads(resto[0])))
        elif comando == "ligar-alarme" and len(resto) == 2 and resto[1] in ("sim", "nao"):
            imprimir(ligar_alarme(resto[0], resto[1] == "sim"))
        elif comando == "apagar-alarme" and len(resto) == 1:
            imprimir(apagar_alarme(resto[0]))
        elif comando == "sincronizar":
            with trava():
                imprimir(sincronizar(ler_alarmes()))
        elif comando == "cidades":
            imprimir({"cidades": catalogo()})
        elif comando == "fusos":
            agora = time.time()
            imprimir({"fusos": [info_fuso(tz, agora) for tz in resto if fuso_valido(tz)]})
        elif comando == "temporizador" and len(resto) == 3:
            imprimir(agendar_temporizador(resto[0], float(resto[1]), resto[2]))
        elif comando == "cancelar-temporizador" and len(resto) == 1:
            imprimir(cancelar_temporizador(resto[0]))
        elif comando == "ouvir" and len(resto) == 1:
            return ouvir(resto[0])
        elif comando == "tocar" and len(resto) >= 2 and resto[0] in ("alarme", "temporizador"):
            nome = resto[2] if resto[0] == "temporizador" and len(resto) > 2 else ""
            return tocar(resto[0], resto[1], nome=nome, soneca="--soneca" in resto[2:])
        else:
            print(__doc__)
            return 2
    except (ValueError, TypeError) as e:
        imprimir({"ok": False, "erro": str(e)})
        return 1
    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    sys.exit(main(sys.argv[1:]))
