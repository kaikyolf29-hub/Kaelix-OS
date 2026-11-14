import { useRef, useState } from 'react';
import BarraVidro from './BarraVidro.jsx';
import { PAPEL } from './Topo.jsx';

const ESTILOS = [
  { id: 'fusao', nome: 'Matsu', texto: 'Três ilhas de vidro: o menu e a busca, os apps e o relógio.' },
  { id: 'windows', nome: 'Windows', texto: 'Uma faixa só, com tudo à esquerda e o relógio no canto.' },
  { id: 'mac', nome: 'Mac', texto: 'A barra fina no alto com os menus do app e a doca que amplia.' }
];

// A barra de verdade não é foto: é a mesma barra desenhada aqui, nos três estilos
// que os Ajustes do Matsu oferecem. Troca só no clique.
export default function Estilos() {
  const [ativo, setAtivo] = useState(0);
  const fundo = useRef(null);
  const botoes = useRef(null);

  const teclado = e => {
    const passo = { ArrowRight: 1, ArrowLeft: -1 }[e.key];
    if (!passo) return;
    e.preventDefault();
    const novo = (ativo + passo + ESTILOS.length) % ESTILOS.length;
    setAtivo(novo);
    botoes.current?.querySelectorAll('[role="tab"]')[novo]?.focus();
  };

  return (
    <section className="secao secao--faixa" id="barra" aria-labelledby="barra-titulo">
      <div className="wrap">
        <div className="cabeca">
          <div>
            <h2 id="barra-titulo">Barra no estilo Matsu, Windows ou Mac</h2>
            <p className="sub">Escolha o estilo nos Ajustes do Matsu e troque quando quiser. Os apps fixados vão junto.</p>
          </div>
          <div className="segmentos" role="tablist" aria-label="Estilo da barra" ref={botoes} onKeyDown={teclado}>
            <span className="segmentos__marca" style={{ '--i': ativo }} aria-hidden="true" />
            {ESTILOS.map((e, i) => (
              <button
                key={e.id}
                type="button"
                role="tab"
                aria-selected={i === ativo}
                aria-controls="barra-palco"
                tabIndex={i === ativo ? 0 : -1}
                onClick={() => setAtivo(i)}
              >
                {e.nome}
              </button>
            ))}
          </div>
        </div>
        <div className="palco" id="barra-palco" role="tabpanel" aria-label={`Barra no estilo ${ESTILOS[ativo].nome}. ${ESTILOS[ativo].texto}`}>
          <picture className="papel-quadro">
            <source media="(max-width: 639px)" srcSet="img/papel-escuro-quadrado.webp" width="720" height="720" />
            <img
              ref={fundo}
              className="palco__papel papel papel--escuro"
              src="img/papel-escuro-1920.webp"
              srcSet={PAPEL('escuro')}
              sizes="(min-width: 1360px) 1280px, 100vw"
              alt=""
              width="1920"
              height="1080"
              loading="lazy"
            />
          </picture>
          <picture className="papel-quadro">
            <source media="(max-width: 639px)" srcSet="img/papel-claro-quadrado.webp" width="720" height="720" />
            <img
              className="palco__papel papel papel--claro"
              src="img/papel-claro-1920.webp"
              srcSet={PAPEL('claro')}
              sizes="(min-width: 1360px) 1280px, 100vw"
              alt=""
              width="1920"
              height="1080"
              loading="lazy"
            />
          </picture>
          {ESTILOS.map((e, i) => (
            <div key={e.id} className="palco__barra" data-ativo={i === ativo} inert={i === ativo ? undefined : true}>
              <BarraVidro estilo={e.id} vidro={i === ativo} fundo={fundo} />
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
