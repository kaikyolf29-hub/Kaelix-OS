#!/usr/bin/env python3
"""Manda comandos para o monitor do QEMU (HMP) por um socket unix.

Uso:
  hmp.py <socket> shot <arquivo.png>      tira um print da tela
  hmp.py <socket> key <tecla> [...]       aperta teclas (ex.: ctrl-alt-t, ret, esc)
  hmp.py <socket> type <texto>            digita um texto simples (letras, números, espaço, - . / _ |)
  hmp.py <socket> click <x> <y> [largura altura]   clica com o mouse num ponto da tela (padrão 1920x1080)
  hmp.py <socket> rclick <x> <y> [largura altura]  o mesmo, com o botão direito

O clique vai pelo socket QMP, que fica ao lado do monitor: <socket>.qmp
"""
import json
import socket
import sys
import time

KEYMAP = {" ": "spc", "-": "minus", ".": "dot", "/": "slash", "_": "shift-minus", "|": "shift-backslash", "\n": "ret"}


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
                key = f"shift-{ch.lower()}" if ch.isupper() else ch
            send(sock_path, f"sendkey {key}")
            time.sleep(0.08)
    elif action == "click":
        clique(sock_path, *[int(a) for a in args])
    elif action == "rclick":
        clique(sock_path, *[int(a) for a in args], botao="right")
    else:
        sys.exit(f"ação desconhecida: {action}")


if __name__ == "__main__":
    main()
