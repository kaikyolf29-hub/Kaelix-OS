# Site do Matsu

A página para baixar a ISO do Matsu. É uma página só, feita com Vite e React e
desenhada já no build (o HTML sai pronto e o React só "acorda" por cima). Sai
em dois idiomas: `index.html` (português, o padrão) e `en.html` (inglês), com o
botão EN/PT no menu levando junto a parte onde a pessoa está.

## Rodar e montar

```bash
cd site
npm ci
npm run dev       # abre em http://localhost:5173
npm run build     # monta em site/dist (é essa pasta que vai para o ar)
npm run preview   # mostra o site/dist
```

O fluxo **Publicar o site** (`.github/workflows/site.yml`) monta e sobe o
`site/dist` no GitHub Pages. Ele roda à mão (Actions > Publicar o site > Run
workflow) e precisa do GitHub Pages ligado em Settings > Pages, com a origem
"GitHub Actions".

## Onde fica cada coisa

- `index.html`: o esqueleto. O `header`, o `main`, o `footer` e a barra do
  celular já estão nele; cada um é uma raiz do React (`src/App.jsx`).
- `src/dados.js`: a edição do ano (27), os links do GitHub, o tamanho da ISO e
  os apps da barra. Na virada do ano, mudar `EDICAO` aqui.
- `src/componentes/`: as partes da página, na ordem: Topo (a área de trabalho
  com a barra de vidro), Telas, Atalhos, Jogos, Estilos (a barra nos três
  estilos), Aparência, Loja, Apps, Criar (programar e criar), Segurança,
  Instalar, Baixar, Perguntas, Apoiar e Rodape. Jogos, Aparência, Loja, Criar e
  Segurança ficam juntas em `Divisoes.jsx` (texto à esquerda, janela à direita).
- Atalhos e Perguntas: cada atalho e cada resposta foi conferido no sistema
  (de onde vem cada um está no comentário do topo do arquivo). Mudou um atalho
  ou o instalador? Mude aqui também.
- `src/estilo/`: `base.css` (cores do Matsu, letras, botões, menu),
  `transicoes.css` (as transições) e `secoes.css` (cada parte).
- `public/img/`: as fotos do sistema, tiradas das prints de verdade da VM por
  `visual/site/preparar-fotos.py`, e o papel de parede em pixel art aumentado
  3 e 6 vezes sem borrar.

## Os dois idiomas

Cada texto fica junto, nos dois idiomas: `t('Baixar', 'Download')` ou
`{ pt: ..., en: ... }` nas listas (`src/idioma.js`). O `scripts/prerender.mjs`
desenha a página duas vezes e troca o título, a descrição e os links do
cabeçalho no `en.html`. As fotos do sistema são as mesmas nos dois.

## Apoie o Matsu

A parte **Apoiar** (e o link no menu) só aparece quando tem um jeito de apoiar,
configurado em `APOIO` no `src/dados.js`:

- **Pix:** só a chave **aleatória** (formato `1234abcd-...`). Nunca CPF,
  telefone ou e-mail: o build para e o `tests/test_matsu.sh` falha. Com o nome
  e a cidade, o site também mostra o QR Code e o "Pix copia e cola" sem valor
  fixo, feitos aqui mesmo (`src/pix.js`, conferido com o exemplo do manual do
  Banco Central; o QR é desenhado pelo `uqr`, MIT), sem serviço de fora.
- **GitHub Sponsors:** trocar `aprovado` para `true` quando o GitHub aprovar o
  perfil, e acrescentar `github: kaikydev1-jpg` no `.github/FUNDING.yml`.

Sem rastreador e sem guardar nada de quem apoia.

## O botão de baixar

O cartão de baixar lê a lista de versões do repositório na API do GitHub. Se já
tem uma versão estável publicada (o fluxo "Publicar versão estável" cria o
Release com `matsu-os-<versão>-amd.iso` e `-nvidia.iso` e as somas `.sha256`),
o botão baixa a ISO da placa escolhida. Enquanto não tem versão estável, ele
baixa a versão de teste (o fluxo "Publicar versão de teste" deixa um Release
marcado como teste, com `matsu-os-teste-amd.iso` e `-nvidia.iso`) e o cartão
diz que é de teste. Sem nenhuma das duas, o botão abre a página de versões e o
cartão avisa que a primeira está quase pronta. Não precisa mexer no site quando
sair uma versão.

## O que veio de fora (e as licenças)

- **Taste Skill** (MIT, Leonxlnx/taste-skill): a estrutura, o ritmo e as
  checagens da página. O momento dos passos de instalação é o
  `pinned-chapters` do kit, copiado sem mudanças em `public/moments/` (licença
  em `public/moments/LICENSE.txt`).
- **React Bits** (MIT + Commons Clause, DavidHDev/react-bits): o vidro da barra
  (GlassSurface), os cartões com luz (SpotlightCard) e o nome do topo saindo do
  desfoque (BlurText), em `src/reactbits/` com a licença ao lado. A Commons
  Clause proíbe vender os componentes em si; usar num site grátis pode.
- **transitions.dev** (as transições gratuitas): troca de ícone, marcador que
  desliza, troca de texto e de foto com desfoque e o visto que se desenha,
  refeitas em CSS em `src/estilo/transicoes.css`.
- **Funnel Display e Funnel Sans** (SIL OFL 1.1): as letras, em
  `public/fontes/` com a licença.
- **Logos de apps de terceiros** (Steam, Brave, Chrome, Discord, Spotify, OBS,
  VS Code, Heroic, Lutris, Python, Node.js, Ubuntu, Arch): dos projetos de cada
  um e do gilbarbara/logos (CC0). O do Kdenlive vem do próprio Kdenlive
  (KDE/kdenlive, `data/icons/sc-apps-kdenlive.svg`, GPL) e o do Kali Linux do
  tema de ícones Papirus (`distributor-logo-kali-linux.svg`, GPL 3.0). São
  marcas dos seus donos, e o rodapé diz isso.
