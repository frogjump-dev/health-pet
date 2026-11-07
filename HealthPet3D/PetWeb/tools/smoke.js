const { chromium } = require('playwright');
const path = process.argv[2], out = process.argv[3];
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 400, height: 400 }, deviceScaleFactor: 1 });
  const errs = [];
  p.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
  p.on('pageerror', (e) => errs.push(String(e)));
  await p.addInitScript(() => {
    window.PET_INIT = { pet: 'toast', rug: true, dark: false };
    window.__msgs = [];
    window.webkit = { messageHandlers: { pet: { postMessage: (m) => window.__msgs.push(m) } } };
  });
  await p.goto('file://' + path);
  await p.waitForTimeout(1500);
  await p.screenshot({ path: out + '/a-toast-light.png' });
  console.log('msgs', JSON.stringify(await p.evaluate(() => window.__msgs)));
  // tap the pet a few times
  await p.mouse.click(200, 220); await p.waitForTimeout(700);
  await p.screenshot({ path: out + '/b-tap.png' });
  await p.evaluate(() => Pet.celebrate('cheer')); await p.waitForTimeout(1100);
  await p.screenshot({ path: out + '/c-cheer.png' });
  await p.evaluate(() => Pet.configure({ dark: true, pet: 'chili' })); await p.waitForTimeout(800);
  await p.screenshot({ path: out + '/d-chili-dark.png' });
  await p.evaluate(() => Pet.morning()); await p.waitForTimeout(2600);
  await p.screenshot({ path: out + '/e-morning.png' });
  console.log('status', JSON.stringify(await p.evaluate(() => Pet.status())));
  // fps
  const fps = await p.evaluate(() => new Promise((r) => { let n = 0; const t0 = performance.now(); const f = () => { n++; if (performance.now() - t0 < 2000) requestAnimationFrame(f); else r(n / 2); }; requestAnimationFrame(f); }));
  console.log('fps', fps, 'errors', JSON.stringify(errs));
  await b.close();
})();
