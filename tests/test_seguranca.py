#!/usr/bin/env python3
"""Testes da Central de segurança do Matsu (system_files/usr/share/matsu/seguranca).

Tudo numa pasta pessoal de mentira: quarentena e restauração, lista de exceções
por SHA-256, origem do arquivo pelo atributo do navegador, filtro dos arquivos
que ainda estão baixando, pausa com prazo, e a leitura do firewall, do Flatpak
e da integridade com saídas de mentira. Um clamd de mentira (num soquete local)
confere a conversa FILDES/INSTREAM.

Uso: python3 tests/test_seguranca.py
"""
import importlib
import json
import os
import socket
import struct
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest import mock

PASTA = Path(__file__).resolve().parents[1] / "system_files/usr/share/matsu/seguranca"
sys.path.insert(0, str(PASTA))

EICAR = b"X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.casa = Path(self.tmp.name) / "kaiky"
        (self.casa / ".config").mkdir(parents=True)
        (self.casa / "Downloads").mkdir()
        (self.casa / "Área de trabalho").mkdir()
        (self.casa / ".config" / "user-dirs.dirs").write_text(
            'XDG_DOWNLOAD_DIR="$HOME/Downloads"\nXDG_DESKTOP_DIR="$HOME/Área de trabalho"\n', encoding="utf-8")
        self.env = mock.patch.dict(os.environ, {
            "HOME": str(self.casa), "XDG_CONFIG_HOME": str(self.casa / ".config"),
            "XDG_DATA_HOME": str(self.casa / ".local" / "share"),
            "MATSU_SEGURANCA_EXECUCAO": str(Path(self.tmp.name) / "run"),
            "MATSU_BOOT_ID": "boot-1", "LANG": "pt_BR.UTF-8", "LC_ALL": "", "LANGUAGE": "", "MATSU_LANG": "pt_BR",
        })
        self.env.start()
        import nucleo
        import sistema
        self.N = importlib.reload(nucleo)
        self.S = importlib.reload(sistema)

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def arquivo(self, nome, conteudo=b"oi", pasta="Downloads"):
        caminho = self.casa / pasta / nome
        caminho.write_bytes(conteudo)
        return caminho


class TestQuarentena(Base):
    def test_quarentena_e_restauracao(self):
        N = self.N
        alvo = self.arquivo("virus.exe", EICAR)
        os.chmod(alvo, 0o755)
        sha = N.sha256_arquivo(alvo)
        r = N.quarentenar(str(alvo), "Eicar-Test-Signature", url="https://site.example/x")
        self.assertFalse(alvo.exists(), "o arquivo sai do lugar")
        guardado = Path(N.pasta_quarentena()) / (r["id"] + ".bin")
        self.assertTrue(guardado.exists())
        self.assertEqual(guardado.stat().st_mode & 0o777, 0o400, "sem permissão de execução")
        self.assertNotIn(b"EICAR", guardado.read_bytes(), "guardado embaralhado")
        self.assertEqual(Path(N.pasta_quarentena()).stat().st_mode & 0o777, 0o700)
        lista = N.listar_quarentena()
        self.assertEqual(len(lista), 1)
        self.assertEqual(lista[0]["origem"], str(alvo))
        self.assertEqual(lista[0]["url"], "https://site.example/x")
        self.assertEqual(lista[0]["sha256"], sha)
        self.assertEqual(N.ler_historico()[0]["tipo"], "quarentena")

        # Alguém pôs outro arquivo com o mesmo nome: restaura com outro nome.
        self.arquivo("virus.exe", b"outro")
        volta = N.restaurar(r["id"])
        self.assertTrue(volta["ok"])
        self.assertTrue(volta["caminho"].endswith("virus (restaurado).exe"))
        self.assertEqual(Path(volta["caminho"]).read_bytes(), EICAR)
        self.assertEqual(Path(volta["caminho"]).stat().st_mode & 0o777, 0o755)
        self.assertEqual(N.listar_quarentena(), [])
        self.assertTrue(N.tem_excecao(sha), "restaurar libera o SHA-256 para o escudo não pegar de novo")
        self.assertEqual(N.ler_historico()[0]["tipo"], "restaurado")

    def test_restaurar_sem_a_pasta_vai_para_downloads(self):
        N = self.N
        pendrive = Path(self.tmp.name) / "pendrive"
        pendrive.mkdir()
        alvo = pendrive / "a.exe"
        alvo.write_bytes(b"MZ123")
        r = N.quarentenar(str(alvo), "X")
        pendrive.rmdir()
        volta = N.restaurar(r["id"])
        self.assertEqual(Path(volta["caminho"]).parent, self.casa / "Downloads")

    def test_apagar_de_vez(self):
        N = self.N
        r = N.quarentenar(str(self.arquivo("b.exe", b"MZ")), "Y")
        self.assertTrue(N.apagar_quarentena(r["id"]))
        self.assertEqual(N.listar_quarentena(), [])
        self.assertEqual(os.listdir(N.pasta_quarentena()), [])
        self.assertEqual(N.ler_historico()[0]["tipo"], "apagado")
        with self.assertRaises(ValueError):
            N.restaurar("../../etc/passwd")


