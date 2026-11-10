#!/usr/bin/env python3
"""Ícones pequenos de traço da barra do Kaelix (rede, Wi-Fi, Bluetooth, som, sino).

Mesmo desenho do vídeo de demonstração da fusão (docs/visual/demo.html).
Saem como ícones "-symbolic" do tema Kaelix: o KDE pinta cada um com a cor do
texto do tema, então ficam claros no tema escuro e escuros no tema claro.

Uso: python3 visual/icones/simbolicos.py
"""
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
DESTINO = RAIZ / "system_files/usr/share/icons/Kaelix/status/symbolic"

# Traço de 1,9 px numa grade de 24, pontas redondas, como na demonstração.
CABECA = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">\n'
    '<style type="text/css" id="current-color-scheme">.ColorScheme-Text { color:#232629; }</style>\n'
)
TRACO = ('class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-width="1.9" '
         'stroke-linecap="round" stroke-linejoin="round"')
CHEIO = 'class="ColorScheme-Text" fill="currentColor" stroke="none"'


def traco(d, opacidade=1.0):
    extra = f' opacity="{opacidade}"' if opacidade < 1 else ""
    return f'<path {TRACO}{extra} d="{d}"/>\n'


def svg(*partes):
    return CABECA + "".join(partes) + "</svg>\n"


# Rede por cabo: o "galhinho" do vídeo (um computador ligado a dois).
CABO = ("M10.2 3h3.6a1.2 1.2 0 0 1 1.2 1.2v2.6a1.2 1.2 0 0 1 -1.2 1.2h-3.6a1.2 1.2 0 0 1 -1.2 -1.2v-2.6a1.2 1.2 0 0 1 1.2 -1.2z"
        "M12 8v4M5 16v-2a2 2 0 0 1 2 -2h10a2 2 0 0 1 2 2v2"
        "M3.7 16h2.6a1.2 1.2 0 0 1 1.2 1.2v2.6a1.2 1.2 0 0 1 -1.2 1.2h-2.6a1.2 1.2 0 0 1 -1.2 -1.2v-2.6a1.2 1.2 0 0 1 1.2 -1.2z"
        "M17.7 16h2.6a1.2 1.2 0 0 1 1.2 1.2v2.6a1.2 1.2 0 0 1 -1.2 1.2h-2.6a1.2 1.2 0 0 1 -1.2 -1.2v-2.6a1.2 1.2 0 0 1 1.2 -1.2z")

# Wi-Fi: três arcos em volta de um ponto (centro em 12,18). Os arcos que o sinal
# não alcança ficam apagados, como no Windows e no Mac.
ARCOS = ["M8.82 14.82A4.5 4.5 0 0 1 15.18 14.82",
         "M5.99 11.99A8.5 8.5 0 0 1 18.01 11.99",
         "M3.16 9.16A12.5 12.5 0 0 1 20.84 9.16"]
PONTO = f'<circle {CHEIO} cx="12" cy="18.2" r="1.45"/>\n'

ALTO_FALANTE = "M4 9.5v5h3.5L12 18V6L7.5 9.5H4z"
ONDA_1 = "M15.5 9a4 4 0 0 1 0 6"
ONDA_2 = "M18 6.5a7.5 7.5 0 0 1 0 11"
SINO = "M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"

ICONES = {
    "kaelix-rede-cabo": svg(traco(CABO)),
    "kaelix-rede-desconectada": svg(traco(CABO, 0.45), traco("M3.5 3.5l17 17")),
    "kaelix-wifi-desligado": svg(PONTO, *[traco(a, 0.35) for a in ARCOS], traco("M4 4l16 16")),
    "kaelix-bluetooth": svg(traco("M7 7l10 10-5 4V3l5 4L7 17")),
    "kaelix-volume-mudo": svg(traco(ALTO_FALANTE), traco("M16 9.5l5 5M21 9.5l-5 5")),
    "kaelix-volume-0": svg(traco(ALTO_FALANTE)),
    "kaelix-volume-1": svg(traco(ALTO_FALANTE), traco(ONDA_1)),
    "kaelix-volume-2": svg(traco(ALTO_FALANTE), traco(ONDA_1), traco(ONDA_2)),
    "kaelix-sino": svg(traco(SINO), traco("M10 21h4")),
    "kaelix-sino-silencio": svg(traco(SINO), traco("M10 21h4"), traco("M3.5 3.5l17 17")),
    "kaelix-raio": svg(f'<path {CHEIO} d="M13.2 2.5L5.5 13.4h5.3l-1 8.1 7.7-10.9h-5.3z"/>\n'),
}
for nivel in range(4):
    ICONES[f"kaelix-wifi-{nivel}"] = svg(PONTO, *[traco(a, 1.0 if i < nivel else 0.3) for i, a in enumerate(ARCOS)])


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    for nome, conteudo in ICONES.items():
        (DESTINO / f"{nome}-symbolic.svg").write_text(conteudo, encoding="utf-8")
    print(f"{len(ICONES)} ícones em {DESTINO.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
