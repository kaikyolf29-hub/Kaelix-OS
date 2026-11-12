#!/usr/bin/python3
"""Nomes dos tipos de arquivo em português do Brasil ("Pasta", "Documento PDF"...).

O shared-mime-info novo grava a tradução brasileira como xml:lang="pt-BR", mas o
Qt (Dolphin, Arquivos, diálogos do KDE) procura "pt_BR". Sem isto, a coluna Tipo
mostra "Folder" e "Plain text document". Aqui as traduções pt-BR de todos os
pacotes de tipos viram um pacote a mais com pt_BR; depois o build.sh roda o
update-mime-database.

Alguns tipos não têm tradução nenhuma no pacote (o .iso aparecia como "Raw CD
image"). Para esses, o nome em português vem da lista NOSSOS, abaixo.

Uso: tipos-pt-br.py [saída]   (padrão: /usr/share/mime/packages/matsu-pt_BR.xml)
"""
import glob
import sys
import xml.etree.ElementTree as ET

NS = "http://www.freedesktop.org/standards/shared-mime-info"
LANG = "{http://www.w3.org/XML/1998/namespace}lang"
saida_arq = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/mime/packages/matsu-pt_BR.xml"

# Tipos comuns que o shared-mime-info ainda não traduziu.
NOSSOS = {
    "application/vnd.efi.iso": "Imagem de disco",
    "application/vnd.efi.img": "Imagem de disco",
    "application/x-shellscript": "Script do terminal",
    "application/x-fishscript": "Script do Fish",
    "application/x-nuscript": "Script do Nushell",
    "application/x-desktop": "Atalho de aplicativo",
    "application/x-sharedlib": "Biblioteca compartilhada",
    "application/x-shared-library-la": "Biblioteca compartilhada (Libtool)",
    "application/x-object": "Código objeto",
    "application/x-core": "Dados de travamento de programa",
    "application/x-msdownload": "Programa do Windows",
    "application/x-dosexec": "Programa do DOS",
    "application/x-ms-ne-executable": "Programa do Windows (16 bits)",
    "application/vnd.microsoft.portable-executable": "Programa do Windows",
    "application/x-ms-pdb": "Banco de dados de programa do Windows",
    "application/x-bat": "Arquivo de lote do Windows",
    "application/x-powershell": "Script do PowerShell",
    "application/x-ms-shortcut": "Atalho do Windows",
    "application/appx": "Pacote de app do Windows",
    "application/msix": "Pacote de app do Windows",
    "application/appxbundle": "Pacote de app do Windows",
    "application/msixbundle": "Pacote de app do Windows",
    "application/appinstaller": "Instalador de app do Windows",
    "application/x-bzip1": "Arquivo compactado Bzip",
    "application/x-bzip3": "Arquivo compactado Bzip3",
    "application/x-bzip1-compressed-tar": "Arquivo Tar compactado (bzip)",
    "application/x-bzip2-compressed-tar": "Arquivo Tar compactado (bzip2)",
    "application/x-bzip3-compressed-tar": "Arquivo Tar compactado (bzip3)",
    "application/x-zpaq": "Arquivo compactado Zpaq",
    "application/x-stuffitx": "Arquivo compactado StuffIt X",
    "application/x-shar": "Arquivo compactado de shell",
    "application/vnd.comicbook-rar": "Revista em quadrinhos (RAR)",
    "application/vnd.comicbook+zip": "Revista em quadrinhos (ZIP)",
    "application/x-cb7": "Revista em quadrinhos (7z)",
    "application/x-cbt": "Revista em quadrinhos (Tar)",
    "application/x-bzpdf": "Documento PDF (compactado)",
    "application/json5": "Documento JSON5",
    "application/schema+json": "Esquema JSON",
    "application/wasm": "Módulo WebAssembly",
    "application/x-openvpn-profile": "Perfil do OpenVPN",
    "application/x-modrinth-modpack+zip": "Pacote de mods do Modrinth",
    "application/x-theme": "Tema",
    "application/x-gettext-translation": "Tradução compilada",
    "application/x-perf-data": "Dados de desempenho",
    "application/x-profile": "Resultado de análise de desempenho",
    "application/vnd.apple.numbers": "Planilha do Apple Numbers",
    "application/vnd.apple.pages": "Documento do Apple Pages",
    "application/vnd.apple.pkpass": "Passe da Apple Wallet",
    "application/vnd.ms-officetheme": "Tema do Microsoft Office",
    "application/cbor": "Dados CBOR",
    "audio/x-mpegurl": "Lista de reprodução",
    "application/vnd.apple.mpegurl": "Lista de reprodução",
    "video/vnd.mpegurl": "Lista de vídeos",
    "image/apng": "Imagem PNG animada",
    "image/svg+xml-compressed": "Imagem SVG compactada",
    "image/x-compressed-xcf": "Imagem do GIMP compactada",
    "image/x-dcraw": "Foto RAW",
    "image/qoi": "Imagem QOI",
    "inode/blockdevice": "Dispositivo de bloco",
    "inode/chardevice": "Dispositivo de caractere",
    "inode/fifo": "Canal (pipe)",
    "inode/socket": "Soquete",
    "text/x-log": "Registro de aplicativo",
    "text/x-patch": "Diferenças entre arquivos",
    "text/x-reject": "Correção rejeitada",
    "text/x-rst": "Documento reStructuredText",
    "text/richtext": "Documento de texto formatado",
    "text/enriched": "Documento de texto formatado",
    "text/vcard": "Cartão de contato",
    "text/x-authors": "Lista de autores",
    "text/x-credits": "Créditos",
    "text/x-copying": "Termos de licença",
    "text/x-todo-txt": "Lista de tarefas",
    "text/x-typst": "Documento Typst",
    "text/org": "Arquivo do Org-mode",
    "text/x-systemd-unit": "Arquivo de serviço do systemd",
    "text/x-uri": "Endereço de recurso",
    "text/x-crystal": "Código-fonte Crystal",
    "text/julia": "Código-fonte Julia",
    "text/x-nim": "Código-fonte Nim",
    "text/x-vb": "Código-fonte Visual Basic .NET",
    "text/x-basic": "Programa BASIC",
    "text/spreadsheet": "Planilha de intercâmbio",
}


