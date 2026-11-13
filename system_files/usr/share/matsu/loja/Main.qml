// Loja do Matsu (no jeito da Microsoft Store e da App Store): destaques no
// Início, apps por categoria, jogos, sites que viram app (Instagram, TikTok,
// YouTube...) e a Biblioteca com o que está instalado e as atualizações. A página
// de cada app tem as fotos, a descrição e o botão de obter com o progresso.
// A janela de vidro é a JanelaMatsu, de ../comum.
//
// Aqui é só o desenho. Quem lê o catálogo (o AppStream do Flathub e as escolhas
// do Matsu, em catalogo.json), instala e remove é o ajudante.py desta pasta.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

JanelaMatsu {
    id: janela

    title: t("Loja do Matsu", "Matsu Store")
    icone: "org.matsu.loja"
    iconeReserva: "matsu-loja"
    dicaBusca: t("Buscar apps, jogos e sites", "Search apps, games and sites")
    paginaDaBusca: "apps"
    trocaSuave: true
    paginas: [
        { id: "inicio", icone: "matsu-inicio-symbolic", nome: t("Início", "Home") },
        { id: "apps", icone: "matsu-apps-symbolic", nome: t("Apps", "Apps") },
        { id: "jogos", icone: "matsu-jogos-symbolic", nome: t("Jogos", "Games") },
        { id: "web", icone: "matsu-web-symbolic", nome: t("Na web", "On the web") },
        { id: "biblioteca", icone: "matsu-biblioteca-symbolic", nome: t("Biblioteca", "Library") }
    ]
    conteudo: Qt.resolvedUrl(({ apps: "PaginaApps.qml", jogos: "PaginaApps.qml", web: "PaginaWeb.qml",
                                biblioteca: "PaginaBiblioteca.qml" })[pagina] || "PaginaInicio.qml")
    width: gu * 66
    height: gu * 42
    minimumWidth: gu * 44
    minimumHeight: gu * 28

    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }

    // ----- o catálogo -----
    property bool lido: false
    property bool baixandoCatalogo: false  // o catálogo do Flathub vindo pela primeira vez
    property bool semCatalogo: false  // não deu para baixar o catálogo (sem internet)
    property bool catalogoVisto: false
    property bool semNavegador: false // tentou pôr um site e não tem Brave nem Chrome
    property bool semIconesWeb: false // já tentou baixar as logos dos sites (as que faltam não vêm agora)
    property var apps: []             // todos, resumidos (nome, resumo, ícone, categoria); os escolhidos do Matsu primeiro
    property var porId: ({})
    property var destaques: []
    property var secoes: []
    property var sites: []            // sites que viram app
    property var contagem: ({})
    property var noSistema: ({})      // id -> .desktop do app que já vem no Matsu
    property var escolhidos: ({})     // id -> true para os apps das seções e destaques do Matsu
    // ----- o que está instalado -----
    property var instalados: ({})     // id -> { versao, remoto, instalacao, tamanho }
    property var sitesInstalados: []
    property var atualizacoes: ({})   // id -> versão nova
    property bool procurando: false
    // ----- o que está acontecendo agora -----
    property var tarefas: ({})        // id -> { acao, progresso, chave, fila }
    property var fila: []             // o que espera a vez (o Flatpak faz uma coisa por vez)
    property string rodando: ""       // a chave do que o Flatpak está fazendo agora
    property var avisos: ({})         // id -> mensagem de erro da última tentativa
    // O que acabou de dar certo: id -> { acao, quando }. O botão mostra "Instalado ✓"
    // por uns segundos e não pisca "Obter" enquanto a lista do que está instalado
    // ainda não voltou do Flatpak.
    property var concluidos: ({})
    property int mudancas: 0          // sobe a cada mudança em tarefas/instalados (para os bindings)
    // ----- a página de um app -----
    property string appAberto: ""
    property var detalhes: ({})
    property string categoria: ""     // filtro da página Apps
    property string secao: ""         // "Ver tudo" de uma seção do Início
    property string ordem: "matsu"    // como a página Apps ordena: "matsu", "nome" ou "verificados"
    // Aviso que aparece embaixo por alguns segundos (um erro ao instalar, por exemplo).
    property string aviso: ""
    property int avisoN: 0

    onPaginaChanged: {
        appAberto = "";
        if (pagina !== "apps") {
            categoria = "";
            secao = "";
        }
    }

    // O selo de verificado, no rosa do Matsu (nada de azul).
    readonly property color corSelo: escuro ? "#f2a7cb" : "#b0447c"

    function app(id) {
        return porId[id] || null;
    }
    function nomeDe(id) {
        var _m = mudancas;
        if (porId[id])
            return porId[id].nome;
        if (instalados[id] && instalados[id].nome)
            return instalados[id].nome;
        var s = id.indexOf("web:") === 0 ? site(id.substring(4)) : null;
        return s ? s.nome : id;
    }
    function avisar(texto) {
        aviso = texto;
        avisoN++;
    }
    function site(id) {
        for (var i = 0; i < sites.length; i++)
            if (sites[i].id === id)
                return sites[i];
        return null;
    }
    function arquivo(caminho) {
        if (!caminho)
            return "";
        if (caminho.indexOf("://") > 0)
            return caminho;
        return "file://" + caminho.split("/").map(encodeURIComponent).join("/");
    }
    function nomeCategoria(c) {
        return ({ "jogos": t("Jogos", "Games"), "internet": t("Internet e conversa", "Internet and chat"),
                  "audio-video": t("Música e vídeo", "Music and video"), "graficos": t("Foto e desenho", "Photo and drawing"),
                  "escritorio": t("Escritório", "Office"), "desenvolvimento": t("Programação", "Development"),
                  "educacao": t("Educação e ciência", "Education and science"), "utilitarios": t("Utilidades", "Utilities"),
                  "sistema": t("Sistema", "System") })[c] || c;
    }
    function iconeCategoria(c) {
        return ({ "jogos": "matsu-ajuste-controles", "internet": "matsu-ajuste-rede", "audio-video": "matsu-ajuste-multimidia",
                  "graficos": "matsu-ajuste-cores", "escritorio": "matsu-ajuste-documentos", "desenvolvimento": "matsu-ajuste-krunner",
                  "educacao": "matsu-ajuste-idioma", "utilitarios": "matsu-ajuste-compactador", "sistema": "matsu-ajuste-servicos" })[c] || "matsu-loja";
    }
    readonly property var ordemCategorias: ["internet", "audio-video", "graficos", "escritorio", "jogos", "educacao",
                                            "desenvolvimento", "utilitarios", "sistema"]

    // O estado do botão de um app: "obter", "abrir", "sistema", "atualizar",
    // "trabalhando" ou "feito" (acabou de instalar ou atualizar).
    function estado(id) {
        var _m = mudancas;
        if (tarefas[id])
            return "trabalhando";
        var c = concluidos[id];
        if (c && c.acao !== "remover" && (Date.now() - c.quando < 2200 || !instalados[id]))
            return "feito";
        if (c && c.acao === "remover")
            return noSistema[id] ? "sistema" : "obter";
        if (instalados[id])
            return atualizacoes[id] ? "atualizar" : "abrir";
        if (noSistema[id])
            return "sistema";
        return "obter";
    }
    function progresso(id) {
        var _m = mudancas;
        return tarefas[id] ? tarefas[id].progresso : 0;
    }
    function acaoAgora(id) {
        var _m = mudancas;
        if (tarefas[id])
            return tarefas[id].acao;
        return concluidos[id] ? concluidos[id].acao : "";
    }
    // Tira de "concluidos" o que a lista do que está instalado já confirmou (ou que
    // ficou velho demais), depois do tempo do "Instalado ✓".
    function limparConcluidos() {
        var agora = Date.now(), novo = {}, sobrou = false, mudou = false;
        for (var id in concluidos) {
            var c = concluidos[id];
            var confirmado = c.acao === "remover" ? !instalados[id] : !!instalados[id];
            if (agora - c.quando > 20000 || (agora - c.quando >= 2200 && confirmado)) {
                mudou = true;
            } else {
                novo[id] = c;
                sobrou = true;
            }
        }
        if (mudou) {
            concluidos = novo;
            mudancas++;
        }
        if (sobrou)
            limpeza.restart();
    }
    Timer {
        id: limpeza
        interval: 2300
        onTriggered: janela.limparConcluidos()
    }

    // ----- ações -----
    function mexer(o, id, valor) {
        var novo = Object.assign({}, o);
        if (valor === undefined)
            delete novo[id];
        else
            novo[id] = valor;
        return novo;
    }
    // O Flatpak faz uma coisa por vez: o resto espera na fila ("Na fila" no botão).
    function enfileirar(ids, acao, alvo) {
        var chave = "op:" + alvo;
        for (var i = 0; i < ids.length; i++) {
            if (tarefas[ids[i]])
                continue;
            avisos = mexer(avisos, ids[i], undefined);
            concluidos = mexer(concluidos, ids[i], undefined);
            tarefas = mexer(tarefas, ids[i], { acao: acao, progresso: 0, chave: chave, fila: true });
        }
        fila = fila.concat([{ chave: chave, ids: ids, cmd: comando([acao, alvo]) }]);
        mudancas++;
        proximo();
    }
    function proximo() {
        if (rodando !== "" || fila.length === 0)
            return;
        var vez = fila[0];
        fila = fila.slice(1);
        for (var i = 0; i < vez.ids.length; i++) {
            var t = tarefas[vez.ids[i]];
            if (t && t.chave === vez.chave)
                tarefas = mexer(tarefas, vez.ids[i], Object.assign({}, t, { fila: false }));
        }
        rodando = vez.chave;
        mudancas++;
        matsu.iniciar(vez.chave, vez.cmd);
    }
    function instalar(id) {
        if (!tarefas[id])
            enfileirar([id], "instalar", id);
    }
    function remover(id) {
        if (!tarefas[id])
            enfileirar([id], "remover", id);
    }
    function atualizar(id) {
        if (!tarefas[id])
            enfileirar([id], "atualizar", id);
    }
    function atualizarTudo() {
        var ids = Object.keys(atualizacoes).filter(function (id) { return !tarefas[id]; });
        if (ids.length > 0)
            enfileirar(ids, "atualizar", "--tudo");
    }
    function cancelar(id) {
        var t = tarefas[id];
        if (!t)
            return;
        if (t.fila) {
            // Ainda não começou: sai da fila e pronto.
            fila = fila.filter(function (v) { return v.chave !== t.chave; });
            for (var outro in tarefas)
                if (tarefas[outro].chave === t.chave)
                    tarefas = mexer(tarefas, outro, undefined);
            mudancas++;
        } else {
            matsu.parar(t.chave);
        }
    }
    function emFila(id) {
        var _m = mudancas;
        return !!(tarefas[id] && tarefas[id].fila);
    }
    function abrir(id) {
        matsu.soltar(comando(["abrir", id]));
    }
    function abrirSite(id) {
        matsu.soltar(comando(["abrir", "web:" + id]));
    }
    function adicionarSite(id) {
        tarefas = mexer(tarefas, "web:" + id, { acao: "instalar", progresso: 50 });
        mudancas++;
        matsu.rodar("web-instalar:" + id, comando(["web-instalar", id]));
    }
    function tirarSite(id) {
        matsu.rodar("web-remover:" + id, comando(["web-remover", id]));
    }
    function siteInstalado(id) {
        var _m = mudancas;
        return sitesInstalados.indexOf(id) >= 0;
    }
    function carregarDetalhes(id) {
        if (!detalhes[id])
            matsu.rodar("detalhes:" + id, comando(["detalhes", id]));
    }
    // O link appstream://com.brave.Browser chega com o id em minúsculas (o Qt trata o
    // id como nome de site): aqui ele volta a ser o do catálogo.
    function idCerto(id) {
        if (!id || porId[id] || instalados[id])
            return id;
        var baixo = id.toLowerCase();
        for (var k in porId)
            if (k.toLowerCase() === baixo)
                return k;
        for (var k2 in instalados)
            if (k2.toLowerCase() === baixo)
                return k2;
        return id;
    }
    function abrirApp(id) {
        appAberto = idCerto(id);
        carregarDetalhes(appAberto);
    }
    function lerInstalados() {
        matsu.rodar("instalados", comando(["instalados"]));
    }
    function procurarAtualizacoes() {
        procurando = true;
        matsu.rodar("atualizacoes", comando(["atualizacoes"]));
    }

    // ----- busca -----
    function buscar(texto, lista) {
        var b = simples(texto.trim());
        if (b.length === 0)
            return lista;
        var palavras = b.split(/\s+/);
        var achados = [];
        for (var i = 0; i < lista.length; i++) {
            var a = lista[i];
            var chave = a.busca || simples(a.nome + " " + (a.resumo || ""));
            var tudo = true;
            for (var p = 0; p < palavras.length; p++) {
                if (chave.indexOf(palavras[p]) < 0) {
                    tudo = false;
                    break;
                }
            }
            if (tudo) {
                var nome = simples(a.nome);
                // O nome começando com o que foi digitado vem primeiro.
                achados.push({ app: a, peso: nome.indexOf(b) === 0 ? 0 : (nome.indexOf(b) > 0 ? 1 : 2) });
            }
        }
        achados.sort(function (x, y) { return x.peso - y.peso; });
        return achados.map(function (x) { return x.app; });
    }

    // ----- o que o ajudante manda -----
    function receberPasso(texto) {
        var d;
        try {
            d = JSON.parse(texto);
        } catch (e) {
            return;
        }
        var chave = "op:" + d.id;
        var ids = [];
        for (var c in tarefas)
            if (tarefas[c].chave === chave)
                ids.push(c);
        for (var i = 0; i < ids.length; i++) {
            var id = ids[i];
            if (d.fim) {
                var feita = tarefas[id].acao;
                tarefas = mexer(tarefas, id, undefined);
                if (!d.ok && !d.cancelado && d.erro) {
                    avisos = mexer(avisos, id, d.erro);
                    avisar(nomeDe(id) + ": " + d.erro);
                }
                if (d.ok && d.acao !== "instalar")
                    atualizacoes = mexer(atualizacoes, id, undefined);
                if (d.ok && !d.cancelado) {
                    concluidos = mexer(concluidos, id, { acao: d.acao || feita, quando: Date.now() });
                    limpeza.restart();
                }
            } else {
                tarefas = mexer(tarefas, id, Object.assign({}, tarefas[id], { progresso: d.progresso || 0 }));
            }
        }
        mudancas++;
        if (d.fim)
            lerInstalados();
    }

    Connections {
        target: matsu
        function onLinha(chave, texto) {
            if (chave.indexOf("op:") === 0)
                janela.receberPasso(texto);
        }
        function onParou(chave, codigo) {
            if (chave.indexOf("op:") !== 0)
                return;
            // Terminou sem a linha do fim (cancelado ou o ajudante caiu): limpa o que sobrou.
            var sobrou = false;
            for (var id in janela.tarefas) {
                if (janela.tarefas[id].chave === chave && !janela.tarefas[id].fila) {
                    janela.tarefas = janela.mexer(janela.tarefas, id, undefined);
                    sobrou = true;
                }
            }
            if (sobrou) {
                janela.mudancas++;
                janela.lerInstalados();
            }
            if (janela.rodando === chave) {
                janela.rodando = "";
                janela.proximo();
            }
        }
        function onPronto(chave, saida, codigo) {
            var d = null;
            try {
                d = JSON.parse(saida);
            } catch (e) {
                d = null;
            }
            if (chave === "catalogo" && d) {
                if (d.idioma)
                    janela.lingua = d.idioma;
                if (d.vidro && JSON.stringify(d.vidro) !== JSON.stringify(janela.vidroConf))
                    janela.vidroConf = d.vidro;
                var mapa = {};
                for (var i = 0; i < d.apps.length; i++)
                    mapa[d.apps[i].id] = d.apps[i];
                // Os escolhidos do Matsu vêm primeiro nas listas, depois os verificados.
                var escolha = {};
                for (var s = 0; s < d.secoes.length; s++)
                    for (var a = 0; a < d.secoes[s].apps.length; a++)
                        escolha[d.secoes[s].apps[a]] = true;
                for (var h = 0; h < d.destaques.length; h++)
                    escolha[d.destaques[h].id] = true;
                var ordem = d.apps.map(function (x, n) { return { app: x, n: n, peso: escolha[x.id] ? 0 : (x.verificado ? 1 : 2) }; });
                ordem.sort(function (x, y) { return x.peso - y.peso || x.n - y.n; });
                janela.porId = mapa;
                // Página pedida antes do catálogo chegar: acerta o id (maiúsculas) agora.
                if (janela.appAberto && janela.idCerto(janela.appAberto) !== janela.appAberto)
                    janela.abrirApp(janela.appAberto);
                janela.escolhidos = escolha;
                janela.apps = ordem.map(function (x) { return x.app; });
                janela.destaques = d.destaques;
                janela.secoes = d.secoes;
                janela.sites = d.web;
                janela.contagem = d.categorias;
                janela.noSistema = d.no_sistema;
                janela.lido = true;
                if (d.apps.length === 0)
                    janela.baixandoCatalogo = true;
                if (!janela.catalogoVisto) {
                    janela.catalogoVisto = true;
                    // A logo oficial de cada site (baixada do próprio site uma vez).
                    matsu.rodar("web-icones", janela.comando(["web-icones"]));
                    // O catálogo do Flathub, de novo se tiver mais de um dia (ou se nunca veio).
                    matsu.rodar("atualizar-catalogo", janela.comando(["atualizar-catalogo"]));
                }
                // As fotos dos destaques, para o Início.
                for (var f = 0; f < d.destaques.length; f++)
                    janela.carregarDetalhes(d.destaques[f].id);
            } else if (chave === "instalados" && d) {
                var inst = {};
                for (var j = 0; j < d.apps.length; j++)
                    inst[d.apps[j].id] = d.apps[j];
                janela.instalados = inst;
                janela.sitesInstalados = d.web;
                janela.mudancas++;
                if (Object.keys(janela.concluidos).length > 0)
                    janela.limparConcluidos();
            } else if (chave === "atualizacoes") {
                janela.procurando = false;
                if (d) {
                    var novas = {};
                    for (var k = 0; k < d.atualizacoes.length; k++)
                        novas[d.atualizacoes[k].id] = d.atualizacoes[k].versao || "";
                    janela.atualizacoes = novas;
                    janela.mudancas++;
                }
            } else if (chave === "atualizar-catalogo") {
                if (d && d.mudou) {
                    janela.detalhes = ({});
                    matsu.rodar("catalogo", janela.comando(["catalogo"]));
                }
                if (!d || !d.mudou)
                    janela.baixandoCatalogo = false;
                if (d && !d.ok && d.vazio)
                    janela.semCatalogo = true;
            } else if (chave === "web-icones" && d) {
                var lista = janela.sites.slice();
                for (var s = 0; s < lista.length; s++) {
                    var novo = Object.assign({}, lista[s]);
                    novo.icone = d.icones[novo.id] || novo.icone;
                    lista[s] = novo;
                }
                janela.sites = lista;
                janela.semIconesWeb = true;
            } else if (chave.indexOf("detalhes:") === 0 && d && !d.erro) {
                janela.detalhes = janela.mexer(janela.detalhes, d.id, d);
            } else if (chave.indexOf("web-instalar:") === 0) {
                var sid = chave.substring(13);
                janela.tarefas = janela.mexer(janela.tarefas, "web:" + sid, undefined);
                janela.semNavegador = !!(d && d.sem_navegador);
                if (d && !d.ok && d.erro && !d.sem_navegador)
                    janela.avisar(janela.nomeDe("web:" + sid) + ": " + d.erro);
                janela.mudancas++;
                janela.lerInstalados();
            } else if (chave.indexOf("web-remover:") === 0) {
                janela.lerInstalados();
            } else if (chave === "ref") {
                if (d && d.ok)
                    janela.abrirApp(d.id);
                else
                    janela.avisar(janela.t("Esse arquivo não diz qual app instalar.", "That file doesn't say which app to install."));
            }
        }
        function onPedido(argumentos) {
            if (argumentos.length > 0)
                janela.pedido(argumentos);
        }
    }

    // "matsu-loja app <id>" (ou appstream://<id>, ou um .flatpakref baixado do
    // site do Flathub) abre direto na página do app; "matsu-loja biblioteca" na
    // Biblioteca.
    function pedido(args) {
        var a = args[0];
        if (/\.flatpakref$/i.test(a)) {
            irPara("inicio");
            matsu.rodar("ref", comando(["ref", a]));
        } else if (/^appstream:/i.test(a)) {
            abrirApp(a.replace(/^appstream:(\/\/)?/i, "").replace(/\/+$/, "").replace(/\.desktop$/, ""));
        } else if (a === "app" && args.length > 1) {
            abrirApp(args[1]);
        } else {
            irPara(a);
        }
    }

    // As atualizações são vistas de novo a cada hora com a loja aberta.
    Timer {
        interval: 3600000
        running: janela.lido
        repeat: true
        onTriggered: janela.procurarAtualizacoes()
    }
    onActiveChanged: if (active && lido) lerInstalados()

    Component.onCompleted: {
        matsu.rodar("catalogo", comando(["catalogo"]));
        lerInstalados();
        procurarAtualizacoes();
        if (matsu.argumentos.length > 0)
            pedido(matsu.argumentos);
    }

    // Embaixo da lista: o que está baixando agora, ou as atualizações.
    rodapeLateral: Component {
        Cartao {
            readonly property int baixando: {
                var _m = janela.mudancas;
                var n = 0;
                for (var id in janela.tarefas)
                    n++;
                return n;
            }
            readonly property int novas: {
                var _m = janela.mudancas;
                return Object.keys(janela.atualizacoes).length;
            }
            visible: baixando > 0 || novas > 0
            implicitHeight: linhaRodape.implicitHeight + Math.round(janela.gu * 1.2)
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: janela.irPara("biblioteca")
            }
            RowLayout {
                id: linhaRodape
                anchors.fill: parent
                anchors.margins: Math.round(janela.gu * 0.6)
                spacing: Math.round(janela.gu * 0.5)
                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    source: "matsu-baixar-symbolic"
                    isMask: true
                    color: janela.frente
                }
                Texto {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    text: parent.parent.baixando > 0
                          ? (parent.parent.baixando === 1 ? janela.t("1 app baixando", "1 app downloading")
                                                          : janela.t(parent.parent.baixando + " apps baixando", parent.parent.baixando + " apps downloading"))
                          : (parent.parent.novas === 1 ? janela.t("1 atualização", "1 update")
                                                       : janela.t(parent.parent.novas + " atualizações", parent.parent.novas + " updates"))
                }
            }
        }
    }

    // ----- o aviso embaixo, por cima de tudo (some sozinho) -----
    Rectangle {
        id: balao
        readonly property bool mostrar: janela.aviso !== "" && esconder.running
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - (mostrar ? height + Math.round(janela.gu * 1.2) : -Math.round(janela.gu * 0.5))
        z: 50
        width: Math.min(linhaBalao.implicitWidth + Math.round(janela.gu * 1.6), parent.width - janela.gu * 4)
        height: Math.round(janela.gu * 2.6)
        radius: height / 2
        opacity: mostrar ? 1 : 0
        visible: opacity > 0
        color: janela.escuro ? Qt.rgba(0.17, 0.17, 0.18, 0.97) : Qt.rgba(0.99, 0.99, 1, 0.98)
        border.width: 1
        border.color: janela.tinta(0.12)
        Behavior on y {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
            }
        }
        Timer {
            id: esconder
            interval: 8000
        }
        Connections {
            target: janela
            function onAvisoNChanged() {
                esconder.restart();
            }
        }
        RowLayout {
            id: linhaBalao
            anchors.fill: parent
            anchors.leftMargin: Math.round(janela.gu * 0.8)
            anchors.rightMargin: Math.round(janela.gu * 0.5)
            spacing: Math.round(janela.gu * 0.5)
            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                source: "matsu-alerta-symbolic"
                fallback: "dialog-warning-symbolic"
                isMask: true
                color: janela.escuro ? "#f5b26b" : "#b8621b"
            }
            Texto {
                Layout.fillWidth: true
                text: janela.aviso
                elide: Text.ElideRight
            }
            Botao {
                icone: "matsu-fechar-symbolic"
                dica: janela.t("Fechar", "Close")
                onClicado: esconder.stop()
            }
        }
    }
}
