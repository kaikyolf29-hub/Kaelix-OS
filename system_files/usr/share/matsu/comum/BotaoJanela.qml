// Bolinha de fechar, minimizar ou tela cheia, iguais às da borda das janelas do
// Matsu (rosa, azul claro e verde água). Como no Mac, o símbolo de dentro só
// aparece quando o mouse chega perto das três (mostrar = mouse em cima do grupo),
// surgindo e crescendo de leve. Com a janela em segundo plano, as bolinhas ficam
// cinza e voltam a ter cor quando o mouse passa por cima.
// Os apps do Matsu desenham a própria barra de título, para o vidro ir até em cima.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property string tipo: "fechar"    // fechar, minimizar, cheia
    property bool ligado: false       // tela cheia ligada: os cantos apontam para dentro
    property string dica: ""
    property bool mostrar: containsMouse

    signal clicado()

    readonly property color cor: tipo === "fechar" ? "#f0609e" : (tipo === "minimizar" ? "#8fa2ff" : "#45d0c1")
    readonly property color simbolo: tipo === "fechar" ? "#5a1036" : (tipo === "minimizar" ? "#1e2a6e" : "#0a4a42")
    readonly property bool colorida: janela.active || mostrar

    implicitWidth: 18
    implicitHeight: 18
    hoverEnabled: true
    Accessible.role: Accessible.Button
    Accessible.name: dica
    onClicked: botao.clicado()

    Rectangle {
        id: bola
        anchors.centerIn: parent
        width: 14
        height: 14
        radius: 7
        color: !botao.colorida ? janela.tinta(janela.escuro ? 0.2 : 0.16)
             : botao.pressed ? Qt.darker(botao.cor, 1.2) : botao.cor
        // Um contorno bem fino, um tom abaixo, dá acabamento à bolinha (como no Mac).
        border.width: 1
        border.color: botao.colorida ? Qt.rgba(0, 0, 0, janela.escuro ? 0.18 : 0.1) : "transparent"
        Behavior on color {
            ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        Item {
            anchors.fill: parent
            opacity: botao.mostrar ? 1 : 0
            scale: botao.mostrar ? 1 : 0.4
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            }

            Canvas {
                id: desenho
                anchors.fill: parent
                antialiasing: true
                property color tom: botao.simbolo
                property bool ligado: botao.ligado
                onTomChanged: requestPaint()
                onLigadoChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d");
                    c.reset();
                    c.strokeStyle = tom;
                    c.lineWidth = 1.4;
                    c.lineCap = "round";
                    c.lineJoin = "round";
                    c.beginPath();
                    if (botao.tipo === "fechar") {
                        c.moveTo(4.7, 4.7); c.lineTo(9.3, 9.3);
                        c.moveTo(9.3, 4.7); c.lineTo(4.7, 9.3);
                        c.stroke();
                    } else if (botao.tipo === "minimizar") {
                        c.moveTo(4.2, 7); c.lineTo(9.8, 7);
                        c.stroke();
                    } else {
                        // Tela cheia: dois triângulos cheios, como no Mac; saindo dela,
                        // eles apontam para dentro.
                        c.fillStyle = tom;
                        c.lineWidth = 0.8;
                        if (ligado) {
                            c.moveTo(6.3, 3.5); c.lineTo(6.3, 6.3); c.lineTo(3.5, 6.3); c.closePath();
                            c.moveTo(7.7, 10.5); c.lineTo(7.7, 7.7); c.lineTo(10.5, 7.7); c.closePath();
                        } else {
                            c.moveTo(4, 4); c.lineTo(7, 4); c.lineTo(4, 7); c.closePath();
                            c.moveTo(10, 10); c.lineTo(7, 10); c.lineTo(10, 7); c.closePath();
                        }
                        c.fill();
                        c.stroke();
                    }
                }
            }
        }
    }

    QQC2.ToolTip.visible: dica.length > 0 && containsMouse
    QQC2.ToolTip.text: dica
    QQC2.ToolTip.delay: 700
}
