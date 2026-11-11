#!/usr/bin/env python3
"""Tela de boot do Matsu (tema do Plymouth "matsu").

É a mesma cara da tela que aparece depois da senha: o fundo quase preto, o
logo (o bonsai rosa no ensō) no meio, o nome "Matsu 27 OS" embaixo e três pontos pulsando
(rosa, lilás e verde água). Assim, ligar o PC, entrar e carregar parecem uma
coisa só. O número da edição vem do arquivo EDICAO, na raiz do repositório.

Usa o módulo "two-step" do Plymouth (o mesmo dos temas do Fedora), que já
cuida da senha do disco criptografado e da tela de atualização.

Uso: python3 visual/boot/gerar.py
Precisa do PySide6 (pip install PySide6) e da fonte Inter instalada.
"""
import math
import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QPointF, QRectF, Qt  # noqa: E402
from PySide6.QtGui import (  # noqa: E402
    QColor, QFont, QFontDatabase, QFontMetricsF, QGuiApplication, QImage,
    QPainter, QPainterPath, QPen,
)
from PySide6.QtSvg import QSvgRenderer  # noqa: E402

RAIZ = Path(__file__).resolve().parents[2]
EMBLEMA = RAIZ / "visual/logo/matsu-emblema-claro.svg"
SAIDA = RAIZ / "system_files/usr/share/plymouth/themes/matsu"

EDICAO = (RAIZ / "EDICAO").read_text().strip()
NOME = f"Matsu {EDICAO} OS"
FUNDO = "#141517"
TEXTO = "#F4F5F7"
DESTAQUE = "#D9DBE0"
PONTOS = ["#F0609E", "#B18CF5", "#45D0C1"]

# Medidas da tela de carregamento depois da senha (Splash.qml) numa tela
# 1920x1080, para as duas ficarem iguais.
TELA_A = 1080
LADO = round(TELA_A * 0.16)                 # emblema
DESCE = round(TELA_A * 0.04)                # o emblema fica um pouco acima do meio
NOME_PX = max(16, round(LADO * 0.17))
NOME_ESPACO = round(LADO * 0.22)
PONTO = max(10, round(LADO * 0.075))
PONTO_VAO = max(8, round(LADO * 0.08))
PONTOS_ESPACO = round(LADO * 0.32)

# O Plymouth passa por todos os quadros dos pontos em 2 segundos, 30 por segundo.
QUADROS = 60
DURACAO_MS = 2000
SOBE_MS = 400       # o ponto acende
ATRASO_MS = 200     # cada ponto começa um pouco depois do anterior
APAGADO = 0.3


def imagem(l, a):
    im = QImage(l, a, QImage.Format_ARGB32_Premultiplied)
    im.fill(Qt.transparent)
    return im


def pintor(im):
    p = QPainter(im)
    p.setRenderHint(QPainter.Antialiasing)
    p.setRenderHint(QPainter.TextAntialiasing)
    p.setRenderHint(QPainter.SmoothPixmapTransform)
    return p


def fonte_nome():
    f = QFont("Inter")
    f.setPixelSize(NOME_PX)
    f.setWeight(QFont.DemiBold)
    f.setLetterSpacing(QFont.AbsoluteSpacing, 1.5)
    f.setHintingPreference(QFont.PreferNoHinting)
    return f


class Medidas:
    """Onde cada coisa fica dentro do quadro do Matsu.

    A marca d'água (emblema e nome) e os quadros dos pontos têm o mesmo tamanho e
    ficam os dois no meio da tela. Assim os pontos ficam sempre na mesma distância
    do nome, em qualquer resolução. Uma folga em cima desce o conjunto até o
    emblema ficar onde ele fica na tela de carregamento (um pouco acima do meio).
    """

    def __init__(self):
        fm = QFontMetricsF(fonte_nome())
        self.alt_nome = math.ceil(fm.height())
        self.larg = max(LADO, math.ceil(fm.horizontalAdvance(NOME))) + 24
        resto = LADO + NOME_ESPACO + self.alt_nome + PONTOS_ESPACO + PONTO
        # meio do emblema = A/2 - (folga + resto)/2 + folga + LADO/2 = A/2 - DESCE
        self.folga = round(resto - LADO - 2 * DESCE)
        self.alt = self.folga + resto
        self.topo_nome = self.folga + LADO + NOME_ESPACO
        self.topo_pontos = self.topo_nome + self.alt_nome + PONTOS_ESPACO


def marca(m):
    """Emblema e nome (a "marca d'água" do two-step, que fica parada)."""
    im = imagem(m.larg, m.alt)
    p = pintor(im)
    QSvgRenderer(str(EMBLEMA)).render(p, QRectF((m.larg - LADO) / 2, m.folga, LADO, LADO))
    p.setFont(fonte_nome())
    cor = QColor(TEXTO)
    cor.setAlphaF(0.92)
    p.setPen(cor)
    p.drawText(QRectF(0, m.topo_nome, m.larg, m.alt_nome), Qt.AlignHCenter | Qt.AlignTop, NOME)
    p.end()
    return im


def suave(x):
    """Mesma curva do Easing.InOutQuad do QML."""
    return 2 * x * x if x < 0.5 else 1 - (-2 * x + 2) ** 2 / 2


def brilho(ms, i):
    t = ms - i * ATRASO_MS
    if 0 <= t < SOBE_MS:
        return APAGADO + (1 - APAGADO) * suave(t / SOBE_MS)
    if SOBE_MS <= t < 2 * SOBE_MS:
        return 1 - (1 - APAGADO) * suave((t - SOBE_MS) / SOBE_MS)
    return APAGADO


