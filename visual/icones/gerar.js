#!/usr/bin/env node
// Gera os ícones próprios do Matsu (apps do sistema) como SVG.
// Uso: node gerar.js <pasta de saída>
// Estilo: quadrado arredondado com degradê da paleta do Matsu e desenho claro,
// de traço grosso e cantos arredondados, para ler bem até em 22 px na barra.
const fs = require('fs');
const path = require('path');

const B = '#F4F6FF';                       // branco do Matsu (nunca branco puro)
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

// Velocímetro: arco claro de fundo, arco cheio até "nivel" (0 a 1) e o ponteiro.
function velocimetro(cx, cy, r, nivel) {
  const a0 = Math.PI * 0.92, a1 = Math.PI * 2.08;
  const ap = a0 + (a1 - a0) * nivel;
  const pt = (a, raio) => `${(cx + raio * Math.cos(a)).toFixed(1)} ${(cy + raio * Math.sin(a)).toFixed(1)}`;
  const grande = ap - a0 > Math.PI ? 1 : 0;
  return `<path d="M${pt(a0, r)} A${r} ${r} 0 1 1 ${pt(a1, r)}" fill="none" stroke="${B}" stroke-opacity=".35" stroke-width="18" ${liso}/>` +
    `<path d="M${pt(a0, r)} A${r} ${r} 0 ${grande} 1 ${pt(ap, r)}" fill="none" stroke="${B}" stroke-width="18" ${liso}/>` +
    `<line x1="${cx}" y1="${cy}" x2="${pt(ap, r - 16).split(' ')[0]}" y2="${pt(ap, r - 16).split(' ')[1]}" stroke="${B}" stroke-width="12" ${liso}/>` +
    `<circle cx="${cx}" cy="${cy}" r="15" fill="${B}"/>`;
}

