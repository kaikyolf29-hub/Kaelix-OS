#!/usr/bin/env python3
"""Testes do build_files/telas-matsu.py (a tela de bloqueio do Matsu).

O arquivo de exemplo é o LockScreenUi.qml do Plasma 6.6 (tests/dados/telas/).
Quando o Plasma da imagem mudar, ponha o arquivo novo ao lado (o fluxo
"Extrair arquivos da imagem" copia ele para o ramo "extraidos").
"""
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("telas_matsu", RAIZ / "build_files/telas-matsu.py")
T = importlib.util.module_from_spec(spec)
spec.loader.exec_module(T)
EXEMPLOS = sorted(p for p in (RAIZ / "tests/dados/telas").glob("LockScreenUi-*.qml") if not p.stem.endswith("-trocado"))
BLOCO = RAIZ / "system_files/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/MatsuBloco.qml"


class Bloqueio(unittest.TestCase):
    def test_tem_exemplo(self):
        self.assertTrue(EXEMPLOS)

    def test_troca_em_cada_versao_do_plasma(self):
        for exemplo in EXEMPLOS:
            with self.subTest(exemplo.name):
                novo, problemas = T.trocar(exemplo.read_text(encoding="utf-8"))
                self.assertEqual(problemas, [])
                self.assertIn(T.IMPORTE, novo)
                self.assertIn("initialItem: MatsuBloco {", novo)
                self.assertIn("Matsu.Relogio {", novo)
                self.assertIn("Matsu.Fundo {", novo)
                self.assertNotIn("WallpaperFader", novo)
                self.assertNotIn("clockShadow", novo)
                # O que destrava continua o do KDE.
                for parte in ("authenticator.respond(password)", "onPasswordResult", "VirtualKeyboardLoader", "rejectPasswordAnimation"):
                    self.assertIn(parte, novo)
                # As chaves continuam fechando.
                self.assertEqual(novo.count("{"), novo.count("}"))

    def test_segunda_vez_nao_mexe(self):
        texto = EXEMPLOS[0].read_text(encoding="utf-8")
        novo, _ = T.trocar(texto)
        de_novo, problemas = T.trocar(novo)
        self.assertEqual(de_novo, novo)
        self.assertEqual(problemas, ["já trocado antes"])

    def test_arquivo_diferente_fica_como_veio(self):
        texto = EXEMPLOS[0].read_text(encoding="utf-8").replace("initialItem: MainBlock {", "initialItem: OutroBloco {")
        novo, problemas = T.trocar(texto)
        self.assertEqual(novo, texto)
        self.assertTrue(problemas)

    def test_main_na_pasta(self):
        with tempfile.TemporaryDirectory() as d:
            pasta = Path(d)
            (pasta / "LockScreenUi.qml").write_text(EXEMPLOS[0].read_text(encoding="utf-8"), encoding="utf-8")
            sys.argv = ["telas-matsu.py", str(pasta)]
            T.PASTA = pasta
            T.ORIGINAIS = pasta / "originais"
            T.main()  # sem o MatsuBloco: fica como veio
            self.assertIn("MainBlock", (pasta / "LockScreenUi.qml").read_text(encoding="utf-8"))
            (pasta / "MatsuBloco.qml").write_text(BLOCO.read_text(encoding="utf-8"), encoding="utf-8")
            T.main()
            self.assertIn("MatsuBloco", (pasta / "LockScreenUi.qml").read_text(encoding="utf-8"))

    def test_bloco_aceita_tudo_que_cada_plasma_passa(self):
        """O que o LockScreenUi de cada versão passa para o bloco (e lê dele) existe no MatsuBloco.

        Se faltar uma propriedade, a tela de bloqueio inteira não carrega (o KDE mostra
        a tela de emergência). O Plasma 6.8 passou a usar authenticationTypeItem e
        passwordInputVisible.
        """
        import re
        bloco = BLOCO.read_text(encoding="utf-8")
        nomes = set(re.findall(r"(?:property\s+[\w<>.]+|property alias|signal)\s+(\w+)", bloco))
        nomes |= {"enabled", "focus", "visible", "id"}
        trocados = sorted((RAIZ / "tests/dados/telas").glob("LockScreenUi-*-trocado.qml"))
        self.assertTrue(trocados)
        for exemplo in EXEMPLOS + trocados:
            texto = exemplo.read_text(encoding="utf-8")
            if "initialItem: MatsuBloco {" not in texto:
                texto, _ = T.trocar(texto)
            inicio = texto.index("initialItem: MatsuBloco {")
            recuo = len(texto[:inicio]) - len(texto[:inicio].rstrip(" ")) + 4
            # Só o bloco do MatsuBloco (até a chave que fecha a dele).
            fim, nivel = texto.index("{", inicio), 0
            for fim in range(fim, len(texto)):
                nivel += {"{": 1, "}": -1}.get(texto[fim], 0)
                if nivel == 0:
                    break
            passados = set(re.findall(r"^ {%d}(\w+)\s*:" % recuo, texto[inicio:fim], re.M))
            sinais = {re.sub(r"^on([A-Z])", lambda m: m.group(1).lower(), n) for n in passados if re.match(r"on[A-Z]", n)}
            usados = set(re.findall(r"\bmainBlock\.(\w+)", texto))
            for nome in sorted((passados - {n for n in passados if re.match(r"on[A-Z]", n)}) | sinais | usados):
                with self.subTest(exemplo=exemplo.name, nome=nome):
                    self.assertIn(nome, nomes)

    def test_bloco_tem_o_que_o_lockscreenui_usa(self):
        bloco = BLOCO.read_text(encoding="utf-8")
        for nome in ("mainPasswordBox", "lockScreenUiVisible", "showPassword", "userListModel", "showUserList",
                     "notificationMessage", "actionItems", "visibleBoundary", "signal passwordResult", "PasswordSync"):
            self.assertIn(nome, bloco)


