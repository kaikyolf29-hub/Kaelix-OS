// Bluetooth: liga e desliga; parear aparelhos no ajuste de Bluetooth do KDE.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    Grupo {
        Linha {
            primeira: true
            nome: "Bluetooth"
            detalhe: ajustes.sim("bt_tem") ? "" : ajustes.t("Este computador não tem Bluetooth.", "This computer has no Bluetooth.")
            PlasmaComponents.Switch {
                visible: ajustes.sim("bt_tem")
                checked: ajustes.sim("bt_ligado")
                onToggled: ajustes.alternar("bt_ligado", "bluetooth")
                Accessible.name: "Bluetooth"
            }
        }
        Linha {
            visible: ajustes.sim("bt_tem")
            abre: true
            nome: ajustes.t("Aparelhos Bluetooth", "Bluetooth devices")
            detalhe: ajustes.t("Fones, teclados, mouses e controles.", "Headphones, keyboards, mice and controllers.")
            onAberto: ajustes.abrir("bluetooth")
        }
    }
}
