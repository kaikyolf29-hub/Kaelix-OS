// Drivers: cada placa de vídeo (a integrada e a dedicada, nos notebooks com as
// duas), o driver que ela usa e a versão; o Mesa, o Vulkan (64 e 32 bits) e o
// OpenGL; a atualização do driver (que chega junto com a do sistema) e a troca
// para a versão do Matsu com o driver da NVIDIA (e a volta).
// Quem lê tudo é o ajudante (drivers.py), com cache de uma hora.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Flickable {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.4)
    readonly property var d: janela.drivers
    readonly property var a: janela.atualizacao
    readonly property var troca: d ? d.troca : null
    readonly property var outra: d ? d.outra : null
    readonly property bool naNvidia: d !== null && d.imagem && d.imagem.variante === "nvidia"
    readonly property bool temAmd: {
        if (!d)
            return false;
        for (var i = 0; i < d.placas.length; i++)
            if (d.placas[i].fornecedor === "1002")
                return true;
        return false;
    }
    readonly property color verde: janela.escuro ? "#7fcf6a" : "#3d9533"
    readonly property color laranja: janela.escuro ? "#f5b330" : "#c98a12"

    function corMarca(marca) {
        return marca === "AMD" ? "#ed1c24" : (marca === "NVIDIA" ? "#76b900" : (marca === "Intel" ? "#0071c5" : janela.frente));
    }
    function nomeDriverVulkan(v) {
        if (!v)
            return "";
        return ({ radv: "RADV", anv: "ANV", nvk: "NVK", nvidia: "NVIDIA", amdvlk: "AMDVLK", llvmpipe: "llvmpipe" })[v.driver] || v.driver || "";
    }
    function pedirTroca(t, outraVersao) {
        var nvidia = t.acao === "instalar-nvidia";
        var canal = d.imagem && d.imagem.tag ? d.imagem.tag : "estavel";
        janela.perguntar({
            titulo: nvidia ? janela.t("Instalar o driver da NVIDIA?", "Install the NVIDIA driver?")
                           : janela.t("Voltar para a versão comum?", "Go back to the standard version?"),
            texto: (nvidia ? janela.t("O Matsu baixa a versão dele com o driver oficial da NVIDIA, no mesmo canal (" + canal + ").",
                                      "Matsu downloads its version with the official NVIDIA driver, on the same channel (" + canal + ").")
                           : janela.t("O Matsu baixa a versão comum, sem o driver da NVIDIA, no mesmo canal (" + canal + ").",
                                      "Matsu downloads the standard version, without the NVIDIA driver, on the same channel (" + canal + ")."))
                   + " " + janela.t("Leva alguns minutos e dá para continuar usando o computador. Ele vai pedir a sua senha. No fim, é só reiniciar: seus arquivos, apps e ajustes ficam como estão.",
                                    "It takes a few minutes and you can keep using the computer. It will ask for your password. At the end, just restart: your files, apps and settings stay as they are.")
                   + (t.aviso === "antiga" ? "\n\n" + janela.t("Atenção: esta placa é anterior às GTX 16 e RTX 20, e o driver novo da NVIDIA pode não funcionar nela.",
                                                              "Heads up: this card is older than the GTX 16 and RTX 20 series, and the new NVIDIA driver may not work on it.") : ""),
            sim: nvidia ? janela.t("Baixar e instalar", "Download and install") : janela.t("Baixar e trocar", "Download and switch"),
            nao: janela.t("Agora não", "Not now")
        }, function () { janela.trocarImagem(outraVersao); });
    }

    contentHeight: coluna.implicitHeight + 2 * margem
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: BarraRolagem {}

    // Pílula de situação: o pontinho e o texto (verde quando está tudo certo).
    component Situacao: Rectangle {
        id: sit
        property string texto: ""
        property color cor: pagina.verde
        implicitWidth: linhaSit.implicitWidth + Math.round(janela.gu * 1)
        implicitHeight: Math.round(janela.gu * 1.5)
        radius: height / 2
        color: Qt.rgba(cor.r, cor.g, cor.b, janela.escuro ? 0.14 : 0.11)
        Row {
            id: linhaSit
            anchors.centerIn: parent
            spacing: 6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: sit.cor
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: sit.texto
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
            }
        }
    }
    // O valor à direita de uma linha (a versão), em destaque.
    component Valor: Texto {
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }

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
                    text: janela.t("Drivers", "Drivers")
                    font.pixelSize: Math.round(janela.gu * 1.3)
                    font.weight: Font.DemiBold
                }
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Chegam junto com as atualizações do sistema.",
                                   "They arrive with the system updates.")
                    wrapMode: Text.WordWrap
                    opacity: 0.65
                }
            }
            Girando {
                visible: janela.lendoDrivers && pagina.d !== null
                Layout.preferredWidth: Math.round(janela.gu * 0.9)
                Layout.preferredHeight: Layout.preferredWidth
            }
            Botao {
                visible: pagina.d !== null
                ativo: !janela.lendoDrivers
                texto: janela.t("Conferir de novo", "Check again")
                icone: "matsu-recarregar-symbolic"
                onClicado: janela.lerDrivers(true)
            }
        }

        // Lendo pela primeira vez (o vulkaninfo leva um segundinho).
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(janela.gu * 3)
            visible: pagina.d === null
            spacing: Math.round(janela.gu * 0.5)
            Girando {
                Layout.preferredWidth: Math.round(janela.gu * 1.1)
                Layout.preferredHeight: Layout.preferredWidth
            }
            Texto {
                text: janela.t("Lendo os drivers…", "Reading the drivers…")
                opacity: 0.75
            }
        }

        // ----- a troca de versão em andamento -----
        Cartao {
            id: andamento
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.4)
            visible: janela.troca !== null
            readonly property var t: janela.troca
            readonly property bool ok: t !== null && t.fim && t.erro === 0
            implicitHeight: linhaTroca.implicitHeight + Math.round(janela.gu * 1.8)

            ColumnLayout {
                id: linhaTroca
                anchors.fill: parent
                anchors.margins: Math.round(janela.gu * 0.9)
                spacing: Math.round(janela.gu * 0.5)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.6)
                    Item {
                        Layout.preferredWidth: Math.round(janela.gu * 1.4)
                        Layout.preferredHeight: Layout.preferredWidth
                        Girando {
                            anchors.fill: parent
                            visible: andamento.t !== null && !andamento.t.fim
                        }
                        Kirigami.Icon {
                            anchors.fill: parent
                            visible: andamento.t !== null && andamento.t.fim
                            source: andamento.ok ? "matsu-certo-symbolic" : "matsu-alerta-symbolic"
                            isMask: true
                            color: andamento.ok ? pagina.verde : janela.frente
                        }
                    }
                    Texto {
                        Layout.fillWidth: true
                        font.weight: Font.DemiBold
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                        wrapMode: Text.WordWrap
                        text: {
                            var t = andamento.t;
                            if (!t)
                                return "";
                            if (!t.fim)
                                return janela.t("Baixando a nova versão do Matsu…", "Downloading the new Matsu version…");
                            if (t.erro === 0)
                                return janela.t("Pronto! Reinicie para entrar na versão nova", "Done! Restart to start the new version");
                            if (t.erro === 126 || t.erro === 127)
                                return janela.t("Cancelado: a senha não foi confirmada", "Cancelled: the password wasn't confirmed");
                            if (t.erro === 3)
                                return janela.t("Não há nada para trocar", "There's nothing to switch");
                            return janela.t("Não deu para trocar de versão", "Couldn't switch versions");
                        }
                    }
                }
                // O que o bootc está fazendo agora (as últimas linhas).
                Rectangle {
                    Layout.fillWidth: true
                    visible: andamento.t !== null && andamento.t.linhas.length > 0 && !andamento.ok
                    implicitHeight: linhas.implicitHeight + Math.round(janela.gu * 0.8)
                    radius: Math.round(janela.gu * 0.35)
                    color: janela.tinta(0.04)
                    Column {
                        id: linhas
                        x: Math.round(janela.gu * 0.5)
                        y: Math.round(janela.gu * 0.4)
                        width: parent.width - Math.round(janela.gu)
                        spacing: 2
                        Repeater {
                            model: andamento.t ? andamento.t.linhas : []
                            Texto {
                                required property string modelData
                                required property int index
                                width: parent.width
                                text: modelData
                                elide: Text.ElideMiddle
                                font.family: "monospace"
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: andamento.t && index === andamento.t.linhas.length - 1 ? 0.9 : 0.5
                            }
                        }
                    }
                }
                Texto {
                    Layout.fillWidth: true
                    visible: andamento.t !== null && andamento.t.fim && !andamento.ok
                    text: janela.t("Confira a internet e tente de novo. Nada mudou no seu sistema.", "Check the internet and try again. Nothing changed on your system.")
                    wrapMode: Text.WordWrap
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.65
                }
                RowLayout {
                    visible: andamento.t !== null && andamento.t.fim
                    spacing: Math.round(janela.gu * 0.4)
                    BotaoDestaque {
                        visible: andamento.ok
                        texto: janela.t("Reiniciar agora", "Restart now")
                        icone: "matsu-recarregar-symbolic"
                        onClicado: janela.reiniciar()
                    }
                    Botao {
                        visible: !andamento.ok
                        texto: janela.t("Fechar", "Close")
                        onClicado: janela.troca = null
                    }
                }
            }
        }

        // ----- a placa pede a outra versão do Matsu -----
        Cartao {
            id: oferta
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.4)
            visible: pagina.troca !== null && janela.troca === null
            readonly property bool instalar: pagina.troca !== null && pagina.troca.acao === "instalar-nvidia"
            readonly property color cor: instalar ? "#76b900" : janela.frente
            implicitHeight: linhaOferta.implicitHeight + Math.round(janela.gu * 2)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: janela.cartao }
                GradientStop { position: 1; color: Qt.rgba(oferta.cor.r, oferta.cor.g, oferta.cor.b, janela.escuro ? 0.1 : 0.08) }
            }
            RowLayout {
                id: linhaOferta
                anchors.fill: parent
                anchors.margins: Math.round(janela.gu * 1)
                spacing: Math.round(janela.gu * 0.9)
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: Math.round(janela.gu * 2.8)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: Math.round(width * 0.28)
                    color: Qt.rgba(oferta.cor.r, oferta.cor.g, oferta.cor.b, janela.escuro ? 0.16 : 0.12)
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.smallMedium
                        height: width
                        source: "matsu-baixar-symbolic"
                        isMask: true
                        color: oferta.cor
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.3)
                    Texto {
                        Layout.fillWidth: true
                        text: oferta.instalar ? janela.t("Instale o driver da NVIDIA", "Install the NVIDIA driver")
                                              : janela.t("Este computador não tem placa NVIDIA", "This computer has no NVIDIA card")
                        font.weight: Font.DemiBold
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
                        wrapMode: Text.WordWrap
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: oferta.instalar ? janela.t("Sua placa NVIDIA está com o driver livre (nouveau), que é bem mais lento nos jogos. O Matsu tem uma versão com o driver oficial da NVIDIA: ela é baixada inteira e entra quando você reiniciar.",
                                                         "Your NVIDIA card is on the free driver (nouveau), which is much slower in games. Matsu has a version with the official NVIDIA driver: it downloads in full and kicks in when you restart.")
                                              : janela.t("Você está na versão do Matsu com o driver da NVIDIA. A versão comum serve para AMD e Intel e recebe as mesmas atualizações.",
                                                         "You're on the Matsu version with the NVIDIA driver. The standard version covers AMD and Intel and gets the same updates.")
                        wrapMode: Text.WordWrap
                        opacity: 0.72
                    }
                    Texto {
                        Layout.fillWidth: true
                        visible: pagina.troca !== null && pagina.troca.aviso === "antiga"
                        text: janela.t("Esta placa é anterior às GTX 16 e RTX 20: o driver novo da NVIDIA pode não funcionar nela.",
                                       "This card is older than the GTX 16 and RTX 20 series: the new NVIDIA driver may not work on it.")
                        wrapMode: Text.WordWrap
                        color: pagina.laranja
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                    BotaoDestaque {
                        Layout.topMargin: Math.round(janela.gu * 0.3)
                        texto: oferta.instalar ? janela.t("Instalar o driver da NVIDIA", "Install the NVIDIA driver")
                                               : janela.t("Voltar para a versão comum", "Go back to the standard version")
                        icone: "matsu-baixar-symbolic"
                        onClicado: pagina.pedirTroca(pagina.troca, false)
                    }
                }
            }
        }

        // ----- cada placa -----
        Repeater {
            model: pagina.d ? pagina.d.placas : []

            Cartao {
                id: placa
                required property var modelData
                readonly property var p: modelData
                readonly property color cor: pagina.corMarca(p.marca)
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.3)
                implicitHeight: miolo.implicitHeight + Math.round(janela.gu * 1.8)

                ColumnLayout {
                    id: miolo
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.9)
                    spacing: Math.round(janela.gu * 0.7)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.8)
                        Rectangle {
                            Layout.preferredWidth: Math.round(janela.gu * 2.8)
                            Layout.preferredHeight: Layout.preferredWidth
                            radius: Math.round(width * 0.28)
                            color: Qt.rgba(placa.cor.r, placa.cor.g, placa.cor.b, janela.escuro ? 0.16 : 0.12)
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Kirigami.Units.iconSizes.smallMedium
                                height: width
                                source: "matsu-placa-symbolic"
                                isMask: true
                                color: placa.p.marca ? placa.cor : janela.frente
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Texto {
                                visible: placa.p.marca.length > 0
                                text: placa.p.marca
                                color: placa.cor
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                            Texto {
                                Layout.fillWidth: true
                                text: placa.p.nome
                                font.weight: Font.DemiBold
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
                                wrapMode: Text.WordWrap
                            }
                        }
                        Situacao {
                            visible: placa.p.tipo === "integrada" || placa.p.tipo === "dedicada" || placa.p.tipo === "virtual"
                            texto: placa.p.tipo === "integrada" ? janela.t("Integrada", "Integrated")
                                 : placa.p.tipo === "virtual" ? janela.t("Máquina virtual", "Virtual machine")
                                 : janela.t("Dedicada", "Dedicated")
                            cor: placa.p.tipo === "dedicada" ? placa.cor : janela.tinta(0.6)
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: coluna.width > janela.gu * 30 ? 3 : 1
                        columnSpacing: Math.round(janela.gu * 0.5)
                        rowSpacing: Math.round(janela.gu * 0.5)
                        Repeater {
                            model: [
                                { nome: janela.t("Driver em uso", "Driver in use"), valor: placa.p.driver_nome || janela.t("Nenhum", "None") },
                                { nome: janela.t("Versão", "Version"), valor: placa.p.versao || "—" },
                                { nome: "Vulkan", valor: placa.p.vulkan ? placa.p.vulkan.api + "  ·  " + pagina.nomeDriverVulkan(placa.p.vulkan) : janela.t("Não respondeu", "No answer") }
                            ]
                            Rectangle {
                                id: fato
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: Math.round(janela.gu * 2.9)
                                radius: Math.round(janela.gu * 0.35)
                                color: janela.tinta(0.035)
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(janela.gu * 0.6)
                                    anchors.rightMargin: Math.round(janela.gu * 0.6)
                                    anchors.topMargin: Math.round(janela.gu * 0.4)
                                    anchors.bottomMargin: Math.round(janela.gu * 0.4)
                                    spacing: 0
                                    Texto {
                                        text: fato.modelData.nome
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.6
                                    }
                                    Texto {
                                        Layout.fillWidth: true
                                        text: fato.modelData.valor
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ----- as peças dos jogos -----
        Texto {
            Layout.topMargin: Math.round(janela.gu * 0.9)
            visible: pagina.d !== null
            text: janela.t("Para os jogos", "For games")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
            font.weight: Font.DemiBold
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: pagina.d !== null
            spacing: 2
            LinhaOpcao {
                Layout.fillWidth: true
                visible: pagina.d !== null && pagina.d.mesa !== ""
                ultima: false
                icone: Qt.resolvedUrl("icones/driver.svg")
                nome: "Mesa"
                texto: janela.t("O driver das placas AMD e Intel.",
                                "The driver for AMD and Intel cards.")
                Valor { text: pagina.d ? pagina.d.mesa : "" }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                visible: pagina.d !== null && pagina.d.nvidia !== ""
                primeira: !(pagina.d && pagina.d.mesa !== "")
                ultima: false
                icone: Qt.resolvedUrl("icones/driver.svg")
                nome: janela.t("Driver da NVIDIA", "NVIDIA driver")
                texto: janela.t("O driver oficial, que vem na versão do Matsu para NVIDIA.", "The official driver, included in Matsu's NVIDIA version.")
                Valor { text: pagina.d ? pagina.d.nvidia : "" }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                ultima: false
                icone: "matsu-jogos-symbolic"
                nome: "Vulkan"
                texto: janela.t("Os jogos do Windows rodam nele (Proton).",
                                "Windows games run on it (Proton).")
                Valor {
                    text: pagina.d && pagina.d.vulkan.instancia ? pagina.d.vulkan.instancia
                        : (pagina.d && !pagina.d.vulkan.tem_vulkaninfo ? janela.t("Sem como conferir", "Can't check") : "—")
                    opacity: pagina.d && pagina.d.vulkan.instancia ? 1 : 0.6
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                ultima: false
                icone: "matsu-biblioteca-symbolic"
                nome: janela.t("Vulkan de 32 bits", "32-bit Vulkan")
                texto: pagina.d && pagina.d.vulkan32.ok ? janela.t("Para os jogos antigos e partes da Steam. ", "For older games and parts of Steam. ") + pagina.d.vulkan32.drivers.join(", ")
                       : janela.t("Falta: jogos antigos de 32 bits podem não abrir. Uma atualização do Matsu resolve.",
                                  "Missing: older 32-bit games may not start. A Matsu update fixes it.")
                Situacao {
                    texto: pagina.d && pagina.d.vulkan32.ok ? janela.t("Pronto", "Ready") : janela.t("Falta", "Missing")
                    cor: pagina.d && pagina.d.vulkan32.ok ? pagina.verde : pagina.laranja
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                visible: pagina.d !== null && pagina.d.opengl && pagina.d.opengl.api !== undefined && pagina.d.opengl.api !== ""
                primeira: false
                ultima: false
                icone: "matsu-tela-symbolic"
                nome: "OpenGL"
                texto: pagina.d && pagina.d.opengl && pagina.d.opengl.placa ? janela.t("Jogos nativos mais antigos. ", "Older native games. ") + pagina.d.opengl.placa : ""
                Valor { text: pagina.d && pagina.d.opengl ? (pagina.d.opengl.api || "") : "" }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                visible: pagina.temAmd
                primeira: false
                ultima: false
                icone: "matsu-relogio-symbolic"
                nome: "Anti-Lag"
                texto: pagina.d && pagina.d.anti_lag
                       ? janela.t("O driver da AMD tem o Anti-Lag: os jogos DirectX 12 pelo Proton (VKD3D-Proton) usam sozinhos.",
                                  "The AMD driver has Anti-Lag: DirectX 12 games through Proton (VKD3D-Proton) use it by themselves.")
                       : janela.t("Chega com o Mesa 26.3, numa atualização do Matsu. Até lá, ligue a Baixa latência em Gráficos.",
                                  "Arrives with Mesa 26.3, in a Matsu update. Until then, turn on Low latency in Graphics.")
                Situacao {
                    texto: pagina.d && pagina.d.anti_lag ? janela.t("Tem", "Available") : janela.t("Ainda não", "Not yet")
                    cor: pagina.d && pagina.d.anti_lag ? pagina.verde : janela.tinta(0.5)
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                icone: "matsu-engrenagem-symbolic"
                nome: janela.t("Núcleo do sistema (kernel)", "System core (kernel)")
                texto: janela.t("Onde mora a parte do driver que fala com a placa.", "Where the part of the driver that talks to the card lives.")
                Valor { text: pagina.d ? pagina.d.kernel.split("-")[0] : "" }
            }
        }

        // ----- atualização do driver -----
        Texto {
            Layout.topMargin: Math.round(janela.gu * 0.9)
            visible: pagina.d !== null
            text: janela.t("Atualização do driver", "Driver update")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
            font.weight: Font.DemiBold
        }
        Cartao {
            Layout.fillWidth: true
            visible: pagina.d !== null
            implicitHeight: linhaAtualiza.implicitHeight + Math.round(janela.gu * 1.6)
            RowLayout {
                id: linhaAtualiza
                anchors.fill: parent
                anchors.margins: Math.round(janela.gu * 0.8)
                spacing: Math.round(janela.gu * 0.8)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.25)
                    Row {
                        spacing: 7
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: 4
                            color: !pagina.a || pagina.a.tem === null ? janela.tinta(0.4)
                                 : (pagina.a.tem || pagina.a.pronta ? "#f5b330" : pagina.verde)
                        }
                        Texto {
                            text: janela.procurando ? janela.t("Procurando…", "Checking…")
                                : (!pagina.a ? janela.t("Ainda não conferido", "Not checked yet")
                                : (pagina.a.pronta ? janela.t("Atualização pronta: reinicie para usar", "Update ready: restart to use it")
                                : (pagina.a.tem ? janela.t("Tem atualização, com driver novo junto", "Update available, with a new driver")
                                : (pagina.a.tem === false ? janela.t("Tudo atualizado", "Everything up to date")
                                : janela.t("Sem internet para conferir", "No internet to check")))))
                            font.weight: Font.DemiBold
                        }
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: janela.t("Não precisa baixar driver de site: o Matsu testa o driver novo com o resto do sistema e entrega tudo junto, pelo app Atualizações.",
                                       "No need to download drivers from websites: Matsu tests the new driver with the rest of the system and delivers it all together, through the Updates app.")
                        wrapMode: Text.WordWrap
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.65
                    }
                }
                ColumnLayout {
                    spacing: Math.round(janela.gu * 0.3)
                    BotaoDestaque {
                        Layout.alignment: Qt.AlignRight
                        visible: !(pagina.a && pagina.a.tem === true && !pagina.a.pronta)
                        texto: janela.t("Procurar atualização", "Check for updates")
                        icone: "matsu-recarregar-symbolic"
                        estado: janela.procurando ? "carregando" : ""
                        onClicado: janela.procurarAtualizacao()
                    }
                    BotaoDestaque {
                        Layout.alignment: Qt.AlignRight
                        visible: pagina.a !== null && pagina.a.tem === true && !pagina.a.pronta
                        texto: janela.t("Atualizar agora", "Update now")
                        icone: "matsu-baixar-symbolic"
                        onClicado: janela.atualizarAgora()
                    }
                    Botao {
                        Layout.alignment: Qt.AlignRight
                        texto: janela.t("Abrir Atualizações", "Open Updates")
                        icone: "matsu-seta-symbolic"
                        iconeNoFim: true
                        onClicado: janela.atualizarAgora()
                    }
                }
            }
        }

        // ----- a versão do Matsu (e o caminho de volta) -----
        LinhaOpcao {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.5)
            visible: pagina.d !== null && pagina.d.imagem && pagina.d.imagem.nome !== ""
            icone: "matsu-info-symbolic"
            nome: janela.t("Versão do Matsu: ", "Matsu version: ") + (pagina.naNvidia ? janela.t("com o driver da NVIDIA", "with the NVIDIA driver") : janela.t("comum", "standard"))
            texto: pagina.d && pagina.d.imagem ? pagina.d.imagem.nome + (pagina.d.imagem.tag ? janela.t(", canal ", ", channel ") + pagina.d.imagem.tag : "") : ""
            Botao {
                visible: pagina.naNvidia && pagina.troca === null && pagina.outra !== null && janela.troca === null
                texto: janela.t("Voltar para a comum", "Back to standard")
                onClicado: pagina.pedirTroca(pagina.outra, true)
            }
        }
    }
}
