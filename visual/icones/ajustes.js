#!/usr/bin/env node
// Ícones das páginas de configuração (as Configurações do sistema do KDE e o
// que mais o sistema mostra como "ajuste"), no mesmo jeito da lista dos Ajustes
// do Matsu: um quadrado arredondado colorido, como no Mac, com o desenho branco
// de traço grosso. Assim as Configurações do sistema ficam com a cara do Matsu.
// Também faz os ícones dos apps do KDE que vinham com ícone genérico (Ark,
// Firewall, Centro de ajuda, Carteira...). Detalhes em visual/icones/README.md.
//
// Uso: node visual/icones/ajustes.js system_files/usr/share/icons/Matsu system_files/usr/share/icons/Matsu-claro
//
// Cada desenho é feito numa grade de 24 (como os ícones de traço da barra) e
// ampliado para o quadrado de 256. As cores são as dos grupos dos Ajustes.
const fs = require('fs');
const path = require('path');

const B = '#F4F6FF';   // branco do Matsu (nunca branco puro)

// As cores dos grupos, iguais às da lista dos Ajustes do Matsu.
const COR = {
  rede: ['#5A9BFF', '#2563EB'],
  bluetooth: ['#4F86FF', '#1D4ED8'],
  avisos: ['#FF6B6B', '#DC2626'],
  som: ['#FF6FB5', '#DB2777'],
  aparencia: ['#76767F', '#45454E'],
  barra: ['#FFB547', '#E2860B'],
  papel: ['#2CC3D6', '#0A8FA0'],
  telas: ['#A47BFF', '#7042E6'],
  energia: ['#37C774', '#178A45'],
  sistema: ['#8C93A3', '#555B69'],
  teclado: ['#7C8DFF', '#4353D6'],
  seguranca: ['#4FB3FF', '#1C6FD1'],
  idioma: ['#3FD2C3', '#139C8F'],
  apps: ['#FF9A62', '#E25F1F'],
  janelas: ['#6F7CFF', '#2E35B0'],
  pessoas: ['#FFA94D', '#E8730B'],
  fogo: ['#FF8A4C', '#E0452B'],
  arquivo: ['#D9A066', '#A86B32'],
};

function base(id, [c1, c2]) {
  return `<defs><linearGradient id="g-${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></linearGradient>` +
    `<linearGradient id="b-${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".38"/><stop offset=".5" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient></defs>` +
    `<rect x="16" y="16" width="224" height="224" rx="58" fill="url(#g-${id})"/>` +
    `<rect x="17.5" y="17.5" width="221" height="221" rx="56.5" fill="none" stroke="url(#b-${id})" stroke-width="3"/>`;
}

// O desenho: traços (t) e partes cheias (c) na grade de 24, ampliados 6,25x e
// centrados no quadrado (a grade de 24 vira 150 px no meio dos 256).
function desenho({ t = '', c = '', fraco = '' }) {
  let s = `<g transform="translate(53 53) scale(6.25)" stroke-linecap="round" stroke-linejoin="round">`;
  if (fraco) s += `<path d="${fraco}" fill="none" stroke="${B}" stroke-opacity=".45" stroke-width="2"/>`;
  if (c) s += `<path d="${c}" fill="${B}"/>`;
  if (t) s += `<path d="${t}" fill="none" stroke="${B}" stroke-width="2"/>`;
  return s + '</g>';
}

// Engrenagem de verdade (dentes retos), calculada: 8 dentes em volta de um furo.
function engrenagem(cx = 12, cy = 12, R = 8.6, r = 6.5, furo = 2.7) {
  const p = (raio, grau) => {
    const a = (grau - 90) * Math.PI / 180;
    return `${(cx + raio * Math.cos(a)).toFixed(2)} ${(cy + raio * Math.sin(a)).toFixed(2)}`;
  };
  let d = '';
  for (let i = 0; i < 8; i++) {
    const a = i * 45;
    d += (i ? `A${r} ${r} 0 0 1 ` : 'M') + `${p(r, a - 15)} L${p(R, a - 9)} L${p(R, a + 9)} L${p(r, a + 15)} `;
  }
  d += `A${r} ${r} 0 0 1 ${p(r, 345)}z `;
  return d + `M${cx} ${cy - furo}a${furo} ${furo} 0 1 1 0 ${2 * furo}a${furo} ${furo} 0 0 1 0 ${-2 * furo}z`;
}

