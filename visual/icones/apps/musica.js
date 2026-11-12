// Música: duas colcheias ligadas, claras, sobre o degradê coral e rosa (sem o azul),
// com três barrinhas da onda do player atrás.
module.exports = ({ base, B, liso }) => ({
  musica: {
    nomes: ['org.matsu.musica'],
    svg: base('mus', '#FF8A8F', '#D2336E') +
      `<path d="M58 150 v-24 M74 160 v-44 M90 146 v-16" fill="none" stroke="${B}" stroke-opacity=".38" stroke-width="10" ${liso}/>` +
      `<path d="M112 170 V84 l80 -16 v86" fill="none" stroke="${B}" stroke-width="15" ${liso}/>` +
      `<path d="M112 100 l80 -16" fill="none" stroke="${B}" stroke-width="22" ${liso}/>` +
      `<ellipse cx="96" cy="172" rx="21" ry="17" transform="rotate(-18 96 172)" fill="${B}"/>` +
      `<ellipse cx="176" cy="156" rx="21" ry="17" transform="rotate(-18 176 156)" fill="${B}"/>`,
  },
});
