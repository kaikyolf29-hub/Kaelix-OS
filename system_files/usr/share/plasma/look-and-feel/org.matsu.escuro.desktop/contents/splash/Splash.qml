// Matsu OS: tela que aparece depois da senha, enquanto a área de trabalho carrega.
// Fundo quase preto do logo, o pinheiro no meio e três pontos pulsando.
import QtQuick

Rectangle {
    id: raiz

    // O sistema avisa por aqui em que etapa do carregamento está (1 a 6).
    property int stage

    color: "#141517"

    onStageChanged: {
        if (stage === 2) {
            entrada.running = true;
        } else if (stage === 5) {
            saida.running = true;
        }
    }

    Item {
        id: conteudo
        anchors.fill: parent
        opacity: 0

        Image {
            id: emblema
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Math.round(parent.height * 0.04)
            readonly property int lado: Math.round(Math.min(parent.width, parent.height) * 0.16)
            width: lado
            height: lado
            sourceSize.width: lado
            sourceSize.height: lado
            source: "images/emblema.svg"
            asynchronous: false
        }

        Text {
            id: nome
            anchors.top: emblema.bottom
            anchors.topMargin: Math.round(emblema.lado * 0.22)
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Matsu @EDICAO@ OS"
            color: "#F4F5F7"
            opacity: 0.92
            font.pixelSize: Math.max(16, Math.round(emblema.lado * 0.17))
            font.weight: Font.DemiBold
            font.letterSpacing: 1.5
        }

        Row {
            id: pontos
            anchors.top: nome.bottom
            anchors.topMargin: Math.round(emblema.lado * 0.32)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.max(8, Math.round(emblema.lado * 0.08))

            Repeater {
                model: 3

                Rectangle {
                    id: ponto
                    required property int index
                    readonly property int tamanho: Math.max(10, Math.round(emblema.lado * 0.075))
                    width: tamanho
                    height: tamanho
                    radius: tamanho / 2
                    color: index === 0 ? "#F0609E" : (index === 1 ? "#B18CF5" : "#45D0C1")
                    opacity: 0.3

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: ponto.index * 180 }
                        NumberAnimation { from: 0.3; to: 1; duration: 360; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1; to: 0.3; duration: 360; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: (2 - ponto.index) * 180 + 240 }
                    }
                }
            }
        }
    }

    OpacityAnimator {
        id: entrada
        running: false
        target: conteudo
        from: 0
        to: 1
        duration: 500
        easing.type: Easing.InOutQuad
    }

    OpacityAnimator {
        id: saida
        running: false
        target: pontos
        from: 1
        to: 0
        duration: 400
        easing.type: Easing.InOutQuad
    }
}
