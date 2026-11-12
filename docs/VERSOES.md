# Versões do Matsu OS

## Como os números funcionam

- **Uma edição por ano.** O número é o fim do ano: o **Matsu 27 OS** é a edição de
  2027, o Matsu 28 OS a de 2028. O número da edição fica no arquivo [`EDICAO`](../EDICAO)
  e aparece no nome do sistema, no menu de boot, no "Sobre" e no site.
- **Atualizações durante o ano** ganham um ponto e um número: **27.1**, **27.2**,
  **27.3**... Elas trazem apps novos, melhorias e correções, sem trocar o nome do sistema.
- A primeira versão da edição é só o número: **27** (e não 27.0).
- Correções de segurança da base (Fedora) entram todo dia no canal `teste`, sem
  número novo. O número muda quando há novidade que a pessoa percebe.

## Onde fica o que mudou

O arquivo [`NOVIDADES.md`](../NOVIDADES.md), na raiz do repositório, guarda o que mudou
em cada versão, **a mais nova em cima**:

```markdown
## 27.1
_Em preparação_

Uma frase curta sobre a versão (opcional).

- **Relógio**: os alarmes tocam mesmo com o app fechado.
- **Loja**: fotos maiores e instalação mais rápida.
```

- A versão de cima **é a versão da imagem**: a montagem lê o número dali, coloca no
  `/usr/lib/os-release` (`VERSION="27.1 (Edição 2027)"`) e no
  `/usr/share/matsu/image-info.json`, e copia o arquivo para `/usr/share/matsu/novidades.md`.
  Se o número não for da edição do arquivo `EDICAO`, a montagem para com erro.
- Cada item é uma linha `- **Assunto**: o que mudou.`, curta, para quem usa o
  computador (nada de termos técnicos). O teste `tests/test_novidades.py` confere.
- Enquanto a versão não sai, a data fica `_Em preparação_`: a imagem do canal teste
  mostra "Montada em <data>" no lugar, e o Release mostra "Publicada em <data>".

## Começar uma versão nova

1. Em cima do `NOVIDADES.md`, crie `## 27.1` com `_Em preparação_` e vá juntando os
   itens conforme as coisas ficam prontas.
2. Para a edição do ano seguinte, troque o `EDICAO` para `28` e crie `## 28` em cima.

## Publicar (só o Kaiky decide)

1. Confira se a imagem do canal `teste` já é a versão nova: o fluxo **Montar imagem**
   roda sozinho a cada mudança de código e todo dia às 3h. Se o `NOVIDADES.md` foi a
   única mudança, rode **Montar imagem** à mão (aba Actions, "Run workflow").
2. Rode **Publicar versão estável** na aba Actions: escreva o número (`27.1`), um recado
   extra se quiser e `PUBLICAR`.
3. O fluxo confere que o número é da edição, que é o de cima do `NOVIDADES.md` e que a
   imagem do canal `teste` tem esse número (rótulo `org.matsu.versao`). Depois copia a
   imagem assinada para o canal `estavel` e para a etiqueta `27.1`, cria o Release
   `v27.1` com as novidades e anexa as ISOs.

## O aviso no computador

O `matsu-novidades.timer` (do usuário) roda o `/usr/share/matsu/atualizacoes/ajudante.py`
2 minutos depois do login e a cada 6 horas:

- **Depois de atualizar:** "O Matsu foi atualizado para a 27.1", com os três primeiros
  assuntos e o botão **Ver novidades**. Na edição nova: "Bem-vindo ao Matsu 28 OS".
  No primeiro login depois de instalar, e depois de voltar para a versão anterior,
  não aparece nada.
- **Versão nova no canal:** lê o rótulo `org.matsu.versao` da imagem do canal do
  computador com o `skopeo` (sem baixar a imagem). Se for maior, avisa uma vez:
  "Matsu 27.2 disponível", com o que muda (rótulo `org.matsu.novidades`) e os botões
  **Atualizar** (abre o terminal com `matsu atualizar`) e **Ver novidades**. Se a
  versão já foi baixada, o aviso pede para reiniciar.
- **Apps da Loja com atualização** (Flatpak): avisa uma vez por lista, com o botão
  **Abrir a Loja**. O aviso do Discover não sobe mais.

A janela **Atualizações** (`org.matsu.atualizacoes`, no menu e nos avisos) mostra a
versão do computador, procura a versão nova e lista o que mudou em todas as versões.

O que já foi avisado fica em `~/.local/state/matsu/novidades.json`.
