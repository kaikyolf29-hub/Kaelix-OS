// Bloco de notas (o editor de texto): a folha clara com as linhas do texto e o
// lápis inclinado por cima (corpo claro, borracha rosa, ponta de madeira), com
// uma folga no tom do fundo separando o lápis da folha, sobre o degradê areia.
module.exports = ({ grade, B, R, liso }) => {
  const cores = ['bloco', '#F2D7B6', '#C99A6B'];
  // Lápis deitado com a ponta em (0, 0), girado para subir para a direita.
  const lapis = (x, y, largura, folga, detalhes = true) => {
    const m = largura / 2;
    return `<g transform="translate(${x} ${y}) rotate(-45)">` +
      `<path d="M24 0 H350" stroke="url(#f-bloco)" stroke-width="${largura + folga * 2}" ${liso}/>` +
      `<path d="M10 -4 Q0 0 10 4 L100 ${m} H310 V${-m} H100 Z" fill="${B}"/>` +
      (detalhes ? `<path d="M10 -4 Q0 0 10 4 L100 ${m} V${-m} Z" fill="#E9C9A0"/>` : '') +
      `<path d="M8 -3.6 Q0 0 8 3.6 L${detalhes ? 36 : 50} ${m * (detalhes ? 0.36 : 0.5)} V${-m * (detalhes ? 0.36 : 0.5)} Z" fill="#6B4A2E"/>` +
      `<path d="M300 ${-m} H330 A${m} ${m} 0 0 1 330 ${m} H300 Z" fill="${R}"/>` +
      (detalhes ? `<path d="M288 ${-m} V${m}" stroke="#D9B98F" stroke-width="16"/>` : '') +
      `</g>`;
  };
  return {
    blocodenotas: {
      nomes: ['org.matsu.blocodenotas'],
      svg: grade(...cores,
        `<rect x="252" y="244" width="408" height="536" rx="58" fill="${B}"/>` +
        `<path d="M334 380 H578 M334 474 H578 M334 568 H470" fill="none" stroke="#C99A6B" stroke-width="40" ${liso}/>` +
        lapis(470, 716, 96, 26)),
      pequeno: grade(...cores,
        `<rect x="244" y="236" width="424" height="552" rx="62" fill="${B}"/>` +
        `<path d="M336 392 H576 M336 520 H500" fill="none" stroke="#C99A6B" stroke-width="58" ${liso}/>` +
        lapis(476, 724, 120, 30, false), 1.06),
    },
  };
};
