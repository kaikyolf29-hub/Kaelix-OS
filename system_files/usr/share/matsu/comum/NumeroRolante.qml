// Número que rola: cada algarismo é uma fita de 0 a 9 que sobe ou desce até o novo
// valor (como no contador do vídeo de referência e nos relógios de aeroporto).
// O que não é algarismo (vírgula, "R$", ":") fica parado. Cresce para a esquerda.
//   NumeroRolante { texto: janela.num(total, 2); font.pixelSize: janela.gu * 2.4 }
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: rolante

    property string texto: "0"
    property font font: Kirigami.Theme.defaultFont
    property color cor: janela.frente
    property int duracao: 520

    readonly property real altura: medida.height

    implicitWidth: linha.implicitWidth
    implicitHeight: altura
    Accessible.role: Accessible.StaticText
    Accessible.name: texto

    TextMetrics {
        id: medida
        font: rolante.font
        text: "0"
    }

    Row {
        id: linha
        anchors.right: parent.right
        layoutDirection: Qt.RightToLeft

        Repeater {
            model: rolante.texto.length

            Item {
                id: casa
                required property int index
                // A casa 0 é o último caractere (direita): o número cresce para a esquerda.
                readonly property string ch: rolante.texto.charAt(rolante.texto.length - 1 - index)
                readonly property bool algarismo: ch >= "0" && ch <= "9"
                readonly property int alvo: algarismo ? Number(ch) : 0

                width: algarismo ? medida.advanceWidth : soletra.implicitWidth
                height: rolante.altura
                clip: true

                Column {
                    id: fita
                    visible: casa.algarismo
                    y: -casa.alvo * rolante.altura
                    Behavior on y {
                        NumberAnimation {
                            duration: rolante.duracao
                            easing.type: Easing.OutCubic
                        }
                    }
                    Repeater {
                        model: 10
                        Text {
                            required property int index
                            width: medida.advanceWidth
                            height: rolante.altura
                            horizontalAlignment: Text.AlignHCenter
                            text: index
                            font: rolante.font
                            color: rolante.cor
                        }
                    }
                }
                Text {
                    id: soletra
                    visible: !casa.algarismo
                    anchors.verticalCenter: parent.verticalCenter
                    text: casa.ch
                    font: rolante.font
                    color: rolante.cor
                }
                // Algarismo novo (o número ganhou uma casa) entra de baixo, aparecendo.
                Component.onCompleted: entrada.start()
                NumberAnimation {
                    id: entrada
                    target: casa
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: rolante.duracao
                }
            }
        }
    }
}
