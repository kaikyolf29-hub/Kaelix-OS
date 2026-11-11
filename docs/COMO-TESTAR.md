# Como testar o Matsu OS

Primeiro numa **máquina virtual**, para nenhum erro tocar no PC de verdade. Depois no **SSD separado**, em dual boot.

## 1. Baixar a ISO de teste

1. No repositório, abra a aba **Actions**.
2. Escolha **Montar ISO** → **Run workflow** → canal `teste` → **Run workflow**.
3. Quando terminar (uns 15 minutos), abra a execução e baixe `matsu-os-teste-...-amd.iso` em **Artifacts**.
   Ela vem dentro de um `.zip`: extraia antes de usar.

A ISO é um instalador de rede (cerca de 1 GB). **Precisa de internet durante a instalação**, porque ela baixa
o sistema assinado direto do GitHub.

## 2. Máquina virtual no Hyper-V (Windows 11 Pro)

1. Ligue o Hyper-V: menu Iniciar → "Ativar ou desativar recursos do Windows" → marque **Hyper-V** → reinicie.
2. Abra o **Gerenciador do Hyper-V** → **Novo → Máquina Virtual**:
   - **Geração 2**;
   - memória: **8192 MB**, sem memória dinâmica;
   - rede: **Default Switch**;
   - disco: **64 GB**;
   - instalar a partir de arquivo: escolha a ISO.
3. Antes de ligar, em **Configurações → Segurança**, troque o modelo do Secure Boot para
   **Autoridade de Certificação UEFI da Microsoft** (o Linux usa esse).
4. Em **Processador**, coloque 4 processadores virtuais.
5. Ligue e siga o instalador: idioma, teclado, disco (o disco virtual) e usuário.

Na máquina virtual o visual fica mais lento, porque o Hyper-V não usa a placa de vídeo. Isso é normal.
Jogos ficam para o teste no SSD.

### O que conferir na VM

- [ ] Instala e liga até a área de trabalho.
- [ ] Aparece a pergunta do navegador no primeiro login.
- [ ] `matsu versao` mostra a imagem `matsu-os:teste`.
- [ ] `matsu atualizar` termina sem erro (e liga a verificação de assinatura).
- [ ] Steam, Heroic, Lutris, OBS e Kdenlive aparecem no menu (os Flatpak podem levar alguns minutos depois do primeiro boot).
- [ ] `matsu seguranca` cria o contêiner do Kali.

## 3. No SSD NVMe, em dual boot com o Windows

Antes de instalar:

1. **Faça cópia de segurança** do que importa num HD externo.
2. Grave a ISO num pendrive com o [Fedora Media Writer](https://fedoraproject.org/workstation/download) ou o Rufus (modo DD).
3. No instalador, selecione **só o SSD do Linux**. Não marque o disco do Windows.
4. **Confira duas vezes** o disco escolhido antes de confirmar.

### O que conferir no PC

- [ ] Liga pelo menu de boot e o Windows continua aparecendo lá.
- [ ] As duas telas funcionam, na taxa de atualização certa.
- [ ] A RX 580 aparece em `matsu drivers` com o driver `amdgpu`.
- [ ] Um jogo da Steam abre e roda.
- [ ] Recebe uma atualização assinada com `matsu atualizar`.
- [ ] O relógio fica certo ao voltar para o Windows (ver a lista de acompanhamento).

### Bandeja perto do relógio (como no Windows)

Os ícones dos apps que ficam rodando em segundo plano aparecem na ilha da
direita, à esquerda da pílula de rede e som. O Matsu é KDE, então isso já vem
pronto, sem instalar extensão. Para conferir no PC:

1. Abra a Steam e o Discord (instale pela Loja, se quiser) e feche a janela
   deles: os dois continuam rodando na bandeja.
- [ ] Os dois ícones aparecem na ilha da direita.
- [ ] Um clique no ícone abre o app de novo.
- [ ] O botão direito no ícone mostra o menu do app (na Steam: Loja, Biblioteca, Sair...).
- [ ] A setinha "mostrar mais" (ou Meta+B) mostra os ícones escondidos. Pelo
      botão direito na setinha, em "Configurar a bandeja", dá para escolher quais
      ficam sempre à vista.
- [ ] No tema claro (central de controle, botão "Modo escuro") os ícones continuam
      fáceis de ver.
- [ ] Um app antigo também aparece. Os apps antigos usam um jeito velho de bandeja
      (XEmbed), que o Matsu converte sozinho para o novo. Exemplo: um programa do
      Windows aberto pelo Wine ou pelo Proton que fica na bandeja.

Se um ícone não aparecer, estes comandos no terminal mostram o que a bandeja
recebeu (mande o resultado):

```sh
busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
  org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems
pgrep -a xembedsniproxy
```

A primeira linha lista os apps registrados (protocolo novo, StatusNotifierItem e
AppIndicator). A segunda mostra se o conversor dos apps antigos está rodando.

Tire foto ou grave a tela de cada item: é a prova de que está pronto.
