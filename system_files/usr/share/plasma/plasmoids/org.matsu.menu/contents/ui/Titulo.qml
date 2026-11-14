// O título de uma parte do menu ("Fixados", "Recentes", "Todos os apps"), como
// no Menu Iniciar do Windows 11, e à direita um botão pequeno de texto
// ("Mostrar tudo", "Exibição: Categorias").
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

RowLayout {
    id: titulo

    property string texto
    property string acao: ""
    property string iconeAcao: ""

    signal acionado(Item botao)

    readonly property color cor: Kirigami.Theme.textColor

    Layout.fillWidth: true
    Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.55)
    Layout.rightMargin: Math.round(Kirigami.Units.gridUnit * 0.3)
    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.Label {
        text: titulo.texto
        textFormat: Text.PlainText
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
    }

    MouseArea {
        id: botao
        visible: titulo.acao.length > 0
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: titulo.acao
        implicitWidth: conteudo.implicitWidth + Math.round(Kirigami.Units.gridUnit * 1.1)
        implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.55)
        Layout.alignment: Qt.AlignVCenter
        onClicked: titulo.acionado(botao)
        Keys.onReturnPressed: titulo.acionado(botao)
        Keys.onSpacePressed: titulo.acionado(botao)

        Rectangle {
            anchors.fill: parent
            radius: Math.round(Kirigami.Units.gridUnit * 0.4)
            color: Qt.rgba(titulo.cor.r, titulo.cor.g, titulo.cor.b,
                           botao.pressed ? 0.16 : (botao.containsMouse || botao.activeFocus ? 0.11 : 0.06))
            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
        }

        RowLayout {
            id: conteudo
            anchors.centerIn: parent
            spacing: Math.round(Kirigami.Units.gridUnit * 0.25)

            PlasmaComponents.Label {
                text: titulo.acao
                textFormat: Text.PlainText
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            Kirigami.Icon {
                visible: titulo.iconeAcao.length > 0
                source: titulo.iconeAcao
                isMask: true
                color: Kirigami.Theme.textColor
                opacity: 0.8
                implicitWidth: Math.round(Kirigami.Units.gridUnit * 0.7)
                implicitHeight: implicitWidth
            }
        }
    }
}
