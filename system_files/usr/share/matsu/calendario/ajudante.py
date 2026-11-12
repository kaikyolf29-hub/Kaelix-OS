#!/usr/bin/python3
"""Calendário do Matsu: o ajudante dos lembretes, dos feriados e dos arquivos .ics.

A janela (os arquivos .qml desta pasta) desenha e guarda os eventos em
~/.local/share/matsu/calendario/eventos.json. Este script faz o que precisa do
sistema: agenda os lembretes no systemd do usuário (um .timer e um .service por
evento, em ~/.config/systemd/user/matsu-lembrete-<id>.*), mostra a notificação
na hora (e agenda a próxima, se o evento se repete) e lê e escreve arquivos .ics.
Só usa a biblioteca padrão do Python e responde em JSON.

Uso:
  ajudante.py estado                 idioma, vidro e se os lembretes funcionam aqui
  ajudante.py sincronizar            recria os lembretes a partir do eventos.json
  ajudante.py avisar <id>            mostra o lembrete do evento e agenda o próximo (o systemd chama)
  ajudante.py importar <arquivo.ics> os eventos do arquivo, no formato do app (JSON)
  ajudante.py exportar <arquivo.ics> grava todos os eventos num arquivo .ics
  ajudante.py feriados <ano>         os feriados nacionais do ano (JSON)
"""
import datetime as dt
import json
import os
import re
import secrets
import shutil
import signal
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
APP_ID = "org.matsu.calendario"
HORA_DIA_TODO = 9  # o lembrete de um evento de dia todo conta a partir das 9h
LEMBRETES = (-1, 0, 5, 15, 30, 60, 1440)
REPETICOES = ("nunca", "dia", "semana", "mes", "ano")
CORES = ("salvia", "lavanda", "coral", "mel", "rosa", "menta")
PREFIXO = "matsu-lembrete-"


# ----- onde as coisas ficam (os testes trocam pelas variáveis de ambiente) -----
def casa():
    return os.environ.get("HOME") or os.path.expanduser("~")


def config_casa():
    return os.environ.get("XDG_CONFIG_HOME") or os.path.join(casa(), ".config")


def arquivo_eventos():
    if os.environ.get("MATSU_CALENDARIO"):
        return os.environ["MATSU_CALENDARIO"]
    dados = os.environ.get("XDG_DATA_HOME") or os.path.join(casa(), ".local", "share")
    return os.path.join(dados, "matsu", "calendario", "eventos.json")


def pasta_unidades():
    return os.environ.get("MATSU_SYSTEMD_USER") or os.path.join(config_casa(), "systemd", "user")


def programa(nome, variavel):
    return os.environ.get(variavel) or shutil.which(nome) or ""


