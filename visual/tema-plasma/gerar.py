#!/usr/bin/env python3
"""Atalho para o gerador do vidro do Matsu, que agora vai dentro da imagem
(o comando "matsu vidro" usa o mesmo arquivo para a cor que a pessoa escolhe).

Uso: python3 visual/tema-plasma/gerar.py   (refaz o tema padrão da imagem)
"""
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
GERADOR = RAIZ / "system_files/usr/share/matsu/vidro/gerar.py"
TEMA = RAIZ / "system_files/usr/share/plasma/desktoptheme/Matsu"
sys.exit(subprocess.call([sys.executable, str(GERADOR), *sys.argv[1:], str(TEMA)]))
