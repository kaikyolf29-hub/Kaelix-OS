// Bolinha de fechar, minimizar ou tela cheia, iguais às da borda das janelas do
// Kaelix (rosa, azul claro e verde água, com o símbolo dentro). O Gerenciador de
// tarefas desenha a própria barra de título, para o vidro ir até em cima.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property string tipo: "fechar"    // fechar, minimizar, cheia
    property bool ligado: false       // tela cheia ligada: os cantos apontam para dentro
    property string dica: ""

    signal clicado()

    readonly property color fundo: tipo === "fechar" ? "#f0609e" : (tipo === "minimizar" ? "#8fa2ff" : "#45d0c1")
    readonly property color simbolo: tipo === "fechar" ? "#4a1230" : (tipo === "minimizar" ? "#1e2a66" : "#0b4740")

    implicitWidth: 18
    implicitHeight: 18
    hoverEnabled: true
    Accessible.role: Accessible.Button
    Accessible.name: dica
    onClicked: botao.clicado()

    Rectangle {
        anchors.centerIn: parent
        width: 14
        height: 14
        radius: 7
        color: botao.pressed ? Qt.darker(botao.fundo, 1.18) : (botao.containsMouse ? Qt.lighter(botao.fundo, 1.1) : botao.fundo)
        opacity: tarefas.active || botao.containsMouse ? 1 : 0.5

        Canvas {
            id: desenho
            anchors.fill: parent
            property color cor: botao.simbolo
            property bool ligado: botao.ligado
            onCorChanged: requestPaint()
            onLigadoChanged: requestPaint()
            onPaint: {
                var c = getContext("2d");
                c.reset();
                c.strokeStyle = Qt.rgba(cor.r, cor.g, cor.b, tarefas.active || botao.containsMouse ? 1 : 0.6);
                c.lineWidth = 1.3;
                c.lineCap = "round";
                c.lineJoin = "round";
                c.beginPath();
                if (botao.tipo === "fechar") {
                    c.moveTo(4.6, 4.6); c.lineTo(9.4, 9.4);
                    c.moveTo(9.4, 4.6); c.lineTo(4.6, 9.4);
                } else if (botao.tipo === "minimizar") {
                    c.moveTo(4.2, 7); c.lineTo(9.8, 7);
                } else if (botao.ligado) {
                    c.moveTo(4, 6.2); c.lineTo(6.2, 6.2); c.lineTo(6.2, 4);
                    c.moveTo(10, 7.8); c.lineTo(7.8, 7.8); c.lineTo(7.8, 10);
                } else {
                    c.moveTo(4, 6.4); c.lineTo(4, 4); c.lineTo(6.4, 4);
                    c.moveTo(10, 7.6); c.lineTo(10, 10); c.lineTo(7.6, 10);
                }
                c.stroke();
            }
            Connections {
                target: tarefas
                function onActiveChanged() {
                    desenho.requestPaint();
                }
            }
        }
    }

    QQC2.ToolTip.visible: dica.length > 0 && containsMouse
    QQC2.ToolTip.text: dica
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
