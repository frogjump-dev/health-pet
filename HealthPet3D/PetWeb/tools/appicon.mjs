// Renders the Ovenpals app icon (logo-v1 「A 打卡贴纸」, picked 2026-11-13) in its three iOS
// appearances: the in-app Toast, drawn by the same 3D slice engine as the live pet, peeks in from
// the bottom-right corner, tilted, with a white sticker outline and a soft shadow; a white tag in
// the top-left carries a check mark and this week's dots (the app records check-ins).
//
// Usage (here, after `npm install`): node tools/appicon.mjs [out dir]
//   default out dir = ../Resources/Assets.xcassets/AppIcon.appiconset
//   writes AppIcon.png (light), AppIcon-Dark.png, AppIcon-Tinted.png — 1024 × 1024, no alpha.
// Needs Playwright (preinstalled in the cloud container; elsewhere `npm i -g playwright`).
import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = resolve(process.argv[2] || join(here, '..', 'Resources', 'Assets.xcassets', 'AppIcon.appiconset'));
const src = (f) => readFileSync(join(here, 'src', f), 'utf8');

// ---- the pet page: the same sources as build.mjs, without the app bridge ----
const lib = (f) => `./node_modules/open-bot-avatar/dist/${f}`;
const imports = [
  `import { validateAvatar, pointerGaze, BASE_YAW, BASE_PITCH, renderAvatarScene, sceneFrame } from '${lib('index.js')}';`,
  `import { analyzeBody } from '${lib('validate.js')}';`,
  `import { bounds, insideRow, isInside } from '${lib('path.js')}';`,
  `import { erosionAt, faceRoom, insideDistance, buildVolume } from '${lib('volume.js')}';`,
  `import { contourLoops, loopsToPath } from '${lib('contour.js')}';`,
  `import { silhouetteSeams } from '${lib('seams.js')}';`,
  `import { preparedVolume, DEFAULT_DEPTH } from '${lib('render.js')}';`,
].join('\n');
const pose = `
const PETS = Object.fromEntries(FAMILIES.flatMap((f) => f.pets).map((p) => [p.def.id, p]));
window.drawPet = (id, st) => {
  const pet = mountPet(document.getElementById('stage'), PETS[id], { shadow: false, rug: false });
  pet.frame(Object.assign(base(), st));
};`;
const entry = [imports, src('helpers.js'), src('engine.js'), src('live.js'), pose].join('\n;\n');
const bundle = await build({
  stdin: { contents: entry, resolveDir: here, sourcefile: 'appicon-entry.js', loader: 'js' },
  bundle: true, format: 'iife', minify: true, target: ['chrome120'], write: false, legalComments: 'none',
});
const petPage = src('page.html')
  .replace('/*BUNDLE*/', () => bundle.outputFiles[0].text.replace(/<\/script/gi, '<\\/script'))
  .replace('#stage { position: absolute;', '#stage { position: absolute; left: 0; top: 0; width: 100vw; height: 100vh;');

// ---- the icon ----
// Toast turned a little (its crust shows its thickness) and looking up at the tag.
const TOAST = { yaw: -18, pitch: 5, gx: -1, gy: -1 };
const PET_PX = 1200; // the pet's 100 × 100 box, rendered at this size
const LAYOUT = { cx: 690, cy: 782, size: 990, angle: -12, outline: 24 }; // where the box sits on the 1024 icon
const TAG = { x: 64, y: 116, w: 446, h: 158, r: 50, angle: -11 };
const THEMES = {
  light: { bg: ['#5A7B50', '#3E5A38'], outline: '#FFFFFF', shadow: 'rgba(24,34,22,.38)', tag: '#FFFFFF', tagShadow: 'rgba(24,34,22,.30)', check: '#B3AC3C', on: '#4B6844', off: '#DAD7CF' },
  dark: { bg: ['#25301F', '#0E120D'], outline: '#EBE9E3', shadow: 'rgba(0,0,0,.55)', tag: '#38432F', tagShadow: 'rgba(0,0,0,.45)', check: '#D9D387', on: '#8FAE85', off: '#56614F' },
};

const browser = await chromium.launch();
const petTab = await browser.newPage({ viewport: { width: PET_PX, height: PET_PX }, deviceScaleFactor: 1 });
const errors = [];
petTab.on('pageerror', (e) => errors.push(String(e)));
await petTab.setContent(petPage);
await petTab.evaluate((st) => window.drawPet('toast', st), TOAST);
await petTab.waitForTimeout(900); // smooth slices are swapped in when idle
await petTab.evaluate((st) => window.drawPet('toast', st), TOAST);
await petTab.waitForTimeout(300);
const toastPng = (await petTab.screenshot({ omitBackground: true })).toString('base64');
if (errors.length) throw new Error(errors.join('\n'));

