# Jogos no Matsu OS

O que vem pronto para jogar, o que a Central de jogos faz de verdade e o que ficou de fora (e por quê).
Quem monta a parte dos jogos na imagem é o `build_files/jogos.sh`; a Central de jogos mora em
`system_files/usr/share/matsu/jogos/`.

## Resposta curta

| Pergunta | Resposta |
|---|---|
| O Mesa vem completo? | Sim. O driver livre de AMD, Intel e NVIDIA (NVK), para Vulkan e OpenGL, em 64 e 32 bits. |
| E a NVIDIA? | Tem uma versão do Matsu só para ela (`matsu-os-nvidia`), com o driver oficial. A Central oferece a troca. |
| Vulkan 32 e 64 bits? | Sim, os dois. A página **Drivers** da Central mostra se o de 32 bits está pronto. |
| DXVK e VKD3D? | Vêm dentro do Proton da Steam (não são pacotes do sistema). O Matsu deixa o caminho livre para eles. |
| A Central reconhece a placa e aplica os perfis? | Sim: lê a placa, liga o perfil quando o jogo abre e desfaz quando ele fecha. |
| A sobreposição combina com o Matsu? | Sim: fonte e cores do Matsu, liga e desliga pela Central, pela Central de controle da barra e pelo atalho **Win + Alt + F**. |

## Placa de vídeo e drivers

### AMD e Intel

O driver é o **Mesa**, que já vem no Fedora e é atualizado junto com o Matsu (sempre testado com o resto
do sistema, nada de baixar driver de site). O `jogos.sh` garante as peças que os jogos usam:

- `mesa-vulkan-drivers` e `mesa-vulkan-drivers.i686`: o Vulkan da AMD (RADV), da Intel (ANV) e o NVK;
- `mesa-dri-drivers`, `mesa-libGL` e `mesa-libEGL`, com as versões `.i686`: o OpenGL;
- `vulkan-loader` e `vulkan-loader.i686`: a peça que liga o jogo ao driver Vulkan;
- `vulkan-tools` (`vulkaninfo`) e `glx-utils` (`glxinfo`): é com eles que a Central lê as versões.

Tudo é instalado com `--skip-unavailable`, e o registro da montagem mostra a versão de cada pacote e avisa
se faltar o Vulkan de 32 bits ou a camada do MangoHud.

### NVIDIA

São duas versões do Matsu, as duas assinadas (a política do `build.sh` aceita `matsu-os` e `matsu-os-nvidia`):

- **`matsu-os`** (comum): para AMD e Intel. Uma placa NVIDIA funciona com o driver livre (nouveau + NVK),
  mas fica bem mais lenta nos jogos.
- **`matsu-os-nvidia`**: igual, mais o driver oficial da NVIDIA (vem da base da Universal Blue).

Na página **Drivers** da Central:

- com placa NVIDIA na versão comum, aparece **Instalar o driver da NVIDIA**. Ela explica que a versão nova
  é baixada inteira (no mesmo canal, por exemplo `estavel`), pede a senha, mostra o andamento e, no fim,
  oferece **Reiniciar agora**. Arquivos, apps e ajustes ficam como estão;
- placas anteriores às GTX 16 e RTX 20 ganham um aviso: o driver novo da NVIDIA pode não funcionar nelas;
- na versão NVIDIA sem placa NVIDIA, aparece a volta para a versão comum. E mesmo com a placa, sempre tem o
  botão **Voltar para a comum** (caso o driver dê problema).

Por baixo é o mesmo comando do `matsu drivers --trocar`:
`pkexec bootc switch --enforce-container-sigpolicy <registro>/matsu-os-nvidia:<canal>` (com a assinatura
conferida). Na montagem da versão NVIDIA, o `jogos.sh` registra se as bibliotecas de 32 bits da NVIDIA
vieram (`libGLX_nvidia.so.0` em `/usr/lib`): sem elas, jogos de 32 bits não abrem.

### Notebooks com duas placas

A página **Drivers** mostra cada placa separada (a integrada e a dedicada), com o driver em uso, a versão e
o Vulkan de cada uma.

## Jogos do Windows: Proton, DXVK e VKD3D

- **Proton** vem com a Steam (pacote `steam` do RPM Fusion, já no Matsu). Dentro dele estão o **DXVK**
  (DirectX 9, 10 e 11 → Vulkan) e o **VKD3D-Proton** (DirectX 12 → Vulkan). Eles atualizam com a Steam,
  não com o sistema. O que o Matsu precisa é ter o Vulkan certo, em 64 e 32 bits: isso ele tem.
- **RADV com GPL**: o Vulkan da AMD no Mesa já monta os efeitos aos pedaços (graphics pipeline library), o
  que corta a maior parte das travadinhas de "compilando shader". Não precisa ligar nada.
