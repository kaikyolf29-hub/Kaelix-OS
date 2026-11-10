# Plano do Kaelix OS

Escrito em 09/11/2026. Este plano é de um **projeto separado do Valkode**. Ele vai morar num **repositório novo, público e gratuito**, numa outra conta do GitHub do criador. Foi escrito para ser entendido do zero, por qualquer conta ou IA.

**Para a IA que receber este arquivo:** leia tudo antes de começar. Crie o repositório `kaelix-os` e salve este plano nele como `docs/PLANO.md`. Comece pela Etapa 1 da seção 5, seguindo a seção 6 (completar o que o criador não lembrou) e a seção 7 (regras). Fale com o criador em português do Brasil, de forma simples.

Nome escolhido pelo criador em 09/11/2026: **Kaelix OS** (ele já usou esse nome num canal dele). Nos comandos e arquivos técnicos ele aparece em minúsculas: `kaelix`. Falta conferir a marca no INPI (ver a seção 4).

## 1. O que é

Um sistema operacional **do criador**, construído em cima de uma base Linux que já existe. É o mesmo caminho do Ubuntu, que nasceu do Debian, e do Mint, que nasceu do Ubuntu. Ninguém escreve kernel ou driver do zero. O que torna o sistema dele é **quem controla o que chega para quem usa**.

- **Atualizações saem do servidor do criador** (GitHub), assinadas com a chave dele. Quem instala recebe o que ele testou e aprovou, não o que a base solta.
- **Correções de erro feitas por ele**, no ritmo dele, com versões dele (1.0, 1.1…) e notas de atualização.
- **Pacotes próprios:**
  - visual;
  - central de configurações;
  - gerenciador de tarefas;
  - terminal próprio;
  - assistente do primeiro boot;
  - atualizador e instalador;
  - no futuro, a integração com o Valkode.
- **Com o tempo**, ele mesmo compila os pacotes mais importantes (kernel e gráficos), com ajustes de desempenho próprios.
- **Drivers** de placa de vídeo, áudio e rede vêm dos fabricantes e da base, mas passam pelo servidor dele e chegam quando ele libera.
- **Tudo gratuito e público.** Nada pago. O Valkode (o app pago do criador) continua um produto separado: o sistema funciona sem ele, e quem quiser instala o Valkode depois.

### Para que serve

1. **Jogar:** Steam, Epic Games e outros lançadores, com bom desempenho.
2. **Programar:** terminal pronto, linguagens e editores.
3. **Cibersegurança:** as ferramentas do Kali disponíveis sem precisar instalar o Kali.
4. **Uso normal:** navegador, arquivos, vídeos e trabalho do dia a dia.
5. **Futuro:** o Valkode rodando nele do melhor jeito possível.

## 2. Decisões técnicas

### Base: Fedora Atomic (imagem própria com bootc)

O sistema é descrito num arquivo (`Containerfile`) dentro do repositório. A cada mudança, o GitHub monta sozinho a imagem do sistema inteiro, assina e publica no registro do próprio GitHub (`ghcr.io/<usuario>/kaelix-os`). As máquinas de quem usa se atualizam a partir **dessa imagem**.

Por que essa base:

- **A atualização é inteira e atômica:** ou o sistema todo atualiza, ou nada muda. Não fica pela metade.
- **Se uma atualização quebrar, dá para voltar à versão anterior no próprio menu de boot.** Isso é essencial para quem mantém sozinho.
- **Tudo é automático no GitHub**, sem servidor próprio pago.
- É o mesmo esquema das distribuições de jogo mais usadas hoje, com Steam e drivers resolvidos.

Alternativa considerada: Arch, como nas distros otimizadas. É mais rápida, mas atualiza o tempo todo e quebra com mais facilidade. Fica de fora no começo.

### Repositório de pacotes próprio

Os programas criados pelo criador (central de configurações, monitor de desempenho e atualizador) viram pacotes RPM num repositório dele. Esses pacotes também são montados pelo GitHub e assinados. A imagem do sistema já sai com eles.

### Assinatura (obrigatória desde o primeiro dia)

- **Imagem do sistema:** assinada com **cosign**.
  - A chave privada fica **só** nos segredos do GitHub (`Settings → Secrets → Actions`), nunca no código nem solta no PC.
  - A chave pública vai dentro do sistema, e a máquina só aceita atualização com assinatura válida.
- **Pacotes RPM:** assinados com uma chave GPG do criador, guardada do mesmo jeito.
- **Cópia de segurança das chaves privadas offline**, num pendrive guardado. Quem perde a chave não consegue mais assinar; se ela vaza, outra pessoa consegue se passar pelo sistema.
- **Verificação em duas etapas ligada na conta do GitHub.** O repositório é público, mas só o criador publica.

