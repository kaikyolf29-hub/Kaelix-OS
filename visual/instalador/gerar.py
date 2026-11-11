#!/usr/bin/env python3
"""Cara do Matsu no instalador (Anaconda, o instalador do Fedora).

Gera as imagens e o estilo que entram na ISO como um "updates.img":
  - a faixa da esquerda com um pedaço do papel de parede em pixel art (as
    árvores, o lago e o céu estrelado) e o logo do Matsu em cima;
  - a barra de cima com o céu estrelado do papel de parede;
  - a configuração que manda o instalador usar esse estilo.

O nome "Matsu 27 OS" no lugar de "Fedora" vem do arquivo .buildstamp, que o
fluxo "Montar ISO" escreve na hora (com a versão certa).

Uso: python3 visual/instalador/gerar.py
Precisa do PySide6 (pip install PySide6) e da fonte Inter instalada.
"""
import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QRectF, Qt  # noqa: E402
from PySide6.QtGui import (  # noqa: E402
    QColor, QFont, QFontDatabase, QFontMetricsF, QGuiApplication, QImage,
    QLinearGradient, QPainter,
)
from PySide6.QtSvg import QSvgRenderer  # noqa: E402

RAIZ = Path(__file__).resolve().parents[2]
PAPEL = RAIZ / "system_files/usr/share/wallpapers/Matsu/contents/images_dark/3840x2160.png"
EMBLEMA = RAIZ / "visual/logo/matsu-emblema-claro.svg"
MARCA = RAIZ / "installer/marca"
PIXMAPS = MARCA / "usr/share/anaconda/pixmaps/matsu"
PIXMAPS_NO_INSTALADOR = "/usr/share/anaconda/pixmaps/matsu"

EDICAO = (RAIZ / "EDICAO").read_text().strip()
NOME = f"Matsu {EDICAO} OS"
FUNDO = "#12152B"   # o mesmo céu da noite do papel de parede, que aparece na faixa
TEXTO = "#F4F5F7"


def papel_pela_metade():
    """O papel de parede escuro em 1920x1080, sem borrar os pixels."""
    im = QImage(str(PAPEL)).convertToFormat(QImage.Format_ARGB32)
    return im.scaled(1920, 1080, Qt.IgnoreAspectRatio, Qt.FastTransformation)


def escurece(im, de_cima, de_baixo):
    """Passa um véu índigo por cima, para o texto branco ler bem."""
    p = QPainter(im)
    g = QLinearGradient(0, 0, 0, im.height())
    c1 = QColor(FUNDO)
    c1.setAlphaF(de_cima)
    c2 = QColor(FUNDO)
    c2.setAlphaF(de_baixo)
    g.setColorAt(0, c1)
    g.setColorAt(1, c2)
    p.fillRect(im.rect(), g)
    p.end()
    return im


def faixa_lateral(papel):
    # Pedaço da esquerda do papel: árvores embaixo, céu em cima. O estilo prende
    # a imagem embaixo, então em telas baixas some só o céu de cima.
    im = papel.copy(0, 0, 420, 1080)
    return escurece(im, 0.55, 0.10)


def barra_de_cima(papel):
    im = papel.copy(0, 0, 1920, 140)
    return escurece(im, 0.25, 0.25)


def logo_lateral():
    lado = 64
    f = QFont("Inter")
    f.setPixelSize(19)
    f.setWeight(QFont.DemiBold)
    f.setLetterSpacing(QFont.AbsoluteSpacing, 1.0)
    fm = QFontMetricsF(f)
    alt_nome = int(fm.height() + 1)
    larg, alt = 180, lado + 12 + alt_nome
    im = QImage(larg, alt, QImage.Format_ARGB32_Premultiplied)
    im.fill(Qt.transparent)
    p = QPainter(im)
    p.setRenderHint(QPainter.Antialiasing)
    p.setRenderHint(QPainter.TextAntialiasing)
    QSvgRenderer(str(EMBLEMA)).render(p, QRectF((larg - lado) / 2, 0, lado, lado))
    p.setFont(f)
    p.setPen(QColor(TEXTO))
    p.drawText(QRectF(0, lado + 12, larg, alt_nome), Qt.AlignHCenter | Qt.AlignTop, NOME)
    p.end()
    return im


ESTILO = f"""/* Matsu OS: cara do Matsu no instalador (gerado por visual/instalador/gerar.py). */

@define-color matsu {FUNDO};
@define-color anaconda_bg_color {FUNDO};

/* Faixa da esquerda: um pedaço do papel de parede em pixel art. */
.logo-sidebar {{
    background-image: url('{PIXMAPS_NO_INSTALADOR}/sidebar-bg.png');
    background-color: @matsu;
    background-repeat: no-repeat;
    background-position: left bottom;
}}

/* Logo do Matsu no alto da faixa. */
.logo {{
    background-image: url('{PIXMAPS_NO_INSTALADOR}/sidebar-logo.png');
    background-position: 50% 24px;
    background-repeat: no-repeat;
    background-color: transparent;
}}

.product-logo {{
    background-image: none;
    background-color: transparent;
}}

/* Barra de cima das telas: o céu estrelado do papel de parede. */
AnacondaSpokeWindow #nav-box {{
    background-color: @matsu;
    background-image: url('{PIXMAPS_NO_INSTALADOR}/topbar-bg.png');
    background-repeat: no-repeat;
    background-position: left top;
    color: white;
}}
"""

CONFIG = f"""# Matsu OS: o instalador usa o estilo do Matsu (logo e cores).
[User Interface]
custom_stylesheet = {PIXMAPS_NO_INSTALADOR}/matsu.css
"""


def main():
    app = QGuiApplication(sys.argv)  # noqa: F841 (o Qt precisa dele para as fontes)
    if "Inter" not in QFontDatabase.families():
        sys.exit("Falta a fonte Inter (no Fedora: dnf install rsms-inter-fonts)")
    PIXMAPS.mkdir(parents=True, exist_ok=True)
    papel = papel_pela_metade()
    faixa_lateral(papel).save(str(PIXMAPS / "sidebar-bg.png"))
    barra_de_cima(papel).save(str(PIXMAPS / "topbar-bg.png"))
    logo_lateral().save(str(PIXMAPS / "sidebar-logo.png"))
    (PIXMAPS / "matsu.css").write_text(ESTILO, encoding="utf-8")
    conf = MARCA / "etc/anaconda/conf.d"
    conf.mkdir(parents=True, exist_ok=True)
    (conf / "90-matsu.conf").write_text(CONFIG, encoding="utf-8")
    print(f"Cara do instalador em {MARCA.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
