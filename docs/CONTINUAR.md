# Onde parou (para continuar de outra conta)

Atualizado em 16/11/2026, 04:15 UTC (01:15 em Brasília).

## O que está pronto

- **Matsu 27 oficial** publicado em 15/11/2026 (Release v27, ISOs AMD e NVIDIA, site em
  https://kaikyolf29-hub.github.io/Matsu-OS/).
- **Estilo Mac como o macOS 26** (pedido do Kaiky em 15/11): doca com vidro próprio que
  estica com a lupa, lupa crescendo menos, barra de cima sem fundo, balões com o vidro
  do Mac. Já está no estável (`:estavel` e `:27`), solto "calado" com o fluxo
  `atualizar-estavel.yml` (commit c11b523).
- **Avisos dos apps no jeito do Mac, feitos pelo Matsu** (pedido do Kaiky em 15/11,
  22:19 UTC: "notificação no estilo Mac de todas as notificações do aplicativo"):
  cartão de vidro com o ícone do app à esquerda, título em negrito, texto, hora no canto,
  botões do app, "x" ao passar o mouse e barra de progresso nas cópias de arquivo.
  No estilo Mac ficam no canto de cima, à direita; nos outros estilos, no canto de baixo.
  - Código: `org.matsu.relogio/contents/ui/Avisos.qml` (cria, empilha, "não perturbe")
    e `Aviso.qml` (a janela de cada aviso).
  - A peça de avisos do KDE sai da bandeja: `barra/comum.js` (`semAvisosDoKde`), no login
    antes da área de trabalho ligar (`etc/xdg/plasma-workspace/env/matsu-avisos.sh`) e
    depois dela ligar (`usr/libexec/matsu/matsu-avisos` + `barra/avisos.js`).
  - Ponto do app aberto na doca do Mac afastado da borda do vidro (`org.matsu.doca`).
  - **A peça de avisos do KDE sai da imagem** (`build_files/build.sh`, 16/11): uma bandeja
    nova (primeiro login de uma conta ou troca de estilo da barra) liga essa peça sozinha
    antes de o roteiro da barra desligar, e no Plasma 6.8 ela deixa os avisos dela na tela
    até o fim da sessão (o aviso a mais no canto de cima, à esquerda, do print do 78ac498).
    O ajuste do login só cobre quem já tinha a barra montada; na VM a conta é nova, então
    ele não muda o print. Sem o arquivo `org.kde.plasma.notifications.so`, a bandeja nem
    sabe que a peça existe. Nada mais usa esse arquivo: o "não perturbe", a lista e os
    ajustes de cada app são da `libnotificationmanager`.
  - **Avisos do Mac com o mesmo vidro da doca** (pedido do Kaiky em 16/11: "transparente
    estilo vidro, daquela barra embaixo, na mesma proporção"): em `vidro/gerar.py --mac`, os
    avisos (`dialogs/background`) usam a transparência da doca em cada nível (`NIVEIS_DOCA`,
    32% no normal), a borda acesa, o brilho, o canto (18) e a sombra dela. Os balões da
    barra de cima (bandeja, calendário, volume) continuam com o vidro dos balões do Mac.
    Quem já usa o estilo Mac recebe o vidro novo no login seguinte (a marca `.matsu-vidro`
    guarda o gerador).
  - Testes: `node tests/test_barra_avisos.js` (27) e `bash tests/test_matsu.sh` (208).
  - **Já está no estável** (`:estavel` e `:27`, normal e NVIDIA), solto "calado" em
    16/11/2026, 04:12 UTC, com o fluxo `atualizar-estavel.yml` (imagem do commit 56ba1f7).
    Print da VM conferido antes (`13d-aviso-estilo-mac.png`, ramo `prints`, commit
    d762347): só os dois cartões do Matsu no canto de cima, à direita, com o vidro da
    doca, e nenhum aviso do KDE no canto esquerdo; a lista do relógio (print 29), a
    bandeja e a central continuam funcionando sem a peça do KDE. Os digests de `:teste`,
    `:estavel` e `:27` ficaram iguais nas duas imagens. Os prints foram mandados ao Kaiky.

## O que falta fazer agora

Nada pendente dos avisos do Mac: está tudo no estável. Para lembrar:

- Quem já usa o estilo Mac recebe o vidro novo dos avisos na atualização automática e no
  login seguinte.
- Os avisos usam o vidro fino da doca. No PC com placa de vídeo o desfoque ajuda a ler por
  cima de janelas; se o Kaiky achar difícil de ler, subir só o vidro dos avisos em
  `vidro/gerar.py` (no bloco `if opcoes.mac:`).
- Os balões da barra de cima do Mac (bandeja, calendário, volume) ficaram com o vidro de
  antes. Se o Kaiky quiser igual à doca também, é trocar as pastas `solid/dialogs` no
  mesmo bloco.
- O fluxo de prints agora tem limite de 130 minutos (era 100 e cortou um teste).
- Para conferir os canais: token anônimo de `ghcr.io/token` e HEAD em
  `/v2/kaikyolf29-hub/<imagem>/manifests/<tag>` (`teste`, `estavel`, `27`).
- Há um pedido automático do Dependabot aberto (kaikyolf29-hub/Matsu-OS#2, actions/checkout
  5 para 7). Ninguém mexeu nele.

## Depois disso

- Teste no PC do Kaiky (começou em 15/11: ISO AMD, Rufus em modo DD, dual boot).
- Depois do teste: Matsu Performance (central do notebook) e Matsu Connect (celular).
- O acompanhamento de cada parte está em `docs/ACOMPANHAMENTO.md`; o plano em `docs/PLANO.md`.

## Regras combinadas com o Kaiky

- Tudo em português do Brasil, simples. Prints em português.
- Commits direto na `main` (autorizado em 13/11/2026): a montagem e os prints só rodam por lá.
- Nunca publicar versão nova (27.1, 28...) sem ele pedir. Atualização pequena que ele
  pediu vai "calada" pelo `atualizar-estavel.yml`, depois dos prints.
- Foto antes de dizer que algo visual está pronto. Foto do Plasma de teste (docker) não
  é o sistema: dizer que é teste.
- No máximo 3 agentes ao mesmo tempo; conversa grande vira conversa nova com resumo.
- Fazer por iniciativa o que faltar no tema (tudo com o visual do Matsu); vidro neutro,
  nada de azul estranho nem texto preto sobre azul.

## Como testar

- `bash tests/test_matsu.sh`, `bash tests/test_central.sh`, `node tests/test_barra_fixados.js`,
  `node tests/test_barra_avisos.js`, `node tests/test_doca.js` (o fluxo "Testes" roda todos).
- Avisos no Plasma de teste: `notify-send -a App -i icone 'Título' 'Texto'`; com botões,
  `notify-send -A r=Responder ... --wait` (sem `--wait` o aviso some na hora).
