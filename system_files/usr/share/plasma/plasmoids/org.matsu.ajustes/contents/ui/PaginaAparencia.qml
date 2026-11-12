// Aparência: tema claro ou escuro, a cor do vidro (que também é a cor de
// destaque), o efeito vidro ligado ou não e quanto o vidro deixa ver o que está atrás.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: pagina

    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    readonly property var cores: [
        { id: "padrao", cor: "#a1a1a8", nome: ajustes.t("Cinza neutro", "Neutral gray") },
        { id: "azul", cor: "#2f80ed", nome: ajustes.t("Azul", "Blue") },
        { id: "roxo", cor: "#8b5cf6", nome: ajustes.t("Roxo", "Purple") },
        { id: "rosa", cor: "#ec4899", nome: ajustes.t("Rosa", "Pink") },
        { id: "vermelho", cor: "#ef4444", nome: ajustes.t("Vermelho", "Red") },
        { id: "laranja", cor: "#f97316", nome: ajustes.t("Laranja", "Orange") },
        { id: "amarelo", cor: "#eab308", nome: ajustes.t("Amarelo", "Yellow") },
        { id: "verde", cor: "#22c55e", nome: ajustes.t("Verde", "Green") },
        { id: "grafite", cor: "#6b7280", nome: ajustes.t("Grafite", "Graphite") }
    ]
    readonly property string corAtual: ajustes.texto("vidro_cor") || "padrao"
    readonly property string nivelAtual: ajustes.texto("vidro_transparencia") || "normal"

    function nomeDaCor(id) {
        for (var i = 0; i < cores.length; i++) {
            if (cores[i].id === id) {
                return cores[i].nome;
            }
        }
        return id;
    }

    function trocarVidro(cor, nivel) {
        ajustes.definir("vidro_cor", cor);
        ajustes.definir("vidro_transparencia", nivel);
        ajustes.fazer("vidro " + cor + " " + nivel);
    }

    Grupo {
        Linha {
            primeira: true
            nome: ajustes.t("Tema", "Theme")
            detalhe: ajustes.t("O tema escuro descansa a vista à noite.", "The dark theme is easier on the eyes at night.")

            Repeater {
                model: [
                    { escuro: false, nome: ajustes.t("Claro", "Light") },
                    { escuro: true, nome: ajustes.t("Escuro", "Dark") }
                ]
                Miniatura {
                    id: tema
                    required property var modelData
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    largura: Kirigami.Units.gridUnit * 6.5
                    nome: modelData.nome
                    escolhida: ajustes.sim("escuro") === modelData.escuro
                    onClicked: {
                        ajustes.definir("escuro", modelData.escuro ? "1" : "0");
                        ajustes.fazer("tema " + (modelData.escuro ? "escuro" : "claro"));
                    }
                    MiniTela {
                        escuro: tema.modelData.escuro
                        comJanela: true
                    }
                }
            }
        }
    }

    Grupo {
        nota: ajustes.t("A cor pinta de leve o vidro da barra, dos balões e do menu, e vira a cor dos botões ligados e da seleção.",
                        "The color lightly tints the glass of the bar, popups and menu, and becomes the color of switched-on buttons and selections.")

        Linha {
            primeira: true
            nome: ajustes.t("Cor do vidro", "Glass color")
            detalhe: pagina.nomeDaCor(pagina.corAtual)

            Repeater {
                model: pagina.cores
                PontoCor {
                    required property var modelData
                    cor: modelData.cor
                    nome: modelData.nome
                    escolhido: pagina.corAtual === modelData.id
                    onClicked: pagina.trocarVidro(modelData.id, pagina.nivelAtual)
                }
            }
        }

        // Sem vidro: a barra, os balões, o menu e as janelas dos apps ficam sólidos.
        Linha {
            nome: ajustes.t("Efeito vidro", "Glass effect")
            detalhe: pagina.nivelAtual === "sem"
                ? ajustes.t("Desligado: a barra, o menu e as janelas ficam sólidos.", "Off: the bar, menu and windows are solid.")
                : ajustes.t("O papel de parede aparece de leve, desfocado, atrás da barra e das janelas.", "The wallpaper shows softly, blurred, behind the bar and windows.")
            PlasmaComponents.Switch {
                checked: pagina.nivelAtual !== "sem"
                onToggled: pagina.trocarVidro(pagina.corAtual, checked ? "normal" : "sem")
                Accessible.name: ajustes.t("Efeito vidro", "Glass effect")
            }
        }

        Linha {
            visible: pagina.nivelAtual !== "sem"
            nome: ajustes.t("Transparência", "Transparency")
            detalhe: ajustes.t("Quanto dá para ver o papel de parede através do vidro.", "How much of the wallpaper shows through the glass.")

            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                atual: pagina.nivelAtual
                opcoes: [
                    { valor: "mais", nome: ajustes.t("Mais", "More") },
                    { valor: "normal", nome: ajustes.t("Normal", "Normal") },
                    { valor: "menos", nome: ajustes.t("Menos", "Less") }
                ]
                onEscolhido: valor => pagina.trocarVidro(pagina.corAtual, valor)
            }
        }
    }
}
