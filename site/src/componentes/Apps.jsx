import SpotlightCard from '../reactbits/SpotlightCard.jsx';

const APPS = [
  { nome: 'Arquivos', texto: 'Abas, busca e ícones de pasta próprios.', icone: 'arquivos', foto: 'janela-arquivos', l: 998, a: 620 },
  { nome: 'Gerenciador de tarefas', texto: 'Ctrl + Shift + Esc, como no Windows.', icone: 'tarefas', foto: 'janela-tarefas', l: 1077, a: 681 },
  { nome: 'Calendário', texto: 'Mês, semana e eventos com cor.', icone: 'calendario', foto: 'app-calendario', l: 995, a: 640 },
  { nome: 'Notas', texto: 'Listas, fixadas e pastas.', icone: 'notas', foto: 'app-notas', l: 1000, a: 640 },
  { nome: 'Música', texto: 'Toca o que está na pasta Música.', icone: 'musica', foto: 'app-musica', l: 966, a: 640 },
  { nome: 'Relógio', texto: 'Alarmes, timer e cronômetro.', icone: 'relogio', foto: 'app-relogio', l: 982, a: 640 }
];

export default function Apps() {
  return (
    <section className="secao" id="apps" aria-labelledby="apps-titulo">
      <div className="wrap">
        <div className="cabeca">
          <div>
            <h2 id="apps-titulo">Os apps do dia a dia já vêm junto</h2>
            <p className="sub">Feitos para o Matsu, com o mesmo vidro e o mesmo jeito de usar. Também tem Fotos, Câmera, Calculadora e Bloco de notas.</p>
          </div>
        </div>
        <ul className="grade-apps">
          {APPS.map(app => (
            <li key={app.nome}>
              <SpotlightCard
                className="cartao-app"
                spotlightColor="var(--luz)"
                intensity={0.22}
                spotlightSize={260}
                style={{
                  '--spotlight-card-surface': 'var(--cartao)',
                  '--spotlight-card-border': 'var(--linha)',
                  '--spotlight-card-shadow': 'none'
                }}
              >
                <div className="cartao-app__topo">
                  <img src={`icones/${app.icone}.svg`} alt="" width="32" height="32" loading="lazy" />
                  <span>
                    <b>{app.nome}</b>
                    <span>{app.texto}</span>
                  </span>
                </div>
                <div className="cartao-app__janela">
                  <img
                    src={`img/${app.foto}-640.webp`}
                    srcSet={`img/${app.foto}-320.webp 320w, img/${app.foto}-640.webp 640w, img/${app.foto}.webp ${app.l}w`}
                    sizes="(max-width: 639px) 45vw, (max-width: 1023px) 46vw, 362px"
                    alt={`O app ${app.nome} do Matsu`}
                    width={app.l}
                    height={app.a}
                    loading="lazy"
                  />
                </div>
              </SpotlightCard>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
