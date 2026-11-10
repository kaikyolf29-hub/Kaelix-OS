'use strict';
const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
const stage = $('#stage');
const DUR = 38.5;
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const E = {
  lin: x => x,
  io: x => x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2,
  out: x => 1 - Math.pow(1 - x, 3),
  inn: x => x * x * x,
  back: x => { const c1 = 1.25, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); },
};
const seg = (t, t0, d, e = E.io) => e(clamp((t - t0) / d));
const lerp = (a, b, p) => a + (b - a) * p;

/* ---------- tema ---------- */
const THEME = {
  bg: ['#222848', '#E3E8F8'], sun: ['#F2B45A', '#F4BE6A'],
  d1: ['#2B3360', '#CDD6F4'], d2: ['#364078', '#B7C3EE'], d3: ['#445092', '#9FAEE6'], d4: ['#5361AE', '#8898DC'],
  fg: ['#F1F3FA', '#1B2038'], fg2: ['#D5DAEE', '#3A4162'], muted: ['#B9C0DA', '#4A5170'],
  win: ['rgba(32,37,62,0.88)', 'rgba(246,248,254,0.9)'], term: ['rgba(24,28,48,0.74)', 'rgba(250,251,255,0.82)'],
  glass: ['rgba(30,35,60,0.5)', 'rgba(255,255,255,0.58)'], panel: ['rgba(30,35,60,0.62)', 'rgba(255,255,255,0.66)'],
  edge: ['rgba(255,255,255,0.17)', 'rgba(255,255,255,0.85)'],
  shadow: ['rgba(10,12,30,0.5)', 'rgba(50,60,120,0.28)'], shadow2: ['rgba(10,12,30,0.4)', 'rgba(50,60,120,0.22)'],
  tint0: ['rgba(255,255,255,0.03)', 'rgba(27,32,56,0.035)'], tint1: ['rgba(255,255,255,0.04)', 'rgba(27,32,56,0.07)'],
  tint2: ['rgba(255,255,255,0.1)', 'rgba(27,32,56,0.08)'], tint2b: ['rgba(255,255,255,0.12)', 'rgba(27,32,56,0.08)'],
  tint3: ['rgba(255,255,255,0.18)', 'rgba(27,32,56,0.16)'],
  field: ['rgba(20,24,44,0.55)', 'rgba(255,255,255,0.8)'], line: ['rgba(255,255,255,0.08)', 'rgba(27,32,56,0.1)'],
  sel: ['rgba(84,104,232,0.28)', 'rgba(84,104,232,0.16)'], selside: ['rgba(84,104,232,0.4)', 'rgba(84,104,232,0.2)'],
  slider: ['#F1F3FA', '#5468E8'], seg: ['rgba(20,24,44,0.5)', 'rgba(27,32,56,0.1)'], segon: ['#F1F3FA', '#FFFFFF'],
  prompt: ['#F2B45A', '#9A5B00'], cmd: ['#7FE0D6', '#0B6B62'], iconacc: ['#8FA2FF', '#4558D6'],
  tip: ['rgba(30,35,60,0.85)', 'rgba(255,255,255,0.9)'],
};
function parse(c) {
  if (c[0] === '#') return [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16), 1];
  return c.match(/[\d.]+/g).map(Number);
}
const mix = (a, b, p) => a.map((v, i) => lerp(v, b[i], p));
const css = c => `rgba(${c[0].toFixed(1)},${c[1].toFixed(1)},${c[2].toFixed(1)},${c[3].toFixed(3)})`;
for (const k in THEME) THEME[k] = THEME[k].map(parse);
let lastTheme = -1;
function setTheme(p) {
  if (p === lastTheme) return; lastTheme = p;
  for (const k in THEME) stage.style.setProperty('--' + k, css(mix(THEME[k][0], THEME[k][1], p)));
  const tile = $('#darktile');
  tile.style.background = css(mix(parse('#5468E8'), mix(THEME.tint2[0], THEME.tint2[1], p), p));
  tile.style.color = css(mix(parse('#FFFFFF'), THEME.fg[1], p));
  $('#darklbl').textContent = p < .5 ? 'Ligado' : 'Desligado';
}

