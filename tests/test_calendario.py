#!/usr/bin/env python3
"""Testes do ajudante do Calendário (system_files/usr/share/matsu/calendario/ajudante.py).

Feriados, repetições, o próximo lembrete, as unidades do systemd (com um systemctl e um
notify-send de mentira, numa pasta temporária) e a ida e volta dos arquivos .ics. No fim,
se o Node existir, confere se as contas do QML (datas.js) dão o mesmo que as do Python.

Uso: python3 tests/test_calendario.py
"""
import datetime as dt
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
PASTA = RAIZ / "system_files/usr/share/matsu/calendario"
AJUDANTE = PASTA / "ajudante.py"

sys.dont_write_bytecode = True  # não deixar __pycache__ dentro de system_files
spec = importlib.util.spec_from_file_location("ajudante_calendario", AJUDANTE)
aj = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aj)

D = dt.date
T = dt.datetime


def evento(**campos):
    base = {"id": "ev1", "titulo": "Dentista", "diaTodo": False, "inicio": "2026-11-12T09:00", "fim": "2026-11-12T10:00",
            "cor": "salvia", "lembrete": -1, "repetir": "nunca", "local": "", "notas": ""}
    base.update(campos)
    return aj.normalizar(base)


class Feriados(unittest.TestCase):
    def test_pascoa(self):
        self.assertEqual(aj.pascoa(2026), D(2026, 4, 5))
        self.assertEqual(aj.pascoa(2024), D(2024, 3, 31))
        self.assertEqual(aj.pascoa(2025), D(2025, 4, 20))
        self.assertEqual(aj.pascoa(2027), D(2027, 3, 28))
        self.assertEqual(aj.pascoa(2038), D(2038, 4, 25))
        self.assertEqual(aj.pascoa(2000), D(2000, 4, 23))

    def test_moveis_2026(self):
        datas = {f["data"]: f["nome"] for f in aj.feriados(2026)}
        self.assertEqual(datas[D(2026, 2, 16)], "Carnaval")
        self.assertEqual(datas[D(2026, 2, 17)], "Carnaval")
        self.assertEqual(datas[D(2026, 4, 3)], "Sexta-feira Santa")
        self.assertEqual(datas[D(2026, 4, 5)], "Páscoa")
        self.assertEqual(datas[D(2026, 6, 4)], "Corpus Christi")

    def test_fixos(self):
        datas = {f["data"]: f for f in aj.feriados(2026)}
        for mes, dia in ((1, 1), (4, 21), (5, 1), (9, 7), (10, 12), (11, 2), (11, 15), (11, 20), (12, 25)):
            self.assertIn(D(2026, mes, dia), datas)
            self.assertEqual(datas[D(2026, mes, dia)]["tipo"], "feriado")
        self.assertEqual(len(aj.feriados(2026)), 14)
        self.assertEqual(datas[D(2026, 2, 16)]["tipo"], "facultativo")
        self.assertEqual(datas[D(2026, 4, 5)]["tipo"], "data")

    def test_consciencia_negra_desde_2024(self):
        self.assertNotIn(D(2023, 11, 20), {f["data"] for f in aj.feriados(2023)})
        self.assertIn(D(2024, 11, 20), {f["data"] for f in aj.feriados(2024)})

    def test_em_ordem(self):
        for ano in (2025, 2026, 2030):
            datas = [f["data"] for f in aj.feriados(ano)]
            self.assertEqual(datas, sorted(datas))

    def test_comando(self):
        r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), "feriados", "2026"], capture_output=True, text=True)
        lista = json.loads(r.stdout)
        self.assertIn({"data": "2026-02-16", "nome": "Carnaval", "nome_en": "Carnival", "tipo": "facultativo"}, lista)


