import Icone from './Icone.jsx';
import { LINKS, TAMANHO_ISO } from '../dados.js';
import { useT } from '../idioma.js';

// As dúvidas de quem vai instalar. Cada resposta foi conferida no sistema: o
// "lado a lado" e os 40 GB vêm do instalador (motor.py e instalador.py), o
// antitrapaça do README e as atualizações da Central de segurança.
// Cada pergunta é um <details>: abre e fecha sem script, e o nome igual faz
// uma fechar quando outra abre.
const PERGUNTAS = [
  {
    id: 'gratis',
    p: { pt: 'O Matsu é de graça mesmo?', en: 'Is Matsu really free?' },
    r: {
      pt: 'É. O sistema é livre (licença GPL 3.0), sem cadastro, sem propaganda e sem plano pago. Na Loja, alguns apps são pagos e liberados com um código de resgate, e só compra quem quiser.',
      en: 'Yes. The system is free and open (GPL 3.0 license), with no sign-up, no ads and no paid plan. In the Store, a few apps are paid and unlocked with a redeem code, and only those who want them buy them.'
    }
  },
  {
    id: 'windows',
    p: { pt: 'Dá para manter o Windows junto?', en: 'Can I keep Windows alongside it?' },
    r: {
      pt: 'Dá. No instalador, escolha Instalar ao lado do que já existe: precisa de 40 GB livres no disco. Quando o computador liga, você escolhe qual sistema usar. Para liberar espaço, use Diminuir volume no Gerenciamento de disco do Windows, e antes faça uma cópia dos arquivos que importam.',
      en: 'Yes. In the installer, choose to install next to what’s already there: it needs 40 GB free on the disk. When the computer starts, you pick which system to use. To free up space, use Shrink Volume in Windows Disk Management, and back up the files that matter first.'
    }
  },
  {
    id: 'jogos',
    p: { pt: 'Meus jogos da Steam rodam?', en: 'Will my Steam games run?' },
    r: {
      pt: 'A maioria roda, pelo Proton, que vem com a própria Steam. Jogos com antitrapaça que não libera o Linux, como Fortnite e Valorant, não abrem em nenhum Linux. Antes de comprar, procure o jogo no ProtonDB.',
      en: 'Most do, through Proton, which comes with Steam itself. Games with anti-cheat that doesn’t allow Linux, like Fortnite and Valorant, don’t run on any Linux. Before buying, look the game up on ProtonDB.'
    },
    link: { url: 'https://www.protondb.com', nome: { pt: 'Abrir o ProtonDB', en: 'Open ProtonDB' } }
  },
  {
    id: 'programas',
    p: { pt: 'Os programas do Windows funcionam?', en: 'Do Windows programs work?' },
    r: {
      pt: 'Os arquivos .exe não abrem direto. Para quase tudo tem a versão de Linux na Loja do Matsu: Chrome, Discord, Spotify, OBS, VS Code e milhares de outros. Os jogos do Windows rodam pela Steam, pelo Heroic e pelo Lutris.',
      en: '.exe files don’t open directly. For almost everything there’s a Linux version in the Matsu Store: Chrome, Discord, Spotify, OBS, VS Code and thousands more. Windows games run through Steam, Heroic and Lutris.'
    }
  },
  {
    id: 'iso',
    p: { pt: 'Qual ISO eu baixo?', en: 'Which ISO should I download?' },
    r: {
      pt: 'Com placa NVIDIA (GeForce), a ISO NVIDIA, que já traz o driver. Com AMD (Radeon), Intel ou só o vídeo do processador, a ISO AMD ou Intel. Notebook com Intel e NVIDIA juntas usa a ISO NVIDIA.',
      en: 'With an NVIDIA (GeForce) card, the NVIDIA ISO, which already has the driver. With AMD (Radeon), Intel or just the processor’s graphics, the AMD or Intel ISO. A laptop with both Intel and NVIDIA uses the NVIDIA ISO.'
    }
  },
  {
    id: 'internet',
    p: { pt: 'Preciso de internet para instalar?', en: 'Do I need internet to install?' },
    r: {
      pt: `Precisa, por cabo ou Wi-Fi. A ISO é pequena (${TAMANHO_ISO.pt}) porque o instalador baixa o sistema na hora, e ele já entra na versão mais nova.`,
      en: `Yes, wired or Wi-Fi. The ISO is small (${TAMANHO_ISO.en}) because the installer downloads the system on the spot, so you start on the newest version.`
    }
  },
  {
    id: 'atualizar',
    p: { pt: 'Como o Matsu se atualiza?', en: 'How does Matsu update?' },
    r: {
      pt: 'Sozinho. As correções baixam em segundo plano e entram quando você reinicia. Se algo der errado, escolha a versão anterior no menu de boot. Uma vez por ano sai a edição nova: depois do 27 vem o 28.',
      en: 'On its own. Fixes download in the background and take effect when you restart. If something goes wrong, pick the previous version in the boot menu. Once a year a new edition comes out: after 27 comes 28.'
    }
  },
  {
    id: 'notebook',
    p: { pt: 'Funciona em notebook?', en: 'Does it work on laptops?' },
    r: {
      pt: 'Na maioria, sim. O Matsu é feito em cima do Fedora, que reconhece Wi-Fi, Bluetooth, som e bateria da maior parte dos notebooks. Os perfis de energia ficam na central de controle (Win + A).',
      en: 'On most, yes. Matsu is built on Fedora, which supports the Wi-Fi, Bluetooth, sound and battery of most laptops. Power profiles are in the control center (Win + A).'
    }
  },
  {
    id: 'quem',
    p: { pt: 'Quem faz o Matsu?', en: 'Who makes Matsu?' },
    r: {
      pt: 'É um projeto independente, feito no Brasil. Por baixo ele usa o Fedora e o KDE Plasma, e todo o código fica aberto no GitHub.',
      en: 'It’s an independent project, made in Brazil. Under the hood it uses Fedora and KDE Plasma, and all the code is open on GitHub.'
    },
    link: { url: LINKS.codigo, nome: { pt: 'Ver o código no GitHub', en: 'See the code on GitHub' } }
  }
];

export default function Perguntas() {
  const t = useT();
  return (
    <section className="secao" id="perguntas" aria-labelledby="perguntas-titulo">
      <div className="wrap divisao divisao--4-8">
        <div className="divisao__texto">
          <h2 id="perguntas-titulo">{t('Perguntas frequentes', 'Frequently asked questions')}</h2>
          <p className="sub">{t('O que mais perguntam antes de instalar.', 'What people ask most before installing.')}</p>
          <p className="nota">
            {t('Ficou outra dúvida?', 'Have another question?')}{' '}
            <a className="link" href={LINKS.perguntar}>
              {t('Pergunte no GitHub', 'Ask on GitHub')}
            </a>
          </p>
        </div>
        <div className="perguntas">
          {PERGUNTAS.map(q => (
            <details key={q.id} className="pergunta" name="perguntas" id={`pergunta-${q.id}`} open={q.id === PERGUNTAS[0].id}>
              <summary>
                <span>{t(q.p)}</span>
                <Icone nome="chevron" tamanho={20} className="pergunta__seta" />
              </summary>
              <div className="pergunta__resposta">
                <p>
                  {t(q.r)}
                  {q.link && (
                    <>
                      {' '}
                      <a className="link" href={q.link.url}>
                        {t(q.link.nome)}
                      </a>
                    </>
                  )}
                </p>
              </div>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
