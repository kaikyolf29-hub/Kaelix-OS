// Menu do botão direito (ou do botão "mais"), com o fundo dos balões do Matsu.
// Itens: { id, nome, icone, perigo (vermelho), separador (linha antes), ativo }.
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

    signal escolhido(string id)

    // Abre no ponto (x, y) de "item", sem sair da janela.
    function abrirEm(item, px, py) {
        var p = item.mapToItem(parent, px, py);
        var larg = Math.max(width, implicitWidth), alt = Math.max(height, implicitHeight);
        x = Math.min(p.x, parent.width - larg - 4);
        y = p.y + alt > parent.height - 4 ? Math.max(4, p.y - alt) : p.y;
        open();
    }

    parent: QQC2.Overlay.overlay
    padding: 4
    width: Math.max(Math.round(janela.gu * 11), coluna.implicitWidth + 2 * padding)
    transformOrigin: QQC2.Popup.TopLeft
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
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
        Repeater {
            model: menu.itens
            ColumnLayout {
                id: bloco
                required property var modelData
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
                    readonly property color corTexto: bloco.modelData.perigo ? (janela.escuro ? "#ff8a8a" : "#c62828") : janela.frente
                    Layout.fillWidth: true
                    implicitWidth: linha.implicitWidth + Math.round(janela.gu * 1.2)
                    implicitHeight: Math.round(janela.gu * 1.9)
                    hoverEnabled: true
                    enabled: pode
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: bloco.modelData.nome
                    onClicked: { menu.close(); menu.escolhido(bloco.modelData.id); }
                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(janela.gu * 0.3)
                        color: opcao.containsMouse ? (bloco.modelData.perigo ? Qt.rgba(0.9, 0.2, 0.2, 0.14) : janela.tinta(0.075)) : "transparent"
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
