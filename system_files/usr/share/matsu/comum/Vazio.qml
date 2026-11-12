// Quando não há nada para mostrar (nenhuma música, nenhuma câmera...): ícone
// grande num círculo suave, o título, uma frase e, se tiver, um botão.
//   Vazio { icone: "matsu-pasta-symbolic"; titulo: "Nenhuma música"; texto: "..."; botao: "Escolher pasta"; onClicado: ... }
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: vazio

    property string icone: ""
    property string titulo: ""
    property string texto: ""
    property string botao: ""

    signal clicado()

    spacing: Math.round(janela.gu * 0.6)
    width: Math.min(parent ? parent.width - janela.gu * 2 : janela.gu * 22, janela.gu * 22)

    // Entra subindo de leve.
    opacity: 0
    Component.onCompleted: entrada.start()
    ParallelAnimation {
        id: entrada
        NumberAnimation { target: vazio; property: "opacity"; from: 0; to: 1; duration: 420 }
        NumberAnimation { target: vazio; property: "scale"; from: 0.96; to: 1; duration: 520; easing.type: Easing.OutCubic }
    }

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Math.round(janela.gu * 0.4)
        visible: vazio.icone.length > 0
        implicitWidth: Math.round(janela.gu * 4.6)
        implicitHeight: implicitWidth
        radius: width / 2
        color: janela.tinta(janela.escuro ? 0.06 : 0.05)
        border.width: 1
        border.color: janela.tinta(0.06)
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.44)
            height: width
            source: vazio.icone
            isMask: true
            color: janela.frente
            opacity: 0.75
        }
    }
    Texto {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: vazio.titulo
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
    }
    Texto {
        Layout.fillWidth: true
        visible: vazio.texto.length > 0
        horizontalAlignment: Text.AlignHCenter
        text: vazio.texto
        opacity: 0.65
        wrapMode: Text.WordWrap
    }
    BotaoDestaque {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Math.round(janela.gu * 0.4)
        visible: vazio.botao.length > 0
        texto: vazio.botao
        onClicado: vazio.clicado()
    }
}
