import { useEffect, useRef } from 'react';
import Icone from './Icone.jsx';
import { EDICAO, TAMANHO_ISO } from '../dados.js';
import { useT } from '../idioma.js';

// O primeiro passo não tem tela do sistema: é a ISO indo para o pendrive.
function Gravar() {
  const t = useT();
  return (
    <div
      className="gravar"
      role="img"
      aria-label={t(`O arquivo da ISO do Matsu ${EDICAO} sendo gravado num pendrive`, `The Matsu ${EDICAO} ISO file being written to a USB drive`)}
    >
      <div className="gravar__arquivo">
        <img src="img/logo.svg" alt="" width="56" height="56" loading="lazy" />
        <b>matsu-os-{EDICAO}-amd.iso</b>
        <span>{t(`Imagem de disco, ${TAMANHO_ISO.pt}`, `Disk image, ${TAMANHO_ISO.en}`)}</span>
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

const PASSOS = [
  {
    titulo: { pt: 'Grave a ISO num pendrive', en: 'Write the ISO to a USB drive' },
    texto: {
      pt: 'Use um pendrive de 4 GB ou mais e o balenaEtcher ou o Rufus, no modo DD. O que estiver nele é apagado.',
      en: 'Use a USB drive of 4 GB or more and balenaEtcher or Rufus, in DD mode. Everything on it is erased.'
    },
    visual: <Gravar />
  },
  {
    titulo: { pt: 'Ligue o PC pelo pendrive', en: 'Start the PC from the USB drive' },
    tamanhos: [640, 1280],
    texto: {
      pt: `Aperte a tecla do menu de boot (F12, F11 ou Esc, depende do PC) e escolha Instalar o Matsu ${EDICAO} OS.`,
      en: `Press the boot menu key (F12, F11 or Esc, depending on the PC) and choose “Instalar o Matsu ${EDICAO} OS”.`
    },
    foto: 'passo-boot',
    alt: {
      pt: `A tela de carregar do Matsu ${EDICAO} OS, com o logo do bonsai`,
      en: `The Matsu ${EDICAO} OS loading screen, with the bonsai logo`
    }
  },
  {
    titulo: { pt: 'Escolha o disco e crie sua conta', en: 'Choose the disk and create your account' },
    texto: {
      pt: 'O instalador do Matsu pergunta o idioma, a internet, o disco e a sua conta. Depois baixa o sistema pela internet.',
      en: 'The Matsu installer asks for your language, internet, disk and account. Then it downloads the system over the internet.'
    },
    foto: 'passo-instalador',
    tamanhos: [800, 1440],
    alt: {
      pt: 'O instalador do Matsu na tela Tudo pronto para instalar, com o disco, a conta, o idioma e o teclado escolhidos',
      en: 'The Matsu installer on the ready-to-install screen, with the disk, account, language and keyboard chosen'
    }
  },
  {
    titulo: { pt: 'Escolha a aparência e comece', en: 'Choose the look and get started' },
    texto: {
      pt: 'Nas boas-vindas você escolhe o tema, o papel de parede e o navegador: Brave, Chrome ou os dois.',
      en: 'In the welcome app you choose the theme, the wallpaper and the browser: Brave, Chrome or both.'
    },
    foto: 'passo-boasvindas',
    tamanhos: [800, 1600],
    alt: {
      pt: 'As boas-vindas do Matsu na página Escolha a aparência, com os temas escuro e claro',
      en: 'The Matsu welcome app on the appearance page, with the dark and light themes'
    }
  }
];

// Um passo com foto mostra a foto; os desenhados ficam no fundo claro do quadro.
function Visual({ passo }) {
  const t = useT();
  if (passo.visual) return <figure className="mo-pc__visual mo-pc__visual--lit">{passo.visual}</figure>;
  return (
    <figure className="mo-pc__visual">
      <img
        src={`img/${passo.foto}.webp`}
        srcSet={`img/${passo.foto}-${passo.tamanhos[0]}.webp ${passo.tamanhos[0]}w, img/${passo.foto}.webp ${passo.tamanhos[1]}w`}
        sizes="(max-width: 1023px) 90vw, 628px"
        alt={t(passo.alt)}
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
  const t = useT();

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
            <h2 id="instalar-titulo">{t('Como instalar o Matsu', 'How to install Matsu')}</h2>
            <p className="sub">
              {t('São quatro passos. Antes, faça uma cópia dos arquivos que importam.', 'It takes four steps. Before you start, back up the files that matter.')}
            </p>
          </div>
          <ol className="mo-pc__steps">
            {PASSOS.map((p, i) => (
              <li key={p.titulo.pt} className="mo-pc__step">
                <h3>
                  <span className="passo__n">{i + 1}</span> {t(p.titulo)}
                </h3>
                <p>{t(p.texto)}</p>
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
