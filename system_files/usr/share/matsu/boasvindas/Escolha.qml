// Um cartão para escolher (o tema, a barra, o navegador): o desenho em cima, o
// nome e uma linha embaixo. O escolhido ganha a borda na cor de destaque e o
// visto no canto; "ocupado" mostra a rodinha enquanto o sistema troca.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

CartaoClicavel {
    id: escolha

    property string nome: ""
    property string texto: ""
    property bool escolhida: false
    property bool ocupado: false
    // O desenho em cima (um Component, para não brigar com o conteúdo do cartão).
    property Component arte: null
    property real alturaArte: Math.round(janela.gu * 6.5)

    implicitHeight: coluna.implicitHeight + Math.round(janela.gu * 1.2)
    Accessible.name: nome
    Accessible.checkable: true
    Accessible.checked: escolhida

    ColumnLayout {
        id: coluna
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Math.round(janela.gu * 0.6)
        spacing: Math.round(janela.gu * 0.45)

        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: escolha.alturaArte
            active: escolha.arte !== null
            visible: active
            sourceComponent: escolha.arte
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.35)
            Texto {
                Layout.fillWidth: true
                text: escolha.nome
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Girando {
                visible: escolha.ocupado
                Layout.preferredWidth: Math.round(janela.gu * 0.9)
                Layout.preferredHeight: Math.round(janela.gu * 0.9)
            }
        }
        Texto {
            Layout.fillWidth: true
            visible: escolha.texto !== ""
            text: escolha.texto
            wrapMode: Text.WordWrap
            opacity: 0.65
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }

    // A borda do escolhido, por cima de tudo.
    Rectangle {
        anchors.fill: parent
        radius: escolha.raio
        color: "transparent"
        border.width: escolha.escolhida ? 2 : 0
        border.color: janela.destaque
        Behavior on border.width {
            NumberAnimation {
                duration: 160
            }
        }
    }
    // O visto, que pula ao escolher.
    Rectangle {
        id: visto
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Math.round(janela.gu * 0.45)
        width: Math.round(janela.gu * 1.15)
        height: width
        radius: width / 2
        color: janela.destaque
        scale: escolha.escolhida ? 1 : 0
        Behavior on scale {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutBack
            }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.62)
            height: width
            source: "matsu-certo-symbolic"
            color: janela.sobreDestaque
            isMask: true
        }
    }
}
