// O botão de cada app, como o da Microsoft Store: "Obter" (cheio), "Abrir",
// "Atualizar" ou, durante a instalação, a pílula enchendo com um anel pequeno do
// progresso e a porcentagem (que rola, algarismo por algarismo). Preparando ou
// removendo, a rodinha gira; no fim, a pílula fica verde com "Instalado ✓" por uns
// segundos. Com o mouse em cima do progresso, vira "Cancelar". Os que já vêm no
// Matsu (a Steam, por exemplo) só abrem. A largura acompanha o texto, deslizando.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
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
    readonly property bool trabalhando: estado === "trabalhando"
    readonly property bool feito: estado === "feito"
    readonly property bool cheio: estado === "obter" || estado === "atualizar"
    // O que aparece antes do texto: a rodinha (sem porcentagem ainda) ou o anel.
    readonly property bool comAnel: trabalhando && !naFila && progresso > 0 && acao !== "remover" && !containsMouse
    readonly property bool comRodinha: trabalhando && !naFila && !comAnel && !containsMouse

    readonly property color verde: janela.escuro ? "#2fa66a" : "#23915a"
    readonly property color fundo: sobreCor ? "#ffffff" : janela.destaque
    readonly property bool fundoClaro: (0.299 * fundo.r + 0.587 * fundo.g + 0.114 * fundo.b) > 0.6
    readonly property color letraCheia: fundoClaro ? "#141416" : "#ffffff"
    readonly property color letra: feito ? "#ffffff" : (cheio ? letraCheia : (sobreCor ? "#ffffff" : janela.frente))

    readonly property string texto: {
        if (trabalhando) {
            if (containsMouse)
                return janela.t("Cancelar", "Cancel");
            if (naFila)
                return janela.t("Na fila", "Queued");
            if (acao === "remover")
                return janela.t("Removendo", "Removing");
            if (acao === "atualizar")
                return janela.t("Atualizando", "Updating");
            return progresso > 0 ? "" : janela.t("Preparando", "Preparing");
        }
        if (feito)
            return acao === "atualizar" ? janela.t("Atualizado", "Updated") : janela.t("Instalado", "Installed");
        return ({ obter: janela.t("Obter", "Get"), abrir: janela.t("Abrir", "Open"), sistema: janela.t("Abrir", "Open"),
                  atualizar: janela.t("Atualizar", "Update") })[estado] || "";
    }

    implicitWidth: Math.max(Math.round(janela.gu * (grande ? 7.6 : 4.8)), linha.implicitWidth + Math.round(janela.gu * 1.6))
    implicitHeight: Math.round(janela.gu * (grande ? 2.2 : 1.65))
    hoverEnabled: true
    cursorShape: feito ? Qt.ArrowCursor : Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: comAnel ? (texto + " " + janela.porcento(progresso)).trim() : texto
    scale: pressed && !feito ? 0.96 : 1
    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    function clicar() {
        if (trabalhando)
            janela.cancelar(appId);
        else if (estado === "obter")
            janela.instalar(appId);
        else if (estado === "atualizar")
            janela.atualizar(appId);
        else if (!feito)
            janela.abrir(appId);
    }
    onClicked: clicar()
    Keys.onReturnPressed: clicar()
    Keys.onSpacePressed: clicar()
    // A troca de texto entra de leve (não pisca de uma palavra para outra).
    onTextoChanged: troca.restart()
    onFeitoChanged: if (feito) pulo.restart()

    // A pílula: cheia (Obter, Atualizar), verde (Instalado) ou um vidro leve (Abrir, progresso).
    Rectangle {
        id: pilula
        anchors.fill: parent
        radius: height / 2
        color: {
            if (botao.feito)
                return botao.verde;
            if (botao.cheio)
                return botao.pressed ? Qt.darker(botao.fundo, 1.12) : (botao.containsMouse ? Qt.lighter(botao.fundo, botao.fundoClaro ? 1.0 : 1.12) : botao.fundo);
            if (botao.sobreCor)
                return Qt.rgba(1, 1, 1, botao.containsMouse ? 0.26 : 0.18);
            return janela.tinta(botao.pressed ? 0.16 : (botao.containsMouse ? 0.12 : 0.08));
        }
        opacity: botao.cheio && botao.fundoClaro && botao.containsMouse && !botao.pressed ? 0.88 : 1
        border.width: botao.cheio || botao.feito ? 0 : 1
        border.color: botao.sobreCor ? Qt.rgba(1, 1, 1, 0.25) : janela.tinta(0.1)
        clip: true
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.longDuration
            }
        }

        // O progresso enchendo da esquerda para a direita.
        Rectangle {
            opacity: botao.trabalhando && !botao.naFila && botao.progresso > 0 ? 1 : 0
            visible: opacity > 0
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
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                }
            }
        }
        // Na fila: um brilho que passa devagar.
        Rectangle {
            id: brilho
            visible: botao.trabalhando && botao.naFila
            width: parent.width * 0.45
            height: parent.height
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: botao.sobreCor ? Qt.rgba(1, 1, 1, 0.3) : janela.tinta(0.1) }
                GradientStop { position: 1; color: "transparent" }
            }
            NumberAnimation on x {
                running: brilho.visible
                loops: Animation.Infinite
                from: -brilho.width
                to: pilula.width
                duration: 2200
                easing.type: Easing.InOutSine
            }
        }
        // Brilho de cima para baixo quando fica pronto.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: botao.feito ? 1 : 0
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.22) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                }
            }
        }
        // Anel de foco do teclado.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: botao.activeFocus ? 1.5 : 0
            border.color: botao.cheio || botao.feito ? botao.letra : janela.destaque
        }
    }

    RowLayout {
        id: linha
        anchors.centerIn: parent
        spacing: Math.round(janela.gu * 0.35)

        // A rodinha ou o anel do progresso.
        Item {
            id: indicador
            readonly property real lado: Math.round(janela.gu * (botao.grande ? 0.95 : 0.75))
            visible: botao.comAnel || botao.comRodinha
            Layout.preferredWidth: lado
            Layout.preferredHeight: lado
            Girando {
                anchors.fill: parent
                visible: botao.comRodinha
                cor: botao.letra
            }
            Shape {
                id: anel
                anchors.fill: parent
                visible: botao.comAnel
                preferredRendererType: Shape.CurveRenderer
                readonly property real espessura: Math.max(1.6, indicador.lado / 7)
                readonly property real raio: Math.max(1, indicador.lado / 2 - espessura / 2)
                property real volta: 360 * Math.max(0, Math.min(100, botao.progresso)) / 100
                Behavior on volta {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.rgba(botao.letra.r, botao.letra.g, botao.letra.b, 0.25)
                    strokeWidth: anel.espessura
                    PathAngleArc {
                        centerX: indicador.lado / 2
                        centerY: indicador.lado / 2
                        radiusX: anel.raio
                        radiusY: anel.raio
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: botao.letra
                    strokeWidth: anel.espessura
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: indicador.lado / 2
                        centerY: indicador.lado / 2
                        radiusX: anel.raio
                        radiusY: anel.raio
                        startAngle: -90
                        sweepAngle: Math.max(1, anel.volta)
                    }
                }
            }
        }
        Texto {
            id: rotulo
            visible: text !== ""
            text: botao.texto
            color: botao.letra
            font.weight: Font.DemiBold
            font.pointSize: botao.grande ? Kirigami.Theme.defaultFont.pointSize + 0.5 : Kirigami.Theme.defaultFont.pointSize - 0.5
        }
        NumeroRolante {
            visible: botao.comAnel
            texto: janela.porcento(botao.progresso)
            font: rotulo.font
            cor: botao.letra
            duracao: 360
        }
        // O visto do "Instalado".
        Shape {
            id: visto
            readonly property real lado: Math.round(janela.gu * (botao.grande ? 0.8 : 0.65))
            visible: botao.feito
            Layout.preferredWidth: lado
            Layout.preferredHeight: lado
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: botao.letra
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: visto.lado * 0.12
                startY: visto.lado * 0.52
                PathLine { x: visto.lado * 0.4; y: visto.lado * 0.8 }
                PathLine { x: visto.lado * 0.9; y: visto.lado * 0.22 }
            }
        }
    }
    ParallelAnimation {
        id: troca
        NumberAnimation { target: linha; property: "opacity"; from: 0.25; to: 1; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: linha; property: "scale"; from: 0.9; to: 1; duration: 260; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: pulo
        NumberAnimation { target: visto; property: "scale"; from: 0.3; to: 1.25; duration: 220; easing.type: Easing.OutQuad }
        NumberAnimation { target: visto; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }

    QQC2.ToolTip.visible: estado === "sistema" && containsMouse
    QQC2.ToolTip.text: janela.t("Já vem no Matsu", "Comes with Matsu")
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
