# Kit dos apps do Matsu

Os apps do Matsu feitos em QML (Loja, Central de jogos, Gerenciador de tarefas,
Relógio, Música...) usam as mesmas peças, em `system_files/usr/share/matsu/comum`.
Assim todos têm o mesmo acabamento: vidro neutro, cantos redondos, nada de azul,
animações curtas em cada toque. Para ver todas as peças juntas:

    /usr/libexec/matsu/matsu-janela org.matsu.vitrine tests/vitrine/Main.qml

## Regras de visual

- Texto sempre em `janela.frente` (branco no tema escuro, quase preto no claro).
  Em cima da cor de destaque, `janela.sobreDestaque`. Nunca texto escuro em cor escura.
- `janela.destaque` é a cor do vidro que a pessoa escolheu (no padrão, a própria cor
  da frente). Só em detalhes: chave ligada, botão principal, escolha.
- Nada de tracinho colorido embaixo de aba ou de item escolhido: o escolhido se
  destaca pelo fundo (`janela.tinta(0.08)`) e pela borda fina.
- Fundos suaves com `janela.tinta(a)`; cartões com `Cartao` (`janela.cartao`).
- Tudo em português, com o inglês ao lado: `janela.t("Salvar", "Save")`. Números e
  datas no jeito da pessoa: `janela.num(1234.5, 2)` dá "1.234,50".
- Animações: `Easing.OutCubic` para andar, `Easing.OutBack` para "pular";
  `Kirigami.Units.shortDuration` (passar o mouse) e `longDuration` (abrir, trocar).
- Funciona no tema claro e no escuro, com e sem vidro (`janela.comVidro`).

## A janela

`JanelaMatsu` (o `id` precisa ser `janela`): barra de título com as bolinhas, busca
no meio, lista de assuntos à esquerda (a pílula do escolhido desliza) e o miolo.
Veja o começo de `JanelaMatsu.qml`. Também tem:

- `semLista`: sem a lista de assuntos (um editor, a Câmera); o miolo ocupa a largura
  toda e a barra de título fica igual. Já vem ligado quando `paginas: []`.
- `raioMiolo`: o raio dos cantos de cima do miolo (com a lista, só o da esquerda;
  sem a lista, os dois; o padrão sem a lista é 0, colado na barra de título).
- `trocaSuave: true`: a página nova entra aparecendo e subindo de leve (também quando
  duas páginas usam o mesmo arquivo). Desligado por padrão.

- `janela.avisoRapido(texto, tipo, acao, funcao)`: aviso que sobe embaixo e some
  sozinho; `tipo` "" / "certo" / "erro"; com `acao` aparece um botão ("Desfazer").
- `janela.num`, `bytes`, `duracao`, `simples` (tira acentos para a busca), `local`.

O programa `matsu-janela` dá ao QML o objeto `matsu`:

| Chamada | O que faz |
| --- | --- |
| `matsu.rodar(chave, [prog, args])` | roda uma vez; o fim chega em `onPronto(chave, saida, codigo)` |
| `matsu.iniciar(chave, [prog, args])` | fica rodando; cada linha chega em `onLinha(chave, texto)` |
| `matsu.escrever(chave, texto)` | manda uma linha para a entrada de quem foi iniciado |
| `matsu.parar(chave)` | para quem foi iniciado |
| `matsu.soltar([prog, args])` | abre outro programa, que continua aberto |
| `matsu.ler(caminho)` / `matsu.gravar(caminho, texto)` | arquivo de texto (gravar não deixa o arquivo pela metade) |
| `matsu.existe(caminho)` | se existe |
| `matsu.pasta(nome)` | "casa", "musica", "imagens", "videos", "documentos", "downloads", "area", "dados" (`~/.local/share/matsu/<app>`), "config" (`~/.config/matsu`) |
| `matsu.argumentos` | argumentos da linha de comando |
| `onPedido(argumentos)` | o app foi aberto de novo (com outro arquivo, por exemplo) |

## As peças

