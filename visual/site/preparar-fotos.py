#!/usr/bin/python3
"""Prepara as fotos do site a partir das prints de verdade do sistema.

As fotos da área de trabalho e das janelas vêm das prints que o fluxo "Testar e
tirar prints" tira da imagem montada (ramo prints, pasta ultimo). As dos apps
novos (Relógio, Calendário, Notas...) vêm das prévias com dados de exemplo
(/mnt/project-files/kaelix-os/apps-novos/), porque na VM eles abrem vazios.
A do instalador vem das prints do teste da ISO (ramo prints-instalador, pasta
ultimo). O passo 1 (gravar o pendrive) é desenhado no próprio site, em código.

Uso:
  git fetch origin prints
  git archive origin/prints ultimo | tar -x -C /tmp/prints
  git fetch origin prints-instalador
  git archive origin/prints-instalador ultimo | tar -x -C /tmp/prints-iso
  python3 visual/site/preparar-fotos.py /tmp/prints/ultimo <pasta apps-novos> /tmp/prints-iso/ultimo

Uma pasta vazia ("") pula as fotos dela e deixa as que já estão no site.

Cada foto vira um .webp em site/public/img/. Uma print que não existe é
pulada e o nome sai na lista do fim.
"""
import os
import sys

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DESTINO = os.path.join(RAIZ, "site", "public", "img")

# nome no site: (pasta, arquivo, recorte (esq, topo, dir, baixo) ou None, larguras)
# Pastas: "vm" = prints da VM, "apps" = prévias, "iso" = prints do instalador.
FOTOS = {
    # A tela inteira, nas abas de "Você já sabe usar".
    "tela-menu": ("vm", "04d-menu.png", None, (1600, 800)),
    "tela-central": ("vm", "22-central-de-controle-escuro.png", None, (1600, 800)),
    "tela-bloqueio": ("vm", "23-tela-de-bloqueio.png", None, (1600, 800)),
    "tela-claro": ("vm", "11-tema-claro-area-de-trabalho.png", None, (1600, 800)),
    # Só a janela de cada app (o retângulo exato dela na tela de 1920x1080).
    "janela-jogos": ("vm", "36-jogos-inicio.png", (385, 141, 1534, 858), (1149, 640)),
    "janela-loja": ("vm", "37-loja-inicio.png", (367, 123, 1552, 876), (1185, 640)),
    "janela-seguranca": ("vm", "38-seguranca-inicio.png", (403, 141, 1516, 858), (1113, 640)),
    "janela-arquivos": ("vm", "40-app-00-org.matsu.arquivos.png", (461, 189, 1459, 809), (998, 640)),
    "janela-tarefas": ("vm", "34-gerenciador-processos.png", (421, 159, 1498, 840), (1077, 640)),
    # Apps novos: cada prévia tem o tema escuro à esquerda e o claro à direita.
    "app-calendario": ("apps", "calendario.png", "metade", (995,)),
    "app-notas": ("apps", "notas.png", "metade", (1000,)),
    "app-musica": ("apps", "musica.png", "metade", (966,)),
    "app-relogio": ("apps", "relogio.png", "metade", (982,)),
    # Instalação, passo a passo.
    "passo-boot": ("vm", "01a-tela-de-boot-5.png", None, (1280,)),
    # O cartão do instalador no meio, com um pouco do papel de parede em volta (16:9).
    "passo-instalador": ("iso", "08-resumo.png", (240, 135, 1680, 945), (1440, 800)),
    "passo-boasvindas": ("vm", "16-boas-vindas-2.png", None, (1600, 800)),
}


def main(pastas):
    os.makedirs(DESTINO, exist_ok=True)
    faltou = []
    for nome, (pasta, origem, recorte, larguras) in FOTOS.items():
        caminho = os.path.join(pastas[pasta], origem) if pastas.get(pasta) else ""
        if not caminho or not os.path.exists(caminho):
            faltou.append(f"{nome} ({origem})")
            continue
        im = Image.open(caminho).convert("RGB")
        if recorte == "metade":
            im = im.crop((0, 0, im.width // 2, im.height))
        elif recorte:
            im = im.crop(recorte)
        for i, largura in enumerate(larguras):
            copia = im
            if copia.width != largura:
                copia = im.resize((largura, round(im.height * largura / im.width)), Image.LANCZOS)
            sufixo = "" if i == 0 else f"-{largura}"
            copia.save(os.path.join(DESTINO, f"{nome}{sufixo}.webp"), "WEBP", quality=84, method=6)
        print(f"{nome}.webp  <- {origem}")
    if faltou:
        print("ficaram de fora:", ", ".join(faltou))
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__.strip())
        sys.exit(2)
    args = sys.argv[1:] + ["", "", ""]
    sys.exit(main({"vm": args[0], "apps": args[1], "iso": args[2]}))
