#!/usr/bin/env python3
"""Instalador do Matsu: as telas, no mesmo jeito das Boas-vindas.

Uma coisa por tela, num cartão claro por cima do papel de parede em pixel art:
Olá, Idioma e teclado, Internet, Onde instalar, Sua conta e Resumo. Depois
vêm Instalando (com a barra) e Pronto. Quem instala de verdade é o instalador
do Fedora (anaconda), sem tela, com o kickstart que o motor.py escreve.

Roda no lugar do anaconda (o iniciar chama este arquivo dentro do gnome-kiosk).
Sai com o código 10 quando a pessoa pede o instalador avançado: aí o iniciar
abre o anaconda de sempre.

Para ver as telas sem instalar nada: MATSU_INSTALADOR_DEMO=1 (discos e rede de
mentira). MATSU_INSTALADOR_TELA=<tela> abre direto numa tela.
"""
import json
import os
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk, Pango  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import motor  # noqa: E402

DEMO = os.environ.get("MATSU_INSTALADOR_DEMO") == "1"
TELA_INICIAL = os.environ.get("MATSU_INSTALADOR_TELA", "ola")
PASTA_TEMP = os.environ.get("MATSU_INSTALADOR_TEMP", "/tmp/matsu-instalador")
SAIR_PARA_O_AVANCADO = 10

PASSOS = ["ola", "idioma", "internet", "disco", "conta", "resumo"]
OLAS = ["Olá", "Hello", "Hola", "Bonjour", "Ciao", "Hallo"]
DICAS = [
    "Na primeira vez que você entrar, as Boas-vindas ajudam a escolher o tema, a barra e o navegador.",
    "Na Loja do Matsu você instala apps e jogos com um clique.",
    "A Central de jogos já vem com o Steam e mostra o FPS por cima do jogo quando você quiser.",
    "As atualizações chegam sozinhas. Se uma der problema, dá para ligar na versão anterior.",
]


def nome_do_sistema():
    try:
        edicao = open(os.path.join(AQUI, "edicao"), encoding="utf-8").read().strip()
    except OSError:
        edicao = "27"
    return f"Matsu {edicao} OS"


NOME = nome_do_sistema()


def marcar(texto):
    """Deixa um sinal nos registros (o teste da ISO na VM espera por eles)."""
    linha = f"MATSU-INSTALADOR: {texto}"
    print(linha, flush=True)
    if DEMO:
        return
    try:
        import syslog
        syslog.syslog(syslog.LOG_INFO, linha)
    except Exception:  # noqa: BLE001
        pass
    for porta in ("/dev/ttyS0", "/dev/virtio-ports/org.fedoraproject.anaconda.log.0"):
        try:
            with open(porta, "w", encoding="utf-8") as f:
                f.write(linha + "\n")
        except OSError:
            pass


# ----- ícones (os do Matsu, pintados na cor certa) -----

CORES = {"escuro": "#1a1a1e", "claro": "#ffffff", "suave": "#7a7a84", "vermelho": "#d93036", "verde": "#1f8a54"}


def preparar_icones():
    """Copia os ícones do Matsu numa pasta temporária, um arquivo por cor.

    Os ícones são de traço (stroke); o GTK pintaria eles como cheios se fossem
    tratados como simbólicos, então cada cor vira um arquivo comum.
    """
    origem = os.path.join(AQUI, "icones")
    destino = os.path.join(PASTA_TEMP, "icones")
    os.makedirs(destino, exist_ok=True)
    for arq in os.listdir(origem):
        if not arq.endswith(".svg"):
            continue
        texto = open(os.path.join(origem, arq), encoding="utf-8").read()
        base = arq[:-4]
        if base == "logo":
            with open(os.path.join(destino, "mi-logo.svg"), "w", encoding="utf-8") as f:
                f.write(texto)
            continue
        base = base.replace("matsu-", "").replace("-symbolic", "")
        for nome, cor in CORES.items():
            with open(os.path.join(destino, f"mi-{base}-{nome}.svg"), "w", encoding="utf-8") as f:
                f.write(texto.replace("currentColor", cor).replace("#232629", cor))
    Gtk.IconTheme.get_default().append_search_path(destino)


def icone(nome, cor="escuro", px=20):
    img = Gtk.Image.new_from_icon_name(f"mi-{nome}-{cor}" if nome != "logo" else "mi-logo", Gtk.IconSize.BUTTON)
    img.set_pixel_size(px)
    return img


def classes(widget, *nomes):
    ctx = widget.get_style_context()
    for n in nomes:
        ctx.add_class(n)
    return widget


def rotulo(texto, *css, wrap=False, xalign=0.5, largura=0):
    r = Gtk.Label(label=texto)
    r.set_xalign(xalign)
    if wrap:
        r.set_line_wrap(True)
        r.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
        r.set_justify(Gtk.Justification.CENTER if xalign == 0.5 else Gtk.Justification.LEFT)
    if largura:
        r.set_max_width_chars(largura)
    return classes(r, *css)


def suave(de, para, ms, passo, fim=None):
    """Anima um número de 'de' até 'para' (saída suave, como nas Boas-vindas)."""
    inicio = GLib.get_monotonic_time()

    def quadro():
        t = min(1.0, (GLib.get_monotonic_time() - inicio) / (ms * 1000))
        e = 1 - (1 - t) ** 3
        passo(de + (para - de) * e)
        if t >= 1:
            if fim:
                fim()
            return False
        return True

    GLib.timeout_add(16, quadro)


# ----- peças das telas -----

