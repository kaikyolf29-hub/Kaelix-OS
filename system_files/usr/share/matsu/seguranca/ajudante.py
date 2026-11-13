#!/usr/bin/python3
"""Central de segurança do Matsu: o ajudante da janela, do aviso e da bandeja.

A janela (Main.qml), o aviso de arquivo desconhecido (Aviso.qml) e o ícone da
bandeja só desenham. Quem lê o estado, verifica arquivos, mexe na quarentena,
na rede e nas permissões é este script, sempre como a própria pessoa (nunca
root). Responde em JSON, uma linha por resposta.

Uso:
  ajudante.py estado | vigiar [segundos]     o estado do escudo (vigiar: uma linha por intervalo)
  ajudante.py inicio                         o resumo de cada área para a página Início
  ajudante.py bandeja                        o estado curto para o ícone da bandeja
  ajudante.py pausar 15|60|reiniciar | retomar
  ajudante.py ajuste <ligado|pendrive_auto|esperar_jogo> sim|nao
  ajudante.py atualizar-lista                pede a lista de ameaças nova (freshclam)
  ajudante.py verificar rapida|completa|caminho <pasta ou arquivo>...  [--silencioso]
  ajudante.py historico | visto | restaurar <id> | apagar <id> | excecao-tirar <sha256>
  ajudante.py rede | rede-tipo <uuid> casa|publica | rede-servico <id> sim|nao | rede-padrao | firewall-ligar
  ajudante.py apps | app-permissao <app> <permissão> sim|nao | app-padrao <app>
  ajudante.py integridade | fsck
  ajudante.py abrir <arquivo>                o tratador dos executáveis baixados (o .desktop do aviso)
  ajudante.py aviso-info <arquivo> | aviso-verificar <arquivo> | liberar <arquivo>
  ajudante.py quarentenar <arquivo> [ameaça] | nao-abrir <arquivo> | loja <app> | central [página]

Com MATSU_SEGURANCA_DEMO=protegido|atencao|pausado|baixando os dados são de
mentira (para as fotos da prévia, sem ClamAV, firewalld nem Flatpak).
"""
import json
import os
import re
import shlex
import shutil
import signal
import stat
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nucleo as N  # noqa: E402
import sistema as S  # noqa: E402

DEMO = os.environ.get("MATSU_SEGURANCA_DEMO", "")
if DEMO == "1":
    DEMO = "protegido"


def saida(dados):
    print(json.dumps(dados, ensure_ascii=False), flush=True)


# ======================================================================
# Estado do escudo
# ======================================================================
def escudo_vivo(e, agora=None):
    """O serviço do escudo está rodando (a batida dele tem menos de 40 s e o processo existe)."""
    agora = time.time() if agora is None else agora
    if not isinstance(e, dict) or agora - float(e.get("batida") or 0) > 40:
        return False
    try:
        os.kill(int(e.get("pid") or 0), 0)
        return True
    except (OSError, ValueError):
        return False


def contagem(c):
    quarentena = N.listar_quarentena()
    hist = N.ler_historico()
    agora = time.time()
    novas = [h for h in hist if h["tipo"] == "quarentena" and h.get("data", 0) > c.get("visto_ate", 0)]
    trinta = [h for h in hist if h["tipo"] == "quarentena" and agora - h.get("data", 0) < 30 * 86400]
    ultima = next((h for h in hist if h["tipo"] == "verificacao"), None)
    return {"quarentena": len(quarentena), "excecoes": len(N.ler_excecoes()), "novas": len(novas),
            "ameacas30": len(trinta), "ultimaVerificacao": ultima}


def estado():
    if DEMO:
        return demo_estado()
    c = N.ler_config()
    p = N.estado_pausa(c)
    e = N.ler_json(N.arquivo_escudo(), {}) or {}
    vivo = escudo_vivo(e)
    instalado = N.clamav_instalado()
    presente = N.lista_presente()
    atualizar = N.estado_unidade(N.UNIDADE_ATUALIZAR) if instalado else {"ativo": "", "baixado": 0, "resultado": ""}
    baixando = atualizar["ativo"] in ("activating", "active", "reloading")
    info = N.info_lista() if presente else None
    cont = contagem(c)
    pastas = N.pastas_usuario()
    if not instalado:
        geral = "indisponivel"
    elif not c["ligado"]:
        geral = "desligado"
    elif p["pausado"]:
        geral = "pausado"
    elif not presente:
        geral = "baixando" if baixando else "sem-lista"
    elif cont["novas"] > 0:
        geral = "atencao"
    elif not vivo:
        geral = "parado"
    else:
        geral = "protegido"
    return {
        "idioma": N.idioma(),
        "vidro": N.vidro(),
        "geral": geral,
        "instalado": instalado,
        "escudo": {
            "ligado": c["ligado"], "pausado": p["pausado"], "pausaAte": p["ate"], "pausaReiniciar": p["reiniciar"],
            "servico": vivo, "clamd": e.get("clamd", "parado") if vivo else "parado",
            "fila": int(e.get("fila", 0)) if vivo else 0, "verificados": int(e.get("verificados", 0)) if vivo else 0,
            "jogo": bool(e.get("jogo")) if vivo else False, "pendentes": int(e.get("pendentes", 0)) if vivo else 0,
            "pastas": [{"id": k, "caminho": v, "nome": os.path.basename(v.rstrip("/"))} for k, v in pastas.items() if v],
        },
        "lista": {"presente": presente, "versao": info["versao"] if info else 0, "data": info["data"] if info else 0,
                  "assinaturas": info["assinaturas"] if info else 0, "baixando": baixando,
                  "baixado": atualizar.get("baixado", 0), "total": N.TAMANHO_LISTA,
                  "erro": atualizar.get("resultado") not in ("", "success") and not baixando},
        "ajustes": {"ligado": c["ligado"], "pendrive_auto": c["pendrive_auto"], "esperar_jogo": c["esperar_jogo"]},
        "contagem": cont,
    }


