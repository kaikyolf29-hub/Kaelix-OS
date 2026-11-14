import { hydrateRoot, createRoot } from 'react-dom/client';
import { RAIZES } from './App.jsx';

// No build cada parte já vem desenhada (prerender); no "npm run dev" começa vazia.
for (const [id, Parte] of Object.entries(RAIZES)) {
  const el = document.getElementById(id);
  if (!el) continue;
  if (el.firstElementChild) hydrateRoot(el, <Parte />);
  else createRoot(el).render(<Parte />);
}