/* ---------- medidas ---------- */
let P = {}, dockBase = [], scale = 1;
function ctr(el) {
  const r = el.getBoundingClientRect(), s = stage.getBoundingClientRect();
  return { x: (r.left + r.width / 2 - s.left) / scale, y: (r.top + r.height / 2 - s.top) / scale, w: r.width / scale, h: r.height / scale, l: (r.left - s.left) / scale, t: (r.top - s.top) / scale };
}
const dks = $$('.dk');
const IC = {"folder": "<path d=\"M3 7.5a2 2 0 0 1 2-2h4l2 2.5h8a2 2 0 0 1 2 2V17a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z\"/>", "term": "<path d=\"M5 8l4 4-4 4\"/><path d=\"M12 16h7\"/>", "doc": "<path d=\"M7 3.5h7l4 4V19a1.5 1.5 0 0 1-1.5 1.5h-9.5A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z\"/><path d=\"M14 3.5v4h4\"/>", "game": "<path d=\"M7.5 8h9a4.5 4.5 0 0 1 4.4 5.4l-.6 3a2.6 2.6 0 0 1-4.5 1.2L14 15.5h-4l-1.8 2.1a2.6 2.6 0 0 1-4.5-1.2l-.6-3A4.5 4.5 0 0 1 7.5 8z\"/><path d=\"M8 10.8v3M6.5 12.3h3\"/>", "pulse": "<path d=\"M3 12h4l2.5-6 4 12 2.5-6h5\"/>"};
const RECENT = [
  ['#5468E8', 'Arquivos', 'App', 'folder'], ['#343B63', 'Terminal do Kaelix', 'App', 'term'], ['#6B7399', 'plano-kaelix.md', 'Texto em Downloads', 'doc'],
];
const RESULTS = [
  ['#7C6BE6', 'Jogos', 'App: Steam, Heroic e Lutris num lugar só', 'game'], ['#3E9C7A', 'Modo jogo', 'Configurações: mais desempenho ao jogar', 'pulse'], ['#5468E8', 'jogos-salvos', 'Pasta em Documentos', 'folder'],
];
function rows(list, hi) {
  return list.map((r, i) => `<div class="lrow" style="${i === hi ? 'background:var(--selside)' : ''}"><span class="ic" style="background:${r[0]}"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">${IC[r[3]]}</svg></span><span><b>${r[1]}</b><small>${r[2]}</small></span></div>`).join('');
}
function measure() {
  $('#lrows').innerHTML = rows(RESULTS, -1);
  dockBase = dks.map(d => ctr(d.querySelector('button')));
  P.files = dockBase[0]; P.termIcon = dockBase[2]; P.settings = dockBase[7];
  P.filesWin = ctr($('#files')); P.termWin = ctr($('#term'));
  P.min = ctr($('#minbtn')); P.tray = ctr($('#tray'));
  const tr = ctr($('#voltrack')); P.vol = v => ({ x: tr.l + tr.w * v / 100, y: tr.y });
  P.dark = ctr($('#darktile')); P.search = ctr($('#search'));
  P.res1 = ctr($('#lrows').firstElementChild);
  build();
}

