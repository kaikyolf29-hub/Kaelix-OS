import SpotlightCard from '../reactbits/SpotlightCard.jsx';
import { useT } from '../idioma.js';

const APPS = [
  {
    nome: { pt: 'Arquivos', en: 'Files' },
    texto: { pt: 'Abas, busca e ícones de pasta próprios.', en: 'Tabs, search and its own folder icons.' },
    icone: 'arquivos',
    foto: 'janela-arquivos',
    l: 998,
    a: 620
  },
  {
    nome: { pt: 'Gerenciador de tarefas', en: 'Task Manager' },
    texto: { pt: 'Ctrl + Shift + Esc, como no Windows.', en: 'Ctrl + Shift + Esc, like on Windows.' },
    icone: 'tarefas',
    foto: 'janela-tarefas',
    l: 1077,
    a: 681
  },
  {
    nome: { pt: 'Calendário', en: 'Calendar' },
    texto: { pt: 'Mês, semana e eventos com cor.', en: 'Month, week and color-coded events.' },
    icone: 'calendario',
    foto: 'app-calendario',
    l: 995,
    a: 640
  },
  {
    nome: { pt: 'Notas', en: 'Notes' },
    texto: { pt: 'Listas, fixadas e pastas.', en: 'Lists, pinned notes and folders.' },
    icone: 'notas',
    foto: 'app-notas',
    l: 1000,
    a: 640
  },
  {
    nome: { pt: 'Música', en: 'Music' },
    texto: { pt: 'Toca o que está na pasta Música.', en: 'Plays what’s in your Music folder.' },
    icone: 'musica',
    foto: 'app-musica',
    l: 966,
    a: 640
  },
  {
    nome: { pt: 'Relógio', en: 'Clock' },
    texto: { pt: 'Alarmes, timer e cronômetro.', en: 'Alarms, timer and stopwatch.' },
    icone: 'relogio',
    foto: 'app-relogio',
    l: 982,
    a: 640
  }
];

export default function Apps() {
  const t = useT();
  return (
    <section className="secao" id="apps" aria-labelledby="apps-titulo">
      <div className="wrap">
        <div className="cabeca">
          <div>
            <h2 id="apps-titulo">{t('Os apps do dia a dia já vêm junto', 'Everyday apps come included')}</h2>
            <p className="sub">
              {t(
                'Feitos para o Matsu, com o mesmo vidro e o mesmo jeito de usar. Também tem Fotos, Câmera, Calculadora e Bloco de notas.',
                'Made for Matsu, with the same glass and the same way of working. Photos, Camera, Calculator and Text Editor are there too.'
              )}
            </p>
          </div>
        </div>
        <ul className="grade-apps">
          {APPS.map(app => (
            <li key={app.icone}>
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
                    <b>{t(app.nome)}</b>
                    <span>{t(app.texto)}</span>
                  </span>
                </div>
                <div className="cartao-app__janela">
                  <img
                    src={`img/${app.foto}-640.webp`}
                    srcSet={`img/${app.foto}-320.webp 320w, img/${app.foto}-640.webp 640w, img/${app.foto}.webp ${app.l}w`}
                    sizes="(max-width: 639px) 45vw, (max-width: 1023px) 46vw, 362px"
                    alt={t(`O app ${app.nome.pt} do Matsu`, `The Matsu ${app.nome.en} app`)}
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
