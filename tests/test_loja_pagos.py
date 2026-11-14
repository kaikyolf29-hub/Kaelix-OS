#!/usr/bin/python3
"""Testes da Loja do Matsu ligada ao servidor: apps do repositório "matsu" (selo,
preço, escondidos), catálogo baixado do servidor, códigos de resgate e licenças
(com um servidor de mentira que assina com uma chave Ed25519 de teste, pelo
openssl) e a versão nova do sistema (com um bootc de mentira)."""
import base64
import gzip
import hashlib
import http.server
import json
import os
import subprocess
import sys
import tempfile
import threading
import time

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOJA = os.path.join(RAIZ, "system_files", "usr", "share", "matsu", "loja")
AJUDANTE = os.path.join(LOJA, "ajudante.py")
ok = falhas = 0


def check(nome, cond):
    global ok, falhas
    if cond:
        ok += 1
    else:
        falhas += 1
        print("FALHOU:", nome)


FLATHUB = """<?xml version="1.0" encoding="UTF-8"?>
<components version="0.8" origin="flathub">
  <component type="desktop-application">
    <id>com.discordapp.Discord</id>
    <name>Discord</name>
    <summary>Chat</summary>
    <categories><category>Network</category></categories>
  </component>
</components>
"""

MATSU = """<?xml version="1.0" encoding="UTF-8"?>
<components version="0.8" origin="matsu">
  <component type="desktop-application">
    <id>com.exemplo.Pago</id>
    <name>App Pago</name>
    <summary xml:lang="pt_BR">Um app pago da Loja</summary>
    <summary>A paid app</summary>
    <developer><name>Exemplo</name></developer>
    <categories><category>Office</category></categories>
    <custom><value key="matsu::loja">true</value><value key="matsu::pago">true</value>
      <value key="matsu::preco">R$ 19,90</value><value key="matsu::comprar">https://exemplo.com/comprar</value></custom>
  </component>
  <component type="desktop-application">
    <id>com.exemplo.Gratis</id>
    <name>App Grátis</name>
    <summary>Free</summary>
    <categories><category>Utility</category></categories>
    <custom><value key="matsu::loja">true</value></custom>
  </component>
  <component type="desktop-application">
    <id>org.matsu.TesteLoja</id>
    <name>Teste da Loja</name>
    <summary>Teste</summary>
    <categories><category>Utility</category></categories>
    <custom><value key="matsu::loja">true</value><value key="matsu::oculto">true</value></custom>
  </component>
</components>
"""

CATALOGO = {
    "versao": 2,
    "destaques": [{"id": "org.matsu.TesteLoja", "titulo": "Escondido"}, {"id": "com.discordapp.Discord", "titulo": "Discord"}],
    "secoes": [{"id": "so-no-servidor", "titulo": "Essenciais", "apps": ["com.discordapp.Discord", "org.matsu.TesteLoja"]}],
    "web": [],
    "no_sistema": {},
    "publicar": {"email": "loja@exemplo.com", "texto": {"pt": "Mande um e-mail", "en": "Send an email"}},
    # O servidor manda o preço mais novo (sem esperar o AppStream).
    "matsu": {"com.exemplo.Pago": {"pago": True, "preco": "R$ 24,90", "comprar": "https://exemplo.com/novo",
                                   "planos": "Para sempre, 3 computadores", "oculto": False}},
}


def openssl(*args, entrada=None):
    return subprocess.run(["openssl", *args], input=entrada, capture_output=True, check=True).stdout


