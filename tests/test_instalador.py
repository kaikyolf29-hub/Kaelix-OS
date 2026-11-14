#!/usr/bin/env python3
"""Testes do instalador do Matsu (installer/marca/usr/share/matsu-instalador).

Confere o motor (discos, conta, kickstart e a leitura do progresso do
anaconda) sem tela nenhuma, e que os arquivos que entram no updates.img
batem entre si (tmux.conf, iniciar, ícones usados pelas telas).
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
MARCA = RAIZ / "installer/marca"
TELAS = MARCA / "usr/share/matsu-instalador"
sys.path.insert(0, str(TELAS))
import motor  # noqa: E402

BASE_KS = (RAIZ / "installer/matsu.ks.in").read_text(encoding="utf-8").replace(
    "@IMAGE_REF@", "ghcr.io/kaikyolf29-hub/matsu-os:estavel")

LSBLK = json.dumps({"blockdevices": [
    {"name": "sda", "path": "/dev/sda", "size": 16008609792, "type": "disk", "model": "SanDisk Ultra",
     "tran": "usb", "rm": True, "ro": False, "rota": False, "fstype": "iso9660",
     "label": "Fedora-E-dvd-x86_64-44", "mountpoints": [None],
     "children": [{"name": "sda1", "path": "/dev/sda1", "size": 1000000000, "type": "part",
                   "fstype": "iso9660", "label": "Fedora-E-dvd-x86_64-44", "mountpoints": ["/run/install/repo"]}]},
    {"name": "nvme0n1", "path": "/dev/nvme0n1", "size": 512110190592, "type": "disk",
     "model": "Samsung SSD 980 PRO 512GB ", "tran": "nvme", "rm": False, "ro": False, "rota": False,
     "fstype": None, "label": None, "mountpoints": [None],
     "children": [
         {"name": "nvme0n1p1", "path": "/dev/nvme0n1p1", "size": 104857600, "type": "part", "fstype": "vfat"},
         {"name": "nvme0n1p2", "path": "/dev/nvme0n1p2", "size": 16777216, "type": "part", "fstype": None},
         {"name": "nvme0n1p3", "path": "/dev/nvme0n1p3", "size": 380000000000, "type": "part", "fstype": "ntfs"},
     ]},
    {"name": "vda", "path": "/dev/vda", "size": 68719476736, "type": "disk", "model": None,
     "tran": None, "rm": False, "ro": False, "rota": True, "fstype": None, "label": None, "mountpoints": [None]},
    {"name": "zram0", "path": "/dev/zram0", "size": 8000000000, "type": "disk", "ro": False},
    {"name": "sdb", "path": "/dev/sdb", "size": 8000000000, "type": "disk", "model": "Pendrive velho",
     "tran": "usb", "rm": True, "ro": False, "rota": False, "fstype": None, "mountpoints": [None],
     "children": [{"name": "sdb1", "path": "/dev/sdb1", "size": 8000000000, "type": "part", "fstype": "exfat"}]},
]})

# nvme0n1 com 380 GB de partições e o resto livre (setores de 512 bytes).
TABELA_NVME = {"partitiontable": {
    "label": "gpt", "device": "/dev/nvme0n1", "unit": "sectors", "firstlba": 2048,
    "lastlba": 1000215182, "sectorsize": 512,
    "partitions": [
        {"node": "/dev/nvme0n1p1", "start": 2048, "size": 204800},
        {"node": "/dev/nvme0n1p2", "start": 206848, "size": 32768},
        {"node": "/dev/nvme0n1p3", "start": 239616, "size": 742187500},
    ]}}

CMDLINE = "BOOT_IMAGE=/images/pxeboot/vmlinuz inst.stage2=hd:LABEL=Fedora-E-dvd-x86_64-44 quiet " \
          "inst.ks=hd:LABEL=Fedora-E-dvd-x86_64-44:/matsu.ks"


def escolhas(**mudar):
    e = {"idioma": "pt_BR.UTF-8", "teclado": "br-abnt2", "fuso": "America/Sao_Paulo",
         "disco": "/dev/nvme0n1", "modo": "apagar", "nome": "Kaiky Oliveira", "usuario": "kaiky"}
    e.update(mudar)
    return e


class Conta(unittest.TestCase):
    def test_usuario_sai_do_primeiro_nome_sem_acento(self):
        self.assertEqual(motor.usuario_do_nome("Kaiky Oliveira"), "kaiky")
        self.assertEqual(motor.usuario_do_nome("Ângela Sá"), "angela")
        self.assertEqual(motor.usuario_do_nome("  João  "), "joao")
        self.assertEqual(motor.usuario_do_nome("123 Teste"), "usuario")
        self.assertEqual(motor.usuario_do_nome("Root"), "root1")
        self.assertEqual(motor.usuario_do_nome(""), "usuario")

    def test_usuario_invalido_tem_explicacao(self):
        self.assertEqual(motor.problema_no_usuario("kaiky"), "")
        self.assertTrue(motor.problema_no_usuario("Kaiky"))
        self.assertTrue(motor.problema_no_usuario("1abc"))
        self.assertTrue(motor.problema_no_usuario("root"))
        self.assertTrue(motor.problema_no_usuario("com espaço"))

    def test_senha(self):
        self.assertTrue(motor.problema_na_senha("123", "123"))
        self.assertTrue(motor.problema_na_senha("segredo1", "segredo2"))
        self.assertTrue(motor.problema_na_senha("segredo1", ""))
        self.assertEqual(motor.problema_na_senha("segredo1", "segredo1"), "")

    def test_senha_cifrada_no_formato_do_shadow(self):
        cifrada = motor.cifrar_senha("segredo123")
        if cifrada is None:
            self.skipTest("sem libcrypt nem openssl nesta máquina")
        self.assertTrue(cifrada.startswith("$6$"), cifrada)
        self.assertNotIn("segredo123", cifrada)


class Discos(unittest.TestCase):
    def setUp(self):
        self.discos = motor.ler_discos(LSBLK, CMDLINE, {"/dev/nvme0n1": TABELA_NVME, "/dev/vda": None,
                                                        "/dev/sdb": {"partitiontable": {"partitions": []}}})

    def test_deixa_de_fora_o_pendrive_do_instalador_e_o_zram(self):
        nomes = [d["nome"] for d in self.discos]
        self.assertNotIn("sda", nomes)
        self.assertNotIn("zram0", nomes)
        self.assertEqual(nomes[-1], "sdb", "pendrives vão para o fim")

    def test_disco_com_windows(self):
        nvme = next(d for d in self.discos if d["nome"] == "nvme0n1")
        self.assertEqual(nvme["tipo"], "NVMe")
        self.assertEqual(nvme["sistemas"], ["Windows"])
        self.assertEqual(nvme["modelo"], "Samsung SSD 980 PRO 512GB")
        self.assertFalse(nvme["vazio"])
        # 1000215183 setores no total, 742424 mil ocupados até o fim da p3.
        esperado = (1000215183 - (239616 + 742187500)) * 512 - 1024 ** 2
        self.assertEqual(nvme["livre"], esperado)
        self.assertIn("tem Windows", motor.descricao_do_disco(nvme))

    def test_disco_vazio_usa_tudo(self):
        vda = next(d for d in self.discos if d["nome"] == "vda")
        self.assertTrue(vda["vazio"])
        self.assertEqual(vda["livre"], vda["tamanho"])
        self.assertEqual(vda["modelo"], "Disco vda")

    def test_rotulo_da_midia(self):
        self.assertEqual(motor.rotulo_da_midia(CMDLINE), "Fedora-E-dvd-x86_64-44")
        self.assertEqual(motor.rotulo_da_midia("inst.stage2=hd:LABEL=Matsu\\x2027:/x"), "Matsu 27")
        self.assertEqual(motor.rotulo_da_midia("quiet"), "")

    def test_tamanho_como_na_caixa_do_disco(self):
        self.assertEqual(motor.tamanho(512110190592), "512 GB")
        self.assertEqual(motor.tamanho(1000204886016), "1 TB")
        self.assertEqual(motor.tamanho(1500000000000), "1,5 TB")
        self.assertEqual(motor.tamanho(4_300_000_000), "4,3 GB")
        self.assertEqual(motor.tamanho(68719476736), "69 GB")


class Kickstart(unittest.TestCase):
    def test_apagar_o_disco(self):
        ks = motor.gerar_kickstart(BASE_KS, escolhas(), "$6$sal$cifrada")
        self.assertIn("ignoredisk --only-use=nvme0n1", ks)
        self.assertIn("zerombr", ks)
        self.assertIn("clearpart --all --initlabel --drives=nvme0n1", ks)
        self.assertIn("autopart --type=btrfs --noswap", ks)
        self.assertIn("rootpw --lock", ks)
        self.assertIn("user --name=kaiky --gecos=\"Kaiky Oliveira\" --groups=wheel --iscrypted "
                      "--password='$6$sal$cifrada'", ks)
        self.assertIn("network --hostname=matsu-kaiky", ks)
        self.assertIn("keyboard --vckeymap=br-abnt2 --xlayouts='br'", ks)
        self.assertIn("timezone America/Sao_Paulo --utc", ks)

    def test_ao_lado_nao_apaga_nada(self):
        ks = motor.gerar_kickstart(BASE_KS, escolhas(modo="lado"), "$6$x")
        self.assertNotIn("zerombr", ks)
        self.assertIn("clearpart --none --drives=nvme0n1", ks)

    def test_guarda_a_imagem_e_o_post_da_iso(self):
        ks = motor.gerar_kickstart(BASE_KS, escolhas(), "$6$x")
        self.assertIn("ostreecontainer --url=ghcr.io/kaikyolf29-hub/matsu-os:estavel", ks)
        self.assertIn("bootc switch --mutate-in-place --enforce-container-sigpolicy", ks)
        self.assertEqual(ks.count("%post"), ks.count("%end"))
        # O lang/keyboard/timezone da ISO não podem ficar duplicados.
        self.assertEqual(len(re.findall(r"^lang ", ks, re.M)), 1)
        self.assertEqual(len(re.findall(r"^keyboard ", ks, re.M)), 1)
        self.assertEqual(len(re.findall(r"^timezone ", ks, re.M)), 1)

    def test_idioma_do_sistema_vai_pelo_post(self):
        ks = motor.gerar_kickstart(BASE_KS, escolhas(idioma="es_ES.UTF-8", teclado="us-acentos"), "$6$x")
        self.assertIn("lang en_US.UTF-8", ks)
        self.assertIn("printf 'LANG=%s\\n' es_ES.UTF-8 > /etc/locale.conf", ks)
        self.assertIn("keyboard --vckeymap=us-acentos --xlayouts='us (intl)'", ks)

    def test_nome_com_aspas_nao_quebra_o_arquivo(self):
        ks = motor.gerar_kickstart(BASE_KS, escolhas(nome='Ka"iky: \\ O'), "$6$x")
        self.assertIn('--gecos="Kaiky  O"', ks)

    def test_recusa_escolha_estranha(self):
        for ruim in ({"disco": "/dev/sda; rm -rf /"}, {"idioma": "xx"}, {"fuso": "Lua/Base"}, {"usuario": "Root"}):
            with self.assertRaises(ValueError):
                motor.gerar_kickstart(BASE_KS, escolhas(**ruim), "$6$x")
        with self.assertRaises(ValueError):
            motor.gerar_kickstart(BASE_KS, escolhas(), None)

    def test_kickstart_valido_pelo_pykickstart(self):
        try:
            from pykickstart.parser import KickstartParser
            from pykickstart.version import makeVersion
        except ImportError:
            self.skipTest("pykickstart não está instalado")
        ks = motor.gerar_kickstart(BASE_KS, escolhas(), "$6$sal$cifrada")
        parser = KickstartParser(makeVersion())
        parser.readKickstartFromString(ks)
        self.assertEqual(parser.handler.user.userList[0].name, "kaiky")
        self.assertTrue(parser.handler.user.userList[0].isCrypted)


class Progresso(unittest.TestCase):
    SAIDA = """Starting installer, one moment...
