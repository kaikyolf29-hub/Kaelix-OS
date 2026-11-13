#!/usr/bin/python3
"""Escudo em tempo real do Matsu: o serviço do usuário (matsu-escudo.service).

Vigia as pastas onde chegam arquivos de fora (Downloads e Área de trabalho, com
os nomes de verdade do user-dirs.dirs) pelo inotify do kernel, e os pendrives
que a pessoa liga (/run/media/<pessoa>/...). Quando um download termina (o
navegador troca o .crdownload/.part pelo nome final), o arquivo vai para o
clamd pelo soquete local; se tiver ameaça, vai para a quarentena e aparece o
aviso. O clamd sobe só quando há o que verificar e desce depois de 10 minutos
parado: num PC de jogo, 1 GB de memória parado faz falta.

Não vigia o /tmp, a pasta da Steam nem os jogos (veja docs/SEGURANCA.md).
Roda como a própria pessoa; só a biblioteca padrão do Python (inotify por ctypes).
"""
import ctypes
import ctypes.util
import errno
import os
import queue
import re
import select
import struct
import subprocess
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nucleo as N  # noqa: E402

AJUDANTE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ajudante.py")

IN_CLOSE_WRITE = 0x00000008
IN_MOVED_TO = 0x00000080
IN_CREATE = 0x00000100
IN_DELETE_SELF = 0x00000400
IN_MOVE_SELF = 0x00000800
IN_Q_OVERFLOW = 0x00004000
IN_IGNORED = 0x00008000
IN_ONLYDIR = 0x01000000
IN_ISDIR = 0x40000000
IN_NONBLOCK = 0o4000
IN_CLOEXEC = 0o2000000

MASCARA_PASTA = IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE | IN_DELETE_SELF | IN_MOVE_SELF | IN_ONLYDIR
PROFUNDIDADE = 2          # Downloads/pasta/subpasta
MAX_VIGIAS = 600
ESPERA_ESTAVEL = 2.0      # o arquivo tem que ficar parado 2 s antes de verificar
MAX_PENDENTES = 300


class Inotify:
    def __init__(self):
        try:
            libc = ctypes.CDLL("libc.so.6", use_errno=True)
        except OSError:
            libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
        self._add = libc.inotify_add_watch
        self._add.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
        self._rm = libc.inotify_rm_watch
        self._rm.argtypes = [ctypes.c_int, ctypes.c_int]
        self.fd = libc.inotify_init1(IN_NONBLOCK | IN_CLOEXEC)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), "inotify_init1")
        self.pastas = {}   # wd -> caminho
        self.wds = {}      # caminho -> wd

    def vigiar(self, caminho, mascara=MASCARA_PASTA):
        if caminho in self.wds:
            return self.wds[caminho]
        wd = self._add(self.fd, os.fsencode(caminho), mascara)
        if wd < 0:
            return -1
        self.pastas[wd] = caminho
        self.wds[caminho] = wd
        return wd

    def esquecer(self, wd):
        caminho = self.pastas.pop(wd, None)
        if caminho:
            self.wds.pop(caminho, None)

    def esquecer_tudo(self):
        for wd in list(self.pastas):
            self._rm(self.fd, wd)
        self.pastas.clear()
        self.wds.clear()

    def ler(self):
        """[(caminho da pasta, nome, máscara)]."""
        eventos = []
        try:
            dados = os.read(self.fd, 64 * 1024)
        except OSError as e:
            if e.errno in (errno.EAGAIN, errno.EINTR):
                return eventos
            raise
        i = 0
        while i + 16 <= len(dados):
            wd, mascara, _cookie, tamanho = struct.unpack_from("iIII", dados, i)
            nome = dados[i + 16:i + 16 + tamanho].split(b"\0", 1)[0]
            i += 16 + tamanho
            eventos.append((self.pastas.get(wd, ""), os.fsdecode(nome), mascara, wd))
        return eventos


