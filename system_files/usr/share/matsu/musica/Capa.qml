// A capa de uma música ou de um álbum: a imagem com os cantos redondos (decodificada
// só no tamanho que aparece) e, sem imagem, um degradê da paleta do Matsu com a nota.
// A cor do degradê vem do nome, então cada álbum sem capa tem sempre a mesma.
//   Capa { caminho: album.capa; nome: album.nome; raio: janela.gu * 0.5; sombra: 0.6 }
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: capa

    property string caminho: ""
    property string nome: ""
    property real raio: Math.round(janela.gu * 0.4)
    property real sombra: 0
    property bool redonda: false
    property string iconeVazio: "nota"

    readonly property real r: redonda ? width / 2 : raio
    readonly property bool pronta: imagem.status === Image.Ready
    readonly property var paletas: [["#F7A3C4", "#B9467F"], ["#B9A0FF", "#6A49DD"], ["#71E0D2", "#1E8F86"],
                                    ["#FFC98A", "#E2832A"], ["#9AA8FF", "#4A55C9"], ["#FF9AA8", "#D2405F"],
                                    ["#A7DB8E", "#3F8F45"]]
    readonly property var paleta: {
        var h = 0, s = nome || "";
        for (var i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 9973;
        return paletas[h % paletas.length];
    }

    // Sombra embaixo (só quando pedida).
    RectangularShadow {
        anchors.fill: parent
        visible: capa.sombra > 0
        radius: capa.r
        offset.y: Math.round(janela.gu * 0.4 * capa.sombra)
        blur: Math.round(janela.gu * 1.2)
        spread: -Math.round(janela.gu * 0.2)
        color: Qt.rgba(0, 0, 0, (janela.escuro ? 0.55 : 0.32) * capa.sombra)
    }

    // Sem capa: o degradê com a nota.
    Rectangle {
        anchors.fill: parent
        visible: !capa.pronta
        radius: capa.r
        gradient: Gradient {
            GradientStop { position: 0; color: capa.paleta[0] }
            GradientStop { position: 1; color: capa.paleta[1] }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(Math.min(parent.width, parent.height) * 0.42)
            height: width
            source: janela.ic(capa.iconeVazio)
            isMask: true
            color: "#F4F6FF"
            opacity: 0.92
        }
    }

    Image {
        id: imagem
        anchors.fill: parent
        visible: false
        source: janela.arquivo(capa.caminho)
        sourceSize.width: Math.min(1024, Math.ceil(capa.width * 2))
        sourceSize.height: Math.min(1024, Math.ceil(capa.height * 2))
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
        radius: capa.r
        color: "white"
    }
    MultiEffect {
        anchors.fill: parent
        visible: capa.pronta
        autoPaddingEnabled: false
        source: imagem
        maskEnabled: true
        maskSource: mascara
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        opacity: capa.pronta ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
    }
    // Linha bem fina na borda: a capa não "vaza" no fundo de mesma cor.
    Rectangle {
        anchors.fill: parent
        radius: capa.r
        color: "transparent"
        border.width: 1
        border.color: janela.escuro ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06)
    }
}
