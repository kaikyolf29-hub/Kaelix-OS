// Atualização: a versão deste computador, o estado da busca por uma versão nova
// (com o botão para atualizar ou reiniciar) e o que há de novo nesta versão.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property var remota: janela.dados ? janela.dados.remota : null
    readonly property string versao: janela.dados ? janela.dados.versao : ""
    readonly property string edicao: janela.dados ? janela.dados.edicao : ""

    readonly property string tituloEstado: {
        switch (janela.estado) {
        case "lendo":
        case "procurando":
            return janela.t("Procurando atualização…", "Checking for updates…");
        case "disponivel":
            return janela.t("A versão " + remota.versao + " está disponível", "Version " + remota.versao + " is available");
        case "baixada":
            return remota ? janela.t("A versão " + remota.versao + " já foi baixada", "Version " + remota.versao + " is ready")
                          : janela.t("A atualização já foi baixada", "The update is ready");
        case "sem-internet":
            return janela.t("Não deu para procurar agora", "Couldn't check right now");
        default:
            return janela.t("Você está na versão mais nova", "You're up to date");
        }
    }
    readonly property string textoEstado: {
        switch (janela.estado) {
        case "lendo":
        case "procurando":
            return janela.t("Conferindo o canal do sistema, sem baixar nada.", "Looking at the system channel, without downloading anything.");
        case "disponivel":
            return janela.terminalAberto
                ? janela.t("O terminal abriu com a atualização. Ela entra quando você reiniciar.", "The terminal opened with the update. It takes effect after a restart.")
                : janela.t("A atualização é baixada inteira e só entra quando você reiniciar.", "The whole update downloads first and only takes effect after a restart.");
        case "baixada":
            return janela.t("Ela entra quando você reiniciar o computador.", "It takes effect when you restart the computer.");
        case "sem-internet":
            return janela.t("Confira a internet e tente de novo.", "Check the internet connection and try again.");
        default:
            var q = janela.quando(janela.dados ? janela.dados.procurado : 0);
            return q ? janela.t("Última busca: ", "Last checked: ") + q : "";
        }
    }
    readonly property string iconeEstado: ({
        "disponivel": "matsu-baixar-symbolic",
        "baixada": "matsu-recarregar-symbolic",
        "sem-internet": "matsu-alerta-symbolic",
        "em-dia": "matsu-certo-symbolic"
    })[janela.estado] || ""

    Flickable {
        id: rolagem
        anchors.fill: parent
        contentWidth: width
        contentHeight: coluna.implicitHeight + 2 * pagina.margem
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        QQC2.ScrollBar.vertical: BarraRolagem {}

        ColumnLayout {
            id: coluna
            width: Math.min(rolagem.width - 2 * pagina.margem, Math.round(janela.gu * 48))
            x: Math.round((rolagem.width - width) / 2)
            y: pagina.margem
            spacing: Math.round(janela.gu * 0.8)

            // ----- a versão deste computador -----
            Cartao {
                Layout.fillWidth: true
                implicitHeight: linhaVersao.implicitHeight + Math.round(janela.gu * 2.4)

                RowLayout {
                    id: linhaVersao
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 1.2)
                    spacing: Math.round(janela.gu * 1.1)

                    Item {
                        Layout.preferredWidth: Math.round(janela.gu * 4)
                        Layout.preferredHeight: Layout.preferredWidth
                        Kirigami.Icon {
                            id: logo
                            anchors.fill: parent
                            source: "matsu-logo"
                            scale: janela.dados ? 1 : 0.82
                            opacity: janela.dados ? 1 : 0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 420
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.6
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Kirigami.Units.longDuration
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Texto {
                            Layout.fillWidth: true
                            text: pagina.edicao ? "Matsu " + pagina.edicao + " OS" : "Matsu OS"
                            font.pixelSize: Math.round(janela.gu * 1.45)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Texto {
                            Layout.fillWidth: true
                            visible: pagina.versao !== ""
                            text: janela.t("Versão ", "Version ") + pagina.versao + "  ·  " + janela.t("Edição 20", "20") + pagina.edicao + janela.t("", " edition")
                            opacity: 0.72
                            elide: Text.ElideRight
                        }
                        Texto {
                            Layout.fillWidth: true
                            readonly property string data: janela.dataMontagem(janela.dados ? janela.dados.build : "")
                            visible: data !== ""
                            text: janela.t("Montada em ", "Built on ") + data
                            opacity: 0.5
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // ----- a busca por uma versão nova -----
            Cartao {
                id: cartaoEstado
                Layout.fillWidth: true
                implicitHeight: colunaEstado.implicitHeight + Math.round(janela.gu * 2.2)
                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }
                clip: true

                ColumnLayout {
                    id: colunaEstado
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Math.round(janela.gu * 1.1)
                    spacing: Math.round(janela.gu * 0.9)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.9)

                        // O símbolo do estado, num círculo; troca com um pulinho.
                        Rectangle {
                            Layout.preferredWidth: Math.round(janela.gu * 2.6)
                            Layout.preferredHeight: Layout.preferredWidth
                            radius: width / 2
                            color: janela.estado === "disponivel" ? janela.destaque : janela.tinta(0.07)
                            Behavior on color {
                                ColorAnimation {
                                    duration: Kirigami.Units.longDuration
                                }
                            }
                            Girando {
                                anchors.centerIn: parent
                                width: Math.round(janela.gu * 1.2)
                                height: width
                                visible: janela.estado === "lendo" || janela.estado === "procurando"
                            }
                            Kirigami.Icon {
                                id: simbolo
                                anchors.centerIn: parent
                                width: Kirigami.Units.iconSizes.smallMedium
                                height: width
                                source: pagina.iconeEstado
                                visible: source !== ""
                                isMask: true
                                color: janela.estado === "disponivel" ? janela.sobreDestaque : janela.frente
                                onSourceChanged: if (visible) pulo.restart()
                                SequentialAnimation {
                                    id: pulo
                                    NumberAnimation { target: simbolo; property: "scale"; from: 0.3; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Texto {
                                Layout.fillWidth: true
                                text: pagina.tituloEstado
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                            }
                            Texto {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: pagina.textoEstado
                                opacity: 0.65
                                wrapMode: Text.WordWrap
                            }
                        }
                        Botao {
                            visible: janela.estado === "em-dia" || janela.estado === "sem-internet"
                            texto: janela.estado === "em-dia" ? janela.t("Procurar de novo", "Check again") : janela.t("Tentar de novo", "Try again")
                            icone: "matsu-recarregar-symbolic"
                            onClicado: janela.procurar()
                        }
                        BotaoDestaque {
                            visible: janela.estado === "disponivel"
                            texto: janela.t("Atualizar agora", "Update now")
                            icone: "matsu-baixar-symbolic"
                            estado: janela.terminalAberto ? "feito" : ""
                            textoFeito: janela.t("Atualizando", "Updating")
                            onClicado: janela.atualizar()
                        }
                        BotaoDestaque {
                            visible: janela.estado === "baixada"
                            texto: janela.t("Reiniciar agora", "Restart now")
                            onClicado: janela.reiniciar()
                        }
                    }

                    // O que muda na versão nova (do rótulo da imagem).
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: janela.estado === "disponivel" && pagina.remota !== null && pagina.remota.novidades.length > 0
                        spacing: Math.round(janela.gu * 0.45)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: janela.tinta(0.08)
                        }
                        Texto {
                            Layout.topMargin: Math.round(janela.gu * 0.2)
                            text: pagina.remota ? janela.t("O que muda na " + pagina.remota.versao, "What's new in " + pagina.remota.versao) : ""
                            font.weight: Font.DemiBold
                            opacity: 0.8
                        }
                        Repeater {
                            model: pagina.remota ? pagina.remota.novidades : []
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(janela.gu * 0.6)
                                Rectangle {
                                    Layout.preferredWidth: 6
                                    Layout.preferredHeight: 6
                                    radius: 3
                                    color: janela.tinta(0.45)
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    text: modelData
                                    wrapMode: Text.WordWrap
                                    opacity: 0.85
                                }
                            }
                        }
                    }
                }
            }

            // ----- o que há de novo nesta versão -----
            Texto {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.8)
                visible: janela.atual !== null
                text: janela.atual ? janela.t("O que há de novo na versão ", "What's new in version ") + janela.atual.versao : ""
                font.pixelSize: Math.round(janela.gu * 1.15)
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
            Texto {
                Layout.fillWidth: true
                visible: text !== ""
                text: janela.atual ? janela.atual.resumo : ""
                opacity: 0.7
                wrapMode: Text.WordWrap
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.2)
                columns: coluna.width > janela.gu * 30 ? 2 : 1
                columnSpacing: Math.round(janela.gu * 0.7)
                rowSpacing: Math.round(janela.gu * 0.7)

                Repeater {
                    model: janela.atual ? janela.atual.itens : []
                    delegate: ItemNovidade {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        assunto: modelData.assunto
                        texto: modelData.texto
                        ordem: index
                    }
                }
            }

            Vazio {
                Layout.fillWidth: true
                Layout.topMargin: janela.gu
                visible: janela.dados !== null && janela.versoes.length === 0
                icone: "matsu-info-symbolic"
                titulo: janela.t("Sem notas desta versão", "No notes for this version")
                texto: janela.t("As novidades aparecem aqui quando o sistema traz o arquivo delas.", "Release notes show up here when the system includes them.")
            }
        }
    }
}
