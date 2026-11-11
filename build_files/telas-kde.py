#!/usr/bin/env python3
"""Dá a cara do Matsu às telas de login, de bloqueio e de sair do KDE.

Essas telas vêm prontas dentro dos programas do KDE, mas usam peças que ficam
em arquivos (relógio, foto da pessoa e botões redondos). Este script troca só
o desenho dessas peças, com trocas exatas de texto: se o KDE mudar o arquivo e
uma troca não servir mais, ela é pulada (com aviso no registro) e a peça fica
como veio, funcionando. Nada aqui mexe na senha ou no desbloqueio.

Uso: telas-kde.py [pasta das peças]   (padrão: a pasta do sistema)
"""
import sys
from pathlib import Path

PASTA = Path(sys.argv[1] if len(sys.argv) > 1 else "/usr/lib64/qt6/qml/org/kde/breeze/components")

TROCAS = {
    # Botões redondos (desligar, reiniciar, sair, trocar de usuário): vidro
    # sempre visível, como as pílulas das ilhas, e mais claro ao passar o mouse.
    "ActionButton.qml": [
        ("return root.softwareRendering ? 0.8 : 0.15", "return root.softwareRendering ? 0.8 : 0.26"),
        ("return root.softwareRendering ? 0.6 : 0\n", "return root.softwareRendering ? 0.6 : 0.13\n"),
    ],
    # Hora em negrito, como na ilha da direita.
    "Clock.qml": [
        ("font.weight: Font.DemiBold", "font.weight: Font.Bold"),
    ],
    # Foto da pessoa num círculo da cor de destaque (o anil do Matsu, ou a cor
    # do vidro que a pessoa escolheu), que aparece quando não há foto, e
    # o nome em negrito.
    "UserDelegate.qml": [
        ("        color: Kirigami.Theme.backgroundColor\n        opacity: 0.6\n",
         "        color: Kirigami.Theme.highlightColor\n        opacity: 0.92\n"),
        ("        font.pointSize: wrapper.fontSize + 4\n",
         "        font.pointSize: wrapper.fontSize + 4\n        font.weight: Font.DemiBold\n"),
    ],
}


def main():
    feitas = puladas = 0
    for nome, trocas in TROCAS.items():
        arquivo = PASTA / nome
        if not arquivo.is_file():
            print(f"AVISO: {arquivo} não existe; fica como veio")
            puladas += len(trocas)
            continue
        texto = original = arquivo.read_text(encoding="utf-8")
        for antes, depois in trocas:
            if texto.count(antes) == 1:
                texto = texto.replace(antes, depois)
                feitas += 1
            else:
                print(f"AVISO: {nome}: a troca de {antes.strip()[:50]!r} não serviu; essa parte fica como veio")
                puladas += 1
        if texto != original:
            arquivo.write_text(texto, encoding="utf-8")
    print(f"Telas de login, bloqueio e sair: {feitas} trocas feitas, {puladas} puladas")


if __name__ == "__main__":
    main()
