// Matsu OS — a foto e o nome de cada pessoa nas telas do KDE
// (org.kde.breeze.components.UserDelegate), no lugar do original da Breeze.
//
// A foto num círculo com a borda de vidro (Matsu.Pessoa): sem foto, a primeira
// letra do nome, nada do ícone genérico. O nome em branco embaixo. Quem não está
// escolhido fica menor e apagado, como no Mac.
//
// Tem as mesmas propriedades e o mesmo sinal do original (a tela de login, que
// vem compilada, e a lista de pessoas usam todas): isCurrent, name, userName,
// avatarPath, iconSource, needsPassword, vtNumber, constrainText, nameFontSize,
// fontSize, faceSize, softwareRendering e clicked().
import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "file:///usr/share/matsu/telas" as Matsu

Item {
    id: wrapper

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    property bool isCurrent: true

    property string name
    property string userName
    property string avatarPath
    property string iconSource
    property bool needsPassword
    property var vtNumber
    property bool constrainText: true
    property alias nameFontSize: usernameDelegate.font.pointSize
    property real fontSize: Kirigami.Theme.defaultFont.pointSize + 2
    signal clicked()

    // A altura da tela dá o tamanho, como no bloqueio do Matsu.
    readonly property real alturaTela: Window.window && Window.window.height > 0 ? Window.window.height : 1080
    property real faceSize: Math.max(Kirigami.Units.gridUnit * 3.5, Math.round(alturaTela * 0.074))

    Matsu.Pessoa {
        id: foto
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        lado: wrapper.isCurrent ? wrapper.faceSize : Math.round(wrapper.faceSize * 0.82)
        nome: wrapper.name || wrapper.userName
        // Só a foto de verdade; o ícone genérico do KDE vira a letra do nome.
        foto: wrapper.avatarPath
        escolhida: wrapper.isCurrent
        mostrarNome: false
        onClicada: wrapper.clicked()
        Behavior on lado {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
    }

    Text {
        id: usernameDelegate

        anchors.top: foto.bottom
        anchors.topMargin: Math.round(wrapper.faceSize * 0.16)
        anchors.horizontalCenter: parent.horizontalCenter

        width: wrapper.constrainText ? parent.width : undefined
        text: wrapper.name
        textFormat: Text.PlainText
        color: "white"
        opacity: wrapper.isCurrent ? 1 : 0.7
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: Math.max(13, Math.round(wrapper.faceSize * 0.2))
        font.weight: Font.DemiBold
        // Indica o foco quando se chega aqui pelo teclado.
        font.underline: wrapper.activeFocus
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.25)
        wrapMode: Text.WordWrap
        maximumLineCount: wrapper.constrainText ? 2 : 1
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: wrapper.isCurrent ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: wrapper.clicked()
    }

    Keys.onSpacePressed: wrapper.clicked()

    Accessible.name: name
    Accessible.role: Accessible.Button
    function accessiblePressAction() { wrapper.clicked() }
}
