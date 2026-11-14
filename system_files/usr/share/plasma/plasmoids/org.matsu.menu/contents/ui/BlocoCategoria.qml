// Um bloco de categoria de "Todos os apps", como na vista Apps do Mac e nas
// pastas do Menu Iniciar do Windows 11: três apps grandes (clicar abre o app)
// e, no quarto canto, os próximos quatro pequenos (clicar abre a categoria).
// Com até quatro apps, os quatro ficam grandes. O nome fica embaixo; clicar
// no fundo do bloco ou no nome também abre a categoria.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: bloco

    property string nome
    property var apps: []

    signal abrirApp(var app)
    signal abrirCategoria()
    signal menuPedido(Item item, var app, real x, real y)

    readonly property color cor: Kirigami.Theme.textColor
    readonly property real lado: width
    readonly property real folga: Math.round(lado * 0.09)
    readonly property real celula: (lado - folga * 2) / 2
    readonly property bool comPilha: apps.length > 4

    implicitHeight: lado + rotulo.implicitHeight + Kirigami.Units.smallSpacing * 2

    Rectangle {
        id: caixa
        width: bloco.lado
        height: bloco.lado
        radius: Math.round(Kirigami.Units.gridUnit * 0.9)
        color: Qt.rgba(bloco.cor.r, bloco.cor.g, bloco.cor.b, fundo.containsMouse || nomeArea.containsMouse ? 0.09 : 0.055)
        border.width: 1
        border.color: Qt.rgba(bloco.cor.r, bloco.cor.g, bloco.cor.b, 0.07)
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }

        MouseArea {
            id: fundo
            anchors.fill: parent
            hoverEnabled: true
            Accessible.role: Accessible.Button
            Accessible.name: bloco.nome
            onClicked: bloco.abrirCategoria()
        }

        // Os apps grandes.
        Repeater {
            model: bloco.comPilha ? 3 : Math.min(4, bloco.apps.length)

            MouseArea {
                id: grande
                required property int index
                readonly property var app: bloco.apps[index]

                x: bloco.folga + (index % 2) * bloco.celula
                y: bloco.folga + Math.floor(index / 2) * bloco.celula
                width: bloco.celula
                height: bloco.celula
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                Accessible.role: Accessible.Button
                Accessible.name: app ? app.nome : ""
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        bloco.menuPedido(grande, app, mouse.x, mouse.y);
                    } else {
                        bloco.abrirApp(app);
                    }
                }
                onPressAndHold: mouse => bloco.menuPedido(grande, app, mouse.x, mouse.y)

                Kirigami.Icon {
                    anchors.centerIn: parent
                    readonly property real base: Math.round(bloco.celula * 0.74)
                    width: grande.containsMouse ? Math.round(base * 1.08) : base
                    height: width
                    roundToIconSize: false
                    source: grande.app ? grande.app.icone : ""
                    Behavior on width {
                        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                    }
                }

                QQC2.ToolTip.text: app ? app.nome : ""
                QQC2.ToolTip.visible: containsMouse && !pressed
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        // Os próximos quatro, pequenos: abrem a categoria inteira.
        MouseArea {
            id: pilha
            visible: bloco.comPilha
            x: bloco.folga + bloco.celula
            y: bloco.folga + bloco.celula
            width: bloco.celula
            height: bloco.celula
            hoverEnabled: true
            Accessible.role: Accessible.Button
            Accessible.name: bloco.nome
            onClicked: bloco.abrirCategoria()

            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.round(bloco.celula * 0.06)
                radius: Math.round(Kirigami.Units.gridUnit * 0.5)
                color: Qt.rgba(bloco.cor.r, bloco.cor.g, bloco.cor.b, pilha.pressed ? 0.16 : (pilha.containsMouse ? 0.10 : 0))
                Behavior on color {
                    ColorAnimation { duration: Kirigami.Units.shortDuration }
                }
            }

            Grid {
                anchors.centerIn: parent
                columns: 2
                spacing: Math.round(bloco.celula * 0.07)

                Repeater {
                    model: bloco.comPilha ? Math.min(4, bloco.apps.length - 3) : 0
                    Kirigami.Icon {
                        required property int index
                        width: Math.round(bloco.celula * 0.33)
                        height: width
                        roundToIconSize: false
                        source: bloco.apps[3 + index].icone
                    }
                }
            }
        }
    }

    MouseArea {
        id: nomeArea
        anchors.top: caixa.bottom
        anchors.topMargin: Kirigami.Units.smallSpacing
        width: bloco.lado
        height: rotulo.implicitHeight
        hoverEnabled: true
        onClicked: bloco.abrirCategoria()

        PlasmaComponents.Label {
            id: rotulo
            anchors.fill: parent
            text: bloco.nome
            textFormat: Text.PlainText
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            opacity: nomeArea.containsMouse ? 1 : 0.8
        }
    }
}
