#!/usr/bin/python3
"""Liga os nomes de ícone de pasta e de tipo de arquivo aos desenhos do Matsu.

Os programas pedem o ícone pelo nome do tipo (video-x-matroska, application-pdf,
folder-download...). O Breeze tem centenas desses nomes; aqui cada um vira uma
ligação para um dos desenhos do Matsu (visual/icones/tipos.py), pela categoria:
vídeo, imagem, música, disco, compactado, código... Assim a lista do Arquivos,
os diálogos de abrir e salvar e a área de trabalho ficam todos no mesmo jeito.

Fica com o Breeze: ícones "-symbolic", pastas de cor escolhida pela pessoa
(folder-red, folder-green...) e folder-open (é ícone de ação nos menus).

Uso: icones-de-arquivo.py [raiz]   (padrão: /, ou seja /usr/share/icons)
"""
import re
import sys
from pathlib import Path

RAIZ = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/")
ICONES = RAIZ / "usr/share/icons"
TEMAS = {"Matsu": "breeze-dark", "Matsu-claro": "breeze"}

# Nomes genéricos do padrão freedesktop (o Breeze pode não ter todos).
GENERICOS = [
    "text-x-generic", "text-x-script", "text-plain", "text-html", "image-x-generic", "video-x-generic",
    "audio-x-generic", "font-x-generic", "package-x-generic", "application-x-executable",
    "application-octet-stream", "x-office-document", "x-office-spreadsheet", "x-office-presentation",
    "application-x-zerosize", "unknown", "inode-directory", "application-x-cd-image", "application-zip",
]
PASTAS_GENERICAS = ["folder", "inode-directory", "user-home", "user-desktop", "folder-download",
                    "folder-documents", "folder-pictures", "folder-videos", "folder-music"]

CORES_DE_PASTA = {"black", "blue", "brown", "cyan", "green", "grey", "gray", "magenta", "orange", "red",
                  "violet", "yellow", "white", "pink", "purple", "teal", "yellowgreen", "darkcyan",
                  "lightblue", "custom"}


# Arquivos de um programa de outra marca (Krita, Blender, Godot, Kdenlive...):
# ficam com o ícone que lembra o programa, como no Windows.
DE_PROGRAMA = re.compile(
    r"(krita|blender|kdenlive|godot|audacity|k3b|kexi|kmymoney|kplato|kformula|kontour|labplot|marble|xmind|"
    r"scribus|lyx|qet-|x-skg|kgetlist|kvtml|x-designer|tgif|illustrator|visio|msonenote|msoutlook|ms-access|"
    r"ms-publisher|infopath|x-egon|x-plasma|kcsrc|x-siag|x-sif$|x-root$|x-rdata|x-nzb|smb-server|smb-workgroup|"
    r"nsplugin|kleopatra|iccprofile|dicom|openofficeorg\.extension|libreoffice-extension|libreoffice-database|"
    r"libreoffice-oasis-database|libreoffice-formula|libreoffice-oasis-formula|x-kde-)")


