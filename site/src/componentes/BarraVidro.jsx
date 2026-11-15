import { useEffect, useState } from 'react';
import GlassSurface from '../reactbits/GlassSurface.jsx';
import Icone from './Icone.jsx';
import { APPS_BARRA } from '../dados.js';
import { LOCALE, useIdioma, useT } from '../idioma.js';

// A hora e a data como a barra do Matsu mostra: "06:14" e "sáb. 14 de nov."
// (em inglês: "06:14" e "Sat Nov 14").
function useRelogio() {
  const idioma = useIdioma();
  const [agora, setAgora] = useState(null);
  useEffect(() => {
    setAgora(new Date());
    const t = setInterval(() => setAgora(new Date()), 15000);
    return () => clearInterval(t);
  }, []);
  if (!agora) return { hora: '--:--', data: '' };
  const hora = agora.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
  const semana = agora.toLocaleDateString(LOCALE[idioma], { weekday: 'short' });
  const mes = agora.toLocaleDateString(LOCALE[idioma], { month: 'short' });
  if (idioma === 'en') return { hora, data: `${semana} ${mes} ${agora.getDate()}` };
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

function Logo({ cedo = false }) {
  return <img className="barra__logo" src="img/logo.svg" alt="" width="40" height="40" loading={cedo ? 'eager' : 'lazy'} />;
}

function Busca() {
  const t = useT();
  return (
    <span className="barra__busca">
      <Icone nome="busca" tamanho={16} />
      {t('Buscar apps e arquivos', 'Search apps and files')}
    </span>
  );
}

function AppsDaBarra({ comLixeira = true, links = true, ampliar = false }) {
  const t = useT();
  return (
    <ul className={`barra__apps${ampliar ? ' barra__apps--ampliar' : ''}`}>
      {APPS_BARRA.map((app, i) => (
        <li key={app.icone}>
          {links ? (
            <a className="barra__app" href={app.ir} aria-label={t(app.nome)} data-balao={t(app.nome)}>
              {/* No celular o topo mostra só os seis primeiros; os outros esperam. */}
              <img src={app.icone} alt="" width="36" height="36" loading={i < 6 ? 'eager' : 'lazy'} />
            </a>
          ) : (
            <span className="barra__app" data-balao={t(app.nome)}>
              <img src={app.icone} alt="" width="36" height="36" loading="lazy" />
            </span>
          )}
        </li>
      ))}
      {comLixeira && (
        <>
          <li className="barra__separador" aria-hidden="true" />
          <li>
            <span className="barra__app" data-balao={t('Lixeira', 'Trash')}>
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
  const t = useT();

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
          <img src="img/logo.svg" alt="" width="20" height="20" loading="lazy" />
          <b>{t('Arquivos', 'Files')}</b>
          <span>{t('Arquivo', 'File')}</span>
          <span>{t('Editar', 'Edit')}</span>
          <span>{t('Exibir', 'View')}</span>
          <span>{t('Ir', 'Go')}</span>
          <span>{t('Janela', 'Window')}</span>
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
        <Logo cedo={links} />
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
