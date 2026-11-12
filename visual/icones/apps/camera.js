// Câmera do Matsu: câmera clara de traço grosso sobre o degradê coral e framboesa,
// a lente funda com o brilho e a luz do flash no laranja do Matsu.
module.exports = ({ base, B, liso }) => ({
  camera: {
    nomes: ['org.matsu.camera'],
    svg: base('cam', '#FF9B7D', '#D63F6C') +
      `<path d="M104 74 h48 a10 10 0 0 1 9 6 l6 12 h-78 l6 -12 a10 10 0 0 1 9 -6 z" fill="${B}" stroke="${B}" stroke-width="6" ${liso}/>` +
      `<rect x="52" y="88" width="152" height="102" rx="24" fill="${B}"/>` +
      `<circle cx="128" cy="140" r="38" fill="#C2416A"/>` +
      `<circle cx="128" cy="140" r="26" fill="#3B1E3E"/>` +
      `<circle cx="128" cy="140" r="38" fill="none" stroke="${B}" stroke-opacity=".35" stroke-width="5"/>` +
      `<circle cx="118" cy="130" r="7.5" fill="${B}" opacity=".85"/>` +
      `<circle cx="180" cy="108" r="7" fill="#FFC677"/>`,
  },
});