class Servidor:
    """O servidor da Loja de mentira: o catálogo público e a função resgatar."""

    def __init__(self, pasta, computador):
        self.pasta = pasta
        self.computador = computador
        self.privada = os.path.join(pasta, "chave.pem")
        openssl("genpkey", "-algorithm", "ed25519", "-out", self.privada)
        der = openssl("pkey", "-in", self.privada, "-pubout", "-outform", "DER")
        self.publica = base64.b64encode(der[-32:]).decode()
        self.ativacoes = {}
        self.catalogo = json.dumps(CATALOGO).encode()
        servidor = self

        class H(http.server.BaseHTTPRequestHandler):
            def log_message(self, *a):
                pass

            def responder(self, status, corpo, tipo="application/json"):
                self.send_response(status)
                self.send_header("Content-Type", tipo)
                self.send_header("Content-Length", str(len(corpo)))
                self.end_headers()
                self.wfile.write(corpo)

            def do_GET(self):
                if self.path == "/storage/v1/object/public/loja/catalogo.json":
                    self.responder(200, servidor.catalogo)
                else:
                    self.responder(400, b'{"statusCode":"404","error":"not_found"}')

            def do_POST(self):
                corpo = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                status, r = servidor.resgatar(corpo)
                self.responder(status, json.dumps(r).encode())

        self.http = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
        self.url = "http://127.0.0.1:%d" % self.http.server_address[1]
        threading.Thread(target=self.http.serve_forever, daemon=True).start()

    def licenca(self, app, plano, expira):
        dados = json.dumps({"v": 1, "app": app, "computador": self.computador, "plano": plano, "expira": expira,
                            "emitida": int(time.time()), "codigo": "MATSU-••••-••••-CCCC"}).encode()
        caminho = os.path.join(self.pasta, "dados.bin")
        with open(caminho, "wb") as f:
            f.write(dados)
        assinatura = openssl("pkeyutl", "-sign", "-inkey", self.privada, "-rawin", "-in", caminho)
        return {"dados": base64.b64encode(dados).decode(), "assinatura": base64.b64encode(assinatura).decode()}

    def resgatar(self, corpo):
        if corpo.get("acao") == "restaurar":
            lic = [{"app": a, "licenca": self.licenca(a, "sempre", 0)} for a in self.ativacoes.get(corpo["computador"], [])]
            return 200, {"ok": True, "licencas": lic}
        codigo = "".join(c for c in str(corpo.get("codigo", "")).upper() if c.isalnum())
        if codigo == "MATSUAAAABBBBCCCC" and corpo.get("computador") == self.computador:
            apps = ["com.exemplo.Pago", "com.exemplo.Gratis"]
            self.ativacoes[self.computador] = apps
            return 200, {"ok": True, "apps": apps, "plano": "sempre", "expira": 0, "computadores": 3, "usados": 1,
                         "licencas": [{"app": a, "licenca": self.licenca(a, "sempre", 0)} for a in apps]}
        if codigo == "MATSUVENCVENCVENC":
            return 200, {"ok": True, "apps": ["com.exemplo.Pago"], "plano": "dias", "expira": 1000,
                         "licencas": [{"app": "com.exemplo.Pago", "licenca": self.licenca("com.exemplo.Pago", "dias", 1000)}]}
        return 404, {"ok": False, "erro": "codigo-invalido", "mensagem": "Esse código não existe. Confira as letras."}


def rodar(args, env):
    r = subprocess.run([sys.executable, "-I", "-S", AJUDANTE] + args, capture_output=True, text=True, env=env, timeout=60)
    return r.returncode, r.stdout, r.stderr


