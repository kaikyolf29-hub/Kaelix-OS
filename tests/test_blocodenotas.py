#!/usr/bin/env python3
"""Testes do Bloco de notas (system_files/usr/share/matsu/blocodenotas/).

Duas partes:
- o ajudante.py (o que o arquivo tem: tamanho, binário, codificação, fim de
  linha; ler e gravar sem trocar a codificação nem deixar o arquivo pela metade);
- o logica.js, a parte da janela sem tela (fim de linha, busca, linha e coluna,
  a sessão e os ajustes). Ele roda no node, como o QML roda: o teste tira a linha
  ".pragma library" e chama as funções. Sem node, essa parte é pulada.

Uso: python3 tests/test_blocodenotas.py
"""
import importlib.util
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PASTA = Path(__file__).resolve().parents[1] / "system_files/usr/share/matsu/blocodenotas"
AJUDANTE = PASTA / "ajudante.py"
LOGICA = PASTA / "logica.js"


def carregar():
    spec = importlib.util.spec_from_file_location("ajudante_bloco", AJUDANTE)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


aj = carregar()


def rodar(*args, cwd=None, env=None):
    """Roda o ajudante como a janela roda (python3 -I -S) e devolve (código, JSON)."""
    r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), *args], capture_output=True, text=True,
                       cwd=cwd, env=env, timeout=20)
    try:
        dados = json.loads(r.stdout)
    except ValueError:
        dados = None
    return r.returncode, dados


class Pasta(unittest.TestCase):
    def setUp(self):
        self.pasta = Path(tempfile.mkdtemp(prefix="bloco-"))

    def tearDown(self):
        shutil.rmtree(self.pasta, ignore_errors=True)

    def arquivo(self, nome, dados):
        p = self.pasta / nome
        p.write_bytes(dados)
        return str(p)


