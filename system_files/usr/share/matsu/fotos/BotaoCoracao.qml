// O coração das favoritas: ao favoritar ele pula (cresce e volta com mola), solta
// um anel e umas faíscas no rosa do Matsu, como o "curtir" dos apps de foto.
// "claro": em cima de foto ou do fundo escuro do visualizador (contorno branco).
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

MouseArea {
    id: botao

    property bool ligado: false
    property bool mostrar: true
    property bool claro: false
    property bool comFundo: claro
    property real lado: Math.round(janela.gu * 1.75)

    signal clicado()

    implicitWidth: lado
    implicitHeight: lado
    width: lado
    height: lado
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    opacity: mostrar ? 1 : 0
    enabled: mostrar
    Accessible.role: Accessible.CheckBox
    Accessible.checked: ligado
    Accessible.name: ligado ? janela.t("Tirar das favoritas", "Remove from favorites") : janela.t("Favoritar", "Add to favorites")
    onClicked: botao.clicado()
    onLigadoChanged: {
        if (ligado) {
            pulo.restart();
            faiscas.restart();
        } else {
            murcha.restart();
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: botao.comFundo
        color: Qt.rgba(0, 0, 0, botao.pressed ? 0.45 : (botao.containsMouse ? 0.36 : 0.22))
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: !botao.comFundo
        color: botao.claro ? Qt.rgba(1, 1, 1, botao.pressed ? 0.16 : (botao.containsMouse ? 0.1 : 0))
                           : janela.tinta(botao.pressed ? 0.1 : (botao.containsMouse ? 0.065 : 0))
    }

    // O anel que se abre ao favoritar.
    Rectangle {
        id: anel
        anchors.centerIn: parent
        width: botao.lado * 0.7
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: janela.corCoracao
        opacity: 0
    }
    // As faíscas: seis pontinhos que saem do meio.
    Repeater {
        id: pontos
        model: 6
        Rectangle {
            required property int index
            property real distancia: 0
            readonly property real angulo: index * Math.PI / 3 - Math.PI / 2
            width: 3
            height: 3
            radius: 1.5
            color: index % 2 === 0 ? janela.corCoracao : "#ffb3cb"
            x: botao.width / 2 - 1.5 + Math.cos(angulo) * distancia
            y: botao.height / 2 - 1.5 + Math.sin(angulo) * distancia
            opacity: 0
        }
    }

    Kirigami.Icon {
        id: simbolo
        anchors.centerIn: parent
        width: Math.round(botao.lado * 0.56)
        height: width
        source: botao.ligado ? String(Qt.resolvedUrl("icones/coracao-cheio.svg")) : "matsu-coracao-symbolic"
        isMask: true
        color: botao.ligado ? janela.corCoracao : (botao.claro ? "#ffffff" : janela.frente)
    }

    SequentialAnimation {
        id: pulo
        NumberAnimation { target: simbolo; property: "scale"; from: 0.6; to: 1.32; duration: 170; easing.type: Easing.OutQuad }
        NumberAnimation { target: simbolo; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
    }
    SequentialAnimation {
        id: murcha
        NumberAnimation { target: simbolo; property: "scale"; from: 1; to: 0.78; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: simbolo; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack }
    }
    ParallelAnimation {
        id: faiscas
        NumberAnimation { target: anel; property: "scale"; from: 0.5; to: 1.55; duration: 420; easing.type: Easing.OutCubic }
        NumberAnimation { target: anel; property: "opacity"; from: 0.9; to: 0; duration: 420; easing.type: Easing.OutQuad }
        ScriptAction {
            script: {
                for (var i = 0; i < pontos.count; i++)
                    voo.createObject(botao, { alvo: pontos.itemAt(i) }).start();
            }
        }
    }
    Component {
        id: voo
        ParallelAnimation {
            id: animacao
            property Item alvo
            NumberAnimation { target: animacao.alvo; property: "distancia"; from: botao.lado * 0.25; to: botao.lado * 0.62; duration: 460; easing.type: Easing.OutCubic }
            SequentialAnimation {
                NumberAnimation { target: animacao.alvo; property: "opacity"; from: 0; to: 1; duration: 80 }
                NumberAnimation { target: animacao.alvo; property: "opacity"; to: 0; duration: 380; easing.type: Easing.InQuad }
            }
            onFinished: animacao.destroy()
        }
    }

    QQC2.ToolTip.visible: containsMouse && mostrar
    QQC2.ToolTip.text: Accessible.name
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
