// Integridade: o que protege o próprio sistema (imagem assinada, pasta do
// sistema só de leitura, Secure Boot, criptografia do disco, atualizações
// automáticas, lojas de apps com assinatura) e a conferência dos arquivos do
// sistema (ostree fsck). O que não dá para conferir aparece como tal, com o motivo.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property var dados: janela.integ
    readonly property bool lendo: !dados
    readonly property var itens: dados && dados.itens ? dados.itens : []
    readonly property int bons: itens.filter(function (i) { return i.estado === "ok"; }).length
    readonly property int atencao: itens.filter(function (i) { return i.estado === "atencao"; }).length
    readonly property var fim: janela.fsckFim

    function iconeItem(id) {
        return ({
            assinatura: "matsu-verificado-symbolic", leitura: "matsu-cadeado-symbolic", secureboot: janela.ic("chip"),
            disco: "matsu-disco-symbolic", atualizacoes: "matsu-sincronia-symbolic", flatpak: "matsu-apps-symbolic"
        })[id] || "matsu-info-symbolic";
    }
    function corItem(estado) {
        return estado === "ok" ? janela.verde : estado === "atencao" ? janela.ambar : janela.corEstado("");
    }
    function marcaItem(estado) {
        return estado === "ok" ? "matsu-certo-symbolic" : estado === "atencao" ? "matsu-alerta-symbolic"
             : estado === "desligado" ? janela.ic("menos") : janela.ic("interrogacao");
    }

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
            width: Math.min(rolagem.width - 2 * pagina.margem, Math.round(janela.gu * 52))
            x: Math.round((rolagem.width - width) / 2)
            y: pagina.margem
            spacing: Math.round(janela.gu * 0.7)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.6)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Texto {
                        text: janela.t("Integridade do sistema", "System integrity")
                        font.pixelSize: Math.round(janela.gu * 1.3)
                        font.weight: Font.DemiBold
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: pagina.lendo ? janela.t("Conferindo…", "Checking…")
                            : pagina.atencao > 0 ? (pagina.atencao === 1 ? janela.t("1 item pede atenção", "1 item needs attention") : janela.t(pagina.atencao + " itens pedem atenção", pagina.atencao + " items need attention"))
                                                   + janela.t(" · " + pagina.bons + " de " + pagina.itens.length + " em ordem", " · " + pagina.bons + " of " + pagina.itens.length + " in order")
                            : janela.t(pagina.bons + " de " + pagina.itens.length + " itens em ordem", pagina.bons + " of " + pagina.itens.length + " items in order")
                        opacity: 0.65
                        wrapMode: Text.WordWrap
                    }
                }
                Botao {
                    texto: janela.t("Conferir de novo", "Check again")
                    icone: "matsu-recarregar-symbolic"
                    ativo: !pagina.lendo
                    onClicado: {
                        janela.integ = null;
                        janela.carregar("integridade");
                    }
                }
            }

            // ----- cada item -----
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.4)
                spacing: 2
                Repeater {
                    model: pagina.lendo ? 6 : pagina.itens
                    Cartao {
                        id: cartaoItem
                        required property var modelData
                        required property int index
                        readonly property bool real: typeof modelData === "object"
                        readonly property int total: pagina.lendo ? 6 : pagina.itens.length
                        Layout.fillWidth: true
                        implicitHeight: Math.max(Math.round(janela.gu * 3.6), linhaItem.implicitHeight + Math.round(janela.gu * 1.4))
                        topLeftRadius: index === 0 ? radius : 2
                        topRightRadius: index === 0 ? radius : 2
                        bottomLeftRadius: index === total - 1 ? radius : 2
                        bottomRightRadius: index === total - 1 ? radius : 2
                        // Entram um depois do outro.
                        opacity: 0
                        Component.onCompleted: entrada.start()
                        SequentialAnimation {
                            id: entrada
                            PauseAnimation { duration: 40 * cartaoItem.index }
                            NumberAnimation { target: cartaoItem; property: "opacity"; to: 1; duration: 220 }
                        }

                        RowLayout {
                            id: linhaItem
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Math.round(janela.gu * 0.9)
                            anchors.rightMargin: Math.round(janela.gu * 0.9)
                            spacing: Math.round(janela.gu * 0.8)

                            Item {
                                Layout.preferredWidth: Math.round(janela.gu * 2.3)
                                Layout.preferredHeight: Layout.preferredWidth
                                Layout.alignment: Qt.AlignTop
                                Esqueleto {
                                    anchors.fill: parent
                                    raio: width / 2
                                    visible: !cartaoItem.real
                                }
                                IconeRedondo {
                                    anchors.fill: parent
                                    visible: cartaoItem.real
                                    icone: cartaoItem.real ? pagina.iconeItem(cartaoItem.modelData.id) : ""
                                    cor: cartaoItem.real ? pagina.corItem(cartaoItem.modelData.estado) : janela.frente
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Esqueleto {
                                    visible: !cartaoItem.real
                                    Layout.preferredWidth: Math.round(janela.gu * (8 + cartaoItem.index % 3 * 2))
                                    Layout.preferredHeight: Math.round(janela.gu * 0.7)
                                }
                                Esqueleto {
                                    visible: !cartaoItem.real
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(janela.gu * 0.55)
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    visible: cartaoItem.real
                                    text: cartaoItem.real ? cartaoItem.modelData.titulo : ""
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.WordWrap
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    visible: cartaoItem.real
                                    text: cartaoItem.real ? (cartaoItem.modelData.estado === "?" ? janela.t("Não foi possível conferir: ", "Couldn't check: ") : "") + cartaoItem.modelData.texto : ""
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.68
                                    wrapMode: Text.WordWrap
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    visible: cartaoItem.real && !!cartaoItem.modelData.detalhe
                                    text: cartaoItem.real ? cartaoItem.modelData.detalhe || "" : ""
                                    font.family: "monospace"
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize - 0.5
                                    opacity: 0.45
                                    elide: Text.ElideMiddle
                                }
                            }
                            Kirigami.Icon {
                                visible: cartaoItem.real
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Layout.preferredWidth
                                source: cartaoItem.real ? pagina.marcaItem(cartaoItem.modelData.estado) : ""
                                isMask: true
                                color: cartaoItem.real ? pagina.corItem(cartaoItem.modelData.estado) : janela.frente
                            }
                        }
                    }
                }
            }
            Texto {
                Layout.fillWidth: true
                visible: !!pagina.dados && pagina.dados.atomico === false
                text: janela.t("Este computador não usa o sistema por imagem do Matsu (ostree): alguns itens não se aplicam.",
                               "This computer doesn't use Matsu's image-based system (ostree): some items don't apply.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.6
                wrapMode: Text.WordWrap
            }

            // ----- conferir os arquivos do sistema -----
            Secao {
                titulo: janela.t("Verificar os arquivos do sistema", "Verify system files")
                texto: janela.t("Confere, um por um, se os arquivos do sistema são exatamente os da versão assinada. Leva alguns minutos e pede a senha de administrador.",
                                "Checks, one by one, that system files are exactly those of the signed version. Takes a few minutes and asks for the administrator password.")
            }
            Cartao {
                Layout.fillWidth: true
                implicitHeight: linhaFsck.implicitHeight + Math.round(janela.gu * 2.2)
                Behavior on implicitHeight {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }
                RowLayout {
                    id: linhaFsck
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Math.round(janela.gu * 1.1)
                    spacing: Math.round(janela.gu * 1.1)

                    Item {
                        Layout.preferredWidth: janela.fsckRodando ? Math.round(janela.gu * 5) : Math.round(janela.gu * 2.8)
                        Layout.preferredHeight: Layout.preferredWidth
                        Behavior on Layout.preferredWidth {
                            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                        }
                        Anel {
                            anchors.fill: parent
                            visible: janela.fsckRodando && janela.fsckTotal > 0
                            valor: janela.fsckParte
                            texto: janela.porcento(janela.fsckParte * 100)
                        }
                        Girando {
                            anchors.centerIn: parent
                            width: Math.round(janela.gu * 2)
                            height: width
                            visible: janela.fsckRodando && janela.fsckTotal === 0
                        }
                        IconeRedondo {
                            anchors.fill: parent
                            visible: !janela.fsckRodando
                            icone: !pagina.fim ? "matsu-verificado-symbolic" : pagina.fim.ok ? "matsu-certo-symbolic" : pagina.fim.cancelado ? "matsu-info-symbolic" : "matsu-alerta-symbolic"
                            cor: !pagina.fim ? janela.frente : pagina.fim.ok ? janela.verde : pagina.fim.cancelado ? janela.frente : janela.coral
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Texto {
                            Layout.fillWidth: true
                            text: janela.fsckRodando ? (janela.fsckTexto || janela.t("Conferindo…", "Checking…"))
                                : !pagina.fim ? janela.t("Nenhuma conferência nesta sessão", "No check this session")
                                : pagina.fim.ok ? janela.t("Tudo igual à versão assinada", "Everything matches the signed version")
                                : pagina.fim.cancelado ? janela.t("Conferência não começou", "The check didn't start")
                                : pagina.fim.erro ? janela.t("Não foi possível conferir", "Couldn't check")
                                : janela.t("Achou arquivos diferentes", "Found files that differ")
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }
                        Texto {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: janela.fsckRodando ? (janela.fsckTotal > 0 ? janela.t(janela.num(janela.fsckFeitos) + " de " + janela.num(janela.fsckTotal) + " partes conferidas",
                                                                                         janela.num(janela.fsckFeitos) + " of " + janela.num(janela.fsckTotal) + " parts checked") : "")
                                : !pagina.fim ? ""
                                : pagina.fim.ok ? janela.t("Conferido em ", "Checked in ") + janela.tempoCurto(pagina.fim.duracao || 0) + "."
                                : pagina.fim.erro ? pagina.fim.erro
                                : janela.t("Isso pode ser o disco com defeito. Atualize o sistema; se continuar, peça ajuda.", "This may be a failing disk. Update the system; if it persists, ask for help.")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.68
                            wrapMode: Text.WordWrap
                        }
                    }
                    BotaoDestaque {
                        visible: !janela.fsckRodando
                        texto: pagina.fim ? janela.t("Verificar de novo", "Verify again") : janela.t("Verificar os arquivos", "Verify files")
                        icone: "matsu-verificado-symbolic"
                        onClicado: janela.verificarSistema()
                    }
                }
            }
        }
    }
}
