// Câmera: a lente de frente (anel claro, vidro escuro e o reflexo rosa), sobre
// o degradê grafite.
module.exports = ({ grade, B, R }) => {
  const cores = ['cam', '#5A5A66', '#232329'];
  return {
    camera: {
      nomes: ['org.matsu.camera'],
      svg: grade(...cores,
        `<circle cx="512" cy="512" r="256" fill="${B}"/><circle cx="512" cy="512" r="204" fill="#2A2A32"/>` +
        `<circle cx="512" cy="512" r="146" fill="none" stroke="${B}" stroke-width="34" opacity=".8"/>` +
        `<circle cx="512" cy="512" r="94" fill="#16161B"/>` +
        `<circle cx="580" cy="444" r="38" fill="${R}"/><circle cx="452" cy="574" r="18" fill="${B}" opacity=".85"/>`),
      pequeno: grade(...cores,
        `<circle cx="512" cy="512" r="290" fill="${B}"/><circle cx="512" cy="512" r="224" fill="#2A2A32"/>` +
        `<circle cx="512" cy="512" r="140" fill="none" stroke="${B}" stroke-width="54" opacity=".85"/>` +
        `<circle cx="590" cy="434" r="46" fill="${R}"/>`),
    },
  };
};
