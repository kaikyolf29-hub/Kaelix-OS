// A capa de uma playlist: as capas de até quatro álbuns dela, em mosaico (uma só,
// se tiver menos de quatro; o degradê com o ícone, se estiver vazia).
import QtQuick
import QtQuick.Effects

Item {
    id: mosaico

    property var musicas: []
    property string nome: ""
    property real raio: Math.round(janela.gu * 0.6)
    property real sombra: 0

    readonly property var capas: {
        var r = [];
        for (var i = 0; i < musicas.length && r.length < 4; i++)
            if (musicas[i].capa && r.indexOf(musicas[i].capa) < 0)
                r.push(musicas[i].capa);
        return r;
    }

    RectangularShadow {
        anchors.fill: parent
        visible: mosaico.sombra > 0
        radius: mosaico.raio
        offset.y: Math.round(janela.gu * 0.4 * mosaico.sombra)
        blur: Math.round(janela.gu * 1.2)
        spread: -Math.round(janela.gu * 0.2)
        color: Qt.rgba(0, 0, 0, (janela.escuro ? 0.55 : 0.32) * mosaico.sombra)
    }
    Capa {
        anchors.fill: parent
        visible: mosaico.capas.length < 4
        caminho: mosaico.capas.length > 0 ? mosaico.capas[0] : ""
        nome: mosaico.nome
        iconeVazio: "playlist"
        raio: mosaico.raio
    }
    Item {
        id: quatro
        anchors.fill: parent
        visible: mosaico.capas.length >= 4
        layer.enabled: visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mascara
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        Grid {
            anchors.fill: parent
            columns: 2
            Repeater {
                model: quatro.visible ? mosaico.capas : []
                Image {
                    required property string modelData
                    width: quatro.width / 2
                    height: quatro.height / 2
                    source: janela.arquivo(modelData)
                    sourceSize.width: Math.ceil(width * 2)
                    sourceSize.height: Math.ceil(height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }
            }
        }
    }
    Rectangle {
        id: mascara
        anchors.fill: parent
        visible: false
        layer.enabled: true
        radius: mosaico.raio
        color: "white"
    }
}
