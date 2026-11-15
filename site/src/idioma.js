import { createContext, useContext } from 'react';

// O site sai em dois arquivos: index.html (português, o padrão) e en.html
// (inglês). Cada raiz do React recebe o idioma da página por este contexto.
export const Idioma = createContext('pt');

export const LOCALE = { pt: 'pt-BR', en: 'en-US' };

// Para onde o botão de idioma leva (os dois arquivos ficam na mesma pasta).
export const PAGINA = { pt: './', en: 'en.html' };

export function useIdioma() {
  return useContext(Idioma);
}

// t('Baixar', 'Download') ou t({ pt: 'Baixar', en: 'Download' }).
export function useT() {
  const idioma = useIdioma();
  return (pt, en) => {
    if (pt && typeof pt === 'object') return pt[idioma] ?? pt.pt;
    return idioma === 'en' ? en : pt;
  };
}
