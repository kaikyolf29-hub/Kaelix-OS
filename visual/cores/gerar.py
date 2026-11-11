#!/usr/bin/env python3
"""Esquemas de cores do Matsu (MatsuEscuro e MatsuClaro), para os apps do KDE.

O Kaiky escolheu (11/11/2026) o vidro cinza neutro do terminal e do Gerenciador
de tarefas para o sistema todo: nada do azul-marinho e do anil de antes. Aqui sai
o mesmo cinza dos apps do Matsu (o "fundo" da JanelaMatsu, como o Mica do
Windows 11), texto sempre claro no escuro, e a seleção num cinza médio com texto
branco. Cor só nos detalhes: links em verde-água, avisos em rosa, amarelo e verde.

Se a pessoa escolher uma cor do vidro (Ajustes > Aparência, ou "matsu vidro rosa"),
o KDE pinta a seleção e o foco com ela por cima destes esquemas.

Uso: python3 visual/cores/gerar.py
"""
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
SAIDA = RAIZ / "system_files/usr/share/color-schemes"

# A seleção é a mesma nos dois temas e igual ao destaque padrão do "matsu vidro"
# (VIDRO_PADRAO_DESTAQUE), para nada mudar quando a pessoa volta ao padrão.
SELECAO = (110, 110, 118)
SELECAO_ALT = (98, 98, 106)

TEMAS = {
    "MatsuEscuro": {
        "nome": "Matsu Escuro",
        "janela": ((32, 32, 34), (38, 38, 41)),
        "lista": ((26, 26, 28), (30, 30, 33)),
        "botao": ((46, 46, 50), (54, 54, 59)),
        "cabecalho": ((32, 32, 34), (38, 38, 41)),
        "cabecalho_inativo": ((30, 30, 32), (36, 36, 39)),
        "dica": ((40, 40, 44), (46, 46, 50)),
        "complementar": ((24, 24, 26), (30, 30, 33)),
        "texto": (236, 236, 241),
        "texto_fraco": (160, 160, 168),
        "texto_ativo": (255, 255, 255),
        "link": (69, 208, 193),
        "visitado": (177, 140, 245),
        "negativo": (242, 104, 138),
        "neutro": (242, 190, 100),
        "positivo": (127, 207, 106),
        "foco": (150, 150, 160),
        "sobre": (120, 120, 130),
        "complementar_texto": (236, 236, 241),
        "complementar_fraco": (160, 160, 168),
        "titulo": ((32, 32, 34), (236, 236, 241)),
        "titulo_inativo": ((30, 30, 32), (160, 160, 168)),
        "desligado": (56, 56, 56),
    },
    "MatsuClaro": {
        "nome": "Matsu Claro",
        "janela": ((243, 243, 245), (236, 236, 239)),
        "lista": ((251, 251, 252), (245, 245, 247)),
        "botao": ((250, 250, 251), (242, 242, 245)),
        "cabecalho": ((243, 243, 245), (236, 236, 239)),
        "cabecalho_inativo": ((246, 246, 248), (240, 240, 243)),
        "dica": ((250, 250, 251), (243, 243, 245)),
        # O "complementar" do KDE é o lado escuro do tema claro (tela de bloqueio, avisos na tela).
        "complementar": ((32, 32, 34), (38, 38, 41)),
        "texto": (30, 30, 36),
        "texto_fraco": (110, 110, 120),
        "texto_ativo": (0, 0, 0),
        "link": (0, 134, 122),
        "visitado": (122, 76, 216),
        "negativo": (206, 46, 96),
        "neutro": (168, 110, 0),
        "positivo": (40, 140, 50),
        "foco": (90, 90, 100),
        "sobre": (140, 140, 150),
        "complementar_texto": (236, 236, 241),
        "complementar_fraco": (160, 160, 168),
        "titulo": ((243, 243, 245), (30, 30, 36)),
        "titulo_inativo": ((246, 246, 248), (110, 110, 120)),
        "desligado": (200, 200, 204),
    },
}


def rgb(c):
    return ",".join(str(v) for v in c)


def grupo(nome, fundo, t, texto=None, fraco=None, selecao=False):
    """Um grupo de cores do KDE ([Colors:Window], [Colors:View]...)."""
    texto = texto or t["texto"]
    fraco = fraco or t["texto_fraco"]
    if selecao:
        frente = {"ForegroundActive": (255, 255, 255), "ForegroundInactive": (225, 225, 230),
                  "ForegroundLink": (255, 255, 255), "ForegroundNormal": (255, 255, 255),
                  "ForegroundVisited": (255, 255, 255)}
    else:
        frente = {"ForegroundActive": t["texto_ativo"] if texto == t["texto"] else texto,
                  "ForegroundInactive": fraco, "ForegroundLink": t["link"],
                  "ForegroundNormal": texto, "ForegroundVisited": t["visitado"]}
    valores = {
        "BackgroundAlternate": fundo[1],
        "BackgroundNormal": fundo[0],
        "DecorationFocus": t["foco"],
        "DecorationHover": t["sobre"],
        **frente,
        "ForegroundNegative": t["negativo"],
        "ForegroundNeutral": t["neutro"],
        "ForegroundPositive": t["positivo"],
    }
    linhas = [f"[{nome}]"] + [f"{k}={rgb(v)}" for k, v in sorted(valores.items())]
    return "\n".join(linhas) + "\n"


def esquema(chave, t):
    partes = [
        "# Esquema de cores do Matsu. Gerado por visual/cores/gerar.py: não editar à mão.\n",
        "[ColorEffects:Disabled]\nColor=%s\nColorAmount=0\nColorEffect=0\nContrastAmount=0.65\n"
        "ContrastEffect=1\nIntensityAmount=0.1\nIntensityEffect=2\n" % rgb(t["desligado"]),
        "[ColorEffects:Inactive]\nChangeSelectionColor=true\nColor=112,111,110\nColorAmount=0.025\n"
        "ColorEffect=2\nContrastAmount=0.1\nContrastEffect=2\nEnable=false\nIntensityAmount=0\nIntensityEffect=0\n",
        grupo("Colors:Button", t["botao"], t),
        grupo("Colors:Complementary", t["complementar"], t, t["complementar_texto"], t["complementar_fraco"]),
        grupo("Colors:Header", t["cabecalho"], t),
        grupo("Colors:Header][Inactive", t["cabecalho_inativo"], t),
        grupo("Colors:Selection", (SELECAO, SELECAO_ALT), t, selecao=True),
        grupo("Colors:Tooltip", t["dica"], t),
        grupo("Colors:View", t["lista"], t),
        grupo("Colors:Window", t["janela"], t),
        f"[General]\nColorScheme={chave}\nName={t['nome']}\nshadeSortColumn=true\n",
        "[KDE]\ncontrast=4\n",
        "[WM]\nactiveBackground=%s\nactiveBlend=%s\nactiveForeground=%s\n"
        "inactiveBackground=%s\ninactiveBlend=%s\ninactiveForeground=%s\n" % (
            rgb(t["titulo"][0]), rgb(t["titulo"][1]), rgb(t["titulo"][1]),
            rgb(t["titulo_inativo"][0]), rgb(t["titulo_inativo"][1]), rgb(t["titulo_inativo"][1])),
    ]
    return "\n".join(partes)


if __name__ == "__main__":
    for chave, t in TEMAS.items():
        (SAIDA / f"{chave}.colors").write_text(esquema(chave, t), encoding="utf-8")
        print("ok", chave)
