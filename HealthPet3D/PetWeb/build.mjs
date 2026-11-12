// Builds ../Resources/PetWeb/pet.html, one self-contained page (no network) that the app loads
// into a WKWebView. Run `npm install && npm run build` here after changing anything in src/.
//
// src/helpers.js, engine.js and live.js are copied unchanged from the 3D方案 expression preview
// (project files 健康宠物/3D方案/expressions-v2/src, helpers = the pet-svg3d block of the built
// preview page). src/decor.js (the wearable decorations, PRD §5.4) is copied unchanged from
// 健康宠物/3D方案/decor-v1/workbench/src. They are scripts that expect open-bot-avatar's functions in scope, so they are
// joined after the library imports into one module, then bundled as a classic script.
import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const src = (f) => readFileSync(join(here, 'src', f), 'utf8');
const lib = (f) => `./node_modules/open-bot-avatar/dist/${f}`; // internal modules, not in the package's exports map
const imports = [
  `import { validateAvatar, pointerGaze, BASE_YAW, BASE_PITCH, renderAvatarScene, sceneFrame } from '${lib('index.js')}';`,
  `import { analyzeBody } from '${lib('validate.js')}';`,
  `import { bounds, insideRow, isInside } from '${lib('path.js')}';`,
  `import { erosionAt, faceRoom, insideDistance, buildVolume } from '${lib('volume.js')}';`,
  `import { contourLoops, loopsToPath } from '${lib('contour.js')}';`,
  `import { silhouetteSeams } from '${lib('seams.js')}';`,
  `import { preparedVolume, DEFAULT_DEPTH } from '${lib('render.js')}';`,
].join('\n');
const entry = [imports, src('helpers.js'), src('engine.js'), src('live.js'), src('decor.js'), src('bridge.js')].join('\n;\n');

const out = await build({
  stdin: { contents: entry, resolveDir: here, sourcefile: 'pet-entry.js', loader: 'js' },
  bundle: true, format: 'iife', minify: true, target: ['safari16'], write: false, legalComments: 'none',
});
const js = out.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');
const license = '/*! open-bot-avatar 0.1.2 · MIT License · (c) 2026 Dominik Scholz */\n';
const page = src('page.html').replace('/*BUNDLE*/', () => license + js);
const dest = join(here, '..', 'Resources', 'PetWeb', 'pet.html');
mkdirSync(dirname(dest), { recursive: true });
writeFileSync(dest, page);
console.log(`pet.html ${(page.length / 1024).toFixed(0)} KB`);
