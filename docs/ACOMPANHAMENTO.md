# Lista de acompanhamento

> **11/11/2026:** o sistema mudou de nome. O Kaelix OS agora é o **Matsu 27 OS** (logo do pinheiro japonês). Os registros antigos abaixo já aparecem com o nome novo.

Cada item do plano vira uma linha aqui. Um item só ganha ✅ quando está **feito e provado**
(foto, vídeo ou teste rodando).

| Marca | Quer dizer |
|---|---|
| ✅ | Feito e provado |
| 🔧 | Feito, falta provar (montar no GitHub ou testar na máquina) |
| ⬜ | Ainda não começado |
| 💬 | Proposta: esperando o criador escolher |

## Etapa 1: Fundação

| | Item | Observação |
|---|---|---|
| ✅ | Repositório público `matsu-os`, licença GPL-3.0 | Criado em 09/11/2026 |
| ✅ | Plano salvo em `docs/PLANO.md` | |
| ✅ | Chave de assinatura cosign criada no pendrive do criador | Pública em `cosign.pub`. Ver `docs/CHAVES.md` |
| ✅ | Chave privada e senha nos segredos do GitHub | Provado: a montagem 20261110.6 saiu assinada e conferida |
| ✅ | Chave guardada no pendrive (nasceu nele, nunca ficou solta no PC) | |
| ⬜ | Verificação em duas etapas na conta do GitHub | Passo do criador |
| ✅ | `Containerfile` em cima do Fedora Atomic KDE (Fedora 44) | Base `ublue-os/kinoite-main`. Monta sem erro no GitHub (montagem 20261110.6) |
| 🔧 | Steam (com Proton), GameMode e MangoHud | Pacotes RPM na imagem |
| 🔧 | Heroic e Lutris | Flatpak, instalados no primeiro boot com internet |
| 🔧 | Flathub ligado | Serviço `matsu-flatpak-setup` |
| 🔧 | Escolha entre Chrome e Brave | A pergunta abre sozinha no primeiro login (provado na máquina virtual) e também por `matsu navegador`. Falta provar a instalação do navegador escolhido |
| 🔧 | Ferramentas de programação, VS Code e Distrobox | |
| 🔧 | OBS Studio e Kdenlive | Flatpak |
| ✅ | GitHub Actions monta, assina com cosign e publica em `ghcr.io` | `ghcr.io/kaikyolf29-hub/matsu-os:teste`, assinatura conferida no próprio fluxo |
| 🔧 | Variante NVIDIA | `ghcr.io/kaikyolf29-hub/matsu-os-nvidia:teste` montada e assinada. Falta testar numa placa NVIDIA |
| 🔧 | ISO de instalação | Montada pelo fluxo `Montar ISO` (instalador de rede, 1,2 GB, AMD e NVIDIA). Falta instalar de verdade |
| 🔧 | Publicar como Release | Fluxo `Publicar versão estável`. Só roda quando o criador manda |
| ✅ | Comandos `matsu atualizar`, `voltar`, `drivers`, `seguranca` (e `navegador`, `versao`) | 30 testes automáticos passando |
| ✅ | Imagens públicas no ghcr.io | Já ficaram públicas sozinhas (herdaram do repositório) |
| ✅ | Testar na máquina virtual | Automático no GitHub (fluxo `Testar e tirar prints`): liga, entra na área de trabalho, abre o terminal e roda `matsu`. Prints no ramo `prints` |
| ⬜ | Instalar numa máquina de teste pelo criador | Combinado: só com o sistema completo, perto do fim. `docs/COMO-TESTAR.md` |
| ⬜ | Testar no SSD, em dual boot | `docs/COMO-TESTAR.md` |
| ⬜ | **Pronto quando:** instala pela ISO, joga um jogo da Steam e recebe atualização assinada | |

## Etapa 2: Visual próprio