class TestExcecoes(Base):
    def test_lista_por_sha256(self):
        N = self.N
        a = self.arquivo("app.AppImage", b"\x7fELF" + b"\0" * 60)
        sha = N.sha256_arquivo(a)
        self.assertFalse(N.tem_excecao(sha))
        N.por_excecao(sha, str(a), "https://x.example/app", "aberto mesmo assim")
        self.assertTrue(N.tem_excecao(sha))
        self.assertTrue(N.tem_excecao(sha.upper()))
        # O mesmo SHA de novo não duplica (e vai para o começo).
        N.por_excecao(sha, str(a))
        self.assertEqual(len(N.ler_excecoes()), 1)
        self.assertEqual(N.ler_excecoes()[0]["nome"], "app.AppImage")
        # Outro arquivo com o mesmo nome mas outro conteúdo não está liberado.
        a.write_bytes(b"mudou")
        self.assertFalse(N.tem_excecao(N.sha256_arquivo(a)))
        self.assertTrue(N.tirar_excecao(sha))
        self.assertFalse(N.tem_excecao(sha))
        with self.assertRaises(ValueError):
            N.por_excecao("nao-e-sha")


class TestOrigem(Base):
    def test_atributo_do_navegador(self):
        N = self.N
        fora = Path(self.tmp.name) / "outro"
        fora.mkdir()
        f = fora / "jogo.exe"
        f.write_bytes(b"MZ")
        self.assertFalse(N.origem(str(f))["internet"], "fora de Downloads e sem atributo: local")
        try:
            os.setxattr(f, "user.xdg.origin.url", b"https://www.gratis-download.example/jogo.exe")
            os.setxattr(f, "user.xdg.referrer.url", b"https://busca.example/?q=jogo")
        except OSError:
            self.skipTest("o sistema de arquivos do teste não aceita atributos user.*")
        o = N.origem(str(f))
        self.assertTrue(o["internet"])
        self.assertEqual(o["site"], "gratis-download.example")
        self.assertEqual(o["url"], "https://www.gratis-download.example/jogo.exe")
        self.assertFalse(o["downloads"])

    def test_pasta_downloads_conta_como_internet(self):
        N = self.N
        f = self.arquivo("setup.run", b"#!/bin/sh\n")
        o = N.origem(str(f))
        self.assertTrue(o["downloads"])
        self.assertTrue(o["internet"])
        self.assertEqual(o["site"], "")
        sub = self.casa / "Downloads" / "pasta"
        sub.mkdir()
        (sub / "x.sh").write_text("#!/bin/sh\n")
        self.assertTrue(N.origem(str(sub / "x.sh"))["downloads"])

    def test_nomes_reais_das_pastas(self):
        p = self.N.pastas_usuario()
        self.assertEqual(p["downloads"], str(self.casa / "Downloads"))
        self.assertEqual(p["area"], str(self.casa / "Área de trabalho"))

    def test_site_de(self):
        self.assertEqual(self.N.site_de("https://user@WWW.Exemplo.com.br:8080/a?b"), "exemplo.com.br")
        self.assertEqual(self.N.site_de("nada"), "")


class TestTemporarios(Base):
    def test_filtro_de_downloads(self):
        e = self.N.e_temporario
        for nome in ("filme.mkv.crdownload", "jogo.zip.part", "x.iso.Ab12Cd.part", "a.tmp", "b.!qB", "c.aria2",
                     ".com.google.Chrome.aB3dEf", ".goutputstream-XYZ", "doc.docx~", "~$planilha.xlsx", "f.partial",
                     ".~lock.texto.odt#"):
            self.assertTrue(e(nome), nome)
        for nome in ("filme.mkv", "jogo.zip", "partitura.pdf", "app.AppImage", "setup.exe", "tmp.txt", "parte.part1.rar"):
            self.assertFalse(e(nome), nome)


