// A faixa "Manter estas configurações?", como no Mac e no Windows: aparece
// descendo em cima da página depois de uma mudança que pode deixar a tela
// preta, com a contagem descendo e uma linha fina que encurta até a volta.
// Quem volta de verdade é o ajudante (monitores/ajudante.py): a faixa só mostra.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: faixa

    property bool aberta: false
    property int segundos: 0
    property real total: 15
    property real falta: 0
    readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property int gu: Kirigami.Units.gridUnit

    signal manter()
    signal voltar()

    implicitHeight: cartao.implicitHeight
    height: implicitHeight
    visible: opacity > 0.01
    opacity: aberta ? 1 : 0
    z: 50
    transform: Translate {
        y: faixa.aberta ? 0 : -faixa.gu * 1.2
        Behavior on y {
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
        }
    }
    Behavior on opacity {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    // A página por baixo não recebe os cliques da faixa.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Kirigami.ShadowedRectangle {
        id: cartao
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: linha.implicitHeight + faixa.gu * 1.4
        radius: Math.round(faixa.gu * 0.75)
        color: faixa.escuro ? Qt.rgba(0.165, 0.165, 0.18, 0.97) : Qt.rgba(0.99, 0.99, 0.995, 0.97)
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
        shadow.size: Math.round(faixa.gu * 1.3)
        shadow.yOffset: 5
        shadow.color: Qt.rgba(0, 0, 0, faixa.escuro ? 0.5 : 0.18)

        RowLayout {
            id: linha
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Math.round(faixa.gu * 0.8)
            anchors.rightMargin: Math.round(faixa.gu * 0.7)
            spacing: Math.round(faixa.gu * 0.7)

            // O relógio da contagem: o número dentro de um anel que se esvazia.
            Item {
                implicitWidth: Math.round(faixa.gu * 2)
                implicitHeight: implicitWidth

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                }
                Canvas {
                    id: anel
                    anchors.fill: parent
                    property real parte: faixa.total > 0 ? Math.max(0, Math.min(1, faixa.falta / faixa.total)) : 0
                    property color cor: Kirigami.Theme.textColor
                    onParteChanged: requestPaint()
                    onCorChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var r = width / 2 - 1.5;
                        ctx.lineWidth = 2.5;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = Qt.rgba(cor.r, cor.g, cor.b, 0.85);
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + parte * 2 * Math.PI, false);
                        ctx.stroke();
                    }
                }
                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: faixa.segundos
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: ajustes.t("Manter estas configurações?", "Keep these display settings?")
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: ajustes.t("Voltando em " + faixa.segundos + " s",
                                    "Reverting in " + faixa.segundos + " s")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                    font.features: ({ "tnum": 1 })
                    opacity: 0.65
                    elide: Text.ElideRight
                }
            }

            TelasBotao {
                texto: ajustes.t("Voltar", "Revert")
                onClicked: faixa.voltar()
            }
            TelasBotao {
                principal: true
                texto: ajustes.t("Manter", "Keep")
                onClicked: faixa.manter()
            }
        }
    }
}
