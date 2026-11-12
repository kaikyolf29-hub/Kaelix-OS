// Botão principal de uma página (como o botão cheio do Windows 11): fundo na cor
// de destaque e o texto na cor que contrasta com ela (nunca texto escuro em cor escura).
// Estados (como o "Send → Sent ✓" do vídeo de referência):
//   estado: "carregando"  a rodinha gira no lugar do texto
//   estado: "feito"       o fundo vira verde, o visto pula e aparece textoFeito
// "perigo": vermelho, para apagar e desinstalar.
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property string texto: ""
    property string icone: ""
    // Ícone com as cores dele (a logo de um app), em vez de pintado com a cor do texto.
    property bool iconeColorido: false
    property bool ativo: true
    property bool perigo: false
    property string estado: ""
    property string textoFeito: janela.t("Pronto", "Done")

    signal clicado()

    readonly property bool feito: estado === "feito"
    readonly property bool carregando: estado === "carregando"
    readonly property color fundo: feito ? (janela.escuro ? "#2fa66a" : "#23915a") : (perigo ? (janela.escuro ? "#e5484d" : "#d93036") : janela.destaque)
    readonly property bool fundoClaro: (0.299 * fundo.r + 0.587 * fundo.g + 0.114 * fundo.b) > 0.6
    readonly property color letra: fundoClaro ? "#141416" : "#ffffff"
    readonly property bool podeClicar: ativo && !carregando

    implicitWidth: Math.max(linha.implicitWidth, linhaFeito.implicitWidth) + Math.round(janela.gu * 1.6)
    implicitHeight: Math.round(janela.gu * 2)
    hoverEnabled: true
    cursorShape: podeClicar ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: ativo
    Accessible.role: Accessible.Button
    Accessible.name: feito ? textoFeito : texto
    onClicked: if (podeClicar) botao.clicado()
    Keys.onReturnPressed: if (podeClicar) botao.clicado()
    Keys.onSpacePressed: if (podeClicar) botao.clicado()
    onFeitoChanged: if (feito) pulo.restart()

    Rectangle {
        id: caixa
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.35)
        scale: botao.pressed && botao.podeClicar ? 0.97 : 1
        color: !botao.ativo ? janela.tinta(0.12) : (botao.pressed ? Qt.darker(botao.fundo, 1.12) : (botao.containsMouse && !botao.feito ? Qt.lighter(botao.fundo, botao.fundoClaro ? 1.0 : 1.1) : botao.fundo))
        opacity: botao.containsMouse && botao.fundoClaro && !botao.pressed && !botao.feito ? 0.9 : 1
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.longDuration
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 120
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
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: botao.activeFocus ? 1.5 : 0
            border.color: janela.frente
        }
    }
    RowLayout {
        id: linha
        anchors.centerIn: parent
        spacing: Math.round(janela.gu * 0.45)
        opacity: botao.estado === "" ? (botao.ativo ? 1 : 0.5) : 0
        scale: botao.estado === "" ? 1 : 0.85
        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Kirigami.Icon {
            visible: botao.icone.length > 0
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            source: botao.icone
            isMask: !botao.iconeColorido
            color: botao.letra
        }
        Texto {
            text: botao.texto
            color: botao.ativo ? botao.letra : janela.frente
            font.weight: Font.DemiBold
        }
    }
    Girando {
        anchors.centerIn: parent
        width: Math.round(botao.height * 0.5)
        cor: botao.letra
        rodando: botao.carregando
        opacity: botao.carregando ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }
    }
    RowLayout {
        id: linhaFeito
        anchors.centerIn: parent
        spacing: Math.round(janela.gu * 0.4)
        opacity: botao.feito ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
        Texto {
            text: botao.textoFeito
            color: botao.letra
            font.weight: Font.DemiBold
        }
        Shape {
            id: visto
            readonly property real lado: Math.round(janela.gu * 0.8)
            Layout.preferredWidth: lado
            Layout.preferredHeight: lado
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: botao.letra
                strokeWidth: 2.2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: visto.lado * 0.12
                startY: visto.lado * 0.52
                PathLine { x: visto.lado * 0.4; y: visto.lado * 0.8 }
                PathLine { x: visto.lado * 0.9; y: visto.lado * 0.22 }
            }
        }
    }
    SequentialAnimation {
        id: pulo
        NumberAnimation { target: visto; property: "scale"; from: 0.3; to: 1.25; duration: 220; easing.type: Easing.OutQuad }
        NumberAnimation { target: visto; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }
}
