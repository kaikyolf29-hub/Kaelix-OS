import { EDICAO, LINKS, NOME, SECOES } from '../dados.js';

// O <footer class="rodape closing"> está no index.html; o React desenha o de dentro:
// o fecho (o nome grande, a frase, o botão e os links) e a linha de baixo.
export default function Rodape() {
  const ano = new Date().getFullYear();
  return (
    <div className="wrap rodape__wrap">
      <div className="rodape__chamada">
        <h2 id="rodape-titulo" className="rodape__nome">
          {NOME}
        </h2>
        <div className="rodape__fecho">
          <p className="sub">Uma edição por ano: depois do 27 vem o 28. Entre uma e outra, as correções chegam sozinhas.</p>
          <div className="btn-linha">
            <a className="btn btn--primario" id="rodape-baixar" href="#baixar">
              Baixar o Matsu {EDICAO}
            </a>
          </div>
        </div>
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
      </div>
      <p className="rodape__legal">
        {NOME}, {ano}. Livre e de graça. O nome vem do pinheiro japonês, matsu (松). Steam, Discord e os outros nomes e logos
        são marcas dos seus donos.
      </p>
    </div>
  );
}