class Escudo:
    def __init__(self):
        self.cfg = N.ler_config()
        self.trava = threading.Lock()
        self.fila = {}            # caminho -> (hora em que pode verificar, tamanho, mtime)
        self.pendentes = set()    # chegaram com o escudo pausado
        self.trabalho = queue.Queue()
        self.ocupado = False
        self.verificados = 0
        self.clamd = "parado"
        self.jogo = False
        self.lista_faltando_desde = 0
        self.ultima_batida = 0
        self.ultimo_ocioso = 0
        self.ultimo_jogo = 0
        self.montados = set()
        self.ino = Inotify()
        self.pastas_vigiadas = []
        self.config_dir = os.path.dirname(N.arquivo_config())

    # ----- estado para a janela e a bandeja -----
    def gravar_estado(self, forcar=False):
        agora = time.time()
        if not forcar and agora - self.ultima_batida < 10:
            return
        self.ultima_batida = agora
        with self.trava:
            dados = {"pid": os.getpid(), "batida": int(agora), "clamd": self.clamd, "fila": len(self.fila),
                     "verificados": self.verificados, "jogo": self.jogo, "pendentes": len(self.pendentes),
                     "pastas": self.pastas_vigiadas}
        try:
            N.gravar_json(N.arquivo_escudo(), dados)
        except OSError:
            pass

    # ----- pastas -----
    def montar_vigias(self):
        self.ino.esquecer_tudo()
        p = N.pastas_usuario()
        self.pastas_vigiadas = [x for x in (p["downloads"], p["area"]) if x and os.path.isdir(x)]
        for raiz in self.pastas_vigiadas:
            self._vigiar_arvore(raiz, 0)
        N.criar_pasta(self.config_dir, 0o755)
        self.ino.vigiar(self.config_dir, IN_CLOSE_WRITE | IN_MOVED_TO | IN_ONLYDIR)

    def _vigiar_arvore(self, pasta, nivel):
        if len(self.ino.wds) >= MAX_VIGIAS or self.ino.vigiar(pasta) < 0:
            return
        if nivel >= PROFUNDIDADE:
            return
        try:
            for e in os.scandir(pasta):
                if e.is_dir(follow_symlinks=False) and not e.name.startswith(".") and e.name not in N.PULAR_NOMES:
                    self._vigiar_arvore(e.path, nivel + 1)
        except OSError:
            pass

    def _nivel(self, pasta):
        for raiz in self.pastas_vigiadas:
            if N.dentro_de(pasta, raiz):
                return os.path.relpath(pasta, raiz).count("/") + (0 if os.path.normpath(pasta) == os.path.normpath(raiz) else 1)
        return PROFUNDIDADE

    # ----- eventos -----
    def tratar(self, pasta, nome, mascara):
        if mascara & IN_Q_OVERFLOW:
            return
        if pasta == self.config_dir:
            if nome == os.path.basename(N.arquivo_config()):
                self.recarregar_config()
            return
        if mascara & (IN_DELETE_SELF | IN_MOVE_SELF | IN_IGNORED):
            return
        if not nome or not pasta:
            return
        caminho = os.path.join(pasta, nome)
        if mascara & IN_ISDIR:
            if mascara & (IN_CREATE | IN_MOVED_TO) and not nome.startswith(".") and nome not in N.PULAR_NOMES:
                nivel = self._nivel(caminho)
                if nivel <= PROFUNDIDADE:
                    self._vigiar_arvore(caminho, nivel)
                if mascara & IN_MOVED_TO:
                    # Uma pasta inteira chegou (extraída ou movida): os arquivos dela também.
                    for arq, _t in N.arquivos_de([caminho], pular=[]):
                        if not N.e_temporario(arq):
                            self.enfileirar(arq)
            return
        if mascara & (IN_CLOSE_WRITE | IN_MOVED_TO) and not N.e_temporario(nome):
            self.enfileirar(caminho)

    def enfileirar(self, caminho):
        if not self.cfg["ligado"]:
            return
        if N.estado_pausa(self.cfg)["pausado"]:
            if len(self.pendentes) < MAX_PENDENTES:
                self.pendentes.add(caminho)
            return
        try:
            st = os.stat(caminho)
        except OSError:
            return
        if st.st_size == 0 or st.st_size > N.MAIOR_ARQUIVO:
            return
        with self.trava:
            self.fila[caminho] = (time.time() + ESPERA_ESTAVEL, st.st_size, st.st_mtime)

    def andar_fila(self):
        """Manda para o trabalhador o que já ficou parado o bastante."""
        if not self.fila or self.ocupado:
            return
        if self.cfg["esperar_jogo"] and self.jogo:
            return
        agora = time.time()
        prontos = []
        with self.trava:
            for caminho, (hora, tamanho, mtime) in list(self.fila.items()):
                if hora > agora:
                    continue
                try:
                    st = os.stat(caminho)
                except OSError:
                    del self.fila[caminho]
                    continue
                if st.st_size != tamanho or st.st_mtime != mtime:
                    # Ainda mudando (cópia lenta): espera mais um pouco.
                    self.fila[caminho] = (agora + ESPERA_ESTAVEL, st.st_size, st.st_mtime)
                    continue
                del self.fila[caminho]
                prontos.append(caminho)
        if prontos:
            self.ocupado = True
            self.trabalho.put(prontos)

    # ----- o trabalhador (verifica sem travar a vigia) -----
    def trabalhador(self):
        while True:
            lista = self.trabalho.get()
            try:
                self.verificar_lista(lista)
            except Exception as erro:  # noqa: BLE001 - o escudo não pode cair por um arquivo
                print("escudo: erro ao verificar: %s" % erro, file=sys.stderr, flush=True)
            finally:
                self.ocupado = False

    def verificar_lista(self, lista):
        try:
            self.clamd = "subindo"
            self.gravar_estado(True)
            c = N.ligar_clamd()
            self.clamd = "pronto"
            self.lista_faltando_desde = 0
        except N.SemLista:
            self.clamd = "sem-lista"
            if not self.lista_faltando_desde:
                self.lista_faltando_desde = time.time()
                N.iniciar_unidade(N.UNIDADE_ATUALIZAR)
            with self.trava:
                for caminho in lista:
                    if len(self.pendentes) < MAX_PENDENTES:
                        self.pendentes.add(caminho)
            return
        except (N.EscudoIndisponivel, OSError) as erro:
            self.clamd = "erro"
            print("escudo: %s" % erro, file=sys.stderr, flush=True)
            return
        for caminho in lista:
            if not os.path.isfile(caminho):
                continue
            try:
                resultado, nome = c.verificar(caminho)
            except OSError:
                try:
                    c = N.ligar_clamd()
                    resultado, nome = c.verificar(caminho)
                except (OSError, N.EscudoIndisponivel, N.SemLista):
                    self.clamd = "erro"
                    return
            N.marcar_uso()
            self.verificados += 1
            if resultado == "FOUND":
                self.ameaca(caminho, nome)
        self.gravar_estado(True)

    def ameaca(self, caminho, nome_ameaca):
        try:
            sha = N.sha256_arquivo(caminho)
        except OSError:
            return
        if N.tem_excecao(sha):
            return  # a pessoa já liberou este arquivo (restaurou da quarentena)
        try:
            item = N.quarentenar(caminho, nome_ameaca, sha=sha)
        except OSError as erro:
            print("escudo: não deu para pôr %s na quarentena: %s" % (caminho, erro), file=sys.stderr, flush=True)
            self.notificar(N.t("Ameaça encontrada", "Threat found"),
                           N.t("%s tem %s, mas não deu para tirar do lugar. Apague o arquivo.",
                               "%s contains %s but could not be moved. Delete the file.") % (os.path.basename(caminho), nome_ameaca),
                           [("ver", N.t("Ver detalhes", "View details"))], "historico", urgente=True)
            return
        self.notificar(N.t("Ameaça bloqueada", "Threat blocked"),
                       N.t("%s tinha %s e foi para a quarentena.", "%s contained %s and was quarantined.") %
                       (item["nome"], nome_ameaca),
                       [("ver", N.t("Ver detalhes", "View details"))], "historico", urgente=True)

    def notificar(self, titulo, texto, acoes=(), pagina="", urgente=False, caminho=None):
        def avisar():
            escolha = N.avisar(titulo, texto, acoes, urgente=urgente)
            if escolha == "ver":
                N.abrir_central(pagina or "inicio")
            elif escolha == "verificar" and caminho:
                N.abrir_central("verificar", caminho)
        threading.Thread(target=avisar, daemon=True).start()

    # ----- pendrives -----
    def ler_montados(self):
        usuario = os.environ.get("USER") or os.path.basename(N.casa())
        base = "/run/media/%s/" % usuario
        montados = set()
        for linha in N.ler("/proc/self/mounts").splitlines():
            partes = linha.split()
            if len(partes) > 1:
                # O /proc/self/mounts troca espaço, tab e barra invertida por "\\040"...
                ponto = re.sub(r"\\([0-7]{3})", lambda m: chr(int(m.group(1), 8)), partes[1])
                if ponto.startswith(base):
                    montados.add(ponto)
        return montados

    def ver_montagens(self, inicio=False):
        agora = self.ler_montados()
        novos = agora - self.montados
        self.montados = agora
        if inicio:
            return
        for ponto in sorted(novos):
            self.pendrive(ponto)

    def pendrive(self, ponto):
        nome = os.path.basename(ponto)
        N.registrar("pendrive", nome, ponto)
        if not self.cfg["ligado"] or N.estado_pausa(self.cfg)["pausado"]:
            return
        if self.cfg["pendrive_auto"]:
            try:
                subprocess.Popen([sys.executable, "-I", "-S", AJUDANTE, "verificar", "caminho", ponto, "--silencioso"],
                                 stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, start_new_session=True)
            except OSError:
                pass
            return
        self.notificar(N.t("Verificar o pendrive?", "Scan the USB drive?"),
                       N.t("%s foi conectado. O escudo pode conferir os arquivos dele agora.",
                           "%s was connected. The shield can check its files now.") % nome,
                       [("verificar", N.t("Verificar agora", "Scan now")), ("depois", N.t("Agora não", "Not now"))],
                       caminho=ponto)

    # ----- ajustes, pausa e o clamd parado -----
    def recarregar_config(self):
        antes = self.cfg
        self.cfg = N.ler_config()
        estava = N.estado_pausa(antes)["pausado"] or not antes["ligado"]
        agora = N.estado_pausa(self.cfg)["pausado"] or not self.cfg["ligado"]
        if estava and not agora:
            self.soltar_pendentes()
        self.gravar_estado(True)

    def soltar_pendentes(self):
        pend, self.pendentes = self.pendentes, set()
        for caminho in pend:
            self.enfileirar(caminho)

    def ver_pausa(self):
        if N.pausa_venceu(self.cfg):
            self.cfg = N.retomar(self.cfg)
            try:
                N.gravar_config(self.cfg)
            except OSError:
                pass
            N.registrar("volta", "", "")
            self.notificar(N.t("O escudo voltou", "The shield is back"),
                           N.t("A pausa acabou e o escudo em tempo real está ligado de novo.",
                               "The pause is over and real-time protection is on again."),
                           [("ver", N.t("Abrir a Central", "Open Security"))], "escudo")
            self.soltar_pendentes()

    def ver_ocioso(self):
        agora = time.time()
        if agora - self.ultimo_ocioso < 60 or self.ocupado:
            return
        self.ultimo_ocioso = agora
        if agora - N.ultimo_uso() > N.OCIOSO_SEGUNDOS and os.path.exists(N.SOCKET_CLAMD):
            c = N.Clamd()
            if c.pronto():
                c.desligar()
            self.clamd = "parado"
            self.gravar_estado(True)

    def ver_lista(self):
        """A lista de ameaças chegou (primeiro download): verifica o que esperava."""
        if self.lista_faltando_desde and N.lista_presente():
            self.lista_faltando_desde = 0
            self.clamd = "parado"
            self.notificar(N.t("O escudo está pronto", "The shield is ready"),
                           N.t("A lista de ameaças foi baixada. Os seus downloads agora são verificados.",
                               "The threat list was downloaded. Your downloads are now checked."))
            self.soltar_pendentes()

    def ver_jogo(self):
        agora = time.time()
        if agora - self.ultimo_jogo < 3:
            return
        self.ultimo_jogo = agora
        jogo = N.jogo_aberto()
        if jogo != self.jogo:
            self.jogo = jogo
            self.gravar_estado(True)

    # ----- o laço -----
    def rodar(self):
        self.montar_vigias()
        self.ver_montagens(inicio=True)
        threading.Thread(target=self.trabalhador, daemon=True).start()
        if self.cfg["ligado"] and N.clamav_instalado() and not N.lista_presente():
            # Primeiro uso: baixa a lista de ameaças (~230 MB) assim que houver internet.
            self.lista_faltando_desde = time.time()
            N.iniciar_unidade(N.UNIDADE_ATUALIZAR)
        poller = select.poll()
        poller.register(self.ino.fd, select.POLLIN)
        montagens = open("/proc/self/mounts", "r")
        poller.register(montagens.fileno(), select.POLLPRI | select.POLLERR)
        self.gravar_estado(True)
        ultima_pastas = time.time()
        while True:
            for fd, _ev in poller.poll(1000):
                if fd == self.ino.fd:
                    for pasta, nome, mascara, wd in self.ino.ler():
                        if mascara & IN_IGNORED:
                            self.ino.esquecer(wd)
                            continue
                        self.tratar(pasta, nome, mascara)
                else:
                    montagens.seek(0)
                    montagens.read()
                    self.ver_montagens()
            self.ver_pausa()
            self.ver_jogo()
            self.andar_fila()
            self.ver_ocioso()
            if self.lista_faltando_desde:
                self.ver_lista()
            # Downloads ou Área de trabalho criados/renomeados depois (user-dirs mudou).
            if time.time() - ultima_pastas > 120:
                ultima_pastas = time.time()
                p = N.pastas_usuario()
                if [x for x in (p["downloads"], p["area"]) if x and os.path.isdir(x)] != self.pastas_vigiadas:
                    self.montar_vigias()
            self.gravar_estado()


if __name__ == "__main__":
    try:
        Escudo().rodar()
    except KeyboardInterrupt:
        pass
