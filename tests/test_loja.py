#!/usr/bin/python3
"""Testes do ajudante da Loja do Matsu, com um AppStream e um flatpak de mentira."""
import gzip
import json
import os
import subprocess
import sys
import tempfile
import textwrap

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AJUDANTE = os.path.join(RAIZ, "system_files", "usr", "share", "matsu", "loja", "ajudante.py")
ok = falhas = 0


def check(nome, cond):
    global ok, falhas
    if cond:
        ok += 1
    else:
        falhas += 1
        print("FALHOU:", nome)


APPSTREAM = """<?xml version="1.0" encoding="UTF-8"?>
<components version="0.8" origin="flathub">
  <component type="desktop-application">
    <id>com.discordapp.Discord</id>
    <name>Discord</name>
    <summary>Messaging, voice and video client</summary>
    <summary xml:lang="pt_BR">Mensagens, voz e vídeo</summary>
    <developer><name>Discord Inc.</name></developer>
    <description>
      <p>Discord is the easiest way to talk.</p>
      <p xml:lang="pt_BR">O Discord é o jeito mais fácil de conversar.</p>
      <ul><li>Voice</li><li>Video</li></ul>
      <ul><li xml:lang="pt_BR">Voz</li><li xml:lang="pt_BR">Vídeo &amp; tela</li></ul>
    </description>
    <icon type="cached" width="64" height="64">com.discordapp.Discord.png</icon>
    <icon type="cached" width="128" height="128">com.discordapp.Discord.png</icon>
    <categories><category>Network</category><category>InstantMessaging</category></categories>
    <keywords><keyword>chat</keyword><keyword xml:lang="pt_BR">conversa</keyword></keywords>
    <url type="homepage">https://discord.com</url>
    <project_license>LicenseRef-proprietary</project_license>
    <screenshots>
      <screenshot type="default">
        <caption xml:lang="pt_BR">Conversa</caption>
        <image type="source">https://exemplo/s1.png</image>
        <image type="thumbnail" width="624" height="351">https://exemplo/s1-624.png</image>
        <image type="thumbnail" width="1248" height="702">https://exemplo/s1-1248.png</image>
        <image type="thumbnail" width="2496" height="1404">https://exemplo/s1-2496.png</image>
      </screenshot>
      <screenshot><image type="source">https://exemplo/s2.png</image></screenshot>
    </screenshots>
    <releases><release version="0.0.70" timestamp="1730000000"/></releases>
    <custom><value key="flathub::verification::verified">true</value></custom>
  </component>
  <component type="desktop-application">
    <id>com.heroicgameslauncher.hgl.desktop</id>
    <name>Heroic Games Launcher</name>
    <summary>Epic, GOG and Amazon games</summary>
    <categories><category>Game</category></categories>
  </component>
  <component type="desktop-application">
    <id>com.valvesoftware.Steam</id>
    <name>Steam</name>
    <summary>Games</summary>
    <categories><category>Game</category></categories>
  </component>
  <component type="runtime">
    <id>org.freedesktop.Platform</id>
    <name>Freedesktop Platform</name>
  </component>
  <component type="addon">
    <id>org.gimp.GIMP.Plugin.Foo</id>
    <name>Plugin</name>
  </component>
</components>
"""

CATALOGO = {
    "destaques": [{"id": "com.discordapp.Discord", "titulo": {"pt": "Discord PT", "en": "Discord EN"},
                   "texto": {"pt": "Texto PT", "en": "Text EN"}, "cores": ["#111111", "#222222"]},
                  {"id": "com.nao.Existe", "titulo": "Some"}],
    "secoes": [{"id": "jogar", "titulo": {"pt": "Para jogar", "en": "For gaming"},
                "apps": ["com.heroicgameslauncher.hgl", "com.nao.Existe", "com.valvesoftware.Steam"]},
               {"id": "vazia", "titulo": "Vazia", "apps": ["com.nao.Existe"]}],
    "web": [{"id": "instagram", "nome": "Instagram", "url": "https://www.instagram.com/", "cor": "#E1306C",
             "resumo": {"pt": "Fotos", "en": "Photos"}}],
    "no_sistema": {"com.valvesoftware.Steam": "steam.desktop"},
}

