import { useRef, useState } from 'react';
import { useT } from '../idioma.js';

const ABAS = [
  {
    id: 'menu',
    nome: { pt: 'Menu e barra', en: 'Menu and taskbar' },
    texto: { pt: 'Apps fixados, busca e categorias, como no Windows\u00a011.', en: 'Pinned apps, search and categories, like Windows\u00a011.' },
    foto: 'tela-menu',
    alt: {
      pt: 'A área de trabalho do Matsu com o menu aberto e a barra de vidro embaixo',
      en: 'The Matsu desktop with the menu open and the glass taskbar at the bottom'
    }
  },
  {
    id: 'central',
    nome: { pt: 'Central de controle', en: 'Control center' },
    texto: { pt: 'Rede, som, modo escuro e perfil de energia num clique.', en: 'Network, sound, dark mode and power profile in one click.' },
    foto: 'tela-central',
    alt: {
      pt: 'A central de controle aberta perto do relógio, com rede, modo escuro, som e perfil de energia',
      en: 'The control center open next to the clock, with network, dark mode, sound and power profile'
    }
  },
  {
    id: 'bloqueio',
    nome: { pt: 'Tela de bloqueio', en: 'Lock screen' },
    texto: { pt: 'Hora grande, sua foto e a senha numa pílula.', en: 'A big clock, your photo and the password in a pill.' },
    foto: 'tela-bloqueio',
    alt: { pt: 'A tela de bloqueio do Matsu com a hora, a data e o campo de senha', en: 'The Matsu lock screen with the time, the date and the password field' }
  },
  {
    id: 'claro',
    nome: { pt: 'Tema claro', en: 'Light theme' },
    texto: { pt: 'O papel de parede vira dia e as janelas ficam brancas.', en: 'The wallpaper turns to day and the windows turn white.' },
    foto: 'tela-claro',
    alt: { pt: 'A área de trabalho do Matsu no tema claro', en: 'The Matsu desktop in the light theme' }
  }
];

// "Você já sabe usar": abas que trocam a foto da tela (só no clique, nada troca sozinho).
export default function Telas() {
  const [ativa, setAtiva] = useState(0);
  const lista = useRef(null);
  const t = useT();

  const teclado = e => {
    const passo = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 }[e.key];
    if (!passo) return;
    e.preventDefault();
    const nova = (ativa + passo + ABAS.length) % ABAS.length;
    setAtiva(nova);
    lista.current?.querySelectorAll('[role="tab"]')[nova]?.focus();
  };

  return (
    <section className="secao" id="sistema" aria-labelledby="sistema-titulo">
      <div className="wrap divisao divisao--5-7">
        <div className="divisao__texto">
          <h2 id="sistema-titulo">{t('Fácil para quem vem do Windows', 'Easy if you come from Windows')}</h2>
          <p className="sub">
            {t(
              'O menu, a busca, os apps abertos e o relógio ficam na barra de baixo. As janelas são de vidro e deixam ver o papel de parede.',
              'The menu, search, open apps and the clock sit on the bottom bar. Windows are made of glass and let the wallpaper show through.'
            )}
          </p>
          <div className="abas" role="tablist" aria-label={t('Partes do sistema', 'Parts of the system')} aria-orientation="vertical" ref={lista} onKeyDown={teclado}>
            <span className="abas__marca" style={{ '--i': ativa }} aria-hidden="true" />
            {ABAS.map((a, i) => (
              <button
                key={a.id}
                type="button"
                role="tab"
                id={`aba-${a.id}`}
                aria-selected={i === ativa}
                aria-controls="tela-foto"
                tabIndex={i === ativa ? 0 : -1}
                className="aba"
                onClick={() => setAtiva(i)}
              >
                <b>{t(a.nome)}</b>
                <span>{t(a.texto)}</span>
              </button>
            ))}
          </div>
        </div>
        <div className="quadro quadro--tela" id="tela-foto" role="tabpanel" aria-labelledby={`aba-${ABAS[ativa].id}`}>
          {ABAS.map((a, i) => (
            <img
              key={a.id}
              className="quadro__foto troca-foto"
              data-ativa={i === ativa}
              src={`img/${a.foto}.webp`}
              srcSet={`img/${a.foto}-800.webp 800w, img/${a.foto}.webp 1600w`}
              sizes="(min-width: 1024px) 737px, 100vw"
              width="1600"
              height="900"
              alt={i === ativa ? t(a.alt) : ''}
              aria-hidden={i === ativa ? undefined : 'true'}
              loading="lazy"
            />
          ))}
        </div>
      </div>
    </section>
  );
}
