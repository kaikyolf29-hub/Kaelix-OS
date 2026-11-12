// A capa bem desfocada, como fundo (Tocando agora e o topo do álbum): só as cores
// dela, em manchas suaves. A imagem é lida bem pequena (64 px) e borrada pelo
// MultiEffect, o que é leve. Ao trocar de música, a cor nova entra aos poucos.
import QtQuick
import QtQuick.Effects

Item {
    id: fundo

    property string caminho: ""
    property string nome: ""
    property real saturacao: 0.15

    readonly property var paletas: [["#F7A3C4", "#B9467F"], ["#B9A0FF", "#6A49DD"], ["#71E0D2", "#1E8F86"],
                                    ["#FFC98A", "#E2832A"], ["#9AA8FF", "#4A55C9"], ["#FF9AA8", "#D2405F"],
                                    ["#A7DB8E", "#3F8F45"]]
    readonly property var paleta: {
        var h = 0, s = nome || "";
        for (var i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 9973;
        return paletas[h % paletas.length];
    }
    property string mostrado: caminho
    onCaminhoChanged: troca.restart()
    clip: true

    SequentialAnimation {
        id: troca
        NumberAnimation { target: camada; property: "opacity"; to: 0.25; duration: 180 }
        PropertyAction { target: fundo; property: "mostrado"; value: fundo.caminho }
        NumberAnimation { target: camada; property: "opacity"; to: 1; duration: 520; easing.type: Easing.OutCubic }
    }

    Item {
        id: camada
        anchors.fill: parent

        // Sem capa: o degradê da mesma cor do lugar da capa.
        Rectangle {
            anchors.fill: parent
            visible: imagem.status !== Image.Ready
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: fundo.paleta[0] }
                GradientStop { position: 1; color: fundo.paleta[1] }
            }
        }
        Image {
            id: imagem
            anchors.centerIn: parent
            width: Math.max(parent.width, parent.height) * 1.3
            height: width
            visible: false
            source: janela.arquivo(fundo.mostrado)
            sourceSize.width: 64
            sourceSize.height: 64
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }
        MultiEffect {
            anchors.fill: imagem
            visible: imagem.status === Image.Ready
            source: imagem
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            blurMultiplier: 1.5
            saturation: fundo.saturacao
        }
    }
}