class TestPausa(Base):
    def test_pausa_com_prazo(self):
        N = self.N
        c = N.ler_config()
        self.assertTrue(c["ligado"])
        self.assertFalse(N.estado_pausa(c)["pausado"])
        agora = 1_000_000.0
        p = N.pausar(c, 15, agora=agora)
        self.assertEqual(p["pausa_ate"], agora + 900)
        self.assertTrue(N.estado_pausa(p, agora=agora + 60)["pausado"])
        self.assertFalse(N.pausa_venceu(p, agora=agora + 60))
        self.assertTrue(N.pausa_venceu(p, agora=agora + 901), "volta sozinho depois de 15 min")
        self.assertFalse(N.estado_pausa(p, agora=agora + 901)["pausado"])
        hora = N.pausar(c, 60, agora=agora)
        self.assertEqual(hora["pausa_ate"], agora + 3600)
        self.assertFalse(N.estado_pausa(N.retomar(hora), agora=agora)["pausado"])

    def test_pausa_ate_reiniciar(self):
        N = self.N
        p = N.pausar(N.ler_config(), "reiniciar")
        self.assertTrue(N.estado_pausa(p)["reiniciar"])
        self.assertFalse(N.pausa_venceu(p))
        with mock.patch.dict(os.environ, {"MATSU_BOOT_ID": "boot-2"}):
            self.assertTrue(N.pausa_venceu(p), "reiniciou: o escudo volta")
            self.assertFalse(N.estado_pausa(p)["pausado"])

    def test_config_gravada_e_limpa(self):
        N = self.N
        c = N.ler_config()
        c["pendrive_auto"] = True
        c["lixo"] = "x"
        N.gravar_config(c)
        lido = N.ler_config()
        self.assertTrue(lido["pendrive_auto"])
        self.assertNotIn("lixo", lido)
        Path(N.arquivo_config()).write_text('{"ligado": "sim"}')
        self.assertTrue(N.ler_config()["ligado"], "valor de tipo errado volta ao padrão")


class ClamdFalso:
    """Um clamd pequeno: responde PING, FILDES (lê o descritor recebido) e INSTREAM."""

    def __init__(self, caminho, fildes_quebrado=False):
        self.caminho = caminho
        self.fildes_quebrado = fildes_quebrado
        self.comandos = []
        self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.s.bind(caminho)
        self.s.listen(5)
        threading.Thread(target=self._servir, daemon=True).start()

    def _resposta(self, dados, rotulo):
        return (rotulo + (": Eicar-Test-Signature FOUND" if b"EICAR" in dados else ": OK")).encode() + b"\0"

    def _servir(self):
        while True:
            try:
                c, _ = self.s.accept()
            except OSError:
                return
            with c:
                cmd = b""
                while not cmd.endswith(b"\0"):
                    b = c.recv(1)
                    if not b:
                        break
                    cmd += b
                cmd = cmd.strip(b"\0").lstrip(b"z").decode()
                self.comandos.append(cmd)
                if cmd == "PING":
                    c.sendall(b"PONG\0")
                elif cmd == "FILDES":
                    _msg, fds, _f, _a = socket.recv_fds(c, 1, 1)
                    if self.fildes_quebrado:
                        os.close(fds[0])
                        c.sendall(b"fd[9]: lstat() failed: Permission denied. ERROR\0")
                        continue
                    with os.fdopen(fds[0], "rb") as f:
                        c.sendall(self._resposta(f.read(), "fd[%d]" % fds[0]))
                elif cmd == "INSTREAM":
                    dados = b""
                    while True:
                        tam = struct.unpack(">I", c.recv(4, socket.MSG_WAITALL))[0]
                        if tam == 0:
                            break
                        dados += c.recv(tam, socket.MSG_WAITALL)
                    c.sendall(self._resposta(dados, "stream"))
                elif cmd == "SHUTDOWN":
                    self.s.close()
                    return


class TestClamd(Base):
    def test_respostas(self):
        r = self.N.ler_resposta
        self.assertEqual(r("fd[10]: OK\0"), ("OK", ""))
        self.assertEqual(r("fd[10]: Win.Test.EICAR_HDB-1 FOUND\0"), ("FOUND", "Win.Test.EICAR_HDB-1"))
        self.assertEqual(r("stream: OK"), ("OK", ""))
        self.assertEqual(r("fd[3]: Size limit reached ERROR")[0], "ERROR")

    def test_fildes_e_fluxo(self):
        N = self.N
        sock = os.path.join(self.tmp.name, "clamd.sock")
        falso = ClamdFalso(sock)
        c = N.Clamd(sock, tempo=5)
        self.assertTrue(c.pronto())
        limpo = self.arquivo("limpo.txt", b"nada aqui")
        virus = self.arquivo("eicar.com", EICAR)
        self.assertEqual(c.verificar(str(limpo)), ("OK", ""))
        self.assertEqual(c.verificar(str(virus)), ("FOUND", "Eicar-Test-Signature"))
        self.assertIn("FILDES", falso.comandos)
        self.assertEqual(c.verificar(str(self.casa)), ("ERROR", "não é um arquivo comum"))
        self.assertTrue(c.desligar())

    def test_sem_descritor_usa_o_fluxo(self):
        N = self.N
        N.Clamd.so_fluxo = False
        sock = os.path.join(self.tmp.name, "clamd2.sock")
        falso = ClamdFalso(sock, fildes_quebrado=True)
        c = N.Clamd(sock, tempo=5)
        self.assertEqual(c.verificar(str(self.arquivo("e.com", EICAR))), ("FOUND", "Eicar-Test-Signature"))
        self.assertIn("INSTREAM", falso.comandos)
        self.assertTrue(N.Clamd.so_fluxo)
        N.Clamd.so_fluxo = False

    def test_lista_de_ameacas(self):
        N = self.N
        db = Path(self.tmp.name) / "clamav"
        db.mkdir()
        self.assertFalse(N.lista_presente(str(db)))
        (db / "main.cvd").write_bytes(b"x")
        self.assertFalse(N.lista_presente(str(db)))
        cabeca = b"ClamAV-VDB:13 Nov 2026 04-23 +0000:27827:2077840:90:x:y:z"
        (db / "daily.cld").write_bytes(cabeca.ljust(512, b" "))
        self.assertTrue(N.lista_presente(str(db)))
        info = N.info_lista(str(db))
        self.assertEqual(info["versao"], 27827)
        self.assertEqual(info["assinaturas"], 2077840)


