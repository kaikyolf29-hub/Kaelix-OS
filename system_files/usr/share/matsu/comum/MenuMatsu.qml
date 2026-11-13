// Menu do botão direito (ou do botão "mais"), com o fundo dos balões do Matsu.
// Itens: { id, nome, icone, atalho, perigo (vermelho), separador (linha antes), ativo }.
// Abre com o foco: Esc fecha, as setas andam nos itens (pulando os apagados),
// Enter escolhe; o mouse em cima também acende o item.
//   MenuMatsu { id: menu; itens: [{ id: "abrir", nome: "Abrir" }, { id: "apagar", nome: "Apagar", perigo: true, separador: true }]
//               onEscolhido: (id) => ... }
//   ... menu.abrirEm(item, mouse.x, mouse.y)
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.Popup {
    id: menu

    property var itens: []
    // O item aceso (mouse ou setas); -1: nenhum.
    property int realce: -1

    signal escolhido(string id)

    // Abre no ponto (x, y) de "item", sem sair da janela.
    function abrirEm(item, px, py) {
        var p = item.mapToItem(parent, px, py);
        var larg = Math.max(width, implicitWidth), alt = Math.max(height, implicitHeight);
        x = Math.min(p.x, parent.width - larg - 4);
        y = p.y + alt > parent.height - 4 ? Math.max(4, p.y - alt) : p.y;
        open();
    }
    function _pode(i) {
        return i >= 0 && i < itens.length && itens[i].ativo !== false;
    }
    // Anda d itens (1 ou -1), dando a volta e pulando os que não dá para usar.
    function _andar(d) {
        var n = itens.length;
        if (n === 0)
            return;
        var i = realce;
        for (var k = 0; k < n; k++) {
            i = i < 0 ? (d > 0 ? 0 : n - 1) : (i + d + n) % n;
            if (_pode(i)) {
                realce = i;
                return;
            }
        }
    }
    function _ir(d) {
        realce = d > 0 ? -1 : itens.length;
        for (var k = 0; k < itens.length; k++) {
            var i = d > 0 ? k : itens.length - 1 - k;
            if (_pode(i)) {
                realce = i;
                return;
            }
        }
        realce = -1;
    }
    function _escolher(i) {
        if (!_pode(i))
            return;
        var id = itens[i].id;
        close();
        escolhido(id);
    }

    parent: QQC2.Overlay.overlay
    padding: 4
    focus: true
    width: Math.max(Math.round(janela.gu * 11), coluna.implicitWidth + 2 * padding)
    transformOrigin: QQC2.Popup.TopLeft
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    onAboutToShow: realce = -1
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 130 }
            NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: 100 }
    }
    background: FundoBalao {}
    contentItem: ColumnLayout {
        id: coluna
        spacing: 1
        focus: true
        Keys.onUpPressed: menu._andar(-1)
        Keys.onDownPressed: menu._andar(1)
        Keys.onReturnPressed: menu._escolher(menu.realce)
        Keys.onEnterPressed: menu._escolher(menu.realce)
        Keys.onSpacePressed: menu._escolher(menu.realce)
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Home || e.key === Qt.Key_PageUp) {
                menu._ir(1);
                e.accepted = true;
            } else if (e.key === Qt.Key_End || e.key === Qt.Key_PageDown) {
                menu._ir(-1);
                e.accepted = true;
            }
        }

        Repeater {
            model: menu.itens
            ColumnLayout {
                id: bloco
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 1
                Rectangle {
                    visible: !!bloco.modelData.separador
                    Layout.fillWidth: true
                    Layout.topMargin: 3
                    Layout.bottomMargin: 3
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    implicitHeight: 1
                    color: janela.tinta(0.1)
                }
                MouseArea {
                    id: opcao
                    readonly property bool pode: bloco.modelData.ativo !== false
                    readonly property bool aceso: menu.realce === bloco.index && pode
                    readonly property color corTexto: bloco.modelData.perigo ? (janela.escuro ? "#ff8a8a" : "#c62828") : janela.frente
                    Layout.fillWidth: true
                    implicitWidth: linha.implicitWidth + Math.round(janela.gu * 1.2)
                    implicitHeight: Math.round(janela.gu * 1.9)
                    hoverEnabled: true
                    enabled: pode
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: bloco.modelData.nome
                    // Só quando o mouse anda de verdade (parado em cima, as setas mandam).
                    property point ultimo: Qt.point(-1, -1)
                    onPositionChanged: (m) => {
                        var p = mapToItem(null, m.x, m.y);
                        if (p.x !== ultimo.x || p.y !== ultimo.y) {
                            ultimo = p;
                            menu.realce = bloco.index;
                        }
                    }
                    onExited: if (menu.realce === bloco.index) menu.realce = -1
                    onClicked: { menu.close(); menu.escolhido(bloco.modelData.id); }
                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(janela.gu * 0.3)
                        color: opcao.aceso ? (bloco.modelData.perigo ? Qt.rgba(0.9, 0.2, 0.2, opcao.pressed ? 0.2 : 0.14) : janela.tinta(opcao.pressed ? 0.11 : 0.075))
                                           : (bloco.modelData.perigo ? Qt.rgba(0.9, 0.2, 0.2, 0) : janela.tinta(0))
                        Behavior on color {
                            ColorAnimation {
                                duration: 90
                            }
                        }
                    }
                    RowLayout {
                        id: linha
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(janela.gu * 0.6)
                        anchors.rightMargin: Math.round(janela.gu * 0.8)
                        spacing: Math.round(janela.gu * 0.55)
                        opacity: opcao.pode ? 1 : 0.4
                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: bloco.modelData.icone || ""
                            visible: (bloco.modelData.icone || "").length > 0
                            isMask: true
                            color: opcao.corTexto
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: bloco.modelData.nome
                            color: opcao.corTexto
                        }
                        Texto {
                            visible: (bloco.modelData.atalho || "").length > 0
                            text: bloco.modelData.atalho || ""
                            opacity: 0.5
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }
                }
            }
        }
    }
}