// Desenhos de traço (grade de 24). Mantidos simples para ler bem em 22 px.
const D = {
  pessoa: { t: 'M12 4.5a3 3 0 1 1 0 6a3 3 0 0 1 0 -6z M5.5 19.5a6.5 6.5 0 0 1 13 0' },
  pessoas: { t: 'M9 5a2.8 2.8 0 1 1 0 5.6a2.8 2.8 0 0 1 0 -5.6z M3.5 19a5.5 5.5 0 0 1 11 0 M15.5 5.3a2.6 2.6 0 0 1 0 5 M17 13.8a5.2 5.2 0 0 1 3.5 5.2' },
  acessibilidade: { t: 'M12 3.5a1.6 1.6 0 1 1 0 3.2a1.6 1.6 0 0 1 0 -3.2z M5 8.5l7 1.5l7 -1.5 M12 10v4.5 M12 14.5l-3.5 6 M12 14.5l3.5 6' },
  camadas: { t: 'M12 4l8.5 4.5l-8.5 4.5l-8.5 -4.5z M3.5 12.5l8.5 4.5l8.5 -4.5 M3.5 16.5l8.5 4.5l8.5 -4.5' },
  brilhos: { t: 'M12 3.5l1.8 5.2l5.2 1.8l-5.2 1.8l-1.8 5.2l-1.8 -5.2l-5.2 -1.8l5.2 -1.8z M18.5 15.5l.8 2.2l2.2 .8l-2.2 .8l-.8 2.2l-.8 -2.2l-2.2 -.8l2.2 -.8z' },
  animacao: { t: 'M14.5 8a5 5 0 1 1 0 10a5 5 0 0 1 0 -10z M3 9.5h5 M2.5 13h4.5 M3 16.5h5' },
  play: { t: 'M12 3.5a8.5 8.5 0 1 1 0 17a8.5 8.5 0 0 1 0 -17z M10 8.5l5.5 3.5l-5.5 3.5z' },
  lupa: { t: 'M10.5 4a6.5 6.5 0 1 1 0 13a6.5 6.5 0 0 1 0 -13z M15.3 15.3l5.2 5.2' },
  relogio: { t: 'M12 3.5a8.5 8.5 0 1 1 0 17a8.5 8.5 0 0 1 0 -17z M12 7.5v4.8l3.2 2' },
  paleta: { t: 'M12 3.5c-4.8 0 -8.5 3.6 -8.5 8.3c0 4.7 3.8 8.7 8 8.7c1.4 0 2 -1 1.6 -2.1c-.5 -1.3 .3 -2.4 1.7 -2.4h2.2c2 0 3.5 -1.6 3.5 -3.6c0 -4.9 -3.8 -8.9 -8.5 -8.9z', c: 'M7.8 10.2a1.3 1.3 0 1 1 0 2.6a1.3 1.3 0 0 1 0 -2.6z M10.8 6.6a1.3 1.3 0 1 1 0 2.6a1.3 1.3 0 0 1 0 -2.6z M15.2 7.4a1.3 1.3 0 1 1 0 2.6a1.3 1.3 0 0 1 0 -2.6z' },
  grade: { t: 'M5 4.5h4.5a.5 .5 0 0 1 .5 .5v4.5a.5 .5 0 0 1 -.5 .5h-4.5a.5 .5 0 0 1 -.5 -.5v-4.5a.5 .5 0 0 1 .5 -.5z M14.5 4.5h4.5a.5 .5 0 0 1 .5 .5v4.5a.5 .5 0 0 1 -.5 .5h-4.5a.5 .5 0 0 1 -.5 -.5v-4.5a.5 .5 0 0 1 .5 -.5z M5 14h4.5a.5 .5 0 0 1 .5 .5v4.5a.5 .5 0 0 1 -.5 .5h-4.5a.5 .5 0 0 1 -.5 -.5v-4.5a.5 .5 0 0 1 .5 -.5z M14 16.8l2 2l3.8 -4' },
  cursor: { t: 'M6 3.5l12 7.2l-5.2 1.4l3.4 6.3l-2.3 1.2l-3.4 -6.3l-4.5 3.4z' },
  pasta: { t: 'M3.5 7.5v-1.5a1.5 1.5 0 0 1 1.5 -1.5h4.2l2 2.2h7.8a1.5 1.5 0 0 1 1.5 1.5v9.3a1.5 1.5 0 0 1 -1.5 1.5h-14a1.5 1.5 0 0 1 -1.5 -1.5z M3.5 10h17' },
  pincel: { t: 'M19.5 4.5c-2 .4 -7.8 5.2 -9.3 7.3l2 2c2.1 -1.5 6.9 -7.3 7.3 -9.3z M10.2 11.8c-2.2 -.2 -3.7 1.2 -3.9 3.2c-.2 1.7 -.9 2.7 -2.3 3.5c2.8 1.4 6.6 .9 7.6 -2.1c.3 -1 .4 -2 -.4 -2.6' },
  janela: { t: 'M4.5 5h15a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1h-15a1 1 0 0 1 -1 -1v-12a1 1 0 0 1 1 -1z M3.5 9h17', c: 'M6.3 6.2a.9 .9 0 1 1 0 1.8a.9 .9 0 0 1 0 -1.8z M9 6.2a.9 .9 0 1 1 0 1.8a.9 .9 0 0 1 0 -1.8z' },
  janelas: { t: 'M8 7.5v-2a1 1 0 0 1 1 -1h10.5a1 1 0 0 1 1 1v8.5a1 1 0 0 1 -1 1h-2.5 M4.5 9.5h11a1 1 0 0 1 1 1v8a1 1 0 0 1 -1 1h-11a1 1 0 0 1 -1 -1v-8a1 1 0 0 1 1 -1z M3.5 12.5h13' },
  tela: { t: 'M4.5 4.5h15a1 1 0 0 1 1 1v9.5a1 1 0 0 1 -1 1h-15a1 1 0 0 1 -1 -1v-9.5a1 1 0 0 1 1 -1z M9 20h6 M12 16v4' },
  teclado: { t: 'M4 6.5h16a1 1 0 0 1 1 1v9a1 1 0 0 1 -1 1h-16a1 1 0 0 1 -1 -1v-9a1 1 0 0 1 1 -1z M8 14.5h8', c: 'M6.2 9.2h1.6v1.6h-1.6z M9.2 9.2h1.6v1.6h-1.6z M12.2 9.2h1.6v1.6h-1.6z M15.2 9.2h1.6v1.6h-1.6z' },
  atalho: { t: 'M15 6.2V17.8A2.8 2.8 0 1 0 17.8 15H6.2A2.8 2.8 0 1 0 9 17.8V6.2A2.8 2.8 0 1 0 6.2 9H17.8A2.8 2.8 0 1 0 15 6.2' },
  mouse: { t: 'M12 3.5a5.5 5.5 0 0 1 5.5 5.5v6a5.5 5.5 0 0 1 -11 0v-6a5.5 5.5 0 0 1 5.5 -5.5z M12 7v3' },
  touchpad: { t: 'M5 4.5h14a1 1 0 0 1 1 1v13a1 1 0 0 1 -1 1h-14a1 1 0 0 1 -1 -1v-13a1 1 0 0 1 1 -1z M4 15h16 M12 15v4.5' },
  toque: { t: 'M9.5 11v-5.5a1.5 1.5 0 0 1 3 0v5 M12.5 10v-1a1.5 1.5 0 0 1 3 0v2 M15.5 10.5a1.5 1.5 0 0 1 3 0v3.5a6.5 6.5 0 0 1 -6.5 6.5h-.5a6 6 0 0 1 -4.6 -2.2l-2.7 -3.4a1.5 1.5 0 0 1 2.3 -1.9l1.5 1.7v-3.2' },
  caneta: { t: 'M15.5 4.5l4 4l-10.5 10.5l-5 1l1 -5z M13.5 6.5l4 4' },
  controle: { t: 'M8 7h8a4.5 4.5 0 0 1 4.4 3.6l1 5.2a2.3 2.3 0 0 1 -4 1.9l-1.8 -2.2h-7.2l-1.8 2.2a2.3 2.3 0 0 1 -4 -1.9l1 -5.2a4.5 4.5 0 0 1 4.4 -3.6z M8 10v3.5 M6.2 11.8h3.6', c: 'M15.2 10a1 1 0 1 1 0 2a1 1 0 0 1 0 -2z M17.4 12.2a1 1 0 1 1 0 2a1 1 0 0 1 0 -2z' },
  sino: { t: 'M6 16.5v-5.5a6 6 0 0 1 12 0v5.5l1.5 1.5h-15z M10 20.5a2.2 2.2 0 0 0 4 0' },
  som: { t: 'M4 9.5h3l5 -4v13l-5 -4h-3z M15.5 9a4 4 0 0 1 0 6 M18 6.5a7.5 7.5 0 0 1 0 11' },
  microfone: { t: 'M12 3.5a3 3 0 0 1 3 3v5a3 3 0 0 1 -6 0v-5a3 3 0 0 1 3 -3z M6 11a6 6 0 0 0 12 0 M12 17v3.5' },
  globo: { t: 'M12 3.5a8.5 8.5 0 1 1 0 17a8.5 8.5 0 0 1 0 -17z M3.5 12h17 M12 3.5c2.4 2.6 3.5 5.4 3.5 8.5s-1.1 5.9 -3.5 8.5c-2.4 -2.6 -3.5 -5.4 -3.5 -8.5s1.1 -5.9 3.5 -8.5z' },
  idioma: { t: 'M4 5.5h9 M8.5 4v1.5 M11 5.5c-.6 3.6 -3 6.6 -6.5 8.5 M6.5 8.5c1.2 2.2 3 3.9 5 5 M13 20l3.5 -8.5l3.5 8.5 M14.2 17h4.6' },
  cadeado: { t: 'M6.5 10.5h11a1 1 0 0 1 1 1v8a1 1 0 0 1 -1 1h-11a1 1 0 0 1 -1 -1v-8a1 1 0 0 1 1 -1z M8.5 10.5v-3a3.5 3.5 0 0 1 7 0v3 M12 14.5v2.5' },
  escudo: { t: 'M12 3.5l7 2.8v5.2c0 4.3 -2.9 7.6 -7 9c-4.1 -1.4 -7 -4.7 -7 -9v-5.2z M9 12l2.2 2.2l4 -4.2' },
  chave: { t: 'M8.5 11a4 4 0 1 1 0 .01z M12.5 11h8 M17.5 11v3 M20.5 11v2.5' },
  raio: { c: 'M13.5 2.8l-8 10.7h5.2l-1.2 7.7l8 -10.7h-5.2z' },
  bateria: { t: 'M4.5 7.5h13a1 1 0 0 1 1 1v7a1 1 0 0 1 -1 1h-13a1 1 0 0 1 -1 -1v-7a1 1 0 0 1 1 -1z M21 10.5v3', c: 'M6 10h7v4h-7z' },
  info: { t: 'M12 3.5a8.5 8.5 0 1 1 0 17a8.5 8.5 0 0 1 0 -17z M12 11v5.5', c: 'M12 6.8a1.2 1.2 0 1 1 0 2.4a1.2 1.2 0 0 1 0 -2.4z' },
  engrenagem: { t: engrenagem() },
  rede: { t: 'M12 3.5a8.5 8.5 0 1 1 0 17a8.5 8.5 0 0 1 0 -17z M3.5 12h17 M12 3.5c2.4 2.6 3.5 5.4 3.5 8.5s-1.1 5.9 -3.5 8.5c-2.4 -2.6 -3.5 -5.4 -3.5 -8.5s1.1 -5.9 3.5 -8.5z' },
  wifi: { t: 'M3 9.5a13 13 0 0 1 18 0 M6 12.8a8.6 8.6 0 0 1 12 0 M9 16a4.2 4.2 0 0 1 6 0', c: 'M12 18a1.4 1.4 0 1 1 0 2.8a1.4 1.4 0 0 1 0 -2.8z' },
  bluetooth: { t: 'M7 7.5l10 9l-5 4.5v-18l5 4.5l-10 9' },
  usb: { t: 'M12 3v14.5 M12 17.5a2 2 0 1 1 0 4a2 2 0 0 1 0 -4z M12 13l-4.5 -3v-2.5 M12 15l4.5 -3v-3 M15 6.5h3v2.5h-3z', c: 'M7.5 5.2a1.6 1.6 0 1 1 0 3.2a1.6 1.6 0 0 1 0 -3.2z M12 1.8l2 2.7h-4z' },
  impressora: { t: 'M7 9v-4.5h10v4.5 M5 9h14a1.5 1.5 0 0 1 1.5 1.5v5.5h-3.5 M7 16h-3.5v-5.5a1.5 1.5 0 0 1 1.5 -1.5 M7 13.5h10v6.5h-10z' },
  disco: { t: 'M4.5 6.5c0 -1.7 3.4 -3 7.5 -3s7.5 1.3 7.5 3v11c0 1.7 -3.4 3 -7.5 3s-7.5 -1.3 -7.5 -3z M4.5 6.5c0 1.7 3.4 3 7.5 3s7.5 -1.3 7.5 -3 M4.5 12c0 1.7 3.4 3 7.5 3s7.5 -1.3 7.5 -3' },
  fonte: { t: 'M3.5 19l5 -14l5 14 M5.3 14h6.4 M16 12.5a2.8 2.8 0 1 1 0 5.6a2.8 2.8 0 0 1 0 -5.6z M18.8 11v8' },
  imagem: { t: 'M4.5 5h15a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1h-15a1 1 0 0 1 -1 -1v-12a1 1 0 0 1 1 -1z M3.5 16l5 -5l4 4l2.5 -2.5l5.5 5.5', c: 'M15.5 7.8a1.7 1.7 0 1 1 0 3.4a1.7 1.7 0 0 1 0 -3.4z' },
  lua: { t: 'M19.5 14.5a7.8 7.8 0 1 1 -10 -10a6.2 6.2 0 0 0 10 10z' },
  sol: { t: 'M12 8a4 4 0 1 1 0 8a4 4 0 0 1 0 -8z M12 2.8v1.7 M12 19.5v1.7 M2.8 12h1.7 M19.5 12h1.7 M5.5 5.5l1.2 1.2 M17.3 17.3l1.2 1.2 M5.5 18.5l1.2 -1.2 M17.3 6.7l1.2 -1.2' },
  barra: { t: 'M4.5 5h15a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1h-15a1 1 0 0 1 -1 -1v-12a1 1 0 0 1 1 -1z', c: 'M6 15h12v2h-12z' },
  ampulheta: { t: 'M7 3.5h10 M7 20.5h10 M8 3.5v3l4 5.5l-4 5.5v3 M16 3.5v3l-4 5.5l4 5.5v3' },
  papel: { t: 'M4.5 5h15a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1h-15a1 1 0 0 1 -1 -1v-12a1 1 0 0 1 1 -1z M3.5 15.5l4.5 -4.5l4 4l3 -3l5.5 5.5', c: 'M16.5 7.8a1.6 1.6 0 1 1 0 3.2a1.6 1.6 0 0 1 0 -3.2z' },
  lixeira: { t: 'M5 6.5h14 M9.5 6.5v-2h5v2 M6.5 6.5l1 13h9l1 -13 M10.2 10v6.5 M13.8 10v6.5' },
  ajuda: { t: 'M12 3.5a8.5 8.5 0 1 1 0 17a8.5 8.5 0 0 1 0 -17z M9.4 9.4a2.7 2.7 0 0 1 5.2 1c0 1.8 -2.6 2.2 -2.6 3.8', c: 'M12 16.2a1.2 1.2 0 1 1 0 2.4a1.2 1.2 0 0 1 0 -2.4z' },
  pacote: { t: 'M12 3.5l7.5 4v9l-7.5 4l-7.5 -4v-9z M4.5 7.5l7.5 4l7.5 -4 M12 11.5v9 M8.2 5.5l7.5 4' },
  peca: { t: 'M4 8h3.8a2.4 2.4 0 1 1 4.4 0h3.8v3.8a2.4 2.4 0 1 1 0 4.4v3.8h-12z' },
  nuvem: { t: 'M7.5 18.5a4 4 0 0 1 -.6 -8a5.5 5.5 0 0 1 10.6 1.3a3.4 3.4 0 0 1 -.5 6.7z' },
  celular: { t: 'M8 3.5h8a1.5 1.5 0 0 1 1.5 1.5v14a1.5 1.5 0 0 1 -1.5 1.5h-8a1.5 1.5 0 0 1 -1.5 -1.5v-14a1.5 1.5 0 0 1 1.5 -1.5z M10.5 17.5h3' },
  compartilhar: { t: 'M17 4a2.5 2.5 0 1 1 0 5a2.5 2.5 0 0 1 0 -5z M7 9.5a2.5 2.5 0 1 1 0 5a2.5 2.5 0 0 1 0 -5z M17 15a2.5 2.5 0 1 1 0 5a2.5 2.5 0 0 1 0 -5z M9.2 10.8l5.6 -3.1 M9.2 13.2l5.6 3.1' },
  privacidade: { t: 'M2.5 12c2.3 -4.2 5.6 -6.5 9.5 -6.5s7.2 2.3 9.5 6.5c-2.3 4.2 -5.6 6.5 -9.5 6.5s-7.2 -2.3 -9.5 -6.5z M12 9a3 3 0 1 1 0 6a3 3 0 0 1 0 -6z M4 20l16 -16' },
  sessao: { t: 'M12 3.5v8 M7 6.2a7.5 7.5 0 1 0 10 0' },
  ok: { t: 'M12 3.5a8.5 8.5 0 1 1 0 17a8.5 8.5 0 0 1 0 -17z M8 12.2l2.8 2.8l5.2 -5.4' },
  clipe: { t: 'M8.5 6.5h-2a1.5 1.5 0 0 0 -1.5 1.5v11a1.5 1.5 0 0 0 1.5 1.5h11a1.5 1.5 0 0 0 1.5 -1.5v-11a1.5 1.5 0 0 0 -1.5 -1.5h-2 M9 4.5h6v3.5h-6z M9 12.5h6 M9 16h4' },
  emoji: { t: 'M12 3.5a8.5 8.5 0 1 1 0 17a8.5 8.5 0 0 1 0 -17z M8.3 14a4.5 4.5 0 0 0 7.4 0', c: 'M9 8.8a1.3 1.3 0 1 1 0 2.6a1.3 1.3 0 0 1 0 -2.6z M15 8.8a1.3 1.3 0 1 1 0 2.6a1.3 1.3 0 0 1 0 -2.6z' },
  calculadora: { t: 'M7 3.5h10a1.5 1.5 0 0 1 1.5 1.5v14a1.5 1.5 0 0 1 -1.5 1.5h-10a1.5 1.5 0 0 1 -1.5 -1.5v-14a1.5 1.5 0 0 1 1.5 -1.5z M8.5 6.5h7v3h-7z', c: 'M8.4 12h1.8v1.8h-1.8z M11.1 12h1.8v1.8h-1.8z M13.8 12h1.8v1.8h-1.8z M8.4 15.2h1.8v1.8h-1.8z M11.1 15.2h1.8v1.8h-1.8z M13.8 15.2h1.8v1.8h-1.8z' },
  documento: { t: 'M6.5 3.5h7.5l4.5 4.5v12.5h-12z M14 3.5v4.5h4.5 M9 12h6 M9 15.5h6' },
  zip: { t: 'M6 3.5h12a1 1 0 0 1 1 1v15a1 1 0 0 1 -1 1h-12a1 1 0 0 1 -1 -1v-15a1 1 0 0 1 1 -1z M11 3.5h2 M12 5.5h1 M11 7.5h1 M12 9.5h1 M10.5 12h3v3.5h-3z' },
  baixar: { t: 'M12 4v11 M7.5 10.5l4.5 4.5l4.5 -4.5 M4.5 19.5h15' },
  caixa: { t: 'M4 5h16a.8 .8 0 0 1 .8 .8v2.9a.8 .8 0 0 1 -.8 .8h-16a.8 .8 0 0 1 -.8 -.8v-2.9a.8 .8 0 0 1 .8 -.8z M5 9.5v9a1.5 1.5 0 0 0 1.5 1.5h11a1.5 1.5 0 0 0 1.5 -1.5v-9 M10 13h4' },
  fogo: { t: 'M12 3.2c.6 3.3 5 5.2 5 10.3a5 5 0 0 1 -10 0c0 -2.6 1.4 -4.2 2.5 -5.2c.2 1.7 .9 2.8 2 3.3c-.3 -2.8 0 -5.7 .5 -8.4z' },
  inseto: { t: 'M9 7.5a3 3 0 0 1 6 0 M8 9.5h8a1 1 0 0 1 1 1v3.5a5 5 0 0 1 -10 0v-3.5a1 1 0 0 1 1 -1z M12 12v7 M3.8 11.5h3.2 M17 11.5h3.2 M4.5 17.5l2.8 -1.5 M19.5 17.5l-2.8 -1.5 M5 6l2.5 2.2 M19 6l-2.5 2.2' },
  alerta: { t: 'M10.3 4.9a2 2 0 0 1 3.4 0l7.1 12.4a2 2 0 0 1 -1.7 3h-14.2a2 2 0 0 1 -1.7 -3z M12 9.5v4.5', c: 'M12 15.9a1.15 1.15 0 1 1 0 2.3a1.15 1.15 0 0 1 0 -2.3z' },
  pizza: { t: 'M10.5 5.6a7.5 7.5 0 1 0 8 8h-8z M14 3.5a7 7 0 0 1 6.5 6.5h-6.5z' },
  omega: { t: 'M5.5 19.5h4.2v-2a6.3 6.3 0 1 1 4.6 0v2h4.2' },
  'pasta-lupa': { t: 'M3.5 17.5v-11a1.5 1.5 0 0 1 1.5 -1.5h4.2l2 2.2h7.8a1.5 1.5 0 0 1 1.5 1.5v2.8 M3.5 17.5a1.5 1.5 0 0 0 1.5 1.5h5 M15.5 11.5a3 3 0 1 1 0 6a3 3 0 0 1 0 -6z M17.7 17.7l2.6 2.6' },
  registros: { t: 'M4 6.5h1.5 M8.5 6.5h11.5 M4 12h1.5 M8.5 12h11.5 M4 17.5h1.5 M8.5 17.5h7.5' },
  'menu-editar': { t: 'M4 6.5h13 M4 11h9 M4 15.5h5 M18 10.5l2.5 2.5l-6.5 6.5h-2.5v-2.5z' },
  remoto: { t: 'M4.5 4.5h15a1 1 0 0 1 1 1v9.5a1 1 0 0 1 -1 1h-15a1 1 0 0 1 -1 -1v-9.5a1 1 0 0 1 1 -1z M9 20h6 M12 16v4 M9.5 12.8l5 -5 M10.5 7.8h4v4' },
  carteira: { t: 'M4 7.5h15a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1h-14a1 1 0 0 1 -1 -1z M4 7.5l11.5 -3.2v3.2 M15.5 11.5h4.5v4.5h-4.5a2.25 2.25 0 0 1 0 -4.5z' },
  chip: { t: 'M8.5 7h7a1.5 1.5 0 0 1 1.5 1.5v7a1.5 1.5 0 0 1 -1.5 1.5h-7a1.5 1.5 0 0 1 -1.5 -1.5v-7a1.5 1.5 0 0 1 1.5 -1.5z M10 3.5v3.5 M14 3.5v3.5 M10 17v3.5 M14 17v3.5 M3.5 10h3.5 M3.5 14h3.5 M17 10h3.5 M17 14h3.5' },
  plasma: { t: 'M4.5 4.5h15a1 1 0 0 1 1 1v13a1 1 0 0 1 -1 1h-15a1 1 0 0 1 -1 -1v-13a1 1 0 0 1 1 -1z M3.5 15.5h17 M13.5 7.5h3.5a.5 .5 0 0 1 .5 .5v3.5a.5 .5 0 0 1 -.5 .5h-3.5a.5 .5 0 0 1 -.5 -.5v-3.5a.5 .5 0 0 1 .5 -.5z' },
  estrela: { t: 'M12 3.8l2.5 5.2l5.7 .8l-4.1 4l1 5.7l-5.1 -2.7l-5.1 2.7l1 -5.7l-4.1 -4l5.7 -.8z' },
  magica: { t: 'M4.5 19.5l10.5 -10.5 M13.2 7.2l3.6 3.6 M18.5 3.5v3 M17 5h3 M9 4v2.5 M7.75 5.25h2.5 M19 12.5v2.5 M17.75 13.75h2.5' },
  'janela-ajuste': { t: 'M4.5 5h15a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1h-15a1 1 0 0 1 -1 -1v-12a1 1 0 0 1 1 -1z M3.5 9h17 M7 12.8h10 M7 15.8h6' },
  quatro: { t: 'M5 4.5h4.5a.5 .5 0 0 1 .5 .5v4.5a.5 .5 0 0 1 -.5 .5h-4.5a.5 .5 0 0 1 -.5 -.5v-4.5a.5 .5 0 0 1 .5 -.5z M14.5 4.5h4.5a.5 .5 0 0 1 .5 .5v4.5a.5 .5 0 0 1 -.5 .5h-4.5a.5 .5 0 0 1 -.5 -.5v-4.5a.5 .5 0 0 1 .5 -.5z M5 14h4.5a.5 .5 0 0 1 .5 .5v4.5a.5 .5 0 0 1 -.5 .5h-4.5a.5 .5 0 0 1 -.5 -.5v-4.5a.5 .5 0 0 1 .5 -.5z M14.5 14h4.5a.5 .5 0 0 1 .5 .5v4.5a.5 .5 0 0 1 -.5 .5h-4.5a.5 .5 0 0 1 -.5 -.5v-4.5a.5 .5 0 0 1 .5 -.5z' },
  bordas: { t: 'M4.5 4.5h15a1 1 0 0 1 1 1v13a1 1 0 0 1 -1 1h-15a1 1 0 0 1 -1 -1v-13a1 1 0 0 1 1 -1z M10 14l6.5 -6.5 M12 7.5h4.5v4.5' },
  cartoes: { t: 'M3.5 8.5h3a1 1 0 0 1 1 1v5a1 1 0 0 1 -1 1h-3a1 1 0 0 1 -1 -1v-5a1 1 0 0 1 1 -1z M17.5 8.5h3a1 1 0 0 1 1 1v5a1 1 0 0 1 -1 1h-3a1 1 0 0 1 -1 -1v-5a1 1 0 0 1 1 -1z', c: 'M10 6.5h4a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 1 -1.5 1.5h-4a1.5 1.5 0 0 1 -1.5 -1.5v-8a1.5 1.5 0 0 1 1.5 -1.5z' },
  proxy: { t: 'M8 7.5h8a1.5 1.5 0 0 1 1.5 1.5v6a1.5 1.5 0 0 1 -1.5 1.5h-8a1.5 1.5 0 0 1 -1.5 -1.5v-6a1.5 1.5 0 0 1 1.5 -1.5z M2.5 12h19 M18.5 9l3 3l-3 3' },
  trafego: { t: 'M8 19.5v-15 M4.5 8l3.5 -3.5l3.5 3.5 M16 4.5v15 M12.5 16l3.5 3.5l3.5 -3.5' },
  balao: { t: 'M5 5h14a1.5 1.5 0 0 1 1.5 1.5v8.5a1.5 1.5 0 0 1 -1.5 1.5h-8l-4.5 3.5v-3.5h-1.5a1.5 1.5 0 0 1 -1.5 -1.5v-8.5a1.5 1.5 0 0 1 1.5 -1.5z M8 9.5h8 M8 12.5h5' },
  nota: { t: 'M9.2 17.5v-11.5l10 -2v11.5', c: 'M6.8 15.3a2.4 2.4 0 1 1 0 4.8a2.4 2.4 0 0 1 0 -4.8z M16.8 13.3a2.4 2.4 0 1 1 0 4.8a2.4 2.4 0 0 1 0 -4.8z' },
  login: { t: 'M4.5 4.5h15a1 1 0 0 1 1 1v9.5a1 1 0 0 1 -1 1h-15a1 1 0 0 1 -1 -1v-9.5a1 1 0 0 1 1 -1z M9 20h6 M12 16v4 M12 6.8a1.9 1.9 0 1 1 0 3.8a1.9 1.9 0 0 1 0 -3.8z M8.5 14.3a3.5 3.5 0 0 1 7 0' },
  comando: { t: 'M4.5 5h15a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1h-15a1 1 0 0 1 -1 -1v-12a1 1 0 0 1 1 -1z M7.5 9.5l3 2.5l-3 2.5 M12.5 15h4' },
  sliders: { t: 'M4 7h8.8 M17.2 7h2.8 M4 12h2.8 M11.2 12h8.8 M4 17h10.8 M19.2 17h.8 M15 4.8a2.2 2.2 0 1 1 0 4.4a2.2 2.2 0 0 1 0 -4.4z M9 9.8a2.2 2.2 0 1 1 0 4.4a2.2 2.2 0 0 1 0 -4.4z M17 14.8a2.2 2.2 0 1 1 0 4.4a2.2 2.2 0 0 1 0 -4.4z' },
  'dia-noite': { t: 'M12 3.5a8.5 8.5 0 1 1 0 17a8.5 8.5 0 0 1 0 -17z', c: 'M12 3.5a8.5 8.5 0 0 1 0 17z' },
  ortografia: { t: 'M3.5 15.5l4 -10l4 10 M5.1 11.5h4.8 M13 15.5l2.6 2.6l5 -5.6' },
  'pessoa-brilho': { t: 'M10 5a3 3 0 1 1 0 6a3 3 0 0 1 0 -6z M3.5 20a6.5 6.5 0 0 1 13 0 M18.5 3.5l.9 2.1l2.1 .9l-2.1 .9l-.9 2.1l-.9 -2.1l-2.1 -.9l2.1 -.9z' },
  'doc-lupa': { t: 'M12.5 20.5h-6v-17h7.5l4.5 4.5v3.5 M14 3.5v4.5h4.5 M15 12.5a2.7 2.7 0 1 1 0 5.4a2.7 2.7 0 0 1 0 -5.4z M17 17.4l2.6 2.6' },
};


