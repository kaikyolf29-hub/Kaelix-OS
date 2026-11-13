// Central de jogos do Matsu (no jeito do AMD Software do Windows): os jogos da
// Steam com as capas de verdade, os perfis gráficos (Padrão, Desempenho,
// Qualidade, Economia e Personalizado), a sobreposição no jogo (FPS, CPU, GPU...),
// os controles (PlayStation, Xbox... pelo Bluetooth), a placa de vídeo e os
// drivers. A janela de vidro é a JanelaMatsu, de ../comum.
//
// Aqui é só o desenho. Quem lê o sistema, a Steam e grava os ajustes é o
// ajudante.py desta pasta; quem liga o modo jogo quando um jogo abre é o serviço
// matsu-jogos (o mesmo ajudante, rodando sozinho na sessão).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

JanelaMatsu {
    id: janela

    title: t("Central de jogos", "Game Center")
    icone: "org.matsu.jogos"
    iconeReserva: "applications-games"
    dicaBusca: t("Buscar nos seus jogos", "Search your games")
    paginaDaBusca: "jogos"
    trocaSuave: true
    paginas: [
        { id: "inicio", icone: "matsu-inicio-symbolic", nome: t("Início", "Home") },
        { id: "jogos", icone: "matsu-jogos-symbolic", nome: t("Meus jogos", "My games") },
        { id: "graficos", icone: "matsu-graficos-symbolic", nome: t("Gráficos", "Graphics") },
        { id: "sobreposicao", icone: "matsu-sobreposicao-symbolic", nome: t("Sobreposição", "Overlay") },
        { id: "controles", icone: Qt.resolvedUrl("icones/controle.svg"), nome: t("Controles", "Controllers") },
        { id: "placa", icone: "matsu-placa-symbolic", nome: t("Placa de vídeo", "Graphics card") },
        { id: "drivers", icone: Qt.resolvedUrl("icones/driver.svg"), nome: t("Drivers", "Drivers") }
    ]
    conteudo: Qt.resolvedUrl(({ jogos: "PaginaJogos.qml", graficos: "PaginaGraficos.qml", sobreposicao: "PaginaSobreposicao.qml",
                                controles: "PaginaControles.qml", placa: "PaginaPlaca.qml", drivers: "PaginaDrivers.qml" })[pagina]
                             || "PaginaInicio.qml")
    width: gu * 64
    height: gu * 40
    minimumWidth: gu * 44
    minimumHeight: gu * 28

    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }

    // ----- o que o ajudante manda -----
    property var dados: null          // leitura de um em um segundo (placa, CPU, jogo aberto...)
    property int tique: 0
    property var historico: ({})
    readonly property int pontos: 60
    property var jogos: []            // a biblioteca, do último jogado para o primeiro
    property bool temSteam: true
    property bool bibliotecaLida: false
    property var conf: null           // a configuração da central
    property var atualizacao: null    // se o sistema (e o driver junto) tem versão nova
    property bool procurando: false
    // O jogo aberto nos detalhes (em Meus jogos).
    property string jogoAberto: ""

    readonly property var placa: dados && dados.placas.length > 0 ? dados.placas[0] : null
    readonly property var jogoAgora: dados ? dados.jogo : null

    // ----- perfis -----
    readonly property var perfis: ["padrao", "desempenho", "qualidade", "economia", "personalizado"]
    function nomePerfil(p) {
        return ({ padrao: t("Padrão", "Default"), desempenho: t("Desempenho", "Performance"),
                  qualidade: t("Qualidade", "Quality"), economia: t("Economia", "Power saving"),
                  personalizado: t("Personalizado", "Custom") })[p] || p;
    }
    function textoPerfil(p) {
        return ({ padrao: t("O jogo decide. Só liga o modo jogo.", "The game decides. Just turns on game mode."),
                  desempenho: t("Mais FPS e menos atraso: tudo no máximo.", "More FPS, less lag: everything at max."),
                  qualidade: t("Imagem mais lisa e nítida, sem cortes na tela.", "Smoother, sharper picture, no tearing."),
                  economia: t("Limite de 60 FPS: mais silencioso e mais bateria.", "60 FPS cap: quieter and longer battery."),
                  personalizado: t("Você escolhe cada ajuste.", "You choose each setting.") })[p] || "";
    }
    function iconePerfil(p) {
        return ({ padrao: "matsu-perfil-padrao-symbolic", desempenho: "matsu-raio-symbolic", qualidade: "matsu-qualidade-symbolic",
                  economia: "matsu-folha-symbolic", personalizado: "matsu-ajustes-symbolic" })[p] || "";
    }
    // As cores das bolinhas do Matsu (rosa, azul claro, verde água) e da paleta.
    function corPerfil(p) {
        return escuro ? ({ padrao: "#45d0c1", desempenho: "#f0609e", qualidade: "#b18cf5", economia: "#7fcf6a", personalizado: "#f5b330" })[p]
                      : ({ padrao: "#0f9c8e", desempenho: "#d23f78", qualidade: "#7650dc", economia: "#3d9533", personalizado: "#c98a12" })[p];
    }
    // O que cada perfil pronto faz (o mesmo PERFIS do ajudante; o teste confere).
    readonly property var ajustesProntos: ({
        padrao: { energia: "manter", placa: "auto", fps: 0, vsync: "jogo", af: 0, modo_jogo: true, latencia: false },
        desempenho: { energia: "desempenho", placa: "maximo", fps: 0, vsync: "desligada", af: 0, modo_jogo: true, latencia: true },
        qualidade: { energia: "desempenho", placa: "auto", fps: 0, vsync: "ligada", af: 16, modo_jogo: true, latencia: false },
        economia: { energia: "economia", placa: "auto", fps: 60, vsync: "ligada", af: 0, modo_jogo: false, latencia: false }
    })
    function ajustesDe(p) {
        if (p === "personalizado")
            return conf ? conf.personalizado : ajustesProntos.padrao;
        return ajustesProntos[p] || ajustesProntos.padrao;
    }
    function perfilDoJogo(id) {
        return conf && conf.jogos[id] ? conf.jogos[id] : "";
    }

    // ----- gravar -----
    function copia(o) {
        return JSON.parse(JSON.stringify(o));
    }
    property double gravadoEm: 0
    function salvar(nova) {
        conf = nova;
        gravadoEm = Date.now();
        matsu.rodar("salvar", comando(["salvar", JSON.stringify(nova)]));
    }
    // mudar("sobreposicao.ligada", true)
    function mudar(caminho, valor) {
        if (!conf)
            return;
        var nova = copia(conf);
        var partes = caminho.split(".");
        var alvo = nova;
        for (var i = 0; i < partes.length - 1; i++)
            alvo = alvo[partes[i]];
        alvo[partes[partes.length - 1]] = valor;
        salvar(nova);
    }
    function escolherPerfilDoJogo(id, perfil) {
        var nova = copia(conf);
        if (perfil)
            nova.jogos[id] = perfil;
        else
            delete nova.jogos[id];
        salvar(nova);
    }

    // ----- abrir coisas -----
    function jogar(id) {
        matsu.soltar(comando(["jogar", id]));
    }
    function abrirSteam(caminho) {
        matsu.soltar(["xdg-open", caminho || "steam://open/games"]);
    }
    function abrirPasta(pasta) {
        matsu.soltar(["xdg-open", pasta]);
    }
    function procurarAtualizacao() {
        procurando = true;
        matsu.rodar("atualizacao", comando(["atualizacao", "--agora"]));
    }
    // O app Atualizações do Matsu (o driver da placa vem junto com o sistema).
    function atualizarAgora() {
        matsu.soltar(["/usr/libexec/matsu/matsu-central", "abrir", "atualizacoes"]);
    }
    function reiniciar() {
        matsu.soltar(["systemctl", "reboot"]);
    }
    function perguntar(p, sim) {
        dialogo.perguntar(p, sim);
    }

    // ----- FPS no jogo (o mesmo liga e desliga da Central de controle e do atalho) -----
    readonly property bool fpsLigado: conf ? conf.sobreposicao.ligada : false
    readonly property string atalhoFps: dados && dados.atalho ? dados.atalho : "Meta+Alt+F"
    // As teclas do atalho para mostrar na tela (Meta é a tecla com a janelinha: "Win").
    readonly property var teclasAtalho: atalhoFps.split("+").map(function (k) { return k === "Meta" ? "Win" : k; })
    readonly property string textoAtalho: teclasAtalho.join(" + ")
    function ligarFps(ligada) {
        mudar("sobreposicao.ligada", ligada);
    }

    // ----- controles -----
    property var controles: null      // { bluetooth: {tem, ligado, programa}, controles: [...] }
    property var pareamento: null     // a última etapa do pareamento ({ etapa, ... })
    property bool pareando: false
    property string tipoPareando: ""
    property var teste: null          // o estado ao vivo do controle em teste
    property var controleEmTeste: null
    property string erroTeste: ""
    property string controleOcupado: ""   // o MAC do controle com uma ação em andamento
    property bool ligandoBluetooth: false
    function lerControles() {
        matsu.rodar("controles", comando(["controles"]));
    }
    function acaoControle(qual, mac) {
        controleOcupado = mac;
        matsu.rodar("controle:" + qual, comando(["controle", qual, mac]));
    }
    function ligarBluetooth() {
        ligandoBluetooth = true;
        matsu.rodar("bluetooth", comando(["bluetooth-ligar"]));
    }
    function parear(tipo) {
        if (pareando)
            return;
        tipoPareando = tipo;
        pareamento = { etapa: "comecando" };
        pareando = true;
        matsu.iniciar("parear", comando(["parear", tipo, "30"]));
    }
    function cancelarPareamento() {
        matsu.parar("parear");
        pareando = false;
        pareamento = null;
    }
    function testar(c) {
        pararTeste();
        controleEmTeste = c;
        teste = null;
        erroTeste = "";
        matsu.iniciar("teste", comando(["testar", c.evento, c.tipo]));
    }
    function pararTeste() {
        matsu.parar("teste");
        controleEmTeste = null;
        teste = null;
    }
    function nomeTipo(tipo) {
        return ({ playstation: "PlayStation", xbox: "Xbox", nintendo: "Nintendo", steam: "Steam" })[tipo] || t("Controle", "Controller");
    }

    // ----- drivers -----
    property var drivers: null
    property bool lendoDrivers: false
    property var troca: null          // { linhas: [...], fim: bool, erro: código }
    function lerDrivers(agora) {
        lendoDrivers = true;
        matsu.rodar("drivers", comando(agora ? ["drivers", "--agora"] : ["drivers"]));
    }
    // outra: vai para a outra versão (com ou sem NVIDIA) mesmo sem a placa pedir.
    function trocarImagem(outra) {
        troca = { linhas: [], fim: false, erro: 0, alvo: "" };
        matsu.iniciar("troca", comando(outra ? ["trocar-imagem", "outra"] : ["trocar-imagem"]));
    }

    // ----- textos -----
    // Caminho de arquivo virando endereço (os nomes das pastas da Steam têm espaço).
    function arquivo(caminho) {
        if (!caminho)
            return "";
        return "file://" + caminho.split("/").map(encodeURIComponent).join("/");
    }
    function horas(minutos) {
        if (!minutos)
            return t("Nunca jogado", "Never played");
        if (minutos < 60)
            return minutos + " min";
        var h = minutos / 60;
        return (h < 10 ? num(h, 1) : num(Math.round(h), 0)) + " h";
    }
    function quando(segundos) {
        if (!segundos)
            return t("Ainda não jogou", "Not played yet");
        var agora = new Date();
        var dia = new Date(segundos * 1000);
        var hoje = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate());
        var dias = Math.floor((hoje - new Date(dia.getFullYear(), dia.getMonth(), dia.getDate())) / 86400000);
        if (dias <= 0)
            return t("Hoje", "Today");
        if (dias === 1)
            return t("Ontem", "Yesterday");
        if (dias < 7)
            return t("Há " + dias + " dias", dias + " days ago");
        if (dias < 30) {
            var s = Math.floor(dias / 7);
            return pt ? (s === 1 ? "Há 1 semana" : "Há " + s + " semanas") : (s === 1 ? "1 week ago" : s + " weeks ago");
        }
        return dia.toLocaleDateString(local, pt ? "d 'de' MMM 'de' yyyy" : "MMM d, yyyy");
    }
    function jogoPorId(id) {
        for (var i = 0; i < jogos.length; i++)
            if (jogos[i].id === id)
                return jogos[i];
        return null;
    }

    // ----- leituras -----
    function guardar(h, chave, valor) {
        var lista = h[chave] || [];
        lista.push(valor);
        if (lista.length > pontos)
            lista.shift();
        h[chave] = lista;
    }

    function receber(texto) {
        var d;
        try {
            d = JSON.parse(texto);
        } catch (e) {
            return;
        }
        if (d.idioma)
            lingua = d.idioma;
        if (d.vidro && JSON.stringify(d.vidro) !== JSON.stringify(vidroConf))
            vidroConf = d.vidro;
        var h = historico;
        guardar(h, "cpu", d.cpu.uso);
        if (d.placas.length > 0) {
            var p = d.placas[0];
            guardar(h, "uso", Math.max(0, p.uso));
            guardar(h, "temp", p.temp);
            guardar(h, "mhz", p.mhz);
            guardar(h, "vram", p.vram_total > 0 ? 100 * p.vram_usada / p.vram_total : 0);
            guardar(h, "watts", p.watts);
            guardar(h, "ventoinha", p.rpm > 0 ? p.rpm : Math.max(0, p.ventoinha));
        }
        historico = h;
        // O FPS no jogo mudou pelo atalho ou pela Central de controle.
        if (conf && d.fps !== undefined && d.fps !== conf.sobreposicao.ligada && Date.now() - gravadoEm > 3000) {
            var c = copia(conf);
            c.sobreposicao.ligada = d.fps;
            conf = c;
        }
        var mudouJogo = (dados && dados.jogo ? dados.jogo.id : "") !== (d.jogo ? d.jogo.id : "");
        dados = d;
        tique++;
        // Um jogo abriu ou fechou: as horas jogadas mudaram.
        if (mudouJogo && bibliotecaLida)
            lerBiblioteca();
    }

    function iniciarVigia() {
        matsu.iniciar("vigia", comando(["vigiar", "1"]));
    }
    function lerBiblioteca() {
        matsu.rodar("biblioteca", comando(["biblioteca"]));
    }

    Connections {
        target: matsu
        function onLinha(chave, texto) {
            if (chave === "vigia") {
                janela.receber(texto);
                return;
            }
            var d;
            try {
                d = JSON.parse(texto);
            } catch (e) {
                return;
            }
            if (chave === "parear") {
                janela.pareamento = d;
                if (d.etapa === "pronto" || d.etapa === "erro")
                    janela.lerControles();
            } else if (chave === "teste") {
                if (d.erro)
                    janela.erroTeste = d.erro;
                else
                    janela.teste = d;
            } else if (chave === "troca" && janela.troca) {
                var t = janela.copia(janela.troca);
                if (d.alvo)
                    t.alvo = d.alvo;
                if (d.linha) {
                    t.linhas.push(d.linha);
                    if (t.linhas.length > 6)
                        t.linhas.shift();
                }
                if (d.fim !== undefined) {
                    t.fim = true;
                    t.erro = d.fim;
                }
                janela.troca = t;
            }
        }
        function onParou(chave, codigo) {
            if (chave === "vigia") {
                religar.start();
            } else if (chave === "parear") {
                janela.pareando = false;
                // Parou sem dizer o porquê (o programa caiu): mostra como falha.
                if (janela.pareamento && janela.pareamento.etapa !== "pronto" && janela.pareamento.etapa !== "erro")
                    janela.pareamento = codigo === 0 ? null : { etapa: "erro", erro: "falhou" };
            } else if (chave === "teste") {
                if (janela.controleEmTeste && !janela.erroTeste && codigo !== 0 && codigo !== 15)
                    janela.erroTeste = "sumiu";
            } else if (chave === "troca" && janela.troca && !janela.troca.fim) {
                var t = janela.copia(janela.troca);
                t.fim = true;
                t.erro = codigo === 0 ? 1 : codigo;
                janela.troca = t;
            }
        }
        function onPronto(chave, saida, codigo) {
            var d = null;
            try {
                d = JSON.parse(saida);
            } catch (e) {
                d = null;
            }
            if (chave === "biblioteca" && d) {
                janela.jogos = d.jogos;
                janela.temSteam = d.steam;
                janela.bibliotecaLida = true;
            } else if ((chave === "config" || chave === "salvar") && d) {
                janela.conf = d;
            } else if (chave === "atualizacao") {
                janela.procurando = false;
                if (d)
                    janela.atualizacao = d;
            } else if (chave === "controles" && d) {
                janela.controles = d;
            } else if (chave.indexOf("controle:") === 0) {
                var qual = chave.split(":")[1];
                janela.controleOcupado = "";
                if (d && d.ok)
                    janela.avisoRapido(({ desconectar: janela.t("Controle desconectado", "Controller disconnected"),
                                          conectar: janela.t("Controle conectado", "Controller connected"),
                                          esquecer: janela.t("Controle esquecido", "Controller forgotten") })[qual] || "", "certo")
                else
                    janela.avisoRapido(janela.textoErroControle(d ? d.erro : "", qual), "erro");
                janela.lerControles();
            } else if (chave === "bluetooth") {
                janela.ligandoBluetooth = false;
                if (!d || !d.ok)
                    janela.avisoRapido(janela.t("Não deu para ligar o Bluetooth", "Couldn't turn Bluetooth on"), "erro");
                janela.lerControles();
            } else if (chave === "drivers") {
                janela.lendoDrivers = false;
                if (d)
                    janela.drivers = d;
            }
        }
        function onPedido(argumentos) {
            if (argumentos.length > 0)
                janela.irPara(argumentos[0]);
        }
    }

    Timer {
        id: religar
        interval: 2000
        onTriggered: janela.iniciarVigia()
    }
    // Na página dos controles: a lista (conectado, bateria) se atualiza sozinha.
    Timer {
        interval: 3000
        running: janela.active && janela.pagina === "controles" && !janela.pareando
        repeat: true
        onTriggered: janela.lerControles()
    }
    // Saiu da página dos controles: o teste e a busca param.
    onPaginaChanged: {
        if (pagina !== "controles") {
            if (controleEmTeste)
                pararTeste();
            if (pareando)
                cancelarPareamento();
            pareamento = null;
        }
        if (pagina === "controles")
            lerControles();
        if (pagina === "drivers" && !drivers && !lendoDrivers)
            lerDrivers(false);
    }

    function textoErroControle(erro, qual) {
        return ({ "sem-adaptador": t("Este computador não tem Bluetooth", "This computer has no Bluetooth"),
                  desligado: t("O Bluetooth está desligado", "Bluetooth is off"),
                  tempo: t("O controle não respondeu a tempo", "The controller didn't answer in time"),
                  sumiu: t("O controle não está mais por perto", "The controller is no longer nearby") })[erro]
               || (qual === "esquecer" ? t("Não deu para esquecer o controle", "Couldn't forget the controller")
                                       : t("Não deu para falar com o controle", "Couldn't reach the controller"));
    }

    Dialogo {
        id: dialogo
    }
    // A biblioteca muda quando a pessoa instala um jogo pela Steam.
    Timer {
        interval: 60000
        running: janela.active
        repeat: true
        onTriggered: janela.lerBiblioteca()
    }
    onActiveChanged: if (active && bibliotecaLida) lerBiblioteca()

    Component.onCompleted: {
        iniciarVigia();
        lerBiblioteca();
        matsu.rodar("config", comando(["config"]));
        matsu.rodar("atualizacao", comando(["atualizacao"]));
        if (matsu.argumentos.length > 0)
            irPara(matsu.argumentos[0]);
    }

    // Embaixo da lista: o jogo aberto agora (com o modo jogo), ou a placa de vídeo.
    rodapeLateral: Component {
        Item {
            implicitHeight: agora.visible ? agora.implicitHeight : resumo.implicitHeight

            // Jogo aberto: a capinha dele, o nome e o perfil, com o pontinho aceso.
            Cartao {
                id: agora
                readonly property var jogo: janela.jogoAgora
                readonly property var info: jogo ? janela.jogoPorId(jogo.id) : null
                visible: jogo !== null && jogo !== undefined
                width: parent.width
                implicitHeight: Math.round(janela.gu * 3.6)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.45)
                    spacing: Math.round(janela.gu * 0.5)
                    Item {
                        Layout.preferredWidth: Math.round(janela.gu * 2.6)
                        Layout.fillHeight: true
                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            color: agora.jogo ? janela.corPerfil(agora.jogo.perfil) : "transparent"
                            opacity: 0.25
                            visible: !capinha.visible
                        }
                        ImagemRedonda {
                            id: capinha
                            anchors.fill: parent
                            raio: 5
                            visible: status === Image.Ready
                            source: agora.info && agora.info.icone ? janela.arquivo(agora.info.icone)
                                  : (agora.info && agora.info.capa ? janela.arquivo(agora.info.capa) : "")
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Texto {
                            Layout.fillWidth: true
                            text: agora.jogo ? agora.jogo.nome : ""
                            elide: Text.ElideRight
                            font.weight: Font.DemiBold
                            font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
                        }
                        Row {
                            spacing: 5
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 6
                                radius: 3
                                color: janela.escuro ? "#7fcf6a" : "#3d9533"
                                SequentialAnimation on opacity {
                                    running: agora.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                                }
                            }
                            Texto {
                                text: agora.jogo ? janela.nomePerfil(agora.jogo.perfil) : ""
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.7
                            }
                        }
                    }
                }
            }

            // Sem jogo: a placa de vídeo numa olhada (uso e temperatura).
            ColumnLayout {
                id: resumo
                visible: !agora.visible && janela.placa !== null
                width: parent.width
                spacing: Math.round(janela.gu * 0.4)

                Repeater {
                    model: janela.placa ? [
                        { nome: "GPU", cor: janela.cores.gpu, valor: Math.max(0, janela.placa.uso), texto: janela.porcento(Math.max(0, janela.placa.uso)) },
                        { nome: janela.t("Temperatura", "Temperature"), cor: janela.placa.temp >= 85 ? "#f0609e" : janela.cores.rede,
                          valor: Math.min(100, janela.placa.temp), texto: janela.placa.temp > 0 ? janela.placa.temp + " °C" : "—" }
                    ] : []

                    ColumnLayout {
                        id: barra
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Texto {
                                Layout.fillWidth: true
                                text: barra.modelData.nome
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.7
                            }
                            NumeroRolante {
                                texto: barra.modelData.texto
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.features: { "tnum": 1 }
                                opacity: 0.9
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 3
                            radius: 1.5
                            color: janela.tinta(0.1)
                            Rectangle {
                                width: parent.width * Math.min(1, barra.modelData.valor / 100)
                                height: parent.height
                                radius: 1.5
                                color: barra.modelData.cor
                                Behavior on width {
                                    NumberAnimation {
                                        duration: Kirigami.Units.longDuration
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
