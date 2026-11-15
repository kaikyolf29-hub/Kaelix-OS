import { useEffect, useRef, useState } from 'react';
import SpotlightCard from '../reactbits/SpotlightCard.jsx';
import Icone from './Icone.jsx';
import { EDICAO, LINKS, TAMANHO_ISO } from '../dados.js';
import { LOCALE, useIdioma, useT } from '../idioma.js';

const PLACAS = [
  {
    id: 'amd',
    nome: { pt: 'AMD ou Intel', en: 'AMD or Intel' },
    texto: { pt: 'Para placas de vídeo AMD (Radeon), Intel e vídeo integrado.', en: 'For AMD (Radeon) and Intel graphics cards and integrated graphics.' }
  },
  {
    id: 'nvidia',
    nome: { pt: 'NVIDIA', en: 'NVIDIA' },
    texto: { pt: 'Já vem com o driver da NVIDIA (GeForce) instalado.', en: 'Comes with the NVIDIA (GeForce) driver installed.' }
  }
];

function tamanho(bytes, idioma) {
  const gb = bytes / 1024 ** 3;
  if (gb >= 1) return `${gb.toLocaleString(LOCALE[idioma], { maximumFractionDigits: 1 })} GB`;
  return `${Math.round(bytes / 1024 ** 2)} MB`;
}

// As ISOs de um Release, pela placa: { amd: { nome, url, bytes, somaUrl }, nvidia: ... }.
function isosDo(rel) {
  const arquivos = {};
  for (const a of rel.assets || []) {
    const placa = a.name.endsWith('-nvidia.iso') ? 'nvidia' : a.name.endsWith('-amd.iso') ? 'amd' : null;
    if (placa) arquivos[placa] = { ...arquivos[placa], nome: a.name, url: a.browser_download_url, bytes: a.size };
    const soma = a.name.match(/-(amd|nvidia)\.iso\.sha256$/);
    if (soma) arquivos[soma[1]] = { ...arquivos[soma[1]], somaUrl: a.browser_download_url };
  }
  return arquivos.amd || arquivos.nvidia ? arquivos : null;
}

