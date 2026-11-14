// Tudo o que muda de ano para ano ou de versão para versão fica aqui.

// A edição do ano (o arquivo EDICAO na raiz do repositório): 27 = edição 2027.
export const EDICAO = 27;
export const NOME = `Matsu ${EDICAO} OS`;

// Onde moram o código e as versões publicadas (o fluxo "Publicar versão
// estável" cria um Release com as duas ISOs: ...-amd.iso e ...-nvidia.iso).
export const REPO = 'kaikyolf29-hub/kaelix-os';
export const LINKS = {
  codigo: `https://github.com/${REPO}`,
  versoes: `https://github.com/${REPO}/releases`,
  novidades: `https://github.com/${REPO}/blob/main/NOVIDADES.md`,
  licenca: `https://github.com/${REPO}/blob/main/LICENSE`,
  // A lista (e não /latest) responde 200 com [] quando ainda não há versão.
  apiVersoes: `https://api.github.com/repos/${REPO}/releases?per_page=10`
};

// Tamanho aproximado da ISO (instalador de rede): usado enquanto a versão
// publicada não responde.
export const TAMANHO_ISO = 'cerca de 1,1 GB';

// As seções, na ordem da página (o menu de cima usa esta lista).
export const SECOES = [
  { id: 'sistema', nome: 'Sistema' },
  { id: 'jogos', nome: 'Jogos' },
  { id: 'loja', nome: 'Loja' },
  { id: 'apps', nome: 'Apps' },
  { id: 'seguranca', nome: 'Segurança' },
  { id: 'instalar', nome: 'Instalar' }
];

// Os apps da barra, na ordem da barra padrão do sistema (barra/comum.js):
// Arquivos, navegador, Terminal, Steam, Loja, Gerenciador e Ajustes, e a
// Lixeira separada. Cada um leva à parte da página que fala dele.
export const APPS_BARRA = [
  { nome: 'Arquivos', icone: 'icones/arquivos.svg', ir: '#apps' },
  { nome: 'Brave', icone: 'icones/brave.svg', ir: '#loja' },
  { nome: 'Terminal', icone: 'icones/terminal.svg', ir: '#apps' },
  { nome: 'Steam', icone: 'icones/steam.svg', ir: '#jogos' },
  { nome: 'Loja do Matsu', icone: 'icones/loja.svg', ir: '#loja' },
  { nome: 'Central de jogos', icone: 'icones/jogos.svg', ir: '#jogos' },
  { nome: 'Gerenciador de tarefas', icone: 'icones/tarefas.svg', ir: '#apps' },
  { nome: 'Ajustes do Matsu', icone: 'icones/configuracoes.svg', ir: '#sistema' }
];
