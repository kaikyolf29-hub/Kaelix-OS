// Bloco de fundo clarinho e cantos redondos, igual aos da central do vídeo.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: cartao

    default property alias conteudo: coluna.data
    readonly property int folgaV: Math.round(Kirigami.Units.gridUnit * 0.67)
    readonly property int folgaH: Math.round(Kirigami.Units.gridUnit * 0.78)

    implicitHeight: coluna.implicitHeight + folgaV * 2
    radius: Math.round(Kirigami.Units.gridUnit * 0.9)
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.09)

    ColumnLayout {
        id: coluna
        anchors.fill: parent
        anchors.leftMargin: cartao.folgaH
        anchors.rightMargin: cartao.folgaH
        anchors.topMargin: cartao.folgaV
        anchors.bottomMargin: cartao.folgaV
        spacing: Math.round(Kirigami.Units.gridUnit * 0.55)
    }
}
