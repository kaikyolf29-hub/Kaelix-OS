// Cronômetro: o tempo grande (horas, minutos e segundos rolam; os centésimos são
// texto comum com números de largura fixa, para não tremer), tocar/pausar, volta e
// zerar. As voltas entram por cima; a mais rápida e a mais lenta ganham uma marca
// discreta. Continua contando com o app fechado. Atalhos: Espaço, V (volta), Z (zerar).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    opacity: 0
    transform: Translate { id: desliza; y: janela.gu * 0.6 }
    Component.onCompleted: entrada.start()
    ParallelAnimation {
        id: entrada
        NumberAnimation { target: pagina; property: "opacity"; to: 1; duration: 220 }
        NumberAnimation { target: desliza; property: "y"; to: 0; duration: 380; easing.type: Easing.OutCubic }
    }

    property real tempo: janela.cronoTempo()
    Timer {
        interval: 16
        repeat: true
        running: janela.cronoRodando
        onTriggered: pagina.tempo = janela.cronoTempo()
    }
    Connections {
        target: janela
        function onCronoRodandoChanged() { pagina.tempo = janela.cronoTempo(); }
        function onCronoAcumuladoChanged() { pagina.tempo = janela.cronoTempo(); }
    }
    readonly property var partes: janela.cronoTexto(tempo)
    readonly property bool temVoltas: janela.voltas.count > 0

    // A mais rápida e a mais lenta (com duas voltas ou mais).
    readonly property var extremos: {
        var n = janela.voltas.count, rapida = -1, lenta = -1, min = Infinity, max = -1;
        if (n < 2)
            return { rapida: -1, lenta: -1 };
        for (var i = 0; i < n; i++) {
            var v = janela.voltas.get(i);
            if (v.volta < min) { min = v.volta; rapida = v.n; }
            if (v.volta > max) { max = v.volta; lenta = v.n; }
        }
        return { rapida: rapida, lenta: lenta };
    }
    function textoVolta(ms) {
        var p = janela.cronoTexto(ms);
        var principal = ms >= 3600000 ? p.principal : p.principal.substring(3);
        return principal + p.centesimos;
    }

    Shortcut { sequences: ["Space"]; onActivated: janela.cronoAlternar() }
    Shortcut { sequences: ["V", "L"]; enabled: janela.cronoRodando; onActivated: janela.cronoVolta() }
    Shortcut { sequences: ["Z", "R"]; enabled: !janela.cronoRodando; onActivated: janela.cronoZerar() }
    Connections {
        target: janela
        function onNovo() { janela.cronoAlternar(); }
    }

    Cabecalho {
        id: cabecalho
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(janela.gu * 1.4)
        anchors.rightMargin: Math.round(janela.gu * 1.4)
        anchors.topMargin: Math.round(janela.gu * 0.6)
        titulo: janela.t("Cronômetro", "Stopwatch")
    }

    // O mostrador: no meio sem voltas; sobe quando a primeira volta entra.
    Item {
        id: mostrador
        anchors.left: parent.left
        anchors.right: parent.right
        height: colunaTempo.implicitHeight
        y: pagina.temVoltas ? cabecalho.y + cabecalho.height + janela.gu * 0.6
                            : Math.max(cabecalho.y + cabecalho.height, (pagina.height - height) / 2 - janela.gu)
        Behavior on y {
            NumberAnimation {
                duration: 480
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: colunaTempo
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(janela.gu * 1.2)

            Row {
                id: linhaTempo
                Layout.alignment: Qt.AlignHCenter
                readonly property real tamanho: Math.round(Math.min(janela.gu * 4.6, pagina.width / 9.5))
                Accessible.role: Accessible.StaticText
                Accessible.name: pagina.partes.principal + pagina.partes.centesimos
                NumeroRolante {
                    anchors.bottom: parent.bottom
                    texto: pagina.partes.principal
                    duracao: 360
                    font.pixelSize: linhaTempo.tamanho
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Text {
                    anchors.baseline: parent.bottom
                    anchors.baselineOffset: -linhaTempo.tamanho * 0.235
                    text: pagina.partes.centesimos
                    color: janela.frente
                    opacity: 0.55
                    font.family: Kirigami.Theme.defaultFont.family
                    font.pixelSize: linhaTempo.tamanho
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
            // "h  min  s" embaixo, bem fraquinho.
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -Math.round(janela.gu * 1.1)
                spacing: 0
                Repeater {
                    model: [janela.t("h", "hr"), "min", "s", ""]
                    Texto {
                        required property string modelData
                        width: linhaTempo.tamanho * 1.5
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.45
                    }
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Math.round(janela.gu * 1.2)
                BotaoRedondo {
                    anchors.verticalCenter: parent.verticalCenter
                    icone: Qt.resolvedUrl("icones/bandeira.svg")
                    dica: janela.t("Volta (V)", "Lap (L)")
                    ativo: janela.cronoRodando
                    onClicado: janela.cronoVolta()
                }
                BotaoRedondo {
                    anchors.verticalCenter: parent.verticalCenter
                    principal: true
                    tamanho: Math.round(janela.gu * 3.2)
                    icone: janela.cronoRodando ? Qt.resolvedUrl("icones/pausa.svg") : "matsu-jogar-symbolic"
                    dica: janela.cronoRodando ? janela.t("Pausar (Espaço)", "Pause (Space)") : janela.t("Começar (Espaço)", "Start (Space)")
                    onClicado: janela.cronoAlternar()
                }
                BotaoRedondo {
                    anchors.verticalCenter: parent.verticalCenter
                    icone: Qt.resolvedUrl("icones/zerar.svg")
                    dica: janela.t("Zerar (Z)", "Reset (R)")
                    ativo: !janela.cronoRodando && pagina.tempo > 0
                    onClicado: janela.cronoZerar()
                }
            }
        }
    }

    // As voltas.
    Rectangle {
        id: cartaoVoltas
        anchors.top: mostrador.bottom
        anchors.topMargin: Math.round(janela.gu * 1.2)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(janela.gu * 1.2)
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - janela.gu * 2.8, janela.gu * 30)
        radius: Math.round(janela.gu * 0.6)
        color: janela.cartao
        border.width: 1
        border.color: janela.bordaCartao
        opacity: pagina.temVoltas ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 320
            }
        }

        readonly property real colVolta: width * 0.3
        readonly property real colTempo: width * 0.35

        // Títulos das colunas.
        Item {
            id: titulos
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.round(janela.gu * 2.1)
            Repeater {
                model: [janela.t("Volta", "Lap"), janela.t("Tempo da volta", "Lap time"), janela.t("Total", "Total")]
                Texto {
                    required property string modelData
                    required property int index
                    x: index === 0 ? janela.gu : (index === 1 ? cartaoVoltas.colVolta : cartaoVoltas.colVolta + cartaoVoltas.colTempo)
                    width: index === 0 ? cartaoVoltas.colVolta - janela.gu : (index === 1 ? cartaoVoltas.colTempo : cartaoVoltas.width - x - janela.gu)
                    horizontalAlignment: index === 2 ? Text.AlignRight : Text.AlignLeft
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.55
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: janela.tinta(0.07)
            }
        }

        ListView {
            id: listaVoltas
            anchors.top: titulos.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            clip: true
            model: janela.voltas
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: BarraRolagem {}

            // A volta que está correndo agora, em cima.
            header: Item {
                width: listaVoltas.width
                height: janela.cronoRodando || pagina.tempo > 0 ? Math.round(janela.gu * 2.1) : 0
                visible: height > 0
                readonly property real anterior: janela.voltas.count > 0 ? janela.voltas.get(0).total : 0
                Texto {
                    x: janela.gu
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(janela.voltas.count + 1)
                    font.features: { "tnum": 1 }
                    opacity: 0.6
                }
                Texto {
                    x: cartaoVoltas.colVolta
                    anchors.verticalCenter: parent.verticalCenter
                    text: pagina.textoVolta(Math.max(0, pagina.tempo - parent.anterior))
                    font.features: { "tnum": 1 }
                    opacity: 0.6
                }
                Texto {
                    anchors.right: parent.right
                    anchors.rightMargin: janela.gu
                    anchors.verticalCenter: parent.verticalCenter
                    text: pagina.textoVolta(pagina.tempo)
                    font.features: { "tnum": 1 }
                    opacity: 0.6
                }
            }

            delegate: Item {
                id: linha
                required property int index
                required property int n
                required property real volta
                required property real total
                readonly property bool rapida: pagina.extremos.rapida === n
                readonly property bool lenta: pagina.extremos.lenta === n
                width: listaVoltas.width
                height: Math.round(janela.gu * 2.1)
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: janela.gu * 0.6
                    anchors.rightMargin: janela.gu * 0.6
                    height: 1
                    color: janela.tinta(0.05)
                }
                Texto {
                    id: numeroVolta
                    x: janela.gu
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(linha.n)
                    font.features: { "tnum": 1 }
                }
                // Marca discreta: um pontinho de cor suave e o nome.
                Row {
                    anchors.left: numeroVolta.right
                    anchors.leftMargin: Math.round(janela.gu * 0.6)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(janela.gu * 0.3)
                    visible: linha.rapida || linha.lenta
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: linha.rapida ? janela.cores.disco : janela.cores.rede
                        opacity: 0.85
                    }
                    Texto {
                        text: linha.rapida ? janela.t("mais rápida", "fastest") : janela.t("mais lenta", "slowest")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.65
                    }
                }
                Texto {
                    x: cartaoVoltas.colVolta
                    anchors.verticalCenter: parent.verticalCenter
                    text: pagina.textoVolta(linha.volta)
                    font.features: { "tnum": 1 }
                    font.weight: linha.rapida || linha.lenta ? Font.DemiBold : Font.Normal
                }
                Texto {
                    anchors.right: parent.right
                    anchors.rightMargin: janela.gu
                    anchors.verticalCenter: parent.verticalCenter
                    text: pagina.textoVolta(linha.total)
                    font.features: { "tnum": 1 }
                    opacity: 0.8
                }
            }
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260 }
                    NumberAnimation { property: "x"; from: -janela.gu; to: 0; duration: 320; easing.type: Easing.OutCubic }
                }
            }
            displaced: Transition {
                NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutCubic }
            }
        }
    }

    Texto {
        anchors.top: mostrador.bottom
        anchors.topMargin: Math.round(janela.gu * 1.6)
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !pagina.temVoltas
        opacity: janela.cronoRodando ? 0.55 : 0
        text: janela.t("Toque na bandeira (ou V) para marcar uma volta", "Press the flag (or L) to mark a lap")
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }
}
