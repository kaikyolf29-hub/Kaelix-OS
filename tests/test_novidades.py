#!/usr/bin/env python3
"""Testes do aviso de atualização e das novidades (system_files/usr/share/matsu/atualizacoes/ajudante.py).

Lê um NOVIDADES.md de mentira e o de verdade do repositório, e confere os avisos
com o rpm-ostree, o skopeo, o flatpak e o notify-send trocados por respostas
prontas (nada roda de verdade e nenhuma notificação aparece).

Uso: python3 tests/test_novidades.py
"""
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
PROGRAMA = RAIZ / "system_files/usr/share/matsu/atualizacoes/ajudante.py"

EXEMPLO = """# Novidades do Matsu OS

Texto de apresentação que não é de nenhuma versão.
- nem este item

## 27.2 · Correções
_3 de março de 2027_

Uma versão pequena,
em duas linhas.

- **Relógio**: o alarme agora
  toca mesmo com o som no mudo.
- **Loja**: [fotos](https://exemplo) maiores e `flatpak` mais rápido.
- Item sem assunto.

## 27.1
_Em preparação_

- **Calendário**: feriados do Brasil.

## Uma seção que não é versão

- não entra

## 27

- **Barra em três ilhas**: menu, apps e bandeja.
"""


def carregar(env):
    antigo = {k: os.environ.get(k) for k in env}
    os.environ.update(env)
    try:
        carregador = importlib.machinery.SourceFileLoader("matsu_novidades_teste", str(PROGRAMA))
        spec = importlib.util.spec_from_loader(carregador.name, carregador)
        modulo = importlib.util.module_from_spec(spec)
        carregador.exec_module(modulo)
        return modulo
    finally:
        for k, v in antigo.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


class Mundo:
    """Os programas do sistema trocados por respostas prontas."""

    def __init__(self, nov, pasta):
        self.nov = nov
        self.pasta = Path(pasta)
        self.booted = "ostree-image-signed:docker://ghcr.io/dono/matsu-os:estavel"
        self.baixada = False
        self.rotulos = None          # None: o skopeo falha (sem internet)
        self.apps = []               # ids com atualização
        self.avisos = []             # (titulo, corpo, acoes)
        self.escolha = ""
        self.soltos = []
        nov.rodar = self.rodar
        nov.avisar = self.avisar
        nov.soltar = self.soltos.append
        nov.shutil.which = lambda nome: "/usr/bin/" + nome
        nov.time.sleep = lambda s: None

    def info(self, versao, build="20270301.10"):
        caminho = self.pasta / "image-info.json"
        caminho.write_text(json.dumps({"versao": versao, "build-id": build, "image-registry": "ghcr.io/dono",
                                       "image-name": "matsu-os"}))
        self.nov.INFO = str(caminho)

    def rodar(self, args, tempo=60):
        if args[:2] == ["rpm-ostree", "status"]:
            impl = [{"booted": True, "container-image-reference": self.booted}]
            if self.baixada:
                impl.insert(0, {"staged": True, "container-image-reference": self.booted})
            return 0, json.dumps({"deployments": impl})
        if args[:2] == ["skopeo", "inspect"]:
            if self.rotulos is None:
                return 1, ""
            self.ref_pedida = args[-1]
            return 0, json.dumps({"Name": "x", "Labels": self.rotulos})
        if args[:2] == ["flatpak", "remote-ls"]:
            return 0, "".join(a + "\n" for a in self.apps)
        if args[:2] == ["flatpak", "list"]:
            return 0, "com.spotify.Client\tSpotify\norg.gimp.GIMP\tGIMP\n"
        raise AssertionError("programa inesperado: %r" % (args,))

    def avisar(self, titulo, corpo, acoes, espera=3600):
        self.avisos.append((titulo, corpo, [a[0] for a in acoes]))
        return self.escolha


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.nov = carregar({"MATSU_LANG": "pt_BR.UTF-8", "XDG_STATE_HOME": self.tmp.name})
        self.estado = Path(self.tmp.name) / "matsu" / "novidades.json"
        self.versoes = self.nov.ler_versoes(EXEMPLO)
        self.mundo = Mundo(self.nov, self.tmp.name)