class Lista(Gtk.Box):
    """Lista agrupada (como nos Ajustes do Mac): linhas num bloco arredondado,
    a escolhida com o visto à direita."""

    def __init__(self, ao_escolher=None):
        super().__init__(orientation=Gtk.Orientation.VERTICAL)
        classes(self, "lista")
        self.ao_escolher = ao_escolher
        self.linhas = []

    def limpar(self):
        for filho in self.get_children():
            self.remove(filho)
        self.linhas = []

    def adicionar(self, chave, titulo, detalhe="", nome_icone="", ativa=True, clicavel=True, valor=""):
        if self.linhas:
            self.pack_start(classes(Gtk.Box(), "divisa"), False, False, 0)
        miolo = Gtk.Box(spacing=12)
        if nome_icone:
            img = icone(nome_icone, "escuro" if ativa else "suave", 22)
            img.set_valign(Gtk.Align.CENTER)
            miolo.pack_start(img, False, False, 0)
        textos = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        textos.set_valign(Gtk.Align.CENTER)
        textos.pack_start(rotulo(titulo, "linha-titulo", xalign=0), False, False, 0)
        if detalhe:
            d = rotulo(detalhe, "linha-detalhe", wrap=True, xalign=0)
            d.set_max_width_chars(70)
            textos.pack_start(d, False, False, 0)
        miolo.pack_start(textos, True, True, 0)
        if valor:
            v = rotulo(valor, "linha-valor", wrap=True, xalign=1)
            v.set_max_width_chars(42)
            miolo.pack_end(v, False, False, 0)
        visto = icone("certo", "escuro", 18)
        visto.set_valign(Gtk.Align.CENTER)
        visto.set_opacity(0)
        if clicavel:
            miolo.pack_end(visto, False, False, 0)
            linha = Gtk.Button()
            linha.set_relief(Gtk.ReliefStyle.NONE)
            linha.add(miolo)
            linha.set_sensitive(ativa)
            linha.connect("clicked", lambda *_: self.escolher(chave, avisar=True))
        else:
            linha = Gtk.Box()
            linha.pack_start(miolo, True, True, 0)
        classes(linha, "linha")
        self.pack_start(linha, False, False, 0)
        self.linhas.append((chave, linha, visto))
        self._cantos()
        return linha

    def _cantos(self):
        for i, (_, linha, _) in enumerate(self.linhas):
            ctx = linha.get_style_context()
            for c in ("primeira", "ultima"):
                ctx.remove_class(c)
            if i == 0:
                ctx.add_class("primeira")
            if i == len(self.linhas) - 1:
                ctx.add_class("ultima")

    def escolher(self, chave, avisar=False):
        for c, linha, visto in self.linhas:
            sim = c == chave
            visto.set_opacity(1 if sim else 0)
            ctx = linha.get_style_context()
            (ctx.add_class if sim else ctx.remove_class)("escolhida")
        if avisar and self.ao_escolher:
            self.ao_escolher(chave)


class Pontos(Gtk.Box):
    """Um pontinho por passo; o atual estica numa pílula (o CSS anima a largura)."""

    def __init__(self, total):
        super().__init__(spacing=7)
        self.set_halign(Gtk.Align.CENTER)
        self.set_valign(Gtk.Align.CENTER)
        self.pontos = []
        for _ in range(total):
            p = classes(Gtk.Box(), "ponto")
            p.set_valign(Gtk.Align.CENTER)
            self.pack_start(p, False, False, 0)
            self.pontos.append(p)

    def atual(self, i):
        for k, p in enumerate(self.pontos):
            ctx = p.get_style_context()
            for c in ("atual", "feito"):
                ctx.remove_class(c)
            if k == i:
                ctx.add_class("atual")
            elif k < i:
                ctx.add_class("feito")


# ----- a janela -----

