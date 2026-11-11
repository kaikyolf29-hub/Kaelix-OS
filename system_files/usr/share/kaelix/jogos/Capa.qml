// A capa de um jogo, em pé (a mesma da biblioteca da Steam), com o nome e as
// horas embaixo. Com o mouse em cima, ela sobe um pouco, ganha sombra e mostra
// o botão de jogar. Sem a capa (jogo novo, ainda sem imagem), desenha uma no
// jeito do Kaelix com o nome do jogo.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: capa

    property var jogo: ({})
    property bool legenda: true

    signal abrir()
    signal jogar()

    readonly property bool sobre: area.containsMouse || botaoJogar.containsMouse
    implicitWidth: Math.round(janela.gu * 8)
    implicitHeight: figura.height + (legenda ? textos.implicitHeight + Math.round(janela.gu * 0.45) : 0)

    // Cores da capa de reserva, tiradas do nome (sempre as mesmas para o mesmo jogo).
    readonly property var paletas: [["#f0609e", "#6d3fd8"], ["#45d0c1", "#2a5bd7"], ["#f5b330", "#e0506e"],
                                    ["#8fa2ff", "#b0408f"], ["#7fcf6a", "#1f8f86"], ["#b18cf5", "#3a3f9e"]]
    readonly property var paleta: {
        var n = 0;
        var nome = String(jogo.nome || "");
        for (var i = 0; i < nome.length; i++)
            n = (n * 31 + nome.charCodeAt(i)) % 9973;
        return paletas[n % paletas.length];
    }

    Item {
        id: figura
        width: parent.width
        height: Math.round(width * 1.5)
        y: capa.sobre ? -Math.round(janela.gu * 0.25) : 0
        Behavior on y {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }

        // Reserva: degradê com as iniciais grandes e o nome embaixo.
        Rectangle {
            anchors.fill: parent
            visible: imagem.status !== Image.Ready
            radius: Math.round(janela.gu * 0.5)
            gradient: Gradient {
                GradientStop { position: 0; color: capa.paleta[0] }
                GradientStop { position: 1; color: capa.paleta[1] }
            }
            Texto {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -parent.height * 0.08
                text: {
                    var p = String(capa.jogo.nome || "?").replace(/[^A-Za-z0-9\u00C0-\u024F ]/g, "").split(" ").filter(function (s) {
                        return s.length > 0;
                    });
                    return p.length > 1 ? (p[0][0] + p[1][0]).toUpperCase() : String(p[0] || "?").slice(0, 2).toUpperCase();
                }
                color: "#ffffff"
                opacity: 0.92
                font.pixelSize: Math.round(parent.width * 0.3)
                font.weight: Font.Bold
                font.letterSpacing: -1
            }
            Texto {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Math.round(janela.gu * 0.6)
                text: capa.jogo.nome || ""
                color: "#ffffff"
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.weight: Font.DemiBold
            }
        }
        ImagemRedonda {
            id: imagem
            anchors.fill: parent
            source: capa.jogo.capa ? janela.arquivo(capa.jogo.capa) : ""
            sombra: capa.sobre ? 1 : 0.35
            Behavior on sombra {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                }
            }
        }
        // Brilho fino na borda, para a capa não "vazar" no vidro escuro.
        Rectangle {
            anchors.fill: parent
            radius: Math.round(janela.gu * 0.5)
            color: "transparent"
            border.width: 1
            border.color: capa.sobre ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, janela.escuro ? 0.1 : 0.25)
            Behavior on border.color {
                ColorAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
        // Atualizando ou baixando pela Steam.
        Rectangle {
            visible: capa.jogo.pronto === false
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Math.round(janela.gu * 0.4)
            radius: height / 2
            height: Math.round(janela.gu * 1.2)
            width: aviso.implicitWidth + Math.round(janela.gu * 0.9)
            color: Qt.rgba(0.08, 0.08, 0.09, 0.82)
            Texto {
                id: aviso
                anchors.centerIn: parent
                text: janela.t("Atualizando", "Updating")
                color: "#ffffff"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: capa.abrir()
            activeFocusOnTab: true
            Keys.onReturnPressed: capa.abrir()
            Keys.onSpacePressed: capa.abrir()
            Accessible.role: Accessible.Button
            Accessible.name: capa.jogo.nome || ""
        }
        // Foco do teclado.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Math.round(janela.gu * 0.5) + 3
            color: "transparent"
            border.width: area.activeFocus ? 2 : 0
            border.color: janela.frente
        }

        // Botão de jogar, redondo, no canto de baixo (aparece com o mouse).
        MouseArea {
            id: botaoJogar
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(janela.gu * 0.5)
            width: Math.round(janela.gu * 2.3)
            height: width
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            visible: capa.jogo.pronto !== false
            opacity: capa.sobre ? 1 : 0
            scale: capa.sobre ? (pressed ? 0.92 : (containsMouse ? 1.08 : 1)) : 0.6
            onClicked: capa.jogar()
            Accessible.role: Accessible.Button
            Accessible.name: janela.t("Jogar", "Play") + " " + (capa.jogo.nome || "")
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutBack
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#ffffff"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.12)
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                width: Math.round(parent.width * 0.48)
                height: width
                source: "kaelix-jogar-symbolic"
                isMask: true
                color: "#141416"
            }
            QQC2.ToolTip.visible: containsMouse
            QQC2.ToolTip.text: janela.t("Jogar", "Play")
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }

    ColumnLayout {
        id: textos
        visible: capa.legenda
        y: figura.height + Math.round(janela.gu * 0.45)
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 1
        Texto {
            Layout.fillWidth: true
            text: capa.jogo.nome || ""
            elide: Text.ElideRight
            font.weight: Font.DemiBold
        }
        Texto {
            Layout.fillWidth: true
            text: janela.horas(capa.jogo.minutos)
            elide: Text.ElideRight
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.6
        }
    }
}
