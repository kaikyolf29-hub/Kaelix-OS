// Seus apps: onde instalar programas e jogos e onde mudar o resto (Loja, Central
// de jogos e Ajustes). Cada linha abre o app na hora; as Boas-vindas ficam abertas.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - janela.gu * 4, janela.gu * 30)
        spacing: Math.round(janela.gu * 1)

        Cabecalho {
            titulo: janela.t("Tudo à mão", "Everything at hand")
            texto: janela.t("Três lugares para conhecer. Clique para abrir agora, ou continue e veja depois.",
                            "Three places worth knowing. Click to open one now, or continue and look later.")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.45)
            Repeater {
                model: [
                    { id: "org.matsu.loja", icone: "org.matsu.loja", nome: janela.t("Loja do Matsu", "Matsu Store"),
                      texto: janela.t("Apps, jogos e sites, com as atualizações de tudo.", "Apps, games and websites, with updates for everything.") },
                    { id: "org.matsu.jogos", icone: "org.matsu.jogos", nome: janela.t("Central de jogos", "Game Center"),
                      texto: janela.t("Seus jogos da Steam, desempenho, FPS na tela, controles e drivers.", "Your Steam games, performance, on-screen FPS, controllers and drivers.") },
                    { id: "org.matsu.ajustes", icone: "org.matsu.ajustes", nome: janela.t("Ajustes do Matsu", "Matsu Settings"),
                      texto: janela.t("Rede, som, telas, papel de parede, barra e a sua conta. Fica na engrenagem da barra.", "Network, sound, displays, wallpaper, bar and your account. It's the gear on the bar.") }
                ]
                delegate: CartaoClicavel {
                    id: linha
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Math.round(janela.gu * 3.6)
                    Accessible.name: modelData.nome
                    onClicked: janela.abrirApp(modelData.id)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(janela.gu * 0.8)
                        anchors.rightMargin: Math.round(janela.gu * 0.8)
                        spacing: Math.round(janela.gu * 0.8)
                        Kirigami.Icon {
                            Layout.preferredWidth: Math.round(janela.gu * 2.3)
                            Layout.preferredHeight: Math.round(janela.gu * 2.3)
                            source: linha.modelData.icone
                            fallback: "matsu-logo"
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Texto {
                                Layout.fillWidth: true
                                text: linha.modelData.nome
                                font.weight: Font.DemiBold
                            }
                            Texto {
                                Layout.fillWidth: true
                                text: linha.modelData.texto
                                wrapMode: Text.WordWrap
                                opacity: 0.65
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                        }
                        Kirigami.Icon {
                            Layout.preferredWidth: Math.round(janela.gu * 0.9)
                            Layout.preferredHeight: Math.round(janela.gu * 0.9)
                            source: "matsu-seta-symbolic"
                            color: janela.frente
                            isMask: true
                            opacity: linha.containsMouse ? 0.8 : 0.35
                        }
                    }
                }
            }
        }
    }
}
