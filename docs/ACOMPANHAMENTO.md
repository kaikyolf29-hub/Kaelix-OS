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
| 🔧 | Escolha entre Chrome e Brave | `kaelix navegador` funciona. No teste da máquina virtual a pergunta não abriu sozinha no primeiro login: em conferência |
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
| ⬜ | O criador aprovar o vídeo | Só depois disso o tema entra no sistema |
| ⬜ | Servir para PC e para notebook | Pedido do criador: no PC mostra a rede por cabo e esconde a bateria; no notebook mostra Wi-Fi e bateria; com os dois, mostra os dois |
| ⬜ | Tema escuro e claro, nenhum com preto puro | O monitor do criador esmaga o preto |
| ⬜ | Botões de janela nas cores do Kaelix | Rosa (fechar), azul claro (minimizar), verde água (tela cheia) |
| ⬜ | Dock que aumenta os ícones perto do mouse | |
| ⬜ | Central de controle no canto direito | Rede, Bluetooth, modo escuro, som, brilho, perfil de energia |
| ⬜ | Busca de apps e arquivos no canto esquerdo | |
| ⬜ | Assistente de primeiro uso em português e com a cara do Kaelix | Hoje abre o do KDE (Plasma Setup), em inglês, e depois a "Welcome Center" do KDE |
| ⬜ | Logo do Kaelix | O "K" da demonstração é só um marcador. Logo de verdade só com a aprovação do criador |
| ⬜ | Apps próprios: configurações, gerenciador de tarefas, terminal | |

## Seção 6: o que provavelmente faltou pedir

Propostas. Nada aqui entra sem o criador escolher. Algumas já vêm na base e só precisam ser conferidas.

### Hardware e uso diário

| | Item | Observação |
|---|---|---|
| 💬 | Teclado ABNT2, português do Brasil e fuso de Brasília já marcados no instalador | Hoje o instalador pergunta. Dá para deixar pré-marcado |
| 💬 | Duas telas: posição, taxa de atualização, VRR/FreeSync e HDR | O KDE já tem. Falta testar no PC do criador |
| 💬 | Controles de Xbox e PlayStation (USB e Bluetooth) | `steam-devices` já entra na imagem. Falta testar; Xbox sem fio pode precisar do `xone` |
| 💬 | Bluetooth, fones, microfone, impressora e scanner | Já vêm na base. Falta testar |
| 💬 | Perfis de energia visíveis na barra | Já vêm no KDE. Falta conferir |
| 💬 | Firmware (BIOS, SSD) pelo `fwupd` | Já vem na base. Entra na central de configurações na Etapa 2 |

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
| 💬 | Instalador com o nome e a cara do Kaelix | Hoje a tela do instalador ainda diz Fedora. Etapa 2 |