def quadro_pontos(m, ms):
    """Um quadro dos pontos, do tamanho da marca d'água (o resto é transparente)."""
    im = imagem(m.larg, m.alt)
    p = pintor(im)
    p.setPen(Qt.NoPen)
    x0 = (m.larg - (3 * PONTO + 2 * PONTO_VAO)) / 2
    for i, hexa in enumerate(PONTOS):
        cor = QColor(hexa)
        cor.setAlphaF(brilho(ms, i))
        p.setBrush(cor)
        p.drawEllipse(QRectF(x0 + i * (PONTO + PONTO_VAO), m.topo_pontos, PONTO, PONTO))
    p.end()
    return im


def campo_senha():
    """Caixa onde a pessoa digita a senha do disco (se ele for criptografado).

    O Plymouth centraliza o cadeado e a caixa juntos. A sobra transparente à
    direita, do tamanho do cadeado, faz a caixa ficar no meio, embaixo do nome.
    """
    im = imagem(305 + 44, 36)
    p = pintor(im)
    r = QRectF(0.75, 0.75, 305 - 1.5, 36 - 1.5)
    p.setBrush(QColor(255, 255, 255, 20))
    p.setPen(QPen(QColor(DESTAQUE), 1.5))
    p.drawRoundedRect(r, 10, 10)
    p.end()
    return im


def bolinha():
    im = imagem(10, 10)
    p = pintor(im)
    p.setPen(Qt.NoPen)
    p.setBrush(QColor(TEXTO))
    p.drawEllipse(QRectF(1, 1, 8, 8))
    p.end()
    return im


def cadeado():
    # 8 pixels transparentes à direita separam o cadeado da caixa da senha.
    im = imagem(44, 36)
    p = pintor(im)
    p.setPen(Qt.NoPen)
    p.setBrush(QColor(DESTAQUE))
    p.drawRoundedRect(QRectF(0, 0, 36, 36), 10, 10)
    branco = QColor(TEXTO)
    p.setBrush(branco)
    p.drawRoundedRect(QRectF(11, 16, 14, 11), 2.5, 2.5)
    p.setBrush(Qt.NoBrush)
    p.setPen(QPen(branco, 2.2, Qt.SolidLine, Qt.RoundCap))
    arco = QPainterPath(QPointF(13.5, 16.5))
    arco.lineTo(13.5, 13.5)
    arco.arcTo(QRectF(13.5, 9, 9, 9), 180, -180)
    arco.lineTo(22.5, 16.5)
    p.drawPath(arco)
    p.end()
    return im


def cor_plymouth(hexa):
    return "0x" + hexa.lstrip("#").lower()


def tema():
    # A marca d'água e os pontos ficam os dois no meio (veja Medidas). A caixa da
    # senha e a barra de progresso das atualizações ficam onde estariam os pontos,
    # com folga para não encostar no nome numa tela pequena (1366x768).
    return f"""[Plymouth Theme]
Name=Matsu
Name[pt_BR]=Matsu
Description={NOME} boot screen: the pink bonsai logo on near black with three pulsing dots.
Description[pt_BR]=Tela de boot do {NOME}: o bonsai rosa do logo no fundo quase preto, com três pontos pulsando.
ModuleName=two-step

[two-step]
Font=Inter 12
TitleFont=Inter Light 30
ImageDir=/usr/share/plymouth/themes/matsu
DialogHorizontalAlignment=.5
DialogVerticalAlignment=.72
TitleHorizontalAlignment=.5
TitleVerticalAlignment=.2
HorizontalAlignment=.5
VerticalAlignment=.5
WatermarkHorizontalAlignment=.5
WatermarkVerticalAlignment=.5
ProgressBarHorizontalAlignment=.5
ProgressBarVerticalAlignment=.72
ProgressBarWidth=240
ProgressBarHeight=6
Transition=none
TransitionDuration=0.0
BackgroundStartColor={cor_plymouth(FUNDO)}
BackgroundEndColor={cor_plymouth(FUNDO)}
ProgressBarBackgroundColor=0x2a2f52
ProgressBarForegroundColor={cor_plymouth(DESTAQUE)}
MessageBelowAnimation=true

[boot-up]
UseEndAnimation=false

[shutdown]
UseEndAnimation=false

[reboot]
UseEndAnimation=false

[updates]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
Title=Instalando atualizações...
SubTitle=Não desligue o computador

[system-upgrade]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
Title=Atualizando o sistema...
SubTitle=Não desligue o computador

[firmware-upgrade]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
Title=Atualizando o firmware...
SubTitle=Não desligue o computador

[system-reset]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
Title=Restaurando o sistema...
SubTitle=Não desligue o computador
"""


def main():
    app = QGuiApplication(sys.argv)  # noqa: F841 (o Qt precisa dele para as fontes)
    if "Inter" not in QFontDatabase.families():
        sys.exit("Falta a fonte Inter (no Fedora: dnf install rsms-inter-fonts)")
    SAIDA.mkdir(parents=True, exist_ok=True)
    for velho in SAIDA.glob("throbber-*.png"):
        velho.unlink()
    m = Medidas()
    im = marca(m)
    im.save(str(SAIDA / "watermark.png"))
    for n in range(QUADROS):
        quadro_pontos(m, n * DURACAO_MS / QUADROS).save(str(SAIDA / f"throbber-{n + 1:04d}.png"))
    campo_senha().save(str(SAIDA / "entry.png"))
    bolinha().save(str(SAIDA / "bullet.png"))
    cadeado().save(str(SAIDA / "lock.png"))
    (SAIDA / "matsu.plymouth").write_text(tema(), encoding="utf-8")
    print(f"Tema do Plymouth em {SAIDA.relative_to(RAIZ)}: marca {im.width()}x{im.height()}, {QUADROS} quadros dos pontos")


if __name__ == "__main__":
    main()
