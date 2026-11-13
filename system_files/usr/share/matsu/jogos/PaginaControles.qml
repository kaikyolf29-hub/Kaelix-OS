// Controles: os de PlayStation, Xbox e outros pelo Bluetooth (e os de cabo),
// com o nome de gente, se está conectado e a bateria. Daqui dá para parear um
// controle novo passo a passo, desconectar, esquecer e testar os botões ao vivo.
// Quem fala com o Bluetooth e lê o controle é o ajudante (controles.py).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Flickable {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.4)
    readonly property var info: janela.controles
    readonly property var bt: info ? info.bluetooth : null
    readonly property var lista: info ? info.controles : []
    readonly property bool semAdaptador: bt !== null && (!bt.tem || !bt.programa)
    readonly property bool desligado: bt !== null && bt.tem && bt.programa && !bt.ligado
    readonly property bool podeParear: bt !== null && bt.tem && bt.programa
    // Escolhendo o tipo antes de procurar (o pareamento em si mora na janela).
    property bool escolhendo: false
    property string escolhido: "ps5"
    readonly property string modo: janela.controleEmTeste ? "teste" : ((escolhendo || janela.pareamento) ? "parear" : "lista")

    function corTipo(tipo) {
        return janela.escuro ? ({ playstation: "#b18cf5", xbox: "#7fcf6a", nintendo: "#f0609e", steam: "#45d0c1" })[tipo] || "#f5b330"
                             : ({ playstation: "#7650dc", xbox: "#3d9533", nintendo: "#d23f78", steam: "#0f9c8e" })[tipo] || "#c98a12";
    }
    function tipoDaBusca(escolha) {
        return ({ ps5: "playstation", ps4: "playstation", xbox: "xbox" })[escolha] || "outro";
    }
    function comecarPareamento() {
        escolhendo = false;
        janela.parear(tipoDaBusca(escolhido));
    }
    function voltarParaLista() {
        escolhendo = false;
        if (janela.pareando)
            janela.cancelarPareamento();
        janela.pareamento = null;
    }
    function esquecer(c) {
        janela.perguntar({ titulo: janela.t("Esquecer o " + c.nome + "?", "Forget " + c.nome + "?"),
                           texto: janela.t("Para usar de novo, vai ser preciso parear outra vez.", "To use it again, you'll need to pair it again."),
                           sim: janela.t("Esquecer", "Forget"), nao: janela.t("Cancelar", "Cancel"), perigo: true },
                         function () { janela.acaoControle("esquecer", c.mac); });
    }

    contentHeight: coluna.implicitHeight + 2 * margem
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: BarraRolagem {}
    onModoChanged: contentY = 0

    // Uma parte da página que entra subindo de leve quando aparece.
    component Parte: ColumnLayout {
        id: parte
        property bool ativa: false
        visible: ativa
        Layout.fillWidth: true
        spacing: Math.round(janela.gu * 0.5)
        onAtivaChanged: if (ativa) entrada.restart()
        transform: Translate { id: desliza }
        ParallelAnimation {
            id: entrada
            NumberAnimation { target: parte; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: desliza; property: "y"; from: 14; to: 0; duration: 320; easing.type: Easing.OutCubic }
        }
    }

    // A bateria desenhada, com a porcentagem rolando e o raio quando carrega.
    component Bateria: Row {
        id: bat
        property int valor: -1
        property bool carregando: false
        readonly property color corCarga: valor >= 0 && valor <= 20 && !carregando ? (janela.escuro ? "#f0609e" : "#d23f78")
                                                                                 : (janela.escuro ? "#7fcf6a" : "#3d9533")
        spacing: Math.round(janela.gu * 0.35)
        visible: valor >= 0
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: bat.carregando
            width: Kirigami.Units.iconSizes.small - 2
            height: width
            source: "matsu-raio-symbolic"
            isMask: true
            color: bat.corCarga
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(janela.gu * 1.6)
            height: Math.round(janela.gu * 0.8)
            Rectangle {
                id: casca
                width: parent.width - 3
                height: parent.height
                radius: 3
                color: "transparent"
                border.width: 1.5
                border.color: janela.tinta(0.45)
                Rectangle {
                    x: 2.5
                    y: 2.5
                    height: parent.height - 5
                    width: Math.max(2, (parent.width - 5) * bat.valor / 100)
                    radius: 1.5
                    color: bat.corCarga
                    Behavior on width {
                        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                    }
                }
            }
            Rectangle {
                anchors.left: casca.right
                anchors.leftMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: parent.height * 0.45
                radius: 1
                color: janela.tinta(0.45)
            }
        }
        NumeroRolante {
            anchors.verticalCenter: parent.verticalCenter
            texto: bat.valor + "%"
            font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
            font.features: { "tnum": 1 }
        }
    }

    ColumnLayout {
        id: coluna
        x: pagina.margem
        y: pagina.margem
        width: pagina.width - 2 * pagina.margem
        spacing: Math.round(janela.gu * 0.5)

        // =====================================================================
        // A lista
        // =====================================================================
        Parte {
            ativa: pagina.modo === "lista"
            opacity: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.8)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Texto {
                        text: janela.t("Controles", "Controllers")
                        font.pixelSize: Math.round(janela.gu * 1.3)
                        font.weight: Font.DemiBold
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: janela.t("PlayStation, Xbox e outros pelo Bluetooth. Com cabo USB, é só ligar.",
                                       "PlayStation, Xbox and others over Bluetooth. With a USB cable, just plug it in.")
                        wrapMode: Text.WordWrap
                        opacity: 0.65
                    }
                }
                BotaoDestaque {
                    visible: pagina.podeParear && !pagina.desligado && pagina.lista.length > 0
                    texto: janela.t("Parear um controle", "Pair a controller")
                    icone: "matsu-mais-symbolic"
                    onClicado: pagina.escolhendo = true
                }
            }

            // Bluetooth desligado: o aviso e o botão de ligar.
            Cartao {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.5)
                visible: pagina.desligado
                implicitHeight: linhaBt.implicitHeight + Math.round(janela.gu * 1.4)
                RowLayout {
                    id: linhaBt
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.7)
                    spacing: Math.round(janela.gu * 0.7)
                    Rectangle {
                        Layout.preferredWidth: Math.round(janela.gu * 2.2)
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: width / 2
                        color: janela.tinta(0.07)
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.small
                            height: width
                            source: "matsu-bluetooth-symbolic"
                            isMask: true
                            color: janela.frente
                            opacity: 0.8
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Texto {
                            text: janela.t("O Bluetooth está desligado", "Bluetooth is off")
                            font.weight: Font.DemiBold
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: janela.t("Ligue para ver e parear os controles sem fio.", "Turn it on to see and pair wireless controllers.")
                            wrapMode: Text.WordWrap
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.65
                        }
                    }
                    BotaoDestaque {
                        texto: janela.t("Ligar o Bluetooth", "Turn on Bluetooth")
                        estado: janela.ligandoBluetooth ? "carregando" : ""
                        onClicado: janela.ligarBluetooth()
                    }
                }
            }

            // Os controles, um cartão para cada.
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.5)
                visible: pagina.lista.length > 0
                columns: coluna.width > janela.gu * 34 ? 2 : 1
                columnSpacing: Math.round(janela.gu * 0.6)
                rowSpacing: Math.round(janela.gu * 0.6)

                Repeater {
                    model: pagina.lista

                    Cartao {
                        id: cartao
                        required property var modelData
                        required property int index
                        readonly property var c: modelData
                        readonly property color cor: pagina.corTipo(c.tipo)
                        readonly property bool ocupado: janela.controleOcupado === c.mac && c.mac !== ""
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: miolo.implicitHeight + Math.round(janela.gu * 1.4)
                        opacity: 0
                        Component.onCompleted: aparece.start()
                        NumberAnimation {
                            id: aparece
                            target: cartao
                            property: "opacity"
                            to: 1
                            duration: 300
                            easing.type: Easing.OutCubic
                        }

                        ColumnLayout {
                            id: miolo
                            anchors.fill: parent
                            anchors.margins: Math.round(janela.gu * 0.7)
                            spacing: Math.round(janela.gu * 0.6)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(janela.gu * 0.7)
                                Rectangle {
                                    Layout.preferredWidth: Math.round(janela.gu * 2.8)
                                    Layout.preferredHeight: Layout.preferredWidth
                                    radius: Math.round(width * 0.3)
                                    color: Qt.rgba(cartao.cor.r, cartao.cor.g, cartao.cor.b, janela.escuro ? 0.18 : 0.13)
                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        width: Kirigami.Units.iconSizes.medium
                                        height: width
                                        source: Qt.resolvedUrl("icones/controle.svg")
                                        isMask: true
                                        color: cartao.cor
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Texto {
                                        Layout.fillWidth: true
                                        text: cartao.c.nome
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Row {
                                        spacing: 6
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 7
                                            height: 7
                                            radius: 3.5
                                            color: cartao.c.conectado ? (janela.escuro ? "#7fcf6a" : "#3d9533") : janela.tinta(0.3)
                                        }
                                        Texto {
                                            text: (cartao.c.conectado ? janela.t("Conectado", "Connected") : janela.t("Desconectado", "Disconnected"))
                                                  + " · " + (cartao.c.via === "cabo" ? janela.t("cabo USB", "USB cable") : "Bluetooth")
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            opacity: 0.7
                                        }
                                    }
                                }
                                Bateria {
                                    valor: cartao.c.conectado ? cartao.c.bateria : -1
                                    carregando: cartao.c.carregando
                                }
                            }

                            // Desconectado: como ligar de novo.
                            Texto {
                                Layout.fillWidth: true
                                visible: !cartao.c.conectado
                                text: cartao.c.tipo === "playstation" ? janela.t("Aperte o botão PS no controle para ligar.", "Press the PS button to turn it on.")
                                      : (cartao.c.tipo === "xbox" ? janela.t("Aperte o botão Xbox no controle para ligar.", "Press the Xbox button to turn it on.")
                                                                 : janela.t("Ligue o controle e ele conecta sozinho.", "Turn the controller on and it connects by itself."))
                                wrapMode: Text.WordWrap
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.6
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 1
                                color: janela.tinta(0.07)
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(janela.gu * 0.2)
                                Botao {
                                    visible: cartao.c.conectado && cartao.c.evento !== ""
                                    texto: janela.t("Testar", "Test")
                                    icone: Qt.resolvedUrl("icones/controle.svg")
                                    onClicado: janela.testar(cartao.c)
                                }
                                Botao {
                                    visible: cartao.c.via === "bluetooth" && cartao.c.conectado
                                    ativo: !cartao.ocupado
                                    texto: janela.t("Desconectar", "Disconnect")
                                    icone: "matsu-desligar-symbolic"
                                    onClicado: janela.acaoControle("desconectar", cartao.c.mac)
                                }
                                Botao {
                                    visible: cartao.c.via === "bluetooth" && !cartao.c.conectado && cartao.c.pareado
                                    ativo: !cartao.ocupado
                                    texto: janela.t("Conectar", "Connect")
                                    icone: "matsu-link-symbolic"
                                    onClicado: janela.acaoControle("conectar", cartao.c.mac)
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                Girando {
                                    visible: cartao.ocupado
                                    Layout.preferredWidth: Math.round(janela.gu * 0.9)
                                    Layout.preferredHeight: Layout.preferredWidth
                                }
                                Botao {
                                    visible: cartao.c.via === "bluetooth" && cartao.c.pareado
                                    ativo: !cartao.ocupado
                                    texto: janela.t("Esquecer", "Forget")
                                    icone: "matsu-lixeira-symbolic"
                                    onClicado: pagina.esquecer(cartao.c)
                                }
                            }
                        }
                    }
                }
            }

            // Nada para mostrar: sem Bluetooth, ou nenhum controle ainda.
            Item {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 1.5)
                visible: pagina.info !== null && pagina.lista.length === 0 && !pagina.desligado
                implicitHeight: vazio.implicitHeight + Math.round(janela.gu * 2)
                Vazio {
                    id: vazio
                    anchors.horizontalCenter: parent.horizontalCenter
                    icone: pagina.semAdaptador ? "matsu-bluetooth-symbolic" : Qt.resolvedUrl("icones/controle.svg")
                    titulo: pagina.semAdaptador ? (pagina.bt && !pagina.bt.tem ? janela.t("Este computador não tem Bluetooth", "This computer has no Bluetooth")
                                                                               : janela.t("Falta o programa do Bluetooth", "The Bluetooth tool is missing"))
                                                : janela.t("Nenhum controle ainda", "No controllers yet")
                    texto: pagina.semAdaptador ? janela.t("Controles com cabo USB funcionam do mesmo jeito: é só ligar. Para os sem fio, um adaptador USB de Bluetooth resolve.",
                                                          "USB controllers work just the same: plug them in. For wireless ones, a USB Bluetooth adapter does the trick.")
                                               : janela.t("Pareie um controle de PlayStation ou Xbox pelo Bluetooth. Com cabo USB, ele aparece aqui sozinho.",
                                                          "Pair a PlayStation or Xbox controller over Bluetooth. With a USB cable, it shows up here by itself.")
                    botao: pagina.podeParear ? janela.t("Parear um controle", "Pair a controller") : ""
                    onClicado: pagina.escolhendo = true
                }
            }

            // Ainda lendo pela primeira vez.
            Girando {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(janela.gu * 3)
                Layout.preferredWidth: Math.round(janela.gu * 1.4)
                Layout.preferredHeight: Layout.preferredWidth
                visible: pagina.info === null
            }

            // Dicas.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 1.2)
                visible: pagina.info !== null
                spacing: 2
                Texto {
                    Layout.bottomMargin: Math.round(janela.gu * 0.3)
                    text: janela.t("Bom saber", "Good to know")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1.5
                    font.weight: Font.DemiBold
                }
                LinhaOpcao {
                    Layout.fillWidth: true
                    ultima: false
                    icone: "matsu-jogos-symbolic"
                    nome: janela.t("Na Steam, todos funcionam", "On Steam, they all work")
                    texto: janela.t("A Steam traduz os botões de qualquer controle para o jogo (Steam Input), até nos jogos do Windows.",
                                    "Steam translates any controller's buttons for the game (Steam Input), even in Windows games.")
                }
                LinhaOpcao {
                    Layout.fillWidth: true
                    primeira: false
                    icone: "matsu-bluetooth-symbolic"
                    nome: janela.t("Liga e conecta sozinho", "Turns on and connects by itself")
                    texto: janela.t("Depois de pareado, é só apertar o botão do meio do controle: o Matsu conecta de novo.",
                                    "Once paired, just press the controller's middle button: Matsu connects it again.")
                }
            }
        }

        // =====================================================================
        // Parear um controle
        // =====================================================================
        Parte {
            id: parear
            ativa: pagina.modo === "parear"
            readonly property var p: janela.pareamento
            readonly property string etapa: p ? p.etapa : ""
            readonly property var ordem: ["procurando", "achou", "pareando", "confiando", "conectando", "pronto"]
            readonly property int passo: ordem.indexOf(etapa === "ligando" || etapa === "comecando" ? "procurando" : etapa)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.5)
                Botao {
                    icone: "matsu-voltar-symbolic"
                    dica: janela.t("Voltar para os controles", "Back to controllers")
                    onClicado: pagina.voltarParaLista()
                }
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Parear um controle", "Pair a controller")
                    font.pixelSize: Math.round(janela.gu * 1.3)
                    font.weight: Font.DemiBold
                }
            }

            // ----- 1. qual controle e como deixar ele pronto -----
            ColumnLayout {
                Layout.fillWidth: true
                visible: parear.p === null
                spacing: Math.round(janela.gu * 0.6)

                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Qual é o controle?", "Which controller is it?")
                    opacity: 0.65
                }
                Seletor {
                    opcoes: [{ id: "ps5", nome: "PS5 (DualSense)" }, { id: "ps4", nome: "PS4 (DualShock 4)" },
                             { id: "xbox", nome: "Xbox" }, { id: "outro", nome: janela.t("Outro", "Other") }]
                    escolhido: pagina.escolhido
                    onEscolher: (id) => pagina.escolhido = id
                }
                Cartao {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(janela.gu * 0.3)
                    implicitHeight: instrucoes.implicitHeight + Math.round(janela.gu * 1.8)

                    RowLayout {
                        id: instrucoes
                        anchors.fill: parent
                        anchors.margins: Math.round(janela.gu * 0.9)
                        spacing: Math.round(janela.gu * 1.2)

                        // O controle com os botões do pareamento acesos (piscando).
                        ControleDesenho {
                            id: dica
                            Layout.preferredWidth: Math.min(Math.round(janela.gu * 18), coluna.width * 0.42)
                            Layout.preferredHeight: Layout.preferredWidth * 262 / 400
                            Layout.alignment: Qt.AlignVCenter
                            tipo: pagina.tipoDaBusca(pagina.escolhido)
                            cor: pagina.corTipo(tipo)
                            property bool pisca: true
                            estado: ({ botoes: { select: pagina.escolhido.indexOf("ps") === 0 && pisca ? 1 : 0, guia: pisca && pagina.escolhido !== "outro" ? 1 : 0 }, eixos: {} })
                            Timer {
                                running: parear.ativa && parear.p === null
                                interval: 650
                                repeat: true
                                onTriggered: dica.pisca = !dica.pisca
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(janela.gu * 0.55)
                            Repeater {
                                model: ({
                                    ps5: [janela.t("Desligue o controle (segure o botão PS até a luz apagar).", "Turn the controller off (hold the PS button until the light goes out)."),
                                          janela.t("Segure o botão Create (à esquerda do touchpad) e o botão PS juntos.", "Hold the Create button (left of the touchpad) and the PS button together."),
                                          janela.t("Solte quando a luz em volta do touchpad piscar rápido, duas vezes seguidas.", "Let go when the light around the touchpad blinks fast, twice in a row.")],
                                    ps4: [janela.t("Desligue o controle (segure o botão PS por 10 segundos).", "Turn the controller off (hold the PS button for 10 seconds)."),
                                          janela.t("Segure o botão Share e o botão PS juntos.", "Hold the Share button and the PS button together."),
                                          janela.t("Solte quando a barra de luz piscar em rajadas rápidas.", "Let go when the light bar blinks in quick bursts.")],
                                    xbox: [janela.t("Ligue o controle no botão Xbox.", "Turn the controller on with the Xbox button."),
                                           janela.t("Segure o botão de parear, em cima do controle, perto da entrada do cabo.", "Hold the pair button on top of the controller, next to the cable port."),
                                           janela.t("Solte quando o botão Xbox piscar rápido.", "Let go when the Xbox button blinks fast.")],
                                    outro: [janela.t("Ligue o controle.", "Turn the controller on."),
                                            janela.t("Coloque ele no modo de parear (quase sempre é segurar um botão até a luz piscar rápido; veja o manual).", "Put it in pairing mode (usually holding a button until the light blinks fast; check the manual)."),
                                            janela.t("Deixe o controle pertinho do computador.", "Keep the controller close to the computer.")]
                                })[pagina.escolhido]
                                RowLayout {
                                    id: passoDica
                                    required property string modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: Math.round(janela.gu * 0.55)
                                    Rectangle {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.preferredWidth: Math.round(janela.gu * 1.3)
                                        Layout.preferredHeight: Layout.preferredWidth
                                        radius: width / 2
                                        color: janela.tinta(0.08)
                                        Texto {
                                            anchors.centerIn: parent
                                            text: passoDica.index + 1
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                    Texto {
                                        Layout.fillWidth: true
                                        text: passoDica.modelData
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(janela.gu * 0.3)
                    spacing: Math.round(janela.gu * 0.5)
                    Texto {
                        Layout.fillWidth: true
                        text: janela.t("Com a luz piscando, clique em Procurar.", "With the light blinking, click Search.")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.6
                    }
                    Botao {
                        texto: janela.t("Cancelar", "Cancel")
                        onClicado: pagina.voltarParaLista()
                    }
                    BotaoDestaque {
                        texto: janela.t("Procurar", "Search")
                        icone: "matsu-busca-symbolic"
                        onClicado: pagina.comecarPareamento()
                    }
                }
            }

            // ----- 2. procurando, pareando... pronto (ou o erro) -----
            Cartao {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.3)
                visible: parear.p !== null
                implicitHeight: andamento.implicitHeight + Math.round(janela.gu * 2.4)

                RowLayout {
                    id: andamento
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 1.2)
                    spacing: Math.round(janela.gu * 1.6)

                    // O anel: conta o tempo da busca, enche ao parear e vira o visto no fim.
                    Anel {
                        id: anel
                        Layout.preferredWidth: Math.round(janela.gu * 8)
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.alignment: Qt.AlignVCenter
                        readonly property bool erro: parear.etapa === "erro"
                        cor: erro ? (janela.escuro ? "#f0609e" : "#d23f78") : pagina.corTipo(janela.tipoPareando)
                        valor: erro ? 1 : (parear.etapa === "procurando" && parear.p.total > 0 ? parear.p.restam / parear.p.total
                                         : (parear.passo <= 0 ? 1 : (parear.passo + 1) / parear.ordem.length))
                        texto: ""
                        Item {
                            width: anel.width * 0.6
                            height: width
                            NumeroRolante {
                                anchors.centerIn: parent
                                visible: parear.etapa === "procurando"
                                texto: parear.p && parear.p.restam !== undefined ? String(parear.p.restam) : ""
                                font.pixelSize: Math.round(janela.gu * 1.9)
                                font.weight: Font.DemiBold
                            }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                visible: parear.etapa === "pronto" || parear.etapa === "erro"
                                width: Math.round(anel.width * 0.4)
                                height: width
                                source: parear.etapa === "erro" ? "matsu-alerta-symbolic" : "matsu-certo-symbolic"
                                isMask: true
                                color: anel.cor
                                scale: visible ? 1 : 0.4
                                Behavior on scale {
                                    NumberAnimation { duration: 380; easing.type: Easing.OutBack }
                                }
                            }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                visible: ["comecando", "ligando", "achou", "pareando", "confiando", "conectando"].indexOf(parear.etapa) >= 0
                                width: Math.round(janela.gu * 2.2)
                                height: width
                                source: parear.etapa === "ligando" ? "matsu-bluetooth-symbolic" : Qt.resolvedUrl("icones/controle.svg")
                                isMask: true
                                color: janela.frente
                                SequentialAnimation on opacity {
                                    running: parent.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.4; duration: 700; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Math.round(janela.gu * 0.45)

                        Texto {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                            font.weight: Font.DemiBold
                            text: {
                                var p = parear.p;
                                if (!p)
                                    return "";
                                switch (p.etapa) {
                                case "comecando": return janela.t("Preparando o Bluetooth…", "Getting Bluetooth ready…");
                                case "ligando": return janela.t("Ligando o Bluetooth…", "Turning Bluetooth on…");
                                case "procurando": return janela.t("Procurando o controle…", "Looking for the controller…");
                                case "achou": return janela.t("Achei: ", "Found: ") + p.nome;
                                case "pareando": return janela.t("Pareando com o ", "Pairing with ") + p.nome + "…";
                                case "confiando": return janela.t("Guardando o ", "Saving ") + p.nome + "…";
                                case "conectando": return janela.t("Conectando…", "Connecting…");
                                case "pronto": return p.nome + janela.t(" pronto para jogar", " is ready to play");
                                }
                                return ({ "sem-programa": janela.t("Falta o programa do Bluetooth", "The Bluetooth tool is missing"),
                                          "sem-adaptador": janela.t("Este computador não tem Bluetooth", "This computer has no Bluetooth"),
                                          "sem-servico": janela.t("O Bluetooth não respondeu", "Bluetooth didn't answer"),
                                          desligado: janela.t("Não deu para ligar o Bluetooth", "Couldn't turn Bluetooth on"),
                                          tempo: janela.t("Nenhum controle apareceu", "No controller showed up"),
                                          autenticacao: janela.t("O controle recusou o pareamento", "The controller refused to pair"),
                                          conectar: janela.t("Pareou, mas não conectou", "Paired, but didn't connect") })[p.erro]
                                       || janela.t("Algo deu errado no pareamento", "Something went wrong while pairing");
                            }
                        }
                        Texto {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            opacity: 0.68
                            text: {
                                var p = parear.p;
                                if (!p)
                                    return "";
                                if (p.etapa === "procurando" || p.etapa === "comecando" || p.etapa === "ligando")
                                    return janela.t("Deixe a luz do controle piscando rápido, pertinho do computador.", "Keep the controller's light blinking fast, close to the computer.");
                                if (p.etapa === "pronto")
                                    return janela.t("Da próxima vez, é só apertar o botão do meio: ele conecta sozinho.", "Next time, just press the middle button: it connects by itself.");
                                if (p.etapa !== "erro")
                                    return janela.t("Não desligue o controle.", "Don't turn the controller off.");
                                return ({ "sem-programa": janela.t("O bluetoothctl não está no sistema.", "bluetoothctl is not on the system."),
                                          "sem-adaptador": janela.t("Um adaptador USB de Bluetooth resolve. Controles com cabo funcionam sem ele.", "A USB Bluetooth adapter does the trick. Wired controllers work without it."),
                                          "sem-servico": janela.t("Reinicie o computador e tente de novo.", "Restart the computer and try again."),
                                          desligado: janela.t("Veja se o modo avião está desligado e tente de novo.", "Check that airplane mode is off and try again."),
                                          tempo: janela.t("Confira se a luz do controle está piscando rápido (não devagar) e tente de novo, com ele pertinho.", "Check that the light is blinking fast (not slow) and try again, with it close by."),
                                          autenticacao: janela.t("Desligue o controle, coloque no modo de parear de novo e tente outra vez.", "Turn the controller off, put it in pairing mode again and retry."),
                                          conectar: janela.t("Aperte o botão do meio (PS ou Xbox) para ligar o controle.", "Press the middle button (PS or Xbox) to turn the controller on.") })[p.erro]
                                       || janela.t("Tente de novo. Se continuar, desligue e ligue o Bluetooth.", "Try again. If it keeps happening, turn Bluetooth off and on.");
                            }
                        }

                        // As etapas, com o visto em cada uma que passou.
                        ColumnLayout {
                            Layout.topMargin: Math.round(janela.gu * 0.3)
                            visible: parear.etapa !== "erro"
                            spacing: Math.round(janela.gu * 0.3)
                            Repeater {
                                model: [{ id: "procurando", nome: janela.t("Achar o controle", "Find the controller") },
                                        { id: "pareando", nome: janela.t("Parear", "Pair") },
                                        { id: "confiando", nome: janela.t("Guardar no computador", "Save on this computer") },
                                        { id: "conectando", nome: janela.t("Conectar", "Connect") }]
                                RowLayout {
                                    id: etapaLinha
                                    required property var modelData
                                    readonly property int meu: parear.ordem.indexOf(modelData.id)
                                    readonly property bool feita: parear.passo > meu || parear.etapa === "pronto"
                                    readonly property bool agora: !feita && (parear.passo === meu || (meu === 0 && parear.passo <= 1))
                                    spacing: Math.round(janela.gu * 0.45)
                                    Item {
                                        Layout.preferredWidth: Math.round(janela.gu * 1)
                                        Layout.preferredHeight: Layout.preferredWidth
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            visible: !etapaLinha.agora
                                            color: etapaLinha.feita ? anel.cor : "transparent"
                                            border.width: etapaLinha.feita ? 0 : 1.5
                                            border.color: janela.tinta(0.3)
                                            Kirigami.Icon {
                                                anchors.centerIn: parent
                                                visible: etapaLinha.feita
                                                width: Math.round(parent.width * 0.8)
                                                height: width
                                                source: "matsu-certo-symbolic"
                                                isMask: true
                                                color: (0.299 * anel.cor.r + 0.587 * anel.cor.g + 0.114 * anel.cor.b) > 0.6 ? "#141416" : "#ffffff"
                                            }
                                        }
                                        Girando {
                                            anchors.fill: parent
                                            visible: etapaLinha.agora
                                        }
                                    }
                                    Texto {
                                        text: etapaLinha.modelData.nome
                                        opacity: etapaLinha.feita || etapaLinha.agora ? 1 : 0.5
                                        font.weight: etapaLinha.agora ? Font.DemiBold : Font.Normal
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.topMargin: Math.round(janela.gu * 0.5)
                            spacing: Math.round(janela.gu * 0.4)
                            BotaoDestaque {
                                visible: parear.etapa === "pronto"
                                texto: janela.t("Testar o controle", "Test the controller")
                                icone: Qt.resolvedUrl("icones/controle.svg")
                                onClicado: {
                                    var mac = parear.p.mac;
                                    var achado = null;
                                    for (var i = 0; i < pagina.lista.length; i++)
                                        if (pagina.lista[i].mac === mac && pagina.lista[i].evento)
                                            achado = pagina.lista[i];
                                    janela.pareamento = null;
                                    if (achado)
                                        janela.testar(achado);
                                    else
                                        janela.avisoRapido(janela.t("O controle ainda está ligando. Use Testar na lista daqui a pouco.",
                                                                    "The controller is still starting up. Use Test in the list in a moment."), "");
                                }
                            }
                            BotaoDestaque {
                                visible: parear.etapa === "erro"
                                texto: janela.t("Tentar de novo", "Try again")
                                icone: "matsu-recarregar-symbolic"
                                onClicado: janela.parear(janela.tipoPareando)
                            }
                            Botao {
                                texto: parear.etapa === "pronto" ? janela.t("Concluir", "Done")
                                       : (parear.etapa === "erro" ? janela.t("Voltar", "Back") : janela.t("Cancelar", "Cancel"))
                                onClicado: pagina.voltarParaLista()
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // Testar: o controle desenhado acompanha os botões e os direcionais
        // =====================================================================
        Parte {
            id: testar
            ativa: pagina.modo === "teste"
            readonly property var c: janela.controleEmTeste
            readonly property var e: janela.teste
            readonly property color cor: c ? pagina.corTipo(c.tipo) : janela.frente

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.5)
                Botao {
                    icone: "matsu-voltar-symbolic"
                    dica: janela.t("Voltar para os controles", "Back to controllers")
                    onClicado: janela.pararTeste()
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Texto {
                        Layout.fillWidth: true
                        text: janela.t("Testar o ", "Test the ") + (testar.c ? testar.c.nome : "")
                        font.pixelSize: Math.round(janela.gu * 1.3)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: janela.t("Aperte os botões e mexa os direcionais: o desenho acompanha.", "Press the buttons and move the sticks: the drawing follows along.")
                        wrapMode: Text.WordWrap
                        opacity: 0.65
                    }
                }
            }

            Cartao {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.5)
                implicitHeight: desenhoTeste.height + Math.round(janela.gu * 3)

                ControleDesenho {
                    id: desenhoTeste
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(janela.gu * 1.5)
                    width: Math.min(parent.width - janela.gu * 2, janela.gu * 30)
                    height: width * 262 / 400
                    tipo: testar.c ? testar.c.tipo : "outro"
                    estado: testar.e
                    cor: testar.cor
                    opacity: testar.e || janela.erroTeste ? 1 : 0.45
                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }
                }
                // Esperando o primeiro sinal do controle.
                Row {
                    anchors.centerIn: desenhoTeste
                    visible: !testar.e && !janela.erroTeste
                    spacing: Math.round(janela.gu * 0.5)
                    Girando {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(janela.gu * 1.1)
                        height: width
                    }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: janela.t("Esperando o controle…", "Waiting for the controller…")
                        font.weight: Font.DemiBold
                    }
                }
            }

            // Sem acesso, ou o controle saiu.
            Cartao {
                Layout.fillWidth: true
                visible: janela.erroTeste !== ""
                implicitHeight: linhaErro.implicitHeight + Math.round(janela.gu * 1.4)
                RowLayout {
                    id: linhaErro
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.7)
                    spacing: Math.round(janela.gu * 0.7)
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Layout.preferredWidth
                        source: "matsu-alerta-symbolic"
                        isMask: true
                        color: janela.frente
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Texto {
                            text: ({ acesso: janela.t("Sem permissão para ler o controle", "No permission to read the controller"),
                                     sumiu: janela.t("O controle desconectou", "The controller disconnected") })[janela.erroTeste]
                                  || janela.t("Não deu para ler o controle", "Couldn't read the controller")
                            font.weight: Font.DemiBold
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: janela.erroTeste === "acesso" ? janela.t("Desconecte e conecte o controle de novo. Se continuar, saia e entre na sessão.",
                                                                           "Disconnect and reconnect the controller. If it keeps happening, log out and back in.")
                                                                : janela.t("Ligue o controle e volte para a lista.", "Turn the controller on and go back to the list.")
                            wrapMode: Text.WordWrap
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.65
                        }
                    }
                }
            }

            // Os gatilhos e os direcionais em números.
            GridLayout {
                Layout.fillWidth: true
                visible: testar.e !== null && testar.e !== undefined
                columns: coluna.width > janela.gu * 34 ? 4 : 2
                columnSpacing: Math.round(janela.gu * 0.6)
                rowSpacing: Math.round(janela.gu * 0.6)
                Repeater {
                    model: [{ nome: testar.c && testar.c.tipo === "playstation" ? "L2" : "LT", valor: testar.e ? testar.e.eixos.l2 : 0, gatilho: true },
                            { nome: testar.c && testar.c.tipo === "playstation" ? "R2" : "RT", valor: testar.e ? testar.e.eixos.r2 : 0, gatilho: true },
                            { nome: janela.t("Direcional esquerdo", "Left stick"), x: testar.e ? testar.e.eixos.lx : 0, y: testar.e ? testar.e.eixos.ly : 0 },
                            { nome: janela.t("Direcional direito", "Right stick"), x: testar.e ? testar.e.eixos.rx : 0, y: testar.e ? testar.e.eixos.ry : 0 }]
                    Cartao {
                        id: medida
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: Math.round(janela.gu * 3.6)
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Math.round(janela.gu * 0.6)
                            spacing: 2
                            Texto {
                                Layout.fillWidth: true
                                text: medida.modelData.nome
                                elide: Text.ElideRight
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.65
                            }
                            NumeroRolante {
                                visible: medida.modelData.gatilho === true
                                texto: Math.round(100 * (medida.modelData.valor || 0)) + "%"
                                duracao: 160
                                font.pixelSize: Math.round(janela.gu * 1.15)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                            Texto {
                                visible: medida.modelData.gatilho !== true
                                text: "x " + janela.num(medida.modelData.x || 0, 2) + "   y " + janela.num(medida.modelData.y || 0, 2)
                                font.pixelSize: Math.round(janela.gu * 1.0)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
            }
        }
    }
}
