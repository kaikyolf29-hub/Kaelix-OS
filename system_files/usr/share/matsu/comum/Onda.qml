// Onda do som com o progresso (como o player de voz do vídeo de referência): barras
// arredondadas, a parte já tocada na cor da frente e o resto apagado. As barras
// crescem ao aparecer e clicar ou arrastar pula para aquele ponto.
//   Onda { amostras: [0.2, 0.8, ...]; progresso: tocado / total; onBuscar: (f) => player.position = f * total }
import QtQuick

Item {
    id: onda

    property var amostras: []
    property real progresso: 0
    property bool tocando: false
    property color cor: janela.frente
    property real grossura: Math.max(2, Math.round(janela.gu * 0.18))
    property real vao: Math.max(2, Math.round(janela.gu * 0.14))

    signal buscar(real fracao)

    // Quantas barras cabem; as amostras são reamostradas para esse número.
    readonly property int quantas: Math.max(1, Math.floor((width + vao) / (grossura + vao)))
    readonly property var barras: {
        var n = quantas, a = amostras || [], r = [];
        for (var i = 0; i < n; i++) {
            if (a.length === 0) {
                r.push(0.12);
                continue;
            }
            var ini = Math.floor(i * a.length / n), fim = Math.max(ini + 1, Math.floor((i + 1) * a.length / n)), m = 0;
            for (var j = ini; j < fim && j < a.length; j++)
                m = Math.max(m, Number(a[j]) || 0);
            r.push(Math.max(0.08, Math.min(1, m)));
        }
        return r;
    }
    property real crescer: 0
    Component.onCompleted: aparecer.start()
    onAmostrasChanged: aparecer.restart()
    NumberAnimation {
        id: aparecer
        target: onda
        property: "crescer"
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.OutCubic
    }

    implicitWidth: Math.round(janela.gu * 14)
    implicitHeight: Math.round(janela.gu * 2.2)

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: onda.vao
        Repeater {
            model: onda.barras.length
            Rectangle {
                required property int index
                readonly property real fracao: (index + 0.5) / onda.barras.length
                readonly property bool tocada: fracao <= onda.progresso
                // Cada barra cresce um pouco depois da anterior.
                readonly property real atraso: Math.max(0, Math.min(1, onda.crescer * 1.6 - index / onda.barras.length * 0.6))
                anchors.verticalCenter: parent.verticalCenter
                width: onda.grossura
                height: Math.max(onda.grossura, onda.height * onda.barras[index] * atraso)
                radius: width / 2
                color: onda.cor
                opacity: tocada ? 1 : 0.28
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: (m) => onda.buscar(Math.max(0, Math.min(1, m.x / width)))
        onPositionChanged: (m) => { if (pressed) onda.buscar(Math.max(0, Math.min(1, m.x / width))); }
    }
}
