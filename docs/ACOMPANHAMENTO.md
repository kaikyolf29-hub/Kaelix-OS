# Lista de acompanhamento

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
| ✅ | Repositório público `kaelix-os`, licença GPL-3.0 | Criado em 09/11/2026 |
| ✅ | Plano salvo em `docs/PLANO.md` | |
| ✅ | Chave de assinatura cosign criada no pendrive do criador | Pública em `cosign.pub`. Ver `docs/CHAVES.md` |
| ✅ | Chave privada e senha nos segredos do GitHub | Provado: a montagem 20261110.6 saiu assinada e conferida |
| ✅ | Chave guardada no pendrive (nasceu nele, nunca ficou solta no PC) | |
| ⬜ | Verificação em duas etapas na conta do GitHub | Passo do criador |
| ✅ | `Containerfile` em cima do Fedora Atomic KDE (Fedora 44) | Base `ublue-os/kinoite-main`. Monta sem erro no GitHub (montagem 20261110.6) |
| 🔧 | Steam (com Proton), GameMode e MangoHud | Pacotes RPM na imagem |
| 🔧 | Heroic e Lutris | Flatpak, instalados no primeiro boot com internet |
| 🔧 | Flathub ligado | Serviço `kaelix-flatpak-setup` |
| 🔧 | Escolha entre Chrome e Brave | A pergunta abre sozinha no primeiro login (provado na máquina virtual) e também por `kaelix navegador`. Falta provar a instalação do navegador escolhido |
| 🔧 | Ferramentas de programação, VS Code e Distrobox | |
| 🔧 | OBS Studio e Kdenlive | Flatpak |
| ✅ | GitHub Actions monta, assina com cosign e publica em `ghcr.io` | `ghcr.io/kaikyolf29-hub/kaelix-os:teste`, assinatura conferida no próprio fluxo |
| 🔧 | Variante NVIDIA | `ghcr.io/kaikyolf29-hub/kaelix-os-nvidia:teste` montada e assinada. Falta testar numa placa NVIDIA |
| 🔧 | ISO de instalação | Montada pelo fluxo `Montar ISO` (instalador de rede, 1,2 GB, AMD e NVIDIA). Falta instalar de verdade |
| 🔧 | Publicar como Release | Fluxo `Publicar versão estável`. Só roda quando o criador manda |
| ✅ | Comandos `kaelix atualizar`, `voltar`, `drivers`, `seguranca` (e `navegador`, `versao`) | 30 testes automáticos passando |
| ✅ | Imagens públicas no ghcr.io | Já ficaram públicas sozinhas (herdaram do repositório) |
| ✅ | Testar na máquina virtual | Automático no GitHub (fluxo `Testar e tirar prints`): liga, entra na área de trabalho, abre o terminal e roda `kaelix`. Prints no ramo `prints` |
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
| ✅ | Tema escuro e claro, nenhum com preto puro | Cores `KaelixEscuro` e `KaelixClaro` e temas globais `org.kaelix.escuro.desktop` e `org.kaelix.claro.desktop`. Provado na máquina virtual em 10/11/2026 |
| ✅ | Barra em três ilhas (a fusão) como padrão | Feita pelo arranjo do tema global, com cantos redondos, borda clara e destaque redondo do app aberto (tema Plasma `Kaelix`, gerado por `system_files/usr/share/kaelix/vidro/gerar.py`). Provada na máquina virtual em 10/11/2026. O desfoque de vidro só dá para ver no PC de verdade, porque a máquina virtual não tem placa de vídeo |
| ✅ | Papel de parede próprio em pixel art | Pedido do criador: fundo bonito de verdade. Pôr do sol no lago, feito por código (`visual/papel-de-parede/gerar.py`), versão escura e clara. Provado na máquina virtual em 10/11/2026 |
| ✅ | Personalizar a barra | Pedido do criador. Três estilos: "Fusão" (padrão), "Mac" (barra fina no topo e doca) e "Windows" (uma barra só embaixo), em três tamanhos. Pelo menu ("Estilo da barra") ou pelo comando `kaelix barra`. Mantém os apps fixados. Provado na máquina virtual em 10/11/2026. Agora também fica nos Ajustes do Kaelix (página Barra), com a opção de esconder a barra sozinha (`kaelix barra --esconder sim`) |
| 🔧 | Ícones próprios para os apps da barra | Pedido do criador: bem personalizados e bonitos. Primeira leva: Arquivos, Terminal, Loja, Monitor, Configurações, Editor de texto, Capturas e Imagens (`visual/icones/gerar.js`, tema de ícones `Kaelix`). Programas de outras marcas (Steam, navegador) ficam com o ícone deles. Provados na máquina virtual em 10/11/2026. Falta a opinião do criador |
| ✅ | Botões de janela nas cores do Kaelix | Rosa (fechar), azul claro (minimizar), verde água (tela cheia), do lado esquerdo. Feitos em cima da moldura do KDE (`build_files/deco/`). Provados na máquina virtual em 10/11/2026 |
| 💬 | Dock que aumenta os ícones perto do mouse | A barra do KDE não tem esse efeito. Só com uma doca própria, num app à parte. Fica para depois, se o criador quiser |
| 🔧 | Central de controle no canto direito | Feita, na ilha da direita e no atalho Meta+A: rede (Wi-Fi no notebook, cabo no PC), Bluetooth, não perturbe, tema escuro, luz noturna, estilo da barra, volume, brilho e bateria (só aparecem onde existem), configurações, bloquear e desligar. Na máquina virtual ela carregou na ilha e leu o sistema certo; falta o print dela aberta. Ganhou o perfil de energia (economia, equilibrado, desempenho) |
| ✅ | Busca de apps e arquivos no canto esquerdo | Pílula "Buscar" na ilha da esquerda (`org.kaelix.busca`), abre a busca do sistema. Provada na máquina virtual em 10/11/2026 |
| 🔧 | Assistente de primeiro uso em português e com a cara do Kaelix | A tela de boas-vindas ganhou o logo, o texto do Kaelix e três telas próprias (tema e barra, navegador, comando `kaelix`), provado na máquina virtual em 10/11/2026. Falta o assistente de criar a conta (Plasma Setup), que ainda é o do KDE |
| ✅ | Logo do Kaelix | O criador escolheu o caminho "Asas" e aprovou a versão refinada em 10/11/2026: um K com três penas, branco em fundo índigo escuro. Fonte em `visual/logo/`. Já é o botão do menu, o logo do sistema (provado na máquina virtual), a tela de boot e o instalador (falta o print desses dois) |
| ✅ | Tela de login, tela de bloqueio e tela de carregamento com a cara do Kaelix | Login e bloqueio usam o papel de parede em pixel art; depois da senha aparece o emblema Asas em fundo índigo, no lugar do logo do KDE. Provado na máquina virtual em 10/11/2026 |
| 🔧 | Vidro com cor e transparência à escolha | Pedido do criador (10/11/2026): o vidro das ilhas, menus e balões pode ser incolor (padrão) ou azul, roxo, rosa, vermelho, laranja, amarelo, verde, grafite ou qualquer cor, com três níveis de transparência. Nos Ajustes do Kaelix (Aparência) ou por `kaelix vidro roxo --transparencia mais`. Conferido no computador; falta o print da máquina virtual |
| 🔧 | Ajustes do Kaelix (como os Ajustes do Sistema do Mac) | App próprio de configurações com barra lateral e busca: Aparência, Barra (estilo Mac, Fusão ou Windows, tamanho, esconder sozinha), Papel de parede, Telas, Som, Rede, Bluetooth, Notificações, Energia, Sobre e "Mais ajustes". Abre pela engrenagem da central e fica fixado na barra. Falta o print da máquina virtual |
| 🔧 | Terminal e Arquivos no estilo do vídeo | Terminal com fundo de vidro (escuro ou claro, segue o tema), fonte JetBrains Mono, sem barra de menu e com o prompt do vídeo. Arquivos abre em lista com data, tipo e tamanho. Falta o print da máquina virtual |
| 🔧 | Lixeira própria | Ícone próprio (vazia e cheia) e lixeira no fim da ilha do meio (fusão) e da doca (estilo Mac). Falta o print da máquina virtual |
| 🔧 | Ilha da direita e relógio como no vídeo | Pílula com rede, som e bateria, relógio com data e balão da central. Esperando os prints da máquina virtual |
| 🔧 | Ícones de apps na bandeja, como no Windows | O KDE (não é GNOME) já fala os dois jeitos: StatusNotifierItem/AppIndicator e o XEmbed antigo (pelo `xembedsniproxy`). Clique abre o app, botão direito abre o menu, segue o tema claro/escuro e os ícones extras ficam na setinha "mostrar mais". Teste com um app de bandeja de verdade na máquina virtual; como validar numa máquina de verdade está em `docs/COMO-TESTAR.md` ("Bandeja perto do relógio") |
| 🔧 | Papel de parede animado (Wallpaper Engine da Steam) | Pedido do criador. O app Waywallen vem do Flathub no primeiro boot e a peça dele para o KDE vem na imagem; ele roda os papéis do Wallpaper Engine que a pessoa tem na Steam (precisa ter o Wallpaper Engine comprado e baixado na Steam). Ligar em Ajustes do Kaelix > Papel de parede. Falta o criador testar no PC dele |
| 🔧 | Tela de boot com o logo do Kaelix | No lugar do logo do Fedora: o emblema Asas no fundo índigo, o nome e três pontos pulsando, igual à tela depois da senha, para ligar, entrar e carregar parecerem uma coisa só. Também a caixa da senha do disco (se ele for criptografado) e a tela de atualização em português. Tema do Plymouth feito por `visual/boot/gerar.py`. Conferido no computador nas telas 1920x1080 e 1366x768; falta o print da máquina virtual |
| 🔧 | Apps próprios: configurações, gerenciador de tarefas, terminal | Configurações: feito (Ajustes do Kaelix). Terminal: o Konsole com a cara do Kaelix. Falta o gerenciador de tarefas |

