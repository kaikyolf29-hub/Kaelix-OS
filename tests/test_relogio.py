#!/usr/bin/env python3
"""Testes do ajudante do Relógio (system_files/usr/share/matsu/relogio/ajudante.py).

Cobrem o cálculo do OnCalendar, o próximo toque, os arquivos de unidade do systemd
gerados (com um systemctl de mentira), a leitura e gravação da lista de alarmes, o
toque (alarme de uma vez se desliga, soneca agenda com systemd-run) e os fusos.
Tudo numa pasta pessoal temporária: nada encosta no systemd de verdade.

Uso: python3 tests/test_relogio.py
"""
import datetime as dt
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

PASTA = Path(__file__).resolve().parents[1] / "system_files/usr/share/matsu/relogio"
AJUDANTE = PASTA / "ajudante.py"
TOCAR = PASTA / "tocar.py"


def carregar():
    spec = importlib.util.spec_from_file_location("relogio_teste", AJUDANTE)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


aj = carregar()

# Quinta-feira, 12 de novembro de 2026, 14:30.
QUINTA = dt.datetime(2026, 11, 12, 14, 30, 0)


def alarme(**campos):
    base = {"id": "abc123", "nome": "Acordar", "hora": 7, "minuto": 30, "dias": [0, 1, 2, 3, 4], "ligado": True}
    base.update(campos)
    return aj.normalizar(base)


