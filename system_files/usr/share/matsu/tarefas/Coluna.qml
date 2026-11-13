// Título de uma coluna da lista de processos, como no Windows: o total em cima
// e o nome embaixo, com a linha fina à esquerda. Clicar ordena por ela; a
// setinha em cima mostra o sentido (aparece descendo e vira girando).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: cabeca

    property string titulo: ""
    property string total: ""
    property string coluna: ""
    property bool separador: true
    property int alinhamento: Text.AlignRight
    readonly property bool ativa: pagina.ordem === cabeca.coluna

    implicitHeight: parent ? parent.height : janela.gu * 2.8
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.ColumnHeader
    Accessible.name: titulo
    onClicked: pagina.ordenar(cabeca.coluna)

    Rectangle {
        anchors.fill: parent
        color: janela.tinta(cabeca.pressed ? 0.07 : (cabeca.containsMouse ? 0.04 : 0))
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }
    Rectangle {
        visible: cabeca.separador
        width: 1
        height: parent.height
        color: janela.tinta(0.07)
    }

    Kirigami.Icon {
        // Como no Windows: a setinha da ordem fica no meio, em cima do título.
        anchors.horizontalCenter: parent.horizontalCenter
        y: cabeca.ativa ? 1 : -4
        width: 10
        height: 10
        visible: opacity > 0
        source: "matsu-seta-symbolic"
        isMask: true
        color: janela.frente
        opacity: cabeca.ativa ? 0.7 : 0
        rotation: pagina.crescente ? -90 : 90
        Behavior on rotation {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * (cabeca.alinhamento === Text.AlignLeft ? 0.75 : 0.6))
        anchors.rightMargin: Math.round(janela.gu * 0.6)
        anchors.topMargin: Math.round(janela.gu * 0.45)
        anchors.bottomMargin: Math.round(janela.gu * 0.35)
        spacing: 0

        Texto {
            Layout.fillWidth: true
            horizontalAlignment: cabeca.alinhamento
            text: cabeca.total.length > 0 ? cabeca.total : " "
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
            font.features: { "tnum": 1 }
        }
        Item {
            Layout.fillHeight: true
        }
        Texto {
            Layout.fillWidth: true
            horizontalAlignment: cabeca.alinhamento
            text: cabeca.titulo
            elide: Text.ElideRight
            opacity: cabeca.ativa ? 0.95 : 0.72
            font.weight: cabeca.ativa ? Font.DemiBold : Font.Normal
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
        }
    }
}
