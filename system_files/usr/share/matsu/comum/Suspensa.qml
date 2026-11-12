// Lista suspensa: o botão mostra a escolha e a setinha; ao abrir, a lista desce
// com as opções e o visto na escolhida (como o "dropdown" do vídeo de referência).
//   Suspensa { opcoes: [{ id: "nome", nome: "Nome" }, ...]; escolhido: "nome"; onEscolher: (id) => ... }
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

MouseArea {
    id: suspensa

    property var opcoes: []
    property var escolhido
    property string nome: ""
    property string icone: ""
    property bool ativo: true

    signal escolher(var id)

    readonly property var atual: {
        for (var i = 0; i < opcoes.length; i++)
            if (opcoes[i].id === escolhido)
                return opcoes[i];
        return opcoes.length > 0 ? opcoes[0] : null;
    }

    implicitWidth: Math.max(Math.round(janela.gu * 8), linha.implicitWidth + Math.round(janela.gu * 1.4))
    implicitHeight: Math.round(janela.gu * 2)
    hoverEnabled: true
    enabled: ativo
    opacity: ativo ? 1 : 0.5
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: nome
    Accessible.description: atual ? atual.nome : ""
    onClicked: lista.opened ? lista.close() : lista.open()
    Keys.onSpacePressed: lista.open()
    Keys.onReturnPressed: lista.open()

    Rectangle {
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.4)
        color: janela.tinta(suspensa.pressed ? 0.1 : (suspensa.containsMouse || lista.opened ? 0.075 : (janela.escuro ? 0.05 : 0.04)))
        border.width: 1
        border.color: suspensa.activeFocus || lista.opened ? janela.destaque : janela.tinta(janela.escuro ? 0.09 : 0.12)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }
    RowLayout {
        id: linha
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 0.7)
        anchors.rightMargin: Math.round(janela.gu * 0.55)
        spacing: Math.round(janela.gu * 0.45)
        Kirigami.Icon {
            visible: suspensa.icone.length > 0 || (suspensa.atual && (suspensa.atual.icone || "").length > 0)
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: suspensa.atual && suspensa.atual.icone ? suspensa.atual.icone : suspensa.icone
            isMask: true
            color: janela.frente
        }
        Texto {
            Layout.fillWidth: true
            text: suspensa.atual ? suspensa.atual.nome : ""
            elide: Text.ElideRight
        }
        Kirigami.Icon {
            Layout.preferredWidth: Math.round(Kirigami.Units.iconSizes.small * 0.8)
            Layout.preferredHeight: Layout.preferredWidth
            source: "matsu-seta-symbolic"
            isMask: true
            color: janela.frente
            opacity: 0.7
            rotation: lista.opened ? -90 : 90
            Behavior on rotation {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    QQC2.Popup {
        id: lista
        y: suspensa.height + 4
        width: Math.max(suspensa.width, coluna.implicitWidth + 2 * padding)
        padding: 4
        transformOrigin: QQC2.Popup.Top
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
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
        contentItem: ColumnLayout {
            id: coluna
            spacing: 1
            Repeater {
                model: suspensa.opcoes
                MouseArea {
                    id: opcao
                    required property var modelData
                    required property int index
                    readonly property bool escolhida: suspensa.atual === modelData
                    Layout.fillWidth: true
                    implicitWidth: linhaOpcao.implicitWidth + Math.round(janela.gu * 1.2)
                    implicitHeight: Math.round(janela.gu * 1.95)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: modelData.nome
                    Accessible.checked: escolhida
                    onClicked: { lista.close(); suspensa.escolher(modelData.id); }
                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(janela.gu * 0.3)
                        color: janela.tinta(opcao.containsMouse ? 0.07 : (opcao.escolhida ? 0.045 : 0))
                    }
                    RowLayout {
                        id: linhaOpcao
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(janela.gu * 0.6)
                        anchors.rightMargin: Math.round(janela.gu * 0.6)
                        spacing: Math.round(janela.gu * 0.5)
                        Kirigami.Icon {
                            visible: (opcao.modelData.icone || "").length > 0
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: opcao.modelData.icone || ""
                            isMask: true
                            color: janela.frente
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: opcao.modelData.nome
                            font.weight: opcao.escolhida ? Font.DemiBold : Font.Normal
                        }
                        Shape {
                            Layout.preferredWidth: Math.round(janela.gu * 0.8)
                            Layout.preferredHeight: Layout.preferredWidth
                            opacity: opcao.escolhida ? 1 : 0
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: janela.frente
                                strokeWidth: 2
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                startX: janela.gu * 0.8 * 0.12
                                startY: janela.gu * 0.8 * 0.52
                                PathLine { x: janela.gu * 0.8 * 0.4; y: janela.gu * 0.8 * 0.8 }
                                PathLine { x: janela.gu * 0.8 * 0.9; y: janela.gu * 0.8 * 0.22 }
                            }
                        }
                    }
                }
            }
        }
    }
}
