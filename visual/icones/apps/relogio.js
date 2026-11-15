// Relógio (alarmes, timer e cronômetro): o cronômetro de mostrador claro, com a
// coroa em cima e o botão do lado, o ponteiro escuro nas 12 e o rosa nas 4,
// sobre o degradê grafite.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['rel', '#4A4A55', '#1E1E24'];
  const E = '#2A2A32';
  const cx = 512, cy = 566;
  // Marcas das horas: traço nas 12, 3, 6 e 9, pontinho nas outras.
  const marcas = (r) => Array.from({ length: 12 }, (_, i) => {
    const a = (i * 30 * Math.PI) / 180;
    const x = (d) => (cx + Math.sin(a) * d).toFixed(1), y = (d) => (cy - Math.cos(a) * d).toFixed(1);
    return i % 3 === 0
      ? `<path d="M${x(r - 22)} ${y(r - 22)} L${x(r - 58)} ${y(r - 58)}" stroke="#4A4A55" stroke-opacity=".55" stroke-width="22" ${liso}/>`
      : `<circle cx="${x(r - 34)}" cy="${y(r - 34)}" r="9" fill="#4A4A55" opacity=".35"/>`;
  }).join('');
  const ponteiros = (t) =>
    `<path d="M${cx} ${cy} V${cy - 150}" stroke="${E}" stroke-width="${t}" ${liso}/>` +
    `<path d="M${cx} ${cy} L${cx + 118} ${cy + 74}" stroke="#C94F8A" stroke-width="${t}" ${liso}/>` +
    `<path d="M${cx} ${cy} L${cx + 118} ${cy + 74}" stroke="${R}" stroke-width="${t - 16}" ${liso}/>` +
    `<circle cx="${cx}" cy="${cy}" r="${t * 0.75}" fill="${E}"/><circle cx="${cx}" cy="${cy}" r="${t * 0.35}" fill="${R}"/>`;
  const coroa = `<rect x="488" y="262" width="48" height="80" rx="16" fill="${B}"/>` +
    `<rect x="436" y="232" width="152" height="52" rx="26" fill="${B}"/>`;
  return {
    relogio: {
      nomes: ['org.matsu.relogio'],
      svg: grade(...cores,
        coroa +
        `<rect x="490" y="268" width="44" height="66" rx="20" fill="${B}" transform="rotate(44 ${cx} ${cy})"/>` +
        `<circle cx="${cx}" cy="${cy}" r="240" fill="${B}"/>` + marcas(240) + ponteiros(42)),
      pequeno: grade(...cores,
        `<g transform="translate(0 -14)">${coroa}</g>` +
        `<circle cx="${cx}" cy="${cy}" r="252" fill="${B}"/>` + ponteiros(56), 1.1),
    },
  };
};
