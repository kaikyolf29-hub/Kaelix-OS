import { ICONES } from '../icones.js';

// Os que o Matsu não tem no conjunto simbólico, desenhados no mesmo traço.
const EXTRAS = {
  copiar: [
    { t: 'p', d: 'M9 8.5h8.5a2 2 0 0 1 2 2V19a2 2 0 0 1 -2 2H9a2 2 0 0 1 -2 -2v-8.5a2 2 0 0 1 2 -2z' },
    { t: 'p', d: 'M15.5 8.5V6a2 2 0 0 0 -2 -2H6a2 2 0 0 0 -2 2v7.5a2 2 0 0 0 2 2h1' }
  ],
  chevron: [{ t: 'p', d: 'M7 10l5 5 5-5' }],
  coracao: [{ t: 'p', d: 'M12 19.5s-7.5-4.6-7.5-10.1a4.1 4.1 0 0 1 7.5-2.3a4.1 4.1 0 0 1 7.5 2.3c0 5.5-7.5 10.1-7.5 10.1z' }],
  // Estes quatro vêm de system_files/usr/share/icons/Matsu/status/symbolic
  // (matsu-aparencia, matsu-papel, matsu-textura), menos o terminal, no mesmo traço.
  aparencia: [
    { t: 'p', d: 'M12 3.5a8.5 8.5 0 1 0 0 17a8.5 8.5 0 1 0 0 -17z' },
    { t: 'p', d: 'M12 3.5a8.5 8.5 0 0 1 0 17z', f: true }
  ],
  papel: [
    { t: 'p', d: 'M5 4h14a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2zM3.5 17l5 -5.5 4 4 2.5 -2.5 5.5 5.5' },
    { t: 'c', cx: 15.5, cy: 8.5, r: 1.7, f: true }
  ],
  vidro: [{ t: 'p', d: 'M3 18.5L8 5.5h8l5 13zM5.7 12h12.6M10.5 5.5l-1.3 13M13.5 5.5l1.3 13' }],
  terminal: [{ t: 'p', d: 'M5 4h14a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2zM7.5 9.5l3 2.5 -3 2.5M13 15h3.5' }]
};

// Ícone de linha (24x24, traço 1.9), na cor do texto.
export default function Icone({ nome, tamanho = 20, className = '', titulo }) {
  const partes = ICONES[nome] || EXTRAS[nome];
  if (!partes) return null;
  return (
    <svg
      className={`icone ${className}`}
      width={tamanho}
      height={tamanho}
      viewBox="0 0 24 24"
      aria-hidden={titulo ? undefined : 'true'}
      role={titulo ? 'img' : undefined}
      aria-label={titulo}
      focusable="false"
    >
      {partes.map((p, i) => {
        const cheio = p.f ? { fill: 'currentColor', stroke: 'none' } : { fill: 'none', stroke: 'currentColor' };
        if (p.t === 'c') return <circle key={i} cx={p.cx} cy={p.cy} r={p.r} {...cheio} />;
        if (p.t === 'r') return <rect key={i} x={p.x} y={p.y} width={p.w} height={p.h} rx={p.rx} {...cheio} />;
        return <path key={i} d={p.d} fillRule={p.fr} {...cheio} />;
      })}
    </svg>
  );
}
