// A paleta da cor da nota: "sem cor" e os seis tons pastel. A escolhida ganha o
// anel e o visto que pula; passar o mouse cresce a bolinha de leve.
//   PaletaCores { id: paleta; cor: nota.cor; onEscolher: (id) => janela.pintar(nid, id) }
//   paleta.abrirEm(botao)
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "../comum"
import "notas.js" as N

QQC2.Popup {
    id: paleta

    property string cor: ""

    signal escolher(string id)

    // Abre embaixo do botão, alinhada pela direita, sem sair da janela.
    function abrirEm(item) {
        var p = item.mapToItem(parent, item.width, item.height);
        x = Math.max(4, Math.min(p.x - implicitWidth, parent.width - implicitWidth - 4));
        y = p.y + 6;
        open();
    }

    parent: QQC2.Overlay.overlay
    padding: Math.round(janela.gu * 0.6)
    transformOrigin: QQC2.Popup.TopRight
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 130 }
            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: 100 }
    }
    background: FundoBalao {}

    contentItem: ColumnLayout {
        spacing: Math.round(janela.gu * 0.45)
        Texto {
            text: janela.t("Cor da nota", "Note color")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.65
        }
        Row {
            spacing: Math.round(janela.gu * 0.35)
            Repeater {
                model: [{ id: "", tom: "" }].concat(N.CORES)

                MouseArea {
                    id: bolinha
                    required property var modelData
                    readonly property bool escolhida: paleta.cor === modelData.id
                    readonly property int lado: Math.round(janela.gu * 1.55)
                    width: lado
                    height: lado
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    activeFocusOnTab: true
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: janela.nomeCor(modelData.id)
                    Accessible.checked: escolhida
                    onClicked: paleta.escolher(modelData.id)
                    Keys.onReturnPressed: paleta.escolher(modelData.id)
                    Keys.onSpacePressed: paleta.escolher(modelData.id)
                    onEscolhidaChanged: if (escolhida) pulo.restart()

                    // O anel da escolhida.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: bolinha.escolhida || bolinha.activeFocus ? 2 : 0
                        border.color: janela.frente
                        opacity: bolinha.escolhida ? 0.85 : 0.5
                    }
                    Rectangle {
                        id: miolo
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: width
                        radius: width / 2
                        scale: bolinha.pressed ? 0.9 : (bolinha.containsMouse ? 1.1 : 1)
                        color: bolinha.modelData.tom ? bolinha.modelData.tom : janela.tinta(janela.escuro ? 0.06 : 0.04)
                        border.width: bolinha.modelData.tom ? 0 : 1.5
                        border.color: janela.tinta(0.3)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutBack
                            }
                        }
                        // "Sem cor": o risco na diagonal.
                        Rectangle {
                            visible: !bolinha.modelData.tom
                            anchors.centerIn: parent
                            width: parent.width * 0.7
                            height: 1.5
                            rotation: -45
                            color: janela.tinta(0.45)
                        }
                        Shape {
                            id: visto
                            anchors.centerIn: parent
                            width: parent.width * 0.6
                            height: width
                            visible: bolinha.escolhida && bolinha.modelData.tom !== ""
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: "#2a2620"
                                strokeWidth: 2
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                startX: visto.width * 0.18
                                startY: visto.height * 0.52
                                PathLine { x: visto.width * 0.42; y: visto.height * 0.76 }
                                PathLine { x: visto.width * 0.84; y: visto.height * 0.26 }
                            }
                        }
                    }
                    SequentialAnimation {
                        id: pulo
                        NumberAnimation { target: visto; property: "scale"; from: 0.3; to: 1.2; duration: 160; easing.type: Easing.OutQuad }
                        NumberAnimation { target: visto; property: "scale"; to: 1; duration: 240; easing.type: Easing.OutBack; easing.overshoot: 3 }
                    }

                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: janela.nomeCor(modelData.id)
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }
    }
}