- **Cache de shader maior**: o jogo compila cada efeito uma vez e guarda. O Matsu aumenta esse cache para
  10 GB (`MESA_SHADER_CACHE_MAX_SIZE=10G`; na NVIDIA, `__GL_SHADER_DISK_CACHE_SIZE` e
  `__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1`), em `usr/lib/environment.d/60-matsu-jogos.conf`. Com o cache
  pequeno, o jogo joga fora o que compilou e volta a travar.
- **Pré-cache de shaders da Steam**: a Steam baixa shaders já compilados para a sua placa. Vem ligado; fica
  nas configurações da Steam, em Downloads.
- **ntsync**: o jeito novo (do kernel) de o Wine imitar a sincronização do Windows, mais rápido em vários
  jogos. O Matsu carrega o módulo `ntsync` no boot (`usr/lib/modules-load.d/matsu-jogos-ntsync.conf`) e
  deixa os jogos usarem `/dev/ntsync` (`usr/lib/udev/rules.d/70-matsu-jogos-ntsync.rules`). O GE-Proton usa
  sozinho quando ele existe; no Proton da Valve depende da versão. Se o kernel da imagem não tiver o módulo,
  o `jogos.sh` avisa e tira o arquivo, para não dar erro no boot.

## O que a Central de jogos faz (de verdade)

Os perfis (**Padrão**, **Desempenho**, **Qualidade**, **Economia** e **Personalizado**) ligam sozinhos
quando um jogo da Steam ou do Windows (Heroic, Lutris) abre, e tudo volta ao normal quando ele fecha.
Quem faz isso é o serviço `matsu-jogos` (o `ajudante.py`, rodando na sessão da pessoa).

| Ajuste | Como é feito | Quando vale |
|---|---|---|
| Energia | Perfil de energia do sistema (power-profiles), pelo D-Bus | Na hora |
| Placa de vídeo (só AMD) | Nível da placa (`power_dpm_force_performance_level`) pelo `matsu-jogos-placa`, com permissão do polkit | Na hora; se você ajustou à mão no LACT/CoreCtrl, a Central não mexe, e no fim devolve o nível que estava |
| Limite de FPS | MangoHud (`fps_limit`) | Na hora, até com o jogo aberto |
| V-Sync | MangoHud (`vsync`) | Quando o jogo abre |
| Texturas nítidas | MangoHud (`af`, filtro anisotrópico) | Quando o jogo abre |
| Baixa latência | DXVK (`dxgi.maxFrameLatency = 1` e `d3d9.maxFrameLatency = 1`) e, com limite de FPS, o limitador "early" do MangoHud | Quando o jogo abre; só DirectX 9, 10 e 11 pelo Proton |
| Modo jogo | GameMode (`RegisterGame` pelo D-Bus) | Na hora |

O perfil **Desempenho** liga a Baixa latência; o **Economia** limita a 60 FPS e usa energia econômica, mas
deixa a placa na automática (travar a placa na velocidade mais baixa deixava jogos pesados ruins).

Na NVIDIA e na Intel, o próprio driver cuida da velocidade da placa: a opção aparece apagada, explicando.

### Sobreposição (FPS no jogo)

- É o **MangoHud**, que já vem no Matsu e fica carregado nos jogos Vulkan (quase todos, inclusive os do
  Windows pelo Proton), mas escondido. A Central mostra só enquanto um jogo está aberto.
- Liga e desliga em três lugares, sempre juntos (o mesmo arquivo `~/.config/matsu/jogos.json`, e o MangoHud
  relê a configuração sozinho):
  - a chave grande no topo da página **Sobreposição**;
  - o botão **FPS no jogo** na Central de controle da barra;
  - o atalho **Win + Alt + F** (registrado no KDE pelo `jogos.sh`; o Meta+G já é do Plasma).
- As teclas próprias do MangoHud ficam desligadas, para nada sair de sincronia (e para nenhum atalho mandar
  dados para fora sem querer).
- O visual é o do Matsu: fonte Inter, cantos redondos, vidro escuro e as cores de cada parte (CPU, GPU,
  memória). Nunca fica clara, porque por cima do jogo uma caixa clara atrapalharia.
- **Fundo**: **Escuro** (o vidro, padrão), **Leve** (mais transparente) ou **Transparente** (só os números,
  sem caixa, para não tapar o jogo). Sem o vidro escuro, as letras ganham um contorno preto
  (`text_outline`) para dar para ler numa cena clara.
- A linha da placa e a do processador começam com **GPU uso** e **CPU uso**: o primeiro número é o uso (%),
  e os outros (°C, MHz, W, RPM) já se explicam pela unidade.
- Em pé, como uma tela de celular, em três blocos com um respiro entre eles: o FPS (com o tempo do quadro,
  o FPS médio, o 1% mais baixo e o gráfico), a placa (nome, uso, temperatura, ventoinha, frequência,
  consumo e a memória de vídeo) e o processador (nome, uso, temperatura, frequência, consumo e a memória).
  A página tem três jeitos prontos (**Só o FPS**, **Essencial** e **Tudo**) e cada item pode ser ligado e
  desligado. **Em linha** põe tudo numa linha só, discreta.
