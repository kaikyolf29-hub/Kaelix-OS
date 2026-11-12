// Roda de rolar para escolher um número (hora, minuto, segundo), como a do relógio
// do celular: o número do meio fica grande e na faixa clara; os vizinhos diminuem e
// somem aos poucos. A roda dá a volta (59 → 00). Arrastar, a rodinha do mouse, as
// setas do teclado e clicar num vizinho mudam o valor; mudar por fora faz a roda rolar.
//   RodaNumero { quantos: 24; valor: 7; nome: "Hora"; onMudou: (v) => hora = v }
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: roda

    property int valor: 0
    property int quantos: 60
    property string nome: ""
    property string sufixo: ""

    signal mudou(int valor)

    readonly property real alturaItem: Math.round(janela.gu * 1.75)

    implicitWidth: Math.round(janela.gu * 3.4)
    implicitHeight: alturaItem * 5

    onValorChanged: if (lista.currentIndex !== valor) lista.currentIndex = valor
    Component.onCompleted: {
        lista.highlightMoveDuration = 0;
        lista.currentIndex = valor;
        lista.highlightMoveDuration = 420;
    }

    activeFocusOnTab: true
    Accessible.role: Accessible.SpinBox
    Accessible.name: nome
    Accessible.description: String(valor) + (sufixo ? " " + sufixo : "")
    Keys.onUpPressed: lista.decrementCurrentIndex()
    Keys.onDownPressed: lista.incrementCurrentIndex()
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_PageUp) { roda.valor = (roda.valor - 10 + roda.quantos * 10) % roda.quantos; roda.mudou(roda.valor); e.accepted = true; }
        else if (e.key === Qt.Key_PageDown) { roda.valor = (roda.valor + 10) % roda.quantos; roda.mudou(roda.valor); e.accepted = true; }
    }

    HoverHandler {
        id: sobre
    }

    // A faixa do escolhido.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: roda.alturaItem
        radius: Math.round(janela.gu * 0.45)
        color: janela.tinta(roda.activeFocus || sobre.hovered ? (janela.escuro ? 0.1 : 0.07) : (janela.escuro ? 0.065 : 0.05))
        border.width: roda.activeFocus ? 1 : 0
        border.color: janela.destaque
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }

    PathView {
        id: lista
        anchors.fill: parent
        model: roda.quantos
        pathItemCount: 5
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        snapMode: PathView.SnapToItem
        highlightMoveDuration: 420
        maximumFlickVelocity: 1600
        clip: true
        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex !== roda.valor) {
                roda.valor = currentIndex;
                roda.mudou(currentIndex);
            }
        }
        onMovementStarted: roda.forceActiveFocus()

        path: Path {
            startX: lista.width / 2
            startY: 0
            PathAttribute { name: "escala"; value: 0.6 }
            PathAttribute { name: "nitidez"; value: 0.12 }
            PathLine { x: lista.width / 2; y: lista.height / 2 }
            PathAttribute { name: "escala"; value: 1.0 }
            PathAttribute { name: "nitidez"; value: 1.0 }
            PathLine { x: lista.width / 2; y: lista.height }
            PathAttribute { name: "escala"; value: 0.6 }
            PathAttribute { name: "nitidez"; value: 0.12 }
        }

        delegate: Item {
            id: numero
            required property int index
            width: lista.width
            height: roda.alturaItem
            scale: numero.PathView.escala || 0.6
            opacity: numero.PathView.nitidez || 0
            Texto {
                anchors.centerIn: parent
                text: (numero.index < 10 ? "0" : "") + numero.index
                font.pixelSize: Math.round(janela.gu * 1.4)
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            TapHandler {
                onTapped: {
                    roda.forceActiveFocus();
                    lista.currentIndex = numero.index;
                }
            }
        }
    }

    // Rodinha do mouse (e o rolar de dois dedos do touchpad, somado aos poucos).
    WheelHandler {
        property real soma: 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            soma += e.angleDelta.y;
            while (soma >= 90) { lista.decrementCurrentIndex(); soma -= 90; }
            while (soma <= -90) { lista.incrementCurrentIndex(); soma += 90; }
        }
    }

    // O nome embaixo ("h", "min", "s").
    Texto {
        visible: roda.sufixo.length > 0
        anchors.top: parent.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        text: roda.sufixo
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.6
    }
}
