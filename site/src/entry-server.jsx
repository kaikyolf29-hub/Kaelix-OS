import { renderToString } from 'react-dom/server';
import { RAIZES } from './App.jsx';

// Cada raiz vira o HTML que vai dentro do seu elemento no index.html.
export function render() {
  return Object.fromEntries(Object.entries(RAIZES).map(([id, Parte]) => [id, renderToString(<Parte />)]));
}
