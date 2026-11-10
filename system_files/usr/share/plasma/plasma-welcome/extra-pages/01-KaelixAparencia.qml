// Kaelix OS: tela de boas-vindas para escolher o tema e o jeito da barra.
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

    heading: t("Deixe o Kaelix com a sua cara", "Make Kaelix yours")
    description: t("Escolha o tema e o jeito da barra. Dá para trocar depois, quando quiser, nos Ajustes do Kaelix (a engrenagem na barra), junto com a cor do vidro e o papel de parede.",
                   "Pick the theme and the bar style. You can change them later in Kaelix Settings (the gear in the bar), along with the glass color and the wallpaper.")

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            Layout.alignment: Qt.AlignHCenter
            level: 3
            text: pagina.t("Tema", "Theme")
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.largeSpacing
            QQC2.Button {
                text: pagina.t("Escuro", "Dark")
                icon.name: "weather-clear-night"
                onClicked: Controller.runCommand("plasma-apply-lookandfeel -a org.kaelix.escuro.desktop")
            }
            QQC2.Button {
                text: pagina.t("Claro", "Light")
                icon.name: "weather-clear"
                onClicked: Controller.runCommand("plasma-apply-lookandfeel -a org.kaelix.claro.desktop")
            }
        }

        Kirigami.Heading {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.gridUnit
            level: 3
            text: pagina.t("Barra", "Bar")
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.largeSpacing
            QQC2.Button {
                text: pagina.t("Fusão: três ilhas embaixo", "Fusion: three islands at the bottom")
                icon.name: "kaelix-logo"
                onClicked: Controller.runCommand("kaelix barra fusao")
            }
            QQC2.Button {
                text: pagina.t("Mac: barra no topo e doca", "Mac: top bar and dock")
                onClicked: Controller.runCommand("kaelix barra mac")
            }
            QQC2.Button {
                text: pagina.t("Windows: uma barra embaixo", "Windows: one bar at the bottom")
                onClicked: Controller.runCommand("kaelix barra windows")
            }
        }
        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.smallSpacing
            opacity: 0.7
            text: pagina.t("Os apps que você fixou na barra continuam nela.", "The apps you pinned stay on the bar.")
        }
    }
}
