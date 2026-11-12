// Campo de hora do editor (24 h): dá para digitar ("930" vira 09:30), usar as setas
// (de 15 em 15 minutos) ou escolher na lista que abre embaixo. No campo do fim, a
// lista mostra quanto dura ("10:00 · 1 h").
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

Rectangle {
    id: campo

    property int minutos: 9 * 60
    // Começo do evento, para mostrar a duração na lista (-1: não mostra).
    property int referencia: -1
    property string nome: ""
    signal mudou(int minutos)

    function ler(texto) {
        var s = String(texto).replace(/[^0-9:h]/g, "").replace("h", ":");
        var h, m;
        if (s.indexOf(":") >= 0) {
            var p = s.split(":");
            h = Number(p[0] || 0);
            m = Number(p[1] || 0);
        } else if (s.length <= 2) {
            h = Number(s);
            m = 0;
        } else {
            h = Number(s.slice(0, s.length - 2));
            m = Number(s.slice(-2));
        }
        if (isNaN(h) || isNaN(m) || h > 23 || m > 59)
            return -1;
        return h * 60 + m;
    }
    function duracao(m) {
        var d = m - referencia;
        if (d <= 0)
            return "";
        if (d < 60)
            return d + " min";
        var h = Math.floor(d / 60), r = d % 60;
        return r === 0 ? h + " h" : h + " h " + r + (janela.pt ? "" : "m");
    }
    function confirmar() {
        var m = ler(entrada.text);
        if (m >= 0 && m !== minutos)
            campo.mudou(m);
        entrada.text = Datas.deMinutos(m >= 0 ? m : minutos);
    }

    implicitWidth: Math.round(janela.gu * 4.8)
    implicitHeight: Math.round(janela.gu * 2.1)
    radius: Math.round(janela.gu * 0.4)
    color: janela.tinta(entrada.activeFocus ? (janela.escuro ? 0.08 : 0.03) : (area.containsMouse ? 0.07 : (janela.escuro ? 0.05 : 0.04)))
    border.width: entrada.activeFocus || lista.opened ? 1.5 : 1
    border.color: entrada.activeFocus || lista.opened ? janela.destaque : janela.tinta(janela.escuro ? 0.09 : 0.12)
    Behavior on color {
        ColorAnimation {
            duration: Kirigami.Units.shortDuration
        }
    }
    onMinutosChanged: if (!entrada.activeFocus) entrada.text = Datas.deMinutos(minutos)

    MouseArea {
        id: area
        z: 1
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Clicar: foca (o texto fica selecionado para digitar por cima) e abre a lista.
        onClicked: {
            entrada.forceActiveFocus();
            entrada.selectAll();
            if (lista.opened)
                lista.close();
            else
                lista.open();
        }
    }
    TextInput {
        id: entrada
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 0.5)
        anchors.rightMargin: Math.round(janela.gu * 0.5)
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        text: Datas.deMinutos(campo.minutos)
        color: janela.frente
        selectionColor: janela.destaque
        selectedTextColor: janela.sobreDestaque
        font.family: Kirigami.Theme.defaultFont.family
        font.pointSize: Kirigami.Theme.defaultFont.pointSize
        font.features: { "tnum": 1 }
        maximumLength: 5
        selectByMouse: true
        inputMethodHints: Qt.ImhTime
        Accessible.name: campo.nome
        onActiveFocusChanged: if (activeFocus) selectAll(); else campo.confirmar()
        onAccepted: {
            campo.confirmar();
            lista.close();
        }
        Keys.onUpPressed: campo.mudou(Math.min(23 * 60 + 45, Math.floor(campo.minutos / 15) * 15 + 15))
        Keys.onDownPressed: campo.mudou(Math.max(0, Math.ceil(campo.minutos / 15) * 15 - 15))
        Keys.onEscapePressed: (e) => {
            if (lista.opened) {
                lista.close();
            } else {
                e.accepted = false;
            }
        }
    }
    WheelHandler {
        onWheel: (w) => campo.mudou(Math.max(0, Math.min(23 * 60 + 45, (Math.round(campo.minutos / 15) + (w.angleDelta.y > 0 ? 1 : -1)) * 15)))
    }

    QQC2.Popup {
        id: lista
        y: campo.height + 4
        width: Math.max(campo.width, Math.round(janela.gu * (campo.referencia >= 0 ? 8 : 5.5)))
        height: Math.round(janela.gu * 12)
        padding: 4
        transformOrigin: QQC2.Popup.Top
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
        onOpened: vista.positionViewAtIndex(Math.max(0, Math.round(campo.minutos / 15) - 3), ListView.Beginning)
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 220; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 110 }
        }
        background: FundoBalao {}
        contentItem: ListView {
            id: vista
            clip: true
            model: 96
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: BarraRolagem {}
            delegate: MouseArea {
                id: opcao
                required property int index
                readonly property int valor: index * 15
                readonly property bool escolhida: valor === campo.minutos
                width: vista.width
                height: Math.round(janela.gu * 1.75)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    campo.mudou(valor);
                    entrada.text = Datas.deMinutos(valor);
                    lista.close();
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(janela.gu * 0.3)
                    color: janela.tinta(opcao.containsMouse ? 0.08 : (opcao.escolhida ? 0.06 : 0))
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round(janela.gu * 0.6)
                    spacing: Math.round(janela.gu * 0.4)
                    Texto {
                        text: Datas.deMinutos(opcao.valor)
                        font.features: { "tnum": 1 }
                        font.weight: opcao.escolhida ? Font.DemiBold : Font.Normal
                    }
                    Texto {
                        visible: text.length > 0
                        text: campo.referencia >= 0 ? campo.duracao(opcao.valor) : ""
                        opacity: 0.5
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
