// O vidro da doca do estilo Mac: a sombra em volta e o vidro claro com a borda
// acesa (peças "doca-sombra-" e "doca-" do tema do Matsu, feitas pelo
// usr/share/matsu/vidro/gerar.py, com a cor e a transparência que a pessoa
// escolheu). Vai de "inicio" a "fim" ao longo do eixo da doca e tem a
// espessura da doca, a partir da borda da tela.
import QtQuick
import org.kde.ksvg as KSvg

Item {
    id: vidro

    property var doca
    property real inicio: 0
    property real fim: 0
    // O comprimento e a espessura do item onde o vidro é desenhado (a barra ou
    // a janela da ampliação), para doca.caixa() saber de que lado fica a tela.
    property real total: 0
    property real fundo: 0

    readonly property rect r: doca.caixa(inicio, 0, Math.max(0, fim - inicio), doca.espessura, total, fundo)
    x: Math.round(r.x)
    y: Math.round(r.y)
    width: Math.round(r.width)
    height: Math.round(r.height)

    KSvg.FrameSvgItem {
        id: sombra
        // Num tema guardado antes das peças da doca (o vidro com cor que a
        // pessoa escolheu antes desta versão), fica sem sombra.
        visible: usedPrefix === "doca-sombra"
        imagePath: "solid/widgets/panel-background"
        prefix: "doca-sombra"
        anchors.fill: parent
        anchors.leftMargin: -margins.left
        anchors.topMargin: -margins.top
        anchors.rightMargin: -margins.right
        anchors.bottomMargin: -margins.bottom
    }

    // Sem as peças "doca-" (tema antigo), o vidro sem prefixo da mesma folha.
    KSvg.FrameSvgItem {
        imagePath: "solid/widgets/panel-background"
        prefix: ["doca", ""]
        anchors.fill: parent
    }
}
