#!/usr/bin/python3
"""Relógio do Matsu: o toque. Quem chama é o systemd do usuário (os timers dos
alarmes em ~/.config/systemd/user e os temporizadores agendados com systemd-run),
então toca mesmo com o app fechado e depois de reiniciar o computador.

Uso:
  tocar.py alarme <id> [--soneca]     mostra o aviso (Soneca / Parar) e toca o som
  tocar.py temporizador <id> <nome>   o aviso de fim do temporizador e o som

Toda a lógica fica no ajudante.py desta mesma pasta (carregado pelo caminho, porque
o Python roda com -I e não olha a pasta do script).
"""
import importlib.util
import os
import signal
import sys


def carregar_ajudante():
    caminho = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ajudante.py")
    spec = importlib.util.spec_from_file_location("relogio_ajudante", caminho)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


def main(args):
    if len(args) < 2 or args[0] not in ("alarme", "temporizador"):
        print(__doc__)
        return 2
    ajudante = carregar_ajudante()
    nome = args[2] if args[0] == "temporizador" and len(args) > 2 else ""
    return ajudante.tocar(args[0], args[1], nome=nome, soneca="--soneca" in args[2:])


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    sys.exit(main(sys.argv[1:]))
