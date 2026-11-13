// Na web: sites que viram app (Instagram, TikTok, YouTube, WhatsApp...). Cada um
// ganha atalho no menu com a logo oficial do site e abre numa janela própria,
// sem barra de endereço, pelo Brave ou pelo Chrome.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property int vao: Math.round(janela.gu * 0.8)
    readonly property var lista: janela.buscar(janela.busca.trim(), janela.sites)

    Flickable {
        id: rolagem
        anchors.fill: parent
        contentHeight: coluna.implicitHeight + pagina.margem
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        opacity: 1 - detalhe.opacity
        visible: opacity > 0
        QQC2.ScrollBar.vertical: BarraRolagem {}

        ColumnLayout {
            id: coluna
            x: pagina.margem
            width: rolagem.width - 2 * pagina.margem
            spacing: Math.round(janela.gu * 1.0)

            ColumnLayout {
                Layout.topMargin: Math.round(janela.gu * 0.9)
                Layout.fillWidth: true
                spacing: 1
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Sites como app", "Websites as apps")
                    font.pixelSize: Math.round(janela.gu * 1.3)
                    font.weight: Font.DemiBold
                }
                Texto {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: janela.t("Ganham atalho no menu e na barra, com a logo do site, e abrem numa janela própria (sem barra de endereço).",
                                   "They get a shortcut in the menu and on the bar, with the site's logo, and open in their own window (no address bar).")
                    opacity: 0.62
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }

            // Sem Brave nem Chrome: oferece o Brave (o navegador do Matsu).
            Cartao {
                Layout.fillWidth: true
                visible: janela.semNavegador
                implicitHeight: linhaNavegador.implicitHeight + Math.round(janela.gu * 1.6)
                RowLayout {
                    id: linhaNavegador
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.8)
                    spacing: Math.round(janela.gu * 0.7)
                    Kirigami.Icon {
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        source: "matsu-alerta-symbolic"
                        isMask: true
                        color: janela.escuro ? "#f5b26b" : "#b8621b"
                    }
                    Texto {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: janela.t("Para abrir sites como app, precisa do Brave ou do Chrome.",
                                       "To open websites as apps you need Brave or Chrome.")
                    }
                    BotaoDestaque {
                        texto: janela.t("Ver o Brave", "See Brave")
                        onClicado: janela.abrirApp("com.brave.Browser")
                    }
                }
            }

            Flow {
                id: grade
                Layout.fillWidth: true
                spacing: pagina.vao
                readonly property int colunas: Math.max(1, Math.floor((width + spacing) / (janela.gu * 19 + spacing)))
                readonly property int largura: Math.floor((width - (colunas - 1) * spacing) / colunas)

                Repeater {
                    model: pagina.lista

                    Rectangle {
                        id: cartao
                        required property var modelData
                        readonly property bool posto: janela.siteInstalado(modelData.id)
                        readonly property bool trabalhando: {
                            var _m = janela.mudancas;
                            return !!janela.tarefas["web:" + modelData.id];
                        }
                        width: grade.largura
                        height: Math.round(janela.gu * 5.4)
                        radius: Math.round(janela.gu * 0.6)
                        color: sobre.hovered ? (janela.escuro ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(1, 1, 1, 0.85)) : janela.cartao
                        border.width: 1
                        border.color: janela.tinta(sobre.hovered ? 0.13 : (janela.escuro ? 0.07 : 0.08))
                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                        HoverHandler {
                            id: sobre
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Math.round(janela.gu * 0.8)
                            spacing: Math.round(janela.gu * 0.7)
                            IconeSite {
                                Layout.preferredWidth: Math.round(janela.gu * 3.2)
                                Layout.preferredHeight: Layout.preferredWidth
                                site: cartao.modelData
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Texto {
                                    Layout.fillWidth: true
                                    text: cartao.modelData.nome
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    text: cartao.modelData.resumo
                                    opacity: 0.65
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                                }
                            }
                            Girando {
                                visible: cartao.trabalhando
                                Layout.preferredWidth: Math.round(janela.gu * 1.2)
                                Layout.preferredHeight: Layout.preferredWidth
                            }
                            Botao {
                                visible: cartao.posto && !cartao.trabalhando
                                icone: "matsu-lixeira-symbolic"
                                dica: janela.t("Tirar do menu", "Remove from the menu")
                                onClicado: janela.tirarSite(cartao.modelData.id)
                            }
                            Botao {
                                visible: cartao.posto && !cartao.trabalhando
                                texto: janela.t("Abrir", "Open")
                                onClicado: janela.abrirSite(cartao.modelData.id)
                            }
                            BotaoDestaque {
                                visible: !cartao.posto && !cartao.trabalhando
                                texto: janela.t("Adicionar", "Add")
                                icone: "matsu-mais-symbolic"
                                onClicado: janela.adicionarSite(cartao.modelData.id)
                            }
                        }
                    }
                }
            }

            Texto {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 2)
                visible: pagina.lista.length === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.75
                text: janela.t("Nenhum site com esse nome por aqui.", "No website with that name here.")
            }
        }
    }

    DetalheApp {
        id: detalhe
        anchors.fill: parent
    }
}
