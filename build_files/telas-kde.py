#!/usr/bin/env python3
"""Dá a cara do Matsu à tela de login do KDE (Plasma Login Manager).

A tela de login vem compilada dentro do programa (/usr/libexec/plasma-login-greeter),
mas usa peças da Breeze que ficam em arquivos, em org/kde/breeze/components: a hora
(Clock), a foto da pessoa (UserDelegate), os botões redondos (ActionButton) e o miolo
com a senha (SessionManagementScreen). Este script põe as versões do Matsu dessas
quatro peças (/usr/share/matsu/telas/breeze, com as mesmas propriedades das do KDE)
no lugar das originais, que ficam guardadas em /usr/share/matsu/telas/originais/breeze.

O qmldir da Breeze tem "prefer :/qt/qml/...": com essa linha o Qt usa a cópia de
dentro da biblioteca e ignora os arquivos. Ela sai, para os arquivos valerem.

Tudo ou nada: se faltar alguma coisa (o qmldir, uma peça que ele lista, uma das
nossas), nada muda e a tela fica a do KDE, funcionando. Nada aqui mexe na senha.

Uso: telas-kde.py [pasta das peças do KDE] [pasta das peças do Matsu] [pasta dos originais]
"""
import shutil
import sys
from pathlib import Path

PASTA = Path(sys.argv[1] if len(sys.argv) > 1 else "/usr/lib64/qt6/qml/org/kde/breeze/components")
NOSSAS = Path(sys.argv[2] if len(sys.argv) > 2 else "/usr/share/matsu/telas/breeze")
ORIGINAIS = Path(sys.argv[3] if len(sys.argv) > 3 else "/usr/share/matsu/telas/originais/breeze")

PECAS = ("ActionButton.qml", "Clock.qml", "UserDelegate.qml", "SessionManagementScreen.qml")


def tipos_do_qmldir(texto):
    """Os arquivos .qml que o qmldir lista (nome do tipo, versão, arquivo)."""
    arquivos = []
    for linha in texto.splitlines():
        partes = linha.split()
        if len(partes) == 3 and partes[2].endswith(".qml") and partes[0][:1].isupper():
            arquivos.append(partes[2])
    return arquivos


def problemas():
    qmldir = PASTA / "qmldir"
    if not qmldir.is_file():
        return [f"{qmldir} não existe"]
    listados = tipos_do_qmldir(qmldir.read_text(encoding="utf-8"))
    faltas = []
    # Sem o "prefer", o Qt lê cada peça do disco: todas precisam estar lá.
    for nome in listados:
        if not (PASTA / nome).is_file():
            faltas.append(f"{PASTA / nome} não existe (o qmldir lista)")
    for nome in PECAS:
        if nome not in listados:
            faltas.append(f"o qmldir não lista {nome}")
        if not (NOSSAS / nome).is_file():
            faltas.append(f"falta a nossa {NOSSAS / nome}")
    # A lista de pessoas e o tremido da senha errada continuam os do KDE.
    for nome in ("UserList.qml", "RejectPasswordAnimation.qml"):
        if nome not in listados:
            faltas.append(f"o qmldir não lista {nome}")
    return faltas


def guardar(arquivo):
    ORIGINAIS.mkdir(parents=True, exist_ok=True)
    destino = ORIGINAIS / arquivo.name
    # Só a primeira vez: rodar de novo não pode guardar a nossa no lugar da do KDE.
    if not destino.exists():
        shutil.copy2(arquivo, destino)


def main():
    faltas = problemas()
    if faltas:
        for falta in faltas:
            print(f"AVISO: tela de login: {falta}")
        print("Tela de login: fica a do KDE (nada foi trocado)")
        return 0
    qmldir = PASTA / "qmldir"
    guardar(qmldir)
    for nome in PECAS:
        guardar(PASTA / nome)
        shutil.copyfile(NOSSAS / nome, PASTA / nome)
    linhas = qmldir.read_text(encoding="utf-8").splitlines(keepends=True)
    sem_prefer = [linha for linha in linhas if not linha.startswith("prefer ")]
    qmldir.write_text("".join(sem_prefer), encoding="utf-8")
    print(f"Tela de login do Matsu: {len(PECAS)} peças da Breeze trocadas "
          f"({len(linhas) - len(sem_prefer)} linha prefer tirada); originais em {ORIGINAIS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
