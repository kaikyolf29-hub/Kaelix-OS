// Barra de arrastar ligada a um ajuste do sistema (volume, brilho): mostra o
// valor do sistema e manda o novo valor enquanto a pessoa arrasta.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

RowLayout {
    id: regulador

    property int valor: 0
    property int minimo: 0
    property string acao: ""

    spacing: Kirigami.Units.smallSpacing * 2
    Layout.preferredWidth: Kirigami.Units.gridUnit * 14

    Trilho {
        id: trilho
        Layout.fillWidth: true
        from: regulador.minimo
        to: 100
        stepSize: 1
        value: regulador.valor
        Accessible.name: regulador.acao
        onMoved: envio.restart()
    }
    PlasmaComponents.Label {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
        horizontalAlignment: Text.AlignRight
        text: Math.round(trilho.value) + "%"
        font.features: { "tnum": 1 }
        opacity: 0.75
    }
    // Não manda um comando por pixel: espera um instante.
    Timer {
        id: envio
        interval: 120
        onTriggered: ajustes.fazer(regulador.acao + " " + Math.round(trilho.value))
    }
    Binding {
        target: trilho
        property: "value"
        value: regulador.valor
        when: !trilho.pressed && !envio.running
    }
}
