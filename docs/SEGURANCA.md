# Central de segurança do Matsu

A Central de segurança (app **Segurança**, `org.matsu.seguranca`) junta num lugar
só o que protege o computador: o antivírus em tempo real, o aviso de arquivo
baixado, o firewall, as permissões dos apps da Loja e a integridade do sistema.
A ideia é a mesma da Segurança do Windows, mas com o jeito do Matsu e só com o
que é tecnicamente certo no Fedora.

## Como as peças se juntam

```
Janela (Main.qml)  Aviso (Aviso.qml)  Bandeja (plasmoide)
        \                |                 /
         ajudante.py  (sempre como a pessoa, responde em JSON)
        /      |          |            \
 escudo.py   systemd   firewalld /    flatpak
 (serviço    (polkit)  NetworkManager  (na conta
  da pessoa)            (polkit)        da pessoa)
```

- **As janelas só desenham.** Quem lê e muda as coisas é
  `/usr/share/matsu/seguranca/ajudante.py`, sempre como a própria pessoa (nunca root).
  Ele usa só a biblioteca padrão do Python.
- **Não há programa novo rodando como root.** O que precisa de root passa pelo que já
  existe: o systemd (para ligar o motor do antivírus), o firewalld e o NetworkManager
  (pelo D-Bus, com a senha de administrador quando a regra pede) e o `pkexec` (só para
  conferir os arquivos do sistema).
- **`matsu-escudo.service`** é um serviço da sessão de cada pessoa
  (`systemctl --user`). Ele vigia as pastas e os pendrives e grava o estado em
  `$XDG_RUNTIME_DIR/matsu-seguranca/escudo.json`.

Os arquivos ficam assim:

| O quê | Onde |
|---|---|
| App, aviso, ajudante, escudo | `/usr/share/matsu/seguranca/` |
| Entrada do menu e tratador dos executáveis | `/usr/share/applications/org.matsu.seguranca*.desktop` |
| Ícone da bandeja | `/usr/share/plasma/plasmoids/org.matsu.seguranca/` |
| Serviços | `/usr/lib/systemd/{user,system}/matsu-escudo*` |
| Regras do polkit | `/usr/share/polkit-1/{actions,rules.d}/*seguranca*` |
| Zonas do firewall | `/usr/lib/firewalld/zones/matsu-*.xml` |
| Atalhos de terminal | `/usr/libexec/matsu/matsu-seguranca`, `matsu-seguranca-fsck` |
| Montagem da imagem | `build_files/seguranca.sh` |
| Dados da pessoa | `~/.local/share/matsu/seguranca/` (histórico, quarentena, exceções) e `~/.config/matsu/seguranca.json` (ajustes) |

## 1. O escudo (antivírus)

O antivírus é o **ClamAV** do Fedora (pacotes `clamav`, `clamd` e `clamav-update`, que no Fedora 44 se chama `clamav-freshclam`).

- **A lista de ameaças não vem na imagem.** São uns 230 MB. Ela é baixada no
  primeiro uso com internet e depois atualizada a cada 4 horas
  (`matsu-escudo-atualizar.timer`). Depois da primeira vez, só chegam as novidades.
  Enquanto ela chega, a Central mostra "Baixando a lista de ameaças…" com o quanto
  já veio (o systemd conta os bytes do download com `IPAccounting`).
- **O motor (clamd) só liga quando precisa.** Ele gasta perto de 1 GB de memória com
  a lista carregada. Por isso o Matsu tem uma unidade própria,
  `matsu-escudo-clamd.service`, que sobe quando chega um arquivo para conferir e é
  desligada depois de 10 minutos sem uso. Ela roda com um usuário criado na hora
  (`DynamicUser`), sem rede, sem acesso à pasta pessoal e com prioridade baixa. O
  arquivo chega até ela pelo próprio descritor, que o escudo abre como a pessoa.
  Se o SELinux não deixar, o arquivo vai pelo fluxo (INSTREAM).
- **Ligar o motor não pede senha.** Uma regra do polkit (`50-matsu-seguranca.rules`)
  deixa quem está sentado no computador (sessão local e ativa) ligar e desligar só
  estas duas unidades. Pedir a senha de administrador cada vez que um arquivo
  chegasse tornaria o escudo inútil. A regra não pede `wheel`, porque uma conta comum
  também precisa de antivírus.
- **O que é vigiado:** Downloads e a Área de trabalho, com os nomes de verdade das
  pastas (os do `user-dirs`), até dois níveis abaixo. Downloads pela metade
  (`.part`, `.crdownload`, `.tmp`) ficam de fora até terminar. O escudo espera o
  arquivo parar de crescer por 2 segundos antes de conferir.
- **Pendrives:** quando um pendrive é montado em `/run/media/<pessoa>/`, o Matsu
  pergunta "Verificar o pendrive?". Nos ajustes dá para verificar sozinho.
- **Jogos:** com um jogo aberto (pela Central de jogos), os arquivos novos esperam na
  fila. A Steam e as pastas de jogos nunca são conferidas.