class TestVarredura(Base):
    def test_pula_jogos_caches_e_quarentena(self):
        N = self.N
        for p in (".local/share/Steam/steamapps/common/Jogo", ".cache/x", "Games/y", ".var/app/org.app/cache",
                  "Documentos/projeto/node_modules/z", "Documentos/projeto/src", ".local/share/matsu/seguranca/quarentena"):
            (self.casa / p).mkdir(parents=True)
            (self.casa / p / "arquivo.bin").write_bytes(b"x")
        os.symlink("/etc", self.casa / "atalho")
        achados = {os.path.relpath(c, self.casa) for c, _t in N.arquivos_de([str(self.casa)])}
        self.assertIn("Documentos/projeto/src/arquivo.bin", achados)
        self.assertIn(".config/user-dirs.dirs", achados)
        for proibido in ("Steam", ".cache", "Games", "node_modules", "quarentena", ".var/app/org.app/cache", "atalho"):
            self.assertFalse(any(proibido in a for a in achados), proibido)

    def test_raizes_rapida(self):
        raizes = self.N.raizes_rapida()
        self.assertIn(str(self.casa / "Downloads"), raizes)
        self.assertIn(str(self.casa / "Área de trabalho"), raizes)


class TestTipos(Base):
    def test_tipos_e_assinatura(self):
        N = self.N
        appimage = self.arquivo("x.AppImage", b"\x7fELF\x02\x01\x01\x00AI\x02" + b"\0" * 60)
        self.assertEqual(N.tipo_arquivo(str(appimage)), "appimage")
        self.assertEqual(N.assinatura(str(appimage), "appimage"), "nao")
        self.assertEqual(N.tipo_arquivo(str(self.arquivo("y", b"\x7fELF\x02\x01" + b"\0" * 60))), "elf")
        self.assertEqual(N.tipo_arquivo(str(self.arquivo("libz.so.1", b"\x7fELF\x02\x01" + b"\0" * 60))), "biblioteca")
        self.assertEqual(N.tipo_arquivo(str(self.arquivo("instalar", b"#!/bin/bash\necho"))), "script")
        self.assertEqual(N.tipo_arquivo(str(self.arquivo("driver.run", b"#!/bin/sh\n"))), "instalador")
        self.assertEqual(N.tipo_arquivo(str(self.arquivo("a.deb", b"!<arch>"))), "deb")
        self.assertEqual(N.tipo_arquivo(str(self.arquivo("b.rpm", b"\xed\xab\xee\xdb"))), "rpm")
        self.assertEqual(N.tipo_arquivo(str(self.arquivo("c.jar", b"PK"))), "java")
        # Um .exe sem assinatura (diretório de segurança vazio) e um com.
        pe = bytearray(512)
        pe[0:2] = b"MZ"
        pe[0x3C:0x40] = struct.pack("<I", 0x80)
        pe[0x80:0x84] = b"PE\0\0"
        pe[0x98:0x9A] = struct.pack("<H", 0x20B)
        sem = self.arquivo("sem.exe", bytes(pe))
        self.assertEqual(N.tipo_arquivo(str(sem)), "windows")
        self.assertEqual(N.assinatura(str(sem), "windows"), "nao")
        pe[0x98 + 112 + 32:0x98 + 112 + 40] = struct.pack("<II", 0x400, 0x1A00)
        com = self.arquivo("com.exe", bytes(pe))
        self.assertEqual(N.assinatura(str(com), "windows"), "sim")


