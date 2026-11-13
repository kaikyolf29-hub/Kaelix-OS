// Um cartão da página Início: uma área da segurança (escudo, rede, apps...),
// com o estado numa linha e a bolinha da cor do estado. Leva para a página.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

CartaoClicavel {
    id: area

    property string icone: ""
    property string titulo: ""
    property string linha: ""
    // A bolinha do estado (transparente: sem bolinha).
    property color cor: "transparent"
    property bool lendo: false

    implicitHeight: Math.round(janela.gu * 6)
    Accessible.name: titulo + ". " + linha

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(janela.gu * 0.9)
        spacing: Math.round(janela.gu * 0.25)

        RowLayout {
            Layout.fillWidth: true
            IconeRedondo {
                icone: area.icone
                cor: area.cor.a > 0 ? area.cor : janela.frente
            }
            Item {
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Layout.preferredWidth
                source: "matsu-seta-symbolic"
                isMask: true
                color: janela.frente
                opacity: area.containsMouse ? 0.75 : 0.35
                transform: Translate {
                    x: area.containsMouse ? 2 : 0
                    Behavior on x {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
        Item {
            Layout.fillHeight: true
        }
        Texto {
            Layout.fillWidth: true
            text: area.titulo
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: textoLinha.implicitHeight
            Esqueleto {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.7
                height: Math.round(janela.gu * 0.6)
                visible: area.lendo
            }
            RowLayout {
                anchors.fill: parent
                spacing: Math.round(janela.gu * 0.35)
                visible: !area.lendo
                Rectangle {
                    visible: area.cor.a > 0
                    Layout.preferredWidth: Math.round(janela.gu * 0.42)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: area.cor
                }
                Texto {
                    id: textoLinha
                    Layout.fillWidth: true
                    text: area.linha
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.68
                    elide: Text.ElideRight
                }
            }
        }
    }
}
