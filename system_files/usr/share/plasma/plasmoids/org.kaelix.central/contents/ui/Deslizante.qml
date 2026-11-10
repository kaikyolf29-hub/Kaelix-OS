// Uma linha da central de controle com ícone, barra de arrastar e o número.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

RowLayout {
    id: linha

    property string icone: ""
    property string nome: ""
    property int valor: 0          // o que o sistema diz (0 a 100)
    property int minimo: 0
    property bool botaoClicavel: false

    signal mudou(int novo)
    signal iconeClicado()

    spacing: Kirigami.Units.smallSpacing

    // Enquanto a pessoa arrasta, a barra é dela; quando solta, volta a seguir o sistema.
    onValorChanged: {
        if (!barra.pressed) {
            barra.value = valor;
        }
    }

    Timer {
        id: envio
        interval: 120
        onTriggered: linha.mudou(Math.round(barra.value))
    }

    PlasmaComponents.ToolButton {
        icon.name: linha.icone
        enabled: linha.botaoClicavel
        opacity: 1
        Accessible.name: linha.nome
        onClicked: linha.iconeClicado()
    }

    PlasmaComponents.Slider {
        id: barra
        Layout.fillWidth: true
        from: linha.minimo
        to: 100
        stepSize: 1
        value: linha.valor
        Accessible.name: linha.nome
        onMoved: envio.restart()
    }

    PlasmaComponents.Label {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 2
        horizontalAlignment: Text.AlignRight
        text: Math.round(barra.value) + "%"
        opacity: 0.8
    }
}
