// Desenha a página no build: o HTML sai pronto (lê sem JavaScript, abre mais rápido
// e o Google e as prévias de link enxergam o texto). O React só "acorda" por cima.
// Sai em dois idiomas: dist/index.html (português) e dist/en.html (inglês), na
// mesma pasta, para as fotos e os arquivos servirem aos dois.
import { readFile, writeFile, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const raiz = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const modelo = await readFile(path.join(raiz, 'dist/index.html'), 'utf8');
const { render, SITE, CHAVE_PIX_OK } = await import(path.join(raiz, 'dist-ssr/entry-server.js'));

// O esqueleto do en.html: cada texto do index.html e o que entra no lugar.
const SITE_EN = `${SITE}en.html`;
const CABECA_EN = [
  ['<html lang="pt-BR"', '<html lang="en"'],
  [
    /<title>[^<]*<\/title>/,
    '<title>Matsu 27 OS: a free operating system for your PC</title>'
  ],
  [
    /<meta name="description" content="[^"]*">/,
    '<meta name="description" content="Download Matsu 27 OS, a computer system that looks great from the first boot and is ready for gaming.">'
  ],
  [
    /<meta property="og:description" content="[^"]*">/,
    '<meta property="og:description" content="A free system for your PC: ready for gaming, with an app store, in English or Portuguese.">'
  ],
  [`<meta property="og:url" content="${SITE}">`, `<meta property="og:url" content="${SITE_EN}">`],
  ['<meta property="og:locale" content="pt_BR">', '<meta property="og:locale" content="en_US">'],
  [`<link rel="canonical" href="${SITE}">`, `<link rel="canonical" href="${SITE_EN}">`],
  // A barra de baixo do celular também está no esqueleto.
  ['aria-label="Baixar"', 'aria-label="Download"']
];

function cabecaEn(html) {
  for (const [de, para] of CABECA_EN) {
    const antes = html;
    html = html.replace(de, para);
    if (html === antes) throw new Error(`index.html sem o trecho do cabeçalho: ${de}`);
  }
  return html;
}

function desenhar(idioma) {
  let html = idioma === 'en' ? cabecaEn(modelo) : modelo;
  for (const [id, parte] of Object.entries(render(idioma))) {
    const marca = `<!--${id}-->`;
    if (!html.includes(marca)) throw new Error(`index.html sem o marcador ${marca}`);
    html = html.replace(marca, parte);
  }
  return html;
}

if (!CHAVE_PIX_OK) throw new Error('A chave Pix em src/dados.js tem que ser a aleatória (nunca CPF, telefone ou e-mail).');
await writeFile(path.join(raiz, 'dist/index.html'), desenhar('pt'));
await writeFile(path.join(raiz, 'dist/en.html'), desenhar('en'));
await rm(path.join(raiz, 'dist-ssr'), { recursive: true, force: true });
console.log('página desenhada em dist/index.html e dist/en.html');
