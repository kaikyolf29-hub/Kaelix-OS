// Segurança do Matsu: o escudo com o pinheiro dentro (o mesmo selo da Central de
// segurança), claros sobre o degradê de mar fundo.
module.exports = ({ base, B, liso }) => {
  // Uma nuvem de folhas do pinheiro: pílula com centro (x, y), largura e altura.
  const nuvem = (x, y, w, h) =>
    `<rect x="${x - w / 2}" y="${y - h / 2}" width="${w}" height="${h}" rx="${h / 2}" fill="${B}"/>`;
  return {
    seguranca: {
      nomes: ['org.matsu.seguranca'],
      svg: base('seg', '#4CC7B8', '#145F72') +
        // O escudo.
        `<path d="M128 46 L192 72 V122 C192 166 165 197 128 214 C91 197 64 166 64 122 V72 Z" fill="none" stroke="${B}" stroke-width="14" ${liso}/>` +
        // O tronco torto e os galhos.
        `<path d="M128 182 C128 168 115 162 119 148 C123 136 136 133 131 112" fill="none" stroke="${B}" stroke-width="10" ${liso}/>` +
        `<path d="M119 149 C111 148 106 145 101 139 M130 128 C138 127 144 125 151 120" fill="none" stroke="${B}" stroke-width="7" ${liso}/>` +
        // As nuvens de folhas e a pedra.
        nuvem(129, 108, 58, 18) + nuvem(129, 94, 28, 14) + nuvem(100, 138, 40, 15) + nuvem(155, 121, 38, 14) +
        `<rect x="104" y="181" width="48" height="8" rx="4" fill="${B}" opacity="0.6"/>`,
    },
  };
};
