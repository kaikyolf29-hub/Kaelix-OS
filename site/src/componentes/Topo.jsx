import { useRef } from 'react';
import BlurText from '../reactbits/BlurText.jsx';
import BarraVidro from './BarraVidro.jsx';
import { EDICAO, TAMANHO_ISO } from '../dados.js';
import { useT } from '../idioma.js';

// O papel de parede é pixel art de 640x360 aumentado 3 e 6 vezes sem borrar
// (WebP sem perda: os dois juntos pesam menos que o PNG pequeno). No celular vai
// um recorte em pé (o pedaço do sol), para não baixar a imagem larga inteira.
// Com object-fit: cover, numa tela mais estreita que 16:9 a imagem fica com a
// largura de 16/9 da altura (cortada dos lados): é essa largura que vai no sizes.
const TAMANHO_PAPEL = '(max-aspect-ratio: 16/9) 178vh, 100vw';
export const PAPEL = tema => `img/papel-${tema}-1920.webp 1920w, img/papel-${tema}-3840.webp 3840w`;

// A primeira tela é a área de trabalho do Matsu: o papel de parede em pixel art
// do sistema (o mesmo do primeiro boot) e a barra de vidro em três ilhas.
export default function Topo() {
  const escuro = useRef(null);
  const t = useT();
  return (
    <section className="topo" id="inicio" data-enter aria-labelledby="topo-titulo">
      <picture className="papel-quadro">
        <source media="(max-width: 639px)" srcSet="img/papel-escuro-celular.webp" width="540" height="1080" />
        <img
          ref={escuro}
          className="papel papel--escuro"
          src="img/papel-escuro-1920.webp"
          srcSet={PAPEL('escuro')}
          sizes={TAMANHO_PAPEL}
          alt=""
          width="1920"
          height="1080"
          fetchPriority="high"
        />
      </picture>
      <picture className="papel-quadro">
        <source media="(max-width: 639px)" srcSet="img/papel-claro-celular.webp" width="540" height="1080" />
        <img
          className="papel papel--claro"
          src="img/papel-claro-1920.webp"
          srcSet={PAPEL('claro')}
          sizes={TAMANHO_PAPEL}
          alt=""
          width="1920"
          height="1080"
          fetchPriority="low"
        />
      </picture>
      <div className="wrap topo__wrap">
        <div className="hero-text topo__texto">
        <h1 id="topo-titulo" className="topo__h1">
          <BlurText
            as="span"
            className="topo__nome entrada"
            text={`Matsu ${EDICAO} OS`}
            trigger="load"
            animateBy="words"
            delay={90}
            stepDuration={0.42}
            blur={12}
            distance={28}
          />
          <span className="topo__categoria entra" style={{ '--atraso': '380ms' }}>
            {t('Sistema operacional de graça para o seu PC', 'A free operating system for your PC')}
          </span>
        </h1>
        <p className="topo__lead entra" style={{ '--atraso': '460ms' }}>
          {t(
            'Bonito desde o primeiro boot, pronto para jogar e todo em português. Tem loja de apps, central de jogos e atualiza sozinho.',
            'Looks great from the first boot, ready for gaming, in English or Portuguese. It has an app store and a game center, and it updates itself.'
          )}
        </p>
        <div className="btn-linha entra" style={{ '--atraso': '540ms' }}>
          <a className="btn btn--primario" id="botao-topo" href="#baixar">
            {t('Baixar o Matsu', 'Download Matsu')} {EDICAO}
          </a>
          <a className="btn btn--secundario" href="#instalar">
            {t('Ver como instalar', 'See how to install')}
          </a>
        </div>
        <p className="topo__fato entra" style={{ '--atraso': '600ms' }}>
          {t(
            `Instalador de ${TAMANHO_ISO.pt}, para PCs com placa AMD, Intel ou NVIDIA.`,
            `An installer of ${TAMANHO_ISO.en}, for PCs with AMD, Intel or NVIDIA graphics.`
          )}
        </p>
        </div>
        <div className="topo__pe">
          <BarraVidro estilo="fusao" vidro fundo={escuro} links className="topo__barra entra" />
        </div>
      </div>
    </section>
  );
}
