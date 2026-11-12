// Caixinha de marcar: ao marcar, ela "pula" (encolhe e volta um pouco maior) e o
// visto é desenhado da esquerda para a direita. "redonda" para listas de tarefas.
//   Marca { marcada: feito; onTrocada: (m) => feito = m }
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

MouseArea {
    id: marca

    property bool marcada: false
    property bool redonda: false
    property string nome: ""

    signal trocada(bool marcada)

    implicitWidth: Math.round(janela.gu * 1.15)
    implicitHeight: implicitWidth
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: nome
    Accessible.checkable: true
    Accessible.checked: marcada
    onClicked: marca.trocada(!marcada)
    Keys.onSpacePressed: marca.trocada(!marcada)
    Keys.onReturnPressed: marca.trocada(!marcada)

    onMarcadaChanged: if (marcada) pulo.restart()

    Rectangle {
        id: caixa
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        radius: marca.redonda ? width / 2 : Math.round(width * 0.3)
        color: marca.marcada ? janela.destaque : janela.tinta(marca.pressed ? 0.1 : (marca.containsMouse ? 0.06 : 0))
        border.width: marca.marcada ? 0 : 1.5
        border.color: janela.tinta(marca.containsMouse ? 0.6 : 0.42)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        // Anel de foco do teclado.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: marca.redonda ? width / 2 : parent.radius + 3
            color: "transparent"
            border.width: marca.activeFocus ? 1.5 : 0
            border.color: janela.frente
        }
        // O visto aparece da esquerda para a direita.
        Item {
            id: revela
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: marca.marcada ? caixa.width : 0
            clip: true
            Behavior on width {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
            Shape {
                width: caixa.width
                height: caixa.height
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: janela.sobreDestaque
                    strokeWidth: Math.max(1.6, caixa.width * 0.12)
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: caixa.width * 0.27
                    startY: caixa.height * 0.52
                    PathLine { x: caixa.width * 0.43; y: caixa.height * 0.68 }
                    PathLine { x: caixa.width * 0.74; y: caixa.height * 0.35 }
                }
            }
        }
    }
    SequentialAnimation {
        id: pulo
        NumberAnimation { target: caixa; property: "scale"; to: 0.82; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: caixa; property: "scale"; to: 1.0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }
}
