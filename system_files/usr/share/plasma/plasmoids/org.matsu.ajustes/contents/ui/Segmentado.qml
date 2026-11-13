// Escolha de uma entre poucas opções, lado a lado (como "Perfil de energia" no
// vídeo): a escolhida fica numa pílula clara, que desliza de uma opção para a outra.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: grupo

    // Cada opção: { valor: "balanced", nome: "Equilibrado", ativa: true }
    property var opcoes: []
    property string atual: ""
    readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5

    signal escolhido(string valor)

    implicitHeight: linha.implicitHeight + 6
    radius: Math.round(Kirigami.Units.gridUnit * 0.55)
    color: escuro ? Qt.rgba(0.08, 0.09, 0.17, 0.5) : Qt.rgba(0.11, 0.13, 0.22, 0.1)

    readonly property int indice: {
        for (var i = 0; i < opcoes.length; i++)
            if (opcoes[i].valor === atual)
                return i;
        return -1;
    }

    // A pílula da escolhida (uma só, que desliza). Só anima depois de aparecer.
    Rectangle {
        id: pilula
        readonly property Item alvo: grupo.indice >= 0 && grupo.indice < repetidor.count ? repetidor.itemAt(grupo.indice) : null
        property bool pronta: false
        visible: alvo !== null
        x: alvo ? linha.x + alvo.x : 0
        y: alvo ? linha.y + alvo.y : 0
        width: alvo ? alvo.width : 0
        height: alvo ? alvo.height : 0
        radius: Math.round(Kirigami.Units.gridUnit * 0.45)
        color: grupo.escuro ? "#f1f3fa" : "#ffffff"
        Behavior on x {
            enabled: pilula.pronta
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            enabled: pilula.pronta
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
        Timer {
            running: true
            interval: 300
            onTriggered: pilula.pronta = true
        }
    }

    RowLayout {
        id: linha
        anchors.fill: parent
        anchors.margins: 3
        spacing: 4

        Repeater {
            id: repetidor
            model: grupo.opcoes

            MouseArea {
                id: opcao

                required property var modelData
                readonly property bool escolhida: modelData.valor === grupo.atual

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: rotulo.implicitHeight + Math.round(Kirigami.Units.gridUnit * 0.75)
                enabled: modelData.ativa !== false
                hoverEnabled: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.nome
                Accessible.checked: escolhida
                onClicked: grupo.escolhido(modelData.valor)

                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(Kirigami.Units.gridUnit * 0.45)
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                                   !opcao.escolhida && opcao.containsMouse ? 0.08 : 0)
                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }
                PlasmaComponents.Label {
                    id: rotulo
                    anchors.centerIn: parent
                    width: parent.width - 4
                    horizontalAlignment: Text.AlignHCenter
                    text: opcao.modelData.nome
                    elide: Text.ElideRight
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                    font.weight: opcao.escolhida ? Font.DemiBold : Font.Normal
                    color: opcao.escolhida ? "#1a1a1e" : Kirigami.Theme.textColor
                    opacity: opcao.escolhida ? 1 : (opcao.enabled ? 0.75 : 0.35)
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                }
            }
        }
    }
}