## Seção 6: o que provavelmente faltou pedir

Em 10/11/2026 o criador autorizou colocar por conta própria o que um sistema operacional precisa e ele
esqueceu de pedir. O que entrar é avisado a ele e marcado aqui. Escolhas de gosto continuam com ele.

### Hardware e uso diário

| | Item | Observação |
|---|---|---|
| 🔧 | Teclado ABNT2, português do Brasil e fuso de Brasília já marcados no instalador | O sistema já nasce em português do Brasil, com o horário de Brasília (provado na máquina virtual em 10/11/2026). O instalador agora já abre em português, com o teclado ABNT2 e o horário de Brasília marcados (dá para trocar ali mesmo). Arquivo `installer/kaelix.ks.in`, conferido pelo `ksvalidator` do Fedora 44. Falta ver na tela do instalador |
| 💬 | Duas telas: posição, taxa de atualização, VRR/FreeSync e HDR | O KDE já tem. Falta testar no PC do criador |
| 🔧 | Escolha de telas com Meta+P: estender, duplicar, só a tela do PC, só a segunda tela | Pedido do criador (10/11/2026). Já vem no KDE, com o mesmo atalho do Windows. Os balões do sistema (menu, bandeja, avisos e esta escolha de telas) ganharam o canto redondo e a borda clara das ilhas (provado na máquina virtual). Falta provar com as duas telas dele |
| 💬 | Controles de Xbox e PlayStation (USB e Bluetooth) | `steam-devices` já entra na imagem. Falta testar; Xbox sem fio pode precisar do `xone` |
| 💬 | Bluetooth, fones, microfone, impressora e scanner | Já vêm na base. Falta testar |
| 🔧 | Perfis de energia visíveis na barra | Entraram na central de controle (Meta+A) e nos Ajustes do Kaelix (Energia). Falta o print |
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
| 💬 | Atualizações automáticas assinadas | Hoje a pessoa roda `kaelix atualizar`. Dá para fazer sozinho em segundo plano |
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
| 🔧 | Instalador com o nome e a cara do Kaelix | O instalador diz "Kaelix OS" no lugar de Fedora, tem a faixa da esquerda com o papel de parede em pixel art e o logo, e o menu de boot da ISO ficou em português ("Instalar o Kaelix OS"). Feito por `visual/instalador/gerar.py` e pelo fluxo `Montar ISO`, que agora também liga a ISO numa máquina virtual e tira prints (ramo `prints-instalador`). Falta conferir os prints |
