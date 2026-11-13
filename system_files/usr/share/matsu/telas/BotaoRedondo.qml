// Botão redondo de vidro das telas de login e bloqueio (Suspender, Reiniciar,
// Desligar, Trocar de pessoa), com o nome embaixo. O ícone é um arquivo do tema
// Matsu, pintado de branco.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: botao

    property string texto: ""
    // "matsu-desligar" (os ícones do Matsu, por arquivo, para valer em qualquer tema
    // de ícones da tela de login) ou o nome de um ícone do tema.
    property string icone: ""
    property real lado: 44
    signal clicado()

    readonly property string arquivo: icone.indexOf("matsu-") === 0
        ? "/usr/share/icons/Matsu/status/symbolic/" + icone + "-symbolic.svg" : icone

    implicitWidth: Math.max(lado + 16, rotulo.implicitWidth + 8)
    implicitHeight: lado + rotulo.anchors.topMargin + rotulo.implicitHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: texto
    Keys.onReturnPressed: botao.clicado()
    Keys.onEnterPressed: botao.clicado()
    Keys.onSpacePressed: botao.clicado()

    Rectangle {
        id: circulo
        anchors.horizontalCenter: parent.horizontalCenter
        width: botao.lado
        height: width
        radius: width / 2
        color: Qt.rgba(1, 1, 1, toque.pressed ? 0.3 : (toque.containsMouse || botao.activeFocus ? 0.24 : 0.14))
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, botao.activeFocus ? 0.7 : 0.2)
        scale: toque.pressed ? 0.93 : 1
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on scale {
            NumberAnimation { duration: 120 }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(botao.lado * 0.46)
            height: width
            source: botao.arquivo
            isMask: true
            color: "white"
        }
    }
    Text {
        id: rotulo
        anchors.top: circulo.bottom
        anchors.topMargin: Math.round(botao.lado * 0.18)
        anchors.horizontalCenter: parent.horizontalCenter
        text: botao.texto
        color: "white"
        opacity: toque.containsMouse || botao.activeFocus ? 1 : 0.8
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: Math.max(11, Math.round(botao.lado * 0.27))
        font.weight: Font.Medium
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.25)
    }
    MouseArea {
        id: toque
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: botao.clicado()
    }
}
