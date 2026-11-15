import { renderToString } from 'react-dom/server';
import { RAIZES } from './App.jsx';
import { Idioma } from './idioma.js';
import { APOIO } from './dados.js';
import { chaveValida } from './pix.js';

export { SITE } from './dados.js';

// O prerender confere a chave Pix antes de escrever a página: vazia (sem Pix)
// ou a aleatória. CPF, telefone ou e-mail param o build.
export const CHAVE_PIX_OK = !APOIO.pix.chave || chaveValida(APOIO.pix.chave);

// Cada raiz vira o HTML que vai dentro do seu elemento no index.html, no idioma
// pedido ('pt' para o index.html, 'en' para o en.html).
export function render(idioma = 'pt') {
  return Object.fromEntries(
    Object.entries(RAIZES).map(([id, Parte]) => [
      id,
      renderToString(
        <Idioma.Provider value={idioma}>
          <Parte />
        </Idioma.Provider>
      )
    ])
  );
}
