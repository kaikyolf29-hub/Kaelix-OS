// Calculadora: quatro teclas claras (+, −, × e =), a do igual em rosa, sobre o
// degradê laranja.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['calc', '#FFB86B', '#E8742A'];
  const L = '#E8742A';
  const teclas = (t, m) => {
    const a = 256, b = 532, l = 236;
    const tecla = (x, y, cor, op) => `<rect x="${x}" y="${y}" width="${l}" height="${l}" rx="58" fill="${cor}"${op ? ` opacity="${op}"` : ''}/>`;
    const c1 = a + l / 2, c2 = b + l / 2;
    return tecla(a, a, B) + tecla(b, a, B, '.92') + tecla(a, b, B, '.92') + tecla(b, b, R) +
      `<path d="M${c1} ${c1 - m} V${c1 + m} M${c1 - m} ${c1} H${c1 + m} M${c2 - m} ${c1} H${c2 + m}` +
      ` M${c1 - m * 0.74} ${c2 - m * 0.74} L${c1 + m * 0.74} ${c2 + m * 0.74} M${c1 + m * 0.74} ${c2 - m * 0.74} L${c1 - m * 0.74} ${c2 + m * 0.74}"` +
      ` fill="none" stroke="${L}" stroke-width="${t}" ${liso}/>` +
      `<path d="M${c2 - m} ${c2 - m * 0.56} H${c2 + m} M${c2 - m} ${c2 + m * 0.56} H${c2 + m}" fill="none" stroke="#9E2A5B" stroke-width="${t}" ${liso}/>`;
  };
  return {
    calculadora: {
      nomes: ['org.matsu.calculadora'],
      svg: grade(...cores, teclas(38, 48)),
      pequeno: grade(...cores, teclas(54, 50), 1.06),
    },
  };
};
