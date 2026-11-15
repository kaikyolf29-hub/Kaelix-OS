// Arquivos do Matsu: a pasta de frente, com a aba atrás meio transparente e o
// pontinho rosa, sobre o degradê lavanda.
module.exports = ({ grade, B, R }) => {
  const cores = ['arq', '#A99BFF', '#5E4FD1'];
  const pasta = `<path d="M236 328 a48 48 0 0 1 48 -48 h150 a32 32 0 0 1 23 9.8 l38 39.4 a32 32 0 0 0 23 9.8 h222 a48 48 0 0 1 48 48 v270 a56 56 0 0 1 -56 56 h-440 a56 56 0 0 1 -56 -56 z" fill="${B}" opacity=".58"/>` +
    `<rect x="236" y="400" width="552" height="340" rx="60" fill="${B}"/>`;
  return {
    arquivos: {
      nomes: ['org.matsu.arquivos', 'system-file-manager', 'org.kde.dolphin'],
      svg: grade(...cores, pasta + `<circle cx="708" cy="476" r="26" fill="${R}"/>`),
      pequeno: grade(...cores, pasta, 1.12),
    },
  };
};
