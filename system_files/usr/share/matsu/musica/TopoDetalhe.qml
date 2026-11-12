// O topo de um álbum, artista ou playlist: o "voltar", a capa grande (com sombra)
// e, ao lado, o tipo, o nome, o detalhe e os botões (que vêm de quem usa).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: topo

    property string voltar: ""
    property string tipo: ""
    property string titulo: ""
    property string subtitulo: ""
    property bool subtituloClicavel: false
    property string detalhe: ""
    property Component capa: null
    default property alias acoes: linhaAcoes.data

    signal voltarClicado()
    signal subtituloClicado()

    readonly property bool estreito: width < janela.gu * 30
    readonly property int lado: Math.round(janela.gu * (estreito ? 7.5 : 11))
    implicitHeight: coluna.implicitHeight + Math.round(janela.gu * 1.6)

    ColumnLayout {
        id: coluna
        x: Math.round(janela.gu * 1.6)
        y: Math.round(janela.gu * 0.7)
        width: parent.width - 2 * x
        spacing: Math.round(janela.gu * 0.8)

        Botao {
            Layout.leftMargin: -Math.round(janela.gu * 0.5)
            texto: topo.voltar
            icone: "matsu-voltar-symbolic"
            onClicado: topo.voltarClicado()
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 1.4)
            Loader {
                Layout.preferredWidth: topo.lado
                Layout.preferredHeight: topo.lado
                Layout.alignment: Qt.AlignTop
                sourceComponent: topo.capa
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                spacing: Math.round(janela.gu * 0.2)
                Texto {
                    text: topo.tipo
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                    opacity: 0.6
                }
                Texto {
                    Layout.fillWidth: true
                    text: topo.titulo
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * (topo.estreito ? 1.6 : 2.2)
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Texto {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: topo.subtitulo
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    opacity: areaSub.containsMouse ? 1 : 0.85
                    MouseArea {
                        id: areaSub
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.min(parent.width, parent.contentWidth)
                        enabled: topo.subtituloClicavel
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: topo.subtituloClicado()
                    }
                }
                Texto {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: topo.detalhe
                    opacity: 0.62
                    elide: Text.ElideRight
                }
                RowLayout {
                    id: linhaAcoes
                    Layout.topMargin: Math.round(janela.gu * 0.6)
                    spacing: Math.round(janela.gu * 0.4)
                }
            }
        }
    }
}
