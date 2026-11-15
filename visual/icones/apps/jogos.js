// Central de jogos: o controle claro sobre o degradê rosa e roxo, com a cruz em
// roxo, um botão roxo e um rosa, e um brilho branco em cima.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['jog', '#FF7DB5', '#7A45E0'];
  const controle = `<path d="M275.4 415.3 A72 72 0 0 1 346.3 356 L677.7 356 A72 72 0 0 1 748.6 415.3 L779.1 586 A68 68 0 0 1 742.5 658.7 L717.1 671.4 A56 56 0 0 1 647.8 655.7 L598.6 592.3 A42 42 0 0 0 565.4 576 L458.6 576 A42 42 0 0 0 425.4 592.3 L376.2 655.7 A56 56 0 0 1 306.9 671.4 L281.5 658.7 A68 68 0 0 1 244.9 586 Z" fill="${B}" stroke="${B}" stroke-width="16" ${liso}/>`;
  const comandos = (traco, botao) =>
    `<path d="M376 430 V538 M322 484 H430" fill="none" stroke="#7A45E0" stroke-width="${traco}" ${liso}/>` +
    `<circle cx="618" cy="516" r="${botao}" fill="#7A45E0"/><circle cx="678" cy="456" r="${botao}" fill="${R}"/>`;
  return {
    jogos: {
      nomes: ['org.matsu.jogos'],
      svg: grade(...cores, controle + comandos(40, 30) + `<circle cx="512" cy="290" r="20" fill="#FFFFFF"/>`),
      pequeno: grade(...cores, controle + comandos(56, 38), 1.12),
    },
  };
};