class TestFirewall(Base):
    def test_nmcli_e_zonas(self):
        S = self.S
        saida = ("Casa\\: 5G:8c2a6a3e-6f0b-4e7a-9c1d-2b9f0d4f1a77:802-11-wireless:wlp4s0\n"
                 "lo:11111111-2222-3333-4444-555555555555:loopback:lo\n"
                 "Cabo:0f0e0d0c-0b0a-0908-0706-050403020100:802-3-ethernet:enp3s0\n")
        conexoes = S.ler_conexoes(saida)
        self.assertEqual([c["nome"] for c in conexoes], ["Casa: 5G", "Cabo"])
        self.assertEqual(conexoes[0]["tipo"], "wifi")
        self.assertEqual(S.tipo_da_zona("matsu-casa"), "casa")
        self.assertEqual(S.tipo_da_zona("FedoraWorkstation"), "outra")
        self.assertEqual(S.ler_zona_padrao("# x\nDefaultZone=matsu-publica\nFoo=1\n"), "matsu-publica")

    def test_zonas_do_matsu(self):
        S = self.S
        raiz = Path(__file__).resolve().parents[1] / "system_files/usr/lib/firewalld/zones"
        casa = S.ler_zona_xml((raiz / "matsu-casa.xml").read_text())
        publica = S.ler_zona_xml((raiz / "matsu-publica.xml").read_text())
        self.assertEqual(publica["servicos"], ["dhcpv6-client"], "a rede pública fecha tudo")
        self.assertNotIn("ssh", casa["servicos"], "sem ssh aberto na rede de casa")
        for s in ("mdns", "samba-client", "kdeconnect", "steam-streaming"):
            self.assertIn(s, casa["servicos"])
        for s in casa["servicos"]:
            self.assertTrue(s == "dhcpv6-client" or s in S.IDS_SERVICOS or s in ("ws-discovery-client", "llmnr-client"), s)

    def test_zona_padrao_de_etc_ou_de_usr_lib(self):
        S = self.S
        etc = Path(self.tmp.name) / "etc-sem-conf"
        etc.mkdir()
        usr = Path(self.tmp.name) / "usr-firewalld"
        usr.mkdir()
        (usr / "firewalld.conf").write_text("DefaultZone=matsu-publica\n")
        with mock.patch.object(S, "FIREWALLD_ETC", str(etc)), mock.patch.object(S, "FIREWALLD_USR", str(usr)):
            self.assertEqual(S.zona_padrao(), "matsu-publica", "sem /etc, vale o de /usr/lib")
            (etc / "firewalld.conf").write_text("DefaultZone=matsu-casa\n")
            self.assertEqual(S.zona_padrao(), "matsu-casa", "o de /etc vale mais")

    def test_rede_com_saidas_de_mentira(self):
        S = self.S
        etc = Path(self.tmp.name) / "etc-firewalld"
        (etc / "zones").mkdir(parents=True)
        (etc / "firewalld.conf").write_text("DefaultZone=matsu-publica\n")
        (etc / "zones" / "matsu-casa.xml").write_text('<zone><service name="kdeconnect"/><service name="ssh"/></zone>')
        usr = Path(__file__).resolve().parents[1] / "system_files/usr/lib/firewalld"
        respostas = {
            ("systemctl", "is-active"): (0, "active\n"),
            ("nmcli", "-t"): (0, "Casa:8c2a6a3e-6f0b-4e7a-9c1d-2b9f0d4f1a77:802-11-wireless:wlp4s0\n"),
            ("nmcli", "-g"): (0, "matsu-casa\n"),
        }

        def falso(args, tempo=30, entrada=None):
            return respostas.get(tuple(args[:2]), (1, ""))

        with mock.patch.object(S, "FIREWALLD_ETC", str(etc)), mock.patch.object(S, "FIREWALLD_USR", str(usr)), \
                mock.patch.object(S, "rodar", falso):
            r = S.rede()
        self.assertEqual(r["firewall"], "ligado")
        self.assertTrue(r["padraoMatsu"])
        self.assertEqual(r["conexoes"][0]["rede"], "casa")
        ligados = {s["id"] for s in r["servicos"] if s["ligado"]}
        self.assertEqual(ligados, {"kdeconnect", "ssh"}, "lê a cópia mudada em /etc")
        self.assertTrue(r["casaMudada"])

    def test_servico_desconhecido_recusado(self):
        with mock.patch.object(self.S, "rodar") as rodar:
            self.assertFalse(self.S.servico_casa("telnet", True)["ok"])
            self.assertFalse(self.S.trocar_tipo("x; rm -rf", "casa")["ok"])
            rodar.assert_not_called()


METADATA = """[Application]
name=com.discordapp.Discord

[Context]
shared=network;ipc;
sockets=x11;pulseaudio;
devices=all;
filesystems=xdg-download;xdg-pictures:ro;xdg-config/kdeglobals:ro;

[Session Bus Policy]
org.freedesktop.Notifications=talk
"""


