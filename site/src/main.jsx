import { hydrateRoot, createRoot } from 'react-dom/client';
import App from './App.jsx';

const raiz = document.getElementById('app');
// No build a página já vem desenhada (prerender); no "npm run dev" ela começa vazia.
if (raiz.hasChildNodes()) hydrateRoot(raiz, <App />);
else createRoot(raiz).render(<App />);
