// Calculadora do Matsu: a calculadora clara (visor e teclas) sobre o degradê
// âmbar e laranja, com o "=" na cor do fundo.
module.exports = ({ base, B, liso }) => {
  const tecla = (x, y, cor, op = 1) => `<rect x="${x}" y="${y}" width="26" height="22" rx="7" fill="${cor}" opacity="${op}"/>`;
  let teclas = '';
  const xs = [82, 115, 148];
  const ys = [124, 152, 180];
  for (const y of ys) for (const x of xs) teclas += tecla(x, y, '#C9651B', 0.82);
  return {
    calculadora: {
      nomes: ['org.matsu.calculadora'],
      svg: base('calc', '#FFC36B', '#F0762A') +
        `<rect x="66" y="50" width="124" height="164" rx="22" fill="${B}" stroke="${B}" stroke-width="4" ${liso}/>` +
        `<rect x="82" y="66" width="92" height="42" rx="10" fill="#E8833A" opacity=".9"/>` +
        `<path d="M142 87 h20 M152 77 v20" stroke="${B}" stroke-width="7" ${liso} opacity=".95"/>` +
        teclas.replace(/<rect x="148" y="180"[^>]*>/, '') +
        `<rect x="148" y="180" width="26" height="22" rx="7" fill="#F0762A"/>` +
        `<path d="M155 188 h12 M155 194 h12" stroke="${B}" stroke-width="3.6" ${liso}/>`,
    },
  };
};
