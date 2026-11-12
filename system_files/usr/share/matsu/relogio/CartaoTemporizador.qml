// Cartão de um temporizador: o nome, o anel que esvazia enquanto o tempo corre, os
// números que rolam no meio e os botões (+1 min, tocar/pausar, zerar). Ao terminar,
// o anel pulsa e o cartão ganha a borda acesa até a pessoa parar.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: cartao

    property var item: ({ id: "", nome: "", total: 60, restante: 60, fim: 0, estado: "parado" })
    property real agoraMs: Date.now()

    signal menu(real x, real y)
    signal editar()
    signal apagar()

    readonly property real restante: janela.restanteAgora(item, agoraMs)
    readonly property bool rodando: item.estado === "rodando"
    readonly property bool terminado: item.estado === "terminado"
    readonly property int segundos: Math.ceil(restante - 0.001)

    function texto(s) {
        var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, ss = s % 60;
        return (item.total >= 3600 ? h + ":" : "") + janela.dois(m) + ":" + janela.dois(ss);
    }
    function totalTexto(s) {
        var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, ss = s % 60;
        var partes = [];
        if (h)
            partes.push(h + " h");
        if (m)
            partes.push(m + " min");
        if (ss)
            partes.push(ss + " s");
        return partes.join(" ");
    }

    hoverEnabled: true
    acceptedButtons: Qt.RightButton
    onClicked: (m) => cartao.menu(m.x, m.y)
    Accessible.role: Accessible.Grouping
    Accessible.name: item.nome + ", " + texto(segundos) + (terminado ? ", " + janela.t("terminou", "done") : "")

    Rectangle {
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.6)
        color: janela.cartao
        border.width: cartao.terminado ? 1.5 : 1
        border.color: cartao.terminado ? janela.cereja : janela.bordaCartao
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: janela.tinta(0.03)
            opacity: cartao.containsMouse ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
        // O brilho que pulsa quando o tempo acaba.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: janela.cereja
            opacity: 0
            SequentialAnimation on opacity {
                running: cartao.terminado
                loops: Animation.Infinite
                NumberAnimation { to: 0.1; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.0; duration: 700; easing.type: Easing.InOutSine }
                onStopped: parent.opacity = 0
            }
        }
    }

    // Nome e os botões de editar e apagar (aparecem com o mouse em cima).
    RowLayout {
        id: topo
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Math.round(janela.gu * 0.55)
        anchors.leftMargin: Math.round(janela.gu * 0.95)
        anchors.rightMargin: Math.round(janela.gu * 0.45)
        spacing: 2
        Texto {
            Layout.fillWidth: true
            text: cartao.item.nome
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Repeater {
            model: [
                { id: "editar", icone: Qt.resolvedUrl("icones/lapis.svg"), dica: janela.t("Editar", "Edit") },
                { id: "apagar", icone: "matsu-fechar-symbolic", dica: janela.t("Apagar", "Delete") }
            ]
            Botao {
                required property var modelData
                icone: modelData.icone
                dica: modelData.dica
                implicitWidth: implicitHeight
                opacity: cartao.containsMouse || activeFocus ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
                onClicado: modelData.id === "apagar" ? cartao.apagar() : cartao.editar()
            }
        }
    }

    Anel {
        id: anel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: topo.bottom
        anchors.topMargin: Math.round(janela.gu * 0.2)
        width: Math.min(Math.round(janela.gu * 7.6), cartao.width - janela.gu * 2)
        height: width
        valor: cartao.terminado ? 1 : (cartao.item.total > 0 ? cartao.restante / cartao.item.total : 0)
        cor: cartao.terminado ? janela.cereja : janela.destaque
        espessura: Math.max(4, Math.round(width * 0.06))
        Item {
            implicitWidth: numeros.implicitWidth
            implicitHeight: numeros.implicitHeight
            NumeroRolante {
                id: numeros
                anchors.centerIn: parent
                texto: cartao.texto(cartao.segundos)
                font.pixelSize: Math.round(anel.width * (cartao.item.total >= 3600 ? 0.17 : 0.21))
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            text: cartao.terminado ? janela.t("Terminou", "Done") : cartao.totalTexto(cartao.item.total)
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.weight: cartao.terminado ? Font.DemiBold : Font.Normal
            color: cartao.terminado ? janela.cereja : janela.frente
            opacity: cartao.terminado ? 1 : 0.6
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(janela.gu * 0.8)
        spacing: Math.round(janela.gu * 0.7)
        BotaoRedondo {
            anchors.verticalCenter: parent.verticalCenter
            icone: "matsu-mais-symbolic"
            dica: janela.t("Mais 1 minuto", "Add 1 minute")
            tamanho: Math.round(janela.gu * 2)
            onClicado: janela.maisUmMinuto(cartao.item.id)
        }
        BotaoRedondo {
            anchors.verticalCenter: parent.verticalCenter
            principal: true
            icone: cartao.terminado ? Qt.resolvedUrl("icones/parar.svg")
                   : (cartao.rodando ? Qt.resolvedUrl("icones/pausa.svg") : "matsu-jogar-symbolic")
            dica: cartao.terminado ? janela.t("Parar", "Stop") : (cartao.rodando ? janela.t("Pausar", "Pause") : janela.t("Começar", "Start"))
            onClicado: {
                if (cartao.terminado)
                    janela.zerarTemporizador(cartao.item.id);
                else if (cartao.rodando)
                    janela.pausarTemporizador(cartao.item.id);
                else
                    janela.iniciarTemporizador(cartao.item.id);
            }
        }
        BotaoRedondo {
            anchors.verticalCenter: parent.verticalCenter
            icone: Qt.resolvedUrl("icones/zerar.svg")
            dica: janela.t("Zerar", "Reset")
            tamanho: Math.round(janela.gu * 2)
            ativo: cartao.item.estado !== "parado" || cartao.item.restante !== cartao.item.total
            onClicado: janela.zerarTemporizador(cartao.item.id)
        }
    }
}
