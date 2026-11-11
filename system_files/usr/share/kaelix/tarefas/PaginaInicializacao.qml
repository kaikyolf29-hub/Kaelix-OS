// Inicialização, como no Windows: os apps que abrem sozinhos quando a pessoa
// entra no Kaelix, com um botão para ligar e desligar cada um. As peças do
// sistema (senha de administrador, acessibilidade...) não aparecem aqui.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    property var itens: []
    property bool carregado: false

    function carregar() {
        kaelix.rodar("inicio", janela.comando(["inicializacao"]));
    }
    function ligar(item, sim) {
        // Mostra na hora; o ajudante grava e a lista é lida de novo.
        var novos = [];
        for (var i = 0; i < itens.length; i++) {
            var x = Object.assign({}, itens[i]);
            if (x.arquivo === item.arquivo)
                x.ligado = sim;
            novos.push(x);
        }
        itens = novos;
        kaelix.rodar("inicio-ligar", janela.comando(["inicializacao-ligar", item.arquivo, sim ? "sim" : "nao"]));
    }

    Connections {
        target: kaelix
        function onPronto(chave, saida, codigo) {
            if (chave === "inicio") {
                try {
                    var r = JSON.parse(saida);
                    pagina.itens = r.itens;
                    if (r.idioma)
                        janela.lingua = r.idioma;
                } catch (e) {
                    pagina.itens = [];
                }
                pagina.carregado = true;
            } else if (chave === "inicio-ligar") {
                pagina.carregar();
            }
        }
    }
    Component.onCompleted: carregar()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Título da página e o botão de pôr outro app, como a barra do Windows 11.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(janela.gu * 3)
            Layout.leftMargin: Math.round(janela.gu * 1.1)
            Layout.rightMargin: Math.round(janela.gu * 0.6)

            Texto {
                Layout.fillWidth: true
                text: janela.t("Inicialização", "Startup apps")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Botao {
                texto: janela.t("Adicionar app", "Add app")
                icone: "kaelix-mais-symbolic"
                dica: janela.t("Escolher outro app para abrir sozinho ao entrar", "Choose another app to open at login")
                onClicado: kaelix.soltar(["systemsettings", "kcm_autostart"])
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: janela.tinta(0.07)
        }

        Flickable {
            id: rolagem
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: corpo.implicitHeight + janela.gu * 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

            ColumnLayout {
                id: corpo
                x: Math.round(janela.gu * 1.1)
                y: Math.round(janela.gu * 0.9)
                width: rolagem.width - Math.round(janela.gu * 2.2)
                spacing: Math.round(janela.gu * 0.8)

                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Estes apps abrem sozinhos quando você entra no Kaelix. Desligar deixa a entrada mais rápida. A mudança vale a partir da próxima vez que você entrar.",
                                    "These apps open by themselves when you log in to Kaelix. Turning them off makes login faster. Changes apply the next time you log in.")
                    wrapMode: Text.WordWrap
                    opacity: 0.72
                }

                // Uma linha por app, num cartão de vidro.
                Rectangle {
                    Layout.fillWidth: true
                    visible: pagina.itens.length > 0
                    implicitHeight: coluna.implicitHeight
                    radius: Math.round(janela.gu * 0.4)
                    color: janela.escuro ? janela.tinta(0.04) : Qt.rgba(1, 1, 1, 0.6)
                    border.width: 1
                    border.color: janela.tinta(janela.escuro ? 0.07 : 0.08)

                    ColumnLayout {
                        id: coluna
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 0

                        Repeater {
                            model: pagina.itens

                            Item {
                                id: item
                                required property var modelData
                                required property int index
                                readonly property int folga: Math.round(janela.gu * 0.8)

                                Layout.fillWidth: true
                                implicitHeight: Math.max(Math.round(janela.gu * 3), conteudo.implicitHeight + folga)

                                Rectangle {
                                    visible: item.index > 0
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: janela.tinta(0.07)
                                }

                                RowLayout {
                                    id: conteudo
                                    anchors.fill: parent
                                    anchors.leftMargin: item.folga
                                    anchors.rightMargin: item.folga
                                    spacing: item.folga

                                    Kirigami.Icon {
                                        implicitWidth: Math.round(janela.gu * 1.6)
                                        implicitHeight: implicitWidth
                                        source: item.modelData.icone || "kaelix-engrenagem-symbolic"
                                        fallback: "application-x-executable"
                                        opacity: item.modelData.ligado ? 1 : 0.55
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Texto {
                                            Layout.fillWidth: true
                                            text: item.modelData.nome
                                            elide: Text.ElideRight
                                        }
                                        Texto {
                                            Layout.fillWidth: true
                                            visible: text.length > 0
                                            text: item.modelData.descricao
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            opacity: 0.65
                                            elide: Text.ElideRight
                                        }
                                    }
                                    // De onde veio: do sistema ou colocado pela pessoa.
                                    Texto {
                                        Layout.preferredWidth: Math.round(janela.gu * 5)
                                        text: item.modelData.origem === "sistema" ? janela.t("Do sistema", "System") : janela.t("Seu", "Yours")
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.65
                                    }
                                    Texto {
                                        Layout.preferredWidth: Math.round(janela.gu * 4.5)
                                        horizontalAlignment: Text.AlignRight
                                        text: item.modelData.ligado ? janela.t("Ligado", "Enabled") : janela.t("Desligado", "Disabled")
                                        opacity: item.modelData.ligado ? 0.95 : 0.65
                                    }
                                    Chave {
                                        ligada: item.modelData.ligado
                                        nome: item.modelData.nome
                                        onTrocada: ligada => pagina.ligar(item.modelData, ligada)
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: janela.gu * 2
                    visible: pagina.carregado && pagina.itens.length === 0
                    spacing: Math.round(janela.gu * 0.6)
                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Math.round(janela.gu * 3)
                        implicitHeight: implicitWidth
                        source: "kaelix-inicializacao-symbolic"
                        isMask: true
                        color: janela.frente
                        opacity: 0.35
                    }
                    Texto {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: janela.t("Nenhum app abre sozinho quando você entra.", "No apps open by themselves when you log in.")
                        opacity: 0.6
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
