#!/usr/bin/env python3
"""Troca o desenho da tela de bloqueio do KDE pelo do Matsu (no jeito do Mac).

A tela de bloqueio do Plasma 6 fica no pacote do shell
(/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/), em QML
lido do disco. Este script mexe só no LockScreenUi.qml, com trocas exatas:
  - importa as peças do Matsu (/usr/share/matsu/telas);
  - no lugar do desfoque do papel de parede (WallpaperFader) e do relógio do KDE,
    o fundo limpo com escurecido leve (Matsu.Fundo) e a hora grande (Matsu.Relogio);
  - no lugar do MainBlock, o MatsuBloco (foto, nome, senha em pílula e botões).
Tudo o que destrava (authenticator, PasswordSync, teclado virtual) continua o do KDE.
Se o KDE mudar o arquivo e uma troca não servir, nenhuma troca é feita e a tela
fica como veio (funcionando), com AVISO no registro da montagem.

Uso: telas-matsu.py [pasta lockscreen]   (padrão: a pasta do sistema)
"""
import re
import sys
from pathlib import Path

PASTA = Path(sys.argv[1] if len(sys.argv) > 1 else
             "/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen")

IMPORTE = 'import "file:///usr/share/matsu/telas" as Matsu'

FUNDO_E_HORA = '''        // Matsu: o papel de parede limpo, como no Mac (sem o desfoque do KDE), com
        // um escurecido leve em cima e embaixo para a hora e a senha.
        Matsu.Fundo {
            anchors.fill: parent
        }

        // Matsu: a hora grande em cima, com a data pequena acima dela.
        Matsu.Relogio {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.075)
            altura: parent.height
            visible: config.alwaysShowClock
        }
'''


def trocar(texto):
    """Devolve (texto novo, lista de problemas). Com problema, o texto volta igual."""
    problemas = []
    novo = texto
    if IMPORTE in novo:
        return texto, ["já trocado antes"]
    # 1. As peças do Matsu.
    if novo.count("import org.kde.breeze.components\n") == 1:
        novo = novo.replace("import org.kde.breeze.components\n",
                            "import org.kde.breeze.components\n" + IMPORTE + "\n")
    else:
        problemas.append("não achei o import org.kde.breeze.components")
    # 2. Do WallpaperFader até o fim do Clock: o fundo limpo e a hora do Matsu.
    padrao = re.compile(r"        WallpaperFader \{\n.*?\n        Clock \{\n.*?\n        \}\n", re.S)
    achados = padrao.findall(novo)
    if len(achados) == 1:
        novo = padrao.sub(lambda _m: FUNDO_E_HORA, novo)
    else:
        problemas.append(f"o trecho WallpaperFader…Clock apareceu {len(achados)} vezes")
    # 3. O miolo do Matsu no lugar do MainBlock.
    if novo.count("initialItem: MainBlock {") == 1:
        novo = novo.replace("initialItem: MainBlock {", "initialItem: MatsuBloco {")
    else:
        problemas.append("não achei o initialItem: MainBlock")
    # O resto do arquivo não pode falar mais do desfoque nem da sombra do relógio.
    for resto in ("clockShadow", "WallpaperFader"):
        if resto in novo and not problemas:
            problemas.append(f"sobrou {resto} no arquivo")
    return (texto, problemas) if problemas else (novo, [])


def main():
    arquivo = PASTA / "LockScreenUi.qml"
    if not arquivo.is_file():
        print(f"AVISO: {arquivo} não existe; a tela de bloqueio fica a do KDE")
        return 0
    if not (PASTA / "MatsuBloco.qml").is_file():
        print(f"AVISO: falta {PASTA / 'MatsuBloco.qml'}; a tela de bloqueio fica a do KDE")
        return 0
    texto = arquivo.read_text(encoding="utf-8")
    novo, problemas = trocar(texto)
    if problemas:
        for p in problemas:
            print(f"AVISO: tela de bloqueio: {p}; ela fica a do KDE")
        return 0
    arquivo.write_text(novo, encoding="utf-8")
    print("Tela de bloqueio: desenho do Matsu (hora grande, foto, senha em pílula)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