/* ---------- roteiro ---------- */
let CUR = [], CLICKS = [], CAPS = [];
function build() {
  const v62 = P.vol(62), v86 = P.vol(86);
  CUR = [
    [4.2, 760, 470], [5.6, P.settings.x, P.settings.y + 4], [7.1, P.files.x, P.files.y + 4], [8.0, P.files.x, P.files.y + 4],
    [8.9, P.termIcon.x, P.termIcon.y + 4], [9.3, P.termIcon.x, P.termIcon.y + 4], [10.1, 880, 640], [15.0, 880, 640],
    [15.8, P.min.x + 2, P.min.y + 3], [16.4, P.min.x + 2, P.min.y + 3], [17.4, P.termIcon.x, P.termIcon.y + 4], [18.2, P.termIcon.x, P.termIcon.y + 4],
    [19.6, P.tray.x, P.tray.y + 4], [20.4, P.tray.x, P.tray.y + 4], [21.2, v62.x, v62.y + 3], [21.4, v62.x, v62.y + 3], [22.4, v86.x, v86.y + 3], [22.6, v86.x, v86.y + 3],
    [23.6, P.dark.x + 30, P.dark.y + 8], [28.9, P.dark.x + 30, P.dark.y + 8], [29.6, 960, 250], [30.0, 960, 250],
    [31.0, P.search.x - 30, P.search.y + 4], [32.8, P.search.x - 30, P.search.y + 4], [33.7, P.res1.x - 60, P.res1.y + 4], [40, P.res1.x - 60, P.res1.y + 4],
  ];
  CLICKS = [7.4, 9.1, 16.0, 17.7, 19.8, 23.9, 27.3, 29.75, 31.2];
  CAPS = [
    [2.9, 4.6, 'Demonstração do visual. Ainda não é o sistema rodando.'],
    [4.9, 8.6, 'Os ícones do Dock crescem quando o mouse passa'],
    [8.9, 15.2, 'As janelas abrem a partir do Dock, com vidro e os botões do Kaelix'],
    [15.5, 19.2, 'Minimizar guarda a janela no Dock'],
    [19.5, 23.5, 'Rede, som e brilho ficam no canto direito, perto do relógio'],
    [23.8, 30.4, 'Tema escuro e tema claro. Nenhum dos dois usa preto puro'],
    [30.7, 35.0, 'Busca de apps e arquivos no canto esquerdo'],
  ];
}
function cursorAt(t) {
  if (t <= CUR[0][0]) return { x: CUR[0][1], y: CUR[0][2] };
  for (let i = 1; i < CUR.length; i++) if (t <= CUR[i][0]) {
    const a = CUR[i - 1], b = CUR[i], p = E.io((t - a[0]) / (b[0] - a[0]));
    return { x: lerp(a[1], b[1], p), y: lerp(a[2], b[2], p) };
  }
  const l = CUR[CUR.length - 1]; return { x: l[1], y: l[2] };
}

/* ---------- terminal ---------- */
const CMD = 'kaelix atualizar';
function termHTML(t) {
  const pr = '<span class="pr">kaiky@kaelix</span> <span class="muted">~</span> $ ';
  const n = Math.round(clamp((t - 10.3) / 1.3) * CMD.length);
  const blink = (Math.floor(t * 2) % 2 === 0) ? '<span class="caret"></span>' : '<span class="caret" style="opacity:0"></span>';
  let h = pr + CMD.slice(0, n) + (t < 11.8 ? (t > 10.3 && t < 11.6 ? '<span class="caret"></span>' : blink) : '') + '\n';
  if (t >= 12.0) h += '<span class="muted">Procurando versão nova no canal de teste...</span>\n';
  if (t >= 12.6) h += 'Versão 2026.11.10 encontrada. <span class="ok">Assinatura conferida.</span>\n';
  if (t >= 12.9) {
    const p = seg(t, 12.9, 1.4, E.io);
    h += `Baixando  <span style="display:inline-block;width:200px;height:8px;border-radius:4px;background:var(--tint3);vertical-align:1px"><span style="display:block;width:${(p * 100).toFixed(1)}%;height:8px;border-radius:4px;background:var(--cmd)"></span></span>  ${String(Math.round(p * 100)).padStart(3)}%\n`;
  }
  if (t >= 14.5) h += '<span class="ok">Pronto.</span> A versão nova entra na próxima vez que ligar.\n';
  if (t >= 14.7) h += pr + blink;
  return h;
}

