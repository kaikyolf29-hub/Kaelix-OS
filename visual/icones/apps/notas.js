// Notas do Matsu: uma nota autoadesiva clara, com o canto de baixo dobrado, a
// linha do título e uma tarefa marcada, sobre o degradê de manteiga ao âmbar.
module.exports = ({ base, B, liso }) => {
  const ambar = '#D98A1E';
  const dobra = '#F6D48A';
  return {
    notas: {
      nomes: ['org.matsu.notas'],
      svg: base('notas', '#FFDF7E', '#F2A12E') +
        // Tudo um pouco maior, para ler bem em 22 px.
        `<g transform="translate(128 130) scale(1.16) translate(-128 -129)">` +
        // Sombra leve embaixo da nota.
        `<path d="M86 70 h86 a18 18 0 0 1 18 18 v74 l-38 38 h-66 a18 18 0 0 1 -18 -18 v-94 a18 18 0 0 1 18 -18 z" fill="#8A4B00" opacity=".16" transform="translate(0 7)"/>` +
        // A nota, com o canto dobrado.
        `<path d="M86 64 h86 a18 18 0 0 1 18 18 v74 l-38 38 h-66 a18 18 0 0 1 -18 -18 v-94 a18 18 0 0 1 18 -18 z" fill="${B}"/>` +
        `<path d="M190 156 h-24 a14 14 0 0 0 -14 14 v24 z" fill="${dobra}" stroke="${dobra}" stroke-width="4" ${liso}/>` +
        // Título e uma linha de texto.
        `<path d="M94 100 h68" stroke="${ambar}" stroke-width="14" ${liso}/>` +
        `<path d="M94 128 h52" stroke="${ambar}" stroke-opacity=".55" stroke-width="10" ${liso}/>` +
        // Uma tarefa feita: a bolinha com o visto.
        `<circle cx="102" cy="160" r="11" fill="${ambar}"/>` +
        `<path d="M96.5 160.5 l4 4 l7.5 -8" fill="none" stroke="${B}" stroke-width="4.5" ${liso}/>` +
        `<path d="M124 160 h16" stroke="${ambar}" stroke-opacity=".55" stroke-width="10" ${liso}/>` +
        `</g>`,
    },
  };
};