class Leitura(Base):
    def test_versoes_na_ordem_do_arquivo(self):
        self.assertEqual([v["versao"] for v in self.versoes], ["27.2", "27.1", "27"])

    def test_data_resumo_e_itens(self):
        v = self.versoes[0]
        self.assertEqual(v["titulo"], "27.2 · Correções")
        self.assertEqual(v["data"], "3 de março de 2027")
        self.assertEqual(v["resumo"], "Uma versão pequena, em duas linhas.")
        self.assertEqual(v["itens"][0], {"assunto": "Relógio", "texto": "O alarme agora toca mesmo com o som no mudo."})
        self.assertEqual(v["itens"][1], {"assunto": "Loja", "texto": "Fotos maiores e flatpak mais rápido."})
        self.assertEqual(v["itens"][2], {"assunto": "", "texto": "Item sem assunto."})
        self.assertIn("- **Relógio**", v["markdown"])

    def test_texto_fora_de_versao_fica_de_fora(self):
        tudo = json.dumps(self.versoes, ensure_ascii=False)
        self.assertNotIn("apresentação", tudo)
        self.assertNotIn("não entra", tudo)
        self.assertEqual(len(self.versoes[2]["itens"]), 1)

    def test_ordem_das_versoes(self):
        c = self.nov.chave
        self.assertLess(c("27"), c("27.1"))
        self.assertLess(c("27.1"), c("27.2"))
        self.assertLess(c("27.2"), c("27.10"))
        self.assertLess(c("27.10"), c("28"))
        self.assertEqual(c("v27.1"), (27, 1))
        self.assertEqual(c("abc"), ())
        self.assertEqual(c(""), ())

    def test_lista_curta(self):
        self.assertEqual(self.nov.lista_curta(["A", "B"]), "• A\n• B")
        self.assertEqual(self.nov.lista_curta(["A", "B", "C", "D"]), "• A\n• B\n• C\ne mais 1 novidade.")
        self.assertTrue(self.nov.lista_curta(list("ABCDEF")).endswith("e mais 3 novidades."))

    def test_arquivo_de_verdade(self):
        versoes = self.nov.ler_arquivo(RAIZ / "NOVIDADES.md")
        self.assertTrue(versoes, "o NOVIDADES.md precisa ter pelo menos uma versão")
        edicao = (RAIZ / "EDICAO").read_text().strip()
        for v in versoes:
            self.assertTrue(v["itens"], "a versão %s não tem itens" % v["versao"])
            for item in v["itens"]:
                self.assertTrue(item["assunto"], "item sem **assunto** na %s: %s" % (v["versao"], item["texto"]))
                self.assertTrue(item["texto"][:1].isupper(), item["texto"])
        # A versão de cima é desta edição (27, 27.1...), e elas vêm da mais nova para a mais velha.
        self.assertEqual(versoes[0]["versao"].split(".")[0], edicao)
        chaves = [self.nov.chave(v["versao"]) for v in versoes]
        self.assertEqual(chaves, sorted(chaves, reverse=True))
        self.assertEqual(len(set(chaves)), len(chaves))


