// Uma nota na lista do miolo: o pontinho da cor, o título e, embaixo, quando foi
// mexida e o começo do texto (como no Notas do Mac). O fundo da escolhida é a
// pílula que desliza (o highlight da lista); aqui fica só o fundo do mouse.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "notas.js" as N

MouseArea {
    id: item

    required property int index
    required property string nid
    required property string titulo
    required property string previa
    required property double editada
    required property double apagada
    required property string cor
    required property bool fixada
    required property string tipo
    required property int feitos
    required property int total
    required property string grupo

    readonly property bool escolhido: ListView.isCurrentItem
    readonly property bool proximoEscolhido: ListView.view && ListView.view.currentIndex === index + 1

    signal escolher()
    signal pedirMenu(real px, real py)

    width: ListView.view ? ListView.view.width : 0
    implicitHeight: coluna.implicitHeight + Math.round(janela.gu * 1.15)
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onPressed: (m) => { if (m.button === Qt.LeftButton) item.escolher(); }
    onClicked: (m) => { if (m.button === Qt.RightButton) item.pedirMenu(m.x, m.y); }
    Accessible.role: Accessible.ListItem
    Accessible.name: titulo

    Rectangle {
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.45)
        color: janela.tinta(!item.escolhido && item.containsMouse ? (item.pressed ? 0.07 : 0.045) : 0)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }
    // A linha fina entre as notas some perto da escolhida e do mouse.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(janela.gu * 0.75)
        anchors.rightMargin: Math.round(janela.gu * 0.75)
        height: 1
        color: janela.tinta(janela.escuro ? 0.07 : 0.08)
        opacity: item.escolhido || item.proximoEscolhido || item.containsMouse ? 0 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }

    ColumnLayout {
        id: coluna
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Math.round(janela.gu * 0.75)
        anchors.rightMargin: Math.round(janela.gu * 0.65)
        spacing: Math.round(janela.gu * 0.15)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.4)
            Rectangle {
                visible: item.cor !== ""
                implicitWidth: Math.round(janela.gu * 0.55)
                implicitHeight: implicitWidth
                radius: width / 2
                color: janela.tom(item.cor)
            }
            Texto {
                Layout.fillWidth: true
                text: N.realcar(item.titulo, janela.busca, '<font color="' + janela.corAchado + '">', "</font>")
                textFormat: Text.StyledText
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Kirigami.Icon {
                visible: item.fixada && item.apagada === 0 && item.grupo === ""
                implicitWidth: Math.round(Kirigami.Units.iconSizes.small * 0.8)
                implicitHeight: implicitWidth
                source: Qt.resolvedUrl("icones/fixada.svg")
                isMask: true
                color: janela.frente
                opacity: 0.45
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.45)
            Texto {
                text: item.apagada > 0
                      ? janela.t("faltam " + N.diasRestantes(item.apagada, janela.agora) + " dias", N.diasRestantes(item.apagada, janela.agora) + " days left")
                      : N.quando(item.editada, janela.agora, janela.lingua)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.features: { "tnum": 1 }
                opacity: 0.55
            }
            // Lista: o quanto já foi feito.
            Row {
                visible: item.tipo === "lista" && item.total > 0
                spacing: 3
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(Kirigami.Units.iconSizes.small * 0.75)
                    height: width
                    source: Qt.resolvedUrl("icones/lista.svg")
                    isMask: true
                    color: janela.frente
                    opacity: 0.55
                }
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    text: item.feitos + "/" + item.total
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                    opacity: 0.6
                }
            }
            Texto {
                Layout.fillWidth: true
                text: item.previa ? N.realcar(item.previa, janela.busca, '<font color="' + janela.corAchado + '">', "</font>")
                                  : (item.tipo === "lista" ? "" : janela.t("Sem mais texto", "No additional text"))
                textFormat: Text.StyledText
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                maximumLineCount: 1
                opacity: item.previa ? 0.62 : 0.38
            }
        }
    }
}
