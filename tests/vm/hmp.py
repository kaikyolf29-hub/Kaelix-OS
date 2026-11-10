#!/usr/bin/env python3
"""Manda comandos para o monitor do QEMU (HMP) por um socket unix.

Uso:
  hmp.py <socket> shot <arquivo.png>      tira um print da tela
  hmp.py <socket> key <tecla> [...]       aperta teclas (ex.: ctrl-alt-t, ret, esc)
  hmp.py <socket> type <texto>            digita um texto simples (letras, números, espaço, - . / _)
"""
import socket
import sys
import time

KEYMAP = {" ": "spc", "-": "minus", ".": "dot", "/": "slash", "_": "shift-minus", "\n": "ret"}


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
    else:
        sys.exit(f"ação desconhecida: {action}")


if __name__ == "__main__":
    main()