class Linha(unittest.TestCase):
    """O programa chamado como a montagem da imagem e o fluxo de publicar chamam."""

    def rodar(self, *args, env=None):
        e = dict(os.environ, MATSU_LANG="pt_BR.UTF-8", **(env or {}))
        return subprocess.run([sys.executable, str(PROGRAMA)] + list(args), capture_output=True, text=True, env=e)

    def test_versao_resumo_e_notas(self):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write(EXEMPLO)
        self.addCleanup(os.unlink, f.name)
        r = self.rodar("--arquivo", f.name, "versao")
        self.assertEqual((r.returncode, r.stdout), (0, "27.2\n"))
        r = self.rodar("--arquivo", f.name, "resumo", "27.2")
        self.assertEqual(json.loads(r.stdout), ["Relógio", "Loja", "Item sem assunto."])
        r = self.rodar("--arquivo", f.name, "notas", "27.1")
        self.assertEqual(r.stdout.strip(), "_Em preparação_\n\n- **Calendário**: feriados do Brasil.")
        r = self.rodar("--arquivo", f.name, "notas", "26.9")
        self.assertEqual(r.returncode, 1)

    def test_arquivo_sem_versao(self):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write("# Nada aqui\n")
        self.addCleanup(os.unlink, f.name)
        r = self.rodar("--arquivo", f.name, "versao")
        self.assertEqual(r.returncode, 1)

    def test_json_para_a_janela(self):
        with tempfile.TemporaryDirectory() as d:
            nov = Path(d) / "novidades.md"
            nov.write_text(EXEMPLO)
            info = Path(d) / "info.json"
            info.write_text(json.dumps({"versao": "27.1", "build-id": "20270101.3"}))
            r = self.rodar("json", env={"MATSU_NOVIDADES": str(nov), "MATSU_IMAGE_INFO": str(info), "XDG_STATE_HOME": d})
        dados = json.loads(r.stdout)
        self.assertEqual((dados["versao"], dados["edicao"], dados["build"]), ("27.1", "27", "20270101.3"))
        self.assertEqual(len(dados["versoes"]), 3)
        self.assertIsNone(dados["remota"])

    def test_comando_desconhecido(self):
        self.assertEqual(self.rodar("xyz").returncode, 2)


