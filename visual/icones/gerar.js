#!/usr/bin/env node
// Gera os ícones próprios do Kaelix (apps do sistema) como SVG.
// Uso: node gerar.js <pasta de saída>
// Estilo: quadrado arredondado com degradê da paleta do Kaelix e desenho claro,
// de traço grosso e cantos arredondados, para ler bem até em 22 px na barra.
const fs = require('fs');
const path = require('path');

const B = '#F4F6FF';                       // branco do Kaelix (nunca branco puro)
const liso = `stroke-linejoin="round" stroke-linecap="round"`;

function base(id, c1, c2, extra = '') {
  return `<defs><linearGradient id="g-${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></linearGradient>` +
    `<linearGradient id="b-${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".38"/><stop offset=".5" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>${extra}</defs>` +
    `<rect x="16" y="16" width="224" height="224" rx="58" fill="url(#g-${id})"/>` +
    `<rect x="17.5" y="17.5" width="221" height="221" rx="56.5" fill="none" stroke="url(#b-${id})" stroke-width="3"/>`;
}

function engrenagem(cx, cy, dentes, rFora, rDentro, furo) {
  const p = [];
  const passo = (Math.PI * 2) / dentes;
  for (let i = 0; i < dentes; i++) {
    const a = i * passo - Math.PI / 2;
    const pts = [[a - passo * 0.30, rDentro], [a - passo * 0.17, rFora], [a + passo * 0.17, rFora], [a + passo * 0.30, rDentro]];
    for (const [ang, r] of pts) p.push(`${(cx + Math.cos(ang) * r).toFixed(1)},${(cy + Math.sin(ang) * r).toFixed(1)}`);
  }
  return `<path fill-rule="evenodd" fill="${B}" stroke="${B}" stroke-width="8" ${liso} d="M${p.join(' L')} Z M${cx + furo},${cy} a${furo},${furo} 0 1 0 ${-2 * furo},0 a${furo},${furo} 0 1 0 ${2 * furo},0 Z"/>`;
}

const ICONES = {
  arquivos: {
    nomes: ['system-file-manager', 'org.kde.dolphin'],
    svg: base('arq', '#7C8DFF', '#4353D6') +
      `<path d="M66 98 v-6 a6 6 0 0 1 6 -6 h34 l14 16 h64 a6 6 0 0 1 6 6 v62 h-124 z" fill="${B}" opacity=".5" stroke="${B}" stroke-opacity=".5" stroke-width="6" ${liso}/>` +
      `<path d="M58 124 h140 l-9 58 h-122 z" fill="${B}" stroke="${B}" stroke-width="10" ${liso}/>`,
  },
  terminal: {
    nomes: ['utilities-terminal', 'org.kde.konsole', 'konsole'],
    svg: base('term', '#262C58', '#12152B') +
      `<polyline points="80,96 120,128 80,160" fill="none" stroke="#45D0C1" stroke-width="18" ${liso}/>` +
      `<line x1="136" y1="162" x2="180" y2="162" stroke="${B}" stroke-width="18" ${liso}/>`,
  },
  loja: {
    nomes: ['plasmadiscover', 'org.kde.discover'],
    svg: base('loja', '#FF8FBF', '#DB3F86') +
      `<path d="M104 106 v-10 a24 24 0 0 1 48 0 v10" fill="none" stroke="${B}" stroke-width="12" ${liso}/>` +
      `<path d="M76 108 h104 l8 78 h-120 z" fill="${B}" stroke="${B}" stroke-width="10" ${liso}/>` +
      `<path d="M128 124 v34 m-16 -14 l16 16 l16 -16" fill="none" stroke="#DB3F86" stroke-width="11" ${liso}/>`,
  },
  monitor: {
    nomes: ['utilities-system-monitor', 'org.kde.plasma-systemmonitor'],
    svg: base('mon', '#62E3D5', '#1E9C90') +
      `<polyline points="54,138 90,138 108,92 134,176 152,118 164,138 202,138" fill="none" stroke="${B}" stroke-width="15" ${liso}/>`,
  },
  configuracoes: {
    nomes: ['systemsettings', 'org.kde.systemsettings', 'preferences-system'],
    svg: base('conf', '#A3AEDC', '#5A659F') + engrenagem(128, 128, 8, 66, 50, 22),
  },
  editor: {
    nomes: ['kate', 'org.kde.kate', 'kwrite', 'org.kde.kwrite'],
    svg: base('edit', '#FFC677', '#E98A28') +
      `<path d="M86 64 h62 l26 26 v102 h-88 z" fill="${B}" stroke="${B}" stroke-width="10" ${liso}/>` +
      `<path d="M148 64 v26 h26" fill="none" stroke="#E98A28" stroke-width="8" ${liso}/>` +
      `<path d="M102 122 h56 M102 146 h56 M102 170 h34" fill="none" stroke="#E98A28" stroke-width="10" ${liso}/>`,
  },
  capturas: {
    nomes: ['spectacle', 'org.kde.spectacle'],
    svg: base('cap', '#B093FF', '#6A49DD') +
      `<path d="M72 104 v-22 a10 10 0 0 1 10 -10 h22 M152 72 h22 a10 10 0 0 1 10 10 v22 M184 152 v22 a10 10 0 0 1 -10 10 h-22 M104 184 h-22 a10 10 0 0 1 -10 -10 v-22" fill="none" stroke="${B}" stroke-width="14" ${liso}/>` +
      `<circle cx="128" cy="128" r="22" fill="${B}"/>`,
  },
  imagens: {
    nomes: ['gwenview', 'org.kde.gwenview'],
    svg: base('img', '#39408F', '#C76F90', `<clipPath id="c-img"><rect x="16" y="16" width="224" height="224" rx="58"/></clipPath>`) +
      `<circle cx="170" cy="96" r="24" fill="#FFC677"/>` +
      `<g clip-path="url(#c-img)"><path d="M16 208 L92 124 L132 168 L164 138 L240 214 V240 H16 Z" fill="${B}"/></g>`,
  },
};

const saida = process.argv[2];
if (!saida) { console.error('uso: node gerar.js <pasta de saída>'); process.exit(1); }
fs.mkdirSync(saida, { recursive: true });
for (const [nome, ic] of Object.entries(ICONES)) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">${ic.svg}</svg>\n`;
  const principal = `kaelix-${nome}.svg`;
  fs.writeFileSync(path.join(saida, principal), svg);
  for (const n of ic.nomes) {
    const alvo = path.join(saida, `${n}.svg`);
    try { fs.unlinkSync(alvo); } catch (e) { /* ainda não existe */ }
    fs.symlinkSync(principal, alvo);
  }
}
console.log(`${Object.keys(ICONES).length} ícones em ${saida}`);
module.exports = { ICONES };
