// Telas: brilho (no notebook), luz noturna e o resto no ajuste de telas do KDE.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    Grupo {
        Linha {
            primeira: true
            abre: true
            nome: ajustes.t("Resolução, escala e posição das telas", "Resolution, scale and screen layout")
            detalhe: ajustes.t("Também estender, duplicar ou usar uma tela só (Meta+P).", "Also extend, mirror or use a single screen (Meta+P).")
            onAberto: ajustes.abrir("tela")
        }
        Linha {
            visible: ajustes.sim("brilho_tem")
            nome: ajustes.t("Brilho", "Brightness")
            Regulador {
                valor: ajustes.numero("brilho")
                minimo: 1
                acao: "brilho"
            }
        }
    }

    Grupo {
        nota: ajustes.t("A luz noturna deixa a tela mais amarelada, para cansar menos a vista.",
                        "Night light makes the screen warmer, so it is easier on the eyes.")
        Linha {
            primeira: true
            nome: ajustes.t("Luz noturna", "Night light")
            PlasmaComponents.Switch {
                checked: ajustes.sim("noturna")
                onToggled: ajustes.alternar("noturna", "luz-noturna")
                Accessible.name: ajustes.t("Luz noturna", "Night light")
            }
        }
        Linha {
            abre: true
            nome: ajustes.t("Horários e cor da luz noturna", "Night light schedule and color")
            onAberto: ajustes.abrir("luz-noturna")
        }
    }
}
