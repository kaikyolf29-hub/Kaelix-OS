// Mostra um período (mês, semana, dia) e, quando ele muda, o novo entra deslizando
// pelo lado e empurra o velho (para a esquerda quando vai para a frente no tempo).
// Duas cópias do mesmo componente se revezam; cada uma recebe o seu "periodo" (Date).
//   Carrossel { componente: Component { VisaoMes {} }; valor: inicioDoMes }
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: carrossel

    property Component componente
    property var valor
    // Quanto o velho anda (1 = a largura toda, como um empurrão).
    property real empurrao: 1
    readonly property Item atual: ativo === 0 ? a.item : b.item

    property int ativo: 0
    property var valorA: null
    property var valorB: null
    property var ultimo: null

    clip: true
    Component.onCompleted: {
        valorA = valor;
        ultimo = valor;
    }

    function trocar() {
        if (!ultimo) {
            valorA = valor;
            ultimo = valor;
            return;
        }
        if (!valor || valor.getTime() === ultimo.getTime())
            return;
        var direcao = valor.getTime() > ultimo.getTime() ? 1 : -1;
        ultimo = valor;
        if (anim.running)
            anim.complete();
        var entra = ativo === 0 ? b : a;
        var sai = ativo === 0 ? a : b;
        if (ativo === 0)
            valorB = valor;
        else
            valorA = valor;
        entraX.target = entra;
        saiX.target = sai;
        saiOpacidade.target = sai;
        entraX.from = direcao * width;
        saiX.to = -direcao * width * empurrao;
        entra.x = entraX.from;
        entra.opacity = 1;
        entra.visible = true;
        ativo = 1 - ativo;
        anim.restart();
    }
    onValorChanged: trocar()

    Loader {
        id: a
        width: carrossel.width
        height: carrossel.height
        active: carrossel.valorA !== null
        sourceComponent: carrossel.componente
        Binding {
            target: a.item
            property: "periodo"
            value: carrossel.valorA
            when: a.status === Loader.Ready && carrossel.valorA !== null
        }
    }
    Loader {
        id: b
        width: carrossel.width
        height: carrossel.height
        visible: false
        active: carrossel.valorB !== null
        sourceComponent: carrossel.componente
        Binding {
            target: b.item
            property: "periodo"
            value: carrossel.valorB
            when: b.status === Loader.Ready && carrossel.valorB !== null
        }
    }

    ParallelAnimation {
        id: anim
        NumberAnimation {
            id: entraX
            property: "x"
            to: 0
            duration: 340
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: saiX
            property: "x"
            from: 0
            duration: 340
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: saiOpacidade
            property: "opacity"
            from: 1
            to: 0.2
            duration: 340
        }
        onFinished: {
            if (saiX.target) {
                saiX.target.visible = false;
                saiX.target.x = 0;
                saiX.target.opacity = 1;
            }
        }
    }
}
