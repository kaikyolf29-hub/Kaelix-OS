// Campo de texto do Matsu: fundo suave, borda que acende na cor de destaque com o
// foco, ícone opcional na frente e o xis para limpar.
//   Campo { dica: "Nome do alarme"; texto: nome; onEditado: (t) => nome = t; onConfirmado: salvar() }
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: campo

    property alias texto: entrada.text
    property string dica: ""
    property string icone: ""
    property bool senha: false
    property bool podeLimpar: true
    property int maximo: 32767
    readonly property alias entrada: entrada

    signal editado(string texto)
    signal confirmado(string texto)

    function focar() {
        entrada.forceActiveFocus();
        entrada.selectAll();
    }

    implicitWidth: Math.round(janela.gu * 14)
    implicitHeight: Math.round(janela.gu * 2.1)
    radius: Math.round(janela.gu * 0.4)
    color: janela.tinta(entrada.activeFocus ? (janela.escuro ? 0.08 : 0.03) : (area.containsMouse ? 0.07 : (janela.escuro ? 0.05 : 0.04)))
    border.width: entrada.activeFocus ? 1.5 : 1
    border.color: entrada.activeFocus ? janela.destaque : janela.tinta(janela.escuro ? 0.09 : 0.12)
    Behavior on color {
        ColorAnimation {
            duration: Kirigami.Units.shortDuration
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onPressed: (m) => { entrada.forceActiveFocus(); m.accepted = false; }
    }
    Kirigami.Icon {
        id: simbolo
        visible: campo.icone.length > 0
        anchors.left: parent.left
        anchors.leftMargin: Math.round(janela.gu * 0.6)
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? Kirigami.Units.iconSizes.small : 0
        height: width
        source: campo.icone
        isMask: true
        color: janela.frente
        opacity: 0.65
    }
    TextInput {
        id: entrada
        anchors.left: simbolo.visible ? simbolo.right : parent.left
        anchors.leftMargin: Math.round(janela.gu * (simbolo.visible ? 0.45 : 0.7))
        anchors.right: limpar.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        color: janela.frente
        selectionColor: janela.destaque
        selectedTextColor: janela.sobreDestaque
        font: Kirigami.Theme.defaultFont
        echoMode: campo.senha ? TextInput.Password : TextInput.Normal
        maximumLength: campo.maximo
        clip: true
        selectByMouse: true
        onTextEdited: campo.editado(text)
        onAccepted: campo.confirmado(text)
        Keys.onEscapePressed: (e) => { if (text.length > 0 && campo.podeLimpar) { text = ""; campo.editado(""); } else e.accepted = false; }
        Accessible.name: campo.dica

        Texto {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: entrada.text.length === 0
            text: campo.dica
            opacity: entrada.activeFocus ? 0.4 : 0.55
            elide: Text.ElideRight
        }
    }
    MouseArea {
        id: limpar
        anchors.right: parent.right
        anchors.rightMargin: Math.round(janela.gu * 0.4)
        anchors.verticalCenter: parent.verticalCenter
        readonly property bool mostrar: campo.podeLimpar && entrada.text.length > 0
        width: mostrar ? Math.round(janela.gu * 1.2) : 0
        height: Math.round(janela.gu * 1.2)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { entrada.text = ""; campo.editado(""); entrada.forceActiveFocus(); }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: janela.tinta(limpar.containsMouse ? 0.1 : 0)
            scale: limpar.mostrar ? 1 : 0.4
            opacity: limpar.mostrar ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutBack
                }
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(Kirigami.Units.iconSizes.small * 0.8)
                height: width
                source: "matsu-fechar-symbolic"
                isMask: true
                color: janela.frente
                opacity: 0.7
            }
        }
    }
}