class TestExaminar(Pasta):
    def test_utf8_lf(self):
        r = aj.examinar(self.arquivo("compras.txt", "Lista de compras\n\n- arroz\n- feijão\n".encode()))
        self.assertTrue(r["existe"] and r["legivel"])
        self.assertEqual(r["codificacao"], "utf-8")
        self.assertEqual(r["fim"], "lf")
        self.assertFalse(r["binario"])
        self.assertFalse(r["grande"])
        self.assertEqual(r["tamanho"], len("Lista de compras\n\n- arroz\n- feijão\n".encode()))

    def test_fim_de_linha(self):
        self.assertEqual(aj.examinar(self.arquivo("a", b"um\r\ndois\r\n"))["fim"], "crlf")
        self.assertEqual(aj.examinar(self.arquivo("b", b"um\rdois\r"))["fim"], "cr")
        self.assertEqual(aj.examinar(self.arquivo("c", b"sem quebra"))["fim"], "")
        # Misturado: vale o que aparece mais.
        self.assertEqual(aj.examinar(self.arquivo("d", b"a\r\nb\r\nc\nd\r\n"))["fim"], "crlf")
        self.assertEqual(aj.examinar(self.arquivo("e", b"a\nb\nc\r\n"))["fim"], "lf")

    def test_bom_e_utf16(self):
        self.assertEqual(aj.examinar(self.arquivo("bom", b"\xef\xbb\xbfOl\xc3\xa1\r\n"))["codificacao"], "utf-8-bom")
        le = self.arquivo("le", "﻿Olá\r\nmundo".encode("utf-16-le"))
        r = aj.examinar(le)
        self.assertEqual(r["codificacao"], "utf-16-le")
        self.assertFalse(r["binario"], "UTF-16 tem bytes nulos, mas é texto")
        self.assertEqual(r["fim"], "crlf")
        self.assertEqual(aj.examinar(self.arquivo("be", "﻿Oi\n".encode("utf-16-be")))["codificacao"], "utf-16-be")

    def test_windows_1252_e_latin1(self):
        self.assertEqual(aj.examinar(self.arquivo("w", "Olá, açúcar – café".encode("cp1252")))["codificacao"], "windows-1252")
        # 0x81 não existe no Windows-1252: só pode ser ISO-8859-1.
        self.assertEqual(aj.examinar(self.arquivo("l", b"ol\xe1 \x81"))["codificacao"], "iso-8859-1")

    def test_binario(self):
        self.assertTrue(aj.examinar(self.arquivo("prog", b"\x7fELF\x02\x01\x01\x00\x00\x00" + bytes(range(256))))["binario"])
        self.assertTrue(aj.examinar(self.arquivo("png", b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"))["binario"])
        # Muitos caracteres de controle, mesmo sem o nulo.
        self.assertTrue(aj.examinar(self.arquivo("ctrl", bytes([1, 2, 3, 4, 5, 6, 7, 65] * 50)))["binario"])
        # Texto com tab, ESC (cores do terminal) e form feed não é binário.
        self.assertFalse(aj.examinar(self.arquivo("log", b"\x1b[31merro\x1b[0m\tlinha\x0c\n" * 20))["binario"])
        self.assertFalse(aj.examinar(self.arquivo("vazio", b""))["binario"])

    def test_utf8_cortado_na_amostra(self):
        """Um "ã" cortado no fim da amostra não faz o arquivo virar Windows-1252."""
        antigo = aj.AMOSTRA
        try:
            aj.AMOSTRA = 11
            r = aj.examinar(self.arquivo("corte", "abcdefghijã resto".encode()))
            self.assertEqual(r["codificacao"], "utf-8")
        finally:
            aj.AMOSTRA = antigo

    def test_grande(self):
        antigo = aj.LIMITE_GRANDE
        try:
            aj.LIMITE_GRANDE = 100
            self.assertTrue(aj.examinar(self.arquivo("g", b"x" * 101))["grande"])
            self.assertFalse(aj.examinar(self.arquivo("p", b"x" * 100))["grande"])
        finally:
            aj.LIMITE_GRANDE = antigo
        self.assertEqual(aj.LIMITE_GRANDE, 20 * 1024 * 1024)

    def test_nao_existe_e_pasta(self):
        r = aj.examinar(str(self.pasta / "nada.txt"))
        self.assertFalse(r["existe"])
        r = aj.examinar(str(self.pasta))
        self.assertTrue(r["existe"] and r["pasta"])

    @unittest.skipIf(os.geteuid() == 0, "root lê qualquer arquivo")
    def test_sem_permissao(self):
        p = self.arquivo("fechado", b"segredo")
        os.chmod(p, 0)
        r = aj.examinar(p)
        self.assertTrue(r["existe"])
        self.assertFalse(r["legivel"])

    def test_linha_de_comando_resolve_caminho_relativo(self):
        self.arquivo("rel.txt", b"oi\n")
        codigo, r = rodar("examinar", "rel.txt", cwd=self.pasta)
        self.assertEqual(codigo, 0)
        self.assertTrue(r["existe"])
        self.assertEqual(r["caminho"], str(self.pasta / "rel.txt"))


class TestLerGravar(Pasta):
    def test_ler_codificacoes(self):
        self.assertEqual(aj.ler_arquivo(self.arquivo("w", "Olá, café".encode("cp1252")), "windows-1252"), "Olá, café")
        self.assertEqual(aj.ler_arquivo(self.arquivo("le", "﻿Olá".encode("utf-16-le")), "utf-16-le"), "Olá")
        self.assertEqual(aj.ler_arquivo(self.arquivo("bom", b"\xef\xbb\xbfOi"), "utf-8-bom"), "Oi")
        # Fim de linha fica como está (a janela converte).
        self.assertEqual(aj.ler_arquivo(self.arquivo("crlf", "a\r\nb".encode("cp1252")), "windows-1252"), "a\r\nb")

    def test_ler_pela_linha_de_comando(self):
        p = self.arquivo("w", "Pão de queijo\n".encode("cp1252"))
        codigo, r = rodar("ler", p, "windows-1252")
        self.assertEqual(codigo, 0)
        self.assertEqual(r["texto"], "Pão de queijo\n")

    def gravar(self, texto, destino, cod):
        origem = self.pasta / "passagem.txt"
        origem.write_text(texto, encoding="utf-8", newline="")
        r = aj.gravar(str(origem), destino, cod)
        self.assertFalse(origem.exists(), "o arquivo de passagem é apagado")
        return r

    def test_gravar_mantem_codificacao(self):
        destino = str(self.pasta / "saida.txt")
        self.assertTrue(self.gravar("Olá\r\ncafé", destino, "windows-1252")["ok"])
        self.assertEqual(Path(destino).read_bytes(), "Olá\r\ncafé".encode("cp1252"))
        self.assertTrue(self.gravar("Olá", destino, "utf-16-le")["ok"])
        self.assertEqual(Path(destino).read_bytes(), b"\xff\xfe" + "Olá".encode("utf-16-le"))
        self.assertTrue(self.gravar("Oi", destino, "utf-8-bom")["ok"])
        self.assertEqual(Path(destino).read_bytes(), b"\xef\xbb\xbfOi")
        # O BOM não sai duas vezes.
        self.assertTrue(self.gravar("﻿Oi", destino, "utf-8-bom")["ok"])
        self.assertEqual(Path(destino).read_bytes(), b"\xef\xbb\xbfOi")

    def test_gravar_caractere_que_nao_cabe(self):
        destino = self.arquivo("velho.txt", b"original")
        r = self.gravar("emoji 😀", destino, "windows-1252")
        self.assertFalse(r["ok"])
        self.assertEqual(r["erro"], "caracteres")
        self.assertEqual(r["caractere"], "😀")
        self.assertEqual(Path(destino).read_bytes(), b"original", "o arquivo antigo fica intacto")

    def test_gravar_mantem_permissoes_e_segue_link(self):
        alvo = self.arquivo("script.sh", b"echo velho\n")
        os.chmod(alvo, 0o750)
        link = self.pasta / "atalho.sh"
        os.symlink(alvo, link)
        self.assertTrue(self.gravar("echo novo\n", str(link), "iso-8859-1")["ok"])
        self.assertTrue(link.is_symlink(), "o link continua link")
        self.assertEqual(Path(alvo).read_bytes(), b"echo novo\n")
        self.assertEqual(stat.S_IMODE(os.stat(alvo).st_mode), 0o750)
        self.assertEqual([p.name for p in self.pasta.iterdir() if p.name.startswith(".matsu-")], [])

    def test_gravar_pasta_que_nao_existe(self):
        r = self.gravar("x", str(self.pasta / "nao" / "existe.txt"), "windows-1252")
        self.assertFalse(r["ok"])

    def test_gravar_pela_linha_de_comando(self):
        origem = self.pasta / "p.txt"
        origem.write_text("Ação\n", encoding="utf-8")
        destino = str(self.pasta / "d.txt")
        codigo, r = rodar("gravar", str(origem), destino, "windows-1252")
        self.assertEqual((codigo, r), (0, {"ok": True}))
        self.assertEqual(Path(destino).read_bytes(), "Ação\n".encode("cp1252"))


class TestAmbiente(Pasta):
    def test_idioma_e_vidro(self):
        env = {"PATH": os.environ.get("PATH", ""), "HOME": str(self.pasta), "LANG": "pt_BR.UTF-8",
               "XDG_CONFIG_HOME": str(self.pasta / "cfg")}
        (self.pasta / "cfg" / "matsu").mkdir(parents=True)
        (self.pasta / "cfg" / "matsu" / "vidro").write_text("cor=verde\ntransparencia=sem\n")
        codigo, r = rodar("ambiente", env=env)
        self.assertEqual(codigo, 0)
        self.assertEqual(r["idioma"], "pt")
        self.assertEqual(r["vidro"], {"cor": "#22c55e", "nivel": "sem"})
        env["LANG"] = "en_US.UTF-8"
        self.assertEqual(rodar("ambiente", env=env)[1]["idioma"], "en")

    def test_comando_errado(self):
        self.assertEqual(rodar("voar")[0], 2)
        self.assertEqual(rodar("examinar")[0], 2)


NODE = shutil.which("node")


def js(*chamadas):
    """Chama funções do logica.js no node: js(["detectarFim", "a\\r\\n"], ...) -> [resultado, ...]."""
    codigo = LOGICA.read_text(encoding="utf-8").replace(".pragma library", "", 1)
    programa = (
        "const vm = require('vm'); const ctx = {}; vm.createContext(ctx);"
        "vm.runInContext(" + json.dumps(codigo) + ", ctx);"
        "const chamadas = " + json.dumps(chamadas) + ";"
        "process.stdout.write(JSON.stringify(chamadas.map(([f, ...a]) => {"
        "  const r = ctx[f](...a); return r === undefined ? null : r; })));"
    )
    r = subprocess.run([NODE, "-e", programa], capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        raise AssertionError(r.stderr)
    return json.loads(r.stdout)


@unittest.skipUnless(NODE, "sem node")
class TestLogica(unittest.TestCase):
    def test_fim_de_linha(self):
        self.assertEqual(js(["detectarFim", "a\r\nb\r\n"], ["detectarFim", "a\nb"], ["detectarFim", "a\rb"],
                            ["detectarFim", "nada"], ["detectarFim", "a\r\nb\nc\r\n"]),
                         ["crlf", "lf", "cr", "", "crlf"])
        # Ida e volta: o editor só vê "\n"; o arquivo volta com o fim de linha dele.
        editor, volta, mac = js(["paraEditor", "um\r\ndois\rtrês\n"], ["paraArquivo", "um\ndois\n", "crlf"],
                                ["paraArquivo", "a\nb", "cr"])
        self.assertEqual(editor, "um\ndois\ntrês\n")
        self.assertEqual(volta, "um\r\ndois\r\n")
        self.assertEqual(mac, "a\rb")
        self.assertEqual(js(["nomeFim", "crlf", True], ["nomeFim", "lf", True], ["nomeCodificacao", "utf-8-bom", True]),
                         ["Windows (CRLF)", "Unix (LF)", "UTF-8 com BOM"])

    def test_binario_sem_ajudante(self):
        self.assertEqual(js(["pareceBinario", "texto normal\n"], ["pareceBinario", "ELF\u0000\u0001"],
                            ["pareceBinario", "�" * 50 + "abc"], ["pareceBinario", ""]),
                         [False, True, True, False])

    def test_busca(self):
        texto = "Sol, sol e girassol. SOL!"
        self.assertEqual(js(["buscar", texto, "sol", False, False, 0]), [[0, 5, 16, 21]])
        self.assertEqual(js(["buscar", texto, "sol", True, False, 0]), [[5, 16]])
        # Palavra inteira: não acha dentro de "girassol".
        self.assertEqual(js(["buscar", texto, "sol", False, True, 0]), [[0, 5, 21]])
        # Acentos contam como letra para a palavra inteira; símbolos de regex são texto.
        self.assertEqual(js(["buscar", "pão pãozinho", "pão", False, True, 0], ["buscar", "a.b a+b (a)", "a+b", False, False, 0],
                            ["buscar", "x", "", False, False, 0], ["buscar", "aaaa", "aa", False, False, 0],
                            ["buscar", "AÇÚCAR açúcar", "açúcar", False, False, 0]),
                         [[0], [4], [], [0, 2], [0, 7]])
        self.assertEqual(len(js(["buscar", "a" * 50, "a", False, False, 10])[0]), 10)
        self.assertEqual(js(["proximoAchado", [2, 8, 20], 9], ["proximoAchado", [2, 8, 20], 21],
                            ["achadoAnterior", [2, 8, 20], 8], ["achadoAnterior", [2, 8, 20], 2],
                            ["proximoAchado", [], 0]),
                         [2, 0, 0, 2, -1])

    def test_trocar_tudo(self):
        r = js(["trocarTudo", "um sol, dois sóis, três sol", "sol", "lua", True, True])[0]
        self.assertEqual(r["n"], 2)
        texto = "um sol, dois sóis, três sol"
        self.assertEqual(texto[:r["inicio"]] + r["trecho"] + texto[r["fim"]:], "um lua, dois sóis, três lua")
        self.assertEqual(js(["trocarTudo", "nada", "x", "y", False, False])[0]["n"], 0)

    def test_linhas(self):
        self.assertEqual(js(["linhaColuna", "ab\ncd\nef", 0], ["linhaColuna", "ab\ncd\nef", 4],
                            ["linhaColuna", "ab\ncd\nef", 8], ["linhaColuna", "ab\n", 3]),
                         [{"linha": 1, "coluna": 1}, {"linha": 2, "coluna": 2}, {"linha": 3, "coluna": 3},
                          {"linha": 2, "coluna": 1}])
        self.assertEqual(js(["inicioDaLinha", "ab\ncd\nef", 3], ["inicioDaLinha", "ab\ncd", 4], ["inicioDaLinha", "x", 0],
                            ["contarLinhas", "a\nb\n"], ["iniciosDasLinhas", "a\nbc\n"], ["linhaDaPosicao", [0, 2, 5], 4]),
                         [6, -1, -1, 3, [0, 2, 5], 1])

    def test_nomes_e_caminhos(self):
        self.assertEqual(js(["caminhoLocal", "file:///home/kaiky/Documentos/a%C3%A7%C3%BAcar%20bom.txt"],
                            ["caminhoLocal", "/tmp/x.txt"], ["nomeDoCaminho", "/a/b/c.md"], ["pastaDoCaminho", "/a/b/c.md"],
                            ["pastaCurta", "/home/k/Documentos/x.txt", "/home/k"],
                            ["proximoSemTitulo", ["Sem título", "Sem título 2"], "Sem título"],
                            ["proximoSemTitulo", ["Sem título 2"], "Sem título"]),
                         ["/home/kaiky/Documentos/açúcar bom.txt", "/tmp/x.txt", "c.md", "/a/b", "~/Documentos",
                          "Sem título 3", "Sem título"])

    def test_ajustes(self):
        padrao, estragado, limites = js(["lerAjustes", ""], ["lerAjustes", "{oops"],
                                        ["lerAjustes", json.dumps({"zoom": 9000, "tamanho": "x", "fonte": "comic",
                                                                   "quebra": False, "recentes": ["/a", "rel", "/a", 3, "/b"]})])
        self.assertEqual(padrao, {"quebra": True, "barraStatus": True, "numeros": False, "fonte": "mono", "tamanho": 11,
                                  "zoom": 100, "lembrar": True, "recentes": []})
        self.assertEqual(estragado, padrao)
        self.assertEqual((limites["zoom"], limites["tamanho"], limites["fonte"], limites["quebra"], limites["recentes"]),
                         (500, 11, "mono", False, ["/a", "/b"]))
        self.assertEqual(js(["adicionarRecente", ["/b", "/a", "/c"], "/a", 10], ["adicionarRecente", ["/1", "/2", "/3"], "/4", 3]),
                         [["/a", "/b", "/c"], ["/4", "/1", "/2"]])

    def test_sessao_ida_e_volta(self):
        abas = [
            {"caminho": "/home/k/compras.txt", "nome": "compras.txt", "texto": "não vai", "modificado": False,
             "fim": "crlf", "codificacao": "utf-8", "cursor": 12, "rolagem": 40},
            {"caminho": "/home/k/ideias.md", "nome": "ideias.md", "texto": "mudado e não salvo", "modificado": True,
             "fim": "lf", "codificacao": "windows-1252", "cursor": 3, "rolagem": 0},
            {"caminho": "", "nome": "Sem título", "texto": "rascunho", "modificado": True, "fim": "lf",
             "codificacao": "utf-8", "cursor": 8, "rolagem": 0},
            # Aba vazia sem arquivo: não volta.
            {"caminho": "", "nome": "Sem título 2", "texto": "", "modificado": False, "fim": "lf",
             "codificacao": "utf-8", "cursor": 0, "rolagem": 0},
        ]
        guardada = js(["montarSessao", abas, 2])[0]
        d = json.loads(guardada)
        self.assertIsNone(d["abas"][0]["texto"], "arquivo salvo volta lendo do disco")
        self.assertEqual(d["abas"][1]["texto"], "mudado e não salvo")
        s = js(["lerSessao", guardada])[0]
        self.assertEqual([a["nome"] for a in s["abas"]], ["compras.txt", "ideias.md", "Sem título"])
        self.assertEqual(s["atual"], 2)
        self.assertEqual(s["abas"][0]["fim"], "crlf")
        self.assertEqual(s["abas"][0]["cursor"], 12)
        self.assertEqual(s["abas"][1]["codificacao"], "windows-1252")
        self.assertTrue(s["abas"][1]["modificado"] and s["abas"][2]["modificado"])
        self.assertFalse(s["abas"][0]["modificado"])

    def test_sessao_estragada(self):
        vazia = {"atual": 0, "abas": []}
        self.assertEqual(js(["lerSessao", ""], ["lerSessao", "{"], ["lerSessao", "[]"], ["lerSessao", '{"abas": 3}']),
                         [vazia] * 4)
        s = js(["lerSessao", json.dumps({"atual": 9, "abas": [
            None, {"caminho": "relativo.txt"}, {"caminho": "/ok.txt", "fim": "??", "codificacao": "klingon", "cursor": -5},
            {"texto": "só texto"}]})])[0]
        self.assertEqual(len(s["abas"]), 2)
        self.assertEqual(s["abas"][0], {"caminho": "/ok.txt", "nome": "ok.txt", "texto": None, "modificado": False,
                                        "fim": "lf", "codificacao": "utf-8", "cursor": 0, "rolagem": 0})
        self.assertEqual(s["abas"][1]["texto"], "só texto")
        self.assertTrue(s["abas"][1]["modificado"])
        self.assertEqual(s["atual"], 1)


if __name__ == "__main__":
    unittest.main(verbosity=1)
