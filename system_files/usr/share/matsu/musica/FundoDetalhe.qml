// O fundo do topo de um álbum, artista ou playlist: as cores da capa, desfocadas e
// bem de leve, sumindo para baixo. Acompanha a rolagem da lista (yRolagem).
import QtQuick
import QtQuick.Effects

Item {
    id: fundo

    property string caminho: ""
    property string nome: ""
    property real yRolagem: 0

    clip: true
    FundoCapa {
        id: cores
        y: -fundo.yRolagem
        width: parent.width
        height: Math.round(janela.gu * 18)
        caminho: fundo.caminho
        nome: fundo.nome
        opacity: janela.escuro ? 0.32 : 0.38
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: degrade
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }
    Rectangle {
        id: degrade
        width: cores.width
        height: cores.height
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0; color: "#ffffffff" }
            GradientStop { position: 0.45; color: "#bbffffff" }
            GradientStop { position: 1; color: "#00ffffff" }
        }
    }
}
