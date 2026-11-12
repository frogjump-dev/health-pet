// ===================================================================================
// HealthPet 3D app bridge. The page holds one living pet (mountPet + createDirector from
// engine.js / live.js, unchanged from the 3D方案 preview); the SwiftUI app drives it through
// window.Pet and hears back through webkit.messageHandlers.pet.
// ===================================================================================
const PETS = Object.fromEntries(FAMILIES.flatMap((f) => f.pets).map((p) => [p.def.id, p]));
// Mountain Jade (day) and 森林夜 (night), the same values as the preview's CSS variables.
const DAY = { line: '#2D392A', shadow: '#2D392A', accent: '#4B6844', ink2: '#6B7466', bubble: '#FFFFFF', cloud: '#B4C6D9', sky: '#E2ECF5', puff: '#FFFFFF', canvas: '#EBE9E3' };
const NIGHT = { line: '#EBE9E3', shadow: '#000000', accent: '#8FAE85', ink2: '#A3A99C', bubble: '#2B3428', cloud: '#8A9AAB', sky: '#34424C', puff: '#DCE4EA', canvas: '#121611' };
// Awake hours: drowsy after 45 s alone, asleep after 2 min. Bedtime: it nods off almost at once.
const AWAKE = { drowsy: 45, asleep: 120 };
const BEDTIME = { drowsy: 4, asleep: 10 };

const post = (msg) => { try { window.webkit?.messageHandlers?.pet?.postMessage(msg); } catch { /* not in the app */ } };
const stage = document.getElementById('stage');
window.addEventListener('error', (e) => post({ type: 'error', message: `${e.message} @${e.lineno}:${e.colno}` }));
window.addEventListener('unhandledrejection', (e) => post({ type: 'error', message: String(e.reason) }));
const cfg = { pet: 'toast', rug: false, shadow: true, dark: false, canvas: null, bedtime: false, mood: 'normal', energy: 'normal', calm: false, interactive: true, still: null,
  // where the pet's 100 × 100 box sits in the page, as fractions of the page width / height
  box: { x: 0.19, y: 0.245, size: 0.62 } };
let pet = null, dir = null, raf = 0, last = 0, paused = false, gulp = -1, gulpAmp = 1;

function applyTheme() {
  Object.assign(PAL, cfg.dark ? NIGHT : DAY);
  if (cfg.canvas) PAL.canvas = cfg.canvas;
}
function placeStage() {
  const { x, y, size } = cfg.box;
  stage.style.left = `${x * 100}%`;
  stage.style.top = `${y * 100}%`;
  stage.style.width = stage.style.height = `${size * 100}vw`;
}

// ---------- the pet's slow energy (PRD v0.2 §5.5) ----------
// Built on the director's own idle (live.js is unchanged): every so often, while the pet is awake,
// in a normal mood and doing nothing else, it gets one more idle move from its energy's pool.
// Lively hums, hops and sparkles more; low yawns, daydreams, stretches and now and then looks a
// little tired (PRD v0.3: the daily 「有点累」 mood is gone, its look lives here), its floor is
// paler, and a tap first cheers you on. Never sad.
const ENERGY_IDLE = {
  lively: ['hum', 'hum', 'hum', 'hop', 'hop', 'starry', 'proud'],
  low: ['yawn', 'yawn', 'daydream', 'daydream', 'stretch', 'tired'],
};
let energyIn = 8, cheeredAt = -1e9;
function applyEnergy() {
  stage.classList.toggle('low', cfg.energy === 'low');
  energyIn = 8;
}
function energyTick(dt) {
  const pool = ENERGY_IDLE[cfg.energy];
  if (!pool || !dir) return;
  energyIn -= dt;
  if (energyIn > 0) return;
  energyIn = 9 + Math.random() * 8;
  const st = dir.status();
  if (st.mode !== 'awake' || st.event || st.mood !== 'normal') return;
  dir.request(pool[Math.floor(Math.random() * pool.length)], { prio: 0.5, kind: 'ambient' });
}