class Repeticao(unittest.TestCase):
    def dias(self, ev, de, ate):
        return [i.date() for i, _ in aj.ocorrencias(ev, de, ate)]

    def test_nunca(self):
        ev = evento()
        self.assertEqual(self.dias(ev, D(2026, 11, 1), D(2026, 11, 30)), [D(2026, 11, 12)])
        self.assertEqual(self.dias(ev, D(2026, 12, 1), D(2026, 12, 31)), [])

    def test_todo_dia(self):
        ev = evento(repetir="dia")
        self.assertEqual(self.dias(ev, D(2026, 11, 10), D(2026, 11, 14)), [D(2026, 11, 12), D(2026, 11, 13), D(2026, 11, 14)])

    def test_toda_semana_com_excecao(self):
        ev = evento(repetir="semana", excecoes=["2026-11-26"])
        self.assertEqual(self.dias(ev, D(2026, 11, 1), D(2026, 12, 10)),
                         [D(2026, 11, 12), D(2026, 11, 19), D(2026, 12, 3), D(2026, 12, 10)])

    def test_todo_mes_dia_31(self):
        ev = evento(inicio="2026-01-31T08:00", fim="2026-01-31T09:00", repetir="mes")
        self.assertEqual(self.dias(ev, D(2026, 1, 1), D(2026, 8, 31)),
                         [D(2026, 1, 31), D(2026, 3, 31), D(2026, 5, 31), D(2026, 7, 31), D(2026, 8, 31)])

    def test_todo_ano_29_de_fevereiro(self):
        ev = evento(diaTodo=True, inicio="2024-02-29", fim="2024-02-29", repetir="ano")
        self.assertEqual(self.dias(ev, D(2024, 1, 1), D(2032, 12, 31)), [D(2024, 2, 29), D(2028, 2, 29), D(2032, 2, 29)])

    def test_ate(self):
        ev = evento(repetir="semana", ate="2026-11-26")
        self.assertEqual(self.dias(ev, D(2026, 11, 1), D(2026, 12, 31)), [D(2026, 11, 12), D(2026, 11, 19), D(2026, 11, 26)])

    def test_varios_dias(self):
        # Viagem de 3 dias: aparece numa grade que começa no meio dela.
        ev = evento(diaTodo=True, inicio="2026-11-10", fim="2026-11-12", repetir="nunca")
        oc = aj.ocorrencias(ev, D(2026, 11, 11), D(2026, 11, 20))
        self.assertEqual(oc, [(T(2026, 11, 10), T(2026, 11, 12))])

    def test_nao_comeca_antes_do_inicio(self):
        ev = evento(repetir="mes")
        self.assertEqual(self.dias(ev, D(2026, 1, 1), D(2026, 11, 11)), [])

    def test_normalizar(self):
        ev = aj.normalizar({"id": "a b/c", "inicio": "2026-11-12T10:00", "fim": "2026-11-12T09:00", "repetir": "x",
                            "cor": "azul-kde", "lembrete": "15"})
        self.assertEqual(ev["id"], "abc")
        self.assertEqual(ev["fim"], "2026-11-12T10:00")
        self.assertEqual(ev["repetir"], "nunca")
        self.assertEqual(ev["cor"], "salvia")
        self.assertEqual(ev["lembrete"], 15)
        self.assertIsNone(aj.normalizar({"titulo": "sem data"}))


