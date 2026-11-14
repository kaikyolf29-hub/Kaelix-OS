// Régua com um nome em cada ponta ("Pequena … Grande", "Pouca … Muita"), como
// as do Mac. Avisa o valor novo quando a pessoa solta a bolinha (ou depois de
// um instante parada no teclado), para não mandar um comando por pixel.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

RowLayout {
    id: regua

    property real valor: 0
    property real de: 0
    property real ate: 100
    property real passo: 1
    property string esquerda: ""
    property string direita: ""
    property string nome: ""

    signal escolhido(real valor)

    spacing: Kirigami.Units.smallSpacing * 2
    Layout.preferredWidth: Kirigami.Units.gridUnit * 16

    PlasmaComponents.Label {
        text: regua.esquerda
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.65
    }
    Trilho {
        id: trilho
        Layout.fillWidth: true
        from: regua.de
        to: regua.ate
        stepSize: regua.passo
        value: regua.valor
        Accessible.name: regua.nome
        onPressedChanged: {
            if (!pressed) {
                espera.stop();
                regua.escolhido(value);
            }
        }
        onMoved: {
            if (!pressed) {
                espera.restart();
            }
        }
    }
    PlasmaComponents.Label {
        text: regua.direita
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.65
    }
    Timer {
        id: espera
        interval: 450
        onTriggered: regua.escolhido(trilho.value)
    }
    Binding {
        target: trilho
        property: "value"
        value: regua.valor
        when: !trilho.pressed && !espera.running
    }
}