def bandeja():
    e = estado()
    return {"idioma": e["idioma"], "geral": e["geral"], "pausaAte": e["escudo"]["pausaAte"],
            "pausaReiniciar": e["escudo"]["pausaReiniciar"], "novas": e["contagem"]["novas"],
            "lista": {"presente": e["lista"]["presente"], "baixado": e["lista"]["baixado"], "total": e["lista"]["total"]},
            "ligado": e["escudo"]["ligado"]}


def inicio():
    """O resumo de cada área (a página Início): rede, apps e integridade."""
    if DEMO:
        return demo_inicio()
    r = {"rede": None, "apps": None, "integridade": None}
    try:
        rd = S.rede()
        atual = rd["conexoes"][0] if rd["conexoes"] else None
        r["rede"] = {"firewall": rd["firewall"], "nome": atual["nome"] if atual else "",
                     "rede": atual["rede"] if atual else "", "tipo": atual["tipo"] if atual else ""}
    except Exception:  # noqa: BLE001 - o resumo nunca derruba a página
        pass
    try:
        a = S.apps()
        lista = a["apps"]
        r["apps"] = {"flatpak": a["flatpak"], "total": len(lista),
                     "camera": sum(1 for x in lista if x["permissoes"]["camera"]),
                     "microfone": sum(1 for x in lista if x["permissoes"]["microfone"]),
                     "localizacao": sum(1 for x in lista if x["permissoes"]["localizacao"]),
                     "arquivos": sum(1 for x in lista if x["permissoes"]["arquivos"])}
    except Exception:  # noqa: BLE001
        pass
    try:
        i = S.integridade()
        r["integridade"] = {"nivel": i["nivel"], "ok": sum(1 for x in i["itens"] if x["estado"] == "ok"),
                            "total": len(i["itens"]),
                            "atencao": [x["titulo"] for x in i["itens"] if x["estado"] == "atencao"]}
    except Exception:  # noqa: BLE001
        pass
    return r


# ======================================================================
# Verificações (manuais e do pendrive)
# ======================================================================
class Parar:
    def __init__(self):
        self.pedido = False
        signal.signal(signal.SIGTERM, self._sinal)
        signal.signal(signal.SIGINT, self._sinal)

    def _sinal(self, *_):
        self.pedido = True

    def __call__(self):
        return self.pedido


def verificar(tipo, caminhos, silencioso=False):
    """Uma linha JSON por passo: preparando, contando, verificando (feitos/total), fim."""
    parar = Parar()
    if DEMO:
        return demo_verificar(tipo, parar)
    if tipo == "rapida":
        raizes = N.raizes_rapida()
    elif tipo == "completa":
        raizes = N.raizes_completa()
    else:
        raizes = [os.path.abspath(c) for c in caminhos if os.path.exists(c)]
    inicio_t = time.time()
    nome_tipo = {"rapida": N.t("Verificação rápida", "Quick scan"), "completa": N.t("Verificação completa", "Full scan")}.get(
        tipo, N.t("Verificação de %s", "Scan of %s") % ", ".join(os.path.basename(r.rstrip("/")) or r for r in raizes))
    if not raizes:
        saida({"fase": "erro", "erro": N.t("Não há nada para verificar.", "There is nothing to scan.")})
        return 1
    saida({"fase": "preparando", "texto": N.t("Preparando o escudo...", "Getting the shield ready...")})
    try:
        clamd = N.ligar_clamd(avisar=lambda tx: saida({"fase": "preparando", "texto": tx}), parar=parar)
    except N.SemLista:
        saida({"fase": "erro", "erro": N.t("A lista de ameaças ainda não foi baixada.", "The threat list has not been downloaded yet."),
               "semLista": True})
        return 1
    except N.EscudoIndisponivel as erro:
        saida({"fase": "erro", "erro": str(erro)})
        return 1
    except InterruptedError:
        saida({"fase": "fim", "cancelada": True, "feitos": 0, "total": 0, "ameacas": [], "pulados": 0, "duracao": 0})
        return 0
    saida({"fase": "contando", "texto": N.t("Contando os arquivos...", "Counting files...")})
    lista, pulados = [], 0
    ultimo = 0
    for caminho, tamanho in N.arquivos_de(raizes, parar=parar, mesmo_disco=tipo != "caminho"):
        if tamanho > N.MAIOR_ARQUIVO or tamanho == 0:
            pulados += 1
            continue
        lista.append(caminho)
        if time.time() - ultimo > 0.25:
            ultimo = time.time()
            saida({"fase": "contando", "total": len(lista)})
    total = len(lista)
    ameacas, erros = [], 0
    feitos = 0
    ultimo = 0
    for caminho in lista:
        if parar():
            break
        try:
            resultado, nome = clamd.verificar(caminho)
        except OSError:
            # O clamd caiu ou foi desligado no meio: sobe de novo e continua.
            try:
                clamd = N.ligar_clamd(parar=parar)
                resultado, nome = clamd.verificar(caminho)
            except (OSError, N.EscudoIndisponivel, N.SemLista, InterruptedError):
                saida({"fase": "erro", "erro": N.t("O escudo parou no meio da verificação.", "The shield stopped in the middle of the scan.")})
                return 1
        feitos += 1
        if resultado == "FOUND":
            achado = {"nome": os.path.basename(caminho), "caminho": caminho, "ameaca": nome, "quarentena": False}
            try:
                sha = N.sha256_arquivo(caminho)
                if N.tem_excecao(sha):
                    continue
                N.quarentenar(caminho, nome, sha=sha)
                achado["quarentena"] = True
            except OSError:
                pass
            ameacas.append(achado)
            saida({"fase": "ameaca", **achado})
        elif resultado == "ERROR":
            erros += 1
        if time.time() - ultimo > 0.1 or feitos == total:
            ultimo = time.time()
            N.marcar_uso()
            saida({"fase": "verificando", "feitos": feitos, "total": total, "atual": os.path.basename(caminho)})
    duracao = int(time.time() - inicio_t)
    resumo = {"fase": "fim", "cancelada": parar(), "feitos": feitos, "total": total, "ameacas": ameacas,
              "pulados": pulados, "erros": erros, "duracao": duracao, "tipo": tipo}
    N.registrar("verificacao", nome_tipo, "", feitos=feitos, ameacas=len(ameacas), cancelada=parar() or None,
                duracao=duracao, tipoVerificacao=tipo)
    saida(resumo)
    if silencioso:
        if ameacas:
            N.avisar(N.t("Ameaça encontrada no pendrive", "Threat found on the USB drive"),
                     (N.t("1 arquivo foi para a quarentena.", "1 file was quarantined.") if len(ameacas) == 1 else N.t("%d arquivos foram para a quarentena.", "%d files were quarantined.") % len(ameacas)),
                     urgente=True, espera=20)
        else:
            N.avisar(N.t("Pendrive verificado", "USB drive scanned"),
                     N.t("Nenhuma ameaça em %s arquivos.", "No threats in %s files.") % feitos, espera=20)
    return 0