class TestFlatpak(Base):
    def test_permissoes_com_overrides(self):
        S = self.S
        padrao = S.ler_contexto(METADATA)
        override = S.ler_contexto("[Context]\nshared=!network;\nsockets=!pulseaudio;\nfilesystems=!xdg-download;home;\n")
        ctx = S.juntar(padrao, override)
        portal = S.ler_permissoes_portal("devices\tcamera\tcom.discordapp.Discord\tno\t0x00\n"
                                         "location\tlocation\tcom.discordapp.Discord\tEXACT,0\t{}\n")
        p = S.permissoes_efetivas(ctx, portal)
        self.assertFalse(p["rede"])
        self.assertFalse(p["microfone"])
        self.assertFalse(p["camera"], "o portal disse não")
        self.assertTrue(p["localizacao"])
        self.assertTrue(p["arquivos"])
        self.assertEqual(p["arquivosTexto"], "A pasta pessoal inteira")
        self.assertTrue(p["notificacoes"])
        d = S.permissoes_efetivas(padrao, {})
        self.assertTrue(d["camera"] and d["microfone"] and d["rede"])
        self.assertEqual(d["arquivosTexto"], "Downloads, Imagens", "kdeglobals não conta como arquivo pessoal")

    def test_comandos_de_cada_chave(self):
        S = self.S
        padrao = S.ler_contexto(METADATA)
        app = "com.discordapp.Discord"
        cmds = S.comandos_permissao(app, "camera", False, padrao, padrao)
        self.assertIn(["flatpak", "permission-set", "devices", "camera", app, "no"], cmds)
        self.assertIn(["flatpak", "override", "--user", "--nodevice=all", "--device=dri", app], cmds)
        self.assertEqual(S.comandos_permissao(app, "microfone", False, padrao, padrao),
                         [["flatpak", "override", "--user", "--nosocket=pulseaudio", app]])
        self.assertEqual(S.comandos_permissao(app, "rede", True, padrao, padrao),
                         [["flatpak", "override", "--user", "--share=network", app]])
        arq = S.comandos_permissao(app, "arquivos", False, padrao, padrao)
        self.assertEqual(arq, [["flatpak", "override", "--user", "--nofilesystem=xdg-download",
                                "--nofilesystem=xdg-pictures", app]])
        volta = S.comandos_permissao(app, "arquivos", True, padrao, S.ler_contexto(""))
        self.assertEqual(volta[0][-3:], ["--filesystem=xdg-download", "--filesystem=xdg-pictures", app])
        notif = S.comandos_permissao(app, "notificacoes", False, padrao, padrao)
        self.assertIn(["flatpak", "override", "--user", "--no-talk-name=org.freedesktop.Notifications", app], notif)

    def test_lista_dos_apps_instalados(self):
        S = self.S
        sistema = Path(self.tmp.name) / "flatpak"
        app = "com.discordapp.Discord"
        (sistema / "app" / app / "current" / "active").mkdir(parents=True)
        (sistema / "app" / app / "current" / "active" / "metadata").write_text(METADATA)
        (sistema / "exports" / "share" / "applications").mkdir(parents=True)
        (sistema / "exports" / "share" / "applications" / (app + ".desktop")).write_text(
            "[Desktop Entry]\nName=Discord\nName[pt_BR]=Discord BR\n")
        icones = sistema / "exports" / "share" / "icons" / "hicolor" / "128x128" / "apps"
        icones.mkdir(parents=True)
        (icones / (app + ".png")).write_bytes(b"png")
        usuario = self.casa / ".local" / "share" / "flatpak"
        (usuario / "overrides").mkdir(parents=True)
        (usuario / "overrides" / app).write_text("[Context]\nsockets=!pulseaudio;\n")

        def falso(args, tempo=30, entrada=None):
            return (0, "") if args[:2] == ["flatpak", "--version"] else (0, "")

        with mock.patch.object(S, "FLATPAK_SISTEMA", str(sistema)), mock.patch.object(S, "rodar", falso):
            r = S.apps()
        self.assertTrue(r["flatpak"])
        a = r["apps"][0]
        self.assertEqual(a["nome"], "Discord BR")
        self.assertTrue(a["icone"].endswith("128x128/apps/com.discordapp.Discord.png"))
        self.assertTrue(a["mudado"])
        self.assertFalse(a["permissoes"]["microfone"])
        self.assertTrue(a["padrao"]["microfone"])

    def test_pedido_invalido(self):
        self.assertFalse(self.S.mudar_permissao("com.app; rm", "camera", True)["ok"])
        self.assertFalse(self.S.mudar_permissao("com.app", "tudo", True)["ok"])


