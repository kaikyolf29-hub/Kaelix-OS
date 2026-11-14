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

Também põe a tela de sair do Matsu (/usr/share/matsu/telas/sair) no lugar da do KDE:
no Plasma 6.8 ela fica no pacote do shell (pasta logout, ao lado da lockscreen);
antes, no visual (look-and-feel) do Matsu escuro e claro.
Os arquivos do KDE trocados ficam guardados em /usr/share/matsu/telas/originais
(para comparar quando o Plasma mudar).

Uso: telas-matsu.py [pasta lockscreen]   (padrão: a pasta do sistema)
"""
import re
import sys
from pathlib import Path

PASTA = Path(sys.argv[1] if len(sys.argv) > 1 else
             "/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen")

IMPORTE = 'import "file:///usr/share/matsu/telas" as Matsu'
ORIGINAIS = Path("/usr/share/matsu/telas/originais")
SAIR_MATSU = Path("/usr/share/matsu/telas/sair")
VISUAIS = Path("/usr/share/plasma/look-and-feel")

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
    guardar(arquivo)
    arquivo.write_text(novo, encoding="utf-8")
    print("Tela de bloqueio: desenho do Matsu (hora grande, foto, senha em pílula)")
    return 0


def guardar(arquivo):
    """Guarda o arquivo do KDE como veio, antes de trocar."""
    try:
        ORIGINAIS.mkdir(parents=True, exist_ok=True)
        (ORIGINAIS / arquivo.name).write_bytes(arquivo.read_bytes())
    except OSError as erro:
        print(f"AVISO: não deu para guardar {arquivo}: {erro}")


def trocar_sair():
    """Põe a tela de sair do Matsu no lugar da do KDE. Devolve as pastas trocadas."""
    nossa = SAIR_MATSU / "Logout.qml"
    if not nossa.is_file():
        print(f"AVISO: falta {nossa}; a tela de sair fica a do KDE")
        return []
    do_shell = PASTA.parent / "logout"
    if (do_shell / "Logout.qml").is_file():
        pastas = [do_shell]  # Plasma 6.8 em diante
    else:
        pastas = [VISUAIS / v / "contents" / "logout" for v in ("org.matsu.escuro.desktop", "org.matsu.claro.desktop")
                  if (VISUAIS / v / "contents").is_dir()]
    feitas = []
    for pasta in pastas:
        pasta.mkdir(parents=True, exist_ok=True)
        if (pasta / "Logout.qml").is_file() and IMPORTE not in (pasta / "Logout.qml").read_text(encoding="utf-8"):
            guardar(pasta / "Logout.qml")
        for nome in ("Logout.qml", "contagem.js"):
            (pasta / nome).write_bytes((SAIR_MATSU / nome).read_bytes())
        feitas.append(pasta)
        print(f"Tela de sair do Matsu em {pasta}")
    if not feitas:
        print("AVISO: não achei onde fica a tela de sair; ela fica a do KDE")
    return feitas


if __name__ == "__main__":
    codigo = main()
    trocar_sair()
    sys.exit(codigo)
