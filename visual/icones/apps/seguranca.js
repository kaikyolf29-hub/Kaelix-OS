// Central de segurança: o escudo claro com o sinal de certo em verde e o
// pontinho rosa em cima, sobre o degradê verde.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['seg', '#5FD39A', '#1F8A5B'];
  const escudo = `<path d="M499.1 251.6 A48 48 0 0 1 524.9 251.6 L713.4 304.1 A52 52 0 0 1 751.1 360 L731.2 539.3 A80 80 0 0 1 707.2 588.1 L550.8 738.6 A56 56 0 0 1 473.2 738.6 L316.8 588.1 A80 80 0 0 1 292.8 539.3 L272.9 360 A52 52 0 0 1 310.6 304.1 Z" fill="${B}" stroke="${B}" stroke-width="12" ${liso}/>`;
  const certo = (t) => `<path d="M410 526 L484 600 L622 450" fill="none" stroke="#1F8A5B" stroke-width="${t}" ${liso}/>`;
  return {
    seguranca: {
      nomes: ['org.matsu.seguranca'],
      svg: grade(...cores, escudo + certo(56) + `<circle cx="512" cy="344" r="24" fill="${R}"/>`),
      pequeno: grade(...cores, escudo + certo(74), 1.14),
    },
  };
};
