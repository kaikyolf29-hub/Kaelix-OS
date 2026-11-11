#!/usr/bin/env python3
"""Manda comandos para o monitor do QEMU (HMP) por um socket unix.

Uso:
  hmp.py <socket> shot <arquivo.png>      tira um print da tela
  hmp.py <socket> key <tecla> [...]       aperta teclas (ex.: ctrl-alt-t, ret, esc)
  hmp.py <socket> type <texto>            digita um texto simples (letras, números, espaço, - . / _ |)
  hmp.py <socket> click <x> <y> [largura altura]   clica com o mouse num ponto da tela (padrão 1920x1080)
  hmp.py <socket> rclick <x> <y> [largura altura]  o mesmo, com o botão direito
  hmp.py <socket> segurar <mantida> <tecla> <segundos> <arquivo.png>
                                          segura uma tecla (ex.: alt), aperta outra (tab) e tira
                                          o print antes de soltar (para ver o Alt+Tab)

O clique vai pelo socket QMP, que fica ao lado do monitor: <socket>.qmp
"""
import json
import socket
import sys
import time

# Teclado americano na máquina virtual. Um caractere que não está aqui (nem é
# letra ou número) para o teste, em vez de sumir calado do que foi digitado.
KEYMAP = {
    " ": "spc", "\n": "ret", "-": "minus", "_": "shift-minus", "=": "equal", "+": "shift-equal",
    ".": "dot", ">": "shift-dot", ",": "comma", "<": "shift-comma", "/": "slash", "?": "shift-slash",
    ";": "semicolon", ":": "shift-semicolon", "'": "apostrophe", '"': "shift-apostrophe",
    "\\": "backslash", "|": "shift-backslash", "`": "grave_accent", "~": "shift-grave_accent",
    "[": "bracket_left", "]": "bracket_right", "{": "shift-bracket_left", "}": "shift-bracket_right",
    "!": "shift-1", "@": "shift-2", "#": "shift-3", "$": "shift-4", "%": "shift-5",
    "^": "shift-6", "&": "shift-7", "*": "shift-8", "(": "shift-9", ")": "shift-0",
}


def send(sock_path, cmd):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)
    s.settimeout(2)
    try:
        s.recv(4096)  # cabeçalho do monitor
    except socket.timeout:
        pass
    s.sendall((cmd + "\n").encode())
    time.sleep(0.3)
    try:
        s.recv(4096)
    except socket.timeout:
        pass
    s.close()


def qmp(sock_path, comandos):
    """Manda comandos pelo QMP (o protocolo em JSON do QEMU), que aceita posição absoluta do mouse."""
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)
    f = s.makefile("rw")
    f.readline()  # saudação
    for c in [{"execute": "qmp_capabilities"}] + comandos:
        f.write(json.dumps(c) + "\n")
        f.flush()
        while True:  # pula os eventos soltos até chegar a resposta deste comando
            r = json.loads(f.readline())
            if "return" in r or "error" in r:
                break
        time.sleep(0.15)
    s.close()


def clique(sock_path, x, y, largura=1920, altura=1080, botao="left"):
    def ev(eventos):
        return {"execute": "input-send-event", "arguments": {"events": eventos}}
    ax = int(x * 32767 / (largura - 1))
    ay = int(y * 32767 / (altura - 1))
    mover = ev([{"type": "abs", "data": {"axis": "x", "value": ax}}, {"type": "abs", "data": {"axis": "y", "value": ay}}])
    apertar = ev([{"type": "btn", "data": {"down": True, "button": botao}}])
    soltar = ev([{"type": "btn", "data": {"down": False, "button": botao}}])
    qmp(sock_path + ".qmp", [mover, mover, apertar, soltar])


def mover(sock_path, x, y, largura=1920, altura=1080):
    """Só leva o mouse até o ponto, sem clicar (para os balões de passar o mouse)."""
    ax = int(x * 32767 / (largura - 1))
    ay = int(y * 32767 / (altura - 1))
    ev = {"execute": "input-send-event", "arguments": {"events": [
        {"type": "abs", "data": {"axis": "x", "value": ax}}, {"type": "abs", "data": {"axis": "y", "value": ay}}]}}
    qmp(sock_path + ".qmp", [ev, ev])


def segurar(sock_path, mantida, tecla, segundos, arquivo):
    def ev(nome, apertada):
        return {"execute": "input-send-event", "arguments": {"events": [
            {"type": "key", "data": {"down": apertada, "key": {"type": "qcode", "data": nome}}}]}}
    qmp(sock_path + ".qmp", [ev(mantida, True), ev(tecla, True), ev(tecla, False)])
    time.sleep(segundos)
    send(sock_path, f"screendump {arquivo} -f png")
    time.sleep(1)
    qmp(sock_path + ".qmp", [ev(mantida, False)])


def main():
    sock_path, action, *args = sys.argv[1:]
    if action == "shot":
        send(sock_path, f"screendump {args[0]} -f png")
    elif action == "key":
        for k in args:
            send(sock_path, f"sendkey {k}")
            time.sleep(0.15)
    elif action == "type":
        for ch in " ".join(args):
            key = KEYMAP.get(ch)
            if key is None:
                if not (ch.isascii() and ch.isalnum()):
                    sys.exit(f"hmp.py: não sei digitar {ch!r}")
                key = f"shift-{ch.lower()}" if ch.isupper() else ch
            send(sock_path, f"sendkey {key}")
            time.sleep(0.08)
    elif action == "click":
        clique(sock_path, *[int(a) for a in args])
    elif action == "rclick":
        clique(sock_path, *[int(a) for a in args], botao="right")
    elif action == "mover":
        mover(sock_path, *[int(a) for a in args])
    elif action == "segurar":
        segurar(sock_path, args[0], args[1], float(args[2]), args[3])
    else:
        sys.exit(f"ação desconhecida: {action}")


if __name__ == "__main__":
    main()
