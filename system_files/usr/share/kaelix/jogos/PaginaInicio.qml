// Início da Central de jogos: o último jogo em destaque (o fundo grande e a logo
// dele, da Steam), os jogados recentemente e três cartões: modo jogo,
// sobreposição e placa de vídeo.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Flickable {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.4)
    readonly property var destaque: janela.jogos.length > 0 ? janela.jogos[0] : null
    readonly property bool jogandoDestaque: destaque !== null && janela.jogoAgora !== null && janela.jogoAgora !== undefined
                                            && janela.jogoAgora.id === destaque.id

    contentHeight: coluna.implicitHeight + 2 * margem
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

    ColumnLayout {
        id: coluna
        x: pagina.margem
        y: pagina.margem
        width: pagina.width - 2 * pagina.margem
        spacing: Math.round(janela.gu * 1.1)

        // ----- destaque: continuar jogando -----
        Item {
            id: heroi
            visible: pagina.destaque !== null
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(Math.max(janela.gu * 11, Math.min(janela.gu * 16, width * 0.28)))

            // Sem o fundo grande da Steam: um degradê do Kaelix.
            Rectangle {
                anchors.fill: parent
                radius: Math.round(janela.gu * 0.7)
                visible: fundo.status !== Image.Ready
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#2a1f4f" }
                    GradientStop { position: 0.6; color: "#6b2d6e" }
                    GradientStop { position: 1; color: "#c4497f" }
                }
            }
            ImagemRedonda {
                id: fundo
                anchors.fill: parent
                raio: Math.round(janela.gu * 0.7)
                horizontalAlignment: Image.AlignRight
                source: pagina.destaque && pagina.destaque.heroi ? janela.arquivo(pagina.destaque.heroi) : ""
                sombra: 0.4
            }
            // Escurece a esquerda, onde ficam a logo e os botões.
            Rectangle {
                anchors.fill: parent
                radius: Math.round(janela.gu * 0.7)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(0.04, 0.04, 0.05, 0.82) }
                    GradientStop { position: 0.45; color: Qt.rgba(0.04, 0.04, 0.05, 0.45) }
                    GradientStop { position: 0.8; color: Qt.rgba(0.04, 0.04, 0.05, 0.0) }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: Math.round(janela.gu * 0.7)
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: Math.round(janela.gu * 1.6)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width * 0.5, janela.gu * 22)
                spacing: Math.round(janela.gu * 0.55)

                Row {
                    spacing: 6
                    Rectangle {
                        visible: pagina.jogandoDestaque
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: "#7fcf6a"
                        SequentialAnimation on opacity {
                            running: pagina.jogandoDestaque
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                    Texto {
                        text: pagina.jogandoDestaque ? janela.t("JOGANDO AGORA", "PLAYING NOW") : janela.t("CONTINUAR JOGANDO", "CONTINUE PLAYING")
                        color: "#ffffff"
                        opacity: 0.78
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }
                }

                // A logo do jogo (da Steam); sem ela, o nome.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(janela.gu * (logo.status === Image.Ready ? 4.2 : 2.6))
                    Image {
                        id: logo
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        horizontalAlignment: Image.AlignLeft
                        verticalAlignment: Image.AlignBottom
                        asynchronous: true
                        mipmap: true
                        source: pagina.destaque && pagina.destaque.logo ? janela.arquivo(pagina.destaque.logo) : ""
                    }
                    Texto {
                        anchors.fill: parent
                        visible: logo.status !== Image.Ready
                        verticalAlignment: Text.AlignBottom
                        text: pagina.destaque ? pagina.destaque.nome : ""
                        color: "#ffffff"
                        elide: Text.ElideRight
                        font.pixelSize: Math.round(janela.gu * 1.75)
                        font.weight: Font.Bold
                    }
                }

                Texto {
                    Layout.fillWidth: true
                    text: pagina.destaque ? (janela.quando(pagina.destaque.ultima) + "  ·  " + janela.horas(pagina.destaque.minutos)
                                             + (pagina.destaque.minutos ? janela.t(" jogadas", " played") : "")) : ""
                    color: "#ffffff"
                    opacity: 0.82
                    elide: Text.ElideRight
                }

                Row {
                    Layout.topMargin: Math.round(janela.gu * 0.25)
                    spacing: Math.round(janela.gu * 0.5)

                    // Jogar: pílula branca, como o botão de jogar dos consoles.
                    MouseArea {
                        id: jogar
                        width: linhaJogar.implicitWidth + Math.round(janela.gu * 1.8)
                        height: Math.round(janela.gu * 2.2)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: pagina.destaque !== null && pagina.destaque.pronto !== false && !pagina.jogandoDestaque
                        opacity: enabled ? 1 : 0.6
                        scale: pressed ? 0.97 : 1
                        onClicked: janela.jogar(pagina.destaque.id)
                        Accessible.role: Accessible.Button
                        Accessible.name: janela.t("Jogar", "Play")
                        Behavior on scale {
                            NumberAnimation {
                                duration: 90
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: jogar.containsMouse ? "#ffffff" : "#f4f4f6"
                        }
                        Row {
                            id: linhaJogar
                            anchors.centerIn: parent
                            spacing: 7
                            Kirigami.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Kirigami.Units.iconSizes.small
                                height: width
                                source: pagina.jogandoDestaque ? "kaelix-jogos-symbolic" : "kaelix-jogar-symbolic"
                                isMask: true
                                color: "#141416"
                            }
                            Texto {
                                anchors.verticalCenter: parent.verticalCenter
                                text: pagina.jogandoDestaque ? janela.t("Jogando", "Playing") : janela.t("Jogar", "Play")
                                color: "#141416"
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    // O perfil deste jogo (abre o menu dos perfis).
                    MouseArea {
                        id: chipPerfil
                        readonly property string perfil: pagina.destaque ? (janela.perfilDoJogo(pagina.destaque.id) || (janela.conf ? janela.conf.perfil : "padrao")) : "padrao"
                        width: linhaPerfil.implicitWidth + Math.round(janela.gu * 1.4)
                        height: Math.round(janela.gu * 2.2)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menuPerfil.open()
                        Accessible.role: Accessible.ButtonMenu
                        Accessible.name: janela.t("Perfil gráfico: ", "Graphics profile: ") + janela.nomePerfil(perfil)
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, chipPerfil.containsMouse ? 0.24 : 0.16)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.22)
                        }
                        Row {
                            id: linhaPerfil
                            anchors.centerIn: parent
                            spacing: 6
                            Kirigami.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Kirigami.Units.iconSizes.small
                                height: width
                                source: janela.iconePerfil(chipPerfil.perfil)
                                isMask: true
                                color: "#ffffff"
                            }
                            Texto {
                                anchors.verticalCenter: parent.verticalCenter
                                text: janela.nomePerfil(chipPerfil.perfil)
                                color: "#ffffff"
                            }
                            Kirigami.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(Kirigami.Units.iconSizes.small * 0.8)
                                height: width
                                source: "kaelix-seta-symbolic"
                                rotation: 90
                                isMask: true
                                color: "#ffffff"
                                opacity: 0.8
                            }
                        }
                        MenuPerfil {
                            id: menuPerfil
                            y: parent.height + 6
                            jogoId: pagina.destaque ? pagina.destaque.id : ""
                        }
                    }
                }
            }
        }

        // ----- sem jogos ainda: boas-vindas -----
        Cartao {
            visible: janela.bibliotecaLida && pagina.destaque === null
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(janela.gu * 13)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: janela.escuro ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.7) }
                GradientStop { position: 1; color: janela.escuro ? Qt.rgba(0.94, 0.38, 0.62, 0.12) : Qt.rgba(0.94, 0.38, 0.62, 0.14) }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Math.round(janela.gu * 1.6)
                spacing: Math.round(janela.gu * 1.4)

                Kirigami.Icon {
                    Layout.preferredWidth: Math.round(janela.gu * 5.5)
                    Layout.preferredHeight: Layout.preferredWidth
                    source: "org.kaelix.jogos"
                    fallback: "applications-games"
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.4)
                    Texto {
                        Layout.fillWidth: true
                        text: janela.t("Seus jogos aparecem aqui", "Your games show up here")
                        font.pixelSize: Math.round(janela.gu * 1.3)
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: janela.t("Instale pela Steam e eles chegam sozinhos, com a capa, as horas jogadas e um perfil gráfico para cada um.",
                                       "Install them with Steam and they show up on their own, with the cover art, hours played and a graphics profile for each.")
                        wrapMode: Text.WordWrap
                        opacity: 0.7
                    }
                    BotaoDestaque {
                        Layout.topMargin: Math.round(janela.gu * 0.3)
                        texto: janela.t("Abrir a Steam", "Open Steam")
                        icone: "steam"
                        iconeColorido: true
                        onClicado: janela.abrirSteam()
                    }
                }
            }
        }

        // ----- jogados recentemente -----
        ColumnLayout {
            id: recentes
            readonly property int largura: Math.round(janela.gu * 6.6)
            readonly property int vao: Math.round(janela.gu * 1.1)
            readonly property int cabem: Math.max(1, Math.floor((coluna.width + vao) / (largura + vao)))
            readonly property var lista: janela.jogos.slice(1, 1 + cabem)
            visible: lista.length > 0
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.7)

            RowLayout {
                Layout.fillWidth: true
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Jogados recentemente", "Recently played")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
                    font.weight: Font.DemiBold
                }
                Botao {
                    texto: janela.t("Ver todos", "See all")
                    icone: "kaelix-seta-symbolic"
                    iconeNoFim: true
                    onClicado: janela.pagina = "jogos"
                }
            }
            Row {
                spacing: recentes.vao
                Repeater {
                    model: recentes.lista
                    Capa {
                        required property var modelData
                        width: recentes.largura
                        jogo: modelData
                        onAbrir: {
                            janela.jogoAberto = modelData.id;
                            janela.pagina = "jogos";
                        }
                        onJogar: janela.jogar(modelData.id)
                    }
                }
            }
        }

        // ----- modo jogo, sobreposição e placa de vídeo -----
        GridLayout {
            Layout.fillWidth: true
            columns: coluna.width > janela.gu * 40 ? 3 : 1
            columnSpacing: Math.round(janela.gu * 0.8)
            rowSpacing: Math.round(janela.gu * 0.8)

            CartaoResumo {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icone: "kaelix-jogos-symbolic"
                cor: janela.corPerfil("desempenho")
                nome: janela.t("Modo jogo", "Game mode")
                texto: {
                    var j = janela.jogoAgora;
                    if (j)
                        return janela.t("Ligado em ", "On for ") + j.nome + " · " + janela.nomePerfil(j.perfil);
                    if (janela.conf && !janela.conf.automatico)
                        return janela.t("Desligado. Os jogos abrem sem ajuste.", "Off. Games open untouched.");
                    return janela.t("Liga sozinho quando um jogo abre.", "Turns on by itself when a game opens.");
                }
                Chave {
                    ligada: janela.conf ? janela.conf.automatico : true
                    nome: janela.t("Modo jogo automático", "Automatic game mode")
                    onTrocada: (ligada) => janela.mudar("automatico", ligada)
                }
            }
            CartaoResumo {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icone: "kaelix-sobreposicao-symbolic"
                cor: janela.corPerfil("padrao")
                nome: janela.t("Sobreposição", "Overlay")
                texto: janela.t("FPS, CPU e GPU em cima do jogo. Shift direito + F12 mostra e esconde.",
                                "FPS, CPU and GPU on top of the game. Right Shift + F12 shows and hides it.")
                onClicado: janela.pagina = "sobreposicao"
                Chave {
                    ligada: janela.conf ? janela.conf.sobreposicao.ligada : false
                    nome: janela.t("Mostrar a sobreposição no jogo", "Show the overlay in games")
                    onTrocada: (ligada) => janela.mudar("sobreposicao.ligada", ligada)
                }
            }
            CartaoResumo {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icone: "kaelix-placa-symbolic"
                cor: janela.cores.gpu
                nome: janela.placa ? janela.placa.nome : janela.t("Placa de vídeo", "Graphics card")
                texto: {
                    var p = janela.placa;
                    if (!p)
                        return janela.t("Lendo a placa de vídeo...", "Reading the graphics card...");
                    var a = janela.atualizacao;
                    var estado = a && a.pronta ? janela.t("atualização pronta, reinicie", "update ready, restart")
                               : (a && a.tem ? janela.t("tem atualização", "update available")
                               : (a && a.tem === false ? janela.t("atualizado", "up to date") : ""));
                    return p.driver + (estado ? " · " + estado : "") + (p.temp > 0 ? " · " + p.temp + " °C" : "");
                }
                onClicado: janela.pagina = "placa"
                Kirigami.Icon {
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    source: "kaelix-seta-symbolic"
                    isMask: true
                    color: janela.frente
                    opacity: 0.6
                }
            }
        }
    }
}
