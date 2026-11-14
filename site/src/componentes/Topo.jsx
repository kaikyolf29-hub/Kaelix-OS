import { useRef } from 'react';
import BlurText from '../reactbits/BlurText.jsx';
import BarraVidro from './BarraVidro.jsx';
import { EDICAO, TAMANHO_ISO } from '../dados.js';

// A primeira tela é a área de trabalho do Matsu: o papel de parede em pixel art
// do sistema (o mesmo do primeiro boot) e a barra de vidro em três ilhas.
export default function Topo() {
  const escuro = useRef(null);
  return (
    <section className="topo" id="inicio" data-enter aria-labelledby="topo-titulo">
      <div className="topo__papel" aria-hidden="true">
        <img ref={escuro} className="papel papel--escuro" src="img/papel-escuro.png" alt="" width="640" height="360" fetchPriority="high" />
        <img className="papel papel--claro" src="img/papel-claro.png" alt="" width="640" height="360" loading="lazy" />
      </div>
      <div className="wrap topo__texto">
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
            Sistema operacional de graça para o seu PC
          </span>
        </h1>
        <p className="topo__lead entra" style={{ '--atraso': '460ms' }}>
          Bonito desde o primeiro boot, pronto para jogar e todo em português. Tem loja de apps, central de
          jogos e atualiza sozinho.
        </p>
        <div className="btn-linha entra" style={{ '--atraso': '540ms' }}>
          <a className="btn btn--primario" id="botao-topo" href="#baixar">
            Baixar o Matsu {EDICAO}
          </a>
          <a className="btn btn--secundario" href="#instalar">
            Ver como instalar
          </a>
        </div>
        <p className="topo__fato entra" style={{ '--atraso': '600ms' }}>
          Instalador de {TAMANHO_ISO}, para PCs com placa AMD, Intel ou NVIDIA.
        </p>
      </div>
      <BarraVidro estilo="fusao" vidro fundo={escuro} links className="topo__barra entra" />
    </section>
  );
}
