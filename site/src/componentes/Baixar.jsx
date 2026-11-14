import { useEffect, useRef, useState } from 'react';
import SpotlightCard from '../reactbits/SpotlightCard.jsx';
import Icone from './Icone.jsx';
import { EDICAO, LINKS, TAMANHO_ISO } from '../dados.js';

const PLACAS = [
  { id: 'amd', nome: 'AMD ou Intel', texto: 'Para placas de vídeo AMD (Radeon), Intel e vídeo integrado.' },
  { id: 'nvidia', nome: 'NVIDIA', texto: 'Já vem com o driver da NVIDIA (GeForce) instalado.' }
];

function tamanho(bytes) {
  const gb = bytes / 1024 ** 3;
  if (gb >= 1) return `${gb.toLocaleString('pt-BR', { maximumFractionDigits: 1 })} GB`;
  return `${Math.round(bytes / 1024 ** 2)} MB`;
}

// Lê a última versão publicada no GitHub (o fluxo "Publicar versão estável"
// cria o Release com as ISOs). Sem versão publicada, o cartão diz que ela vem aí.
function useVersao() {
  const [estado, setEstado] = useState({ fase: 'carregando' });
  useEffect(() => {
    let vivo = true;
    const guardado = (() => {
      try {
        return JSON.parse(sessionStorage.getItem('matsu-versao') || 'null');
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
      .then(lista => (Array.isArray(lista) ? lista.find(r => !r.draft && !r.prerelease) : null))
      .then(rel => {
        if (!rel) return { fase: 'sem-versao' };
        const arquivos = {};
        for (const a of rel.assets || []) {
          const placa = a.name.endsWith('-nvidia.iso') ? 'nvidia' : a.name.endsWith('-amd.iso') ? 'amd' : null;
          if (placa) arquivos[placa] = { ...arquivos[placa], nome: a.name, url: a.browser_download_url, bytes: a.size };
          const soma = a.name.match(/-(amd|nvidia)\.iso\.sha256$/);
          if (soma) arquivos[soma[1]] = { ...arquivos[soma[1]], somaUrl: a.browser_download_url };
        }
        if (!arquivos.amd && !arquivos.nvidia) return { fase: 'sem-versao' };
        return {
          fase: 'pronta',
          versao: (rel.tag_name || '').replace(/^v/, ''),
          data: rel.published_at,
          pagina: rel.html_url,
          arquivos
        };
      })
      .catch(() => ({ fase: 'erro' }))
      .then(novo => {
        if (!vivo) return;
        setEstado(novo);
        if (novo.fase !== 'erro') {
          try {
            sessionStorage.setItem('matsu-versao', JSON.stringify(novo));
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
          Baixar a soma SHA-256
        </a>{' '}
        para conferir se a ISO chegou inteira.
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
      <button type="button" className="botao-icone" onClick={copiar} aria-label={copiado ? 'Soma copiada' : 'Copiar a soma SHA-256'}>
        <span className="troca-icone" data-mostra={copiado ? 'b' : 'a'}>
          <Icone nome="copiar" tamanho={18} className="troca-icone__a" />
          <Icone nome="certo" tamanho={18} className="troca-icone__b visto" />
        </span>
      </button>
    </div>
  );
}

export default function Baixar() {
  const [placa, setPlaca] = useState(0);
  const versao = useVersao();
  const atual = PLACAS[placa];
  const arquivo = versao.fase === 'pronta' ? versao.arquivos[atual.id] : null;
  const nomeVersao = versao.fase === 'pronta' ? `Matsu ${versao.versao}` : `Matsu ${EDICAO}`;
  const data =
    versao.fase === 'pronta' && versao.data
      ? new Date(versao.data).toLocaleDateString('pt-BR', { day: 'numeric', month: 'long', year: 'numeric' })
      : '';

  return (
    <section className="secao" id="baixar" aria-labelledby="baixar-titulo">
      <div className="wrap divisao divisao--7-5">
        <div className="divisao__texto">
          <h2 id="baixar-titulo">Baixar o Matsu {EDICAO}</h2>
          <p className="sub">É de graça, sem cadastro e sem propaganda. Escolha a ISO pela sua placa de vídeo.</p>
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
            <div className="segmentos segmentos--largo" role="radiogroup" aria-label="Sua placa de vídeo">
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
                  {p.nome}
                </button>
              ))}
            </div>
            <p className="cartao-baixar__placa troca-texto" key={atual.id}>
              {atual.texto}
            </p>

            {versao.fase === 'pronta' && arquivo ? (
              <>
                <a className="btn btn--primario btn--grande" href={arquivo.url}>
                  <Icone nome="baixar" tamanho={20} />
                  Baixar o {nomeVersao}
                </a>
                <p className="cartao-baixar__arquivo troca-texto" key={arquivo.nome}>
                  {arquivo.nome}, {tamanho(arquivo.bytes)}
                  {data && <>. Publicada em {data}.</>}
                </p>
                <Soma url={arquivo.somaUrl} />
              </>
            ) : (
              <>
                <a className="btn btn--primario btn--grande" href={LINKS.versoes} aria-describedby="aviso-versao">
                  <Icone nome="baixar" tamanho={20} />
                  Baixar o {nomeVersao}
                </a>
                <p className="cartao-baixar__arquivo" id="aviso-versao" aria-live="polite">
                  {versao.fase === 'carregando'
                    ? 'Procurando a versão mais nova...'
                    : versao.fase === 'erro'
                      ? 'Não deu para ler a versão mais nova agora. O botão abre a página de versões no GitHub.'
                      : `A primeira versão está quase pronta. Quando sair, este botão baixa a ISO (${TAMANHO_ISO}).`}
                </p>
              </>
            )}
            <p className="cartao-baixar__links">
              <a className="link" href={LINKS.versoes}>
                Ver todas as versões
              </a>
              <a className="link" href={LINKS.novidades}>
                Ler as novidades
              </a>
            </p>
          </SpotlightCard>
        </div>
        <div className="requisitos">
          <h3>O que o PC precisa ter</h3>
          <dl>
            <div>
              <dt>Processador</dt>
              <dd>64 bits, Intel ou AMD</dd>
            </div>
            <div>
              <dt>Memória</dt>
              <dd>4 GB, ou 8 GB para jogar</dd>
            </div>
            <div>
              <dt>Disco</dt>
              <dd>64 GB livres, de preferência SSD</dd>
            </div>
            <div>
              <dt>Placa de vídeo</dt>
              <dd>AMD, Intel ou NVIDIA</dd>
            </div>
            <div>
              <dt>Pendrive</dt>
              <dd>4 GB ou mais</dd>
            </div>
            <div>
              <dt>Internet</dt>
              <dd>Na hora de instalar, por cabo ou Wi-Fi</dd>
            </div>
          </dl>
        </div>
      </div>
    </section>
  );
}