/* ---------- quadro ---------- */
const el = { splash: $('#splash'), end: $('#endcard'), sun: $('#sun'), dunes: $$('.dune'), islL: $('#islL'), islR: $('#islR'), dock: $('#dock'), files: $('#files'), term: $('#term'), cc: $('#cc'), launch: $('#launch'), cur: $('#cursor'), rip: $('#ripple'), cap: $('#caption'), tip: $('#tip'), termout: $('#termout') };
let lastTerm = '', lastRows = '';
function winState(w, v, from, win) {
  const dx = (from.x - win.x) * (1 - v), dy = (from.y - win.y) * (1 - v);
  const s = lerp(0.1, 1, v) + 0.025 * Math.sin(Math.PI * v);
  w.style.transform = `translate(${dx.toFixed(2)}px,${dy.toFixed(2)}px) scale(${s.toFixed(4)})`;
  w.style.opacity = clamp(v * 2.2).toFixed(3);
  w.style.visibility = v <= 0.001 ? 'hidden' : 'visible';
}
function seek(t) {
  // abertura
  const sp = 1 - seg(t, 1.7, 0.9);
  el.splash.style.opacity = sp.toFixed(3); el.splash.style.display = sp <= 0 ? 'none' : 'flex';
  const wp = seg(t, 1.7, 2.4, E.out);
  el.sun.setAttribute('transform', `translate(0 ${((1 - wp) * 150).toFixed(2)})`);
  el.dunes.forEach((d, i) => d.setAttribute('transform', `translate(0 ${((1 - wp) * (40 + i * 26)).toFixed(2)})`));
  const endP = seg(t, 35.3, 0.9);
  const rise = (e, t0, cx) => { const p = seg(t, t0, 0.75, E.back), o = seg(t, t0, 0.35, E.out); e.style.transform = `${cx ? 'translateX(-50%) ' : ''}translateY(${((1 - p) * 120).toFixed(2)}px)`; e.style.opacity = o.toFixed(3); };
  rise(el.islL, 2.7); rise(el.dock, 2.85, true); rise(el.islR, 3.0);

  // tema
  setTheme(+(seg(t, 23.95, 1.3) - seg(t, 27.35, 1.3)).toFixed(4));

  // cursor e cliques
  const c = cursorAt(t);
  let press = 0, lastClick = -9;
  for (const k of CLICKS) { press = Math.max(press, 1 - clamp(Math.abs(t - k) / 0.13)); if (k <= t) lastClick = k; }
  if (t > 21.35 && t < 22.5) press = 1;
  el.cur.style.opacity = (seg(t, 4.2, 0.3) * (1 - endP)).toFixed(3);
  el.cur.style.transform = `translate(${(c.x - 2).toFixed(2)}px,${(c.y - 2).toFixed(2)}px) scale(${(1 - 0.14 * press).toFixed(3)})`;
  const rp = clamp((t - lastClick) / 0.5);
  const cl = cursorAt(lastClick);
  el.rip.style.transform = `translate(${cl.x.toFixed(1)}px,${cl.y.toFixed(1)}px) scale(${(0.25 + 0.9 * E.out(rp)).toFixed(3)})`;
  el.rip.style.opacity = (lastClick < 0 || rp >= 1 ? 0 : 0.75 * (1 - rp)).toFixed(3);

  // dock: aumento perto do mouse, pulo ao abrir, bolinhas
  const hov = E.io(clamp((c.y - 770) / 50)) * seg(t, 4.2, 0.3) * (1 - endP);
  let near = -1, nd = 1e9;
  dks.forEach((d, i) => {
    const dx = c.x - dockBase[i].x; if (Math.abs(dx) < nd) { nd = Math.abs(dx); near = i; }
    const s = 1 + 0.42 * hov * Math.exp(-Math.pow(dx / 66, 2));
    const b = d.querySelector('button'), sv = b.firstElementChild;
    b.style.width = b.style.height = (48 * s).toFixed(2) + 'px'; b.style.borderRadius = (14 * s).toFixed(2) + 'px';
    sv.style.width = sv.style.height = (26 * s).toFixed(2) + 'px';
    let hop = 0;
    for (const [k, idx] of [[7.4, 0], [9.1, 2], [17.7, 2]]) if (idx === i && t >= k && t < k + 0.55) hop = Math.sin(Math.PI * (t - k) / 0.55) * 14;
    b.style.transform = `translateY(${(-hop).toFixed(2)}px)`;
  });
  dks[0].querySelector('i').style.opacity = seg(t, 7.5, 0.3).toFixed(2);
  dks[2].querySelector('i').style.opacity = seg(t, 9.2, 0.3).toFixed(2);
  const tipOn = hov > 0.6 && nd < 36 ? 1 : 0;
  if (tipOn) { const r = ctr(dks[near].querySelector('button')); el.tip.textContent = dks[near].dataset.n; el.tip.style.left = r.x.toFixed(1) + 'px'; el.tip.style.top = (r.t - 10).toFixed(1) + 'px'; }
  el.tip.style.opacity = tipOn * (1 - endP);

  // janelas
  winState(el.files, seg(t, 7.45, 0.6, E.out), P.files, P.filesWin);
  const tv = seg(t, 9.15, 0.6, E.out) * (1 - seg(t, 16.05, 0.55, E.io) + seg(t, 17.75, 0.55, E.out));
  winState(el.term, tv, P.termIcon, P.termWin);
  const th = termHTML(t); if (th !== lastTerm) { el.termout.innerHTML = th; lastTerm = th; }
  $('#minbtn').style.transform = `scale(${(1 + 0.25 * seg(t, 15.7, 0.2) * (1 - seg(t, 16.1, 0.2))).toFixed(3)})`;

  // central de controle
  const cc = seg(t, 19.85, 0.45, E.out) - seg(t, 29.8, 0.3, E.inn);
  el.cc.style.transform = `translateY(${((1 - cc) * 22).toFixed(2)}px) scale(${(0.9 + 0.1 * cc).toFixed(4)})`;
  el.cc.style.opacity = cc.toFixed(3); el.cc.style.visibility = cc <= 0.001 ? 'hidden' : 'visible';
  $('#trayhl').style.opacity = cc.toFixed(3);
  const vol = 62 + 24 * seg(t, 21.4, 1.0, E.io);
  $('#volfill').style.width = vol.toFixed(2) + '%'; $('#volknob').style.left = vol.toFixed(2) + '%'; $('#volnum').textContent = Math.round(vol) + '%';
  $('#volknob').style.transform = `scale(${t > 21.35 && t < 22.5 ? 1.2 : 1})`;

  // busca
  const la = seg(t, 31.25, 0.45, E.out);
  el.launch.style.transform = `translateY(${((1 - la) * 22).toFixed(2)}px) scale(${(0.9 + 0.1 * la).toFixed(4)})`;
  el.launch.style.opacity = la.toFixed(3); el.launch.style.visibility = la <= 0.001 ? 'hidden' : 'visible';
  const typed = 'jog'.slice(0, Math.round(clamp((t - 31.9) / 0.7) * 3));
  const caret = `<span style="display:inline-block;width:1.5px;height:16px;vertical-align:-3px;margin-left:1px;background:var(--fg);opacity:${Math.floor(t * 2) % 2 ? 0 : 1}"></span>`;
  const st = t < 31.2 ? 'Buscar apps e arquivos' : (typed ? `<span style="color:var(--fg)">${typed}</span>` : '') + caret;
  if ($('#searchtxt').innerHTML !== st) $('#searchtxt').innerHTML = st;
  $('#lhead').textContent = typed ? `Resultados para "${typed}"` : 'Recentes';
  const rh = typed ? rows(RESULTS, t > 33.4 ? 0 : -1) : rows(RECENT, -1);
  if (rh !== lastRows) { $('#lrows').innerHTML = rh; lastRows = rh; }

  // legenda
  let co = 0, ct = '';
  for (const [a, b, txt] of CAPS) if (t >= a && t <= b) { co = Math.min(seg(t, a, 0.35, E.out), 1 - seg(t, b - 0.35, 0.35, E.inn)); ct = txt; }
  if (ct && el.cap.textContent !== ct) el.cap.textContent = ct;
  el.cap.style.opacity = co.toFixed(3);
  el.cap.style.transform = `translateX(-50%) translateY(${((1 - co) * -8).toFixed(2)}px)`;

  // fim
  el.end.style.display = endP > 0 ? 'flex' : 'none'; el.end.style.opacity = endP.toFixed(3);
}
window.seek = seek; window.DUR = DUR;

function fit() {
  if (CAPTURE) return;
  scale = Math.min(innerWidth / 1440, innerHeight / 900);
  stage.style.transform = `scale(${scale})`;
  stage.style.left = ((innerWidth - 1440 * scale) / 2) + 'px'; stage.style.top = ((innerHeight - 900 * scale) / 2) + 'px';
}
const CAPTURE = location.search.includes('capture');
(document.fonts ? document.fonts.ready : Promise.resolve()).then(() => {
  setTheme(0); fit(); measure(); seek(0); window.READY = true;
  if (!CAPTURE) {
    addEventListener('resize', () => { fit(); });
    const t0 = performance.now();
    const loop = () => { seek(((performance.now() - t0) / 1000) % (DUR + 1.5)); requestAnimationFrame(loop); };
    requestAnimationFrame(loop);
  }
});
