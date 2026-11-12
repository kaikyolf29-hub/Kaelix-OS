// Ícone do Calendário: a folhinha clara com as argolas, a faixa de cima na cor do
// ícone e a grade de dias com a pílula cheia no dia escolhido (como no app).
module.exports = ({ base, B, liso }) => {
  const escuro = '#C9455A';
  const dias = [];
  for (let l = 0; l < 3; l++) {
    for (let c = 0; c < 4; c++) {
      const x = 87 + c * 27, y = 132 + l * 22;
      if (l === 1 && c === 2) continue; // o dia escolhido
      dias.push(`<circle cx="${x}" cy="${y}" r="5.5" fill="${escuro}" opacity="${l === 2 && c > 1 ? 0.28 : 0.5}"/>`);
    }
  }
  return {
    calendario: {
      nomes: ['org.matsu.calendario'],
      svg: base('cal', '#FF9A86', '#E04F63') +
        // A folha.
        `<rect x="58" y="70" width="140" height="128" rx="24" fill="${B}"/>` +
        // A faixa de cima, um pouco mais funda.
        `<path d="M58 94 a24 24 0 0 1 24 -24 h92 a24 24 0 0 1 24 24 v12 h-140 z" fill="${escuro}" opacity=".9"/>` +
        // As argolas.
        `<path d="M98 58 v24 M158 58 v24" stroke="${B}" stroke-width="13" ${liso}/>` +
        dias.join('') +
        // A pílula do dia escolhido.
        `<circle cx="141" cy="154" r="13" fill="${escuro}"/>` +
        `<circle cx="141" cy="154" r="4.5" fill="${B}"/>`,
    },
  };
};
