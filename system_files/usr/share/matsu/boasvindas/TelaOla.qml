// Primeira tela: o pinheiro do Matsu chegando, "Olá" em várias línguas (como o
// "hello" do Mac) e as boas-vindas com o nome do sistema.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: tela

    readonly property var olas: ["Olá", "Hello", "Hola", "Bonjour", "Ciao", "Hallo"]
    property int qual: 0

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - janela.gu * 4, janela.gu * 30)
        spacing: Math.round(janela.gu * 0.6)

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.round(janela.gu * 7)
            Layout.preferredHeight: Math.round(janela.gu * 7)
            Image {
                id: logo
                anchors.fill: parent
                source: "file:///usr/share/pixmaps/matsu-logo.svg"
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                smooth: true
                opacity: 0
                scale: 0.82
            }
        }

        // "Olá" grande, trocando de língua devagar.
        Item {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.8)
            Layout.preferredHeight: Math.round(janela.gu * 3.2)
            Texto {
                id: ola
                anchors.centerIn: parent
                text: tela.olas[tela.qual]
                font.pixelSize: Math.round(janela.gu * 2.8)
                font.weight: Font.DemiBold
                opacity: 0
            }
        }
        Cabecalho {
            id: textos
            titulo: janela.t("Bem-vindo ao ", "Welcome to ") + janela.nomeSistema
            texto: janela.t("Um sistema feito para jogar, criar e programar, com a sua cara. Em poucos passos fica tudo do seu jeito.",
                            "A system made for gaming, creating and coding, with your own look. A few steps and it is all set your way.")
            opacity: 0
        }
    }

    // A chegada: o logo cresce, depois o "Olá" e o texto aparecem.
    SequentialAnimation {
        running: true
        ParallelAnimation {
            NumberAnimation { target: logo; property: "opacity"; to: 1; duration: 520; easing.type: Easing.OutCubic }
            NumberAnimation { target: logo; property: "scale"; to: 1; duration: 720; easing.type: Easing.OutBack }
        }
        NumberAnimation { target: ola; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
        NumberAnimation { target: textos; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
    }

    Timer {
        interval: 2600
        repeat: true
        running: janela.passo === 0
        onTriggered: troca.restart()
    }
    SequentialAnimation {
        id: troca
        NumberAnimation { target: ola; property: "opacity"; to: 0; duration: 280 }
        ScriptAction { script: tela.qual = (tela.qual + 1) % tela.olas.length }
        NumberAnimation { target: ola; property: "opacity"; to: 1; duration: 380 }
    }
}
