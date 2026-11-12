// Fotos: uma foto clara com a montanha e o sol, sobre o degradê do pôr do sol do
// Matsu (pêssego para o rosa da cerejeira). Diferente do ícone das Imagens (Gwenview),
// que é anil com duas fotos tortas.
module.exports = ({ base, B, liso }) => ({
  fotos: {
    nomes: ['org.matsu.fotos'],
    svg: base('fot', '#FFB86B', '#E2508A',
      `<clipPath id="c-fot"><rect x="70" y="74" width="116" height="108" rx="16"/></clipPath>` +
      `<linearGradient id="ceu-fot" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE1B8"/><stop offset="1" stop-color="#FFC2D4"/></linearGradient>`) +
      `<rect x="58" y="62" width="140" height="132" rx="26" fill="${B}"/>` +
      `<g clip-path="url(#c-fot)"><rect x="70" y="74" width="116" height="108" fill="url(#ceu-fot)"/>` +
      `<circle cx="154" cy="106" r="15" fill="#FFB547"/>` +
      `<path d="M62 190 L104 128 L130 160 L148 140 L194 190 Z" fill="#E2508A" ${liso}/>` +
      `<path d="M62 190 L104 128 L122 150" fill="none" stroke="#B8336E" stroke-opacity=".35" stroke-width="5" ${liso}/></g>`,
  },
});