### Área de trabalho: KDE Plasma

É a mais personalizável que existe e consegue juntar o que o criador gosta nos dois sistemas. Regra: **fundir, não copiar.** Nada de logo, ícones, cores exatas ou nomes da Apple ou da Microsoft. O visual é próprio e só **lembra** o que ele gosta.

| Parte | Inspiração | Como fica |
|---|---|---|
| Barra de cima | Mac | **Barra fina no topo, no estilo da barra de menus do Mac**, de vidro. À esquerda, a logo do Kaelix e o nome do app aberto. À direita, Wi-Fi, Bluetooth, som, bateria, data e hora, e o botão da **central de controle**, um painel de vidro com Wi-Fi, som, brilho, modo escuro, perfis de energia e "não perturbe" |
| Barra de baixo (apps) | Mac | **Dock no estilo do Mac**: flutuante e de vidro, com os apps no centro, ícones que crescem ao passar o mouse e um ponto embaixo dos apps abertos. No começo do Dock fica o botão que abre a lista de todos os apps |
| Botões da janela | Mac | Três botões redondos no canto (fechar, minimizar e tela cheia), no estilo dos "semáforos" do Mac, mas com **cores próprias do Kaelix**, não o vermelho, o amarelo e o verde da Apple. O símbolo aparece ao passar o mouse |
| Vidro (transparência) | Mac | Barra de cima, Dock, menus, central de controle e central de configurações com efeito de **vidro fosco**: translúcido, desfocando o que está atrás, com um tom cinza e uma borda de luz suave, como nos Macs mais novos |
| Pastas e arquivos | Windows | Gerenciador de arquivos com painel lateral (Este computador, Downloads, Documentos, discos), abas e caminho no topo |
| Configurações | Mac | Central de configurações própria: lista à esquerda com ícones, conteúdo limpo à direita e busca no topo |
| Desempenho (CPU, RAM, placa de vídeo, disco, rede) | Windows | **Gerenciador de tarefas próprio**, organizado como o do Windows: a aba Desempenho com uma lista à esquerda (processador, memória, placa de vídeo, discos, rede) e, à direita, o gráfico grande da peça escolhida, com nome, uso, temperatura e velocidade. Abas de processos e de apps que iniciam com o sistema. Abre com Ctrl+Shift+Esc |
| Terminal | Próprio | **Terminal do Kaelix**: app próprio, bonito, de vidro, com abas, divisão de tela, temas claro e escuro e a fonte e as cores do Kaelix. O comando `kaelix` aparece ali com ajuda clara. No estilo dos terminais modernos, sem cara de sistema antigo |
| Apps abrindo e fechando | Mac | Animação suave que sai do ícone na barra e volta para ele ao minimizar, com cantos arredondados |
| Janelas | Mistura | Cantos arredondados, sombra leve e barra de título integrada |
| Fundo e cores | Do criador | Tema claro e escuro, **nunca preto puro** (o monitor do criador escurece demais o preto) |

### Acabamento premium (nível de sistema vendido)

O Kaelix é gratuito, mas precisa **parecer um sistema pago**, bonito e polido em cada detalhe:

- **Do ligar ao desligar, tudo com a cara do Kaelix:** tela de boot animada, tela de login de vidro com o fundo do sistema, tela de bloqueio e tela de desligar.
- **Uma fonte só**, moderna e bem legível, em todo o sistema, e ícones de um mesmo estilo (sem misturar ícones de pacotes diferentes).
- **Animações suaves**, sem travar, mesmo na RX 580 do criador. Se o vidro pesar numa placa fraca, ele fica mais simples sozinho.
- **Sons próprios**, discretos: ligar, notificação e erro.
- **Papéis de parede próprios**, claros e escuros, que combinam com o vidro.
- **Nada com cara de "Linux cru":** nenhuma janela de configuração técnica aparecendo para quem usa, nenhum ícone quebrado e nenhuma tela com metade em português e metade em inglês (o idioma escolhido vale para tudo).
- **Revisão de acabamento a cada versão:** abrir cada tela, tirar foto e conferir alinhamento, cores e textos antes de lançar.

### Português e inglês

- **O sistema inteiro funciona nos dois idiomas**, português do Brasil e inglês, escolhidos no primeiro boot e trocados na central de configurações: telas, apps próprios, instalador, site e notas de versão.
- **No terminal, os comandos de programação continuam em inglês**, como no mundo todo (`git`, `python`, `npm`, `ls`, `cd`). Não traduzir nada disso: é o que o criador vai estudar, e o que ele aprender vale em qualquer computador.
- **Os comandos do Kaelix aceitam os dois idiomas:**

