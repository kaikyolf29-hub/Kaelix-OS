// Barra e doca: o estilo da barra (fusão, Mac ou Windows), o tamanho, onde
// ficam a busca e o menu, se a barra se esconde sozinha e, com mais de uma
// tela, se a barra aparece em todas e onde ficam os apps abertos (como no Windows).
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
    readonly property string busca: ajustes.texto("barra_busca") || "esquerda"
    readonly property string menu: ajustes.texto("barra_menu") || "esquerda"
    readonly property bool todasAsTelas: ajustes.texto("barra_telas") !== "principal"
    readonly property string abertos: ajustes.texto("barra_abertos") || "tela"
    readonly property int telas: Qt.application.screens.length

    function trocar(estilo, tamanho, esconde, busca, menu, todas, abertos) {
        var b = busca !== undefined ? busca : pagina.busca;
        var m = menu !== undefined ? menu : pagina.menu;
        var t = (todas !== undefined ? todas : pagina.todasAsTelas) ? "todas" : "principal";
        var a = abertos !== undefined ? abertos : pagina.abertos;
        ajustes.definir("barra", estilo);
        ajustes.definir("barra_tamanho", tamanho);
        ajustes.definir("barra_esconder", esconde ? "1" : "0");
        ajustes.definir("barra_busca", b);
        ajustes.definir("barra_menu", m);
        ajustes.definir("barra_telas", t);
        ajustes.definir("barra_abertos", a);
        ajustes.fazer("barra " + estilo + " " + tamanho + " " + (esconde ? "sim" : "nao") + " " + b + " " + m + " " + t + " " + a);
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
                            busca: pagina.busca
                            menu: pagina.menu
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

        // Onde fica a pílula "Buscar apps e arquivos". No meio ela se junta à
        // ilha dos apps. Na barra única do Windows ela fica sempre ao lado do menu.
        Linha {
            visible: pagina.estilo !== "mac"
            nome: ajustes.t("Busca", "Search")
            detalhe: pagina.estilo === "windows" ? ajustes.t("Na barra única, a busca fica ao lado do menu.", "On the single bar, search sits next to the menu.")
                                                 : ajustes.t("No meio, a busca se junta à ilha dos apps.", "In the middle, search joins the apps island.")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 17
                atual: pagina.estilo === "windows" && pagina.busca === "meio" ? "esquerda" : pagina.busca
                opcoes: pagina.estilo === "windows"
                    ? [
                        { valor: "esquerda", nome: ajustes.t("Ao lado do menu", "Next to the menu") },
                        { valor: "nao", nome: ajustes.t("Sem busca", "No search") }
                    ]
                    : [
                        { valor: "esquerda", nome: ajustes.t("Junto do menu", "With the menu") },
                        { valor: "meio", nome: ajustes.t("No meio", "In the middle") },
                        { valor: "nao", nome: ajustes.t("Sem busca", "No search") }
                    ]
                onEscolhido: valor => pagina.trocar(pagina.estilo, pagina.tamanho, pagina.esconde, valor, pagina.menu)
            }
        }

        // O botão do menu no meio, junto dos apps, como no Windows 11.
        Linha {
            visible: pagina.estilo === "fusao"
            nome: ajustes.t("Menu", "Menu")
            detalhe: ajustes.t("No meio, o logo fica junto dos apps, como no Windows 11.", "In the middle, the logo sits with the apps, like Windows 11.")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                atual: pagina.menu
                opcoes: [
                    { valor: "esquerda", nome: ajustes.t("À esquerda", "On the left") },
                    { valor: "meio", nome: ajustes.t("No meio", "In the middle") }
                ]
                onEscolhido: valor => pagina.trocar(pagina.estilo, pagina.tamanho, pagina.esconde, pagina.busca, valor)
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

    // Várias telas, como no Windows: a barra em todas as telas (só a principal
    // tem a bandeja, a central e a lixeira) e onde aparece cada app aberto.
    Grupo {
        titulo: ajustes.t("Várias telas", "Multiple screens")
        nota: pagina.telas > 1
              ? ajustes.t("Agora há " + pagina.telas + " telas ligadas. Ao ligar outro monitor, a barra aparece nele sozinha.",
                          "There are " + pagina.telas + " screens connected now. When you plug in another monitor, the bar shows up on it by itself.")
              : ajustes.t("Vale quando houver mais de uma tela. Ao ligar um monitor, a barra aparece nele sozinha.",
                          "Applies when there is more than one screen. When you plug in a monitor, the bar shows up on it by itself.")

        Linha {
            primeira: true
            nome: ajustes.t("Mostrar a barra em todas as telas", "Show the bar on all screens")
            detalhe: ajustes.t("A bandeja, a central e a lixeira ficam na tela principal.",
                               "The tray, control center and trash stay on the main screen.")
            PlasmaComponents.Switch {
                checked: pagina.todasAsTelas
                onToggled: pagina.trocar(pagina.estilo, pagina.tamanho, pagina.esconde, pagina.busca, pagina.menu, checked, pagina.abertos)
                Accessible.name: ajustes.t("Mostrar a barra em todas as telas", "Show the bar on all screens")
            }
        }

        Linha {
            visible: pagina.todasAsTelas
            nome: ajustes.t("Apps abertos aparecem", "Open apps show up")
            detalhe: pagina.abertos === "tela" ? ajustes.t("Cada app fica só na barra da tela onde a janela está.", "Each app stays only on the bar of the screen its window is on.")
                   : pagina.abertos === "todas" ? ajustes.t("Todo app aberto aparece em todas as barras.", "Every open app shows up on every bar.")
                   : ajustes.t("Na barra principal e na barra da tela onde a janela está.", "On the main bar and on the bar of the screen its window is on.")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 19
                atual: pagina.abertos
                opcoes: [
                    { valor: "tela", nome: ajustes.t("Na tela dele", "On its screen") },
                    { valor: "principal", nome: ajustes.t("Principal e dele", "Main and its") },
                    { valor: "todas", nome: ajustes.t("Em todas", "On all") }
                ]
                onEscolhido: valor => pagina.trocar(pagina.estilo, pagina.tamanho, pagina.esconde, pagina.busca, pagina.menu, pagina.todasAsTelas, valor)
            }
        }
    }
}
