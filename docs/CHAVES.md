# Chaves de assinatura

O Kaelix OS só aceita atualizações **assinadas com a chave do criador**. Isso impede que outra pessoa
se passe pelo sistema e mande uma atualização falsa.

## As duas partes da chave

| Parte | Onde fica | Pode ser pública? |
|---|---|---|
| **Chave pública** | [`cosign.pub`](../cosign.pub), neste repositório, e dentro do sistema em `/etc/pki/containers/kaelix-os.pub` | Sim. Ela só confere assinaturas |
| **Chave privada** e **senha** | Só nos segredos do GitHub e numa cópia offline no pendrive | **Nunca.** Quem tem ela consegue assinar como o Kaelix |

A chave foi criada em 10/11/2026 com o cosign v2.5.0 (tipo ECDSA P-256, protegida por senha).

## Segredos do GitHub

Ficam em **Settings → Secrets and variables → Actions → New repository secret**:

| Nome do segredo | O que colocar |
|---|---|
| `SIGNING_SECRET` | O texto inteiro da chave privada, de `-----BEGIN ENCRYPTED SIGSTORE PRIVATE KEY-----` até `-----END ENCRYPTED SIGSTORE PRIVATE KEY-----` |
| `COSIGN_PASSWORD` | A senha da chave |

Sem esses dois segredos, o GitHub monta a imagem mas não publica nada.

## Cópia de segurança

1. Guarde o arquivo com a chave privada e a senha **num pendrive**, e o pendrive num lugar seguro.
2. **Apague o arquivo do computador** depois de copiar para o pendrive.
3. Ative a **verificação em duas etapas** na conta do GitHub (Settings → Password and authentication).

## Se a chave se perder ou vazar

- **Perdeu (e não tem a cópia):** dá para criar uma chave nova, mas quem já instalou o Kaelix vai rejeitar as
  imagens assinadas com ela e vai precisar reinstalar ou trocar a imagem à mão. Por isso a cópia no pendrive é tão importante.
- **Vazou:** crie uma chave nova o quanto antes, troque o `cosign.pub` e os dois segredos, e publique uma versão
  nova. Avise quem usa.
