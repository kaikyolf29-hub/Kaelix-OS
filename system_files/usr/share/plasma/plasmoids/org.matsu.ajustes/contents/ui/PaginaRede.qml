// Rede: Wi-Fi, cabo e o resto (VPN, senhas) no ajuste de rede do KDE.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    Grupo {
        Linha {
            primeira: true
            visible: ajustes.sim("wifi_tem")
            nome: "Wi-Fi"
            detalhe: ajustes.texto("wifi_nome").length > 0 ? ajustes.t("Conectado a ", "Connected to ") + ajustes.texto("wifi_nome")
                   : ajustes.sim("wifi_ligado") ? ajustes.t("Ligado, sem rede", "On, not connected") : ajustes.t("Desligado", "Off")
            PlasmaComponents.Switch {
                checked: ajustes.sim("wifi_ligado")
                onToggled: ajustes.alternar("wifi_ligado", "wifi")
                Accessible.name: "Wi-Fi"
            }
        }
        Linha {
            primeira: !ajustes.sim("wifi_tem")
            visible: ajustes.sim("cabo_tem")
            nome: ajustes.t("Rede cabeada", "Wired network")
            detalhe: ajustes.sim("cabo_ligado") ? ajustes.t("Conectada", "Connected") : ajustes.t("Cabo desconectado", "Cable unplugged")
        }
        Linha {
            primeira: !ajustes.sim("wifi_tem") && !ajustes.sim("cabo_tem")
            abre: true
            nome: ajustes.t("Redes, senhas e VPN", "Networks, passwords and VPN")
            onAberto: ajustes.abrir("rede")
        }
    }
}
