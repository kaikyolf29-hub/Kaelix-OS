#!/usr/bin/env python3
"""Atalho para o gerador do vidro do Kaelix, que agora vai dentro da imagem
(o comando "kaelix vidro" usa o mesmo arquivo para a cor que a pessoa escolhe).

Uso: python3 visual/tema-plasma/gerar.py   (refaz o tema padrão da imagem)
"""
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
GERADOR = RAIZ / "system_files/usr/share/kaelix/vidro/gerar.py"
TEMA = RAIZ / "system_files/usr/share/plasma/desktoptheme/Kaelix"
sys.exit(subprocess.call([sys.executable, str(GERADOR), *sys.argv[1:], str(TEMA)]))
