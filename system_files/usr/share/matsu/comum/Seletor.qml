// Escolha entre poucas opções lado a lado (como os botões segmentados do
// Windows 11): a escolhida ganha o fundo claro, que desliza até ela.
//   Seletor { opcoes: [{ id: "a", nome: "A" }, ...]; escolhido: "a"; onEscolher: (id) => ... }
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: seletor

    property var opcoes: []
    property string escolhido: ""
    property bool ativo: true

    signal escolher(string id)

    readonly property int indice: {
        for (var i = 0; i < opcoes.length; i++)
            if (opcoes[i].id === escolhido)
                return i;
        return -1;
    }

    implicitWidth: linha.implicitWidth + 6
    implicitHeight: Math.round(janela.gu * 1.8)
    radius: Math.round(janela.gu * 0.35)
    color: janela.tinta(janela.escuro ? 0.05 : 0.045)
    border.width: 1
    border.color: janela.tinta(janela.escuro ? 0.07 : 0.09)
    opacity: ativo ? 1 : 0.55

    // O fundo da escolhida, que anda até a nova.
    Rectangle {
        readonly property Item alvo: seletor.indice >= 0 && repetidor.count > seletor.indice ? repetidor.itemAt(seletor.indice) : null
        visible: alvo !== null
        x: alvo ? linha.x + alvo.x : 0
        y: 3
        width: alvo ? alvo.width : 0
        height: parent.height - 6
        radius: Math.max(2, seletor.radius - 2)
        color: janela.escuro ? Qt.rgba(1, 1, 1, 0.11) : "#ffffff"
        border.width: janela.escuro ? 0 : 1
        border.color: janela.tinta(0.08)
        Behavior on x {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    RowLayout {
        id: linha
        anchors.fill: parent
        anchors.margins: 3
        spacing: 0

        Repeater {
            id: repetidor
            model: seletor.opcoes

            MouseArea {
                id: opcao
                required property var modelData
                required property int index
                readonly property bool escolhida: seletor.escolhido === modelData.id
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitWidth: rotulo.implicitWidth + (simbolo.visible ? simbolo.width + 6 : 0) + Math.round(janela.gu * 1.3)
                hoverEnabled: true
                enabled: seletor.ativo
                cursorShape: Qt.PointingHandCursor
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.nome
                Accessible.checked: escolhida
                onClicked: seletor.escolher(modelData.id)
                Keys.onSpacePressed: seletor.escolher(modelData.id)
                Keys.onReturnPressed: seletor.escolher(modelData.id)

                Rectangle {
                    anchors.fill: parent
                    radius: Math.max(2, seletor.radius - 2)
                    color: janela.tinta(!opcao.escolhida && opcao.containsMouse ? 0.05 : 0)
                    border.width: opcao.activeFocus ? 1 : 0
                    border.color: janela.destaque
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Kirigami.Icon {
                        id: simbolo
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (opcao.modelData.icone || "").length > 0
                        width: visible ? Kirigami.Units.iconSizes.small : 0
                        height: width
                        source: opcao.modelData.icone || ""
                        isMask: true
                        color: janela.frente
                        opacity: opcao.escolhida ? 1 : 0.75
                    }
                    Texto {
                        id: rotulo
                        anchors.verticalCenter: parent.verticalCenter
                        text: opcao.modelData.nome
                        font.weight: opcao.escolhida ? Font.DemiBold : Font.Normal
                        opacity: opcao.escolhida ? 1 : 0.78
                    }
                }
            }
        }
    }
}
