// Biblioteca: o que está baixando agora (com o progresso e cancelar), as
// atualizações (uma por uma ou todas), os apps instalados (abrir, remover) e os
// sites que viraram app. A busca da barra de título filtra.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property string busca: janela.simples(janela.busca.trim())

    function combina(nome) {
        return busca.length === 0 || janela.simples(nome).indexOf(busca) >= 0;
    }

    readonly property var baixando: {
        var _m = janela.mudancas;
        return Object.keys(janela.tarefas).filter(function (id) {
            return id.indexOf("web:") !== 0 && pagina.combina(janela.nomeDe(id));
        });
    }
    readonly property var paraAtualizar: {
        var _m = janela.mudancas;
        return Object.keys(janela.atualizacoes).filter(function (id) {
            return !janela.tarefas[id] && pagina.combina(janela.nomeDe(id));
        }).sort(function (a, b) { return janela.nomeDe(a).localeCompare(janela.nomeDe(b)); });
    }
    readonly property var instalados: {
        var _m = janela.mudancas;
        return Object.keys(janela.instalados).filter(function (id) {
            return pagina.combina(janela.nomeDe(id));
        }).sort(function (a, b) { return janela.nomeDe(a).localeCompare(janela.nomeDe(b), janela.pt ? "pt-BR" : "en"); });
    }
    readonly property var sites: {
        var _m = janela.mudancas;
        return janela.sitesInstalados.map(function (id) { return janela.site(id); })
            .filter(function (s) { return s !== null && pagina.combina(s.nome); });
    }

    // Uma linha de app: logo, nome, o que está acontecendo e os botões.
    component LinhaApp: Rectangle {
        id: linha
        property string appId: ""
        property string detalheTexto: ""
        property bool mostrarProgresso: false
        property bool primeira: false
        property bool ultima: false
        default property alias botoes: lugarBotoes.data

        Layout.fillWidth: true
        implicitHeight: Math.round(janela.gu * 3.6)
        color: sobre.hovered ? janela.tinta(janela.escuro ? 0.05 : 0.04) : "transparent"
        radius: Math.round(janela.gu * 0.5)
        HoverHandler {
            id: sobre
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (janela.app(linha.appId)) janela.abrirApp(linha.appId)
        }
        Rectangle {
            visible: !linha.ultima
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Math.round(janela.gu * 3.6)
            height: 1
            color: janela.tinta(janela.escuro ? 0.06 : 0.07)
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(janela.gu * 0.6)
            anchors.rightMargin: Math.round(janela.gu * 0.6)
            spacing: Math.round(janela.gu * 0.7)
            IconeApp {
                Layout.preferredWidth: Math.round(janela.gu * 2.2)
                Layout.preferredHeight: Layout.preferredWidth
                fonte: janela.app(linha.appId) ? janela.app(linha.appId).icone : ""
                appId: linha.appId
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Texto {
                    Layout.fillWidth: true
                    text: janela.nomeDe(linha.appId)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Texto {
                    Layout.fillWidth: true
                    visible: linha.detalheTexto !== ""
                    text: linha.detalheTexto
                    opacity: 0.62
                    elide: Text.ElideRight
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                // Barrinha do progresso, na cor da frente (nada de azul).
                Rectangle {
                    visible: linha.mostrarProgresso
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.round(janela.gu * 18)
                    Layout.preferredHeight: 4
                    radius: 2
                    color: janela.tinta(0.12)
                    Rectangle {
                        height: parent.height
                        radius: 2
                        color: janela.frente
                        width: parent.width * Math.max(0.04, janela.progresso(linha.appId) / 100)
                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                            }
                        }
                    }
                }
            }
            RowLayout {
                id: lugarBotoes
                spacing: Math.round(janela.gu * 0.4)
            }
        }
    }

    // A caixa de uma parte (título em cima, as linhas num cartão).
    component Parte: ColumnLayout {
        property string titulo: ""
        property string detalhe: ""
        default property alias linhas: cartaoLinhas.data
        Layout.fillWidth: true
        spacing: Math.round(janela.gu * 0.5)
        Titulo {
            Layout.fillWidth: true
            texto: parent.titulo
            detalhe: parent.detalhe
        }
        Cartao {
            Layout.fillWidth: true
            implicitHeight: cartaoLinhas.implicitHeight + Math.round(janela.gu * 0.6)
            ColumnLayout {
                id: cartaoLinhas
                anchors.fill: parent
                anchors.margins: Math.round(janela.gu * 0.3)
                spacing: 0
            }
        }
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
            spacing: Math.round(janela.gu * 1.3)

            // ----- cabeçalho -----
            RowLayout {
                Layout.topMargin: Math.round(janela.gu * 0.9)
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.6)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Texto {
                        Layout.fillWidth: true
                        text: janela.t("Biblioteca", "Library")
                        font.pixelSize: Math.round(janela.gu * 1.3)
                        font.weight: Font.DemiBold
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: {
                            var n = Object.keys(janela.instalados).length;
                            var s = janela.sitesInstalados.length;
                            var t = n === 1 ? janela.t("1 app instalado", "1 app installed") : janela.num(n) + janela.t(" apps instalados", " apps installed");
                            if (s > 0)
                                t += "  ·  " + (s === 1 ? janela.t("1 site", "1 website") : s + janela.t(" sites", " websites"));
                            return t;
                        }
                        opacity: 0.62
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
                Botao {
                    texto: janela.procurando ? janela.t("Procurando...", "Checking...") : janela.t("Procurar atualizações", "Check for updates")
                    icone: "matsu-recarregar-symbolic"
                    ativo: !janela.procurando
                    onClicado: janela.procurarAtualizacoes()
                }
                BotaoDestaque {
                    visible: pagina.paraAtualizar.length > 0
                    texto: janela.t("Atualizar tudo", "Update all")
                    icone: "matsu-baixar-symbolic"
                    onClicado: janela.atualizarTudo()
                }
            }

            // ----- baixando agora -----
            Parte {
                visible: pagina.baixando.length > 0
                titulo: janela.t("Agora", "Now")
                Repeater {
                    model: pagina.baixando
                    LinhaApp {
                        id: baixa
                        required property string modelData
                        required property int index
                        appId: modelData
                        ultima: index === pagina.baixando.length - 1
                        mostrarProgresso: !janela.emFila(modelData)
                        detalheTexto: {
                            var _m = janela.mudancas;
                            if (janela.emFila(modelData))
                                return janela.t("Na fila, esperando a vez", "Queued, waiting its turn");
                            var a = janela.acaoAgora(modelData);
                            var p = janela.progresso(modelData);
                            var pct = p > 0 ? " · " + janela.porcento(p) : "";
                            if (a === "remover")
                                return janela.t("Removendo", "Removing");
                            if (a === "atualizar")
                                return janela.t("Atualizando", "Updating") + pct;
                            return janela.t("Baixando", "Downloading") + pct;
                        }
                        Botao {
                            texto: janela.t("Cancelar", "Cancel")
                            onClicado: janela.cancelar(baixa.appId)
                        }
                    }
                }
            }

            // ----- atualizações -----
            Parte {
                visible: pagina.paraAtualizar.length > 0
                titulo: janela.t("Atualizações", "Updates")
                detalhe: pagina.paraAtualizar.length === 1 ? janela.t("1 app com versão nova", "1 app with a new version")
                                                           : pagina.paraAtualizar.length + janela.t(" apps com versão nova", " apps with a new version")
                Repeater {
                    model: pagina.paraAtualizar
                    LinhaApp {
                        id: atualiza
                        required property string modelData
                        required property int index
                        appId: modelData
                        ultima: index === pagina.paraAtualizar.length - 1
                        detalheTexto: {
                            var _m = janela.mudancas;
                            var atual = janela.instalados[modelData] ? janela.instalados[modelData].versao : "";
                            var nova = janela.atualizacoes[modelData] || "";
                            if (atual && nova)
                                return atual + "  →  " + nova;
                            return nova ? janela.t("Versão nova: ", "New version: ") + nova : janela.t("Versão nova disponível", "New version available");
                        }
                        BotaoObter {
                            appId: atualiza.appId
                        }
                    }
                }
            }

            // ----- instalados -----
            Parte {
                visible: pagina.instalados.length > 0
                titulo: janela.t("Apps instalados", "Installed apps")
                Repeater {
                    model: pagina.instalados
                    LinhaApp {
                        id: instalado
                        required property string modelData
                        required property int index
                        property bool confirmar: false
                        appId: modelData
                        ultima: index === pagina.instalados.length - 1
                        detalheTexto: {
                            var _m = janela.mudancas;
                            var i = janela.instalados[modelData] || {};
                            var partes = [];
                            if (i.versao)
                                partes.push(janela.t("versão ", "version ") + i.versao);
                            if (i.tamanho)
                                partes.push(i.tamanho);
                            if (i.instalacao === "pessoa")
                                partes.push(janela.t("só para você", "just for you"));
                            return partes.join("  ·  ");
                        }
                        Timer {
                            id: voltar
                            interval: 4000
                            onTriggered: instalado.confirmar = false
                        }
                        Botao {
                            visible: !janela.tarefas[instalado.appId]
                            texto: instalado.confirmar ? janela.t("Confirmar", "Confirm") : ""
                            icone: "matsu-lixeira-symbolic"
                            dica: janela.t("Remover", "Remove")
                            onClicado: {
                                if (instalado.confirmar) {
                                    instalado.confirmar = false;
                                    janela.remover(instalado.appId);
                                } else {
                                    instalado.confirmar = true;
                                    voltar.restart();
                                }
                            }
                        }
                        BotaoObter {
                            appId: instalado.appId
                        }
                    }
                }
            }

            // ----- sites -----
            Parte {
                visible: pagina.sites.length > 0
                titulo: janela.t("Sites como app", "Websites as apps")
                Repeater {
                    model: pagina.sites
                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: Math.round(janela.gu * 3.6)
                        color: "transparent"
                        Rectangle {
                            visible: parent.index < pagina.sites.length - 1
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Math.round(janela.gu * 3.6)
                            height: 1
                            color: janela.tinta(janela.escuro ? 0.06 : 0.07)
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(janela.gu * 0.6)
                            anchors.rightMargin: Math.round(janela.gu * 0.6)
                            spacing: Math.round(janela.gu * 0.7)
                            IconeSite {
                                Layout.preferredWidth: Math.round(janela.gu * 2.2)
                                Layout.preferredHeight: Layout.preferredWidth
                                site: parent.parent.modelData
                            }
                            Texto {
                                Layout.fillWidth: true
                                text: parent.parent.modelData.nome
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Botao {
                                icone: "matsu-lixeira-symbolic"
                                dica: janela.t("Tirar do menu", "Remove from the menu")
                                onClicado: janela.tirarSite(parent.parent.modelData.id)
                            }
                            Botao {
                                texto: janela.t("Abrir", "Open")
                                onClicado: janela.abrirSite(parent.parent.modelData.id)
                            }
                        }
                    }
                }
            }

            // ----- vazia -----
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 3)
                visible: pagina.instalados.length === 0 && pagina.sites.length === 0 && pagina.baixando.length === 0
                spacing: Math.round(janela.gu * 0.6)
                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Math.round(janela.gu * 2.8)
                    implicitHeight: implicitWidth
                    source: "matsu-biblioteca-symbolic"
                    isMask: true
                    color: janela.frente
                    opacity: 0.5
                }
                Texto {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                    text: pagina.busca.length > 0 ? janela.t("Nada com esse nome na Biblioteca.", "Nothing with that name in the Library.")
                                                  : janela.t("Os apps que você obtiver na Loja aparecem aqui.", "Apps you get from the Store show up here.")
                }
                BotaoDestaque {
                    Layout.alignment: Qt.AlignHCenter
                    visible: pagina.busca.length === 0
                    texto: janela.t("Ver os destaques", "See highlights")
                    onClicado: janela.irPara("inicio")
                }
            }
        }
    }

    DetalheApp {
        id: detalhe
        anchors.fill: parent
    }
}
