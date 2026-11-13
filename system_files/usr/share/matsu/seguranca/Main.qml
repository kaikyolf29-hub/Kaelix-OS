// Central de segurança do Matsu: o escudo (antivírus ClamAV em tempo real, com
// quarentena), a rede e o firewall (firewalld com as zonas do Matsu), as
// permissões dos apps da Loja (Flatpak), a integridade do sistema e o histórico.
//
// A janela só desenha. Quem lê e muda as coisas é o ajudante.py desta pasta,
// sempre como a própria pessoa (o que precisa de root passa pelo polkit, pelo
// systemd, pelo firewalld e pelo NetworkManager). Ver docs/SEGURANCA.md.
//
// Argumentos (do menu, da bandeja e dos avisos): uma página (inicio, escudo,
// rede, apps, integridade, historico), "verificar-rapida" ou "verificar <caminho>".
// Com MATSU_SEGURANCA_DEMO=protegido|atencao|pausado|baixando o ajudante dá
// dados de mentira (para as fotos da prévia).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

JanelaMatsu {
    id: janela

    title: t("Segurança", "Security")
    icone: "org.matsu.seguranca"
    iconeReserva: "matsu-escudo-symbolic"
    width: gu * 62
    height: gu * 40
    minimumWidth: gu * 44
    trocaSuave: true
    dicaBusca: t("Buscar apps e histórico", "Search apps and history")
    paginas: [
        { id: "inicio", icone: "matsu-inicio-symbolic", nome: t("Início", "Home") },
        { id: "escudo", icone: "matsu-escudo-symbolic", nome: t("Escudo", "Shield") },
        { id: "rede", icone: "matsu-web-symbolic", nome: t("Rede e firewall", "Network & firewall") },
        { id: "apps", icone: "matsu-apps-symbolic", nome: t("Permissões dos apps", "App permissions") },
        { id: "integridade", icone: "matsu-verificado-symbolic", nome: t("Integridade", "Integrity") },
        { id: "historico", icone: "matsu-relogio-symbolic", nome: t("Histórico", "History") }
    ]
    conteudo: Qt.resolvedUrl(({
        inicio: "PaginaInicio.qml", escudo: "PaginaEscudo.qml", rede: "PaginaRede.qml",
        apps: "PaginaApps.qml", integridade: "PaginaIntegridade.qml", historico: "PaginaHistorico.qml"
    })[pagina] || "PaginaInicio.qml")
    rodapeLateral: Component {
        RowLayout {
            spacing: Math.round(janela.gu * 0.5)
            Rectangle {
                Layout.preferredWidth: Math.round(janela.gu * 0.5)
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: janela.corEstado(janela.geral)
                Behavior on color {
                    ColorAnimation { duration: 300 }
                }
            }
            Texto {
                Layout.fillWidth: true
                text: janela.nomeEstado(janela.geral)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.75
                elide: Text.ElideRight
            }
        }
    }

    // A busca procura nos apps (ou no histórico, quando ele está aberto).
    onBuscaChanged: if (busca.length > 0 && pagina !== "apps" && pagina !== "historico") pagina = "apps"
    onPaginaChanged: aoAbrir(pagina)

    // ----- o ajudante -----
    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }

    // ----- o estado, que chega sozinho a cada 2 s (ajudante.py vigiar) -----
    property var est: null
    readonly property string geral: est ? est.geral : "lendo"
    readonly property var escudo: est ? est.escudo : null
    readonly property var lista: est ? est.lista : null
    readonly property var cont: est ? est.contagem : null
    readonly property bool pausado: escudo ? escudo.pausado : false
    readonly property bool ligado: escudo ? escudo.ligado : true
    // Uma mudança feita aqui segura as linhas do vigia por um instante (sem piscar).
    property real _seguraAte: 0
    property real agora: Date.now() / 1000

    // Os dados de cada página (lidos ao abrir a página).
    property var resumo: null
    property var rede: null
    property var apps: null
    property var integ: null
    property var hist: null
    property string appEscolhido: ""
    property string abaHistorico: "tudo"

    // Ações em andamento (botões com a rodinha): { chave: true }.
    property var ocupado: ({})
    property var _depois: ({})

    // ----- a verificação manual (fica aqui para continuar ao trocar de página) -----
    property bool verRodando: false
    property string verTipo: "rapida"
    property string verNome: ""
    property string verFase: ""
    property string verTexto: ""
    property int verFeitos: 0
    property int verTotal: 0
    property string verAtual: ""
    property var verAmeacas: []
    property var verFim: null
    property string verErro: ""
    property bool verSemLista: false
    property real verInicio: 0
    readonly property real verParte: verTotal > 0 ? Math.min(1, verFeitos / verTotal) : 0

    // ----- a conferência dos arquivos do sistema (ostree fsck) -----
    property bool fsckRodando: false
    property string fsckFase: ""
    property string fsckTexto: ""
    property int fsckFeitos: 0
    property int fsckTotal: 0
    property var fsckFim: null
    readonly property real fsckParte: fsckTotal > 0 ? Math.min(1, fsckFeitos / fsckTotal) : 0

    readonly property alias dialogo: dialogoCentral
    readonly property alias menuPausa: menuPausaCentral

    // ----- cores e nomes de cada estado -----
    function corEstado(e) {
        switch (e) {
        case "protegido":
            return escuro ? "#4fca8c" : "#1d8a50";
        case "pausado":
        case "baixando":
        case "sem-lista":
            return escuro ? "#f1b84f" : "#b06a00";
        case "atencao":
        case "parado":
        case "desligado":
            return escuro ? "#ff8b78" : "#c63f2b";
        default:
            return tinta(escuro ? 0.45 : 0.4);
        }
    }
    readonly property color verde: corEstado("protegido")
    readonly property color ambar: corEstado("pausado")
    readonly property color coral: corEstado("atencao")
    function nomeEstado(e) {
        switch (e) {
        case "protegido":
            return t("Protegido", "Protected");
        case "pausado":
            return t("Escudo pausado", "Shield paused");
        case "atencao":
            return t("Pede atenção", "Needs attention");
        case "parado":
            return t("Escudo parado", "Shield stopped");
        case "desligado":
            return t("Escudo desligado", "Shield off");
        case "baixando":
            return t("Baixando a lista", "Downloading list");
        case "sem-lista":
            return t("Falta a lista", "List missing");
        case "indisponivel":
            return t("Sem antivírus", "No antivirus");
        default:
            return t("Conferindo…", "Checking…");
        }
    }
    // Um ícone: os do tema (matsu-*) pelo nome; os desta pasta pelo arquivo.
    function ic(nome) {
        return nome.indexOf("matsu-") === 0 || nome.indexOf("file:") === 0 ? nome : Qt.resolvedUrl("icones/" + nome + ".svg");
    }

    // Como cada acontecimento do histórico aparece: ícone, cor, título e detalhe.
    function descrever(ev) {
        var nome = ev.nome || "";
        var mais = function (a, b) {
            return a && b ? a + " · " + b : (a || b || "");
        };
        switch (ev.tipo) {
        case "quarentena":
            return { icone: ic("quarentena"), cor: coral, titulo: t("Ameaça trancada na quarentena", "Threat quarantined"), texto: mais(nome, ev.detalhe) };
        case "verificacao":
            var feitos = num(ev.feitos || 0);
            return {
                icone: "matsu-escudo-symbolic", cor: ev.ameacas > 0 ? coral : verde, titulo: nome || t("Verificação", "Scan"),
                texto: ev.cancelada ? t("Cancelada depois de " + feitos + " arquivos", "Cancelled after " + feitos + " files")
                     : ev.ameacas > 0 ? t(feitos + " arquivos, " + ev.ameacas + (ev.ameacas === 1 ? " ameaça" : " ameaças"), feitos + " files, " + ev.ameacas + (ev.ameacas === 1 ? " threat" : " threats"))
                     : t(feitos + " arquivos, nada encontrado", feitos + " files, nothing found")
            };
        case "aviso-bloqueado":
            return { icone: ic("escudo-alerta"), cor: verde, titulo: t("Arquivo baixado não foi aberto", "Downloaded file not opened"), texto: mais(nome, ev.detalhe) };
        case "aviso-liberado":
            return { icone: ic("abrir-fora"), cor: ambar, titulo: t("Aberto mesmo assim", "Opened anyway"), texto: mais(nome, ev.detalhe) };
        case "pendrive":
            return { icone: ic("pendrive"), cor: frente, titulo: t("Pendrive conectado", "USB drive connected"), texto: nome };
        case "pausa":
            return {
                icone: ic("pausa"), cor: ambar, titulo: t("Escudo pausado", "Shield paused"),
                texto: ev.detalhe === "reiniciar" ? t("Até reiniciar", "Until restart") : ev.detalhe === "60" ? t("Por 1 hora", "For 1 hour")
                     : ev.detalhe ? t("Por " + ev.detalhe + " minutos", "For " + ev.detalhe + " minutes") : ""
            };
        case "volta":
            return { icone: "matsu-certo-symbolic", cor: verde, titulo: t("O escudo voltou a vigiar", "The shield resumed"), texto: "" };
        case "restaurado":
            return { icone: ic("restaurar"), cor: ambar, titulo: t("Restaurado da quarentena", "Restored from quarantine"), texto: mais(nome, ev.detalhe) };
        case "apagado":
            return { icone: "matsu-lixeira-symbolic", cor: frente, titulo: t("Apagado de vez", "Deleted for good"), texto: mais(nome, ev.detalhe) };
        case "fsck":
            return {
                icone: "matsu-verificado-symbolic", cor: ev.ok ? verde : coral, titulo: t("Arquivos do sistema conferidos", "System files checked"),
                texto: ev.ok ? t("Tudo igual à versão assinada", "Everything matches the signed version") : t("Achou diferenças", "Found differences")
            };
        default:
            return { icone: "matsu-info-symbolic", cor: frente, titulo: ev.tipo || "", texto: nome };
        }
    }

    // ----- datas do jeito daqui -----
    // "hoje às 10:32", "ontem às 18:05" ou "3 de nov. às 09:10".
    function quando(segundos) {
        if (!segundos)
            return "";
        var d = new Date(segundos * 1000);
        var hoje = new Date();
        var ontem = new Date(hoje.getFullYear(), hoje.getMonth(), hoje.getDate() - 1);
        var hora = d.toLocaleTimeString(local, "HH:mm");
        if (d.toDateString() === hoje.toDateString())
            return t("hoje às ", "today at ") + hora;
        if (d.toDateString() === ontem.toDateString())
            return t("ontem às ", "yesterday at ") + hora;
        return d.toLocaleDateString(local, pt ? "d 'de' MMM" : "MMM d") + t(" às ", " at ") + hora;
    }
    // "há 3 h", "há 2 dias".
    function ha(segundos) {
        if (!segundos)
            return "";
        var s = Math.max(0, agora - segundos);
        if (s < 90)
            return t("agora há pouco", "just now");
        if (s < 3600)
            return t("há " + Math.round(s / 60) + " min", Math.round(s / 60) + " min ago");
        if (s < 86400)
            return t("há " + Math.round(s / 3600) + " h", Math.round(s / 3600) + " h ago");
        var d = Math.round(s / 86400);
        return t("há " + d + (d === 1 ? " dia" : " dias"), d + (d === 1 ? " day ago" : " days ago"));
    }
    // "8 s", "1 min 14 s", "1 h 05 min".
    function tempoCurto(segundos) {
        var s = Math.round(segundos);
        return s < 60 ? s + " s" : duracao(s);
    }
    function hora(segundos) {
        return new Date(segundos * 1000).toLocaleTimeString(local, "HH:mm");
    }
    // Quanto falta para a pausa acabar: "11:40" (min:s) ou "1:05:10".
    function falta(ate) {
        var s = Math.max(0, Math.round(ate - agora));
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = s % 60;
        function dois(n) {
            return n < 10 ? "0" + n : String(n);
        }
        return h > 0 ? h + ":" + dois(m) + ":" + dois(x) : m + ":" + dois(x);
    }
    // "3,6 milhões".
    function muitos(n) {
        if (n >= 1e6)
            return num(n / 1e6, 1) + t(" milhões", " million");
        if (n >= 1e3)
            return num(n / 1e3, 0) + t(" mil", "k");
        return num(n, 0);
    }

    // ----- ações -----
    function marcar(chave, sim) {
        var o = Object.assign({}, ocupado);
        if (sim)
            o[chave] = true;
        else
            delete o[chave];
        ocupado = o;
    }
    function carregar(qual) {
        matsu.rodar("ler:" + qual, comando([qual]));
    }
    // Roda um comando do ajudante que responde {"ok", "erro"}. opcoes: certo (o
    // aviso de pronto), recarregar (páginas para ler de novo), depois(resposta).
    function agir(chave, args, opcoes) {
        if (ocupado[chave])
            return;
        marcar(chave, true);
        _depois[chave] = opcoes || {};
        matsu.rodar("acao:" + chave, comando(args));
    }
    function aoAbrir(p) {
        if (p === "inicio") {
            carregar("inicio");
            carregar("historico");
        }
        else if (p === "rede")
            carregar("rede");
        else if (p === "apps")
            carregar("apps");
        else if (p === "integridade" && !integ)
            carregar("integridade");
        else if (p === "historico") {
            carregar("historico");
            // As ameaças novas foram vistas: o estado sai de "atenção".
            if (cont && cont.novas > 0) {
                mexerEstado(function (e) {
                    e.contagem.novas = 0;
                });
                matsu.rodar("visto", comando(["visto"]));
            }
        }
    }

    // O estado geral, igual ao do ajudante (para mudar na hora, sem esperar o vigia).
    function geralDe(e) {
        if (!e.instalado)
            return "indisponivel";
        if (!e.escudo.ligado)
            return "desligado";
        if (e.escudo.pausado)
            return "pausado";
        if (!e.lista.presente)
            return e.lista.baixando ? "baixando" : "sem-lista";
        if (e.contagem.novas > 0)
            return "atencao";
        if (!e.escudo.servico)
            return "parado";
        return "protegido";
    }
    function mexerEstado(f) {
        if (!est)
            return;
        var e = JSON.parse(JSON.stringify(est));
        f(e);
        e.geral = geralDe(e);
        _seguraAte = Date.now() + 2500;
        est = e;
    }

    function pausar(quanto) {
        var ate = quanto === "reiniciar" ? 0 : agora + Number(quanto) * 60;
        mexerEstado(function (e) {
            e.escudo.pausado = true;
            e.escudo.pausaAte = ate;
            e.escudo.pausaReiniciar = quanto === "reiniciar";
        });
        agir("pausar", ["pausar", String(quanto)], {
            certo: quanto === "reiniciar" ? t("O escudo volta quando você reiniciar", "The shield comes back when you restart")
                                          : t("O escudo volta sozinho às ", "The shield comes back by itself at ") + hora(ate)
        });
    }
    function retomar() {
        mexerEstado(function (e) {
            e.escudo.pausado = false;
            e.escudo.pausaAte = 0;
            e.escudo.pausaReiniciar = false;
            e.escudo.ligado = true;
            e.ajustes.ligado = true;
        });
        agir("retomar", ["retomar"], { certo: t("O escudo voltou a vigiar", "The shield is watching again") });
    }
    function ajuste(chave, valor) {
        mexerEstado(function (e) {
            e.ajustes[chave] = valor;
            if (chave === "ligado") {
                e.escudo.ligado = valor;
                if (valor) {
                    e.escudo.pausado = false;
                    e.escudo.pausaAte = 0;
                }
            }
        });
        agir("ajuste-" + chave, ["ajuste", chave, valor ? "sim" : "nao"], {});
    }
    // Desligar de vez pergunta antes (e sugere a pausa, que volta sozinha).
    function desligarEscudo() {
        dialogo.perguntar({
            titulo: t("Desligar o escudo?", "Turn off the shield?"),
            texto: t("Os arquivos que chegarem não serão conferidos até você ligar de novo. Se é só por um tempo, pause: o escudo volta sozinho.",
                     "Incoming files won't be checked until you turn it back on. If it's just for a while, pause it: the shield comes back by itself."),
            sim: t("Desligar", "Turn off"), nao: t("Cancelar", "Cancel"), terceiro: t("Pausar 1 hora", "Pause 1 hour"), perigo: true
        }, function () {
            ajuste("ligado", false);
        }, function () {
            pausar(60);
        });
    }
    function atualizarLista() {
        mexerEstado(function (e) {
            e.lista.baixando = true;
            e.lista.erro = false;
        });
        agir("lista", ["atualizar-lista"], {});
    }
    function religarEscudo() {
        matsu.soltar(["systemctl", "--user", "restart", "matsu-escudo.service"]);
        avisoRapido(t("Ligando o escudo de novo…", "Starting the shield again…"));
    }

    function verificar(tipo, caminhos) {
        pagina = "escudo";
        if (verRodando)
            return;
        verTipo = tipo;
        verNome = tipo === "caminho" && caminhos && caminhos.length ? String(caminhos[0]).replace(/\/+$/, "").split("/").pop() : "";
        verFase = "preparando";
        verTexto = "";
        verFeitos = 0;
        verTotal = 0;
        verAtual = "";
        verAmeacas = [];
        verFim = null;
        verErro = "";
        verSemLista = false;
        verInicio = Date.now() / 1000;
        verRodando = true;
        matsu.iniciar("verificar", comando(["verificar", tipo].concat(caminhos || [])));
    }
    function cancelarVerificacao() {
        matsu.parar("verificar");
    }
    function verificarSistema() {
        if (fsckRodando)
            return;
        fsckFase = "comecando";
        fsckTexto = t("Esperando a sua senha…", "Waiting for your password…");
        fsckFeitos = 0;
        fsckTotal = 0;
        fsckFim = null;
        fsckRodando = true;
        matsu.iniciar("fsck", comando(["fsck"]));
    }

    function abrirPedido(args) {
        if (!args || args.length === 0)
            return;
        var a = String(args[0]);
        if (a === "verificar-rapida")
            verificar("rapida");
        else if (a === "verificar-completa")
            verificar("completa");
        else if (a === "verificar" && args.length > 1)
            verificar("caminho", [String(args[1])]);
        else if (a === "quarentena") {
            abaHistorico = "quarentena";
            pagina = "historico";
        } else if (a === "app" && args.length > 1) {
            appEscolhido = String(args[1]);
            pagina = "apps";
        } else
            irPara(a);
        raise();
        requestActivate();
    }

    Connections {
        target: matsu
        function onLinha(chave, linha) {
            var r = null;
            try {
                r = JSON.parse(linha);
            } catch (e) {
                return;
            }
            if (chave === "vigiar") {
                if (Date.now() < janela._seguraAte)
                    return;
                if (r.idioma && r.idioma !== janela.lingua)
                    janela.lingua = r.idioma;
                if (r.vidro && JSON.stringify(r.vidro) !== JSON.stringify(janela.vidroConf))
                    janela.vidroConf = r.vidro;
                janela.est = r;
            } else if (chave === "verificar") {
                switch (r.fase) {
                case "preparando":
                    janela.verFase = "preparando";
                    janela.verTexto = r.texto || "";
                    break;
                case "contando":
                    janela.verFase = "contando";
                    janela.verTotal = r.total || 0;
                    break;
                case "verificando":
                    janela.verFase = "verificando";
                    janela.verFeitos = r.feitos || 0;
                    janela.verTotal = r.total || 0;
                    janela.verAtual = r.atual || "";
                    break;
                case "ameaca":
                    janela.verAmeacas = janela.verAmeacas.concat([r]);
                    break;
                case "fim":
                    janela.verFim = r;
                    janela.verFeitos = r.feitos || janela.verFeitos;
                    janela.verFase = "fim";
                    break;
                case "erro":
                    janela.verErro = r.erro || "";
                    janela.verSemLista = !!r.semLista;
                    janela.verFase = "erro";
                    break;
                }
            } else if (chave === "fsck") {
                if (r.fase === "fim") {
                    janela.fsckFim = r;
                    janela.fsckFase = "fim";
                } else if (r.fase === "erro") {
                    janela.fsckFim = { ok: false, erro: r.erro || "", cancelado: !!r.cancelado };
                    janela.fsckFase = "fim";
                } else {
                    janela.fsckFase = r.fase;
                    janela.fsckTexto = r.texto || janela.fsckTexto;
                    if (r.total) {
                        janela.fsckFeitos = r.feitos || 0;
                        janela.fsckTotal = r.total;
                    }
                }
            }
        }
        function onParou(chave, codigo) {
            if (chave === "vigiar") {
                religarVigia.restart();
            } else if (chave === "verificar") {
                janela.verRodando = false;
                if (janela.verFase !== "fim" && janela.verFase !== "erro") {
                    janela.verFase = "erro";
                    janela.verErro = janela.t("A verificação parou antes do fim.", "The scan stopped before the end.");
                }
                if (janela.pagina === "historico")
                    janela.carregar("historico");
            } else if (chave === "fsck") {
                janela.fsckRodando = false;
                if (janela.fsckFase !== "fim") {
                    janela.fsckFim = { ok: false, erro: janela.t("A conferência parou antes do fim.", "The check stopped before the end.") };
                    janela.fsckFase = "fim";
                }
            }
        }
        function onPronto(chave, saida, codigo) {
            var r = null;
            try {
                r = JSON.parse(saida);
            } catch (e) {
                r = null;
            }
            if (chave.indexOf("ler:") === 0) {
                var q = chave.substring(4);
                var dados = r || { falhou: true };
                if (q === "inicio")
                    janela.resumo = dados;
                else if (q === "rede")
                    janela.rede = dados;
                else if (q === "apps")
                    janela.apps = dados;
                else if (q === "integridade")
                    janela.integ = dados;
                else if (q === "historico")
                    janela.hist = dados;
            } else if (chave.indexOf("acao:") === 0) {
                var k = chave.substring(5);
                var o = janela._depois[k] || {};
                delete janela._depois[k];
                janela.marcar(k, false);
                if (r && r.ok) {
                    if (o.certo)
                        janela.avisoRapido(o.certo, "certo");
                } else if (!(r && r.cancelado)) {
                    janela.avisoRapido(r && r.erro ? r.erro : janela.t("Não deu certo. Tente de novo.", "That didn't work. Try again."), "erro");
                }
                (o.recarregar || []).forEach(function (p) {
                    janela.carregar(p);
                });
                if (o.depois)
                    o.depois(r || {});
            }
        }
        function onPedido(argumentos) {
            janela.abrirPedido(argumentos);
        }
    }

    Timer {
        id: religarVigia
        interval: 3000
        onTriggered: matsu.iniciar("vigiar", janela.comando(["vigiar", "2"]))
    }
    // O relógio da contagem da pausa e dos "há 3 min".
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: janela.agora = Date.now() / 1000
    }

    Dialogo {
        id: dialogoCentral
    }
    MenuMatsu {
        id: menuPausaCentral
        itens: [
            { id: "15", nome: janela.t("Pausar por 15 minutos", "Pause for 15 minutes"), icone: Qt.resolvedUrl("icones/pausa.svg") },
            { id: "60", nome: janela.t("Pausar por 1 hora", "Pause for 1 hour"), icone: Qt.resolvedUrl("icones/pausa.svg") },
            { id: "reiniciar", nome: janela.t("Pausar até reiniciar", "Pause until restart"), icone: "matsu-recarregar-symbolic" },
            { id: "desligar", nome: janela.t("Desligar o escudo…", "Turn off the shield…"), icone: Qt.resolvedUrl("icones/menos.svg"), perigo: true, separador: true }
        ]
        onEscolhido: (id) => {
            if (id === "desligar")
                janela.desligarEscudo();
            else
                janela.pausar(id);
        }
    }

    Component.onCompleted: {
        matsu.iniciar("vigiar", comando(["vigiar", "2"]));
        abrirPedido(matsu.argumentos);
        aoAbrir(pagina);
    }
}