| Português | Inglês |
|---|---|
| `kaelix atualizar` | `kaelix update` |
| `kaelix voltar` | `kaelix rollback` |
| `kaelix drivers` | `kaelix drivers` |
| `kaelix seguranca` | `kaelix security` |
| `kaelix ajuda` | `kaelix help` |

### Terminal opcional, mas ótimo para estudar

- **Tudo o que uma pessoa comum precisa dá para fazer sem terminal:** instalar apps pela loja, atualizar, drivers, configurações, Wi-Fi e jogos. Quem nunca abrir o terminal usa o Kaelix normalmente.
- **Para quem quer aprender (o caso do criador)**, o terminal do Kaelix ajuda a estudar:
  - `kaelix explica <comando>` mostra, em português ou inglês, o que o comando faz, com exemplos simples (por exemplo, `kaelix explica git commit`);
  - um **modo aprendiz** opcional que, quando liga, mostra embaixo do comando digitado uma linha curta explicando o que aconteceu;
  - **trilhas de estudo** prontas, acessadas pelo terminal: básico do terminal, Git e GitHub, Python e segurança (no contêiner do Kali);
  - autocompletar e sugestão de comandos enquanto digita;
  - mensagens de erro com uma dica do que fazer, em vez de só o erro em inglês.
- **Quando o Valkode estiver integrado (Etapa 3)**, ele pode explicar comandos e erros pelo terminal também.

### Programas que já vêm

- **Navegador:** no primeiro boot, a pessoa escolhe entre **Google Chrome** e **Brave**, e pode instalar os dois.
- **Jogos:**
  - **Steam** com Proton, pronta;
  - **Heroic**, para a Epic Games e a GOG;
  - **Lutris**, para os outros lançadores;
  - **GameMode** e **MangoHud**, para desempenho e números na tela.
- **Programação:**
  - Git, Python, Node e compiladores;
  - VS Code (ou uma versão aberta dele);
  - **Distrobox**, para criar ambientes de outras distros sem sujar o sistema.
- **Cibersegurança:** um **contêiner do Kali pronto via Distrobox**, criado pelo comando `kaelix seguranca`. As ferramentas do Kali rodam dentro dele, e o sistema principal continua limpo e estável.
- **Vídeo:** Kdenlive e OBS Studio, instalados como estão, sem misturar o código deles em nada.
- **Loja de apps:** Flathub ativado, para instalar programas com um clique.

### Aviso importante sobre jogos

**O Fortnite não roda no Linux hoje.** A própria Epic decidiu não ativar o antitrapaça do Fortnite no Linux, e nenhuma distribuição resolve isso. O mesmo vale para alguns outros jogos com antitrapaça no kernel, como o Valorant.

A maioria dos jogos da Steam e da Epic roda bem pelo Proton. Antes de prometer um jogo no canal, conferir em **protondb.com** e **areweanticheatyet.com**.

O assistente do primeiro boot explica isso e oferece o jeito legítimo: **jogar pela nuvem** (GeForce Now ou Xbox Cloud Gaming), no navegador, onde o Fortnite funciona. Nunca tentar burlar o antitrapaça, porque isso dá banimento da conta.

### Drivers

- **AMD e Intel:** já vêm no sistema.
- **NVIDIA:** a imagem tem uma variante com o driver oficial já incluído. A pessoa escolhe a imagem certa no download, e o atualizador troca de variante se ela mudar de placa.
- **Comando** `kaelix drivers`: verifica e instala o que falta. Também aparece na central de configurações.
- **Não hospedar driver baixado de site nenhum.** O que entra vem dos repositórios oficiais e passa pela imagem assinada.

### Atualizações e canais

- `estavel`: o que quem usa recebe. Só sai depois de testado.
- `teste`: o criador e quem quiser ajudar testam antes.
- Cada versão estável vira um **Release no GitHub**, com notas e a imagem de instalação (ISO) para baixar.
- Para atualizar: o comando `kaelix atualizar` ou o botão na central de configurações.
- Se der problema: `kaelix voltar` (ou o menu de boot) volta à versão anterior.

## 3. Como o criador vai testar

