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
EXEMPLOS = sorted((RAIZ / "tests/dados/telas").glob("LockScreenUi-*.qml"))
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
            T.main()  # sem o MatsuBloco: fica como veio
            self.assertIn("MainBlock", (pasta / "LockScreenUi.qml").read_text(encoding="utf-8"))
            (pasta / "MatsuBloco.qml").write_text(BLOCO.read_text(encoding="utf-8"), encoding="utf-8")
            T.main()
            self.assertIn("MatsuBloco", (pasta / "LockScreenUi.qml").read_text(encoding="utf-8"))

    def test_bloco_tem_o_que_o_lockscreenui_usa(self):
        bloco = BLOCO.read_text(encoding="utf-8")
        for nome in ("mainPasswordBox", "lockScreenUiVisible", "showPassword", "userListModel", "showUserList",
                     "notificationMessage", "actionItems", "visibleBoundary", "signal passwordResult", "PasswordSync"):
            self.assertIn(nome, bloco)


SAIR = RAIZ / "system_files/usr/share/plasma/look-and-feel/org.matsu.escuro.desktop/contents/logout"
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
        self.assertTrue((SAIR / "timer.js").is_file())

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


if __name__ == "__main__":
    unittest.main()
