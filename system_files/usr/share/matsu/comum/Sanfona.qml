// Sanfona: um cartão com o título e a setinha; clicar abre e fecha, e o miolo
// desliza junto. Várias em coluna formam as perguntas frequentes, por exemplo.
//   Sanfona { titulo: "Como funciona?"; Texto { width: parent.width; wrapMode: Text.WordWrap; text: "..." } }
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: sanfona

    property string titulo: ""
    property string icone: ""
    property bool aberta: false
    default property alias conteudo: miolo.data

    signal trocada(bool aberta)

    readonly property int folga: Math.round(janela.gu * 0.9)

    Layout.fillWidth: true
    implicitWidth: Math.round(janela.gu * 20)
    implicitHeight: cabeca.height + corpo.height
    radius: Math.round(janela.gu * 0.5)
    color: janela.cartao
    border.width: 1
    border.color: aberta ? janela.tinta(janela.escuro ? 0.12 : 0.13) : janela.bordaCartao
    clip: true
    Behavior on border.color {
        ColorAnimation {
            duration: Kirigami.Units.longDuration
        }
    }

    MouseArea {
        id: cabeca
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(Math.round(janela.gu * 2.8), linha.implicitHeight + sanfona.folga)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: sanfona.titulo
        onClicked: { sanfona.aberta = !sanfona.aberta; sanfona.trocada(sanfona.aberta); }
        Keys.onSpacePressed: clicked(null)
        Keys.onReturnPressed: clicked(null)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: sanfona.radius - 1
            color: janela.tinta(cabeca.containsMouse ? 0.035 : 0)
            border.width: cabeca.activeFocus ? 1 : 0
            border.color: janela.destaque
        }
        RowLayout {
            id: linha
            anchors.fill: parent
            anchors.leftMargin: sanfona.folga
            anchors.rightMargin: sanfona.folga
            spacing: Math.round(janela.gu * 0.6)
            Kirigami.Icon {
                visible: sanfona.icone.length > 0
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: sanfona.icone
                isMask: true
                color: janela.frente
                opacity: 0.85
            }
            Texto {
                Layout.fillWidth: true
                text: sanfona.titulo
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            // A setinha gira para baixo quando abre, dentro de um círculo.
            Rectangle {
                Layout.preferredWidth: Math.round(janela.gu * 1.4)
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: janela.tinta(sanfona.aberta ? 0.09 : 0.05)
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(Kirigami.Units.iconSizes.small * 0.8)
                    height: width
                    source: "matsu-seta-symbolic"
                    isMask: true
                    color: janela.frente
                    rotation: sanfona.aberta ? -90 : 90
                    Behavior on rotation {
                        NumberAnimation {
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }
        }
    }

    Item {
        id: corpo
        anchors.top: cabeca.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: sanfona.aberta ? miolo.implicitHeight + sanfona.folga : 0
        clip: true
        Behavior on height {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
        Column {
            id: miolo
            x: sanfona.folga
            width: parent.width - 2 * sanfona.folga
            y: sanfona.aberta ? 0 : -Math.round(janela.gu * 0.6)
            opacity: sanfona.aberta ? 1 : 0
            spacing: Math.round(janela.gu * 0.5)
            Behavior on y {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                }
            }
        }
    }
}
