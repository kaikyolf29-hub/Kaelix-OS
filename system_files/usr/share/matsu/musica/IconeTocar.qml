// O ícone de tocar e pausar que vira um no outro: as duas barras da pausa se
// deformam nas duas metades do triângulo (e voltam), em vez de só trocar a imagem.
//   IconeTocar { width: 20; height: 20; tocando: player.tocando; cor: "#fff" }
import QtQuick
import QtQuick.Shapes

Item {
    id: icone

    property bool tocando: false
    property color cor: janela.frente
    // 0: pausa (as duas barras); 1: tocar (o triângulo). Mostra "pausa" enquanto toca.
    property real fase: tocando ? 0 : 1
    Behavior on fase {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    implicitWidth: 20
    implicitHeight: 20

    // Pontos numa grade de 24: [pausa, tocar] de cada canto.
    readonly property var esquerda: [[[6.2, 5], [8, 4.8]], [[10.2, 5], [13.8, 8.4]], [[10.2, 19], [13.8, 15.6]], [[6.2, 19], [8, 19.2]]]
    readonly property var direita: [[[13.8, 5], [13.8, 8.4]], [[17.8, 5], [19.6, 12]], [[17.8, 19], [19.6, 12]], [[13.8, 19], [13.8, 15.6]]]
    function px(p) {
        return (p[0][0] + (p[1][0] - p[0][0]) * fase) * width / 24;
    }
    function py(p) {
        return (p[0][1] + (p[1][1] - p[0][1]) * fase) * height / 24;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Um pulinho no meio da troca.
        scale: 1 - 0.12 * Math.sin(icone.fase * Math.PI)

        ShapePath {
            fillColor: icone.cor
            strokeColor: icone.cor
            strokeWidth: Math.max(1, icone.width * 0.07)
            joinStyle: ShapePath.RoundJoin
            startX: icone.px(icone.esquerda[0])
            startY: icone.py(icone.esquerda[0])
            PathLine { x: icone.px(icone.esquerda[1]); y: icone.py(icone.esquerda[1]) }
            PathLine { x: icone.px(icone.esquerda[2]); y: icone.py(icone.esquerda[2]) }
            PathLine { x: icone.px(icone.esquerda[3]); y: icone.py(icone.esquerda[3]) }
            PathLine { x: icone.px(icone.esquerda[0]); y: icone.py(icone.esquerda[0]) }
        }
        ShapePath {
            fillColor: icone.cor
            strokeColor: icone.cor
            strokeWidth: Math.max(1, icone.width * 0.07)
            joinStyle: ShapePath.RoundJoin
            startX: icone.px(icone.direita[0])
            startY: icone.py(icone.direita[0])
            PathLine { x: icone.px(icone.direita[1]); y: icone.py(icone.direita[1]) }
            PathLine { x: icone.px(icone.direita[2]); y: icone.py(icone.direita[2]) }
            PathLine { x: icone.px(icone.direita[3]); y: icone.py(icone.direita[3]) }
            PathLine { x: icone.px(icone.direita[0]); y: icone.py(icone.direita[0]) }
        }
    }
}
