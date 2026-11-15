#!/usr/bin/env node
// Gera os ícones próprios do Matsu (apps do sistema) como SVG.
// Uso: node gerar.js <pasta de saída> [pasta hicolor]
//
// Estilo (a família de 15/11/2026, feita a partir dos desenhos que o Kaiky
// gerou no Google Antigravity): quadrado arredondado com o degradê do app, um
// brilho de vidro na metade de cima e a borda clara fininha; o desenho no meio
// em branco do Matsu, de traço grosso e cantos redondos, com um detalhe rosa de
// cerejeira (a assinatura da família).
//
// Cada app tem duas versões:
//   - <saída>/matsu-<app>.svg: a normal, de 25 px para cima (barra, doca, menu);
//   - <saída>/../pequeno/matsu-<app>.svg: a de 16 a 24 px (lista do gerenciador
//     de tarefas, avisos, buscas), com o desenho maior e sem os detalhes que
//     viram borrão nesse tamanho. O index.theme lista a pasta "pequeno" antes.
// Com a pasta hicolor, os ícones org.matsu.* também vão para lá (cópia), para
// os apps do Matsu continuarem com o ícone deles se a pessoa trocar o tema.
const fs = require('fs');
const path = require('path');

const B = '#F4F6FF';                       // branco do Matsu (nunca branco puro)
const R = '#F0A6CC';                       // rosa de cerejeira (o detalhe da família)
const liso = `stroke-linejoin="round" stroke-linecap="round"`;

// O quadrado do ícone (16 a 240 na grade de 256). O degradê do fundo fica em
// coordenadas da grade (g-<id>), para servir também de "recorte" entre desenhos.
function base(id, c1, c2, extra = '') {
  return `<defs><linearGradient id="g-${id}" gradientUnits="userSpaceOnUse" x1="0" y1="16" x2="0" y2="240"><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></linearGradient>` +
    `<linearGradient id="v-${id}" gradientUnits="userSpaceOnUse" x1="0" y1="16" x2="0" y2="128"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".3"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>` +
    `<linearGradient id="b-${id}" gradientUnits="userSpaceOnUse" x1="0" y1="16" x2="0" y2="240"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".42"/><stop offset=".5" stop-color="#FFFFFF" stop-opacity=".16"/><stop offset="1" stop-color="#FFFFFF" stop-opacity=".1"/></linearGradient>${extra}</defs>` +
    `<rect x="16" y="16" width="224" height="224" rx="58" fill="url(#g-${id})"/>` +
    `<path d="M16 128 V74 A58 58 0 0 1 74 16 H182 A58 58 0 0 1 240 74 V128 Z" fill="url(#v-${id})"/>` +
    `<rect x="17.5" y="17.5" width="221" height="221" rx="56.5" fill="none" stroke="url(#b-${id})" stroke-width="3"/>`;
}

// Os desenhos dos apps são feitos na grade de 1024 dos originais (o quadrado vai
// de 100 a 924, centro 512) e encaixados no quadrado do Matsu. "k" amplia o
// desenho em volta do centro (a versão pequena usa 1,1 a 1,2). Dentro do
// desenho, url(#f-<id>) é o mesmo degradê do fundo: serve para abrir uma folga
// entre duas partes (o lápis em cima da folha, o broto na frente do sol).
const ESCALA = 224 / 824;
function grade(id, c1, c2, desenho, k = 1) {
  const s = ESCALA * k;
  const d = 128 - 512 * s;
  const y1 = (16 - d) / s, y2 = (240 - d) / s;
  const fundo = `<linearGradient id="f-${id}" gradientUnits="userSpaceOnUse" x1="0" y1="${y1.toFixed(1)}" x2="0" y2="${y2.toFixed(1)}"><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></linearGradient>`;
  return base(id, c1, c2, fundo) +
    `<g transform="matrix(${s.toFixed(5)} 0 0 ${s.toFixed(5)} ${d.toFixed(3)} ${d.toFixed(3)})">${desenho}</g>`;
}

// Estrelinha de quatro pontas (brilho), na grade de 1024.
function estrela(cx, cy, r, cor = B, opacidade = 1) {
  const c = r * 0.2;
  return `<path d="M${cx} ${cy - r} Q${cx + c} ${cy - c} ${cx + r} ${cy} Q${cx + c} ${cy + c} ${cx} ${cy + r} ` +
    `Q${cx - c} ${cy + c} ${cx - r} ${cy} Q${cx - c} ${cy - c} ${cx} ${cy - r} Z" fill="${cor}"${opacidade < 1 ? ` opacity="${opacidade}"` : ''}/>`;
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

// Apps do KDE que o Matsu cobre com o ícone dele (os apps do próprio Matsu
// ficam um por arquivo em apps/).
const ICONES = {
  // Monitor do sistema: velocímetro de desempenho (a linha de batimento lembrava coração).
  monitor: {
    nomes: ['utilities-system-monitor', 'org.kde.plasma-systemmonitor'],
    svg: base('mon', '#62E3D5', '#1E9C90') + velocimetro(128, 150, 70, 0.70),
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
};

// Ícones dos apps do Matsu, um arquivo por app em apps/ (Arquivos, Relógio...):
//   module.exports = ({ grade, B, R, liso, estrela }) => ({
//     relogio: { nomes: ['org.matsu.relogio'], svg: grade('rel', '#..', '#..', desenho), pequeno: grade(..., 1.15) },
//   });
const kit = { base, grade, estrela, B, R, liso };
const pastaApps = path.join(__dirname, 'apps');
if (fs.existsSync(pastaApps)) {
  for (const arq of fs.readdirSync(pastaApps).filter((a) => a.endsWith('.js')).sort()) {
    const novos = require(path.join(pastaApps, arq))(kit);
    for (const [nome, ic] of Object.entries(novos)) {
      if (ICONES[nome]) throw new Error(`ícone repetido: ${nome} (${arq})`);
      ICONES[nome] = ic;
    }
  }
}

function gravar(pasta, nome, ic, svgDoIcone) {
  fs.mkdirSync(pasta, { recursive: true });
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">${svgDoIcone}</svg>\n`;
  const principal = `matsu-${nome}.svg`;
  fs.writeFileSync(path.join(pasta, principal), svg);
  for (const n of ic.nomes) {
    const alvo = path.join(pasta, `${n}.svg`);
    try { fs.unlinkSync(alvo); } catch (e) { /* ainda não existe */ }
    fs.symlinkSync(principal, alvo);
  }
  return svg;
}

const saida = process.argv[2];
const hicolor = process.argv[3];
if (!saida) { console.error('uso: node gerar.js <pasta de saída> [pasta hicolor]'); process.exit(1); }
const pequena = path.join(saida, '..', 'pequeno');
let pequenos = 0;
for (const [nome, ic] of Object.entries(ICONES)) {
  const svg = gravar(saida, nome, ic, ic.svg);
  if (ic.pequeno) { gravar(pequena, nome, ic, ic.pequeno); pequenos++; }
  if (hicolor) {
    for (const n of ic.nomes.filter((n) => n.startsWith('org.matsu.'))) {
      fs.mkdirSync(hicolor, { recursive: true });
      fs.writeFileSync(path.join(hicolor, `${n}.svg`), svg);
    }
  }
}
console.log(`${Object.keys(ICONES).length} ícones em ${saida} (${pequenos} com a versão pequena)`);
module.exports = { ICONES };