class Lembretes(unittest.TestCase):
    def test_proximo_simples(self):
        ev = evento(lembrete=15)
        self.assertEqual(aj.proximo_lembrete(ev, T(2026, 11, 12, 8, 0))[0], T(2026, 11, 12, 8, 45))
        self.assertIsNone(aj.proximo_lembrete(ev, T(2026, 11, 12, 8, 45)))
        self.assertIsNone(aj.proximo_lembrete(evento(), T(2026, 11, 1)))

    def test_proximo_que_se_repete(self):
        ev = evento(lembrete=30, repetir="semana")
        self.assertEqual(aj.proximo_lembrete(ev, T(2026, 11, 12, 8, 31))[0], T(2026, 11, 19, 8, 30))
        ev = evento(lembrete=30, repetir="semana", excecoes=["2026-11-19"])
        self.assertEqual(aj.proximo_lembrete(ev, T(2026, 11, 12, 8, 31))[0], T(2026, 11, 26, 8, 30))

    def test_dia_todo(self):
        ev = evento(diaTodo=True, inicio="2026-12-24", fim="2026-12-24", lembrete=1440)
        self.assertEqual(aj.proximo_lembrete(ev, T(2026, 12, 1))[0], T(2026, 12, 23, 9, 0))
        ev = evento(diaTodo=True, inicio="2026-12-24", fim="2026-12-24", lembrete=0)
        self.assertEqual(aj.proximo_lembrete(ev, T(2026, 12, 1))[0], T(2026, 12, 24, 9, 0))

    def test_um_dia_antes_atravessa_o_ano(self):
        ev = evento(inicio="2027-01-01T00:30", fim="2027-01-01T02:00", lembrete=60)
        self.assertEqual(aj.proximo_lembrete(ev, T(2026, 12, 31, 12))[0], T(2026, 12, 31, 23, 30))

    def test_aniversario_bissexto(self):
        ev = evento(diaTodo=True, inicio="2024-02-29", fim="2024-02-29", repetir="ano", lembrete=0)
        self.assertEqual(aj.proximo_lembrete(ev, T(2026, 11, 12))[0], T(2028, 2, 29, 9, 0))

    def test_devido(self):
        ev = evento(lembrete=15, repetir="dia")
        # O timer disparou na hora.
        self.assertEqual(aj.lembrete_devido(ev, T(2026, 11, 13, 8, 45))[1], T(2026, 11, 13, 9, 0))
        # Computador ligado no meio do evento: ainda avisa; depois que acabou, não.
        self.assertEqual(aj.lembrete_devido(evento(lembrete=15), T(2026, 11, 12, 9, 30))[1], T(2026, 11, 12, 9, 0))
        self.assertIsNone(aj.lembrete_devido(evento(lembrete=15), T(2026, 11, 12, 10, 30)))
        self.assertIsNone(aj.lembrete_devido(evento(), T(2026, 11, 12, 9, 0)))

    def test_on_calendar(self):
        self.assertEqual(aj.on_calendar(T(2026, 11, 12, 8, 45)), "2026-11-12 08:45:00")
        ev = evento(id="abc123", titulo="Reunião 100% importante", lembrete=15)
        timer = aj.texto_timer(ev, T(2026, 11, 12, 8, 45))
        self.assertIn("OnCalendar=2026-11-12 08:45:00\n", timer)
        self.assertIn("Persistent=true\n", timer)
        self.assertIn("Unit=matsu-lembrete-abc123.service\n", timer)
        self.assertIn("WantedBy=timers.target\n", timer)
        self.assertIn("Description=Lembrete do Calendário: Reunião 100%% importante\n", timer)
        servico = aj.texto_service(ev)
        self.assertIn("Type=oneshot\n", servico)
        self.assertIn('"avisar" "abc123"', servico)
        self.assertIn(str(AJUDANTE), servico)

    def test_texto_do_aviso(self):
        ev = evento(local="Clínica Sorriso")
        agora = T(2026, 11, 12, 8, 45)
        self.assertEqual(aj.texto_aviso(ev, T(2026, 11, 12, 9), T(2026, 11, 12, 10), agora, "pt"),
                         ("Dentista", "Hoje, 09:00 – 10:00 · Clínica Sorriso"))
        self.assertEqual(aj.texto_aviso(ev, T(2026, 11, 13, 9), T(2026, 11, 13, 10), agora, "pt")[1],
                         "Amanhã, 09:00 – 10:00 · Clínica Sorriso")
        self.assertEqual(aj.texto_aviso(ev, T(2026, 11, 12, 9), T(2026, 11, 12, 10), T(2026, 11, 12, 9), "pt")[1],
                         "Agora, 09:00 – 10:00 · Clínica Sorriso")
        self.assertEqual(aj.texto_aviso(ev, T(2026, 11, 20, 9), T(2026, 11, 20, 10), agora, "pt")[1],
                         "sex., 20 de nov., 09:00 – 10:00 · Clínica Sorriso")
        self.assertEqual(aj.texto_aviso(evento(diaTodo=True, titulo="Natal da família", inicio="2026-12-24", fim="2026-12-24"),
                                        T(2026, 12, 24), T(2026, 12, 24), T(2026, 12, 23, 9), "pt"),
                         ("Natal da família", "Amanhã · dia todo"))
        self.assertEqual(aj.texto_aviso(ev, T(2026, 11, 12, 9), T(2026, 11, 12, 10), agora, "en")[1],
                         "Today, 09:00 – 10:00 · Clínica Sorriso")


