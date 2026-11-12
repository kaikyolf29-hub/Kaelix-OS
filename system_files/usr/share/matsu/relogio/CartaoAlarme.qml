// Cartão de um alarme (como no Relógio do Windows 11): a hora grande, quanto falta
// ("Toca em 7 h 12 min"), o nome, as bolinhas dos dias (S T Q Q S S D) e a chave.
// Desligado, fica apagado. Clicar abre o editor; o botão direito abre o menu.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: cartao

    property var alarme: ({ id: "", nome: "", hora: 0, minuto: 0, dias: [], ligado: false, data: "" })

    signal editar()
    signal ligar(bool sim)
    signal menu(real x, real y)

    readonly property var quando: janela.proximoToque(alarme, janela.agora)
    readonly property string horaTexto: janela.hhmm(alarme.hora, alarme.minuto)

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: horaTexto + (alarme.nome ? ", " + alarme.nome : "") + ", " + janela.resumoDias(alarme.dias)
                     + ", " + (alarme.ligado ? janela.t("ligado", "on") : janela.t("desligado", "off"))
    Accessible.description: janela.t("Abrir para editar", "Open to edit")
    onClicked: (m) => {
        if (m.button === Qt.RightButton)
            cartao.menu(m.x, m.y);
        else
            cartao.editar();
    }
    Keys.onReturnPressed: cartao.editar()
    Keys.onSpacePressed: cartao.ligar(!alarme.ligado)
    Keys.onDeletePressed: cartao.menu(width / 2, height / 2)

    Rectangle {
        id: fundo
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.6)
        color: janela.cartao
        border.width: 1
        border.color: cartao.activeFocus ? janela.destaque : janela.bordaCartao
        scale: cartao.pressed ? 0.985 : 1
        Behavior on scale {
            NumberAnimation {
                duration: 140
            }
        }
        // O claro de passar o mouse por cima.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: janela.tinta(cartao.pressed ? 0.06 : 0.035)
            opacity: cartao.containsMouse ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 1.0)
        anchors.rightMargin: Math.round(janela.gu * 0.9)
        anchors.topMargin: Math.round(janela.gu * 0.7)
        anchors.bottomMargin: Math.round(janela.gu * 0.8)
        spacing: Math.round(janela.gu * 0.15)

        RowLayout {
            Layout.fillWidth: true
            spacing: janela.gu * 0.5
            NumeroRolante {
                texto: cartao.horaTexto
                font.pixelSize: Math.round(janela.gu * 2.5)
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                opacity: cartao.alarme.ligado ? 1 : 0.42
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Chave {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: Math.round(janela.gu * 0.35)
                ligada: cartao.alarme.ligado
                nome: janela.t("Alarme das ", "Alarm at ") + cartao.horaTexto
                onTrocada: (l) => cartao.ligar(l)
            }
        }
        // Quanto falta (só ligado).
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.35)
            opacity: cartao.alarme.ligado ? 0.75 : 0.45
            Kirigami.Icon {
                implicitWidth: Math.round(Kirigami.Units.iconSizes.small * 0.85)
                implicitHeight: implicitWidth
                source: cartao.alarme.ligado ? "matsu-sino-symbolic" : "matsu-sino-silencio-symbolic"
                isMask: true
                color: janela.frente
            }
            Texto {
                Layout.fillWidth: true
                text: cartao.quando ? janela.t("Toca em ", "Rings in ") + janela.textoFalta(cartao.quando - janela.agora)
                                    : janela.t("Desligado", "Off")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.features: { "tnum": 1 }
                elide: Text.ElideRight
            }
        }
        Texto {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.2)
            text: cartao.alarme.nome || janela.t("Alarme", "Alarm")
            font.weight: Font.DemiBold
            opacity: cartao.alarme.ligado ? 1 : 0.55
            elide: Text.ElideRight
        }
        Item {
            Layout.fillHeight: true
        }
        // Os dias: bolinhas S T Q Q S S D (cheia = toca nesse dia). Só uma vez: o dia.
        Row {
            visible: cartao.alarme.dias.length > 0
            spacing: Math.round(janela.gu * 0.22)
            opacity: cartao.alarme.ligado ? 1 : 0.55
            Repeater {
                model: 7
                Rectangle {
                    id: bolinha
                    required property int index
                    readonly property bool escolhido: cartao.alarme.dias.indexOf(index) >= 0
                    readonly property bool hoje: janela.diaDaSemana(janela.agora) === index
                    width: Math.round(janela.gu * 1.3)
                    height: width
                    radius: width / 2
                    color: escolhido ? janela.tinta(janela.escuro ? 0.16 : 0.1) : "transparent"
                    border.width: hoje ? 1 : 0
                    border.color: janela.tinta(0.35)
                    Accessible.ignored: true
                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.longDuration
                        }
                    }
                    Texto {
                        anchors.centerIn: parent
                        text: janela.letrasDias[bolinha.index]
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.weight: bolinha.escolhido ? Font.DemiBold : Font.Normal
                        opacity: bolinha.escolhido ? 1 : 0.4
                    }
                }
            }
        }
        Texto {
            visible: cartao.alarme.dias.length === 0
            Layout.fillWidth: true
            text: janela.t("Só uma vez", "Once") + (cartao.quando ? " · " + janela.quandoDia(cartao.quando, janela.agora) : "")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.62
            elide: Text.ElideRight
        }
    }
}
