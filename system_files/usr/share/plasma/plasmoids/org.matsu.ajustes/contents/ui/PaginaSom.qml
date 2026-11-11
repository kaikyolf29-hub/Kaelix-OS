// Som: volume e mudo; saídas e entradas no ajuste de som do KDE.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    Grupo {
        Linha {
            primeira: true
            nome: ajustes.t("Volume", "Volume")
            visible: ajustes.sim("vol_tem")
            Regulador {
                valor: ajustes.numero("vol")
                acao: "volume"
            }
        }
        Linha {
            visible: ajustes.sim("vol_tem")
            nome: ajustes.t("Sem som", "Mute")
            PlasmaComponents.Switch {
                checked: ajustes.sim("mudo")
                onToggled: {
                    ajustes.definir("mudo", checked ? "1" : "0");
                    ajustes.fazer("mudo");
                }
                Accessible.name: ajustes.t("Sem som", "Mute")
            }
        }
        Linha {
            primeira: !ajustes.sim("vol_tem")
            abre: true
            nome: ajustes.t("Saídas e entradas de som", "Sound outputs and inputs")
            detalhe: ajustes.t("Caixas de som, fones, microfone e o som de cada app.", "Speakers, headphones, microphone and per-app volume.")
            onAberto: ajustes.abrir("som")
        }
    }
}
