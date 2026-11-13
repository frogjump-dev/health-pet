// Renders the static pet pictures the app uses (grids, share cards).
// Usage: node tools/stills.cjs <pet.html> <out dir> [kinds, default neutral,happy,proud]
// (The app icon has its own tool since 2026-11-13: tools/appicon.mjs.)
// (copy to .cjs first: this package is an ES module). proud = 骄傲挺胸 for share cards.
const { chromium } = require('playwright');
const [page, out, kindArg] = process.argv.slice(2);
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
  console.log('errors', JSON.stringify(errs));
  await b.close();
})();