class Systemd(unittest.TestCase):
    """Com um systemctl e um notify-send de mentira, que anotam como foram chamados."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        raiz = Path(self.tmp.name)
        self.unidades = raiz / "systemd"
        self.dados = raiz / "eventos.json"
        self.log = raiz / "log.txt"
        self.systemctl = raiz / "systemctl"
        self.systemctl.write_text(f'#!/bin/sh\necho "systemctl $*" >> "{self.log}"\nexit 0\n')
        self.notify = raiz / "notify-send"
        self.notify.write_text(f'#!/bin/sh\nfor a in "$@"; do echo "notify $a" >> "{self.log}"; done\nexit 0\n')
        for p in (self.systemctl, self.notify):
            p.chmod(0o755)
        self.antigo = {k: os.environ.get(k) for k in ("MATSU_SYSTEMD_USER", "MATSU_CALENDARIO", "MATSU_SYSTEMCTL", "MATSU_NOTIFY", "MATSU_LANG")}
        os.environ.update({"MATSU_SYSTEMD_USER": str(self.unidades), "MATSU_CALENDARIO": str(self.dados),
                           "MATSU_SYSTEMCTL": str(self.systemctl), "MATSU_NOTIFY": str(self.notify), "MATSU_LANG": "pt_BR.UTF-8"})

    def tearDown(self):
        for k, v in self.antigo.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        self.tmp.cleanup()

    def guardar(self, eventos):
        self.dados.write_text(json.dumps({"versao": 1, "eventos": eventos}))

    def chamadas(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_sincronizar(self):
        self.guardar([evento(id="a", lembrete=15), evento(id="b"), evento(id="c", lembrete=5, inicio="2026-01-01T09:00", fim="2026-01-01T10:00")])
        r = aj.sincronizar(agora=T(2026, 11, 12, 7, 0))
        self.assertTrue(r["systemd"])
        self.assertEqual(r["agendados"], 1)
        self.assertEqual(sorted(os.listdir(self.unidades)), ["matsu-lembrete-a.service", "matsu-lembrete-a.timer"])
        self.assertIn("OnCalendar=2026-11-12 08:45:00", (self.unidades / "matsu-lembrete-a.timer").read_text())
        log = self.chamadas()
        self.assertIn("systemctl --user show-environment", log)
        self.assertIn("systemctl --user daemon-reload", log)
        self.assertIn("systemctl --user enable matsu-lembrete-a.timer", log)
        self.assertIn("systemctl --user restart matsu-lembrete-a.timer", log)

        # De novo, sem mudanças: não recarrega nada.
        self.log.unlink()
        aj.sincronizar(agora=T(2026, 11, 12, 7, 0))
        self.assertEqual(self.chamadas(), ["systemctl --user show-environment"])

        # O evento foi apagado: o timer sai.
        self.guardar([])
        aj.sincronizar(agora=T(2026, 11, 12, 7, 0))
        self.assertEqual(os.listdir(self.unidades), [])
        self.assertIn("systemctl --user disable --now matsu-lembrete-a.timer", self.chamadas())

    def test_sem_systemd(self):
        self.systemctl.write_text("#!/bin/sh\nexit 1\n")
        self.guardar([evento(id="a", lembrete=15)])
        r = aj.sincronizar(agora=T(2026, 11, 12, 7, 0))
        self.assertEqual(r, {"systemd": False, "agendados": 0})
        self.assertFalse(self.unidades.exists())

    def test_avisar_e_reagendar(self):
        self.guardar([evento(id="sem", titulo="Aula de violão", lembrete=15, repetir="semana", local="Escola", inicio="2026-11-12T19:00",
                             fim="2026-11-12T20:00")])
        aj.sincronizar(agora=T(2026, 11, 12, 7, 0))
        self.log.unlink()
        r = aj.avisar("sem", agora=T(2026, 11, 12, 18, 45))
        self.assertTrue(r["avisou"])
        self.assertEqual(r["proximo"], "2026-11-19 18:45:00")
        log = self.chamadas()
        self.assertIn("notify --app-name=Calendário", log)
        self.assertIn("notify --icon=org.matsu.calendario", log)
        self.assertIn("notify Aula de violão", log)
        self.assertIn("notify Hoje, 19:00 – 20:00 · Escola", log)
        self.assertIn("OnCalendar=2026-11-19 18:45:00", (self.unidades / "matsu-lembrete-sem.timer").read_text())
        self.assertIn("systemctl --user restart matsu-lembrete-sem.timer", log)

    def test_avisar_ultimo(self):
        self.guardar([evento(id="um", lembrete=0)])
        aj.sincronizar(agora=T(2026, 11, 12, 7, 0))
        r = aj.avisar("um", agora=T(2026, 11, 12, 9, 0))
        self.assertTrue(r["avisou"])
        self.assertIsNone(r["proximo"])
        self.assertEqual(os.listdir(self.unidades), [])
        self.assertIn("notify Agora, 09:00 – 10:00", self.chamadas())

    def test_avisar_evento_que_sumiu(self):
        self.guardar([])
        self.unidades.mkdir()
        (self.unidades / "matsu-lembrete-x.timer").write_text("")
        (self.unidades / "matsu-lembrete-x.service").write_text("")
        r = aj.avisar("x", agora=T(2026, 11, 12, 9, 0))
        self.assertFalse(r["avisou"])
        self.assertEqual(os.listdir(self.unidades), [])

    def test_avisar_atrasado_demais(self):
        # Ligou o computador depois que o evento acabou: só agenda o próximo, sem avisar.
        self.guardar([evento(id="d", lembrete=15, repetir="dia")])
        r = aj.avisar("d", agora=T(2026, 11, 12, 11, 0))
        self.assertFalse(r["avisou"])
        self.assertEqual(r["proximo"], "2026-11-13 08:45:00")


ICS = (
    "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Teste//PT\r\n"
    "BEGIN:VTIMEZONE\r\nTZID:America/Sao_Paulo\r\nBEGIN:STANDARD\r\nDTSTART:19700101T000000\r\nTZOFFSETFROM:-0300\r\n"
    "TZOFFSETTO:-0300\r\nEND:STANDARD\r\nEND:VTIMEZONE\r\n"
    "BEGIN:VEVENT\r\nUID:viagem@teste\r\nDTSTART;VALUE=DATE:20261120\r\nDTEND;VALUE=DATE:20261123\r\n"
    "SUMMARY:Viagem para a praia\\, com a família\r\nLOCATION:Ubatuba\\; SP\r\n"
    "DESCRIPTION:Levar protetor\\nE o guarda-sol\r\nEND:VEVENT\r\n"
    "BEGIN:VEVENT\r\nUID:aula@teste\r\nDTSTART;TZID=America/Sao_Paulo:20261103T190000\r\n"
    "DTEND;TZID=America/Sao_Paulo:20261103T203000\r\nRRULE:FREQ=WEEKLY;BYDAY=TU;COUNT=6\r\n"
    "EXDATE;TZID=America/Sao_Paulo:20261117T190000\r\n"
    "SUMMARY:Aula de violão com um título bem comprido que passa de setenta e cinco \r\n"
    " caracteres\r\n"
    "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT15M\r\nEND:VALARM\r\nEND:VEVENT\r\n"
    "BEGIN:VEVENT\r\nUID:utc@teste\r\nDTSTART:20261112T150000Z\r\nDURATION:PT45M\r\nSUMMARY:Reunião\r\nEND:VEVENT\r\n"
    "BEGIN:VEVENT\r\nUID:aula@teste\r\nRECURRENCE-ID;TZID=America/Sao_Paulo:20261124T190000\r\n"
    "DTSTART;TZID=America/Sao_Paulo:20261124T200000\r\nDTEND;TZID=America/Sao_Paulo:20261124T213000\r\n"
    "SUMMARY:Aula de violão (mais tarde)\r\nEND:VEVENT\r\n"
    "BEGIN:VEVENT\r\nUID:cancelado@teste\r\nDTSTART:20261201T100000\r\nSTATUS:CANCELLED\r\nSUMMARY:Nada\r\nEND:VEVENT\r\n"
    "BEGIN:VEVENT\r\nUID:aniv@teste\r\nDTSTART;VALUE=DATE:20260315\r\nRRULE:FREQ=YEARLY\r\nSUMMARY:Aniversário da Ana\r\n"
    "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT15H\r\nEND:VALARM\r\nEND:VEVENT\r\n"
    "END:VCALENDAR\r\n"
)


class Ics(unittest.TestCase):
    def setUp(self):
        self.tz = os.environ.get("TZ")
        os.environ["TZ"] = "America/Sao_Paulo"
        time.tzset()

    def tearDown(self):
        if self.tz is None:
            os.environ.pop("TZ", None)
        else:
            os.environ["TZ"] = self.tz
        time.tzset()

    def importar(self):
        eventos, ignorados = aj.importar_ics(ICS)
        return {e["uid"] + ("*" if e["repetir"] == "nunca" and "mais tarde" in e["titulo"] else ""): e for e in eventos}, ignorados

    def test_importar(self):
        evs, ignorados = self.importar()
        self.assertEqual(ignorados, 1)  # o cancelado
        self.assertEqual(len(evs), 5)
        v = evs["viagem@teste"]
        self.assertEqual((v["diaTodo"], v["inicio"], v["fim"]), (True, "2026-11-20", "2026-11-22"))
        self.assertEqual(v["titulo"], "Viagem para a praia, com a família")
        self.assertEqual(v["local"], "Ubatuba; SP")
        self.assertEqual(v["notas"], "Levar protetor\nE o guarda-sol")
        a = evs["aula@teste"]
        self.assertEqual((a["inicio"], a["fim"], a["repetir"]), ("2026-11-03T19:00", "2026-11-03T20:30", "semana"))
        self.assertEqual(a["titulo"], "Aula de violão com um título bem comprido que passa de setenta e cinco caracteres")
        self.assertEqual(a["lembrete"], 15)
        self.assertEqual(a["ate"], "2026-12-08")  # COUNT=6
        self.assertEqual(a["excecoes"], ["2026-11-17", "2026-11-24"])  # EXDATE e a ocorrência mudada
        self.assertEqual(evs["aula@teste*"]["inicio"], "2026-11-24T20:00")
        u = evs["utc@teste"]
        self.assertEqual((u["inicio"], u["fim"]), ("2026-11-12T12:00", "2026-11-12T12:45"))  # 15h UTC = 12h em Brasília
        n = evs["aniv@teste"]
        self.assertEqual((n["repetir"], n["lembrete"], n["fim"]), ("ano", 1440, "2026-03-15"))
        for e in evs.values():
            self.assertRegex(e["id"], r"^[0-9a-f]{10}$")

    def test_exportar(self):
        evs = [evento(id="a", titulo="Dentista, revisão; anual", local="Clínica", notas="Linha 1\nLinha 2", lembrete=60,
                      repetir="semana", excecoes=["2026-11-19"]),
               evento(id="b", titulo="Natal", diaTodo=True, inicio="2026-12-24", fim="2026-12-25", lembrete=1440, cor="coral"),
               evento(id="c", titulo="Ç" * 80)]
        texto = aj.exportar_ics(evs, agora=dt.datetime(2026, 11, 12, 12, tzinfo=dt.timezone.utc))
        self.assertTrue(texto.startswith("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"))
        self.assertTrue(texto.endswith("END:VCALENDAR\r\n"))
        self.assertIn("DTSTART:20261112T090000\r\n", texto)
        self.assertIn("SUMMARY:Dentista\\, revisão\\; anual\r\n", texto)
        self.assertIn("DESCRIPTION:Linha 1\\nLinha 2\r\n", texto)
        self.assertIn("RRULE:FREQ=WEEKLY\r\n", texto)
        self.assertIn("EXDATE:20261119T090000\r\n", texto)
        self.assertIn("TRIGGER:-PT1H\r\n", texto)
        self.assertIn("DTSTART;VALUE=DATE:20261224\r\nDTEND;VALUE=DATE:20261226\r\n", texto)
        self.assertIn("TRIGGER:-PT15H\r\n", texto)
        self.assertIn("X-MATSU-COR:coral\r\n", texto)
        for linha in texto.split("\r\n"):
            self.assertLessEqual(len(linha.encode("utf-8")), 75)
        self.assertNotIn("\n", texto.replace("\r\n", ""))

    def test_ida_e_volta(self):
        evs = [evento(id="a", titulo="Dentista, revisão; anual", local="Clínica \\ Centro", notas="Linha 1\nLinha 2", lembrete=60,
                      repetir="semana", excecoes=["2026-11-19"], ate="2027-01-28"),
               evento(id="b", titulo="Natal", diaTodo=True, inicio="2026-12-24", fim="2026-12-25", lembrete=0, cor="coral"),
               evento(id="c", titulo="Ç" * 80, lembrete=5)]
        volta, ignorados = aj.importar_ics(aj.exportar_ics(evs))
        self.assertEqual(ignorados, 0)
        campos = ("titulo", "diaTodo", "inicio", "fim", "cor", "lembrete", "repetir", "ate", "excecoes", "local", "notas")
        for ida, vinda in zip(evs, volta):
            self.assertEqual({k: ida[k] for k in campos}, {k: vinda[k] for k in campos})
            self.assertEqual(vinda["uid"], ida["id"] + "@calendario.matsu")

    def test_comandos(self):
        with tempfile.TemporaryDirectory() as tmp:
            dados = Path(tmp) / "eventos.json"
            dados.write_text(json.dumps({"eventos": [evento(id="a")]}))
            env = dict(os.environ, MATSU_CALENDARIO=str(dados))
            saida = Path(tmp) / "meu calendário"
            r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), "exportar", str(saida)], capture_output=True, text=True, env=env)
            self.assertEqual(json.loads(r.stdout), {"ok": True, "arquivo": str(saida) + ".ics", "n": 1})
            r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), "importar", "file://" + str(saida).replace(" ", "%20") + ".ics"],
                               capture_output=True, text=True, env=env)
            d = json.loads(r.stdout)
            self.assertTrue(d["ok"])
            self.assertEqual(d["nome"], "meu calendário.ics")
            self.assertEqual(d["eventos"][0]["titulo"], "Dentista")
            r = subprocess.run([sys.executable, "-I", "-S", str(AJUDANTE), "importar", str(Path(tmp) / "nao-existe.ics")],
                               capture_output=True, text=True, env=env)
            self.assertFalse(json.loads(r.stdout)["ok"])

    def test_arquivo_estranho(self):
        eventos, ignorados = aj.importar_ics("isto não é um calendário\nBEGIN:VEVENT\nSUMMARY:sem data\nEND:VEVENT\n")
        self.assertEqual((eventos, ignorados), ([], 1))
        self.assertEqual(aj.importar_ics(""), ([], 0))


@unittest.skipUnless(shutil.which("node"), "sem Node")
class MesmasContasNoQml(unittest.TestCase):
    """O datas.js (usado pelas telas) e o ajudante (usado pelos lembretes) dão o mesmo resultado."""

    def rodar_js(self, codigo):
        js = (PASTA / "datas.js").read_text().replace(".pragma library\n", "", 1)
        prog = "const module = {exports: {}};\n" + js + "\nconst D = module.exports;\n" + codigo
        r = subprocess.run(["node", "-e", prog], capture_output=True, text=True, env=dict(os.environ, TZ="America/Sao_Paulo"))
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads(r.stdout)

    def test_feriados(self):
        anos = [2000, 2019, 2023, 2024, 2026, 2027, 2038, 2099]
        js = self.rodar_js(f"console.log(JSON.stringify({anos}.map(a => D.feriados(a).map(f => f.chave + ' ' + f.nome))))")
        py = [[f"{f['data'].isoformat()} {f['nome']}" for f in aj.feriados(a)] for a in anos]
        self.assertEqual(js, py)

    def test_repeticoes(self):
        evs = [evento(id="s", repetir="semana", excecoes=["2026-11-26"]),
               evento(id="m", inicio="2026-01-31T08:00", fim="2026-01-31T09:00", repetir="mes"),
               evento(id="a", diaTodo=True, inicio="2024-02-29", fim="2024-03-01", repetir="ano"),
               evento(id="d", repetir="dia", ate="2026-12-03"),
               evento(id="v", diaTodo=True, inicio="2026-11-28", fim="2026-12-02")]
        js = self.rodar_js(f"const evs = {json.dumps(evs)};\n"
                           "console.log(JSON.stringify(D.ocorrencias(evs, new Date(2024, 0, 1), new Date(2028, 11, 31))"
                           ".map(o => o.ev.id + ' ' + o.chave)))")
        py = []
        for ev in evs:
            py += [f"{ev['id']} {i.date().isoformat()}" for i, _ in aj.ocorrencias(ev, D(2024, 1, 1), D(2028, 12, 31))]
        self.assertEqual(sorted(js), sorted(py))


if __name__ == "__main__":
    unittest.main()
