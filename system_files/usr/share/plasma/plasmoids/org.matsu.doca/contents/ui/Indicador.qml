// O ponto embaixo de um app aberto, como na doca do Mac (no Mac é a opção
// "Mostrar indicadores de apps abertos"), no jeito do Matsu: um ponto redondo
// na cor do texto, perto da borda da tela. Ele nasce crescendo quando o app
// abre e some encolhendo quando fecha. O app em uso fica com o ponto mais forte
// e um brilho suave em volta (no Mac todos são iguais; aqui dá para saber qual
// está na frente sem virar o traço do Windows). O app que pede atenção pisca
// em laranja. Com a ampliação, o ponto não cresce junto com o ícone.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: ponto

    property var doca
    // O centro do app no eixo e o tamanho do lugar onde o ponto é desenhado.
    property real centro: 0
    property real total: 0
    property real fundo: 0
    property bool aberto: false
    property bool ativo: false
    property bool pedindo: false

    // Uns 4 px numa doca média, maior junto com a doca.
    readonly property real lado: Math.max(4, Math.round(doca.tamanhoIcone * 0.11))
    readonly property rect r: doca.caixa(centro - lado / 2, Math.max(1, Math.round((doca.margemIcone - lado) / 2)), lado, lado, total, fundo)
    readonly property color cor: pedindo ? "#ff9f43" : Kirigami.Theme.textColor

    visible: Plasmoid.configuration.indicadores !== false
    x: Math.round(r.x)
    y: Math.round(r.y)
    width: lado
    height: lado

    // O brilho do app em uso.
    Rectangle {
        anchors.centerIn: parent
        width: Math.round(ponto.lado * 2.6)
        height: width
        radius: width / 2
        color: ponto.cor
        opacity: ponto.aberto && ponto.ativo && !ponto.pedindo ? 0.16 : 0
        Behavior on opacity {
            NumberAnimation { duration: 220 }
        }
    }

    Rectangle {
        id: bolinha
        anchors.fill: parent
        radius: width / 2
        color: ponto.cor
        opacity: !ponto.aberto ? 0 : (ponto.pedindo ? piscar.valor : (ponto.ativo ? 1 : 0.6))
        scale: ponto.aberto ? 1 : 0.2
        Behavior on opacity {
            enabled: !ponto.pedindo
            NumberAnimation { duration: 220 }
        }
        Behavior on scale {
            NumberAnimation { duration: 280; easing.type: Easing.OutBack }
        }
        Behavior on color {
            ColorAnimation { duration: 200 }
        }
    }

    QtObject {
        id: piscar
        property real valor: 1
    }
    SequentialAnimation {
        running: ponto.pedindo && ponto.aberto && ponto.visible
        loops: Animation.Infinite
        NumberAnimation { target: piscar; property: "valor"; to: 0.35; duration: 520; easing.type: Easing.InOutSine }
        NumberAnimation { target: piscar; property: "valor"; to: 1; duration: 520; easing.type: Easing.InOutSine }
        onStopped: piscar.valor = 1
    }
}
