// Campo de data do editor: mostra "qui., 12 de nov." e, ao clicar, abre um
// mini-calendário num balão (com a pílula no dia escolhido).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

MouseArea {
    id: campo

    property var dia: Datas.hoje()
    property string nome: ""
    signal mudou(var dia)

    implicitWidth: Math.max(Math.round(janela.gu * 8.5), linha.implicitWidth + Math.round(janela.gu * 1.4))
    implicitHeight: Math.round(janela.gu * 2.1)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: nome
    Accessible.description: rotulo.text
    onClicked: balao.opened ? balao.close() : balao.open()
    Keys.onSpacePressed: balao.open()
    Keys.onReturnPressed: balao.open()

    Rectangle {
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.4)
        color: janela.tinta(campo.pressed ? 0.1 : (campo.containsMouse || balao.opened ? 0.075 : (janela.escuro ? 0.05 : 0.04)))
        border.width: 1
        border.color: campo.activeFocus || balao.opened ? janela.destaque : janela.tinta(janela.escuro ? 0.09 : 0.12)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }
    RowLayout {
        id: linha
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 0.6)
        anchors.rightMargin: Math.round(janela.gu * 0.6)
        spacing: Math.round(janela.gu * 0.45)
        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: "matsu-calendario-symbolic"
            isMask: true
            color: janela.frente
            opacity: 0.7
        }
        Texto {
            id: rotulo
            Layout.fillWidth: true
            text: Datas.dataCurtaAno(campo.dia, janela.pt)
            elide: Text.ElideRight
        }
    }

    QQC2.Popup {
        id: balao
        y: campo.height + 4
        width: Math.round(janela.gu * 14)
        padding: Math.round(janela.gu * 0.6)
        focus: true
        transformOrigin: QQC2.Popup.Top
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
        property var mes: Datas.inicioMes(campo.dia)
        onAboutToShow: mes = Datas.inicioMes(campo.dia)
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
        contentItem: MiniCalendario {
            mes: balao.mes
            escolhido: campo.dia
            onMudarMes: (m) => balao.mes = m
            onEscolher: (d) => {
                campo.mudou(d);
                fechar.restart();
            }
        }
        // Fecha um instante depois, para ver a pílula chegar no dia.
        Timer {
            id: fechar
            interval: 260
            onTriggered: balao.close()
        }
    }
}
