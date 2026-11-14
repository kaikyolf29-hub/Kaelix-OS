#!/usr/bin/env python3
"""Testes do build_files/primeiro-uso.py (textos do assistente de primeiro uso).

Monta um catálogo .mo parecido com o do KDE, roda a troca e lê de volta com o
módulo gettext do Python (o mesmo formato que o KDE lê).
"""
import gettext
import importlib.util
import tempfile
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("primeiro_uso", RAIZ / "build_files/primeiro-uso.py")
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)

CABECA = (b"", b"Content-Type: text/plain; charset=UTF-8\nPlural-Forms: nplurals=2; plural=(n > 1);\n")
PARES = [
    CABECA,
    (b"Welcome to<br/><b>Plasma Desktop</b>", "Bem-vindo ao<br/><b>Plasma Desktop</b>".encode()),
    (b"%1 is the distro name\x04Powered by<br/><b>%1</b>", "Fornecido por<br/><b>%1</b>".encode()),
    (b"@action:button\x04Next", "Próximo".encode()),
    (b"Begin Setup", "Iniciar configuração".encode()),
    (b"%1 minute\x00%1 minutes", "%1 minuto\x00%1 minutos".encode()),
]


class PrimeiroUso(unittest.TestCase):
    def _catalogo(self, base, pares=PARES):
        pasta = base / "pt_BR/LC_MESSAGES"
        pasta.mkdir(parents=True)
        arquivo = pasta / P.CATALOGO
        arquivo.write_bytes(P.gravar_mo(pares))
        return arquivo

    def test_le_o_que_grava(self):
        self.assertEqual(sorted(P.ler_mo(P.gravar_mo(PARES))), sorted(PARES))

    def test_troca_so_as_frases_da_entrada(self):
        with tempfile.TemporaryDirectory() as d:
            arquivo = self._catalogo(Path(d))
            self.assertEqual(P.trocar(arquivo, P.TROCAS["pt_BR"]), 2)
            with arquivo.open("rb") as f:
                t = gettext.GNUTranslations(f)
            self.assertEqual(t.gettext("Welcome to<br/><b>Plasma Desktop</b>"), "Bem-vindo ao<br/><b>Matsu</b>")
            self.assertEqual(t.pgettext("%1 is the distro name", "Powered by<br/><b>%1</b>"), "<b>%1</b>")
            # O resto fica igual, plural incluído.
            self.assertEqual(t.pgettext("@action:button", "Next"), "Próximo")
            self.assertEqual(t.gettext("Begin Setup"), "Iniciar configuração")
            self.assertEqual(t.ngettext("%1 minute", "%1 minutes", 3), "%1 minutos")

    def test_frase_que_mudou_fica_como_veio(self):
        with tempfile.TemporaryDirectory() as d:
            pares = [CABECA, (b"Welcome to Plasma", "Bem-vindo ao Plasma".encode())]
            arquivo = self._catalogo(Path(d), pares)
            antes = arquivo.read_bytes()
            self.assertEqual(P.trocar(arquivo, P.TROCAS["pt_BR"]), 0)
            self.assertEqual(arquivo.read_bytes(), antes)

    def test_main_sem_catalogo_nao_quebra(self):
        with tempfile.TemporaryDirectory() as d:
            P.LOCALE = Path(d)
            self.assertEqual(P.main(), 0)

    def test_main_com_catalogo(self):
        with tempfile.TemporaryDirectory() as d:
            arquivo = self._catalogo(Path(d))
            P.LOCALE = Path(d)
            P.main()
            textos = dict(P.ler_mo(arquivo.read_bytes()))
            self.assertEqual(textos[b"Welcome to<br/><b>Plasma Desktop</b>"].decode(), "Bem-vindo ao<br/><b>Matsu</b>")


if __name__ == "__main__":
    unittest.main()
