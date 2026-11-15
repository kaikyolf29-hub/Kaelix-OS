// Atualizações do Matsu: as duas setas que dão a volta (atualizar) com o
// brilho rosa no meio, sobre o degradê violeta.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['atu', '#B093FF', '#6A49DD'];
  const setas = (t, p) =>
    `<path d="M321.7 423.3 A210 210 0 0 1 702.3 423.3" fill="none" stroke="${B}" stroke-width="${t}" ${liso}/>` +
    `<path d="M628 410 L708 432 L720 350" fill="none" stroke="${B}" stroke-width="${p}" ${liso}/>` +
    `<path d="M702.3 600.7 A210 210 0 0 1 321.7 600.7" fill="none" stroke="${B}" stroke-width="${t}" ${liso}/>` +
    `<path d="M396 614 L316 592 L304 674" fill="none" stroke="${B}" stroke-width="${p}" ${liso}/>`;
  const brilho = `<path d="M499.5 435 A14 14 0 0 1 524.5 435 L543.6 473.2 A16 16 0 0 0 550.8 480.4 L589 499.5 A14 14 0 0 1 589 524.5 L550.8 543.6 A16 16 0 0 0 543.6 550.8 L524.5 589 A14 14 0 0 1 499.5 589 L480.4 550.8 A16 16 0 0 0 473.2 543.6 L435 524.5 A14 14 0 0 1 435 499.5 L473.2 480.4 A16 16 0 0 0 480.4 473.2 Z" fill="${R}"/>`;
  return {
    atualizacoes: {
      nomes: ['org.matsu.atualizacoes'],
      svg: grade(...cores, setas(52, 48) + brilho + `<circle cx="512" cy="512" r="14" fill="${B}"/>`),
      pequeno: grade(...cores, setas(74, 70), 1.08),
    },
  };
};
