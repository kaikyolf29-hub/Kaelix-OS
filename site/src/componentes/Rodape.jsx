import { APOIAR, EDICAO, LINKS, NOME, RODAPE, TEM_APOIO } from '../dados.js';
import { useT } from '../idioma.js';
import { BotaoIdioma } from './Navegacao.jsx';

// O <footer class="rodape closing"> está no index.html; o React desenha o de dentro:
// o fecho (o nome grande, a frase, o botão e os links) e a linha de baixo.
export default function Rodape() {
  const ano = new Date().getFullYear();
  const t = useT();
  return (
    <div className="wrap rodape__wrap">
      <div className="rodape__chamada">
        <h2 id="rodape-titulo" className="rodape__nome">
          {NOME}
        </h2>
        <div className="rodape__fecho">
          <p className="sub">
            {t(
              'Uma edição por ano: depois do 27 vem o 28. Entre uma e outra, as correções chegam sozinhas.',
              'One edition per year: after 27 comes 28. In between, fixes arrive on their own.'
            )}
          </p>
          <div className="btn-linha">
            <a className="btn btn--primario" id="rodape-baixar" href="#baixar">
              {t('Baixar o Matsu', 'Download Matsu')} {EDICAO}
            </a>
          </div>
        </div>
        <div className="rodape__colunas">
          <div>
            <h3>{t('O sistema', 'The system')}</h3>
            <ul>
              {RODAPE.sistema.map(s => (
                <li key={s.id}>
                  <a href={`#${s.id}`}>{t(s.nome)}</a>
                </li>
              ))}
            </ul>
          </div>
          <div>
            <h3>{t('Para começar', 'Get started')}</h3>
            <ul>
              {RODAPE.comecar.map(s => (
                <li key={s.id}>
                  <a href={`#${s.id}`}>{t(s.nome)}</a>
                </li>
              ))}
            </ul>
          </div>
          <div>
            <h3>{t('O projeto', 'The project')}</h3>
            <ul>
              {TEM_APOIO && (
                <li>
                  <a href={`#${APOIAR.id}`}>{t(APOIAR.nome)}</a>
                </li>
              )}
              <li>
                <a href={LINKS.codigo}>{t('Código no GitHub', 'Code on GitHub')}</a>
              </li>
              <li>
                <a href={LINKS.versoes}>{t('Todas as versões', 'All versions')}</a>
              </li>
              <li>
                <a href={LINKS.novidades}>{t('Novidades', 'What’s new')}</a>
              </li>
              <li>
                <a href={LINKS.licenca}>{t('Licença GPL 3.0', 'GPL 3.0 license')}</a>
              </li>
              <li>
                <BotaoIdioma longo />
              </li>
            </ul>
          </div>
        </div>
      </div>
      <p className="rodape__legal">
        {t(
          `${NOME}, ${ano}. Livre e de graça. O nome vem do pinheiro japonês, matsu (松). Steam, Discord e os outros nomes e logos são marcas dos seus donos.`,
          `${NOME}, ${ano}. Free and open. The name comes from the Japanese pine, matsu (松). Steam, Discord and the other names and logos are trademarks of their owners.`
        )}
      </p>
    </div>
  );
}
