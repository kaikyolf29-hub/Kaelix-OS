# Logo do Matsu OS

O logo é um **bonsai dentro do ensō**, o círculo de pincel zen, em rosa de
cerejeira sobre um fundo ameixa com cantos arredondados. A árvore tem uma copa
larga em nuvem no alto, uma almofada menor embaixo à esquerda, presa por um
galho, e o tronco em S que abre um pouco no pé. O anel tem pontas redondas e
fica aberto no alto, à direita.

Nasceu em 11/11/2026 da junção das duas imagens de referência do criador: a
árvore da segunda com o rosa e o acabamento da primeira. Antes foi o pinheiro
branco podado em nuvens e, até 10/11/2026, quando o sistema ainda era Kaelix
OS, o "Asas".

O desenho é feito por `gerar.py` (precisa do Shapely: `pip install shapely`):

```
python3 visual/logo/gerar.py
```

As frestas entre as folhas e a madeira são cortes de verdade no contorno, então
o emblema fica certo em cima de qualquer fundo, até transparente. Cores (cada
peça tem um degradê do alto à esquerda para baixo à direita):

| Peça | Cores |
|---|---|
| Fundo | `#6a4862` → `#1b1120` |
| Anel | `#f0bfd6` → `#b0668f` |
| Folhas | `#fde6f1` → `#f0a6cc` |
| Tronco | `#e6b4cb` → `#c98aac` |

- `matsu-logo.svg`: o logo completo, com o fundo. É o que entra no sistema.
- `matsu-emblema-claro.svg`: só o anel e a árvore, para fundo escuro.
- `matsu-emblema-escuro.svg`: o mesmo, num rosa mais forte, para fundo claro.

No sistema ele fica em `system_files/usr/share/icons/hicolor/scalable/apps/`
como `matsu-logo.svg` (logo do sistema) e `matsu-menu.svg` (botão do menu), e
na tela de carregar do Plasma. O `gerar.py` também escreve o desenho em letras
de bloco do fastfetch (`system_files/usr/share/matsu/fastfetch/logo.txt`). A
tela de boot e o instalador usam o emblema claro: depois de mudar o logo, rode
também `visual/boot/gerar.py` e `visual/instalador/gerar.py` (precisam do
PySide6).

## Nome e edição do ano

O nome é **Matsu 27 OS**: uma edição por ano, e só o número muda (27 = edição
2027, 28 = edição 2028). O número fica num lugar só, o arquivo `EDICAO` na raiz
do repositório. Para trocar de ano: mude o número e rode de novo
`visual/boot/gerar.py` e `visual/instalador/gerar.py` (que desenham o nome nas
imagens); o resto o sistema lê sozinho na montagem.
