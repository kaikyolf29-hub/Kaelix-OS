import { EDICAO, LINKS, NOME, SECOES } from '../dados.js';

export default function Rodape() {
  const ano = new Date().getFullYear();
  return (
    <footer className="rodape" aria-labelledby="rodape-titulo">
      <div className="wrap rodape__wrap">
        <div className="rodape__fecho">
          <img className="rodape__logo" src="img/logo.svg" alt="" width="96" height="96" loading="lazy" />
          <h2 id="rodape-titulo" className="rodape__nome">
            {NOME}
          </h2>
          <p className="sub">Uma edição por ano: depois do 27 vem o 28. Entre uma e outra, as correções chegam sozinhas.</p>
          <div className="btn-linha">
            <a className="btn btn--primario" id="rodape-baixar" href="#baixar">
              Baixar o Matsu {EDICAO}
            </a>
          </div>
        </div>
        <div className="rodape__diretorio">
          <div className="rodape__colunas">
            <div>
              <h3>O sistema</h3>
              <ul>
                {SECOES.map(s => (
                  <li key={s.id}>
                    <a href={`#${s.id}`}>{s.nome}</a>
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h3>O projeto</h3>
              <ul>
                <li>
                  <a href={LINKS.codigo}>Código no GitHub</a>
                </li>
                <li>
                  <a href={LINKS.versoes}>Todas as versões</a>
                </li>
                <li>
                  <a href={LINKS.novidades}>Novidades</a>
                </li>
                <li>
                  <a href={LINKS.licenca}>Licença GPL 3.0</a>
                </li>
              </ul>
            </div>
          </div>
          <p className="rodape__legal">
            {NOME}, {ano}. Livre e de graça. O nome vem do pinheiro japonês, matsu (松). Steam, Discord e os outros nomes e
            logos são marcas dos seus donos.
          </p>
        </div>
      </div>
    </footer>
  );
}