# ======================================================================
# O aviso de arquivo desconhecido
# ======================================================================
TIPOS_NOMES = {
    "appimage": ("App em AppImage", "AppImage app"), "elf": ("Programa para Linux", "Linux program"),
    "biblioteca": ("Biblioteca de programa", "Program library"), "script": ("Script do terminal", "Terminal script"),
    "instalador": ("Instalador (.run)", "Installer (.run)"), "deb": ("Pacote do Debian/Ubuntu", "Debian/Ubuntu package"),
    "rpm": ("Pacote RPM", "RPM package"), "windows": ("Programa do Windows", "Windows program"),
    "java": ("Programa em Java", "Java program"),
}


def examinar(caminho):
    tipo = N.tipo_arquivo(caminho)
    try:
        st = os.stat(caminho)
        tamanho = st.st_size
    except OSError:
        tamanho = 0
    o = N.origem(caminho)
    return {"caminho": caminho, "nome": os.path.basename(caminho), "pasta": os.path.dirname(caminho),
            "tipo": tipo, "tipoNome": N.t(*TIPOS_NOMES[tipo]) if tipo in TIPOS_NOMES else N.t("Arquivo", "File"),
            "tamanho": tamanho, "origem": o}


def aviso_info(caminho):
    """Tudo o que o aviso mostra (sem a verificação do escudo, que vem em aviso-verificar)."""
    if DEMO:
        return demo_aviso()
    caminho = os.path.abspath(caminho)
    if not os.path.isfile(caminho):
        return {"modo": "sumiu", "nome": os.path.basename(caminho)}
    info = examinar(caminho)
    try:
        info["sha256"] = N.sha256_arquivo(caminho)
    except OSError:
        info["sha256"] = ""
    info["conhecido"] = bool(info["sha256"]) and N.tem_excecao(info["sha256"])
    info["assinatura"] = N.assinatura(caminho, info["tipo"])
    estado_escudo = N.ler_config()
    info["escudoPausado"] = N.estado_pausa(estado_escudo)["pausado"] or not estado_escudo["ligado"]
    tipo = info["tipo"]
    if tipo in ("deb", "rpm"):
        info["modo"] = "pacote"
    elif tipo == "biblioteca":
        info["modo"] = "biblioteca"
    else:
        info["modo"] = "aviso"
    return info


def aviso_verificar(caminho):
    """O escudo confere o arquivo agora (sobe o clamd se precisar)."""
    if DEMO:
        time.sleep(1.2)
        return {"resultado": "OK", "ameaca": ""} if DEMO != "atencao" else \
            {"resultado": "FOUND", "ameaca": "Win.Trojan.Agent-1234"}
    try:
        clamd = N.ligar_clamd(tempo=120)
        resultado, nome = clamd.verificar(os.path.abspath(caminho))
    except N.SemLista:
        return {"resultado": "SEMLISTA", "ameaca": ""}
    except (N.EscudoIndisponivel, OSError, InterruptedError):
        return {"resultado": "INDISPONIVEL", "ameaca": ""}
    return {"resultado": resultado, "ameaca": nome if resultado == "FOUND" else ""}


def _inicio_processo():
    """pid,início,uid deste processo para o pkcheck (sem corrida com outro processo de mesmo pid)."""
    texto = N.ler("/proc/self/stat")
    resto = texto.rsplit(")", 1)[-1].split()
    inicio = resto[19] if len(resto) > 19 else ""
    return "%d,%s,%d" % (os.getpid(), inicio, os.getuid()) if inicio else str(os.getpid())


def confirmar_pessoa(nome):
    """A senha da própria pessoa pelo polkit (ação com auth_self): sem root."""
    if DEMO:
        time.sleep(1.0)
        return True, ""
    if not shutil.which("pkcheck"):
        return False, N.t("O polkit não está disponível para confirmar.", "polkit is not available to confirm.")
    codigo, _ = N.rodar(["pkcheck", "--action-id", "org.matsu.seguranca.liberar", "--process", _inicio_processo(),
                         "--allow-user-interaction", "--detail", "arquivo", nome], 600)
    if codigo == 0:
        return True, ""
    if codigo == 3:
        return False, N.t("Você fechou a confirmação.", "You closed the confirmation.")
    return False, N.t("A senha não foi confirmada.", "The password was not confirmed.")


