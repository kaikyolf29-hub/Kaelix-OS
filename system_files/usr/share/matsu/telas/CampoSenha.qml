// A senha numa pílula de vidro, como no Mac: "Digite a senha" apagado dentro, os
// pontinhos ao digitar e a setinha num círculo à direita quando há algo escrito.
// Enter ou a setinha mandam a senha (sinal "enviar"). "mostrar" mostra o texto.
import QtQuick
import QtQuick.Controls.Basic as Basico
import org.kde.kirigami as Kirigami

Basico.TextField {
    id: campo

    property bool mostrar: false
    // O nome que o KDE usa (o LockScreenUi do Plasma 6.8 desliga por ele).
    property alias showPassword: campo.mostrar
    property real altura: 38
    signal enviar()

    readonly property bool pt: Qt.locale().name.indexOf("pt") === 0

    implicitWidth: Math.round(altura * 6)
    implicitHeight: altura
    leftPadding: Math.round(altura * 0.45)
    rightPadding: Math.round(altura * 0.45) + (seta.visible ? seta.width : 0)
    topPadding: 0
    bottomPadding: 0
    verticalAlignment: TextInput.AlignVCenter
    echoMode: mostrar ? TextInput.Normal : TextInput.Password
    passwordCharacter: "●"
    color: "white"
    selectionColor: Qt.rgba(1, 1, 1, 0.35)
    selectedTextColor: "white"
    placeholderText: pt ? "Digite a senha" : "Enter password"
    placeholderTextColor: Qt.rgba(1, 1, 1, 0.62)
    font.family: Kirigami.Theme.defaultFont.family
    font.pixelSize: Math.round(altura * 0.36)
    font.letterSpacing: echoMode === TextInput.Password && text.length > 0 ? 1.5 : 0
    inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
    onAccepted: campo.enviar()

    background: Rectangle {
        radius: height / 2
        color: Qt.rgba(1, 1, 1, campo.activeFocus ? 0.2 : 0.15)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, campo.activeFocus ? 0.38 : 0.22)
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // A setinha de entrar, dentro da pílula.
    Rectangle {
        id: seta
        anchors.right: parent.right
        anchors.rightMargin: Math.round(campo.altura * 0.14)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(campo.altura * 0.72)
        height: width
        radius: width / 2
        visible: campo.text.length > 0
        color: Qt.rgba(1, 1, 1, toqueSeta.pressed ? 0.42 : (toqueSeta.containsMouse ? 0.34 : 0.25))
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.6)
            height: width
            source: "/usr/share/icons/Matsu/status/symbolic/matsu-seta-symbolic.svg"
            isMask: true
            color: "white"
        }
        MouseArea {
            id: toqueSeta
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: campo.enviar()
        }
        Accessible.role: Accessible.Button
        Accessible.name: campo.pt ? "Entrar" : "Log in"
    }
}
