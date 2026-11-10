const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const FPS = 30, out = __dirname + '/frames';
  fs.rmSync(out, { recursive: true, force: true }); fs.mkdirSync(out);
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 4 / 3 });
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.goto('file://' + __dirname + '/demo.html?capture');
  await p.waitForFunction('window.READY === true');
  const dur = await p.evaluate('window.DUR'), n = Math.round(dur * FPS);
  const t0 = Date.now();
  for (let i = 0; i < n; i++) {
    await p.evaluate(t => window.seek(t), i / FPS);
    await p.screenshot({ path: `${out}/f${String(i).padStart(5, '0')}.jpg`, type: 'jpeg', quality: 93 });
    if (i % 150 === 0) console.log(i, n, ((Date.now() - t0) / 1000).toFixed(0) + 's');
  }
  await b.close(); console.log('done', n);
})();
