// Número que rola: cada algarismo é uma fita de 0 a 9 que sobe ou desce até o novo
// valor (como no contador do vídeo de referência e nos relógios de aeroporto).
// O que não é algarismo (vírgula, "R$", ":") fica parado. Cresce para a esquerda:
// quando o número ganha uma casa (9 → 10), a casa nova entra abrindo espaço e
// subindo; quando perde, a que sobra sai descendo e o resto desliza junto, sem
// refazer as outras casas.
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

    // As casas, da direita para a esquerda (a 0 é o último caractere). As que estão
    // saindo ficam no fim da lista até a animação acabar.
    ListModel {
        id: casas
    }
    property bool _pronto: false
    property bool _animar: false

    function _atualizar() {
        var t = texto;
        var n = t.length;
        for (var i = 0; i < n; i++) {
            var ch = t.charAt(n - 1 - i);
            if (i < casas.count) {
                if (casas.get(i).ch !== ch)
                    casas.setProperty(i, "ch", ch);
                if (casas.get(i).saindo)
                    casas.setProperty(i, "saindo", false);
            } else {
                casas.append({ ch: ch, saindo: false });
            }
        }
        var sobrou = false;
        for (var j = n; j < casas.count; j++) {
            if (!casas.get(j).saindo)
                casas.setProperty(j, "saindo", true);
            sobrou = true;
        }
        if (sobrou)
            limpeza.restart();
    }
    onTextoChanged: if (_pronto) _atualizar()
    Component.onCompleted: {
        _atualizar();
        _pronto = true;
        _animar = true;
    }
    // Tira as casas que já saíram (as do fim, marcadas "saindo").
    Timer {
        id: limpeza
        interval: rolante.duracao + 40
        onTriggered: {
            while (casas.count > 0 && casas.get(casas.count - 1).saindo)
                casas.remove(casas.count - 1);
        }
    }

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
            model: casas

            Item {
                id: casa
                required property int index
                required property string ch
                required property bool saindo
                readonly property bool algarismo: ch >= "0" && ch <= "9"
                readonly property int alvo: algarismo ? Number(ch) : 0
                readonly property real larguraCheia: algarismo ? medida.advanceWidth : soletra.implicitWidth
                // 0 a 1: abre espaço e aparece ao entrar; fecha e some ao sair.
                property real fator: 1

                width: larguraCheia * fator
                height: rolante.altura
                opacity: fator
                clip: true

                Item {
                    // A casa entra subindo e sai descendo.
                    x: (casa.width - casa.larguraCheia) / 2
                    y: (1 - casa.fator) * rolante.altura * (casa.saindo ? 0.55 : 0.45)
                    width: casa.larguraCheia
                    height: rolante.altura

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
                }

                Component.onCompleted: {
                    if (rolante._animar) {
                        fator = 0;
                        entrada.start();
                    }
                }
                onSaindoChanged: {
                    if (saindo) {
                        entrada.stop();
                        saida.from = fator;
                        saida.start();
                    } else {
                        saida.stop();
                        entrada.from = fator;
                        entrada.start();
                    }
                }
                NumberAnimation {
                    id: entrada
                    target: casa
                    property: "fator"
                    from: 0
                    to: 1
                    duration: rolante.duracao
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    id: saida
                    target: casa
                    property: "fator"
                    to: 0
                    duration: Math.round(rolante.duracao * 0.75)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