function mount() {
  applyTheme();
  placeStage();
  applyEnergy();
  const p = PETS[cfg.pet] || PETS.toast;
  pet = mountPet(stage, p, { rug: cfg.rug, shadow: cfg.shadow });
  dir = createDirector(pet.anchors, { timing: cfg.bedtime ? BEDTIME : AWAKE, seed: 5 });
  if (cfg.mood !== 'normal') dir.setMood(cfg.mood);
  if (cfg.still) drawStill(cfg.still);
  else pet.frame(dir.update(0));
  const a = pet.anchors;
  stage.style.transformOrigin = `${a.cx}% ${a.bottom}%`;
  post({ type: 'ready', pet: p.def.id, anchors: { cx: a.cx, top: a.top, bottom: a.bottom, ey: a.ey, w: a.w, h: a.h } });
  run();
  // two frames later the pet is on screen: the app takes away the still picture it showed meanwhile
  requestAnimationFrame(() => requestAnimationFrame(() => post({ type: 'drawn', pet: p.def.id })));
}

/** A posed, motionless frame, for the pictures the app shows in grids and share cards. */
function drawStill(kind) {
  if (kind === 'proud') {
    // 骄傲挺胸 at its key pose: the main pet on share cards
    const e = EXPR_BY_ID.proud;
    pet.frame(e.f(e.key, pet.anchors));
    return;
  }
  const s = base();
  if (kind === 'happy') s.eyes = both({ k: 'happy' });
  pet.frame(s);
}

// ---------- feeding (PRD v0.2 §4.3, B 轻泡): the eyes follow the crumbs, it chews, it swallows ----------
// The app draws the bubble and its crumbs; the page only moves the pet, on the same timings:
// the crumbs burst at 0.2 s, stream into the mouth from 0.36 s (one every 0.05 s, 0.4 s each),
// the last one is in at about 1.06 s.
const feeds = [];
const look = { w: 0, x: 0, y: 0 };
function mouthPx() {
  const r = stage.getBoundingClientRect(), a = pet.anchors;
  const my = Math.min(a.bottom - 0.1 * a.h, a.ey + 0.12 * a.h);
  return [r.left + (a.cx / 100) * r.width, r.top + (my / 100) * r.height];
}
function feedTick(dt, st) {
  let target = null;
  for (const f of feeds) {
    f.t += dt;
    const t = f.t;
    if (t < 0.36) target = [f.x, f.y];
    else if (t < 0.76) { const p = (t - 0.36) / 0.4, e = p * p * p * 0.7 + p * 0.3; target = [f.x + (f.mx - f.x) * e, f.y + (f.my - f.y) * e]; }
    else if (t < 1.06) target = [f.mx, f.my];
    // chewing: a small gulp as every second crumb goes in, then the swallow
    while (f.bites.length && t >= f.bites[0]) { f.bites.shift(); gulp = 0; gulpAmp = 0.45; }
    if (!f.done && t >= 1.06) {
      f.done = true;
      gulp = 0; gulpAmp = 1;
      dir.activity();
      if (f.then === 'giggle') dir.play('giggle', { endAt: 1.6 });
      else if (f.then) dir.request(f.then, { prio: 3 });
    }
  }
  for (let i = feeds.length - 1; i >= 0; i--) if (feeds[i].t > 1.4) feeds.splice(i, 1);
  look.w += ((target ? 1 : 0) - look.w) * Math.min(1, dt * (target ? 10 : 3));
  if (target) { look.x = target[0]; look.y = target[1]; }
  if (look.w < 0.01) return st;
  const r = stage.getBoundingClientRect(), a = pet.anchors;
  const ex = r.left + (a.cx / 100) * r.width, ey = r.top + (a.ey / 100) * r.height;
  const reach = 110 * (window.innerWidth / 402);
  return { ...st,
    gx: st.gx + (clamp((look.x - ex) / reach, -1, 1) - st.gx) * look.w,
    gy: st.gy + (clamp((look.y - ey) / reach, -1, 1) - st.gy) * look.w };
}

function tick(now) {
  raf = 0;
  if (paused || !pet || cfg.still) return;
  const dt = Math.min(0.1, (now - last) / 1000);
  last = now;
  energyTick(dt);
  let st = dir.update(dt);
  if (feeds.length || look.w > 0.01) st = feedTick(dt, st);
  // Reduce Motion (PRD v0.3 §8.2): the body stays still and effects are left out; blinks, the
  // eyes and every expression's face still change.
  if (cfg.calm) st = { ...st, lift: 0, roll: 0, spin: 0, sx: 1, sy: 1, yaw: 0, pitch: 0, fx: [] };
  pet.frame(st);
  if (gulp >= 0 && cfg.calm) gulp = -1;
  if (gulp >= 0) {
    // the pet swallows food: a quick squash on its feet (a smaller one for each chew)
    gulp += dt;
    const g = gulp / 0.32, k = g < 1 ? Math.sin(g * Math.PI) * gulpAmp : 0;
    stage.style.transform = k ? `scale(${(1 + 0.07 * k).toFixed(3)}, ${(1 - 0.06 * k).toFixed(3)})` : '';
    if (g >= 1) gulp = -1;
  }
  raf = requestAnimationFrame(tick);
}
function run() {
  if (raf || paused || cfg.still || !pet) return;
  last = performance.now();
  raf = requestAnimationFrame(tick);
}