class CasaTemporaria(unittest.TestCase):
    """Cada teste ganha uma pasta pessoal nova e um systemctl que só anota as chamadas."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.raiz = Path(self.tmp.name)
        self.env = mock.patch.dict(os.environ, {
            "HOME": str(self.raiz), "XDG_DATA_HOME": str(self.raiz / "dados"),
            "XDG_CONFIG_HOME": str(self.raiz / "config"), "MATSU_RELOGIO_SYSTEMD": "sim", "LANG": "pt_BR.UTF-8",
            "LC_ALL": "", "LC_MESSAGES": "", "LANGUAGE": "", "MATSU_LANG": "",
        })
        self.env.start()
        self.chamadas = []
        self.sysctl = mock.patch.object(aj, "systemctl", side_effect=self._systemctl)
        self.sysctl.start()
        self.unidades = self.raiz / "config/systemd/user"

    def _systemctl(self, *args):
        self.chamadas.append(list(args))
        return True, ""

    def tearDown(self):
        self.sysctl.stop()
        self.env.stop()
        self.tmp.cleanup()

    def verbos(self):
        return [c[0] for c in self.chamadas]


class TesteOnCalendar(unittest.TestCase):
    def test_dias_uteis(self):
        self.assertEqual(aj.oncalendar(alarme()), "Mon,Tue,Wed,Thu,Fri *-*-* 07:30:00")

    def test_todos_os_dias(self):
        self.assertEqual(aj.oncalendar(alarme(dias=list(range(7)), hora=6, minuto=5)), "*-*-* 06:05:00")

    def test_fim_de_semana_e_dias_soltos(self):
        self.assertEqual(aj.oncalendar(alarme(dias=[6, 5])), "Sat,Sun *-*-* 07:30:00")
        self.assertEqual(aj.oncalendar(alarme(dias=[2, 0, 4])), "Mon,Wed,Fri *-*-* 07:30:00")

    def test_uma_vez_usa_a_data(self):
        a = alarme(dias=[], data="2026-11-13", hora=0, minuto=0)
        self.assertEqual(aj.oncalendar(a), "2026-11-13 00:00:00")

    def test_meia_noite_e_fim_do_dia(self):
        self.assertEqual(aj.oncalendar(alarme(dias=[0], hora=23, minuto=59)), "Mon *-*-* 23:59:00")


class TesteProximoToque(unittest.TestCase):
    def test_mais_tarde_hoje(self):
        a = alarme(dias=[3], hora=18, minuto=0)  # quinta
        self.assertEqual(aj.proximo_toque(a, QUINTA), dt.datetime(2026, 11, 12, 18, 0))

    def test_ja_passou_hoje_vai_para_o_proximo_dia_util(self):
        self.assertEqual(aj.proximo_toque(alarme(), QUINTA), dt.datetime(2026, 11, 13, 7, 30))

    def test_sexta_a_noite_pula_o_fim_de_semana(self):
        sexta = dt.datetime(2026, 11, 13, 22, 0)
        self.assertEqual(aj.proximo_toque(alarme(), sexta), dt.datetime(2026, 11, 16, 7, 30))

    def test_mesmo_minuto_conta_como_passado(self):
        a = alarme(dias=[3], hora=14, minuto=30)
        self.assertEqual(aj.proximo_toque(a, QUINTA), dt.datetime(2026, 11, 19, 14, 30))

    def test_so_um_dia_por_semana(self):
        a = alarme(dias=[2], hora=9, minuto=0)  # quarta
        self.assertEqual(aj.proximo_toque(a, QUINTA), dt.datetime(2026, 11, 18, 9, 0))

    def test_uma_vez_sem_data(self):
        self.assertEqual(aj.proximo_toque(alarme(dias=[], hora=15, minuto=0), QUINTA), dt.datetime(2026, 11, 12, 15, 0))
        self.assertEqual(aj.proximo_toque(alarme(dias=[], hora=8, minuto=0), QUINTA), dt.datetime(2026, 11, 13, 8, 0))

    def test_uma_vez_com_data(self):
        a = alarme(dias=[], hora=8, minuto=0, data="2026-11-20")
        self.assertEqual(aj.proximo_toque(a, QUINTA), dt.datetime(2026, 11, 20, 8, 0))

    def test_uma_vez_que_ja_passou_nao_toca(self):
        a = alarme(dias=[], hora=8, minuto=0, data="2026-11-12")
        self.assertIsNone(aj.proximo_toque(a, QUINTA))

    def test_desligado_nao_toca(self):
        self.assertIsNone(aj.proximo_toque(alarme(ligado=False), QUINTA))

    def test_virada_do_ano(self):
        a = alarme(dias=[4], hora=0, minuto=1)  # sexta
        self.assertEqual(aj.proximo_toque(a, dt.datetime(2026, 12, 31, 23, 59)), dt.datetime(2027, 1, 1, 0, 1))

    def test_proxima_data(self):
        self.assertEqual(aj.proxima_data(14, 31, QUINTA), "2026-11-12")
        self.assertEqual(aj.proxima_data(14, 30, QUINTA), "2026-11-13")


class TesteNormalizar(unittest.TestCase):
    def test_limpa_e_completa(self):
        a = aj.normalizar({"hora": "25", "minuto": -3, "dias": [6, 6, 9, "x", "2"], "nome": "  Ir\n  à\tacademia  ",
                           "som": "trombeta", "soneca": 7})
        self.assertEqual((a["hora"], a["minuto"]), (23, 0))
        self.assertEqual(a["dias"], [2, 6])
        self.assertEqual(a["nome"], "Ir à academia")
        self.assertEqual(a["som"], "alarme")
        self.assertEqual(a["soneca"], 10)
        self.assertRegex(a["id"], r"^[0-9a-f]{8}$")
        self.assertEqual(a["data"], "")

    def test_nome_comprido_e_soneca_zero(self):
        a = aj.normalizar({"nome": "x" * 200, "soneca": 0, "som": "sino"})
        self.assertEqual(len(a["nome"]), 60)
        self.assertEqual(a["soneca"], 0)
        self.assertEqual(a["som"], "sino")

    def test_recusa_id_estranho_e_hora_sem_numero(self):
        with self.assertRaises(ValueError):
            aj.normalizar({"id": "../../etc", "hora": 7})
        with self.assertRaises(ValueError):
            aj.normalizar({"hora": "sete"})

    def test_data_so_vale_para_uma_vez(self):
        self.assertEqual(aj.normalizar({"dias": [1], "data": "2026-11-13"})["data"], "")
        self.assertEqual(aj.normalizar({"dias": [], "data": "2026-02-30"})["data"], "")
        self.assertEqual(aj.normalizar({"dias": [], "data": "2026-11-13"})["data"], "2026-11-13")


class TesteLista(CasaTemporaria):
    def test_ler_sem_arquivo(self):
        self.assertEqual(aj.ler_alarmes(), [])

    def test_gravar_e_ler(self):
        lista = [alarme(id="b2", hora=9), alarme(id="a1", hora=6, dias=[], data="2026-11-13")]
        aj.gravar_alarmes(lista)
        caminho = self.raiz / "dados/matsu/relogio/alarmes.json"
        dados = json.loads(caminho.read_text())
        self.assertEqual(dados["versao"], 1)
        self.assertEqual([a["id"] for a in dados["alarmes"]], ["a1", "b2"])  # em ordem de hora
        self.assertEqual(aj.ler_alarmes(), aj.ordenar(lista))
        self.assertEqual([p.name for p in caminho.parent.iterdir() if p.name.endswith(".tmp")], [])

    def test_acentos_ficam_legiveis(self):
        aj.gravar_alarmes([alarme(nome="Remédio da manhã")])
        self.assertIn("Remédio da manhã", (self.raiz / "dados/matsu/relogio/alarmes.json").read_text())

    def test_arquivo_estragado_vira_copia(self):
        caminho = self.raiz / "dados/matsu/relogio/alarmes.json"
        caminho.parent.mkdir(parents=True)
        caminho.write_text("{ isso não é json")
        self.assertEqual(aj.ler_alarmes(), [])
        self.assertTrue((caminho.parent / "alarmes.json.estragado").exists())

    def test_lista_antiga_e_itens_ruins(self):
        caminho = self.raiz / "dados/matsu/relogio/alarmes.json"
        caminho.parent.mkdir(parents=True)
        caminho.write_text(json.dumps([{"id": "x1", "hora": 8}, {"id": "x1", "hora": 9}, "lixo", {"id": "../", "hora": 1}]))
        lista = aj.ler_alarmes()
        self.assertEqual([(a["id"], a["hora"]) for a in lista], [("x1", 8)])


class TesteUnidades(CasaTemporaria):
    def test_alarme_ligado_gera_timer_e_servico(self):
        a = alarme(id="ab12", nome="Acordar 100%")
        r = aj.sincronizar([a], QUINTA)
        self.assertTrue(r["systemd"])
        timer = (self.unidades / "matsu-alarme-ab12.timer").read_text()
        servico = (self.unidades / "matsu-alarme-ab12.service").read_text()
        self.assertIn("OnCalendar=Mon,Tue,Wed,Thu,Fri *-*-* 07:30:00\n", timer)
        self.assertIn("Persistent=false\n", timer)
        self.assertIn("AccuracySec=1s\n", timer)
        self.assertIn("Unit=matsu-alarme-ab12.service\n", timer)
        self.assertIn("WantedBy=timers.target\n", timer)
        self.assertIn("Description=Relógio do Matsu: 07:30 Acordar 100%%\n", timer)
        self.assertIn(f"ExecStart={aj.PYTHON} -I -S {TOCAR} alarme ab12\n", servico)
        self.assertIn("Type=simple\n", servico)
        self.assertEqual(self.chamadas, [["daemon-reload"], ["enable", "--now", "matsu-alarme-ab12.timer"],
                                         ["restart", "matsu-alarme-ab12.timer"]])

    def test_sem_mudanca_nao_recarrega(self):
        a = alarme(id="ab12")
        aj.sincronizar([a], QUINTA)
        self.chamadas.clear()
        aj.sincronizar([a], QUINTA)
        self.assertNotIn("daemon-reload", self.verbos())
        self.assertNotIn("restart", self.verbos())
        self.assertEqual(self.chamadas, [["enable", "--now", "matsu-alarme-ab12.timer"]])

    def test_mudar_a_hora_reinicia_o_timer(self):
        aj.sincronizar([alarme(id="ab12")], QUINTA)
        self.chamadas.clear()
        aj.sincronizar([alarme(id="ab12", hora=8)], QUINTA)
        self.assertIn("OnCalendar=Mon,Tue,Wed,Thu,Fri *-*-* 08:30:00", (self.unidades / "matsu-alarme-ab12.timer").read_text())
        self.assertEqual(self.verbos(), ["daemon-reload", "enable", "restart"])

    def test_desligar_e_apagar_tiram_as_unidades(self):
        aj.sincronizar([alarme(id="aa1"), alarme(id="bb2")], QUINTA)
        self.chamadas.clear()
        aj.sincronizar([alarme(id="aa1", ligado=False)], QUINTA)
        self.assertEqual(self.chamadas[0], ["disable", "--now", "matsu-alarme-aa1.timer", "matsu-alarme-bb2.timer"])
        self.assertIn(["daemon-reload"], self.chamadas)
        self.assertEqual(sorted(p.name for p in self.unidades.glob("matsu-alarme-*")), [])

    def test_uma_vez_que_passou_nao_gera(self):
        a = alarme(id="cc3", dias=[], data="2026-11-12", hora=8)
        aj.sincronizar([a], QUINTA)
        self.assertFalse((self.unidades / "matsu-alarme-cc3.timer").exists())

    def test_caminho_com_espaco_vai_entre_aspas(self):
        with mock.patch.object(aj, "TOCAR", "/opt/meu relogio/tocar.py"):
            texto = aj.texto_servico(alarme(id="dd4"))
        self.assertIn('ExecStart=' + aj.PYTHON + ' -I -S "/opt/meu relogio/tocar.py" alarme dd4\n', texto)

    def test_sem_systemd_habilita_pelo_link(self):
        with mock.patch.dict(os.environ, {"MATSU_RELOGIO_SYSTEMD": "nao"}):
            r = aj.sincronizar([alarme(id="ee5")], QUINTA)
            self.assertFalse(r["systemd"])
            link = self.unidades / "timers.target.wants/matsu-alarme-ee5.timer"
            self.assertTrue(link.is_symlink())
            self.assertEqual(os.readlink(link), str(self.unidades / "matsu-alarme-ee5.timer"))
            aj.sincronizar([], QUINTA)
            self.assertFalse(os.path.lexists(link))
        self.assertEqual(self.chamadas, [])

    def test_nao_mexe_em_outras_unidades(self):
        self.unidades.mkdir(parents=True)
        (self.unidades / "outra-coisa.timer").write_text("[Timer]\n")
        aj.sincronizar([], QUINTA)
        self.assertTrue((self.unidades / "outra-coisa.timer").exists())


class TesteComandos(CasaTemporaria):
    def test_salvar_uma_vez_ganha_data(self):
        r = aj.salvar_alarme({"nome": "Pão", "hora": 15, "minuto": 0}, QUINTA)
        self.assertEqual(r["alarme"]["data"], "2026-11-12")
        r = aj.salvar_alarme({"nome": "Pão", "hora": 9, "minuto": 0}, QUINTA)
        self.assertEqual(r["alarme"]["data"], "2026-11-13")
        self.assertEqual(len(aj.ler_alarmes()), 2)

    def test_editar_mantem_o_id(self):
        r = aj.salvar_alarme({"id": "f00", "hora": 6}, QUINTA)
        aj.salvar_alarme(dict(r["alarme"], hora=7, nome="Novo"), QUINTA)
        lista = aj.ler_alarmes()
        self.assertEqual([(a["id"], a["hora"], a["nome"]) for a in lista], [("f00", 7, "Novo")])

    def test_ligar_desligar_e_apagar(self):
        aj.salvar_alarme({"id": "f01", "hora": 6, "dias": [1]}, QUINTA)
        r = aj.ligar_alarme("f01", False, QUINTA)
        self.assertFalse(r["alarme"]["ligado"])
        self.assertFalse((self.unidades / "matsu-alarme-f01.timer").exists())
        self.assertIn(["stop", "matsu-alarme-f01.service", "matsu-soneca-f01-*.timer", "matsu-soneca-f01-*.service"],
                      self.chamadas)
        aj.ligar_alarme("f01", True, QUINTA)
        self.assertTrue((self.unidades / "matsu-alarme-f01.timer").exists())
        r = aj.apagar_alarme("f01", QUINTA)
        self.assertEqual(r["apagado"]["id"], "f01")
        self.assertEqual(r["alarmes"], [])
        self.assertFalse((self.unidades / "matsu-alarme-f01.timer").exists())
        self.assertFalse(aj.ligar_alarme("nada", True, QUINTA)["ok"])

    def test_religar_uma_vez_recalcula_a_data(self):
        aj.salvar_alarme({"id": "f02", "hora": 8, "dias": []}, dt.datetime(2026, 11, 10, 9, 0))
        r = aj.ligar_alarme("f02", True, QUINTA)
        self.assertEqual(r["alarme"]["data"], "2026-11-13")

    def test_estado_desliga_uma_vez_perdido(self):
        aj.salvar_alarme({"id": "f03", "hora": 8, "dias": []}, dt.datetime(2026, 11, 10, 9, 0))
        e = aj.estado(QUINTA)
        self.assertFalse(e["alarmes"][0]["ligado"])
        self.assertEqual(e["idioma"], "pt")
        self.assertIn("fuso", e)

    def test_cli_salvar_e_estado(self):
        env = dict(os.environ, MATSU_RELOGIO_SYSTEMD="nao")
        r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), "salvar-alarme",
                            json.dumps({"nome": "Café", "hora": 6, "minuto": 45, "dias": [0, 2, 4]})],
                           capture_output=True, text=True, env=env, timeout=30)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(json.loads(r.stdout)["alarme"]["nome"], "Café")
        r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), "estado"], capture_output=True, text=True,
                           env=env, timeout=30)
        d = json.loads(r.stdout)
        self.assertFalse(d["systemd"])
        self.assertEqual(d["alarmes"][0]["dias"], [0, 2, 4])
        self.assertTrue((self.unidades / f"matsu-alarme-{d['alarmes'][0]['id']}.timer").exists())

    def test_cli_json_ruim(self):
        r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), "salvar-alarme", "{nao"], capture_output=True,
                           text=True, env=dict(os.environ, MATSU_RELOGIO_SYSTEMD="nao"), timeout=30)
        self.assertEqual(r.returncode, 1)
        self.assertFalse(json.loads(r.stdout)["ok"])


class TesteToque(CasaTemporaria):
    def toque_falso(self, resposta):
        criados = []

        class Falso:
            def __init__(self, titulo, corpo, acoes, som, limite=300):
                criados.append({"titulo": titulo, "corpo": corpo, "acoes": acoes, "som": som})
                self.aviso = mock.Mock()

            def executar(self):
                return resposta

            def interromper(self, *_):
                pass

        return mock.patch.object(aj, "Toque", Falso), criados

    def test_uma_vez_se_desliga_depois_de_tocar(self):
        aj.salvar_alarme({"id": "u1", "nome": "Forno", "hora": 15, "minuto": 0, "dias": [], "som": "sino"}, QUINTA)
        remendo, criados = self.toque_falso("parar")
        with remendo, mock.patch("signal.signal"):
            aj.tocar("alarme", "u1")
        self.assertFalse(aj.ler_alarmes()[0]["ligado"])
        self.assertFalse((self.unidades / "matsu-alarme-u1.timer").exists())
        self.assertEqual(criados[0]["titulo"], "Forno")
        self.assertEqual(criados[0]["som"], "sino")
        self.assertEqual([c for c, _ in criados[0]["acoes"]], ["soneca", "parar"])
        self.assertEqual(criados[0]["acoes"][0][1], "Soneca (10 min)")

    def test_repetido_continua_ligado(self):
        aj.salvar_alarme({"id": "u2", "hora": 7, "dias": [0, 1]}, QUINTA)
        remendo, _ = self.toque_falso("parar")
        with remendo, mock.patch("signal.signal"):
            aj.tocar("alarme", "u2")
        self.assertTrue(aj.ler_alarmes()[0]["ligado"])

    def test_desligado_ou_apagado_nao_toca(self):
        aj.salvar_alarme({"id": "u3", "hora": 7, "dias": [0], "ligado": False}, QUINTA)
        remendo, criados = self.toque_falso("parar")
        with remendo, mock.patch("signal.signal"):
            aj.tocar("alarme", "u3")
            aj.tocar("alarme", "naoexiste")
        self.assertEqual(criados, [])

    def test_soneca_agenda_com_systemd_run(self):
        aj.salvar_alarme({"id": "u4", "hora": 7, "dias": [0], "soneca": 5}, QUINTA)
        remendo, _ = self.toque_falso("soneca")
        with remendo, mock.patch("signal.signal"), mock.patch.object(aj, "rodar", return_value=(True, "", "")) as rodar, \
                mock.patch.object(aj.shutil, "which", return_value="/usr/bin/x"):
            aj.tocar("alarme", "u4")
        comando = rodar.call_args[0][0]
        self.assertEqual(comando[:3], ["systemd-run", "--user", "--collect"])
        self.assertIn("--on-active=300", comando)
        self.assertIn("--timer-property=AccuracySec=1s", comando)
        self.assertEqual(comando[-4:], [str(TOCAR), "alarme", "u4", "--soneca"])
        self.assertTrue(any(c.startswith("--unit=matsu-soneca-u4-") for c in comando))

    def test_soneca_toca_mesmo_desligado(self):
        aj.salvar_alarme({"id": "u5", "hora": 7, "dias": [], "ligado": False}, QUINTA)
        remendo, criados = self.toque_falso("parar")
        with remendo, mock.patch("signal.signal"):
            aj.tocar("alarme", "u5", soneca=True)
        self.assertEqual(len(criados), 1)

    def test_sem_soneca_so_parar(self):
        aj.salvar_alarme({"id": "u6", "hora": 7, "dias": [0], "soneca": 0}, QUINTA)
        remendo, criados = self.toque_falso("")
        with remendo, mock.patch("signal.signal"):
            aj.tocar("alarme", "u6")
        self.assertEqual([c for c, _ in criados[0]["acoes"]], ["parar"])

    def test_ninguem_respondeu_avisa_perdido(self):
        aj.salvar_alarme({"id": "u7", "nome": "Reunião", "hora": 7, "dias": [0]}, QUINTA)
        remendo, _ = self.toque_falso(None)
        with remendo, mock.patch("signal.signal"), mock.patch.object(aj, "avisar_simples") as perdido:
            aj.tocar("alarme", "u7")
        perdido.assert_called_once_with("Alarme perdido", "Reunião · 07:00")

    def test_temporizador(self):
        remendo, criados = self.toque_falso("parar")
        with remendo, mock.patch("signal.signal"):
            aj.tocar("temporizador", "t1", nome="Chá")
        self.assertEqual(criados[0]["titulo"], "Tempo esgotado")
        self.assertIn("“Chá”", criados[0]["corpo"])

    def test_agendar_temporizador(self):
        with mock.patch.object(aj, "rodar", return_value=(True, "", "")) as rodar, \
                mock.patch.object(aj.shutil, "which", return_value="/usr/bin/systemd-run"):
            r = aj.agendar_temporizador("t2", 1_900_000_000.2, "Massa")
        self.assertTrue(r["ok"])
        comando = rodar.call_args[0][0]
        self.assertIn("--on-calendar=2030-03-17 17:46:41 UTC", comando)
        self.assertEqual(comando[-3:], ["temporizador", "t2", "Massa"])
        self.assertEqual(self.chamadas[0], ["stop", "matsu-temporizador-t2-*.timer", "matsu-temporizador-t2-*.service"])
        self.assertFalse(aj.agendar_temporizador("../x", 0, "x")["ok"])

    def test_temporizador_sem_systemd(self):
        with mock.patch.dict(os.environ, {"MATSU_RELOGIO_SYSTEMD": "nao"}):
            self.assertEqual(aj.agendar_temporizador("t3", 0, "x"), {"ok": False, "erro": "sem-systemd"})


class TesteAviso(unittest.TestCase):
    def test_texto_gvariant(self):
        self.assertEqual(aj.gvariant_texto("D'Ávila \\o/"), "'D\\'Ávila \\\\o/'")

    def test_notify_send_recebe_as_acoes(self):
        aviso = aj.Aviso("Acordar", "07:30", [("soneca", "Soneca (5 min)"), ("parar", "Parar")])
        processo = mock.Mock()
        processo.stdout = iter(["42\n", "soneca\n"])
        processo.returncode = 0
        with mock.patch.object(aj.subprocess, "Popen", return_value=processo) as popen:
            self.assertTrue(aviso._notify_send())
            aviso._fim.wait(2)
        comando = popen.call_args[0][0]
        self.assertIn("--urgency=critical", comando)
        self.assertIn("--wait", comando)
        self.assertIn("--icon=org.matsu.relogio", comando)
        self.assertIn("--action=soneca=Soneca (5 min)", comando)
        self.assertEqual(comando[-2:], ["Acordar", "07:30"])
        self.assertEqual((aviso.ident, aviso.resposta), (42, "soneca"))


class TesteSom(unittest.TestCase):
    def test_acha_som_do_tema_e_reserva(self):
        with tempfile.TemporaryDirectory() as d:
            estereo = Path(d, "freedesktop/stereo")
            estereo.mkdir(parents=True)
            (estereo / "bell.oga").write_bytes(b"x")
            with mock.patch.dict(os.environ, {"MATSU_SONS": d}):
                self.assertEqual(aj.achar_som("sino"), str(estereo / "bell.oga"))
                self.assertEqual(aj.achar_som("alarme"), str(estereo / "bell.oga"))  # reserva
                (estereo / "alarm-clock-elapsed.oga").write_bytes(b"x")
                self.assertEqual(aj.achar_som("alarme"), str(estereo / "alarm-clock-elapsed.oga"))
            with mock.patch.dict(os.environ, {"MATSU_SONS": str(Path(d, "vazio"))}):
                self.assertEqual(aj.achar_som("alarme"), "")
        self.assertIsNone(aj.comando_som(""))

    def test_tocador_preferido(self):
        com = {"pw-play": None, "paplay": "/usr/bin/paplay", "canberra-gtk-play": "/usr/bin/c"}
        with mock.patch.object(aj.shutil, "which", side_effect=lambda n: com.get(n)):
            self.assertEqual(aj.comando_som("/s.oga"), ["paplay", "/s.oga"])


class TesteFusos(unittest.TestCase):
    def test_cidades_validas_e_sem_repetir(self):
        ids = [c[0] for c in aj.CIDADES]
        self.assertEqual(len(ids), len(set(ids)))
        for c in aj.CIDADES:
            self.assertTrue(aj.fuso_valido(c[5]), c)
        nomes = {c[1] for c in aj.CIDADES}
        for nome in ("São Paulo", "Lisboa", "Tóquio", "Nova York", "Londres", "Paris"):
            self.assertIn(nome, nomes)

    def test_desvios(self):
        inverno_norte = dt.datetime(2026, 1, 15, 12, tzinfo=dt.timezone.utc).timestamp()
        verao_norte = dt.datetime(2026, 7, 15, 12, tzinfo=dt.timezone.utc).timestamp()
        self.assertEqual(aj.desvio("America/Sao_Paulo", inverno_norte), -3 * 3600)
        self.assertEqual(aj.desvio("Asia/Tokyo", inverno_norte), 9 * 3600)
        self.assertEqual(aj.desvio("Asia/Kolkata", inverno_norte), 5 * 3600 + 1800)
        self.assertEqual(aj.desvio("Europe/Lisbon", inverno_norte), 0)
        self.assertEqual(aj.desvio("Europe/Lisbon", verao_norte), 3600)

    def test_proxima_mudanca(self):
        antes = dt.datetime(2027, 3, 1, tzinfo=dt.timezone.utc).timestamp()
        ate, depois = aj.proxima_mudanca("America/New_York", antes)
        self.assertEqual(ate, int(dt.datetime(2027, 3, 14, 7, 0, tzinfo=dt.timezone.utc).timestamp()))
        self.assertEqual(depois, -4 * 3600)
        self.assertEqual(aj.proxima_mudanca("Asia/Tokyo", antes), (0, 9 * 3600))

    def test_fuso_local(self):
        with mock.patch.dict(os.environ, {"TZ": "Asia/Tokyo"}):
            self.assertEqual(aj.fuso_local(), "Asia/Tokyo")
        with mock.patch.dict(os.environ, {"TZ": ":Europe/Paris"}):
            self.assertEqual(aj.fuso_local(), "Europe/Paris")
        with mock.patch.dict(os.environ, {"TZ": "", "MATSU_LOCALTIME": "/usr/share/zoneinfo/America/Manaus"}):
            self.assertEqual(aj.fuso_local(), "America/Manaus")
        with mock.patch.dict(os.environ, {"TZ": "Lugar/Nenhum", "MATSU_LOCALTIME": "/nao/existe"}), \
                mock.patch.object(aj, "ler", return_value=""):
            self.assertEqual(aj.fuso_local(), "America/Sao_Paulo")

    def test_nomes_dos_fusos(self):
        self.assertEqual(aj.nome_fuso("America/Sao_Paulo")[0], "Horário de Brasília")
        self.assertEqual(aj.nome_fuso("America/Fortaleza")[0], "Horário de Brasília")
        self.assertEqual(aj.nome_fuso("America/Manaus")[0], "Horário do Amazonas")
        self.assertEqual(aj.nome_fuso("Asia/Tokyo"), ("Tóquio", "Tokyo"))
        self.assertEqual(aj.nome_fuso("Antarctica/Troll"), ("Troll", "Troll"))

    def test_catalogo_em_ingles(self):
        with mock.patch.dict(os.environ, {"MATSU_LANG": "en_US.UTF-8"}):
            nomes = {c["id"]: c["nome"] for c in aj.catalogo()}
        self.assertEqual(nomes["toquio"], "Tokyo")

    def test_cli_fusos_ignora_invalidos(self):
        r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), "fusos", "Asia/Tokyo", "../etc/passwd", "Nada/Aqui"],
                           capture_output=True, text=True, timeout=30)
        self.assertEqual([f["fuso"] for f in json.loads(r.stdout)["fusos"]], ["Asia/Tokyo"])


class TesteTocarPy(unittest.TestCase):
    def test_sem_argumentos_mostra_uso(self):
        r = subprocess.run([sys.executable, "-I", "-S", str(TOCAR)], capture_output=True, text=True, timeout=30)
        self.assertEqual(r.returncode, 2)

    def test_alarme_que_nao_existe_sai_quieto(self):
        with tempfile.TemporaryDirectory() as d:
            env = dict(os.environ, HOME=d, XDG_DATA_HOME=d, XDG_CONFIG_HOME=d, MATSU_RELOGIO_SYSTEMD="nao")
            r = subprocess.run([sys.executable, "-I", "-S", str(TOCAR), "alarme", "abc"], capture_output=True,
                               text=True, env=env, timeout=30)
        self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