FLATPAK = r"""#!/usr/bin/bash
echo "$*" >> "$FAKE_LOG"
case "$1" in
  list)
    printf 'com.discordapp.Discord\tDiscord\t0.0.70\tflathub\tsystem\t300 MB\n'
    printf 'com.brave.Browser\tBrave\t1.70\tflathub\tuser\t400 MB\n' ;;
  remote-ls)
    [[ $2 == --system ]] && printf 'com.discordapp.Discord\t0.0.71\tflathub\n' ;;
  install)
    printf 'Installing 1/2… ██ 10%%  1.0 MB/s  00:10\rInstalling 1/2… ████ 50%%\rInstalling 1/2… ████████ 100%%\n'
    printf 'Installing 2/2… 40%%\rInstalling 2/2… 100%%\n'
    [[ ${FAKE_FALHA:-} == rede ]] && { echo "error: Could not resolve hostname"; exit 1; }
    exit 0 ;;
  update)
    if [[ $* == *--appstream* ]]; then
      [[ -n ${FAKE_APPSTREAM:-} ]] && touch "$FAKE_APPSTREAM"
      exit 0
    fi
    printf 'Uninstalling 1/1\r 100%%\n'; exit 0 ;;
  uninstall) printf 'Uninstalling 1/1\r 100%%\n'; exit 0 ;;
esac
"""


def rodar(args, env):
    r = subprocess.run([sys.executable, "-I", "-S", AJUDANTE] + args, capture_output=True, text=True, env=env, timeout=60)
    return r.returncode, r.stdout, r.stderr