const ICONES = {
  arquivos: {
    nomes: ['system-file-manager', 'org.kde.dolphin'],
    svg: base('arq', '#7C8DFF', '#4353D6') +
      `<path d="M66 98 v-6 a6 6 0 0 1 6 -6 h34 l14 16 h64 a6 6 0 0 1 6 6 v62 h-124 z" fill="${B}" opacity=".5" stroke="${B}" stroke-opacity=".5" stroke-width="6" ${liso}/>` +
      `<path d="M58 124 h140 l-9 58 h-122 z" fill="${B}" stroke="${B}" stroke-width="10" ${liso}/>`,
  },
  // Terminal do Matsu: grafite quase preto (o fundo do logo), sem o azul.
  terminal: {
    nomes: ['org.matsu.terminal', 'utilities-terminal', 'org.kde.konsole', 'konsole'],
    svg: base('term', '#3A3B42', '#141517') +
      `<polyline points="80,96 120,128 80,160" fill="none" stroke="#45D0C1" stroke-width="18" ${liso}/>` +
      `<line x1="136" y1="162" x2="180" y2="162" stroke="${B}" stroke-width="18" ${liso}/>`,
  },
  // Loja: sacola azul com a seta de baixar (o Kaiky pediu tirar o rosa, 10/11/2026).
  loja: {
    nomes: ['plasmadiscover', 'org.kde.discover'],
    svg: base('loja', '#63D0FF', '#2867E3') +
      `<path d="M100 104 v-12 a28 28 0 0 1 56 0 v12" fill="none" stroke="${B}" stroke-width="13" ${liso}/>` +
      `<path d="M70 104 h116 l-6 74 a14 14 0 0 1 -14 13 h-76 a14 14 0 0 1 -14 -13 z" fill="${B}" stroke="${B}" stroke-width="6" ${liso}/>` +
      `<circle cx="100" cy="120" r="6" fill="#2B78E8" opacity=".9"/><circle cx="156" cy="120" r="6" fill="#2B78E8" opacity=".9"/>` +
      `<path d="M128 132 v32 m-15 -13 l15 15 l15 -15" fill="none" stroke="#2B78E8" stroke-width="11" ${liso}/>`,
  },
  // Monitor do sistema: velocímetro de desempenho (a linha de batimento lembrava coração).
  monitor: {
    nomes: ['utilities-system-monitor', 'org.kde.plasma-systemmonitor'],
    svg: base('mon', '#62E3D5', '#1E9C90') + velocimetro(128, 150, 70, 0.70),
  },
  // Gerenciador de tarefas: o gráfico de desempenho subindo, num anil mais fundo
  // que o dos Arquivos.
  tarefas: {
    nomes: ['org.matsu.tarefas'],
    svg: base('tar', '#6F7CFF', '#2E35B0') +
      `<path d="M62 170 L98 128 L126 150 L162 96 L194 122 V190 H62 Z" fill="${B}" opacity=".26"/>` +
      `<path d="M62 170 L98 128 L126 150 L162 96 L194 122" fill="none" stroke="${B}" stroke-width="15" ${liso}/>` +
      `<line x1="58" y1="192" x2="198" y2="192" stroke="${B}" stroke-width="10" opacity=".55" ${liso}/>` +
      `<circle cx="162" cy="96" r="13" fill="#45D0C1" stroke="${B}" stroke-width="6"/>`,
  },
  // Central de jogos: controle claro sobre o degradê rosa e roxo das bolinhas do
  // Matsu, com a cruz em roxo e os botões nas cores de fechar e tela cheia.
  jogos: {
    nomes: ['org.matsu.jogos'],
    svg: base('jog', '#FF7DB5', '#7A45E0') +
      `<path d="M88 88 h80 a42 42 0 0 1 41 34 l10 50 a24 24 0 0 1 -42 19 l-17 -20 h-64 l-17 20 a24 24 0 0 1 -42 -19 l10 -50 a42 42 0 0 1 41 -34 z" fill="${B}" stroke="${B}" stroke-width="6" ${liso}/>` +
      `<path d="M94 116 v34 M77 133 h34" fill="none" stroke="#7A45E0" stroke-width="12" ${liso}/>` +
      `<circle cx="160" cy="122" r="10" fill="#F0609E"/><circle cx="182" cy="144" r="10" fill="#45D0C1"/>` +
      `<path d="M118 102 h20" stroke="#7A45E0" stroke-opacity=".35" stroke-width="7" ${liso}/>`,
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
  // Imagens: duas fotos, a da frente com paisagem (o desenho antigo parecia um papel de parede).
  imagens: {
    nomes: ['gwenview', 'org.kde.gwenview'],
    svg: base('img', '#39408F', '#C76F90',
      `<clipPath id="c-img"><rect x="-44" y="-36" width="88" height="66" rx="6"/></clipPath>` +
      `<linearGradient id="ceu-img" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8FA2FF"/><stop offset="1" stop-color="#F6B7C8"/></linearGradient>`) +
      `<g transform="translate(116 124) rotate(-12)"><rect x="-56" y="-48" width="112" height="104" rx="12" fill="${B}" opacity=".55"/></g>` +
      `<g transform="translate(138 132) rotate(7)"><rect x="-56" y="-48" width="112" height="104" rx="12" fill="${B}"/>` +
      `<g clip-path="url(#c-img)"><rect x="-44" y="-36" width="88" height="66" fill="url(#ceu-img)"/><circle cx="20" cy="-14" r="10" fill="#FFC677"/>` +
      `<path d="M-44 30 L-14 -4 L6 16 L20 4 L44 28 V30 Z" fill="#4353D6"/></g></g>`,
  },
  // Lixeira do Matsu (vazia e cheia), no fim dos apps da barra, como a do Mac.
  lixeira: {
    nomes: ['user-trash', 'trashcan_empty'],
    svg: base('lix', '#9AA6D6', '#4C5690') + lata(false),
  },
  'lixeira-cheia': {
    nomes: ['user-trash-full', 'trashcan_full'],
    svg: base('lixc', '#9AA6D6', '#4C5690') + lata(true),
  },
};

// Lata de lixo: tampa com alça, corpo com frisos. Cheia: sem tampa, com papéis saindo.
function lata(cheia) {
  const corpo = `<path d="M82 104 h92 l-8 82 a12 12 0 0 1 -12 11 h-52 a12 12 0 0 1 -12 -11 z" fill="${B}" stroke="${B}" stroke-width="8" ${liso}/>` +
    `<path d="M108 122 l2 54 M128 122 v54 M148 122 l-2 54" fill="none" stroke="#5C66A3" stroke-width="9" ${liso}/>`;
  if (!cheia) {
    return corpo + `<path d="M72 88 h112" fill="none" stroke="${B}" stroke-width="14" ${liso}/>` +
      `<path d="M110 84 v-10 a6 6 0 0 1 6 -6 h24 a6 6 0 0 1 6 6 v10" fill="none" stroke="${B}" stroke-width="10" ${liso}/>`;
  }
  return `<g transform="rotate(-14 104 92)"><rect x="80" y="66" width="46" height="56" rx="5" fill="#FFC677"/><path d="M90 82 h26 M90 94 h20" stroke="#E98A28" stroke-width="5" ${liso}/></g>` +
    `<g transform="rotate(12 152 92)"><rect x="130" y="62" width="44" height="58" rx="5" fill="#8FA2FF"/><path d="M140 78 h24 M140 90 h18" stroke="#4353D6" stroke-width="5" ${liso}/></g>` +
    `<path d="M112 98 q16 -26 34 -4 q-8 -22 -30 -12 z" fill="${B}" opacity=".85"/>` +
    corpo;
}

const saida = process.argv[2];
if (!saida) { console.error('uso: node gerar.js <pasta de saída>'); process.exit(1); }
fs.mkdirSync(saida, { recursive: true });
for (const [nome, ic] of Object.entries(ICONES)) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">${ic.svg}</svg>\n`;
  const principal = `matsu-${nome}.svg`;
  fs.writeFileSync(path.join(saida, principal), svg);
  for (const n of ic.nomes) {
    const alvo = path.join(saida, `${n}.svg`);
    try { fs.unlinkSync(alvo); } catch (e) { /* ainda não existe */ }
    fs.symlinkSync(principal, alvo);
  }
}
console.log(`${Object.keys(ICONES).length} ícones em ${saida}`);
module.exports = { ICONES };