- **`/tmp` fica de fora.** É onde os programas guardam rascunhos que somem sozinhos,
  e vigiar ali pesaria muito. O que sai de lá para os Downloads é conferido.
- **Pausar:** por 15 minutos, por 1 hora ou até reiniciar. O escudo volta sozinho e
  avisa ("O escudo voltou"). Os arquivos que chegam durante a pausa ficam guardados
  e são conferidos na volta. Desligar de vez pede confirmação e sugere a pausa.
- **Quarentena:** a ameaça vai para `~/.local/share/matsu/seguranca/quarentena`,
  embaralhada (cada byte trocado), sem permissão de rodar, numa pasta que só a
  pessoa abre, com um registro de onde veio. Na Central dá para restaurar (com
  confirmação, e então o arquivo não é mais acusado) ou apagar de vez.
- **Verificações manuais:** rápida (Downloads, Área de trabalho, o que abre sozinho
  e os programas da pasta pessoal), completa (a pasta pessoal e os pendrives, menos
  jogos e caches) ou uma pasta ou arquivo escolhido. Cada uma mostra o anel com a
  porcentagem e os números, pode ser cancelada e termina com um resultado claro.

### O que o escudo não faz (e por quê)

Ele **não intercepta cada programa que abre**. Isso precisaria do `fanotify` com
permissão de bloqueio (o `clamonacc`), que roda como root, deixa cada arquivo aberto
mais lento (jogos sofrem muito) e pode travar o sistema se o motor parar. No Matsu a
proteção vem em camadas:

1. o sistema só pode ser lido e vem assinado (ver Integridade);
2. os apps da Loja ficam em caixas de areia;
3. o que chega de fora (downloads, pendrives) é conferido;
4. o aviso abaixo segura o primeiro clique num programa baixado.

## 2. O aviso de arquivo baixado

É o "SmartScreen" do Matsu. O tratador `org.matsu.seguranca.aviso.desktop`
(`matsu-seguranca abrir %f`) é chamado quando a pessoa abre um programa: AppImage,
programa do Linux, programa do Windows (`.exe`, `.msi`), `.run`, `.jar`, `.deb` ou
`.rpm`.

Por onde ele é chamado:

- **Navegador** (abrir o download): o navegador abre pelo GIO ou pelo portal, que
  seguem o app padrão do tipo de arquivo, e o padrão desses tipos é o tratador.
- **Arquivos** (dois cliques): o KIO perguntaria "Executar?" e rodaria o programa
  sem olhar de onde veio. O Matsu grava `behaviourOnLaunch=open` em
  `/etc/xdg/kiorc` (grupo `Executable scripts`), então o arquivo vai para o app do
  tipo dele: programas para o tratador (que abre direto o que não veio da internet),
  scripts para o Bloco de notas.
- **`xdg-open` no terminal**: no KDE ele chama o `kioclient`, que recusa qualquer
  executável ("não é permitido iniciar executáveis neste contexto") antes de olhar
  o app padrão. Para testar pelo terminal, use `gio open arquivo`.

- Se o arquivo **veio da internet** e não está na lista de liberados, a janela
  `Aviso.qml` abre. Saber que veio da internet usa a marca que o navegador grava
  (`user.xdg.origin.url`) ou o fato de estar em Downloads. A janela mostra o nome,
  o site, a assinatura digital, o SHA-256 e o que o escudo achou.
- O botão principal é o mais seguro: **Não abrir**. Também dá para **Mover para a
  quarentena**.
- **Abrir mesmo assim** fica em "Mais informações" e pede a senha da própria pessoa
  (`pkcheck`, ação `org.matsu.seguranca.liberar`, `auth_self`). Não é a senha de
  administrador, e o objetivo é fazer a pessoa parar e pensar. Depois o arquivo
  entra na lista de liberados (pelo SHA-256) e abre do jeito esperado:
  - AppImage e programa do Linux ganham permissão de rodar e abrem;
  - `.sh` e `.run` abrem no Terminal do Matsu;
  - programa do Windows abre no Bottles (ou no Wine). Sem nenhum dos dois, o aviso
    oferece instalar o Bottles na Loja;
  - `.deb` e `.rpm` não instalam: o aviso explica que os apps vêm da Loja.
- Se o escudo achar uma ameaça, não existe "Abrir mesmo assim": só a quarentena.
- **Script feito pela própria pessoa** (que não veio da internet) abre no editor,
  como sempre. O tratador **não** é o padrão de `application/x-shellscript`, para
  não atrapalhar quem programa.

Tipos que devem ter o tratador como padrão no `mimeapps.list` do sistema:
`application/vnd.appimage`, `application/x-iso9660-appimage`,
`application/x-executable`, `application/x-sharedlib`, `application/x-msdownload`,
`application/vnd.microsoft.portable-executable`, `application/x-ms-dos-executable`,
`application/x-dosexec`, `application/x-ms-ne-executable`, `application/x-msi`,
`application/vnd.debian.binary-package`, `application/x-rpm`,
`application/java-archive`, `application/x-makeself`.