class TestIntegridade(Base):
    def test_imagem_assinada(self):
        S = self.S
        status = json.dumps({"deployments": [
            {"booted": False, "container-image-reference": "ostree-unverified-registry:ghcr.io/x/matsu-os:latest"},
            {"booted": True, "container-image-reference": "ostree-image-signed:docker://ghcr.io/kaikyolf29-hub/matsu-os:latest",
             "version": "27.2"}]})
        r = S.ler_status_ostree(status)
        self.assertTrue(r["assinada"])
        self.assertEqual(r["versao"], "27.2")
        politica = json.dumps({"default": [{"type": "insecureAcceptAnything"}], "transports": {"docker": {
            "ghcr.io/kaikyolf29-hub/matsu-os": [{"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/matsu-os.pub"}]}}})
        self.assertTrue(S.politica_tem_chave(r["referencia"], politica))
        self.assertFalse(S.politica_tem_chave("ostree-image-signed:docker://ghcr.io/outro/img:1", politica))
        nao = S.ler_status_ostree(json.dumps({"deployments": [
            {"booted": True, "container-image-reference": "ostree-unverified-registry:ghcr.io/x/y:latest"}]}))
        self.assertFalse(nao["assinada"] or nao["verificada"])
        bootc = S.ler_status_bootc(json.dumps({"spec": {"image": {"signature": "containerPolicy"}},
                                                "status": {"booted": {"image": {"image": {"image": "ghcr.io/a/b"}}}}}))
        self.assertTrue(bootc["assinada"])

    def test_secure_boot_disco_e_remotos(self):
        S = self.S
        self.assertTrue(S.ler_secure_boot(b"\x06\x00\x00\x00\x01"))
        self.assertFalse(S.ler_secure_boot(b"\x06\x00\x00\x00\x00"))
        self.assertIsNone(S.ler_secure_boot(b""))
        lsblk = json.dumps({"blockdevices": [{"name": "nvme0n1", "type": "disk", "fstype": None, "mountpoints": [None],
                                              "children": [
            {"name": "nvme0n1p1", "type": "part", "fstype": "vfat", "mountpoints": ["/boot/efi"]},
            {"name": "nvme0n1p3", "type": "part", "fstype": "crypto_LUKS", "mountpoints": [None], "children": [
                {"name": "luks-abc", "type": "crypt", "fstype": "btrfs", "mountpoints": ["/sysroot", "/var/home", "/var"]}]}]}]})
        d = S.ler_lsblk(lsblk)
        self.assertTrue(d["raiz"])
        self.assertTrue(d["casa"])
        self.assertTrue(d["mesmoDisco"])
        sem = S.ler_lsblk(json.dumps({"blockdevices": [{"name": "sda", "type": "disk", "children": [
            {"name": "sda2", "type": "part", "fstype": "btrfs", "mountpoints": ["/sysroot", "/var"]}]}]}))
        self.assertFalse(sem["raiz"])
        remotos = S.ler_remotos(['[core]\nmode=bare\n\n[remote "flathub"]\nurl=https://dl.flathub.org/repo/\ngpg-verify=true\n',
                                 '[remote "teste"]\nurl=http://x\ngpg-verify = false\n'])
        self.assertEqual(remotos, {"flathub": True, "teste": False})
        self.assertEqual(S.ler_politica_rpm_ostree("[Daemon]\nAutomaticUpdatePolicy=stage\n"), "stage")

    def test_integridade_sem_nada_nao_finge(self):
        S = self.S
        with mock.patch.object(S, "rodar", lambda *a, **k: (127, "")), \
                mock.patch.object(S, "EFIVARS", os.path.join(self.tmp.name, "sem-efi")), \
                mock.patch.object(S, "FLATPAK_SISTEMA", os.path.join(self.tmp.name, "sem-flatpak")):
            r = S.integridade()
        estados = {i["id"]: i["estado"] for i in r["itens"]}
        self.assertEqual(estados["assinatura"], "?")
        self.assertEqual(estados["disco"], "?")
        self.assertEqual(estados["atualizacoes"], "?")
        self.assertEqual(estados["flatpak"], "?")
        self.assertEqual(estados["secureboot"], "desligado", "sem EFI: modo antigo, sem Secure Boot")


