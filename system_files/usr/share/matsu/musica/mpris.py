#!/usr/bin/python3
"""Música do Matsu: os controles de mídia do Plasma e as teclas do teclado (MPRIS).

A janela inicia este script com matsu.iniciar e conversa com ele por linhas JSON:

  a janela manda (matsu.escrever):  {"estado": "Playing", "titulo": "...", "artista": "...",
                                     "album": "...", "capa": "/caminho.jpg", "duracao": ms,
                                     "posicao": ms, "volume": 0..1, "aleatorio": bool,
                                     "repetir": "nao"|"tudo"|"uma", "id": "/caminho.mp3",
                                     "proxima": bool, "anterior": bool, "buscou": bool}
  o script responde (uma linha):    {"ok": true} ao publicar o nome no D-Bus, ou {"ok": false}
                                    e sai com o código 3 se faltar o dbus-python ou o PyGObject
  e manda os pedidos do Plasma:     {"cmd": "PlayPause"}, {"cmd": "Next"}, {"cmd": "Seek", "offset": ms},
                                    {"cmd": "SetPosition", "posicao": ms}, {"cmd": "Volume", "valor": 0..1}...

Publica org.mpris.MediaPlayer2.matsu_musica no barramento da sessão. Quando a
janela fecha (a entrada acaba), o script sai e o nome some do D-Bus.
"""
import hashlib
import json
import os
import sys
import time
from urllib.parse import quote

NOME = "org.mpris.MediaPlayer2.matsu_musica"
CAMINHO = "/org/mpris/MediaPlayer2"
RAIZ = "org.mpris.MediaPlayer2"
PLAYER = "org.mpris.MediaPlayer2.Player"
SEM_FAIXA = "/org/mpris/MediaPlayer2/TrackList/NoTrack"

REPETIR_PARA_MPRIS = {"nao": "None", "tudo": "Playlist", "uma": "Track"}
MPRIS_PARA_REPETIR = {v: k for k, v in REPETIR_PARA_MPRIS.items()}
TIPOS = ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-vorbis+ogg", "audio/opus", "audio/mp4", "audio/x-m4a",
         "audio/wav", "audio/x-wav"]


def uri_de(caminho):
    """file:///caminho com os caracteres especiais codificados (o Plasma pede uma URI válida)."""
    if not caminho:
        return ""
    if "://" in caminho:
        return caminho
    return "file://" + quote(caminho, safe="/")


def id_da_faixa(caminho):
    """Um caminho de objeto D-Bus válido para a faixa (só letras, números e _)."""
    if not caminho:
        return SEM_FAIXA
    return "/org/matsu/musica/faixa/m" + hashlib.sha1(caminho.encode("utf-8", "replace")).hexdigest()[:16]


