// Energia: bateria (no notebook), perfil de energia e o resto no ajuste do KDE.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    Grupo {
        Linha {
            primeira: true
            visible: ajustes.sim("bateria_tem")
            nome: ajustes.t("Bateria", "Battery")
            detalhe: ajustes.numero("bateria") + "%" + (ajustes.sim("carregando") ? ajustes.t(", carregando", ", charging") : "")
        }
        Linha {
            primeira: !ajustes.sim("bateria_tem")
            visible: ajustes.sim("perfil_tem")
            nome: ajustes.t("Perfil de energia", "Power profile")
            Segmentado {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                atual: ajustes.texto("perfil")
                opcoes: [
                    { valor: "power-saver", nome: ajustes.t("Economia", "Saver") },
                    { valor: "balanced", nome: ajustes.t("Equilibrado", "Balanced") },
                    { valor: "performance", nome: ajustes.t("Desempenho", "Performance"), ativa: ajustes.sim("perfil_desempenho") }
                ]
                onEscolhido: valor => {
                    ajustes.definir("perfil", valor);
                    ajustes.fazer("perfil " + (valor === "power-saver" ? "economia" : valor === "performance" ? "desempenho" : "equilibrado"));
                }
            }
        }
        Linha {
            primeira: !ajustes.sim("bateria_tem") && !ajustes.sim("perfil_tem")
            abre: true
            nome: ajustes.t("Tela, suspensão e economia de energia", "Screen, sleep and power saving")
            onAberto: ajustes.abrir("energia")
        }
    }
}
