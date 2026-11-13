// Início da Loja: a vitrine dos destaques, as seções escolhidas pelo Matsu (com
// "Ver tudo"), os sites que viram app e as categorias para explorar.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)

    function verSecao(id) {
        janela.irPara("apps");
        janela.secao = id;
        janela.categoria = "";
    }
    function verCategoria(c) {
        janela.irPara(c === "jogos" ? "jogos" : "apps");
        janela.secao = "";
        janela.categoria = c === "jogos" ? "" : c;
    }

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
            spacing: Math.round(janela.gu * 1.4)

            Item {
                Layout.preferredHeight: Math.round(janela.gu * 0.2)
            }

            // ----- a vitrine (ou o lugar dela enquanto o catálogo chega) -----
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Math.max(janela.gu * 12, Math.min(janela.gu * 16, width * 0.32)))
                visible: !janela.lido || janela.destaques.length > 0
                Esqueleto {
                    anchors.fill: parent
                    raio: Math.round(janela.gu * 0.8)
                    visible: !janela.lido
                }
                Vitrine {
                    anchors.fill: parent
                    visible: janela.lido
                    lista: janela.destaques
                }
            }

            // ----- avisos do catálogo -----
            Cartao {
                Layout.fillWidth: true
                visible: janela.lido && (janela.baixandoCatalogo || janela.semCatalogo) && janela.apps.length === 0
                implicitHeight: linhaAviso.implicitHeight + Math.round(janela.gu * 1.6)
                RowLayout {
                    id: linhaAviso
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.8)
                    spacing: Math.round(janela.gu * 0.7)
                    Girando {
                        visible: !janela.semCatalogo
                        Layout.preferredWidth: Math.round(janela.gu * 1.4)
                        Layout.preferredHeight: Layout.preferredWidth
                    }
                    Kirigami.Icon {
                        visible: janela.semCatalogo
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        source: "matsu-rede-desconectada-symbolic"
                        isMask: true
                        color: janela.frente
                    }
                    Texto {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: janela.semCatalogo
                              ? janela.t("Sem internet agora: os apps aparecem aqui assim que o computador conectar.",
                                         "No internet right now: apps will show up here as soon as the computer connects.")
                              : janela.t("Baixando o catálogo de apps pela primeira vez. Leva só um instante.",
                                         "Downloading the app catalog for the first time. It only takes a moment.")
                    }
                }
            }

            // ----- seções do Matsu -----
            Repeater {
                model: janela.secoes

                ColumnLayout {
                    id: secao
                    required property var modelData
                    // Sem depender de janela.mudancas: o progresso não refaz os cartões.
                    readonly property var lista: {
                        return modelData.apps.map(function (i) { return janela.app(i); }).filter(function (a) { return a !== null; });
                    }
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.7)
                    visible: lista.length > 0

                    Titulo {
                        Layout.fillWidth: true
                        texto: secao.modelData.titulo
                        detalhe: secao.modelData.texto
                        verTudo: grade.sobra ? janela.t("Ver tudo", "See all") : ""
                        onClicado: pagina.verSecao(secao.modelData.id)
                    }
                    GradeApps {
                        id: grade
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        lista: secao.lista
                        linhas: 1
                    }
                }
            }

            // Lugar das seções enquanto o catálogo chega.
            Repeater {
                model: janela.lido ? 0 : 2
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.7)
                    Esqueleto {
                        Layout.preferredWidth: Math.round(janela.gu * 9)
                        Layout.preferredHeight: Math.round(janela.gu * 1.2)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.8)
                        Repeater {
                            model: 3
                            Esqueleto {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(janela.gu * 8.4)
                                raio: Math.round(janela.gu * 0.6)
                            }
                        }
                    }
                }
            }

            // ----- sites que viram app -----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.7)
                visible: janela.sites.length > 0

                Titulo {
                    Layout.fillWidth: true
                    texto: janela.t("Sites como app", "Websites as apps")
                    detalhe: janela.t("Instagram, TikTok, YouTube e outros, numa janela própria", "Instagram, TikTok, YouTube and more, in their own window")
                    verTudo: janela.t("Ver tudo", "See all")
                    onClicado: janela.irPara("web")
                }
                Flow {
                    id: fileiraSites
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.8)
                    readonly property int tamanho: Math.round(janela.gu * 6.4)
                    readonly property int cabem: Math.max(1, Math.floor((width + spacing) / (tamanho + spacing)))
                    Repeater {
                        model: janela.sites.slice(0, fileiraSites.cabem)
                        CartaoClicavel {
                            id: ladrilho
                            required property var modelData
                            width: fileiraSites.tamanho
                            height: Math.round(janela.gu * 6.2)
                            Accessible.name: modelData.nome
                            onClicked: janela.siteInstalado(modelData.id) ? janela.abrirSite(modelData.id) : janela.irPara("web")
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Math.round(janela.gu * 0.4)
                                IconeSite {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: Math.round(janela.gu * 3)
                                    Layout.preferredHeight: Layout.preferredWidth
                                    site: ladrilho.modelData
                                    scale: ladrilho.containsMouse ? 1.06 : 1
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Kirigami.Units.shortDuration
                                        }
                                    }
                                }
                                Texto {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.maximumWidth: fileiraSites.tamanho - Math.round(janela.gu * 0.6)
                                    text: ladrilho.modelData.nome
                                    elide: Text.ElideRight
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                                }
                            }
                        }
                    }
                }
            }

            // ----- categorias -----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.7)
                visible: janela.lido && janela.apps.length > 0

                Titulo {
                    Layout.fillWidth: true
                    texto: janela.t("Explorar por categoria", "Browse by category")
                }
                Flow {
                    id: categorias
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.8)
                    readonly property int colunas: Math.max(1, Math.floor((width + spacing) / (janela.gu * 13 + spacing)))
                    readonly property int largura: Math.floor((width - (colunas - 1) * spacing) / colunas)
                    Repeater {
                        model: janela.ordemCategorias.filter(function (c) { return (janela.contagem[c] || 0) > 0; })
                        CartaoClicavel {
                            id: categoria
                            required property string modelData
                            width: categorias.largura
                            height: Math.round(janela.gu * 3.6)
                            Accessible.name: janela.nomeCategoria(modelData)
                            onClicked: pagina.verCategoria(modelData)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(janela.gu * 0.7)
                                anchors.rightMargin: Math.round(janela.gu * 0.7)
                                spacing: Math.round(janela.gu * 0.6)
                                Kirigami.Icon {
                                    implicitWidth: Math.round(janela.gu * 2.1)
                                    implicitHeight: implicitWidth
                                    source: janela.iconeCategoria(categoria.modelData)
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    text: janela.nomeCategoria(categoria.modelData)
                                    elide: Text.ElideRight
                                    font.weight: Font.DemiBold
                                }
                                Texto {
                                    text: janela.num(janela.contagem[categoria.modelData] || 0)
                                    opacity: 0.55
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    DetalheApp {
        id: detalhe
        anchors.fill: parent
    }
}
