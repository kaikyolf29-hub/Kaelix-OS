// Mais e menos com o número no meio (− 6 +): o número rola ao trocar e os botões
// "afundam" no clique. Segurar o botão repete. Setas do teclado também mudam.
// O valor muda sozinho (como um controle deslizante) e avisa em mudou(valor).
//   Contador { valor: 5; minimo: 1; maximo: 60; sufixo: " min"; onMudou: (v) => ... }
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: contador

    property real valor: 0
    property real minimo: 0
    property real maximo: 99
    property real passo: 1
    property int casas: 0
    property string sufixo: ""
    property string nome: ""
    property bool ativo: true

    signal mudou(real valor)

    function andar(d) {
        if (!ativo)
            return false;
        var novo = Math.max(minimo, Math.min(maximo, Math.round((valor + d * passo) * 1e6) / 1e6));
        if (novo === valor)
            return false;
        valor = novo;
        mudou(novo);
        return true;
    }

    implicitWidth: linha.implicitWidth + 8
    implicitHeight: Math.round(janela.gu * 2.1)
    radius: height / 2
    color: janela.tinta(janela.escuro ? 0.05 : 0.045)
    border.width: 1
    border.color: foco.activeFocus ? janela.destaque : janela.tinta(janela.escuro ? 0.07 : 0.09)
    opacity: ativo ? 1 : 0.5

    Item {
        id: foco
        anchors.fill: parent
        activeFocusOnTab: contador.ativo
        Accessible.role: Accessible.SpinBox
        Accessible.name: contador.nome
        Accessible.description: numero.texto + contador.sufixo
        Keys.onUpPressed: contador.andar(1)
        Keys.onRightPressed: contador.andar(1)
        Keys.onDownPressed: contador.andar(-1)
        Keys.onLeftPressed: contador.andar(-1)
    }

    GridLayout {
        id: linha
        anchors.centerIn: parent
        rows: 1
        columnSpacing: Math.round(janela.gu * 0.35)

        Repeater {
            model: [-1, 1]
            delegate: MouseArea {
                id: botao
                required property int modelData
                required property int index
                readonly property bool pode: contador.ativo && (modelData < 0 ? contador.valor > contador.minimo : contador.valor < contador.maximo)
                Layout.preferredWidth: contador.height - 8
                Layout.preferredHeight: contador.height - 8
                // O "−" fica antes do número e o "+" depois.
                Layout.column: modelData < 0 ? 0 : 2
                Layout.row: 0
                hoverEnabled: true
                cursorShape: pode ? Qt.PointingHandCursor : Qt.ArrowCursor
                Accessible.role: Accessible.Button
                Accessible.name: modelData < 0 ? janela.t("Menos", "Less") : janela.t("Mais", "More")
                onPressed: if (pode) { contador.andar(modelData); repete.interval = 420; repete.start(); }
                onReleased: repete.stop()
                onCanceled: repete.stop()
                Timer {
                    id: repete
                    repeat: true
                    onTriggered: {
                        interval = 70;
                        if (!contador.andar(botao.modelData))
                            stop();
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    scale: botao.pressed && botao.pode ? 0.88 : 1
                    color: botao.pode ? janela.tinta(botao.pressed ? 0.16 : (botao.containsMouse ? 0.11 : 0.07)) : "transparent"
                    Behavior on scale {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutBack
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                    // Desenho do − e do +, em traço redondo.
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.38)
                        height: 2
                        radius: 1
                        color: janela.frente
                        opacity: botao.pode ? 0.9 : 0.3
                    }
                    Rectangle {
                        visible: botao.modelData > 0
                        anchors.centerIn: parent
                        width: 2
                        height: Math.round(parent.width * 0.38)
                        radius: 1
                        color: janela.frente
                        opacity: botao.pode ? 0.9 : 0.3
                    }
                }
            }
        }
        Item {
            Layout.column: 1
            Layout.row: 0
            Layout.minimumWidth: Math.round(janela.gu * 2)
            implicitWidth: numero.implicitWidth + rotuloSufixo.implicitWidth
            implicitHeight: numero.implicitHeight
            NumeroRolante {
                id: numero
                anchors.right: rotuloSufixo.left
                anchors.verticalCenter: parent.verticalCenter
                texto: janela.num(contador.valor, contador.casas)
                font.pixelSize: Math.round(janela.gu * 0.95)
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            Texto {
                id: rotuloSufixo
                anchors.right: parent.right
                anchors.rightMargin: Math.max(0, (parent.width - numero.implicitWidth - implicitWidth) / 2)
                anchors.verticalCenter: parent.verticalCenter
                text: contador.sufixo
                opacity: 0.7
            }
        }
    }
}
