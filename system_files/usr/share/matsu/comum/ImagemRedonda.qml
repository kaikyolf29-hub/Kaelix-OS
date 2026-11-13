// Imagem com os cantos arredondados (capas e fundos dos jogos), com sombra
// opcional e, se pedir, sumindo aos poucos embaixo (para o fundo de um jogo
// virar o vidro da janela). Sem a imagem, fica vazia (quem usa desenha por baixo).
// Com "aparecer", a imagem surge aos poucos quando acaba de carregar.
import QtQuick
import QtQuick.Effects

Item {
    id: caixa

    property alias source: imagem.source
    property alias fillMode: imagem.fillMode
    property alias status: imagem.status
    property alias horizontalAlignment: imagem.horizontalAlignment
    property alias verticalAlignment: imagem.verticalAlignment
    property real raio: Math.round(janela.gu * 0.5)
    property real raioEmCima: raio
    property real raioEmBaixo: raio
    // Sombra embaixo, de 0 a 1 (as capas ganham mais com o mouse em cima).
    property real sombra: 0
    // Quanto da altura, embaixo, vai sumindo até ficar transparente (0: nada).
    property real esmaecer: 0
    // A imagem aparece com um fade (e um zoom bem leve) quando fica pronta.
    property bool aparecer: false

    readonly property bool pronta: imagem.status === Image.Ready
    property real _vista: !aparecer || pronta ? 1 : 0
    Behavior on _vista {
        enabled: caixa.aparecer
        NumberAnimation {
            duration: 380
            easing.type: Easing.OutCubic
        }
    }

    // Sombra embaixo (desenhada pelo Qt, sem copiar a imagem).
    RectangularShadow {
        anchors.fill: parent
        visible: caixa.pronta && caixa.sombra > 0 && caixa.esmaecer === 0
        opacity: caixa._vista
        radius: caixa.raioEmBaixo
        offset.y: Math.round(janela.gu * 0.45 * caixa.sombra)
        blur: Math.round(janela.gu * 1.1)
        spread: -Math.round(janela.gu * 0.15)
        color: Qt.rgba(0, 0, 0, 0.55 * caixa.sombra)
    }

    Image {
        id: imagem
        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
    }
    Rectangle {
        id: mascara
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        topLeftRadius: caixa.raioEmCima
        topRightRadius: caixa.raioEmCima
        bottomLeftRadius: caixa.raioEmBaixo
        bottomRightRadius: caixa.raioEmBaixo
        gradient: Gradient {
            GradientStop { position: 0; color: "#ffffffff" }
            GradientStop { position: Math.max(0.001, 1 - caixa.esmaecer); color: "#ffffffff" }
            GradientStop { position: 1; color: caixa.esmaecer > 0 ? "#00ffffff" : "#ffffffff" }
        }
    }
    MultiEffect {
        anchors.fill: parent
        visible: caixa.pronta
        opacity: caixa._vista
        scale: caixa.aparecer ? 1.03 - 0.03 * caixa._vista : 1
        autoPaddingEnabled: false
        source: imagem
        maskEnabled: true
        maskSource: mascara
        // Com 0,5 e 1, a máscara vira smoothstep(0, 1, alfa): borda lisa nos
        // cantos e, no esmaecer, a transparência acompanhando o degradê.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
