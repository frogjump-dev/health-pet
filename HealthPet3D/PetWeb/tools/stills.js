// Renders the static pet pictures the app uses (grids, share cards) and the app icon.
// Usage: node tools/stills.cjs <pet.html> <out dir> [kinds, default neutral,happy,proud] [icon]
// (copy to .cjs first: this package is an ES module). proud = 骄傲挺胸 for share cards.
const { chromium } = require('playwright');
const [page, out, kindArg, iconArg] = process.argv.slice(2);
const KINDS = (kindArg || 'neutral,happy,proud').split(',');
const IDS = ['toast','onigiri','mantou','baguette','waffle','coffee','matcha','bubbletea','darkchoco','pudding','marshmallow','strawberrycake','mochi','avocado','lemon','chili','pineapple','honey','warmmilk','proteinbar'];
(async () => {
  const b = await chromium.launch();
  const errs = [];
  for (const id of IDS) for (const still of KINDS) {
    const p = await b.newPage({ viewport: { width: 600, height: 600 }, deviceScaleFactor: 1 });
    p.on('pageerror', (e) => errs.push(id + ' ' + e));
    await p.addInitScript((init) => { window.PET_INIT = init; }, { pet: id, still, shadow: false, box: { x: 0, y: 0, size: 1 } });
    await p.goto('file://' + page);
    await p.waitForTimeout(900); // smooth slices are swapped in when idle
    await p.screenshot({ path: `${out}/pet3d_${id}${still === 'neutral' ? '' : '_' + still}.png`, omitBackground: true });
    await p.close();
  }
  if (iconArg === 'no-icon') { console.log('errors', JSON.stringify(errs)); await b.close(); return; }
  // app icon: Toast, happy, on the home disc, Mountain Jade canvas
  const p = await b.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  await p.addInitScript(() => { window.PET_INIT = { pet: 'toast', still: 'happy', rug: true, box: { x: 0.13, y: 0.1, size: 0.74 } }; });
  await p.goto('file://' + page);
  await p.addStyleTag({ content: 'html,body{background:#EBE9E3 !important}' });
  await p.waitForTimeout(1200);
  await p.screenshot({ path: `${out}/AppIcon.png` });
  console.log('errors', JSON.stringify(errs));
  await b.close();
})();