def liberar(caminho):
    caminho = os.path.abspath(caminho)
    if DEMO:
        confirmar_pessoa("")
        return {"ok": True, "acao": "aberto"}
    if not os.path.isfile(caminho):
        return {"ok": False, "erro": N.t("O arquivo não está mais lá.", "The file is no longer there.")}
    ok, erro = confirmar_pessoa(os.path.basename(caminho))
    if not ok:
        return {"ok": False, "erro": erro, "cancelado": True}
    sha = N.sha256_arquivo(caminho)
    o = N.origem(caminho)
    N.por_excecao(sha, caminho, o["url"] or o["referencia"], "aberto mesmo assim")
    N.registrar("aviso-liberado", caminho, o["site"], sha256=sha)
    r = executar(examinar(caminho))
    r["ok"] = r.get("acao") == "aberto" or r.get("ok", False)
    return r


def quarentenar_arquivo(caminho, ameaca=""):
    if DEMO:
        return {"ok": True}
    try:
        N.quarentenar(os.path.abspath(caminho), ameaca or N.t("Arquivo desconhecido", "Unknown file"))
        return {"ok": True}
    except OSError as erro:
        return {"ok": False, "erro": erro.strerror or str(erro)}


# ----- abrir de verdade (depois do aviso, ou quando não precisa de aviso) -----
def pastas_apps():
    base = [os.path.join(N.dados_casa(), "applications"), "/usr/local/share/applications", "/usr/share/applications",
            os.path.join(S.flatpak_usuario(), "exports", "share", "applications"),
            os.path.join(S.FLATPAK_SISTEMA, "exports", "share", "applications")]
    return [p for p in base if os.path.isdir(p)]


def ler_desktop(caminho):
    valores, dentro = {}, False
    for linha in N.ler(caminho).splitlines():
        linha = linha.strip()
        if linha.startswith("["):
            dentro = linha == "[Desktop Entry]"
            continue
        if dentro and "=" in linha:
            k, _, v = linha.partition("=")
            valores.setdefault(k.strip(), v.strip())
    return valores


def achar_desktop(ident):
    for pasta in pastas_apps():
        caminho = os.path.join(pasta, ident)
        if os.path.isfile(caminho):
            return caminho
    return ""


def comando_desktop(caminho, arquivo):
    """O Exec do .desktop com o arquivo no lugar de %f/%u (os outros códigos saem)."""
    d = ler_desktop(caminho)
    try:
        partes = shlex.split(d.get("Exec", ""))
    except ValueError:
        return []
    cmd = []
    for p in partes:
        if p in ("%f", "%F", "%u", "%U"):
            cmd.append(arquivo)
        elif re.fullmatch(r"%[a-zA-Z]", p):
            continue
        else:
            cmd.append(p.replace("%%", "%"))
    if arquivo not in cmd:
        cmd.append(arquivo)
    return cmd


def nosso(ident):
    return ident.startswith("org.matsu.seguranca")


def app_padrao(tipos):
    """O app padrão destes tipos (mimeapps.list), sem ser o nosso."""
    arquivos = [os.path.join(N.config_casa(), "mimeapps.list"), os.path.join(N.config_casa(), "kde-mimeapps.list"),
                "/etc/xdg/mimeapps.list", "/etc/xdg/kde-mimeapps.list",
                os.path.join(N.dados_casa(), "applications", "mimeapps.list"), "/usr/share/applications/mimeapps.list"]
    for tipo in tipos:
        for arq in arquivos:
            dentro = False
            for linha in N.ler(arq).splitlines():
                linha = linha.strip()
                if linha.startswith("["):
                    dentro = linha == "[Default Applications]"
                    continue
                if dentro and linha.startswith(tipo + "="):
                    for ident in linha.split("=", 1)[1].split(";"):
                        ident = ident.strip()
                        if ident and not nosso(ident) and achar_desktop(ident):
                            return achar_desktop(ident)
    return ""


TIPOS_WINDOWS = ("application/x-msdownload", "application/x-ms-dos-executable", "application/vnd.microsoft.portable-executable",
                 "application/x-msi", "application/x-dosexec", "application/x-wine-extension-msp")


def app_do_windows():
    """Bottles (pela Loja) ou o Wine, se estiverem instalados."""
    preferidos = ("com.usebottles.bottles.desktop", "wine.desktop", "org.winehq.Wine.desktop")
    for ident in preferidos:
        caminho = achar_desktop(ident)
        if caminho:
            return caminho
    for pasta in pastas_apps():
        try:
            nomes = sorted(os.listdir(pasta))
        except OSError:
            continue
        for nome in nomes:
            if nome.endswith(".desktop") and not nosso(nome):
                d = ler_desktop(os.path.join(pasta, nome))
                if any(tp in d.get("MimeType", "").split(";") for tp in TIPOS_WINDOWS):
                    return os.path.join(pasta, nome)
    return ""


def tornar_executavel(caminho):
    try:
        st = os.stat(caminho)
        os.chmod(caminho, stat.S_IMODE(st.st_mode) | stat.S_IXUSR)
        return True
    except OSError:
        return False


def no_terminal(caminho):
    pasta = os.path.dirname(caminho)
    comeco = N._cabeca(caminho, 2)
    programa = [caminho] if comeco == b"#!" or comeco[:1] == b"\x7f" else ["sh", caminho]
    if shutil.which("matsu-terminal"):
        return N.soltar(["matsu-terminal", "--hold", "--workdir", pasta, "-e"] + programa, pasta)
    if shutil.which("konsole"):
        return N.soltar(["konsole", "--hold", "--workdir", pasta, "-e"] + programa, pasta)
    return False


