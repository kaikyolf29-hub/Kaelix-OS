// Sobreposição no jogo: FPS, GPU, CPU, memória e o que a pessoa escolher, em
// cima do jogo, no visual do Matsu (o MangoHud por baixo). Em cima, uma prévia
// com os números deste computador; clicar nela muda o canto.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Flickable {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.4)
    readonly property var s: janela.conf ? janela.conf.sobreposicao
                                         : ({ ligada: false, itens: ["fps", "fps_baixo", "grafico", "nomes", "gpu", "vram", "cpu", "ram", "temperatura"],
                                            posicao: "top-left", tamanho: "medio", compacta: false, fundo: "escuro" })
    function tem(item) {
        return s.itens.indexOf(item) >= 0;
    }
    function trocarItem(item) {
        var lista = s.itens.slice();
        var i = lista.indexOf(item);
        if (i >= 0)
            lista.splice(i, 1);
        else
            lista.push(item);
        janela.mudar("sobreposicao.itens", lista);
    }
    readonly property var nomesPosicao: ({ "top-left": janela.t("Em cima, à esquerda", "Top left"), "top-center": janela.t("Em cima, no meio", "Top center"),
                                          "top-right": janela.t("Em cima, à direita", "Top right"), "bottom-left": janela.t("Embaixo, à esquerda", "Bottom left"),
                                          "bottom-right": janela.t("Embaixo, à direita", "Bottom right") })

    contentHeight: coluna.implicitHeight + 2 * margem
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: BarraRolagem {}

    ColumnLayout {
        id: coluna
        x: pagina.margem
        y: pagina.margem
        width: pagina.width - 2 * pagina.margem
        spacing: Math.round(janela.gu * 0.5)

        Texto {
            text: janela.t("Sobreposição no jogo", "In-game overlay")
            font.pixelSize: Math.round(janela.gu * 1.3)
            font.weight: Font.DemiBold
        }
        Texto {
            Layout.fillWidth: true
            text: janela.t("Os números do computador em cima do jogo, no visual do Matsu. Só aparece com um jogo aberto.",
                           "Your computer's numbers on top of the game, in Matsu style. Only shows while a game is open.")
            wrapMode: Text.WordWrap
            opacity: 0.65
        }

        // ----- a chave grande: liga e desliga (a mesma da Central de controle e do atalho) -----
        MouseArea {
            id: heroi
            readonly property bool ligada: pagina.s.ligada
            readonly property color cor: janela.corPerfil("padrao")
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.6)
            implicitHeight: linhaHeroi.implicitHeight + Math.round(janela.gu * 1.8)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: janela.ligarFps(!ligada)
            Accessible.role: Accessible.CheckBox
            Accessible.checkable: true
            Accessible.checked: ligada
            Accessible.name: janela.t("FPS no jogo", "In-game FPS")

            Rectangle {
                anchors.fill: parent
                radius: Math.round(janela.gu * 0.6)
                color: heroi.ligada ? Qt.rgba(heroi.cor.r, heroi.cor.g, heroi.cor.b, janela.escuro ? 0.12 : 0.09)
                                    : (heroi.containsMouse ? Qt.rgba(janela.cartao.r, janela.cartao.g, janela.cartao.b, Math.min(1, janela.cartao.a * 1.6)) : janela.cartao)
                border.width: 1
                border.color: heroi.ligada ? Qt.rgba(heroi.cor.r, heroi.cor.g, heroi.cor.b, 0.45) : janela.bordaCartao
                Behavior on color {
                    ColorAnimation { duration: Kirigami.Units.longDuration }
                }
            }
            RowLayout {
                id: linhaHeroi
                anchors.fill: parent
                anchors.margins: Math.round(janela.gu * 0.9)
                spacing: Math.round(janela.gu * 0.9)

                Rectangle {
                    Layout.preferredWidth: Math.round(janela.gu * 3.2)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: heroi.ligada ? heroi.cor : janela.tinta(0.07)
                    Behavior on color {
                        ColorAnimation { duration: Kirigami.Units.longDuration }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.smallMedium
                        height: width
                        source: "matsu-sobreposicao-symbolic"
                        isMask: true
                        color: heroi.ligada ? ((0.299 * heroi.cor.r + 0.587 * heroi.cor.g + 0.114 * heroi.cor.b) > 0.6 ? "#141416" : "#ffffff") : janela.frente
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.25)
                    Texto {
                        text: janela.t("FPS no jogo", "In-game FPS")
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 3
                        font.weight: Font.DemiBold
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: heroi.ligada ? (janela.jogoAgora ? janela.t("Ligado: aparecendo em ", "On: showing in ") + janela.jogoAgora.nome
                                                               : janela.t("Ligado: aparece quando um jogo abrir", "On: shows when a game opens"))
                                           : janela.t("Desligado", "Off")
                        wrapMode: Text.WordWrap
                        opacity: 0.72
                    }
                    // O atalho, com as teclas desenhadas.
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: Math.round(janela.gu * 0.2)
                        spacing: 6
                        Texto {
                            height: Math.round(janela.gu * 1.45)
                            verticalAlignment: Text.AlignVCenter
                            text: janela.t("No jogo:", "In game:")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.65
                        }
                        Repeater {
                            model: janela.teclasAtalho
                            Row {
                                required property string modelData
                                required property int index
                                spacing: 6
                                Texto {
                                    visible: parent.index > 0
                                    height: Math.round(janela.gu * 1.45)
                                    verticalAlignment: Text.AlignVCenter
                                    text: "+"
                                    opacity: 0.5
                                }
                                Rectangle {
                                    width: Math.max(Math.round(janela.gu * 1.45), tecla.implicitWidth + Math.round(janela.gu * 0.8))
                                    height: Math.round(janela.gu * 1.45)
                                    radius: 5
                                    color: janela.tinta(janela.escuro ? 0.09 : 0.05)
                                    border.width: 1
                                    border.color: janela.tinta(0.18)
                                    // A borda de baixo mais grossa, como uma tecla.
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 1
                                        height: 2
                                        radius: 1
                                        color: janela.tinta(0.14)
                                    }
                                    Texto {
                                        id: tecla
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -1
                                        text: parent.parent.modelData
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                        Texto {
                            height: Math.round(janela.gu * 1.45)
                            verticalAlignment: Text.AlignVCenter
                            text: janela.t("liga e desliga, e a Central de controle tem o botão também.", "turns it on and off; the Control Center has the button too.")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.65
                        }
                    }
                }
                // A chave em tamanho grande.
                Item {
                    Layout.preferredWidth: Math.round(chaveGrande.implicitWidth * 1.5)
                    Layout.preferredHeight: Math.round(chaveGrande.implicitHeight * 1.5)
                    Chave {
                        id: chaveGrande
                        anchors.centerIn: parent
                        scale: 1.5
                        ligada: heroi.ligada
                        nome: janela.t("FPS no jogo", "In-game FPS")
                        onTrocada: (ligada) => janela.ligarFps(ligada)
                    }
                }
            }
        }

        // ----- prévia: um jogo de fundo e a sobreposição em cima -----
        Item {
            id: tela
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.6)
            Layout.preferredHeight: Math.round(Math.min(width * 9 / 16, janela.gu * 17))
            readonly property var jogo: janela.jogos.length > 0 ? janela.jogos[0] : null
            // A letra da prévia acompanha o tamanho escolhido (proporcional a uma tela cheia).
            readonly property real letra: ({ pequeno: 18, medio: 22, grande: 27 })[pagina.s.tamanho] * height / 560

            Rectangle {
                anchors.fill: parent
                radius: Math.round(janela.gu * 0.6)
                visible: fundoJogo.status !== Image.Ready
                gradient: Gradient {
                    GradientStop { position: 0; color: "#33406e" }
                    GradientStop { position: 0.55; color: "#a0507a" }
                    GradientStop { position: 1; color: "#f2a65a" }
                }
                // Um morro e um sol, para parecer uma cena de jogo.
                Rectangle {
                    x: parent.width * 0.68
                    y: parent.height * 0.22
                    width: parent.height * 0.22
                    height: width
                    radius: width / 2
                    color: "#ffd9a0"
                    opacity: 0.9
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * 0.3
                    bottomLeftRadius: parent.radius
                    bottomRightRadius: parent.radius
                    color: "#2b2440"
                }
            }
            ImagemRedonda {
                id: fundoJogo
                anchors.fill: parent
                raio: Math.round(janela.gu * 0.6)
                source: tela.jogo && tela.jogo.heroi ? janela.arquivo(tela.jogo.heroi) : ""
                sombra: 0.4
            }
            Rectangle {
                anchors.fill: parent
                radius: Math.round(janela.gu * 0.6)
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.14)
            }
            // Desligada: a prévia fica apagada, com o aviso no meio.
            Rectangle {
                anchors.fill: parent
                radius: Math.round(janela.gu * 0.6)
                color: Qt.rgba(0, 0, 0, pagina.s.ligada ? 0 : 0.45)
                Behavior on color {
                    ColorAnimation {
                        duration: Kirigami.Units.longDuration
                    }
                }
            }

            // Os cantos onde ela pode ficar (aparecem com o mouse em cima).
            MouseArea {
                id: areaTela
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (m) => {
                    var direita = m.x > width * 0.62;
                    var esquerda = m.x < width * 0.38;
                    var p = m.y < height / 2 ? (esquerda ? "top-left" : (direita ? "top-right" : "top-center"))
                                             : (direita ? "bottom-right" : "bottom-left");
                    janela.mudar("sobreposicao.posicao", p);
                }
            }
            Repeater {
                model: ["top-left", "top-center", "top-right", "bottom-left", "bottom-right"]
                Rectangle {
                    required property string modelData
                    readonly property real m: Math.round(janela.gu * 0.6)
                    visible: areaTela.containsMouse && modelData !== pagina.s.posicao
                    width: hud.width
                    height: hud.height
                    x: modelData.indexOf("left") >= 0 ? m : (modelData.indexOf("right") >= 0 ? tela.width - width - m : (tela.width - width) / 2)
                    y: modelData.indexOf("top") === 0 ? m : tela.height - height - m
                    radius: hud.radius
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.45)
                }
            }

            // A sobreposição de mentira, desenhada como o MangoHud desenha (três colunas:
            // o nome à esquerda e os números descendo em duas colunas), com as cores das
            // partes do Matsu. Os números da placa, do processador e da memória são deste
            // computador; o FPS é de exemplo.
            Rectangle {
                id: hud
                readonly property real m: Math.round(janela.gu * 0.6)
                readonly property string p: pagina.s.posicao
                readonly property bool linha: pagina.s.compacta
                readonly property real l: tela.letra
                readonly property real pequena: l * 0.55
                readonly property real secundaria: l * 0.7
                readonly property real pad: l * 0.3
                readonly property real alturaLinha: l * 1.32
                // Só o FPS: a pílula estreita, como no jogo (ajudante.py, width).
                readonly property bool soFps: !pagina.tem("grafico") && !mostraGpu && !mostraCpu && !pagina.tem("vram") && !pagina.tem("ram")
                readonly property real largura: l * (soFps ? 11.5 : 13.8)
                readonly property real coluna: (largura - 2 * pad) / 3
                readonly property real alinhar: l * 2.7   // o MangoHud alinha os números pela direita em 4 letras
                readonly property bool mostraGpu: pagina.tem("gpu") || pagina.tem("temperatura") || pagina.tem("frequencia") || pagina.tem("consumo") || pagina.tem("ventoinha")
                readonly property bool watsCpu: janela.dados && janela.dados.pc ? janela.dados.pc.cpu_watts : false
                readonly property bool mostraCpu: pagina.tem("cpu") || pagina.tem("temperatura") || pagina.tem("frequencia") || (pagina.tem("consumo") && watsCpu)
                readonly property bool nomes: pagina.tem("nomes") && !linha
                // No jogo é o nome da API do jogo aberto (DX12, DX11, DX9, VULKAN, OpenGL).
                readonly property string api: "DX12"

                visible: pagina.s.itens.length > 0
                x: p.indexOf("left") >= 0 ? m : (p.indexOf("right") >= 0 ? tela.width - width - m : (tela.width - width) / 2)
                y: p.indexOf("top") === 0 ? m : tela.height - height - m
                width: linha ? emLinha.implicitWidth + 2 * l * 0.45 : largura
                height: linha ? l * 1.6 : emPe.implicitHeight + 2 * pad
                radius: l * 0.55
                // O fundo escolhido (ajudante.py, FUNDOS); sem ele, as letras ganham contorno.
                readonly property string fundo: pagina.s.fundo || "escuro"
                readonly property bool contorno: fundo !== "escuro"
                color: Qt.rgba(0.082, 0.082, 0.094, ({ escuro: 0.62, leve: 0.3, transparente: 0 })[fundo])
                opacity: pagina.s.ligada ? 1 : 0.5
                Behavior on color {
                    ColorAnimation {
                        duration: Kirigami.Units.longDuration
                    }
                }
                Behavior on x {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }

                // Os números. A placa é a de jogo (a do nome), como no jogo.
                readonly property int fps: 141 + (janela.tique * 7) % 6
                readonly property var p0: {
                    var lista = janela.dados ? janela.dados.placas : [];
                    var nome = janela.dados && janela.dados.pc ? janela.dados.pc.gpu : "";
                    for (var i = 0; i < lista.length; i++)
                        if (lista[i].nome === nome)
                            return lista[i];
                    return janela.placa;
                }
                function ou(valor, exemplo) {
                    return valor > 0 ? String(Math.round(valor)) : exemplo;
                }
                readonly property var valoresGpu: {
                    var v = [];
                    if (pagina.tem("gpu") || mostraGpu)
                        v.push({ n: p0 && p0.uso >= 0 ? String(p0.uso) : "57", u: "%", grande: true });
                    if (pagina.tem("temperatura"))
                        v.push({ n: p0 ? ou(p0.temp, "61") : "61", u: linha ? "°" : "°C", grande: true });
                    if (pagina.tem("ventoinha"))
                        v.push(p0 && p0.ventoinha >= 0 && !(p0.rpm > 0) ? { n: String(p0.ventoinha), u: "%", grande: true, extra: "FAN" }
                                                                    : { n: p0 ? ou(p0.rpm, "1650") : "1650", u: "RPM" });
                    if (pagina.tem("frequencia"))
                        v.push({ n: p0 ? ou(p0.mhz, "2581") : "2581", u: "MHz" });
                    if (pagina.tem("consumo"))
                        v.push({ n: p0 ? ou(p0.watts, "187") : "187", u: "W" });
                    return v;
                }
                readonly property var valoresVram: {
                    var v = [{ n: p0 && p0.vram_total > 0 ? (p0.vram_usada / 1073741824).toFixed(1) : "3.2", u: linha ? "" : "GiB" }];
                    if (pagina.tem("frequencia") && !linha)
                        v.push({ n: p0 ? ou(p0.mhz_mem, "1000") : "1000", u: "MHz" });
                    return v;
                }
                readonly property var valoresCpu: {
                    var d = janela.dados ? janela.dados.cpu : null;
                    var v = [{ n: d ? String(Math.round(d.uso)) : "23", u: "%", grande: true }];
                    if (pagina.tem("temperatura"))
                        v.push({ n: d ? ou(d.temp, "52") : "52", u: linha ? "°" : "°C", grande: true });
                    if (pagina.tem("frequencia"))
                        v.push({ n: d ? ou(d.mhz, "4200") : "4200", u: "MHz" });
                    if (pagina.tem("consumo") && watsCpu)
                        v.push({ n: "58", u: "W" });
                    return v;
                }
                readonly property string ram: janela.dados ? (janela.dados.memoria.usada / 1073741824).toFixed(1) : "5.4"
                readonly property color corFps: fps < 30 ? "#f0609e" : (fps < 60 ? "#f5c36b" : "#ffffff")
                readonly property string unidadeFps: pagina.tem("api") ? "FPS" : ""
                // O primeiro número da linha é o uso (ajudante.py, gpu_text e cpu_text).
                readonly property string rotuloGpu: janela.t("GPU uso", "GPU load")
                readonly property string rotuloCpu: janela.t("CPU uso", "CPU load")

                component Rotulo: Text {
                    font.family: "Inter"
                    font.pixelSize: hud.l
                    font.weight: Font.DemiBold
                    color: "#ffffff"
                    textFormat: Text.PlainText
                    style: hud.contorno ? Text.Outline : Text.Normal
                    styleColor: "#000000"
                }
                // Um número alinhado pela direita e a unidade logo depois (pequena e no
                // alto, como no MangoHud; "%" e "°C" ficam do tamanho do número).
                component Valor: Item {
                    property string n: ""
                    property string u: ""
                    property bool grande: false
                    property string extra: ""
                    property color cor: "#ffffff"
                    width: hud.coluna
                    height: hud.alturaLinha
                    Rotulo {
                        id: numero
                        x: hud.alinhar - width
                        text: parent.n
                        color: parent.cor
                    }
                    Rotulo {
                        x: numero.x + numero.width + 1
                        text: parent.u
                        font.pixelSize: parent.grande ? hud.l : hud.pequena
                    }
                    Rotulo {
                        visible: parent.extra !== ""
                        x: numero.x + numero.width + 1 + hud.l * 0.75
                        text: parent.extra
                        font.pixelSize: hud.pequena
                    }
                }
                // Uma linha da tabela: o nome e os valores em duas colunas, descendo.
                component LinhaHud: Item {
                    property string rotulo: ""
                    property color corRotulo: "#ffffff"
                    property var valores: []
                    width: hud.largura - 2 * hud.pad
                    height: Math.max(1, Math.ceil(valores.length / 2)) * hud.alturaLinha
                    Rotulo {
                        text: parent.rotulo
                        color: parent.corRotulo
                    }
                    Repeater {
                        model: parent.valores
                        Valor {
                            required property var modelData
                            required property int index
                            x: hud.coluna * (1 + index % 2)
                            y: Math.floor(index / 2) * hud.alturaLinha
                            n: modelData.n
                            u: modelData.u
                            grande: modelData.grande === true
                            extra: modelData.extra || ""
                            cor: modelData.cor || "#ffffff"
                        }
                    }
                }
                component Nome: Rotulo {
                    font.pixelSize: hud.secundaria
                    height: hud.secundaria * 1.45
                    verticalAlignment: Text.AlignVCenter
                }
                component Respiro: Item {
                    width: 1
                    height: hud.secundaria * 1.45
                }

                // ----- em pé (Completa) -----
                Column {
                    id: emPe
                    x: hud.pad
                    y: hud.pad
                    visible: !hud.linha

                    Rotulo {
                        visible: pagina.tem("hora")
                        height: hud.alturaLinha
                        text: "21:47"
                    }
                    Respiro { visible: pagina.tem("hora") && pagina.tem("fps") }
                    LinhaHud {
                        visible: pagina.tem("fps")
                        rotulo: pagina.tem("api") ? hud.api : "FPS"
                        valores: [{ n: String(hud.fps), u: hud.unidadeFps, cor: hud.corFps },
                                  { n: (1000 / hud.fps).toFixed(1), u: "ms" }]
                    }
                    LinhaHud {
                        visible: pagina.tem("fps") && pagina.tem("fps_baixo")
                        rotulo: "AVG"
                        valores: [{ n: String(hud.fps - 4), u: hud.unidadeFps }]
                    }
                    LinhaHud {
                        visible: pagina.tem("fps") && pagina.tem("fps_baixo")
                        rotulo: "1%"
                        valores: [{ n: String(Math.round(hud.fps * 0.68)), u: hud.unidadeFps }]
                    }
                    // O gráfico do tempo de cada quadro, com o título pequeno do MangoHud.
                    Item {
                        visible: pagina.tem("fps") && pagina.tem("grafico")
                        width: hud.largura - 2 * hud.pad
                        height: hud.pequena * 2.6
                        Rotulo {
                            anchors.bottom: parent.bottom
                            text: "Frametime"
                            font.pixelSize: hud.pequena
                        }
                        Rotulo {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            text: "min: " + (1000 / (hud.fps + 9)).toFixed(1) + "ms, max: " + (1000 / (hud.fps - 30)).toFixed(1) + "ms"
                            font.pixelSize: hud.pequena
                        }
                    }
                    Canvas {
                        id: graficoHud
                        visible: pagina.tem("fps") && pagina.tem("grafico")
                        width: hud.largura - 2 * hud.pad
                        height: hud.l * 2.3
                        property int t: janela.tique
                        onTChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.strokeStyle = "#45d0c1";
                            ctx.lineWidth = Math.max(1, hud.l * 0.07);
                            ctx.beginPath();
                            for (var i = 0; i <= 60; i++) {
                                var v = 0.22 + 0.05 * Math.sin((i + t * 3) * 1.3) + ((i * 7 + t) % 17 === 0 ? 0.25 : 0);
                                var x = i * width / 60;
                                var y = height - v * height;
                                if (i === 0)
                                    ctx.moveTo(x, y);
                                else
                                    ctx.lineTo(x, y);
                            }
                            ctx.stroke();
                        }
                    }
                    Respiro { visible: pagina.tem("fps") && (hud.mostraGpu || pagina.tem("vram")) }
                    Nome {
                        visible: hud.nomes && (hud.mostraGpu || pagina.tem("vram"))
                        text: janela.dados && janela.dados.pc && janela.dados.pc.gpu ? janela.dados.pc.gpu : (hud.p0 ? hud.p0.nome : "")
                    }
                    LinhaHud {
                        visible: hud.mostraGpu
                        rotulo: hud.rotuloGpu
                        corRotulo: "#f0729f"
                        valores: hud.valoresGpu
                    }
                    LinhaHud {
                        visible: pagina.tem("vram")
                        rotulo: "VRAM"
                        corRotulo: "#f59f6b"
                        valores: hud.valoresVram
                    }
                    Respiro { visible: (pagina.tem("fps") || hud.mostraGpu || pagina.tem("vram")) && (hud.mostraCpu || pagina.tem("ram")) }
                    Nome {
                        visible: hud.nomes && hud.mostraCpu
                        text: janela.dados && janela.dados.pc ? janela.dados.pc.cpu : ""
                    }
                    LinhaHud {
                        visible: hud.mostraCpu
                        rotulo: hud.rotuloCpu
                        corRotulo: "#45d0c1"
                        valores: hud.valoresCpu
                    }
                    LinhaHud {
                        visible: pagina.tem("ram")
                        rotulo: "RAM"
                        corRotulo: "#b18cf5"
                        valores: [{ n: hud.ram, u: "GiB" }]
                    }
                }

                // ----- em linha: tudo numa linha só, com um traço entre as partes -----
                Row {
                    id: emLinha
                    anchors.centerIn: parent
                    visible: hud.linha
                    spacing: hud.l * 0.4

                    component Parte: Row {
                        property string rotulo: ""
                        property color corRotulo: "#ffffff"
                        property var valores: []
                        property bool primeira: false
                        spacing: hud.l * 0.3
                        Rectangle {
                            visible: !parent.primeira
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: hud.l * 0.8
                            color: "#55555c"
                        }
                        Rotulo {
                            text: parent.rotulo
                            color: parent.corRotulo
                        }
                        Repeater {
                            model: parent.valores
                            Row {
                                required property var modelData
                                Rotulo {
                                    text: modelData.n
                                    color: modelData.cor || "#ffffff"
                                }
                                Rotulo {
                                    text: modelData.u
                                    font.pixelSize: modelData.grande ? hud.l : hud.pequena
                                }
                            }
                        }
                    }
                    Rotulo {
                        visible: pagina.tem("hora")
                        text: "21:47"
                    }
                    Parte {
                        visible: pagina.tem("fps")
                        primeira: !pagina.tem("hora")
                        rotulo: pagina.tem("api") ? hud.api : "FPS"
                        valores: [{ n: String(hud.fps), u: hud.unidadeFps, cor: hud.corFps }]
                    }
                    Parte {
                        visible: pagina.tem("fps") && pagina.tem("fps_baixo")
                        rotulo: "AVG"
                        valores: [{ n: String(hud.fps - 4), u: hud.unidadeFps }]
                    }
                    Parte {
                        visible: pagina.tem("fps") && pagina.tem("fps_baixo")
                        primeira: true   // o MangoHud junta a média e o 1% numa parte só
                        rotulo: "1%"
                        valores: [{ n: String(Math.round(hud.fps * 0.68)), u: hud.unidadeFps }]
                    }
                    Parte {
                        visible: hud.mostraGpu
                        rotulo: hud.rotuloGpu
                        corRotulo: "#f0729f"
                        valores: hud.valoresGpu
                    }
                    Parte {
                        visible: pagina.tem("vram")
                        rotulo: "VRAM"
                        corRotulo: "#f59f6b"
                        valores: hud.valoresVram
                    }
                    Parte {
                        visible: hud.mostraCpu
                        rotulo: hud.rotuloCpu
                        corRotulo: "#45d0c1"
                        valores: hud.valoresCpu
                    }
                    Parte {
                        visible: pagina.tem("ram")
                        rotulo: "RAM"
                        corRotulo: "#b18cf5"
                        valores: [{ n: hud.ram, u: "" }]
                    }
                }
            }
        }
        Texto {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: janela.t("Clique na prévia para mudar o canto", "Click the preview to change the corner")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.5
        }

        // ----- o que mostrar: três jeitos prontos e, embaixo, item por item -----
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.8)
            spacing: Math.round(janela.gu * 0.6)
            Texto {
                Layout.fillWidth: true
                text: janela.t("O que mostrar", "What to show")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
                font.weight: Font.DemiBold
            }
            Seletor {
                // Os mesmos MODELOS do ajudante.py; nenhum fica marcado quando a
                // pessoa escolheu outra mistura.
                readonly property var modelos: ({
                    basica: ["fps"],
                    media: ["fps", "fps_baixo", "grafico", "gpu", "cpu", "ram"],
                    completa: ["fps", "fps_baixo", "grafico", "nomes", "gpu", "vram", "cpu", "ram", "temperatura",
                               "frequencia", "consumo", "ventoinha"]
                })
                // A hora e a API são extras: ficam como estão ao trocar de modelo.
                readonly property var extras: ["hora", "api"]
                opcoes: [{ id: "basica", nome: janela.t("Só o FPS", "FPS only") }, { id: "media", nome: janela.t("Essencial", "Essentials") },
                         { id: "completa", nome: janela.t("Tudo", "Everything") }]
                escolhido: {
                    var atuais = pagina.s.itens.filter((i) => extras.indexOf(i) < 0).slice().sort().join(",");
                    for (var nome in modelos)
                        if (modelos[nome].slice().sort().join(",") === atuais)
                            return nome;
                    return "";
                }
                onEscolher: (id) => {
                    var lista = modelos[id].slice();
                    for (var i = 0; i < extras.length; i++)
                        if (pagina.tem(extras[i]))
                            lista.push(extras[i]);
                    janela.mudar("sobreposicao.itens", lista);
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.3)
            spacing: Math.round(janela.gu * 0.45)

            Repeater {
                model: [
                    { id: "fps", nome: janela.t("FPS e tempo do quadro", "FPS and frame time"), cor: "#ffffff" },
                    { id: "fps_baixo", nome: janela.t("FPS médio e 1% mais baixo", "Average and 1% low FPS"), cor: "#ffffff" },
                    { id: "api", nome: janela.t("DirectX ou Vulkan (no lugar de “FPS”)", "DirectX or Vulkan (instead of “FPS”)"), cor: "#ffffff" },
                    { id: "grafico", nome: janela.t("Gráfico dos quadros", "Frame graph"), cor: "#45d0c1" },
                    { id: "nomes", nome: janela.t("Nome do processador e da placa", "CPU and GPU names"), cor: "#ffffff" },
                    { id: "gpu", nome: janela.t("Uso da placa (GPU)", "GPU usage"), cor: "#f0729f" },
                    { id: "vram", nome: janela.t("Memória de vídeo", "Video memory"), cor: "#f59f6b" },
                    { id: "cpu", nome: janela.t("Uso do processador (CPU)", "CPU usage"), cor: "#45d0c1" },
                    { id: "ram", nome: janela.t("Memória (RAM)", "Memory (RAM)"), cor: "#b18cf5" },
                    { id: "temperatura", nome: janela.t("Temperaturas", "Temperatures"), cor: "#f5c36b" },
                    { id: "frequencia", nome: janela.t("Frequências (MHz)", "Clock speeds (MHz)"), cor: "#8fa2ff" },
                    { id: "consumo", nome: janela.t("Consumo (W)", "Power draw (W)"), cor: "#7fcf6a" },
                    { id: "ventoinha", nome: janela.t("Ventoinha da placa", "GPU fan"), cor: "#9fd8ff" },
                    { id: "hora", nome: janela.t("Hora", "Clock"), cor: "#ffffff" }
                ]

                MouseArea {
                    id: chip
                    required property var modelData
                    readonly property bool ligado: pagina.tem(modelData.id)
                    width: linhaChip.implicitWidth + Math.round(janela.gu * 1.2)
                    height: Math.round(janela.gu * 2)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    activeFocusOnTab: true
                    onClicked: pagina.trocarItem(modelData.id)
                    Keys.onSpacePressed: pagina.trocarItem(modelData.id)
                    Accessible.role: Accessible.CheckBox
                    Accessible.checkable: true
                    Accessible.checked: ligado
                    Accessible.name: modelData.nome
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: chip.ligado ? janela.tinta(janela.escuro ? 0.12 : 0.09) : janela.tinta(chip.containsMouse ? 0.06 : 0.025)
                        border.width: chip.activeFocus ? 1.5 : 1
                        border.color: chip.activeFocus ? janela.frente : janela.tinta(chip.ligado ? 0.22 : 0.1)
                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                    }
                    Row {
                        id: linhaChip
                        anchors.centerIn: parent
                        spacing: 6
                        // A cor que o item tem no jogo (branco vira a cor da frente no tema claro).
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(janela.gu * 0.9)
                            height: width
                            radius: width / 2
                            color: chip.ligado ? (chip.modelData.cor === "#ffffff" ? janela.frente : chip.modelData.cor) : "transparent"
                            border.width: chip.ligado ? 0 : 1.5
                            border.color: janela.tinta(0.4)
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                visible: chip.ligado
                                width: Math.round(parent.width * 0.8)
                                height: width
                                source: "matsu-certo-symbolic"
                                isMask: true
                                color: chip.modelData.cor === "#ffffff" && !janela.escuro ? "#ffffff" : "#141416"
                            }
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.nome
                            opacity: chip.ligado ? 1 : 0.75
                        }
                    }
                }
            }
        }

        // ----- canto, tamanho e jeito -----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.9)
            spacing: 2

            LinhaOpcao {
                Layout.fillWidth: true
                ultima: false
                icone: "matsu-sobreposicao-symbolic"
                nome: janela.t("Canto da tela", "Screen corner")
                texto: pagina.nomesPosicao[pagina.s.posicao] || ""
                // Uma telinha com os cinco lugares.
                Rectangle {
                    width: Math.round(janela.gu * 5.2)
                    height: Math.round(janela.gu * 2.9)
                    radius: 5
                    color: janela.tinta(0.05)
                    border.width: 1
                    border.color: janela.tinta(0.18)
                    Repeater {
                        model: ["top-left", "top-center", "top-right", "bottom-left", "bottom-right"]
                        MouseArea {
                            id: ponto
                            required property string modelData
                            readonly property bool escolhido: pagina.s.posicao === modelData
                            width: Math.round(janela.gu * 1.2)
                            height: Math.round(janela.gu * 0.8)
                            x: modelData.indexOf("left") >= 0 ? 3 : (modelData.indexOf("right") >= 0 ? parent.width - width - 3 : (parent.width - width) / 2)
                            y: modelData.indexOf("top") === 0 ? 3 : parent.height - height - 3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: janela.mudar("sobreposicao.posicao", modelData)
                            Accessible.role: Accessible.RadioButton
                            Accessible.checked: escolhido
                            Accessible.name: pagina.nomesPosicao[modelData]
                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: ponto.escolhido ? janela.frente : janela.tinta(ponto.containsMouse ? 0.3 : 0.12)
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Kirigami.Units.shortDuration
                                    }
                                }
                            }
                            QQC2.ToolTip.visible: containsMouse
                            QQC2.ToolTip.text: pagina.nomesPosicao[modelData]
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                    }
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                ultima: false
                icone: "matsu-texto-symbolic"
                nome: janela.t("Tamanho", "Size")
                Seletor {
                    opcoes: [{ id: "pequeno", nome: janela.t("Pequena", "Small") }, { id: "medio", nome: janela.t("Média", "Medium") },
                             { id: "grande", nome: janela.t("Grande", "Large") }]
                    escolhido: pagina.s.tamanho
                    onEscolher: (id) => janela.mudar("sobreposicao.tamanho", id)
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                ultima: false
                icone: "matsu-textura-symbolic"
                nome: janela.t("Fundo", "Background")
                texto: janela.t("Transparente: só os números, com contorno, sem tapar o jogo.",
                                "Transparent: just the numbers, outlined, without covering the game.")
                Seletor {
                    opcoes: [{ id: "escuro", nome: janela.t("Escuro", "Dark") }, { id: "leve", nome: janela.t("Leve", "Light") },
                             { id: "transparente", nome: janela.t("Transparente", "Transparent") }]
                    escolhido: pagina.s.fundo || "escuro"
                    onEscolher: (id) => janela.mudar("sobreposicao.fundo", id)
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                icone: "matsu-menu-symbolic"
                nome: janela.t("Jeito", "Layout")
                texto: janela.t("Completa, uma coisa por linha; ou tudo numa linha só, discreta.", "Full, one item per line; or everything on a single, discreet line.")
                Seletor {
                    opcoes: [{ id: "completa", nome: janela.t("Completa", "Full") }, { id: "linha", nome: janela.t("Em linha", "Single line") }]
                    escolhido: pagina.s.compacta ? "linha" : "completa"
                    onEscolher: (id) => janela.mudar("sobreposicao.compacta", id === "linha")
                }
            }
        }

        // ----- onde ela aparece -----
        Texto {
            Layout.topMargin: Math.round(janela.gu * 0.9)
            text: janela.t("Bom saber", "Good to know")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
            font.weight: Font.DemiBold
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.3)
            spacing: 2
            LinhaOpcao {
                Layout.fillWidth: true
                ultima: false
                icone: "matsu-jogos-symbolic"
                nome: janela.t("Jogos do Windows e jogos Vulkan", "Windows games and Vulkan games")
                texto: janela.t("Aparece sozinha: quase todos os jogos da Steam, inclusive os do Windows pelo Proton.",
                                "Shows up by itself: almost every Steam game, including Windows games through Proton.")
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                ultima: false
                icone: "matsu-raio-symbolic"
                nome: janela.t("Consumo do processador", "CPU power draw")
                texto: janela.dados && janela.dados.pc && janela.dados.pc.cpu_watts
                       ? janela.t("Neste computador aparece o consumo da placa e do processador.",
                                  "On this computer both the GPU and the CPU power draw show up.")
                       : janela.t("Neste computador aparece só o da placa: o do processador o Linux deixa só para o administrador, por segurança.",
                                  "On this computer only the GPU's shows up: Linux keeps the CPU's for the administrator, for security.")
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                icone: "matsu-texto-symbolic"
                nome: janela.t("Jogos OpenGL (nativos mais antigos)", "OpenGL games (older native ones)")
                texto: janela.t("Na Steam, em Propriedades do jogo › Opções de inicialização, coloque: mangohud %command%",
                                "On Steam, in the game's Properties › Launch options, enter: mangohud %command%")
                Botao {
                    texto: janela.t("Copiar", "Copy")
                    icone: "matsu-papel-symbolic"
                    onClicado: {
                        copiador.text = "mangohud %command%";
                        copiador.selectAll();
                        copiador.copy();
                        janela.avisoRapido(janela.t("Copiado: mangohud %command%", "Copied: mangohud %command%"), "certo");
                    }
                }
            }
        }
        // Só para copiar o texto (o QtQuick não tem área de transferência sem um campo).
        TextEdit {
            id: copiador
            visible: false
        }
    }
}
