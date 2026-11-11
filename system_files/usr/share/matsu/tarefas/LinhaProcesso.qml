// Uma linha da lista de processos: título de seção ("Apps (5)"), um app (com a
// setinha, se tiver mais de um processo) ou um processo dele. As colunas de
// CPU, memória e disco ganham um âmbar bem leve quando a coisa gasta, mais
// forte quanto mais gasta (como no Windows); parada, fica sem cor.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: linha

    required property var model
    property int colNum: 100
    property bool selecionada: false
    property real memTotal: 1

    signal clicada()
    signal alternada()
    signal menuPedido()

    readonly property bool secao: model.tipo === "secao"
    readonly property int recuo: Math.round(janela.gu * 0.75)

    implicitHeight: secao ? Math.round(janela.gu * 2.2) : Math.round(janela.gu * 1.7)
    hoverEnabled: !secao
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    Accessible.role: secao ? Accessible.StaticText : Accessible.ListItem
    Accessible.name: model.nome
    Accessible.selected: selecionada

    onClicked: mouse => {
        if (secao)
            return;
        if (mouse.button === Qt.RightButton)
            linha.menuPedido();
        else
            linha.clicada();
    }
    onDoubleClicked: {
        if (model.tipo === "grupo" && model.n > 1)
            linha.alternada();
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Nome (com a setinha e o ícone).
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Kirigami.Icon {
                id: seta
                visible: linha.model.tipo === "grupo" && linha.model.n > 1
                x: linha.recuo
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                source: "matsu-seta-symbolic"
                isMask: true
                color: janela.frente
                opacity: 0.7
                rotation: linha.model.aberto ? 90 : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: linha.alternada()
                }
            }

            Kirigami.Icon {
                id: icone
                visible: !linha.secao
                x: linha.recuo + Math.round(janela.gu * (linha.model.nivel > 0 ? 2.3 : 1.25))
                anchors.verticalCenter: parent.verticalCenter
                width: Kirigami.Units.iconSizes.small
                height: width
                source: linha.model.icone.length > 0 ? linha.model.icone
                      : (linha.model.tipo === "proc" ? "matsu-processo-symbolic" : "matsu-engrenagem-symbolic")
                fallback: "matsu-engrenagem-symbolic"
                isMask: linha.model.icone.length === 0
                color: janela.frente
                opacity: linha.model.icone.length > 0 ? 1 : 0.7
            }

            Texto {
                anchors.left: linha.secao ? parent.left : icone.right
                anchors.leftMargin: linha.secao ? linha.recuo : Math.round(janela.gu * 0.55)
                anchors.right: parent.right
                anchors.rightMargin: Math.round(janela.gu * 0.5)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: linha.secao ? Math.round(janela.gu * 0.3) : 0
                text: {
                    var n = linha.model.nome;
                    if (linha.secao || (linha.model.tipo === "grupo" && linha.model.n > 1))
                        n += " (" + linha.model.n + ")";
                    return n;
                }
                elide: Text.ElideRight
                font.weight: linha.secao ? Font.DemiBold : Font.Normal
                opacity: linha.model.tipo === "proc" ? 0.82 : 0.95
            }
        }

        Repeater {
            model: linha.secao ? [] : [
                { valor: linha.model.cpu, texto: janela.num(linha.model.cpu, 1) + "%", cheio: 50 },
                { valor: linha.model.mem, texto: janela.bytes(linha.model.mem), cheio: linha.memTotal * 0.25 },
                { valor: linha.model.disco, texto: janela.mbs(linha.model.disco), cheio: 20 * 1048576 }
            ]

            Rectangle {
                id: celula
                required property var modelData
                Layout.preferredWidth: linha.colNum
                Layout.fillHeight: true
                color: janela.calor(modelData.valor, modelData.cheio)
                Behavior on color {
                    ColorAnimation {
                        duration: Kirigami.Units.longDuration
                    }
                }

                Texto {
                    anchors.fill: parent
                    anchors.rightMargin: Math.round(janela.gu * 0.6)
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    text: celula.modelData.texto
                    font.features: { "tnum": 1 }
                    opacity: celula.modelData.valor > 0 ? (linha.model.tipo === "proc" ? 0.82 : 0.95) : 0.5
                }
            }
        }
    }

    // Escolhida ou com o mouse em cima: um véu claro por cima da linha toda.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        visible: !linha.secao
        radius: Math.round(janela.gu * 0.25)
        color: janela.tinta(linha.selecionada ? (janela.escuro ? 0.09 : 0.075) : (linha.containsMouse ? 0.045 : 0))
    }
}
