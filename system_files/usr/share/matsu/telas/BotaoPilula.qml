// Botão em pílula das telas do Matsu (sair, desligar, login). O principal é
// branco com o texto escuro, como o botão escolhido dos alertas do Mac; o outro
// é de vidro. "perigo" deixa o principal coral (apagar, forçar).
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: botao

    property string texto: ""
    property bool principal: false
    property bool perigo: false
    property real altura: 36
    signal clicado()

    implicitWidth: Math.max(altura * 4, rotulo.implicitWidth + altura)
    implicitHeight: altura
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: texto
    Keys.onReturnPressed: botao.clicado()
    Keys.onEnterPressed: botao.clicado()
    Keys.onSpacePressed: botao.clicado()

    Rectangle {
        id: fundo
        anchors.fill: parent
        radius: height / 2
        color: {
            if (botao.principal) {
                var base = botao.perigo ? Qt.rgba(1, 0.42, 0.38, 1) : Qt.rgba(1, 1, 1, 1);
                return toque.pressed ? Qt.darker(base, 1.12) : (toque.containsMouse ? Qt.darker(base, 1.04) : base);
            }
            return Qt.rgba(1, 1, 1, toque.pressed ? 0.26 : (toque.containsMouse ? 0.2 : 0.13));
        }
        border.width: botao.activeFocus ? 2 : 1
        border.color: botao.activeFocus ? Qt.rgba(1, 1, 1, 0.75)
                                        : Qt.rgba(1, 1, 1, botao.principal ? 0 : 0.16)
        scale: toque.pressed ? 0.97 : 1
        Behavior on color {
            ColorAnimation { duration: 140 }
        }
        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }
    Text {
        id: rotulo
        anchors.centerIn: parent
        width: Math.min(implicitWidth, botao.width - botao.altura * 0.6)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: botao.texto
        color: botao.principal ? (botao.perigo ? "white" : "#1c1c1f") : "white"
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: Math.round(botao.altura * 0.4)
        font.weight: botao.principal ? Font.DemiBold : Font.Medium
    }
    MouseArea {
        id: toque
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: botao.clicado()
    }
}
