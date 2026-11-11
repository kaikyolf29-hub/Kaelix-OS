// Sobreposição no jogo: FPS, GPU, CPU, memória e o que a pessoa escolher, em
// cima do jogo, no visual do Kaelix (o MangoHud por baixo). Em cima, uma prévia
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
                                         : ({ ligada: false, itens: ["fps", "grafico", "cpu", "gpu", "ram"], posicao: "top-left", tamanho: "medio", compacta: false })
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
    QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

    ColumnLayout {
        id: coluna
        x: pagina.margem
        y: pagina.margem
        width: pagina.width - 2 * pagina.margem
        spacing: Math.round(janela.gu * 0.5)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.8)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Texto {
                    text: janela.t("Sobreposição no jogo", "In-game overlay")
                    font.pixelSize: Math.round(janela.gu * 1.3)
                    font.weight: Font.DemiBold
                }
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Aparece só com um jogo aberto. No jogo, Shift direito + F12 mostra e esconde.",
                                   "Only shows while a game is open. In the game, Right Shift + F12 shows and hides it.")
                    wrapMode: Text.WordWrap
                    opacity: 0.65
                }
            }
            Texto {
                text: pagina.s.ligada ? janela.t("Ligada", "On") : janela.t("Desligada", "Off")
                opacity: 0.75
            }
            Chave {
                ligada: pagina.s.ligada
                nome: janela.t("Mostrar a sobreposição no jogo", "Show the overlay in games")
                onTrocada: (ligada) => janela.mudar("sobreposicao.ligada", ligada)
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

            // A sobreposição de mentira, igual à do jogo (cores das partes do Kaelix).
            Rectangle {
                id: hud
                readonly property real m: Math.round(janela.gu * 0.6)
                readonly property string p: pagina.s.posicao
                visible: pagina.s.itens.length > 0
                x: p.indexOf("left") >= 0 ? m : (p.indexOf("right") >= 0 ? tela.width - width - m : (tela.width - width) / 2)
                y: p.indexOf("top") === 0 ? m : tela.height - height - m
                width: conteudoHud.implicitWidth + tela.letra * 1.1
                height: conteudoHud.implicitHeight + tela.letra * 0.8
                radius: tela.letra * 0.45
                color: Qt.rgba(0.11, 0.11, 0.12, 0.62)
                opacity: pagina.s.ligada ? 1 : 0.5
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

                // Números de verdade deste computador; o FPS é de exemplo.
                readonly property int fps: 141 + (janela.tique * 7) % 6
                readonly property var p0: janela.placa
                readonly property string gpu: p0 ? Math.max(0, p0.uso) + "%" : "57%"
                readonly property string gpuTemp: p0 && p0.temp > 0 ? p0.temp + "°C" : "61°C"
                readonly property string gpuMhz: p0 && p0.mhz > 0 ? p0.mhz + "MHz" : "2581MHz"
                readonly property string gpuW: p0 && p0.watts > 0 ? Math.round(p0.watts) + "W" : "187W"
                readonly property string cpu: janela.dados ? Math.round(janela.dados.cpu.uso) + "%" : "23%"
                readonly property string cpuTemp: janela.dados && janela.dados.cpu.temp > 0 ? janela.dados.cpu.temp + "°C" : "52°C"
                readonly property string ram: janela.dados ? janela.num(janela.dados.memoria.usada / 1073741824, 1) + " GiB" : "5,4 GiB"
                readonly property string vram: p0 && p0.vram_total > 0 ? janela.num(p0.vram_usada / 1073741824, 1) + " GiB" : "3,2 GiB"

                component Rotulo: Text {
                    font.family: "Inter"
                    font.pixelSize: tela.letra
                    font.weight: Font.DemiBold
                    color: "#ffffff"
                }

                Column {
                    id: conteudoHud
                    anchors.centerIn: parent
                    spacing: tela.letra * 0.25
                    visible: !pagina.s.compacta

                    Rotulo {
                        visible: pagina.tem("hora")
                        text: "21:47"
                    }
                    Row {
                        visible: pagina.tem("fps")
                        spacing: tela.letra * 0.6
                        Rotulo { text: "FPS"; width: tela.letra * 3.2 }
                        Rotulo { text: hud.fps; width: tela.letra * 2.6; horizontalAlignment: Text.AlignRight }
                        Rotulo { text: janela.num(1000 / hud.fps, 1) + " ms"; opacity: 0.85 }
                    }
                    // Gráfico do tempo de cada quadro.
                    Canvas {
                        id: graficoHud
                        visible: pagina.tem("grafico") && pagina.tem("fps")
                        width: tela.letra * 10
                        height: tela.letra * 1.6
                        property int t: janela.tique
                        onTChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.strokeStyle = "#45d0c1";
                            ctx.lineWidth = Math.max(1, tela.letra * 0.09);
                            ctx.beginPath();
                            for (var i = 0; i <= 40; i++) {
                                var v = 0.5 + 0.18 * Math.sin((i + t * 3) * 0.7) + ((i * 7 + t) % 13 === 0 ? 0.3 : 0);
                                var x = i * width / 40;
                                var y = height - v * height * 0.8;
                                if (i === 0)
                                    ctx.moveTo(x, y);
                                else
                                    ctx.lineTo(x, y);
                            }
                            ctx.stroke();
                        }
                    }
                    Row {
                        visible: pagina.tem("gpu") || pagina.tem("temperatura") || pagina.tem("frequencia") || pagina.tem("consumo")
                        spacing: tela.letra * 0.6
                        Rotulo { text: "GPU"; color: "#f0729f"; width: tela.letra * 3.2 }
                        Rotulo { text: hud.gpu; width: tela.letra * 2.6; horizontalAlignment: Text.AlignRight }
                        Rotulo { visible: pagina.tem("temperatura"); text: hud.gpuTemp }
                        Rotulo { visible: pagina.tem("frequencia"); text: hud.gpuMhz }
                        Rotulo { visible: pagina.tem("consumo"); text: hud.gpuW }
                    }
                    Row {
                        visible: pagina.tem("cpu") || pagina.tem("temperatura") || pagina.tem("frequencia")
                        spacing: tela.letra * 0.6
                        Rotulo { text: "CPU"; color: "#45d0c1"; width: tela.letra * 3.2 }
                        Rotulo { text: hud.cpu; width: tela.letra * 2.6; horizontalAlignment: Text.AlignRight }
                        Rotulo { visible: pagina.tem("temperatura"); text: hud.cpuTemp }
                        Rotulo { visible: pagina.tem("frequencia"); text: "4200MHz" }
                    }
                    Row {
                        visible: pagina.tem("vram")
                        spacing: tela.letra * 0.6
                        Rotulo { text: "VRAM"; color: "#f59f6b"; width: tela.letra * 3.2 }
                        Rotulo { text: hud.vram }
                    }
                    Row {
                        visible: pagina.tem("ram")
                        spacing: tela.letra * 0.6
                        Rotulo { text: "RAM"; color: "#b18cf5"; width: tela.letra * 3.2 }
                        Rotulo { text: hud.ram }
                    }
                }
                // Em linha (compacta): tudo numa linha só.
                Row {
                    anchors.centerIn: parent
                    visible: pagina.s.compacta
                    spacing: tela.letra * 0.7
                    Rotulo { visible: pagina.tem("hora"); text: "21:47" }
                    Rotulo { visible: pagina.tem("fps"); text: hud.fps + " FPS" }
                    Row {
                        visible: pagina.tem("gpu")
                        spacing: tela.letra * 0.3
                        Rotulo { text: "GPU"; color: "#f0729f" }
                        Rotulo { text: hud.gpu }
                    }
                    Row {
                        visible: pagina.tem("cpu")
                        spacing: tela.letra * 0.3
                        Rotulo { text: "CPU"; color: "#45d0c1" }
                        Rotulo { text: hud.cpu }
                    }
                    Row {
                        visible: pagina.tem("vram")
                        spacing: tela.letra * 0.3
                        Rotulo { text: "VRAM"; color: "#f59f6b" }
                        Rotulo { text: hud.vram }
                    }
                    Row {
                        visible: pagina.tem("ram")
                        spacing: tela.letra * 0.3
                        Rotulo { text: "RAM"; color: "#b18cf5" }
                        Rotulo { text: hud.ram }
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

        // ----- o que mostrar -----
        Texto {
            Layout.topMargin: Math.round(janela.gu * 0.8)
            text: janela.t("O que mostrar", "What to show")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
            font.weight: Font.DemiBold
        }
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.3)
            spacing: Math.round(janela.gu * 0.45)

            Repeater {
                model: [
                    { id: "fps", nome: janela.t("FPS e tempo do quadro", "FPS and frame time"), cor: "#ffffff" },
                    { id: "grafico", nome: janela.t("Gráfico dos quadros", "Frame graph"), cor: "#45d0c1" },
                    { id: "gpu", nome: janela.t("Uso da placa (GPU)", "GPU usage"), cor: "#f0729f" },
                    { id: "cpu", nome: janela.t("Uso do processador (CPU)", "CPU usage"), cor: "#45d0c1" },
                    { id: "ram", nome: janela.t("Memória (RAM)", "Memory (RAM)"), cor: "#b18cf5" },
                    { id: "vram", nome: janela.t("Memória de vídeo", "Video memory"), cor: "#f59f6b" },
                    { id: "temperatura", nome: janela.t("Temperaturas", "Temperatures"), cor: "#f5c36b" },
                    { id: "frequencia", nome: janela.t("Frequências (MHz)", "Clock speeds (MHz)"), cor: "#8fa2ff" },
                    { id: "consumo", nome: janela.t("Consumo da placa (W)", "GPU power (W)"), cor: "#7fcf6a" },
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
                                source: "kaelix-certo-symbolic"
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
                icone: "kaelix-sobreposicao-symbolic"
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
                icone: "kaelix-texto-symbolic"
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
                icone: "kaelix-menu-symbolic"
                nome: janela.t("Jeito", "Layout")
                texto: janela.t("Completa, uma coisa por linha; ou tudo numa linha só, discreta.", "Full, one item per line; or everything on a single, discreet line.")
                Seletor {
                    opcoes: [{ id: "completa", nome: janela.t("Completa", "Full") }, { id: "linha", nome: janela.t("Em linha", "Single line") }]
                    escolhido: pagina.s.compacta ? "linha" : "completa"
                    onEscolher: (id) => janela.mudar("sobreposicao.compacta", id === "linha")
                }
            }
        }
    }
}
