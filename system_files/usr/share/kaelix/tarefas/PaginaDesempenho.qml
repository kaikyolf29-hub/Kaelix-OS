// Desempenho, como no Windows: à esquerda cada parte do computador com um
// gráfico pequeno (CPU, memória, discos, rede, placa de vídeo); à direita a
// parte escolhida, com o gráfico do último minuto e os números dela.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    property string escolhida: "cpu"
    readonly property var d: janela.dados

    function tipoDisco(k) {
        switch (k.tipo) {
        case "nvme":
            return "SSD (NVMe)";
        case "ssd":
            return "SSD";
        case "hd":
            return janela.t("HD", "HDD");
        case "virtual":
            return janela.t("Disco virtual", "Virtual disk");
        }
        return "";
    }

    function partes() {
        var l = [];
        if (!d)
            return l;
        l.push({ chave: "cpu", nome: "CPU", cor: janela.cores.cpu, hist: "cpu", hist2: "", max: 100,
                 sub: janela.porcento(d.cpu.uso) + (d.cpu.ghz > 0 ? "  " + janela.num(d.cpu.ghz, 2) + " GHz" : ""), sub2: "" });
        var m = d.memoria;
        l.push({ chave: "mem", nome: janela.t("Memória", "Memory"), cor: janela.cores.mem, hist: "mem", hist2: "", max: 100,
                 sub: janela.par(m.usada, m.total) + " (" + janela.porcento(m.total > 0 ? 100 * m.usada / m.total : 0) + ")", sub2: "" });
        for (var i = 0; i < d.discos.length; i++) {
            var k = d.discos[i];
            l.push({ chave: "disco:" + k.nome, nome: janela.t("Disco ", "Disk ") + k.indice + " (" + k.nome + ")", cor: janela.cores.disco,
                     hist: "disco:" + k.nome, hist2: "", max: 100, sub: pagina.tipoDisco(k), sub2: janela.porcento(k.ativo) });
        }
        for (var j = 0; j < d.redes.length; j++) {
            var r = d.redes[j];
            l.push({ chave: "rede:" + r.nome, nome: r.wifi ? "Wi-Fi" : "Ethernet", cor: janela.cores.rede,
                     hist: "rede-r:" + r.nome, hist2: "rede-e:" + r.nome, max: 0, sub: r.nome,
                     sub2: r.ligada ? janela.t("E: ", "S: ") + janela.bits(r.env) + "  " + janela.t("R: ", "R: ") + janela.bits(r.rec)
                                    : janela.t("Desconectado", "Disconnected") });
        }
        for (var p = 0; p < d.placas.length; p++) {
            var g = d.placas[p];
            l.push({ chave: "gpu:" + p, nome: janela.t("Placa de vídeo ", "GPU ") + p, cor: janela.cores.gpu, hist: "gpu:" + p, hist2: "", max: 100,
                     sub: g.nome, sub2: (g.uso >= 0 ? janela.porcento(g.uso) : "") + (g.temp > 0 ? " (" + Math.round(g.temp) + " °C)" : "") });
        }
        return l;
    }

    function acha(chave) {
        if (!d)
            return null;
        var tipo = chave.split(":")[0];
        var nome = chave.substring(tipo.length + 1);
        var lista = tipo === "disco" ? d.discos : (tipo === "rede" ? d.redes : (tipo === "gpu" ? d.placas : []));
        for (var i = 0; i < lista.length; i++) {
            if ((tipo === "gpu" ? String(i) : lista[i].nome) === nome)
                return lista[i];
        }
        return null;
    }

    // Tudo o que o lado direito mostra da parte escolhida.
    function detalhes() {
        if (!d)
            return null;
        var c = d.cpu, m = d.memoria;
        var tipo = escolhida.split(":")[0];
        if (tipo === "mem") {
            return { titulo: janela.t("Memória", "Memory"), modelo: janela.bytes(m.total), cor: janela.cores.mem, hist: "mem", hist2: "", max: 100,
                     rotulo: janela.t("Uso da memória", "Memory usage"), teto: janela.bytes(m.total), composicao: true,
                     grandes: [
                         { r: janela.t("Em uso", "In use"), v: janela.bytes(m.usada) },
                         { r: janela.t("Disponível", "Available"), v: janela.bytes(m.disponivel) },
                         { r: janela.t("Em cache", "Cached"), v: janela.bytes(m.cache) },
                         { r: janela.t("Memória virtual", "Swap"), v: m.swap_total > 0 ? janela.par(m.swap_usada, m.swap_total) : janela.t("Sem", "None") }
                     ],
                     tabela: [
                         { r: janela.t("Total", "Total"), v: janela.bytes(m.total) },
                         { r: janela.t("Livre", "Free"), v: janela.bytes(m.livre) }
                     ] };
        }
        if (tipo === "disco") {
            var k = acha(escolhida);
            if (!k)
                return null;
            var tabela = [
                { r: janela.t("Capacidade", "Capacity"), v: janela.bytes(k.total) },
                { r: janela.t("Usado", "Used"), v: k.usado > 0 ? janela.bytes(k.usado) + " (" + janela.porcento(100 * k.usado / Math.max(1, k.total)) + ")" : "—" },
                { r: janela.t("Tipo", "Type"), v: pagina.tipoDisco(k) }
            ];
            if (k.removivel)
                tabela.push({ r: janela.t("Removível", "Removable"), v: janela.t("Sim", "Yes") });
            return { titulo: janela.t("Disco ", "Disk ") + k.indice + " (" + k.nome + ")", modelo: k.modelo || pagina.tipoDisco(k),
                     cor: janela.cores.disco, hist: "disco:" + k.nome, hist2: "", max: 100,
                     rotulo: janela.t("Tempo ativo", "Active time"), teto: "100%",
                     transferencia: { hist: "disco-l:" + k.nome, hist2: "disco-g:" + k.nome },
                     grandes: [
                         { r: janela.t("Tempo ativo", "Active time"), v: janela.porcento(k.ativo) },
                         { r: janela.t("Leitura", "Read speed"), v: janela.mbs(k.leitura) },
                         { r: janela.t("Gravação", "Write speed"), v: janela.mbs(k.gravacao) }
                     ],
                     tabela: tabela };
        }
        if (tipo === "rede") {
            var r = acha(escolhida);
            if (!r)
                return null;
            var t2 = [
                { r: janela.t("Adaptador", "Adapter"), v: r.nome },
                { r: janela.t("Tipo de conexão", "Connection type"), v: r.wifi ? "Wi-Fi" : "Ethernet" },
                { r: janela.t("Endereço IPv4", "IPv4 address"), v: r.ip || "—" },
                { r: janela.t("Situação", "Status"), v: r.ligada ? janela.t("Conectado", "Connected") : janela.t("Desconectado", "Disconnected") }
            ];
            if (r.velocidade > 0)
                t2.push({ r: janela.t("Velocidade do cabo", "Link speed"), v: janela.num(r.velocidade, 0) + " Mbps" });
            return { titulo: r.wifi ? "Wi-Fi" : "Ethernet", modelo: r.nome, cor: janela.cores.rede, hist: "rede-r:" + r.nome, hist2: "rede-e:" + r.nome,
                     max: 0, rotulo: janela.t("Recebendo (linha cheia) e enviando (tracejada)", "Receiving (solid) and sending (dashed)"), teto: "",
                     unidade: "bits",
                     grandes: [
                         { r: janela.t("Enviar", "Send"), v: janela.bits(r.env) },
                         { r: janela.t("Receber", "Receive"), v: janela.bits(r.rec) }
                     ],
                     tabela: t2 };
        }
        if (tipo === "gpu") {
            var g = acha(escolhida);
            if (!g)
                return null;
            var grandes = [];
            grandes.push({ r: janela.t("Utilização", "Utilization"), v: g.uso >= 0 ? janela.porcento(g.uso) : "—" });
            if (g.vram_total > 0)
                grandes.push({ r: janela.t("Memória da placa", "Dedicated memory"), v: janela.par(g.vram_usada, g.vram_total) });
            if (g.temp > 0)
                grandes.push({ r: janela.t("Temperatura", "Temperature"), v: Math.round(g.temp) + " °C" });
            if (g.mhz > 0)
                grandes.push({ r: janela.t("Velocidade", "Clock"), v: janela.num(g.mhz, 0) + " MHz" });
            return { titulo: janela.t("Placa de vídeo ", "GPU ") + escolhida.split(":")[1], modelo: g.nome, cor: janela.cores.gpu,
                     hist: "gpu:" + escolhida.split(":")[1], hist2: "", max: 100, rotulo: janela.t("Uso da placa", "GPU usage"), teto: "100%",
                     aviso: g.uso < 0 ? janela.t("Esta placa não informa o uso (é comum em máquina virtual).", "This GPU does not report usage (common in virtual machines).") : "",
                     grandes: grandes,
                     tabela: [{ r: janela.t("Driver", "Driver"), v: g.driver || "—" }] };
        }
        var tabelaCpu = [];
        if (c.base > 0)
            tabelaCpu.push({ r: janela.t("Velocidade base", "Base speed"), v: janela.num(c.base, 2) + " GHz" });
        tabelaCpu.push({ r: janela.t("Núcleos", "Cores"), v: String(c.nucleos) });
        tabelaCpu.push({ r: janela.t("Processadores lógicos", "Logical processors"), v: String(c.logicos) });
        if (c.virtual)
            tabelaCpu.push({ r: janela.t("Máquina virtual", "Virtual machine"), v: janela.t("Sim", "Yes") });
        var grandesCpu = [
            { r: janela.t("Utilização", "Utilization"), v: janela.porcento(c.uso) },
            { r: janela.t("Velocidade", "Speed"), v: c.ghz > 0 ? janela.num(c.ghz, 2) + " GHz" : "—" },
            { r: janela.t("Processos", "Processes"), v: janela.num(c.processos, 0) },
            { r: janela.t("Threads", "Threads"), v: janela.num(c.threads, 0) },
            { r: janela.t("Tempo ligado", "Up time"), v: janela.duracao(c.ligado) }
        ];
        if (c.temp > 0)
            grandesCpu.push({ r: janela.t("Temperatura", "Temperature"), v: c.temp + " °C" });
        return { titulo: "CPU", modelo: c.nome, cor: janela.cores.cpu, hist: "cpu", hist2: "", max: 100,
                 rotulo: janela.t("% de utilização", "% Utilization"), teto: "100%", nucleos: c.nucleos_uso,
                 grandes: grandesCpu, tabela: tabelaCpu };
    }

    readonly property var lista: { janela.tique; return partes(); }
    readonly property var info: { janela.tique; escolhida; return detalhes(); }


    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Título da página, como a barra do Windows 11.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(janela.gu * 3)
            Layout.leftMargin: Math.round(janela.gu * 1.1)
            Layout.rightMargin: Math.round(janela.gu * 0.6)

            Texto {
                Layout.fillWidth: true
                text: janela.t("Desempenho", "Performance")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Botao {
                texto: janela.t("Nova tarefa", "Run new task")
                icone: "kaelix-nova-tarefa-symbolic"
                dica: janela.t("Abre a busca do sistema para rodar um app ou comando", "Opens the system search to run an app or command")
                onClicado: kaelix.soltar(["krunner"])
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: janela.tinta(0.07)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // As partes, uma embaixo da outra, com o gráfico pequeno.
            Flickable {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.round(janela.gu * 14.5)
                contentHeight: colunaPartes.implicitHeight + janela.gu
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: colunaPartes
                    x: Math.round(janela.gu * 0.4)
                    y: Math.round(janela.gu * 0.4)
                    width: parent.width - Math.round(janela.gu * 0.8)
                    spacing: 2

                    Repeater {
                        model: pagina.lista

                        MouseArea {
                            id: parte
                            required property var modelData
                            readonly property bool ativa: pagina.escolhida === modelData.chave

                            Layout.fillWidth: true
                            implicitHeight: Math.round(janela.gu * 3.5)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            activeFocusOnTab: true
                            Accessible.role: Accessible.PageTab
                            Accessible.name: modelData.nome + ", " + modelData.sub + " " + modelData.sub2
                            onClicked: pagina.escolhida = modelData.chave
                            Keys.onReturnPressed: pagina.escolhida = modelData.chave

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.round(janela.gu * 0.3)
                                color: janela.tinta(parte.ativa ? (janela.escuro ? 0.08 : 0.065) : (parte.containsMouse || parte.activeFocus ? 0.04 : 0))
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Kirigami.Units.shortDuration
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(janela.gu * 0.5)
                                anchors.rightMargin: Math.round(janela.gu * 0.4)
                                spacing: Math.round(janela.gu * 0.65)

                                Grafico {
                                    Layout.preferredWidth: Math.round(janela.gu * 3.6)
                                    Layout.preferredHeight: Math.round(janela.gu * 2.4)
                                    mini: true
                                    cor: parte.modelData.cor
                                    valores: janela.historico[parte.modelData.hist] || []
                                    valores2: parte.modelData.hist2 ? (janela.historico[parte.modelData.hist2] || []) : []
                                    maximo: parte.modelData.max
                                    tique: janela.tique
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Texto {
                                        Layout.fillWidth: true
                                        text: parte.modelData.nome
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                                        elide: Text.ElideRight
                                    }
                                    Texto {
                                        Layout.fillWidth: true
                                        text: parte.modelData.sub
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.72
                                        elide: Text.ElideRight
                                    }
                                    Texto {
                                        Layout.fillWidth: true
                                        visible: parte.modelData.sub2.length > 0
                                        text: parte.modelData.sub2
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        font.features: { "tnum": 1 }
                                        opacity: 0.72
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 1
                color: janela.tinta(0.07)
            }

            // A parte escolhida.
            Flickable {
                id: rolagem
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: corpo.implicitHeight + janela.gu * 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                ColumnLayout {
                    id: corpo
                    x: Math.round(janela.gu * 1.3)
                    y: Math.round(janela.gu * 0.9)
                    width: rolagem.width - Math.round(janela.gu * 2.6)
                    spacing: Math.round(janela.gu * 0.35)
                    visible: pagina.info !== null

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: janela.gu
                        Texto {
                            text: pagina.info ? pagina.info.titulo : ""
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 9
                            font.weight: Font.Medium
                        }
                        Texto {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 4
                            horizontalAlignment: Text.AlignRight
                            text: pagina.info ? pagina.info.modelo : ""
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                            opacity: 0.9
                            elide: Text.ElideLeft
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Math.round(janela.gu * 0.4)
                        Texto {
                            Layout.fillWidth: true
                            text: pagina.info ? pagina.info.rotulo : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.72
                            elide: Text.ElideRight
                        }
                        Texto {
                            text: {
                                if (!pagina.info)
                                    return "";
                                if (pagina.info.max > 0)
                                    return pagina.info.teto;
                                return pagina.info.unidade === "bits" ? janela.bits(grande.escala) : janela.mbs(grande.escala);
                            }
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.72
                        }
                    }
                    Grafico {
                        id: grande
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(janela.gu * (pagina.info && pagina.info.transferencia ? 9 : 12))
                        cor: pagina.info ? pagina.info.cor : "gray"
                        valores: pagina.info ? (janela.historico[pagina.info.hist] || []) : []
                        valores2: pagina.info && pagina.info.hist2 ? (janela.historico[pagina.info.hist2] || []) : []
                        maximo: pagina.info ? pagina.info.max : 100
                        tique: janela.tique
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Texto {
                            Layout.fillWidth: true
                            text: janela.t("60 segundos", "60 seconds")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                        }
                        Texto {
                            text: "0"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                        }
                    }

                    Texto {
                        Layout.fillWidth: true
                        visible: pagina.info !== null && (pagina.info.aviso || "").length > 0
                        text: pagina.info ? (pagina.info.aviso || "") : ""
                        wrapMode: Text.WordWrap
                        opacity: 0.72
                    }

                    // Disco: velocidade de leitura (cheia) e gravação (tracejada).
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: pagina.info !== null && pagina.info.transferencia !== undefined
                        spacing: 3
                        RowLayout {
                            Layout.fillWidth: true
                            Texto {
                                Layout.fillWidth: true
                                text: janela.t("Velocidade de leitura (cheia) e gravação (tracejada)", "Read (solid) and write (dashed) speed")
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.72
                                elide: Text.ElideRight
                            }
                            Texto {
                                text: janela.mbs(transferencia.escala)
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.72
                            }
                        }
                        Grafico {
                            id: transferencia
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(janela.gu * 4.5)
                            cor: janela.cores.disco
                            maximo: 0
                            valores: pagina.info && pagina.info.transferencia ? (janela.historico[pagina.info.transferencia.hist] || []) : []
                            valores2: pagina.info && pagina.info.transferencia ? (janela.historico[pagina.info.transferencia.hist2] || []) : []
                            tique: janela.tique
                        }
                    }

                    // CPU: cada processador lógico numa barrinha.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Math.round(janela.gu * 0.3)
                        visible: pagina.info !== null && pagina.info.nucleos !== undefined && pagina.info.nucleos.length > 1
                        spacing: 4
                        Texto {
                            text: janela.t("Cada processador lógico", "Each logical processor")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.72
                        }
                        Row {
                            Layout.fillWidth: true
                            spacing: 3
                            Repeater {
                                model: pagina.info && pagina.info.nucleos ? pagina.info.nucleos : []
                                Rectangle {
                                    id: barra
                                    required property var modelData
                                    readonly property int total: pagina.info && pagina.info.nucleos ? pagina.info.nucleos.length : 1
                                    width: Math.max(4, (corpo.width - (total - 1) * 3) / total)
                                    height: Math.round(janela.gu * 1.4)
                                    radius: 3
                                    color: janela.tinta(0.06)
                                    border.width: 1
                                    border.color: janela.tinta(0.1)
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 1
                                        height: Math.max(2, (parent.height - 2) * Math.min(1, barra.modelData / 100))
                                        radius: 2
                                        color: janela.cores.cpu
                                        opacity: 0.85
                                        Behavior on height {
                                            NumberAnimation {
                                                duration: Kirigami.Units.longDuration
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Memória: em uso, em cache e livre numa barra só.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Math.round(janela.gu * 0.3)
                        visible: pagina.info !== null && pagina.info.composicao === true
                        spacing: 4
                        Texto {
                            text: janela.t("Como a memória está dividida", "Memory composition")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.72
                        }
                        Rectangle {
                            id: comp
                            Layout.fillWidth: true
                            implicitHeight: Math.round(janela.gu * 1.4)
                            radius: 4
                            color: janela.tinta(0.06)
                            border.width: 1
                            border.color: janela.tinta(0.1)
                            clip: true
                            readonly property var m: pagina.d ? pagina.d.memoria : null
                            Row {
                                anchors.fill: parent
                                anchors.margins: 1
                                Rectangle {
                                    height: parent.height
                                    width: comp.m && comp.m.total > 0 ? parent.width * comp.m.usada / comp.m.total : 0
                                    color: janela.cores.mem
                                    opacity: 0.85
                                }
                                Rectangle {
                                    height: parent.height
                                    width: comp.m && comp.m.total > 0 ? parent.width * Math.min(comp.m.cache, comp.m.total - comp.m.usada) / comp.m.total : 0
                                    color: janela.cores.mem
                                    opacity: 0.35
                                }
                            }
                        }
                        RowLayout {
                            spacing: janela.gu
                            Repeater {
                                model: [
                                    { n: janela.t("Em uso", "In use"), o: 0.85 },
                                    { n: janela.t("Em cache", "Cached"), o: 0.35 },
                                    { n: janela.t("Livre", "Free"), o: 0 }
                                ]
                                RowLayout {
                                    id: legenda
                                    required property var modelData
                                    spacing: 5
                                    Rectangle {
                                        implicitWidth: 10
                                        implicitHeight: 10
                                        radius: 3
                                        color: legenda.modelData.o > 0 ? janela.cores.mem : janela.tinta(0.12)
                                        opacity: legenda.modelData.o > 0 ? legenda.modelData.o : 1
                                    }
                                    Texto {
                                        text: legenda.modelData.n
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.75
                                    }
                                }
                            }
                        }
                    }

                    // Os números grandes (como no Windows) e a tabela ao lado.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Math.round(janela.gu * 0.6)
                        spacing: Math.round(janela.gu * 1.6)

                        GridLayout {
                            Layout.alignment: Qt.AlignTop
                            columns: 3
                            columnSpacing: Math.round(janela.gu * 1.4)
                            rowSpacing: Math.round(janela.gu * 0.55)

                            Repeater {
                                model: pagina.info ? pagina.info.grandes : []
                                ColumnLayout {
                                    id: numero
                                    required property var modelData
                                    spacing: 0
                                    Texto {
                                        text: numero.modelData.r
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.72
                                    }
                                    Texto {
                                        text: numero.modelData.v
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 5
                                        font.features: { "tnum": 1 }
                                    }
                                }
                            }
                        }

                        GridLayout {
                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: janela.gu
                            rowSpacing: Math.round(janela.gu * 0.25)

                            Repeater {
                                model: pagina.info ? pagina.info.tabela : []
                                Texto {
                                    required property var modelData
                                    required property int index
                                    Layout.row: index
                                    Layout.column: 0
                                    text: modelData.r + ":"
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
                                    opacity: 0.72
                                }
                            }
                            Repeater {
                                model: pagina.info ? pagina.info.tabela : []
                                Texto {
                                    required property var modelData
                                    required property int index
                                    Layout.row: index
                                    Layout.column: 1
                                    Layout.fillWidth: true
                                    text: modelData.v
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                QQC2.BusyIndicator {
                    anchors.centerIn: parent
                    visible: pagina.d === null
                    running: visible
                }
            }
        }
    }
}
