import Icone from './Icone.jsx';

// Uma parte com o texto à esquerda e a janela de verdade do app à direita.
function Divisao({ id, titulo, sub, children, foto, alt, largura, altura }) {
  return (
    <section className="secao" id={id} aria-labelledby={`${id}-titulo`}>
      <div className="wrap divisao divisao--5-7">
        <div className="divisao__texto">
          <h2 id={`${id}-titulo`}>{titulo}</h2>
          <p className="sub">{sub}</p>
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
            alt={alt}
            loading="lazy"
          />
        </figure>
      </div>
    </section>
  );
}

function Linhas({ itens }) {
  return (
    <ul className="linhas">
      {itens.map(it => (
        <li key={it.titulo}>
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
            <b>{it.titulo}</b>
            <span>{it.texto}</span>
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
      titulo="Pronto para jogar no primeiro boot"
      sub="A Central de jogos junta seus jogos da Steam, com a capa e as horas jogadas, e dá um perfil gráfico para cada um."
      foto="janela-jogos"
      largura={1149}
      altura={717}
      alt="A Central de jogos do Matsu, com o modo jogo, a sobreposição de FPS e a placa de vídeo"
    >
      <Linhas
        itens={[
          {
            titulo: 'Steam, Heroic e Lutris instalados',
            texto: 'A Epic e a GOG entram pelo Heroic.',
            marcas: [
              { nome: 'Steam', icone: 'icones/steam.svg' },
              { nome: 'Heroic', icone: 'icones/heroic.svg' },
              { nome: 'Lutris', icone: 'icones/lutris.svg' }
            ]
          },
          { titulo: 'FPS na tela com um atalho', texto: 'Win + Alt + F mostra FPS, processador e placa.', icone: 'sobreposicao' },
          { titulo: 'O driver certo já vem', texto: 'AMD e Intel numa ISO, NVIDIA na outra.', icone: 'placa' },
          { titulo: 'Controles de PS4, PS5 e Xbox', texto: 'Ligue pelo Bluetooth e jogue.', icone: 'controle' }
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
  return (
    <Divisao
      id="loja"
      titulo="Todos os apps numa loja só"
      sub="A Loja do Matsu tem milhares de apps com fotos e descrição. Instagram, TikTok e YouTube viram app, com a logo deles."
      foto="janela-loja"
      largura={1185}
      altura={753}
      alt="A Loja do Matsu com o OBS Studio em destaque e Brave, Chrome, Discord e Spotify nos essenciais"
    >
      <ul className="vitrine" aria-label="Alguns apps da Loja">
        {MARCAS_LOJA.map(m => (
          <li key={m.nome}>
            <img src={m.icone} alt="" width="32" height="32" loading="lazy" />
            <span>{m.nome}</span>
          </li>
        ))}
      </ul>
      <p className="nota">Os apps pagos usam um código de resgate, que você compra fora e digita na Loja.</p>
    </Divisao>
  );
}

export function Seguranca() {
  return (
    <Divisao
      id="seguranca"
      titulo="Segurança e atualizações do Matsu"
      sub="Mostra num lugar só o escudo, a rede e o que cada app pode usar. O sistema se atualiza sozinho."
      foto="janela-seguranca"
      largura={1113}
      altura={717}
      alt="A Central de segurança do Matsu dizendo que o computador está protegido"
    >
      <Linhas
        itens={[
          {
            titulo: 'Atualiza inteiro e volta se der errado',
            texto: 'A versão nova entra quando você reinicia. Se algo falhar, escolha a anterior no boot.',
            icone: 'sincronia'
          },
          { titulo: 'Cada versão é assinada', texto: 'E testada numa máquina virtual antes de sair.', icone: 'verificado' },
          { titulo: 'Apps na caixinha deles', texto: 'Os apps da Loja rodam isolados e um não estraga o outro.', icone: 'cadeado' }
        ]}
      />
    </Divisao>
  );
}
