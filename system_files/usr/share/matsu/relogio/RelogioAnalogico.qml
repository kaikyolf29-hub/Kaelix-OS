// Relógio de ponteiros desenhado: mostrador com as marcas dos minutos (e os números,
// no grande), ponteiros de cantos redondos e o dos segundos no rosa de cerejeira. Os
// ponteiros andam lisos (uma animação contínua, sem pulos) e, com "intro", giram do
// meio-dia até a hora certa ao aparecer. "noite" escurece o mostrador (cidades).
//   RelogioAnalogico { desvio: -10800; width: janela.gu * 10 }
import QtQuick
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: relogio

    // Segundos a leste de UTC do lugar mostrado (o padrão é o fuso do computador).
    property real desvio: janela.desvioLocal()
    property bool segundos: true
    property bool numeros: true
    property bool noite: false
    property bool intro: false

    readonly property real raio: Math.min(width, height) / 2
    readonly property color corPonteiro: noite ? "#f4f4f6" : janela.frente
    readonly property color corMostrador: noite ? (janela.escuro ? Qt.rgba(0, 0, 0, 0.42) : "#2b2b31")
                                                : (janela.escuro ? Qt.rgba(1, 1, 1, 0.075) : "#ffffff")

    implicitWidth: Math.round(janela.gu * 10)
    implicitHeight: implicitWidth
    Accessible.role: Accessible.Clock
    Accessible.name: {
        var _a = janela.agora;
        var d = new Date(Date.now() + desvio * 1000);
        return janela.hhmm(d.getUTCHours(), d.getUTCMinutes());
    }

    // Ângulos dos ponteiros daqui a "adiante" ms.
    function angulos(adiante) {
        var d = new Date(Date.now() + (adiante || 0) + desvio * 1000);
        var s = d.getUTCSeconds() + d.getUTCMilliseconds() / 1000;
        var m = d.getUTCMinutes() + s / 60;
        var h = (d.getUTCHours() % 12) + m / 60;
        return { s: s * 6, m: m * 6, h: h * 30 };
    }
    function comecar(animar) {
        giro.stop();
        abertura.stop();
        if (animar) {
            var alvo = angulos(1100);
            ponteiroS.rotation = 0;
            ponteiroM.rotation = 0;
            ponteiroH.rotation = 0;
            introS.to = alvo.s + 360;
            introM.to = alvo.m;
            introH.to = alvo.h;
            abertura.start();
            return;
        }
        var a = angulos(0);
        giroS.from = a.s;
        giroS.to = a.s + 360;
        giroM.from = a.m;
        giroM.to = a.m + 360;
        giroH.from = a.h;
        giroH.to = a.h + 360;
        giro.start();
    }
    function longe(atual, certo) {
        var d = ((atual - certo) % 360 + 540) % 360 - 180;
        return Math.abs(d) > 1.5;
    }
    onDesvioChanged: if (giro.running) comecar(false)
    Component.onCompleted: comecar(intro)

    // Confere de vez em quando (o relógio do computador pode ter sido acertado).
    Timer {
        interval: 15000
        repeat: true
        running: giro.running
        onTriggered: {
            var a = relogio.angulos(0);
            if (relogio.longe(ponteiroS.rotation, a.s) || relogio.longe(ponteiroM.rotation, a.m))
                relogio.comecar(false);
        }
    }

    ParallelAnimation {
        id: giro
        NumberAnimation { id: giroS; target: ponteiroS; property: "rotation"; duration: 60000; loops: Animation.Infinite }
        NumberAnimation { id: giroM; target: ponteiroM; property: "rotation"; duration: 3600000; loops: Animation.Infinite }
        NumberAnimation { id: giroH; target: ponteiroH; property: "rotation"; duration: 43200000; loops: Animation.Infinite }
    }
    SequentialAnimation {
        id: abertura
        ParallelAnimation {
            NumberAnimation { id: introS; target: ponteiroS; property: "rotation"; duration: 1100; easing.type: Easing.OutCubic }
            NumberAnimation { id: introM; target: ponteiroM; property: "rotation"; duration: 1100; easing.type: Easing.OutCubic }
            NumberAnimation { id: introH; target: ponteiroH; property: "rotation"; duration: 1100; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: relogio.comecar(false) }
    }

    // Mostrador.
    Rectangle {
        anchors.centerIn: parent
        width: relogio.raio * 2
        height: width
        radius: width / 2
        color: relogio.corMostrador
        border.width: 1
        border.color: relogio.noite ? Qt.rgba(1, 1, 1, 0.1) : janela.tinta(janela.escuro ? 0.1 : 0.1)
        Behavior on color {
            ColorAnimation {
                duration: 600
            }
        }
    }

    // Marcas: 60 dos minutos (as das horas mais fortes).
    Repeater {
        model: relogio.numeros ? 60 : 12
        Item {
            required property int index
            readonly property bool hora: relogio.numeros ? index % 5 === 0 : true
            anchors.fill: parent
            rotation: index * (relogio.numeros ? 6 : 30)
            Rectangle {
                x: relogio.width / 2 - width / 2
                y: relogio.height / 2 - relogio.raio + relogio.raio * 0.06
                width: parent.hora ? Math.max(1.5, relogio.raio * 0.035) : Math.max(1, relogio.raio * 0.014)
                height: parent.hora ? relogio.raio * 0.09 : relogio.raio * 0.045
                radius: width / 2
                color: relogio.corPonteiro
                opacity: parent.hora ? 0.75 : 0.3
                antialiasing: true
            }
        }
    }
    // Números das horas (só no grande).
    Repeater {
        model: relogio.numeros ? 12 : 0
        Text {
            required property int index
            readonly property real angulo: (index + 1) * Math.PI / 6
            x: relogio.width / 2 + Math.sin(angulo) * relogio.raio * 0.7 - width / 2
            y: relogio.height / 2 - Math.cos(angulo) * relogio.raio * 0.7 - height / 2
            text: index + 1
            color: relogio.corPonteiro
            opacity: 0.8
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: Math.round(relogio.raio * 0.15)
            font.weight: Font.Medium
        }
    }

    // Ponteiros (cada um gira em volta do centro do relógio).
    Item {
        id: ponteiroH
        anchors.fill: parent
        Rectangle {
            readonly property real largura: Math.max(3, relogio.raio * 0.075)
            x: relogio.width / 2 - largura / 2
            y: relogio.height / 2 - relogio.raio * 0.5
            width: largura
            height: relogio.raio * 0.5 + largura
            radius: largura / 2
            color: relogio.corPonteiro
            antialiasing: true
        }
    }
    Item {
        id: ponteiroM
        anchors.fill: parent
        Rectangle {
            readonly property real largura: Math.max(2, relogio.raio * 0.05)
            x: relogio.width / 2 - largura / 2
            y: relogio.height / 2 - relogio.raio * 0.76
            width: largura
            height: relogio.raio * 0.76 + largura
            radius: largura / 2
            color: relogio.corPonteiro
            antialiasing: true
        }
    }
    Item {
        id: ponteiroS
        anchors.fill: parent
        visible: relogio.segundos
        Rectangle {
            readonly property real largura: Math.max(1.2, relogio.raio * 0.02)
            x: relogio.width / 2 - largura / 2
            y: relogio.height / 2 - relogio.raio * 0.84
            width: largura
            height: relogio.raio * 1.04
            radius: largura / 2
            color: janela.cereja
            antialiasing: true
        }
    }
    // O pino do meio.
    Rectangle {
        anchors.centerIn: parent
        width: Math.max(5, relogio.raio * 0.1)
        height: width
        radius: width / 2
        color: relogio.segundos ? janela.cereja : relogio.corPonteiro
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.4
            height: width
            radius: width / 2
            color: relogio.corMostrador
            visible: relogio.segundos
        }
    }
}
