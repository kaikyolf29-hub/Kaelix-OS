// Fotos: a moldura clara com a paisagem dentro (dois morros e o sol rosa),
// sobre o degradê de pôr do sol.
module.exports = ({ grade, B, R }) => {
  const cores = ['fot', '#FFB199', '#C76F90'];
  const paisagem = (moldura, sol) =>
    `<path d="M404 746 A236 236 0 0 1 746 529.1 V746 Z" fill="${B}" opacity=".6"/>` +
    `<path d="M278 746 V523.5 A268 268 0 0 1 671.6 746 Z" fill="${B}"/>` +
    sol +
    `<rect x="256" y="256" width="512" height="512" rx="76" fill="none" stroke="${B}" stroke-width="${moldura}"/>`;
  return {
    fotos: {
      nomes: ['org.matsu.fotos'],
      svg: grade(...cores, paisagem(48, `<circle cx="414" cy="408" r="58" fill="${R}" stroke="${B}" stroke-width="14"/>`)),
      pequeno: grade(...cores, paisagem(64, `<circle cx="420" cy="414" r="70" fill="${R}"/>`), 1.12),
    },
  };
};
