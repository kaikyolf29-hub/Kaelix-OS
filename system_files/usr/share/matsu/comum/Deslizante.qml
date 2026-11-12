// Controle deslizante: trilho em pílula, a parte cheia na cor de destaque e a
// bolinha, que cresce com o mouse em cima. Ao arrastar, um balão mostra o valor.
// O valor muda sozinho; movido(v) avisa durante o arraste e solto(v) no fim.
//   Deslizante { de: 0; ate: 100; valor: volume; onMovido: (v) => mudarVolume(v) }
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: deslizante

    property real valor: 0
    property real de: 0
    property real ate: 100
    property real passo: 1
    property string nome: ""
    property bool ativo: true
    property bool mostrarBalao: true
    // Como o valor aparece no balão.
    property var formato: function (v) {
        return janela.num(v, passo < 1 ? 1 : 0);
    }

    signal movido(real valor)
    signal solto(real valor)

    readonly property real fracao: ate > de ? Math.max(0, Math.min(1, (valor - de) / (ate - de))) : 0
    readonly property bool arrastando: area.pressed
    readonly property int bola: Math.round(janela.gu * (area.pressed ? 1.15 : (area.containsMouse || foco.activeFocus ? 1.0 : 0.85)))

    function ajustar(v) {
        var p = passo > 0 ? Math.round((v - de) / passo) * passo + de : v;
        return Math.max(de, Math.min(ate, Math.round(p * 1e6) / 1e6));
    }
    function irPara(v, fim) {
        var novo = ajustar(v);
        if (novo !== valor) {
            valor = novo;
            movido(novo);
        }
        if (fim)
            solto(valor);
    }

    implicitWidth: Math.round(janela.gu * 12)
    implicitHeight: Math.round(janela.gu * 1.6)
    opacity: ativo ? 1 : 0.45

    Item {
        id: foco
        anchors.fill: parent
        activeFocusOnTab: deslizante.ativo
        Accessible.role: Accessible.Slider
        Accessible.name: deslizante.nome
        Accessible.description: deslizante.formato(deslizante.valor)
        Keys.onLeftPressed: deslizante.irPara(deslizante.valor - Math.max(deslizante.passo, (deslizante.ate - deslizante.de) / 50), true)
        Keys.onDownPressed: deslizante.irPara(deslizante.valor - Math.max(deslizante.passo, (deslizante.ate - deslizante.de) / 50), true)
        Keys.onRightPressed: deslizante.irPara(deslizante.valor + Math.max(deslizante.passo, (deslizante.ate - deslizante.de) / 50), true)
        Keys.onUpPressed: deslizante.irPara(deslizante.valor + Math.max(deslizante.passo, (deslizante.ate - deslizante.de) / 50), true)
    }

    // O trilho e a parte cheia.
    Rectangle {
        id: trilho
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round(janela.gu * 0.6)
        width: parent.width - 2 * x
        height: Math.round(janela.gu * (area.pressed || area.containsMouse ? 0.36 : 0.3))
        radius: height / 2
        color: janela.tinta(janela.escuro ? 0.14 : 0.12)
        Behavior on height {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        Rectangle {
            height: parent.height
            radius: parent.radius
            width: Math.max(height, bolinha.x + bolinha.width / 2 - trilho.x)
            color: janela.destaque
        }
    }

    Rectangle {
        id: bolinha
        readonly property real alvo: trilho.x + deslizante.fracao * trilho.width - width / 2
        x: alvo
        anchors.verticalCenter: parent.verticalCenter
        width: deslizante.bola
        height: width
        radius: width / 2
        color: janela.escuro ? "#f4f4f6" : "#ffffff"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, janela.escuro ? 0.3 : 0.14)
        Behavior on x {
            enabled: !area.pressed
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutBack
            }
        }
        // Sombra suave embaixo da bolinha.
        Rectangle {
            z: -1
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1.5
            width: parent.width + 3
            height: width
            radius: width / 2
            color: Qt.rgba(0, 0, 0, janela.escuro ? 0.35 : 0.12)
        }
        // Ponto da cor de destaque no meio da bolinha.
        Rectangle {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.32)
            height: width
            radius: width / 2
            color: janela.destaque
            opacity: area.pressed ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
    }

    // Balão com o valor, em cima da bolinha, enquanto arrasta.
    Rectangle {
        id: balao
        visible: deslizante.mostrarBalao && opacity > 0
        opacity: area.pressed ? 1 : 0
        scale: area.pressed ? 1 : 0.6
        transformOrigin: Item.Bottom
        anchors.bottom: bolinha.top
        anchors.bottomMargin: Math.round(janela.gu * 0.35)
        x: Math.round(bolinha.x + bolinha.width / 2 - width / 2)
        width: textoBalao.implicitWidth + Math.round(janela.gu * 0.9)
        height: Math.round(janela.gu * 1.5)
        radius: height / 2
        color: janela.frente
        z: 5
        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
            }
        }
        Texto {
            id: textoBalao
            anchors.centerIn: parent
            text: deslizante.formato(deslizante.valor)
            color: janela.escuro ? "#1a1a1e" : "#ffffff"
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: deslizante.ativo
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function valorEm(px) {
            return deslizante.de + Math.max(0, Math.min(1, (px - trilho.x) / trilho.width)) * (deslizante.ate - deslizante.de);
        }
        onPressed: (m) => { foco.forceActiveFocus(); deslizante.irPara(valorEm(m.x), false); }
        onPositionChanged: (m) => { if (pressed) deslizante.irPara(valorEm(m.x), false); }
        onReleased: deslizante.solto(deslizante.valor)
        onWheel: (r) => deslizante.irPara(deslizante.valor + (r.angleDelta.y > 0 ? 1 : -1) * Math.max(deslizante.passo, (deslizante.ate - deslizante.de) / 50), true)
    }
}
