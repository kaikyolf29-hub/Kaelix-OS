// Gráficos: o perfil que vale para todos os jogos (cada jogo pode ter o seu em
// Meus jogos), como os perfis do AMD Software. Embaixo, o que o perfil escolhido
// faz; mexer em qualquer ajuste de um perfil pronto passa para o Personalizado.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Flickable {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.4)
    readonly property string perfil: janela.conf ? janela.conf.perfil : "padrao"
    readonly property var ajustes: janela.ajustesDe(perfil)
    readonly property bool amd: janela.placa !== null && janela.placa.nivel_mudavel === true

    // Mexer num ajuste: no perfil pronto, vira Personalizado com os valores dele.
    function ajustar(chave, valor) {
        var nova = janela.copia(janela.conf);
        if (nova.perfil !== "personalizado")
            nova.personalizado = janela.copia(janela.ajustesDe(nova.perfil));
        nova.personalizado[chave] = valor;
        nova.perfil = "personalizado";
        janela.salvar(nova);
    }

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
            text: janela.t("Perfil gráfico", "Graphics profile")
            font.pixelSize: Math.round(janela.gu * 1.3)
            font.weight: Font.DemiBold
        }
        Texto {
            Layout.fillWidth: true
            text: janela.t("Vale para todos os jogos e liga sozinho quando um jogo abre. Cada jogo pode ter o seu, em Meus jogos.",
                           "Applies to every game and turns on by itself when a game opens. Each game can have its own, in My games.")
            wrapMode: Text.WordWrap
            opacity: 0.65
        }

        // ----- os cinco perfis -----
        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.6)
            columns: coluna.width > janela.gu * 44 ? 5 : (coluna.width > janela.gu * 27 ? 3 : 2)
            columnSpacing: Math.round(janela.gu * 0.6)
            rowSpacing: Math.round(janela.gu * 0.6)

            Repeater {
                model: janela.perfis

                MouseArea {
                    id: cartao
                    required property string modelData
                    readonly property bool escolhido: pagina.perfil === modelData
                    readonly property color cor: janela.corPerfil(modelData)
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: Math.round(janela.gu * 7.6)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    activeFocusOnTab: true
                    onClicked: janela.mudar("perfil", modelData)
                    Keys.onSpacePressed: janela.mudar("perfil", modelData)
                    Keys.onReturnPressed: janela.mudar("perfil", modelData)
                    Accessible.role: Accessible.RadioButton
                    Accessible.checked: escolhido
                    Accessible.name: janela.nomePerfil(modelData)
                    Accessible.description: janela.textoPerfil(modelData)
                    scale: pressed ? 0.98 : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: 90
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(janela.gu * 0.55)
                        color: cartao.escolhido ? Qt.rgba(cartao.cor.r, cartao.cor.g, cartao.cor.b, janela.escuro ? 0.13 : 0.1)
                                                : (cartao.containsMouse ? Qt.rgba(janela.cartao.r, janela.cartao.g, janela.cartao.b, Math.min(1, janela.cartao.a * 1.7)) : janela.cartao)
                        border.width: cartao.escolhido ? 1.5 : 1
                        border.color: cartao.escolhido ? cartao.cor : (cartao.activeFocus ? janela.frente : janela.bordaCartao)
                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                    }
                    // Marquinha de escolhido, no canto.
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Math.round(janela.gu * 0.55)
                        width: Math.round(janela.gu * 1.1)
                        height: width
                        radius: width / 2
                        color: cartao.cor
                        scale: cartao.escolhido ? 1 : 0
                        Behavior on scale {
                            NumberAnimation {
                                duration: Kirigami.Units.longDuration
                                easing.type: Easing.OutBack
                            }
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.75)
                            height: width
                            source: "matsu-certo-symbolic"
                            isMask: true
                            color: "#ffffff"
                        }
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(janela.gu * 0.8)
                        spacing: Math.round(janela.gu * 0.3)
                        Rectangle {
                            Layout.preferredWidth: Math.round(janela.gu * 2.2)
                            Layout.preferredHeight: Layout.preferredWidth
                            radius: Math.round(width * 0.32)
                            color: Qt.rgba(cartao.cor.r, cartao.cor.g, cartao.cor.b, janela.escuro ? 0.2 : 0.15)
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Kirigami.Units.iconSizes.small
                                height: width
                                source: janela.iconePerfil(cartao.modelData)
                                isMask: true
                                color: cartao.cor
                            }
                        }
                        Texto {
                            Layout.fillWidth: true
                            Layout.topMargin: Math.round(janela.gu * 0.35)
                            text: janela.nomePerfil(cartao.modelData)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: janela.textoPerfil(cartao.modelData)
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.62
                        }
                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }
        }

        // ----- o que o perfil faz -----
        Texto {
            Layout.topMargin: Math.round(janela.gu * 1.2)
            text: janela.t("Ajustes do perfil ", "Settings for ") + janela.nomePerfil(pagina.perfil)
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
            font.weight: Font.DemiBold
        }
        Texto {
            Layout.fillWidth: true
            visible: pagina.perfil !== "personalizado"
            text: janela.t("Mudou algum? O perfil vira Personalizado, com o resto igual.",
                           "Changed one? The profile becomes Custom, keeping the rest.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.6
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.3)
            spacing: 2

            LinhaOpcao {
                Layout.fillWidth: true
                ultima: false
                icone: "matsu-raio-symbolic"
                nome: janela.t("Energia", "Power")
                texto: janela.t("O perfil de energia do computador enquanto o jogo está aberto.", "The computer's power profile while the game is open.")
                Seletor {
                    opcoes: [{ id: "manter", nome: janela.t("Do sistema", "System") }, { id: "economia", nome: janela.t("Economia", "Saving") },
                             { id: "equilibrado", nome: janela.t("Equilibrada", "Balanced") }, { id: "desempenho", nome: janela.t("Máxima", "Max") }]
                    escolhido: pagina.ajustes.energia
                    onEscolher: (id) => pagina.ajustar("energia", id)
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                ultima: false
                icone: "matsu-placa-symbolic"
                nome: janela.t("Placa de vídeo", "Graphics card")
                texto: pagina.amd ? janela.t("Máxima: sempre na velocidade mais alta. Econômica: na mais baixa, só para jogos leves.",
                                             "Max: always at top speed. Saving: at the lowest, for light games only.")
                                  : janela.t("Nesta placa, o próprio driver cuida da velocidade.", "On this card, the driver handles the speed itself.")
                Seletor {
                    ativo: pagina.amd
                    opcoes: [{ id: "auto", nome: janela.t("Automática", "Auto") }, { id: "economia", nome: janela.t("Econômica", "Saving") },
                             { id: "maximo", nome: janela.t("Máxima", "Max") }]
                    escolhido: pagina.ajustes.placa
                    onEscolher: (id) => pagina.ajustar("placa", id)
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                ultima: false
                icone: "matsu-desempenho-symbolic"
                nome: janela.t("Limite de FPS", "Frame rate limit")
                texto: janela.t("Segura os quadros por segundo: a placa esquenta menos e faz menos barulho. Muda na hora, até com o jogo aberto.",
                                "Caps frames per second: the card runs cooler and quieter. Changes right away, even mid-game.")
                Passos {
                    nome: janela.t("Limite de FPS", "Frame rate limit")
                    opcoes: [{ id: 0, nome: janela.t("Sem limite", "No limit") }, { id: 30, nome: "30 FPS" }, { id: 40, nome: "40 FPS" },
                             { id: 45, nome: "45 FPS" }, { id: 60, nome: "60 FPS" }, { id: 75, nome: "75 FPS" }, { id: 90, nome: "90 FPS" },
                             { id: 120, nome: "120 FPS" }, { id: 144, nome: "144 FPS" }, { id: 165, nome: "165 FPS" }, { id: 240, nome: "240 FPS" }]
                    escolhido: pagina.ajustes.fps
                    onEscolher: (id) => pagina.ajustar("fps", id)
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                ultima: false
                icone: "matsu-sincronia-symbolic"
                nome: janela.t("Sincronia vertical (V-Sync)", "Vertical sync (V-Sync)")
                texto: janela.t("Ligada, a imagem não corta ao meio. Desligada, responde mais rápido. Vale ao abrir o jogo.",
                                "On, the picture never tears. Off, it responds faster. Applies when the game starts.")
                Seletor {
                    opcoes: [{ id: "jogo", nome: janela.t("Do jogo", "Game's") }, { id: "ligada", nome: janela.t("Ligada", "On") },
                             { id: "desligada", nome: janela.t("Desligada", "Off") }]
                    escolhido: pagina.ajustes.vsync
                    onEscolher: (id) => pagina.ajustar("vsync", id)
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                ultima: false
                icone: "matsu-textura-symbolic"
                nome: janela.t("Texturas nítidas", "Sharp textures")
                texto: janela.t("Filtro anisotrópico: o chão e as paredes de lado ficam nítidos, não borrados. Vale ao abrir o jogo.",
                                "Anisotropic filtering: floors and walls at an angle stay sharp, not blurry. Applies when the game starts.")
                Passos {
                    nome: janela.t("Texturas nítidas", "Sharp textures")
                    opcoes: [{ id: 0, nome: janela.t("Do jogo", "Game's") }, { id: 2, nome: "2x" }, { id: 4, nome: "4x" }, { id: 8, nome: "8x" }, { id: 16, nome: "16x" }]
                    escolhido: pagina.ajustes.af
                    onEscolher: (id) => pagina.ajustar("af", id)
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                ultima: false
                icone: "matsu-relogio-symbolic"
                nome: janela.t("Baixa latência", "Low latency")
                texto: janela.t("Menos atraso entre o comando e a tela nos jogos DirectX 9, 10 e 11 pelo Proton (vale ao abrir o jogo). Com limite de FPS, o limite segura o quadro do jeito com menos atraso.",
                                "Less delay between input and screen in DirectX 9, 10 and 11 games through Proton (applies when the game starts). With a frame rate limit, the limit holds frames the lowest-latency way.")
                Chave {
                    ligada: pagina.ajustes.latencia === true
                    nome: janela.t("Baixa latência", "Low latency")
                    onTrocada: (ligada) => pagina.ajustar("latencia", ligada)
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                icone: "matsu-jogos-symbolic"
                nome: janela.t("Modo jogo (GameMode)", "Game mode (GameMode)")
                texto: janela.t("O jogo ganha a preferência do processador e a tela não apaga no meio da partida.",
                                "The game gets CPU priority and the screen never dims mid-match.")
                Chave {
                    ligada: pagina.ajustes.modo_jogo
                    nome: janela.t("Modo jogo", "Game mode")
                    onTrocada: (ligada) => pagina.ajustar("modo_jogo", ligada)
                }
            }
        }

        // ----- automático -----
        Texto {
            Layout.topMargin: Math.round(janela.gu * 1.2)
            text: janela.t("Automático", "Automatic")
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
                icone: "matsu-jogar-symbolic"
                nome: janela.t("Ligar sozinho quando um jogo abre", "Turn on by itself when a game opens")
                texto: janela.t("Jogos da Steam e do Windows (Heroic, Lutris). Quando o jogo fecha, tudo volta ao normal.",
                                "Steam and Windows games (Heroic, Lutris). When the game closes, everything goes back to normal.")
                Chave {
                    ligada: janela.conf ? janela.conf.automatico : true
                    nome: janela.t("Ligar sozinho quando um jogo abre", "Turn on by itself when a game opens")
                    onTrocada: (ligada) => janela.mudar("automatico", ligada)
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                primeira: false
                icone: "matsu-sino-symbolic"
                nome: janela.t("Avisar quando o modo jogo ligar", "Notify when game mode turns on")
                texto: janela.t("Um aviso pequeno com o perfil que ligou.", "A small notice with the profile that turned on.")
                Chave {
                    ligada: janela.conf ? janela.conf.avisar : true
                    nome: janela.t("Avisar quando o modo jogo ligar", "Notify when game mode turns on")
                    onTrocada: (ligada) => janela.mudar("avisar", ligada)
                }
            }
        }
    }
}
