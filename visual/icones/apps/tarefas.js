// Gerenciador de tarefas: três barras subindo (um painel de desempenho) e o
// pontinho que pulsa em cima da última, sobre o degradê verde-água.
module.exports = ({ grade, B, R }) => {
  const cores = ['tar', '#62E3D5', '#1E9C90'];
  const barras = `<rect x="270" y="536" width="120" height="208" rx="52" fill="${B}" opacity=".78"/>` +
    `<rect x="452" y="446" width="120" height="298" rx="52" fill="${B}" opacity=".9"/>` +
    `<rect x="634" y="364" width="120" height="380" rx="52" fill="${B}"/>`;
  return {
    tarefas: {
      nomes: ['org.matsu.tarefas'],
      svg: grade(...cores, barras + `<circle cx="694" cy="270" r="46" fill="${B}"/><circle cx="694" cy="270" r="32" fill="${R}"/>`),
      pequeno: grade(...cores, `<g transform="translate(0 -40)">${barras}</g>`, 1.14),
    },
  };
};
