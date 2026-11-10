# Kaelix OS

Sistema operacional gratuito e público, feito em cima do Fedora Atomic com KDE Plasma.
Para jogar, programar, estudar cibersegurança e usar no dia a dia.

> **Estado:** em construção (Etapa 1, a fundação). Ainda não existe versão estável.

## O que já tem

- **Imagem do sistema** descrita no [`Containerfile`](Containerfile), montada pelo GitHub,
  **assinada com cosign** e publicada em `ghcr.io/kaikyolf29-hub/kaelix-os`.
- Duas variantes: `kaelix-os` (placas AMD e Intel) e `kaelix-os-nvidia` (driver oficial da NVIDIA).
- **Jogos:** Steam com Proton, Heroic (Epic e GOG), Lutris, GameMode e MangoHud.
- **Programação:** Git, Python, Node, compiladores, VS Code e Distrobox.
- **Cibersegurança:** contêiner do Kali criado pelo comando `kaelix seguranca`.
- **Vídeo:** OBS Studio e Kdenlive. **Loja de apps:** Flathub ligado.
- **Navegador:** no primeiro login a pessoa escolhe Google Chrome, Brave ou os dois.
- **Atualização atômica:** ou atualiza tudo, ou nada muda. Se quebrar, volta pelo menu de boot.

## O comando `kaelix`

| Português | English | O que faz |
|---|---|---|
| `kaelix atualizar` | `kaelix update` | Baixa a nova versão assinada (entra ao reiniciar) |
| `kaelix voltar` | `kaelix rollback` | Volta para a versão anterior |
| `kaelix drivers` | `kaelix drivers` | Mostra a placa de vídeo e confere o driver |
| `kaelix seguranca` | `kaelix security` | Abre o contêiner do Kali |
| `kaelix navegador` | `kaelix browser` | Instala o Chrome, o Brave ou os dois |
| `kaelix barra` | `kaelix bar` | Troca o estilo da barra (fusão, mac ou windows) e o tamanho |
| `kaelix versao` | `kaelix version` | Mostra a versão |
| `kaelix ajuda` | `kaelix help` | Ajuda |

## Canais de atualização

- `teste`: montado sozinho a cada mudança e todo dia. É o que o criador testa.
- `estavel`: só muda quando o criador publica uma versão (fluxo **Publicar versão estável**).

## Como funciona por dentro

| Arquivo | Para que serve |
|---|---|
| [`Containerfile`](Containerfile) | Descreve o sistema inteiro |
| [`build_files/build.sh`](build_files/build.sh) | Instala os pacotes e configura a imagem |
| [`system_files/`](system_files) | Arquivos próprios do Kaelix copiados para o sistema (comando `kaelix`, serviços) |
| [`installer/kaelix.ks.in`](installer/kaelix.ks.in) | Configuração do instalador |
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

Os arquivos próprios do Kaelix OS estão sob a [GPL-3.0](LICENSE).
Os programas de terceiros incluídos seguem as licenças deles.

---

### English

Kaelix OS is a free, public operating system built on Fedora Atomic with KDE Plasma, aimed at gaming,
programming, security studies and everyday use. Images are built by GitHub Actions, signed with cosign
and published to `ghcr.io/kaikyolf29-hub/kaelix-os` (`-nvidia` for NVIDIA cards). Status: early development,
no stable release yet. License: GPL-3.0 for Kaelix's own files.
