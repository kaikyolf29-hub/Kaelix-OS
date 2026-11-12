// O botão de cada app, como o da Microsoft Store: "Obter" (cheio), "Abrir",
// "Atualizar" ou, durante a instalação, a pílula enchendo com a porcentagem.
// Com o mouse em cima do progresso, vira "Cancelar". Os que já vêm no Matsu
// (a Steam, por exemplo) só abrem.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: botao

    property string appId: ""
    property bool grande: false
    // Em cima de uma cor forte (os destaques do Início): pílula branca.
    property bool sobreCor: false

    readonly property string estado: janela.estado(appId)
    readonly property real progresso: janela.progresso(appId)
    readonly property bool naFila: janela.emFila(appId)
    readonly property string acao: janela.acaoAgora(appId)
    readonly property bool cheio: estado === "obter" || estado === "atualizar"

    readonly property color fundo: sobreCor ? "#ffffff" : janela.destaque
    readonly property bool fundoClaro: (0.299 * fundo.r + 0.587 * fundo.g + 0.114 * fundo.b) > 0.6
    readonly property color letraCheia: fundoClaro ? "#141416" : "#ffffff"
    readonly property color letra: cheio ? letraCheia : (sobreCor ? "#ffffff" : janela.frente)

    readonly property string texto: {
        if (estado === "trabalhando") {
            if (containsMouse)
                return janela.t("Cancelar", "Cancel");
            if (naFila)
                return janela.t("Na fila", "Queued");
            var p = progresso > 0 && progresso < 100 ? " " + janela.porcento(progresso) : "";
            if (acao === "remover")
                return janela.t("Removendo", "Removing");
            if (acao === "atualizar")
                return janela.t("Atualizando", "Updating") + p;
            return progresso > 0 ? janela.porcento(progresso) : janela.t("Baixando", "Downloading");
        }
        return ({ obter: janela.t("Obter", "Get"), abrir: janela.t("Abrir", "Open"), sistema: janela.t("Abrir", "Open"),
                  atualizar: janela.t("Atualizar", "Update") })[estado] || "";
    }

    implicitWidth: Math.max(Math.round(janela.gu * (grande ? 7.6 : 4.8)), rotulo.implicitWidth + Math.round(janela.gu * 1.6))
    implicitHeight: Math.round(janela.gu * (grande ? 2.2 : 1.65))
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: texto
    scale: pressed ? 0.97 : 1
    Behavior on scale {
        NumberAnimation {
            duration: 90
        }
    }

    function clicar() {
        if (estado === "trabalhando")
            janela.cancelar(appId);
        else if (estado === "obter")
            janela.instalar(appId);
        else if (estado === "atualizar")
            janela.atualizar(appId);
        else
            janela.abrir(appId);
    }
    onClicked: clicar()
    Keys.onReturnPressed: clicar()
    Keys.onSpacePressed: clicar()

    // A pílula: cheia (Obter, Atualizar) ou um vidro leve (Abrir, progresso).
    Rectangle {
        id: pilula
        anchors.fill: parent
        radius: height / 2
        color: {
            if (botao.cheio)
                return botao.pressed ? Qt.darker(botao.fundo, 1.12) : (botao.containsMouse ? Qt.lighter(botao.fundo, botao.fundoClaro ? 1.0 : 1.12) : botao.fundo);
            if (botao.sobreCor)
                return Qt.rgba(1, 1, 1, botao.containsMouse ? 0.26 : 0.18);
            return janela.tinta(botao.pressed ? 0.16 : (botao.containsMouse ? 0.12 : 0.08));
        }
        opacity: botao.cheio && botao.fundoClaro && botao.containsMouse && !botao.pressed ? 0.88 : 1
        border.width: botao.cheio ? 0 : 1
        border.color: botao.sobreCor ? Qt.rgba(1, 1, 1, 0.25) : janela.tinta(0.1)
        clip: true
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }

        // O progresso enchendo da esquerda para a direita.
        Rectangle {
            visible: botao.estado === "trabalhando" && !botao.naFila && botao.progresso > 0
            height: parent.height
            width: Math.max(parent.height, parent.width * botao.progresso / 100)
            radius: height / 2
            color: botao.sobreCor ? Qt.rgba(1, 1, 1, 0.32) : (janela.vidroConf.cor ? Qt.rgba(janela.destaque.r, janela.destaque.g, janela.destaque.b, 0.45) : janela.tinta(0.2))
            Behavior on width {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
        }
        // Sem porcentagem ainda (preparando, na fila, removendo): um brilho que passa.
        Rectangle {
            id: brilho
            visible: botao.estado === "trabalhando" && botao.progresso <= 0
            width: parent.width * 0.45
            height: parent.height
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: botao.sobreCor ? Qt.rgba(1, 1, 1, 0.3) : janela.tinta(botao.naFila ? 0.08 : 0.16) }
                GradientStop { position: 1; color: "transparent" }
            }
            NumberAnimation on x {
                running: brilho.visible
                loops: Animation.Infinite
                from: -brilho.width
                to: pilula.width
                duration: botao.naFila ? 2200 : 1300
                easing.type: Easing.InOutSine
            }
        }
        // Anel de foco do teclado.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: botao.activeFocus ? 1.5 : 0
            border.color: botao.cheio ? botao.letraCheia : janela.destaque
        }
    }

    Texto {
        id: rotulo
        anchors.centerIn: parent
        text: botao.texto
        color: botao.letra
        font.weight: Font.DemiBold
        font.pointSize: botao.grande ? Kirigami.Theme.defaultFont.pointSize + 0.5 : Kirigami.Theme.defaultFont.pointSize - 0.5
        font.features: { "tnum": 1 }
    }

    QQC2.ToolTip.visible: estado === "sistema" && containsMouse
    QQC2.ToolTip.text: janela.t("Já vem no Matsu", "Comes with Matsu")
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
