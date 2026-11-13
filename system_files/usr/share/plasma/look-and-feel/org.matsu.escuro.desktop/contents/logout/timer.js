// Contagem compartilhada entre as telas (uma janela por monitor): uma tecla em
// qualquer tela para a contagem de todas. Mesma ideia do timer.js da Breeze.
.pragma library

var paradas = [];

function aoParar(funcao) {
    paradas.push(funcao);
}

function parar() {
    paradas.forEach(function(f) {
        if (f) {
            f();
        }
    });
}
