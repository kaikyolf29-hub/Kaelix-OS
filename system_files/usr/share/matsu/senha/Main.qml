// A janela de senha do sistema (o agente do polkit do Matsu).
//
// Quando um programa pede permissão de administrador (instalar um driver, mudar
// o firewall, "abrir mesmo assim" no aviso de programa baixado...), aparece este
// alerta pequeno de vidro, no jeito do Mac: o cadeado, a pergunta, quem vai dar
// a permissão (a foto e o nome), a senha e os botões um embaixo do outro.
// Senha errada: o campo balança e avisa, sem fechar.
//
// Fica aberto a sessão inteira, escondido (matsu-senha.service, pela
// matsu-janela); o AgenteSenha (org.matsu.senha, build_files/deco/senha) é quem
// conversa com o polkit. Se não der para virar o agente, sai com o código 3 e o
// serviço abre o agente do KDE no lugar (matsu-senha-iniciar).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.matsu.senha
import "../comum"

JanelaMatsu {
    id: janela

    title: t("Permissão", "Permission")
    icone: "org.matsu.seguranca"
    iconeReserva: "matsu-cadeado-symbolic"
    paginas: []
    alerta: true
    visible: false

    readonly property int margem: Math.round(gu * 1.4)
    readonly property int larguraCerta: Math.round(gu * 18.5)
    readonly property int alturaCerta: Math.min(Math.round(gu * 36), Math.round(painel.implicitHeight) + margem + Math.round(gu * 1.6))
    width: larguraCerta
    height: alturaCerta
    minimumWidth: larguraCerta
    maximumWidth: larguraCerta
    minimumHeight: alturaCerta
    maximumHeight: alturaCerta

    readonly property color coral: escuro ? "#ff8b78" : "#c63f2b"
    readonly property color verde: escuro ? "#4fca8c" : "#1d8a50"

    property bool detalhes: false
    property string aviso: ""
    property bool aceito: false
    readonly property var pessoaAtual: agente.pessoas.length > agente.pessoa ? agente.pessoas[agente.pessoa] : null
    readonly property bool outraPessoa: pessoaAtual !== null && !pessoaAtual.eu

    // O nome do programa que vai rodar como administrador (pkexec), sem a pasta.
    readonly property string nomePrograma: agente.programa.length > 0 ? agente.programa.split("/").pop() : ""

    readonly property string titulo: nomePrograma.length > 0
        ? t("Rodar “" + nomePrograma + "” como administrador?", "Run “" + nomePrograma + "” as administrator?")
        : t("Permitir esta mudança?", "Allow this change?")
    // A frase do polkit já vem no idioma da pessoa ("É necessária autenticação para...").
    readonly property string texto: {
        var m = agente.mensagem.trim();
        if (m.length === 0)
            return t("Digite a senha para permitir.", "Enter the password to allow this.");
        return m.charAt(m.length - 1) === "." ? m : m + ".";
    }

    AgenteSenha {
        id: agente
        onPedido: janela.mostrar()
        onErro: (texto) => {
            if (texto === "senha-errada") {
                janela.aviso = janela.t("Senha errada. Tente de novo.", "Wrong password. Try again.");
                campo.texto = "";
                balanco.restart();
                campo.entrada.forceActiveFocus();
            } else if (texto === "sem-pessoa") {
                janela.aviso = janela.t("Nenhuma conta de administrador pode permitir isto.", "No administrator account can allow this.");
            } else if (texto === "falhou") {
                janela.aviso = janela.t("Não deu para conferir a senha agora. Tente de novo.", "Couldn't check the password right now. Try again.");
            } else if (texto.length > 0) {
                // Mensagem do sistema (PAM), como "conta travada por alguns minutos".
                console.warn("matsu-senha:", texto);
                janela.aviso = texto;
            }
        }
        onInfo: (texto) => janela.aviso = texto
        onTerminado: (autorizado) => {
            if (autorizado) {
                janela.aceito = true;
                pulo.restart();
                fechar.restart();
            } else {
                janela.esconder();
            }
        }
    }

    function mostrar() {
        // Um pedido logo depois do outro: a janela do anterior não pode fechar este.
        fechar.stop();
        aviso = "";
        aceito = false;
        detalhes = false;
        campo.texto = "";
        visible = true;
        raise();
        requestActivate();
        entrada.restart();
        campo.entrada.forceActiveFocus();
    }
    function esconder() {
        campo.texto = "";
        visible = false;
    }
    function permitir() {
        if (campo.texto.length === 0 || agente.esperando || aceito)
            return;
        aviso = "";
        agente.responder(campo.texto);
    }

    Timer {
        id: fechar
        interval: 650
        onTriggered: janela.esconder()
    }
    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: agente.cancelar()
    }
    // Fechar pela janela (Alt+F4) é o mesmo que Cancelar.
    onClosing: (fecho) => {
        fecho.accepted = false;
        agente.cancelar();
    }

    Component.onCompleted: {
        if (!agente.registrar()) {
            console.warn("matsu-senha: não deu para virar o agente de senha da sessão");
            Qt.exit(3);
        }
    }

    // ----- animações -----
    ParallelAnimation {
        id: entrada
        NumberAnimation { target: cadeado; property: "scale"; from: 0.8; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        NumberAnimation { target: cadeado; property: "opacity"; from: 0; to: 1; duration: 220 }
    }
    // Senha errada: o campo balança de um lado para o outro, como no Mac.
    SequentialAnimation {
        id: balanco
        NumberAnimation { target: campo; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
        NumberAnimation { target: campo; property: "anchors.horizontalCenterOffset"; to: 10; duration: 70 }
        NumberAnimation { target: campo; property: "anchors.horizontalCenterOffset"; to: -7; duration: 70 }
        NumberAnimation { target: campo; property: "anchors.horizontalCenterOffset"; to: 5; duration: 70 }
        NumberAnimation { target: campo; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
    }
    SequentialAnimation {
        id: pulo
        NumberAnimation { target: cadeado; property: "scale"; to: 1.12; duration: 140; easing.type: Easing.OutQuad }
        NumberAnimation { target: cadeado; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
    }

    // Botão de segunda opção (Cancelar): a mesma forma do principal, num cinza de vidro.
    component BotaoCalmo: MouseArea {
        id: calmo
        property string texto: ""
        signal clicado()
        Layout.fillWidth: true
        implicitHeight: Math.round(janela.gu * 2)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: texto
        onClicked: calmo.clicado()
        Keys.onReturnPressed: calmo.clicado()
        Keys.onSpacePressed: calmo.clicado()
        Rectangle {
            anchors.fill: parent
            radius: Math.round(janela.gu * 0.35)
            scale: calmo.pressed ? 0.97 : 1
            color: janela.tinta(calmo.pressed ? 0.16 : (calmo.containsMouse ? 0.12 : 0.08))
            border.width: calmo.activeFocus ? 1.5 : 0
            border.color: janela.frente
            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
            Behavior on scale {
                NumberAnimation { duration: 120 }
            }
        }
        Texto {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - janela.gu)
            text: calmo.texto
            elide: Text.ElideRight
        }
    }

    component LinhaDado: RowLayout {
        property string nome: ""
        property string valor: ""
        Layout.fillWidth: true
        spacing: Math.round(janela.gu * 0.6)
        visible: valor.length > 0
        Texto {
            Layout.alignment: Qt.AlignTop
            text: parent.nome
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.55
        }
        Texto {
            Layout.fillWidth: true
            text: parent.valor
            horizontalAlignment: Text.AlignRight
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }

    // ----- o miolo, direto no vidro -----
    ColumnLayout {
        id: painel
        parent: janela.contentItem
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: janela.margem
        anchors.leftMargin: janela.margem
        anchors.rightMargin: janela.margem
        spacing: 0

        // O cadeado, num círculo; vira o visto verde quando a senha é aceita.
        Item {
            id: cadeado
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(janela.gu * 3.4)
            implicitHeight: implicitWidth
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: janela.aceito ? Qt.rgba(janela.verde.r, janela.verde.g, janela.verde.b, 0.18) : janela.tinta(0.08)
                border.width: 1
                border.color: janela.tinta(0.1)
                Behavior on color {
                    ColorAnimation { duration: 250 }
                }
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.46)
                height: width
                isMask: true
                color: janela.aceito ? janela.verde : janela.frente
                source: janela.aceito ? "matsu-certo-symbolic" : "matsu-cadeado-symbolic"
            }
        }

        Texto {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.9)
            text: janela.titulo
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Math.round(janela.gu * 0.85)
            font.weight: Font.Bold
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
        Texto {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.35)
            text: janela.texto
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
            opacity: 0.68
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        // Quem dá a permissão: a foto e o nome. Com mais de um administrador, toca
        // para escolher outro.
        MouseArea {
            id: quem
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(janela.gu * 1)
            visible: janela.pessoaAtual !== null
            implicitWidth: linhaQuem.implicitWidth + Math.round(janela.gu * 1)
            implicitHeight: Math.round(janela.gu * 2.1)
            readonly property bool podeTrocar: agente.pessoas.length > 1
            hoverEnabled: podeTrocar
            cursorShape: podeTrocar ? Qt.PointingHandCursor : Qt.ArrowCursor
            activeFocusOnTab: podeTrocar
            Accessible.role: Accessible.Button
            Accessible.name: nomeQuem.text
            onClicked: if (podeTrocar) menuPessoas.abrirEm(quem, 0, quem.height)
            Keys.onReturnPressed: if (podeTrocar) menuPessoas.abrirEm(quem, 0, quem.height)
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: janela.tinta(quem.containsMouse ? 0.08 : 0.04)
                border.width: quem.activeFocus ? 1 : 0
                border.color: janela.frente
            }
            Row {
                id: linhaQuem
                anchors.centerIn: parent
                spacing: Math.round(janela.gu * 0.45)
                Foto {
                    anchors.verticalCenter: parent.verticalCenter
                    lado: Math.round(janela.gu * 1.5)
                    nome: janela.pessoaAtual ? janela.pessoaAtual.nome : ""
                    foto: janela.pessoaAtual ? janela.pessoaAtual.foto : ""
                }
                Texto {
                    id: nomeQuem
                    anchors.verticalCenter: parent.verticalCenter
                    text: janela.pessoaAtual ? janela.pessoaAtual.nome : ""
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, janela.larguraCerta - janela.gu * 7)
                }
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: quem.podeTrocar
                    width: Math.round(janela.gu * 0.7)
                    height: width
                    source: "matsu-seta-symbolic"
                    isMask: true
                    color: janela.frente
                    opacity: 0.6
                    rotation: 90
                }
            }
        }
        MenuMatsu {
            id: menuPessoas
            itens: agente.pessoas.map((p, i) => ({ id: String(i), nome: p.nome }))
            onEscolhido: (id) => {
                janela.aviso = "";
                agente.escolherPessoa(Number(id));
            }
        }

        // A senha (o campo balança quando está errada).
        Item {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.7)
            implicitHeight: campo.implicitHeight
            Campo {
                id: campo
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                senha: !agente.mostrarTexto
                podeLimpar: false
                enabled: !agente.esperando && !janela.aceito
                dica: janela.outraPessoa
                    ? janela.t("Senha de " + (janela.pessoaAtual ? janela.pessoaAtual.nome : ""), "Password for " + (janela.pessoaAtual ? janela.pessoaAtual.nome : ""))
                    : janela.t("Senha", "Password")
                onConfirmado: janela.permitir()
            }
        }
        Texto {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.4)
            visible: janela.aviso.length > 0
            text: janela.aviso
            color: janela.coral
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            wrapMode: Text.Wrap
        }

        // ----- os botões, um embaixo do outro -----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 1)
            spacing: Math.round(janela.gu * 0.45)

            BotaoDestaque {
                Layout.fillWidth: true
                texto: janela.t("Permitir", "Allow")
                estado: agente.esperando ? "carregando" : (janela.aceito ? "feito" : "")
                textoFeito: janela.t("Permitido", "Allowed")
                enabled: campo.texto.length > 0 || janela.aceito
                onClicado: janela.permitir()
            }
            BotaoCalmo {
                texto: janela.t("Cancelar", "Cancel")
                onClicado: agente.cancelar()
            }
        }

        // "Detalhes", discreto, no meio: a ação do polkit e o programa.
        MouseArea {
            id: mais
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(janela.gu * 0.55)
            implicitWidth: linhaMais.implicitWidth + Math.round(janela.gu * 0.8)
            implicitHeight: Math.round(janela.gu * 1.4)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: textoMais.text
            onClicked: janela.detalhes = !janela.detalhes
            Keys.onReturnPressed: janela.detalhes = !janela.detalhes
            Keys.onSpacePressed: janela.detalhes = !janela.detalhes
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: janela.tinta(mais.containsMouse ? 0.06 : 0)
                border.width: mais.activeFocus ? 1 : 0
                border.color: janela.frente
            }
            Row {
                id: linhaMais
                anchors.centerIn: parent
                spacing: Math.round(janela.gu * 0.25)
                Texto {
                    id: textoMais
                    anchors.verticalCenter: parent.verticalCenter
                    text: janela.detalhes ? janela.t("Menos detalhes", "Fewer details") : janela.t("Detalhes", "Details")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: mais.containsMouse ? 0.9 : 0.6
                }
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(janela.gu * 0.7)
                    height: width
                    source: "matsu-seta-symbolic"
                    isMask: true
                    color: janela.frente
                    opacity: textoMais.opacity
                    rotation: janela.detalhes ? -90 : 90
                    Behavior on rotation {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
        Cartao {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.45)
            visible: janela.detalhes
            implicitHeight: dados.implicitHeight + Math.round(janela.gu * 1.1)
            ColumnLayout {
                id: dados
                anchors.fill: parent
                anchors.margins: Math.round(janela.gu * 0.55)
                spacing: Math.round(janela.gu * 0.3)
                LinhaDado {
                    nome: janela.t("Ação", "Action")
                    valor: agente.acao
                }
                LinhaDado {
                    nome: janela.t("Programa", "Program")
                    valor: agente.programa
                }
                LinhaDado {
                    nome: janela.t("Comando", "Command")
                    valor: agente.comando
                }
            }
        }
    }

    // A foto redonda de quem dá a permissão (ou a primeira letra do nome).
    component Foto: Item {
        id: foto
        property string nome: ""
        property string foto: ""
        property real lado: 24
        width: lado
        height: lado
        readonly property bool temFoto: foto.length > 0 && imagem.status === Image.Ready
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: janela.tinta(0.14)
            visible: !foto.temFoto
            Texto {
                anchors.centerIn: parent
                text: foto.nome.trim().length > 0 ? foto.nome.trim().charAt(0).toUpperCase() : "?"
                font.pixelSize: Math.round(foto.lado * 0.48)
                font.weight: Font.DemiBold
            }
        }
        ImagemRedonda {
            id: imagem
            anchors.fill: parent
            raio: width / 2
            source: foto.foto.length > 0 ? "file://" + foto.foto : ""
            visible: foto.temFoto
        }
    }
}