def executar(info):
    """O que a pessoa esperava ao abrir o arquivo. {"acao": "aberto" | "loja-windows" | "java" | ...}."""
    caminho, tipo = info["caminho"], info["tipo"]
    if tipo in ("appimage", "elf"):
        tornar_executavel(caminho)
        return {"acao": "aberto" if N.soltar([caminho], os.path.dirname(caminho)) else "erro"}
    if tipo in ("script", "instalador"):
        tornar_executavel(caminho)
        return {"acao": "aberto" if no_terminal(caminho) else "erro"}
    if tipo == "windows":
        app = app_do_windows()
        if app:
            return {"acao": "aberto" if N.soltar(comando_desktop(app, caminho), os.path.dirname(caminho)) else "erro"}
        return {"acao": "sem-windows"}
    if tipo == "java":
        if shutil.which("java"):
            return {"acao": "aberto" if N.soltar(["java", "-jar", caminho], os.path.dirname(caminho)) else "erro"}
        return {"acao": "sem-java"}
    if tipo in ("deb", "rpm"):
        return {"acao": "pacote"}
    return {"acao": "erro"}


def abrir_aviso(caminho):
    return N.soltar([N.MATSU_JANELA, N.ID_APP + ".aviso", N.AVISO_QML, caminho])


def abrir(caminho):
    """O tratador: decide se precisa do aviso. Arquivo local da pessoa abre direto;
    o que veio da internet e não está na lista de exceções passa pelo aviso."""
    caminho = os.path.abspath(caminho)
    if not os.path.isfile(caminho):
        abrir_aviso(caminho)
        return 0
    info = examinar(caminho)
    tipo = info["tipo"]
    if tipo in ("deb", "rpm", "biblioteca"):
        abrir_aviso(caminho)
        return 0
    if tipo == "script" and not info["origem"]["internet"]:
        # Script da pessoa: abre no editor, como sempre (nada de aviso).
        app = app_padrao(["application/x-shellscript", "text/x-sh", "text/plain"])
        if app:
            N.soltar(comando_desktop(app, caminho), os.path.dirname(caminho))
        return 0
    if not info["origem"]["internet"]:
        r = executar(info)
        if r["acao"] != "aberto":
            abrir_aviso(caminho)
        return 0
    try:
        sha = N.sha256_arquivo(caminho)
    except OSError:
        sha = ""
    if sha and N.tem_excecao(sha):
        r = executar(info)
        if r["acao"] != "aberto":
            abrir_aviso(caminho)
        return 0
    abrir_aviso(caminho)
    return 0


def loja(app):
    """Abre a Loja na página do app (ou no início, com "inicio")."""
    pedido = ["inicio"] if app in ("", "inicio") else ["app", app]
    N.soltar([N.MATSU_JANELA, "org.matsu.loja", "/usr/share/matsu/loja/Main.qml"] + pedido)
    return {"ok": True}


# ======================================================================
# Dados de mentira (MATSU_SEGURANCA_DEMO), para as fotos da prévia
# ======================================================================
def demo_estado():
    agora = time.time()
    geral = {"protegido": "protegido", "atencao": "atencao", "pausado": "pausado", "baixando": "baixando"}.get(DEMO, "protegido")
    pastas = N.pastas_usuario()
    novas = 1 if geral == "atencao" else 0
    return {
        "idioma": N.idioma(), "vidro": N.vidro(), "geral": geral, "instalado": True,
        "escudo": {"ligado": True, "pausado": geral == "pausado", "pausaAte": agora + 11 * 60 + 40 if geral == "pausado" else 0,
                   "pausaReiniciar": False, "servico": True, "clamd": "parado", "fila": 0, "verificados": 214,
                   "jogo": False, "pendentes": 0,
                   "pastas": [{"id": k, "caminho": v, "nome": os.path.basename(v.rstrip("/"))} for k, v in pastas.items() if v]},
        "lista": {"presente": geral != "baixando", "versao": 27827, "data": agora - 3 * 3600, "assinaturas": 3627519,
                  "baixando": geral == "baixando", "baixado": 96 * 1024 * 1024, "total": N.TAMANHO_LISTA, "erro": False},
        "ajustes": {"ligado": True, "pendrive_auto": False, "esperar_jogo": True},
        "contagem": {"quarentena": 2 if geral == "atencao" else 1, "excecoes": 2, "novas": novas,
                     "ameacas30": 2 if geral == "atencao" else 1,
                     "ultimaVerificacao": {"tipo": "verificacao", "nome": "Verificação rápida", "data": agora - 26 * 3600,
                                           "feitos": 1284, "ameacas": 0}},
    }


def demo_inicio():
    return {"rede": {"firewall": "ligado", "nome": "Casa 5G", "rede": "casa", "tipo": "wifi"},
            "apps": {"flatpak": True, "total": 14, "camera": 2, "microfone": 4, "localizacao": 1, "arquivos": 6},
            "integridade": {"nivel": "ok" if DEMO != "atencao" else "atencao", "ok": 5, "total": 6,
                            "atencao": [] if DEMO != "atencao" else ["Atualizações automáticas desligadas"]}}


def demo_rede():
    servicos = []
    ligados = {"steam-streaming", "steam-lan-transfer", "kdeconnect", "mdns", "ipp-client", "samba-client", "upnp-client"}
    for s in S.SERVICOS_CASA:
        servicos.append({"id": s["id"], "nome": S._texto(s["nome"]), "texto": S._texto(s["texto"]), "icone": s["icone"],
                         "reserva": s["reserva"], "ligado": s["id"] in ligados})
    return {"firewall": "ligado", "padrao": "matsu-publica", "padraoMatsu": True, "zonasMatsu": True, "nm": True,
            "conexoes": [{"nome": "Casa 5G", "uuid": "8c2a6a3e-6f0b-4e7a-9c1d-2b9f0d4f1a77", "tipo": "wifi",
                          "dispositivo": "wlp4s0", "zona": "matsu-casa", "efetiva": "matsu-casa", "rede": "casa"}],
            "servicos": servicos, "casaMudada": False}


