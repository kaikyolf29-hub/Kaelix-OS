// O mini-calendário, como o cartão do vídeo de referência: o mês com as setinhas,
// as iniciais dos dias (D S T Q Q S S), a pílula cheia no dia escolhido (que desliza
// de um dia para o outro), o dia de hoje marcado de leve e um pontinho nos dias com
// evento. O mês troca deslizando. Usado na lateral e para escolher datas no editor.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

ColumnLayout {
    id: mini

    property var mes: Datas.inicioMes(new Date())
    property var escolhido: null
    // { "2026-11-12": true } — os dias que ganham o pontinho.
    property var marcas: ({})
    readonly property real lado: Math.floor(width / 7)

    signal escolher(var dia)
    signal mudarMes(var novo)

    spacing: Math.round(janela.gu * 0.25)

    RowLayout {
        Layout.fillWidth: true
        spacing: 0
        Texto {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(janela.gu * 0.3)
            text: janela.pt ? Datas.MESES[mini.mes.getMonth()].charAt(0).toUpperCase() + Datas.MESES[mini.mes.getMonth()].slice(1) + " " + mini.mes.getFullYear()
                            : Datas.MESES_EN[mini.mes.getMonth()] + " " + mini.mes.getFullYear()
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        BotaoRedondo {
            tamanho: Math.round(janela.gu * 1.5)
            icone: "matsu-voltar-symbolic"
            dica: janela.t("Mês anterior", "Previous month")
            onClicado: mini.mudarMes(Datas.somarMeses(mini.mes, -1))
        }
        BotaoRedondo {
            tamanho: Math.round(janela.gu * 1.5)
            icone: "matsu-seta-symbolic"
            dica: janela.t("Próximo mês", "Next month")
            onClicado: mini.mudarMes(Datas.somarMeses(mini.mes, 1))
        }
    }
    Row {
        Layout.fillWidth: true
        Repeater {
            model: 7
            Texto {
                required property int index
                width: mini.lado
                horizontalAlignment: Text.AlignHCenter
                text: janela.pt ? Datas.INICIAIS[index] : Datas.INICIAIS_EN[index]
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                opacity: 0.45
            }
        }
    }
    Carrossel {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(mini.lado * 0.92) * 6
        valor: mini.mes
        componente: Component {
            Item {
                id: gm
                property var periodo: mini.mes
                readonly property var inicio: Datas.inicioSemana(Datas.inicioMes(periodo))
                readonly property real alto: height / 6
                readonly property int indice: {
                    if (!mini.escolhido)
                        return -1;
                    var n = Datas.diasEntre(inicio, mini.escolhido);
                    return n >= 0 && n < 42 && mini.escolhido.getMonth() === periodo.getMonth() ? n : -1;
                }
                readonly property real circulo: Math.min(mini.lado, alto) - 3

                Rectangle {
                    id: pilula
                    readonly property Item alvo: gm.indice >= 0 && dias.count > gm.indice ? dias.itemAt(gm.indice) : null
                    property bool pronta: false
                    visible: alvo !== null
                    x: alvo ? alvo.x + (alvo.width - width) / 2 : 0
                    y: alvo ? alvo.y + (alvo.height - height) / 2 : 0
                    width: gm.circulo
                    height: width
                    radius: width / 2
                    color: janela.destaque
                    Behavior on x {
                        enabled: pilula.pronta
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        enabled: pilula.pronta
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }
                    onAlvoChanged: {
                        if (alvo && pronta)
                            pulo.restart();
                        if (!alvo)
                            pronta = false;
                        else
                            Qt.callLater(function () { pilula.pronta = true; });
                    }
                    SequentialAnimation {
                        id: pulo
                        NumberAnimation { target: pilula; property: "scale"; to: 0.8; duration: 90 }
                        NumberAnimation { target: pilula; property: "scale"; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                    }
                }

                Repeater {
                    id: dias
                    model: 42
                    MouseArea {
                        id: dia
                        required property int index
                        readonly property var quando: Datas.somarDias(gm.inicio, index)
                        readonly property bool doMes: quando.getMonth() === gm.periodo.getMonth()
                        readonly property bool hoje: Datas.mesmoDia(quando, janela.hojeAgora)
                        readonly property bool escolhido: index === gm.indice
                        x: (index % 7) * mini.lado
                        y: Math.floor(index / 7) * gm.alto
                        width: mini.lado
                        height: gm.alto
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mini.escolher(quando)
                        Accessible.role: Accessible.Button
                        Accessible.name: Datas.dataLonga(quando, janela.pt)

                        Rectangle {
                            anchors.centerIn: parent
                            width: gm.circulo
                            height: width
                            radius: width / 2
                            color: janela.tinta(dia.hoje && !dia.escolhido ? (janela.escuro ? 0.14 : 0.1) : (dia.containsMouse && !dia.escolhido ? 0.06 : 0))
                            Behavior on color {
                                ColorAnimation {
                                    duration: Kirigami.Units.shortDuration
                                }
                            }
                        }
                        Texto {
                            anchors.centerIn: parent
                            text: dia.quando.getDate()
                            color: dia.escolhido ? janela.sobreDestaque : janela.frente
                            opacity: dia.escolhido ? 1 : (dia.doMes ? 0.9 : 0.3)
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.weight: dia.hoje || dia.escolhido ? Font.Bold : Font.Normal
                            font.features: { "tnum": 1 }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }
                        }
                        Rectangle {
                            visible: !!mini.marcas[Datas.chave(dia.quando)] && dia.doMes
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height / 2 + gm.circulo / 2 - height - 1
                            width: 3
                            height: 3
                            radius: 1.5
                            color: dia.escolhido ? janela.sobreDestaque : janela.frente
                            opacity: dia.escolhido ? 0.8 : 0.45
                        }
                    }
                }
            }
        }
    }
}
