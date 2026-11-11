// Bloco de fundo clarinho e cantos redondos, igual aos da central do vídeo.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: cartao

    default property alias conteudo: coluna.data
    readonly property int folga: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing

    implicitHeight: coluna.implicitHeight + folga * 2
    radius: Math.round(Kirigami.Units.gridUnit * 0.8)
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)

    ColumnLayout {
        id: coluna
        anchors.fill: parent
        anchors.margins: cartao.folga
        spacing: Kirigami.Units.smallSpacing * 2
    }
}
