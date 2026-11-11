// Cartão no miolo das páginas: um degrau acima do fundo, com a borda bem fina.
import QtQuick

Rectangle {
    radius: Math.round(janela.gu * 0.5)
    color: janela.cartao
    border.width: 1
    border.color: janela.bordaCartao
}
