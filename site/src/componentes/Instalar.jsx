import { useEffect, useRef } from 'react';
import Icone from './Icone.jsx';
import { EDICAO, TAMANHO_ISO } from '../dados.js';

// O primeiro passo não tem tela do sistema: é a ISO indo para o pendrive.
function Gravar() {
  return (
    <div className="gravar" role="img" aria-label={`O arquivo da ISO do Matsu ${EDICAO} sendo gravado num pendrive`}>
      <div className="gravar__arquivo">
        <img src="img/logo.svg" alt="" width="56" height="56" loading="lazy" />
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
    tamanhos: [640, 1280],
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
    tamanhos: [800, 1600],
    alt: 'As boas-vindas do Matsu na página Escolha a aparência, com os temas escuro e claro'
  }
];

// Um passo com foto mostra a foto; os desenhados ficam no fundo claro do quadro.
function Visual({ passo }) {
  if (passo.visual) return <figure className="mo-pc__visual mo-pc__visual--lit">{passo.visual}</figure>;
  return (
    <figure className="mo-pc__visual">
      <img
        src={`img/${passo.foto}.webp`}
        srcSet={`img/${passo.foto}-${passo.tamanhos[0]}.webp ${passo.tamanhos[0]}w, img/${passo.foto}.webp ${passo.tamanhos[1]}w`}
        sizes="(max-width: 1023px) 90vw, 628px"
        alt={passo.alt}
        width="1600"
        height="900"
        loading="lazy"
      />
    </figure>
  );
}

// Os quatro passos usam o momento "pinned-chapters" do Taste Skill (public/moments):
// no PC a parte fica presa por uma tela de rolagem, o passo da vez abre à esquerda
// e o quadro da direita troca a imagem. No celular, num tablet, com "reduzir
// movimento" ou sem script, cada passo fica parado com a sua imagem.
export default function Instalar() {
  const secao = useRef(null);

  useEffect(() => {
    let vivo = true;
    // O script do momento mexe no DOM desta parte depois que o React já desenhou;
    // esta parte não tem estado, então o React não volta a mexer nela.
    import(/* @vite-ignore */ new URL('moments/moments.js', document.baseURI).href)
      .then(m => vivo && secao.current && m.mount(secao.current))
      .catch(() => {});
    return () => {
      vivo = false;
    };
  }, []);

  return (
    <section className="secao" id="instalar" ref={secao} data-moment="pinned-chapters" aria-labelledby="instalar-titulo">
      <div className="wrap mo-pc__grid">
        <div className="mo-pc__text">
          <div>
            <h2 id="instalar-titulo">Como instalar o Matsu</h2>
            <p className="sub">São quatro passos. Antes, faça uma cópia dos arquivos que importam.</p>
          </div>
          <ol className="mo-pc__steps">
            {PASSOS.map((p, i) => (
              <li key={p.titulo} className="mo-pc__step">
                <h3>
                  <span className="passo__n">{i + 1}</span> {p.titulo}
                </h3>
                <p>{p.texto}</p>
                <Visual passo={p} />
              </li>
            ))}
          </ol>
        </div>
        <div className="mo-pc__visuals" />
      </div>
    </section>
  );
}
