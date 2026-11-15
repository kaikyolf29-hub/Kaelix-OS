import Icone from './Icone.jsx';
import { useT } from '../idioma.js';

// Uma parte com o texto à esquerda e a janela de verdade do app à direita.
function Divisao({ id, titulo, sub, children, foto, alt, largura, altura }) {
  const t = useT();
  return (
    <section className="secao" id={id} aria-labelledby={`${id}-titulo`}>
      <div className="wrap divisao divisao--5-7">
        <div className="divisao__texto">
          <h2 id={`${id}-titulo`}>{t(titulo)}</h2>
          <p className="sub">{t(sub)}</p>
          {children}
        </div>
        <figure className="quadro quadro--janela">
          <img
            className="quadro__foto"
            src={`img/${foto}.webp`}
            srcSet={`img/${foto}-640.webp 640w, img/${foto}.webp ${largura}w`}
            sizes="(min-width: 1024px) 737px, 100vw"
            width={largura}
            height={altura}
            alt={t(alt)}
            loading="lazy"
          />
        </figure>
      </div>
    </section>
  );
}

function Linhas({ itens }) {
  const t = useT();
  return (
    <ul className="linhas">
      {itens.map(it => (
        <li key={it.titulo.pt}>
          <span className="linhas__icone">
            {it.marcas ? (
              <span className="marcas">
                {it.marcas.map(m => (
                  <img key={m.nome} src={m.icone} alt={m.nome} width="22" height="22" loading="lazy" />
                ))}
              </span>
            ) : (
              <Icone nome={it.icone} tamanho={20} />
            )}
          </span>
          <span>
            <b>{t(it.titulo)}</b>
            <span>{t(it.texto)}</span>
          </span>
        </li>
      ))}
    </ul>
  );
}

export function Jogos() {
  return (
    <Divisao
      id="jogos"
      titulo={{ pt: 'Pronto para jogar no primeiro boot', en: 'Ready for gaming from the first boot' }}
      sub={{
        pt: 'A Central de jogos junta seus jogos da Steam, com a capa e as horas jogadas, e dá um perfil gráfico para cada um.',
        en: 'The Game Center brings your Steam games together, with cover art and hours played, and gives each one a graphics profile.'
      }}
      foto="janela-jogos"
      largura={1149}
      altura={717}
      alt={{
        pt: 'A Central de jogos do Matsu, com o modo jogo, a sobreposição de FPS e a placa de vídeo',
        en: 'The Matsu Game Center, with game mode, the FPS overlay and the graphics card'
      }}
    >
      <Linhas
        itens={[
          {
            titulo: { pt: 'Steam, Heroic e Lutris instalados', en: 'Steam, Heroic and Lutris installed' },
            texto: { pt: 'A Epic e a GOG entram pelo Heroic.', en: 'Epic and GOG come in through Heroic.' },
            marcas: [
              { nome: 'Steam', icone: 'icones/steam.svg' },
              { nome: 'Heroic', icone: 'icones/heroic.svg' },
              { nome: 'Lutris', icone: 'icones/lutris.svg' }
            ]
          },
          {
            titulo: { pt: 'FPS na tela com um atalho', en: 'FPS on screen with one shortcut' },
            texto: { pt: 'Win + Alt + F mostra FPS, processador e placa.', en: 'Win + Alt + F shows FPS, processor and graphics card.' },
            icone: 'sobreposicao'
          },
          {
            titulo: { pt: 'O driver certo já vem', en: 'The right driver comes included' },
            texto: { pt: 'AMD e Intel numa ISO, NVIDIA na outra.', en: 'AMD and Intel in one ISO, NVIDIA in the other.' },
            icone: 'placa'
          },
          {
            titulo: { pt: 'Controles de PS4, PS5 e Xbox', en: 'PS4, PS5 and Xbox controllers' },
            texto: { pt: 'Ligue pelo Bluetooth e jogue.', en: 'Connect over Bluetooth and play.' },
            icone: 'controle'
          }
        ]}
      />
    </Divisao>
  );
}

const MARCAS_LOJA = [
  { nome: 'Brave', icone: 'icones/brave.svg' },
  { nome: 'Google Chrome', icone: 'icones/chrome.svg' },
  { nome: 'Discord', icone: 'icones/discord.svg' },
  { nome: 'Spotify', icone: 'icones/spotify.svg' },
  { nome: 'OBS Studio', icone: 'icones/obs.svg' },
  { nome: 'Visual Studio Code', icone: 'icones/vscode.svg' }
];

export function Loja() {
  const t = useT();
  return (
    <Divisao
      id="loja"
      titulo={{ pt: 'Todos os apps numa loja só', en: 'All your apps in one store' }}
      sub={{
        pt: 'A Loja do Matsu tem milhares de apps com fotos e descrição. Instagram, TikTok e YouTube viram app, com a logo deles.',
        en: 'The Matsu Store has thousands of apps with screenshots and descriptions. Instagram, TikTok and YouTube become apps, with their own logos.'
      }}
      foto="janela-loja"
      largura={1185}
      altura={753}
      alt={{
        pt: 'A Loja do Matsu com o OBS Studio em destaque e Brave, Chrome, Discord e Spotify nos essenciais',
        en: 'The Matsu Store with OBS Studio featured and Brave, Chrome, Discord and Spotify among the essentials'
      }}
    >
      <ul className="vitrine" aria-label={t('Alguns apps da Loja', 'Some apps from the Store')}>
        {MARCAS_LOJA.map(m => (
          <li key={m.nome}>
            <img src={m.icone} alt="" width="32" height="32" loading="lazy" />
            <span>{m.nome}</span>
          </li>
        ))}
      </ul>
      <p className="nota">
        {t(
          'Os apps pagos usam um código de resgate, que você compra fora e digita na Loja.',
          'Paid apps use a redeem code, which you buy elsewhere and type into the Store.'
        )}
      </p>
    </Divisao>
  );
}

export function Seguranca() {
  return (
    <Divisao
      id="seguranca"
      titulo={{ pt: 'Segurança e atualizações do Matsu', en: 'Matsu security and updates' }}
      sub={{
        pt: 'Mostra num lugar só o escudo, a rede e o que cada app pode usar. O sistema se atualiza sozinho.',
        en: 'The shield, the network and what each app can use, all in one place. The system updates itself.'
      }}
      foto="janela-seguranca"
      largura={1113}
      altura={717}
      alt={{
        pt: 'A Central de segurança do Matsu dizendo que o computador está protegido',
        en: 'The Matsu Security Center saying the computer is protected'
      }}
    >
      <Linhas
        itens={[
          {
            titulo: { pt: 'Atualiza inteiro e volta se der errado', en: 'Updates as a whole and rolls back if something breaks' },
            texto: {
              pt: 'A versão nova entra quando você reinicia. Se algo falhar, escolha a anterior no boot.',
              en: 'The new version starts when you restart. If something fails, pick the previous one at boot.'
            },
            icone: 'sincronia'
          },
          {
            titulo: { pt: 'Cada versão é assinada', en: 'Every version is signed' },
            texto: { pt: 'E testada numa máquina virtual antes de sair.', en: 'And tested in a virtual machine before release.' },
            icone: 'verificado'
          },
          {
            titulo: { pt: 'Apps na caixinha deles', en: 'Apps in their own box' },
            texto: { pt: 'Os apps da Loja rodam isolados e um não estraga o outro.', en: 'Store apps run isolated, so one can’t break another.' },
            icone: 'cadeado'
          }
        ]}
      />
    </Divisao>
  );
}