| Peça | Para quê | Uso |
| --- | --- | --- |
| `Texto` | texto na cor certa | `Texto { text: "Oi" }` |
| `Cartao` | cartão do miolo | `Cartao { ... }` |
| `CartaoClicavel` | cartão que se clica (um app, uma categoria): com o mouse sobe um pouco e ganha sombra macia; apertando, afunda | `CartaoClicavel { width; height; onClicked: ...; RowLayout { anchors.fill: parent; ... } }`; `raio`, `elevar: false` (só clareia) |
| `Botao` | botão sem fundo (barra de ferramentas) | `Botao { texto; icone; dica; onClicado }` |
| `BotaoDestaque` | botão principal; `estado: "carregando"` (rodinha) e `"feito"` (verde com visto); `perigo` (vermelho) | `BotaoDestaque { texto: "Enviar"; estado: s; textoFeito: "Enviado" }` |
| `Chave` | ligar e desligar | `Chave { ligada: x; onTrocada: (l) => x = l }` |
| `Marca` | caixinha que pula ao marcar; `redonda` para tarefas | `Marca { marcada: x; onTrocada: (m) => x = m }` |
| `Seletor` | botões segmentados com a pílula que desliza | `Seletor { opcoes: [{id, nome}]; escolhido; onEscolher: (id) => ... }` |
| `Passos` | valor numa lista, com setinhas | `Passos { opcoes; escolhido; onEscolher }` |
| `Contador` | − número + (o número rola); segurar repete | `Contador { valor; minimo; maximo; passo; sufixo: " min"; onMudou: (v) => ... }` |
| `NumeroRolante` | número cujos algarismos rolam ao mudar; casa nova entra abrindo espaço, a que sobra sai (sem refazer as outras) | `NumeroRolante { texto: janela.num(v, 2); font.pixelSize: 40 }` |
| `Anel` | anel de progresso (0 a 1), pula ao completar | `Anel { valor: 0.75; texto: "3/4"; subtexto: "tarefas" }` |
| `Girando` | rodinha de carregando | `Girando { width: janela.gu }` |
| `Etiqueta` | chip; o visto entra ao escolher | `Etiqueta { texto: "Rock"; escolhida: x; onTrocada: (e) => x = e }` |
| `Deslizante` | controle deslizante com balão do valor | `Deslizante { de: 0; ate: 100; valor; onMovido: (v) => ...; onSolto: (v) => ... }` |
| `Onda` | onda do som com o progresso; clicar pula | `Onda { amostras: [...]; progresso: 0.4; onBuscar: (f) => ... }` |
| `Sanfona` | cartão que abre e fecha | `Sanfona { titulo: "Pergunta"; Texto { ... } }` |
| `Campo` | campo de texto | `Campo { dica: "Nome"; texto; onEditado: (t) => ...; onConfirmado: ... }` |
| `Suspensa` | lista suspensa com visto; lista comprida abre para o lado que cabe, rola e mostra a escolhida; setas e Enter | `Suspensa { opcoes: [{id, nome, icone}]; escolhido; onEscolher: (id) => ... }` |
| `MenuMatsu` | menu do botão direito; abre com o foco (Esc fecha, setas e Enter escolhem) | `menu.abrirEm(item, x, y)`; `itens: [{id, nome, icone, atalho, perigo, separador, ativo}]` |
| `Dialogo` | pergunta no meio, com o fundo escurecido | `dialogo.perguntar({titulo, texto, sim, nao, perigo, terceiro}, aoSim, aoTerceiro)` |
| `Vazio` | quando não há nada (sem músicas, sem câmera) | `Vazio { icone; titulo; texto; botao; onClicado }` |
| `LinhaOpcao` | linha de ajuste (ícone, nome, explicação e o controle) | `LinhaOpcao { nome; texto; Chave { } }` |
| `BarraRolagem` | barra de rolagem fina do Matsu | `QQC2.ScrollBar.vertical: BarraRolagem {}` |
| `ImagemRedonda` | imagem com cantos redondos | ver o arquivo; `aparecer: true` faz a imagem surgir com fade quando carrega |
| `Grafico` | gráfico de linha (Gerenciador) | ver o arquivo; `suave: true` desenha em curva, desliza a cada valor novo e muda a escala devagar |
| `FundoBalao` | fundo dos balões (lista, menu, diálogo) | `background: FundoBalao {}` |
| `Esqueleto` | lugar do que ainda está chegando, com o brilho que passa (todos juntos, como uma luz só) | `Esqueleto { anchors.fill: parent; raio: janela.gu * 0.6; visible: !pronto }`; `cor`, `forca`, `brilho: false` (só pulsa) |
| `BotaoSimbolo` | botão só de ícone (barra do editor, setas, o + das abas); `ligado` com fundo e borda fina | `BotaoSimbolo { icone; dica; ligado; ativo; giro: 90; redondo; pingo: "#f2c861"; lado; tamanhoIcone; focavel; onClicado }` |
| `BotaoCirculo` | botão redondo de ícone, afunda e volta com mola; selinho no canto que pula | `BotaoCirculo { icone; dica; ligado; selo: "3"; lado; corFundo; onClicado }` |
| `BotaoCoracao` | favoritar: o coração pula e solta faíscas; murcha ao tirar | `BotaoCoracao { ligado: fav; claro; comFundo; lado; cor; onClicado: fav = !fav }` |
| `LinhaEscolha` | como a `LinhaOpcao`, com o controle embaixo, na largura toda (painéis estreitos) | `LinhaEscolha { icone; nome; texto; Suspensa { Layout.fillWidth: true } }` |
| `FaixaAbas` | abas no topo do miolo (a aberta com o fundo da folha e a borda fina, sem tracinho); rola, arrasta, fecha | `FaixaAbas { modelo: listModel; atual; corFolha; onEscolher: (i); onFechar: (i); onMover: (de, para); onNova; onMenu: (i, item, x, y) }`; papéis `nome`, `modificado`, `carregando`, `dica` (ou `dicaDe: (a) => ...`) |

**Nome de peça nova:** uma peça desta pasta ganha da que tem o mesmo nome na pasta do
app (o `import "../comum"` vem antes da pasta do próprio arquivo). Antes de criar uma
peça aqui, confira que nenhum app tem um arquivo com o mesmo nome
(`find system_files/usr/share/matsu -name Nome.qml`). Por isso o botão de ícone se
chama `BotaoSimbolo` (Música tem um `BotaoIcone` próprio) e o redondo, `BotaoCirculo`
(Relógio e Calendário têm um `BotaoRedondo` próprio).