class Estado:
    """O que a janela contou por último: dá as propriedades do MPRIS (sem depender do D-Bus)."""

    def __init__(self, relogio=time.monotonic):
        self.relogio = relogio
        self.status = "Stopped"
        self.titulo = ""
        self.artista = ""
        self.artista_album = ""
        self.album = ""
        self.capa = ""
        self.caminho = ""
        self.duracao = 0          # microssegundos
        self.posicao = 0          # microssegundos, no instante "quando"
        self.quando = relogio()
        self.volume = 1.0
        self.aleatorio = False
        self.repetir = "None"
        self.pode_proxima = False
        self.pode_anterior = False

    def posicao_agora(self):
        if self.status != "Playing":
            return int(self.posicao)
        andou = (self.relogio() - self.quando) * 1e6
        fim = self.duracao if self.duracao > 0 else float("inf")
        return int(max(0, min(fim, self.posicao + andou)))

    def metadados(self):
        m = {"mpris:trackid": id_da_faixa(self.caminho)}
        if self.caminho:
            m["xesam:title"] = self.titulo or os.path.basename(self.caminho)
            m["xesam:url"] = uri_de(self.caminho)
            if self.artista:
                m["xesam:artist"] = [self.artista]
            if self.artista_album:
                m["xesam:albumArtist"] = [self.artista_album]
            if self.album:
                m["xesam:album"] = self.album
            if self.duracao > 0:
                m["mpris:length"] = int(self.duracao)
            if self.capa:
                m["mpris:artUrl"] = uri_de(self.capa)
        return m

    def player(self):
        """Todas as propriedades de org.mpris.MediaPlayer2.Player."""
        tem = bool(self.caminho)
        return {
            "PlaybackStatus": self.status,
            "LoopStatus": self.repetir,
            "Rate": 1.0,
            "Shuffle": self.aleatorio,
            "Metadata": self.metadados(),
            "Volume": self.volume,
            "Position": self.posicao_agora(),
            "MinimumRate": 1.0,
            "MaximumRate": 1.0,
            "CanGoNext": self.pode_proxima,
            "CanGoPrevious": self.pode_anterior,
            "CanPlay": tem,
            "CanPause": tem,
            "CanSeek": tem and self.duracao > 0,
            "CanControl": True,
        }

    def atualizar(self, dados):
        """Aplica o que a janela mandou. Devolve (propriedades que mudaram, se houve um pulo)."""
        antes = self.player()
        antes.pop("Position")
        self.status = dados.get("estado", self.status) if dados.get("estado") in ("Playing", "Paused", "Stopped") else self.status
        for chave, attr in (("titulo", "titulo"), ("artista", "artista"), ("artistaAlbum", "artista_album"),
                            ("album", "album"), ("capa", "capa"), ("id", "caminho")):
            if chave in dados:
                setattr(self, attr, str(dados[chave] or ""))
        if "duracao" in dados:
            self.duracao = max(0, int(float(dados["duracao"] or 0) * 1000))
        if "posicao" in dados:
            self.posicao = max(0, int(float(dados["posicao"] or 0) * 1000))
            self.quando = self.relogio()
        if "volume" in dados:
            self.volume = max(0.0, min(1.0, float(dados["volume"])))
        if "aleatorio" in dados:
            self.aleatorio = bool(dados["aleatorio"])
        if "repetir" in dados:
            self.repetir = REPETIR_PARA_MPRIS.get(dados["repetir"], self.repetir)
        if "proxima" in dados:
            self.pode_proxima = bool(dados["proxima"])
        if "anterior" in dados:
            self.pode_anterior = bool(dados["anterior"])
        depois = self.player()
        depois.pop("Position")
        mudou = {k: v for k, v in depois.items() if antes.get(k) != v}
        return mudou, bool(dados.get("buscou"))


def em_portugues(ambiente=None):
    """Se o nome do player vai em português ("Música"): a primeira língua definida no ambiente."""
    amb = os.environ if ambiente is None else ambiente
    primeiro = amb.get("LANGUAGE", "").split(":")[0]
    for valor in (amb.get("MATSU_LANG"), amb.get("LC_ALL"), amb.get("LC_MESSAGES"), primeiro, amb.get("LANG")):
        if valor and not valor.startswith("C") and valor != "POSIX":
            return valor.startswith("pt")
    return False


def pedido(cmd, **extra):
    """A linha que vai para a janela."""
    d = {"cmd": cmd}
    d.update(extra)
    return json.dumps(d, ensure_ascii=False)


def pedido_set(interface, nome, valor):
    """O Plasma (ou o playerctl) mudando uma propriedade: vira um pedido para a janela."""
    if interface != PLAYER:
        return None
    if nome == "Volume":
        return pedido("Volume", valor=max(0.0, min(1.0, float(valor))))
    if nome == "Shuffle":
        return pedido("Shuffle", valor=bool(valor))
    if nome == "LoopStatus" and str(valor) in MPRIS_PARA_REPETIR:
        return pedido("Repetir", valor=MPRIS_PARA_REPETIR[str(valor)])
    return None


