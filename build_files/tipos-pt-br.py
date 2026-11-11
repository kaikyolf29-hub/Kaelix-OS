#!/usr/bin/python3
"""Nomes dos tipos de arquivo em português do Brasil ("Pasta", "Documento PDF"...).

O shared-mime-info novo grava a tradução brasileira como xml:lang="pt-BR", mas o
Qt (Dolphin, Arquivos, diálogos do KDE) procura "pt_BR". Sem isto, a coluna Tipo
mostra "Folder" e "Plain text document". Aqui as traduções pt-BR de todos os
pacotes de tipos viram um pacote a mais com pt_BR; depois o build.sh roda o
update-mime-database.

Uso: tipos-pt-br.py [saída]   (padrão: /usr/share/mime/packages/matsu-pt_BR.xml)
"""
import glob
import sys
import xml.etree.ElementTree as ET

NS = "http://www.freedesktop.org/standards/shared-mime-info"
LANG = "{http://www.w3.org/XML/1998/namespace}lang"
saida_arq = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/mime/packages/matsu-pt_BR.xml"

saida = ET.Element("mime-info", xmlns=NS)
n = 0
for arq in sorted(glob.glob("/usr/share/mime/packages/*.xml")):
    if "matsu" in arq:
        continue
    for tipo in ET.parse(arq).getroot().findall(f"{{{NS}}}mime-type"):
        # Já tem pt_BR (pacote antigo): não mexe.
        if any(el.get(LANG) == "pt_BR" for el in tipo):
            continue
        novos = [(tag, el.text) for tag in ("comment", "acronym", "expanded-acronym")
                 for el in tipo.findall(f"{{{NS}}}{tag}") if el.get(LANG) == "pt-BR" and el.text]
        if novos:
            t = ET.SubElement(saida, "mime-type", type=tipo.get("type"))
            for tag, texto in novos:
                e = ET.SubElement(t, tag)
                e.set("xml:lang", "pt_BR")
                e.text = texto
            n += 1
ET.ElementTree(saida).write(saida_arq, encoding="UTF-8", xml_declaration=True)
print(f"tipos de arquivo traduzidos para pt_BR: {n}")
