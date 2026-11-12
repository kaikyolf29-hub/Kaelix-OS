// Placa de vídeo: o nome, o driver e se tem versão nova (o driver chega junto
// com as atualizações do Matsu), os números de agora com o último minuto em
// gráfico, e o ajuste fino no app da própria placa (LACT ou CoreCtrl).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Flickable {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.4)
    readonly property var p: janela.placa
    readonly property var a: janela.atualizacao
    readonly property string marca: p ? (p.marca || "") : ""
    readonly property color corMarca: marca === "AMD" ? "#ed1c24" : (marca === "NVIDIA" ? "#76b900" : (marca === "Intel" ? "#0071c5" : janela.frente))

    contentHeight: coluna.implicitHeight + 2 * margem
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: BarraRolagem {}

    ColumnLayout {
        id: coluna
        x: pagina.margem
        y: pagina.margem
        width: pagina.width - 2 * pagina.margem
        spacing: Math.round(janela.gu * 0.8)

        // ----- a placa e o driver -----
        Cartao {
            Layout.fillWidth: true
            implicitHeight: cabecalho.implicitHeight + Math.round(janela.gu * 2.2)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: janela.cartao }
                GradientStop { position: 1; color: Qt.rgba(pagina.corMarca.r, pagina.corMarca.g, pagina.corMarca.b, janela.escuro ? 0.1 : 0.08) }
            }

            RowLayout {
                id: cabecalho
                anchors.fill: parent
                anchors.margins: Math.round(janela.gu * 1.1)
                spacing: Math.round(janela.gu * 1)

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: Math.round(janela.gu * 3.6)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: Math.round(width * 0.28)
                    color: Qt.rgba(pagina.corMarca.r, pagina.corMarca.g, pagina.corMarca.b, janela.escuro ? 0.16 : 0.12)
                    border.width: 1
                    border.color: Qt.rgba(pagina.corMarca.r, pagina.corMarca.g, pagina.corMarca.b, 0.35)
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.55)
                        height: width
                        source: "matsu-placa-symbolic"
                        isMask: true
                        color: pagina.marca ? pagina.corMarca : janela.frente
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.2)
                    Texto {
                        visible: pagina.marca.length > 0
                        text: pagina.marca
                        color: pagina.corMarca
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: pagina.p ? pagina.p.nome : janela.t("Lendo a placa de vídeo...", "Reading the graphics card...")
                        font.pixelSize: Math.round(janela.gu * 1.35)
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }
                    Texto {
                        Layout.fillWidth: true
                        visible: pagina.p !== null
                        text: pagina.p ? janela.t("Driver ", "Driver ") + pagina.p.driver
                                         + (pagina.p.vram_total > 0 ? "  ·  " + janela.bytes(pagina.p.vram_total) + janela.t(" de memória", " of memory") : "") : ""
                        opacity: 0.7
                        wrapMode: Text.WordWrap
                    }
                }
                // Atualização do driver (vem com a do sistema).
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Math.round(janela.gu * 0.35)
                    Row {
                        Layout.alignment: Qt.AlignRight
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: 4
                            color: !pagina.a || pagina.a.tem === null ? janela.tinta(0.4)
                                 : (pagina.a.tem || pagina.a.pronta ? "#f5b330" : (janela.escuro ? "#7fcf6a" : "#3d9533"))
                        }
                        Texto {
                            text: janela.procurando ? janela.t("Procurando...", "Checking...")
                                : (!pagina.a ? "" : (pagina.a.pronta ? janela.t("Atualização pronta: reinicie", "Update ready: restart")
                                : (pagina.a.tem ? janela.t("Tem driver novo", "New driver available")
                                : (pagina.a.tem === false ? janela.t("Driver atualizado", "Driver up to date")
                                : janela.t("Sem internet para conferir", "No internet to check")))))
                            font.weight: Font.DemiBold
                        }
                    }
                    Texto {
                        Layout.alignment: Qt.AlignRight
                        visible: pagina.a !== null && pagina.a.quando > 0
                        text: pagina.a ? janela.t("Conferido ", "Checked ") + janela.quando(pagina.a.quando).toLowerCase() : ""
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.55
                    }
                    BotaoDestaque {
                        Layout.alignment: Qt.AlignRight
                        Layout.topMargin: 2
                        visible: pagina.a !== null && pagina.a.tem === true && !pagina.a.pronta
                        texto: janela.t("Atualizar agora", "Update now")
                        icone: "matsu-baixar-symbolic"
                        onClicado: janela.atualizarAgora()
                    }
                    Botao {
                        Layout.alignment: Qt.AlignRight
                        visible: !(pagina.a !== null && pagina.a.tem === true && !pagina.a.pronta)
                        texto: janela.t("Procurar agora", "Check now")
                        icone: "matsu-recarregar-symbolic"
                        ativo: !janela.procurando
                        onClicado: janela.procurarAtualizacao()
                    }
                }
            }
        }
        Texto {
            Layout.fillWidth: true
            text: janela.t("O driver da placa chega junto com as atualizações do Matsu, já testado com o resto do sistema.",
                           "The graphics driver comes with Matsu updates, already tested with the rest of the system.")
            wrapMode: Text.WordWrap
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.55
        }

        // ----- números de agora -----
        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.3)
            visible: pagina.p !== null
            columns: coluna.width > janela.gu * 40 ? 3 : 2
            columnSpacing: Math.round(janela.gu * 0.6)
            rowSpacing: Math.round(janela.gu * 0.6)

            Repeater {
                model: pagina.p ? [
                    { nome: janela.t("Uso", "Usage"), valor: pagina.p.uso >= 0 ? janela.porcento(pagina.p.uso) : "—", extra: "",
                      chave: "uso", cor: janela.cores.gpu, maximo: 100 },
                    { nome: janela.t("Temperatura", "Temperature"), valor: pagina.p.temp > 0 ? pagina.p.temp + " °C" : "—",
                      extra: pagina.p.temp_junc > 0 ? janela.t("ponto mais quente ", "hotspot ") + pagina.p.temp_junc + " °C" : "",
                      chave: "temp", cor: pagina.p.temp >= 85 ? "#f0609e" : janela.cores.rede, maximo: 100 },
                    { nome: janela.t("Velocidade", "Clock"), valor: pagina.p.mhz > 0 ? janela.num(pagina.p.mhz, 0) + " MHz" : "—",
                      extra: pagina.p.mhz_mem > 0 ? janela.t("memória ", "memory ") + janela.num(pagina.p.mhz_mem, 0) + " MHz" : "",
                      chave: "mhz", cor: janela.cores.cpu, maximo: 0 },
                    { nome: janela.t("Memória de vídeo", "Video memory"), valor: pagina.p.vram_total > 0 ? janela.par(pagina.p.vram_usada, pagina.p.vram_total) : "—",
                      extra: "", chave: "vram", cor: janela.cores.mem, maximo: 100 },
                    { nome: janela.t("Consumo", "Power"), valor: pagina.p.watts > 0 ? janela.num(pagina.p.watts, 0) + " W" : "—",
                      extra: pagina.p.watts_max > 0 ? janela.t("limite ", "limit ") + janela.num(pagina.p.watts_max, 0) + " W" : "",
                      chave: "watts", cor: janela.cores.disco, maximo: pagina.p.watts_max > 0 ? pagina.p.watts_max : 0 },
                    { nome: janela.t("Ventoinha", "Fan"), valor: pagina.p.rpm > 0 ? janela.num(pagina.p.rpm, 0) + " RPM" : (pagina.p.ventoinha >= 0 ? janela.porcento(pagina.p.ventoinha) : "—"),
                      extra: pagina.p.rpm === 0 && pagina.p.ventoinha === 0 ? janela.t("parada (placa fria)", "stopped (card is cool)")
                           : (pagina.p.rpm > 0 && pagina.p.ventoinha >= 0 ? janela.porcento(pagina.p.ventoinha) + janela.t(" da força", " of max") : ""),
                      chave: "ventoinha", cor: "#8fa2ff", maximo: 0 }
                ] : []

                Cartao {
                    id: bloco
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: Math.round(janela.gu * 6.4)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(janela.gu * 0.8)
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: bloco.modelData.cor
                            }
                            Texto {
                                Layout.fillWidth: true
                                text: bloco.modelData.nome
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.65
                                elide: Text.ElideRight
                            }
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: bloco.modelData.valor
                            font.pixelSize: Math.round(janela.gu * 1.25)
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: bloco.modelData.extra || " "
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.55
                            elide: Text.ElideRight
                        }
                        Grafico {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: 3
                            mini: true
                            moldura: false
                            cor: bloco.modelData.cor
                            maximo: bloco.modelData.maximo
                            valores: janela.historico[bloco.modelData.chave] || []
                            tique: janela.tique
                        }
                    }
                }
            }
        }

        // Sem placa de verdade (máquina virtual).
        Cartao {
            Layout.fillWidth: true
            visible: janela.dados !== null && pagina.p === null
            implicitHeight: Math.round(janela.gu * 5)
            RowLayout {
                anchors.fill: parent
                anchors.margins: Math.round(janela.gu * 1)
                spacing: Math.round(janela.gu * 0.8)
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Layout.preferredWidth
                    source: "matsu-placa-symbolic"
                    isMask: true
                    color: janela.frente
                    opacity: 0.5
                }
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Não achei uma placa de vídeo de verdade neste computador (ele pode ser uma máquina virtual).",
                                   "No real graphics card found on this computer (it may be a virtual machine).")
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                }
            }
        }

        // ----- ajustes da placa -----
        Texto {
            Layout.topMargin: Math.round(janela.gu * 0.8)
            visible: pagina.p !== null
            text: janela.t("Ajustes da placa", "Card settings")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
            font.weight: Font.DemiBold
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: pagina.p !== null
            spacing: 2
            LinhaOpcao {
                Layout.fillWidth: true
                ultima: !(janela.dados && janela.dados.ajuste)
                icone: "matsu-desempenho-symbolic"
                nome: janela.t("Velocidade da placa agora", "Card speed right now")
                texto: {
                    if (!pagina.p || !pagina.p.nivel_mudavel)
                        return janela.t("O próprio driver escolhe, conforme o jogo pede.", "The driver itself chooses, as the game needs.");
                    return ({ auto: janela.t("Automática: o driver escolhe, conforme o jogo pede.", "Automatic: the driver chooses, as the game needs."),
                              high: janela.t("Máxima: o perfil do jogo aberto pediu desempenho.", "Max: the open game's profile asked for performance."),
                              low: janela.t("Econômica: o perfil do jogo aberto pediu economia.", "Saving: the open game's profile asked for power saving.") })[pagina.p.nivel]
                           || janela.t("Ajustada à mão (", "Set by hand (") + pagina.p.nivel + ")";
                }
                Botao {
                    texto: janela.t("Mudar nos perfis", "Change in profiles")
                    icone: "matsu-seta-symbolic"
                    iconeNoFim: true
                    onClicado: janela.pagina = "graficos"
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                visible: janela.dados !== null && janela.dados.ajuste !== null && janela.dados.ajuste !== undefined
                primeira: false
                icone: "matsu-engrenagem-symbolic"
                nome: janela.t("Ajuste fino", "Fine tuning")
                texto: janela.t("Curva da ventoinha, limite de energia e frequências, no app da placa.", "Fan curve, power limit and clocks, in the card's app.")
                Botao {
                    texto: janela.t("Abrir ", "Open ") + (janela.dados && janela.dados.ajuste ? janela.dados.ajuste.nome : "")
                    icone: janela.dados && janela.dados.ajuste ? janela.dados.ajuste.icone : ""
                    iconeColorido: true
                    onClicado: matsu.soltar(["gio", "launch", janela.dados.ajuste.arquivo])
                }
            }
        }
    }
}
