import { useEffect, useRef, useState } from 'react';
import Icone from './Icone.jsx';
import { EDICAO, TAMANHO_ISO } from '../dados.js';

// O primeiro passo não tem tela do sistema: é a ISO indo para o pendrive.
function Gravar() {
  return (
    <div className="gravar" role="img" aria-label={`O arquivo da ISO do Matsu ${EDICAO} sendo gravado num pendrive`}>
      <div className="gravar__arquivo">
        <img src="img/logo.svg" alt="" width="56" height="56" />
        <b>matsu-os-{EDICAO}-amd.iso</b>
        <span>Imagem de disco, {TAMANHO_ISO}</span>
      </div>
      <div className="gravar__fio" aria-hidden="true">
        <span />
      </div>
      <div className="gravar__pendrive" aria-hidden="true">
        <span className="gravar__ponta" />
        <span className="gravar__corpo">
          <Icone nome="baixar" tamanho={28} />
        </span>
      </div>
    </div>
  );
}

// O terceiro passo também é desenho, não foto: o resumo do que o instalador já
// deixa marcado e do que falta a pessoa escolher.
const RESUMO = [
  { nome: 'Idioma', valor: 'Português (Brasil)', icone: 'web', pronto: true },
  { nome: 'Teclado', valor: 'ABNT2', icone: 'teclado', pronto: true },
  { nome: 'Fuso horário', valor: 'Brasília', icone: 'sincronia', pronto: true },
  { nome: 'Disco', valor: 'Você escolhe', icone: 'disco', pronto: false },
  { nome: 'Sua conta', valor: 'Nome e senha', icone: 'cadeado', pronto: false }
];

function Resumo() {
  return (
    <div className="resumo" role="img" aria-label="Idioma, teclado e fuso horário já marcados; falta escolher o disco e criar a conta">
      <ul className="resumo__lista">
        {RESUMO.map(r => (
          <li key={r.nome} data-pronto={r.pronto}>
            <span className="resumo__icone">
              <Icone nome={r.icone} tamanho={18} />
            </span>
            <span className="resumo__nome">{r.nome}</span>
            <span className="resumo__valor">{r.valor}</span>
            <span className="resumo__estado">{r.pronto ? <Icone nome="certo" tamanho={16} /> : null}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

const PASSOS = [
  {
    titulo: 'Grave a ISO num pendrive',
    texto: 'Use um pendrive de 4 GB ou mais e o balenaEtcher ou o Rufus. O que estiver nele é apagado.',
    visual: <Gravar />
  },
  {
    titulo: 'Ligue o PC pelo pendrive',
    texto: `Aperte a tecla do menu de boot (F12, F11 ou Esc, depende do PC) e escolha Instalar o Matsu ${EDICAO} OS.`,
    foto: 'passo-boot',
    alt: `A tela de carregar do Matsu ${EDICAO} OS, com o logo do bonsai`
  },
  {
    titulo: 'Escolha o disco e crie sua conta',
    texto: 'Português, teclado ABNT2 e horário de Brasília já vêm marcados. O instalador baixa o sistema pela internet.',
    visual: <Resumo />
  },
  {
    titulo: 'Escolha a aparência e comece',
    texto: 'Nas boas-vindas você escolhe o tema, o papel de parede e o navegador: Brave, Chrome ou os dois.',
    foto: 'passo-boasvindas',
    alt: 'As boas-vindas do Matsu na página Escolha a aparência, com os temas escuro e claro'
  }
];

function Visual({ passo }) {
  if (passo.visual) return passo.visual;
  return <img className="quadro__foto" src={`img/${passo.foto}.webp`} alt={passo.alt} width="1600" height="900" loading="lazy" />;
}

// Os quatro passos ficam presos na tela por duas telas de rolagem: o passo da
// esquerda acende e a imagem da direita troca. No celular, cada passo vem com
// a sua imagem, um embaixo do outro.
export default function Instalar() {
  const secao = useRef(null);
  const [ativo, setAtivo] = useState(0);

  useEffect(() => {
    const el = secao.current;
    if (!el) return undefined;
    let quadro = 0;
    const medir = () => {
      quadro = 0;
      const caixa = el.getBoundingClientRect();
      const percurso = caixa.height - window.innerHeight;
      if (percurso <= 0) return;
      const p = Math.min(1, Math.max(0, -caixa.top / percurso));
      setAtivo(Math.min(PASSOS.length - 1, Math.floor(p * PASSOS.length)));
    };
    const pedir = () => {
      if (!quadro) quadro = requestAnimationFrame(medir);
    };
    medir();
    window.addEventListener('scroll', pedir, { passive: true });
    window.addEventListener('resize', pedir);
    return () => {
      cancelAnimationFrame(quadro);
      window.removeEventListener('scroll', pedir);
      window.removeEventListener('resize', pedir);
    };
  }, []);

  // Clicar num passo rola até o ponto em que ele acende.
  const irPara = i => {
    const el = secao.current;
    const percurso = el.offsetHeight - window.innerHeight;
    if (percurso <= 0) return;
    const topo = el.getBoundingClientRect().top + window.scrollY;
    window.scrollTo({ top: topo + ((i + 0.5) / PASSOS.length) * percurso, behavior: 'auto' });
  };

  return (
    <section className="secao secao--instalar" id="instalar" ref={secao} data-moment="pinned-chapters" aria-labelledby="instalar-titulo">
      <div className="instalar__fixo">
        <div className="wrap divisao divisao--5-7">
          <div className="divisao__texto">
            <h2 id="instalar-titulo">Como instalar o Matsu</h2>
            <p className="sub">São quatro passos. Antes, faça uma cópia dos arquivos que importam.</p>
            <ol className="passos">
              {PASSOS.map((p, i) => (
                <li key={p.titulo} data-ativo={i === ativo}>
                  <button type="button" className="passo" onClick={() => irPara(i)} aria-current={i === ativo ? 'step' : undefined}>
                    <span className="passo__numero" aria-hidden="true">
                      {i + 1}
                    </span>
                    <span className="passo__texto">
                      <b>{p.titulo}</b>
                      <span>{p.texto}</span>
                    </span>
                  </button>
                  <div className="passo__visual-celular">
                    <div className="quadro">
                      <Visual passo={p} />
                    </div>
                  </div>
                </li>
              ))}
            </ol>
          </div>
          <div className="quadro quadro--passos" aria-hidden="true">
            {PASSOS.map((p, i) => (
              <div key={p.titulo} className="troca-foto quadro__camada" data-ativa={i === ativo}>
                <Visual passo={p} />
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
