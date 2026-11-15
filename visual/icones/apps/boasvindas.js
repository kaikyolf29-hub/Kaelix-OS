// Boas-vindas: o sol rosa nascendo atrás de um broto (duas folhas abertas para
// cima, uma de cada altura), na linha do horizonte com o reflexo na água, e
// duas estrelinhas no céu de ameixa. Não é o logo do Matsu (o bonsai no
// círculo): é o "começo" do sistema. Uma folga no tom do fundo separa o broto
// do sol.
module.exports = ({ grade, B, R, liso, estrela }) => {
  const cores = ['boas', '#8A5A7E', '#2A1A2E'];
  const H = 664;                                  // linha do horizonte
  const f = (n) => n.toFixed(1);
  // Folha em forma de gota, da base (bx, by) até a ponta (px, py), com largura
  // w; "curva" entorta a folha para um dos lados.
  const folha = (bx, by, px, py, w, curva) => {
    const dx = px - bx, dy = py - by, l = Math.hypot(dx, dy);
    const ux = -dy / l, uy = dx / l;
    const mx = (bx + px) / 2 + ux * curva, my = (by + py) / 2 + uy * curva;
    return `M${bx} ${by} Q${f(mx + ux * w * 2)} ${f(my + uy * w * 2)} ${px} ${py} Q${f(mx - ux * w * 2)} ${f(my - uy * w * 2)} ${bx} ${by} Z`;
  };
  const broto = (caule, folga) => {
    const c = `M512 ${H} C512 610 500 580 508 540`;
    const d = folha(508, 540, 384, 486, 58, -10) + ' ' + folha(508, 540, 640, 430, 62, 12);
    const fundo = 'url(#f-boas)';
    return `<path d="${c}" fill="none" stroke="${fundo}" stroke-width="${caule + folga * 2}" ${liso}/>` +
      `<path d="${d}" fill="${fundo}" stroke="${fundo}" stroke-width="${folga * 2}" ${liso}/>` +
      `<path d="${c}" fill="none" stroke="${B}" stroke-width="${caule}" ${liso}/><path d="${d}" fill="${B}"/>`;
  };
  const sol = (r) => `<path d="M${512 - r} ${H} A${r} ${r} 0 0 1 ${512 + r} ${H} Z" fill="${R}"/>`;
  const horizonte = (x0, x1, t) => `<path d="M${x0} ${H} H${x1}" stroke="${B}" stroke-width="${t}" ${liso}/>`;
  return {
    boasvindas: {
      nomes: ['org.matsu.boasvindas'],
      svg: grade(...cores,
        `<path d="M206 ${H} A306 306 0 0 1 818 ${H} Z" fill="${R}" opacity=".16"/>` +
        sol(250) + broto(40, 22) + horizonte(240, 784, 44) +
        `<path d="M340 748 H684" stroke="${R}" stroke-width="30" ${liso} opacity=".5"/>` +
        `<path d="M420 818 H604" stroke="${R}" stroke-width="26" ${liso} opacity=".28"/>` +
        estrela(300, 330, 46) + estrela(722, 268, 30, B, 0.75)),
      pequeno: grade(...cores,
        sol(262) + broto(54, 24) + horizonte(226, 798, 60) +
        `<path d="M372 768 H652" stroke="${R}" stroke-width="44" ${liso} opacity=".55"/>`, 1.12),
    },
  };
};