def demo_apps():
    def p(cam=False, mic=False, loc=False, arq=False, rede=True, notif=True, texto=""):
        return {"camera": cam, "cameraTodos": False, "microfone": mic, "localizacao": loc, "localPergunta": not loc,
                "arquivos": arq, "arquivosTexto": texto or (N.t("A pasta pessoal inteira", "Your whole home folder") if arq else
                                                            N.t("Só os arquivos que você escolher", "Only the files you pick")),
                "rede": rede, "notificacoes": notif}
    lista = [
        ("com.discordapp.Discord", "Discord", p(True, True, False, False), True),
        ("com.heroicgameslauncher.hgl", "Heroic Games Launcher", p(False, True, False, True), False),
        ("com.obsproject.Studio", "OBS Studio", p(True, True, False, True), False),
        ("com.spotify.Client", "Spotify", p(False, True, False, False, texto=N.t("Músicas", "Music")), False),
        ("net.lutris.Lutris", "Lutris", p(False, True, False, True), False),
        ("org.kde.kdenlive", "Kdenlive", p(False, True, False, True), False),
        ("org.mozilla.firefox", "Firefox", p(False, True, True, False, texto="Downloads"), False),
        ("org.telegram.desktop", "Telegram", p(False, True, False, False, texto="Downloads"), False),
    ]
    apps = []
    for ident, nome, perms, mudado in lista:
        apps.append({"id": ident, "nome": nome, "instalacao": "sistema", "icone": S.icone_flatpak(ident), "mudado": mudado,
                     "permissoes": perms, "padrao": perms})
    return {"flatpak": True, "apps": apps, "semCaixa": [{"nome": "Steam", "icone": "steam"},
                                                       {"nome": "Visual Studio Code", "icone": "code"}]}


def demo_integridade():
    i = [
        S.item("assinatura", "ok", N.t("Sistema assinado e conferido", "Signed and verified system"),
               N.t("Cada atualização só entra se tiver a assinatura do Matsu. Uma versão mexida no caminho seria recusada.",
                   "Each update only goes in with Matsu's signature. A version tampered with on the way would be refused."),
               "ghcr.io/kaikyolf29-hub/matsu-os:latest"),
        S.item("leitura", "ok", N.t("Arquivos do sistema protegidos", "System files protected"),
               N.t("A pasta do sistema só pode ser lida. Nenhum programa consegue mudar o Matsu por dentro: o que muda vem pela atualização assinada.",
                   "The system folder is read-only. No program can change Matsu from the inside: changes only come through the signed update.")),
        S.item("secureboot", "ok", "Secure Boot",
               N.t("O computador só liga com um sistema assinado: um programa malicioso não consegue se esconder antes do Matsu começar.",
                   "The computer only starts a signed system: malware cannot hide before Matsu starts.")),
        S.item("disco", "desligado", N.t("Disco sem criptografia", "Disk not encrypted"),
               N.t("Quem tirar o disco deste computador consegue ler os arquivos. A criptografia só pode ser ligada ao instalar o Matsu.",
                   "Whoever removes this computer's disk can read the files. Encryption can only be turned on when installing Matsu.")),
        S.item("atualizacoes", "ok" if DEMO != "atencao" else "atencao",
               N.t("Atualizações automáticas ligadas", "Automatic updates on") if DEMO != "atencao" else N.t("Atualizações automáticas desligadas", "Automatic updates off"),
               N.t("O Matsu baixa as correções sozinho e elas entram quando você reinicia.",
                   "Matsu downloads fixes by itself and they apply when you restart."), "rpm-ostree"),
        S.item("flatpak", "ok", N.t("Lojas de apps conferidas", "App sources verified"),
               N.t("Todo app que vem da Loja tem a assinatura conferida (GPG) antes de instalar.",
                   "Every app from the Store has its signature (GPG) checked before installing."), "flathub"),
    ]
    return {"itens": i, "nivel": "ok" if DEMO != "atencao" else "atencao", "atomico": True}


def demo_historico():
    agora = time.time()
    quarentena = [{"id": "18f2c1a90b11", "nome": "Instalador-Jogo-Gratis.exe",
                   "origem": os.path.join(N.pastas_usuario()["downloads"], "Instalador-Jogo-Gratis.exe"),
                   "url": "https://gratis-download.example/jogo", "sha256": "4f" * 32, "ameaca": "Win.Trojan.Agent-1234",
                   "data": agora - 40 * 60, "tamanho": 3_481_212}]
    if DEMO == "atencao":
        quarentena.insert(0, {"id": "18f2c1a90c22", "nome": "crack-photoshop.zip",
                              "origem": os.path.join(N.pastas_usuario()["downloads"], "crack-photoshop.zip"),
                              "url": "", "sha256": "9a" * 32, "ameaca": "Win.Malware.Keygen-51", "data": agora - 3 * 60,
                              "tamanho": 12_388_001})
    excecoes = [{"sha256": "c3d9" * 16, "nome": "Minecraft-Launcher.AppImage", "url": "https://launcher.example/",
                 "motivo": "aberto mesmo assim", "data": agora - 5 * 86400},
                {"sha256": "77ab" * 16, "nome": "instalar-driver.run", "url": "", "motivo": "restaurado",
                 "data": agora - 12 * 86400}]
    eventos = [
        {"id": "a1", "tipo": "quarentena", "nome": "Instalador-Jogo-Gratis.exe", "detalhe": "Win.Trojan.Agent-1234", "data": agora - 40 * 60},
        {"id": "a2", "tipo": "verificacao", "nome": N.t("Verificação rápida", "Quick scan"), "feitos": 1284, "ameacas": 0, "data": agora - 26 * 3600},
        {"id": "a3", "tipo": "pendrive", "nome": "KINGSTON", "detalhe": "", "data": agora - 2 * 86400},
        {"id": "a4", "tipo": "aviso-bloqueado", "nome": "setup-premium.AppImage", "detalhe": "free-apps.example", "data": agora - 3 * 86400},
        {"id": "a5", "tipo": "aviso-liberado", "nome": "Minecraft-Launcher.AppImage", "detalhe": "launcher.example", "data": agora - 5 * 86400},
        {"id": "a6", "tipo": "volta", "nome": "", "detalhe": "", "data": agora - 6 * 86400},
    ]
    if DEMO == "atencao":
        eventos.insert(0, {"id": "a0", "tipo": "quarentena", "nome": "crack-photoshop.zip", "detalhe": "Win.Malware.Keygen-51", "data": agora - 3 * 60})
    return {"eventos": eventos, "quarentena": quarentena, "excecoes": excecoes}


