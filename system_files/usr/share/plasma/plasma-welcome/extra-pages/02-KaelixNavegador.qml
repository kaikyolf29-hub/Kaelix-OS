// Kaelix OS: tela de boas-vindas para instalar o Chrome, o Brave ou os dois.
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

    property bool instalando: false

    function instalar(qual) {
        instalando = true;
        estado.text = t("Instalando. Pode levar alguns minutos, e você pode continuar usando o computador.",
                        "Installing. It may take a few minutes, and you can keep using the computer.");
        Controller.runCommand("kaelix navegador " + qual, terminou);
    }

    property var terminou: (codigo, saida) => {
        instalando = false;
        if (codigo === 0) {
            estado.text = t("Pronto! Ele já é o navegador padrão e aparece na barra no lugar do Firefox, que fica guardado como reserva.",
                            "Done! It is now the default browser and takes Firefox's place on the bar. Firefox stays installed as a backup.");
        } else {
            estado.text = t("Não deu para instalar agora. Confira a internet e tente de novo aqui, ou rode: kaelix navegador",
                            "Could not install right now. Check the internet and try again here, or run: kaelix browser");
        }
    }

    heading: t("Escolha o seu navegador", "Pick your browser")
    description: t("O Firefox já vem instalado. Se preferir, instale o Google Chrome, o Brave ou os dois: o escolhido vira o padrão e fica na barra.",
                   "Firefox is already installed. If you prefer, install Google Chrome, Brave or both: your pick becomes the default and goes on the bar.")

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.largeSpacing
            QQC2.Button {
                text: "Google Chrome"
                enabled: !pagina.instalando
                onClicked: pagina.instalar("chrome")
            }
            QQC2.Button {
                text: "Brave"
                enabled: !pagina.instalando
                onClicked: pagina.instalar("brave")
            }
            QQC2.Button {
                text: pagina.t("Os dois", "Both")
                enabled: !pagina.instalando
                onClicked: pagina.instalar("os-dois")
            }
        }
        QQC2.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: pagina.instalando
            visible: pagina.instalando
        }
        QQC2.Label {
            id: estado
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Kirigami.Units.gridUnit * 28
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: ""
        }
    }
}