// Cada ícone: [nome, desenho, cor, nomes de ícone que ele cobre, jeito].
// Os nomes vêm do inventário da imagem (tests/vm/inventario.sh): o ícone que
// cada app do menu e cada página das Configurações do sistema pede.
//
// Jeito "acao": o nome também é ícone de ação do KDE (aparece pequeno nos
// menus dos apps). Aí o quadrado colorido só vale do tamanho da lista das
// Configurações (22 px) para cima; no tamanho de menu (16 px) continua o ícone
// do Breeze, que é o certo ali (pasta actions/16 do tema, ligada ao Breeze).
//
// Ficam de fora, de propósito, nomes de aparelho e de estado que o sistema usa
// em outros lugares (input-keyboard, drive-removable-media, camera-photo,
// smartphone, battery, video-display, system-log-out...): trocar esses mudaria
// o ícone do pendrive no Arquivos, do teclado no Bluetooth, do "Sair" na tela de
// sair. E apps de outras marcas (Steam, Firefox, VS Code, CoreCtrl, htop...)
// ficam com a logo oficial deles.
const PAGINAS = [
  // Configurações do sistema: aparência
  ['tema-global', 'brilhos', 'aparencia', ['preferences-desktop-theme-global']],
  ['cores', 'paleta', 'aparencia', ['preferences-desktop-color', 'preferences-desktop-color-scheme']],
  ['estilo-plasma', 'plasma', 'aparencia', ['preferences-desktop-plasma-theme']],
  ['estilo-apps', 'pincel', 'aparencia', ['preferences-desktop-theme-applications']],
  ['icones', 'grade', 'aparencia', ['preferences-desktop-icons']],
  ['cursores', 'cursor', 'aparencia', ['preferences-desktop-cursors']],
  ['fontes', 'fonte', 'aparencia', ['preferences-desktop-font']],
  ['gerenciar-fontes', 'fonte', 'apps', ['preferences-desktop-font-installer', 'kfontview', 'org.kde.kfontview']],
  ['animacoes', 'animacao', 'aparencia', ['preferences-desktop-animations']],
  ['tela-de-carregamento', 'ampulheta', 'aparencia', ['preferences-system-splash']],
  ['papel-de-parede', 'papel', 'papel', ['preferences-desktop-wallpaper']],
  ['personalizacao', 'pessoa-brilho', 'telas', ['preferences-desktop-user']],
  // janelas e área de trabalho
  ['area-de-trabalho', 'sliders', 'teclado', ['preferences-desktop']],
  ['decoracao', 'janela', 'janelas', ['preferences-desktop-theme-windowdecorations']],
  ['janelas', 'janelas', 'janelas', ['preferences-system-windows']],
  ['regras-janelas', 'janela-ajuste', 'janelas', ['preferences-system-windows-actions']],
  ['efeitos', 'magica', 'janelas', ['preferences-desktop-effects']],
  ['areas-virtuais', 'quatro', 'janelas', ['preferences-desktop-virtual']],
  ['bordas', 'bordas', 'janelas', ['preferences-desktop-gestures-screenedges']],
  ['gestos', 'toque', 'janelas', ['preferences-desktop-gestures-touch']],
  ['seletor-tarefas', 'cartoes', 'janelas', ['preferences-system-tabbox']],
  ['atividades', 'camadas', 'janelas', ['preferences-desktop-activities']],
  ['kwin', 'janelas', 'sistema', ['kwin']],
  ['apps-padrao', 'estrela', 'apps', ['preferences-desktop-default-applications']],
  ['tipos-de-arquivo', 'documento', 'apps', ['preferences-desktop-filetype-association']],
  ['inicio-automatico', 'play', 'apps', ['system-run'], 'acao'],
  ['servicos', 'engrenagem', 'sistema', ['preferences-system-session-services']],
  // pesquisa
  ['pesquisa', 'lupa', 'rede', ['preferences-desktop-search', 'plasma-search', 'preferences-system-search']],
  ['pesquisa-arquivos', 'doc-lupa', 'sistema', ['preferences-desktop-baloo']],
  ['krunner', 'comando', 'aparencia', ['krunner']],
  ['web', 'globo', 'apps', ['preferences-web-browser-shortcuts']],
  // telas
  ['telas', 'tela', 'telas', ['preferences-desktop-display', 'preferences-desktop-display-randr']],
  ['luz-noturna', 'lua', 'telas', ['preferences-desktop-display-nightcolor', 'redshift-status-on']],
  ['luz-noturna-desligada', 'lua', 'sistema', ['redshift-status-off']],
  ['luz-noturna-dia', 'sol', 'barra', ['redshift-status-day']],
  ['dia-noite', 'dia-noite', 'telas', ['lighttable'], 'acao'],
  ['thunderbolt', 'raio', 'telas', ['preferences-desktop-thunderbolt']],
  // entrada
  ['teclado', 'teclado', 'teclado', ['preferences-desktop-keyboard']],
  ['atalhos', 'atalho', 'teclado', ['preferences-desktop-keyboard-shortcut']],
  ['mouse', 'mouse', 'teclado', ['preferences-desktop-mouse']],
  ['touchpad', 'touchpad', 'teclado', ['preferences-desktop-touchpad']],
  ['tela-de-toque', 'toque', 'teclado', ['preferences-desktop-touchscreen']],
  ['mesa-digitalizadora', 'caneta', 'teclado', ['preferences-desktop-tablet']],
  ['controles', 'controle', 'teclado', ['preferences-desktop-gaming']],
  ['acessibilidade', 'acessibilidade', 'pessoas', ['preferences-desktop-accessibility', 'kaccess']],
  // som e avisos
  ['notificacoes', 'sino', 'avisos', ['preferences-desktop-notification-bell', 'preferences-desktop-notification']],
  ['som', 'som', 'som', ['preferences-desktop-sound']],
  ['multimidia', 'nota', 'som', ['preferences-desktop-multimedia']],
  ['sons-do-sistema', 'nota', 'avisos', ['emblem-music-symbolic']],
  // idioma e horário
  ['idioma', 'idioma', 'idioma', ['preferences-desktop-locale']],
  ['data-e-hora', 'relogio', 'idioma', ['preferences-system-time']],
  ['ortografia', 'ortografia', 'idioma', ['tools-check-spelling'], 'acao'],
  // pessoas e segurança
  ['usuarios', 'pessoa', 'pessoas', ['preferences-system-users']],
  ['tela-de-login', 'login', 'seguranca', ['preferences-system-login']],
  ['seguranca', 'escudo', 'seguranca', ['preferences-security']],
  ['bloqueio', 'cadeado', 'seguranca', ['preferences-desktop-user-password']],
  ['carteira', 'carteira', 'seguranca', ['kwalletmanager', 'org.kde.kwalletmanager']],
  ['feedback', 'balao', 'idioma', ['preferences-desktop-feedback']],
  // energia
  ['energia', 'raio', 'energia', ['preferences-system-power-management']],
  ['atualizacoes', 'baixar', 'energia', ['system-software-update']],
  // rede
  ['rede', 'globo', 'rede', ['preferences-system-network']],
  ['conexao', 'trafego', 'rede', ['preferences-system-network-connection']],
  ['proxy', 'proxy', 'rede', ['preferences-system-network-proxy']],
  ['remoto', 'remoto', 'rede', ['preferences-system-network-remote']],
  ['compartilhar', 'compartilhar', 'rede', ['preferences-system-network-sharing']],
  ['contas-online', 'nuvem', 'rede', ['preferences-online-accounts']],
  ['bluetooth', 'bluetooth', 'bluetooth', ['preferences-system-bluetooth']],
  // aparelhos
  ['dispositivos', 'usb', 'sistema', ['preferences-desktop-peripherals']],
  ['impressoras', 'impressora', 'sistema', ['preferences-devices-printer']],
  ['discos', 'disco', 'sistema', ['preferences-system-disks']],
  ['smart', 'disco', 'energia', ['preferences-smart-status']],
  ['cpu', 'chip', 'sistema', ['preferences-devices-cpu']],
  ['sobre', 'info', 'sistema', ['ktip']],
  // apps do sistema que aparecem no menu
  ['informacoes', 'chip', 'janelas', ['hwinfo', 'kinfocenter', 'org.kde.kinfocenter']],
  ['ajuda', 'ajuda', 'seguranca', ['help-browser', 'khelpcenter', 'org.kde.khelpcenter']],
  ['compactador', 'caixa', 'arquivo', ['ark', 'org.kde.ark', 'utilities-file-archiver']],
  ['firewall', 'fogo', 'fogo', ['firewall-config']],
  ['uso-do-disco', 'pizza', 'papel', ['filelight', 'org.kde.filelight']],
  ['caracteres', 'omega', 'idioma', ['accessories-character-map', 'kcharselect', 'org.kde.kcharselect']],
  ['busca-arquivos', 'pasta-lupa', 'rede', ['kfind', 'org.kde.kfind']],
  ['registros', 'registros', 'sistema', ['org.kde.kjournaldbrowser', 'kjournaldbrowser']],
  ['editor-de-menus', 'menu-editar', 'apps', ['kmenuedit', 'org.kde.kmenuedit']],
  ['particoes', 'disco', 'telas', ['partitionmanager', 'org.kde.partitionmanager']],
  ['compartilhar-tela', 'remoto', 'papel', ['krfb', 'org.kde.krfb']],
  ['celular', 'celular', 'bluetooth', ['kdeconnect', 'org.kde.kdeconnect', 'org.kde.kdeconnect.app']],
  ['emoji', 'emoji', 'barra', ['preferences-desktop-emoticons', 'org.kde.plasma.emojier']],
  ['calculadora', 'calculadora', 'sistema', ['accessories-calculator', 'kcalc', 'org.kde.kcalc']],
  ['documentos', 'documento', 'avisos', ['okular', 'org.kde.okular']],
  // Estes o build.sh põe direto no .desktop do app (o nome original é ícone de
  // ação: tools-report-bug e debug-run aparecem no menu Ajuda de todo app).
  ['falhas', 'alerta', 'avisos', []],
  ['depuracao', 'inseto', 'sistema', []],
  // "Estilo da barra" (matsu-barra.desktop)
  ['barra', 'barra', 'barra', []],
];

