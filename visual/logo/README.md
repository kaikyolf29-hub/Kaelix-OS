# Logo do Matsu OS

O logo é o **pinheiro japonês** (matsu, 松) podado em nuvens, como um niwaki ou
um bonsai: tronco em S, raiz abrindo no chão, três galhos e quatro almofadas de
folhas com a parte de cima em lóbulos. Branco suave (`#F4F5F7`) no fundo quase
preto neutro (`#141517`), com cantos arredondados. Entrou em 11/11/2026, quando
o sistema mudou de nome (antes era Kaelix OS, com o logo "Asas").

O desenho é feito por `gerar.py` (precisa do Shapely: `pip install shapely`):

```
python3 visual/logo/gerar.py
```

As frestas entre as folhas e a madeira são cortes de verdade no contorno, então
o emblema fica certo em cima de qualquer fundo, até transparente.

- `matsu-logo.svg`: o logo completo, com o fundo. É o que entra no sistema.
- `matsu-emblema-claro.svg`: só o pinheiro, em branco, para fundo escuro.
- `matsu-emblema-escuro.svg`: só o pinheiro, escuro, para fundo claro.

No sistema ele fica em `system_files/usr/share/icons/hicolor/scalable/apps/`
como `matsu-logo.svg` (logo do sistema) e `matsu-menu.svg` (botão do menu), e
na tela de carregar do Plasma. A tela de boot e o instalador usam o emblema
claro (`visual/boot/gerar.py` e `visual/instalador/gerar.py`).

## Nome e edição do ano

O nome é **Matsu 27 OS**: uma edição por ano, e só o número muda (27 = edição
2027, 28 = edição 2028). O número fica num lugar só, o arquivo `EDICAO` na raiz
do repositório. Para trocar de ano: mude o número e rode de novo
`visual/boot/gerar.py` e `visual/instalador/gerar.py` (que desenham o nome nas
imagens); o resto o sistema lê sozinho na montagem.