class Instalador(Gtk.Window):
    def __init__(self):
        super().__init__(title="Instalar o " + NOME)
        self.codigo_de_saida = 0
        self.escolhas = {
            "idioma": "pt_BR.UTF-8", "teclado": "br-abnt2", "fuso": "America/Sao_Paulo",
            "disco": "", "modo": "", "nome": "", "usuario": "", "senha": "", "confirmacao": "",
        }
        self.usuario_mexido = False
        self.discos = []
        self.rede = {"conectado": False, "tipo": "", "nome": "", "tem_wifi": False}
        self.redes = []
        self.wifi_escolhida = ""
        self.erro_wifi = ""
        self.campo_senha_wifi = None
        self.conectando = False
        self.chegou_ao_fim = False
        self.instalacao = None
        self.tamanho_fundo = (0, 0)
        self.tela = ""

        preparar_icones()
        self._estilo()

        camadas = Gtk.Overlay()
        self.fundo = classes(Gtk.Box(), "fundo")
        camadas.add(self.fundo)
        self.cartao = classes(Gtk.Box(orientation=Gtk.Orientation.VERTICAL), "cartao")
        self.cartao.set_halign(Gtk.Align.CENTER)
        self.cartao.set_valign(Gtk.Align.CENTER)
        camadas.add_overlay(self.cartao)
        self.add(camadas)

        self.palco = Gtk.Stack()
        self.palco.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.palco.set_transition_duration(260)
        self.palco.set_vexpand(True)
        self.cartao.pack_start(self.palco, True, True, 0)
        self._rodape()

        self.telas = {}
        for nome in PASSOS + ["instalando", "pronto", "erro", "avancado"]:
            pagina = getattr(self, "_tela_" + nome)()
            rolar = Gtk.ScrolledWindow()
            rolar.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            rolar.add(pagina)
            self.palco.add_named(rolar, nome)
            self.telas[nome] = pagina

        self.connect("size-allocate", self._mudou_tamanho)
        self.connect("key-press-event", self._tecla)
        self.connect("delete-event", lambda *_: True)  # o instalador não fecha no X

        tela = Gdk.Screen.get_default()
        self.set_default_size(tela.get_width() if DEMO else 1280, tela.get_height() if DEMO else 800)
        if not DEMO:
            self.fullscreen()

        # O GTK só troca para uma tela que já está à mostra: mostra tudo antes de ir.
        camadas.show_all()
        self._montar_modos()
        self._atualizar_avatar()
        self.expansor.set_visible(False)
        self.aplicar_teclado()
        threading.Thread(target=self._procurar_discos, daemon=True).start()
        GLib.timeout_add_seconds(2, self._olhar_rede)
        self._olhar_rede()
        self.ir(TELA_INICIAL if TELA_INICIAL in self.telas else "ola")

    # ----- aparência -----

    def _estilo(self):
        ajustes = Gtk.Settings.get_default()
        ajustes.set_property("gtk-theme-name", "Adwaita")
        ajustes.set_property("gtk-application-prefer-dark-theme", False)
        ajustes.set_property("gtk-font-name", "Inter 11")
        css = Gtk.CssProvider()
        css.load_from_path(os.path.join(AQUI, "estilo.css"))
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css,
                                                 Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.css_fundo = Gtk.CssProvider()
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), self.css_fundo,
                                                 Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1)
        self.papel = GdkPixbuf.Pixbuf.new_from_file(os.path.join(AQUI, "papel.png"))

    def _mudou_tamanho(self, _janela, area):
        largura, altura = area.width, area.height
        self.cartao.set_size_request(min(880, largura - 48), min(640, altura - 48))
        if (largura, altura) != self.tamanho_fundo and largura > 0 and altura > 0:
            self.tamanho_fundo = (largura, altura)
            GLib.idle_add(self._desenhar_fundo, largura, altura)

    def _desenhar_fundo(self, largura, altura):
        """O papel de parede em pixel art, ampliado sem borrar (pixel por pixel)."""
        if (largura, altura) != self.tamanho_fundo:
            return False
        pw, ph = self.papel.get_width(), self.papel.get_height()
        escala = max(largura / pw, altura / ph)
        grande = self.papel.scale_simple(max(1, round(pw * escala)), max(1, round(ph * escala)),
                                         GdkPixbuf.InterpType.NEAREST)
        x = max(0, (grande.get_width() - largura) // 2)
        y = max(0, (grande.get_height() - altura) // 2)
        recorte = grande.new_subpixbuf(x, y, min(largura, grande.get_width()), min(altura, grande.get_height()))
        os.makedirs(PASTA_TEMP, exist_ok=True)
        arquivo = os.path.join(PASTA_TEMP, f"fundo-{largura}x{altura}.png")
        recorte.savev(arquivo, "png", ["compression"], ["1"])
        self.css_fundo.load_from_data(
            f".fundo {{ background-image: url('file://{arquivo}'); }}".encode())
        return False

    # ----- rodapé -----

    def _rodape(self):
        rodape = classes(Gtk.Box(homogeneous=True), "rodape")
        esquerda = Gtk.Box()
        self.botao_voltar = classes(Gtk.Button(), "simples")
        caixa = Gtk.Box(spacing=6)
        caixa.pack_start(icone("voltar", "escuro", 16), False, False, 0)
        caixa.pack_start(Gtk.Label(label="Voltar"), False, False, 0)
        self.botao_voltar.add(caixa)
        self.botao_voltar.connect("clicked", lambda *_: self.voltar())
        self.botao_avancado_erro = classes(Gtk.Button(label="Instalador avançado"), "simples")
        self.botao_avancado_erro.connect("clicked", lambda *_: self.sair(SAIR_PARA_O_AVANCADO))
        esquerda.pack_start(self.botao_voltar, False, False, 0)
        esquerda.pack_start(self.botao_avancado_erro, False, False, 0)
        esquerda.set_halign(Gtk.Align.START)
        esquerda.set_valign(Gtk.Align.CENTER)
        self.pontos = Pontos(len(PASSOS))
        direita = Gtk.Box()
        direita.set_halign(Gtk.Align.END)
        direita.set_valign(Gtk.Align.CENTER)
        self.botao_seguir = classes(Gtk.Button(label="Continuar"), "destaque")
        self.botao_seguir.connect("clicked", lambda *_: self.seguir())
        direita.pack_end(self.botao_seguir, False, False, 0)
        rodape.pack_start(esquerda, True, True, 0)
        rodape.pack_start(self.pontos, True, True, 0)
        rodape.pack_start(direita, True, True, 0)
        self.rodape = rodape
        self.cartao.pack_end(rodape, False, False, 0)

    def atualizar_rodape(self):
        tela = self.tela
        self.rodape.set_visible(tela != "instalando")
        self.botao_voltar.set_visible((tela in PASSOS and PASSOS.index(tela) > 0) or tela == "avancado")
        self.botao_avancado_erro.set_visible(tela == "erro")
        self.pontos.set_opacity(1 if tela in PASSOS else 0)
        if tela in PASSOS:
            self.pontos.atual(PASSOS.index(tela))
        textos = {"ola": "Começar", "pronto": "Reiniciar", "erro": "Reiniciar",
                  "avancado": "Abrir o instalador avançado"}
        texto = textos.get(tela, "Continuar")
        perigo = False
        if tela == "resumo":
            d = self.disco_escolhido()
            perigo = self.escolhas["modo"] == "apagar" and not (d and d["vazio"])
            texto = "Apagar e instalar" if perigo else "Instalar"
        self.botao_seguir.set_label(texto)
        ctx = self.botao_seguir.get_style_context()
        (ctx.add_class if perigo else ctx.remove_class)("perigo")
        self.botao_seguir.set_sensitive(self.pode_seguir())

    def pode_seguir(self):
        t, e = self.tela, self.escolhas
        if t == "internet":
            return self.rede["conectado"]
        if t == "disco":
            return bool(e["disco"] and e["modo"])
        if t == "conta":
            return not motor.problema_no_usuario(e["usuario"]) and \
                not motor.problema_na_senha(e["senha"], e["confirmacao"]) and bool(e["nome"].strip())
        return True

    # ----- andar entre as telas -----

    def ir(self, tela):
        self.tela = tela
        preparar = getattr(self, "_entrar_" + tela, None)
        if preparar:
            preparar()
        self.palco.set_visible_child_name(tela)
        self.atualizar_rodape()
        marcar("tela " + tela)
        GLib.idle_add(self._foco_inicial)

    def _foco_inicial(self):
        if self.tela == "conta" and not self.escolhas["nome"]:
            self.campo_nome.grab_focus()
        elif self.botao_seguir.get_sensitive() and self.botao_seguir.get_visible():
            self.botao_seguir.grab_focus()
        return False

    def seguir(self):
        if not self.pode_seguir():
            return
        t = self.tela
        if t in PASSOS[:-1]:
            self.ir(PASSOS[PASSOS.index(t) + 1])
        elif t == "resumo":
            self.instalar()
        elif t in ("pronto", "erro"):
            self.reiniciar()
        elif t == "avancado":
            self.sair(SAIR_PARA_O_AVANCADO)

    def voltar(self):
        if self.tela == "avancado":
            self.ir("ola")
        elif self.tela in PASSOS and PASSOS.index(self.tela) > 0:
            self.ir(PASSOS[PASSOS.index(self.tela) - 1])

    def _tecla(self, _janela, evento):
        if evento.keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            foco = self.get_focus()
            if foco is self.campo_senha_wifi:
                return False
            if isinstance(foco, Gtk.Entry) and foco is not self.campo_confirmacao and foco is not self.campo_teste:
                foco.get_toplevel().child_focus(Gtk.DirectionType.TAB_FORWARD)
                return True
            self.seguir()
            return True
        if evento.keyval == Gdk.KEY_Left and evento.state & Gdk.ModifierType.MOD1_MASK:
            self.voltar()
            return True
        return False

    def sair(self, codigo):
        self.codigo_de_saida = codigo
        marcar(f"saindo com o código {codigo}")
        if self.instalacao:
            # Uma instalação que deu erro ainda pode estar de pé (o anaconda espera
            # uns minutos antes de fechar); o instalador avançado precisa dele fora.
            self.instalacao.parar()
        Gtk.main_quit()

    def reiniciar(self):
        marcar("reiniciando")
        if DEMO:
            self.sair(0)
            return
        subprocess.Popen(["systemctl", "--no-wall", "reboot"])

    # ----- telas -----

    def _pagina(self, titulo="", texto="", topo=None, espaco_topo=36, centro=False):
        caixa = classes(Gtk.Box(orientation=Gtk.Orientation.VERTICAL), "pagina")
        if centro:
            # Telas de uma mensagem só (pronto, erro): no meio do cartão.
            caixa.set_valign(Gtk.Align.CENTER)
            caixa.set_margin_bottom(28)
        else:
            caixa.set_margin_top(espaco_topo)
        if topo is not None:
            topo.set_halign(Gtk.Align.CENTER)
            caixa.pack_start(topo, False, False, 0)
        if titulo:
            self._titulo = rotulo(titulo, "titulo", wrap=True, largura=40)
            caixa.pack_start(self._titulo, False, False, 0)
        if texto:
            s = rotulo(texto, "subtitulo", wrap=True, largura=64)
            s.set_halign(Gtk.Align.CENTER)
            caixa.pack_start(s, False, False, 0)
        return caixa

    def _secao(self, texto):
        return rotulo(texto, "secao", xalign=0)

    def _miolo(self, largura=560):
        m = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        m.set_halign(Gtk.Align.CENTER)
        m.set_size_request(largura, -1)
        classes(m, "miolo")
        return m

    # Olá
    def _tela_ola(self):
        logo = icone("logo", px=112)
        classes(logo, "logo")
        logo.set_opacity(0)
        self.logo_ola = logo
        self.rotulo_ola = rotulo(OLAS[0], "ola")
        self.rotulo_ola.set_opacity(0)
        self.qual_ola = 0
        caixa = self._pagina(topo=logo, espaco_topo=70)
        caixa.pack_start(self.rotulo_ola, False, False, 0)
        textos = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        textos.pack_start(rotulo(f"Vamos instalar o {NOME}", "titulo-menor", wrap=True), False, False, 0)
        textos.pack_start(rotulo("São poucos passos. Depois de começar, a instalação leva uns 15 minutos.",
                                 "subtitulo", wrap=True, largura=56), False, False, 0)
        textos.set_opacity(0)
        self.textos_ola = textos
        caixa.pack_start(textos, False, False, 0)
        avancado = classes(Gtk.Button(label="Instalador avançado"), "link")
        avancado.set_halign(Gtk.Align.CENTER)
        avancado.set_valign(Gtk.Align.END)
        avancado.set_vexpand(True)
        avancado.set_margin_bottom(14)
        avancado.connect("clicked", lambda *_: self.ir("avancado"))
        caixa.pack_end(avancado, True, True, 0)
        return caixa

    def _entrar_ola(self):
        if getattr(self, "_ola_animado", False):
            return
        self._ola_animado = True

        def chegada():
            suave(0, 1, 520, self.logo_ola.set_opacity)
            suave(18, 0, 720, lambda v: self.logo_ola.set_margin_top(int(v)))
            GLib.timeout_add(380, lambda: suave(0, 1, 420, self.rotulo_ola.set_opacity) or False)
            GLib.timeout_add(700, lambda: suave(0, 1, 420, self.textos_ola.set_opacity) or False)
            return False

        GLib.timeout_add(120, chegada)
        GLib.timeout_add(2600, self._trocar_ola)

    def _trocar_ola(self):
        if self.tela != "ola":
            return True

        def trocar():
            self.qual_ola = (self.qual_ola + 1) % len(OLAS)
            self.rotulo_ola.set_label(OLAS[self.qual_ola])
            suave(0, 1, 380, self.rotulo_ola.set_opacity)

        suave(1, 0, 280, self.rotulo_ola.set_opacity, trocar)
        return True

    # Idioma e teclado
    def _tela_idioma(self):
        caixa = self._pagina("Idioma e teclado",
                             "O Matsu já vem em português do Brasil, com teclado ABNT2. Troque se precisar.")
        colunas = Gtk.Box(spacing=20)
        colunas.set_halign(Gtk.Align.CENTER)
        classes(colunas, "miolo")
        esq = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        esq.pack_start(self._secao("Idioma do sistema"), False, False, 0)
        self.lista_idiomas = Lista(lambda k: self._escolheu("idioma", k))
        for cod, nome in motor.IDIOMAS:
            self.lista_idiomas.adicionar(cod, nome)
        self.lista_idiomas.escolher(self.escolhas["idioma"])
        esq.pack_start(self.lista_idiomas, False, False, 0)
        esq.pack_start(self._secao("Fuso horário"), False, False, 6)
        self.fusos = Gtk.ComboBoxText()
        for cod, nome in motor.FUSOS:
            self.fusos.append(cod, nome)
        self.fusos.set_active_id(self.escolhas["fuso"])
        self.fusos.connect("changed", lambda c: self._escolheu("fuso", c.get_active_id()))
        classes(self.fusos, "suspensa")
        esq.pack_start(self.fusos, False, False, 0)
        esq.set_size_request(300, -1)
        dir_ = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        dir_.pack_start(self._secao("Teclado"), False, False, 0)
        self.lista_teclados = Lista(lambda k: self._escolheu("teclado", k))
        for cod, _, _, nome in motor.TECLADOS:
            self.lista_teclados.adicionar(cod, nome)
        self.lista_teclados.escolher(self.escolhas["teclado"])
        dir_.pack_start(self.lista_teclados, False, False, 0)
        self.campo_teste = classes(Gtk.Entry(), "campo")
        self.campo_teste.set_placeholder_text("Digite aqui para testar: ç, á, ~")
        dir_.pack_start(self.campo_teste, False, False, 6)
        dir_.set_size_request(340, -1)
        colunas.pack_start(esq, False, False, 0)
        colunas.pack_start(dir_, False, False, 0)
        caixa.pack_start(colunas, False, False, 0)
        return caixa

    def _escolheu(self, chave, valor):
        if not valor:
            return
        self.escolhas[chave] = valor
        if chave == "teclado":
            self.aplicar_teclado()
        if chave == "disco":
            d = self.disco_escolhido()
            self.escolhas["modo"] = "apagar" if d and d["vazio"] else ""
            self._montar_modos()
        self.atualizar_rodape()

    def aplicar_teclado(self):
        """Troca o teclado da tela do instalador na hora (o gnome-kiosk segue o localed)."""
        t = next(x for x in motor.TECLADOS if x[0] == self.escolhas["teclado"])
        if DEMO:
            return
        try:
            subprocess.Popen(["localectl", "set-x11-keymap", t[1], "pc105", t[2]],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            pass

    # Internet
    def _tela_internet(self):
        caixa = self._pagina("Internet",
                             "O Matsu é baixado durante a instalação, sempre na versão mais nova. "
                             "Para isso, o computador precisa estar na internet.")
        self.miolo_rede = self._miolo(520)
        caixa.pack_start(self.miolo_rede, False, False, 0)
        return caixa

    def _entrar_internet(self):
        self._montar_rede()
        if not self.rede["conectado"] and self.rede["tem_wifi"]:
            threading.Thread(target=self._procurar_wifi, args=(True,), daemon=True).start()

    def _olhar_rede(self):
        def olhar():
            estado = self._rede_demo() if DEMO else motor.estado_da_rede()
            GLib.idle_add(self._rede_mudou, estado)
        threading.Thread(target=olhar, daemon=True).start()
        return True

    def _rede_demo(self):
        modo = os.environ.get("MATSU_INSTALADOR_REDE", "cabo")
        if modo == "cabo":
            return {"conectado": True, "tipo": "cabo", "nome": "Cabo", "tem_wifi": True}
        if modo == "wifi-ok":
            return {"conectado": True, "tipo": "wifi", "nome": "Casa", "tem_wifi": True}
        return {"conectado": False, "tipo": "", "nome": "", "tem_wifi": modo == "wifi"}

    def _rede_mudou(self, estado):
        mudou = (estado["conectado"], estado["tipo"], estado["nome"], estado["tem_wifi"]) != \
            (self.rede["conectado"], self.rede["tipo"], self.rede["nome"], self.rede["tem_wifi"])
        self.rede = estado
        if mudou and self.tela == "internet":
            self._montar_rede()
            if not estado["conectado"] and estado["tem_wifi"] and not self.redes:
                threading.Thread(target=self._procurar_wifi, args=(True,), daemon=True).start()
        if mudou:
            self.atualizar_rodape()
        return False

    def _procurar_wifi(self, procurar=False):
        if DEMO:
            redes = [{"nome": "Casa", "sinal": 82, "senha": True, "ativa": False},
                     {"nome": "Vizinho 5G", "sinal": 54, "senha": True, "ativa": False},
                     {"nome": "Café da esquina", "sinal": 31, "senha": False, "ativa": False}]
        else:
            redes = motor.redes_wifi(procurar)
        GLib.idle_add(self._wifi_achadas, redes)

    def _wifi_achadas(self, redes):
        self.redes = redes
        if self.tela == "internet":
            self._montar_rede()
        return False

    def _montar_rede(self):
        m = self.miolo_rede
        for filho in m.get_children():
            m.remove(filho)
        self.campo_senha_wifi = None
        r = self.rede
        if r["conectado"]:
            selo = classes(Gtk.Box(), "selo")
            selo.set_halign(Gtk.Align.CENTER)
            img = icone("rede-cabo" if r["tipo"] == "cabo" else "wifi-3", "escuro", 34)
            img.set_hexpand(True)
            selo.pack_start(img, True, True, 0)
            m.pack_start(selo, False, False, 8)
            texto = "Conectado pelo cabo de rede" if r["tipo"] == "cabo" else f"Conectado ao Wi-Fi {r['nome']}"
            m.pack_start(rotulo(texto, "destaque-texto"), False, False, 0)
            m.pack_start(rotulo("Pode continuar.", "subtitulo"), False, False, 0)
        elif r["tem_wifi"]:
            topo = Gtk.Box()
            topo.pack_start(self._secao("Escolha uma rede Wi-Fi"), True, True, 0)
            atualizar = classes(Gtk.Button(), "simples", "pequeno")
            atualizar.add(icone("recarregar", "escuro", 16))
            atualizar.set_tooltip_text("Procurar redes de novo")
            atualizar.connect("clicked", lambda *_: threading.Thread(
                target=self._procurar_wifi, args=(True,), daemon=True).start())
            topo.pack_end(atualizar, False, False, 0)
            m.pack_start(topo, False, False, 0)
            if not self.redes:
                m.pack_start(rotulo("Procurando redes…", "subtitulo"), False, False, 12)
            else:
                lista = Lista(self._escolheu_wifi)
                barras = lambda s: "wifi-3" if s >= 70 else "wifi-2" if s >= 45 else "wifi-1" if s >= 20 else "wifi-0"
                for rede in self.redes[:6]:
                    linha = lista.adicionar(rede["nome"], rede["nome"],
                                            "Com senha" if rede["senha"] else "Aberta",
                                            barras(rede["sinal"]))
                    linha.set_sensitive(not self.conectando)
                if self.wifi_escolhida:
                    lista.escolher(self.wifi_escolhida)
                m.pack_start(lista, False, False, 0)
                rede = next((x for x in self.redes if x["nome"] == self.wifi_escolhida), None)
                if rede and rede["senha"]:
                    linha_senha = Gtk.Box(spacing=8)
                    self.campo_senha_wifi = classes(Gtk.Entry(), "campo")
                    self.campo_senha_wifi.set_visibility(False)
                    self.campo_senha_wifi.set_invisible_char("•")
                    self.campo_senha_wifi.set_placeholder_text(f"Senha de {rede['nome']}")
                    self.campo_senha_wifi.connect("activate", lambda *_: self._conectar_wifi())
                    linha_senha.pack_start(self.campo_senha_wifi, True, True, 0)
                    conectar = classes(Gtk.Button(label="Conectar"), "destaque")
                    conectar.set_sensitive(not self.conectando)
                    conectar.connect("clicked", lambda *_: self._conectar_wifi())
                    linha_senha.pack_start(conectar, False, False, 0)
                    m.pack_start(linha_senha, False, False, 6)
                    GLib.idle_add(self.campo_senha_wifi.grab_focus)
            if self.conectando:
                m.pack_start(rotulo("Conectando…", "subtitulo"), False, False, 0)
            if getattr(self, "erro_wifi", ""):
                m.pack_start(rotulo(self.erro_wifi, "aviso"), False, False, 0)
        else:
            selo = classes(Gtk.Box(), "selo")
            selo.set_halign(Gtk.Align.CENTER)
            img = icone("rede-desconectada", "escuro", 34)
            img.set_hexpand(True)
            selo.pack_start(img, True, True, 0)
            m.pack_start(selo, False, False, 8)
            m.pack_start(rotulo("Ligue o cabo de rede no computador", "destaque-texto"), False, False, 0)
            m.pack_start(rotulo("Assim que a internet chegar, esta tela muda sozinha.", "subtitulo",
                                wrap=True), False, False, 0)
        m.show_all()

    def _escolheu_wifi(self, nome):
        self.wifi_escolhida = nome
        self.erro_wifi = ""
        rede = next((x for x in self.redes if x["nome"] == nome), None)
        if rede and not rede["senha"]:
            self._conectar_wifi()
        else:
            self._montar_rede()

    def _conectar_wifi(self):
        if self.conectando or not self.wifi_escolhida:
            return
        senha = self.campo_senha_wifi.get_text() if self.campo_senha_wifi else ""
        self.conectando = True
        self.erro_wifi = ""
        self._montar_rede()

        def conectar():
            ok, motivo = (False, "Na demonstração não conecta.") if DEMO else \
                motor.conectar_wifi(self.wifi_escolhida, senha)
            GLib.idle_add(self._wifi_conectou, ok, motivo)

        threading.Thread(target=conectar, daemon=True).start()

    def _wifi_conectou(self, ok, motivo):
        self.conectando = False
        self.erro_wifi = "" if ok else motivo
        self._montar_rede()
        self._olhar_rede()
        return False

    # Onde instalar
    def _tela_disco(self):
        caixa = self._pagina("Onde instalar", "Escolha o disco onde o Matsu vai ficar. Os outros discos não são mexidos.")
        m = self._miolo(600)
        self.lista_discos = Lista(lambda k: self._escolheu("disco", k))
        m.pack_start(self.lista_discos, False, False, 0)
        self.titulo_modos = self._secao("O que fazer com este disco")
        m.pack_start(self.titulo_modos, False, False, 8)
        self.lista_modos = Lista(lambda k: self._escolheu("modo", k))
        m.pack_start(self.lista_modos, False, False, 0)
        self.sem_discos = rotulo("", "aviso", wrap=True)
        m.pack_start(self.sem_discos, False, False, 0)
        caixa.pack_start(m, False, False, 0)
        return caixa

    def _procurar_discos(self):
        if DEMO and os.environ.get("MATSU_INSTALADOR_DISCOS") == "vazio":
            discos = [{"nome": "vda", "caminho": "/dev/vda", "tamanho": 68719476736, "modelo": "Disco vda",
                       "tipo": "Disco virtual", "sistemas": [], "vazio": True, "livre": 68719476736, "particoes": 0}]
        elif DEMO:
            discos = [
                {"nome": "nvme0n1", "caminho": "/dev/nvme0n1", "tamanho": 512110190592,
                 "modelo": "Samsung SSD 980 PRO 512GB", "tipo": "NVMe", "sistemas": ["Windows"],
                 "vazio": False, "livre": 120 * 1000 ** 3, "particoes": 4},
                {"nome": "sda", "caminho": "/dev/sda", "tamanho": 1000204886016, "modelo": "WDC WD10EZEX",
                 "tipo": "HD", "sistemas": [], "vazio": False, "livre": 0, "particoes": 1},
            ]
        else:
            discos = motor.descobrir_discos()
        GLib.idle_add(self._discos_achados, discos)

    def _discos_achados(self, discos):
        self.discos = discos
        caminhos = [d["caminho"] for d in discos if d["tamanho"] >= motor.MINIMO_BYTES]
        if self.escolhas["disco"] not in caminhos:
            self.escolhas["disco"] = caminhos[0] if len(caminhos) == 1 else ""
            d = self.disco_escolhido()
            self.escolhas["modo"] = "apagar" if d and d["vazio"] else ""
        self._montar_discos()
        return False

    def _entrar_disco(self):
        self._montar_discos()

    def disco_escolhido(self):
        return next((d for d in self.discos if d["caminho"] == self.escolhas["disco"]), None)

    def _montar_discos(self):
        self.lista_discos.limpar()
        for d in self.discos:
            pequeno = d["tamanho"] < motor.MINIMO_BYTES
            detalhe = motor.descricao_do_disco(d)
            if pequeno:
                detalhe += " · pequeno demais (precisa de 40 GB)"
            self.lista_discos.adicionar(d["caminho"], d["modelo"], detalhe, "disco", ativa=not pequeno)
        self.lista_discos.escolher(self.escolhas["disco"])
        self.lista_discos.show_all()
        self.sem_discos.set_label("" if self.discos else
                                  "Nenhum disco apareceu. Confira se o disco está ligado e reinicie o computador.")
        self._montar_modos()
        self.atualizar_rodape()

    def _montar_modos(self):
        d = self.disco_escolhido()
        self.lista_modos.limpar()
        self.titulo_modos.set_visible(bool(d))
        self.lista_modos.set_visible(bool(d))
        if not d:
            return
        if d["vazio"]:
            self.lista_modos.adicionar("apagar", "Usar o disco inteiro", "O disco está vazio.")
        else:
            outros = " e o ".join(d["sistemas"])
            apagar = "Tudo o que está nele some" + (f", inclusive o {outros}." if outros else ", inclusive os arquivos.")
            self.lista_modos.adicionar("apagar", "Apagar o disco e instalar o Matsu", apagar)
            if d["livre"] >= motor.MINIMO_BYTES:
                fica = f"O {outros} continua lá" if outros else "O que já está no disco continua lá"
                self.lista_modos.adicionar("lado", "Instalar ao lado do que já existe",
                                           f"Usa os {motor.tamanho(d['livre'])} livres. {fica}, e você escolhe "
                                           "qual ligar quando o computador começa.")
            else:
                dica = ("No Windows, abra o Gerenciamento de disco e use Diminuir volume para liberar espaço."
                        if "Windows" in d["sistemas"] else "Libere espaço no disco para usar esta opção.")
                self.lista_modos.adicionar("lado", "Instalar ao lado do que já existe",
                                           f"Precisa de 40 GB livres no disco. {dica}", ativa=False)
        self.lista_modos.escolher(self.escolhas["modo"])
        self.lista_modos.show_all()

    # Sua conta
    def _tela_conta(self):
        self.avatar = classes(Gtk.Box(), "avatar")
        self.letra = rotulo("", "avatar-letra")
        self.letra.set_hexpand(True)
        self.avatar_icone = icone("pessoa", "claro", 34)
        self.avatar_icone.set_hexpand(True)
        self.avatar.pack_start(self.letra, True, True, 0)
        self.avatar.pack_start(self.avatar_icone, True, True, 0)
        caixa = self._pagina("Crie sua conta",
                             "É com ela que você entra no Matsu e muda os ajustes do sistema.",
                             topo=self.avatar, espaco_topo=28)
        grade = Gtk.Grid(column_spacing=14, row_spacing=10)
        grade.set_halign(Gtk.Align.CENTER)
        classes(grade, "miolo")

        def campo(linha, texto, senha=False, dica=""):
            r = rotulo(texto, "campo-nome", xalign=1)
            grade.attach(r, 0, linha, 1, 1)
            e = classes(Gtk.Entry(), "campo")
            e.set_size_request(320, -1)
            e.set_visibility(not senha)
            if senha:
                e.set_invisible_char("•")
            if dica:
                e.set_placeholder_text(dica)
            grade.attach(e, 1, linha, 1, 1)
            return e

        self.campo_nome = campo(0, "Nome", dica="Seu nome")
        self.campo_usuario = campo(1, "Usuário", dica="nome curto, sem espaço")
        self.campo_senha = campo(2, "Senha", True)
        self.campo_confirmacao = campo(3, "Confirmar senha", True)
        self.campo_nome.connect("changed", self._nome_mudou)
        self.campo_usuario.connect("changed", self._usuario_mudou)
        self.campo_senha.connect("changed", lambda e: self._campo("senha", e.get_text()))
        self.campo_confirmacao.connect("changed", lambda e: self._campo("confirmacao", e.get_text()))
        self.campo_confirmacao.connect("activate", lambda *_: self.seguir())
        caixa.pack_start(grade, False, False, 0)
        self.aviso_conta = rotulo(" ", "aviso", wrap=True, largura=60)
        caixa.pack_start(self.aviso_conta, False, False, 0)
        self._atualizar_avatar()
        return caixa

    def _nome_mudou(self, e):
        self.escolhas["nome"] = e.get_text()
        if not self.usuario_mexido:
            self._mudando_usuario = True
            self.campo_usuario.set_text(motor.usuario_do_nome(e.get_text()) if e.get_text().strip() else "")
            self._mudando_usuario = False
        self._atualizar_avatar()
        self._validar_conta()

    def _usuario_mudou(self, e):
        if not getattr(self, "_mudando_usuario", False):
            self.usuario_mexido = bool(e.get_text())
        self.escolhas["usuario"] = e.get_text()
        self._validar_conta()

    def _campo(self, chave, valor):
        self.escolhas[chave] = valor
        self._validar_conta()

    def _atualizar_avatar(self):
        nome = self.escolhas["nome"].strip()
        self.letra.set_label(nome[:1].upper())
        self.letra.set_visible(bool(nome))
        self.avatar_icone.set_visible(not nome)

    def _validar_conta(self):
        e = self.escolhas
        aviso = ""
        if e["usuario"]:
            aviso = motor.problema_no_usuario(e["usuario"])
        if not aviso and e["senha"] and (e["confirmacao"] or len(e["senha"]) < 6):
            aviso = motor.problema_na_senha(e["senha"], e["confirmacao"])
            if aviso.startswith("A senha precisa") and self.get_focus() is self.campo_senha:
                aviso = ""
        self.aviso_conta.set_label(aviso or " ")
        self.atualizar_rodape()

    # Resumo
    def _tela_resumo(self):
        caixa = self._pagina("Tudo pronto para instalar",
                             "Confira antes de começar. Depois que começar, deixe o computador ligado até o fim.")
        self.miolo_resumo = self._miolo(600)
        caixa.pack_start(self.miolo_resumo, False, False, 0)
        return caixa

    def _entrar_resumo(self):
        m = self.miolo_resumo
        for filho in m.get_children():
            m.remove(filho)
        e = self.escolhas
        d = self.disco_escolhido() or {"modelo": "?", "tamanho": 0, "sistemas": []}
        lista = Lista()
        modo = {"apagar": "apagar tudo" if not d.get("vazio") else "disco inteiro",
                "lado": "ao lado do que já existe"}.get(e["modo"], "")
        lista.adicionar("disco", "Disco", clicavel=False,
                        valor=f"{d['modelo']} ({motor.tamanho(d['tamanho'])}) · {modo}")
        lista.adicionar("conta", "Conta", clicavel=False, valor=f"{e['nome'].strip()} ({e['usuario']})")
        lista.adicionar("idioma", "Idioma", clicavel=False, valor=dict(motor.IDIOMAS)[e["idioma"]])
        lista.adicionar("teclado", "Teclado", clicavel=False,
                        valor=next(t[3] for t in motor.TECLADOS if t[0] == e["teclado"]))
        lista.adicionar("fuso", "Fuso horário", clicavel=False, valor=dict(motor.FUSOS)[e["fuso"]])
        rede = {"cabo": "Cabo de rede", "wifi": f"Wi-Fi {self.rede['nome']}"}.get(self.rede["tipo"], "Conectado")
        lista.adicionar("rede", "Internet", clicavel=False, valor=rede)
        m.pack_start(lista, False, False, 0)
        if e["modo"] == "apagar" and not d.get("vazio"):
            alerta = classes(Gtk.Box(spacing=10), "alerta")
            img = icone("alerta", "vermelho", 20)
            img.set_valign(Gtk.Align.START)
            alerta.pack_start(img, False, False, 0)
            outros = " e o ".join(d["sistemas"])
            texto = f"Tudo o que está no {d['modelo']} vai ser apagado"
            texto += f", inclusive o {outros}." if outros else "."
            alerta.pack_start(rotulo(texto, "alerta-texto", wrap=True, xalign=0), True, True, 0)
            m.pack_start(alerta, False, False, 6)
        m.show_all()

    # Instalando
    def _tela_instalando(self):
        logo = icone("logo", px=88)
        self.logo_instalando = logo
        caixa = self._pagina(f"Instalando o {NOME}", topo=logo, espaco_topo=78)
        m = self._miolo(440)
        self.barra = classes(Gtk.ProgressBar(), "barra")
        m.pack_start(self.barra, False, False, 10)
        self.estado_instalacao = rotulo("Começando", "estado")
        m.pack_start(self.estado_instalacao, False, False, 0)
        m.pack_start(rotulo("Leva uns 15 minutos, dependendo da internet. Deixe o computador ligado.",
                            "subtitulo", wrap=True), False, False, 2)
        caixa.pack_start(m, False, False, 0)
        dica = classes(Gtk.Box(spacing=10), "dica")
        dica.set_halign(Gtk.Align.CENTER)
        dica.set_valign(Gtk.Align.END)
        dica.set_vexpand(True)
        dica.set_margin_bottom(30)
        dica.pack_start(icone("info", "suave", 18), False, False, 0)
        self.texto_dica = rotulo(DICAS[0], "dica-texto", wrap=True, xalign=0, largura=62)
        dica.pack_start(self.texto_dica, True, True, 0)
        self.qual_dica = 0
        caixa.pack_end(dica, True, True, 0)
        self.fracao_mostrada = 0.0
        return caixa

    def _trocar_dica(self):
        if self.tela != "instalando":
            return False

        def trocar():
            self.qual_dica = (self.qual_dica + 1) % len(DICAS)
            self.texto_dica.set_label(DICAS[self.qual_dica])
            suave(0, 1, 420, self.texto_dica.set_opacity)

        suave(1, 0, 300, self.texto_dica.set_opacity, trocar)
        return True

    def instalar(self):
        self.ir("instalando")
        GLib.timeout_add_seconds(9, self._trocar_dica)
        if DEMO:
            self._instalacao_demo()
            return
        e = self.escolhas
        try:
            base = open("/run/matsu/base.ks", encoding="utf-8").read() \
                if os.path.exists("/run/matsu/base.ks") else open("/run/install/ks.cfg", encoding="utf-8").read()
            senha = motor.cifrar_senha(e["senha"])
            ks = motor.gerar_kickstart(base, e, senha)
        except (OSError, ValueError, StopIteration) as erro:
            self._mostrar_erro(f"Não deu para preparar a instalação ({erro}).", "")
            return
        try:
            info = json.load(open(os.path.join(AQUI, "imagem.json"), encoding="utf-8"))
            bytes_imagem = int(info.get("bytes", 0))
        except (OSError, ValueError):
            bytes_imagem = 0
        marcar("instalando no " + e["disco"] + " (" + e["modo"] + ")")
        self.instalacao = motor.Instalacao(ks, lambda p: GLib.idle_add(self._progresso, p), bytes_imagem)
        try:
            self.instalacao.comecar()
        except OSError as erro:
            self._mostrar_erro(f"O instalador não abriu ({erro}).", "")

    def _instalacao_demo(self):
        p = motor.Progresso(4_300_000_000)
        mensagens = ["Setting up the installation environment", "Configuring storage", "Creating disklabel on /dev/nvme0n1",
                     "Running pre-installation scripts", "Installing the software", "Deployment starting: x"]
        para = os.environ.get("MATSU_INSTALADOR_PARAR", "")

        def passo(i=[0]):  # noqa: B006 - contador da demonstração
            if i[0] < len(mensagens):
                p.linha(mensagens[i[0]])
            elif p.etapa == "baixando" and p.baixado < p.bytes_da_imagem:
                p.bytes_recebidos(int(p.baixado + 160_000_000), 0)
                if para == "baixando" and p.baixado > 1_700_000_000:
                    self._progresso(p)
                    return False
            else:
                resto = ["Deployment complete: x", "Installing boot loader", "Creating users",
                         "Running post-installation scripts", "Complete!", "Installation complete"]
                k = i[0] - len(mensagens)
                if k >= len(resto):
                    return False
                p.linha(resto[k])
                if para == "erro" and resto[k] == "Creating users":
                    p.erro = "Command 'useradd' exited with status 1"
            self._progresso(p)
            if p.etapa != "baixando" or i[0] < len(mensagens):
                i[0] += 1
            elif p.baixado >= p.bytes_da_imagem:
                i[0] += 1
            return not p.pronto and not p.erro

        GLib.timeout_add(450, passo)

    def _progresso(self, p):
        if p.erro:
            detalhes = self.instalacao.ultimas_linhas() if self.instalacao else p.erro
            self._mostrar_erro(self._erro_amigavel(p.erro), detalhes)
            return False
        self.estado_instalacao.set_label(p.texto())
        alvo = p.fracao
        de = self.fracao_mostrada
        if alvo > de:
            self.fracao_mostrada = alvo
            suave(de, alvo, 600, self.barra.set_fraction)
        if p.pronto and not self.chegou_ao_fim:
            self.chegou_ao_fim = True
            marcar("instalação concluída")
            GLib.timeout_add(900, lambda: self.ir("pronto") or False)
        return False

    def _erro_amigavel(self, erro):
        texto = erro.lower()
        if any(x in texto for x in ("could not resolve", "network", "timed out", "connection", "registry")):
            return "A internet falhou durante o download do Matsu. Confira a conexão e tente de novo."
        if "space" in texto or "espaço" in texto:
            return "Não coube no espaço livre do disco. Tente apagar o disco inteiro ou liberar mais espaço."
        return "Algo deu errado durante a instalação. Você pode reiniciar e tentar de novo, ou usar o instalador avançado."

    # Pronto
    def _tela_pronto(self):
        selo = classes(Gtk.Box(), "selo", "selo-ok")
        img = icone("certo", "claro", 40)
        img.set_hexpand(True)
        selo.pack_start(img, True, True, 0)
        self.selo_ok = selo
        caixa = self._pagina("O Matsu está instalado",
                             "Tire o pendrive e clique em Reiniciar. Na volta, é só entrar com a senha que você criou.",
                             topo=selo, centro=True)
        return caixa

    def _entrar_pronto(self):
        self.selo_ok.set_opacity(0)
        suave(0, 1, 500, self.selo_ok.set_opacity)

    # Erro
    def _tela_erro(self):
        selo = classes(Gtk.Box(), "selo", "selo-erro")
        img = icone("alerta", "vermelho", 36)
        img.set_hexpand(True)
        selo.pack_start(img, True, True, 0)
        caixa = self._pagina("A instalação não terminou", topo=selo, centro=True)
        self.texto_erro = rotulo("", "subtitulo", wrap=True, largura=60)
        self.texto_erro.set_halign(Gtk.Align.CENTER)
        caixa.pack_start(self.texto_erro, False, False, 0)
        self.expansor = classes(Gtk.Expander(label="Detalhes"), "detalhes")
        self.expansor.set_halign(Gtk.Align.CENTER)
        rolar = Gtk.ScrolledWindow()
        rolar.set_size_request(600, 170)
        self.texto_detalhes = classes(Gtk.TextView(), "registro")
        self.texto_detalhes.set_editable(False)
        self.texto_detalhes.set_monospace(True)
        self.texto_detalhes.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        rolar.add(self.texto_detalhes)
        self.expansor.add(rolar)
        caixa.pack_start(self.expansor, False, False, 6)
        return caixa

    def _mostrar_erro(self, texto, detalhes):
        marcar("erro: " + texto)
        self.texto_erro.set_label(texto)
        self.texto_detalhes.get_buffer().set_text(detalhes or texto)
        self.expansor.set_visible(bool(detalhes))
        self.ir("erro")

    # Instalador avançado
    def _tela_avancado(self):
        selo = classes(Gtk.Box(), "selo")
        img = icone("engrenagem", "escuro", 34)
        img.set_hexpand(True)
        selo.pack_start(img, True, True, 0)
        return self._pagina("Instalador avançado",
                            "Tem todas as opções: escolher as partições à mão, proteger o disco com senha e mais. "
                            "Instala o mesmo Matsu, só que com telas mais técnicas.",
                            topo=selo, centro=True)


def main():
    janela = Instalador()
    janela.show()
    if os.environ.get("MATSU_INSTALADOR_PREENCHER") == "1":
        janela.campo_nome.set_text("Kaiky Oliveira")
        janela.campo_senha.set_text("segredo123")
        janela.campo_confirmacao.set_text("segredo123")
        janela.escolhas.update(disco="/dev/nvme0n1", modo="apagar")
        janela._montar_discos()
        if janela.tela == "resumo":
            # Na demonstração, espera os discos e a rede de mentira chegarem.
            GLib.timeout_add(1200, lambda: janela._entrar_resumo() or janela.atualizar_rodape() or False)
    if TELA_INICIAL == "instalando":
        janela.instalar()
    if TELA_INICIAL == "erro":
        janela._mostrar_erro("Algo deu errado durante a instalação. Você pode reiniciar e tentar de novo, "
                             "ou usar o instalador avançado.", "Traceback (most recent call last):\n  ...")
    Gtk.main()
    return janela.codigo_de_saida


if __name__ == "__main__":
    sys.exit(main())
