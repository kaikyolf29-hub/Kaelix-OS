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
| `Botao` | botão sem fundo (barra de ferramentas) | `Botao { texto; icone; dica; onClicado }` |
| `BotaoDestaque` | botão principal; `estado: "carregando"` (rodinha) e `"feito"` (verde com visto); `perigo` (vermelho) | `BotaoDestaque { texto: "Enviar"; estado: s; textoFeito: "Enviado" }` |
| `Chave` | ligar e desligar | `Chave { ligada: x; onTrocada: (l) => x = l }` |
| `Marca` | caixinha que pula ao marcar; `redonda` para tarefas | `Marca { marcada: x; onTrocada: (m) => x = m }` |
| `Seletor` | botões segmentados com a pílula que desliza | `Seletor { opcoes: [{id, nome}]; escolhido; onEscolher: (id) => ... }` |
| `Passos` | valor numa lista, com setinhas | `Passos { opcoes; escolhido; onEscolher }` |
| `Contador` | − número + (o número rola); segurar repete | `Contador { valor; minimo; maximo; passo; sufixo: " min"; onMudou: (v) => ... }` |
| `NumeroRolante` | número cujos algarismos rolam ao mudar | `NumeroRolante { texto: janela.num(v, 2); font.pixelSize: 40 }` |
| `Anel` | anel de progresso (0 a 1), pula ao completar | `Anel { valor: 0.75; texto: "3/4"; subtexto: "tarefas" }` |
| `Girando` | rodinha de carregando | `Girando { width: janela.gu }` |
| `Etiqueta` | chip; o visto entra ao escolher | `Etiqueta { texto: "Rock"; escolhida: x; onTrocada: (e) => x = e }` |
| `Deslizante` | controle deslizante com balão do valor | `Deslizante { de: 0; ate: 100; valor; onMovido: (v) => ...; onSolto: (v) => ... }` |
| `Onda` | onda do som com o progresso; clicar pula | `Onda { amostras: [...]; progresso: 0.4; onBuscar: (f) => ... }` |
| `Sanfona` | cartão que abre e fecha | `Sanfona { titulo: "Pergunta"; Texto { ... } }` |
| `Campo` | campo de texto | `Campo { dica: "Nome"; texto; onEditado: (t) => ...; onConfirmado: ... }` |
| `Suspensa` | lista suspensa com visto | `Suspensa { opcoes: [{id, nome}]; escolhido; onEscolher: (id) => ... }` |
| `MenuMatsu` | menu do botão direito | `menu.abrirEm(item, x, y)`; `itens: [{id, nome, icone, atalho, perigo, separador}]` |
| `Dialogo` | pergunta no meio, com o fundo escurecido | `dialogo.perguntar({titulo, texto, sim, nao, perigo, terceiro}, aoSim, aoTerceiro)` |
| `Vazio` | quando não há nada (sem músicas, sem câmera) | `Vazio { icone; titulo; texto; botao; onClicado }` |
| `LinhaOpcao` | linha de ajuste (ícone, nome, explicação e o controle) | `LinhaOpcao { nome; texto; Chave { } }` |
| `BarraRolagem` | barra de rolagem fina do Matsu | `QQC2.ScrollBar.vertical: BarraRolagem {}` |
| `ImagemRedonda` | imagem com cantos redondos | ver o arquivo |
| `Grafico` | gráfico de linha (Gerenciador) | ver o arquivo |
| `FundoBalao` | fundo dos balões (lista, menu, diálogo) | `background: FundoBalao {}` |
