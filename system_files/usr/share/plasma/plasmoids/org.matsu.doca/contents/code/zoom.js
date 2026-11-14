// Conta da ampliação da doca do Matsu (o "efeito lupa" do Mac), sem nada de
// QML para dar para testar com o node (tests/test_doca.js).
//
// A doca é uma fileira de pedaços ao longo do eixo (da esquerda para a direita
// na doca de baixo, de cima para baixo na doca do lado): cada app é um
// quadrado de lado "celula", e entre os apps e a lixeira há um vão fixo.
// Quando o mouse passa, cada app cresce conforme a distância até o mouse
// (o do meio cresce mais, os vizinhos um pouco) e os outros abrem espaço.
// O app que está embaixo do mouse fica parado embaixo do mouse: assim o
// clique (que vale para a fileira normal, sem ampliação) sempre cai no app
// que a pessoa está vendo crescer.
.pragma library

// Quanto um app cresce: 1 longe do mouse, "maximo" bem em cima dele. A curva é
// um cosseno levantado (suave nas duas pontas, sem quina), que chega a zero a
// "raio" pixels do mouse. "forca" vai de 0 a 1 (a animação de entrar e sair).
function escala(distancia, maximo, raio, forca) {
    var d = Math.abs(distancia);
    if (!(raio > 0) || d >= raio || !(maximo > 1) || !(forca > 0)) {
        return 1;
    }
    var curva = 0.5 * (1 + Math.cos(Math.PI * d / raio));
    return 1 + (maximo - 1) * Math.min(1, forca) * curva;
}

// O teto da ampliação a partir do ajuste da pessoa (0 a 100): de 1,3x a 2,2x.
function maximoDoNivel(nivel) {
    var n = Math.max(0, Math.min(100, Number(nivel) || 0));
    return 1.3 + 0.9 * n / 100;
}

// pedacos: lista de {tamanho, cresce} na ordem do eixo, na fileira normal.
//   cresce = true para os apps (e a lixeira), false para os vãos.
// mouse: a posição do mouse no eixo (na fileira normal).
// Devolve {inicio: [...], tamanho: [...], escala: [...]} de cada pedaço na
// fileira ampliada, no mesmo sistema de coordenadas da fileira normal.
function arrumar(pedacos, mouse, maximo, raio, forca) {
    var n = pedacos.length;
    var base = [], novo = [], escalas = [];
    var pos = 0, i;
    for (i = 0; i < n; i++) {
        base.push(pos);
        pos += pedacos[i].tamanho;
    }
    var acumulado = 0;
    var inicioNovo = [];
    for (i = 0; i < n; i++) {
        var s = 1;
        if (pedacos[i].cresce) {
            var centro = base[i] + pedacos[i].tamanho / 2;
            s = escala(mouse - centro, maximo, raio, forca);
        }
        escalas.push(s);
        novo.push(pedacos[i].tamanho * s);
        inicioNovo.push(acumulado);
        acumulado += novo[i];
    }
    // Onde o mouse cai na fileira ampliada: no mesmo ponto relativo do mesmo
    // pedaço. Antes do primeiro e depois do último, segue reto.
    var alvo;
    if (n === 0) {
        return { inicio: [], tamanho: [], escala: [] };
    }
    if (mouse <= base[0]) {
        alvo = inicioNovo[0] + (mouse - base[0]);
    } else if (mouse >= pos) {
        alvo = acumulado + (mouse - pos);
    } else {
        for (i = 0; i < n; i++) {
            var fim = base[i] + pedacos[i].tamanho;
            if (mouse < fim || i === n - 1) {
                var u = pedacos[i].tamanho > 0 ? (mouse - base[i]) / pedacos[i].tamanho : 0;
                alvo = inicioNovo[i] + u * novo[i];
                break;
            }
        }
    }
    var desvio = mouse - alvo;
    var inicio = [];
    for (i = 0; i < n; i++) {
        inicio.push(inicioNovo[i] + desvio);
    }
    return { inicio: inicio, tamanho: novo, escala: escalas };
}

// Quanto a fileira ampliada pode passar das pontas da fileira normal, no pior
// caso (mouse numa ponta): serve para o tamanho da janela da ampliação.
function sobraMaxima(celula, maximo, raio) {
    if (!(maximo > 1)) {
        return 0;
    }
    // Soma do crescimento de todos os apps que o raio alcança, de um lado só e
    // do do meio inteiro, com folga.
    var total = 0;
    for (var d = 0; d < raio; d += celula) {
        total += celula * (escala(d, maximo, raio, 1) - 1) * (d === 0 ? 1 : 2);
    }
    return Math.ceil(total) + celula;
}
