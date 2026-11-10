// Notificações: não perturbe e os avisos de cada app.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    Grupo {
        Linha {
            primeira: true
            nome: ajustes.t("Não perturbe", "Do not disturb")
            detalhe: ajustes.t("Os avisos ficam guardados no relógio, sem aparecer na tela.", "Notifications are kept by the clock without popping up.")
            PlasmaComponents.Switch {
                checked: ajustes.sim("dnd")
                onToggled: ajustes.alternar("dnd", "nao-perturbe")
                Accessible.name: ajustes.t("Não perturbe", "Do not disturb")
            }
        }
        Linha {
            abre: true
            nome: ajustes.t("Avisos de cada app", "Per-app notifications")
            onAberto: ajustes.abrir("notificacoes")
        }
    }
}
