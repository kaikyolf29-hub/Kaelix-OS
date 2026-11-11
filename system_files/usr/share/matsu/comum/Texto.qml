// Texto dos apps do Matsu: sempre na cor da frente do vidro (branco no
// tema escuro, quase preto no claro), nunca no azul do esquema de cores.
import QtQuick
import QtQuick.Controls as QQC2

QQC2.Label {
    color: janela.frente
    linkColor: janela.destaque
}