// ---------- touch: tap, several taps, press and hold (same rules as the preview) ----------
let pressed = false, held = false, holdTimer = 0;
stage.addEventListener('pointerdown', (ev) => {
  if (!cfg.interactive || !dir) return;
  ev.preventDefault();
  pressed = true; held = false;
  clearTimeout(holdTimer);
  holdTimer = setTimeout(() => { held = true; dir.holdStart(); post({ type: 'hold' }); }, 450);
});
stage.addEventListener('pointerup', () => {
  if (!pressed) return;
  pressed = false;
  clearTimeout(holdTimer);
  if (held) { dir.holdEnd(); return; }
  const st = dir.status();
  if (cfg.energy === 'low' && st.mode === 'awake' && !st.event && performance.now() - cheeredAt > 60000) {
    // a low week: the first tap in a while, the pet cheers you on (给你打气)
    cheeredAt = performance.now();
    dir.request('cheerup', { prio: 2 });
    post({ type: 'tap', mode: 'awake' });
    return;
  }
  dir.tap();
  post({ type: 'tap', mode: dir.status().mode });
});
const cancel = () => { if (!pressed) return; pressed = false; clearTimeout(holdTimer); if (held) dir.holdEnd(); };
stage.addEventListener('pointerleave', cancel);
stage.addEventListener('pointercancel', cancel);

// ---------- the app's handle ----------
window.Pet = {
  /** Change any of cfg; a different pet or floor mounts the pet again. */
  configure(o = {}) {
    const remount = !pet || (o.pet && o.pet !== cfg.pet) || (o.rug !== undefined && o.rug !== cfg.rug) || (o.still !== undefined && o.still !== cfg.still);
    const bedtime = o.bedtime !== undefined && o.bedtime !== cfg.bedtime;
    const mood = o.mood && o.mood !== cfg.mood;
    const energy = o.energy && o.energy !== cfg.energy;
    Object.assign(cfg, o);
    if (remount) { mount(); return; }
    applyTheme();
    placeStage();
    if (energy) applyEnergy();
    if (bedtime) dir.setTiming(cfg.bedtime ? BEDTIME : AWAKE);
    if (mood) dir.setMood(cfg.mood);
  },
  /** Stop drawing while the pet is off screen; start again where it was. */
  pause(on) { paused = !!on; if (!paused) run(); },
  /** First open of the day: 醒来, played to the end. */
  morning() { dir?.morning(); },
  /** A moment that always plays to the end (cheer, starry, proud, hop, love, cheerup, confused). */
  celebrate(id) { dir?.request(id, { prio: 3 }); },
  /** Any expression, as if picked from the list. */
  play(id) { dir?.play(id); },
  /** A food bubble reached the pet's mouth. */
  eat() { if (!dir) return; gulp = 0; gulpAmp = 1; dir.activity(); dir.play('giggle', { endAt: 1.6 }); },
  /**
   * A food bubble at (x, y) (fractions of the page) was tapped: the pet watches its crumbs come,
   * chews, and at 1.06 s swallows and plays `then` (giggle, or a moment such as proud or cheer).
   */
  feed(o = {}) {
    if (!dir || !pet) return;
    dir.activity();
    const [mx, my] = mouthPx();
    feeds.push({ t: 0, x: (o.x ?? 0.5) * window.innerWidth, y: (o.y ?? 0.3) * window.innerHeight, mx, my,
      then: o.then ?? 'giggle', bites: [0.81, 0.91, 1.01], done: false });
  },
  /** Something happened around the pet (a scroll, a button): keeps it from dozing off. */
  activity() { dir?.activity(); },
  status() { return dir ? dir.status() : null; },
};

Object.assign(cfg, window.PET_INIT || {});
mount();
