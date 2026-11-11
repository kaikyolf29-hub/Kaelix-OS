// Detalhes de um jogo, por cima de Meus jogos: o fundo grande e a logo dele (da
// Steam), jogar, abrir na Steam, a pasta, as horas jogadas e o perfil gráfico
// só deste jogo.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: detalhe

    property var jogo: null
    // Guarda o último, para o desenho não sumir enquanto a tela fecha.
    property var mostrado: null
    onJogoChanged: if (jogo) mostrado = jogo

    signal fechar()

    readonly property bool aberto: jogo !== null
    readonly property bool jogando: mostrado !== null && janela.jogoAgora !== null && janela.jogoAgora !== undefined
                                    && janela.jogoAgora.id === mostrado.id
    readonly property string perfilProprio: mostrado ? janela.perfilDoJogo(mostrado.id) : ""
    readonly property string perfilValendo: perfilProprio || (janela.conf ? janela.conf.perfil : "padrao")

    visible: opacity > 0
    opacity: aberto ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutCubic
        }
    }
    focus: aberto
    Keys.onEscapePressed: detalhe.fechar()
    onAbertoChanged: if (aberto) forceActiveFocus()

    // Segura os cliques (para não abrir a capa de baixo).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (evento) => evento.accepted = true
    }

    Flickable {
        id: rolagem
        anchors.fill: parent
        contentHeight: conteudo.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

        ColumnLayout {
            id: conteudo
            width: rolagem.width
            spacing: 0

            // ----- o fundo grande, com a logo em cima -----
            // Os botões sobem um pouco por cima da parte que já está sumindo.
            Item {
                id: topo
                readonly property int sobra: Math.round(height * 0.13)
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Math.max(janela.gu * 11, Math.min(janela.gu * 17, width * 0.36)))

                // Sem o fundo grande, a capa; sem nada, o degradê do Kaelix. Tudo some
                // aos poucos embaixo, virando o vidro da janela.
                Rectangle {
                    anchors.fill: parent
                    visible: !heroi.pronta && !heroiCapa.pronta
                    topLeftRadius: Math.round(janela.gu * 0.5) - 1
                    opacity: 0.55
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#2a1f4f" }
                        GradientStop { position: 1; color: "#c4497f" }
                    }
                }
                ImagemRedonda {
                    id: heroiCapa
                    anchors.fill: parent
                    visible: !heroi.pronta
                    raioEmCima: Math.round(janela.gu * 0.5) - 1
                    raioEmBaixo: 0
                    esmaecer: 0.5
                    opacity: 0.7
                    source: detalhe.mostrado && !detalhe.mostrado.heroi && detalhe.mostrado.capa ? janela.arquivo(detalhe.mostrado.capa) : ""
                }
                ImagemRedonda {
                    id: heroi
                    anchors.fill: parent
                    raioEmCima: Math.round(janela.gu * 0.5) - 1
                    raioEmBaixo: 0
                    esmaecer: 0.45
                    source: detalhe.mostrado && detalhe.mostrado.heroi ? janela.arquivo(detalhe.mostrado.heroi) : ""
                }

                // Voltar.
                MouseArea {
                    id: voltar
                    x: Math.round(janela.gu * 1)
                    y: Math.round(janela.gu * 1)
                    width: linhaVoltar.implicitWidth + Math.round(janela.gu * 1.1)
                    height: Math.round(janela.gu * 1.9)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: detalhe.fechar()
                    Accessible.role: Accessible.Button
                    Accessible.name: janela.t("Voltar para Meus jogos", "Back to My games")
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Qt.rgba(0.06, 0.06, 0.07, voltar.containsMouse ? 0.7 : 0.5)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                    }
                    Row {
                        id: linhaVoltar
                        anchors.centerIn: parent
                        spacing: 4
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Kirigami.Units.iconSizes.small
                            height: width
                            source: "kaelix-seta-symbolic"
                            rotation: 180
                            isMask: true
                            color: "#ffffff"
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: janela.t("Meus jogos", "My games")
                            color: "#ffffff"
                        }
                    }
                }

                // A logo do jogo; sem ela, o nome grande. Fica onde o fundo ainda
                // está forte, com uma sombra macia em volta para ler em qualquer
                // imagem (e no tema claro, onde o fundo some no branco).
                Item {
                    id: caixaLogo
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Math.round(janela.gu * 1.6)
                    anchors.bottomMargin: topo.sobra + Math.round(janela.gu * 1.1)
                    width: Math.min(parent.width * 0.45, janela.gu * 20)
                    height: Math.round(janela.gu * 4.4)
                    visible: false
                    layer.enabled: true
                    Image {
                        id: logo
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        horizontalAlignment: Image.AlignLeft
                        verticalAlignment: Image.AlignBottom
                        asynchronous: true
                        mipmap: true
                        source: detalhe.mostrado && detalhe.mostrado.logo ? janela.arquivo(detalhe.mostrado.logo) : ""
                    }
                    Texto {
                        anchors.fill: parent
                        visible: logo.status !== Image.Ready
                        verticalAlignment: Text.AlignBottom
                        text: detalhe.mostrado ? detalhe.mostrado.nome : ""
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.pixelSize: Math.round(janela.gu * 1.9)
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                }
                MultiEffect {
                    source: caixaLogo
                    x: caixaLogo.x
                    y: caixaLogo.y
                    width: caixaLogo.width
                    height: caixaLogo.height
                    autoPaddingEnabled: false
                    paddingRect: Qt.rect(janela.gu * 2, janela.gu * 2, janela.gu * 2, janela.gu * 2)
                    shadowEnabled: true
                    shadowBlur: 1.0
                    shadowScale: 1.02
                    shadowVerticalOffset: 2
                    shadowHorizontalOffset: 0
                    shadowColor: Qt.rgba(0, 0, 0, janela.escuro ? 0.6 : 0.75)
                }
            }

            // ----- botões -----
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(janela.gu * 1.6)
                Layout.rightMargin: Math.round(janela.gu * 1.6)
                Layout.topMargin: -topo.sobra
                spacing: Math.round(janela.gu * 0.5)

                MouseArea {
                    id: jogar
                    implicitWidth: linhaJogar.implicitWidth + Math.round(janela.gu * 2.4)
                    implicitHeight: Math.round(janela.gu * 2.3)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: detalhe.mostrado !== null && detalhe.mostrado.pronto !== false && !detalhe.jogando
                    scale: pressed ? 0.97 : 1
                    onClicked: janela.jogar(detalhe.mostrado.id)
                    Accessible.role: Accessible.Button
                    Accessible.name: janela.t("Jogar", "Play")
                    Behavior on scale {
                        NumberAnimation {
                            duration: 90
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(janela.gu * 0.4)
                        color: janela.escuro ? (jogar.containsMouse ? "#ffffff" : "#f2f2f4") : (jogar.containsMouse ? "#2a2a2e" : "#1c1c1f")
                        opacity: jogar.enabled ? 1 : 0.55
                    }
                    Row {
                        id: linhaJogar
                        anchors.centerIn: parent
                        spacing: 8
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Kirigami.Units.iconSizes.small
                            height: width
                            source: detalhe.jogando ? "kaelix-jogos-symbolic" : "kaelix-jogar-symbolic"
                            isMask: true
                            color: janela.escuro ? "#141416" : "#ffffff"
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: detalhe.jogando ? janela.t("Jogando agora", "Playing now")
                                : (detalhe.mostrado && detalhe.mostrado.pronto === false ? janela.t("Atualizando na Steam", "Updating in Steam") : janela.t("Jogar", "Play"))
                            color: janela.escuro ? "#141416" : "#ffffff"
                            font.weight: Font.DemiBold
                        }
                    }
                }
                Botao {
                    texto: janela.t("Ver na Steam", "View in Steam")
                    icone: "steam"
                    iconeColorido: true
                    onClicado: janela.abrirSteam("steam://nav/games/details/" + detalhe.mostrado.id)
                }
                Botao {
                    texto: janela.t("Pasta do jogo", "Game folder")
                    icone: "kaelix-pasta-symbolic"
                    visible: detalhe.mostrado !== null && (detalhe.mostrado.pasta || "").length > 0
                    onClicado: janela.abrirPasta(detalhe.mostrado.pasta)
                }
                Item {
                    Layout.fillWidth: true
                }
            }

            // ----- números -----
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(janela.gu * 1.6)
                Layout.rightMargin: Math.round(janela.gu * 1.6)
                Layout.topMargin: Math.round(janela.gu * 1.2)
                spacing: Math.round(janela.gu * 0.8)

                Repeater {
                    model: detalhe.mostrado ? [
                        { icone: "kaelix-relogio-symbolic", nome: janela.t("Tempo jogado", "Time played"), valor: janela.horas(detalhe.mostrado.minutos) },
                        { icone: "kaelix-calendario-symbolic", nome: janela.t("Última vez", "Last played"), valor: janela.quando(detalhe.mostrado.ultima) },
                        { icone: "kaelix-disco-symbolic", nome: janela.t("Tamanho", "Size"), valor: detalhe.mostrado.tamanho > 0 ? janela.bytes(detalhe.mostrado.tamanho) : "—" }
                    ] : []

                    Cartao {
                        id: numero
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: Math.round(janela.gu * 3.6)
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Math.round(janela.gu * 0.8)
                            spacing: Math.round(janela.gu * 0.6)
                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: Layout.preferredWidth
                                source: numero.modelData.icone
                                isMask: true
                                color: janela.frente
                                opacity: 0.7
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Texto {
                                    Layout.fillWidth: true
                                    text: numero.modelData.nome
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.6
                                    elide: Text.ElideRight
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    text: numero.modelData.valor
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            // ----- perfil gráfico deste jogo -----
            Texto {
                Layout.leftMargin: Math.round(janela.gu * 1.6)
                Layout.topMargin: Math.round(janela.gu * 1.4)
                text: janela.t("Perfil gráfico deste jogo", "Graphics profile for this game")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
                font.weight: Font.DemiBold
            }
            Texto {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(janela.gu * 1.6)
                Layout.rightMargin: Math.round(janela.gu * 1.6)
                Layout.topMargin: 2
                text: janela.t("Liga sozinho quando o jogo abre e volta ao normal quando ele fecha.",
                               "Turns on by itself when the game opens and goes back to normal when it closes.")
                wrapMode: Text.WordWrap
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.6
            }
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(janela.gu * 1.6)
                Layout.rightMargin: Math.round(janela.gu * 1.6)
                Layout.topMargin: Math.round(janela.gu * 0.7)
                spacing: Math.round(janela.gu * 0.5)

                Repeater {
                    model: [""].concat(janela.perfis)

                    MouseArea {
                        id: chip
                        required property string modelData
                        readonly property bool escolhido: detalhe.perfilProprio === modelData
                        readonly property color cor: modelData ? janela.corPerfil(modelData) : janela.frente
                        width: linhaChip.implicitWidth + Math.round(janela.gu * 1.3)
                        height: Math.round(janela.gu * 2.2)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        activeFocusOnTab: true
                        onClicked: janela.escolherPerfilDoJogo(detalhe.mostrado.id, modelData)
                        Keys.onSpacePressed: janela.escolherPerfilDoJogo(detalhe.mostrado.id, modelData)
                        Accessible.role: Accessible.RadioButton
                        Accessible.checked: escolhido
                        Accessible.name: modelData ? janela.nomePerfil(modelData) : janela.t("Usar o geral", "Use the global one")
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: chip.escolhido ? Qt.rgba(chip.cor.r, chip.cor.g, chip.cor.b, janela.escuro ? 0.2 : 0.14)
                                                  : janela.tinta(chip.containsMouse ? 0.07 : 0.035)
                            border.width: chip.escolhido || chip.activeFocus ? 1.5 : 1
                            border.color: chip.escolhido ? chip.cor : (chip.activeFocus ? janela.frente : janela.tinta(0.1))
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
                            Kirigami.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Kirigami.Units.iconSizes.small
                                height: width
                                source: janela.iconePerfil(chip.modelData || (janela.conf ? janela.conf.perfil : "padrao"))
                                isMask: true
                                color: chip.modelData ? chip.cor : janela.frente
                                opacity: chip.modelData ? 1 : 0.6
                            }
                            Texto {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData ? janela.nomePerfil(chip.modelData)
                                    : janela.t("Usar o geral", "Global") + " (" + janela.nomePerfil(janela.conf ? janela.conf.perfil : "padrao") + ")"
                                font.weight: chip.escolhido ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }
            }
            // O que o perfil que vale para este jogo faz, numa linha.
            Texto {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(janela.gu * 1.6)
                Layout.rightMargin: Math.round(janela.gu * 1.6)
                Layout.topMargin: Math.round(janela.gu * 0.7)
                Layout.bottomMargin: Math.round(janela.gu * 1.6)
                text: {
                    var a = janela.ajustesDe(detalhe.perfilValendo);
                    var partes = [];
                    partes.push(({ manter: janela.t("energia do sistema", "system power"), economia: janela.t("energia econômica", "power saving"),
                                   equilibrado: janela.t("energia equilibrada", "balanced power"), desempenho: janela.t("energia no máximo", "max power") })[a.energia]);
                    if (a.placa !== "auto")
                        partes.push(a.placa === "maximo" ? janela.t("placa no máximo", "GPU at max") : janela.t("placa econômica", "GPU saving"));
                    if (a.fps > 0)
                        partes.push(janela.t("até ", "up to ") + a.fps + " FPS");
                    if (a.vsync !== "jogo")
                        partes.push(a.vsync === "ligada" ? janela.t("sem cortes na tela (V-Sync)", "no tearing (V-Sync)") : janela.t("V-Sync desligada", "V-Sync off"));
                    if (a.af > 0)
                        partes.push(janela.t("texturas nítidas ", "sharp textures ") + a.af + "x");
                    if (a.modo_jogo)
                        partes.push(janela.t("modo jogo", "game mode"));
                    var s = partes.join(" · ");
                    return janela.nomePerfil(detalhe.perfilValendo) + ": " + s.charAt(0).toLowerCase() + s.slice(1) + ".";
                }
                wrapMode: Text.WordWrap
                opacity: 0.72
            }
        }
    }
}
