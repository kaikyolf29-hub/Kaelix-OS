// Cartão de um app nas listas: a logo oficial, o botão de obter, o nome (com o
// selo de verificado) e o resumo. Clicar abre a página do app. Com o mouse em
// cima, o cartão sobe um pouco e ganha uma sombra macia (CartaoClicavel, do comum).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

CartaoClicavel {
    id: cartao

    property var app: null

    Accessible.name: app ? app.nome : ""
    Accessible.description: app ? app.resumo : ""
    onClicked: if (app) janela.abrirApp(app.id)
    Keys.onReturnPressed: if (app) janela.abrirApp(app.id)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(janela.gu * 0.85)
        spacing: Math.round(janela.gu * 0.3)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.5)
            IconeApp {
                Layout.preferredWidth: Math.round(janela.gu * 3.3)
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignTop
                fonte: cartao.app ? cartao.app.icone : ""
                appId: cartao.app ? cartao.app.id : ""
                scale: cartao.containsMouse ? 1.05 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            BotaoObter {
                Layout.alignment: Qt.AlignTop
                appId: cartao.app ? cartao.app.id : ""
            }
        }

        Item {
            Layout.preferredHeight: Math.round(janela.gu * 0.15)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Texto {
                Layout.maximumWidth: cartao.width - Math.round(janela.gu * 1.7) - (selo.visible ? selo.width + 4 : 0)
                text: cartao.app ? cartao.app.nome : ""
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Kirigami.Icon {
                id: selo
                visible: cartao.app !== null && cartao.app.verificado
                implicitWidth: Math.round(Kirigami.Units.iconSizes.small * 0.85)
                implicitHeight: implicitWidth
                source: "matsu-verificado-symbolic"
                isMask: true
                color: janela.corSelo
                HoverHandler {
                    id: sobreSelo
                }
                QQC2.ToolTip.visible: sobreSelo.hovered
                QQC2.ToolTip.text: janela.t("Verificado: publicado por quem faz o app", "Verified: published by the app's developer")
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            Item {
                Layout.fillWidth: true
            }
        }
        Texto {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: cartao.app ? cartao.app.resumo : ""
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            verticalAlignment: Text.AlignTop
            opacity: 0.65
            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
        }
    }
}
