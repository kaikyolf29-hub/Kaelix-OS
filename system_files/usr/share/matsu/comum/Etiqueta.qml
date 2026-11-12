// Etiqueta (chip) de escolher: a escolhida vira uma pílula cheia e o visto entra
// deslizando antes do nome. Para filtros e escolhas de várias opções.
//   Etiqueta { texto: "Rock"; escolhida: x; onTrocada: (e) => x = e }
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

MouseArea {
    id: etiqueta

    property string texto: ""
    property string icone: ""
    property bool escolhida: false

    signal trocada(bool escolhida)

    readonly property color letra: escolhida ? janela.sobreDestaque : janela.frente
    readonly property int lado: Math.round(janela.gu * 0.8)

    implicitWidth: linha.width + Math.round(janela.gu * 1.3)
    implicitHeight: Math.round(janela.gu * 1.9)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: texto
    Accessible.checkable: true
    Accessible.checked: escolhida
    onClicked: etiqueta.trocada(!escolhida)
    Keys.onSpacePressed: etiqueta.trocada(!escolhida)
    Keys.onReturnPressed: etiqueta.trocada(!escolhida)

    Rectangle {
        id: fundo
        anchors.fill: parent
        radius: height / 2
        scale: etiqueta.pressed ? 0.96 : 1
        color: etiqueta.escolhida ? (etiqueta.containsMouse ? Qt.lighter(janela.destaque, janela.escuro ? 0.92 : 1.12) : janela.destaque)
             : janela.tinta(etiqueta.containsMouse ? 0.08 : (janela.escuro ? 0.05 : 0.04))
        border.width: etiqueta.escolhida ? 0 : 1
        border.color: janela.tinta(janela.escuro ? 0.1 : 0.12)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.longDuration
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 140
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.width: etiqueta.activeFocus ? 1.5 : 0
            border.color: janela.frente
        }
    }

    Row {
        id: linha
        anchors.centerIn: parent
        spacing: 0
        // O visto: abre espaço e é desenhado quando a etiqueta é escolhida.
        Item {
            id: lugarVisto
            anchors.verticalCenter: parent.verticalCenter
            width: etiqueta.escolhida ? etiqueta.lado + Math.round(janela.gu * 0.35) : 0
            height: etiqueta.lado
            clip: true
            Behavior on width {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }
            Shape {
                width: etiqueta.lado
                height: etiqueta.lado
                opacity: etiqueta.escolhida ? 1 : 0
                scale: etiqueta.escolhida ? 1 : 0.4
                preferredRendererType: Shape.CurveRenderer
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutBack
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: etiqueta.letra
                    strokeWidth: 2
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: etiqueta.lado * 0.12
                    startY: etiqueta.lado * 0.52
                    PathLine { x: etiqueta.lado * 0.4; y: etiqueta.lado * 0.8 }
                    PathLine { x: etiqueta.lado * 0.9; y: etiqueta.lado * 0.22 }
                }
            }
        }
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: etiqueta.icone.length > 0
            width: visible ? Kirigami.Units.iconSizes.small + Math.round(janela.gu * 0.35) : 0
            height: Kirigami.Units.iconSizes.small
            source: etiqueta.icone
            isMask: true
            color: etiqueta.letra
        }
        Texto {
            anchors.verticalCenter: parent.verticalCenter
            text: etiqueta.texto
            color: etiqueta.letra
            font.weight: etiqueta.escolhida ? Font.DemiBold : Font.Normal
        }
    }
}
