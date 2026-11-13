// Foto redonda da pessoa (ou a primeira letra do nome num círculo cinza), para
// "Sua conta". O Kirigami 6 não tem mais o Avatar, então ele mora aqui.
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: avatar

    property string name: ""
    property url source
    property color color: "#6e6e76"
    property color initialsColor: "#ffffff"
    property real borda: 0
    property color corBorda: Kirigami.Theme.highlightColor

    readonly property bool temFoto: String(source) !== "" && imagem.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: avatar.color
        visible: !avatar.temFoto
        Text {
            anchors.centerIn: parent
            text: avatar.name.trim().length > 0 ? avatar.name.trim().charAt(0).toUpperCase() : ""
            color: avatar.initialsColor
            font.pixelSize: Math.round(avatar.height * 0.44)
            font.weight: Font.DemiBold
        }
    }
    Image {
        id: imagem
        anchors.fill: parent
        source: avatar.source
        sourceSize.width: Math.round(avatar.width * 2)
        sourceSize.height: Math.round(avatar.height * 2)
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: true
        visible: false
        layer.enabled: true
    }
    Rectangle {
        id: mascara
        anchors.fill: parent
        radius: width / 2
        antialiasing: true
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: imagem
        maskEnabled: true
        maskSource: mascara
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        visible: avatar.temFoto
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -avatar.borda
        radius: width / 2
        color: "transparent"
        visible: avatar.borda > 0
        border.width: avatar.borda
        border.color: avatar.corBorda
    }
}
