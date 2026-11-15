import { hydrateRoot, createRoot } from 'react-dom/client';
import { RAIZES } from './App.jsx';
import { Idioma } from './idioma.js';

// O idioma vem do <html lang>: "en" no en.html, "pt-BR" no index.html.
const idioma = document.documentElement.lang.startsWith('en') ? 'en' : 'pt';

// No build cada parte já vem desenhada (prerender); no "npm run dev" começa vazia.
for (const [id, Parte] of Object.entries(RAIZES)) {
  const el = document.getElementById(id);
  if (!el) continue;
  const arvore = (
    <Idioma.Provider value={idioma}>
      <Parte />
    </Idioma.Provider>
  );
  if (el.firstElementChild) hydrateRoot(el, arvore);
  else createRoot(el).render(arvore);
}
