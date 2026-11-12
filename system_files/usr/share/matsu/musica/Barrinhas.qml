// As barrinhas que pulam no lugar do número da música que está tocando (paradas,
// em alturas diferentes, quando está pausada).
import QtQuick

Item {
    id: barrinhas

    property bool rodando: false
    property color cor: janela.frente

    implicitWidth: Math.round(janela.gu * 0.9)
    implicitHeight: Math.round(janela.gu * 0.8)

    Row {
        anchors.centerIn: parent
        height: parent.height
        spacing: Math.max(1.5, Math.round(barrinhas.width / 10))
        Repeater {
            model: [{ parada: 0.45, de: 0.25, ate: 1.0, t: 420 }, { parada: 0.8, de: 0.35, ate: 0.85, t: 330 },
                    { parada: 0.6, de: 0.2, ate: 0.95, t: 480 }, { parada: 0.35, de: 0.3, ate: 0.75, t: 370 }]
            Rectangle {
                id: barra
                required property var modelData
                required property int index
                property real nivel: modelData.parada
                anchors.bottom: parent.bottom
                width: Math.max(2, Math.round((barrinhas.width - 3 * parent.spacing) / 4))
                height: Math.max(width, barrinhas.height * nivel)
                radius: width / 2
                color: barrinhas.cor
                Behavior on nivel {
                    enabled: !barrinhas.rodando
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }
                SequentialAnimation on nivel {
                    running: barrinhas.rodando
                    loops: Animation.Infinite
                    NumberAnimation { to: barra.modelData.ate; duration: barra.modelData.t; easing.type: Easing.InOutSine }
                    NumberAnimation { to: barra.modelData.de; duration: barra.modelData.t * 1.15; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) barra.nivel = barra.modelData.parada
                }
            }
        }
    }
}
