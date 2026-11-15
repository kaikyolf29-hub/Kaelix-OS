// Música: a nota dupla clara sobre dois arcos de disco de vinil, com o miolo
// rosa numa das notas e um brilho branco, sobre o degradê rosa intenso.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['mus', '#FF6F91', '#C2185B'];
  const notas = (haste) =>
    `<ellipse cx="382" cy="594" rx="64" ry="50" transform="rotate(-18 382 594)" fill="${B}"/>` +
    `<ellipse cx="606" cy="556" rx="64" ry="50" transform="rotate(-18 606 556)" fill="${B}"/>` +
    `<path d="M426 584 V336 M650 546 V298" fill="none" stroke="${B}" stroke-width="${haste}" ${liso}/>` +
    `<path d="M403 333.4 A18 18 0 0 1 418.2 315.6 L648.2 279.3 A18 18 0 0 1 669 297.1 L669 346 A18 18 0 0 1 653.8 363.8 L423.8 400.1 A18 18 0 0 1 403 382.3 Z" fill="${B}"/>`;
  return {
    musica: {
      nomes: ['org.matsu.musica'],
      svg: grade(...cores,
        `<path d="M672.9 663.5 A218 218 0 0 1 295.5 650.3" fill="none" stroke="${B}" stroke-width="32" ${liso} opacity=".45"/>` +
        `<path d="M608.4 656.4 A162 162 0 0 1 360.3 647.7" fill="none" stroke="${B}" stroke-width="24" ${liso} opacity=".28"/>` +
        notas(46) + `<circle cx="606" cy="556" r="20" fill="${R}"/><circle cx="312" cy="384" r="20" fill="#FFFFFF"/>`),
      pequeno: grade(...cores, `<g transform="translate(0 30)">${notas(58)}</g>`, 1.14),
    },
  };
};
