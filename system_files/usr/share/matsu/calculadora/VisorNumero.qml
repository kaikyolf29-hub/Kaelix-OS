// O número grande do visor, com os algarismos que rolam (o NumeroRolante de
// ../comum, mas cada casa fica viva quando o número muda de tamanho: no
// NumeroRolante o Repeater de "texto.length" refaz tudo e os algarismos só
// aparecem, sem rolar, quando o número cresce ou encolhe; aqui as casas são
// contadas da direita, numa ListModel, e só as que sobram entram ou saem).
//   rolar: true   cada algarismo rola até o novo (resultado, conta parcial)
//   rolar: false  troca na hora e o último algarismo pula de baixo (digitando)
// Use mostrar(texto, rolar) para trocar os dois juntos.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: visor

    property string texto: "0"
    property font fonte: Kirigami.Theme.defaultFont
    property color cor: janela.frente
    property bool rolar: true
    property int duracao: 480

    signal cresceu()

    readonly property real altura: medida.height

    implicitWidth: linha.implicitWidth
    implicitHeight: altura
    Accessible.role: Accessible.StaticText
    Accessible.name: texto

    TextMetrics {
        id: medida
        font: visor.fonte
        text: "0"
    }

    ListModel {
        id: casas
    }

    function mostrar(t, r) {
        rolar = r;
        texto = t;
    }

    function sincronizar() {
        var n = texto.length;
        var maior = n >= casas.count;
        for (var i = 0; i < n; i++) {
            var ch = texto.charAt(n - 1 - i);
            if (i < casas.count) {
                if (casas.get(i).ch !== ch)
                    casas.setProperty(i, "ch", ch);
            } else {
                casas.append({ ch: ch });
            }
        }
        if (casas.count > n)
            casas.remove(n, casas.count - n);
        if (!rolar && maior)
            cresceu();
    }
    onTextoChanged: sincronizar()
    Component.onCompleted: sincronizar()

    Row {
        id: linha
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        layoutDirection: Qt.RightToLeft

        Repeater {
            model: casas

            Item {
                id: casa
                required property string ch
                required property int index
                readonly property bool algarismo: ch >= "0" && ch <= "9"
                readonly property int alvo: algarismo ? ch.charCodeAt(0) - 48 : 0
                // Algarismo novo rola desde o 0 (quando o visor está rolando).
                property bool chegou: false

                width: algarismo ? medida.advanceWidth : soletra.implicitWidth
                height: visor.altura
                clip: true
                transform: Translate {
                    id: desloca
                }

                Column {
                    id: fita
                    visible: casa.algarismo
                    y: casa.chegou ? -casa.alvo * visor.altura : 0
                    Behavior on y {
                        enabled: visor.rolar
                        NumberAnimation {
                            duration: visor.duracao
                            easing.type: Easing.OutCubic
                        }
                    }
                    Repeater {
                        model: 10
                        Text {
                            required property int index
                            width: medida.advanceWidth
                            height: visor.altura
                            horizontalAlignment: Text.AlignHCenter
                            text: index
                            font: visor.fonte
                            color: visor.cor
                        }
                    }
                }
                Text {
                    id: soletra
                    visible: !casa.algarismo
                    anchors.verticalCenter: parent.verticalCenter
                    text: casa.ch
                    font: visor.fonte
                    color: visor.cor
                }

                Component.onCompleted: {
                    chegou = true;
                    if (visor.rolar)
                        entrada.start();
                }
                NumberAnimation {
                    id: entrada
                    target: casa
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: visor.duracao * 0.6
                }
                Connections {
                    target: visor
                    function onCresceu() {
                        if (casa.index === 0)
                            pulo.restart();
                    }
                }
                ParallelAnimation {
                    id: pulo
                    NumberAnimation { target: desloca; property: "y"; from: visor.altura * 0.32; to: 0; duration: 230; easing.type: Easing.OutCubic }
                    NumberAnimation { target: casa; property: "opacity"; from: 0.15; to: 1; duration: 170 }
                }
            }
        }
    }
}
