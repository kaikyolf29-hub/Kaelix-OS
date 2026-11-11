// Menu de perfis gráficos de um jogo (no destaque do Início e nos detalhes do
// jogo): "Usar o geral" e os cinco perfis, cada um com a sua cor.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

QQC2.Popup {
    id: menu

    property string jogoId: ""
    readonly property string escolhido: janela.perfilDoJogo(jogoId)

    padding: 5
    width: Math.round(janela.gu * 15)
    modal: false
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.shortDuration }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Kirigami.Units.shortDuration }
    }

    background: Rectangle {
        radius: Math.round(janela.gu * 0.55)
        color: janela.escuro ? "#2a2a2e" : "#fbfbfc"
        border.width: 1
        border.color: janela.escuro ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.12)
    }

    contentItem: ColumnLayout {
        spacing: 1

        Repeater {
            model: [""].concat(janela.perfis)

            MouseArea {
                id: opcao
                required property string modelData
                readonly property bool escolhida: menu.escolhido === modelData
                readonly property string perfilGeral: janela.conf ? janela.conf.perfil : "padrao"
                Layout.fillWidth: true
                implicitHeight: Math.round(janela.gu * 2.1)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    janela.escolherPerfilDoJogo(menu.jogoId, modelData);
                    menu.close();
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(janela.gu * 0.35)
                    color: janela.tinta(opcao.containsMouse ? 0.07 : 0)
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(janela.gu * 0.5)
                    anchors.rightMargin: Math.round(janela.gu * 0.5)
                    spacing: Math.round(janela.gu * 0.55)
                    Rectangle {
                        Layout.preferredWidth: Math.round(janela.gu * 1.35)
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: width / 2
                        color: Qt.rgba(0, 0, 0, 0)
                        border.width: opcao.modelData === "" ? 1.5 : 0
                        border.color: janela.tinta(0.45)
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            visible: opcao.modelData !== ""
                            color: janela.corPerfil(opcao.modelData) || "transparent"
                            opacity: 0.22
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.62)
                            height: width
                            source: janela.iconePerfil(opcao.modelData || opcao.perfilGeral)
                            isMask: true
                            color: opcao.modelData === "" ? janela.frente : janela.corPerfil(opcao.modelData)
                            opacity: opcao.modelData === "" ? 0.7 : 1
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Texto {
                            Layout.fillWidth: true
                            text: opcao.modelData === "" ? janela.t("Usar o geral", "Use the global one") : janela.nomePerfil(opcao.modelData)
                            elide: Text.ElideRight
                            font.weight: opcao.escolhida ? Font.DemiBold : Font.Normal
                        }
                        Texto {
                            visible: opcao.modelData === ""
                            Layout.fillWidth: true
                            text: janela.nomePerfil(opcao.perfilGeral)
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                        }
                    }
                    Kirigami.Icon {
                        visible: opcao.escolhida
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: "matsu-certo-symbolic"
                        isMask: true
                        color: janela.frente
                    }
                }
            }
        }
    }
}
