// Uma nota na grade (como no Google Keep): cartão com o fundo leve da cor, o
// título, o começo do texto (ou os primeiros itens da lista) e, embaixo, quando
// foi mexida. Sobe um pouco com o mouse em cima e afunda ao clicar.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "notas.js" as N

MouseArea {
    id: cartao

    required property string nid
    required property string titulo
    required property string corpo
    required property string amostra
    required property double editada
    required property double apagada
    required property string cor
    required property bool fixada
    required property string tipo
    required property int feitos
    required property int total
    required property string grupo
    property bool escolhido: false

    signal abrir()
    signal pedirMenu(real px, real py)

    readonly property var itens: {
        try {
            return JSON.parse(amostra);
        } catch (e) {
            return [];
        }
    }

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: (m) => { if (m.button === Qt.RightButton) cartao.pedirMenu(m.x, m.y); else cartao.abrir(); }
    Keys.onReturnPressed: cartao.abrir()
    Keys.onSpacePressed: cartao.abrir()
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: titulo

    Rectangle {
        id: fundo
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.7)
        color: janela.cartao
        border.width: 1
        border.color: cartao.escolhido || cartao.activeFocus ? janela.tinta(janela.escuro ? 0.3 : 0.26) : (cartao.containsMouse ? janela.tinta(0.16) : janela.bordaCartao)
        y: cartao.containsMouse && !cartao.pressed ? -2 : 0
        scale: cartao.pressed ? 0.98 : 1
        Behavior on y {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 120
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        // O fundo leve da cor da nota.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: janela.fundoCor(cartao.cor, 1.5)
            Behavior on color {
                ColorAnimation {
                    duration: Kirigami.Units.longDuration
                }
            }
        }
        // Sombra suave que aparece quando o cartão sobe.
        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, janela.escuro ? 0.3 : 0.08)
            opacity: cartao.containsMouse && !cartao.pressed ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(janela.gu * 0.85)
            spacing: Math.round(janela.gu * 0.35)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.4)
                Texto {
                    Layout.fillWidth: true
                    text: N.realcar(cartao.titulo, janela.busca, '<font color="' + janela.corAchado + '">', "</font>")
                    textFormat: Text.StyledText
                    font.weight: Font.DemiBold
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.08
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Kirigami.Icon {
                    Layout.alignment: Qt.AlignTop
                    visible: cartao.fixada && cartao.apagada === 0
                    implicitWidth: Math.round(Kirigami.Units.iconSizes.small * 0.85)
                    implicitHeight: implicitWidth
                    source: Qt.resolvedUrl("icones/fixada.svg")
                    isMask: true
                    color: janela.frente
                    opacity: 0.5
                }
            }

            // Texto: o começo, com as linhas como estão.
            Texto {
                visible: cartao.tipo === "texto"
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: cartao.corpo
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                verticalAlignment: Text.AlignTop
                clip: true
                opacity: 0.72
                lineHeight: 1.12
            }
            // Lista: os primeiros itens, com a bolinha (cheia nos feitos).
            ColumnLayout {
                visible: cartao.tipo === "lista"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(janela.gu * 0.2)
                clip: true
                Repeater {
                    model: cartao.itens
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.4)
                        Rectangle {
                            implicitWidth: Math.round(janela.gu * 0.65)
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: modelData.feito ? janela.tinta(0.45) : "transparent"
                            border.width: modelData.feito ? 0 : 1.3
                            border.color: janela.tinta(0.45)
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: modelData.texto
                            elide: Text.ElideRight
                            font.strikeout: modelData.feito
                            opacity: modelData.feito ? 0.45 : 0.78
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.4)
                Texto {
                    Layout.fillWidth: true
                    text: cartao.apagada > 0
                          ? janela.t("faltam " + N.diasRestantes(cartao.apagada, janela.agora) + " dias", N.diasRestantes(cartao.apagada, janela.agora) + " days left")
                          : N.quando(cartao.editada, janela.agora, janela.lingua)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.55
                    elide: Text.ElideRight
                }
                Texto {
                    visible: cartao.tipo === "lista" && cartao.total > 0
                    text: cartao.feitos + "/" + cartao.total
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                    opacity: 0.55
                }
            }
        }
    }
}
