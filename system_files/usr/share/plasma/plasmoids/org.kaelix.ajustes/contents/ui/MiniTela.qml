// Área de trabalho em miniatura: papel de parede, a barra no estilo escolhido
// e (se pedir) uma janela, nas cores do tema claro ou escuro.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: tela

    property bool escuro: true
    property string estilo: "fusao"
    property bool comJanela: false
    readonly property color vidro: escuro ? Qt.rgba(0.12, 0.14, 0.26, 0.85) : Qt.rgba(0.96, 0.97, 1, 0.86)
    readonly property color borda: escuro ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.9)

    anchors.fill: parent

    Kirigami.ShadowedImage {
        anchors.fill: parent
        radius: Math.round(Kirigami.Units.gridUnit * 0.3)
        source: Qt.resolvedUrl("../images/tema-" + (tela.escuro ? "escuro" : "claro") + ".png")
        fillMode: Image.PreserveAspectCrop
    }

    // Uma janela no meio, para ver as cores do tema.
    Rectangle {
        visible: tela.comJanela
        x: Math.round(parent.width * 0.2)
        y: Math.round(parent.height * 0.16)
        width: Math.round(parent.width * 0.6)
        height: Math.round(parent.height * 0.52)
        radius: 4
        color: tela.escuro ? "#262c4c" : "#f0f3fc"
        border.width: 1
        border.color: tela.escuro ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)

        Row {
            x: 5; y: 5
            spacing: 3
            Repeater {
                model: 3
                Rectangle { width: 4; height: 4; radius: 2; color: tela.escuro ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(0, 0, 0, 0.25) }
            }
        }
        Rectangle {
            x: 6; y: 14
            width: parent.width * 0.3; height: 4; radius: 2
            color: tela.escuro ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.45)
        }
        Rectangle {
            x: 6; y: 22
            width: parent.width * 0.55; height: 3; radius: 1.5
            color: tela.escuro ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.2)
        }
        Rectangle {
            x: 6; y: 28
            width: parent.width * 0.45; height: 3; radius: 1.5
            color: tela.escuro ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.2)
        }
        Rectangle {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 6
            width: parent.width * 0.22; height: 7; radius: 3.5
            color: Kirigami.Theme.highlightColor
        }
    }

    // Fusão: três ilhas flutuando embaixo.
    Item {
        visible: tela.estilo === "fusao"
        anchors.fill: parent
        readonly property real h: Math.round(parent.height * 0.1)
        readonly property real y0: parent.height - h - Math.round(parent.height * 0.045)
        Rectangle { x: parent.width * 0.04; y: parent.y0; width: parent.width * 0.12; height: parent.h; radius: height * 0.4; color: tela.vidro; border.color: tela.borda }
        Rectangle { x: parent.width * 0.3; y: parent.y0; width: parent.width * 0.4; height: parent.h; radius: height * 0.4; color: tela.vidro; border.color: tela.borda }
        Rectangle { x: parent.width * 0.72; y: parent.y0; width: parent.width * 0.24; height: parent.h; radius: height * 0.4; color: tela.vidro; border.color: tela.borda }
    }

    // Mac: barra fina em cima e a doca embaixo.
    Item {
        visible: tela.estilo === "mac"
        anchors.fill: parent
        Rectangle { x: 0; y: 0; width: parent.width; height: Math.round(parent.height * 0.065); color: tela.vidro }
        Rectangle {
            x: parent.width * 0.27; width: parent.width * 0.46
            height: Math.round(parent.height * 0.12)
            y: parent.height - height - Math.round(parent.height * 0.035)
            radius: height * 0.3; color: tela.vidro; border.color: tela.borda
        }
    }

    // Windows: uma barra só embaixo, de ponta a ponta.
    Rectangle {
        visible: tela.estilo === "windows"
        x: 0
        width: parent.width
        height: Math.round(parent.height * 0.1)
        y: parent.height - height
        color: tela.vidro
    }
}
