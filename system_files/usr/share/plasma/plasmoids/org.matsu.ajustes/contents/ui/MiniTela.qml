// Área de trabalho em miniatura: papel de parede, a barra no estilo escolhido
// e (se pedir) uma janela, nas cores do tema claro ou escuro.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: tela

    property bool escuro: true
    property string estilo: "fusao"
    property bool comJanela: false
    // Na fusão: onde ficam a pílula da busca e o botão do menu.
    property string busca: "esquerda"
    property string menu: "esquerda"
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
        color: tela.escuro ? "#202022" : "#f3f3f5"
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

    // Fusão: três ilhas flutuando embaixo. A da esquerda tem o logo (e a busca,
    // se ela estiver junto do menu); com o menu no meio, ela some.
    Item {
        id: fusao
        visible: tela.estilo === "fusao"
        anchors.fill: parent
        readonly property real h: Math.round(parent.height * 0.1)
        readonly property real y0: parent.height - h - Math.round(parent.height * 0.045)
        readonly property bool menuNoMeio: tela.menu === "meio"
        readonly property bool buscaNoMeio: tela.busca === "meio" || (menuNoMeio && tela.busca !== "nao")
        readonly property bool buscaNaEsquerda: !menuNoMeio && tela.busca === "esquerda"
        readonly property color peca: tela.escuro ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(0.11, 0.13, 0.25, 0.22)
        readonly property real meioX: parent.width * (menuNoMeio || buscaNoMeio ? 0.24 : 0.3)
        readonly property real meioW: parent.width * (menuNoMeio || buscaNoMeio ? 0.46 : 0.4)

        Rectangle {
            id: ilhaEsquerda
            visible: !fusao.menuNoMeio
            x: parent.width * 0.04; y: fusao.y0
            width: parent.width * (fusao.buscaNaEsquerda ? 0.15 : 0.06); height: fusao.h
            radius: height * 0.4; color: tela.vidro; border.color: tela.borda
            Rectangle { x: parent.height * 0.25; anchors.verticalCenter: parent.verticalCenter; width: parent.height * 0.5; height: width; radius: width * 0.3; color: Kirigami.Theme.highlightColor }
            Rectangle { visible: fusao.buscaNaEsquerda; x: parent.height * 0.95; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - parent.height * 0.25; height: parent.height * 0.42; radius: height / 2; color: fusao.peca }
        }
        Rectangle {
            x: fusao.meioX; y: fusao.y0; width: fusao.meioW; height: fusao.h
            radius: height * 0.4; color: tela.vidro; border.color: tela.borda
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.height * 0.25
                spacing: parent.height * 0.2
                Rectangle { visible: fusao.menuNoMeio; width: fusao.h * 0.5; height: width; radius: width * 0.3; color: Kirigami.Theme.highlightColor; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { visible: fusao.buscaNoMeio; width: fusao.meioW * 0.26; height: fusao.h * 0.42; radius: height / 2; color: fusao.peca; anchors.verticalCenter: parent.verticalCenter }
                Repeater {
                    model: 5
                    Rectangle { width: fusao.h * 0.48; height: width; radius: width * 0.28; color: fusao.peca; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        Rectangle { x: parent.width * 0.72; y: fusao.y0; width: parent.width * 0.24; height: fusao.h; radius: height * 0.4; color: tela.vidro; border.color: tela.borda }
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