def tipo(nome):
    """Categoria (o nome do desenho matsu-tipo-*) de um nome de ícone de tipo.

    None: é pasta (vai para os desenhos de pasta). "breeze": fica com o Breeze.
    """
    n = nome.lower()
    if n in ("inode-directory", "folder"):
        return None
    if DE_PROGRAMA.search(n):
        return "breeze"
    if re.search(r"(rom$|-rom-|snes|gameboy|gamecube|nintendo|x-gba|x-n64|x-nes|sega|playstation|x-psx)", n):
        return "jogo"
    if re.search(r"(certificate|pgp|pkcs|pkix|x509|pem-key|encrypted|x-keepass|gpg|openvpn|vpn-settings)", n):
        return "seguranca"
    if re.search(r"(wps-office\.(xls|xlt)|quattropro)", n):
        return "planilha"
    if re.search(r"(wps-office\.(ppt|pot))", n):
        return "apresentacao"
    if re.search(r"(ms-word|wps-office\.do|mswrite|x-sxw|-sxw$|libreoffice-.*text|master-document|applix-word|^odf$|"
                 r"x-srt|x-sami|srtrip|troff-man|^viewdvi|^viewps|^viewbib|x-bzdvi|x-gzdvi|message|x-office-contact|"
                 r"address-book|distribution-list)", n):
        return "texto"
    if re.search(r"(libreoffice-.*drawing|x-office-drawing|x-wmf)", n):
        return "imagem"
    if re.search(r"(application-ogg|audiobook|podcast|x-cda$)", n):
        return "audio"
    if re.search(r"(flash-video|realmedia)", n):
        return "video"
    if re.search(r"(x-iso$|vdi-disk)", n):
        return "disco"
    if re.search(r"(x-jar$|vnd\.snap|fonts-package)", n):
        return "fonte" if "fonts" in n else "pacote"
    if re.search(r"(x-arc$|x-lzop|x-pak$)", n):
        return "compactado"
    if re.search(r"(xsd$|relaxng|xliff|x-m4$|x-awk)", n):
        return "codigo"
    if re.search(r"(cd-image|iso9660|efi\.iso|efi\.img|disk-image|diskimage|raw-disk|qemu-disk|vhd|vmdk|"
                 r"virtualbox|-cue$|x-toc$|apple-diskimage)", n):
        return "disco"
    if re.search(r"(rpm|debian|x-deb$|x-deb-|flatpak|appimage|msi$|x-ms-wim|java-archive|android\.package|"
                 r"x-snap|package-x-generic|appx|msix|appinstaller|x-xpinstall|x-ruby-gem|x-archlinux-package)", n):
        return "pacote"
    if re.search(r"(spreadsheet|excel|calc|csv|tab-separated|numbers|gnumeric|kspread|x-xls)", n):
        return "planilha"
    if re.search(r"(presentation|powerpoint|impress|keynote|kpresenter|x-ppt)", n):
        return "apresentacao"
    if re.search(r"(pdf$|-pdf-|x-gzpdf|x-bzpdf|x-xzpdf|-pdf$)", n):
        return "pdf"
    if re.search(r"(^font-|-font-|opentype|truetype|x-font|woff|fontforge)", n):
        return "fonte"
    if n.startswith("image-"):
        return "imagem"
    if n.startswith("video-"):
        return "video"
    if n.startswith("audio-"):
        return "audio"
    if re.search(r"(executable|x-msdownload|dosexec|portable-executable|x-ms-dos|x-ms-ne|x-msi$|x-bat$|"
                 r"x-desktop$|x-sharedlib|x-shared-library|x-object|x-core$|x-elf)", n):
        return "executavel"
    if re.search(r"(zip|tar|rar|7z|compress|archive|bzip|gzip|x-xz|lzma|lzip|lz4|zstd|x-arj|x-ace|cpio|"
                 r"x-lha|x-lzh|x-zoo|stuffit|cab|x-zpaq|x-shar|squashfs|x-ar$|-gz$)", n):
        return "compactado"
    if re.search(r"(msword|wordprocessing|opendocument\.text|x-office-document|rtf|abiword|kword|wordperfect|"
                 r"epub|fictionbook|mobipocket|djvu|postscript|x-dvi|oasis\.opendocument)", n):
        return "texto"
    if re.search(r"(markdown|text-plain|text-x-generic|x-log$|readme|changelog|authors|copying|credits|"
                 r"install$|text-x-nfo|x-todo|subrip|subtitle|x-ssa|text-vtt|text-x-tex$|vcard|calendar|"
                 r"rst$|richtext|enriched|text-x-mpsub|x-mpl2)", n):
        return "texto"
    if re.search(r"(^text-|javascript|json|xml|yaml|toml|x-shellscript|script|x-perl|x-python|x-ruby|x-php|"
                 r"x-java|x-csrc|x-c\+\+|x-chdr|x-rust|x-go$|makefile|cmake|x-sql|sql$|x-lua|x-qml|wasm|"
                 r"x-ipynb|x-patch|x-diff|html|css|x-sh$|x-csh|x-asp|x-jsp|x-kotlin|x-dart|x-swift)", n):
        return "codigo"
    return "generico"


PASTAS_ESPECIAIS = [
    (r"^(folder-downloads?|folder-download-symbolic)$", "-downloads"),
    (r"^folder-documents?$", "-documentos"),
    (r"^(folder-pictures|folder-images?|folder-image-people|folder-photos?|folder-screenshots?)$", "-imagens"),
    (r"^(folder-videos?|folder-movies?)$", "-videos"),
    (r"^(folder-music|folder-sound|folder-audio)$", "-musica"),
    (r"^(folder-desktop|user-desktop|desktop)$", "-area-de-trabalho"),
    (r"^(user-home|folder-home)$", "-pessoal"),
    (r"^(folder-games?|folder-steam)$", "-jogos"),
]


def pasta(nome):
    """Desenho de pasta (sufixo de matsu-pasta*) para um nome, ou None para deixar o Breeze."""
    n = nome.lower()
    if n.endswith("-symbolic") or n in ("folder-open", "folder-drag-accept"):
        return None
    for padrao, sufixo in PASTAS_ESPECIAIS:
        if re.match(padrao, n):
            return sufixo
    if n in ("folder", "inode-directory"):
        return ""
    if n.startswith("folder-"):
        resto = n[len("folder-"):]
        if resto in CORES_DE_PASTA or any(resto.startswith(c + "-") for c in CORES_DE_PASTA):
            return None
        return ""
    return None


def nomes(base, contexto):
    achados = set()
    for svg in (ICONES / base / contexto).glob("*/*.svg"):
        if not svg.stem.endswith("-symbolic"):
            achados.add(svg.stem)
    return achados


def ligar(pasta_destino, nome, alvo):
    destino = pasta_destino / f"{nome}.svg"
    if destino.exists() or destino.is_symlink():
        return False
    destino.symlink_to(alvo)
    return True


def main():
    total = 0
    for tema, base in TEMAS.items():
        raiz = ICONES / tema
        tipos = nomes(base, "mimetypes") | set(GENERICOS)
        lugares = nomes(base, "places") | set(PASTAS_GENERICAS)
        for tamanho in ("pequeno", "scalable"):
            for nome in sorted(tipos):
                cat = tipo(nome)
                if cat == "breeze":
                    continue
                if cat is None:
                    sufixo = pasta(nome)
                    if sufixo is not None and ligar(raiz / "mimetypes" / tamanho, nome, f"../../places/{tamanho}/matsu-pasta{sufixo}.svg"):
                        total += 1
                    continue
                total += ligar(raiz / "mimetypes" / tamanho, nome, f"matsu-tipo-{cat}.svg")
            for nome in sorted(lugares):
                sufixo = pasta(nome)
                if sufixo is not None:
                    total += ligar(raiz / "places" / tamanho, nome, f"matsu-pasta{sufixo}.svg")
    print(f"ícones de pasta e de tipo do Matsu: {total} nomes ligados")


if __name__ == "__main__":
    main()
