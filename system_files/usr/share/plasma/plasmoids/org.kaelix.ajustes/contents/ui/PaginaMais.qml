// Mais ajustes: o que se mexe pouco abre direto a tela certa dos ajustes do KDE.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    Grupo {
        Repeater {
            model: [
                { kcm: "kcm_keyboard", nome: ajustes.t("Teclado", "Keyboard") },
                { kcm: "kcm_mouse", nome: "Mouse" },
                { kcm: "kcm_touchpad", nome: "Touchpad" },
                { kcm: "kcm_keys", nome: ajustes.t("Atalhos de teclado", "Keyboard shortcuts") },
                { kcm: "kcm_users", nome: ajustes.t("Usuários", "Users") },
                { kcm: "kcm_regionandlang", nome: ajustes.t("Idioma e região", "Language and region") },
                { kcm: "kcm_clock", nome: ajustes.t("Data e hora", "Date and time") },
                { kcm: "kcm_componentchooser", nome: ajustes.t("Apps padrão", "Default apps") },
                { kcm: "kcm_printer_manager", nome: ajustes.t("Impressoras", "Printers") }
            ]
            Linha {
                required property var modelData
                required property int index
                primeira: index === 0
                abre: true
                nome: modelData.nome
                onAberto: ajustes.abrir("kcm " + modelData.kcm)
            }
        }
    }

    Grupo {
        Linha {
            primeira: true
            abre: true
            nome: ajustes.t("Todos os ajustes do KDE", "All KDE settings")
            detalhe: ajustes.t("Para quem quer mexer em tudo.", "For those who want to tweak everything.")
            onAberto: ajustes.abrir("configuracoes")
        }
    }
}