1. **Primeiro, numa máquina virtual** no próprio Windows (o Hyper-V vem no Windows 11 Pro), para nenhum erro tocar no PC real.
2. **Depois, no SSD NVMe de cerca de 200 GB**, em dual boot com o Windows. Antes de instalar:
   1. fazer cópia de segurança do que importa (HD externo);
   2. no instalador, selecionar **só o SSD do Linux**, sem tocar no disco do Windows;
   3. conferir duas vezes o disco escolhido antes de confirmar.

O PC do criador tem uma RX 580 (AMD, com driver já incluído). A variante NVIDIA só pode ser testada quando houver uma placa NVIDIA.

## 4. O nome

**Escolhido: Kaelix OS.**

"Cobalt OS" foi descartado em 09/11/2026, porque já existem:

- um CobaltOS Linux ativo (baseado em Debian, para Chromebook);
- o CobaltX (distro de jogo baseada em Arch);
- sistemas Cobalt baseados em FreeDOS e OpenBSD.

O nome também vai ser o da **empresa do criador**, então precisa estar livre como sistema e como marca. Estas foram as opções criadas em 09/11/2026; nenhuma apareceu em busca na internet como sistema operacional:

| Nome | Ideia | Observação |
|---|---|---|
| **Kaelix OS** ✔ escolhido | Som forte, parecido com o de Valkode; o criador já usou num canal | Existem empresas "Kalix" e "Kelix" (nomes parecidos, outras áreas) |
| Nyxar OS | Nyx, a deusa da noite: escuro, hacker | Existe uma empresa espacial chamada "Nyxara" |
| Zyrkon OS | Zircão, um mineral | Nada encontrado com essa grafia |
| ~~Korvex OS~~ | | Descartado: soa igual a **Corvex**, empresa de nuvem listada na bolsa americana |

Antes de divulgar o nome:

1. procurar no **INPI** (busca de marcas, classes 9 e 42: software e tecnologia);
2. procurar no GitHub, no DistroWatch e no Google;
3. ver se o domínio (`.com` e `.com.br`) e o nome de usuário no GitHub, no YouTube e no Instagram estão livres;
4. **registrar a marca no INPI** antes de divulgar no canal, já que vai virar empresa.

Onde o nome aparece:

- tela de boot, instalador, "Sobre este computador" e página do projeto;
- arquivo de instalação (ISO): `kaelix-os-1.0-amd.iso` e `kaelix-os-1.0-nvidia.iso`;
- imagem de atualização: `ghcr.io/<usuario>/kaelix-os`;
- comando do terminal: `kaelix` (por exemplo, `kaelix atualizar`);
- repositório: `kaelix-os`.

A logo só entra depois de aprovada pelo criador.

## 5. As três etapas

Cada etapa termina em algo que funciona e vira episódios no canal do criador.

### Etapa 1: Fundação (o sistema já é dele)

- Criar o repositório público `kaelix-os`, com licença aberta (GPL-3.0 ou MIT nos arquivos próprios).
- Escrever o `Containerfile` em cima do Fedora Atomic KDE, com:
  - Steam, Heroic, Lutris, GameMode e MangoHud;
  - Flathub;
  - a escolha entre Chrome e Brave;
  - as ferramentas de programação, o Distrobox e o comando do contêiner Kali.
- Configurar o GitHub Actions para montar a imagem, **assinar com cosign** e publicar em `ghcr.io`, montando também a variante NVIDIA.
- Gerar a ISO de instalação e publicar como Release.
- Criar os comandos `kaelix atualizar`, `kaelix voltar`, `kaelix drivers` e `kaelix seguranca`.
- Testar na máquina virtual e depois no SSD, em dual boot.
- **Pronto quando:** o criador instala a partir da ISO dele, joga um jogo da Steam e recebe uma atualização assinada vinda do GitHub dele.

### Etapa 2: A cara do sistema

- Tema próprio do KDE (claro e escuro, nunca preto puro), com:
  - a barra de cima no estilo do Mac (Wi-Fi, som, bateria, hora e central de controle);
  - o Dock embaixo com os apps, de vidro;
  - os botões da janela redondos, com cores próprias do Kaelix;
  - efeito de vidro fosco nos painéis e menus;
  - animações no estilo do Mac;
  - cantos arredondados;
  - ícones e cursor próprios.
- Gerenciador de arquivos configurado no estilo das pastas do Windows.
- **Central de configurações própria** (estilo Mac), como pacote RPM do repositório dele.
- **Gerenciador de tarefas próprio** (organização do Windows): CPU, RAM, placa de vídeo, disco e rede.
- **Terminal do Kaelix**, como app próprio.
- **Assistente do primeiro boot**, que pergunta ou mostra:
  - o idioma;
  - o navegador;
  - a variante de driver;
  - o aviso sobre jogos com antitrapaça e o atalho para jogos pela nuvem;
  - se a pessoa quer as ferramentas de segurança.
