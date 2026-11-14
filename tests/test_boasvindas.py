#!/usr/bin/env python3
"""Testes das Boas-vindas do Matsu (system_files/usr/share/matsu/boasvindas).

Confere que o atalho, o autostart e as telas batem entre si, e que o
matsu-boas-vindas (o que roda no login) abre só uma vez.
"""
import os
import re
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
SISTEMA = RAIZ / "system_files"
PASTA = SISTEMA / "usr/share/matsu/boasvindas"
ATALHO = SISTEMA / "usr/share/applications/org.matsu.boasvindas.desktop"
AUTOSTART = SISTEMA / "etc/xdg/autostart/org.matsu.boasvindas.desktop"
ABRIDOR = SISTEMA / "usr/libexec/matsu/matsu-boas-vindas"


def chaves(arquivo):
    saida = {}
    for linha in arquivo.read_text(encoding="utf-8").splitlines():
        if "=" in linha and not linha.startswith("#"):
            k, v = linha.split("=", 1)
            saida.setdefault(k, v)
    return saida


class Arquivos(unittest.TestCase):
    def test_atalho_abre_a_janela_certa(self):
        a = chaves(ATALHO)
        exe, app, qml = a["Exec"].split()
        self.assertEqual(exe, "/usr/libexec/matsu/matsu-janela")
        self.assertEqual(app, "org.matsu.boasvindas")
        self.assertEqual(a["StartupWMClass"], app)
        self.assertTrue((SISTEMA / qml.lstrip("/")).is_file(), qml)
        self.assertEqual(a["Name[pt_BR]"], "Boas-vindas")

    def test_autostart_chama_o_abridor(self):
        a = chaves(AUTOSTART)
        self.assertEqual(a["Exec"], "/usr/libexec/matsu/matsu-boas-vindas")
        self.assertEqual(a["NoDisplay"], "true")
        self.assertTrue(ABRIDOR.stat().st_mode & stat.S_IXUSR, "o abridor precisa ser executável")

    def test_cada_tela_tem_arquivo(self):
        main = (PASTA / "Main.qml").read_text(encoding="utf-8")
        lista = re.search(r"telas:\s*\[([^\]]*)\]", main).group(1)
        telas = re.findall(r'"(\w+)"', lista)
        self.assertEqual(telas[0], "ola")
        self.assertEqual(telas[-1], "pronto")
        for nome in telas:
            arquivo = PASTA / f"Tela{nome[0].upper()}{nome[1:]}.qml"
            self.assertTrue(arquivo.is_file(), arquivo.name)

    def test_navegadores_sem_logo_inventado(self):
        # Brave e Chrome aparecem só com o nome; o único ícone é o do Firefox
        # (o oficial, que já vem instalado).
        texto = (PASTA / "TelaNavegador.qml").read_text(encoding="utf-8").lower()
        icones = re.findall(r'(?:source|icone):\s*"([^"]+)"', texto)
        for icone in icones:
            self.assertNotIn("brave", icone)
            self.assertNotIn("chrome", icone)


class Abridor(unittest.TestCase):
    """Roda o matsu-boas-vindas com kstart e pgrep de mentira."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.config = base / "config"
        self.bin = base / "bin"
        self.bin.mkdir()
        self.chamadas = base / "chamadas"
        self.pgrep_acha = base / "pgrep-acha"
        for nome, corpo in {
            "kstart": f'echo "kstart $*" >> "{self.chamadas}"',
            "pgrep": f'[ -e "{self.pgrep_acha}" ]',
        }.items():
            arquivo = self.bin / nome
            arquivo.write_text(f"#!/bin/sh\n{corpo}\n")
            arquivo.chmod(0o755)

    def tearDown(self):
        self.tmp.cleanup()

    def rodar(self):
        env = dict(os.environ, XDG_CONFIG_HOME=str(self.config), PATH=f"{self.bin}:/usr/bin:/bin")
        r = subprocess.run(["bash", str(ABRIDOR)], env=env, capture_output=True, text=True, timeout=20)
        self.assertEqual(r.returncode, 0, r.stderr)
        return self.chamadas.read_text() if self.chamadas.exists() else ""

    def test_primeira_vez_abre(self):
        self.assertEqual(self.rodar().strip(), "kstart --application org.matsu.boasvindas")

    def test_depois_de_vista_nao_abre(self):
        (self.config / "matsu").mkdir(parents=True)
        (self.config / "matsu/boas-vindas-vista").write_text("vista\n")
        self.assertEqual(self.rodar(), "")

    def test_ja_aberta_nao_abre_outra(self):
        self.pgrep_acha.touch()
        self.assertEqual(self.rodar(), "")

    def test_marca_igual_a_da_janela(self):
        main = (PASTA / "Main.qml").read_text(encoding="utf-8")
        self.assertIn('matsu.pasta("config") + "/boas-vindas-vista"', main)
        self.assertIn('"$config/matsu/boas-vindas-vista"', ABRIDOR.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
