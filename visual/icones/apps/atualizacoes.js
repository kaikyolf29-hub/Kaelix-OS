// Atualizações do Matsu: a seta de baixar dentro do círculo que gira (as duas
// meias-voltas com a pontinha), claros sobre o degradê verde-pinheiro.
module.exports = ({ base, B, liso }) => {
  const cx = 128, cy = 128, r = 70;
  const pt = (graus) => {
    const a = (graus * Math.PI) / 180;
    return [cx + r * Math.cos(a), cy + r * Math.sin(a)].map((n) => n.toFixed(1)).join(' ');
  };
  // Cada meia-volta vai de um lado ao outro, deixando uma folga para a ponta.
  const arco = (de, ate) => `<path d="M${pt(de)} A${r} ${r} 0 0 1 ${pt(ate)}" fill="none" stroke="${B}" stroke-width="16" ${liso}/>`;
  // A pontinha da seta no fim de cada meia-volta (apontando no sentido da volta).
  const ponta = (graus) => {
    const a = (graus * Math.PI) / 180;
    const x = cx + r * Math.cos(a), y = cy + r * Math.sin(a);
    const tx = -Math.sin(a), ty = Math.cos(a);          // tangente (sentido horário)
    const nx = Math.cos(a), ny = Math.sin(a);           // para fora
    const p = (dt, dn) => `${(x + tx * dt + nx * dn).toFixed(1)},${(y + ty * dt + ny * dn).toFixed(1)}`;
    return `<path d="M${p(-4, 20)} L${p(18, 0)} L${p(-4, -20)} Z" fill="${B}" stroke="${B}" stroke-width="6" ${liso}/>`;
  };
  return {
    atualizacoes: {
      nomes: ['org.matsu.atualizacoes'],
      svg: base('atu', '#5ED6A6', '#17795F') +
        arco(-150, -12) + ponta(-12) +
        arco(30, 168) + ponta(168) +
        // A seta de baixar no meio.
        `<path d="M128 94 V156" stroke="${B}" stroke-width="16" ${liso}/>` +
        `<path d="M102 132 L128 158 L154 132" fill="none" stroke="${B}" stroke-width="16" ${liso}/>`,
    },
  };
};
