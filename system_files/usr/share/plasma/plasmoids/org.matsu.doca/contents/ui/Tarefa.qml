// Um app na doca, do tamanho normal (na barra): o ícone e, embaixo, o
// pontinho de aberto (o app em uso ganha um traço). Quem recebe o mouse é a
// doca inteira (main.qml); aqui é só o desenho.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: tarefa

    property var doca
    property int numero: 0
    property var icone
    property string nome
    property bool aberto: false
    property bool ativo: false
    property bool pedindo: false
    // Abrindo (o pulo do Mac): quem desenha o pulo é a janela da ampliação.
    property bool pulando: false
    property bool arrastado: false
    property bool escondido: false

    readonly property rect r: doca.caixa(doca.inicioDe(numero), 0, doca.celula, doca.espessura, doca.comprimento, doca.espessura)
    x: r.x
    y: r.y
    width: r.width
    height: r.height

    Accessible.role: Accessible.Button
    Accessible.name: nome

    // O app que está sendo arrastado para mudar de lugar fica mais claro.
    opacity: escondido ? 0 : (arrastado ? 0.55 : 1)
    Behavior on opacity {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Kirigami.Icon {
        readonly property rect r: tarefa.doca.caixa((tarefa.doca.celula - tarefa.doca.tamanhoIcone) / 2, tarefa.doca.margemIcone,
                                                    tarefa.doca.tamanhoIcone, tarefa.doca.tamanhoIcone, tarefa.width, tarefa.doca.espessura)
        x: Math.round(r.x)
        y: Math.round(r.y)
        width: tarefa.doca.tamanhoIcone
        height: tarefa.doca.tamanhoIcone
        source: tarefa.icone
        roundToIconSize: false
    }

    Indicador {
        doca: tarefa.doca
        centro: tarefa.doca.celula / 2
        total: tarefa.width
        fundo: tarefa.doca.espessura
        aberto: tarefa.aberto
        ativo: tarefa.ativo
        pedindo: tarefa.pedindo
    }
}
