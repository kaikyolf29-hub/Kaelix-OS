#!/usr/bin/env python3
"""Ícones pequenos de traço da barra do Matsu (rede, Wi-Fi, Bluetooth, som, sino).

Mesmo desenho do vídeo de demonstração da fusão (docs/visual/demo.html).
Saem como ícones "-symbolic" do tema Matsu: o KDE pinta cada um com a cor do
texto do tema, então ficam claros no tema escuro e escuros no tema claro.

Uso: python3 visual/icones/simbolicos.py
"""
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
# Os dois temas de ícones (escuro e claro) levam os mesmos desenhos: o Plasma
# pinta cada um com a cor do texto do tema.
DESTINOS = [RAIZ / f"system_files/usr/share/icons/{tema}/status/symbolic" for tema in ("Matsu", "Matsu-claro")]

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
    "matsu-rede-cabo": svg(traco(CABO)),
    "matsu-rede-desconectada": svg(traco(CABO, 0.45), traco("M3.5 3.5l17 17")),
    "matsu-wifi-desligado": svg(PONTO, *[traco(a, 0.35) for a in ARCOS], traco("M4 4l16 16")),
    "matsu-bluetooth": svg(traco("M7 7l10 10-5 4V3l5 4L7 17")),
    "matsu-volume-mudo": svg(traco(ALTO_FALANTE), traco("M16 9.5l5 5M21 9.5l-5 5")),
    "matsu-volume-0": svg(traco(ALTO_FALANTE)),
    "matsu-volume-1": svg(traco(ALTO_FALANTE), traco(ONDA_1)),
    "matsu-volume-2": svg(traco(ALTO_FALANTE), traco(ONDA_1), traco(ONDA_2)),
    "matsu-sino": svg(traco(SINO), traco("M10 21h4")),
    "matsu-sino-silencio": svg(traco(SINO), traco("M10 21h4"), traco("M3.5 3.5l17 17")),
    "matsu-raio": svg(f'<path {CHEIO} d="M13.2 2.5L5.5 13.4h5.3l-1 8.1 7.7-10.9h-5.3z"/>\n'),
    # Central de controle.
    "matsu-lua": svg(traco("M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z")),
    "matsu-nao-perturbe": svg(traco("M12 3.5a8.5 8.5 0 1 0 0 17a8.5 8.5 0 1 0 0 -17zM8.2 12h7.6")),
    "matsu-luz-noturna": svg(traco("M3 17.5h18M7 17.5a5 5 0 0 1 10 0M12 6.5v2.5M5.4 10.4l1.7 1.7M18.6 10.4l-1.7 1.7M8.5 21h7")),
    "matsu-barra": svg(traco("M5 4h14a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2z"
                              "M6.5 16.5h2M10.5 16.5h3M15.5 16.5h2")),
    "matsu-brilho": svg(traco("M12 8.5a3.5 3.5 0 1 0 0 7a3.5 3.5 0 1 0 0 -7z"
                               "M12 3v2.5M12 18.5V21M3 12h2.5M18.5 12H21M5.6 5.6l1.8 1.8M16.6 16.6l1.8 1.8M5.6 18.4l1.8 -1.8M16.6 7.4l1.8 -1.8")),
    "matsu-ajustes": svg(traco("M4 7h8M18 7h2M4 12h2M12 12h8M4 17h10"
                                "M15 4.8a2.2 2.2 0 1 0 0 4.4a2.2 2.2 0 1 0 0 -4.4z"
                                "M9 9.8a2.2 2.2 0 1 0 0 4.4a2.2 2.2 0 1 0 0 -4.4z"
                                "M17 14.8a2.2 2.2 0 1 0 0 4.4a2.2 2.2 0 1 0 0 -4.4z")),
    "matsu-cadeado": svg(traco("M7.5 11V8a4.5 4.5 0 0 1 9 0v3"
                                "M7 11h10a2 2 0 0 1 2 2v6a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2v-6a2 2 0 0 1 2 -2z")),
    "matsu-desligar": svg(traco("M12 3.5v8M6.7 6.6a8 8 0 1 0 10.6 0")),
    # Ajustes do Matsu (a janela de ajustes, como a do Mac).
    "matsu-aparencia": svg(traco("M12 3.5a8.5 8.5 0 1 0 0 17a8.5 8.5 0 1 0 0 -17z"),
                            f'<path {CHEIO} d="M12 3.5a8.5 8.5 0 0 1 0 17z"/>\n'),
    "matsu-papel": svg(traco("M5 4h14a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2z"
                              "M3.5 17l5 -5.5 4 4 2.5 -2.5 5.5 5.5"),
                        f'<circle {CHEIO} cx="15.5" cy="8.5" r="1.7"/>\n'),
    "matsu-tela": svg(traco("M4.5 4h15a2 2 0 0 1 2 2v9a2 2 0 0 1 -2 2h-15a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2z"
                             "M12 17v3.5M8 20.5h8")),
    "matsu-info": svg(traco("M12 3.5a8.5 8.5 0 1 0 0 17a8.5 8.5 0 1 0 0 -17zM12 11v5.5"),
                       f'<circle {CHEIO} cx="12" cy="7.8" r="1.25"/>\n'),
    "matsu-seta": svg(traco("M9.5 6l6 6-6 6")),
    "matsu-busca": svg(traco("M10.5 4a6.5 6.5 0 1 0 0 13a6.5 6.5 0 1 0 0 -13zM15.3 15.3l5 5")),
    "matsu-certo": svg(traco("M5.5 12.5l4.2 4.2 8.8 -9.2")),
    # Menu do Matsu (limpar a busca).
    "matsu-fechar": svg(traco("M7 7l10 10M17 7L7 17")),
    # Central de jogos: as páginas, os perfis gráficos e os detalhes de cada jogo.
    "matsu-inicio": svg(traco("M3.8 11.2L12 4.2l8.2 7M6 9.6v9.4a1 1 0 0 0 1 1h3.4v-5.2h3.2V20H17a1 1 0 0 0 1 -1V9.6")),
    "matsu-jogos": svg(traco("M7.6 7h8.8a4.4 4.4 0 0 1 4.3 3.5l1 5.1a2.6 2.6 0 0 1 -4.5 2.2L15.4 16H8.6l-1.8 1.8a2.6 2.6 0 0 1 -4.5 -2.2l1 -5.1A4.4 4.4 0 0 1 7.6 7z"
                              "M8.2 9.9v3.4M6.5 11.6h3.4"),
                        f'<circle {CHEIO} cx="15.6" cy="10.4" r="1.05"/>\n<circle {CHEIO} cx="17.6" cy="12.6" r="1.05"/>\n'),
    "matsu-graficos": svg(traco("M4.5 4h15a2 2 0 0 1 2 2v9a2 2 0 0 1 -2 2h-15a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2zM12 17v3.5M8 20.5h8"),
                           f'<path {CHEIO} d="M12 6.4l1.05 2.55 2.55 1.05 -2.55 1.05L12 13.6l-1.05 -2.55L8.4 10l2.55 -1.05z"/>\n'),
    "matsu-sobreposicao": svg(traco("M4.5 4.5h15a2 2 0 0 1 2 2v11a2 2 0 0 1 -2 2h-15a2 2 0 0 1 -2 -2v-11a2 2 0 0 1 2 -2z"
                                     "M6 16.5l3 -2.6 2.4 1.6 3.4 -3.4 3.2 2.4"),
                               f'<rect {CHEIO} x="5.6" y="7.4" width="5.6" height="3.4" rx="1"/>\n'),
    "matsu-placa": svg(traco("M2.8 5.5h1.4v14M4.2 7.5h15.3a1.5 1.5 0 0 1 1.5 1.5v7a1.5 1.5 0 0 1 -1.5 1.5H4.2"
                              "M11 9.3a3.2 3.2 0 1 0 0 6.4a3.2 3.2 0 1 0 0 -6.4zM17 10v5M7 17.5v2M9.5 17.5v2M12 17.5v2"),
                        f'<circle {CHEIO} cx="11" cy="12.5" r="1"/>\n'),
    "matsu-jogar": svg('<path class="ColorScheme-Text" fill="currentColor" stroke="currentColor" stroke-width="1.6" '
                        'stroke-linejoin="round" d="M8 5.6v12.8a.8.8 0 0 0 1.2 .7l10.2 -6.4a.8.8 0 0 0 0 -1.4L9.2 4.9A.8.8 0 0 0 8 5.6z"/>\n'),
    "matsu-perfil-padrao": svg(traco("M3.8 16.5a8.2 8.2 0 0 1 16.4 0M12 16.5l3.2 -4.6"),
                                f'<circle {CHEIO} cx="12" cy="16.5" r="1.6"/>\n'),
    "matsu-qualidade": svg(traco("M10 4.5l1.6 4.4 4.4 1.6 -4.4 1.6L10 16.5l-1.6 -4.4L4 10.5l4.4 -1.6z"
                                  "M17.5 14.5l.8 2 2 .8 -2 .8 -.8 2 -.8 -2 -2 -.8 2 -.8z")),
    "matsu-folha": svg(traco("M5 19.2c0 -8.3 5.2 -13.4 14.2 -14.2c0 9.2 -5.2 14.2 -14.2 14.2zM5 19.2l7.4 -7.4")),
    "matsu-textura": svg(traco("M3 18.5L8 5.5h8l5 13zM5.7 12h12.6M10.5 5.5l-1.3 13M13.5 5.5l1.3 13")),
    "matsu-sincronia": svg(traco("M4.5 4.5h15a2 2 0 0 1 2 2v11a2 2 0 0 1 -2 2h-15a2 2 0 0 1 -2 -2v-11a2 2 0 0 1 2 -2z"
                                  "M2.5 12h4M9.5 12h5M17.5 12h4")),
    "matsu-relogio": svg(traco("M12 3.5a8.5 8.5 0 1 0 0 17a8.5 8.5 0 1 0 0 -17zM12 7.5V12l3 2")),
    "matsu-calendario": svg(traco("M5.5 5.5h13a2 2 0 0 1 2 2v11a2 2 0 0 1 -2 2h-13a2 2 0 0 1 -2 -2v-11a2 2 0 0 1 2 -2z"
                                   "M3.5 10h17M8 3.5v4M16 3.5v4"),
                             f'<circle {CHEIO} cx="8.5" cy="14.5" r="1.2"/>\n'),
    "matsu-disco": svg(traco("M4 14h16v4.5a1.5 1.5 0 0 1 -1.5 1.5h-13A1.5 1.5 0 0 1 4 18.5zM4 14l2.2 -8.2A1.5 1.5 0 0 1 7.7 4.6h8.6a1.5 1.5 0 0 1 1.5 1.2L20 14"),
                        f'<circle {CHEIO} cx="16.5" cy="17" r="1.1"/>\n'),
    "matsu-pasta": svg(traco("M3.5 7.5a2 2 0 0 1 2 -2h4l2 2.5h7a2 2 0 0 1 2 2v7.5a2 2 0 0 1 -2 2h-13a2 2 0 0 1 -2 -2z")),
    "matsu-texto": svg(traco("M3.5 18l4.5 -12 4.5 12M5.2 13.6h5.6M17 11a2.8 2.8 0 1 0 0 5.6a2.8 2.8 0 1 0 0 -5.6zM19.8 10.5V18")),
    "matsu-baixar": svg(traco("M12 4v11M7.5 10.5L12 15l4.5 -4.5M5 19.5h14")),
    # Gerenciador de tarefas: Processos (lista), Desempenho (gráfico),
    # Inicialização (foguete), e os botões e linhas dele.
    "matsu-processos": svg(traco("M4 6.5h1.5M8.5 6.5H20M4 12h1.5M8.5 12H20M4 17.5h1.5M8.5 17.5H20")),
    "matsu-desempenho": svg(traco("M3.5 19.5h17M4 15.5l4 -4.5 3.5 3 4.5 -6.5 4 3.5")),
    "matsu-inicializacao": svg(traco("M12 3.2c3 2.3 4.4 5.4 4 9.3l-1.6 3.3H9.6L8 12.5c-.4 -3.9 1 -7 4 -9.3z"
                                      "M8.3 12.8l-2.8 2.3v3.4l3.8 -1.6M15.7 12.8l2.8 2.3v3.4l-3.8 -1.6M10.7 19.3l1.3 1.7 1.3 -1.7"),
                                f'<circle {CHEIO} cx="12" cy="9.3" r="1.5"/>\n'),
    "matsu-mais": svg(traco("M12 5v14M5 12h14")),
    "matsu-menu": svg(traco("M4 7h16M4 12h16M4 17h16")),
    "matsu-nova-tarefa": svg(traco("M5 4.5h8a1.5 1.5 0 0 1 1.5 1.5v3M9.5 19.5H5A1.5 1.5 0 0 1 3.5 18V6A1.5 1.5 0 0 1 5 4.5"
                                    "M17 12.5a4.5 4.5 0 1 0 0 9a4.5 4.5 0 1 0 0 -9zM17 15v4M15 17h4")),
    "matsu-parar": svg(traco("M12 3.5a8.5 8.5 0 1 0 0 17a8.5 8.5 0 1 0 0 -17zM8.6 8.6l6.8 6.8")),
    "matsu-recarregar": svg(traco("M19.5 12a7.5 7.5 0 1 1 -2.2 -5.3M19.5 4.5v4.2h-4.2")),
    "matsu-processo": svg(traco("M5 5.5h14a1.5 1.5 0 0 1 1.5 1.5v10a1.5 1.5 0 0 1 -1.5 1.5H5a1.5 1.5 0 0 1 -1.5 -1.5V7A1.5 1.5 0 0 1 5 5.5z"
                                 "M7 10l2.5 2L7 14M11.5 14.5H16")),
    # Loja do Matsu: Apps (quatro quadrados), Na web (globo), Biblioteca (livros), atualizar.
    "matsu-apps": svg(traco("M5.5 4h3a1.5 1.5 0 0 1 1.5 1.5v3A1.5 1.5 0 0 1 8.5 10h-3A1.5 1.5 0 0 1 4 8.5v-3A1.5 1.5 0 0 1 5.5 4z"
                            "M15.5 4h3A1.5 1.5 0 0 1 20 5.5v3a1.5 1.5 0 0 1 -1.5 1.5h-3A1.5 1.5 0 0 1 14 8.5v-3A1.5 1.5 0 0 1 15.5 4z"
                            "M5.5 14h3a1.5 1.5 0 0 1 1.5 1.5v3A1.5 1.5 0 0 1 8.5 20h-3A1.5 1.5 0 0 1 4 18.5v-3A1.5 1.5 0 0 1 5.5 14z"
                            "M17 14v6M14 17h6")),
    "matsu-web": svg(traco("M12 3.5a8.5 8.5 0 1 0 0 17a8.5 8.5 0 1 0 0 -17zM3.5 12h17"
                           "M12 3.5c2.3 2.5 3.4 5.3 3.4 8.5s-1.1 6 -3.4 8.5c-2.3 -2.5 -3.4 -5.3 -3.4 -8.5s1.1 -6 3.4 -8.5z")),
    "matsu-biblioteca": svg(traco("M5 4.5h2.5a1 1 0 0 1 1 1v13a1 1 0 0 1 -1 1H5a1 1 0 0 1 -1 -1v-13a1 1 0 0 1 1 -1z"
                                  "M11 4.5h2.5a1 1 0 0 1 1 1v13a1 1 0 0 1 -1 1H11a1 1 0 0 1 -1 -1v-13a1 1 0 0 1 1 -1z"
                                  "M15.2 6.4l2.3 -.6a1 1 0 0 1 1.2 .7l2.9 12a1 1 0 0 1 -.7 1.2l-2.3 .6a1 1 0 0 1 -1.2 -.7l-2.9 -12a1 1 0 0 1 .7 -1.2z")),
    "matsu-verificado": svg('<path class="ColorScheme-Text" fill="currentColor" stroke="none" d="M12 2.5l2.3 1.7 2.8 -.2 1 2.7 2.4 1.5'
                            ' -.8 2.7.8 2.7 -2.4 1.5 -1 2.7 -2.8 -.2L12 19.3l-2.3 -1.7 -2.8.2 -1 -2.7 -2.4 -1.5.8 -2.7 -.8 -2.7 2.4 -1.5 1 -2.7 2.8.2z'
                            'M8.2 11.2l-1.3 1.3 3.4 3.4 6.8 -6.8 -1.3 -1.3 -5.5 5.5z" fill-rule="evenodd"/>\n'),
    "matsu-voltar": svg(traco("M15 5l-7 7 7 7")),
    # Alerta: triângulo com a exclamação (avisos da loja).
    "matsu-alerta": svg(traco("M10.3 4.2a2 2 0 0 1 3.4 0l7.4 12.8a2 2 0 0 1 -1.7 3h-14.8a2 2 0 0 1 -1.7 -3z"),
                        traco("M12 9.5v4"), '<circle ' + CHEIO + ' cx="12" cy="16.8" r="1.15"/>\n'),
    # Lixeira: remover um app.
    "matsu-lixeira": svg(traco("M4.5 6.5h15M9.5 6.5v-1.6a1.4 1.4 0 0 1 1.4 -1.4h2.2a1.4 1.4 0 0 1 1.4 1.4v1.6"
                               "M6.3 6.5l.9 12.4a1.8 1.8 0 0 0 1.8 1.6h6a1.8 1.8 0 0 0 1.8 -1.6l.9 -12.4M10.2 10.5v6M13.8 10.5v6")),
    # Abrir fora (o site de um app, no navegador).
    "matsu-link": svg(traco("M13.5 4.5h6v6M19.5 4.5l-8 8M17.5 13.5v4.2a1.8 1.8 0 0 1 -1.8 1.8h-9.4a1.8 1.8 0 0 1 -1.8 -1.8v-9.4"
                            "a1.8 1.8 0 0 1 1.8 -1.8h4.2")),
    # Escudo com o certinho: licença e segurança na página de cada app.
    "matsu-escudo": svg(traco("M12 3l7 2.8v5.4c0 4.4 -2.9 8 -7 9.8c-4.1 -1.8 -7 -5.4 -7 -9.8v-5.4z"), traco("M8.8 12.2l2.2 2.2 4.2 -4.4")),
    # Coração: doar para quem faz o app.
    "matsu-coracao": svg(traco("M12 19.5s-7.5 -4.4 -7.5 -10a4.2 4.2 0 0 1 7.5 -2.6a4.2 4.2 0 0 1 7.5 2.6c0 5.6 -7.5 10 -7.5 10z")),
    # Etiqueta: versão.
    "matsu-etiqueta": svg(traco("M3.8 12.6v-7a1.8 1.8 0 0 1 1.8 -1.8h7l7.6 7.6a1.8 1.8 0 0 1 0 2.5l-6.5 6.5a1.8 1.8 0 0 1 -2.5 0z"),
                          '<circle ' + CHEIO + ' cx="8.3" cy="8.3" r="1.4"/>\n'),
    "matsu-engrenagem": svg(traco("M12 9a3 3 0 1 0 0 6a3 3 0 1 0 0 -6z"
                                   "M10.3 3.5h3.4l.5 2.4 1.7 1 2.3 -.8 1.7 2.9 -1.8 1.6v2l1.8 1.6 -1.7 2.9 -2.3 -.8 -1.7 1 -.5 2.4h-3.4l-.5 -2.4 -1.7 -1 -2.3 .8 -1.7 -2.9 1.8 -1.6v-2L4.1 9l1.7 -2.9 2.3 .8 1.7 -1z")),
}
for nivel in range(4):
    ICONES[f"matsu-wifi-{nivel}"] = svg(PONTO, *[traco(a, 1.0 if i < nivel else 0.3) for i, a in enumerate(ARCOS)])


def main():
    for destino in DESTINOS:
        destino.mkdir(parents=True, exist_ok=True)
        for nome, conteudo in ICONES.items():
            (destino / f"{nome}-symbolic.svg").write_text(conteudo, encoding="utf-8")
        print(f"{len(ICONES)} ícones em {destino.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
