import { useT } from '../idioma.js';

// Os atalhos do Windows que fazem a mesma coisa no Matsu, e dois do próprio
// Matsu. Todos conferidos no sistema: Meta+A (barra/comum.js), Meta+E
// (Arquivos do Matsu), Ctrl+Shift+Esc (org.matsu.tarefas.desktop), Ctrl+Alt+T
// (Terminal) e Meta+Alt+F (jogos.sh); os outros são os do KDE.
const ATALHOS = [
  { teclas: ['Win'], texto: { pt: 'Abre o menu e a busca', en: 'Opens the menu and search' } },
  { teclas: ['Win', 'E'], texto: { pt: 'Abre os Arquivos', en: 'Opens Files' } },
  { teclas: ['Win', 'A'], texto: { pt: 'Abre a central de controle', en: 'Opens the control center' } },
  { teclas: ['Win', 'L'], texto: { pt: 'Bloqueia a tela', en: 'Locks the screen' } },
  { teclas: ['Win', 'P'], texto: { pt: 'Estende ou duplica a tela', en: 'Extends or duplicates the screen' } },
  { teclas: ['Win', '.'], texto: { pt: 'Abre os emojis', en: 'Opens the emoji picker' } },
  {
    teclas: ['Win', '←'],
    nomes: { '←': { pt: 'seta para a esquerda ou para a direita', en: 'left or right arrow' } },
    texto: { pt: 'Encaixa a janela na metade da tela', en: 'Snaps the window to half the screen' }
  },
  { teclas: ['Alt', 'Tab'], texto: { pt: 'Troca de janela', en: 'Switches windows' } },
  { teclas: ['Ctrl', 'Shift', 'Esc'], texto: { pt: 'Abre o Gerenciador de tarefas', en: 'Opens the Task Manager' } },
  { teclas: ['PrtSc'], texto: { pt: 'Tira uma captura de tela', en: 'Takes a screenshot' } },
  { teclas: ['Ctrl', 'Alt', 'T'], texto: { pt: 'Abre o Terminal', en: 'Opens the Terminal' }, matsu: true },
  { teclas: ['Win', 'Alt', 'F'], texto: { pt: 'Mostra o FPS no jogo', en: 'Shows FPS in games' }, matsu: true }
];

export default function Atalhos() {
  const t = useT();
  return (
    <section className="secao secao--faixa" id="atalhos" aria-labelledby="atalhos-titulo">
      <div className="wrap">
        <div className="cabeca">
          <div>
            <h2 id="atalhos-titulo">{t('Os atalhos que você já conhece', 'The shortcuts you already know')}</h2>
            <p className="sub">
              {t(
                'A tecla Windows abre o menu, e os atalhos de sempre fazem a mesma coisa no Matsu.',
                'The Windows key opens the menu, and the usual shortcuts do the same thing on Matsu.'
              )}
            </p>
          </div>
        </div>
        <ul className="atalhos">
          {ATALHOS.map(a => (
            <li key={a.teclas.join('+')} className="atalho">
              <span className="teclas">
                {a.teclas.map((k, i) => (
                  <span key={k} className="teclas__par">
                    {i > 0 && (
                      <span className="teclas__mais" aria-hidden="true">
                        +
                      </span>
                    )}
                    <kbd className="tecla">
                      {a.nomes?.[k] ? (
                        <>
                          <span aria-hidden="true">
                            ←<span className="tecla__ou">/</span>→
                          </span>
                          <span className="visualmente-escondido">{t(a.nomes[k])}</span>
                        </>
                      ) : (
                        k
                      )}
                    </kbd>
                  </span>
                ))}
              </span>
              <span className="atalho__texto">
                {t(a.texto)}
                {a.matsu && <span className="selo">{t('Do Matsu', 'Matsu only')}</span>}
              </span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
