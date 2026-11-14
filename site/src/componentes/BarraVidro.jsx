import { useEffect, useState } from 'react';
import GlassSurface from '../reactbits/GlassSurface.jsx';
import Icone from './Icone.jsx';
import { APPS_BARRA } from '../dados.js';

// A hora e a data como a barra do Matsu mostra: "06:14" e "sáb. 14 de nov.".
function useRelogio() {
  const [agora, setAgora] = useState(null);
  useEffect(() => {
    setAgora(new Date());
    const t = setInterval(() => setAgora(new Date()), 15000);
    return () => clearInterval(t);
  }, []);
  if (!agora) return { hora: '--:--', data: '' };
  const hora = agora.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
  const semana = agora.toLocaleDateString('pt-BR', { weekday: 'short' });
  const mes = agora.toLocaleDateString('pt-BR', { month: 'short' });
  return { hora, data: `${semana} ${agora.getDate()} de ${mes}` };
}

// Uma ilha de vidro. "vidro" liga o vidro do React Bits (refração de verdade no
// Chrome e no Edge; no Safari e no Firefox ele usa a imagem de fundo ou o fosco).
function Ilha({ vidro, fundo, className, children, raio = 18 }) {
  if (!vidro) return <div className={`ilha ilha--simples ${className}`}>{children}</div>;
  return (
    <GlassSurface
      width="auto"
      height="auto"
      borderRadius={raio}
      backgroundOpacity={0.28}
      saturation={1.5}
      blur={8}
      displace={0.4}
      distortionScale={-90}
      backdrop={fundo}
      className={`ilha ${className}`}
    >
      {children}
    </GlassSurface>
  );
}

function Logo() {
  return <img className="barra__logo" src="img/logo.svg" alt="" width="40" height="40" />;
}

function Busca() {
  return (
    <span className="barra__busca">
      <Icone nome="busca" tamanho={16} />
      Buscar apps e arquivos
    </span>
  );
}

function AppsDaBarra({ comLixeira = true, links = true, ampliar = false }) {
  return (
    <ul className={`barra__apps${ampliar ? ' barra__apps--ampliar' : ''}`}>
      {APPS_BARRA.map(app => (
        <li key={app.nome}>
          {links ? (
            <a className="barra__app" href={app.ir} aria-label={app.nome} data-balao={app.nome}>
              <img src={app.icone} alt="" width="36" height="36" loading="eager" />
            </a>
          ) : (
            <span className="barra__app" data-balao={app.nome}>
              <img src={app.icone} alt="" width="36" height="36" loading="lazy" />
            </span>
          )}
        </li>
      ))}
      {comLixeira && (
        <>
          <li className="barra__separador" aria-hidden="true" />
          <li>
            <span className="barra__app" data-balao="Lixeira">
              <img src="icones/lixeira.svg" alt="" width="36" height="36" loading="lazy" />
            </span>
          </li>
        </>
      )}
    </ul>
  );
}

function Bandeja({ relogio, compacta = false }) {
  return (
    <div className="barra__bandeja">
      <Icone nome="escudo" tamanho={18} />
      {!compacta && <Icone nome="chevron" tamanho={18} className="barra__acima" />}
      <span className="barra__pilula">
        <Icone nome="rede-cabo" tamanho={16} />
        <Icone nome="volume-2" tamanho={16} />
      </span>
      <span className="barra__hora" suppressHydrationWarning>
        <b>{relogio.hora}</b>
        <small>{relogio.data}</small>
      </span>
      <Icone nome="sino" tamanho={18} />
    </div>
  );
}

// estilo: "fusao" (três ilhas, o padrão), "windows" (uma faixa) ou "mac"
// (barra fina no alto e doca embaixo). Desenha só o que a barra de verdade tem.
export default function BarraVidro({ estilo = 'fusao', vidro = false, fundo, links = false, className = '' }) {
  const relogio = useRelogio();

  if (estilo === 'windows') {
    return (
      <div className={`barra barra--windows ${className}`} aria-hidden={links ? undefined : 'true'}>
        <div className="faixa">
          <Logo />
          <Busca />
          <AppsDaBarra comLixeira={false} links={links} />
          <Bandeja relogio={relogio} />
        </div>
      </div>
    );
  }

  if (estilo === 'mac') {
    return (
      <div className={`barra barra--mac ${className}`} aria-hidden={links ? undefined : 'true'}>
        <div className="mac-topo">
          <img src="img/logo.svg" alt="" width="20" height="20" />
          <b>Arquivos</b>
          <span>Arquivo</span>
          <span>Editar</span>
          <span>Exibir</span>
          <span>Ir</span>
          <span>Janela</span>
          <span className="mac-topo__direita">
            <Icone nome="escudo" tamanho={16} />
            <Icone nome="rede-cabo" tamanho={16} />
            <Icone nome="volume-2" tamanho={16} />
            <span suppressHydrationWarning>{relogio.data}</span>
            <b suppressHydrationWarning>{relogio.hora}</b>
          </span>
        </div>
        <Ilha vidro={vidro} fundo={fundo} className="ilha--doca" raio={20}>
          <AppsDaBarra links={links} ampliar />
        </Ilha>
      </div>
    );
  }

  return (
    <div className={`barra barra--fusao ${className}`} aria-hidden={links ? undefined : 'true'}>
      <Ilha vidro={vidro} fundo={fundo} className="ilha--inicio">
        <Logo />
        <Busca />
      </Ilha>
      <Ilha vidro={vidro} fundo={fundo} className="ilha--apps">
        <AppsDaBarra links={links} />
      </Ilha>
      <Ilha vidro={vidro} fundo={fundo} className="ilha--relogio">
        <Bandeja relogio={relogio} />
      </Ilha>
    </div>
  );
}
