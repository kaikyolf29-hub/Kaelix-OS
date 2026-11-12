// Rodinha de "carregando": um arco que gira e estica, na cor da frente.
//   Girando { width: janela.gu; rodando: carregando }
import QtQuick
import QtQuick.Shapes

Item {
    id: girando

    property color cor: janela.frente
    property bool rodando: visible
    readonly property real espessura: Math.max(1.6, width / 8)

    implicitWidth: Math.round(janela.gu * 1.1)
    implicitHeight: implicitWidth

    Shape {
        id: forma
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: girando.cor
            strokeWidth: girando.espessura
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                id: arco
                centerX: girando.width / 2
                centerY: girando.height / 2
                radiusX: Math.max(1, girando.width / 2 - girando.espessura / 2)
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 80
            }
        }
        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 1100
            loops: Animation.Infinite
            running: girando.rodando
        }
    }
    // O arco cresce e encolhe enquanto gira (como no Windows 11 e no Android).
    SequentialAnimation {
        running: girando.rodando
        loops: Animation.Infinite
        NumberAnimation { target: arco; property: "sweepAngle"; from: 40; to: 270; duration: 700; easing.type: Easing.InOutCubic }
        ParallelAnimation {
            NumberAnimation { target: arco; property: "sweepAngle"; from: 270; to: 40; duration: 700; easing.type: Easing.InOutCubic }
            NumberAnimation { target: arco; property: "startAngle"; from: -90; to: 140; duration: 700; easing.type: Easing.InOutCubic }
        }
        PropertyAction { target: arco; property: "startAngle"; value: -90 }
    }
}
