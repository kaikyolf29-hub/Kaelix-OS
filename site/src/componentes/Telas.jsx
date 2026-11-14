import { useRef, useState } from 'react';

const ABAS = [
  {
    id: 'menu',
    nome: 'Menu e barra',
    texto: 'Apps fixados, busca e categorias, como no Windows\u00a011.',
    foto: 'tela-menu',
    alt: 'A área de trabalho do Matsu com o menu aberto e a barra de vidro embaixo'
  },
  {
    id: 'central',
    nome: 'Central de controle',
    texto: 'Rede, som, modo escuro e perfil de energia num clique.',
    foto: 'tela-central',
    alt: 'A central de controle aberta perto do relógio, com rede, modo escuro, som e perfil de energia'
  },
  {
    id: 'bloqueio',
    nome: 'Tela de bloqueio',
    texto: 'Hora grande, sua foto e a senha numa pílula.',
    foto: 'tela-bloqueio',
    alt: 'A tela de bloqueio do Matsu com a hora, a data e o campo de senha'
  },
  {
    id: 'claro',
    nome: 'Tema claro',
    texto: 'O papel de parede vira dia e as janelas ficam brancas.',
    foto: 'tela-claro',
    alt: 'A área de trabalho do Matsu no tema claro'
  }
];

// "Você já sabe usar": abas que trocam a foto da tela (só no clique, nada troca sozinho).
export default function Telas() {
  const [ativa, setAtiva] = useState(0);
  const lista = useRef(null);

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
          <h2 id="sistema-titulo">Fácil para quem vem do Windows</h2>
          <p className="sub">
            O menu, a busca, os apps abertos e o relógio ficam na barra de baixo. As janelas são de vidro e deixam ver o
            papel de parede.
          </p>
          <div className="abas" role="tablist" aria-label="Partes do sistema" aria-orientation="vertical" ref={lista} onKeyDown={teclado}>
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
                <b>{a.nome}</b>
                <span>{a.texto}</span>
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
              alt={i === ativa ? a.alt : ''}
              aria-hidden={i === ativa ? undefined : 'true'}
              loading="lazy"
            />
          ))}
        </div>
      </div>
    </section>
  );
}
