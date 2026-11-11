# Matsu 27 OS

Sistema operacional gratuito e público, feito em cima do Fedora Atomic com KDE Plasma.
O nome vem do pinheiro japonês (matsu, 松), que é o logo. Uma edição por ano: só o número
muda (27 = edição 2027), e ele fica no arquivo [`EDICAO`](EDICAO). Até 11/11/2026 o
sistema se chamava Kaelix OS.
Para jogar, programar, estudar cibersegurança e usar no dia a dia.

> **Estado:** em construção (Etapa 1, a fundação). Ainda não existe versão estável.

## O que já tem

- **Imagem do sistema** descrita no [`Containerfile`](Containerfile), montada pelo GitHub,
  **assinada com cosign** e publicada em `ghcr.io/kaikyolf29-hub/matsu-os`.
- Duas variantes: `matsu-os` (placas AMD e Intel) e `matsu-os-nvidia` (driver oficial da NVIDIA).
- **Jogos:** Steam com Proton, Heroic (Epic e GOG), Lutris, GameMode e MangoHud.
- **Programação:** Git, Python, Node, compiladores, VS Code e Distrobox.
- **Terminal próprio:** abas, tela dividida, vidro e uma barra com a pasta, o ramo do git e o programa rodando.
- **Cibersegurança:** contêiner do Kali criado pelo comando `matsu seguranca`.
- **Vídeo:** OBS Studio e Kdenlive. **Loja de apps:** Flathub ligado.
- **Navegador:** no primeiro login a pessoa escolhe Google Chrome, Brave ou os dois.
- **Atualização atômica:** ou atualiza tudo, ou nada muda. Se quebrar, volta pelo menu de boot.

## O comando `matsu`

| Português | English | O que faz |
|---|---|---|
| `matsu atualizar` | `matsu update` | Baixa a nova versão assinada (entra ao reiniciar) |
| `matsu voltar` | `matsu rollback` | Volta para a versão anterior |
| `matsu drivers` | `matsu drivers` | Mostra a placa de vídeo e confere o driver |
| `matsu seguranca` | `matsu security` | Abre o contêiner do Kali |
| `matsu navegador` | `matsu browser` | Instala o Chrome, o Brave ou os dois |
| `matsu barra` | `matsu bar` | Troca o estilo da barra (fusão, mac ou windows) e o tamanho |
| `matsu versao` | `matsu version` | Mostra a versão |
| `matsu ajuda` | `matsu help` | Ajuda |

## Canais de atualização

- `teste`: montado sozinho a cada mudança e todo dia. É o que o criador testa.
- `estavel`: só muda quando o criador publica uma versão (fluxo **Publicar versão estável**).

## Como funciona por dentro

| Arquivo | Para que serve |
|---|---|
| [`Containerfile`](Containerfile) | Descreve o sistema inteiro |
| [`build_files/build.sh`](build_files/build.sh) | Instala os pacotes e configura a imagem |
| [`system_files/`](system_files) | Arquivos próprios do Matsu copiados para o sistema (comando `matsu`, serviços) |
| [`installer/matsu.ks.in`](installer/matsu.ks.in) | Configuração do instalador |
| [`.github/workflows/`](.github/workflows) | Montagem da imagem, da ISO, publicação e testes |
| [`docs/PLANO.md`](docs/PLANO.md) | O plano completo do projeto |
| [`docs/ACOMPANHAMENTO.md`](docs/ACOMPANHAMENTO.md) | O que já foi feito e provado, e o que falta |
| [`docs/CHAVES.md`](docs/CHAVES.md) | Como funcionam as chaves de assinatura |
| [`docs/COMO-TESTAR.md`](docs/COMO-TESTAR.md) | Como testar numa máquina virtual e no SSD |

## Aviso sobre jogos com antitrapaça

O Fortnite e o Valorant **não rodam no Linux**, porque as próprias empresas não liberam o antitrapaça.
Nenhuma distribuição resolve isso. Dá para jogar o Fortnite pela nuvem (GeForce Now ou Xbox Cloud Gaming).
Antes de instalar um jogo, confira em [protondb.com](https://www.protondb.com) e [areweanticheatyet.com](https://areweanticheatyet.com).

## Licença

Os arquivos próprios do Matsu OS estão sob a [GPL-3.0](LICENSE).
Os programas de terceiros incluídos seguem as licenças deles.

---

### English

Matsu OS is a free, public operating system built on Fedora Atomic with KDE Plasma, aimed at gaming,
programming, security studies and everyday use. Images are built by GitHub Actions, signed with cosign
and published to `ghcr.io/kaikyolf29-hub/matsu-os` (`-nvidia` for NVIDIA cards). Status: early development,
no stable release yet. License: GPL-3.0 for Matsu's own files.