def ler_linhas(buffer, novo):
    """Junta o que chegou na entrada e separa as linhas completas: (linhas, o que sobrou)."""
    buffer += novo
    partes = buffer.split(b"\n")
    return [p.decode("utf-8", "replace") for p in partes[:-1] if p.strip()], partes[-1]


# ----- o lado do D-Bus (só carrega se o dbus-python e o PyGObject existirem) -----
PROPRIEDADES_XML = {
    RAIZ: [("CanQuit", "b", "read"), ("Fullscreen", "b", "read"), ("CanSetFullscreen", "b", "read"),
           ("CanRaise", "b", "read"), ("HasTrackList", "b", "read"), ("Identity", "s", "read"),
           ("DesktopEntry", "s", "read"), ("SupportedUriSchemes", "as", "read"),
           ("SupportedMimeTypes", "as", "read")],
    PLAYER: [("PlaybackStatus", "s", "read"), ("LoopStatus", "s", "readwrite"), ("Rate", "d", "readwrite"),
             ("Shuffle", "b", "readwrite"), ("Metadata", "a{sv}", "read"), ("Volume", "d", "readwrite"),
             ("Position", "x", "read"), ("MinimumRate", "d", "read"), ("MaximumRate", "d", "read"),
             ("CanGoNext", "b", "read"), ("CanGoPrevious", "b", "read"), ("CanPlay", "b", "read"),
             ("CanPause", "b", "read"), ("CanSeek", "b", "read"), ("CanControl", "b", "read")],
}


