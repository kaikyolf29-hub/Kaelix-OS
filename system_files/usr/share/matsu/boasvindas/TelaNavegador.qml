// Navegador: o Firefox já vem; aqui dá para instalar o Brave, o Chrome ou os dois
// (o escolhido vira o padrão e fica na barra). A instalação roda num serviço do
// sistema (systemd-run): continua mesmo que a pessoa siga em frente ou feche.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: tela

    readonly property var nomes: ({ brave: "Brave", chrome: "Google Chrome", "os-dois": janela.t("o Brave e o Chrome", "Brave and Chrome") })

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - janela.gu * 4, janela.gu * 32)
        spacing: Math.round(janela.gu * 1)

        Cabecalho {
            titulo: janela.t("Escolha o navegador", "Choose your browser")
            texto: janela.t("O Firefox já vem instalado. Se preferir outro, ele vira o padrão e fica na barra no lugar do Firefox.",
                            "Firefox comes installed. If you prefer another one, it becomes the default and takes Firefox's place on the bar.")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.7)
            Repeater {
                model: [
                    { id: "brave", nome: "Brave", texto: janela.t("Rápido e bloqueia anúncios", "Fast, blocks ads") },
                    { id: "chrome", nome: "Google Chrome", texto: janela.t("O do Google, com a sua conta", "Google's, with your account") },
                    { id: "os-dois", nome: janela.t("Os dois", "Both"), texto: janela.t("O Brave e o Chrome juntos", "Brave and Chrome together") }
                ]
                delegate: Escolha {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    nome: modelData.nome
                    texto: modelData.texto
                    escolhida: janela.navegadorEscolhido === modelData.id && janela.navegador !== "erro"
                    ocupado: escolhida && janela.navegador === "instalando"
                    enabled: janela.navegador !== "instalando" && janela.navegador !== "feito"
                    opacity: enabled || escolhida ? 1 : 0.5
                    onClicked: janela.instalarNavegador(modelData.id)
                }
            }
        }

        // Como vai a instalação.
        Cartao {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(janela.gu * 2.8)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(janela.gu * 0.9)
                anchors.rightMargin: Math.round(janela.gu * 0.9)
                spacing: Math.round(janela.gu * 0.6)
                Kirigami.Icon {
                    Layout.preferredWidth: Math.round(janela.gu * 1.4)
                    Layout.preferredHeight: Math.round(janela.gu * 1.4)
                    visible: janela.navegador === ""
                    // O ícone de verdade do Firefox (ele já está instalado).
                    source: "org.mozilla.firefox"
                    fallback: "firefox"
                }
                Girando {
                    Layout.preferredWidth: Math.round(janela.gu * 1.1)
                    Layout.preferredHeight: Math.round(janela.gu * 1.1)
                    visible: janela.navegador === "instalando"
                }
                Kirigami.Icon {
                    Layout.preferredWidth: Math.round(janela.gu * 1.2)
                    Layout.preferredHeight: Math.round(janela.gu * 1.2)
                    visible: janela.navegador === "feito" || janela.navegador === "erro"
                    source: janela.navegador === "feito" ? "matsu-certo-symbolic" : "matsu-alerta-symbolic"
                    color: janela.navegador === "feito" ? (janela.escuro ? "#5ad18f" : "#23915a") : (janela.escuro ? "#ffb36b" : "#c26a12")
                    isMask: true
                }
                Texto {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: {
                        var nome = tela.nomes[janela.navegadorEscolhido] || "";
                        switch (janela.navegador) {
                        case "instalando":
                            return janela.t("Instalando " + nome + ". Pode continuar: termina sozinho.",
                                            "Installing " + nome + ". You can go on: it finishes by itself.");
                        case "feito":
                            return janela.t("Pronto! " + nome.charAt(0).toUpperCase() + nome.slice(1) + " já está na barra.",
                                            "Done! " + nome + " is on the bar.");
                        case "erro":
                            return janela.t("Não deu para instalar agora. Confira a internet e tente de novo.",
                                            "Could not install right now. Check the internet and try again.");
                        default:
                            return janela.t("Ficar com o Firefox? É só continuar.", "Keeping Firefox? Just continue.");
                        }
                    }
                }
            }
        }
    }
}