## 3. Rede e firewall

O Fedora já usa o **firewalld** (com nftables por baixo). O UFW, sugerido em muitos
guias, brigaria com ele, por isso não entra.

- O Matsu tem duas zonas próprias:
  - **`matsu-publica`** ("Rede pública"): só o necessário para o IPv6 funcionar
    (`dhcpv6-client`). Nada de fora entra.
  - **`matsu-casa`** ("Rede de casa"): os aparelhos da casa se encontram
    (impressoras, TVs, pastas compartilhadas, KDE Connect, Steam Remote Play e cópia
    de jogos pela rede). SSH e área de trabalho remota ficam desligados até a pessoa
    ligar.
- **Toda rede nova começa como pública** (a zona padrão é `matsu-publica`). A zona
  `FedoraWorkstation`, que vem na Kinoite, deixava as portas 1025 a 65535 abertas
  para qualquer rede.
- Trocar uma rede entre pública e de casa é um clique. A Central grava a zona na
  conexão do NetworkManager (`nmcli connection modify <uuid> connection.zone ...`)
  e reaplica, sem derrubar a rede.
- Na lista "Na rede de casa, deixar entrar", cada chave liga ou desliga um serviço
  da zona `matsu-casa` (`firewall-cmd --permanent`, com a senha de administrador).
- **Bloquear um app de usar a internet não existe no firewalld.** Ele não sabe qual
  programa abriu cada conexão, e um bloqueio desses seria fácil de driblar. A página
  diz isso com todas as letras. Para os apps da Loja dá, e de verdade: desligar a
  Rede nas permissões do app deixa ele sem internet nenhuma.

## 4. Permissões dos apps

Para cada app da Loja (Flatpak) há chaves para **Câmera**, **Microfone e som**,
**Localização**, **Arquivos pessoais**, **Rede** e **Avisos**, além de "Voltar ao
padrão do app".

- As mudanças ficam na conta da pessoa (`flatpak override --user` e as permissões
  dos portais, `flatpak permission-set`). Não precisam de senha e valem na próxima
  vez que o app abrir.
- No Flatpak, o som e o microfone vêm juntos (o soquete do PulseAudio): desligar o
  microfone também tira o som do app. A página avisa.
- Os ícones são os oficiais que o próprio Flatpak exporta.
- **Apps fora da Loja não têm caixa de areia.** Os que vêm com o sistema ou de
  pacotes RPM (como a Steam) podem usar tudo o que a pessoa usa. A página explica
  isso e mostra quais estão instalados.

## 5. Integridade

A página mostra, com o estado de cada um:

- **imagem assinada**: o `rpm-ostree` só aceita a imagem com a assinatura do Matsu
  (`ostree-image-signed:` e a chave em `/etc/containers/policy.json`);
- **pasta do sistema só de leitura** (`/usr`);
- **Secure Boot**;
- **disco criptografado** (LUKS);
- **atualizações automáticas**;
- **Flatpak com assinatura GPG** em cada loja (remoto).

"Verificar os arquivos do sistema" roda `ostree fsck` pelo `pkexec` (ação
`org.matsu.seguranca.fsck`), com o anel de progresso. **Nada é inventado:** o que
não dá para conferir aparece como "Não foi possível conferir", com o motivo.

## 6. Bandeja

O plasmoide `org.matsu.seguranca` fica na área de notificação
(`X-Plasma-NotificationArea`). O ícone do escudo muda com o estado (protegido,
pausado, atenção, sem proteção). O balão mostra o estado, a pausa rápida (15 min e
1 hora, ou "Voltar a proteger agora") e o botão para abrir a Central. Os avisos do
escudo (ameaça bloqueada, pendrive, escudo de volta) usam o `notify-send`, com
botões que abrem a Central na página certa.

## 7. Na montagem da imagem

O `build_files/seguranca.sh`:

- instala o ClamAV;
- desliga as unidades do Fedora que fariam o mesmo trabalho em dobro
  (`clamav-freshclam`, `clamav-clamonacc`, `clamd@scan`);
- confere as zonas e põe `matsu-publica` como padrão;
- liga o `firewalld`, o `matsu-escudo-atualizar.timer` e o `matsu-escudo.service`
  (este para todas as contas, com `systemctl --global`);
- confere que todos os arquivos estão no lugar.

## Para testar

    python3 tests/test_seguranca.py

A prévia sem os serviços do sistema usa dados de mentira:

    MATSU_SEGURANCA_DEMO=protegido /usr/libexec/matsu/matsu-janela org.matsu.seguranca /usr/share/matsu/seguranca/Main.qml

Os valores são `protegido`, `atencao`, `pausado` e `baixando`. A janela do aviso abre
com o id `org.matsu.seguranca.aviso` e `Aviso.qml`, seguida do caminho de um arquivo.

Só dá para confirmar num sistema de verdade: o clamd com `DynamicUser` e o SELinux,
a regra do polkit, o primeiro download da lista, os pedidos de senha do firewalld e
do NetworkManager, e o andamento do `ostree fsck`.
