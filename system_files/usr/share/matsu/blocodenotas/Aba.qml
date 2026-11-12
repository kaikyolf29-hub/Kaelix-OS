// Uma aba da faixa: o nome do arquivo e, na ponta, o × (na aba aberta e com o
// mouse em cima) ou a bolinha • das mudanças não salvas, que vira × com o mouse.
// Botão do meio fecha; botão direito abre o menu da aba; arrastar muda a ordem.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: aba

    required property int index
    required property string nome
    required property string caminho
    required property bool modificado
    required property bool carregando
    property real larguraAlvo: 100
    property int alturaAba: 36
    property Item dono
    property ListView vista
    // Cresce de 0 a 1 ao nascer (a animação da faixa).
    property real fator: 1

    readonly property bool ativa: ListView.isCurrentItem
    readonly property bool vizinhaAtiva: index + 1 === janela.atual
    readonly property bool mostrarX: containsMouse || (ativa && !modificado)
    property real pressX: 0
    property bool arrastando: false

    width: Math.max(0, larguraAlvo * fator)
    height: alturaAba
    clip: fator < 1
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: arrastando ? Qt.ClosedHandCursor : Qt.ArrowCursor
    Accessible.role: Accessible.PageTab
    Accessible.name: nome
    Accessible.selected: ativa

    onContainsMouseChanged: {
        if (containsMouse)
            dono.sob = index;
        else if (dono.sob === index)
            dono.sob = -1;
    }
    onPressed: (m) => {
        if (m.button === Qt.LeftButton) {
            pressX = m.x;
            arrastando = false;
            janela.irParaAba(index);
        }
    }
    onReleased: arrastando = false
    onClicked: (m) => {
        if (m.button === Qt.MiddleButton)
            janela.fecharAba(index);
        else if (m.button === Qt.RightButton)
            janela.abrirMenuAba(index, aba, m.x, m.y);
    }
    // Arrastar para os lados troca a aba de lugar.
    onPositionChanged: (m) => {
        if (!(pressedButtons & Qt.LeftButton))
            return;
        if (!arrastando && Math.abs(m.x - pressX) > Qt.styleHints.startDragDistance)
            arrastando = true;
        if (!arrastando)
            return;
        var p = mapToItem(vista.contentItem, m.x, height / 2);
        var alvo = vista.indexAt(p.x, p.y);
        if (alvo >= 0 && alvo !== index)
            janela.moverAba(index, alvo);
    }

    // Fundo com o mouse em cima (a aba aberta já tem o fundo da folha).
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 5
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        radius: Math.round(janela.gu * 0.35)
        color: janela.tinta(!aba.ativa && aba.containsMouse ? (aba.pressed ? 0.08 : 0.055) : 0)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }
    // A linha fina entre duas abas fechadas.
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -1
        width: 1
        height: Math.round(parent.height * 0.42)
        color: janela.tinta(janela.escuro ? 0.14 : 0.16)
        opacity: !aba.ativa && !aba.vizinhaAtiva && aba.dono.sob !== aba.index && aba.dono.sob !== aba.index + 1 ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 0.85)
        anchors.rightMargin: Math.round(janela.gu * 0.4)
        spacing: Math.round(janela.gu * 0.35)

        Girando {
            visible: aba.carregando
            Layout.preferredWidth: Math.round(janela.gu * 0.8)
            Layout.preferredHeight: Math.round(janela.gu * 0.8)
        }
        Texto {
            Layout.fillWidth: true
            text: aba.nome
            elide: Text.ElideRight
            opacity: aba.ativa ? 1 : (aba.containsMouse ? 0.9 : 0.68)
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
        // O × e a bolinha das mudanças no mesmo lugar.
        MouseArea {
            id: fechar
            Layout.preferredWidth: Math.round(janela.gu * 1.3)
            Layout.preferredHeight: Math.round(janela.gu * 1.3)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: janela.fecharAba(aba.index)
            Accessible.role: Accessible.Button
            Accessible.name: janela.t("Fechar aba", "Close tab")

            Rectangle {
                anchors.fill: parent
                radius: Math.round(janela.gu * 0.3)
                color: janela.tinta(fechar.pressed ? 0.14 : (fechar.containsMouse ? 0.09 : 0))
                Behavior on color {
                    ColorAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(Kirigami.Units.iconSizes.small * 0.82)
                height: width
                source: "matsu-fechar-symbolic"
                isMask: true
                color: janela.frente
                opacity: aba.mostrarX ? (fechar.containsMouse ? 1 : 0.75) : 0
                scale: aba.mostrarX ? 1 : 0.5
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: Math.round(janela.gu * 0.42)
                height: width
                radius: width / 2
                color: janela.frente
                readonly property bool mostrar: aba.modificado && !aba.mostrarX
                opacity: mostrar ? 0.8 : 0
                scale: mostrar ? 1 : 0.2
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
    }

    QQC2.ToolTip.visible: containsMouse && !pressed && !fechar.containsMouse
    QQC2.ToolTip.text: caminho ? caminho : janela.t("Ainda não foi salvo", "Not saved yet")
    QQC2.ToolTip.delay: 700
}
