// Escolha numa lista em ordem (limite de FPS, nitidez...): setinhas dos lados e
// o valor no meio, que desliza para o lado ao trocar.
//   Passos { opcoes: [{ id: 0, nome: "Sem limite" }, ...]; escolhido: 0; onEscolher: (id) => ... }
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: passos

    property var opcoes: []
    property var escolhido
    property bool ativo: true
    property string nome: ""

    signal escolher(var id)

    readonly property int indice: {
        for (var i = 0; i < opcoes.length; i++)
            if (opcoes[i].id === escolhido)
                return i;
        return 0;
    }
    property int direcao: 1

    function andar(d) {
        var n = indice + d;
        if (!ativo || n < 0 || n >= opcoes.length)
            return;
        direcao = d;
        escolher(opcoes[n].id);
    }

    implicitWidth: Math.round(janela.gu * 9.5)
    implicitHeight: Math.round(janela.gu * 1.8)
    radius: Math.round(janela.gu * 0.35)
    color: janela.tinta(janela.escuro ? 0.05 : 0.045)
    border.width: area.activeFocus ? 1 : 1
    border.color: area.activeFocus ? janela.destaque : janela.tinta(janela.escuro ? 0.07 : 0.09)
    opacity: ativo ? 1 : 0.55
    activeFocusOnTab: false

    Item {
        id: area
        anchors.fill: parent
        activeFocusOnTab: passos.ativo
        Accessible.role: Accessible.SpinBox
        Accessible.name: passos.nome
        Accessible.description: passos.opcoes.length > 0 ? passos.opcoes[passos.indice].nome : ""
        Keys.onLeftPressed: passos.andar(-1)
        Keys.onRightPressed: passos.andar(1)
    }

    Repeater {
        model: [-1, 1]
        MouseArea {
            id: seta
            required property int modelData
            readonly property bool pode: passos.ativo && (modelData < 0 ? passos.indice > 0 : passos.indice < passos.opcoes.length - 1)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 3
            x: modelData < 0 ? 3 : parent.width - width - 3
            width: height
            hoverEnabled: true
            cursorShape: pode ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: passos.andar(modelData)
            Rectangle {
                anchors.fill: parent
                radius: Math.max(2, passos.radius - 2)
                color: janela.tinta(seta.pode && seta.containsMouse ? (seta.pressed ? 0.1 : 0.06) : 0)
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(Kirigami.Units.iconSizes.small * 0.85)
                height: width
                source: "matsu-seta-symbolic"
                rotation: seta.modelData < 0 ? 180 : 0
                isMask: true
                color: janela.frente
                opacity: seta.pode ? 0.85 : 0.25
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: parent.height
        anchors.rightMargin: parent.height
        clip: true
        Texto {
            id: valor
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: passos.opcoes.length > 0 ? passos.opcoes[passos.indice].nome : ""
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }
    // Ao trocar, o valor entra deslizando do lado da seta.
    onIndiceChanged: entrada.restart()
    ParallelAnimation {
        id: entrada
        NumberAnimation { target: valor; property: "x"; from: passos.direcao * janela.gu * 0.8; to: 0; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: valor; property: "opacity"; from: 0.2; to: 1; duration: Kirigami.Units.longDuration }
    }
}
