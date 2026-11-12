// Anel de progresso: o arco cheio anda até o valor (0 a 1) e, ao completar, o anel
// dá um pulinho. No meio, um texto grande e um pequeno (ou o que for posto dentro).
//   Anel { valor: 3 / 4; texto: "3/4"; subtexto: "tarefas" }
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: anel

    property real valor: 0
    property string texto: ""
    property string subtexto: ""
    property color cor: janela.destaque
    property color trilho: janela.tinta(janela.escuro ? 0.1 : 0.08)
    property real espessura: Math.max(3, Math.round(width * 0.09))
    default property alias conteudo: meio.data

    // O valor desenhado anda suave até o valor de verdade.
    property real mostrado: Math.max(0, Math.min(1, valor))
    Behavior on mostrado {
        NumberAnimation {
            duration: 750
            easing.type: Easing.OutCubic
        }
    }
    onValorChanged: if (valor >= 1) pulo.restart()

    implicitWidth: Math.round(janela.gu * 5)
    implicitHeight: implicitWidth

    Shape {
        id: forma
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: anel.trilho
            strokeWidth: anel.espessura
            PathAngleArc {
                centerX: anel.width / 2
                centerY: anel.height / 2
                radiusX: Math.max(1, anel.width / 2 - anel.espessura / 2)
                radiusY: radiusX
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: anel.mostrado > 0.001 ? anel.cor : "transparent"
            strokeWidth: anel.espessura
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: anel.width / 2
                centerY: anel.height / 2
                radiusX: Math.max(1, anel.width / 2 - anel.espessura / 2)
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * anel.mostrado
            }
        }
    }
    Column {
        id: meio
        anchors.centerIn: parent
        spacing: 0
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: anel.texto.length > 0
            text: anel.texto
            font.pixelSize: Math.round(anel.width * 0.22)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: anel.subtexto.length > 0
            text: anel.subtexto
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.6
        }
    }
    SequentialAnimation {
        id: pulo
        PauseAnimation { duration: 500 }
        NumberAnimation { target: anel; property: "scale"; to: 1.06; duration: 140; easing.type: Easing.OutQuad }
        NumberAnimation { target: anel; property: "scale"; to: 1.0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
    }
}
