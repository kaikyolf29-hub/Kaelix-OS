// Matsu OS: tela de boas-vindas com o comando "matsu".
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import org.kde.plasma.welcome

Page {
    id: pagina

    readonly property bool pt: Qt.locale().name.indexOf("pt") === 0
    function t(portugues, ingles) {
        return pt ? portugues : ingles;
    }

    heading: t("Um comando para cuidar do sistema", "One command to look after the system")
    description: t("Abra o Terminal e digite matsu. As atualizações são assinadas e, se algo der errado, dá para voltar à versão anterior.",
                   "Open the Terminal and type matsu. Updates are signed and, if something goes wrong, you can go back to the previous version.")

    GridLayout {
        anchors.centerIn: parent
        columns: 2
        columnSpacing: Kirigami.Units.gridUnit
        rowSpacing: Kirigami.Units.largeSpacing

        Repeater {
            model: [
                ["matsu atualizar", pagina.t("Baixa a nova versão do sistema", "Downloads the new system version")],
                ["matsu voltar", pagina.t("Volta para a versão anterior", "Goes back to the previous version")],
                ["matsu drivers", pagina.t("Confere a placa de vídeo e o driver", "Checks the graphics card and driver")],
                ["matsu barra", pagina.t("Troca o jeito e o tamanho da barra", "Changes the bar style and size")],
                ["matsu navegador", pagina.t("Instala o Chrome ou o Brave", "Installs Chrome or Brave")],
                ["matsu ajuda", pagina.t("Mostra tudo o que o comando faz", "Shows everything the command does")]
            ]
            delegate: RowLayout {
                required property var modelData
                Layout.columnSpan: 2
                spacing: Kirigami.Units.gridUnit
                QQC2.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    font.family: "monospace"
                    font.bold: true
                    text: modelData[0]
                }
                QQC2.Label {
                    text: modelData[1]
                }
            }
        }
    }
}
