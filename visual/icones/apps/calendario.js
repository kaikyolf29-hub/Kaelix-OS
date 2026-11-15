// Calendário: a folha clara com as argolas em cima, a faixa do mês e os dias,
// com o dia de hoje marcado em coral e o miolo rosa, sobre o degradê coral.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['cal', '#FF8A80', '#E0445A'];
  const C = '#E0445A';
  const argolas = (y0, y1, t) => [392, 632].map((x) =>
    `<circle cx="${x}" cy="${y1}" r="${t * 0.66}" fill="${C}"/><path d="M${x} ${y0} V${y1}" stroke="${B}" stroke-width="${t}" ${liso}/>`).join('');
  const dia = (x, y, l, cheio) => `<rect x="${x - l / 2}" y="${y - l / 2}" width="${l}" height="${l}" rx="${l * 0.3}" fill="${C}"${cheio ? '' : ' opacity=".28"'}/>`;
  return {
    calendario: {
      nomes: ['org.matsu.calendario'],
      svg: grade(...cores,
        `<rect x="264" y="312" width="496" height="448" rx="62" fill="${B}"/>` +
        `<path d="M264 432 V374 A62 62 0 0 1 326 312 H698 A62 62 0 0 1 760 374 V432 Z" fill="${C}" opacity=".2"/>` +
        argolas(260, 352, 44) +
        dia(376, 520, 66) + dia(512, 520, 66) + dia(376, 648, 66) + dia(512, 648, 66) + dia(648, 648, 66) +
        dia(648, 520, 92, true) + `<circle cx="648" cy="520" r="22" fill="${R}"/>`),
      pequeno: grade(...cores,
        `<rect x="264" y="300" width="496" height="460" rx="62" fill="${B}"/>` +
        `<path d="M264 440 V362 A62 62 0 0 1 326 300 H698 A62 62 0 0 1 760 362 V440 Z" fill="${C}"/>` +
        argolas(244, 330, 56) +
        dia(420, 600, 110) + dia(604, 600, 110, true), 1.08),
    },
  };
};