def ler(caminho, padrao=""):
    try:
        with open(caminho, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return padrao


def gravar(caminho, texto):
    """Grava de uma vez (num arquivo ao lado e depois troca), sem deixar pela metade."""
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    temp = caminho + ".tmp"
    with open(temp, "w", encoding="utf-8", newline="") as f:
        f.write(texto)
    os.replace(temp, caminho)


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


# ----- feriados nacionais do Brasil -----
def pascoa(ano):
    """Domingo de Páscoa (método de Meeus/Jones/Butcher, calendário gregoriano)."""
    a, b, c = ano % 19, ano // 100, ano % 100
    d, e = b // 4, b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    mes = (h + l - 7 * m + 114) // 31
    dia = (h + l - 7 * m + 114) % 31 + 1
    return dt.date(ano, mes, dia)


FIXOS = [
    (1, 1, "Confraternização Universal", "New Year's Day"),
    (4, 21, "Tiradentes", "Tiradentes Day"),
    (5, 1, "Dia do Trabalho", "Labour Day"),
    (9, 7, "Independência do Brasil", "Independence Day"),
    (10, 12, "Nossa Senhora Aparecida", "Our Lady of Aparecida"),
    (11, 2, "Finados", "All Souls' Day"),
    (11, 15, "Proclamação da República", "Republic Day"),
    (11, 20, "Consciência Negra", "Black Consciousness Day"),
    (12, 25, "Natal", "Christmas Day"),
]
MOVEIS = [
    (-48, "Carnaval", "Carnival", "facultativo"),
    (-47, "Carnaval", "Carnival", "facultativo"),
    (-2, "Sexta-feira Santa", "Good Friday", "feriado"),
    (0, "Páscoa", "Easter", "data"),
    (60, "Corpus Christi", "Corpus Christi", "facultativo"),
]


def feriados(ano):
    """[{data, nome, nome_en, tipo}] do ano, em ordem. Tipo: feriado, facultativo ou data."""
    lista = []
    for mes, dia, nome, nome_en in FIXOS:
        if (mes, dia) == (11, 20) and ano < 2024:
            continue  # feriado nacional desde 2024 (Lei 14.759/2023)
        lista.append({"data": dt.date(ano, mes, dia), "nome": nome, "nome_en": nome_en, "tipo": "feriado"})
    p = pascoa(ano)
    for dias, nome, nome_en, tipo in MOVEIS:
        lista.append({"data": p + dt.timedelta(days=dias), "nome": nome, "nome_en": nome_en, "tipo": tipo})
    lista.sort(key=lambda f: f["data"])
    return lista


# ----- eventos -----
def ler_quando(texto):
    """"2026-11-12T09:00" ou "2026-11-12" → datetime (hora local, sem fuso)."""
    texto = str(texto or "").strip()
    try:
        if "T" in texto:
            return dt.datetime.strptime(texto[:16], "%Y-%m-%dT%H:%M")
        return dt.datetime.strptime(texto[:10], "%Y-%m-%d")
    except ValueError:
        return None


def texto_quando(quando, dia_todo):
    return quando.strftime("%Y-%m-%d") if dia_todo else quando.strftime("%Y-%m-%dT%H:%M")


def normalizar(ev):
    """O evento com todos os campos e valores que o app entende (ou None se não der)."""
    if not isinstance(ev, dict):
        return None
    dia_todo = bool(ev.get("diaTodo"))
    ini = ler_quando(ev.get("inicio"))
    if ini is None:
        return None
    fim = ler_quando(ev.get("fim")) or ini
    if dia_todo:
        ini = dt.datetime.combine(ini.date(), dt.time())
        fim = dt.datetime.combine(fim.date(), dt.time())
    if fim < ini:
        fim = ini
    try:
        lembrete = int(ev.get("lembrete", -1))
    except (TypeError, ValueError):
        lembrete = -1
    repetir = ev.get("repetir") if ev.get("repetir") in REPETICOES else "nunca"
    ate = ler_quando(ev.get("ate")) if repetir != "nunca" and ev.get("ate") else None
    novo = dict(ev)
    novo.update({
        "id": re.sub(r"[^A-Za-z0-9_-]", "", str(ev.get("id") or "")) or novo_id(),
        "titulo": str(ev.get("titulo") or ""),
        "diaTodo": dia_todo,
        "inicio": texto_quando(ini, dia_todo),
        "fim": texto_quando(fim, dia_todo),
        "cor": ev.get("cor") if ev.get("cor") in CORES else CORES[0],
        "lembrete": lembrete if lembrete >= 0 else -1,
        "repetir": repetir,
        "ate": ate.strftime("%Y-%m-%d") if ate else "",
        "excecoes": sorted({str(x)[:10] for x in (ev.get("excecoes") or []) if ler_quando(str(x)[:10])}),
        "local": str(ev.get("local") or ""),
        "notas": str(ev.get("notas") or ""),
    })
    return novo


def novo_id():
    return secrets.token_hex(5)


def carregar(caminho=None):
    """Os eventos guardados (o arquivo pode ser {"eventos": [...]} ou só a lista)."""
    texto = ler(caminho or arquivo_eventos())
    try:
        dados = json.loads(texto) if texto.strip() else {}
    except ValueError:
        return []
    lista = dados.get("eventos", []) if isinstance(dados, dict) else dados
    return [e for e in (normalizar(x) for x in lista if isinstance(lista, list)) if e]


def extensao(ev):
    """Quantos dias a mais o evento ocupa depois do primeiro."""
    return max(0, (ler_quando(ev["fim"]).date() - ler_quando(ev["inicio"]).date()).days)


def dias_no_mes(ano, mes):
    return ((dt.date(ano + mes // 12, mes % 12 + 1, 1)) - dt.date(ano, mes, 1)).days


def dias_da_serie(ev, de, ate):
    """Os dias (date) em que a série começa uma ocorrência, de "de" até "ate" (inclusive)."""
    ini = ler_quando(ev["inicio"]).date()
    rep = ev.get("repetir") or "nunca"
    if rep != "nunca" and ev.get("ate"):
        ate = min(ate, ler_quando(ev["ate"]).date())
    if ate < ini:
        return []
    if rep == "nunca":
        return [ini] if de <= ini <= ate else []
    r = []
    if rep in ("dia", "semana"):
        passo = 1 if rep == "dia" else 7
        n = max(0, -(-(de - ini).days // passo))
        d = ini + dt.timedelta(days=n * passo)
        while d <= ate:
            r.append(d)
            d += dt.timedelta(days=passo)
    elif rep == "mes":
        # Todo dia 31: os meses sem dia 31 ficam de fora (como no iCalendar).
        k = max(0, (de.year - ini.year) * 12 + de.month - ini.month - 1)
        while True:
            ano, mes = ini.year + (ini.month - 1 + k) // 12, (ini.month - 1 + k) % 12 + 1
            k += 1
            if dt.date(ano, mes, 1) > ate:
                break
            if ini.day > dias_no_mes(ano, mes):
                continue
            d = dt.date(ano, mes, ini.day)
            if de <= d <= ate and d >= ini:
                r.append(d)
    elif rep == "ano":
        # 29 de fevereiro: só nos anos bissextos.
        for ano in range(max(ini.year, de.year - 1), ate.year + 1):
            if ini.day > dias_no_mes(ano, ini.month):
                continue
            d = dt.date(ano, ini.month, ini.day)
            if de <= d <= ate and d >= ini:
                r.append(d)
    return r


def ocorrencias(ev, de, ate):
    """[(inicio, fim)] das ocorrências que tocam os dias de "de" até "ate" (datetimes locais).
    No dia todo, fim é o último dia (à meia-noite)."""
    ini = ler_quando(ev["inicio"])
    fim = ler_quando(ev["fim"]) or ini
    dur = fim - ini
    ext = extensao(ev)
    excecoes = set(ev.get("excecoes") or [])
    r = []
    for d in dias_da_serie(ev, de - dt.timedelta(days=ext), ate):
        if d.isoformat() in excecoes:
            continue
        o_ini = dt.datetime.combine(d, ini.time())
        r.append((o_ini, o_ini + dur))
    return r


def comeco_do_lembrete(o_ini, ev):
    """A hora a partir da qual o lembrete conta (no dia todo, às 9h do dia)."""
    if ev.get("diaTodo"):
        return dt.datetime.combine(o_ini.date(), dt.time(HORA_DIA_TODO))
    return o_ini


def fim_real(o_fim, ev):
    """Quando a ocorrência termina de verdade (no dia todo, à meia-noite do dia seguinte)."""
    return o_fim + dt.timedelta(days=1) if ev.get("diaTodo") else o_fim


def proximo_lembrete(ev, agora):
    """(hora do lembrete, inicio, fim) do próximo lembrete depois de "agora", ou None."""
    minutos = int(ev.get("lembrete", -1))
    if minutos < 0:
        return None
    antes = dt.timedelta(minutes=minutos)
    de = (agora + antes).date() - dt.timedelta(days=1)
    # Janelas de um ano: um "todo ano" em 29 de fevereiro pode levar 8 anos.
    for _ in range(10):
        ate = de + dt.timedelta(days=400)
        for o_ini, o_fim in ocorrencias(ev, de, ate):
            quando = comeco_do_lembrete(o_ini, ev) - antes
            if quando > agora:
                return quando, o_ini, o_fim
        de = ate + dt.timedelta(days=1)
    return None


def lembrete_devido(ev, agora, folga=dt.timedelta(seconds=90)):
    """A ocorrência cujo lembrete venceu agora (ou antes, se o computador estava desligado)
    e que ainda não acabou: (hora do lembrete, inicio, fim), ou None."""
    minutos = int(ev.get("lembrete", -1))
    if minutos < 0:
        return None
    antes = dt.timedelta(minutes=minutos)
    escolhido = None
    for o_ini, o_fim in ocorrencias(ev, agora.date() - dt.timedelta(days=3), (agora + antes).date() + dt.timedelta(days=1)):
        quando = comeco_do_lembrete(o_ini, ev) - antes
        if quando <= agora + folga and fim_real(o_fim, ev) > agora:
            if escolhido is None or quando > escolhido[0]:
                escolhido = (quando, o_ini, o_fim)
    return escolhido


# ----- unidades do systemd -----
def on_calendar(quando):
    """O momento no formato do OnCalendar= do systemd (hora local)."""
    return quando.strftime("%Y-%m-%d %H:%M:%S")


def sem_especificador(texto):
    """Texto de uma linha para os arquivos do systemd ("%" é especial lá)."""
    return re.sub(r"\s+", " ", str(texto)).strip().replace("%", "%%")


def citar(arg):
    return '"' + str(arg).replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%") + '"'


def nome_unidade(ev_id, tipo):
    return f"{PREFIXO}{ev_id}.{tipo}"


def python():
    return sys.executable if sys.executable and os.path.exists(sys.executable) else "/usr/bin/python3"


def texto_timer(ev, quando, lingua="pt"):
    titulo = sem_especificador(ev.get("titulo") or ("Evento" if lingua == "pt" else "Event"))
    descricao = ("Lembrete do Calendário: " if lingua == "pt" else "Calendar reminder: ") + titulo
    return (
        "# Criado pelo Calendário do Matsu: o app reescreve este arquivo.\n"
        "[Unit]\n"
        f"Description={descricao}\n"
        "\n"
        "[Timer]\n"
        f"OnCalendar={on_calendar(quando)}\n"
        "AccuracySec=1s\n"
        "Persistent=true\n"
        f"Unit={nome_unidade(ev['id'], 'service')}\n"
        "\n"
        "[Install]\n"
        "WantedBy=timers.target\n"
    )


def texto_service(ev, lingua="pt"):
    titulo = sem_especificador(ev.get("titulo") or ("Evento" if lingua == "pt" else "Event"))
    descricao = ("Lembrete do Calendário: " if lingua == "pt" else "Calendar reminder: ") + titulo
    comando = " ".join(citar(a) for a in (python(), "-I", "-S", os.path.join(AQUI, "ajudante.py"), "avisar", ev["id"]))
    return (
        "# Criado pelo Calendário do Matsu: o app reescreve este arquivo.\n"
        "[Unit]\n"
        f"Description={descricao}\n"
        "\n"
        "[Service]\n"
        "Type=oneshot\n"
        f"ExecStart={comando}\n"
    )


def systemctl(*args):
    prog = programa("systemctl", "MATSU_SYSTEMCTL")
    if not prog:
        return False
    try:
        r = subprocess.run([prog, "--user", *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
        return r.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def tem_systemd():
    """Se o systemd do usuário responde (na prévia e em contêineres, não)."""
    return systemctl("show-environment")


def agendados():
    """Os ids que têm um .timer de lembrete na pasta."""
    try:
        nomes = os.listdir(pasta_unidades())
    except OSError:
        return set()
    return {n[len(PREFIXO):-len(".timer")] for n in nomes if n.startswith(PREFIXO) and n.endswith(".timer")}


def escrever_unidades(ev, quando, lingua):
    """Grava o .timer e o .service; devolve se algo mudou."""
    pasta = pasta_unidades()
    mudou = False
    for tipo, texto in (("timer", texto_timer(ev, quando, lingua)), ("service", texto_service(ev, lingua))):
        caminho = os.path.join(pasta, nome_unidade(ev["id"], tipo))
        if ler(caminho, None) != texto:
            gravar(caminho, texto)
            mudou = True
    return mudou


def apagar_unidades(ev_id):
    for tipo in ("timer", "service"):
        try:
            os.remove(os.path.join(pasta_unidades(), nome_unidade(ev_id, tipo)))
        except OSError:
            pass


def sincronizar(agora=None, eventos=None):
    """Deixa um timer para cada evento com lembrete pela frente e tira os que sobraram."""
    agora = agora or dt.datetime.now().replace(microsecond=0)
    lingua = idioma()
    if not tem_systemd():
        return {"systemd": False, "agendados": 0}
    eventos = carregar() if eventos is None else eventos
    desejados = {}
    for ev in eventos:
        prox = proximo_lembrete(ev, agora)
        if prox:
            desejados[ev["id"]] = (ev, prox[0])
    sobrando = sorted(agendados() - set(desejados))
    if sobrando:
        systemctl("disable", "--now", *[nome_unidade(i, "timer") for i in sobrando])
        for i in sobrando:
            apagar_unidades(i)
    mudados = sorted(i for i, (ev, quando) in desejados.items() if escrever_unidades(ev, quando, lingua))
    if mudados or sobrando:
        systemctl("daemon-reload")
    if mudados:
        timers = [nome_unidade(i, "timer") for i in mudados]
        systemctl("enable", *timers)
        systemctl("restart", *timers)
    return {"systemd": True, "agendados": len(desejados), "mudados": len(mudados), "removidos": len(sobrando)}


def reagendar(ev, depois):
    """Depois de avisar: o próximo lembrete do evento (se ele se repete) ou nada."""
    timer = nome_unidade(ev["id"], "timer")
    prox = proximo_lembrete(ev, depois)
    if prox:
        if escrever_unidades(ev, prox[0], idioma()):
            systemctl("daemon-reload")
        systemctl("enable", timer)
        systemctl("restart", timer)
        return prox[0]
    systemctl("disable", "--now", timer)
    apagar_unidades(ev["id"])
    systemctl("daemon-reload")
    return None


# ----- a notificação -----
DIAS_CURTOS = ["seg.", "ter.", "qua.", "qui.", "sex.", "sáb.", "dom."]  # weekday(): segunda = 0
DIAS_CURTOS_EN = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
MESES_CURTOS = ["jan.", "fev.", "mar.", "abr.", "mai.", "jun.", "jul.", "ago.", "set.", "out.", "nov.", "dez."]
MESES_CURTOS_EN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def dia_relativo(d, hoje, lingua):
    n = (d - hoje).days
    if n == 0:
        return "Hoje" if lingua == "pt" else "Today"
    if n == 1:
        return "Amanhã" if lingua == "pt" else "Tomorrow"
    if lingua == "pt":
        return f"{DIAS_CURTOS[d.weekday()]}, {d.day} de {MESES_CURTOS[d.month - 1]}"
    return f"{DIAS_CURTOS_EN[d.weekday()]}, {MESES_CURTOS_EN[d.month - 1]} {d.day}"


def texto_aviso(ev, o_ini, o_fim, agora, lingua="pt"):
    """(título, corpo) da notificação: "Hoje, 09:00 – 10:00 · Clínica Sorriso"."""
    pt = lingua == "pt"
    titulo = ev.get("titulo") or ("Evento" if pt else "Event")
    faixa = f"{o_ini:%H:%M}" + (f" – {o_fim:%H:%M}" if o_fim > o_ini else "")
    if ev.get("diaTodo"):
        quando = dia_relativo(o_ini.date(), agora.date(), lingua) + (" · dia todo" if pt else " · all day")
    elif o_ini <= agora < o_ini + dt.timedelta(minutes=2):
        quando = ("Agora, " if pt else "Now, ") + faixa
    elif o_ini <= agora:
        quando = (f"Começou às {o_ini:%H:%M}" if pt else f"Started at {o_ini:%H:%M}") + (f" · até {o_fim:%H:%M}" if pt and o_fim > o_ini else (f" · until {o_fim:%H:%M}" if o_fim > o_ini else ""))
    else:
        quando = f"{dia_relativo(o_ini.date(), agora.date(), lingua)}, {faixa}"
    partes = [quando]
    if ev.get("local"):
        partes.append(ev["local"].strip())
    return titulo, " · ".join(partes)


def notificar(titulo, corpo, dia):
    """Mostra a notificação; clicar nela abre o Calendário naquele dia."""
    prog = programa("notify-send", "MATSU_NOTIFY")
    if not prog:
        return False
    nome = "Calendário" if idioma() == "pt" else "Calendar"
    base = [prog, f"--app-name={nome}", f"--icon={APP_ID}", f"--hint=string:desktop-entry:{APP_ID}", "--urgency=normal"]
    acao = "Abrir" if idioma() == "pt" else "Open"
    try:
        r = subprocess.run(base + ["--wait", f"--action=default={acao}", titulo, corpo],
                           capture_output=True, text=True, timeout=600)
        if r.returncode != 0:
            # notify-send antigo, sem --action: só o aviso.
            r = subprocess.run(base + [titulo, corpo], capture_output=True, text=True, timeout=30)
            return r.returncode == 0
        if r.stdout.strip() == "default":
            abrir_app(dia)
        return True
    except subprocess.TimeoutExpired:
        return True
    except OSError:
        return False


def abrir_app(dia):
    janela = "/usr/libexec/matsu/matsu-janela"
    comando = [janela, APP_ID, os.path.join(AQUI, "Main.qml"), "--dia", dia.isoformat()]
    # Fora do serviço do lembrete, para o app não fechar junto com ele.
    rodar = shutil.which("systemd-run")
    try:
        if rodar:
            subprocess.Popen([rodar, "--user", "--quiet", "--collect", "--"] + comando,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.Popen(comando, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass


def avisar(ev_id, agora=None):
    agora = agora or dt.datetime.now().replace(microsecond=0)
    ev = next((e for e in carregar() if e["id"] == ev_id), None)
    if ev is None:
        systemctl("disable", "--now", nome_unidade(ev_id, "timer"))
        apagar_unidades(ev_id)
        systemctl("daemon-reload")
        return {"avisou": False, "proximo": None}
    devido = lembrete_devido(ev, agora)
    depois = max(agora, devido[0]) if devido else agora
    # Agenda o próximo antes de mostrar: a notificação espera o clique.
    prox = reagendar(ev, depois)
    avisou = False
    if devido:
        titulo, corpo = texto_aviso(ev, devido[1], devido[2], agora, idioma())
        avisou = notificar(titulo, corpo, devido[1].date())
    return {"avisou": avisou, "proximo": on_calendar(prox) if prox else None}


# ----- iCalendar (.ics) -----
def desdobrar(texto):
    """As linhas lógicas do .ics (as continuações começam com espaço ou tab)."""
    linhas = []
    for linha in texto.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if linha[:1] in (" ", "\t") and linhas:
            linhas[-1] += linha[1:]
        elif linha.strip():
            linhas.append(linha)
    return linhas


def partir(linha):
    """"DTSTART;TZID=America/Sao_Paulo:20261112T090000" → ("DTSTART", {"TZID": ...}, "2026...")."""
    dentro = False
    corte = -1
    for i, c in enumerate(linha):
        if c == '"':
            dentro = not dentro
        elif c == ":" and not dentro:
            corte = i
            break
    if corte < 0:
        return linha.upper(), {}, ""
    cabeca, valor = linha[:corte], linha[corte + 1:]
    pedacos = re.findall(r'(?:[^;"]|"[^"]*")+', cabeca)
    nome = pedacos[0].strip().upper() if pedacos else ""
    params = {}
    for p in pedacos[1:]:
        k, _, v = p.partition("=")
        params[k.strip().upper()] = v.strip().strip('"')
    return nome, params, valor


def desescapar(valor):
    return re.sub(r"\\(.)", lambda m: "\n" if m.group(1) in "nN" else m.group(1), valor)


def escapar(valor):
    return str(valor).replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\r\n", "\n").replace("\n", "\\n")


def ler_data_ics(valor, params):
    """(datetime local, dia_todo) de um DTSTART/DTEND/EXDATE, ou (None, False)."""
    valor = valor.strip()
    try:
        if params.get("VALUE", "").upper() == "DATE" or re.fullmatch(r"\d{8}", valor):
            return dt.datetime.strptime(valor[:8], "%Y%m%d"), True
        m = re.fullmatch(r"(\d{8}T\d{4})(\d{2})?(Z)?", valor)
        if not m:
            return None, False
        quando = dt.datetime.strptime(m.group(1), "%Y%m%dT%H%M")
        if m.group(3):
            quando = quando.replace(tzinfo=dt.timezone.utc)
        elif params.get("TZID"):
            try:
                from zoneinfo import ZoneInfo
                quando = quando.replace(tzinfo=ZoneInfo(params["TZID"]))
            except Exception:  # fuso desconhecido (nomes do Windows): fica a hora local
                pass
        if quando.tzinfo is not None:
            quando = dt.datetime.fromtimestamp(quando.timestamp())
        return quando.replace(second=0, microsecond=0), False
    except ValueError:
        return None, False


def ler_duracao(valor):
    """"-PT15M", "P1D", "PT1H30M", "P1W" → timedelta (ou None)."""
    m = re.fullmatch(r"([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?", valor.strip().upper())
    if not m or valor.strip().upper() in ("P", "-P", "+P", "PT"):
        return None
    sinal = -1 if m.group(1) == "-" else 1
    semanas, dias, horas, minutos, segundos = (int(g or 0) for g in m.groups()[1:])
    return sinal * dt.timedelta(weeks=semanas, days=dias, hours=horas, minutes=minutos, seconds=segundos)


def lembrete_mais_perto(minutos):
    validos = [m for m in LEMBRETES if m >= 0]
    return min(validos, key=lambda v: (abs(v - minutos), v))


def importar_ics(texto):
    """Os eventos de um .ics no formato do app: (eventos, ignorados)."""
    blocos = []
    pilha = []
    atual = None
    alarme = None
    for linha in desdobrar(texto):
        nome, params, valor = partir(linha)
        if nome == "BEGIN":
            pilha.append(valor.strip().upper())
            if pilha[-1] == "VEVENT":
                atual = {"props": [], "alarmes": []}
            elif pilha[-1] == "VALARM" and atual is not None:
                alarme = {}
            continue
        if nome == "END":
            fim = valor.strip().upper()
            if fim == "VEVENT" and atual is not None:
                blocos.append(atual)
                atual = None
            elif fim == "VALARM" and alarme is not None and atual is not None:
                atual["alarmes"].append(alarme)
                alarme = None
            if pilha:
                pilha.pop()
            continue
        if alarme is not None:
            alarme[nome] = (params, valor)
        elif atual is not None and pilha and pilha[-1] == "VEVENT":
            atual["props"].append((nome, params, valor))

    eventos = []
    ignorados = 0
    por_uid = {}
    trocas = []  # ocorrências mudadas (RECURRENCE-ID): saem da série e viram eventos soltos
    for bloco in blocos:
        props = {}
        exdates = []
        for nome, params, valor in bloco["props"]:
            if nome == "EXDATE":
                for v in valor.split(","):
                    d, _ = ler_data_ics(v, params)
                    if d:
                        exdates.append(d.date().isoformat())
            elif nome not in props:
                props[nome] = (params, valor)
        if "DTSTART" not in props or props.get("STATUS", ({}, ""))[1].strip().upper() == "CANCELLED":
            ignorados += 1
            continue
        ini, dia_todo = ler_data_ics(props["DTSTART"][1], props["DTSTART"][0])
        if ini is None:
            ignorados += 1
            continue
        fim = None
        if "DTEND" in props:
            fim, _ = ler_data_ics(props["DTEND"][1], props["DTEND"][0])
        elif "DURATION" in props:
            dur = ler_duracao(props["DURATION"][1])
            fim = ini + dur if dur else None
        if dia_todo:
            # No .ics o fim do dia todo é o dia seguinte; no app, o último dia.
            fim = (fim - dt.timedelta(days=1)) if fim and fim > ini else ini
            fim = dt.datetime.combine(fim.date(), dt.time())
        else:
            fim = fim if fim and fim >= ini else ini
        repetir, ate = "nunca", ""
        if "RRULE" in props:
            regra = dict(p.partition("=")[::2] for p in props["RRULE"][1].upper().split(";") if "=" in p)
            freq = {"DAILY": "dia", "WEEKLY": "semana", "MONTHLY": "mes", "YEARLY": "ano"}.get(regra.get("FREQ", ""))
            simples = regra.get("INTERVAL", "1") == "1" and not any(k in regra for k in ("BYSETPOS", "BYWEEKNO", "BYYEARDAY", "BYHOUR"))
            if freq == "semana" and "BYDAY" in regra:
                dias = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                simples = simples and regra["BYDAY"] == dias[ini.weekday()]
            elif "BYDAY" in regra or "BYMONTHDAY" in regra and regra.get("BYMONTHDAY") != str(ini.day):
                simples = False
            if freq and simples:
                repetir = freq
                if "UNTIL" in regra:
                    d, _ = ler_data_ics(regra["UNTIL"], {})
                    ate = d.date().isoformat() if d else ""
                elif regra.get("COUNT", "").isdigit():
                    base = {"id": "x", "inicio": texto_quando(ini, dia_todo), "fim": texto_quando(fim, dia_todo),
                            "diaTodo": dia_todo, "repetir": freq}
                    datas = dias_da_serie(base, ini.date(), ini.date() + dt.timedelta(days=366 * 30))
                    n = int(regra["COUNT"])
                    if 0 < n <= len(datas):
                        ate = datas[n - 1].isoformat()
        lembrete = -1
        for al in bloco["alarmes"]:
            params, valor = al.get("TRIGGER", ({}, ""))
            if not valor:
                continue
            if params.get("VALUE", "").upper() == "DATE-TIME":
                quando, _ = ler_data_ics(valor, {})
                antes = (comeco_do_lembrete(ini, {"diaTodo": dia_todo}) - quando).total_seconds() / 60 if quando else None
            elif params.get("RELATED", "START").upper() == "END":
                continue
            else:
                dur = ler_duracao(valor)
                if dur is None:
                    continue
                # Relativo ao começo; no dia todo o começo do .ics é 00:00 e o do app, 9h.
                antes = -dur.total_seconds() / 60 + (HORA_DIA_TODO * 60 if dia_todo else 0)
            if antes is not None and antes >= 0:
                m = lembrete_mais_perto(antes)
                lembrete = m if lembrete < 0 else min(lembrete, m)
        cor = props.get("X-MATSU-COR", ({}, ""))[1].strip()
        ev = normalizar({
            "id": novo_id(),
            "uid": props.get("UID", ({}, ""))[1].strip(),
            "titulo": desescapar(props.get("SUMMARY", ({}, ""))[1]).strip(),
            "diaTodo": dia_todo,
            "inicio": texto_quando(ini, dia_todo),
            "fim": texto_quando(fim, dia_todo),
            "cor": cor if cor in CORES else CORES[0],
            "lembrete": lembrete,
            "repetir": repetir,
            "ate": ate,
            "excecoes": exdates,
            "local": desescapar(props.get("LOCATION", ({}, ""))[1]).strip(),
            "notas": desescapar(props.get("DESCRIPTION", ({}, ""))[1]).strip(),
        })
        if "RECURRENCE-ID" in props:
            rid, _ = ler_data_ics(props["RECURRENCE-ID"][1], props["RECURRENCE-ID"][0])
            ev["repetir"], ev["ate"] = "nunca", ""
            trocas.append((ev.get("uid"), rid.date().isoformat() if rid else ""))
        elif ev.get("uid"):
            por_uid.setdefault(ev["uid"], ev)
        eventos.append(ev)
    for uid, dia in trocas:
        mestre = por_uid.get(uid)
        if mestre and dia and mestre["repetir"] != "nunca" and dia not in mestre["excecoes"]:
            mestre["excecoes"] = sorted(mestre["excecoes"] + [dia])
    return eventos, ignorados


def dobrar(linha):
    """Linhas de no máximo 75 bytes, sem partir uma letra acentuada no meio."""
    partes = []
    atual = ""
    limite = 75
    for c in linha:
        if len((atual + c).encode("utf-8")) > limite:
            partes.append(atual)
            atual = c
            limite = 74  # a continuação começa com um espaço
        else:
            atual += c
    partes.append(atual)
    return "\r\n ".join(partes)


def fuso_local():
    tz = os.environ.get("TZ", "").lstrip(":")
    if tz and "/" in tz and not tz.startswith("/"):
        return tz
    try:
        alvo = os.path.realpath("/etc/localtime")
        if "zoneinfo/" in alvo:
            return alvo.split("zoneinfo/", 1)[1]
    except OSError:
        pass
    return ""


def exportar_ics(eventos, agora=None):
    agora = agora or dt.datetime.now(dt.timezone.utc)
    linhas = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Matsu OS//Calendario//PT-BR", "CALSCALE:GREGORIAN",
              "METHOD:PUBLISH", "X-WR-CALNAME:Calendário"]
    fuso = fuso_local()
    if fuso:
        linhas.append(f"X-WR-TIMEZONE:{fuso}")
    carimbo = agora.astimezone(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    for ev in eventos:
        ini, fim = ler_quando(ev["inicio"]), ler_quando(ev["fim"])
        linhas += ["BEGIN:VEVENT", f"UID:{ev.get('uid') or ev['id'] + '@calendario.matsu'}", f"DTSTAMP:{carimbo}"]
        if ev["diaTodo"]:
            linhas.append(f"DTSTART;VALUE=DATE:{ini:%Y%m%d}")
            linhas.append(f"DTEND;VALUE=DATE:{fim + dt.timedelta(days=1):%Y%m%d}")
        else:
            linhas.append(f"DTSTART:{ini:%Y%m%dT%H%M%S}")
            linhas.append(f"DTEND:{fim:%Y%m%dT%H%M%S}")
        linhas.append("SUMMARY:" + escapar(ev["titulo"]))
        if ev.get("local"):
            linhas.append("LOCATION:" + escapar(ev["local"]))
        if ev.get("notas"):
            linhas.append("DESCRIPTION:" + escapar(ev["notas"]))
        if ev["repetir"] != "nunca":
            regra = "RRULE:FREQ=" + {"dia": "DAILY", "semana": "WEEKLY", "mes": "MONTHLY", "ano": "YEARLY"}[ev["repetir"]]
            if ev.get("ate"):
                regra += f";UNTIL={ler_quando(ev['ate']):%Y%m%d}" if ev["diaTodo"] else f";UNTIL={ler_quando(ev['ate']):%Y%m%d}T235959"
            linhas.append(regra)
            for dia in ev.get("excecoes") or []:
                d = ler_quando(dia)
                if ev["diaTodo"]:
                    linhas.append(f"EXDATE;VALUE=DATE:{d:%Y%m%d}")
                else:
                    linhas.append(f"EXDATE:{dt.datetime.combine(d.date(), ini.time()):%Y%m%dT%H%M%S}")
        linhas.append(f"X-MATSU-COR:{ev['cor']}")
        if ev["lembrete"] >= 0:
            minutos = ev["lembrete"] - (HORA_DIA_TODO * 60 if ev["diaTodo"] else 0)
            gatilho = ("-" if minutos > 0 else "") + "PT" + (f"{abs(minutos) // 60}H" if abs(minutos) % 60 == 0 and minutos else f"{abs(minutos)}M")
            linhas += ["BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:" + escapar(ev["titulo"] or "Lembrete"),
                       "TRIGGER:" + (gatilho if minutos else "PT0S"), "END:VALARM"]
        linhas.append("END:VEVENT")
    linhas.append("END:VCALENDAR")
    return "".join(dobrar(l) + "\r\n" for l in linhas)


def caminho_de(arg):
    """Aceita caminho ou file://."""
    if arg.startswith("file://"):
        from urllib.parse import unquote, urlparse
        return unquote(urlparse(arg).path)
    return arg


def responder(dados):
    print(json.dumps(dados, ensure_ascii=False))


def main(args):
    if not args:
        print(__doc__)
        return 2
    comando, resto = args[0], args[1:]
    if comando == "estado":
        responder({"idioma": idioma(), "vidro": vidro(), "systemd": tem_systemd(), "arquivo": arquivo_eventos()})
        return 0
    if comando == "sincronizar":
        r = sincronizar()
        r.update({"idioma": idioma(), "vidro": vidro()})
        responder(r)
        return 0
    if comando == "avisar" and len(resto) == 1:
        responder(avisar(resto[0]))
        return 0
    if comando == "importar" and len(resto) == 1:
        caminho = caminho_de(resto[0])
        try:
            with open(caminho, "r", encoding="utf-8-sig", errors="replace") as f:
                texto = f.read()
        except OSError as e:
            responder({"ok": False, "erro": e.strerror or str(e), "arquivo": caminho, "eventos": []})
            return 1
        eventos, ignorados = importar_ics(texto)
        responder({"ok": "BEGIN:VCALENDAR" in texto.upper() or bool(eventos), "arquivo": caminho,
                   "nome": os.path.basename(caminho), "eventos": eventos, "ignorados": ignorados})
        return 0
    if comando == "exportar" and len(resto) == 1:
        caminho = caminho_de(resto[0])
        if not caminho.lower().endswith(".ics"):
            caminho += ".ics"
        eventos = carregar()
        try:
            gravar(caminho, exportar_ics(eventos))
        except OSError as e:
            responder({"ok": False, "erro": e.strerror or str(e), "arquivo": caminho})
            return 1
        responder({"ok": True, "arquivo": caminho, "n": len(eventos)})
        return 0
    if comando == "feriados" and len(resto) == 1 and resto[0].isdigit():
        responder([{**f, "data": f["data"].isoformat()} for f in feriados(int(resto[0]))])
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    sys.exit(main(sys.argv[1:]))
