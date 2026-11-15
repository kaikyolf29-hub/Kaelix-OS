// Terminal do Matsu: o sinal ">" em verde-água e o cursor "_" claro sobre o
// grafite quase preto, com o pontinho rosa no canto.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['term', '#3A3B42', '#141517'];
  const prompt = (t) => `<path d="M300 388 L468 512 L300 636" fill="none" stroke="#45D0C1" stroke-width="${t}" ${liso}/>` +
    `<path d="M532 636 H724" fill="none" stroke="${B}" stroke-width="${t}" ${liso}/>`;
  return {
    terminal: {
      nomes: ['org.matsu.terminal', 'utilities-terminal', 'org.kde.konsole', 'konsole'],
      svg: grade(...cores, prompt(62) + `<circle cx="714" cy="342" r="26" fill="${R}"/>`),
      pequeno: grade(...cores, prompt(76), 1.16),
    },
  };
};
