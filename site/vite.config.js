import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// O site é estático: o build gera dist/ com o HTML já desenhado (scripts/prerender.mjs).
// base './' deixa o site funcionar em qualquer pasta (GitHub Pages em /Matsu-OS/, Vercel na raiz).
export default defineConfig({
  base: './',
  plugins: [react()],
  build: { assetsInlineLimit: 0 }
});
