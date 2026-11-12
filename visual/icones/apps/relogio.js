// Relógio do Matsu: um despertador claro (mostrador, os dois sininhos e as
// perninhas) sobre o degradê de fim de tarde (pêssego ao rosa de cerejeira), com
// os ponteiros em ameixa e o ponteiro dos segundos em coral.
module.exports = ({ base, B, liso }) => {
  const ameixa = '#5B2A55';
  const coral = '#F0607E';
  const cx = 128, cy = 136, r = 66;
  // Marcas das 12, 3, 6 e 9 horas.
  const marcas = [0, 90, 180, 270].map((a) => {
    const rad = (a * Math.PI) / 180;
    const x1 = cx + Math.sin(rad) * (r - 12), y1 = cy - Math.cos(rad) * (r - 12);
    const x2 = cx + Math.sin(rad) * (r - 22), y2 = cy - Math.cos(rad) * (r - 22);
    return `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="${ameixa}" stroke-opacity=".45" stroke-width="7" ${liso}/>`;
  }).join('');
  return {
    relogio: {
      nomes: ['org.matsu.relogio'],
      svg: base('rel', '#FFB877', '#D9487C') +
        // Sininhos e perninhas.
        `<path d="M70 96 a30 30 0 0 1 36 -36" fill="none" stroke="${B}" stroke-width="16" ${liso}/>` +
        `<path d="M186 96 a30 30 0 0 0 -36 -36" fill="none" stroke="${B}" stroke-width="16" ${liso}/>` +
        `<path d="M90 194 l-12 16 M166 194 l12 16" fill="none" stroke="${B}" stroke-width="13" ${liso}/>` +
        // Mostrador.
        `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${B}"/>` +
        marcas +
        // Ponteiros (10:10, o sorriso dos relógios) e o dos segundos.
        `<path d="M${cx} ${cy} L${cx - 26} ${cy - 15}" stroke="${ameixa}" stroke-width="11" ${liso}/>` +
        `<path d="M${cx} ${cy} L${cx + 30} ${cy - 30}" stroke="${ameixa}" stroke-width="9" ${liso}/>` +
        `<path d="M${cx - 9} ${cy - 7} L${cx + 36} ${cy + 27}" stroke="${coral}" stroke-width="5" ${liso}/>` +
        `<circle cx="${cx}" cy="${cy}" r="8" fill="${coral}"/>`,
    },
  };
};
