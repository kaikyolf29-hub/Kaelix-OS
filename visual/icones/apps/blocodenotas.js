// Bloco de notas (o editor de texto, como o do Windows 11): bloco claro com a
// espiral em cima, as linhas do texto e o cursor piscando em verde-água, sobre
// o degradê de ardósia (o amarelo é das Notas rápidas, o laranja é do Kate).
module.exports = ({ base, B, liso }) => ({
  blocodenotas: {
    nomes: ['org.matsu.blocodenotas'],
    svg: base('bloco', '#8C9DB5', '#3B4860') +
      `<rect x="66" y="62" width="124" height="142" rx="16" fill="${B}"/>` +
      [94, 118, 142, 166].map((x) =>
        `<circle cx="${x - 4}" cy="80" r="5.5" fill="#46546C"/>` +
        `<path d="M${x - 4} 80 V60 a8 8 0 0 1 16 0 V68" fill="none" stroke="${B}" stroke-width="7" ${liso}/>`).join('') +
      `<path d="M90 114 h76 M90 138 h76 M90 162 h40" fill="none" stroke="#5D6C86" stroke-width="10" ${liso}/>` +
      `<path d="M148 150 v24" fill="none" stroke="#45D0C1" stroke-width="8" ${liso}/>`,
  },
});
