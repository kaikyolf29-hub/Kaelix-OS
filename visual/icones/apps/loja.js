// Loja do Matsu: a sacola com a seta de baixar, sobre o degradê de cerejeira a
// ameixa, com os furinhos da alça em rosa e um brilho branco no canto.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['loja', '#F7A8CF', '#8E3E70'];
  const sacola = (seta) =>
    `<path d="M404 404 A108 108 0 0 1 620 404" fill="none" stroke="${B}" stroke-width="46" ${liso} opacity=".92"/>` +
    `<rect x="276" y="384" width="472" height="372" rx="66" fill="${B}"/>` +
    `<path d="M512 494 V652 M434 580 L512 658 L590 580" fill="none" stroke="#8E3E70" stroke-width="${seta}" ${liso}/>`;
  return {
    loja: {
      nomes: ['org.matsu.loja', 'plasmadiscover', 'org.kde.discover'],
      svg: grade(...cores, sacola(50) +
        `<circle cx="404" cy="450" r="20" fill="${R}"/><circle cx="620" cy="450" r="20" fill="${R}"/>` +
        `<circle cx="684" cy="296" r="20" fill="#FFFFFF"/>`),
      pequeno: grade(...cores, sacola(64), 1.12),
    },
  };
};