def demo_aviso():
    downloads = N.pastas_usuario()["downloads"]
    ameaca = DEMO == "atencao"
    nome = "Instalador-Jogo-Gratis.AppImage"
    return {"modo": "aviso", "caminho": os.path.join(downloads, nome), "nome": nome, "pasta": downloads,
            "tipo": "appimage", "tipoNome": N.t("App em AppImage", "AppImage app"), "tamanho": 148_336_640,
            "origem": {"url": "https://gratis-download.example/apps/instalador", "referencia": "", "site": "gratis-download.example",
                       "downloads": True, "internet": True},
            "sha256": "8e3b0f1c4d2a99b7f61e05c3a8d4e2f7b19c6a0d3e5f7a8b9c1d2e3f4a5b6c7d", "conhecido": False,
            "assinatura": "nao", "escudoPausado": False, "demoAmeaca": ameaca}


def demo_verificar(tipo, parar):
    saida({"fase": "preparando", "texto": N.t("Preparando o escudo...", "Getting the shield ready...")})
    time.sleep(1.0)
    total = 1284 if tipo != "completa" else 48210
    saida({"fase": "contando", "total": total})
    time.sleep(0.4)
    nomes = ["Minecraft-Launcher.AppImage", "fotos-ferias.zip", "Instalador-Jogo-Gratis.exe", "relatorio.pdf", "musica.flac"]
    passos = 60
    ameacas = []
    for i in range(1, passos + 1):
        if parar():
            break
        feitos = int(total * i / passos)
        saida({"fase": "verificando", "feitos": feitos, "total": total, "atual": nomes[i % len(nomes)]})
        if DEMO == "atencao" and i == passos // 2:
            a = {"nome": "Instalador-Jogo-Gratis.exe", "caminho": "", "ameaca": "Win.Trojan.Agent-1234", "quarentena": True}
            ameacas.append(a)
            saida({"fase": "ameaca", **a})
        time.sleep(float(os.environ.get("MATSU_SEGURANCA_DEMO_PASSO", "0.12")))
    saida({"fase": "fim", "cancelada": parar(), "feitos": total if not parar() else feitos, "total": total,
           "ameacas": ameacas, "pulados": 12, "erros": 0, "duracao": 8, "tipo": tipo})
    return 0


def demo_fsck():
    passos = [("refs", N.t("Conferindo as versões do sistema...", "Checking system versions...")),
              ("commits", N.t("Listando o que conferir...", "Listing what to check..."))]
    for fase, texto in passos:
        saida({"fase": fase, "texto": texto})
        time.sleep(0.6)
    total = 182344
    for i in range(1, 41):
        saida({"fase": "objetos", "feitos": int(total * i / 40), "total": total,
               "texto": N.t("Conferindo os arquivos do sistema...", "Checking system files...")})
        time.sleep(0.1)
    saida({"fase": "fim", "ok": True, "erros": 0, "duracao": 74})
    return 0


# ======================================================================
# Verificar os arquivos do sistema (ostree fsck, pelo pkexec)
# ======================================================================
def fsck():
    if DEMO:
        return demo_fsck()
    script = "/usr/libexec/matsu/matsu-seguranca-fsck"
    if not shutil.which("pkexec") or not os.path.exists(script):
        saida({"fase": "erro", "erro": N.t("Não dá para verificar aqui (falta o pkexec ou o ostree).",
                                            "Cannot check here (pkexec or ostree is missing).")})
        return 1
    import subprocess
    inicio_t = time.time()
    saida({"fase": "refs", "texto": N.t("Começando...", "Starting...")})
    try:
        p = subprocess.Popen(["pkexec", script], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                             errors="replace", bufsize=1)
    except OSError as erro:
        saida({"fase": "erro", "erro": str(erro)})
        return 1
    parar = Parar()
    erros = 0
    codigo_fim = None
    for linha in p.stdout:
        if parar():
            p.terminate()
            break
        linha = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", linha).strip()
        if not linha:
            continue
        if linha.startswith("FIM "):
            codigo_fim = int(linha.split()[1]) if linha.split()[1].lstrip("-").isdigit() else 1
            continue
        if linha.startswith("ERRO "):
            saida({"fase": "erro", "erro": N.t("Este computador não usa o sistema atômico (ostree).",
                                                "This computer does not use the atomic system (ostree).")})
            return 1
        m = re.search(r"(\d+)\s*/\s*(\d+)", linha)
        if m and int(m.group(2)) > 0:
            saida({"fase": "objetos", "feitos": int(m.group(1)), "total": int(m.group(2)),
                   "texto": N.t("Conferindo os arquivos do sistema...", "Checking system files...")})
        elif "Validating refs" in linha:
            saida({"fase": "refs", "texto": N.t("Conferindo as versões do sistema...", "Checking system versions...")})
        elif "Enumerating" in linha or "Verifying content integrity" in linha:
            saida({"fase": "commits", "texto": N.t("Conferindo os arquivos do sistema...", "Checking system files...")})
        elif re.search(r"error|corrupt|invalid", linha, re.I):
            erros += 1
    codigo = p.wait()
    if codigo in (126, 127) and codigo_fim is None:
        saida({"fase": "erro", "erro": N.t("A permissão não foi dada.", "Permission was not granted."), "cancelado": True})
        return 1
    ok = (codigo_fim if codigo_fim is not None else codigo) == 0 and erros == 0
    duracao = int(time.time() - inicio_t)
    N.registrar("fsck", N.t("Arquivos do sistema", "System files"), "", ok=ok, duracao=duracao)
    saida({"fase": "fim", "ok": ok, "erros": erros, "duracao": duracao, "cancelada": parar()})
    return 0


