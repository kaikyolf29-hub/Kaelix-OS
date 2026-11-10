// Barra e doca: o estilo da barra (fusão, Mac ou Windows) e o tamanho.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: pagina

    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    readonly property string estilo: ajustes.texto("barra") || "fusao"
    readonly property string tamanho: ajustes.texto("barra_tamanho") || "media"
    readonly property bool esconde: ajustes.sim("barra_esconder")

    function trocar(estilo, tamanho, esconde) {
        ajustes.definir("barra", estilo);
        ajustes.definir("barra_tamanho", tamanho);
        ajustes.definir("barra_esconder", esconde ? "1" : "0");
        ajustes.fazer("barra " + estilo + " " + tamanho + " " + (esconde ? "sim" : "nao"));
    }

    Grupo {
        nota: ajustes.t("Os apps que você fixou na barra continuam lá quando troca o estilo.",
                        "The apps you pinned stay on the bar when you change the style.")

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Math.round(Kirigami.Units.gridUnit * 0.8)
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents.Label {
                text: ajustes.t("Estilo", "Style")
            }

            RowLayout {
                id: estilos
                Layout.fillWidth: true
                spacing: Kirigami.Units.gridUnit

                Repeater {
                    model: [
                        { id: "fusao", nome: ajustes.t("Fusão", "Fusion") },
                        { id: "mac", nome: "Mac" },
                        { id: "windows", nome: "Windows" }
                    ]
                    Miniatura {
                        id: opcao
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        largura: Math.min(Kirigami.Units.gridUnit * 9, (estilos.width - estilos.spacing * 2) / 3)
                        nome: modelData.nome
                        escolhida: pagina.estilo === modelData.id
                        onClicked: pagina.trocar(modelData.id, pagina.tamanho, pagina.esconde)
                        MiniTela {
                            escuro: ajustes.sim("escuro") || ajustes.texto("escuro") === ""
                            estilo: opcao.modelData.id
                        }
                    }
                }
            }
        }

        Linha {
            nome: ajustes.t("Tamanho", "Size")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                atual: pagina.tamanho
                opcoes: [
                    { valor: "pequena", nome: ajustes.t("Pequena", "Small") },
                    { valor: "media", nome: ajustes.t("Média", "Medium") },
                    { valor: "grande", nome: ajustes.t("Grande", "Large") }
                ]
                onEscolhido: valor => pagina.trocar(pagina.estilo, valor, pagina.esconde)
            }
        }

        Linha {
            nome: ajustes.t("Esconder a barra sozinha", "Automatically hide the bar")
            detalhe: pagina.estilo === "mac" ? ajustes.t("A doca aparece quando o mouse encosta embaixo; a barra de cima fica.", "The dock shows up when the mouse touches the bottom; the top bar stays.")
                                              : ajustes.t("Ela aparece quando o mouse encosta embaixo da tela.", "It shows up when the mouse touches the bottom of the screen.")
            PlasmaComponents.Switch {
                checked: pagina.esconde
                onToggled: pagina.trocar(pagina.estilo, pagina.tamanho, checked)
                Accessible.name: ajustes.t("Esconder a barra sozinha", "Automatically hide the bar")
            }
        }
    }
}
