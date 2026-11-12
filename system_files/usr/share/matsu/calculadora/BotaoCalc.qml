// Tecla da calculadora, como as da Calculadora do Windows 11 com o acabamento do
// Matsu: cantos redondos, os números um pouco mais claros que as operações, o "="
// na cor de destaque. Afunda ao clicar e volta com um pulinho; a tecla do teclado
// físico faz a mesma coisa (janela.piscar). Trocar o rótulo (a tecla 2ª) desliza
// o texto novo de baixo para cima.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: botao

    property string chave: ""
    property string rotulo: ""
    property string icone: ""
    // "numero" | "operador" | "funcao" | "igual"
    property string tipo: "funcao"
    property bool ligado: false
    property bool ativo: true
    property string dica: ""
    // Número pequeno no canto (parênteses abertos).
    property int contador: 0
    // Segurar repete (apagar).
    property bool repete: false

    signal acionado(string chave)

    readonly property bool cheio: tipo === "igual" || ligado
    property real afundar: 0
    property bool repetiu: false

    hoverEnabled: true
    cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
    Accessible.role: Accessible.Button
    Accessible.name: dica || rotulo
    onPressedChanged: {
        if (!ativo)
            return;
        if (pressed) {
            volta.stop();
            pulso.stop();
            desce.restart();
            repetiu = false;
            if (repete) {
                repeticao.interval = 420;
                repeticao.start();
            }
        } else {
            desce.stop();
            repeticao.stop();
            volta.restart();
        }
    }
    onClicked: if (ativo && !repetiu) botao.acionado(chave)

    // A tecla do teclado físico: afunda e volta sozinha.
    function piscar() {
        if (!ativo)
            return;
        desce.stop();
        volta.stop();
        pulso.restart();
    }

    Connections {
        target: janela
        function onPiscar(qual) {
            if (qual === botao.chave)
                botao.piscar();
        }
    }

    NumberAnimation {
        id: desce
        target: botao
        property: "afundar"
        to: 1
        duration: 70
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: volta
        target: botao
        property: "afundar"
        to: 0
        duration: 340
        easing.type: Easing.OutBack
        easing.overshoot: 2.4
    }
    SequentialAnimation {
        id: pulso
        NumberAnimation { target: botao; property: "afundar"; to: 1; duration: 60; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 40 }
        NumberAnimation { target: botao; property: "afundar"; to: 0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
    }
    Timer {
        id: repeticao
        interval: 420
        repeat: true
        onTriggered: {
            interval = 70;
            botao.repetiu = true;
            botao.acionado(botao.chave);
        }
    }

    // ----- cores -----
    function misturar(a, b, f) {
        f = Math.max(0, Math.min(1, f));
        return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, a.a + (b.a - a.a) * f);
    }
    readonly property color corParada: {
        if (cheio)
            return janela.destaque;
        if (tipo === "numero")
            return janela.escuro ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.96);
        return janela.escuro ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(0, 0, 0, 0.028);
    }
    readonly property color corPassando: {
        if (cheio)
            return janela.escuro ? Qt.darker(janela.destaque, 1.12) : Qt.lighter(janela.destaque, 1.35);
        if (tipo === "numero")
            return janela.escuro ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0.975, 0.975, 0.98, 1);
        return janela.escuro ? Qt.rgba(1, 1, 1, 0.085) : Qt.rgba(0, 0, 0, 0.055);
    }
    readonly property color corApertada: {
        if (cheio)
            return janela.escuro ? Qt.darker(janela.destaque, 1.3) : Qt.lighter(janela.destaque, 1.7);
        return janela.escuro ? Qt.rgba(1, 1, 1, 0.03) : Qt.rgba(0, 0, 0, 0.07);
    }
    readonly property color corLetra: cheio ? janela.sobreDestaque : janela.frente

    Rectangle {
        id: caixa
        anchors.fill: parent
        anchors.margins: 1.5
        radius: Math.round(janela.gu * 0.38)
        scale: 1 - 0.055 * botao.afundar
        color: botao.misturar(botao.containsMouse && botao.ativo ? botao.corPassando : botao.corParada, botao.corApertada, botao.afundar)
        border.width: 1
        border.color: botao.cheio ? Qt.rgba(1, 1, 1, janela.escuro ? 0.0 : 0.0)
                                  : (janela.escuro ? Qt.rgba(1, 1, 1, botao.tipo === "numero" ? 0.06 : 0.035) : Qt.rgba(0, 0, 0, botao.tipo === "numero" ? 0.075 : 0.05))
        Behavior on color {
            enabled: botao.afundar === 0
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }

        // A linha de baixo das teclas claras, como a sombrinha das teclas do Windows 11.
        Rectangle {
            visible: !janela.escuro && !botao.cheio
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            height: 1
            color: Qt.rgba(0, 0, 0, 0.06)
        }

        Item {
            id: miolo
            anchors.fill: parent
            opacity: botao.ativo ? 1 - 0.3 * Math.max(0, botao.afundar) : 0.32

            Texto {
                id: letra
                anchors.centerIn: parent
                property real desloca: 0
                anchors.verticalCenterOffset: desloca
                visible: botao.icone.length === 0
                textFormat: Text.PlainText
                text: botao._rotuloVisto
                color: botao.corLetra
                font.pixelSize: Math.max(10, Math.round(Math.min(botao.height * (botao.tipo === "numero" ? 0.36 : 0.31),
                                                                  botao.width * 0.3,
                                                                  janela.gu * (botao.tipo === "numero" ? 1.3 : (botao.tipo === "funcao" ? 1.0 : 1.25)))))
                font.weight: botao.tipo === "numero" || botao.cheio ? Font.DemiBold : Font.Normal
                font.features: { "tnum": 1 }
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                visible: botao.icone.length > 0
                width: Math.round(Math.min(botao.height * 0.4, janela.gu * 1.15))
                height: width
                source: botao.icone
                isMask: true
                color: botao.corLetra
            }
            Texto {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: Math.round(janela.gu * 0.3)
                anchors.topMargin: Math.round(janela.gu * 0.15)
                visible: botao.contador > 0
                text: botao.contador
                color: botao.corLetra
                opacity: 0.65
                font.pixelSize: Math.round(janela.gu * 0.62)
            }
        }
    }

    // Rótulo novo (tecla 2ª): o velho sobe sumindo, o novo vem de baixo.
    property string _rotuloVisto: ""
    Component.onCompleted: _rotuloVisto = rotulo
    onRotuloChanged: {
        if (_rotuloVisto === "")
            _rotuloVisto = rotulo;
        else if (rotulo !== _rotuloVisto)
            troca.restart();
    }
    SequentialAnimation {
        id: troca
        ParallelAnimation {
            NumberAnimation { target: letra; property: "opacity"; to: 0; duration: 90 }
            NumberAnimation { target: letra; property: "desloca"; to: -janela.gu * 0.4; duration: 90; easing.type: Easing.InQuad }
        }
        ScriptAction { script: botao._rotuloVisto = botao.rotulo }
        PropertyAction { target: letra; property: "desloca"; value: janela.gu * 0.4 }
        ParallelAnimation {
            NumberAnimation { target: letra; property: "opacity"; to: 1; duration: 150 }
            NumberAnimation { target: letra; property: "desloca"; to: 0; duration: 220; easing.type: Easing.OutBack }
        }
    }

    QQC2.ToolTip.visible: dica.length > 0 && containsMouse && !pressed
    QQC2.ToolTip.text: dica
    QQC2.ToolTip.delay: 700
}
