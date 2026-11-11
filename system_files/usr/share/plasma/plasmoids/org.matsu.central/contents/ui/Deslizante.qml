// Bloco "Som" ou "Brilho" da central, como no vídeo: nome e número em cima,
// ícone e barra de arrastar embaixo.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Cartao {
    id: bloco

    property string icone: ""
    property string nome: ""
    property int valor: 0          // o que o sistema diz (0 a 100)
    property int minimo: 0
    property bool botaoClicavel: false

    signal mudou(int novo)
    signal iconeClicado()

    // Enquanto a pessoa arrasta, a barra é dela; quando solta, volta a seguir o sistema.
    onValorChanged: {
        if (!barra.pressed) {
            barra.value = valor;
        }
    }

    Timer {
        id: envio
        interval: 120
        onTriggered: bloco.mudou(Math.round(barra.value))
    }

    RowLayout {
        Layout.fillWidth: true

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: bloco.nome
            font.weight: Font.DemiBold
        }
        PlasmaComponents.Label {
            text: Math.round(barra.value) + "%"
            opacity: 0.75
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(Kirigami.Units.gridUnit * 0.55)

        MouseArea {
            implicitWidth: Kirigami.Units.iconSizes.small + 6
            implicitHeight: Kirigami.Units.iconSizes.small + 6
            enabled: bloco.botaoClicavel
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            Accessible.role: Accessible.Button
            Accessible.name: bloco.nome
            onClicked: bloco.iconeClicado()

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small
                height: width
                source: bloco.icone
                isMask: true
                color: Kirigami.Theme.textColor
            }
        }

        Trilho {
            id: barra
            Layout.fillWidth: true
            from: bloco.minimo
            to: 100
            stepSize: 1
            value: bloco.valor
            Accessible.name: bloco.nome
            onMoved: envio.restart()
        }
    }
}