const tab = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
const out = await tab.evaluate(async ({ toastPng, PET_PX, LAYOUT, TAG, THEMES }) => {
  const img = new Image();
  img.src = `data:image/png;base64,${toastPng}`;
  await img.decode();
  const canvas = (w, h) => Object.assign(document.createElement('canvas'), { width: w, height: h });
  // the white sticker: the pet's silhouette, grown by `outline` px all round
  const k = LAYOUT.size / PET_PX;
  const pad = Math.ceil(LAYOUT.outline / k) + 4;
  function sticker(color) {
    const sil = canvas(PET_PX, PET_PX), s = sil.getContext('2d');
    s.drawImage(img, 0, 0);
    s.globalCompositeOperation = 'source-in';
    s.fillStyle = color; s.fillRect(0, 0, PET_PX, PET_PX);
    const big = canvas(PET_PX + 2 * pad, PET_PX + 2 * pad), b = big.getContext('2d');
    const r = LAYOUT.outline / k;
    for (const f of [1, 0.66, 0.33]) for (let a = 0; a < 360; a += 4) {
      b.drawImage(sil, pad + f * r * Math.cos((a * Math.PI) / 180), pad + f * r * Math.sin((a * Math.PI) / 180));
    }
    return big;
  }
  function draw(t) {
    const c = canvas(1024, 1024), g = c.getContext('2d');
    g.imageSmoothingQuality = 'high';
    const bg = g.createLinearGradient(0, 0, 1024, 1024);
    bg.addColorStop(0, t.bg[0]); bg.addColorStop(1, t.bg[1]);
    g.fillStyle = bg; g.fillRect(0, 0, 1024, 1024);
    // tag: ✓ + this week's dots (3 done, 2 to go)
    g.save();
    g.translate(TAG.x + TAG.w / 2, TAG.y + TAG.h / 2); g.rotate((TAG.angle * Math.PI) / 180);
    g.shadowColor = t.tagShadow; g.shadowBlur = 34; g.shadowOffsetY = 12;
    g.fillStyle = t.tag; g.beginPath(); g.roundRect(-TAG.w / 2, -TAG.h / 2, TAG.w, TAG.h, TAG.r); g.fill();
    g.shadowColor = 'transparent';
    g.strokeStyle = t.check; g.lineWidth = 30; g.lineCap = 'round'; g.lineJoin = 'round';
    g.beginPath(); g.moveTo(-TAG.w / 2 + 54, 4); g.lineTo(-TAG.w / 2 + 88, 38); g.lineTo(-TAG.w / 2 + 148, -36); g.stroke();
    ['on', 'on', 'on', 'off', 'off'].forEach((d, i) => {
      g.fillStyle = t[d]; g.beginPath(); g.arc(-TAG.w / 2 + 214 + i * 50, 2, 19, 0, 2 * Math.PI); g.fill();
    });
    g.restore();
    // Toast on its sticker
    g.save();
    g.translate(LAYOUT.cx, LAYOUT.cy); g.rotate((LAYOUT.angle * Math.PI) / 180); g.scale(k, k);
    g.shadowColor = t.shadow; g.shadowBlur = 40 / k; g.shadowOffsetY = 16 / k;
    g.drawImage(sticker(t.outline), -PET_PX / 2 - pad, -PET_PX / 2 - pad);
    g.shadowColor = 'transparent';
    g.drawImage(img, -PET_PX / 2, -PET_PX / 2);
    g.restore();
    return c;
  }
  const light = draw(THEMES.light), dark = draw(THEMES.dark);
  // tinted: iOS tints a grayscale picture; brighter = more of the tint colour. The dark design in grey.
  const tinted = canvas(1024, 1024), tg = tinted.getContext('2d');
  tg.drawImage(dark, 0, 0);
  const px = tg.getImageData(0, 0, 1024, 1024);
  for (let i = 0; i < px.data.length; i += 4) {
    const y = 0.2126 * px.data[i] + 0.7152 * px.data[i + 1] + 0.0722 * px.data[i + 2];
    px.data[i] = px.data[i + 1] = px.data[i + 2] = y;
  }
  tg.putImageData(px, 0, 0);
  return [light, dark, tinted].map((c) => c.toDataURL('image/png').split(',')[1]);
}, { toastPng, PET_PX, LAYOUT, TAG, THEMES });
await browser.close();

// App Store icons must be opaque: re-encode without the alpha channel.
mkdirSync(outDir, { recursive: true });
const names = ['AppIcon.png', 'AppIcon-Dark.png', 'AppIcon-Tinted.png'];
const flat = await chromium.launch();
const p = await flat.newPage({ viewport: { width: 1024, height: 1024 } });
for (let i = 0; i < 3; i++) {
  await p.setContent(`<html><body style="margin:0"><img src="data:image/png;base64,${out[i]}" style="display:block"></body></html>`);
  await p.waitForTimeout(50);
  writeFileSync(join(outDir, names[i]), await p.screenshot({ type: 'png', omitBackground: false }));
}
await flat.close();
console.log('wrote', names.map((n) => join(outDir, n)).join('\n      '));
