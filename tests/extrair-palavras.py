#!/usr/bin/env python3
"""As palavras soltas (texto entre zeros) de dentro de um programa ou biblioteca.

Usado pelo extrair.yml para saber quais opções o MangoHud da imagem conhece:
cada opção do MangoHud.conf fica guardada como um texto separado na biblioteca.
Uso: extrair-palavras.py <arquivo>...
"""
import re
import sys

palavras = set()
for caminho in sys.argv[1:]:
    with open(caminho, "rb") as f:
        dados = f.read()
    palavras.update(p.decode() for p in re.findall(rb"(?<=\x00)[a-z][a-z0-9_]{1,40}(?=\x00)", dados))
print("\n".join(sorted(palavras)))