def main():
    with tempfile.TemporaryDirectory() as tmp:
        ativa = os.path.join(tmp, "appstream", "flathub", "x86_64", "active")
        os.makedirs(os.path.join(ativa, "icons", "128x128"))
        os.makedirs(os.path.join(ativa, "icons", "64x64"))
        for tam in ("64x64", "128x128"):
            open(os.path.join(ativa, "icons", tam, "com.discordapp.Discord.png"), "wb").write(b"png")
        open(os.path.join(ativa, "icons", "128x128", "com.heroicgameslauncher.hgl.png"), "wb").write(b"png")
        with gzip.open(os.path.join(ativa, "appstream.xml.gz"), "wt", encoding="utf-8") as f:
            f.write(APPSTREAM)
        cat = os.path.join(tmp, "catalogo.json")
        json.dump(CATALOGO, open(cat, "w"))
        sistema = os.path.join(tmp, "apps-sistema")
        os.makedirs(sistema)
        open(os.path.join(sistema, "steam.desktop"), "w").write("[Desktop Entry]\nName=Steam\n")
        binarios = os.path.join(tmp, "bin")
        os.makedirs(binarios)
        fp = os.path.join(binarios, "flatpak")
        open(fp, "w").write(FLATPAK)
        os.chmod(fp, 0o755)
        log = os.path.join(tmp, "flatpak.log")
        env = dict(os.environ, MATSU_LOJA_APPSTREAM=os.path.join(tmp, "appstream"), MATSU_LOJA_CACHE=os.path.join(tmp, "cache"),
                   MATSU_LOJA_CATALOGO=cat, MATSU_LOJA_APPS_SISTEMA=sistema, XDG_DATA_HOME=os.path.join(tmp, "dados"),
                   HOME=tmp, MATSU_LANG="pt_BR.UTF-8", PATH=binarios + ":" + os.environ["PATH"], FAKE_LOG=log,
                   MATSU_LOJA_ARQ="x86_64", MATSU_STATE_DIR=os.path.join(tmp, "estado"))

        # catálogo
        codigo, saida, erro = rodar(["catalogo"], env)
        check("catalogo roda: " + erro[-300:], codigo == 0)
        d = json.loads(saida or "{}")
        ids = [a["id"] for a in d.get("apps", [])]
        check("só apps (sem runtime e sem extensão)", sorted(ids) == ["com.discordapp.Discord", "com.heroicgameslauncher.hgl", "com.valvesoftware.Steam"])
        check("o .desktop sai do id", "com.heroicgameslauncher.hgl" in ids)
        disc = next(a for a in d["apps"] if a["id"] == "com.discordapp.Discord")
        check("resumo em português", disc["resumo"] == "Mensagens, voz e vídeo")
        check("desenvolvedor", disc["dev"] == "Discord Inc.")
        check("ícone de 128", disc["icone"].endswith("128x128/com.discordapp.Discord.png"))
        check("verificado", disc["verificado"] is True)
        check("categoria internet", disc["categoria"] == "internet")
        check("busca sem acento e com palavra-chave", "conversa" in disc["busca"] and "video" in disc["busca"])
        check("o resumo da lista não traz a descrição", "descricao" not in disc)
        hero = next(a for a in d["apps"] if a["id"] == "com.heroicgameslauncher.hgl")
        check("jogo cai em jogos", hero["categoria"] == "jogos")
        check("ícone achado pelo tamanho", hero["icone"].endswith("128x128/com.heroicgameslauncher.hgl.png"))
        check("destaque que existe, em português", d["destaques"] == [{"id": "com.discordapp.Discord", "titulo": "Discord PT", "texto": "Texto PT", "cores": ["#111111", "#222222"]}])
        check("seção só com os que existem", d["secoes"] == [{"id": "jogar", "titulo": "Para jogar", "texto": "", "apps": ["com.heroicgameslauncher.hgl", "com.valvesoftware.Steam"]}])
        check("site da web no catálogo", d["web"][0]["id"] == "instagram" and d["web"][0]["resumo"] == "Fotos")
        check("Steam já vem no sistema", d["no_sistema"] == {"com.valvesoftware.Steam": "steam.desktop"})
        check("contagem por categoria", d["categorias"] == {"internet": 1, "jogos": 2})
        check("idioma", d["idioma"] == "pt")
        check("cache gravado", any(n.startswith("appstream-") for n in os.listdir(os.path.join(tmp, "cache"))))
        # segunda vez vem do cache e dá o mesmo
        codigo2, saida2, _ = rodar(["catalogo"], env)
        check("cache dá o mesmo resultado", codigo2 == 0 and json.loads(saida2) == d)
        # em inglês
        env_en = dict(env, MATSU_LANG="en_US.UTF-8")
        _c, saida_en, _ = rodar(["catalogo"], env_en)
        d_en = json.loads(saida_en)
        disc_en = next(a for a in d_en["apps"] if a["id"] == "com.discordapp.Discord")
        check("resumo em inglês", disc_en["resumo"] == "Messaging, voice and video client")
        check("destaque em inglês", d_en["destaques"][0]["titulo"] == "Discord EN")

        # detalhes
        codigo, saida, erro = rodar(["detalhes", "com.discordapp.Discord"], env)
        det = json.loads(saida or "{}")
        check("detalhes roda", codigo == 0)
        check("descrição em português com lista", det.get("descricao") == "O Discord é o jeito mais fácil de conversar.<br><br>•  Voz<br>•  Vídeo &amp; tela")
        check("fotos: a padrão primeiro, a maior até 1600", [f["url"] for f in det["fotos"]] == ["https://exemplo/s1-1248.png", "https://exemplo/s2.png"])
        check("legenda da foto", det["fotos"][0]["legenda"] == "Conversa")
        check("versão, licença e site", det["versao"] == "0.0.70" and det["licenca"] == "LicenseRef-proprietary" and det["site"] == "https://discord.com")
        _c, saida, _ = rodar(["detalhes", "com.valvesoftware.Steam"], env)
        check("detalhes diz que a Steam já vem no sistema", json.loads(saida)["no_sistema"] == "steam.desktop")
        codigo, saida, _ = rodar(["detalhes", "com.nao.Existe"], env)
        check("app que não existe", codigo == 1 and json.loads(saida)["erro"] == "nao-achado")

        # instalados e atualizações
        codigo, saida, _ = rodar(["instalados"], env)
        inst = json.loads(saida)
        check("instalados do flatpak", [a["id"] for a in inst["apps"]] == ["com.discordapp.Discord", "com.brave.Browser"])
        check("instalação da pessoa", inst["apps"][1]["instalacao"] == "pessoa")
        check("nenhum site instalado", inst["web"] == [])
        codigo, saida, _ = rodar(["atualizacoes"], env)
        check("atualizações", json.loads(saida)["atualizacoes"] == [{"id": "com.discordapp.Discord", "versao": "0.0.71"}])

        # o catálogo do Flathub, baixado de novo só quando tem mais de um dia
        xml = os.path.join(ativa, "appstream.xml.gz")
        env_cat = dict(env, FAKE_APPSTREAM=xml)
        open(log, "w").close()
        codigo, saida, _ = rodar(["atualizar-catalogo"], env_cat)
        r = json.loads(saida)
        check("catálogo novo não baixa de novo", codigo == 0 and r["baixou"] is False and r["mudou"] is False
              and "--appstream" not in open(log).read())
        velho = os.path.getmtime(xml) - 3 * 86400
        os.utime(xml, (velho, velho))
        codigo, saida, _ = rodar(["atualizar-catalogo"], env_cat)
        r = json.loads(saida)
        check("catálogo velho é baixado e muda", codigo == 0 and r["baixou"] and r["mudou"] and not r["vazio"]
              and "update --appstream --system --noninteractive" in open(log).read())
        codigo, saida, _ = rodar(["atualizar-catalogo", "--forcar"], env_cat)
        check("forçar baixa sempre", json.loads(saida)["baixou"] is True)
        codigo, saida, _ = rodar(["catalogo"], env)
        check("o catálogo continua lendo depois de baixar", codigo == 0 and len(json.loads(saida)["apps"]) == 3)

        # instalar com progresso
        open(log, "w").close()
        codigo, saida, erro = rodar(["instalar", "com.heroicgameslauncher.hgl"], env)
        linhas = [json.loads(l) for l in saida.splitlines() if l.strip()]
        check("instalar dá certo: " + erro[-200:], codigo == 0 and linhas[-1].get("fim") and linhas[-1].get("ok"))
        progresso = [l["progresso"] for l in linhas if "progresso" in l]
        check("progresso sobe pelos dois passos: %s" % progresso, progresso[0] == 0 and progresso[-1] == 100 and progresso == sorted(progresso) and 25 in progresso)
        check("instala no sistema, do flathub", "install --system -y --noninteractive flathub com.heroicgameslauncher.hgl" in open(log).read())
        env_falha = dict(env, FAKE_FALHA="rede")
        codigo, saida, _ = rodar(["instalar", "com.discordapp.Discord"], env_falha)
        fim = json.loads(saida.splitlines()[-1])
        check("sem internet vira mensagem amigável", codigo == 1 and fim["ok"] is False and "internet" in fim["erro"])
        codigo, _s, _e = rodar(["instalar", "com.x;rm -rf /"], env)
        check("id estranho é recusado", codigo == 2)

        # remover e atualizar
        open(log, "w").close()
        codigo, saida, _ = rodar(["remover", "com.brave.Browser"], env)
        check("remover app da pessoa usa --user", codigo == 0 and "uninstall --user -y --noninteractive com.brave.Browser" in open(log).read())
        codigo, saida, _ = rodar(["atualizar", "--tudo"], env)
        check("atualizar tudo", codigo == 0 and "update -y --noninteractive" in open(log).read())

        # apps da web
        icones = os.path.join(tmp, "cache", "web")
        os.makedirs(icones, exist_ok=True)
        open(os.path.join(icones, "instagram.png"), "wb").write(b"\x89PNG\r\n\x1a\n" + b"0" * 300)
        env_web = dict(env, MATSU_LOJA_NAVEGADOR="flatpak run com.brave.Browser")
        codigo, saida, erro = rodar(["web-instalar", "instagram"], env_web)
        check("web-instalar: " + erro[-200:], codigo == 0 and json.loads(saida)["ok"])
        desk = os.path.join(tmp, "dados", "applications", "matsu-web-instagram.desktop")
        conteudo = open(desk).read() if os.path.exists(desk) else ""
        check("o app do site abre sem barra", "Exec=flatpak run com.brave.Browser --app=https://www.instagram.com/" in conteudo)
        check("o app do site tem a logo", "Icon=matsu-web-instagram" in conteudo and os.path.exists(os.path.join(tmp, "dados", "icons", "hicolor", "256x256", "apps", "matsu-web-instagram.png")))
        check("a barra junta a janela do site", "StartupWMClass=chrome-www.instagram.com_-Default" in conteudo)
        _c, saida, _ = rodar(["instalados"], env)
        check("site aparece nos instalados", json.loads(saida)["web"] == ["instagram"])
        codigo, saida, _ = rodar(["web-remover", "instagram"], env)
        check("web-remover", codigo == 0 and not os.path.exists(desk))
        env_sem = dict(env)
        codigo, saida, _ = rodar(["web-instalar", "instagram"], dict(env_sem, PATH=binarios + ":/usr/bin:/bin"))
        # sem Brave/Chrome: o flatpak de mentira diz que tem o Brave da pessoa, então funciona
        check("acha o Brave do Flatpak", codigo == 0)
        codigo, saida, _ = rodar(["web-instalar", "nao-existe"], env)
        check("site fora do catálogo", codigo == 1)

    # O "Instalar" do site do Flathub: um .flatpakref abre a página do app.
    with tempfile.TemporaryDirectory() as tmp:
        ref = os.path.join(tmp, "Meu App.flatpakref")
        with open(ref, "w") as f:
            f.write("[Flatpak Ref]\nTitle=Discord\nName=com.discordapp.Discord\nBranch=stable\n"
                    "Url=https://dl.flathub.org/repo/\nIsRuntime=false\n")
        codigo, saida, _ = rodar(["ref", ref], dict(os.environ))
        check("flatpakref vira o id do app", codigo == 0 and json.loads(saida) == {"ok": True, "id": "com.discordapp.Discord"})
        codigo, saida, _ = rodar(["ref", "file://" + ref.replace(" ", "%20")], dict(os.environ))
        check("flatpakref por file:// também", codigo == 0 and json.loads(saida)["id"] == "com.discordapp.Discord")
        with open(ref, "w") as f:
            f.write("[Flatpak Ref]\nName=com.x;rm -rf /\n")
        codigo, saida, _ = rodar(["ref", ref], dict(os.environ))
        check("flatpakref com id estranho é recusado", codigo == 1 and json.loads(saida)["ok"] is False)
        codigo, saida, _ = rodar(["ref", os.path.join(tmp, "nao-existe.flatpakref")], dict(os.environ))
        check("flatpakref que não existe", codigo == 1)

    print(f"Resultado: {ok} passaram, {falhas} falharam")
    return 0 if falhas == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
