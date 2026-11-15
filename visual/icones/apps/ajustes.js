// Ajustes do Matsu: a engrenagem com o miolo rosa e dois controles deslizantes,
// sobre o degradê grafite (como os ajustes do Mac, mas com a cara do Matsu).
// A engrenagem do KDE (Configurações do sistema) é outra, em gerar.js.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['ajus', '#9A9DAA', '#4A4D58'];
  const engrenagem = (cx, cy, dente, largura, cubo, furo, miolo) =>
    [0, 45, 90, 135].map((a) =>
      `<rect x="${cx - largura / 2}" y="${cy - dente}" width="${largura}" height="${dente * 2}" rx="${largura * 0.38}" fill="${B}"${a ? ` transform="rotate(${a} ${cx} ${cy})"` : ''}/>`).join('') +
    `<circle cx="${cx}" cy="${cy}" r="${cubo}" fill="${B}"/><circle cx="${cx}" cy="${cy}" r="${furo}" fill="#5B5E6A"/>` +
    (miolo ? `<circle cx="${cx}" cy="${cy}" r="${miolo}" fill="${R}"/>` : '');
  const controle = (y, ate, cor) =>
    `<path d="M292 ${y} H732" stroke="${B}" stroke-opacity=".5" stroke-width="36" ${liso}/>` +
    `<path d="M292 ${y} H${ate}" stroke="${B}" stroke-width="36" ${liso}/>` +
    `<circle cx="${ate}" cy="${y}" r="42" fill="${cor}"/>`;
  return {
    ajustes: {
      nomes: ['org.matsu.ajustes'],
      svg: grade(...cores, engrenagem(512, 418, 166, 76, 128, 58, 28) + controle(652, 444, B) + controle(744, 606, R)),
      pequeno: grade(...cores, engrenagem(512, 512, 226, 104, 172, 74, 0)),
    },
  };
};
