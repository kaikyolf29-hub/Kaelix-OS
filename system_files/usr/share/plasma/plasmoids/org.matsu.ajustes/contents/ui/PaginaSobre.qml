// Sobre o Matsu: a versão do sistema, os detalhes do computador e a atualização.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.gridUnit * 5
            implicitHeight: implicitWidth
            source: "matsu-logo"
        }
        Kirigami.Heading {
            Layout.alignment: Qt.AlignHCenter
            level: 2
            text: "Matsu @EDICAO@ OS"
            font.weight: Font.Bold
        }
    }

    Grupo {
        Repeater {
            // As linhas do "matsu versao" (sem a primeira, que é o nome).
            model: ajustes.versao.split("\n").slice(1).filter(l => l.indexOf(":") > 0)
            Linha {
                required property string modelData
                required property int index
                primeira: index === 0
                nome: modelData.substring(0, modelData.indexOf(":")).trim()
                PlasmaComponents.Label {
                    text: modelData.substring(modelData.indexOf(":") + 1).trim()
                    opacity: 0.75
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                }
            }
        }
    }

    Grupo {
        Linha {
            primeira: true
            abre: true
            nome: ajustes.t("Atualizações e novidades", "Updates and what's new")
            detalhe: ajustes.t("Veja o que mudou nesta versão e procure a próxima.", "See what changed in this version and check for the next one.")
            onAberto: ajustes.abrir("atualizacoes")
        }
        Linha {
            abre: true
            nome: ajustes.t("Detalhes do computador", "Computer details")
            detalhe: ajustes.t("Processador, memória, placa de vídeo e mais.", "Processor, memory, graphics card and more.")
            onAberto: ajustes.abrir("sobre")
        }
    }
}
