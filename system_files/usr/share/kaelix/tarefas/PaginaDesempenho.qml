// Desempenho, como no Windows: à esquerda cada parte do computador com um
// gráfico pequeno (CPU, memória, discos, rede, placa de vídeo); à direita a
// parte escolhida, com o gráfico do último minuto e os números dela.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: pagina

    property string escolhida: "cpu"
    readonly property var d: tarefas.dados

    function tipoDisco(k) {
        switch (k.tipo) {
        case "nvme":
            return "SSD (NVMe)";
        case "ssd":
            return "SSD";
        case "hd":
            return tarefas.t("HD", "HDD");
        case "virtual":
            return tarefas.t("Disco virtual", "Virtual disk");
        }
        return "";
    }

    function partes() {
        var l = [];
        if (!d)
            return l;
        l.push({ chave: "cpu", nome: "CPU", cor: tarefas.cores.cpu, hist: "cpu", hist2: "", max: 100,
                 sub: tarefas.porcento(d.cpu.uso) + (d.cpu.ghz > 0 ? "  " + tarefas.num(d.cpu.ghz, 2) + " GHz" : ""), sub2: "" });
        var m = d.memoria;
        l.push({ chave: "mem", nome: tarefas.t("Memória", "Memory"), cor: tarefas.cores.mem, hist: "mem", hist2: "", max: 100,
                 sub: tarefas.par(m.usada, m.total) + " (" + tarefas.porcento(m.total > 0 ? 100 * m.usada / m.total : 0) + ")", sub2: "" });
        for (var i = 0; i < d.discos.length; i++) {
            var k = d.discos[i];
            l.push({ chave: "disco:" + k.nome, nome: tarefas.t("Disco ", "Disk ") + k.indice + " (" + k.nome + ")", cor: tarefas.cores.disco,
                     hist: "disco:" + k.nome, hist2: "", max: 100, sub: pagina.tipoDisco(k), sub2: tarefas.porcento(k.ativo) });
        }
        for (var j = 0; j < d.redes.length; j++) {
            var r = d.redes[j];
            l.push({ chave: "rede:" + r.nome, nome: r.wifi ? "Wi-Fi" : "Ethernet", cor: tarefas.cores.rede,
                     hist: "rede-r:" + r.nome, hist2: "rede-e:" + r.nome, max: 0, sub: r.nome,
                     sub2: r.ligada ? tarefas.t("E: ", "S: ") + tarefas.bits(r.env) + "  " + tarefas.t("R: ", "R: ") + tarefas.bits(r.rec)
                                    : tarefas.t("Desconectado", "Disconnected") });
        }
        for (var p = 0; p < d.placas.length; p++) {
            var g = d.placas[p];
            l.push({ chave: "gpu:" + p, nome: tarefas.t("Placa de vídeo ", "GPU ") + p, cor: tarefas.cores.gpu, hist: "gpu:" + p, hist2: "", max: 100,
                     sub: g.nome, sub2: (g.uso >= 0 ? tarefas.porcento(g.uso) : "") + (g.temp > 0 ? " (" + Math.round(g.temp) + " °C)" : "") });
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
            return { titulo: tarefas.t("Memória", "Memory"), modelo: tarefas.bytes(m.total), cor: tarefas.cores.mem, hist: "mem", hist2: "", max: 100,
                     rotulo: tarefas.t("Uso da memória", "Memory usage"), teto: tarefas.bytes(m.total), composicao: true,
                     grandes: [
                         { r: tarefas.t("Em uso", "In use"), v: tarefas.bytes(m.usada) },
                         { r: tarefas.t("Disponível", "Available"), v: tarefas.bytes(m.disponivel) },
                         { r: tarefas.t("Em cache", "Cached"), v: tarefas.bytes(m.cache) },
                         { r: tarefas.t("Memória virtual", "Swap"), v: m.swap_total > 0 ? tarefas.par(m.swap_usada, m.swap_total) : tarefas.t("Sem", "None") }
                     ],
                     tabela: [
                         { r: tarefas.t("Total", "Total"), v: tarefas.bytes(m.total) },
                         { r: tarefas.t("Livre", "Free"), v: tarefas.bytes(m.livre) }
                     ] };
        }
        if (tipo === "disco") {
            var k = acha(escolhida);
            if (!k)
                return null;
            var tabela = [
                { r: tarefas.t("Capacidade", "Capacity"), v: tarefas.bytes(k.total) },
                { r: tarefas.t("Usado", "Used"), v: k.usado > 0 ? tarefas.bytes(k.usado) + " (" + tarefas.porcento(100 * k.usado / Math.max(1, k.total)) + ")" : "—" },
                { r: tarefas.t("Tipo", "Type"), v: pagina.tipoDisco(k) }
            ];
            if (k.removivel)
                tabela.push({ r: tarefas.t("Removível", "Removable"), v: tarefas.t("Sim", "Yes") });
            return { titulo: tarefas.t("Disco ", "Disk ") + k.indice + " (" + k.nome + ")", modelo: k.modelo || pagina.tipoDisco(k),
                     cor: tarefas.cores.disco, hist: "disco:" + k.nome, hist2: "", max: 100,
                     rotulo: tarefas.t("Tempo ativo", "Active time"), teto: "100%",
                     transferencia: { hist: "disco-l:" + k.nome, hist2: "disco-g:" + k.nome },
                     grandes: [
                         { r: tarefas.t("Tempo ativo", "Active time"), v: tarefas.porcento(k.ativo) },
                         { r: tarefas.t("Leitura", "Read speed"), v: tarefas.mbs(k.leitura) },
                         { r: tarefas.t("Gravação", "Write speed"), v: tarefas.mbs(k.gravacao) }
                     ],
                     tabela: tabela };
        }
        if (tipo === "rede") {
            var r = acha(escolhida);
            if (!r)
                return null;
            var t2 = [
                { r: tarefas.t("Adaptador", "Adapter"), v: r.nome },
                { r: tarefas.t("Tipo de conexão", "Connection type"), v: r.wifi ? "Wi-Fi" : "Ethernet" },
                { r: tarefas.t("Endereço IPv4", "IPv4 address"), v: r.ip || "—" },
                { r: tarefas.t("Situação", "Status"), v: r.ligada ? tarefas.t("Conectado", "Connected") : tarefas.t("Desconectado", "Disconnected") }
            ];
            if (r.velocidade > 0)
                t2.push({ r: tarefas.t("Velocidade do cabo", "Link speed"), v: tarefas.num(r.velocidade, 0) + " Mbps" });
            return { titulo: r.wifi ? "Wi-Fi" : "Ethernet", modelo: r.nome, cor: tarefas.cores.rede, hist: "rede-r:" + r.nome, hist2: "rede-e:" + r.nome,
                     max: 0, rotulo: tarefas.t("Recebendo (linha cheia) e enviando (tracejada)", "Receiving (solid) and sending (dashed)"), teto: "",
                     unidade: "bits",
                     grandes: [
                         { r: tarefas.t("Enviar", "Send"), v: tarefas.bits(r.env) },
                         { r: tarefas.t("Receber", "Receive"), v: tarefas.bits(r.rec) }
                     ],
                     tabela: t2 };
        }
        if (tipo === "gpu") {
            var g = acha(escolhida);
            if (!g)
                return null;
            var grandes = [];
            grandes.push({ r: tarefas.t("Utilização", "Utilization"), v: g.uso >= 0 ? tarefas.porcento(g.uso) : "—" });
            if (g.vram_total > 0)
                grandes.push({ r: tarefas.t("Memória da placa", "Dedicated memory"), v: tarefas.par(g.vram_usada, g.vram_total) });
            if (g.temp > 0)
                grandes.push({ r: tarefas.t("Temperatura", "Temperature"), v: Math.round(g.temp) + " °C" });
            if (g.mhz > 0)
                grandes.push({ r: tarefas.t("Velocidade", "Clock"), v: tarefas.num(g.mhz, 0) + " MHz" });
            return { titulo: tarefas.t("Placa de vídeo ", "GPU ") + escolhida.split(":")[1], modelo: g.nome, cor: tarefas.cores.gpu,
                     hist: "gpu:" + escolhida.split(":")[1], hist2: "", max: 100, rotulo: tarefas.t("Uso da placa", "GPU usage"), teto: "100%",
                     aviso: g.uso < 0 ? tarefas.t("Esta placa não informa o uso (é comum em máquina virtual).", "This GPU does not report usage (common in virtual machines).") : "",
                     grandes: grandes,
                     tabela: [{ r: tarefas.t("Driver", "Driver"), v: g.driver || "—" }] };
        }
        var tabelaCpu = [];
        if (c.base > 0)
            tabelaCpu.push({ r: tarefas.t("Velocidade base", "Base speed"), v: tarefas.num(c.base, 2) + " GHz" });
        tabelaCpu.push({ r: tarefas.t("Núcleos", "Cores"), v: String(c.nucleos) });
        tabelaCpu.push({ r: tarefas.t("Processadores lógicos", "Logical processors"), v: String(c.logicos) });
        if (c.virtual)
            tabelaCpu.push({ r: tarefas.t("Máquina virtual", "Virtual machine"), v: tarefas.t("Sim", "Yes") });
        var grandesCpu = [
            { r: tarefas.t("Utilização", "Utilization"), v: tarefas.porcento(c.uso) },
            { r: tarefas.t("Velocidade", "Speed"), v: c.ghz > 0 ? tarefas.num(c.ghz, 2) + " GHz" : "—" },
            { r: tarefas.t("Processos", "Processes"), v: tarefas.num(c.processos, 0) },
            { r: tarefas.t("Threads", "Threads"), v: tarefas.num(c.threads, 0) },
            { r: tarefas.t("Tempo ligado", "Up time"), v: tarefas.duracao(c.ligado) }
        ];
        if (c.temp > 0)
            grandesCpu.push({ r: tarefas.t("Temperatura", "Temperature"), v: c.temp + " °C" });
        return { titulo: "CPU", modelo: c.nome, cor: tarefas.cores.cpu, hist: "cpu", hist2: "", max: 100,
                 rotulo: tarefas.t("% de utilização", "% Utilization"), teto: "100%", nucleos: c.nucleos_uso,
                 grandes: grandesCpu, tabela: tabelaCpu };
    }

    readonly property var lista: { tarefas.tique; return partes(); }
    readonly property var info: { tarefas.tique; escolhida; return detalhes(); }


    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Título da página, como a barra do Windows 11.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(tarefas.gu * 3)
            Layout.leftMargin: Math.round(tarefas.gu * 1.1)
            Layout.rightMargin: Math.round(tarefas.gu * 0.6)

            Texto {
                Layout.fillWidth: true
                text: tarefas.t("Desempenho", "Performance")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Botao {
                texto: tarefas.t("Nova tarefa", "Run new task")
                icone: "kaelix-nova-tarefa-symbolic"
                dica: tarefas.t("Abre a busca do sistema para rodar um app ou comando", "Opens the system search to run an app or command")
                onClicado: kaelix.soltar(["krunner"])
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: tarefas.tinta(0.07)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // As partes, uma embaixo da outra, com o gráfico pequeno.
            Flickable {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.round(tarefas.gu * 14.5)
                contentHeight: colunaPartes.implicitHeight + tarefas.gu
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: colunaPartes
                    x: Math.round(tarefas.gu * 0.4)
                    y: Math.round(tarefas.gu * 0.4)
                    width: parent.width - Math.round(tarefas.gu * 0.8)
                    spacing: 2

                    Repeater {
                        model: pagina.lista

                        MouseArea {
                            id: parte
                            required property var modelData
                            readonly property bool ativa: pagina.escolhida === modelData.chave

                            Layout.fillWidth: true
                            implicitHeight: Math.round(tarefas.gu * 3.5)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            activeFocusOnTab: true
                            Accessible.role: Accessible.PageTab
                            Accessible.name: modelData.nome + ", " + modelData.sub + " " + modelData.sub2
                            onClicked: pagina.escolhida = modelData.chave
                            Keys.onReturnPressed: pagina.escolhida = modelData.chave

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.round(tarefas.gu * 0.3)
                                color: tarefas.tinta(parte.ativa ? (tarefas.escuro ? 0.08 : 0.065) : (parte.containsMouse || parte.activeFocus ? 0.04 : 0))
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Kirigami.Units.shortDuration
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(tarefas.gu * 0.5)
                                anchors.rightMargin: Math.round(tarefas.gu * 0.4)
                                spacing: Math.round(tarefas.gu * 0.65)

                                Grafico {
                                    Layout.preferredWidth: Math.round(tarefas.gu * 3.6)
                                    Layout.preferredHeight: Math.round(tarefas.gu * 2.4)
                                    mini: true
                                    cor: parte.modelData.cor
                                    valores: tarefas.historico[parte.modelData.hist] || []
                                    valores2: parte.modelData.hist2 ? (tarefas.historico[parte.modelData.hist2] || []) : []
                                    maximo: parte.modelData.max
                                    tique: tarefas.tique
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
                color: tarefas.tinta(0.07)
            }

            // A parte escolhida.
            Flickable {
                id: rolagem
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: corpo.implicitHeight + tarefas.gu * 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                ColumnLayout {
                    id: corpo
                    x: Math.round(tarefas.gu * 1.3)
                    y: Math.round(tarefas.gu * 0.9)
                    width: rolagem.width - Math.round(tarefas.gu * 2.6)
                    spacing: Math.round(tarefas.gu * 0.35)
                    visible: pagina.info !== null

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: tarefas.gu
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
                        Layout.topMargin: Math.round(tarefas.gu * 0.4)
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
                                return pagina.info.unidade === "bits" ? tarefas.bits(grande.escala) : tarefas.mbs(grande.escala);
                            }
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.72
                        }
                    }
                    Grafico {
                        id: grande
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(tarefas.gu * (pagina.info && pagina.info.transferencia ? 9 : 12))
                        cor: pagina.info ? pagina.info.cor : "gray"
                        valores: pagina.info ? (tarefas.historico[pagina.info.hist] || []) : []
                        valores2: pagina.info && pagina.info.hist2 ? (tarefas.historico[pagina.info.hist2] || []) : []
                        maximo: pagina.info ? pagina.info.max : 100
                        tique: tarefas.tique
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Texto {
                            Layout.fillWidth: true
                            text: tarefas.t("60 segundos", "60 seconds")
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
                                text: tarefas.t("Velocidade de leitura (cheia) e gravação (tracejada)", "Read (solid) and write (dashed) speed")
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.72
                                elide: Text.ElideRight
                            }
                            Texto {
                                text: tarefas.mbs(transferencia.escala)
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.72
                            }
                        }
                        Grafico {
                            id: transferencia
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(tarefas.gu * 4.5)
                            cor: tarefas.cores.disco
                            maximo: 0
                            valores: pagina.info && pagina.info.transferencia ? (tarefas.historico[pagina.info.transferencia.hist] || []) : []
                            valores2: pagina.info && pagina.info.transferencia ? (tarefas.historico[pagina.info.transferencia.hist2] || []) : []
                            tique: tarefas.tique
                        }
                    }

                    // CPU: cada processador lógico numa barrinha.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Math.round(tarefas.gu * 0.3)
                        visible: pagina.info !== null && pagina.info.nucleos !== undefined && pagina.info.nucleos.length > 1
                        spacing: 4
                        Texto {
                            text: tarefas.t("Cada processador lógico", "Each logical processor")
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
                                    height: Math.round(tarefas.gu * 1.4)
                                    radius: 3
                                    color: tarefas.tinta(0.06)
                                    border.width: 1
                                    border.color: tarefas.tinta(0.1)
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 1
                                        height: Math.max(2, (parent.height - 2) * Math.min(1, barra.modelData / 100))
                                        radius: 2
                                        color: tarefas.cores.cpu
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
                        Layout.topMargin: Math.round(tarefas.gu * 0.3)
                        visible: pagina.info !== null && pagina.info.composicao === true
                        spacing: 4
                        Texto {
                            text: tarefas.t("Como a memória está dividida", "Memory composition")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.72
                        }
                        Rectangle {
                            id: comp
                            Layout.fillWidth: true
                            implicitHeight: Math.round(tarefas.gu * 1.4)
                            radius: 4
                            color: tarefas.tinta(0.06)
                            border.width: 1
                            border.color: tarefas.tinta(0.1)
                            clip: true
                            readonly property var m: pagina.d ? pagina.d.memoria : null
                            Row {
                                anchors.fill: parent
                                anchors.margins: 1
                                Rectangle {
                                    height: parent.height
                                    width: comp.m && comp.m.total > 0 ? parent.width * comp.m.usada / comp.m.total : 0
                                    color: tarefas.cores.mem
                                    opacity: 0.85
                                }
                                Rectangle {
                                    height: parent.height
                                    width: comp.m && comp.m.total > 0 ? parent.width * Math.min(comp.m.cache, comp.m.total - comp.m.usada) / comp.m.total : 0
                                    color: tarefas.cores.mem
                                    opacity: 0.35
                                }
                            }
                        }
                        RowLayout {
                            spacing: tarefas.gu
                            Repeater {
                                model: [
                                    { n: tarefas.t("Em uso", "In use"), o: 0.85 },
                                    { n: tarefas.t("Em cache", "Cached"), o: 0.35 },
                                    { n: tarefas.t("Livre", "Free"), o: 0 }
                                ]
                                RowLayout {
                                    id: legenda
                                    required property var modelData
                                    spacing: 5
                                    Rectangle {
                                        implicitWidth: 10
                                        implicitHeight: 10
                                        radius: 3
                                        color: legenda.modelData.o > 0 ? tarefas.cores.mem : tarefas.tinta(0.12)
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
                        Layout.topMargin: Math.round(tarefas.gu * 0.6)
                        spacing: Math.round(tarefas.gu * 1.6)

                        GridLayout {
                            Layout.alignment: Qt.AlignTop
                            columns: 3
                            columnSpacing: Math.round(tarefas.gu * 1.4)
                            rowSpacing: Math.round(tarefas.gu * 0.55)

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
                            columnSpacing: tarefas.gu
                            rowSpacing: Math.round(tarefas.gu * 0.25)

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
