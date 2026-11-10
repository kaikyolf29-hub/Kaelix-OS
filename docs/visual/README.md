# Demonstração do visual (fusão)

Animação feita fora do sistema para o criador ver e aprovar o visual antes de ele entrar no Kaelix.

- `demo.html` e `demo.js`: a demonstração. Abra `demo.html` num navegador e ela toca sozinha, em repetição.
- `capture.js`: grava a demonstração quadro a quadro (Playwright) para montar o vídeo com o ffmpeg.

```
node capture.js
ffmpeg -framerate 30 -i frames/f%05d.jpg -c:v libx264 -crf 19 -pix_fmt yuv420p -movflags +faststart kaelix-visual-fusao.mp4
```

O "K" é só um marcador. O logo de verdade ainda vai ser escolhido.