// O logo do Matsu no lugar do logo do KDE (Centro de boas-vindas e o menu do
// KDE, se alguém puser).
const LOGO = ['start-here-kde-plasma', 'start-here-kde', 'start-here'];

// Uso: node ajustes.js <tema> [<tema>...]  (as pastas dos temas Matsu e Matsu-claro)
const temas = process.argv.slice(2);
if (!temas.length) { console.error('uso: node ajustes.js <pasta do tema> [...]'); process.exit(1); }

function ligar(alvo, para) {
  try {
    const st = fs.lstatSync(alvo);
    if (!st.isSymbolicLink()) return false;              // ícone desenhado à mão: não passa por cima
    const atual = fs.readlinkSync(alvo);
    // ligação de outro gerador (gerar.js): também não mexe
    if (!/matsu-ajuste-|matsu-logo|\/icons\/breeze/.test(atual)) return false;
    fs.unlinkSync(alvo);
  } catch (e) { /* ainda não existe */ }
  fs.symlinkSync(para, alvo);
  return true;
}

for (const tema of temas) {
  const index = fs.readFileSync(path.join(tema, 'index.theme'), 'utf8');
  const pai = (index.match(/^Inherits=([^,\n]+)/m) || [])[1] || 'breeze';
  for (const d of ['apps/scalable', 'ajustes/scalable', 'actions/16']) {
    if (!new RegExp(`^Directories=.*\\b${d.replace('/', '\\/')}\\b`, 'm').test(index)) throw new Error(`${tema}/index.theme sem a pasta ${d}`);
  }
  const apps = path.join(tema, 'apps/scalable');
  const ajustes = path.join(tema, 'ajustes/scalable');
  const acoes = path.join(tema, 'actions/16');
  for (const p of [apps, ajustes, acoes]) fs.mkdirSync(p, { recursive: true });

  // limpa o que este gerador fez antes (para nome tirado da lista não ficar)
  for (const pasta of [apps, ajustes, acoes]) {
    for (const f of fs.readdirSync(pasta)) {
      const alvo = path.join(pasta, f);
      const st = fs.lstatSync(alvo);
      if (st.isSymbolicLink() && /matsu-ajuste-|matsu-logo|\/icons\/breeze/.test(fs.readlinkSync(alvo))) fs.unlinkSync(alvo);
      else if (!st.isSymbolicLink() && /^matsu-ajuste-/.test(f)) fs.unlinkSync(alvo);
    }
  }

  const feitos = new Set();
  let n = 0, nomes = 0;
  for (const [id, des, cor, lista, jeito] of PAGINAS) {
    if (!D[des]) throw new Error(`desenho que não existe: ${des}`);
    if (!COR[cor]) throw new Error(`cor que não existe: ${cor}`);
    const principal = `matsu-ajuste-${id}.svg`;
    fs.writeFileSync(path.join(apps, principal),
      `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">${base(id, COR[cor])}${desenho(D[des])}</svg>\n`);
    n++;
    for (const nome of lista) {
      if (feitos.has(nome)) throw new Error(`nome repetido na lista: ${nome}`);
      feitos.add(nome);
      if (jeito === 'acao') {
        ligar(path.join(ajustes, `${nome}.svg`), `../../apps/scalable/${principal}`);
        ligar(path.join(acoes, `${nome}.svg`), `/usr/share/icons/${pai}/actions/16/${nome}.svg`);
      } else {
        ligar(path.join(apps, `${nome}.svg`), principal);
      }
      nomes++;
    }
  }
  for (const nome of LOGO) ligar(path.join(apps, `${nome}.svg`), '../../../hicolor/scalable/apps/matsu-logo.svg');
  console.log(`${tema}: ${n} ícones, ${nomes} nomes cobertos (+${LOGO.length} com o logo)`);
}
module.exports = { D, PAGINAS, COR };
