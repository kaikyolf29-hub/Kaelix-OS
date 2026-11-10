// Bateria desenhada na pílula da barra (só aparece no notebook): contorno com
// a carga por dentro. Verde carregando, vermelha quando está acabando.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: bateria

    property int nivel: 0
    property bool carregando: false

    readonly property real traco: Math.max(1.5, Math.round(height / 12 * 10) / 10)
    readonly property color cor: Kirigami.Theme.textColor

    width: Math.round(height * 1.3)

    Rectangle {
        id: corpo
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Math.round(bateria.traco * 1.6)
        height: Math.round(parent.height * 0.6)
        radius: Math.round(height * 0.28)
        color: "transparent"
        border.width: bateria.traco
        border.color: bateria.cor
    }

    // Pontinha do polo.
    Rectangle {
        x: corpo.width + Math.round(bateria.traco * 0.4)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(bateria.traco * 1.2)
        height: Math.round(corpo.height * 0.42)
        radius: width / 2
        color: bateria.cor
    }

    // Carga.
    Rectangle {
        readonly property real folga: bateria.traco * 1.9
        x: folga
        y: corpo.y + folga
        height: corpo.height - folga * 2
        width: Math.max(height * 0.5, (corpo.width - folga * 2) * Math.min(100, Math.max(0, bateria.nivel)) / 100)
        radius: Math.max(1, corpo.radius - folga)
        color: bateria.carregando ? Kirigami.Theme.positiveTextColor
             : bateria.nivel <= 15 ? Kirigami.Theme.negativeTextColor
             : bateria.cor
    }
}