// Lê a última versão publicada no GitHub (o fluxo "Publicar versão estável"
// cria o Release com as ISOs). Enquanto não tem versão estável, oferece a de
// teste (o fluxo "Publicar versão de teste" deixa um Release marcado como teste).
// Sem nenhuma das duas, o cartão diz que a primeira vem aí.
function useVersao() {
  const [estado, setEstado] = useState({ fase: 'carregando' });
  useEffect(() => {
    let vivo = true;
    const guardado = (() => {
      try {
        return JSON.parse(sessionStorage.getItem('matsu-versao-2') || 'null');
      } catch {
        return null;
      }
    })();
    if (guardado) {
      setEstado(guardado);
      return undefined;
    }
    fetch(LINKS.apiVersoes, { headers: { Accept: 'application/vnd.github+json' } })
      .then(r => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
      .then(lista => {
        const publicadas = (Array.isArray(lista) ? lista : []).filter(r => !r.draft && isosDo(r));
        // Enquanto uma versão nova ainda recebe as ISOs (a da NVIDIA chega antes
        // da AMD), fica a que já tem as duas.
        const completa = r => {
          const a = isosDo(r);
          return Boolean(a.amd?.url && a.nvidia?.url);
        };
        return (
          publicadas.find(r => !r.prerelease && completa(r)) ||
          publicadas.find(r => r.prerelease && completa(r)) ||
          publicadas.find(r => !r.prerelease) ||
          publicadas.find(r => r.prerelease) ||
          null
        );
      })
      .then(rel => {
        if (!rel) return { fase: 'sem-versao' };
        return {
          fase: 'pronta',
          teste: Boolean(rel.prerelease),
          versao: (rel.tag_name || '').replace(/^v/, ''),
          data: rel.published_at,
          pagina: rel.html_url,
          arquivos: isosDo(rel)
        };
      })
      .catch(() => ({ fase: 'erro' }))
      .then(novo => {
        if (!vivo) return;
        setEstado(novo);
        if (novo.fase !== 'erro') {
          try {
            sessionStorage.setItem('matsu-versao-2', JSON.stringify(novo));
          } catch {
            // Sem armazenamento: busca de novo na próxima visita.
          }
        }
      });
    return () => {
      vivo = false;
    };
  }, []);
  return estado;
}

// A soma SHA-256 confere se a ISO chegou inteira. O botão copia e mostra o visto.
function Soma({ url }) {
  const t = useT();
  const [soma, setSoma] = useState('');
  const [copiado, setCopiado] = useState(false);
  const espera = useRef(0);
  useEffect(() => {
    if (!url) return;
    setSoma('');
    // O arquivo .sha256 vem do GitHub sem permissão para o navegador ler (CORS):
    // pela API do Release não dá, então tentamos e, se não der, mostramos o link.
    fetch(url)
      .then(r => (r.ok ? r.text() : ''))
      .then(t => setSoma((t.split(/\s+/)[0] || '').trim()))
      .catch(() => setSoma(''));
  }, [url]);
  useEffect(() => () => clearTimeout(espera.current), []);
  if (!url) return null;
  if (!soma) {
    return (
      <p className="soma">
        <a className="link" href={url}>
          {t('Baixar a soma SHA-256', 'Download the SHA-256 checksum')}
        </a>{' '}
        {t('para conferir se a ISO chegou inteira.', 'to check that the ISO arrived intact.')}
      </p>
    );
  }
  const copiar = async () => {
    try {
      await navigator.clipboard.writeText(soma);
      setCopiado(true);
      clearTimeout(espera.current);
      espera.current = setTimeout(() => setCopiado(false), 1800);
    } catch {
      setCopiado(false);
    }
  };
  return (
    <div className="soma soma--codigo">
      <span>SHA-256</span>
      <code>{soma}</code>
      <button type="button" className="botao-icone" onClick={copiar} aria-label={copiado ? t('Soma copiada', 'Checksum copied') : t('Copiar a soma SHA-256', 'Copy the SHA-256 checksum')}>
        <span className="troca-icone" data-mostra={copiado ? 'b' : 'a'}>
          <Icone nome="copiar" tamanho={18} className="troca-icone__a" />
          <Icone nome="certo" tamanho={18} className="troca-icone__b visto" />
        </span>
      </button>
    </div>
  );
}

const REQUISITOS = [
  { nome: { pt: 'Processador', en: 'Processor' }, valor: { pt: '64 bits, Intel ou AMD', en: '64-bit, Intel or AMD' } },
  { nome: { pt: 'Memória', en: 'Memory' }, valor: { pt: '4 GB, ou 8 GB para jogar', en: '4 GB, or 8 GB for gaming' } },
  { nome: { pt: 'Disco', en: 'Disk' }, valor: { pt: '64 GB livres, de preferência SSD', en: '64 GB free, ideally an SSD' } },
  { nome: { pt: 'Placa de vídeo', en: 'Graphics card' }, valor: { pt: 'AMD, Intel ou NVIDIA', en: 'AMD, Intel or NVIDIA' } },
  { nome: { pt: 'Pendrive', en: 'USB drive' }, valor: { pt: '4 GB ou mais', en: '4 GB or more' } },
  { nome: { pt: 'Internet', en: 'Internet' }, valor: { pt: 'Na hora de instalar, por cabo ou Wi-Fi', en: 'While installing, wired or Wi-Fi' } }
];

export default function Baixar() {
  const t = useT();
  const idioma = useIdioma();
  const [placa, setPlacaAgora] = useState(0);
  // O texto só faz a troca com desfoque depois que a pessoa escolhe a placa.
  const [trocou, setTrocou] = useState(false);
  const setPlaca = i => {
    setTrocou(true);
    setPlacaAgora(i);
  };
  const versao = useVersao();
  const atual = PLACAS[placa];
  const arquivo = versao.fase === 'pronta' ? versao.arquivos[atual.id] : null;
  const teste = versao.fase === 'pronta' && versao.teste;
  const nomeVersao = teste
    ? t('a versão de teste', 'the test version')
    : `${t('o Matsu', 'Matsu')} ${versao.fase === 'pronta' ? versao.versao : EDICAO}`;
  const data =
    versao.fase === 'pronta' && versao.data
      ? new Date(versao.data).toLocaleDateString(LOCALE[idioma], { day: 'numeric', month: 'long', year: 'numeric' })
      : '';

  return (
    <section className="secao" id="baixar" aria-labelledby="baixar-titulo">
      <div className="wrap divisao divisao--5-7">
        <div className="divisao__texto">
          <h2 id="baixar-titulo">
            {t('Baixar o Matsu', 'Download Matsu')} {EDICAO}
          </h2>
          <p className="sub">
            {t(
              'É de graça, sem cadastro e sem propaganda. Escolha a ISO pela sua placa de vídeo.',
              'It’s free, with no sign-up and no ads. Pick the ISO for your graphics card.'
            )}
          </p>
          <SpotlightCard
            className="cartao-baixar"
            spotlightColor="var(--luz)"
            intensity={0.16}
            spotlightSize={320}
            style={{
              '--spotlight-card-surface': 'var(--cartao)',
              '--spotlight-card-border': 'var(--linha-forte)',
              '--spotlight-card-shadow': 'none'
            }}
          >
            <div className="segmentos segmentos--largo" role="radiogroup" aria-label={t('Sua placa de vídeo', 'Your graphics card')}>
              <span className="segmentos__marca" style={{ '--i': placa }} aria-hidden="true" />
              {PLACAS.map((p, i) => (
                <button
                  key={p.id}
                  type="button"
                  role="radio"
                  aria-checked={i === placa}
                  tabIndex={i === placa ? 0 : -1}
                  onClick={() => setPlaca(i)}
                  onKeyDown={e => {
                    if (['ArrowRight', 'ArrowLeft', 'ArrowUp', 'ArrowDown'].includes(e.key)) {
                      e.preventDefault();
                      const novo = 1 - placa;
                      setPlaca(novo);
                      e.currentTarget.parentElement.querySelectorAll('[role="radio"]')[novo]?.focus();
                    }
                  }}
                >
                  {t(p.nome)}
                </button>
              ))}
            </div>
            <p className={`cartao-baixar__placa${trocou ? ' troca-texto' : ''}`} key={atual.id}>
              {t(atual.texto)}
            </p>

            {versao.fase === 'pronta' && arquivo ? (
              <>
                <a className="btn btn--primario btn--baixar" href={arquivo.url}>
                  <Icone nome="baixar" tamanho={20} />
                  {t('Baixar', 'Download')} {nomeVersao}
                </a>
                <p className={`cartao-baixar__arquivo${trocou ? ' troca-texto' : ''}`} key={arquivo.nome}>
                  {arquivo.nome}, {tamanho(arquivo.bytes, idioma)}
                  {data && (teste ? <>. {t('Montada em', 'Built on')} {data}.</> : <>. {t('Publicada em', 'Released on')} {data}.</>)}
                  {teste && <> {t('A primeira versão oficial sai depois dos testes.', 'The first official version comes after testing.')}</>}
                </p>
                <Soma url={arquivo.somaUrl} />
              </>
            ) : (
              <>
                <a className="btn btn--primario btn--baixar" href={LINKS.versoes} aria-describedby="aviso-versao">
                  <Icone nome="baixar" tamanho={20} />
                  {t('Baixar', 'Download')} {nomeVersao}
                </a>
                <p className="cartao-baixar__arquivo" id="aviso-versao" aria-live="polite">
                  {versao.fase === 'carregando'
                    ? t('Procurando a versão mais nova...', 'Looking for the newest version...')
                    : versao.fase === 'erro'
                      ? t(
                          'Não deu para ler a versão mais nova agora. O botão abre a página de versões no GitHub.',
                          'Couldn’t read the newest version right now. The button opens the releases page on GitHub.'
                        )
                      : t(
                          `A primeira versão está quase pronta. Quando sair, este botão baixa a ISO (${TAMANHO_ISO.pt}).`,
                          `The first version is almost ready. When it’s out, this button downloads the ISO (${TAMANHO_ISO.en}).`
                        )}
                </p>
              </>
            )}
            <p className="cartao-baixar__links">
              <a className="link" href={LINKS.versoes}>
                {t('Ver todas as versões', 'See all versions')}
              </a>
              <a className="link" href={LINKS.novidades}>
                {t('Ler as novidades', 'Read what’s new')}
              </a>
            </p>
          </SpotlightCard>
        </div>
        <div className="requisitos">
          <h3>{t('Requisitos do PC', 'PC requirements')}</h3>
          <dl>
            {REQUISITOS.map(r => (
              <div key={r.nome.pt}>
                <dt>{t(r.nome)}</dt>
                <dd>{t(r.valor)}</dd>
              </div>
            ))}
          </dl>
        </div>
      </div>
    </section>
  );
}
