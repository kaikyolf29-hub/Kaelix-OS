// Rede e firewall: o firewall do Matsu (firewalld), o tipo de cada rede ligada
// agora (pública: nada entra; de casa: os aparelhos da casa se encontram), o que
// pode receber conexões na rede de casa e a verdade sobre bloquear apps.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property var r: janela.rede
    readonly property bool lendo: !r
    readonly property bool falhou: !!(r && r.falhou)
    readonly property string firewall: r && !r.falhou ? r.firewall : "?"
    readonly property var conexoes: r && r.conexoes ? r.conexoes : []
    readonly property var servicos: r && r.servicos ? r.servicos : []

    function iconeServico(s) {
        var locais = { celular: 1, radar: 1, impressora: 1, tv: 1, musica: 1, compartilhar: 1, terminal: 1 };
        if (locais[s.reserva])
            return janela.ic(s.reserva);
        return ({ jogos: "matsu-jogos-symbolic", pasta: "matsu-pasta-symbolic", tela: "matsu-tela-symbolic" })[s.reserva] || "matsu-web-symbolic";
    }
    function trocarTipo(c, tipo) {
        janela.agir("tipo-" + c.uuid, ["rede-tipo", c.uuid, tipo], {
            certo: tipo === "casa" ? janela.t(c.nome + " agora é uma rede de casa", c.nome + " is now a home network")
                                   : janela.t(c.nome + " agora é uma rede pública", c.nome + " is now a public network"),
            recarregar: ["rede"]
        });
        // Muda na hora (a resposta confirma ou volta).
        var novo = JSON.parse(JSON.stringify(janela.rede));
        for (var i = 0; i < novo.conexoes.length; i++)
            if (novo.conexoes[i].uuid === c.uuid)
                novo.conexoes[i].rede = tipo;
        janela.rede = novo;
    }
    function servico(s, ligar) {
        var novo = JSON.parse(JSON.stringify(janela.rede));
        for (var i = 0; i < novo.servicos.length; i++)
            if (novo.servicos[i].id === s.id)
                novo.servicos[i].ligado = ligar;
        janela.rede = novo;
        janela.agir("servico-" + s.id, ["rede-servico", s.id, ligar ? "sim" : "nao"], { recarregar: ["rede"] });
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

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Texto {
                    text: janela.t("Rede e firewall", "Network & firewall")
                    font.pixelSize: Math.round(janela.gu * 1.3)
                    font.weight: Font.DemiBold
                }
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("O firewall decide quem de fora pode falar com este computador.", "The firewall decides who outside can talk to this computer.")
                    opacity: 0.65
                    wrapMode: Text.WordWrap
                }
            }

            // ----- o firewall -----
            Cartao {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.4)
                implicitHeight: linhaFirewall.implicitHeight + Math.round(janela.gu * 2.2)

                RowLayout {
                    id: linhaFirewall
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Math.round(janela.gu * 1.1)
                    spacing: Math.round(janela.gu * 0.9)

                    IconeRedondo {
                        implicitWidth: Math.round(janela.gu * 2.8)
                        icone: pagina.firewall === "ligado" ? "matsu-escudo-symbolic" : janela.ic("escudo-alerta")
                        cor: pagina.lendo ? janela.corEstado("") : pagina.firewall === "ligado" ? janela.verde : pagina.firewall === "desligado" ? janela.coral : janela.corEstado("")
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Esqueleto {
                            visible: pagina.lendo
                            Layout.preferredWidth: Math.round(janela.gu * 10)
                            Layout.preferredHeight: Math.round(janela.gu * 0.8)
                        }
                        Texto {
                            Layout.fillWidth: true
                            visible: !pagina.lendo
                            text: pagina.firewall === "ligado" ? janela.t("Firewall ligado", "Firewall on")
                                : pagina.firewall === "desligado" ? janela.t("Firewall desligado", "Firewall off")
                                : janela.t("Não foi possível conferir o firewall", "Couldn't check the firewall")
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Texto {
                            Layout.fillWidth: true
                            visible: !pagina.lendo
                            text: pagina.firewall === "ligado"
                                ? (pagina.r.padraoMatsu ? janela.t("Toda rede nova começa como pública.",
                                                                   "Every new network starts as public.")
                                                        : janela.t("Ligado, mas a rede nova não começa como pública (zona padrão: ", "On, but new networks don't start as public (default zone: ") + pagina.r.padrao + ").")
                                : pagina.firewall === "desligado" ? janela.t("Aparelhos da rede podem tentar entrar.",
                                                                             "Devices on the network can try to get in.")
                                : pagina.firewall === "indisponivel" ? janela.t("O firewalld não está instalado aqui.", "firewalld isn't installed here.")
                                : janela.t("O ajudante não conseguiu ler o estado do firewalld.", "The helper couldn't read firewalld's state.")
                            opacity: 0.68
                            wrapMode: Text.WordWrap
                        }
                    }
                    BotaoDestaque {
                        visible: pagina.firewall === "desligado"
                        texto: janela.t("Ligar o firewall", "Turn on firewall")
                        estado: janela.ocupado["firewall"] ? "carregando" : ""
                        onClicado: janela.agir("firewall", ["firewall-ligar"], { certo: janela.t("Firewall ligado", "Firewall on"), recarregar: ["rede", "inicio"] })
                    }
                    Botao {
                        visible: pagina.firewall === "ligado" && pagina.r && !pagina.r.padraoMatsu
                        texto: janela.t("Usar o padrão do Matsu", "Use Matsu's default")
                        icone: janela.ic("restaurar")
                        ativo: !janela.ocupado["padrao"]
                        onClicado: janela.agir("padrao", ["rede-padrao"], { certo: janela.t("Rede nova agora começa como pública", "New networks now start as public"), recarregar: ["rede"] })
                    }
                }
            }

            // ----- as redes ligadas agora -----
            Secao {
                titulo: janela.t("Redes ligadas agora", "Connected networks")
                texto: janela.t("O Matsu lembra a escolha de cada rede.",
                                "Matsu remembers the choice for each network.")
            }
            Cartao {
                Layout.fillWidth: true
                visible: !pagina.lendo && pagina.conexoes.length === 0
                implicitHeight: semRede.implicitHeight + Math.round(janela.gu * 1.8)
                RowLayout {
                    id: semRede
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Math.round(janela.gu * 1.1)
                    spacing: Math.round(janela.gu * 0.9)
                    IconeRedondo {
                        icone: "matsu-rede-desconectada-symbolic"
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: pagina.r && pagina.r.nm === false ? janela.t("O NetworkManager não está disponível aqui.", "NetworkManager isn't available here.")
                                                                : janela.t("Nenhuma rede ligada agora. Quando você entrar numa, ela aparece aqui.", "No network connected now. When you join one, it shows up here.")
                        opacity: 0.7
                        wrapMode: Text.WordWrap
                    }
                }
            }
            Repeater {
                model: pagina.conexoes
                Cartao {
                    id: cartaoRede
                    required property var modelData
                    readonly property bool casa: modelData.rede === "casa"
                    Layout.fillWidth: true
                    implicitHeight: colunaRede.implicitHeight + Math.round(janela.gu * 2.2)

                    ColumnLayout {
                        id: colunaRede
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Math.round(janela.gu * 1.1)
                        spacing: Math.round(janela.gu * 0.8)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(janela.gu * 0.9)
                            IconeRedondo {
                                icone: cartaoRede.modelData.tipo === "cabo" ? "matsu-rede-cabo-symbolic"
                                     : cartaoRede.modelData.tipo === "celular" ? janela.ic("celular") : "matsu-wifi-3-symbolic"
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Texto {
                                    Layout.fillWidth: true
                                    text: cartaoRede.modelData.nome
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    text: (cartaoRede.modelData.tipo === "cabo" ? janela.t("Cabo", "Wired") : cartaoRede.modelData.tipo === "celular" ? janela.t("Celular", "Mobile") : "Wi-Fi")
                                          + (cartaoRede.modelData.rede === "outra" ? janela.t(" · configuração própria (zona ", " · custom setup (zone ") + cartaoRede.modelData.efetiva + ")" : "")
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.6
                                    elide: Text.ElideRight
                                }
                            }
                            Girando {
                                width: Math.round(janela.gu * 1.1)
                                height: width
                                visible: !!janela.ocupado["tipo-" + cartaoRede.modelData.uuid]
                            }
                        }

                        // Pública ou de casa: dois cartões grandes de escolher.
                        GridLayout {
                            Layout.fillWidth: true
                            columns: colunaRede.width > janela.gu * 26 ? 2 : 1
                            columnSpacing: Math.round(janela.gu * 0.6)
                            rowSpacing: Math.round(janela.gu * 0.6)
                            Repeater {
                                model: [
                                    { id: "publica", icone: "cafe", nome: janela.t("Rede pública", "Public network"),
                                      texto: janela.t("Café, aeroporto, hotel. Ninguém entra.",
                                                      "Café, airport, hotel. Nobody gets in.") },
                                    { id: "casa", icone: "casa", nome: janela.t("Rede de casa", "Home network"),
                                      texto: janela.t("Impressora, TV e celular encontram você.",
                                                      "Printer, TV and phone can find you.") }
                                ]
                                MouseArea {
                                    id: opcaoRede
                                    required property var modelData
                                    readonly property bool escolhida: cartaoRede.modelData.rede === modelData.id
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: colunaOpcao.implicitHeight + Math.round(janela.gu * 1.4)
                                    hoverEnabled: true
                                    cursorShape: escolhida ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.RadioButton
                                    Accessible.name: modelData.nome
                                    Accessible.checked: escolhida
                                    onClicked: if (!escolhida && !janela.ocupado["tipo-" + cartaoRede.modelData.uuid]) pagina.trocarTipo(cartaoRede.modelData, modelData.id)
                                    Keys.onSpacePressed: clicked(null)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Math.round(janela.gu * 0.45)
                                        color: opcaoRede.escolhida ? janela.tinta(janela.escuro ? 0.09 : 0.06) : janela.tinta(opcaoRede.containsMouse ? 0.04 : 0)
                                        border.width: opcaoRede.escolhida ? 2 : 1
                                        border.color: opcaoRede.escolhida ? janela.frente : janela.tinta(opcaoRede.activeFocus ? 0.5 : 0.12)
                                        Behavior on color {
                                            ColorAnimation { duration: 160 }
                                        }
                                    }
                                    ColumnLayout {
                                        id: colunaOpcao
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: Math.round(janela.gu * 0.7)
                                        spacing: Math.round(janela.gu * 0.3)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Math.round(janela.gu * 0.5)
                                            Kirigami.Icon {
                                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                                Layout.preferredHeight: Layout.preferredWidth
                                                source: janela.ic(opcaoRede.modelData.icone)
                                                isMask: true
                                                color: janela.frente
                                            }
                                            Texto {
                                                Layout.fillWidth: true
                                                text: opcaoRede.modelData.nome
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                            }
                                            // A bolinha de escolha, que enche com um pulo.
                                            Rectangle {
                                                Layout.preferredWidth: Math.round(janela.gu * 1)
                                                Layout.preferredHeight: Layout.preferredWidth
                                                radius: width / 2
                                                color: "transparent"
                                                border.width: opcaoRede.escolhida ? 0 : 1.5
                                                border.color: janela.tinta(0.45)
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: opcaoRede.escolhida ? parent.width : 0
                                                    height: width
                                                    radius: width / 2
                                                    color: janela.destaque
                                                    Behavior on width {
                                                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 }
                                                    }
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: parent.width * 0.38
                                                        height: width
                                                        radius: width / 2
                                                        color: janela.sobreDestaque
                                                    }
                                                }
                                            }
                                        }
                                        Texto {
                                            Layout.fillWidth: true
                                            text: opcaoRede.modelData.texto
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            opacity: 0.68
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ----- o que entra na rede de casa -----
            Secao {
                visible: pagina.servicos.length > 0 && !pagina.falhou
                titulo: janela.t("Na rede de casa, deixar entrar", "On home networks, allow")
                texto: janela.t("Na rede pública nada disso entra.",
                                "On public networks none of this gets in.")
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: pagina.servicos.length > 0 && !pagina.falhou
                Repeater {
                    model: pagina.servicos
                    LinhaOpcao {
                        id: linhaServico
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        primeira: index === 0
                        ultima: index === pagina.servicos.length - 1
                        icone: pagina.iconeServico(modelData)
                        nome: modelData.nome
                        texto: modelData.texto
                        Chave {
                            nome: linhaServico.modelData.nome
                            ligada: linhaServico.modelData.ligado
                            onTrocada: (v) => pagina.servico(linhaServico.modelData, v)
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: !!pagina.r && pagina.r.casaMudada
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Você mudou o que entra na rede de casa.", "You changed what's allowed on home networks.")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.6
                }
                Botao {
                    texto: janela.t("Voltar ao padrão", "Restore default")
                    icone: janela.ic("restaurar")
                    ativo: !janela.ocupado["padrao"]
                    onClicado: janela.agir("padrao", ["rede-padrao"], { certo: janela.t("A rede de casa voltou ao padrão do Matsu", "Home network restored to Matsu's default"), recarregar: ["rede"] })
                }
            }

            // ----- a verdade sobre bloquear apps -----
            Sanfona {
                Layout.topMargin: Math.round(janela.gu * 0.5)
                titulo: janela.t("E para bloquear um app de usar a internet?", "What about blocking an app from the internet?")
                icone: "matsu-info-symbolic"
                Texto {
                    width: parent.width
                    text: janela.t("O firewall do Matsu cuida do que entra: ninguém de fora abre uma conexão com este computador sem você deixar. Ele não separa o que sai por app: o firewalld do Fedora não sabe qual programa abriu cada conexão, e um bloqueio desses seria fácil de driblar.",
                                   "Matsu's firewall handles what comes in: nobody outside opens a connection to this computer unless you allow it. It doesn't filter outgoing traffic per app: Fedora's firewalld doesn't know which program opened each connection, and such a block would be easy to bypass.")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.75
                    wrapMode: Text.WordWrap
                }
                Texto {
                    width: parent.width
                    text: janela.t("Para os apps da Loja dá, e de verdade: em Permissões dos apps, desligue a Rede do app e ele fica sem internet nenhuma.",
                                   "For Store apps you can, for real: in App permissions, turn off the app's Network and it has no internet at all.")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.75
                    wrapMode: Text.WordWrap
                }
                Botao {
                    texto: janela.t("Abrir Permissões dos apps", "Open App permissions")
                    icone: "matsu-apps-symbolic"
                    onClicado: janela.pagina = "apps"
                }
            }
        }
    }
}
