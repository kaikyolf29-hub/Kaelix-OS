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
              <span className={`marcas marcas--${it.marcas.length}`}>
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
            {it.extra}
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

// As nove cores do vidro, as mesmas dos Ajustes do Matsu (PaginaAparencia.qml).
const CORES_VIDRO = [
  { cor: '#a1a1a8', nome: { pt: 'Cinza neutro', en: 'Neutral gray' } },
  { cor: '#2f80ed', nome: { pt: 'Azul', en: 'Blue' } },
  { cor: '#8b5cf6', nome: { pt: 'Roxo', en: 'Purple' } },
  { cor: '#ec4899', nome: { pt: 'Rosa', en: 'Pink' } },
  { cor: '#ef4444', nome: { pt: 'Vermelho', en: 'Red' } },
  { cor: '#f97316', nome: { pt: 'Laranja', en: 'Orange' } },
  { cor: '#eab308', nome: { pt: 'Amarelo', en: 'Yellow' } },
  { cor: '#22c55e', nome: { pt: 'Verde', en: 'Green' } },
  { cor: '#6b7280', nome: { pt: 'Grafite', en: 'Graphite' } }
];

function CoresVidro() {
  const t = useT();
  return (
    <span className="cores" role="list" aria-label={t('As cores do vidro', 'The glass colors')}>
      {CORES_VIDRO.map(c => (
        <span key={c.cor} role="listitem" className="cores__cor" style={{ '--cor': c.cor }} title={t(c.nome)}>
          <span className="visualmente-escondido">{t(c.nome)}</span>
        </span>
      ))}
    </span>
  );
}

export function Aparencia() {
  return (
    <Divisao
      id="aparencia"
      titulo={{ pt: 'Do seu jeito, em poucos cliques', en: 'Make it yours in a few clicks' }}
      sub={{
        pt: 'Nos Ajustes do Matsu você troca o tema, a cor do vidro e o papel de parede, e tudo muda na hora.',
        en: 'In Matsu Settings you change the theme, the glass color and the wallpaper, and everything updates right away.'
      }}
      foto="janela-ajustes"
      largura={793}
      altura={588}
      alt={{
        pt: 'Os Ajustes do Matsu na página Aparência, com o tema, a cor do vidro, o efeito vidro e a transparência',
        en: 'Matsu Settings on the Appearance page, with the theme, the glass color, the glass effect and the transparency'
      }}
    >
      <Linhas
        itens={[
          {
            titulo: { pt: 'Tema claro ou escuro', en: 'Light or dark theme' },
            texto: {
              pt: 'O papel de parede do Matsu vai junto: pôr do sol no claro, céu estrelado no escuro.',
              en: 'The Matsu wallpaper follows along: a sunset in light mode, a starry sky in dark mode.'
            },
            icone: 'aparencia'
          },
          {
            titulo: { pt: 'Vidro na cor que você quiser', en: 'Glass in the color you like' },
            texto: {
              pt: 'Nove cores e três níveis de transparência. Prefere tudo sólido? É só desligar o vidro.',
              en: 'Nine colors and three levels of transparency. Prefer everything solid? Just turn the glass off.'
            },
            icone: 'vidro',
            extra: <CoresVidro />
          },
          {
            titulo: { pt: 'Papel de parede animado', en: 'Animated wallpaper' },
            texto: {
              pt: 'Vídeos e os papéis do Wallpaper Engine que você tem na Steam, em todas as telas.',
              en: 'Videos and the Wallpaper Engine wallpapers you own on Steam, on every screen.'
            },
            icone: 'papel'
          }
        ]}
      />
    </Divisao>
  );
}

export function Criar() {
  return (
    <Divisao
      id="criar"
      titulo={{ pt: 'Para programar, estudar e criar', en: 'For coding, learning and creating' }}
      sub={{
        pt: 'O Terminal do Matsu e as ferramentas de programação já vêm instalados, junto com os apps para gravar e editar vídeo.',
        en: 'The Matsu Terminal and the programming tools come installed, along with apps to record and edit video.'
      }}
      foto="janela-terminal"
      largura={920}
      altura={580}
      alt={{
        pt: 'O Terminal do Matsu com a tela dividida em duas, a pasta embaixo e as abas em pílula',
        en: 'The Matsu Terminal split in two, with the folder at the bottom and pill-shaped tabs'
      }}
    >
      <Linhas
        itens={[
          {
            titulo: { pt: 'Terminal do Matsu', en: 'Matsu Terminal' },
            texto: {
              pt: 'Abas, tela dividida e, embaixo, a pasta e o ramo do git. Abre com Ctrl + Alt + T.',
              en: 'Tabs, split view and, at the bottom, the folder and the git branch. Opens with Ctrl + Alt + T.'
            },
            icone: 'terminal'
          },
          {
            titulo: { pt: 'VS Code, Python e Node.js', en: 'VS Code, Python and Node.js' },
            texto: {
              pt: 'Com Git, gcc, make e cmake para compilar o que precisar.',
              en: 'With Git, gcc, make and cmake to build whatever you need.'
            },
            marcas: [
              { nome: 'Visual Studio Code', icone: 'icones/vscode.svg' },
              { nome: 'Python', icone: 'icones/python.svg' },
              { nome: 'Node.js', icone: 'icones/nodejs.svg' }
            ]
          },
          {
            titulo: { pt: 'Outro Linux numa caixinha', en: 'Another Linux in a box' },
            texto: {
              pt: 'O Distrobox roda Ubuntu, Debian ou Arch sem mexer no sistema. Para estudar cibersegurança, o comando matsu seguranca abre um Kali Linux pronto.',
              en: 'Distrobox runs Ubuntu, Debian or Arch without touching the system. To study cybersecurity, the matsu security command opens a ready-made Kali Linux.'
            },
            marcas: [
              { nome: 'Kali Linux', icone: 'icones/kali.svg' },
              { nome: 'Ubuntu', icone: 'icones/ubuntu.svg' },
              { nome: 'Arch Linux', icone: 'icones/arch.svg' }
            ]
          },
          {
            titulo: { pt: 'Grave, faça live e edite', en: 'Record, stream and edit' },
            texto: {
              pt: 'OBS Studio para gravar e transmitir, Kdenlive para editar os vídeos.',
              en: 'OBS Studio to record and stream, Kdenlive to edit your videos.'
            },
            marcas: [
              { nome: 'OBS Studio', icone: 'icones/obs.svg' },
              { nome: 'Kdenlive', icone: 'icones/kdenlive.svg' }
            ]
          }
        ]}
      />
    </Divisao>
  );
}
