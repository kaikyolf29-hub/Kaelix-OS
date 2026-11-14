// A barra: Fusão (o jeito do Matsu), Mac (barra no alto e doca) ou Windows (uma
// barra inteira embaixo). Troca na hora; os apps fixados continuam nela.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - janela.gu * 4, janela.gu * 36)
        spacing: Math.round(janela.gu * 1)

        Cabecalho {
            titulo: janela.t("Escolha a barra", "Choose your bar")
            texto: janela.t("Os apps que você fixar continuam nela. O tamanho, a doca e esconder sozinha ficam nos Ajustes.",
                            "Your pinned apps stay on it. Size, dock and auto-hide are in Settings.")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.7)
            Repeater {
                model: [
                    { id: "fusao", nome: janela.t("Fusão", "Fusion"), texto: janela.t("Três ilhas embaixo, o jeito do Matsu", "Three islands at the bottom, the Matsu way") },
                    { id: "mac", nome: "Mac", texto: janela.t("Barra no alto e doca embaixo", "Top bar and a dock") },
                    { id: "windows", nome: "Windows", texto: janela.t("Uma barra inteira embaixo", "One full bar at the bottom") }
                ]
                delegate: Escolha {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    nome: modelData.nome
                    texto: modelData.texto
                    escolhida: janela.barra === modelData.id
                    ocupado: janela.mudando === "barra" && escolhida
                    alturaArte: Math.round(janela.gu * 5.6)
                    arte: Component {
                        MiniTela {
                            claro: !janela.temaEscuro
                            estilo: modelData.id
                            vidro: janela.vidro
                        }
                    }
                    onClicked: janela.estiloBarra(modelData.id)
                }
            }
        }
    }
}
