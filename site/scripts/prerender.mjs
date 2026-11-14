// Desenha a página no build: o HTML sai pronto (lê sem JavaScript, abre mais rápido
// e o Google e as prévias de link enxergam o texto). O React só "acorda" por cima.
import { readFile, writeFile, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const raiz = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const modelo = await readFile(path.join(raiz, 'dist/index.html'), 'utf8');
const { render } = await import(path.join(raiz, 'dist-ssr/entry-server.js'));
let html = modelo;
for (const [id, parte] of Object.entries(render())) {
  const marca = `<!--${id}-->`;
  if (!html.includes(marca)) throw new Error(`index.html sem o marcador ${marca}`);
  html = html.replace(marca, parte);
}
await writeFile(path.join(raiz, 'dist/index.html'), html);
await rm(path.join(raiz, 'dist-ssr'), { recursive: true, force: true });
console.log('página desenhada em dist/index.html');