def tem_pt_br(tipo, langs):
    return any(el.get(LANG) in langs for el in tipo.findall(f"{{{NS}}}comment"))


saida = ET.Element("mime-info", xmlns=NS)
n = 0
traduzidos = set()
existentes = set()
for arq in sorted(glob.glob("/usr/share/mime/packages/*.xml")):
    if "matsu" in arq:
        continue
    for tipo in ET.parse(arq).getroot().findall(f"{{{NS}}}mime-type"):
        nome = tipo.get("type")
        existentes.add(nome)
        # Já tem pt_BR (pacote antigo): não mexe.
        if any(el.get(LANG) == "pt_BR" for el in tipo):
            traduzidos.add(nome)
            continue
        novos = [(tag, el.text) for tag in ("comment", "acronym", "expanded-acronym")
                 for el in tipo.findall(f"{{{NS}}}{tag}") if el.get(LANG) == "pt-BR" and el.text]
        if novos:
            t = ET.SubElement(saida, "mime-type", type=nome)
            for tag, texto in novos:
                e = ET.SubElement(t, tag)
                e.set("xml:lang", "pt_BR")
                e.text = texto
            if tem_pt_br(tipo, ("pt-BR",)):
                traduzidos.add(nome)
            n += 1

m = 0
for nome, texto in sorted(NOSSOS.items()):
    if nome in existentes and nome not in traduzidos:
        t = ET.SubElement(saida, "mime-type", type=nome)
        e = ET.SubElement(t, "comment")
        e.set("xml:lang", "pt_BR")
        e.text = texto
        m += 1

ET.ElementTree(saida).write(saida_arq, encoding="UTF-8", xml_declaration=True)
print(f"tipos de arquivo traduzidos para pt_BR: {n} (mais {m} com nome do Matsu)")