def main():
    try:
        import dbus
        import dbus.mainloop.glib
        import dbus.service
        from gi.repository import GLib
    except Exception as erro:  # noqa: BLE001 - qualquer falha aqui só desliga o MPRIS
        print(json.dumps({"ok": False, "erro": str(erro)}), flush=True)
        return 3

    pt = em_portugues()
    estado = Estado()

    def para_dbus(nome, valor):
        if nome == "Metadata":
            m = {}
            for k, v in valor.items():
                if k == "mpris:trackid":
                    m[k] = dbus.ObjectPath(v)
                elif k == "mpris:length":
                    m[k] = dbus.Int64(v)
                elif isinstance(v, list):
                    m[k] = dbus.Array(v, signature="s")
                else:
                    m[k] = dbus.String(v)
            return dbus.Dictionary(m, signature="sv")
        if nome == "Position":
            return dbus.Int64(valor)
        if isinstance(valor, bool):
            return dbus.Boolean(valor)
        if isinstance(valor, float):
            return dbus.Double(valor)
        if isinstance(valor, list):
            return dbus.Array(valor, signature="s")
        return dbus.String(valor)

    def raiz():
        return {"CanQuit": True, "Fullscreen": False, "CanSetFullscreen": False, "CanRaise": True,
                "HasTrackList": False, "Identity": "Música" if pt else "Music", "DesktopEntry": "org.matsu.musica",
                "SupportedUriSchemes": ["file"], "SupportedMimeTypes": TIPOS}

    def mandar(linha):
        try:
            sys.stdout.write(linha + "\n")
            sys.stdout.flush()
        except (BrokenPipeError, OSError):
            laco.quit()

    class Mpris(dbus.service.Object):
        def todas(self, interface):
            if interface == RAIZ:
                valores = raiz()
            elif interface == PLAYER:
                valores = estado.player()
            else:
                raise dbus.exceptions.DBusException("org.freedesktop.DBus.Error.UnknownInterface", interface)
            return {k: para_dbus(k, v) for k, v in valores.items()}

        @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ss", out_signature="v")
        def Get(self, interface, nome):
            todas = self.todas(interface)
            if nome not in todas:
                raise dbus.exceptions.DBusException("org.freedesktop.DBus.Error.UnknownProperty", nome)
            return todas[nome]

        @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="s", out_signature="a{sv}")
        def GetAll(self, interface):
            return dbus.Dictionary(self.todas(interface), signature="sv")

        @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ssv")
        def Set(self, interface, nome, valor):
            linha = pedido_set(interface, nome, valor)
            if linha:
                mandar(linha)

        @dbus.service.signal(dbus.PROPERTIES_IFACE, signature="sa{sv}as")
        def PropertiesChanged(self, interface, mudou, invalidadas):
            pass

        @dbus.service.method(dbus.INTROSPECTABLE_IFACE, out_signature="s", path_keyword="caminho",
                             connection_keyword="conexao")
        def Introspect(self, caminho, conexao):
            # O dbus-python não descreve as propriedades: acrescenta para quem lê a introspecção.
            xml = dbus.service.Object.Introspect(self, caminho, conexao)
            for interface, props in PROPRIEDADES_XML.items():
                linhas = "".join(f'    <property name="{n}" type="{t}" access="{a}"/>\n' for n, t, a in props)
                xml = xml.replace(f'<interface name="{interface}">\n', f'<interface name="{interface}">\n{linhas}', 1)
            return xml

        # org.mpris.MediaPlayer2
        @dbus.service.method(RAIZ)
        def Raise(self):
            mandar(pedido("Raise"))

        @dbus.service.method(RAIZ)
        def Quit(self):
            mandar(pedido("Quit"))

        # org.mpris.MediaPlayer2.Player
        @dbus.service.method(PLAYER)
        def Next(self):
            mandar(pedido("Next"))

        @dbus.service.method(PLAYER)
        def Previous(self):
            mandar(pedido("Previous"))

        @dbus.service.method(PLAYER)
        def Pause(self):
            mandar(pedido("Pause"))

        @dbus.service.method(PLAYER)
        def PlayPause(self):
            mandar(pedido("PlayPause"))

        @dbus.service.method(PLAYER)
        def Stop(self):
            mandar(pedido("Stop"))

        @dbus.service.method(PLAYER)
        def Play(self):
            mandar(pedido("Play"))

        @dbus.service.method(PLAYER, in_signature="x")
        def Seek(self, deslocamento):
            mandar(pedido("Seek", offset=int(deslocamento) // 1000))

        @dbus.service.method(PLAYER, in_signature="ox")
        def SetPosition(self, faixa, posicao):
            # Só vale para a faixa de agora (o MPRIS pede para ignorar se mudou).
            if str(faixa) == id_da_faixa(estado.caminho) and 0 <= int(posicao) <= max(estado.duracao, 0):
                mandar(pedido("SetPosition", posicao=int(posicao) // 1000))

        @dbus.service.method(PLAYER, in_signature="s")
        def OpenUri(self, uri):
            mandar(pedido("Abrir", uri=str(uri)))

        @dbus.service.signal(PLAYER, signature="x")
        def Seeked(self, posicao):
            pass

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    try:
        barramento = dbus.SessionBus()
        nome = dbus.service.BusName(NOME, barramento, do_not_queue=True)
    except dbus.exceptions.DBusException as erro:
        print(json.dumps({"ok": False, "erro": str(erro)}), flush=True)
        return 3
    objeto = Mpris(barramento, CAMINHO)
    laco = GLib.MainLoop()
    sobra = [b""]

    def chegou(fd, condicao):
        try:
            novo = os.read(fd, 65536)
        except OSError:
            novo = b""
        if not novo:
            laco.quit()
            return False
        linhas, sobra[0] = ler_linhas(sobra[0], novo)
        for linha in linhas:
            try:
                dados = json.loads(linha)
            except ValueError:
                continue
            if not isinstance(dados, dict):
                continue
            mudou, buscou = estado.atualizar(dados)
            if mudou:
                objeto.PropertiesChanged(PLAYER, {k: para_dbus(k, v) for k, v in mudou.items()}, [])
            if buscou:
                objeto.Seeked(dbus.Int64(estado.posicao_agora()))
        return True

    GLib.io_add_watch(sys.stdin.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, chegou)
    print(json.dumps({"ok": True, "nome": NOME}), flush=True)
    try:
        laco.run()
    except KeyboardInterrupt:
        pass
    del nome
    return 0


if __name__ == "__main__":
    sys.exit(main())