class Avisos(Base):
    def ler_estado(self):
        return json.loads(self.estado.read_text())

    def test_primeiro_login_nao_avisa(self):
        self.mundo.info("27.1")
        self.nov.verificar(self.versoes)
        self.assertEqual(self.mundo.avisos, [])
        self.assertEqual(self.ler_estado()["vista"], "27.1")

    def test_depois_de_atualizar_avisa_uma_vez(self):
        self.mundo.info("27.1")
        self.nov.verificar(self.versoes)
        self.mundo.info("27.2")
        self.nov.verificar(self.versoes)
        self.assertEqual(len(self.mundo.avisos), 1)
        titulo, corpo, acoes = self.mundo.avisos[0]
        self.assertEqual(titulo, "O Matsu foi atualizado para a 27.2")
        self.assertEqual(corpo, "• Relógio\n• Loja\n• Item sem assunto.")
        self.assertEqual(acoes, ["ver"])
        self.nov.verificar(self.versoes)
        self.assertEqual(len(self.mundo.avisos), 1)

    def test_edicao_nova_da_boas_vindas(self):
        self.mundo.info("27.2")
        self.nov.verificar(self.versoes)
        self.mundo.info("28")
        self.nov.verificar(self.versoes)
        self.assertEqual(self.mundo.avisos[0][0], "Bem-vindo ao Matsu 28 OS")
        # A 28 não está neste arquivo: o texto fica genérico.
        self.assertEqual(self.mundo.avisos[0][1], "Veja o que mudou nesta versão.")

    def test_voltar_para_a_anterior_nao_avisa(self):
        self.mundo.info("27.2")
        self.nov.verificar(self.versoes)
        self.mundo.info("27.1")
        self.nov.verificar(self.versoes)
        self.assertEqual(self.mundo.avisos, [])
        self.assertEqual(self.ler_estado()["vista"], "27.1")

    def test_versao_nova_no_canal(self):
        self.mundo.info("27.1")
        self.nov.verificar(self.versoes)
        self.mundo.rotulos = {"org.matsu.versao": "27.2", "org.matsu.novidades": json.dumps(["Relógio", "Loja"])}
        self.mundo.escolha = "atualizar"
        self.nov.verificar(self.versoes)
        self.assertEqual(self.mundo.ref_pedida, "docker://ghcr.io/dono/matsu-os:estavel")
        titulo, corpo, acoes = self.mundo.avisos[0]
        self.assertEqual(titulo, "Matsu 27.2 disponível")
        self.assertEqual(corpo, "O que muda:\n• Relógio\n• Loja")
        self.assertEqual(acoes, ["atualizar", "ver"])
        # O botão "Atualizar" abre o terminal com o matsu atualizar (pela central).
        self.assertEqual(self.mundo.soltos, [[self.nov.CENTRAL, "abrir", "atualizar"]])
        self.nov.verificar(self.versoes)
        self.assertEqual(len(self.mundo.avisos), 1, "a mesma versão não avisa de novo")

    def test_versao_baixada_pede_para_reiniciar(self):
        self.mundo.info("27.1")
        self.nov.verificar(self.versoes)
        self.mundo.rotulos = {"org.matsu.versao": "27.2"}
        self.nov.verificar(self.versoes)
        self.mundo.baixada = True
        self.nov.verificar(self.versoes)
        self.assertEqual(len(self.mundo.avisos), 2)
        titulo, corpo, acoes = self.mundo.avisos[1]
        self.assertEqual(titulo, "A versão 27.2 já foi baixada")
        self.assertEqual(acoes, ["reiniciar"])

    def test_canal_igual_ou_sem_internet_nao_avisa(self):
        self.mundo.info("27.2")
        self.nov.verificar(self.versoes)
        self.mundo.rotulos = {"org.matsu.versao": "27.2"}
        self.nov.verificar(self.versoes)
        self.mundo.rotulos = {"org.matsu.versao": "lixo"}
        self.nov.verificar(self.versoes)
        self.mundo.rotulos = None
        self.nov.verificar(self.versoes)
        self.assertEqual(self.mundo.avisos, [])

    def test_sem_rpm_ostree_usa_a_imagem_do_sistema(self):
        self.mundo.info("27.1")
        self.mundo.booted = ""
        self.mundo.rotulos = {"org.matsu.versao": "27.2"}
        self.nov.verificar(self.versoes)
        self.assertEqual(self.mundo.ref_pedida, "docker://ghcr.io/dono/matsu-os:estavel")

    def test_apps_com_atualizacao(self):
        self.mundo.info("27.2")
        self.mundo.apps = ["com.spotify.Client", "org.gimp.GIMP", "org.exemplo.SemNome"]
        self.mundo.escolha = "loja"
        self.nov.verificar(self.versoes)
        titulo, corpo, acoes = self.mundo.avisos[0]
        self.assertEqual(titulo, "3 apps têm atualização")
        self.assertEqual(corpo, "• GIMP\n• SemNome\n• Spotify")
        self.assertEqual(self.mundo.soltos[0][1:], ["org.matsu.loja", self.nov.LOJA_QML, "biblioteca"])
        self.nov.verificar(self.versoes)
        self.assertEqual(len(self.mundo.avisos), 1, "a mesma lista não avisa de novo")
        self.mundo.apps = ["org.gimp.GIMP"]
        self.nov.verificar(self.versoes)
        self.assertEqual(self.mundo.avisos[-1][0], "1 app tem atualização")

    def test_estado_estragado(self):
        self.estado.parent.mkdir(parents=True)
        self.estado.write_text("{isto não é json")
        self.mundo.info("27.1")
        self.nov.verificar(self.versoes)
        self.assertEqual(self.ler_estado()["vista"], "27.1")
        self.estado.write_text("[1, 2]")
        self.nov.verificar(self.versoes)
        self.assertEqual(self.ler_estado()["vista"], "27.1")

    def test_ingles(self):
        nov = carregar({"MATSU_LANG": "en_US.UTF-8", "XDG_STATE_HOME": self.tmp.name})
        self.assertEqual(nov.texto_atualizado("27.2", "27.1", self.versoes)[0], "Matsu was updated to 27.2")
        self.assertEqual(nov.lista_curta(list("ABCDE")).splitlines()[-1], "and 2 more changes.")


if __name__ == "__main__":
    unittest.main(verbosity=1)
