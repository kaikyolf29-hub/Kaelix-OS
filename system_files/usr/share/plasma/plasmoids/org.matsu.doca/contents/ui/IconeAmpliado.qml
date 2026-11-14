// Um app na janela da ampliação: o ícone do tamanho que a conta da lupa deu,
// o pulo de quando está abrindo, o pontinho de aberto e o balão com o nome
// (só no app com o mouse em cima).
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: amp

    property var doca
    // O número do app na fileira (a lixeira é o último).
    property int numero: 0
    // A janela da ampliação: quanto sobra para os lados, a espessura dela e o comprimento.
    property real sobra: 0
    property real fundo: 0
    property real eixoTotal: 0
    property var icone
    property string nome
    property bool aberto: false
    property bool ativo: false
    property bool pedindo: false
    property bool comecando: false

    anchors.fill: parent

    readonly property int pedaco: doca.indiceDoPedaco(numero)
    readonly property real inicio: sobra + doca.inicioFileira + (doca.arranjo.inicio[pedaco] !== undefined ? doca.arranjo.inicio[pedaco] : 0)
    readonly property real tamanho: doca.arranjo.tamanho[pedaco] !== undefined ? doca.arranjo.tamanho[pedaco] : doca.celula
    readonly property real escala: doca.arranjo.escala[pedaco] !== undefined ? doca.arranjo.escala[pedaco] : 1
    readonly property real lado: doca.tamanhoIcone * escala
    // O ícone é desenhado uma vez no tamanho maior e encolhido (assim a
    // animação não redesenha o ícone a cada quadro).
    readonly property real ladoMaior: Math.round(doca.tamanhoIcone * Math.max(1, doca.maximo))

    // O pulo de quando o app está abrindo, para dentro da tela.
    property real pulo: 0
    SequentialAnimation {
        id: pular
        running: amp.comecando
        loops: Animation.Infinite
        NumberAnimation { target: amp; property: "pulo"; to: amp.doca.celula * 0.42; duration: 190; easing.type: Easing.OutQuad }
        NumberAnimation { target: amp; property: "pulo"; to: 0; duration: 190; easing.type: Easing.InQuad }
        PauseAnimation { duration: 90 }
        onStopped: voltar.restart()
    }
    NumberAnimation {
        id: voltar
        target: amp
        property: "pulo"
        to: 0
        duration: 160
        easing.type: Easing.OutQuad
    }

    Item {
        id: lugar
        readonly property rect r: amp.doca.caixa(amp.inicio + (amp.tamanho - amp.lado) / 2, amp.doca.margemIcone + amp.pulo,
                                                 amp.lado, amp.lado, amp.eixoTotal, amp.fundo)
        x: r.x
        y: r.y
        width: r.width
        height: r.height

        Kirigami.Icon {
            anchors.centerIn: parent
            width: amp.ladoMaior
            height: amp.ladoMaior
            scale: amp.ladoMaior > 0 ? lugar.width / amp.ladoMaior : 1
            source: amp.icone
            roundToIconSize: false
            smooth: true
        }
    }

    Indicador {
        doca: amp.doca
        centro: amp.inicio + amp.tamanho / 2
        total: amp.eixoTotal
        fundo: amp.fundo
        aberto: amp.aberto
        ativo: amp.ativo
        pedindo: amp.pedindo
    }

    // O balão com o nome, no jeito do vidro do Matsu, depois do ícone ampliado.
    Rectangle {
        id: balao
        readonly property bool mostrar: amp.doca.apontado === amp.numero && amp.nome.length > 0
        readonly property real distancia: amp.doca.margemIcone + amp.lado + amp.pulo + Kirigami.Units.gridUnit * 0.55
        readonly property real largura: Math.round(texto.width + Kirigami.Units.gridUnit * 1.3)
        readonly property real altura: Math.round(texto.implicitHeight + Kirigami.Units.gridUnit * 0.55)
        // Ao longo do eixo: centrado no app (na doca do lado, centrado na altura).
        readonly property real meio: amp.inicio + amp.tamanho / 2
        readonly property rect r: amp.doca.vertical
            ? amp.doca.caixa(meio - altura / 2, distancia, altura, largura, amp.eixoTotal, amp.fundo)
            : amp.doca.caixa(meio - largura / 2, distancia, largura, altura, amp.eixoTotal, amp.fundo)

        x: Math.round(r.x)
        y: Math.round(r.y)
        width: amp.doca.vertical ? Math.round(r.width) : largura
        height: amp.doca.vertical ? Math.round(r.height) : altura
        radius: Math.round(Kirigami.Units.gridUnit * 0.45)
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14)
        opacity: mostrar ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: balao.mostrar ? 120 : 80 }
        }

        PlasmaComponents.Label {
            id: texto
            anchors.centerIn: parent
            // Nomes muito compridos terminam em "…" (o balão cabe na janela da doca).
            width: Math.min(implicitWidth, Kirigami.Units.gridUnit * 11)
            elide: Text.ElideRight
            text: amp.nome
            textFormat: Text.PlainText
            font.weight: Font.Medium
            color: Kirigami.Theme.textColor
        }
    }
}
