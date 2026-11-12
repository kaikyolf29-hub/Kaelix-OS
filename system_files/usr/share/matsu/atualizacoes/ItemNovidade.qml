// Um item das novidades: a folhinha do Matsu, o assunto e o que mudou. Os itens
// entram um depois do outro (subindo de leve) e o cartão acende com o mouse.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Cartao {
    id: item

    property string assunto: ""
    property string texto: ""
    property int ordem: 0
    property real entrada: 0

    implicitHeight: linha.implicitHeight + Math.round(janela.gu * 1.8)
    color: sobre.hovered ? janela.tinta(janela.escuro ? 0.07 : 0.05) : janela.cartao
    opacity: entrada
    transform: Translate { y: (1 - item.entrada) * Math.round(janela.gu * 0.8) }
    Behavior on color {
        ColorAnimation { duration: Kirigami.Units.shortDuration }
    }

    SequentialAnimation {
        running: true
        PauseAnimation { duration: 60 + Math.min(item.ordem, 12) * 45 }
        NumberAnimation { target: item; property: "entrada"; to: 1; duration: 360; easing.type: Easing.OutCubic }
    }
    HoverHandler {
        id: sobre
    }

    RowLayout {
        id: linha
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Math.round(janela.gu * 0.9)
        spacing: Math.round(janela.gu * 0.75)

        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Math.round(janela.gu * 1.9)
            Layout.preferredHeight: Layout.preferredWidth
            radius: Math.round(janela.gu * 0.5)
            color: janela.tinta(sobre.hovered ? 0.11 : 0.07)
            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small
                height: width
                source: "matsu-folha-symbolic"
                isMask: true
                color: janela.frente
                rotation: sobre.hovered ? -12 : 0
                Behavior on rotation {
                    NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Texto {
                Layout.fillWidth: true
                visible: item.assunto !== ""
                text: item.assunto
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
            Texto {
                Layout.fillWidth: true
                text: item.texto
                opacity: 0.72
                wrapMode: Text.WordWrap
                lineHeight: 1.08
            }
        }
    }
}
