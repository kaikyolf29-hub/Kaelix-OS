// Painel de ajustes da Câmera, que entra pela direita do palco: qual câmera, a
// resolução, o temporizador, a grade, o espelho, o som do obturador e o
// microfone dos vídeos. Os ajustes ficam guardados (Main.qml grava).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Rectangle {
    id: painel

    signal fechar()

    readonly property bool livre: janela.estado !== "gravando"

    // Título pequeno de cada grupo de ajustes.
    component Secao: Texto {
        Layout.fillWidth: true
        Layout.topMargin: Math.round(janela.gu * 0.7)
        Layout.bottomMargin: Math.round(janela.gu * 0.25)
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        font.weight: Font.DemiBold
        opacity: 0.6
    }

    color: janela.fundoPalco

    // Linha fina separando do visor.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Math.round(janela.gu * 0.6)
        anchors.bottomMargin: Math.round(janela.gu * 0.6)
        width: 1
        color: janela.tinta(janela.escuro ? 0.08 : 0.1)
    }

    // Os cliques no painel não passam para o visor que está embaixo.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onWheel: (evento) => evento.accepted = false
    }

    RowLayout {
        id: cabeca
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Math.round(janela.gu * 0.7)
        anchors.leftMargin: Math.round(janela.gu * 1.1)
        anchors.rightMargin: Math.round(janela.gu * 0.6)
        spacing: Math.round(janela.gu * 0.4)
        Texto {
            Layout.fillWidth: true
            text: janela.t("Ajustes", "Settings")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Botao {
            icone: "matsu-fechar-symbolic"
            dica: janela.t("Fechar (Esc)", "Close (Esc)")
            onClicado: painel.fechar()
        }
    }

    Flickable {
        id: rolagem
        anchors.top: cabeca.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Math.round(janela.gu * 0.5)
        contentHeight: coluna.implicitHeight + Math.round(janela.gu * 1.2)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: BarraRolagem {}

        ColumnLayout {
            id: coluna
            x: Math.round(janela.gu * 1.1)
            width: rolagem.width - Math.round(janela.gu * 1.9)
            spacing: 2

            Secao {
                Layout.topMargin: 0
                text: janela.t("Imagem", "Picture")
            }
            LinhaEscolha {
                Layout.fillWidth: true
                icone: Qt.resolvedUrl("icones/camera.svg")
                nome: janela.t("Câmera", "Camera")
                texto: janela.cameras.length === 1 ? janela.cameras[0].nome
                     : janela.cameras.length === 0 ? janela.t("Nenhuma câmera ligada", "No camera connected") : ""
                ultima: false
                Suspensa {
                    Layout.fillWidth: true
                    visible: janela.cameras.length > 1
                    nome: janela.t("Câmera", "Camera")
                    ativo: painel.livre
                    opcoes: janela.cameras.map(c => ({ id: c.id, nome: c.nome }))
                    escolhido: janela.cameraAtual ? janela.cameraAtual.id : ""
                    onEscolher: (id) => janela.escolherCamera(id)
                }
            }
            LinhaEscolha {
                Layout.fillWidth: true
                icone: "matsu-qualidade-symbolic"
                nome: janela.t("Resolução", "Resolution")
                texto: janela.t("Vale para as fotos e os vídeos.", "Used for photos and videos.")
                primeira: false
                ultima: false
                Suspensa {
                    Layout.fillWidth: true
                    nome: janela.t("Resolução", "Resolution")
                    ativo: painel.livre && janela.resolucoes.length > 1
                    opcoes: janela.resolucoes
                    escolhido: janela.resolucaoEscolhida
                    onEscolher: (id) => janela.escolherResolucao(id)
                }
            }
            LinhaEscolha {
                Layout.fillWidth: true
                icone: Qt.resolvedUrl("icones/temporizador.svg")
                nome: janela.t("Temporizador", "Timer")
                texto: janela.t("Conta antes de tirar a foto ou começar o vídeo (T).", "Counts down before the photo or video (T).")
                primeira: false
                ultima: false
                Seletor {
                    Layout.fillWidth: true
                    opcoes: [
                        { id: "0", nome: janela.t("Desligado", "Off") },
                        { id: "3", nome: "3 s" },
                        { id: "10", nome: "10 s" }
                    ]
                    escolhido: String(janela.temporizador)
                    onEscolher: (id) => janela.temporizador = Number(id)
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                icone: Qt.resolvedUrl("icones/grade.svg")
                nome: janela.t("Grade de terços", "Rule of thirds grid")
                texto: janela.t("Ajuda a enquadrar (G).", "Helps framing (G).")
                primeira: false
                ultima: false
                Chave {
                    nome: janela.t("Grade de terços", "Rule of thirds grid")
                    ligada: janela.grade
                    onTrocada: (l) => janela.grade = l
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                icone: Qt.resolvedUrl("icones/espelhar.svg")
                nome: janela.t("Espelhar a imagem", "Mirror the picture")
                texto: janela.t("Só na tela: a foto e o vídeo saem como os outros te veem.", "On screen only: photos and videos are saved the way others see you.")
                primeira: false
                ultima: false
                Chave {
                    nome: janela.t("Espelhar a imagem", "Mirror the picture")
                    ligada: janela.espelhar
                    onTrocada: (l) => janela.espelhar = l
                }
            }
            LinhaOpcao {
                Layout.fillWidth: true
                icone: "matsu-volume-2-symbolic"
                nome: janela.t("Som do obturador", "Shutter sound")
                primeira: false
                Chave {
                    nome: janela.t("Som do obturador", "Shutter sound")
                    ligada: janela.somObturador
                    onTrocada: (l) => janela.somObturador = l
                }
            }

            Secao {
                text: janela.t("Vídeo", "Video")
            }
            LinhaOpcao {
                Layout.fillWidth: true
                icone: Qt.resolvedUrl(janela.gravarSom && janela.microfones.length > 0 ? "icones/microfone.svg" : "icones/microfone-mudo.svg")
                nome: janela.t("Gravar o som", "Record sound")
                texto: janela.microfones.length === 0 ? janela.t("Nenhum microfone encontrado.", "No microphone found.")
                     : janela.microfones.length === 1 ? janela.microfones[0].nome : ""
                ultima: !microfone.visible
                Chave {
                    nome: janela.t("Gravar o som", "Record sound")
                    enabled: painel.livre && janela.microfones.length > 0
                    opacity: enabled ? 1 : 0.45
                    ligada: janela.gravarSom && janela.microfones.length > 0
                    onTrocada: (l) => janela.gravarSom = l
                }
            }
            LinhaEscolha {
                id: microfone
                Layout.fillWidth: true
                visible: janela.microfones.length > 1 && janela.gravarSom
                icone: Qt.resolvedUrl("icones/microfone.svg")
                nome: janela.t("Microfone", "Microphone")
                primeira: false
                Suspensa {
                    Layout.fillWidth: true
                    nome: janela.t("Microfone", "Microphone")
                    ativo: painel.livre
                    opcoes: janela.microfones.map(m => ({ id: m.id, nome: m.nome }))
                    escolhido: janela.microfoneAtual ? janela.microfoneAtual.id : ""
                    onEscolher: (id) => janela.microfoneEscolhido = id
                }
            }

            Secao {
                text: janela.t("Onde ficam", "Where they go")
            }
            Cartao {
                Layout.fillWidth: true
                implicitHeight: pastas.implicitHeight + Math.round(janela.gu * 0.8)
                ColumnLayout {
                    id: pastas
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.4)
                    spacing: 2
                    Repeater {
                        model: [
                            { nome: janela.t("Fotos", "Photos"), pasta: janela.pastaFotos, icone: "icones/camera.svg" },
                            { nome: janela.t("Vídeos", "Videos"), pasta: janela.pastaVideos, icone: "icones/video.svg" }
                        ]
                        MouseArea {
                            id: linhaPasta
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: Math.round(janela.gu * 2.3)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: modelData.pasta !== ""
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: janela.t("Abrir a pasta ", "Open folder ") + modelData.nome
                            onClicked: janela.abrirPasta(modelData.pasta)
                            Keys.onReturnPressed: janela.abrirPasta(modelData.pasta)
                            Rectangle {
                                anchors.fill: parent
                                radius: Math.round(janela.gu * 0.35)
                                color: janela.tinta(linhaPasta.pressed ? 0.09 : (linhaPasta.containsMouse ? 0.055 : 0))
                                border.width: linhaPasta.activeFocus ? 1 : 0
                                border.color: janela.destaque
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Kirigami.Units.shortDuration
                                    }
                                }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(janela.gu * 0.5)
                                anchors.rightMargin: Math.round(janela.gu * 0.5)
                                spacing: Math.round(janela.gu * 0.6)
                                Kirigami.Icon {
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                    source: Qt.resolvedUrl(linhaPasta.modelData.icone)
                                    isMask: true
                                    color: janela.frente
                                    opacity: 0.85
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Texto {
                                        Layout.fillWidth: true
                                        text: linhaPasta.modelData.nome
                                        elide: Text.ElideRight
                                    }
                                    Texto {
                                        Layout.fillWidth: true
                                        text: janela.curto(linhaPasta.modelData.pasta)
                                        elide: Text.ElideMiddle
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.6
                                    }
                                }
                                Kirigami.Icon {
                                    Layout.preferredWidth: Math.round(Kirigami.Units.iconSizes.small * 0.85)
                                    Layout.preferredHeight: Layout.preferredWidth
                                    source: Qt.resolvedUrl("icones/abrir.svg")
                                    isMask: true
                                    color: janela.frente
                                    opacity: linhaPasta.containsMouse ? 0.85 : 0.45
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Kirigami.Units.shortDuration
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Texto {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.8)
                text: janela.t("Espaço ou Enter dispara · F troca foto e vídeo · T muda o temporizador",
                               "Space or Enter shoots · F switches photo and video · T changes the timer")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
            }
        }
    }
}
