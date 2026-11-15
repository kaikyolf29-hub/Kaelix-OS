// Lixeira (vazia e cheia), no fim dos apps da barra, como a do Mac: a lata clara
// com dois frisos e o pontinho rosa; a cheia sem tampa e com dois papéis
// saindo (um claro e um rosa), sobre o degradê cinza.
module.exports = ({ grade, B, R, liso }) => {
  const C = '#626672';
  const lata = (frisos) =>
    `<path d="M316 440 A36 36 0 0 1 352 402 H672 A36 36 0 0 1 708 440 L684 700 A52 52 0 0 1 632 748 H392 A52 52 0 0 1 340 700 Z" fill="${B}"/>` +
    `<path d="M454 478 L462 668 M570 478 L562 668" fill="none" stroke="${C}" stroke-width="${frisos}" ${liso}/>`;
  const tampa = (alca) => `<rect x="440" y="256" width="144" height="70" rx="30" fill="none" stroke="${B}" stroke-width="${alca}"/>` +
    `<rect x="276" y="312" width="472" height="58" rx="29" fill="${B}"/>`;
  const papeis = `<rect x="346" y="266" width="170" height="178" rx="32" transform="rotate(-18 431 355)" fill="${B}" opacity=".7"/>` +
    `<rect x="504" y="256" width="174" height="182" rx="32" transform="rotate(16 591 347)" fill="${R}"/>` +
    `<path d="M322 398 H702" stroke="${C}" stroke-width="20" ${liso}/>`;
  const cores = (id) => [id, '#B4B7C2', '#626672'];
  return {
    lixeira: {
      nomes: ['user-trash', 'trashcan_empty'],
      svg: grade(...cores('lix'), tampa(36) + lata(36) + `<circle cx="648" cy="452" r="22" fill="${R}"/>`),
      pequeno: grade(...cores('lix'), tampa(48) + lata(50), 1.1),
    },
    'lixeira-cheia': {
      nomes: ['user-trash-full', 'trashcan_full'],
      svg: grade(...cores('lixc'), papeis + lata(36)),
      pequeno: grade(...cores('lixc'), papeis + lata(50), 1.1),
    },
  };
};