class TestAjudante(Base):
    def setUp(self):
        super().setUp()
        import ajudante
        self.A = importlib.reload(ajudante)

    def test_estado_sem_clamav(self):
        A = self.A
        with mock.patch.object(self.N, "CLAMD_BIN", "/nao/existe"):
            e = A.estado()
        self.assertEqual(e["geral"], "indisponivel")
        self.assertEqual(e["idioma"], "pt")
        nomes = [p["nome"] for p in e["escudo"]["pastas"]]
        self.assertEqual(nomes, ["Downloads", "Área de trabalho"])

    def test_estado_pausado_e_atencao(self):
        A, N = self.A, self.N
        db = Path(self.tmp.name) / "db"
        db.mkdir()
        (db / "main.cvd").write_bytes(b"x")
        (db / "daily.cvd").write_bytes(b"ClamAV-VDB:x:1:2:".ljust(512, b" "))
        sem_systemctl = mock.patch.object(N, "rodar", lambda *a, **k: (127, ""))
        with mock.patch.object(N, "CLAMD_BIN", sys.executable), mock.patch.object(N, "CLAMAV_DB", str(db)), sem_systemctl:
            self.assertEqual(A.estado()["geral"], "parado", "escudo sem batida")
            N.gravar_json(N.arquivo_escudo(), {"pid": os.getpid(), "batida": time.time(), "clamd": "parado"})
            self.assertEqual(A.estado()["geral"], "protegido")
            N.gravar_config(N.pausar(N.ler_config(), 15))
            e = A.estado()
            self.assertEqual(e["geral"], "pausado")
            self.assertGreater(e["escudo"]["pausaAte"], time.time())
            N.gravar_config(N.retomar(N.ler_config()))
            N.quarentenar(str(self.arquivo("v.exe", EICAR)), "Eicar")
            self.assertEqual(A.estado()["geral"], "atencao")
            c = N.ler_config()
            c["visto_ate"] = int(time.time()) + 1
            N.gravar_config(c)
            self.assertEqual(A.estado()["geral"], "protegido", "visto na central: sai da atenção")

    def test_abrir_local_nao_avisa_e_internet_avisa(self):
        A, N = self.A, self.N
        fora = self.casa / "Projetos"
        fora.mkdir()
        local = fora / "meu.AppImage"
        local.write_bytes(b"\x7fELF\x02\x01\x01\x00AI\x02" + b"\0" * 60)
        baixado = self.arquivo("baixado.AppImage", local.read_bytes() + b"1")
        with mock.patch.object(A, "abrir_aviso") as aviso, mock.patch.object(N, "soltar", return_value=True) as soltar:
            A.abrir(str(local))
            aviso.assert_not_called()
            self.assertTrue(os.access(local, os.X_OK), "AppImage local ganha permissão de execução e abre")
            soltar.assert_called_once()
            A.abrir(str(baixado))
            aviso.assert_called_once_with(str(baixado))
            N.por_excecao(N.sha256_arquivo(baixado), str(baixado))
            A.abrir(str(baixado))
            self.assertEqual(aviso.call_count, 1, "liberado antes: abre direto")

    def test_script_local_abre_no_editor(self):
        A = self.A
        fora = self.casa / "scripts"
        fora.mkdir()
        s = fora / "backup.sh"
        s.write_text("#!/bin/sh\necho oi\n")
        apps = self.casa / ".local" / "share" / "applications"
        apps.mkdir(parents=True)
        (apps / "editor.desktop").write_text("[Desktop Entry]\nExec=editor --novo %F\n")
        (self.casa / ".config" / "mimeapps.list").write_text(
            "[Default Applications]\napplication/x-shellscript=org.matsu.seguranca.aviso.desktop;editor.desktop;\n")
        with mock.patch.object(A, "abrir_aviso") as aviso, mock.patch.object(self.N, "soltar", return_value=True) as soltar:
            A.abrir(str(s))
        aviso.assert_not_called()
        self.assertEqual(soltar.call_args[0][0], ["editor", "--novo", str(s)])

    def test_pacote_mostra_explicacao(self):
        A = self.A
        deb = self.arquivo("app.deb", b"!<arch>\n")
        with mock.patch.object(A, "abrir_aviso") as aviso:
            A.abrir(str(deb))
        aviso.assert_called_once()
        self.assertEqual(A.executar(A.examinar(str(deb)))["acao"], "pacote")

    def test_inicio_do_processo_para_o_pkcheck(self):
        texto = self.A._inicio_processo()
        self.assertRegex(texto, r"^\d+,\d+,\d+$")

    def test_comandos_demo(self):
        """Os dados de mentira (para as fotos) também têm o formato certo."""
        with mock.patch.object(self.A, "DEMO", "atencao"):
            self.assertEqual(self.A.estado()["geral"], "atencao")
            self.assertEqual(self.A.demo_aviso()["modo"], "aviso")
            self.assertTrue(self.A.demo_historico()["quarentena"])

    def test_loja_abre_o_app_ou_o_inicio(self):
        with mock.patch.object(self.N, "soltar", return_value=True) as soltar:
            self.A.loja("com.usebottles.bottles")
            self.assertEqual(soltar.call_args[0][0][-2:], ["app", "com.usebottles.bottles"])
            self.A.loja("inicio")
            self.assertEqual(soltar.call_args[0][0][-1], "inicio")


class TestArquivosDaJanela(unittest.TestCase):
    """As telas em QML pedem só ícones e peças que existem."""

    def test_icones_pedidos_existem(self):
        import re
        nomes = set()
        for qml in list(PASTA.glob("*.qml")):
            texto = qml.read_text(encoding="utf-8")
            nomes |= set(re.findall(r'ic\("([a-z-]+)"\)', texto))
            nomes |= set(re.findall(r'icones/([a-z-]+)\.svg', texto))
        self.assertTrue(nomes)
        faltam = [n for n in sorted(nomes) if not (PASTA / "icones" / (n + ".svg")).exists()]
        self.assertEqual(faltam, [])
        # Os da bandeja também.
        bandeja = (PASTA.parents[1] / "plasma/plasmoids/org.matsu.seguranca/contents/ui/main.qml").read_text(encoding="utf-8")
        for n in re.findall(r'"([a-z-]+)\.svg"', bandeja):
            self.assertTrue((PASTA / "icones" / (n + ".svg")).exists(), n)

    def test_paginas_da_janela_existem(self):
        import re
        main = (PASTA / "Main.qml").read_text(encoding="utf-8")
        for arq in re.findall(r'"(Pagina[A-Za-z]+\.qml)"', main):
            self.assertTrue((PASTA / arq).exists(), arq)
        meta = json.loads((PASTA.parents[1] / "plasma/plasmoids/org.matsu.seguranca/metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(meta["X-Plasma-NotificationArea"], "true")
        self.assertEqual(meta["KPlugin"]["Id"], "org.matsu.seguranca")


if __name__ == "__main__":
    unittest.main(verbosity=1)
