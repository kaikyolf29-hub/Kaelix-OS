// Central de jogos do Kaelix (no jeito do AMD Software do Windows): os jogos da
// Steam com as capas de verdade, os perfis gráficos (Padrão, Desempenho,
// Qualidade, Economia e Personalizado), a sobreposição no jogo (FPS, CPU, GPU...)
// e a placa de vídeo com o driver. A janela de vidro é a JanelaKaelix, de ../comum.
//
// Aqui é só o desenho. Quem lê o sistema, a Steam e grava os ajustes é o
// ajudante.py desta pasta; quem liga o modo jogo quando um jogo abre é o serviço
// kaelix-jogos (o mesmo ajudante, rodando sozinho na sessão).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

JanelaKaelix {
    id: janela

    title: t("Central de jogos", "Game Center")
    icone: "org.kaelix.jogos"
    iconeReserva: "applications-games"
    dicaBusca: t("Buscar nos seus jogos", "Search your games")
    paginaDaBusca: "jogos"
    paginas: [
        { id: "inicio", icone: "kaelix-inicio-symbolic", nome: t("Início", "Home") },
        { id: "jogos", icone: "kaelix-jogos-symbolic", nome: t("Meus jogos", "My games") },
        { id: "graficos", icone: "kaelix-graficos-symbolic", nome: t("Gráficos", "Graphics") },
        { id: "sobreposicao", icone: "kaelix-sobreposicao-symbolic", nome: t("Sobreposição", "Overlay") },
        { id: "placa", icone: "kaelix-placa-symbolic", nome: t("Placa de vídeo", "Graphics card") }
    ]
    conteudo: Qt.resolvedUrl(({ jogos: "PaginaJogos.qml", graficos: "PaginaGraficos.qml", sobreposicao: "PaginaSobreposicao.qml",
                                placa: "PaginaPlaca.qml" })[pagina] || "PaginaInicio.qml")
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
                  desempenho: t("Mais FPS e menos atraso: energia e placa no máximo.", "More FPS, less lag: power and GPU at max."),
                  qualidade: t("Imagem mais lisa e nítida, sem cortes na tela.", "Smoother, sharper picture, no tearing."),
                  economia: t("60 FPS, mais silencioso e mais bateria.", "60 FPS, quieter and longer battery."),
                  personalizado: t("Você escolhe cada ajuste.", "You choose each setting.") })[p] || "";
    }
    function iconePerfil(p) {
        return ({ padrao: "kaelix-perfil-padrao-symbolic", desempenho: "kaelix-raio-symbolic", qualidade: "kaelix-qualidade-symbolic",
                  economia: "kaelix-folha-symbolic", personalizado: "kaelix-ajustes-symbolic" })[p] || "";
    }
    // As cores das bolinhas do Kaelix (rosa, azul claro, verde água) e da paleta.
    function corPerfil(p) {
        return escuro ? ({ padrao: "#45d0c1", desempenho: "#f0609e", qualidade: "#b18cf5", economia: "#7fcf6a", personalizado: "#f5b330" })[p]
                      : ({ padrao: "#0f9c8e", desempenho: "#d23f78", qualidade: "#7650dc", economia: "#3d9533", personalizado: "#c98a12" })[p];
    }
    // O que cada perfil pronto faz (o mesmo que o ajudante usa).
    readonly property var ajustesProntos: ({
        padrao: { energia: "manter", placa: "auto", fps: 0, vsync: "jogo", af: 0, modo_jogo: true },
        desempenho: { energia: "desempenho", placa: "maximo", fps: 0, vsync: "desligada", af: 0, modo_jogo: true },
        qualidade: { energia: "desempenho", placa: "auto", fps: 0, vsync: "ligada", af: 16, modo_jogo: true },
        economia: { energia: "economia", placa: "economia", fps: 60, vsync: "ligada", af: 0, modo_jogo: false }
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
    function salvar(nova) {
        conf = nova;
        kaelix.rodar("salvar", comando(["salvar", JSON.stringify(nova)]));
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
        kaelix.soltar(comando(["jogar", id]));
    }
    function abrirSteam(caminho) {
        kaelix.soltar(["xdg-open", caminho || "steam://open/games"]);
    }
    function abrirPasta(pasta) {
        kaelix.soltar(["xdg-open", pasta]);
    }
    function procurarAtualizacao() {
        procurando = true;
        kaelix.rodar("atualizacao", comando(["atualizacao", "--agora"]));
    }
    function atualizarAgora() {
        kaelix.soltar(["/usr/libexec/kaelix/kaelix-central", "abrir", "atualizar"]);
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
        var mudouJogo = (dados && dados.jogo ? dados.jogo.id : "") !== (d.jogo ? d.jogo.id : "");
        dados = d;
        tique++;
        // Um jogo abriu ou fechou: as horas jogadas mudaram.
        if (mudouJogo && bibliotecaLida)
            lerBiblioteca();
    }

    function iniciarVigia() {
        kaelix.iniciar("vigia", comando(["vigiar", "1"]));
    }
    function lerBiblioteca() {
        kaelix.rodar("biblioteca", comando(["biblioteca"]));
    }

    Connections {
        target: kaelix
        function onLinha(chave, texto) {
            if (chave === "vigia")
                janela.receber(texto);
        }
        function onParou(chave, codigo) {
            if (chave === "vigia")
                religar.start();
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
        kaelix.rodar("config", comando(["config"]));
        kaelix.rodar("atualizacao", comando(["atualizacao"]));
        if (kaelix.argumentos.length > 0)
            irPara(kaelix.argumentos[0]);
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
                            Texto {
                                text: barra.modelData.texto
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
