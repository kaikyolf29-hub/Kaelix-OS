// Última tela: o visto desenhado num círculo e duas dicas curtas.
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: tela

    readonly property bool aqui: janela.passo === janela.telas.length - 1
    property real traco: 0

    onAquiChanged: if (aqui) desenho.restart()

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - janela.gu * 4, janela.gu * 30)
        spacing: Math.round(janela.gu * 0.9)

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.round(janela.gu * 5.5)
            Layout.preferredHeight: Math.round(janela.gu * 5.5)
            Rectangle {
                id: circulo
                anchors.fill: parent
                radius: width / 2
                color: janela.escuro ? "#2fa66a" : "#23915a"
                scale: 0
            }
            // O visto, desenhado da esquerda para a direita.
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "white"
                    strokeWidth: Math.max(3, janela.gu * 0.42)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: circulo.width * 0.29
                    startY: circulo.height * 0.52
                    PathLine {
                        x: circulo.width * (0.29 + 0.15 * Math.min(1, tela.traco * 2.2))
                        y: circulo.height * (0.52 + 0.15 * Math.min(1, tela.traco * 2.2))
                    }
                    PathLine {
                        x: circulo.width * (0.44 + 0.29 * Math.max(0, (tela.traco - 0.45) / 0.55))
                        y: circulo.height * (0.67 - 0.32 * Math.max(0, (tela.traco - 0.45) / 0.55))
                    }
                }
            }
        }

        Cabecalho {
            titulo: janela.t("Tudo pronto", "You're all set")
            texto: janela.t("Aproveite o Matsu. Se quiser mudar algo, é só abrir os Ajustes.",
                            "Enjoy Matsu. To change anything later, just open Settings.")
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Math.round(janela.gu * 0.35)
            Repeater {
                model: [
                    { icone: "matsu-busca-symbolic", texto: janela.t("Aperte a tecla Windows para abrir o menu e buscar qualquer coisa.", "Press the Windows key to open the menu and search for anything.") },
                    { icone: "matsu-ajuda-symbolic", texto: janela.t("No Terminal, \"matsu ajuda\" mostra tudo o que o comando do sistema faz.", "In the Terminal, \"matsu help\" shows everything the system command does.") }
                ]
                delegate: RowLayout {
                    required property var modelData
                    spacing: Math.round(janela.gu * 0.5)
                    Kirigami.Icon {
                        Layout.preferredWidth: Math.round(janela.gu * 1)
                        Layout.preferredHeight: Math.round(janela.gu * 1)
                        source: modelData.icone
                        fallback: "matsu-info-symbolic"
                        color: janela.frente
                        isMask: true
                        opacity: 0.7
                    }
                    Texto {
                        text: modelData.texto
                        opacity: 0.8
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: desenho
        PropertyAction { target: tela; property: "traco"; value: 0 }
        PropertyAction { target: circulo; property: "scale"; value: 0 }
        PauseAnimation { duration: 180 }
        NumberAnimation { target: circulo; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutBack }
        NumberAnimation { target: tela; property: "traco"; to: 1; duration: 420; easing.type: Easing.OutCubic }
    }
}
