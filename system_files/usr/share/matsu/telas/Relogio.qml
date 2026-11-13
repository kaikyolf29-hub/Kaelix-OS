// A hora grande das telas de login e bloqueio, no jeito do Mac: a data pequena em
// cima ("sexta-feira, 13 de novembro") e a hora enorme embaixo, em branco com uma
// sombra macia. "altura" é a altura da tela (o tamanho da hora sai dela).
import QtQuick
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

Item {
    id: relogio

    property real altura: 1080
    property date agora: new Date()
    readonly property bool pt: Qt.locale().name.indexOf("pt") === 0
    readonly property var local: Qt.locale()
    // 24 horas no português; no inglês, o jeito do idioma.
    readonly property string formatoHora: pt ? "HH:mm" : local.timeFormat(Locale.ShortFormat).replace(/:ss/, "").replace(/\s*[aA]P?$/, "")

    implicitWidth: coluna.implicitWidth
    implicitHeight: coluna.implicitHeight

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: relogio.agora = new Date()
    }

    Column {
        id: coluna
        spacing: Math.round(relogio.altura * 0.002)
        visible: false

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                var t = relogio.agora.toLocaleDateString(relogio.local, relogio.pt ? "dddd, d 'de' MMMM" : "dddd, MMMM d");
                return t.charAt(0).toUpperCase() + t.slice(1);
            }
            color: "white"
            opacity: 0.88
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: Math.round(relogio.altura * 0.024)
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(relogio.agora, relogio.formatoHora)
            color: "white"
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: Math.round(relogio.altura * 0.125)
            font.weight: Font.DemiBold
            font.letterSpacing: -Math.round(relogio.altura * 0.002)
            // A altura da linha sem o espaço de sobra da fonte embaixo.
            lineHeight: 0.92
        }
    }

    // A sombra macia por trás (e o próprio texto, por cima).
    DropShadow {
        anchors.fill: coluna
        source: coluna
        radius: 24
        samples: 33
        verticalOffset: 2
        spread: 0
        color: Qt.rgba(0, 0, 0, 0.35)
    }
}
