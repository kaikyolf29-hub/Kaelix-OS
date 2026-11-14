import { ICONES } from '../icones.js';

// Os que o Matsu não tem no conjunto simbólico, desenhados no mesmo traço.
const EXTRAS = {
  copiar: [
    { t: 'p', d: 'M9 8.5h8.5a2 2 0 0 1 2 2V19a2 2 0 0 1 -2 2H9a2 2 0 0 1 -2 -2v-8.5a2 2 0 0 1 2 -2z' },
    { t: 'p', d: 'M15.5 8.5V6a2 2 0 0 0 -2 -2H6a2 2 0 0 0 -2 2v7.5a2 2 0 0 0 2 2h1' }
  ],
  chevron: [{ t: 'p', d: 'M7 10l5 5 5-5' }]
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
