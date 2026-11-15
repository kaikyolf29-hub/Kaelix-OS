import { useEffect, useState, useRef } from 'react';
import Icone from './Icone.jsx';
import { APOIAR, NOME, SECOES, TEM_APOIO } from '../dados.js';
import { PAGINA, useIdioma, useT } from '../idioma.js';

// O menu de cima: as partes do sistema e, quando tem um jeito de apoiar, o Apoiar.
const MENU = TEM_APOIO ? [...SECOES, APOIAR] : SECOES;

// O outro idioma, levando junto a parte da página onde a pessoa está (#jogos...).
export function BotaoIdioma({ className = '', longo = false }) {
  const idioma = useIdioma();
  const outro = idioma === 'en' ? 'pt' : 'en';
  const nome = outro === 'en' ? 'English' : 'Português';
  return (
    <a
      className={className}
      href={PAGINA[outro]}
      hrefLang={outro === 'en' ? 'en' : 'pt-BR'}
      lang={outro === 'en' ? 'en' : 'pt-BR'}
      aria-label={outro === 'en' ? 'Read in English' : 'Ler em português'}
      title={nome}
      onClick={e => {
        e.currentTarget.href = PAGINA[outro] + window.location.hash;
      }}
    >
      {longo ? nome : outro.toUpperCase()}
    </a>
  );
}

function useTema() {
  const [tema, setTema] = useState('escuro');
  useEffect(() => {
    setTema(document.documentElement.dataset.tema === 'claro' ? 'claro' : 'escuro');
  }, []);
  const trocar = () => {
    const novo = tema === 'escuro' ? 'claro' : 'escuro';
    document.documentElement.dataset.tema = novo;
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', novo === 'claro' ? '#f3f3f5' : '#161618');
    try {
      localStorage.setItem('matsu-tema', novo);
    } catch {
      // Sem armazenamento (janela anônima): o tema vale só nesta visita.
    }
    setTema(novo);
  };
  return [tema, trocar];
}

export function BotaoTema() {
  const [tema, trocar] = useTema();
  const t = useT();
  const claro = tema === 'claro';
  return (
    <button
      type="button"
      className="botao-icone botao-tema"
      onClick={trocar}
      aria-label={claro ? t('Usar o tema escuro', 'Use the dark theme') : t('Usar o tema claro', 'Use the light theme')}
      title={claro ? t('Tema escuro', 'Dark theme') : t('Tema claro', 'Light theme')}
    >
      <span className="troca-icone" data-mostra={claro ? 'b' : 'a'}>
        <Icone nome="lua" tamanho={20} className="troca-icone__a" />
        <Icone nome="brilho" tamanho={20} className="troca-icone__b" />
      </span>
    </button>
  );
}

// O <header class="nav"> está no index.html; o React desenha o que vai dentro.
export default function Navegacao() {
  const [aberto, setAberto] = useState(false);
  const t = useT();

  useEffect(() => {
    if (!aberto) return undefined;
    const fechar = e => e.key === 'Escape' && setAberto(false);
    document.addEventListener('keydown', fechar);
    document.documentElement.classList.add('sem-rolar');
    return () => {
      document.removeEventListener('keydown', fechar);
      document.documentElement.classList.remove('sem-rolar');
    };
  }, [aberto]);

  return (
    <>
      <div className="wrap nav__linha">
        <a className="pular" href="#conteudo">
          {t('Pular para o conteúdo', 'Skip to content')}
        </a>
        <a className="nav__marca" href="#inicio" aria-label={`${NOME}, ${t('início', 'home')}`}>
          <img src="img/logo.svg" alt="" width="32" height="32" />
          <span>{NOME}</span>
        </a>
        <nav className="nav__secoes" aria-label={t('Seções', 'Sections')}>
          <ul>
            {MENU.map(s => (
              <li key={s.id}>
                <a href={`#${s.id}`}>{t(s.nome)}</a>
              </li>
            ))}
          </ul>
        </nav>
        <div className="nav__acoes">
          <BotaoIdioma className="botao-icone botao-idioma" />
          <BotaoTema />
          <a className="btn btn--primario nav__baixar" href="#baixar">
            {t('Baixar o Matsu', 'Download Matsu')} {NOME.split(' ')[1]}
          </a>
          <button
            type="button"
            className="botao-icone nav__menu"
            aria-expanded={aberto}
            aria-controls="menu-celular"
            aria-label={aberto ? t('Fechar o menu', 'Close the menu') : t('Abrir o menu', 'Open the menu')}
            onClick={() => setAberto(a => !a)}
          >
            <span className="troca-icone" data-mostra={aberto ? 'b' : 'a'}>
              <Icone nome="menu" tamanho={22} className="troca-icone__a" />
              <Icone nome="fechar" tamanho={22} className="troca-icone__b" />
            </span>
          </button>
        </div>
      </div>
      <div id="menu-celular" className="folha" data-aberto={aberto} hidden={!aberto} onClick={() => setAberto(false)}>
        <ul>
          {MENU.map(s => (
            <li key={s.id}>
              <a href={`#${s.id}`}>{t(s.nome)}</a>
            </li>
          ))}
          <li>
            <a href="#baixar">{t('Baixar', 'Download')}</a>
          </li>
          <li className="folha__idioma">
            <BotaoIdioma longo />
          </li>
        </ul>
      </div>
    </>
  );
}

// A barra de baixo do celular: aparece só quando o botão do topo já saiu da tela
// e some de novo perto da parte de baixar, para nunca mostrar o botão duas vezes.
// O <nav class="barra-celular"> está no index.html; aqui vai o botão e o liga/desliga.
export function BarraCelular() {
  const [mostrar, setMostrar] = useState(false);
  const t = useT();
  const botao = useRef(null);
  useEffect(() => {
    const barra = botao.current?.parentElement;
    if (!barra) return;
    barra.dataset.mostrar = String(mostrar);
    barra.inert = !mostrar;
  }, [mostrar]);
  useEffect(() => {
    const alvos = ['#botao-topo', '#baixar', '#rodape-baixar'].map(s => document.querySelector(s)).filter(Boolean);
    const vistos = new Set();
    let passouDoTopo = false;
    const obs = new IntersectionObserver(entradas => {
      for (const e of entradas) {
        if (e.isIntersecting) vistos.add(e.target);
        else vistos.delete(e.target);
        if (e.target.id === 'botao-topo') passouDoTopo = !e.isIntersecting && e.boundingClientRect.top < 0;
      }
      setMostrar(passouDoTopo && vistos.size === 0);
    });
    alvos.forEach(a => obs.observe(a));
    return () => obs.disconnect();
  }, []);
  return (
    <a className="btn btn--primario" href="#baixar" ref={botao} tabIndex={mostrar ? undefined : -1}>
      {t('Baixar o Matsu', 'Download Matsu')} {NOME.split(' ')[1]}
    </a>
  );
}
