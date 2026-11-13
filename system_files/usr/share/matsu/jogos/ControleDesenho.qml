// Um controle desenhado (sem logo de marca): os botões acendem e os direcionais
// andam conforme o estado que o ajudante lê do controle (testar <eventN>).
// O jeito muda com o tipo: no PlayStation os dois direcionais ficam embaixo e os
// botões são △ ○ ✕ □; no Xbox (e nos outros) o direcional esquerdo fica em cima
// e os botões são Y B A X.
//   ControleDesenho { tipo: "playstation"; estado: janela.teste; cor: "#b18cf5" }
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: desenho

    property string tipo: "outro"
    property var estado: null
    property color cor: janela.frente
    readonly property bool ps: tipo === "playstation"
    // A cor do símbolo em cima do botão aceso (contraste com a cor do tipo).
    readonly property color sobreCor: (0.299 * cor.r + 0.587 * cor.g + 0.114 * cor.b) > 0.6 ? "#141416" : "#ffffff"
    readonly property color corPeca: janela.tinta(janela.escuro ? 0.1 : 0.07)
    readonly property color corBorda: janela.tinta(janela.escuro ? 0.28 : 0.24)

    function botao(nome) {
        return estado && estado.botoes ? estado.botoes[nome] === 1 : false;
    }
    function eixo(nome) {
        return estado && estado.eixos ? (estado.eixos[nome] || 0) : 0;
    }

    implicitWidth: 400
    implicitHeight: 262

    // O desenho é feito em 400 x 262 e cresce junto com o espaço.
    Item {
        id: tela
        width: 400
        height: 262
        scale: Math.min(desenho.width / width, desenho.height / height)
        transformOrigin: Item.TopLeft
        x: (desenho.width - width * scale) / 2

        // ----- gatilhos (L2 e R2): enchem conforme o aperto -----
        Repeater {
            model: [{ nome: "l2", x: 76, rotulo: desenho.ps ? "L2" : "LT" }, { nome: "r2", x: 280, rotulo: desenho.ps ? "R2" : "RT" }]
            Rectangle {
                id: gatilho
                required property var modelData
                readonly property real valor: Math.max(desenho.eixo(modelData.nome), desenho.botao(modelData.nome + "b") ? 1 : 0)
                x: modelData.x
                y: 0
                width: 44
                height: 26
                radius: 8
                color: desenho.corPeca
                border.width: 1.5
                border.color: desenho.corBorda
                clip: true
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * gatilho.valor
                    radius: 8
                    color: desenho.cor
                    opacity: 0.35 + 0.65 * gatilho.valor
                    Behavior on height {
                        NumberAnimation { duration: 60 }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    renderType: Text.QtRendering
                    text: gatilho.modelData.rotulo
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: gatilho.valor > 0.5 ? desenho.sobreCor : janela.frente
                    opacity: 0.85
                }
            }
        }

        // ----- ombros (L1 e R1), atrás do corpo -----
        Repeater {
            model: [{ nome: "l1", x: 60 }, { nome: "r1", x: 268 }]
            Rectangle {
                required property var modelData
                readonly property bool aceso: desenho.botao(modelData.nome)
                x: modelData.x
                y: 32
                width: 72
                height: 20
                radius: 9
                color: aceso ? desenho.cor : desenho.corPeca
                border.width: 1.5
                border.color: aceso ? desenho.cor : desenho.corBorda
                Behavior on color {
                    ColorAnimation { duration: 80 }
                }
            }
        }

        // ----- o corpo -----
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: janela.escuro ? Qt.rgba(0.17, 0.17, 0.19, 1) : Qt.rgba(0.97, 0.97, 0.98, 1)
                strokeColor: desenho.corBorda
                strokeWidth: 2
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: "M 130 46 C 160 38 240 38 270 46 C 330 50 362 70 376 120 C 390 170 396 222 366 240 "
                          + "C 340 254 318 236 300 212 C 290 198 280 190 262 190 L 138 190 C 120 190 110 198 100 212 "
                          + "C 82 236 60 254 34 240 C 4 222 10 170 24 120 C 38 70 70 50 130 46 Z"
                }
            }
        }

        // ----- painel do meio (o touchpad do PlayStation) -----
        Rectangle {
            visible: desenho.ps
            x: 156
            y: 52
            width: 88
            height: 50
            radius: 10
            color: desenho.corPeca
            border.width: 1.5
            border.color: desenho.corBorda
        }

        // ----- Select / Start (Share / Options, View / Menu) -----
        Repeater {
            model: [{ nome: "select", x: desenho.ps ? 136 : 166, y: desenho.ps ? 58 : 92 },
                    { nome: "start", x: desenho.ps ? 250 : 220, y: desenho.ps ? 58 : 92 }]
            Rectangle {
                required property var modelData
                readonly property bool aceso: desenho.botao(modelData.nome)
                x: modelData.x
                y: modelData.y
                width: 14
                height: 22
                radius: 7
                color: aceso ? desenho.cor : desenho.corPeca
                border.width: 1.5
                border.color: aceso ? desenho.cor : desenho.corBorda
            }
        }

        // ----- botão do meio (PS / Xbox / Home): só um círculo, sem logo -----
        Rectangle {
            readonly property bool aceso: desenho.botao("guia")
            x: 200 - width / 2
            y: desenho.ps ? 124 : 62
            width: desenho.ps ? 20 : 26
            height: width
            radius: width / 2
            color: aceso ? desenho.cor : desenho.corPeca
            border.width: 1.5
            border.color: aceso ? desenho.cor : desenho.corBorda
        }

        // ----- direcional digital (setas) -----
        Item {
            id: setas
            readonly property real cx: desenho.ps ? 100 : 150
            readonly property real cy: desenho.ps ? 105 : 150
            Repeater {
                model: [{ nome: "cima", x: -10, y: -32, w: 20, h: 23 }, { nome: "baixo", x: -10, y: 9, w: 20, h: 23 },
                        { nome: "esquerda", x: -32, y: -10, w: 23, h: 20 }, { nome: "direita", x: 9, y: -10, w: 23, h: 20 }]
                Rectangle {
                    required property var modelData
                    readonly property bool aceso: desenho.botao(modelData.nome)
                    x: setas.cx + modelData.x
                    y: setas.cy + modelData.y
                    width: modelData.w
                    height: modelData.h
                    radius: 5
                    color: aceso ? desenho.cor : desenho.corPeca
                    border.width: 1.5
                    border.color: aceso ? desenho.cor : desenho.corBorda
                }
            }
            Rectangle {
                x: setas.cx - 10
                y: setas.cy - 10
                width: 20
                height: 20
                color: desenho.corPeca
            }
        }

        // ----- botões de ação -----
        Repeater {
            model: [{ nome: "norte", dx: 0, dy: -25, letra: "Y" }, { nome: "leste", dx: 25, dy: 0, letra: "B" },
                    { nome: "sul", dx: 0, dy: 25, letra: "A" }, { nome: "oeste", dx: -25, dy: 0, letra: "X" }]
            Rectangle {
                id: acao
                required property var modelData
                readonly property bool aceso: desenho.botao(modelData.nome)
                readonly property color simbolo: aceso ? desenho.sobreCor : janela.frente
                x: 300 + modelData.dx - width / 2
                y: 105 + modelData.dy - height / 2
                width: 28
                height: 28
                radius: 14
                color: aceso ? desenho.cor : desenho.corPeca
                border.width: 1.5
                border.color: aceso ? desenho.cor : desenho.corBorda
                scale: aceso ? 0.92 : 1
                Behavior on scale {
                    NumberAnimation { duration: 70 }
                }
                Text {
                    anchors.centerIn: parent
                    renderType: Text.QtRendering
                    visible: !desenho.ps
                    text: acao.modelData.letra
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: acao.simbolo
                    opacity: acao.aceso ? 1 : 0.8
                }
                // △ ○ ✕ □ desenhados (são as marcas dos botões, não uma logo).
                Shape {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    visible: desenho.ps
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: acao.simbolo
                        strokeWidth: 1.6
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathSvg {
                            path: ({ norte: "M 6 1 L 11.5 10.5 L 0.5 10.5 Z",
                                     leste: "M 6 0.8 A 5.2 5.2 0 1 1 5.99 0.8 Z",
                                     sul: "M 1.5 1.5 L 10.5 10.5 M 10.5 1.5 L 1.5 10.5",
                                     oeste: "M 1.5 1.5 L 10.5 1.5 L 10.5 10.5 L 1.5 10.5 Z" })[acao.modelData.nome]
                        }
                    }
                }
            }
        }

        // ----- direcionais analógicos -----
        component Direcional: Item {
            id: dir
            property string eixoX: "lx"
            property string eixoY: "ly"
            property string clique: "l3"
            property real cx: 0
            property real cy: 0
            readonly property bool aceso: desenho.botao(clique)
            Rectangle {
                x: dir.cx - 27
                y: dir.cy - 27
                width: 54
                height: 54
                radius: 27
                color: desenho.corPeca
                border.width: 1.5
                border.color: desenho.corBorda
            }
            Rectangle {
                x: dir.cx - 17 + 12 * desenho.eixo(dir.eixoX)
                y: dir.cy - 17 + 12 * desenho.eixo(dir.eixoY)
                width: 34
                height: 34
                radius: 17
                color: dir.aceso ? desenho.cor : (janela.escuro ? Qt.rgba(0.27, 0.27, 0.3, 1) : Qt.rgba(1, 1, 1, 1))
                border.width: 1.5
                border.color: dir.aceso ? desenho.cor : desenho.corBorda
                Behavior on x {
                    NumberAnimation { duration: 50 }
                }
                Behavior on y {
                    NumberAnimation { duration: 50 }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 10
                    color: "transparent"
                    border.width: 1.2
                    border.color: dir.aceso ? desenho.sobreCor : desenho.corBorda
                    opacity: 0.7
                }
            }
        }
        Direcional {
            cx: desenho.ps ? 150 : 100
            cy: desenho.ps ? 150 : 105
        }
        Direcional {
            eixoX: "rx"
            eixoY: "ry"
            clique: "r3"
            cx: 250
            cy: 150
        }
    }
}
