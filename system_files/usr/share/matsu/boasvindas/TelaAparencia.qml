// Aparência: escuro ou claro (vale na hora, a própria janela muda junto) e o
// efeito vidro ligado ou desligado.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - janela.gu * 4, janela.gu * 32)
        spacing: Math.round(janela.gu * 1)

        Cabecalho {
            titulo: janela.t("Escolha a aparência", "Choose your look")
            texto: janela.t("Dá para trocar quando quiser nos Ajustes do Matsu, junto com a cor do vidro e o papel de parede.",
                            "You can change it anytime in Matsu Settings, along with the glass color and the wallpaper.")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.8)
            Repeater {
                model: [{ id: true, nome: janela.t("Escuro", "Dark") }, { id: false, nome: janela.t("Claro", "Light") }]
                delegate: Escolha {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    nome: modelData.nome
                    escolhida: janela.temaEscuro === modelData.id
                    ocupado: janela.mudando === "tema" && escolhida
                    alturaArte: Math.round(janela.gu * 7)
                    arte: Component {
                        MiniTela {
                            claro: !modelData.id
                            estilo: janela.barra
                            vidro: janela.vidro
                        }
                    }
                    onClicked: janela.tema(modelData.id)
                }
            }
        }

        LinhaOpcao {
            Layout.fillWidth: true
            icone: "matsu-aparencia-symbolic"
            nome: janela.t("Efeito vidro", "Glass effect")
            texto: janela.t("Janelas e barra translúcidas, com o papel de parede desfocado atrás.",
                            "Translucent windows and bar, with the wallpaper blurred behind.")
            Chave {
                nome: janela.t("Efeito vidro", "Glass effect")
                ligada: janela.vidro
                onTrocada: (ligada) => janela.ligarVidro(ligada)
            }
        }
    }
}
