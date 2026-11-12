# Matsu OS — imagem do sistema
#
# Este arquivo descreve o sistema inteiro. O GitHub Actions monta a imagem a
# partir dele, assina com cosign e publica em ghcr.io/<usuario>/matsu-os.
#
# Base: Fedora Atomic KDE (Kinoite) já com codecs, mantido pelo Universal Blue.
#   - variante "main"   (AMD e Intel): ghcr.io/ublue-os/kinoite-main
#   - variante "nvidia" (driver oficial NVIDIA): ghcr.io/ublue-os/kinoite-nvidia

ARG BASE_IMAGE=ghcr.io/ublue-os/kinoite-main
ARG FEDORA_VERSION=44

# Etapa só com os arquivos do repositório, montada durante a construção.
# Nada daqui fica na imagem final, a não ser o que o build.sh copiar.
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files
COPY cosign.pub /cosign.pub
# O número da edição do ano (27 = edição 2027): o nome do sistema é "Matsu 27 OS".
COPY EDICAO /EDICAO
# O que mudou em cada versão (27, 27.1, 27.2...): a de cima é a versão da imagem.
COPY NOVIDADES.md /NOVIDADES.md

# Etapa que compila os botões de janela do Matsu. Usa a mesma base da imagem,
# para a versão do KDE ser exatamente a mesma. Só o arquivo pronto (/out) vai
# para a imagem final; os compiladores ficam de fora.
FROM ${BASE_IMAGE}:${FEDORA_VERSION} AS deco
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/deco/build.sh

FROM ${BASE_IMAGE}:${FEDORA_VERSION}

ARG IMAGE_NAME=matsu-os
ARG IMAGE_VARIANT=main
ARG IMAGE_REGISTRY=ghcr.io/kaikyolf29-hub
ARG BUILD_ID=local
ARG FEDORA_VERSION=44

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=deco,source=/out,target=/deco \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_NAME="${IMAGE_NAME}" \
    IMAGE_VARIANT="${IMAGE_VARIANT}" \
    IMAGE_REGISTRY="${IMAGE_REGISTRY}" \
    BUILD_ID="${BUILD_ID}" \
    FEDORA_VERSION="${FEDORA_VERSION}" \
    /ctx/build_files/build.sh

# Confere se a imagem segue as regras de uma imagem bootc válida.
RUN bootc container lint

LABEL org.opencontainers.image.title="Matsu OS" \
      org.opencontainers.image.description="Sistema operacional Matsu OS, baseado em Fedora Atomic KDE" \
      org.opencontainers.image.licenses="GPL-3.0-only" \
      containers.bootc="1"