def main():
    with tempfile.TemporaryDirectory() as tmp:
        # O resumo deste computador vem de um machine-id de mentira.
        maquina = os.path.join(tmp, "machine-id")
        with open(maquina, "w") as f:
            f.write("0123456789abcdef0123456789abcdef\n")
        computador = hashlib.sha256(b"matsu-loja:0123456789abcdef0123456789abcdef").hexdigest()
        servidor = Servidor(tmp, computador)
        # O kit de licença com a chave de teste e o machine-id de mentira.
        with open(os.path.join(LOJA, "licenca.py"), encoding="utf-8") as f:
            kit = f.read()
        check("o kit do sistema traz a chave da Loja", "UAB0M5942punutDAPzeJyGPTLEnfZ3xymCNUWpJXA5U=" in kit)
        kit = kit.replace("UAB0M5942punutDAPzeJyGPTLEnfZ3xymCNUWpJXA5U=", servidor.publica)
        kit = kit.replace('("/etc/machine-id", "/var/lib/dbus/machine-id")', repr((maquina,)))
        kit_teste = os.path.join(tmp, "licenca.py")
        with open(kit_teste, "w", encoding="utf-8") as f:
            f.write(kit)

        for remoto, xml in (("flathub", FLATHUB), ("matsu", MATSU)):
            ativa = os.path.join(tmp, "appstream", remoto, "x86_64", "active")
            os.makedirs(ativa)
            with gzip.open(os.path.join(ativa, "appstream.xml.gz"), "wt", encoding="utf-8") as f:
                f.write(xml)
        cat = os.path.join(tmp, "catalogo.json")
        with open(cat, "w") as f:
            json.dump(CATALOGO, f)
        env = {k: v for k, v in os.environ.items() if "proxy" not in k.lower()}
        env.update(MATSU_LOJA_APPSTREAM=os.path.join(tmp, "appstream"), MATSU_LOJA_CACHE=os.path.join(tmp, "cache"),
                   MATSU_LOJA_CATALOGO=cat, MATSU_LOJA_APPS_SISTEMA=os.path.join(tmp, "nada"), HOME=tmp,
                   XDG_DATA_HOME=os.path.join(tmp, "dados"), XDG_CONFIG_HOME=os.path.join(tmp, "config"),
                   MATSU_LANG="pt_BR.UTF-8", MATSU_LOJA_ARQ="x86_64", MATSU_LOJA_SERVIDOR=servidor.url,
                   MATSU_LOJA_LICENCA_PY=kit_teste, NO_PROXY="*")

        # ----- apps do repositório da Loja do Matsu -----
        codigo, saida, erro = rodar(["catalogo"], env)
        check("catalogo roda: " + erro[-300:], codigo == 0)
        d = json.loads(saida or "{}")
        apps = {a["id"]: a for a in d.get("apps", [])}
        pago = apps.get("com.exemplo.Pago", {})
        check("app do repositório matsu tem o selo", pago.get("matsu") is True and apps["com.exemplo.Gratis"]["matsu"] is True)
        check("app do Flathub não tem o selo", apps["com.discordapp.Discord"]["matsu"] is False)
        check("o preço do servidor vale mais que o do AppStream", pago.get("pago") is True and pago.get("preco") == "R$ 24,90")
        check("app grátis não é pago", apps["com.exemplo.Gratis"]["pago"] is False)
        check("o escondido vem marcado (a janela tira das listas)", apps["org.matsu.TesteLoja"]["oculto"] is True)
        check("o escondido não entra nos destaques", [x["id"] for x in d["destaques"]] == ["com.discordapp.Discord"])
        secoes = {s["id"]: s for s in d["secoes"]}
        check("o escondido não entra nas seções", secoes["so-no-servidor"]["apps"] == ["com.discordapp.Discord"])
        check("seção Feito para o Matsu em primeiro, sem o escondido",
              d["secoes"][0]["id"] == "matsu" and d["secoes"][0]["titulo"] == "Feito para o Matsu"
              and d["secoes"][0]["apps"] == ["com.exemplo.Gratis", "com.exemplo.Pago"])
        check("a contagem não conta o escondido", d["categorias"] == {"internet": 1, "escritorio": 1, "utilitarios": 1})
        check("o cartão de publicar vem com o e-mail", d["publicar"] == {"email": "loja@exemplo.com", "texto": "Mande um e-mail"})
        codigo, saida, _ = rodar(["detalhes", "com.exemplo.Pago"], env)
        det = json.loads(saida or "{}")
        check("detalhes do pago: onde comprar e planos", det.get("comprar") == "https://exemplo.com/novo"
              and det.get("planos") == "Para sempre, 3 computadores")
        codigo, saida, _ = rodar(["detalhes", "org.matsu.TesteLoja"], env)
        check("o escondido abre pelo link", codigo == 0 and json.loads(saida)["nome"] == "Teste da Loja")

        # ----- o catálogo baixado do servidor -----
        env_online = dict(env)
        env_online.pop("MATSU_LOJA_CATALOGO")
        env_online["MATSU_LOJA_CACHE"] = os.path.join(tmp, "cache-online")
        codigo, saida, _ = rodar(["catalogo"], env_online)
        check("sem o catálogo do servidor, vale o do sistema",
              codigo == 0 and "so-no-servidor" not in [s["id"] for s in json.loads(saida)["secoes"]])
        codigo, saida, erro = rodar(["atualizar-catalogo"], env_online)
        r = json.loads(saida or "{}")
        check("baixar o catálogo do servidor muda a Loja: " + erro[-200:], r.get("mudou") is True)
        codigo, saida, _ = rodar(["atualizar-catalogo"], env_online)
        check("o mesmo catálogo de novo não muda nada", json.loads(saida).get("mudou") is False)
        codigo, saida, _ = rodar(["catalogo"], env_online)
        check("o catálogo do servidor é usado", "so-no-servidor" in [s["id"] for s in json.loads(saida)["secoes"]])
        servidor.catalogo = b"<html>fora do ar</html>"
        os.utime(os.path.join(tmp, "cache-online", "catalogo-online.json"), (1, 1))
        codigo, saida, _ = rodar(["atualizar-catalogo"], env_online)
        codigo, saida, _ = rodar(["catalogo"], env_online)
        check("servidor quebrado não estraga o catálogo guardado", "so-no-servidor" in [s["id"] for s in json.loads(saida)["secoes"]])

        # ----- códigos de resgate e licenças -----
        codigo, saida, _ = rodar(["licencas"], env)
        check("sem licenças no começo", codigo == 0 and json.loads(saida) == {"licencas": {}, "computador": True})
        codigo, saida, erro = rodar(["resgatar", "matsu-aaaa-bbbb-cccc"], env)
        r = json.loads(saida or "{}")
        check("resgatar dá certo (combo com dois apps): " + erro[-300:],
              codigo == 0 and r.get("ok") and r.get("apps") == ["com.exemplo.Pago", "com.exemplo.Gratis"]
              and r.get("computadores") == 3 and r.get("usados") == 1)
        guardada = os.path.join(tmp, "config", "matsu", "licencas", "com.exemplo.Pago.json")
        na_caixa = os.path.join(tmp, ".var", "app", "com.exemplo.Pago", "config", "matsu", "licencas", "com.exemplo.Pago.json")
        check("licença guardada na configuração e na pasta do app no Flatpak", os.path.exists(guardada) and os.path.exists(na_caixa))
        codigo, saida, _ = rodar(["licencas"], env)
        lic = json.loads(saida)["licencas"]
        check("as duas licenças valem para sempre", lic.get("com.exemplo.Pago", {}).get("valida") is True
              and lic["com.exemplo.Pago"]["plano"] == "sempre" and lic["com.exemplo.Pago"]["expira"] == 0
              and lic.get("com.exemplo.Gratis", {}).get("valida") is True)
        # O app pago, de dentro da caixa do Flatpak, confere com o kit.
        env_app = dict(env, XDG_CONFIG_HOME=os.path.join(tmp, ".var", "app", "com.exemplo.Pago", "config"))
        r_app = subprocess.run([sys.executable, kit_teste, "com.exemplo.Pago"], capture_output=True, text=True, env=env_app)
        check("o app confere a licença de dentro da caixa dele", r_app.returncode == 0 and "Liberado para sempre" in r_app.stdout)

        codigo, saida, _ = rodar(["resgatar", "MATSU-ZZZZ-ZZZZ-ZZZZ"], env)
        r = json.loads(saida or "{}")
        check("código que não existe: mensagem do servidor", codigo == 1 and r["ok"] is False
              and r["erro"] == "codigo-invalido" and "não existe" in r["mensagem"])

        # Licença mexida à mão não vale.
        with open(guardada, encoding="utf-8") as f:
            l = json.load(f)
        dados = json.loads(base64.b64decode(l["dados"]))
        dados["app"] = "com.exemplo.Gratis"
        l["dados"] = base64.b64encode(json.dumps(dados).encode()).decode()
        with open(guardada, "w", encoding="utf-8") as f:
            json.dump(l, f)
        codigo, saida, _ = rodar(["licencas"], env)
        mexida = json.loads(saida)["licencas"]["com.exemplo.Pago"]
        check("licença mexida à mão não vale", mexida["valida"] is False and mexida["motivo"] == "assinatura")

        # Formatou o computador: restaurar busca de novo.
        os.remove(guardada)
        codigo, saida, _ = rodar(["restaurar"], env)
        r = json.loads(saida or "{}")
        check("restaurar devolve as licenças deste computador", codigo == 0 and r.get("ok")
              and sorted(r["apps"]) == ["com.exemplo.Gratis", "com.exemplo.Pago"])
        codigo, saida, _ = rodar(["licencas"], env)
        check("depois de restaurar vale de novo", json.loads(saida)["licencas"]["com.exemplo.Pago"]["valida"] is True)

        codigo, saida, _ = rodar(["resgatar", "MATSU-VENC-VENC-VENC"], env)
        codigo, saida, _ = rodar(["licencas"], env)
        check("licença vencida aparece como vencida", json.loads(saida)["licencas"]["com.exemplo.Pago"]["motivo"] == "vencida")

        # Sem servidor (sem internet): mensagem amigável.
        env_sem = dict(env, MATSU_LOJA_SERVIDOR="http://127.0.0.1:9")
        codigo, saida, _ = rodar(["resgatar", "MATSU-AAAA-BBBB-CCCC"], env_sem)
        r = json.loads(saida or "{}")
        check("sem internet: mensagem amigável", codigo == 1 and r["erro"] == "sem-internet" and "internet" in r["mensagem"])

        # ----- a versão nova do sistema -----
        falso = os.path.join(tmp, "atualizacoes.py")
        with open(falso, "w", encoding="utf-8") as f:
            f.write("ARQUIVO = 'x'\n"
                    "def ler_arquivo(caminho):\n    return []\n"
                    "def para_janela(versoes, procurar):\n"
                    "    return {'versao': '27.1', 'edicao': '27', 'remota': {'versao': '27.2', 'novidades': ['Loja nova']} if procurar else None,\n"
                    "            'baixada': False, 'procurado': 1, 'conseguiu': True if procurar else None}\n")
        bootc = os.path.join(tmp, "matsu-atualizar-sistema")
        with open(bootc, "w", encoding="utf-8") as f:
            f.write("#!/usr/bin/bash\nfor i in 1 3 3 2 10; do printf 'Fetching layers ███ %s/10\\r' $i; sleep 0.05; done\n"
                    "printf '\\nQueued for next boot\\n'\n")
        os.chmod(bootc, 0o755)
        env_sis = dict(env, MATSU_ATUALIZACOES_AJUDANTE=falso, MATSU_LOJA_ATUALIZAR_SISTEMA=bootc)
        codigo, saida, erro = rodar(["sistema"], env_sis)
        s = json.loads(saida or "{}")
        check("sistema: versão e edição: " + erro[-200:], codigo == 0 and s.get("versao") == "27.1" and s.get("edicao") == "27"
              and s.get("remota") is None and s.get("pode") is True)
        codigo, saida, _ = rodar(["sistema", "--procurar"], env_sis)
        check("sistema --procurar acha a versão nova", json.loads(saida)["remota"]["versao"] == "27.2")
        codigo, saida, erro = rodar(["atualizar-sistema"], env_sis)
        linhas = [json.loads(x) for x in saida.splitlines() if x.strip()]
        progresso = [x["progresso"] for x in linhas if "progresso" in x and not x.get("fim")]
        check("atualizar-sistema dá certo: " + erro[-200:], codigo == 0 and linhas[-1].get("fim") and linhas[-1].get("ok"))
        check("o progresso do sistema só sobe: %s" % progresso, progresso == sorted(progresso) and 30 in progresso and progresso[-1] <= 99)
        with open(bootc, "w", encoding="utf-8") as f:
            f.write("#!/usr/bin/bash\necho 'error: Not authorized' >&2\nexit 126\n")
        codigo, saida, _ = rodar(["atualizar-sistema"], env_sis)
        fim = json.loads(saida.splitlines()[-1])
        check("sem permissão vira mensagem amigável", codigo == 1 and fim["ok"] is False and "permissão" in fim["erro"])
        codigo, saida, _ = rodar(["sistema"], dict(env, MATSU_ATUALIZACOES_AJUDANTE=os.path.join(tmp, "nao-existe.py")))
        check("sem o ajudante das atualizações não quebra", codigo == 1 and json.loads(saida)["pode"] is False)

        servidor.http.shutdown()

    # O repositório da Loja que vem no sistema: a chave e o endereço certos.
    with open(os.path.join(LOJA, "matsu.flatpakrepo"), encoding="utf-8") as f:
        repo = dict(l.split("=", 1) for l in f.read().splitlines() if "=" in l)
    check("o .flatpakrepo aponta para o balde da Loja",
          repo.get("Url") == "https://orrybyqdyezsoaoeozky.supabase.co/storage/v1/object/public/loja/repo/")
    check("o .flatpakrepo traz a chave GPG da Loja", len(base64.b64decode(repo.get("GPGKey", ""))) > 500)

    print(f"Resultado: {ok} passaram, {falhas} falharam")
    return 0 if falhas == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
