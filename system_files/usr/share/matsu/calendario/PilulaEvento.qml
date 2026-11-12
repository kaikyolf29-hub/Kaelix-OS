// Um evento pequeno na grade do Mês: o de dia todo é uma pílula cheia na cor dele
// (bem de leve); o com hora é a bolinha da cor, a hora e o título. Entra deslizando
// de leve. Clicar abre o editor; arrastar leva para outro dia (quem cuida é a grade).
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

MouseArea {
    id: pilula

    property var o: null
    property string chaveDia: ""
    property int ordem: 0
    // Dia todo que vem do dia anterior / segue no próximo: a pílula encosta na borda.
    property bool continuaAntes: false
    property bool continuaDepois: false
    // Quem arrasta (a grade do Mês): comecar(pilula, ponto), mover(ponto), soltar().
    property var grade: null

    readonly property bool diaTodo: o ? o.diaTodo : false
    readonly property string corId: o ? (o.ev.cor || "salvia") : "salvia"
    property bool arrastando: false
    property point inicioToque

    implicitHeight: Math.round(janela.gu * 1.05)
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: arrastando ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    preventStealing: true

    onPressed: (m) => {
        inicioToque = Qt.point(m.x, m.y);
        arrastando = false;
    }
    onPositionChanged: (m) => {
        if (!pressed || !grade || pressedButtons !== Qt.LeftButton)
            return;
        if (!arrastando && Math.abs(m.x - inicioToque.x) + Math.abs(m.y - inicioToque.y) > 6) {
            arrastando = true;
            grade.comecar(pilula);
        }
        if (arrastando)
            grade.mover(pilula.mapToItem(grade, m.x, m.y));
    }
    onReleased: (m) => {
        if (arrastando) {
            arrastando = false;
            grade.soltar();
        } else if (m.button === Qt.RightButton) {
            janela.abrirMenuEvento(pilula, m.x, m.y, o.ev, o.chave);
        } else if (containsMouse) {
            janela.editarEvento(o.ev, o.chave);
        }
    }
    onCanceled: {
        if (arrastando) {
            arrastando = false;
            grade.cancelar();
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: o ? o.ev.titulo : ""

    // Entra deslizando, um pouco depois da anterior.
    opacity: 0
    Component.onCompleted: entrada.start()
    SequentialAnimation {
        id: entrada
        PauseAnimation { duration: Math.min(pilula.ordem, 6) * 30 }
        ParallelAnimation {
            NumberAnimation { target: pilula; property: "opacity"; from: 0; to: 1; duration: 220 }
            NumberAnimation { target: desloca; property: "x"; from: -8; to: 0; duration: 320; easing.type: Easing.OutCubic }
        }
    }

    transform: Translate {
        id: desloca
    }

    Rectangle {
        id: fundo
        anchors.fill: parent
        readonly property real r: Math.round(janela.gu * 0.3)
        topLeftRadius: pilula.continuaAntes ? 0 : r
        bottomLeftRadius: pilula.continuaAntes ? 0 : r
        topRightRadius: pilula.continuaDepois ? 0 : r
        bottomRightRadius: pilula.continuaDepois ? 0 : r
        color: pilula.diaTodo ? janela.fundoEvento(pilula.corId, pilula.containsMouse) : janela.tinta(pilula.containsMouse ? 0.07 : 0)
        opacity: pilula.arrastando ? 0.35 : 1
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Math.round(janela.gu * (pilula.diaTodo ? 0.4 : 0.3))
            anchors.right: parent.right
            anchors.rightMargin: Math.round(janela.gu * 0.25)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(janela.gu * 0.3)
            visible: pilula.mostrarTitulo

            Rectangle {
                visible: !pilula.diaTodo
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(janela.gu * 0.42)
                height: width
                radius: width / 2
                color: janela.cor(pilula.corId)
            }
            Texto {
                id: textoHora
                visible: !pilula.diaTodo && pilula.width > janela.gu * 5
                anchors.verticalCenter: parent.verticalCenter
                text: pilula.o && !pilula.diaTodo ? Datas.hora(pilula.o.inicio) : ""
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.features: { "tnum": 1 }
                opacity: 0.6
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x
                text: pilula.o ? (pilula.o.ev.titulo || janela.t("Sem título", "Untitled")) : ""
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: pilula.diaTodo ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }
        }
    }
    // Num evento de vários dias, o título aparece no primeiro dia e no domingo.
    property bool mostrarTitulo: true

    QQC2.ToolTip.visible: containsMouse && !arrastando && o !== null
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    QQC2.ToolTip.text: o ? (o.ev.titulo || janela.t("Sem título", "Untitled")) + "\n" + janela.faixaHoras(o) + (o.ev.local ? " · " + o.ev.local : "") : ""
}
