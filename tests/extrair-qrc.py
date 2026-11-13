#!/usr/bin/env python3
"""Tira o QML que vem compilado dentro de um programa do KDE (recursos qrc).

O Qt 6 guarda os arquivos .qml dentro do programa, comprimidos com zstd (ou zlib).
Este script procura esses pedaços e grava os que são QML ou JavaScript em
<pasta>/<nome do programa>/NN.qml, para ler o desenho das telas do KDE.
Usado pelo fluxo "Extrair arquivos da imagem" (Python 3.14 do Fedora, com zstd).

Uso: extrair-qrc.py <programa> <pasta>
"""
import re
import sys
import zlib
from pathlib import Path

try:
    from compression import zstd
except ImportError:  # Python antigo: só zlib
    zstd = None


def pedacos(dados):
    if zstd:
        for m in re.finditer(rb"\x28\xb5\x2f\xfd", dados):
            try:
                yield zstd.ZstdDecompressor().decompress(dados[m.start():m.start() + 400000])
            except Exception:
                pass
    # qCompress: 4 bytes com o tamanho e o zlib logo depois.
    for m in re.finditer(rb"\x78[\x01\x5e\x9c\xda]", dados):
        try:
            yield zlib.decompressobj().decompress(dados[m.start():m.start() + 400000])
        except Exception:
            pass


def main():
    programa, pasta = Path(sys.argv[1]), Path(sys.argv[2])
    if programa.stat().st_size > 60_000_000:
        return
    dados = programa.read_bytes()
    if not dados.startswith(b"\x7fELF"):
        return
    achados = []
    for texto in pedacos(dados):
        inicio = texto[:4000]
        if len(texto) > 120 and (b"import Qt" in inicio or b"import org.kde" in inicio or b".pragma library" in inicio):
            if texto not in achados:
                achados.append(texto)
    if not achados:
        return
    destino = pasta / programa.name
    destino.mkdir(parents=True, exist_ok=True)
    for n, texto in enumerate(achados, 1):
        (destino / f"{n:02d}.qml").write_bytes(texto)
    print(f"{programa}: {len(achados)} arquivos QML")


if __name__ == "__main__":
    main()
