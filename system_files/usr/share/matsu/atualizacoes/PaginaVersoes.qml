// Todas as versões: uma sanfona para cada (a mais nova em cima), com a data, o
// resumo e o que mudou. A versão deste computador leva a etiqueta "Sua versão".
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    // A que abre sozinha: a pedida (27.1 nos argumentos) ou a deste computador.
    readonly property string aberta: janela.versaoAberta || (janela.dados ? janela.dados.versao : "")
    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    Flickable {
        id: rolagem
        anchors.fill: parent
        contentWidth: width
        contentHeight: coluna.implicitHeight + 2 * pagina.margem
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        QQC2.ScrollBar.vertical: BarraRolagem {}

        ColumnLayout {
            id: coluna
            width: Math.min(rolagem.width - 2 * pagina.margem, Math.round(janela.gu * 48))
            x: Math.round((rolagem.width - width) / 2)
            y: pagina.margem
            spacing: Math.round(janela.gu * 0.6)

            Texto {
                Layout.fillWidth: true
                text: janela.t("Todas as versões", "All versions")
                font.pixelSize: Math.round(janela.gu * 1.3)
                font.weight: Font.DemiBold
            }
            Texto {
                Layout.fillWidth: true
                Layout.bottomMargin: Math.round(janela.gu * 0.4)
                text: janela.t("Uma edição por ano (27 é a de 2027) e atualizações menores durante o ano: 27.1, 27.2...",
                               "One edition a year (27 is 2027's) and smaller updates during the year: 27.1, 27.2...")
                opacity: 0.65
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: janela.versoes
                delegate: Sanfona {
                    id: sanfona
                    required property var modelData
                    required property int index
                    readonly property bool sua: janela.dados !== null && modelData.versao === janela.dados.versao
                    Layout.fillWidth: true
                    titulo: janela.t("Versão ", "Version ") + modelData.titulo
                    icone: sua ? "matsu-certo-symbolic" : ""
                    aberta: modelData.versao === pagina.aberta || (pagina.aberta === "" && index === 0)
                    opacity: 0
                    Component.onCompleted: entrada.start()
                    NumberAnimation {
                        id: entrada
                        target: sanfona
                        property: "opacity"
                        to: 1
                        duration: 300
                        easing.type: Easing.OutCubic
                    }

                    Flow {
                        width: parent.width
                        spacing: Math.round(janela.gu * 0.4)
                        visible: sanfona.sua || sanfona.modelData.data !== ""
                        Rectangle {
                            visible: sanfona.sua
                            width: etiquetaSua.implicitWidth + Math.round(janela.gu * 1.1)
                            height: Math.round(janela.gu * 1.5)
                            radius: height / 2
                            color: janela.destaque
                            Texto {
                                id: etiquetaSua
                                anchors.centerIn: parent
                                text: janela.t("Sua versão", "Your version")
                                color: janela.sobreDestaque
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.weight: Font.DemiBold
                            }
                        }
                        Rectangle {
                            visible: sanfona.modelData.data !== ""
                            width: etiquetaData.implicitWidth + Math.round(janela.gu * 1.1)
                            height: Math.round(janela.gu * 1.5)
                            radius: height / 2
                            color: janela.tinta(0.07)
                            Texto {
                                id: etiquetaData
                                anchors.centerIn: parent
                                text: sanfona.modelData.data
                                opacity: 0.8
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                        }
                    }
                    Texto {
                        width: parent.width
                        visible: text !== ""
                        text: sanfona.modelData.resumo
                        opacity: 0.7
                        wrapMode: Text.WordWrap
                    }
                    Repeater {
                        model: sanfona.modelData.itens
                        delegate: Row {
                            required property var modelData
                            width: parent.width
                            spacing: Math.round(janela.gu * 0.6)
                            Rectangle {
                                y: Math.round(textoItem.font.pixelSize * 0.55)
                                width: 6
                                height: 6
                                radius: 3
                                color: janela.tinta(0.45)
                            }
                            Texto {
                                id: textoItem
                                width: parent.width - 6 - parent.spacing
                                textFormat: Text.StyledText
                                text: (modelData.assunto ? "<b>" + pagina.esc(modelData.assunto) + ".</b> " : "") + pagina.esc(modelData.texto)
                                wrapMode: Text.WordWrap
                                opacity: 0.88
                            }
                        }
                    }
                }
            }
        }
    }
}
