// O botão de disparar, grande e redondo: um anel e o disco dentro. Afunda ao
// clicar e volta pulando. Em foto o disco é da cor de destaque; em vídeo fica
// vermelho e, gravando, vira um quadradinho de parar. Na contagem do
// temporizador mostra um X (clicar cancela).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: botao

    property string modo: "foto"     // foto, video
    property string estado: "parado" // parado, contando, gravando
    property bool ativo: true

    signal disparado()

    readonly property color vermelho: janela.escuro ? "#ff4d57" : "#e5363f"
    readonly property bool emVideo: modo === "video"
    readonly property bool gravando: estado === "gravando"
    readonly property bool contando: estado === "contando"
    readonly property color corDisco: emVideo || gravando ? vermelho : janela.destaque
    readonly property real lado: Math.min(width, height)

    implicitWidth: Math.round(janela.gu * 4.2)
    implicitHeight: implicitWidth
    hoverEnabled: true
    cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
    activeFocusOnTab: ativo
    Accessible.role: Accessible.Button
    Accessible.name: dica
    onClicked: if (ativo) botao.disparado()
    // Espaço e Enter chegam pelo atalho da janela (Main.qml); aqui não repetem.

    readonly property string dica: contando ? janela.t("Cancelar o temporizador", "Cancel timer")
                                  : gravando ? janela.t("Parar de gravar", "Stop recording")
                                  : emVideo ? janela.t("Gravar vídeo", "Record video")
                                  : janela.t("Tirar foto", "Take photo")

    Item {
        id: corpo
        anchors.centerIn: parent
        width: botao.lado
        height: botao.lado
        opacity: botao.ativo ? 1 : 0.38
        scale: botao.pressed && botao.ativo ? 0.88 : 1
        Behavior on scale {
            NumberAnimation {
                duration: botao.pressed ? 90 : 360
                easing.type: botao.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: 2.2
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
            }
        }

        // O anel de fora.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: janela.tinta(botao.containsMouse && botao.ativo ? 0.07 : 0.03)
            border.width: Math.max(3, Math.round(botao.lado * 0.05))
            border.color: botao.gravando ? Qt.rgba(botao.vermelho.r, botao.vermelho.g, botao.vermelho.b, 0.85) : janela.tinta(0.88)
            Behavior on border.color {
                ColorAnimation {
                    duration: Kirigami.Units.longDuration
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }

        // O disco de dentro, que vira o quadradinho de parar.
        Rectangle {
            id: disco
            readonly property real cheio: botao.lado - 2 * Math.round(botao.lado * 0.12)
            anchors.centerIn: parent
            width: botao.gravando ? Math.round(botao.lado * 0.38) : (botao.containsMouse && botao.ativo ? cheio - 3 : cheio)
            height: width
            radius: botao.gravando ? Math.round(botao.lado * 0.09) : width / 2
            color: botao.corDisco
            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on radius {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 260
                }
            }
            // Um brilho de cima, bem de leve, para o disco não ficar chapado.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.16) }
                    GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }

        // O X da contagem (cancelar).
        Shape {
            id: xis
            readonly property real l: Math.round(botao.lado * 0.26)
            anchors.centerIn: parent
            width: l
            height: l
            opacity: botao.contando ? 1 : 0
            scale: botao.contando ? 1 : 0.4
            visible: opacity > 0
            preferredRendererType: Shape.CurveRenderer
            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: botao.emVideo ? "#ffffff" : janela.sobreDestaque
                strokeWidth: 2.6
                capStyle: ShapePath.RoundCap
                startX: 0
                startY: 0
                PathLine { x: xis.l; y: xis.l }
                PathMove { x: xis.l; y: 0 }
                PathLine { x: 0; y: xis.l }
            }
        }

        // Anel de foco do teclado.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: width / 2
            color: "transparent"
            border.width: botao.activeFocus ? 1.5 : 0
            border.color: janela.frente
        }
    }

    QQC2.ToolTip.visible: containsMouse && ativo
    QQC2.ToolTip.text: dica + (contando ? " (Esc)" : janela.t(" (Espaço)", " (Space)"))
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
