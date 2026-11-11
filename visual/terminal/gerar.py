#!/usr/bin/env python3
"""Cores e perfis do terminal do Matsu (matsu-terminal).

Gera os esquemas de cores e os perfis que a peça do Konsole usa dentro do
terminal do Matsu, nos dois temas (escuro e claro), cada um em duas versões:
de vidro (o fundo meio transparente, com o desfoque do KWin atrás) e sólida
(para quando o desfoque está desligado; vidro sem desfoque fica difícil de ler).

O fundo é o cinza neutro dos apps do Matsu, sem o azul. As cores do texto são
as mesmas das partes do computador no Matsu (verde água, lilás, rosa...).

Uso: python3 visual/terminal/gerar.py
"""
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
SAIDA = RAIZ / "system_files/usr/share/konsole"

# Opacidade do fundo do terminal no vidro (um degrau mais fundo que o vidro da janela).
OPACIDADE = 0.74

TEMAS = {
    "escuro": {
        "nome": "MatsuTerminal",
        "descricao": "Matsu Terminal",
        "fundo": (17, 17, 19),
        "frente": (236, 236, 241),
        "frente_forte": (255, 255, 255),
        "frente_fraca": (160, 160, 168),
        # (normal, forte, fraca) para cada cor: preto, vermelho, verde, amarelo,
        # azul, roxo, ciano e branco.
        "cores": [
            ((52, 52, 58), (100, 100, 110), (40, 40, 46)),
            ((242, 104, 138), (255, 140, 168), (181, 80, 105)),
            ((127, 207, 106), (166, 230, 148), (98, 158, 82)),
            ((242, 190, 100), (255, 214, 140), (181, 143, 78)),
            ((116, 168, 255), (160, 196, 255), (90, 128, 196)),
            ((177, 140, 245), (206, 182, 255), (134, 107, 186)),
            ((69, 208, 193), (125, 232, 220), (55, 158, 148)),
            ((210, 210, 218), (255, 255, 255), (160, 160, 168)),
        ],
    },
    "claro": {
        "nome": "MatsuTerminalClaro",
        "descricao": "Matsu Terminal Claro",
        "fundo": (251, 251, 252),
        "frente": (30, 30, 36),
        "frente_forte": (0, 0, 0),
        "frente_fraca": (110, 110, 120),
        "cores": [
            ((62, 62, 70), (110, 110, 122), (130, 130, 140)),
            ((206, 46, 96), (226, 76, 122), (214, 120, 148)),
            ((40, 140, 50), (58, 168, 70), (110, 170, 116)),
            ((168, 110, 0), (196, 136, 12), (190, 160, 100)),
            ((36, 104, 214), (66, 130, 236), (110, 150, 214)),
            ((122, 76, 216), (148, 104, 236), (160, 136, 214)),
            ((0, 134, 122), (12, 160, 146), (90, 166, 158)),
            ((106, 106, 116), (60, 60, 68), (150, 150, 160)),
        ],
    },
}


def rgb(c):
    return ",".join(str(v) for v in c)


def esquema(t, opacidade, nome_extra):
    linhas = [f"# Terminal do Matsu ({t['descricao']}{nome_extra}). Gerado por visual/terminal/gerar.py.", ""]
    for chave in ("Background", "BackgroundIntense", "BackgroundFaint"):
        linhas += [f"[{chave}]", f"Color={rgb(t['fundo'])}", ""]
    for i, (normal, forte, fraca) in enumerate(t["cores"]):
        linhas += [f"[Color{i}]", f"Color={rgb(normal)}", ""]
        linhas += [f"[Color{i}Intense]", f"Color={rgb(forte)}", ""]
        linhas += [f"[Color{i}Faint]", f"Color={rgb(fraca)}", ""]
    linhas += ["[Foreground]", f"Color={rgb(t['frente'])}", ""]
    linhas += ["[ForegroundIntense]", f"Color={rgb(t['frente_forte'])}", ""]
    linhas += ["[ForegroundFaint]", f"Color={rgb(t['frente_fraca'])}", ""]
    linhas += ["[General]", "Blur=false", "ColorRandomization=false",
               f"Description={t['descricao']}{nome_extra}", f"Opacity={opacidade:g}", "Wallpaper=", ""]
    return "\n".join(linhas)


def perfil(nome, esquema_nome):
    return f"""# Perfil do terminal do Matsu ({nome}). Gerado por visual/terminal/gerar.py.
[Appearance]
ColorScheme={esquema_nome}
Font=JetBrains Mono,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
LineSpacing=2

[Cursor Options]
CursorShape=1

[General]
Name={nome}
Parent=FALLBACK/
ShowTerminalSizeHint=false
TerminalCenter=false
TerminalMargin=12
LocalTabTitleFormat=%d
RemoteTabTitleFormat=%H : %d

[Interaction Options]
CopyTextAsHTML=false
TrimTrailingSpacesInSelectedText=true

[Scrolling]
HistorySize=10000
ScrollBarPosition=2

[Terminal Features]
BlinkingCursorEnabled=true
"""


def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    for t in TEMAS.values():
        for solido in (False, True):
            arquivo = t["nome"] + ("Solido" if solido else "")
            nome_extra = " Sólido" if solido else ""
            (SAIDA / f"{arquivo}.colorscheme").write_text(
                esquema(t, 1 if solido else OPACIDADE, nome_extra), encoding="utf-8")
            (SAIDA / f"{arquivo}.profile").write_text(
                perfil(t["descricao"] + nome_extra, arquivo), encoding="utf-8")
    print(f"Cores e perfis do terminal em {SAIDA.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
