#!/usr/bin/python3
"""Prepara as fotos do site a partir das prints da máquina virtual.

As fotos do site são sempre do sistema de verdade: as prints que o fluxo
"Testar e tirar prints" tira da imagem montada (ramo prints, pasta ultimo).

Uso:
  git fetch origin prints && git archive origin/prints ultimo | tar -x -C /tmp/prints
  python3 visual/site/preparar-fotos.py /tmp/prints/ultimo

Cada foto vira um .webp em site/img/. Uma print que não existe é pulada (o
site esconde a foto que falta).
"""
import os
import sys

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# nome no site: (print de origem, recorte (esquerda, topo, direita, baixo) ou
# None para a tela inteira, largura final)
FOTOS = {
    # A área de trabalho com o menu aberto.
    "area-de-trabalho": ("site-01-menu.png", None, 1600),
    # Claro e escuro, lado a lado.
    "escuro": ("site-02-escuro.png", None, 960),
    "claro": ("site-03-claro.png", None, 960),
    # Os apps, cada um sozinho na tela.
    "jogos": ("site-10-jogos.png", None, 1600),
    "loja": ("site-11-loja.png", None, 1600),
    "arquivos": ("site-12-arquivos.png", None, 1200),
    "terminal": ("site-13-terminal.png", None, 1200),
    "tarefas": ("site-14-tarefas.png", None, 1200),
    "ajustes": ("site-15-ajustes.png", None, 1200),
    # A barra nos três estilos: só a faixa de baixo da tela.
    "barra-fusao": ("15-barra-de-volta-ao-padrao.png", (0, 940, 1920, 1080), 1920),
    "barra-windows": ("12-barra-estilo-windows.png", (0, 940, 1920, 1080), 1920),
    "barra-mac": ("13-barra-estilo-mac.png", (0, 940, 1920, 1080), 1920),
}


def main(pasta):
    destino = os.path.join(RAIZ, "site", "img")
    os.makedirs(destino, exist_ok=True)
    feitas = 0
    for nome, (origem, recorte, largura) in FOTOS.items():
        caminho = os.path.join(pasta, origem)
        if not os.path.exists(caminho):
            print(f"sem {origem}: {nome} fica de fora")
            continue
        im = Image.open(caminho).convert("RGB")
        if recorte:
            im = im.crop(recorte)
        if im.width != largura:
            im = im.resize((largura, round(im.height * largura / im.width)), Image.LANCZOS)
        im.save(os.path.join(destino, nome + ".webp"), "WEBP", quality=86, method=6)
        feitas += 1
        print(f"{nome}.webp  <- {origem}")
    print(f"{feitas} fotos prontas em {destino}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__.strip())
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