| | Item | Observação |
|---|---|---|
| ✅ | Escolher onde ficam a rede, o som e o relógio | O criador escolheu a **fusão** (09/11/2026): tudo embaixo, em três ilhas de vidro flutuantes. Busca à esquerda, apps no meio, rede, som e relógio à direita. Sem barra no topo |
| ✅ | Vídeo de demonstração do visual, antes de começar | Feito fora do sistema. Fonte em `docs/visual/` (abrir `demo.html` no navegador) |
| ✅ | O criador aprovar o vídeo | Aprovado em 10/11/2026 |
| ⬜ | Servir para PC e para notebook | Pedido do criador: no PC mostra a rede por cabo e esconde a bateria; no notebook mostra Wi-Fi e bateria; com os dois, mostra os dois |
| ✅ | Tema escuro e claro, nenhum com preto puro | Cores `MatsuEscuro` e `MatsuClaro` e temas globais `org.matsu.escuro.desktop` e `org.matsu.claro.desktop`. Provado na máquina virtual em 10/11/2026 |
| ✅ | Barra em três ilhas (a fusão) como padrão | Feita pelo arranjo do tema global, com cantos redondos, borda clara e destaque redondo do app aberto (tema Plasma `Matsu`, gerado por `system_files/usr/share/matsu/vidro/gerar.py`). Provada na máquina virtual em 10/11/2026. O desfoque de vidro só dá para ver no PC de verdade, porque a máquina virtual não tem placa de vídeo |
| ✅ | Papel de parede próprio em pixel art | Pedido do criador: fundo bonito de verdade. Pôr do sol no lago, feito por código (`visual/papel-de-parede/gerar.py`), versão escura e clara. Provado na máquina virtual em 10/11/2026 |
| ✅ | Personalizar a barra | Pedido do criador. Três estilos: "Fusão" (padrão), "Mac" (barra fina no topo e doca) e "Windows" (uma barra só embaixo), em três tamanhos. Pelo menu ("Estilo da barra") ou pelo comando `matsu barra`. Mantém os apps fixados. Provado na máquina virtual em 10/11/2026. Agora também fica nos Ajustes do Matsu (página Barra), com a opção de esconder a barra sozinha (`matsu barra --esconder sim`) |
| 🔧 | Ícones próprios para os apps da barra | Pedido do criador: bem personalizados e bonitos. Primeira leva: Arquivos, Terminal, Loja, Monitor, Configurações, Editor de texto, Capturas e Imagens (`visual/icones/gerar.js`, tema de ícones `Matsu`). Programas de outras marcas (Steam, navegador) ficam com o ícone deles. Provados na máquina virtual em 10/11/2026. Falta a opinião do criador |
| 🔧 | Ícones do sistema todo, sem nada genérico | Pedido do criador (11/11/2026): nenhum ícone feio ou genérico, nem nas Configurações do sistema. Inventário da imagem (`tests/vm/inventario.sh`, roda no GitHub com `[inventario]` na mensagem do commit): 37 apps no menu, 25 grupos e 105 páginas das Configurações. Feitos 91 ícones no jeito dos Ajustes do Matsu, quadrado colorido com desenho branco (`visual/icones/ajustes.js`): todas as páginas das Configurações do sistema e os apps do KDE que estavam com ícone do Breeze (Ark, Firewall, Centro de ajuda, Centro de informações, Carteira, KDE Connect, Filelight, KFind, Partições, Caracteres, Registros, Editor de menus, Emoji...). O Centro de boas-vindas ganhou o logo do Matsu, os Ajustes do Matsu um ícone próprio (antes igual ao das Configurações) e o "Estilo da barra" abre nos Ajustes. Steam, Firefox, VS Code, CoreCtrl, htop e nvtop ficam com a logo oficial. Nomes de ação e de aparelho do KDE (pendrive, teclado, "Sair"...) continuam com o Breeze de propósito, para não virar quadrado colorido no Arquivos e nos menus dos apps. Conferido no Plasma de teste; falta a máquina virtual e o retorno do criador |
| ✅ | Botões de janela nas cores do Matsu | Vermelho (fechar), amarelo (minimizar) e verde (tela cheia), como no Mac, do lado esquerdo; cinza com a janela em segundo plano. Feitos em cima da moldura do KDE (`build_files/deco/`). Provados na máquina virtual em 10/11/2026; cores trocadas em 12/11/2026 |
| 💬 | Dock que aumenta os ícones perto do mouse | A barra do KDE não tem esse efeito. Só com uma doca própria, num app à parte. Fica para depois, se o criador quiser |
| 🔧 | Central de controle no canto direito | Feita, na ilha da direita e no atalho Meta+A: rede (Wi-Fi no notebook, cabo no PC), Bluetooth, não perturbe, tema escuro, luz noturna, estilo da barra, volume, brilho e bateria (só aparecem onde existem), configurações, bloquear e desligar. Na máquina virtual ela abre pelo Meta+A e lê o sistema certo. Ganhou o perfil de energia (economia, equilibrado, desempenho) |
| 🔧 | Menu e busca no jeito do vídeo | Menu próprio do Matsu (`org.matsu.menu`) no lugar do menu do KDE: botão do logo e a pílula "Buscar apps e arquivos" na ilha da esquerda, como no vídeo da fusão. Abre com a tecla Meta, Alt+F1 ou um clique. Tem a busca (apps, arquivos e ajustes, o primeiro resultado já escolhido, Enter abre), os recentes (numa conta nova, os fixados), todos os apps em grade e, embaixo, a conta, os Ajustes do Matsu, bloquear e desligar. Funciona no teclado e segue o vidro e o tema claro/escuro. Em 11/11/2026 um teste com o KDE 6.6 mostrou que o menu não abria (usava uma opção que o KDE tirou); consertado e conferido abrindo. Falta o print da máquina virtual |
| 🔧 | Assistente de primeiro uso em português e com a cara do Matsu | A tela de boas-vindas ganhou o logo, o texto do Matsu e três telas próprias (tema e barra, navegador, comando `matsu`), provado na máquina virtual em 10/11/2026. Falta o assistente de criar a conta (Plasma Setup), que ainda é o do KDE |
| ✅ | Logo do Matsu | Desde 11/11/2026 é um bonsai rosa dentro do ensō (o círculo de pincel zen), no fundo ameixa: a junção das duas imagens de referência do criador, a árvore da segunda com o rosa e o acabamento da primeira. Ele deixou eu aprovar a versão final. Antes foi o pinheiro branco podado em nuvens e, até 10/11/2026, o "Asas". Fonte em `visual/logo/`. É o botão do menu, o logo do sistema, a tela de carregamento, a tela de boot, o instalador e o desenho em letras do fastfetch. Conferido nos prints da máquina virtual em 11/11/2026 (boot, botão do menu, Sobre e fastfetch) |
| ✅ | Tela de login, tela de bloqueio e tela de carregamento com a cara do Matsu | Login e bloqueio usam o papel de parede em pixel art; depois da senha aparece o logo no fundo quase preto, no lugar do logo do KDE. Provado na máquina virtual em 10/11/2026 (com o logo novo em 11/11/2026) |
| 🔧 | Peças das telas de login, bloqueio e sair no estilo do Matsu | Essas telas vêm prontas dentro do KDE, mas dividem peças que dá para trocar: botões redondos de vidro (desligar, reiniciar, sair), hora em negrito e a foto da pessoa num círculo da cor de destaque. Feito por `build_files/telas-kde.py`, que pula sem quebrar se o KDE mudar o arquivo. O teste da máquina virtual agora digita a senha no bloqueio e prova que desbloqueia. Falta o print |
| 🔧 | Alt+Tab como no Windows 11 | As janelas em miniatura lado a lado, no vidro do Matsu. Falta o print |
| 🔧 | Vidro com cor e transparência à escolha | Pedido do criador (10/11/2026): o vidro das ilhas, menus e balões pode ser incolor (padrão) ou azul, roxo, rosa, vermelho, laranja, amarelo, verde, grafite ou qualquer cor, com três níveis de transparência. Nos Ajustes do Matsu (Aparência) ou por `matsu vidro roxo --transparencia mais`. Conferido no computador; falta o print da máquina virtual |
| 🔧 | Cinza neutro no sistema todo, sem o azul | Pedido do criador (11/11/2026, "Sim, em tudo"): o cinza do terminal e do Gerenciador de tarefas vai para tudo. Esquemas de cores MatsuEscuro e MatsuClaro refeitos em `visual/cores/gerar.py` (janelas, listas, títulos e seleção em cinza, cor só nos detalhes); o destaque padrão do vidro virou "Cinza neutro" (#6e6e76). Conferido nos Ajustes e nas Configurações do KDE num teste com o KDE 6.6; falta o print da máquina virtual |
| 🔧 | Ajustes do Matsu (como os Ajustes do Sistema do Mac) | App próprio de configurações com barra lateral e busca: Aparência, Barra (estilo Mac, Fusão ou Windows, tamanho, esconder sozinha), Papel de parede, Telas, Som, Rede, Bluetooth, Notificações, Energia, Sobre e "Mais ajustes". Abre pela engrenagem da central e fica fixado na barra. Falta o print da máquina virtual |
| 🔧 | Terminal e Arquivos no estilo do vídeo | Terminal com fundo de vidro (escuro ou claro, segue o tema), fonte JetBrains Mono, sem barra de menu e com o prompt do Matsu (pasta, ramo do git e setinha). Arquivos abre em lista com data, tipo e tamanho. Falta o print da máquina virtual |
| 🔧 | Lixeira própria | Ícone próprio (vazia e cheia) e lixeira no fim da ilha do meio (fusão) e da doca (estilo Mac). Falta o print da máquina virtual |
| 🔧 | Ilha da direita e relógio como no vídeo | Pílula com rede, som e bateria, relógio com data e balão da central. Esperando os prints da máquina virtual |
| 🔧 | Ícones de apps na bandeja, como no Windows | O KDE (não é GNOME) já fala os dois jeitos: StatusNotifierItem/AppIndicator e o XEmbed antigo (pelo `xembedsniproxy`). Clique abre o app, botão direito abre o menu, segue o tema claro/escuro e os ícones extras ficam na setinha "mostrar mais". Teste com um app de bandeja de verdade na máquina virtual; como validar numa máquina de verdade está em `docs/COMO-TESTAR.md` ("Bandeja perto do relógio") |
| 🔧 | Papel de parede animado (Wallpaper Engine da Steam) | Pedido do criador. O app Waywallen vem do Flathub no primeiro boot e a peça dele para o KDE vem na imagem; ele roda os papéis do Wallpaper Engine que a pessoa tem na Steam (precisa ter o Wallpaper Engine comprado e baixado na Steam). Ligar em Ajustes do Matsu > Papel de parede. Falta o criador testar no PC dele |
| 🔧 | Tela de boot com o logo do Matsu | No lugar do logo do Fedora: o logo do Matsu no fundo quase preto, o nome e três pontos pulsando, igual à tela depois da senha, para ligar, entrar e carregar parecerem uma coisa só. Também a caixa da senha do disco (se ele for criptografado) e a tela de atualização em português. Tema do Plymouth feito por `visual/boot/gerar.py`. Conferido no computador nas telas 1920x1080 e 1366x768; falta o print da máquina virtual |
| 🔧 | Apps próprios: configurações, gerenciador de tarefas, terminal | Configurações: feito (Ajustes do Matsu). Terminal: app próprio (`matsu-terminal`, veja a linha "Terminal do Matsu"). Gerenciador de tarefas próprio (Ctrl+Shift+Esc): Processos, Desempenho e Inicialização, de vidro cinza no jeito do Windows 11; esperando os prints da máquina virtual e o retorno do Kaiky |
| 🔧 | Busca e menu no meio da barra | Pedido do criador (11/11/2026): a busca pode se juntar à ilha do meio, com os apps, e o botão do menu também pode ir para o meio, como no Windows 11. Nos Ajustes do Matsu (Barra e doca) ou por `matsu barra --busca meio` e `--menu meio` (também dá para tirar a busca). Conferido no computador; falta o print |
| 🔧 | Pôr e tirar apps da barra | Pedido do criador (11/11/2026). Nos Ajustes do Matsu (Barra e doca > Apps na barra): a lista dos apps fixados com subir, descer e tirar, "Adicionar app…" com busca e a grade de todos os apps, e "Voltar ao começo". No menu do Matsu, o botão direito num app tem "Fixar na barra" ou "Tirar da barra" e "Organizar os apps da barra…" (também no botão direito do logo). No terminal: `matsu barra apps`, `fixar`, `tirar` e `ordem`. Vale para a barra de todas as telas e muda na hora. Conferido num KDE 6.6 de teste (Ajustes, menu e comando); falta o print da máquina virtual |
| ✅ | Atalhos Meta+A (central) e Meta+B (bandeja) | O "percorrer as atividades" do KDE pegava o Meta+A e o "trocar perfil de energia" pegava o Meta+B, então a central e a bandeja só abriam no clique. O primeiro conserto gravava no /etc/xdg, que o serviço de atalhos não lê. Agora vai no arquivo de atalhos da pessoa, no login, e uma garantia confere no começo da sessão. Conferido na máquina virtual (af1e705): o Meta+A abre a central, e a central e a bandeja ficaram com as suas teclas |
| 🔧 | Barra como a do Windows em várias telas | Pedido do criador (11/11/2026). Cada tela ganha a barra do estilo escolhido (fusão, Mac ou Windows); a da tela principal fica com a bandeja, a central, a lixeira e os atalhos, as outras com o menu, os apps e o relógio. Cada app aberto aparece só na barra da tela onde a janela está (ou em todas, ou na principal e na dele, como as três opções do Windows). Ao ligar um monitor, a barra aparece nele sozinha (script `matsu-telas` do KWin e serviço `matsu-telas`), sem mexer nas barras que já existem. Nos Ajustes do Matsu (Barra e doca > Várias telas) ou por `matsu barra --telas` e `--abertos`. Conferido num KDE 6.6 de teste com duas telas (os três estilos, ligar e desligar monitor); a máquina virtual tem uma tela só. Falta o criador ver no PC dele com os dois monitores |
| 🔧 | Central de jogos (como o AMD Software) | Pedido do criador (11/11/2026), para AMD e NVIDIA. App próprio de vidro com cinco telas: Início (continuar jogando, recentes, modo jogo, sobreposição e placa), Meus jogos (as capas da Steam em grade, busca, ordem, e os detalhes de cada jogo com o fundo grande, horas, tamanho e perfil só dele), Gráficos (perfis padrão, desempenho, qualidade, economia e personalizado: energia, velocidade da placa AMD, limite de FPS, V-Sync, texturas nítidas e modo jogo), Sobreposição e Placa de vídeo (uso, temperatura, velocidade, memória, consumo, ventoinha e aviso de driver novo com "Atualizar agora"). Um ajudante na sessão liga o perfil quando o jogo abre e desfaz quando fecha (`matsu-jogos.service`, 16 testes). Anti-Lag, Boost e nitidez de imagem (vkBasalt) ficam para a próxima etapa. Conferido em prévias no computador; falta o print da máquina virtual e um jogo de verdade
| 🔧 | Sobreposição no jogo | Pedido do criador (11/11/2026). MangoHud com a cara do Matsu (fundo escuro arredondado, letra Inter, as cores do Gerenciador de tarefas), só aparece com jogo aberto, Shift direito + F12 mostra e esconde. Na Central: o que mostrar (FPS, gráfico dos quadros, GPU, CPU, RAM, memória de vídeo, temperaturas, frequências, consumo, hora), canto da tela, tamanho e jeito (completa ou em linha), com prévia ao vivo. Conferido com o MangoHud de verdade num teste Vulkan
| 🔧 | Nome novo: Matsu 27 OS | Pedido do criador (11/11/2026). Kaelix virou Matsu em tudo: nome do sistema, comando `matsu`, apps, ícones, temas, tela de boot, carregamento, instalador e o nome do computador (`matsu`, antes aparecia `fedora`). O nome do Fedora sai do que a pessoa vê (Sobre, fastfetch, menu de boot). Logo nova, o bonsai rosa no ensō (`visual/logo/gerar.py`). O número do ano fica no arquivo `EDICAO`. O repositório no GitHub continua `Kaelix-OS` até o criador renomear; as imagens agora são `matsu-os` e `matsu-os-nvidia` (públicas no ghcr.io). Conferido nos prints da máquina virtual (boot, carregamento, Sobre e fastfetch); falta o retorno do criador |
| 🔧 | Terminal do Matsu | Pedido do criador (11/11/2026). App próprio (`matsu-terminal`, em `build_files/deco/terminal`): janela de vidro neutro com as bolinhas, abas em pílula com a cor de cada uma (arrastar muda de lugar, botão do meio fecha, bolinha quando um programa termina em segundo plano), tela dividida, menu de vidro, e embaixo a pasta (clicar abre nos Arquivos), o ramo do git com as mudanças, o programa rodando e o tamanho do terminal. Tema claro e escuro acompanham o sistema. Dentro roda o terminal do Konsole (a peça konsolepart), que já cuida de cores, busca e atalhos; o Konsole sai do menu. Vira o terminal padrão (Ctrl+Alt+T, barra, "Abrir terminal aqui"). Cores e perfis em `visual/terminal/gerar.py`. Em 11/11/2026 o Kaiky escolheu este visual ("Pílulas") entre três; versão oficial com o tracinho colorido embaixo da aba aberta, o símbolo da aba mudando com o programa (gráfico no htop, servidor no ssh, lápis nos editores, ramo no git), a barra de baixo por extenso ("2 mudanças", "↑1 para enviar") e o prompt novo (`/etc/profile.d/zz-matsu-prompt.sh`: pasta, ramo com * e a setinha que fica vermelha no erro). Conferido num teste com o KDE 6 de verdade; falta o print da máquina virtual |
| 💬 | Loja do Matsu | Pedido do criador (11/11/2026): app próprio parecido com a Microsoft Store, com fotos de cada app, ligado num catálogo só dele (só ele publica; quem quiser publicar manda e-mail). Proposta: repositório próprio assinado já ligado no sistema (o que ele publica aparece sozinho em todos os computadores), Flathub junto com destaques escolhidos por ele, Instagram, TikTok e YouTube como apps da web e apps pagos numa segunda fase |

## Seção 6: o que provavelmente faltou pedir

Em 10/11/2026 o criador autorizou colocar por conta própria o que um sistema operacional precisa e ele
esqueceu de pedir. O que entrar é avisado a ele e marcado aqui. Escolhas de gosto continuam com ele.

### Hardware e uso diário

| | Item | Observação |
|---|---|---|
| 🔧 | Teclado ABNT2, português do Brasil e fuso de Brasília já marcados no instalador | O sistema já nasce em português do Brasil, com o horário de Brasília (provado na máquina virtual em 10/11/2026). O instalador agora já abre em português, com o teclado ABNT2 e o horário de Brasília marcados (dá para trocar ali mesmo). Arquivo `installer/matsu.ks.in`, conferido pelo `ksvalidator` do Fedora 44. Falta ver na tela do instalador |
| 💬 | Duas telas: posição, taxa de atualização, VRR/FreeSync e HDR | O KDE já tem. Falta testar no PC do criador |
| 🔧 | Escolha de telas com Meta+P: estender, duplicar, só a tela do PC, só a segunda tela | Pedido do criador (10/11/2026). Já vem no KDE, com o mesmo atalho do Windows. Os balões do sistema (menu, bandeja, avisos e esta escolha de telas) ganharam o canto redondo e a borda clara das ilhas (provado na máquina virtual). Falta provar com as duas telas dele |
| 💬 | Controles de Xbox e PlayStation (USB e Bluetooth) | `steam-devices` já entra na imagem. Falta testar; Xbox sem fio pode precisar do `xone` |
| 💬 | Bluetooth, fones, microfone, impressora e scanner | Já vêm na base. Falta testar |
| 🔧 | Perfis de energia visíveis na barra | Entraram na central de controle (Meta+A) e nos Ajustes do Matsu (Energia). Falta o print |
| 💬 | Firmware (BIOS, SSD) pelo `fwupd` | Já vem na base. Entra na central de configurações na Etapa 2 |

| 🔧 | Controle da placa de vídeo (ventoinha, temperatura, desempenho) | Entrou o CoreCtrl (o Fedora não tem o LACT no repositório oficial). Faz o papel do "AMD Software" do Windows. O driver da AMD já vem no sistema. Falta testar na RX 580 |

### Dual boot com o Windows

| | Item | Observação |
|---|---|---|
| 💬 | Relógio certo nos dois sistemas | Recomendado: fazer o Windows usar UTC (um ajuste no registro do Windows) |
| 💬 | Acesso aos discos do Windows (como o disco K:) | Montagem automática com leitura e escrita segura (NTFS) |
| 💬 | Menu de boot bonito com o Windows na lista | Etapa 2 |
| 💬 | Funcionar com Secure Boot ligado | AMD funciona. NVIDIA precisa de chave registrada (MOK) |

### Segurança e privacidade

| | Item | Observação |
|---|---|---|
| 💬 | Firewall ligado por padrão | Já vem ligado no Fedora (firewalld). Falta conferir |
| 💬 | Opção de criptografar o disco na instalação | Já existe no instalador ("Criptografar meus dados") |
| 💬 | Zero telemetria | O Fedora conta máquinas de forma anônima (countme). Dá para desligar |
| 💬 | Atualizações automáticas assinadas | Hoje a pessoa roda `matsu atualizar`. Dá para fazer sozinho em segundo plano |
| 💬 | Pendrive de recuperação com um comando | |

### Para o canal e para o criador

| | Item | Observação |
|---|---|---|
| 🔧 | OBS Studio pronto | Flatpak |
| 💬 | Captura de tela e gravação curta com atalho | O Spectacle do KDE já faz. Falta configurar o atalho |
| 💬 | Discord | Flatpak, se quiser na lista |
| 💬 | Atalhos para GeForce Now e Xbox Cloud Gaming | |
| 💬 | Notas de versão bonitas a cada atualização | |

### Qualidade do sistema

| | Item | Observação |
|---|---|---|
| 💬 | Cópia de segurança dos arquivos com um clique | |
| 💬 | Relatório de erro que abre issue no GitHub (só se a pessoa quiser) | |
| 💬 | Acessibilidade: tamanho de texto, alto contraste, leitor de tela | O KDE já tem. Falta conferir em português |
| ✅ | Teste automático da imagem antes de cada versão (liga e abre a área de trabalho) | Feito: fluxo `Testar e tirar prints` |
| 💬 | Atualizações menores e mais rápidas ("rechunk" da imagem) | Proposta técnica: baixa só o que mudou |
| ✅ | Instalador com o nome e a cara do Matsu | O instalador diz "Matsu OS" no lugar de Fedora, tem a faixa da esquerda com o papel de parede em pixel art e o logo, e o menu de boot da ISO ficou em português ("Instalar o Matsu OS"). Feito por `visual/instalador/gerar.py` e pelo fluxo `Montar ISO`, que também liga a ISO numa máquina virtual e tira prints (ramo `prints-instalador`). Provado nos prints da ISO em 10/11/2026: menu de boot em português, "INSTALAÇÃO DO MATSU OS", teclado ABNT2 e horário de São Paulo já escolhidos. O aviso de disco em vermelho é só porque a pessoa escolhe o disco na hora |
