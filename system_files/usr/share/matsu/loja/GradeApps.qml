// Grade de cartões de apps, com quantas colunas couberem. "linhas" limita
// (as seções do Início mostram uma ou duas linhas e o "Ver tudo").
import QtQuick

Item {
    id: grade

    property var lista: []
    property int linhas: 0
    readonly property int vao: Math.round(janela.gu * 0.8)
    readonly property int colunas: Math.max(1, Math.floor((width + vao) / (janela.gu * 11.5 + vao)))
    readonly property int largura: Math.floor((width - (colunas - 1) * vao) / colunas)
    readonly property int altura: Math.round(janela.gu * 8.4)
    readonly property var mostrados: linhas > 0 ? lista.slice(0, colunas * linhas) : lista
    readonly property int quantasLinhas: Math.ceil(mostrados.length / colunas)
    readonly property bool sobra: mostrados.length < lista.length

    implicitHeight: quantasLinhas > 0 ? quantasLinhas * altura + (quantasLinhas - 1) * vao : 0

    Grid {
        columns: grade.colunas
        spacing: grade.vao
        Repeater {
            model: grade.mostrados
            CartaoApp {
                required property var modelData
                width: grade.largura
                height: grade.altura
                app: modelData
            }
        }
    }
}
