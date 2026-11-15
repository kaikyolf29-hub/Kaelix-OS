// Tudo o que muda de ano para ano ou de versão para versão fica aqui.
import { chaveValida } from './pix.js';

// A edição do ano (o arquivo EDICAO na raiz do repositório): 27 = edição 2027.
export const EDICAO = 27;
export const NOME = `Matsu ${EDICAO} OS`;

// O endereço do site no GitHub Pages (o mesmo do canonical no index.html).
export const SITE = 'https://kaikyolf29-hub.github.io/Matsu-OS/';

// Onde moram o código e as versões publicadas (o fluxo "Publicar versão
// estável" cria um Release com as duas ISOs: ...-amd.iso e ...-nvidia.iso).
export const REPO = 'kaikyolf29-hub/Matsu-OS';
export const LINKS = {
  codigo: `https://github.com/${REPO}`,
  versoes: `https://github.com/${REPO}/releases`,
  novidades: `https://github.com/${REPO}/blob/main/NOVIDADES.md`,
  licenca: `https://github.com/${REPO}/blob/main/LICENSE`,
  perguntar: `https://github.com/${REPO}/issues`,
  // A lista (e não /latest) responde 200 com [] quando ainda não há versão.
  apiVersoes: `https://api.github.com/repos/${REPO}/releases?per_page=10`
};

// Tamanho aproximado da ISO (instalador de rede): usado enquanto a versão
// publicada não responde.
export const TAMANHO_ISO = { pt: 'cerca de 1,1 GB', en: 'about 1.1 GB' };

// As seções, na ordem da página (o menu de cima usa esta lista).
export const SECOES = [
  { id: 'sistema', nome: { pt: 'Sistema', en: 'System' } },
  { id: 'jogos', nome: { pt: 'Jogos', en: 'Gaming' } },
  { id: 'loja', nome: { pt: 'Loja', en: 'Store' } },
  { id: 'apps', nome: { pt: 'Apps', en: 'Apps' } },
  { id: 'seguranca', nome: { pt: 'Segurança', en: 'Security' } },
  { id: 'instalar', nome: { pt: 'Instalar', en: 'Install' } },
  { id: 'perguntas', nome: { pt: 'Dúvidas', en: 'FAQ' } }
];

// O rodapé lista todas as partes, em duas colunas: o que o sistema tem e o
// que ajuda a começar.
export const RODAPE = {
  sistema: [
    { id: 'sistema', nome: { pt: 'Vindo do Windows', en: 'Coming from Windows' } },
    { id: 'atalhos', nome: { pt: 'Atalhos', en: 'Shortcuts' } },
    { id: 'jogos', nome: { pt: 'Jogos', en: 'Gaming' } },
    { id: 'aparencia', nome: { pt: 'Aparência', en: 'Appearance' } },
    { id: 'loja', nome: { pt: 'Loja', en: 'Store' } },
    { id: 'apps', nome: { pt: 'Apps', en: 'Apps' } },
    { id: 'criar', nome: { pt: 'Programar e criar', en: 'Coding and creating' } },
    { id: 'seguranca', nome: { pt: 'Segurança', en: 'Security' } }
  ],
  comecar: [
    { id: 'instalar', nome: { pt: 'Como instalar', en: 'How to install' } },
    { id: 'baixar', nome: { pt: 'Baixar e requisitos', en: 'Download and requirements' } },
    { id: 'perguntas', nome: { pt: 'Perguntas frequentes', en: 'FAQ' } }
  ]
};

// Apoie o Matsu. A chave Pix é SEMPRE a aleatória (aquela no formato
// 1234abcd-...): nunca CPF, telefone ou e-mail. Sem chave aleatória, o Pix não
// aparece. Com nome e cidade, o site também mostra o QR Code e o "Pix copia e
// cola" (sem valor fixo), feitos no navegador, sem serviço de fora.
// O campo da cidade é obrigatório no código do Pix, mas o app do banco mostra
// o nome da conta dona da chave e não confere a cidade: vai "BRASIL".
// O GitHub Sponsors só liga depois que o GitHub aprovar o perfil: aí é trocar
// "aprovado" para true (e acrescentar "github: kaikydev1-jpg" no
// .github/FUNDING.yml).
export const APOIO = {
  pix: { chave: '0971af38-cbf2-4f0e-9c58-c13b658f0a54', nome: 'Kaiky Oliveira De Freitas', cidade: 'BRASIL' },
  sponsors: { usuario: 'kaikydev1-jpg', aprovado: false }
};
export const TEM_PIX = chaveValida(APOIO.pix.chave);
export const TEM_SPONSORS = APOIO.sponsors.aprovado && Boolean(APOIO.sponsors.usuario);
// A parte Apoiar (e o link no menu) só aparece quando tem um jeito de apoiar.
export const TEM_APOIO = TEM_PIX || TEM_SPONSORS;
export const APOIAR = { id: 'apoiar', nome: { pt: 'Apoiar', en: 'Support' } };

// Os apps da barra, na ordem da barra padrão do sistema (barra/comum.js):
// Arquivos, navegador, Terminal, Steam, Loja, Gerenciador e Ajustes, e a
// Lixeira separada. Cada um leva à parte da página que fala dele.
export const APPS_BARRA = [
  { nome: { pt: 'Arquivos', en: 'Files' }, icone: 'icones/arquivos.svg', ir: '#apps' },
  { nome: { pt: 'Brave', en: 'Brave' }, icone: 'icones/brave.svg', ir: '#loja' },
  { nome: { pt: 'Terminal', en: 'Terminal' }, icone: 'icones/terminal.svg', ir: '#apps' },
  { nome: { pt: 'Steam', en: 'Steam' }, icone: 'icones/steam.svg', ir: '#jogos' },
  { nome: { pt: 'Loja do Matsu', en: 'Matsu Store' }, icone: 'icones/loja.svg', ir: '#loja' },
  { nome: { pt: 'Central de jogos', en: 'Game Center' }, icone: 'icones/jogos.svg', ir: '#jogos' },
  { nome: { pt: 'Gerenciador de tarefas', en: 'Task Manager' }, icone: 'icones/tarefas.svg', ir: '#apps' },
  { nome: { pt: 'Ajustes do Matsu', en: 'Matsu Settings' }, icone: 'icones/ajustes.svg', ir: '#sistema' }
];
