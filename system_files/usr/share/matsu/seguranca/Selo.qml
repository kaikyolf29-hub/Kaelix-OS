// O selo da Central de segurança: um ensō (o círculo de um traço só, do pincel
// japonês) com um pinheiro dentro (matsu, o pinheiro que dá nome ao sistema).
// A cor diz o estado: verde protegido, âmbar pausado ou ainda sem a lista,
// coral quando algo pede atenção e cinza sem antivírus. Um selinho no canto
// repete o estado com um símbolo (não depende só da cor).
// Com "progresso" (0 a 1) o círculo vira o anel de uma verificação.
//   Selo { estado: janela.geral; progresso: janela.verRodando ? janela.verParte : -1 }
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: selo

    property string estado: "protegido"
    property real progresso: -1
    // Animações paradas quando o selo não está à vista.
    property bool vivo: visible
    property bool comSelinho: true
    readonly property color cor: janela.corEstado(estado)
    readonly property bool emProgresso: progresso >= 0
    readonly property real u: width / 100
    readonly property string simbolo: ({
        "protegido": "matsu-certo-symbolic",
        "pausado": Qt.resolvedUrl("icones/pausa.svg"),
        "atencao": "matsu-alerta-symbolic",
        "parado": "matsu-alerta-symbolic",
        "desligado": Qt.resolvedUrl("icones/menos.svg"),
        "baixando": "matsu-baixar-symbolic",
        "sem-lista": "matsu-baixar-symbolic",
        "indisponivel": Qt.resolvedUrl("icones/menos.svg")
    })[estado] || ""

    implicitWidth: Math.round(janela.gu * 8)
    implicitHeight: implicitWidth

    onEstadoChanged: pulo.restart()

    // ----- o brilho atrás, que respira devagar quando está tudo bem -----
    Rectangle {
        id: brilho
        property real forca: 1
        anchors.centerIn: parent
        width: parent.width * 0.84
        height: width
        radius: width / 2
        color: selo.cor
        opacity: (janela.escuro ? 0.11 : 0.09) * forca
        Behavior on color {
            ColorAnimation { duration: 400 }
        }
        SequentialAnimation on forca {
            running: selo.vivo && selo.estado === "protegido" && !selo.emProgresso
            loops: Animation.Infinite
            NumberAnimation { to: 1.7; duration: 2400; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 2400; easing.type: Easing.InOutSine }
        }
    }

    // ----- o ensō: um traço grosso que afina no fim, com uma folga -----
    Shape {
        id: enso
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: selo.emProgresso ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: 260 }
        }
        // Gira devagar enquanto a lista de ameaças chega.
        RotationAnimation on rotation {
            running: selo.vivo && selo.estado === "baixando" && !selo.emProgresso
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 4200
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: selo.cor
            strokeWidth: 6.4 * selo.u
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: 50 * selo.u
                centerY: 50 * selo.u
                radiusX: 44 * selo.u
                radiusY: radiusX
                startAngle: 118
                sweepAngle: 286
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: selo.cor
            strokeWidth: 3.6 * selo.u
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: 50 * selo.u
                centerY: 50 * selo.u
                radiusX: 44.6 * selo.u
                radiusY: radiusX
                startAngle: 400
                sweepAngle: 22
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: selo.cor
            strokeWidth: 1.8 * selo.u
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: 50 * selo.u
                centerY: 50 * selo.u
                radiusX: 45 * selo.u
                radiusY: radiusX
                startAngle: 420
                sweepAngle: 12
            }
        }
    }

    // ----- o anel da verificação, no lugar do ensō -----
    Shape {
        id: anelVer
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: selo.emProgresso ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: 260 }
        }
        property real mostrado: Math.max(0, Math.min(1, selo.progresso))
        Behavior on mostrado {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(selo.cor.r, selo.cor.g, selo.cor.b, 0.18)
            strokeWidth: 5.4 * selo.u
            PathAngleArc {
                centerX: 50 * selo.u
                centerY: 50 * selo.u
                radiusX: 44 * selo.u
                radiusY: radiusX
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: anelVer.mostrado > 0.002 ? selo.cor : "transparent"
            strokeWidth: 5.4 * selo.u
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: 50 * selo.u
                centerY: 50 * selo.u
                radiusX: 44 * selo.u
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * anelVer.mostrado
            }
        }
    }

    // ----- o pinheiro: tronco torto, três "nuvens" de folhas e a pedra -----
    Item {
        id: pinheiro
        anchors.fill: parent

        // A pedra.
        Rectangle {
            x: 31 * selo.u
            y: 75.5 * selo.u
            width: 38 * selo.u
            height: 4.4 * selo.u
            radius: height / 2
            color: selo.cor
            opacity: 0.45
        }

        Item {
            id: copa
            anchors.fill: parent
            transformOrigin: Item.Bottom
            // O vento: a copa balança de leve.
            SequentialAnimation on rotation {
                running: selo.vivo && (selo.estado === "protegido" || selo.emProgresso)
                loops: Animation.Infinite
                NumberAnimation { to: 1.6; duration: 2600; easing.type: Easing.InOutSine }
                NumberAnimation { to: -1.2; duration: 2600; easing.type: Easing.InOutSine }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: selo.cor
                    strokeWidth: 4.4 * selo.u
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg {
                        readonly property real u: selo.u
                        path: "M " + 50 * u + " " + 76 * u
                              + " C " + 50 * u + " " + 69 * u + " " + 42.5 * u + " " + 65 * u + " " + 44.5 * u + " " + 57.5 * u
                              + " C " + 46.5 * u + " " + 50.5 * u + " " + 55 * u + " " + 49 * u + " " + 52.5 * u + " " + 38 * u
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: selo.cor
                    strokeWidth: 3 * selo.u
                    capStyle: ShapePath.RoundCap
                    PathSvg {
                        readonly property real u: selo.u
                        path: "M " + 45 * u + " " + 58 * u + " C " + 40 * u + " " + 57 * u + " " + 37 * u + " " + 55 * u + " " + 34 * u + " " + 51 * u
                              + " M " + 51.5 * u + " " + 47 * u + " C " + 56 * u + " " + 46.5 * u + " " + 60 * u + " " + 45 * u + " " + 64 * u + " " + 42 * u
                    }
                }
            }
            Repeater {
                // As nuvens de folhas (x, y do centro, largura, altura), no espaço de 100.
                model: [
                    { x: 52, y: 33.5, w: 31, h: 10.5 },
                    { x: 52.5, y: 26.5, w: 16, h: 8 },
                    { x: 32.5, y: 50, w: 24, h: 9.5 },
                    { x: 66.5, y: 41.5, w: 22, h: 9 }
                ]
                Rectangle {
                    required property var modelData
                    required property int index
                    x: (modelData.x - modelData.w / 2) * selo.u
                    y: (modelData.y - modelData.h / 2) * selo.u
                    width: modelData.w * selo.u
                    height: modelData.h * selo.u
                    radius: height / 2
                    color: selo.cor
                    Behavior on color {
                        ColorAnimation { duration: 400 }
                    }
                    // A luz de cima de cada nuvem.
                    Rectangle {
                        x: parent.height * 0.45
                        y: parent.height * 0.2
                        width: parent.width - parent.height * 0.9
                        height: Math.max(1, parent.height * 0.18)
                        radius: height / 2
                        color: "#ffffff"
                        opacity: janela.escuro ? 0.22 : 0.3
                    }
                }
            }
        }
    }

    // ----- o selinho no canto, com o símbolo do estado -----
    Rectangle {
        id: selinho
        visible: selo.comSelinho && selo.simbolo !== "" && !selo.emProgresso
        x: 69 * selo.u
        y: 69 * selo.u
        width: 27 * selo.u
        height: width
        radius: width / 2
        color: selo.cor
        border.width: Math.max(2, 3 * selo.u)
        border.color: janela.escuro ? "#232326" : "#fbfbfc"
        Behavior on color {
            ColorAnimation { duration: 400 }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: parent.width * 0.56
            height: width
            source: selo.simbolo
            isMask: true
            color: (0.299 * selo.cor.r + 0.587 * selo.cor.g + 0.114 * selo.cor.b) > 0.55 ? "#141416" : "#ffffff"
        }
    }

    SequentialAnimation {
        id: pulo
        NumberAnimation { target: selinho; property: "scale"; to: 0.55; duration: 90 }
        NumberAnimation { target: selinho; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
    }
}