- **DirectX ou Vulkan**: no lugar de "FPS" aparece a tecnologia de imagem que o jogo usa (DX12, DX11, DX9,
  VULKAN, OpenGL), não a placa. Fica desligado até no **Tudo**, porque confundia (num teste com um programa
  Vulkan, aparecia "VULKAN" no lugar do FPS).
- Os nomes do processador e da placa são lidos do computador pela Central (o da placa sem o "(RADV ...)"
  que o MangoHud mostraria). Com duas placas (a integrada e a de jogo), a sobreposição mostra só a de jogo
  (`pci_dev`).
- **Consumo do processador**: o MangoHud lê da RAPL do kernel, que desde 2020 só o administrador lê (por
  segurança, contra o ataque PLATYPUS). O Matsu não abre essa porta: quando o número não dá para ler, a
  sobreposição não mostra (em vez de "0 W" parado) e a página explica. O consumo da placa aparece sempre.
- Alguns rótulos são do próprio MangoHud e ficam como ele escreve: **AVG** (média), **1%** e **Frametime**.
- As opções usadas são as do MangoHud 0.8.3 do Fedora 44 (o teste confere a lista). A prévia da sobreposição
  de verdade pode ser feita num contêiner com o MangoHud do Ubuntu e Vulkan por software (sem placa de vídeo,
  com um `/sys` de mentira para a placa e o processador).

### Controles

A página **Controles** mostra os controles de PlayStation (DualShock 4, DualSense), Xbox, Nintendo e outros,
pelo Bluetooth e pelo cabo, com nome de gente, se está conectado e a bateria. Dá para:

- **parear** passo a passo (PS5: Create + PS; PS4: Share + PS; Xbox: o botão de parear), com o tempo da busca
  num anel e cada etapa marcada; se o Bluetooth estiver desligado, a Central liga;
- **desconectar**, **conectar** e **esquecer**;
- **testar** os botões, os gatilhos e os direcionais ao vivo, num controle desenhado.

O `jogos.sh` deixa o Bluetooth pronto para controles: `FastConnectable`, `JustWorksRepairing = always` e
reconexão automática em `/etc/bluetooth/main.conf`, mais as regras `game-devices-udev` (e as `steam-devices`
da Steam). Ele também registra se a base trouxe `xpadneo`/`xone` (drivers extras do Xbox), sem compilar nada.

## O que ficou de fora (e por quê)

- **Anti-Lag da AMD como opção**: o driver da AMD ganha o Anti-Lag (`VK_AMD_anti_lag`) no Mesa 26.3, e o
  VKD3D-Proton usa sozinho quando o driver tem. Não há nada para ligar no sistema, então a Central só
  **mostra** se o seu driver já tem (página Drivers). Até lá, a opção Baixa latência ajuda nos jogos DirectX 9 a 11.
- **Nitidez (vkBasalt, CAS)**: só funciona ligando jogo por jogo (`ENABLE_VKBASALT=1`), e ligar para todos
  quebraria jogos e apps. Como a Central não tem como ligar só num jogo sem mexer nas opções de cada um na
  Steam, ficou de fora. Muitos jogos já têm FSR/nitidez no próprio menu.
- **Sobreposição em jogos OpenGL nativos**: o MangoHud só entra sozinho nos jogos Vulkan. Nos OpenGL (nativos
  mais antigos), é preciso pôr `mangohud %command%` nas opções de inicialização do jogo na Steam. A página
  Sobreposição explica e tem o botão de copiar.
- **Sobreposição e Baixa latência no Heroic e no Lutris (Flatpak)**: o perfil liga (energia, placa, modo
  jogo), mas o MangoHud de dentro do Flatpak precisa da extensão `org.freedesktop.Platform.VulkanLayer.MangoHud`
  da mesma versão do runtime, e o arquivo do DXVK fica em `~/.config/matsu/jogos/`, que o app precisa
  conseguir ler.
- **Placa NVIDIA e Intel com nível de velocidade**: o driver delas não tem esse ajuste aberto como o da AMD.

## Como conferir num computador de verdade

- `vulkaninfo --summary`: o Vulkan e a placa (o mesmo que a página Drivers mostra).
- `ls /dev/ntsync`: o ntsync carregado.
- `cat ~/.config/MangoHud/MangoHud.conf`: o que a Central escreveu (com um jogo aberto, `fps_limit`, `vsync` e `af`).
- `cat ~/.config/matsu/jogos/dxvk.conf`: as linhas da Baixa latência (vazio quando está desligada).
- `python3 /usr/share/matsu/jogos/ajudante.py drivers --agora`: tudo o que a página Drivers lê, em JSON.
- `python3 /usr/share/matsu/jogos/ajudante.py controles`: os controles que a página Controles vê.
