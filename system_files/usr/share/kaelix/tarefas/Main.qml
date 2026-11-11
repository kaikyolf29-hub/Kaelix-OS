// Gerenciador de tarefas do Kaelix: janela de vidro (o papel de parede desfocado
// atrás, em cinza neutro), com a barra de título própria (bolinhas da janela, nome
// e a busca no meio, como no Windows 11) e a lista de assuntos à esquerda:
// Processos, Desempenho e Inicialização. Abre com Ctrl+Shift+Esc, pelo
// kaelix-janela (que dá a identidade da janela, o vidro e a sombra). A janela em
// si (vidro, barra de título, lista e miolo) é a JanelaKaelix, de ../comum.
//
// Aqui é só o desenho. Quem lê o sistema e fecha os processos é o ajudante.py
// desta pasta: ele fica rodando e manda uma leitura completa por segundo.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

JanelaKaelix {
    id: janela

    title: t("Gerenciador de tarefas", "Task Manager")
    icone: "org.kaelix.tarefas"
    iconeReserva: "kaelix-tarefas"
    dicaBusca: t("Buscar por nome ou PID", "Search by name or PID")
    // Buscar leva para Processos.
    paginaDaBusca: "processos"
    paginas: [
        { id: "processos", icone: "kaelix-processos-symbolic", nome: t("Processos", "Processes") },
        { id: "desempenho", icone: "kaelix-desempenho-symbolic", nome: t("Desempenho", "Performance") },
        { id: "inicializacao", icone: "kaelix-inicializacao-symbolic", nome: t("Inicialização", "Startup apps") }
    ]
    conteudo: Qt.resolvedUrl(({ desempenho: "PaginaDesempenho.qml", inicializacao: "PaginaInicializacao.qml" })[pagina] || "PaginaProcessos.qml")

    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }

    property var dados: null
    property int tique: 0
    // Últimos 60 valores de cada gráfico (chave: "cpu", "mem", "disco:sda"...).
    property var historico: ({})
    readonly property int pontos: 60

    // O "calor" das colunas, como no Windows: um âmbar bem leve, mais forte quanto
    // mais a coisa gasta. Parada, fica sem cor.
    readonly property color brasa: escuro ? "#eab24c" : "#f5b330"
    function calor(valor, cheio) {
        var r = cheio > 0 ? Math.sqrt(Math.min(1, Math.max(0, valor) / cheio)) : 0;
        if (r < 0.15)
            return "transparent";
        var a = escuro ? 0.04 + 0.26 * r : 0.14 + 0.5 * r;
        return Qt.rgba(brasa.r, brasa.g, brasa.b, a);
    }

    function mbs(b) {
        var v = (Number(b) || 0) / 1048576;
        return num(v, v > 0 && v < 0.05 ? 2 : 1) + " MB/s";
    }
    function bits(b) {
        var v = (Number(b) || 0) * 8;
        if (v >= 1e9)
            return num(v / 1e9, 1) + " Gbps";
        if (v >= 1e6)
            return num(v / 1e6, 1) + " Mbps";
        return num(v / 1e3, 0) + " Kbps";
    }

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
        guardar(h, "mem", d.memoria.total > 0 ? 100 * d.memoria.usada / d.memoria.total : 0);
        for (var i = 0; i < d.discos.length; i++) {
            var k = d.discos[i];
            guardar(h, "disco:" + k.nome, k.ativo);
            guardar(h, "disco-l:" + k.nome, k.leitura);
            guardar(h, "disco-g:" + k.nome, k.gravacao);
        }
        for (var j = 0; j < d.redes.length; j++) {
            var r = d.redes[j];
            guardar(h, "rede-r:" + r.nome, r.rec);
            guardar(h, "rede-e:" + r.nome, r.env);
        }
        for (var p = 0; p < d.placas.length; p++)
            guardar(h, "gpu:" + p, Math.max(0, d.placas[p].uso));
        historico = h;
        dados = d;
        tique++;
    }

    function iniciarVigia() {
        kaelix.iniciar("vigia", comando(["vigiar", "1"]));
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
        function onPedido(argumentos) {
            if (argumentos.length > 0)
                janela.irPara(argumentos[0]);
        }
    }

    // Se o ajudante cair, volta a ler depois de um instante.
    Timer {
        id: religar
        interval: 2000
        onTriggered: janela.iniciarVigia()
    }

    Component.onCompleted: {
        iniciarVigia();
        if (kaelix.argumentos.length > 0)
            irPara(kaelix.argumentos[0]);
    }

    // Resumo embaixo da lista: CPU e memória agora, como uma olhada rápida.
    rodapeLateral: Component {
        ColumnLayout {
            spacing: Math.round(janela.gu * 0.4)
            visible: janela.dados !== null

            Repeater {
                model: [
                    { nome: "CPU", cor: janela.cores.cpu, valor: janela.dados ? janela.dados.cpu.uso : 0 },
                    { nome: janela.t("Memória", "Memory"), cor: janela.cores.mem,
                      valor: janela.dados && janela.dados.memoria.total > 0 ? 100 * janela.dados.memoria.usada / janela.dados.memoria.total : 0 }
                ]

                ColumnLayout {
                    id: resumo
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Texto {
                            Layout.fillWidth: true
                            text: resumo.modelData.nome
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.7
                        }
                        Texto {
                            text: janela.porcento(resumo.modelData.valor)
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
                            width: parent.width * Math.min(1, resumo.modelData.valor / 100)
                            height: parent.height
                            radius: 1.5
                            color: resumo.modelData.cor
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
