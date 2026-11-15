// Notas: o cartão claro com três linhas e o alfinete rosa em cima, sobre o
// degradê amarelo quente.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['notas', '#FFD978', '#F0A93A'];
  const alfinete = (r) => `<circle cx="512" cy="304" r="${r}" fill="#DE8818"/><circle cx="512" cy="304" r="${r - 13}" fill="${R}"/>`;
  return {
    notas: {
      nomes: ['org.matsu.notas'],
      svg: grade(...cores,
        `<rect x="276" y="304" width="472" height="452" rx="60" fill="${B}"/>` +
        `<path d="M362 464 H662 M362 560 H662 M362 656 H552" fill="none" stroke="#E59222" stroke-width="42" ${liso}/>` +
        alfinete(60) + `<circle cx="497" cy="289" r="13" fill="${B}"/>`),
      pequeno: grade(...cores,
        `<rect x="276" y="320" width="472" height="436" rx="60" fill="${B}"/>` +
        `<path d="M368 488 H656 M368 616 H560" fill="none" stroke="#E59222" stroke-width="60" ${liso}/>` +
        alfinete(64), 1.1),
    },
  };
};