SAIR = RAIZ / "system_files/usr/share/matsu/telas/sair"
TELAS = RAIZ / "system_files/usr/share/matsu/telas"


class Sair(unittest.TestCase):
    """A tela de sair do Matsu entra no lugar da Logout.qml da Breeze (Plasma 6.6)."""

    def test_tem_os_sinais_que_o_kde_liga(self):
        tela = (SAIR / "Logout.qml").read_text(encoding="utf-8")
        for sinal in ("logoutRequested()", "haltRequested()", "haltUpdateRequested()", "suspendRequested(int spdMethod)",
                      "rebootRequested()", "rebootRequested2(int opt)", "rebootUpdateRequested()", "cancelRequested()",
                      "lockScreenRequested()", "cancelSoftwareUpdateRequested()"):
            self.assertIn("signal " + sinal, tela)
        # O que o KDE passa para a tela continua sendo usado.
        for nome in ("sdtype", "maysd", "spdMethods", "canLogout", "softwareUpdatePending", "screenGeometry",
                     "rebootToFirmwareSetup", "rebootToBootLoaderMenu", "rebootToBootLoaderEntry"):
            self.assertIn(nome, tela)
        self.assertTrue((SAIR / "contagem.js").is_file())
        self.assertIn('import "contagem.js" as Contagem', tela)

    def test_pecas_existem(self):
        tela = (SAIR / "Logout.qml").read_text(encoding="utf-8")
        qmldir = (TELAS / "qmldir").read_text(encoding="utf-8")
        for peca in sorted(set(__import__("re").findall(r"Matsu\.([A-Z]\w+)", tela))):
            with self.subTest(peca):
                self.assertIn(f"{peca} 1.0 {peca}.qml", qmldir)
                self.assertTrue((TELAS / f"{peca}.qml").is_file())
        icones = RAIZ / "system_files/usr/share/icons/Matsu/status/symbolic"
        for icone in ("matsu-lua", "matsu-hibernar", "matsu-reiniciar", "matsu-desligar", "matsu-sair"):
            self.assertTrue((icones / f"{icone}-symbolic.svg").is_file(), icone)

    def _montar(self, base, plasma68):
        shell = base / "shells/org.kde.plasma.desktop/contents"
        (shell / "lockscreen").mkdir(parents=True)
        visuais = base / "look-and-feel"
        for v in ("org.matsu.escuro.desktop", "org.matsu.claro.desktop"):
            (visuais / v / "contents").mkdir(parents=True)
        if plasma68:
            (shell / "logout").mkdir()
            (shell / "logout/Logout.qml").write_text("// do KDE\n", encoding="utf-8")
            (shell / "logout/timer.js").write_text("// do KDE\n", encoding="utf-8")
        T.PASTA, T.VISUAIS, T.SAIR_MATSU, T.ORIGINAIS = shell / "lockscreen", visuais, SAIR, base / "originais"
        return shell, visuais

    def test_plasma_68_no_pacote_do_shell(self):
        with tempfile.TemporaryDirectory() as d:
            shell, visuais = self._montar(Path(d), True)
            feitas = T.trocar_sair()
            self.assertEqual(feitas, [shell / "logout"])
            self.assertIn("contagem.js", (shell / "logout/Logout.qml").read_text(encoding="utf-8"))
            self.assertTrue((shell / "logout/contagem.js").is_file())
            # O timer.js do KDE fica (outras peças do KDE usam).
            self.assertTrue((shell / "logout/timer.js").is_file())
            self.assertEqual((Path(d) / "originais/Logout.qml").read_text(encoding="utf-8"), "// do KDE\n")
            # Segunda vez não guarda o nosso por cima do original.
            T.trocar_sair()
            self.assertEqual((Path(d) / "originais/Logout.qml").read_text(encoding="utf-8"), "// do KDE\n")
            self.assertFalse((visuais / "org.matsu.escuro.desktop/contents/logout").exists())

    def test_plasma_66_no_visual_do_matsu(self):
        with tempfile.TemporaryDirectory() as d:
            shell, visuais = self._montar(Path(d), False)
            feitas = T.trocar_sair()
            self.assertEqual(len(feitas), 2)
            for v in ("org.matsu.escuro.desktop", "org.matsu.claro.desktop"):
                self.assertTrue((visuais / v / "contents/logout/Logout.qml").is_file())
                self.assertTrue((visuais / v / "contents/logout/contagem.js").is_file())


if __name__ == "__main__":
    unittest.main()