- Logo do Kaelix OS desenhada e aprovada pelo criador.
- Antes de começar esta etapa, **mostrar ao criador uma demonstração em vídeo do visual**, fora do sistema, para ele aprovar.
- **Pronto quando:** o sistema é reconhecível como dele à primeira vista e tudo do primeiro boot funciona.

### Etapa 3: Lançamento público e otimizações próprias

- Separar o canal `teste` do `estavel`.
- Criar a página do projeto (GitHub Pages), com download, requisitos e lista de jogos testados.
- Criar modelos de issue no GitHub para quem quiser relatar erro ("Relatar bug" e "Pedir recurso").
- Compilar um kernel próprio, com ajustes de desempenho para jogo, como pacote do repositório dele.
- Preparar o espaço para o **Valkode**:
  - um botão "Instalar Valkode" na central, opcional (o sistema continua gratuito);
  - os testes do Valkode no sistema.
- **Pronto quando:** qualquer pessoa baixa pela página, instala, recebe atualizações e consegue relatar erro.

## 6. A IA completa o plano (importante)

O criador avisou: **ele não vai lembrar de pedir tudo**. Quem continuar este plano (qualquer conta ou IA) deve, em cada etapa, **procurar o que falta para um sistema completo e bom de usar** e propor, sem esperar ele pedir. O jeito dele vale sempre:

- visual Windows + Mac fundido, sem copiar;
- fundo nunca preto puro;
- tudo explicado em português simples;
- demonstração em vídeo antes de mudar o visual;
- foto antes de dizer que algo está pronto.

Propor é diferente de decidir: mostrar a lista do que falta e deixar ele escolher. A lista inicial do que ele provavelmente não lembrou:

**Hardware e uso diário**
- teclado **ABNT2**, português do Brasil e fuso horário de Brasília já configurados;
- **duas telas** (o criador usa duas): posição, taxa de atualização, VRR/FreeSync e HDR;
- controles de Xbox e PlayStation funcionando ao ligar (USB e Bluetooth);
- Bluetooth, fones e microfone; impressora e scanner;
- perfis de energia (economia, equilibrado e desempenho), visíveis na barra;
- atualização de firmware (BIOS, SSD) pelo `fwupd`, dentro da central de configurações.

**Dual boot com o Windows**
- **relógio certo nos dois sistemas**: o Windows e o Linux contam a hora de jeitos diferentes, e sem ajuste o relógio fica errado ao trocar de sistema;
- **acesso aos discos do Windows** (como o disco K: do criador), com leitura e escrita seguras;
- menu de boot bonito, com o Windows na lista;
- funcionar com **Secure Boot** ligado, inclusive com o driver da NVIDIA.

**Segurança e privacidade**
- firewall ligado por padrão;
- opção de **criptografar o disco** na instalação;
- **zero telemetria**: o sistema não manda nada para ninguém sem a pessoa ligar;
- atualizações de segurança automáticas, assinadas (ver a seção 2);
- pendrive de recuperação: um comando que cria um pendrive para consertar o sistema.

**Para o canal e para o criador**
- OBS Studio pronto para gravar a tela e a webcam;
- captura de tela e gravação curta com um atalho;
- Discord;
- jogos pela nuvem (GeForce Now e Xbox Cloud Gaming) como atalho;
- notas da versão bonitas a cada atualização, prontas para virar vídeo.

**Qualidade do sistema**
- cópia de segurança dos arquivos da pessoa com um clique;
- relatório de erro: quando algo quebra, um botão gera o relatório e abre uma issue no GitHub, só se a pessoa quiser;
- acessibilidade: tamanho de texto, alto contraste e leitor de tela;
- teste automático da imagem no GitHub antes de cada versão (o sistema liga e abre a área de trabalho).

Cada item que entrar vira uma linha numa lista de acompanhamento no repositório, marcada quando estiver feita e provada.

## 7. Regras que valem o projeto todo

- Repositório público. **Segredos (chaves cosign e GPG, tokens) só nos segredos do GitHub**, nunca no código.
- Nunca publicar versão estável sem o criador pedir. Montar uma imagem de teste não é publicar.
- Respeitar a licença de cada programa incluído. Programas de terceiros entram como estão, sem misturar o código deles nos programas próprios.
- Explicar tudo ao criador em português simples e mostrar foto ou vídeo antes de dizer que algo está pronto.
- Este projeto não mexe no repositório do Valkode, e o Valkode não depende dele.
