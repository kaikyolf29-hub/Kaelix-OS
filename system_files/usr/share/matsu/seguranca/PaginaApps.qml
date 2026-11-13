// Permissões dos apps: o que cada app da Loja (Flatpak) pode usar. À esquerda
// os apps; à direita as chaves (câmera, microfone, localização, arquivos, rede,
// avisos) e "Voltar ao padrão do app". Os apps fora da Loja não têm caixa de
// areia, e a página diz isso com todas as letras.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property var dados: janela.apps
    readonly property bool lendo: !dados
    readonly property bool temFlatpak: !!(dados && dados.flatpak)
    readonly property var todos: dados && dados.apps ? dados.apps : []
    readonly property var filtrados: {
        var b = janela.simples(janela.busca.trim());
        if (!b)
            return todos;
        return todos.filter(function (a) {
            return janela.simples(a.nome).indexOf(b) >= 0 || janela.simples(a.id).indexOf(b) >= 0;
        });
    }
    readonly property var app: {
        for (var i = 0; i < filtrados.length; i++)
            if (filtrados[i].id === janela.appEscolhido)
                return filtrados[i];
        return filtrados.length > 0 ? filtrados[0] : null;
    }
    readonly property var semCaixa: dados && dados.semCaixa ? dados.semCaixa : []

    function mudar(perm, ligar) {
        var a = app;
        if (!a)
            return;
        var novo = JSON.parse(JSON.stringify(janela.apps));
        for (var i = 0; i < novo.apps.length; i++) {
            if (novo.apps[i].id === a.id) {
                novo.apps[i].permissoes[perm] = ligar;
                novo.apps[i].mudado = true;
            }
        }
        janela.apps = novo;
        janela.agir("perm-" + a.id + "-" + perm, ["app-permissao", a.id, perm, ligar ? "sim" : "nao"], { recarregar: ["apps"] });
    }
    function voltarPadrao() {
        var a = app;
        janela.agir("padrao-" + a.id, ["app-padrao", a.id], {
            certo: janela.t(a.nome + " voltou ao padrão", a.nome + " is back to its defaults"),
            recarregar: ["apps"]
        });
    }

    Vazio {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * pagina.margem, Math.round(janela.gu * 26))
        visible: !pagina.lendo && !pagina.temFlatpak
        icone: "matsu-apps-symbolic"
        titulo: janela.t("Nenhum app da Loja", "No Store apps")
        texto: janela.t("Os apps da Loja (Flatpak) aparecem aqui, cada um com as suas permissões.", "Store apps (Flatpak) show up here, each with its permissions.")
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        visible: pagina.lendo || pagina.temFlatpak

        // ----- a lista dos apps -----
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: Math.round(Math.max(janela.gu * 11, Math.min(janela.gu * 16, pagina.width * 0.33)))

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: pagina.margem
                spacing: Math.round(janela.gu * 0.5)

                Texto {
                    Layout.fillWidth: true
                    Layout.leftMargin: Math.round(janela.gu * 1.1)
                    Layout.rightMargin: Math.round(janela.gu * 0.8)
                    text: janela.t("Apps da Loja", "Store apps") + (pagina.todos.length ? "  ·  " + pagina.todos.length : "")
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                ListView {
                    id: listaApps
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: pagina.lendo ? 6 : pagina.filtrados
                    spacing: 1
                    leftMargin: Math.round(janela.gu * 0.5)
                    rightMargin: Math.round(janela.gu * 0.5)
                    QQC2.ScrollBar.vertical: BarraRolagem {}

                    delegate: MouseArea {
                        id: itemApp
                        required property var modelData
                        required property int index
                        readonly property bool real: typeof modelData === "object"
                        readonly property bool escolhido: real && pagina.app && pagina.app.id === modelData.id
                        width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                        height: Math.round(janela.gu * 2.5)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        activeFocusOnTab: real
                        Accessible.role: Accessible.ListItem
                        Accessible.name: real ? modelData.nome : ""
                        onClicked: if (real) janela.appEscolhido = modelData.id
                        Keys.onSpacePressed: clicked(null)

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(janela.gu * 0.35)
                            color: itemApp.escolhido ? janela.tinta(janela.escuro ? 0.09 : 0.07) : janela.tinta(itemApp.containsMouse ? 0.04 : 0)
                            border.width: itemApp.activeFocus ? 1 : 0
                            border.color: janela.destaque
                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(janela.gu * 0.6)
                            anchors.rightMargin: Math.round(janela.gu * 0.6)
                            spacing: Math.round(janela.gu * 0.6)
                            Item {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                Layout.preferredHeight: Layout.preferredWidth
                                Esqueleto {
                                    anchors.fill: parent
                                    raio: Math.round(janela.gu * 0.4)
                                    visible: !itemApp.real
                                }
                                IconeApp {
                                    anchors.fill: parent
                                    visible: itemApp.real
                                    fonte: itemApp.real ? itemApp.modelData.icone : ""
                                }
                            }
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: nomeApp.implicitHeight
                                Esqueleto {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * (0.5 + 0.08 * (itemApp.index % 4))
                                    height: Math.round(janela.gu * 0.6)
                                    visible: !itemApp.real
                                }
                                Texto {
                                    id: nomeApp
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    visible: itemApp.real
                                    text: itemApp.real ? itemApp.modelData.nome : ""
                                    font.weight: itemApp.escolhido ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }
                            }
                            // Pinguinho: este app tem permissões mudadas por você.
                            Rectangle {
                                visible: itemApp.real && itemApp.modelData.mudado
                                Layout.preferredWidth: Math.round(janela.gu * 0.4)
                                Layout.preferredHeight: Layout.preferredWidth
                                radius: width / 2
                                color: janela.frente
                                opacity: 0.5
                            }
                        }
                    }

                    Texto {
                        anchors.centerIn: parent
                        width: parent.width - janela.gu * 2
                        visible: !pagina.lendo && pagina.filtrados.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: janela.t("Nenhum app com esse nome", "No app with that name")
                        opacity: 0.55
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: janela.tinta(0.08)
        }

        // ----- as permissões do app escolhido -----
        Flickable {
            id: rolagem
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: coluna.implicitHeight + 2 * pagina.margem
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            QQC2.ScrollBar.vertical: BarraRolagem {}

            ColumnLayout {
                id: coluna
                width: Math.min(rolagem.width - 2 * pagina.margem, Math.round(janela.gu * 40))
                x: Math.round((rolagem.width - width) / 2)
                y: pagina.margem
                spacing: Math.round(janela.gu * 0.7)

                // O app: ícone grande, nome e de onde veio.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.9)
                    visible: !!pagina.app
                    IconeApp {
                        Layout.preferredWidth: Math.round(janela.gu * 3.4)
                        Layout.preferredHeight: Layout.preferredWidth
                        fonte: pagina.app ? pagina.app.icone : ""
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Texto {
                            Layout.fillWidth: true
                            text: pagina.app ? pagina.app.nome : ""
                            font.pixelSize: Math.round(janela.gu * 1.3)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: pagina.app ? pagina.app.id + (pagina.app.instalacao === "usuario" ? janela.t(" · só na sua conta", " · your account only") : "") : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.55
                            elide: Text.ElideRight
                        }
                    }
                    BotaoSimbolo {
                        icone: janela.ic("abrir-fora")
                        dica: janela.t("Ver na Loja", "View in Store")
                        onClicado: matsu.rodar("loja", janela.comando(["loja", pagina.app.id]))
                    }
                }
                Texto {
                    Layout.fillWidth: true
                    visible: !!pagina.app
                    text: janela.t("O app fica numa caixa de areia: só usa o que estiver ligado aqui. Desligar vale na próxima vez que ele abrir.",
                                   "The app lives in a sandbox: it only uses what's on here. Turning something off applies the next time it opens.")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.62
                    wrapMode: Text.WordWrap
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(janela.gu * 0.3)
                    spacing: 2
                    visible: !!pagina.app
                    Repeater {
                        model: [
                            { id: "camera", icone: janela.ic("camera"), nome: janela.t("Câmera", "Camera"),
                              texto: janela.t("Fotos, vídeo e chamadas com vídeo.", "Photos, video and video calls.") },
                            { id: "microfone", icone: janela.ic("microfone"), nome: janela.t("Microfone e som", "Microphone and sound"),
                              texto: janela.t("Nos apps da Loja, o som e o microfone vêm juntos: desligar tira também o som do app.",
                                              "In Store apps, sound and microphone come together: turning it off also mutes the app.") },
                            { id: "localizacao", icone: janela.ic("localizacao"), nome: janela.t("Localização", "Location"),
                              texto: "" },
                            { id: "arquivos", icone: "matsu-pasta-symbolic", nome: janela.t("Arquivos pessoais", "Personal files"),
                              texto: "" },
                            { id: "rede", icone: "matsu-web-symbolic", nome: janela.t("Rede e internet", "Network and internet"),
                              texto: janela.t("Sem rede, o app fica sem internet nenhuma.", "Without network, the app has no internet at all.") },
                            { id: "notificacoes", icone: "matsu-sino-symbolic", nome: janela.t("Avisos", "Notifications"),
                              texto: janela.t("Os balões que aparecem no canto da tela.", "The pop-ups in the corner of the screen.") }
                        ]
                        LinhaOpcao {
                            id: linhaPerm
                            required property var modelData
                            required property int index
                            readonly property var p: pagina.app ? pagina.app.permissoes : ({})
                            Layout.fillWidth: true
                            primeira: index === 0
                            ultima: index === 5
                            icone: modelData.icone
                            nome: modelData.nome
                            texto: modelData.id === "localizacao" ? (p.localizacao ? janela.t("Pode saber onde você está.", "Can know where you are.")
                                                                                   : p.localPergunta ? janela.t("Pergunta quando o app pedir.", "Asks when the app wants it.")
                                                                                   : janela.t("Não pode saber onde você está.", "Can't know where you are."))
                                 : modelData.id === "arquivos" ? (p.arquivosTexto || "")
                                 : modelData.texto
                            Row {
                                spacing: Math.round(janela.gu * 0.5)
                                Girando {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(janela.gu * 0.9)
                                    height: width
                                    visible: !!pagina.app && !!janela.ocupado["perm-" + pagina.app.id + "-" + linhaPerm.modelData.id]
                                }
                                Chave {
                                    anchors.verticalCenter: parent.verticalCenter
                                    nome: linhaPerm.modelData.nome
                                    ligada: !!linhaPerm.p[linhaPerm.modelData.id]
                                    onTrocada: (v) => pagina.mudar(linhaPerm.modelData.id, v)
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: !!pagina.app
                    Texto {
                        Layout.fillWidth: true
                        text: pagina.app && pagina.app.mudado ? janela.t("Você mudou permissões deste app.", "You changed this app's permissions.")
                                                              : janela.t("Do jeito que o app veio da Loja.", "The way the app came from the Store.")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                    Botao {
                        texto: janela.t("Voltar ao padrão do app", "Reset to app defaults")
                        icone: janela.ic("restaurar")
                        ativo: !!pagina.app && pagina.app.mudado && !janela.ocupado["padrao-" + pagina.app.id]
                        dica: pagina.app && !pagina.app.mudado ? janela.t("Nada foi mudado", "Nothing was changed") : ""
                        onClicado: pagina.voltarPadrao()
                    }
                }

                // Os apps sem caixa de areia (vêm com o sistema ou de fora da Loja).
                Cartao {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(janela.gu * 0.6)
                    visible: !pagina.lendo
                    implicitHeight: colunaSemCaixa.implicitHeight + Math.round(janela.gu * 2)
                    ColumnLayout {
                        id: colunaSemCaixa
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Math.round(janela.gu * 1)
                        spacing: Math.round(janela.gu * 0.5)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(janela.gu * 0.6)
                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Layout.preferredWidth
                                source: "matsu-info-symbolic"
                                isMask: true
                                color: janela.frente
                                opacity: 0.8
                            }
                            Texto {
                                Layout.fillWidth: true
                                text: janela.t("Apps fora da Loja não têm caixa de areia", "Apps outside the Store have no sandbox")
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                            }
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: janela.t("Os do sistema e os instalados por fora podem usar tudo o que você usa. Quando houver, prefira a versão da Loja.",
                                           "System apps and ones installed separately can use everything you can. When available, prefer the Store version.")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.68
                            wrapMode: Text.WordWrap
                        }
                        Flow {
                            Layout.fillWidth: true
                            visible: pagina.semCaixa.length > 0
                            spacing: Math.round(janela.gu * 0.4)
                            Repeater {
                                model: pagina.semCaixa
                                Rectangle {
                                    required property var modelData
                                    width: linhaSem.implicitWidth + Math.round(janela.gu * 1)
                                    height: Math.round(janela.gu * 1.7)
                                    radius: height / 2
                                    color: janela.tinta(janela.escuro ? 0.06 : 0.045)
                                    Row {
                                        id: linhaSem
                                        anchors.centerIn: parent
                                        spacing: Math.round(janela.gu * 0.35)
                                        IconeApp {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.round(janela.gu * 1)
                                            height: width
                                            fonte: modelData.icone || ""
                                            tema: true
                                        }
                                        Texto {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.nome
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