# ======================================================================
def principal(argv):
    if not argv:
        print(__doc__)
        return 2
    cmd, args = argv[0], argv[1:]
    if cmd == "estado":
        saida(estado())
    elif cmd == "vigiar":
        intervalo = float(args[0]) if args else 1.5
        try:
            while True:
                saida(estado())
                time.sleep(intervalo)
        except (BrokenPipeError, KeyboardInterrupt):
            return 0
    elif cmd == "inicio":
        saida(inicio())
    elif cmd == "bandeja":
        saida(bandeja())
    elif cmd in ("pausar", "retomar"):
        if DEMO:
            saida({"ok": True})
            return 0
        c = N.ler_config()
        c = N.pausar(c, args[0] if args else "15") if cmd == "pausar" else N.retomar(c)
        N.gravar_config(c)
        N.registrar("pausa" if cmd == "pausar" else "volta", "", args[0] if args and cmd == "pausar" else "")
        saida({"ok": True})
    elif cmd == "ajuste" and len(args) == 2 and args[0] in ("ligado", "pendrive_auto", "esperar_jogo"):
        if not DEMO:
            c = N.ler_config()
            c[args[0]] = args[1] == "sim"
            if args[0] == "ligado" and c["ligado"]:
                c = N.retomar(c)
            N.gravar_config(c)
        saida({"ok": True})
    elif cmd == "atualizar-lista":
        saida({"ok": True if DEMO else N.iniciar_unidade(N.UNIDADE_ATUALIZAR)})
    elif cmd == "verificar" and args:
        silencioso = "--silencioso" in args
        args = [a for a in args if a != "--silencioso"]
        return verificar(args[0], args[1:] if args[0] == "caminho" else [], silencioso)
    elif cmd == "historico":
        if DEMO:
            saida(demo_historico())
        else:
            saida({"eventos": N.ler_historico()[:200], "quarentena": N.listar_quarentena(), "excecoes": N.ler_excecoes()})
    elif cmd == "visto":
        if not DEMO:
            c = N.ler_config()
            c["visto_ate"] = int(time.time())
            N.gravar_config(c)
        saida({"ok": True})
    elif cmd == "restaurar" and args:
        try:
            saida({"ok": True} if DEMO else N.restaurar(args[0]))
        except (OSError, ValueError) as erro:
            saida({"ok": False, "erro": str(erro)})
    elif cmd == "apagar" and args:
        saida({"ok": True if DEMO else N.apagar_quarentena(args[0])})
    elif cmd == "excecao-tirar" and args:
        saida({"ok": True if DEMO else N.tirar_excecao(args[0])})
    elif cmd == "rede":
        saida(demo_rede() if DEMO else S.rede())
    elif cmd == "rede-tipo" and len(args) == 2:
        saida({"ok": True} if DEMO else S.trocar_tipo(args[0], args[1]))
    elif cmd == "rede-servico" and len(args) == 2:
        saida({"ok": True} if DEMO else S.servico_casa(args[0], args[1] == "sim"))
    elif cmd == "rede-padrao":
        saida({"ok": True} if DEMO else S.usar_padrao_matsu())
    elif cmd == "firewall-ligar":
        saida({"ok": True} if DEMO else S.ligar_firewall())
    elif cmd == "apps":
        saida(demo_apps() if DEMO else S.apps())
    elif cmd == "app-permissao" and len(args) == 3:
        saida({"ok": True} if DEMO else S.mudar_permissao(args[0], args[1], args[2] == "sim"))
    elif cmd == "app-padrao" and args:
        saida({"ok": True} if DEMO else S.voltar_padrao(args[0]))
    elif cmd == "integridade":
        saida(demo_integridade() if DEMO else S.integridade())
    elif cmd == "fsck":
        return fsck()
    elif cmd == "abrir" and args:
        return abrir(args[0])
    elif cmd == "aviso-info" and args:
        saida(aviso_info(args[0]))
    elif cmd == "aviso-verificar" and args:
        saida(aviso_verificar(args[0]))
    elif cmd == "liberar" and args:
        saida(liberar(args[0]))
    elif cmd == "quarentenar" and args:
        saida(quarentenar_arquivo(args[0], args[1] if len(args) > 1 else ""))
    elif cmd == "nao-abrir" and args:
        if not DEMO:
            o = N.origem(args[0])
            N.registrar("aviso-bloqueado", args[0], o["site"])
        saida({"ok": True})
    elif cmd == "loja" and args:
        saida(loja(args[0]))
    elif cmd == "central":
        N.abrir_central(*args)
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(principal(sys.argv[1:]))
    except BrokenPipeError:
        sys.exit(0)
