import { useEffect, useRef, useState } from 'react';
import { encode } from 'uqr';
import SpotlightCard from '../reactbits/SpotlightCard.jsx';
import Icone from './Icone.jsx';
import { APOIO, TEM_APOIO, TEM_PIX, TEM_SPONSORS } from '../dados.js';
import { pixCopiaECola } from '../pix.js';
import { useT } from '../idioma.js';

// O "Pix copia e cola" sai pronto no build (a chave, o nome e a cidade estão em
// dados.js): nada vai para serviço de fora, nem a chave nem quem apoia.
const COPIA_E_COLA = TEM_PIX ? pixCopiaECola(APOIO.pix) : '';

// O QR Code em SVG, desenhado aqui mesmo: quadradinhos pretos num fundo branco
// (nos dois temas, para qualquer câmera ler), com a margem que o padrão pede.
function QrPix({ texto, rotulo }) {
  const { data, size } = encode(texto, { ecc: 'M', border: 0 });
  const margem = 3;
  let caminho = '';
  data.forEach((linha, y) => {
    let x = 0;
    while (x < size) {
      if (!linha[x]) {
        x++;
        continue;
      }
      const inicio = x;
      while (x < size && linha[x]) x++;
      caminho += `M${inicio + margem} ${y + margem}h${x - inicio}v1h-${x - inicio}z`;
    }
  });
  const total = size + margem * 2;
  return (
    <svg className="apoio__qr" viewBox={`0 0 ${total} ${total}`} role="img" aria-label={rotulo} shapeRendering="crispEdges">
      <rect width={total} height={total} rx="2" fill="#fff" />
      <path d={caminho} fill="#111114" />
    </svg>
  );
}

// Uma linha com o texto e o botão Copiar. Sem a área de transferência (navegador
// antigo), o botão seleciona o texto para a pessoa copiar na mão. "inteiro"
// quebra a linha em vez de cortar (a chave aparece toda; o copia e cola é longo
// demais e fica cortado, mas o botão copia ele inteiro).
function Copiavel({ rotulo, valor, botao, aviso, inteiro = false }) {
  const t = useT();
  const [copiado, setCopiado] = useState(false);
  const espera = useRef(0);
  const texto = useRef(null);
  useEffect(() => () => clearTimeout(espera.current), []);

  const copiar = async () => {
    try {
      await navigator.clipboard.writeText(valor);
      setCopiado(true);
      clearTimeout(espera.current);
      espera.current = setTimeout(() => setCopiado(false), 2000);
    } catch {
      const faixa = document.createRange();
      faixa.selectNodeContents(texto.current);
      const selecao = window.getSelection();
      selecao.removeAllRanges();
      selecao.addRange(faixa);
    }
  };

  return (
    <div className={`copiavel${inteiro ? ' copiavel--inteiro' : ''}`}>
      <span className="copiavel__rotulo">{rotulo}</span>
      <code className="copiavel__valor" ref={texto}>
        {valor}
      </code>
      <button
        type="button"
        className="btn btn--secundario copiavel__botao"
        onClick={copiar}
        aria-label={copiado ? t(aviso) : t(botao)}
      >
        <span className="troca-icone" data-mostra={copiado ? 'b' : 'a'} aria-hidden="true">
          <Icone nome="copiar" tamanho={18} className="troca-icone__a" />
          <Icone nome="certo" tamanho={18} className="troca-icone__b visto" />
        </span>
        <span className="copiavel__estado">{copiado ? t('Copiado', 'Copied') : t('Copiar', 'Copy')}</span>
      </button>
      <span className="visualmente-escondido" aria-live="polite">
        {copiado ? t(aviso) : ''}
      </span>
    </div>
  );
}

// "Apoie o Matsu": o projeto é de graça e continua de graça. O Pix (chave
// aleatória, QR Code e copia e cola) e, depois da aprovação, o GitHub Sponsors.
export default function Apoiar() {
  const t = useT();
  if (!TEM_APOIO) return null;
  return (
    <section className="secao secao--apoiar" id="apoiar" aria-labelledby="apoiar-titulo">
      <div className="wrap divisao divisao--5-7">
        <div className="divisao__texto">
          <h2 id="apoiar-titulo">{t('Apoie o Matsu', 'Support Matsu')}</h2>
          <p className="sub">
            {t(
              'O Matsu é de graça e vai continuar de graça, sem anúncio e sem plano pago. Se ele te ajudou, qualquer valor ajuda a manter o projeto andando.',
              'Matsu is free and will stay free, with no ads and no paid plan. If it helped you, any amount helps keep the project going.'
            )}
          </p>
          <p className="nota">
            {t(
              'Esta página não tem rastreador e não guarda nada de quem apoia.',
              'This page has no trackers and keeps nothing about who supports.'
            )}
          </p>
        </div>
        <SpotlightCard
          className="cartao-apoio"
          spotlightColor="var(--luz)"
          intensity={0.16}
          spotlightSize={320}
          style={{
            '--spotlight-card-surface': 'var(--cartao)',
            '--spotlight-card-border': 'var(--linha-forte)',
            '--spotlight-card-shadow': 'none'
          }}
        >
          {TEM_PIX && (
            <div className={`apoio-pix${COPIA_E_COLA ? ' apoio-pix--qr' : ''}`}>
              <div className="apoio-pix__texto">
                <h3>{t('Pix', 'Pix (Brazil)')}</h3>
                <p>
                  {t(
                    'Copie a chave, cole no app do seu banco e escolha o valor que quiser.',
                    'Copy the key, paste it in your Brazilian bank app and choose any amount.'
                  )}
                </p>
                <Copiavel
                  rotulo={t('Chave aleatória', 'Random key')}
                  valor={APOIO.pix.chave}
                  inteiro
                  botao={{ pt: 'Copiar a chave Pix', en: 'Copy the Pix key' }}
                  aviso={{ pt: 'Chave Pix copiada.', en: 'Pix key copied.' }}
                />
                {COPIA_E_COLA && (
                  <Copiavel
                    rotulo={t('Pix copia e cola', 'Pix copy and paste')}
                    valor={COPIA_E_COLA}
                    botao={{ pt: 'Copiar o Pix copia e cola', en: 'Copy the Pix code' }}
                    aviso={{ pt: 'Pix copia e cola copiado.', en: 'Pix code copied.' }}
                  />
                )}
              </div>
              {COPIA_E_COLA && (
                <figure className="apoio-pix__qr">
                  <QrPix texto={COPIA_E_COLA} rotulo={t('QR Code do Pix, sem valor fixo', 'Pix QR code, with no fixed amount')} />
                  <figcaption>
                    {t('Ou aponte a câmera do app do banco para o código.', 'Or point your bank app’s camera at the code.')}
                  </figcaption>
                </figure>
              )}
            </div>
          )}
          {TEM_SPONSORS && (
            <div className="apoio-sponsors">
              <a className="btn btn--secundario" href={`https://github.com/sponsors/${APOIO.sponsors.usuario}`}>
                <Icone nome="coracao" tamanho={18} />
                {t('Apoiar pelo GitHub Sponsors', 'Support on GitHub Sponsors')}
              </a>
              <p>{t('Com cartão, de qualquer país.', 'With a card, from any country.')}</p>
            </div>
          )}
        </SpotlightCard>
      </div>
    </section>
  );
}
