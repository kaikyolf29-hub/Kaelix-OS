// "Tamanho do texto e dos apps", como no Mac: uma fileira de telinhas, de
// "Texto maior" (a escala mais alta) até "Mais espaço" (a mais baixa). Cada
// telinha tem uma janela desenhada com o texto mais ou menos grande, e embaixo
// a frase "Parece com 1920 × 1080" (o tamanho que os apps enxergam).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: bloco

    property var escalas: []
    property real atual: 1
    // O modo da tela (largura e altura de verdade) e se ela está girada.
    property int largura: 1920
    property int altura: 1080
    property bool girada: false
    readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property int gu: Kirigami.Units.gridUnit
    readonly property int folga: Math.round(gu * 0.8)

    signal escolhida(real escala)

    // Da maior para a menor: "Texto maior" fica à esquerda.
    readonly property var ordem: escalas.slice().sort(function (a, b) { return b - a; })
    property real olhando: -1
    readonly property real mostrada: olhando > 0 ? olhando : atual

    function pareceCom(escala) {
        var w = girada ? altura : largura;
        var h = girada ? largura : altura;
        return Math.round(w / escala) + " × " + Math.round(h / escala);
    }
    function igual(a, b) {
        return Math.abs(a - b) < 0.001;
    }

    Layout.fillWidth: true
    spacing: Math.round(gu * 0.5)

    // Risco fino em cima, como entre as outras linhas do cartão.
    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: bloco.folga
        Layout.rightMargin: bloco.folga
        implicitHeight: 1
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.leftMargin: bloco.folga
        Layout.rightMargin: bloco.folga
        Layout.topMargin: Math.round(bloco.gu * 0.3)
        text: ajustes.t("Tamanho do texto e dos apps", "Text and app size")
    }

    RowLayout {
        id: fileira
        Layout.fillWidth: true
        Layout.leftMargin: bloco.folga
        Layout.rightMargin: bloco.folga
        spacing: Math.round(bloco.gu * 0.6)

        readonly property real cada: bloco.ordem.length > 0
            ? Math.min(bloco.gu * 6.5, (width - spacing * (bloco.ordem.length - 1)) / bloco.ordem.length) : 0

        Repeater {
            model: bloco.ordem

            Miniatura {
                id: mini

                required property real modelData
                required property int index
                // 1 na escala mais alta (texto maior), 0 na mais baixa.
                readonly property real f: bloco.ordem.length > 1 ? (modelData - bloco.ordem[bloco.ordem.length - 1])
                                                                   / (bloco.ordem[0] - bloco.ordem[bloco.ordem.length - 1]) : 0.5

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                largura: fileira.cada
                proporcao: 10 / 16
                nome: Math.round(modelData * 100) + "%"
                escolhida: bloco.igual(modelData, bloco.atual)
                Accessible.name: ajustes.t("Escala de ", "Scale ") + Math.round(modelData * 100) + "%, "
                                 + ajustes.t("parece com ", "looks like ") + bloco.pareceCom(modelData)
                onClicked: if (!escolhida) bloco.escolhida(modelData)
                onContainsMouseChanged: {
                    if (containsMouse)
                        bloco.olhando = modelData;
                    else if (bloco.igual(bloco.olhando, modelData))
                        bloco.olhando = -1;
                }

                // A área de trabalho em miniatura, cinza neutro.
                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(bloco.gu * 0.3)
                    gradient: Gradient {
                        GradientStop { position: 0; color: bloco.escuro ? "#4a4a50" : "#d6d6db" }
                        GradientStop { position: 1; color: bloco.escuro ? "#2c2c31" : "#b9b9c0" }
                    }
                }

                // A janela: maior e com o texto maior quanto maior a escala.
                Rectangle {
                    id: janelinha
                    readonly property real u: parent.height
                    x: Math.round(parent.width * (0.16 - 0.1 * mini.f))
                    y: Math.round(u * (0.14 - 0.08 * mini.f))
                    width: Math.round(parent.width * (0.56 + 0.3 * mini.f))
                    height: Math.round(u * (0.5 + 0.26 * mini.f))
                    radius: Math.max(2, Math.round(u * 0.06))
                    color: bloco.escuro ? "#1f1f22" : "#fbfbfc"
                    border.width: 1
                    border.color: bloco.escuro ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.1)

                    readonly property real letra: Math.max(5, u * (0.13 + 0.13 * mini.f))

                    Row {
                        x: Math.round(janelinha.letra * 0.4)
                        y: Math.round(janelinha.letra * 0.35)
                        spacing: Math.max(1.5, janelinha.letra * 0.18)
                        Repeater {
                            model: 3
                            Rectangle {
                                width: Math.max(2.5, janelinha.letra * 0.26)
                                height: width
                                radius: width / 2
                                color: bloco.escuro ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.22)
                            }
                        }
                    }
                    Text {
                        id: aa
                        x: Math.round(janelinha.letra * 0.4)
                        y: Math.round(janelinha.letra * 0.75)
                        text: "Aa"
                        color: Kirigami.Theme.textColor
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pixelSize: Math.round(janelinha.letra * 1.15)
                        font.weight: Font.DemiBold
                        renderType: Text.QtRendering
                    }
                    Column {
                        x: aa.x
                        y: aa.y + aa.height + Math.max(1, janelinha.letra * 0.1)
                        spacing: Math.max(1.5, janelinha.letra * 0.22)
                        Repeater {
                            model: [0.62, 0.48, 0.55]
                            Rectangle {
                                required property real modelData
                                width: (janelinha.width - aa.x * 2) * modelData
                                height: Math.max(1.5, janelinha.letra * 0.2)
                                radius: height / 2
                                color: bloco.escuro ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.16)
                            }
                        }
                    }
                }

                // A barra do Matsu embaixo, também do tamanho da escala.
                Rectangle {
                    readonly property real h: Math.max(3, parent.height * (0.07 + 0.05 * mini.f))
                    width: parent.width * (0.42 + 0.14 * mini.f)
                    height: h
                    radius: h / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.max(2, parent.height * 0.05)
                    color: bloco.escuro ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.75)
                    border.width: 1
                    border.color: bloco.escuro ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.06)
                }
            }
        }
    }

    // "Texto maior" ... "Parece com 1920 × 1080" ... "Mais espaço"
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: bloco.folga
        Layout.rightMargin: bloco.folga
        Layout.bottomMargin: Math.round(bloco.gu * 0.6)
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.preferredWidth: 1
            Layout.fillWidth: true
            text: ajustes.t("Texto maior", "Larger text")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
            opacity: 0.55
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            Layout.preferredWidth: 2
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: ajustes.t("Parece com ", "Looks like ") + bloco.pareceCom(bloco.mostrada)
            font.features: ({ "tnum": 1 })
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            Layout.preferredWidth: 1
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: ajustes.t("Mais espaço", "More space")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
            opacity: 0.55
            elide: Text.ElideRight
        }
    }
}