anaconda 44.30-1.fc44 for Matsu 27 OS estavel started.
Starting automated install.....
Setting up the installation environment
Configuring storage
Creating disklabel on /dev/vda
Creating btrfs on /dev/vda3
Running pre-installation scripts
Running pre-installation tasks
.
Installing the software
Deployment starting: ghcr.io/kaikyolf29-hub/matsu-os:estavel
Deployment complete: ghcr.io/kaikyolf29-hub/matsu-os:estavel
Configuring storage
Installing boot loader
Performing post-installation setup tasks
Configuring installed system
Writing network configuration
Creating users
Configuring addons
Generating initramfs
Storing configuration files and kickstarts
Running post-installation scripts
Complete!
Installation complete
"""

    def test_anda_so_para_frente_e_termina(self):
        p = motor.Progresso()
        vistas = []
        for linha in self.SAIDA.splitlines():
            p.linha(linha)
            vistas.append(p.fracao)
        self.assertEqual(vistas, sorted(vistas))
        self.assertTrue(p.pronto)
        self.assertEqual(p.fracao, 1.0)
        self.assertEqual(p.erro, "")

    def test_download_pela_placa_de_rede(self):
        p = motor.Progresso(bytes_da_imagem=4_000_000_000)
        p.linha("Deployment starting: x")
        self.assertEqual(p.etapa, "baixando")
        self.assertTrue(p.bytes_recebidos(10_000_000_000 + 2_000_000_000, 10_000_000_000))
        self.assertAlmostEqual(p.fracao, motor.DOWNLOAD_INICIO + (motor.DOWNLOAD_FIM - motor.DOWNLOAD_INICIO) * 0.49)
        self.assertEqual(p.texto(), "Baixando o Matsu · 2 GB de 4 GB")
        p.linha("Deployment complete: x")
        self.assertEqual(p.texto(), "Configurando o sistema")

    def test_erro_do_anaconda(self):
        p = motor.Progresso()
        for linha in ["Configuring storage", "", "The installation was stopped due to an error which occurred while",
                      "The exact error message is: ", "", "Non interactive installation failed: disco pequeno.",
                      "", "The installer will now terminate."]:
            p.linha(linha)
        self.assertIn("disco pequeno", p.erro)
        self.assertFalse(p.pronto)

    def test_faltou_escolha(self):
        p = motor.Progresso()
        p.linha("The following mandatory spokes are not completed:")
        self.assertTrue(p.erro)


class Arquivos(unittest.TestCase):
    def test_tmux_abre_o_instalador_do_matsu(self):
        tmux = (MARCA / "usr/share/anaconda/tmux.conf").read_text(encoding="utf-8")
        self.assertIn("new-session -d -s anaconda -n main /usr/libexec/matsu-instalador/iniciar", tmux)
        self.assertNotIn("-n main anaconda", tmux)

    def test_iniciar_executavel_e_aponta_para_as_telas(self):
        iniciar = MARCA / "usr/libexec/matsu-instalador/iniciar"
        self.assertTrue(os.access(iniciar, os.X_OK))
        texto = iniciar.read_text(encoding="utf-8")
        self.assertIn('TELAS = "/usr/share/matsu-instalador/instalador.py"', texto)
        self.assertIn("SAIR_PARA_O_AVANCADO = 10", texto)
        self.assertIn("SAIR_PARA_O_AVANCADO = 10", (TELAS / "instalador.py").read_text(encoding="utf-8"))

    def test_codigo_compila(self):
        for arq in (TELAS / "instalador.py", TELAS / "motor.py", MARCA / "usr/libexec/matsu-instalador/iniciar"):
            compile(arq.read_text(encoding="utf-8"), str(arq), "exec")

    def test_icones_usados_pelas_telas_entram_no_updates(self):
        with tempfile.TemporaryDirectory() as tmp:
            destino = Path(tmp) / "marca"
            subprocess.run(["bash", str(RAIZ / "installer/montar-updates.sh"), str(destino)], check=True)
            pasta = destino / "usr/share/matsu-instalador"
            tem = {p.stem.replace("matsu-", "").replace("-symbolic", "") for p in (pasta / "icones").glob("*.svg")}
            codigo = (TELAS / "instalador.py").read_text(encoding="utf-8")
            usados = set(re.findall(r'icone\("([a-z0-9-]+)"', codigo))
            usados |= {f"wifi-{n}" for n in range(4)}
            self.assertFalse(usados - tem, f"ícones que faltam: {usados - tem}")
            self.assertEqual((pasta / "edicao").read_text(), re.sub(r"\D", "", (RAIZ / "EDICAO").read_text()))
            self.assertTrue((pasta / "papel.png").is_file())
            self.assertTrue(os.access(destino / "usr/libexec/matsu-instalador/iniciar", os.X_OK))


if __name__ == "__main__":
    unittest.main()
