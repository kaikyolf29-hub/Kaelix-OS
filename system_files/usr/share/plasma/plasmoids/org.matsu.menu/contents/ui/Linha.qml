// Uma linha do menu, como as do vídeo da fusão: o ícone, o nome em negrito e,
// embaixo, uma linha pequena (o tipo do app, a pasta do arquivo ou o que o
// resultado faz).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: linha

    property var icone
    property string titulo
    property string detalhe
    // A linha escolhida (pelo teclado ou o primeiro resultado da busca).
    property bool destacado: false
    property real tamanhoIcone: Math.round(Kirigami.Units.gridUnit * 1.9)
    // Só o nome, sem negrito (a exibição em lista de "Todos os apps").
    property bool simples: false

    signal acionado()
    // Botão direito (ou segurar apertado): o menu do app (fixar na barra...).
    signal menuPedido(real x, real y)

    readonly property color texto: Kirigami.Theme.textColor
    readonly property color realce: Kirigami.Theme.highlightColor

    implicitHeight: Math.round(Kirigami.Units.gridUnit * 2.9)
    hoverEnabled: true
    Accessible.role: Accessible.Button
    Accessible.name: titulo
    Accessible.description: detalhe
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            menuPedido(mouse.x, mouse.y);
        } else {
            acionado();
        }
    }
    onPressAndHold: mouse => menuPedido(mouse.x, mouse.y)

    Rectangle {
        anchors.fill: parent
        radius: Math.round(Kirigami.Units.gridUnit * 0.67)
        color: linha.destacado
            ? Qt.rgba(linha.realce.r, linha.realce.g, linha.realce.b, linha.pressed ? 0.42 : 0.28)
            : Qt.rgba(linha.texto.r, linha.texto.g, linha.texto.b, linha.pressed ? 0.16 : (linha.containsMouse ? 0.09 : 0))
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(Kirigami.Units.gridUnit * 0.55)
        anchors.rightMargin: Math.round(Kirigami.Units.gridUnit * 0.55)
        spacing: Math.round(Kirigami.Units.gridUnit * 0.67)

        Kirigami.Icon {
            source: linha.icone
            implicitWidth: linha.tamanhoIcone
            implicitHeight: linha.tamanhoIcone
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            PlasmaComponents.Label {
                text: linha.titulo
                textFormat: Text.PlainText
                font.weight: linha.simples ? Font.Normal : Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                visible: linha.detalhe.length > 0
                text: linha.detalhe
                textFormat: Text.PlainText
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.65
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
