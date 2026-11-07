// ===================================================================================
// Expression engine for the 3D方案 slice pets (on top of open-bot-avatar 0.1.2, unforked).
// The library builds the slice scene (renderAvatarScene) and, per frame, the view, slice
// culling and eye placement (sceneFrame). Everything else is ours: body motion (hop, squash,
// tilt, spin), eye shapes drawn into the library's eye planes, a face plane for blush and
// mouth, a ground shadow and 2D effects (notes, sparkles, hearts, Zzz, confetti).
// Each expression is a pure function of time, so any frame can be rendered exactly.
// ===================================================================================
// pet-svg3d rebuilds rim paints (a 201×201 distance field) on every mount; remember them, so a
// gallery of the same pet (面包人, 麻薯, 牛油果, 热牛奶 have rims) mounts in a few ms, not ~300 ms each.
{
  const orig = rimPath, memo = new Map();
  rimPath = (polys, w) => {
    const k = `${w}|${JSON.stringify(polys)}`;
    let v = memo.get(k);
    if (v === undefined) { v = orig(polys, w); memo.set(k, v); }
    return v;
  };
}
const EYE_W = 4, EYE_H = 11, EYE_LIFT = 1.5;
const D2R = Math.PI / 180;
const r2 = (n) => Math.round(n * 100) / 100;
const U = (n) => `${r2(n)}cqw`;
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const sm = (x) => { x = clamp(x, 0, 1); return x * x * (3 - 2 * x); };
const lerp = (a, b, k) => a + (b - a) * k;
/** 0 before a, eases to 1 by b. */
const win = (t, a, b) => sm((t - a) / (b - a));
/** Rises a→b, falls c→d. */
const env = (t, a, b, c, d) => win(t, a, b) * (1 - win(t, c, d));
const osc = (t, period, phase = 0) => Math.sin((2 * Math.PI * t) / period + phase);
/** Eye closure 0..1 of a blink starting at `at`. */
const blink = (t, at, dur = 0.2) => { const u = (t - at) / dur; return u > 0 && u < 1 ? Math.sin(Math.PI * u) : 0; };
/** Parabolic hop between a and b, height h (negative lift = up). */
const hop = (t, a, b, h) => { const u = (t - a) / (b - a); return u > 0 && u < 1 ? -h * 4 * u * (1 - u) : 0; };
/** Damped spring settle after time a: starts at amp, rings at period. */
const ring = (t, a, amp, period = 0.32, decay = 3.2) => (t < a ? 0 : amp * sm((t - a) / 0.07) * Math.cos((2 * Math.PI * (t - a)) / period) * Math.exp(-decay * (t - a)));
const noise = (n) => { let h = Math.imul(n | 0, 0x9e3779b1) >>> 0; h = Math.imul(h ^ (h >>> 16), 0x85ebca6b); h ^= h >>> 13; return (h >>> 0) / 4294967296; };

const PAL = {
  // Mountain Jade (decided 2026-11-06): ink 森林深绿, accent 玉绿, 青柠 for sleep/primary-dark
  ink2: '#6B7466', line: '#2D392A', shadow: '#2D392A', accent: '#4B6844', gold: '#E2B443', heart: '#F27A8C', blush: '#FF8A9A', drop: '#8CC2E8',
  conf: ['#4B6844', '#E2B443', '#F08A72', '#8CB8D9', '#D9D387'],
  bubble: '#FFFFFF', cloud: '#B4C6D9', blushLine: '#E8687F', sun: '#F0B23E',
  sky: '#E2ECF5', puff: '#FFFFFF', night: '#8D9CC4', canvas: '#EBE9E3',
};

const pill = (o = {}) => ({ k: 'pill', ...o });
const both = (spec) => [{ ...spec }, { ...spec }];

function base() {
  return { lift: 0, roll: 0, spin: 0, sx: 1, sy: 1, yaw: 0, pitch: 0, gx: 0, gy: 0, eyes: both(pill()), blush: 0, mouth: null, fx: [] };
}
/** The calm breathing every expression sits on. Its period is stretched a little per expression, so a loop ends on the breath it started with. */
let BREATH_P = 3.4;
function breathe(s, t, amt = 1) {
  const b = osc(t, BREATH_P, -Math.PI / 2);
  s.sy *= 1 + 0.014 * b * amt;
  s.sx *= 1 - 0.009 * b * amt;
  return s;
}
const setOpen = (s, open) => s.eyes.forEach((e) => { if (e.k === 'pill') e.open = Math.min(e.open ?? 1, open); });

// ------------------------------------------------------------------------------------
// The expressions. c = anchors of the pet (viewBox units): cx, top, bottom, left, right, ey.
// ------------------------------------------------------------------------------------
const EXPRS = [
  // ---------- 待机 Idle (home, nobody touching) ----------
  { id: 'idle', zh: '呼吸', group: 'idle', dur: 4.4, key: 1.0, loop: true, use: '首页默认，一直轻轻呼吸、眨眼',
    f(t) {
      const s = breathe(base(), t);
      s.lift = -0.5 * (1 - Math.cos((2 * Math.PI * t) / 4.4));
      s.roll = 1.2 * osc(t, 4.4);
      s.yaw = 2.5 * osc(t, 4.4, 0.6);
      s.gx = 0.35 * env(t, 2.2, 2.4, 3.4, 3.6);
      setOpen(s, 1 - blink(t, 1.5) - blink(t, 3.9));
      return s;
    } },
  { id: 'lookaround', zh: '东张西望', group: 'idle', dur: 4.8, key: 1.2, loop: true, use: '待机随机：左右看看，露出一点立体感',
    f(t, c) { return this.f0(t * 5.2 / 4.8, c); }, // authored at 5.2 s, played in 4.8 s
    f0(t) {
      const s = breathe(base(), t);
      const side = win(t, 0.5, 1.0) - 2 * win(t, 2.3, 2.9) + win(t, 4.1, 4.6);
      s.yaw = 16 * side;
      s.gx = 0.85 * (win(t, 0.35, 0.6) - 2 * win(t, 2.15, 2.4) + win(t, 3.95, 4.2));
      s.pitch = 2.5 * env(t, 0.5, 1.0, 4.1, 4.6);
      s.roll = -2.5 * side;
      s.lift = hop(t, 0.5, 0.9, 0.6) + hop(t, 2.3, 2.8, 0.6) + hop(t, 4.1, 4.5, 0.6);
      setOpen(s, 1 - blink(t, 2.25) - blink(t, 4.0));
      return s;
    } },
  { id: 'daydream', zh: '发呆', group: 'idle', dur: 5.0, key: 2.68, loop: true, use: '待机随机：望着上方放空，脑袋里只飘着一朵云',
    f(t, c) { return this.f0(t * 5.6 / 5.0, c); }, // authored at 5.6 s, played in 5.0 s
    f0(t, c) {
      const s = breathe(base(), t, 0.7);
      const k = env(t, 0.3, 1.0, 4.7, 5.3);
      s.gx = 0.55 * k; s.gy = -0.8 * k;
      s.roll = -5 * k + 1.2 * osc(t, 2.8) * k;
      s.yaw = 7 * k; s.pitch = 4 * k;
      s.lift = -0.4 * (1 - Math.cos((2 * Math.PI * t) / 5.6));
      // a blank stare: the eyes go a little smaller and blink slowly
      s.eyes = both(pill({ sx: 1 - 0.14 * k, sy: 1 - 0.16 * k }));
      setOpen(s, 1 - blink(t, 3.6, 0.6));
      // three dots float up, then the thought cloud pops open
      const fade = 1 - win(t, 4.5, 5.0);
      [0, 1, 2].forEach((i) => {
        const a = win(t, 0.9 + i * 0.22, 1.05 + i * 0.22) * fade;
        if (a > 0.01) s.fx.push({ k: 'tdot', x: c.right - 13 + i * 1.8, y: c.top + 0.5 - i * 5.6, s: (1.0 + i * 0.45) * popIn(t, 0.9 + i * 0.22, 1.12 + i * 0.22), a });
      });
      const b = win(t, 1.6, 1.75) * fade;
      if (b > 0.01) {
        const pop = 1 + ring(t, 1.6, 0.14, 0.32, 5);
        s.fx.push({ k: 'thought', x: c.right + 4 + 0.8 * osc(t, 2.6), y: c.top - 23 + 0.9 * osc(t, 2.2, 1), s: 1.75 * pop, a: b, drift: (t - 1.6) / 3.6 });
      }
      return s;
    } },
  { id: 'hum', zh: '哼歌', group: 'idle', dur: 3.2, key: 0.45, loop: true, use: '心情好时的待机：闭眼摇摆，飘出音符',
    f(t, c) {
      const s = breathe(base(), t, 0.5);
      s.roll = 6 * osc(t, 1.6);
      s.yaw = 7 * osc(t, 1.6);
      s.lift = -1.2 * Math.abs(osc(t, 1.6));
      s.sy *= 1 - 0.02 * Math.abs(osc(t, 1.6, Math.PI / 2));
      s.eyes = both({ k: 'happy' });
      for (let n = 0; n < 4; n++) {
        const born = n * 0.8, u = ((t - born + 3.2) % 3.2) / 2.2;
        if (u < 0 || u > 1) continue;
        const side = n % 2 ? 1 : -1;
        s.fx.push({ k: 'note', x: c.cx + side * (c.w * 0.36 + u * 8) + 1.4 * Math.sin(u * 5.2 + n), y: c.top + 6 - u * 17, s: 2.15 * popIn(u, 0, 0.16), rot: side * (6 + 8 * osc(u, 0.5)), yaw: 32 * Math.sin(u * 5.6 + n * 1.3), a: env(u, 0, 0.1, 0.72, 1), c: n % 2 ? PAL.gold : PAL.accent, flip: n % 2 });
      }
      return s;
    } },
  { id: 'stretch', zh: '伸懒腰', group: 'idle', dur: 3.8, key: 0.95, loop: true, use: '待机随机：坐久了，伸个大懒腰',
    f(t) {
      const s = breathe(base(), t, 0.5);
      const up = win(t, 0.2, 1.0) * (1 - win(t, 1.7, 1.85));
      const shiver = env(t, 1.0, 1.1, 1.6, 1.7) * 0.6 * osc(t, 0.09);
      s.sy *= 1 + 0.13 * up + ring(t, 1.85, -0.1, 0.34);
      s.sx *= 1 - 0.07 * up + ring(t, 1.85, 0.08, 0.34);
      s.lift = -1.2 * up;
      s.pitch = 6 * up;
      s.roll = shiver;
      if (t > 0.35 && t < 1.9) s.eyes = both({ k: 'chev', s: 0.9 });
      else if (t >= 1.9 && t < 2.5) s.eyes = both({ k: 'happy' });
      setOpen(s, 1 - blink(t, 3.0));
      return s;
    } },
  { id: 'bored', zh: '无聊', group: 'idle', dur: 5.0, key: 3.4, loop: true, use: '很久没人理：眼皮半垂，叹口气，冒出省略号',
    f(t, c) {
      const s = breathe(base(), t, 0.8);
      const drift = osc(t, 5.0, -Math.PI / 2);
      s.gx = 0.5 * drift; s.yaw = 6 * drift; s.roll = -2 * drift;
      s.sy *= 0.975; s.sx *= 1.012; s.pitch = -2;
      const sigh = env(t, 2.0, 2.5, 2.6, 3.5);
      s.sy *= 1 + 0.045 * sigh; s.sx *= 1 - 0.02 * sigh; s.lift = -0.8 * sigh; s.pitch += 3 * sigh;
      s.eyes = both(pill({ lid: 0.5 - 0.14 * sigh }));
      setOpen(s, 1 - blink(t, 1.2, 0.35) - blink(t, 4.3, 0.35));
      [0, 1, 2].forEach((i) => {
        const t0 = 2.9 + i * 0.25, a = env(t, t0, t0 + 0.08, 4.4, 4.85);
        const p = popIn(t, t0, t0 + 0.3);
        if (a > 0.01) s.fx.push({ k: 'dot', x: c.right + 2.4 + i * 5.0, y: c.top + c.h * 0.2 - 1.8 * (1 - p) + 0.4 * osc(t - i * 0.18, 1.2) * win(t, 3.7, 4.0) + 1.8 * win(t, 4.3, 4.85), s: 1.7 * p, a });
      });
      return s;
    } },

  // ---------- 互动 Touch (tap / hold / tap a lot) ----------
  { id: 'shy', zh: '害羞', group: 'touch', dur: 3.0, key: 0.9, loop: true, use: '轻点一下：转开脸、脸红',
    f(t) {
      const s = breathe(base(), t);
      const k = env(t, 0.1, 0.45, 2.2, 2.8);
      s.sy *= 1 - 0.04 * env(t, 0, 0.12, 0.12, 0.35);
      s.yaw = -15 * k; s.roll = -4 * k + 1.8 * osc(t, 0.16) * env(t, 0.4, 0.5, 1.0, 1.3);
      s.gx = -0.6 * k; s.gy = 0.25 * k;
      s.blush = k;
      s.lift = hop(t, 0.05, 0.4, 1.2);
      if (k > 0.3) s.eyes = both({ k: 'happy' });
      return s;
    } },
  { id: 'surprised', zh: '吓一跳', group: 'touch', dur: 2.6, key: 0.3, loop: true, use: '轻点一下 / 犯困时被叫醒：吓一跳，眼睛瞪大',
    f(t, c) {
      const s = breathe(base(), t, 0.5);
      const big = env(t, 0.05, 0.18, 1.7, 2.2);
      s.lift = hop(t, 0.05, 0.55, 7);
      s.sy *= 1 + 0.08 * env(t, 0.05, 0.12, 0.2, 0.4) + ring(t, 0.55, -0.08, 0.3, 4);
      s.sx *= 1 - 0.05 * env(t, 0.05, 0.12, 0.2, 0.4) + ring(t, 0.55, 0.06, 0.3, 4);
      s.pitch = 5 * env(t, 0.05, 0.2, 0.5, 0.9);
      s.eyes = both(pill({ sx: 1 + 0.28 * big, sy: 1 + 0.16 * big }));
      setOpen(s, 1 - blink(t, 1.15, 0.16) - blink(t, 1.4, 0.16));
      const b = env(t, 0.05, 0.15, 0.5, 0.75);
      if (b > 0.01) s.fx.push({ k: 'burst', x: c.cx, y: c.top - 3 + s.lift, s: 1 + 0.4 * win(t, 0.05, 0.4), a: b });
      return s;
    } },
  { id: 'wink', zh: '眨眼', group: 'touch', dur: 2.4, key: 0.8, loop: true, use: '轻点一下（随机）：俏皮地眨一只眼',
    f(t, c) {
      const s = breathe(base(), t);
      const k = env(t, 0.15, 0.4, 1.4, 1.75);
      s.roll = 7 * k; s.yaw = 9 * k; s.pitch = 2 * k;
      s.lift = hop(t, 0.1, 0.4, 1.4);
      s.gx = 0.25 * k;
      s.eyes = [pill({ sx: 1 + 0.06 * k, sy: 1 + 0.04 * k }), k > 0.35 ? { k: 'happy', s: 1.05 } : pill()];
      s.blush = 0.45 * k;
      const g = env(t, 0.45, 0.6, 1.1, 1.4);
      if (g > 0.01) s.fx.push({ k: 'sparkle', x: c.right + 1, y: c.top + c.h * 0.28, s: 0.8 + 0.6 * g, a: g, c: PAL.gold });
      setOpen(s, 1 - blink(t, 2.05));
      return s;
    } },
  { id: 'giggle', zh: '被挠痒', group: 'touch', dur: 2.4, key: 0.6, loop: true, use: '连续点几下：咯咯笑到发抖',
    f(t, c) {
      const s = breathe(base(), t, 0.3);
      const k = env(t, 0.05, 0.2, 1.8, 2.3);
      s.roll = 5 * osc(t, 0.12) * k;
      s.yaw = 5 * osc(t, 0.24, 1) * k;
      s.lift = -1.6 * Math.abs(osc(t, 0.3)) * k;
      s.sy *= 1 - 0.03 * Math.abs(osc(t, 0.3, Math.PI / 2)) * k;
      s.blush = 0.65 * k;
      if (k > 0.2) s.eyes = both({ k: 'chev' });
      [0, 1, 2].forEach((i) => {
        const u = (((t - i * 0.4) % 1.2) + 1.2) % 1.2 / 1.2;
        const side = i % 2 ? 1 : -1;
        const a = env(u, 0, 0.15, 0.6, 1) * k;
        if (a > 0.01) s.fx.push({ k: 'sparkle', x: c.cx + side * (c.w * 0.45 + 4 * u), y: c.top + 8 - 6 * u - i * 2, s: 0.9 + 0.3 * u, a, c: PAL.gold });
      });
      return s;
    } },
  { id: 'pat', zh: '被摸摸', group: 'touch', dur: 3.2, key: 0.8, loop: true, use: '长按 / 手指来回抚摸：蹭蹭你',
    f(t, c) {
      const s = breathe(base(), t, 0.4);
      const k = env(t, 0.1, 0.4, 2.6, 3.1);
      s.roll = 7 * osc(t, 1.25, -Math.PI / 2 + 0.6) * k;
      s.yaw = 9 * osc(t, 1.25, -Math.PI / 2 + 0.6) * k;
      s.sy *= 1 - 0.05 * k; s.sx *= 1 + 0.03 * k;
      s.gy = 0.15 * k;
      s.blush = 0.55 * k;
      if (k > 0.25) s.eyes = both({ k: 'happy' });
      const u = clamp((t - 1.0) / 1.6, 0, 1);
      if (u > 0 && u < 1) s.fx.push({ k: 'heart', x: c.cx + c.w * 0.32 + 3 * u, y: c.top + 2 - 10 * u, s: (1.3 + 0.35 * u) * popIn(u, 0, 0.16), yaw: 26 * Math.sin(u * 6), a: env(u, 0, 0.1, 0.6, 1) });
      return s;
    } },
  { id: 'tilt', zh: '歪头好奇', group: 'touch', dur: 3.4, key: 0.75, loop: true, use: '轻点一下 / 你回到首页时：歪头看你',
    f(t) {
      const s = breathe(base(), t);
      const a = env(t, 0.15, 0.5, 1.3, 1.6), b = env(t, 1.6, 1.95, 2.8, 3.2);
      s.roll = 10 * a - 10 * b;
      s.yaw = 8 * a - 8 * b;
      s.pitch = 3 * (a + b);
      s.lift = hop(t, 0.15, 0.45, 0.8) + hop(t, 1.6, 1.9, 0.8);
      // The highlight stays on through both tilts and slides with the head, mirrored: up-right when it tilts right, up-left when it tilts left.
      const hk = env(t, 0.15, 0.5, 2.8, 3.2);
      s.eyes = both(pill({ sx: 1 + 0.1 * (a + b), sy: 1 + 0.07 * (a + b), hl: hk > 0.4 ? 'star' : 0, hlS: sm((hk - 0.4) / 0.3),
        hlX: 0.14 * (a - b), hlY: -0.07 * (a + b) }));
      setOpen(s, 1 - blink(t, 1.45, 0.18));
      return s;
    } },
  { id: 'confused', zh: '困惑', group: 'touch', dur: 3.2, key: 0.8, loop: true, use: '手表没同步 / 数据没拿到：左右歪头冒问号',
    f(t, c) {
      const s = breathe(base(), t);
      const a = env(t, 0.15, 0.45, 1.35, 1.65), b = env(t, 1.65, 1.95, 2.75, 3.1);
      s.roll = -9 * a + 9 * b; s.yaw = -6 * a + 6 * b; s.pitch = 2 * (a + b);
      s.gx = -0.3 * a + 0.3 * b; s.gy = -0.35 * (a + b);
      s.lift = hop(t, 0.15, 0.4, 0.7) + hop(t, 1.65, 1.9, 0.7);
      const k = a + b;
      const big = pill({ sx: 1 + 0.12 * k, sy: 1 + 0.12 * k }), small = pill({ lid: 0.38 * k, sy: 1 - 0.1 * k, slant: 0.2 * k });
      s.eyes = b > a ? [small, big] : [big, small];
      setOpen(s, 1 - blink(t, 1.55, 0.18));
      const side = b > a ? 1 : -1, q = Math.max(a, b);
      if (q > 0.01) s.fx.push({ k: 'q', x: c.cx + side * c.w * 0.47, y: c.top - 7 + s.lift, s: 2.2 + 0.4 * q + ring(t, b > a ? 1.65 : 0.15, 0.22, 0.3, 5), rot: side * 12, a: q, c: PAL.accent });
      return s;
    } },
  { id: 'dizzy', zh: '晕乎乎', group: 'touch', dur: 3.0, key: 0.5, loop: true, use: '点太多下：转圈圈眼（提示休息一下）',
    f(t, c) {
      const s = breathe(base(), t, 0.3);
      const k = env(t, 0.0, 0.3, 2.5, 3.0);
      const w = (2 * Math.PI * t) / 1.5;
      s.roll = 6 * Math.sin(w) * k;
      s.yaw = 12 * Math.cos(w) * k;
      s.pitch = 5 * Math.sin(w) * k;
      s.lift = -0.8 * k;
      s.eyes = k > 0.15 ? [{ k: 'spiral', rot: t * 420 }, { k: 'spiral', rot: -t * 420 }] : both(pill());
      const rx = c.w * 0.36, ry = 3.6, oy = c.top - 4.5 + s.lift;
      s.fx.push({ k: 'orbit', half: 'back', x: c.cx, y: oy, rx, ry, a: k, back: true }, { k: 'orbit', half: 'front', x: c.cx, y: oy, rx, ry, a: k });
      for (let i = 0; i < 4; i++) {
        const an = w * 1.2 + (i * Math.PI) / 2, z = Math.sin(an);
        s.fx.push({ k: 'star', x: c.cx + Math.cos(an) * rx, y: oy + z * ry, s: (1.45 + 0.35 * z) * popIn(t, 0.04 + i * 0.06, 0.34 + i * 0.06), a: k * (0.72 + 0.28 * (z + 1) / 2), c: PAL.gold, yaw: 55 * Math.sin(t * 7 + i * 1.6), rot: 12 * Math.cos(an), back: z < 0 });
      }
      return s;
    } },

  // ---------- 庆祝 Check-in celebrations ----------
  { id: 'hop', zh: '开心跳', group: 'cheer', dur: 2.76, key: 0.23, loop: true, use: '完成一个小目标（步数、喝水）',
    f(t) {
      const s = base();
      const P = 0.92, p = (t % P) / P;
      const air = 4 * p * (1 - p);
      const land = clamp(1 - Math.min(p, 1 - p) / 0.14, 0, 1);
      s.lift = -5 * air;
      s.sy = 1 - 0.1 * land + 0.04 * air;
      s.sx = 1 + 0.08 * land - 0.02 * air;
      s.roll = 5 * osc(t, P * 2);
      s.yaw = 6 * osc(t, P * 3, 0.6);
      s.eyes = both({ k: 'happy' });
      return s;
    } },
  { id: 'starry', zh: '星星眼', group: 'cheer', dur: 2.8, key: 0.7, loop: true, use: '打卡成功 / 解锁新宠物的那一刻：亮晶晶的大眼睛',
    f(t, c) {
      const s = breathe(base(), t);
      s.pitch = 3;
      s.lift = -0.7 * Math.abs(osc(t, 0.7));
      s.sy *= 1 - 0.015 * Math.abs(osc(t, 0.7, Math.PI / 2));
      s.roll = 1.5 * osc(t, 1.4);
      s.eyes = both({ k: 'gem', shine: osc(t, 1.4) });
      s.blush = 0.6;
      const spots = [[0.6, 0.02], [-0.58, 0.3], [0.66, 0.5]];
      spots.forEach(([dx, dy], i) => {
        const u = (((t / 1.4 + i * 0.41) % 1) + 1) % 1;
        const a = Math.sin(Math.PI * u);
        s.fx.push({ k: 'sparkle', x: c.cx + dx * c.w, y: c.top + (dy + 0.25) * c.h * 0.6, s: 0.5 + 0.6 * a, a: 0.9 * a, c: PAL.gold, rot: 0 });
      });
      return s;
    } },
  { id: 'cheer', zh: '打卡欢呼', group: 'cheer', dur: 3.4, key: 1.02, loop: true, use: '完成一次运动 / 达成自律周：蓄力大跳 + 彩纸',
    f(t, c) {
      const s = base();
      const crouch = env(t, 0.0, 0.3, 0.3, 0.42), up = env(t, 0.36, 0.46, 0.5, 0.75);
      s.sy = 1 - 0.14 * crouch + 0.1 * up + ring(t, 1.15, -0.13, 0.32, 3.5);
      s.sx = 1 + 0.1 * crouch - 0.06 * up + ring(t, 1.15, 0.1, 0.32, 3.5);
      s.lift = hop(t, 0.4, 1.15, 17) + hop(t, 1.75, 2.15, 2.5) + hop(t, 2.35, 2.75, 2.5);
      s.spin = 360 * sm((t - 0.48) / 0.6);
      s.roll = 4 * osc(t, 0.8) * win(t, 1.6, 1.8);
      s.yaw = 6 * osc(t, 0.8, 0.5) * win(t, 1.6, 1.8);
      s.eyes = t < 0.42 ? both({ k: 'chev' }) : both({ k: 'happy' });
      s.blush = 0.4 * win(t, 1.0, 1.3) * (1 - win(t, 3.0, 3.4));
      // confetti from the top of the jump
      if (t > 0.75) {
        const u = t - 0.75, tau = 0.5, gr = 40, e = 1 - Math.exp(-u / tau);
        for (let i = 0; i < 24; i++) {
          const ang = -Math.PI / 2 + ((i + noise(i * 3 + 1)) / 24 - 0.5) * 2.9; // evenly fanned, a little jitter
          const v = 56 + noise(i * 3 + 2) * 40, back = i % 3 === 2; // a third flies behind the pet
          const sway = Math.sin(2 * Math.PI * (1.0 + 0.8 * noise(i * 7)) * u + i) * 2.6 * win(u, 0.25, 0.8);
          const x = c.cx + (noise(i * 5 + 7) - 0.5) * 8 + Math.cos(ang) * v * tau * e + sway;
          const y = c.top - 14 + Math.sin(ang) * v * tau * e + gr * tau * (u - tau * e); // from above the head at the top of the jump
          const a = win(u, 0, 0.05) * (1 - win(u, 1.75, 2.4));
          if (a > 0.01) s.fx.push({ k: 'conf', back, x, y, s: ((i % 3 === 1 ? 0.85 : 1.0) + 0.3 * noise(i * 11)) * (back ? 0.85 : 1), rot: (noise(i * 17) - 0.5) * 360 + u * (noise(i * 19) - 0.5) * 520, flip: u * (420 + 480 * noise(i * 13)) + i * 40, a, c: PAL.conf[i % PAL.conf.length], shape: i % 3 === 1 ? 1 : 0 });
        }
        [[-0.34, -9], [0.32, -13], [0.04, -21]].forEach(([dx, dy], j) => {
          const f = Math.sin(Math.PI * clamp((u - 0.04 - j * 0.08) / 0.55, 0, 1));
          if (f > 0.01) s.fx.push({ k: 'sparkle', x: c.cx + dx * c.w, y: c.top + dy, s: 1.15 * f, a: f, c: PAL.gold, rot: 25 * f });
        });
      }
      return s;
    } },
  { id: 'proud', zh: '骄傲挺胸', group: 'cheer', dur: 3.2, key: 1.2, loop: true, use: '准时睡觉打卡 / 连续自律：抬头挺胸',
    f(t, c) {
      const s = breathe(base(), t, 0.4);
      const k = env(t, 0.2, 0.8, 2.5, 3.1);
      s.pitch = 7 * k;
      s.sx *= 1 + 0.05 * k; s.sy *= 1 + 0.035 * k;
      s.lift = -1.0 * k;
      s.roll = 1.2 * osc(t, 1.6) * k;
      s.eyes = k > 0.3 ? both({ k: 'happy', peak: 0.75 }) : both(pill());
      const g = env(t, 0.85, 1.05, 2.6, 3.05), tw = 1 + 0.12 * osc(t, 0.6);
      if (g > 0.01) s.fx.push({ k: 'sparkle', x: c.right - 2, y: c.top + 3, s: (0.8 + 1.0 * g) * tw, a: g, c: PAL.gold, rot: 8 * osc(t, 1.2) });
      const g2 = env(t, 1.25, 1.45, 2.45, 2.9);
      if (g2 > 0.01) s.fx.push({ k: 'sparkle', x: c.right + 5, y: c.top + 11, s: (0.5 + 0.55 * g2) * (2 - tw), a: g2, c: PAL.gold });
      return s;
    } },
  { id: 'love', zh: '喜欢你', group: 'cheer', dur: 3.0, key: 0.45, loop: true, use: '亲密度升级 / 连续陪伴 7 天：爱心眼',
    f(t, c) {
      const s = breathe(base(), t);
      const beat = (x) => Math.max(0, Math.sin((2 * Math.PI * x) / 0.75)) ** 6;
      s.eyes = both({ k: 'heart', s: 1 + 0.18 * beat(t) });
      s.blush = 0.8;
      s.roll = 4 * osc(t, 1.5);
      s.yaw = 5 * osc(t, 1.5, 0.4);
      s.lift = -0.8 * beat(t);
      for (let n = 0; n < 3; n++) {
        const u = (((t - n * 1.0) % 3.0) + 3.0) % 3.0 / 2.0;
        if (u > 1) continue;
        const side = [-1, 1, 0.3][n];
        s.fx.push({ k: 'heart', x: c.cx + side * c.w * 0.42 + 3 * Math.sin(u * 6), y: c.top + 6 - 14 * u, s: (1.15 + 0.45 * u) * popIn(u, 0, 0.14), yaw: 28 * Math.sin(u * 5.5 + n), a: env(u, 0, 0.1, 0.65, 1) });
      }
      return s;
    } },

  // ---------- 睡觉 Bedtime ----------
  { id: 'yawn', zh: '打哈欠', group: 'sleep', dur: 3.8, key: 1.2, loop: true, use: '临近目标入睡时间：困了提醒',
    f(t) {
      const s = breathe(base(), t, 0.6);
      const inhale = win(t, 0.2, 0.8) * (1 - win(t, 1.9, 2.5));
      const mouth = env(t, 0.6, 1.0, 1.7, 2.1);
      s.sy *= 1 + 0.07 * inhale; s.sx *= 1 - 0.035 * inhale;
      s.pitch = 7 * inhale;
      s.roll = -3 * inhale;
      s.lift = -0.8 * inhale;
      if (t < 0.6) s.eyes = both(pill({ lid: 0.25 + 0.4 * win(t, 0.2, 0.6) }));
      else if (t < 2.0) s.eyes = both({ k: 'chev', s: 0.85, tear: win(t, 1.3, 1.6) });
      else s.eyes = both(pill({ lid: lerp(0.55, 0.25, win(t, 2.6, 3.6)), tear: 1 - win(t, 2.2, 2.8) }));
      setOpen(s, 1 - blink(t, 3.0, 0.4));
      s.mouth = mouth > 0.03 ? { k: 'yawn', s: mouth } : null;
      return s;
    } },
  { id: 'doze', zh: '打瞌睡', group: 'sleep', dur: 4.6, key: 2.2, loop: true, use: '睡前时段：眼皮打架，点头又惊醒',
    f(t) {
      const s = breathe(base(), t, 0.6);
      const drop = win(t, 0.0, 2.5) * (1 - win(t, 2.6, 2.75));
      const lid = 0.35 + 0.6 * drop;
      s.pitch = -7 * drop;
      s.roll = 6 * drop;
      s.sy *= 1 - 0.03 * drop;
      s.lift = hop(t, 2.6, 2.95, 2.2);
      s.eyes = both(pill(t > 2.6 && t < 3.3 ? { sx: 1.08, sy: 1.05 } : { lid: t > 3.3 ? lerp(0.0, 0.35, win(t, 3.3, 4.6)) : lid }));
      if (lid > 0.88 && t < 2.6) s.eyes = both({ k: 'sleep', s: 0.9 });
      setOpen(s, 1 - blink(t, 3.05, 0.15));
      return s;
    } },
  { id: 'sleep', zh: '熟睡', group: 'sleep', dur: 4.8, key: 1.6, loop: true, use: '睡眠中（Apple Watch 检测到入睡）：慢呼吸 + Zzz',
    f(t, c) {
      const s = base();
      const b = osc(t, 2.4, -Math.PI / 2);
      s.sy = 1 + 0.03 * b; s.sx = 1 - 0.018 * b;
      s.roll = -5;
      s.pitch = -3;
      s.yaw = -4;
      s.eyes = both({ k: 'sleep' });
      for (let n = 0; n < 3; n++) {
        const u = (((t - n * 1.6) % 4.8) + 4.8) % 4.8 / 3.2;
        if (u > 1) continue;
        s.fx.push({ k: 'z', x: c.right - 4 + 7 * u + 1.5 * Math.sin(u * 7), y: c.top + 2 - 13 * u, s: (1.55 + 1.1 * u) * popIn(u, 0, 0.15), rot: -10 + 14 * u, yaw: 30 * Math.sin(u * 4.5 + n), a: env(u, 0, 0.12, 0.6, 1) });
      }
      return s;
    } },
  { id: 'wakeup', zh: '醒来', group: 'sleep', dur: 5.2, key: 3.05, loop: false, use: '早上第一次打开 App：太阳出来，眯眼又闭上赖一下床，认出是你，开心地说早安',
    f(t, c) {
      const s = breathe(base(), t, t < 2 ? 1.5 : 0.6);
      // 1) still asleep and leaning; the last Z drifts off while the sun comes up beside it
      const snooze = env(t, 1.3, 1.5, 1.75, 1.95);           // "five more minutes": nods back down
      const leanOff = win(t, 1.95, 2.45);
      s.roll = -5 * (1 - leanOff) - 2.5 * snooze;
      s.pitch = -3 * (1 - leanOff) - 4 * snooze;
      { const u = t / 1.25; if (u < 1) s.fx.push({ k: 'z', x: c.right - 4 + 6 * u, y: c.top + 2 - 11 * u, s: 1.3 + 0.4 * u, rot: -10 + 12 * u, a: 0.85 * (1 - u) }); }
      const rise = win(t, 0.05, 1.05), flare = env(t, 2.75, 2.9, 3.2, 3.6);
      const sunA = rise * (1 - win(t, 4.4, 5.05));
      if (sunA > 0.01) {
        s.fx.push({ k: 'sun', x: c.left - 8, y: c.top + 5 - 16 * rise, s: (1.25 + 0.4 * rise) * (1 + 0.12 * flare), r: win(t, 0.5, 1.2), glow: rise * (0.6 + 0.4 * flare), rot: 18 * t, a: sunA });
        if (flare > 0.01) { s.fx.push({ k: 'sparkle', x: c.left + 4, y: c.top - 18, s: 1.0 * flare, a: flare, c: PAL.gold }); s.fx.push({ k: 'sparkle', x: c.left - 17, y: c.top - 4, s: 0.7 * flare, a: flare, c: PAL.gold }); }
      }
      // 2) the light wakes it: squints, then shuts its eyes again; 3) opens for real, looks around, sees you
      if (t < 0.95) s.eyes = both({ k: 'sleep' });
      else if (t < 1.3) s.eyes = both(pill({ lid: 0.72, slant: -0.25 }));
      else if (t < 1.85) s.eyes = both({ k: 'sleep' });
      else if (t < 2.45) s.eyes = both(pill({ lid: lerp(0.62, 0.22, win(t, 1.9, 2.4)) }));
      else if (t < 2.7) s.eyes = both(pill({ sx: 1.07, sy: 1.07 }));
      else if (t < 3.95) s.eyes = both({ k: 'happy' });
      else s.eyes = both(pill({ sx: 1.03, sy: 1.03 }));
      const look = env(t, 1.95, 2.05, 2.15, 2.25) - env(t, 2.2, 2.3, 2.38, 2.45);
      s.gx = 0.8 * look; s.yaw = 7 * look;
      // the "oh, it's you" pop, then a bounce and a hello-sway, blushing a little
      s.lift = hop(t, 2.45, 2.62, 1.2) + hop(t, 2.72, 3.08, 2.6);
      s.sy *= 1 + ring(t, 3.08, -0.09, 0.3);
      s.sx *= 1 + ring(t, 3.08, 0.07, 0.3);
      s.roll += 6 * env(t, 3.15, 3.3, 3.85, 4.05) * Math.sin((t - 3.15) * 2 * Math.PI / 0.7);
      s.blush = 0.55 * env(t, 2.7, 2.95, 3.9, 4.3);
      setOpen(s, 1 - blink(t, 2.05, 0.18) - blink(t, 4.5, 0.2));
      return s;
    } },

  // ---------- 安慰 Low days (healing, never harsh) ----------
  { id: 'tired', zh: '有点累', group: 'care', dur: 4.4, key: 1.6, loop: true, use: '恢复分低 / 睡得少：慢悠悠的，不责怪',
    f(t, c) {
      const s = breathe(base(), t, 1.3);
      s.sy *= 0.97; s.sx *= 1.015;
      s.pitch = -4;
      s.roll = 2.5 * osc(t, 4.4);
      s.yaw = 3 * osc(t, 4.4, 0.8);
      s.gy = 0.35;
      s.eyes = both(pill({ lid: 0.42, slant: -0.6 }));
      setOpen(s, 1 - blink(t, 2.6, 0.45));
      const u = clamp((t - 0.6) / 2.6, 0, 1);
      if (u > 0 && u < 1) s.fx.push({ k: 'drop', x: c.right - c.w * 0.12, y: c.top + 4 + 6 * u, s: 1.9, a: env(u, 0, 0.15, 0.7, 1) });
      return s;
    } },
  { id: 'sad', zh: '有点失落', group: 'care', dur: 4.8, key: 1.6, loop: true, use: '好几天没打卡 / 断签当天：有点失落，你回来就好了',
    f(t) {
      const s = breathe(base(), t, 1.1);
      s.sy *= 0.965; s.sx *= 1.02;
      s.pitch = -6; s.gy = 0.45; s.gx = -0.15;
      s.roll = -3 + 1.5 * osc(t, 4.8); s.yaw = -5 + 2 * osc(t, 4.8, 0.7);
      const sigh = env(t, 1.0, 1.6, 1.7, 2.9);
      s.sy *= 1 + 0.035 * sigh; s.pitch += 3 * sigh;
      s.eyes = both(pill({ lid: 0.3, slant: -0.85, sy: 0.95 }));
      s.eyes[0].tear = 0.75 * env(t, 0.6, 1.4, 3.6, 4.4);
      setOpen(s, 1 - blink(t, 3.0, 0.5));
      return s;
    } },
  { id: 'cheerup', zh: '给你打气', group: 'care', dur: 3.8, key: 2.1, loop: true, use: '断签后重新开始 / 今天还差一点：给自己打足气，蹦起来为你加油',
    f(t, c) {
      const s = breathe(base(), t, 0.4);
      const P = [0.3, 0.75, 1.2];
      let puff = 0, press = 0;
      P.forEach((p0) => {
        press += env(t, p0, p0 + 0.07, p0 + 0.09, p0 + 0.2);
        puff += 0.03 * win(t, p0 + 0.09, p0 + 0.3);
      });
      puff *= 1 - win(t, 1.72, 1.82);
      s.sx *= 1 + puff + 0.05 * press; s.sy *= 1 + 0.75 * puff - 0.07 * press;
      s.pitch = -3 * press;
      s.lift = hop(t, 1.78, 2.42, 9);
      s.sy *= 1 + 0.07 * env(t, 1.76, 1.82, 1.86, 2.05) + ring(t, 2.42, -0.1, 0.3, 4);
      s.sx *= 1 + ring(t, 2.42, 0.08, 0.3, 4);
      s.pitch += 4 * env(t, 1.8, 2.0, 2.25, 2.45) - 6 * env(t, 2.95, 3.08, 3.1, 3.3);
      if (t > 0.2 && t < 1.78) s.eyes = both(pill({ slant: 0.7, lid: 0.16 }));
      else if (t >= 1.78 && t < 3.35) s.eyes = both({ k: 'happy', s: 1.08 });
      s.blush = 0.25 * win(t, 0.4, 1.5) * (1 - win(t, 1.7, 1.9)) + 0.5 * env(t, 1.85, 2.05, 3.0, 3.4);
      // a "+" pops out with every pump
      P.forEach((p0, i) => {
        const u = clamp((t - p0 - 0.06) / 0.55, 0, 1);
        if (u > 0 && u < 1) {
          const side = i % 2 ? 1 : -1;
          s.fx.push({ k: 'plus', x: c.cx + side * (c.w * 0.57 + 3 * u), y: c.top + c.h * 0.3 - 8 * u - i * 2, s: 1.6 + 0.5 * Math.sin(Math.PI * Math.min(1, u * 1.6)), a: env(u, 0, 0.1, 0.6, 1), c: PAL.accent });
        }
      });
      // the pop: three chevrons rise, two sparkles flash
      const g = clamp((t - 1.82) / 1.15, 0, 1);
      if (g > 0 && g < 1) {
        [-1, 0, 1].forEach((k, i) => s.fx.push({ k: 'up', x: c.cx + k * c.w * 0.34, y: c.top - 6 - 12 * g - (i === 1 ? 3 : 0), s: 1.7, a: env(g, 0, 0.12, 0.55, 1), c: PAL.accent }));
        const f = Math.sin(Math.PI * Math.min(1, g * 1.4));
        s.fx.push({ k: 'sparkle', x: c.cx - c.w * 0.6, y: c.top + 5, s: 1.4 * f, a: f, c: PAL.gold });
        s.fx.push({ k: 'sparkle', x: c.cx + c.w * 0.62, y: c.top + 2, s: 1.1 * f, a: f, c: PAL.gold });
      }
      setOpen(s, 1 - blink(t, 3.55, 0.2));
      return s;
    } },
];
const GROUPS = [
  { id: 'idle', zh: '待机', en: 'Idle', note: '首页没人碰时随机轮播' },
  { id: 'touch', zh: '互动', en: 'Touch', note: '点、长按、连点的反应' },
  { id: 'cheer', zh: '庆祝', en: 'Celebrate', note: '打卡和成就' },
  { id: 'sleep', zh: '睡觉', en: 'Bedtime', note: '睡前、睡着、醒来' },
  { id: 'care', zh: '安慰', en: 'Low days', note: '状态差时温柔陪伴' },
];

// ------------------------------------------------------------------------------------
// Drawing
// ------------------------------------------------------------------------------------
let uidN = 0;
/** Highlight and iris colours for an eye colour: white shine on dark eyes, a deep body-tone shine on light ones. */
const DARK_LOOK = { light: false, hl: '#fff', iris: '#3A4258' };
const LIGHT_GEM = 'shade'; // 星星眼 on light eyes: 'shade' (chosen 2026-11-07) or 'pearl'
function eyeMarkup(spec, i, w, h, ink, uid, look = DARK_LOOK) {
  const ph = 0.75 * h;
  const out = (i === 0 ? -1 : 1); // outer side of this eye, screen x
  let body = '';
  switch (spec.k) {
    case 'pill': {
      const W = w * (spec.sx ?? 1), H0 = ph * (spec.sy ?? 1);
      const open = clamp(spec.open ?? 1, 0, 1);
      const H = Math.max(W * 0.5, H0 * open);
      const y = -H / 2 + (H0 - H) * 0.18;
      let clip = '';
      const lid = spec.lid ?? 0, slant = spec.slant ?? 0;
      if (lid > 0.001 || Math.abs(slant) > 0.001) {
        const top = -H0 / 2 + lid * H0;
        // slant > 0: inner corner lower (determined); < 0: outer corner lower (soft, tired)
        const yIn = top + slant * H0 * 0.32, yOut = top - slant * H0 * 0.32;
        const xIn = -out * (W / 2 + 1), xOut = out * (W / 2 + 1);
        clip = `<clipPath id="${uid}"><path d="M${r2(xOut)} ${r2(yOut)}L${r2(xIn)} ${r2(yIn)}L${r2(xIn)} 40L${r2(xOut)} 40Z"/></clipPath>`;
      }
      body = `${clip}<rect x="${r2(-W / 2)}" y="${r2(y)}" width="${r2(W)}" height="${r2(H)}" rx="${r2(Math.min(W, H) / 2)}" fill="${ink}"${clip ? ` clip-path="url(#${uid})"` : ''}/>`;
      if (spec.hl === 'star' && H > W * 1.1) {
        // four-pointed cross star (十字星); it slides a little with the head (hlX/hlY), and stays inside the eye
        const R = W * 0.43 * (spec.hlS ?? 1);
        const hx = W * (spec.hlX ?? 0), hy = y + H * (0.3 + (spec.hlY ?? 0));
        if (R > 0.05) {
          body += `<clipPath id="${uid}p"><rect x="${r2(-W / 2)}" y="${r2(y)}" width="${r2(W)}" height="${r2(H)}" rx="${r2(Math.min(W, H) / 2)}"/></clipPath>`;
          const star = `<path transform="translate(${r2(hx)} ${r2(hy)}) scale(${r2(R / 3.4)})" d="M0-3.4Q0.5-0.5 3.4 0Q0.5 0.5 0 3.4Q-0.5 0.5-3.4 0Q-0.5-0.5 0-3.4Z" fill="${look.hl}"${clip ? ` clip-path="url(#${uid})"` : ''}/>`;
          body += `<g clip-path="url(#${uid}p)">${star}</g>`;
        }
      } else if (spec.hl && H > W * 1.1 && (spec.hlS ?? 1) > 0.02) body += `<circle cx="${r2(W * 0.14)}" cy="${r2(y + H * 0.26)}" r="${r2(W * 0.2 * (spec.hlS ?? 1))}" fill="${look.hl}" opacity=".92"${clip ? ` clip-path="url(#${uid})"` : ''}/>`;
      break;
    }
    case 'happy': {
      const s = spec.s ?? 1, hw = 0.72 * w * s, b = 0.1 * h, pk = 0.42 * h * (spec.peak ?? 1);
      body = `<path d="M${r2(-hw)} ${r2(b)}Q0 ${r2(-pk)} ${r2(hw)} ${r2(b)}" fill="none" stroke="${ink}" stroke-width="${r2(0.6 * w)}" stroke-linecap="round"/>`;
      break;
    }
    case 'sleep': {
      const s = spec.s ?? 1, hw = 0.7 * w * s;
      body = `<path d="M${r2(-hw)} ${r2(-0.02 * h)}Q0 ${r2(0.3 * h)} ${r2(hw)} ${r2(-0.02 * h)}" fill="none" stroke="${ink}" stroke-width="${r2(0.52 * w)}" stroke-linecap="round"/>`;
      break;
    }
    case 'chev': {
      const s = spec.s ?? 1, dx = 0.55 * w * s, dy = 0.25 * h * s, d = -out; // tip points inward
      body = `<path d="M${r2(-d * dx)} ${r2(-dy)}L${r2(d * dx)} 0L${r2(-d * dx)} ${r2(dy)}" fill="none" stroke="${ink}" stroke-width="${r2(0.55 * w)}" stroke-linecap="round" stroke-linejoin="round"/>`;
      break;
    }
    case 'star': {
      const R = 0.4 * ph * (spec.s ?? 1), r = R * 0.48;
      let d = '';
      for (let k = 0; k < 10; k++) {
        const a = -Math.PI / 2 + (k * Math.PI) / 5, rr = k % 2 ? r : R;
        d += `${k ? 'L' : 'M'}${r2(Math.cos(a) * rr)} ${r2(Math.sin(a) * rr)}`;
      }
      body = `<path d="${d}Z" fill="${ink}" stroke="${ink}" stroke-width="${r2(R * 0.18)}" stroke-linejoin="round" transform="rotate(${r2(spec.rot ?? 0)})"/>`;
      break;
    }
    case 'gem': {
      // Round shiny eye (toned down from the first anime version): a little bigger than the normal
      // eye, a faint lighter low half, one big and one small highlight.
      const R = 0.5 * ph * (spec.s ?? 1), sh = spec.shine ?? 0;
      const cid = `${uid}g`;
      if (look.light) {
        // light eyes (黑巧克力) stay light: a soft warm shade under the top edge lets the white shine show,
        // and a faint glow sits low in the eye. ('pearl' = the radial-gradient alternative.)
        const hl1 = `<circle cx="${r2(-R * 0.28)}" cy="${r2(-R * 0.28)}" r="${r2(R * (0.3 + 0.02 * sh))}" fill="#fff"/>`;
        const hl2 = `<circle cx="${r2(R * 0.34)}" cy="${r2(R * 0.3)}" r="${r2(R * 0.12)}" fill="#fff" opacity=".95"/>`;
        if (LIGHT_GEM === 'pearl') {
          body = `<radialGradient id="${cid}r" cx=".42" cy=".4" r=".62"><stop offset=".35" stop-color="${ink}"/><stop offset="1" stop-color="${look.warm}"/></radialGradient>`
            + `<circle r="${r2(R)}" fill="url(#${cid}r)"/>${hl1}${hl2}`;
        } else {
          body = `<clipPath id="${cid}"><circle r="${r2(R)}"/></clipPath><circle r="${r2(R)}" fill="${ink}"/>`
            + `<circle cy="${r2(-R * 0.95)}" r="${r2(R * 1.05)}" fill="${look.warm}" clip-path="url(#${cid})"/>`
            + `<ellipse cx="0" cy="${r2(R * 0.66)}" rx="${r2(R * 0.6)}" ry="${r2(R * 0.3)}" fill="#fff" opacity=".55" clip-path="url(#${cid})"/>`
            + hl1 + hl2;
        }
        break;
      }
      body = `<clipPath id="${cid}"><circle r="${r2(R)}"/></clipPath><circle r="${r2(R)}" fill="${ink}"/>`
        + `<ellipse cx="0" cy="${r2(R * 0.62)}" rx="${r2(R * 0.72)}" ry="${r2(R * 0.42)}" fill="${look.iris}" opacity=".85" clip-path="url(#${cid})"/>`
        + `<circle cx="${r2(-R * 0.28)}" cy="${r2(-R * 0.28)}" r="${r2(R * (0.3 + 0.02 * sh))}" fill="#fff"/>`
        + `<circle cx="${r2(R * 0.34)}" cy="${r2(R * 0.3)}" r="${r2(R * 0.12)}" fill="#fff" opacity=".9"/>`;
      break;
    }
    case 'heart': {
      const k = 0.48 * ph * (spec.s ?? 1);
      body = `<path transform="scale(${r2(k)})" d="M0 0.95C-0.35 0.62-1 0.18-1-0.3C-1-0.68-0.72-0.95-0.38-0.95C-0.18-0.95-0.06-0.85 0-0.72C0.06-0.85 0.18-0.95 0.38-0.95C0.72-0.95 1-0.68 1-0.3C1 0.18 0.35 0.62 0 0.95Z" fill="#E8546B"/>`;
      break;
    }
    case 'spiral': {
      const R = 0.44 * ph; let d = '';
      for (let k = 0; k <= 48; k++) { const u = k / 48, a = u * Math.PI * 2 * 1.6, rr = R * (0.12 + 0.88 * u); d += `${k ? 'L' : 'M'}${r2(Math.cos(a) * rr)} ${r2(Math.sin(a) * rr)}`; }
      body = `<path d="${d}" fill="none" stroke="${ink}" stroke-width="${r2(0.27 * w)}" stroke-linecap="round" stroke-linejoin="round" transform="rotate(${r2(spec.rot ?? 0)})"/>`;
      break;
    }
    case 'line':
      body = `<path d="M${r2(-0.7 * w)} 0L${r2(0.7 * w)} 0" stroke="${ink}" stroke-width="${r2(0.55 * w)}" stroke-linecap="round"/>`;
      break;
  }
  if (spec.squash != null && spec.squash < 0.999) body = `<g transform="scale(1 ${r2(Math.max(0.06, spec.squash))})">${body}</g>`;
  if (spec.tear > 0.02) {
    const k = 0.9 * spec.tear;
    body += `<path transform="translate(${r2(out * 0.95 * w)} ${r2(0.22 * h)}) scale(${r2(k)})" d="M0-1.9C0.7-0.8 1.2-0.1 1.2 0.6C1.2 1.3 0.65 1.8 0 1.8C-0.65 1.8-1.2 1.3-1.2 0.6C-1.2-0.1-0.7-0.8 0-1.9Z" fill="${PAL.drop}"/>`;
  }
  return body;
}

// ------------------------------------------------------------------------------------
// Effects (v3, 2026-11-07): every effect is a small extruded token in the same spirit as the
// slice pets: a face, a thicker side in a deeper tone of the same colour (lit from above), and a
// small highlight. Tokens can turn (fx.yaw, degrees): the face narrows like a coin and the side
// shows, so stars, notes, hearts and confetti read as little 3D things, not flat stickers.
// ------------------------------------------------------------------------------------
const hexOf = (c) => {
  let h = String(c || '#000').trim().replace('#', '');
  if (h.length === 3) h = h.split('').map((x) => x + x).join('');
  return '#' + h.slice(0, 6).padEnd(6, '0');
};
const rgbOf = (c) => { const n = parseInt(hexOf(c).slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; };
const mixC = (a, b, k) => { const A = rgbOf(a), B = rgbOf(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * k).toString(16).padStart(2, '0')).join(''); };
/** The side of a token: same hue, deeper (in HSL, so gold turns amber, not olive). */
function shadeC(c, k = 0.3) {
  const [r, g, b] = rgbOf(c).map((v) => v / 255), mx = Math.max(r, g, b), mn = Math.min(r, g, b);
  let h = 0, sat = 0, l = (mx + mn) / 2;
  if (mx !== mn) {
    const d = mx - mn;
    sat = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
    h /= 6;
  }
  l *= 1 - k; sat *= 1 - 0.6 * k;
  const q = l < 0.5 ? l * (1 + sat) : l + sat - l * sat, p = 2 * l - q;
  const f = (t) => { t = (t + 1) % 1; return t < 1 / 6 ? p + (q - p) * 6 * t : t < 0.5 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p; };
  return '#' + [f(h + 1 / 3), f(h), f(h - 1 / 3)].map((v) => Math.round(v * 255).toString(16).padStart(2, '0')).join('');
}
/** A soft glow without a filter: a few faint discs. */
const glow = (r, c, a = 1) => [0.36, 0.52, 0.68, 0.84, 1].map((k) => `<circle r="${r2(r * k)}" fill="${c}" opacity="${r2(0.06 * a)}"/>`).join('');
const tintC = (c, k = 0.5) => mixC(c, '#FFFFFF', k);
/** Ease out with a little overshoot: 0 at a, settles to 1 at b. */
const popIn = (u, a = 0, b = 0.2) => {
  const x = clamp((u - a) / (b - a), 0, 1), c1 = 1.9;
  return x <= 0 ? 0 : 1 + (c1 + 1) * (x - 1) ** 3 + c1 * (x - 1) ** 2;
};
/**
 * One token. ds = path data (string or list), face colour, o.dep = thickness (local units),
 * o.yaw = turn in degrees, o.sw = stroke width (stroked shapes like "?" and "+"), o.round = round the
 * corners of a filled shape, o.hl = highlight markup (drawn on the face), o.side = side colour.
 */
function tok(ds, face, o = {}) {
  const list = Array.isArray(ds) ? ds : [ds];
  const yaw = (o.yaw ?? 0) * D2R, cy = Math.cos(yaw), sy = Math.sin(yaw);
  const sx = Math.sign(cy || 1) * Math.max(0.12, Math.abs(cy));
  const dep = o.dep ?? 0.6, dx = -sy * dep * 1.4, dy = dep;
  const side = o.side ?? shadeC(face, cy < 0 ? 0.42 : 0.3);
  const fc = cy < 0 && o.back ? o.back : face;
  const paint = (c) => (o.sw
    ? `fill="none" stroke="${c}" stroke-width="${o.sw}" stroke-linecap="round" stroke-linejoin="round"`
    : o.round ? `fill="${c}" stroke="${c}" stroke-width="${o.round}" stroke-linejoin="round"` : `fill="${c}"`);
  const paths = (c) => list.map((d) => `<path d="${d}" ${paint(c)}/>`).join('');
  const sidePaths = paths(side);
  let out = '';
  for (const k of [1, 0.5]) out += `<g transform="translate(${r2(dx * k)} ${r2(dy * k)}) scale(${r2(sx)} 1)">${sidePaths}</g>`;
  return `${out}<g transform="scale(${r2(sx)} 1)">${paths(fc)}${cy > 0.2 && o.hl ? `<g opacity="${r2(clamp((cy - 0.2) / 0.5, 0, 1))}">${o.hl}</g>` : ''}</g>`;
}
const HL = (cx, cy, rx, ry, rot = -30, op = 0.75) => `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" transform="rotate(${rot} ${cx} ${cy})" fill="#fff" opacity="${op}"/>`;
const circleD = (cx, cy, r) => `M${r2(cx - r)} ${r2(cy)}A${r2(r)} ${r2(r)} 0 1 0 ${r2(cx + r)} ${r2(cy)}A${r2(r)} ${r2(r)} 0 1 0 ${r2(cx - r)} ${r2(cy)}Z`;
const ellipseD = (cx, cy, rx, ry, rot) => {
  const a = rot * D2R, ux = Math.cos(a) * rx, uy = Math.sin(a) * rx;
  return `M${r2(cx - ux)} ${r2(cy - uy)}A${r2(rx)} ${r2(ry)} ${rot} 1 0 ${r2(cx + ux)} ${r2(cy + uy)}A${r2(rx)} ${r2(ry)} ${rot} 1 0 ${r2(cx - ux)} ${r2(cy - uy)}Z`;
};
const starD = (R, r) => {
  let d = '';
  for (let k = 0; k < 10; k++) { const an = -Math.PI / 2 + (k * Math.PI) / 5, rr = k % 2 ? r : R; d += `${k ? 'L' : 'M'}${r2(Math.cos(an) * rr)} ${r2(Math.sin(an) * rr)}`; }
  return d + 'Z';
};
const STAR_D = starD(2.35, 1.2);
const HEART_D = 'M0 2.05C-0.75 1.38-2.2 0.42-2.2-0.66C-2.2-1.5-1.58-2.08-0.84-2.08C-0.4-2.08-0.13-1.87 0-1.58C0.13-1.87 0.4-2.08 0.84-2.08C1.58-2.08 2.2-1.5 2.2-0.66C2.2 0.42 0.75 1.38 0 2.05Z';
const NOTE1_D = [ellipseD(-1.2, 2.55, 1.5, 1.08, -22), 'M0.02 2.3V-3.75H0.78V2.3Z', 'M0.7-3.75C2.05-3.15 3.15-2.2 2.85-0.3C2.45-1.4 1.65-1.85 0.7-1.95Z'];
const NOTE2_D = [ellipseD(-2.25, 2.75, 1.38, 1.0, -22), ellipseD(1.95, 2.05, 1.38, 1.0, -22), 'M-1.17 2.55V-2.9H-0.47V2.55Z', 'M3.03 1.85V-3.6H3.73V1.85Z', 'M-1.17-1.75L3.73-2.45V-3.65L-1.17-2.95Z'];
const Z_D = 'M-1.85-2.05H1.85V-1.05L-0.55 1.05H1.85V2.05H-1.85V1.05L0.55-1.05H-1.85Z';
const DROP_D = 'M0-2.6C0.9-1.15 1.6-0.25 1.6 0.8C1.6 1.75 0.9 2.4 0 2.4C-0.9 2.4-1.6 1.75-1.6 0.8C-1.6-0.25-0.9-1.15 0-2.6Z';
const SPARK_D = 'M0-3.8Q0.58-0.58 3.1 0Q0.58 0.58 0 3.8Q-0.58 0.58-3.1 0Q-0.58-0.58 0-3.8Z';
const CLOUD_L = [[-6.2, 1.2, 4.2], [-2.6, -2.2, 4.8], [2.4, -2.4, 4.6], [6.2, 0.6, 4.1], [3.2, 3.4, 3.9], [-2.4, 3.6, 4.0]];
const PUFF_D = [[-2.0, 0.55, 1.35], [-0.55, -0.45, 1.85], [1.25, -0.1, 1.55], [2.45, 0.7, 1.15]].map(([x, y, r]) => circleD(x, y, r))
  .concat(['M-2.45 0.5H2.75A0.75 0.75 0 0 1 2.75 2H-2.45A0.75 0.75 0 0 1 -2.45 0.5Z']);

function fxMarkup(fx) {
  const a = r2(clamp(fx.a ?? 1, 0, 1));
  if (a <= 0) return '';
  const tr = `translate(${r2(fx.x)} ${r2(fx.y)}) rotate(${r2(fx.rot ?? 0)}) scale(${r2(fx.s ?? 1)})`;
  const g = (inner) => `<g transform="${tr}" opacity="${a}">${inner}</g>`;
  switch (fx.k) {
    case 'note': // ♪ / ♫, turning a little as it floats
      return g(tok(fx.flip ? NOTE2_D : NOTE1_D, fx.c, { dep: 0.55, yaw: fx.yaw, hl: fx.flip ? HL(-2.6, 2.35, 0.5, 0.24) + HL(1.6, 1.65, 0.5, 0.24) : HL(-1.6, 2.15, 0.55, 0.26) }));
    case 'sparkle': { // a slim four-point glint with a soft glow and a bright core
      const c = fx.c ?? PAL.gold;
      return g(`${glow(3.2, c)}<path d="${SPARK_D}" fill="${c}"/><path d="${SPARK_D}" fill="${tintC(c, 0.62)}" transform="scale(.26)"/>`);
    }
    case 'star': // a chubby rounded star that spins like a coin
      return g(tok(STAR_D, fx.c ?? PAL.gold, { dep: 0.6, yaw: fx.yaw, round: 0.95, side: shadeC(fx.c ?? PAL.gold, 0.2), hl: HL(-0.55, -0.55, 0.55, 0.3, -35) }));
    case 'orbit': { // the faint ring the dizzy stars ride on (front or back half)
      const rx = fx.rx, ry = fx.ry, top = fx.half === 'back';
      return `<path d="M${r2(fx.x - rx)} ${r2(fx.y)}A${r2(rx)} ${r2(ry)} 0 0 ${top ? 1 : 0} ${r2(fx.x + rx)} ${r2(fx.y)}" fill="none" stroke="${PAL.gold}" stroke-width=".42" stroke-linecap="round" stroke-dasharray=".1 1.5" opacity="${r2(a * (top ? 0.35 : 0.6))}"/>`;
    }
    case 'heart':
      return g(tok(HEART_D, PAL.heart, { dep: 0.6, yaw: fx.yaw, hl: HL(-1.05, -1.15, 0.5, 0.28, -40) }));
    case 'z': // a chunky Z, night blue
      return g(tok(Z_D, PAL.night, { dep: 0.5, yaw: fx.yaw, round: 0.55 }));
    case 'drop':
      return g(tok(DROP_D, PAL.drop, { dep: 0.45, hl: HL(-0.55, 0.3, 0.32, 0.62, 20, 0.8) }));
    case 'tdot': // the little bubbles that lead up to a thought
      return g(tok(circleD(0, 0, 1), PAL.bubble, { dep: 0.32, side: shadeC(PAL.bubble, 0.16) }));
    case 'thought': {
      // A puffy cloud bubble with a small patch of sky inside, and one little cloud drifting across it.
      const side = mixC(PAL.bubble, PAL.cloud, 0.45);
      const lobes = (c, dy) => CLOUD_L.map(([x, y, r]) => `<circle cx="${x}" cy="${r2(y + dy)}" r="${r}" fill="${c}"/>`).join('');
      const d = fx.drift ?? 0, cx = -2.6 + 5.2 * (0.5 - 0.5 * Math.cos(Math.PI * clamp(d, 0, 1))), cyy = 0.4 + 0.3 * Math.sin(d * 9);
      const puff = tok(PUFF_D, PAL.puff, { dep: 0.6, side: PAL.cloud });
      return g(`${lobes(side, 1.0)}${lobes(PAL.bubble, 0)}<ellipse cx="0" cy="0.5" rx="7.3" ry="4.5" fill="${shadeC(PAL.sky, 0.07)}"/><ellipse cx="0" cy="0.78" rx="7.2" ry="4.22" fill="${PAL.sky}"/>`
        + `<g transform="translate(${r2(cx)} ${r2(cyy)}) scale(1.2)">${puff}</g>`
        + HL(-5.6, -2.6, 1.6, 0.5, -28, 0.9));
    }
    case 'sun': {
      // morning sun: a glow, a round core with a highlight, and eight rounded rays that grow in with fx.r
      const rr = clamp(fx.r ?? 1, 0, 1), gl = fx.glow ?? 0;
      let rays = '';
      for (let k = 0; k < 8; k++) {
        const an = (k * Math.PI) / 4, r0 = 3.6, r1 = 3.6 + 2.0 * rr;
        rays += `M${r2(Math.cos(an) * r0)} ${r2(Math.sin(an) * r0)}L${r2(Math.cos(an) * r1)} ${r2(Math.sin(an) * r1)}`;
      }
      return g(`${glow(7, PAL.sun, 1.3 * gl)}`
        + (rr > 0.02 ? `<path d="${rays}" stroke="${PAL.sun}" stroke-width="1.15" stroke-linecap="round" opacity="${r2(rr)}"/>` : '')
        + tok(circleD(0, 0, 2.6), PAL.sun, { dep: 0.45, hl: HL(-0.85, -0.9, 0.75, 0.4, -35, 0.7) }));
    }
    case 'plus':
      return g(tok('M-1.55 0H1.55M0-1.55V1.55', fx.c, { sw: 1.2, dep: 0.42 }));
    case 'up':
      return g(tok('M-1.8 0.95L0-0.85L1.8 0.95', fx.c, { sw: 1.1, dep: 0.42 }));
    case 'q':
      return g(tok('M-1.45-1.75C-1.45-3.5 1.6-3.6 1.6-1.6C1.6-0.35 0.05-0.25 0.05 0.95', fx.c, { sw: 1.15, dep: 0.45 })
        + tok(circleD(0.05, 2.75, 0.72), fx.c, { dep: 0.45 }));
    case 'dot': // the bored "…": three soft beads
      return g(tok(circleD(0, 0, 1), tintC(PAL.ink2, 0.2), { dep: 0.28, side: shadeC(PAL.ink2, 0.1) }));
    case 'burst': { // surprise marks: three tapered strokes thrown outward
      const L = fx.l ?? 1;
      return g([-40, 0, 40].map((ang) => `<path transform="rotate(${ang})" d="M0 ${r2(-3.6 - 0.3 * L)}L0.78 ${r2(-3.6 - 3.9 * L)}A0.78 0.78 0 0 0 -0.78 ${r2(-3.6 - 3.9 * L)}Z" fill="${PAL.line}"/>`).join(''));
    }
    case 'conf': { // paper confetti: strips and curls flutter (two-sided), sequins shine
      const flip = fx.flip ?? 0, c = fx.c;
      if (fx.shape === 1) return g(`<circle cy=".38" r="1.3" fill="${shadeC(c, 0.22)}"/><circle r="1.3" fill="${c}"/>${HL(-0.4, -0.45, 0.42, 0.22, -30, 0.7)}`);
      const cs = Math.cos(flip * D2R), k = Math.sign(cs || 1) * Math.max(0.1, Math.abs(cs));
      const col = cs < 0 ? shadeC(c, 0.16) : c;
      const body = fx.shape === 0
        ? `<rect x="-2.3" y="-1.05" width="4.6" height="2.1" rx=".4" fill="${col}"/>`
        : `<path d="M-2.5 0.7C-1.5-1.1-0.5 1.4 0.5-0.4S2.2-0.7 2.6 0.8" fill="none" stroke="${col}" stroke-width=".95" stroke-linecap="round"/>`;
      return g(`<g transform="scale(1 ${r2(k)})">${body}</g>`);
    }
  }
  return '';
}

// ------------------------------------------------------------------------------------
// A pet on a stage: mount once, then frame(state) as often as wanted.
// ------------------------------------------------------------------------------------
const hexRgb = (hex) => { const n = parseInt(hex.replace('#', '').padEnd(6, '0').slice(0, 6), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; };
const luma = (hex) => { const [r, g, b] = hexRgb(hex); return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255; };
function eyeLook(ink, bodyColor = '#5a3221') {
  if (luma(ink) < 0.55) return DARK_LOOK;
  const deep = '#' + hexRgb(bodyColor).map((v) => Math.round(v * 0.62).toString(16).padStart(2, '0')).join('');
  const [r1, g1, b1] = hexRgb(ink), [r0, g0, b0] = hexRgb(bodyColor);
  const warm = '#' + [[r1, r0], [g1, g0], [b1, b0]].map(([x, y]) => Math.round(x + (y - x) * 0.32).toString(16).padStart(2, '0')).join('');
  return { light: true, hl: deep, iris: deep, warm };
}

// ------------------------------------------------------------------------------------
// Floor (2026-11-07). Everywhere: a soft contact shadow (gradient, a tight core under the feet and a
// wide penumbra) instead of a flat grey oval. Home stage only (rug: true): a small floor piece in the
// style chosen by FLOOR_STYLE below. The pet's shadow on it is a deeper jade, and it gives a little
// when the pet lands.
// ------------------------------------------------------------------------------------
const RUG = { rx: 47, ry: 9.9, dep: 0.85, border: 0.84 };
function floorColors(rug) {
  const canvas = PAL.canvas, dark = luma(hexOf(canvas)) < 0.4;
  // a soft sage felt from the jade accent; the border band one step deeper
  const face = dark ? mixC(canvas, PAL.accent, 0.2) : mixC(mixC(canvas, PAL.accent, 0.2), '#B9D2A6', 0.28);
  const band = dark ? mixC(canvas, PAL.accent, 0.27) : shadeC(face, 0.06);
  return {
    dark, face, band,
    top: dark ? mixC(face, PAL.accent, 0.06) : mixC(face, '#FFFFFF', 0.3),
    side: shadeC(band, dark ? 0.35 : 0.14),
    stitch: dark ? mixC(face, PAL.accent, 0.55) : mixC(face, PAL.accent, 0.42),
    ao: [PAL.shadow, dark ? 0.5 : 0.12],
    sh: rug ? [shadeC(mixC(face, PAL.accent, 0.5), dark ? 0.55 : 0.3), dark ? 0.75 : 0.36] : [PAL.shadow, dark ? 0.6 : 0.2],
  };
}
// Home-stage floor styles, all in the pets' own slice language (flat face, same-hue deeper side):
//   pad    a thin flat slice: one flat face over a slightly deeper side, nothing else
//   disc   just the flat face, no side
//   shadow no rug, only the pet's soft shadow
//   felt   the stitched felt rug (first version, kept for comparison)
const FLOOR_STYLE = 'disc';
const PAD = { rx: 38, ry: 7.8, dep: 1.5 };
function floorMarkup(id, cx, cy, rug) {
  const style = rug ? FLOOR_STYLE : 'none';
  const c = floorColors(rug && style !== 'shadow');
  const grad = (gid, [col, a], mid = 0.45) => `<radialGradient id="${gid}" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="${col}" stop-opacity="${r2(a)}"/><stop offset="${mid}" stop-color="${col}" stop-opacity="${r2(a * 0.5)}"/><stop offset="1" stop-color="${col}" stop-opacity="0"/></radialGradient>`;
  let defs = grad(`${id}sh`, c.sh);
  if (style === 'none' || style === 'shadow') return `<defs>${defs}</defs>`;
  if (style === 'pad' || style === 'disc') {
    const { rx, ry, dep } = PAD;
    // a pale sage face; the side is the same hue one step deeper, like the pets' own sides
    const face = c.dark ? mixC(PAL.canvas, PAL.accent, 0.22) : mixC(mixC(PAL.canvas, PAL.accent, 0.17), '#B9D2A6', 0.25);
    const side = shadeC(face, c.dark ? 0.22 : 0.24);
    const e = (dy, fill) => `<ellipse cx="${r2(cx)}" cy="${r2(cy + dy)}" rx="${rx}" ry="${ry}" fill="${fill}"/>`;
    return `<defs>${defs}</defs><g data-rug>`
      + (style === 'pad' ? e(dep, side) + `<rect x="${r2(cx - rx)}" y="${r2(cy)}" width="${2 * rx}" height="${dep}" fill="${side}"/>` : '')
      + e(0, face) + `</g>`;
  }
  const { rx, ry, dep, border } = RUG;
  defs += grad(`${id}ao`, c.ao, 0.55)
    + `<radialGradient id="${id}face" cx=".5" cy=".45" r=".55"><stop offset="0" stop-color="${c.top}"/><stop offset=".7" stop-color="${mixC(c.top, c.face, 0.7)}"/><stop offset="1" stop-color="${c.face}"/></radialGradient>`;
  const e = (sc, attrs, dy = 0) => `<ellipse cx="${r2(cx)}" cy="${r2(cy + dy)}" rx="${r2(rx * sc)}" ry="${r2(ry * sc)}" ${attrs}/>`;
  const stitchAt = (sc) => e(sc, `fill="none" stroke="${c.stitch}" stroke-width=".42" stroke-dasharray="1.7 1.1" stroke-linecap="round" opacity=".75"`);
  return `<defs>${defs}</defs><g data-rug>`
    + `<ellipse cx="${r2(cx)}" cy="${r2(cy + dep + 0.6)}" rx="${r2(rx + 2.2)}" ry="${r2(ry + 1.6)}" fill="url(#${id}ao)"/>`
    + e(1, `fill="${c.side}"`, dep)
    + `<rect x="${r2(cx - rx)}" y="${r2(cy)}" width="${2 * rx}" height="${dep}" fill="${c.side}"/>`
    + e(1, `fill="${c.band}"`)
    + e(border, `fill="url(#${id}face)"`)
    + stitchAt(0.955) + stitchAt(border - 0.035)
    + `</g>`;
}
function mountPet(stage, pet, { shadow = true, rug = false } = {}) {
  const def = validateAvatar(pet.def).value;
  const depth = pet.depth;
  // Build the smooth slices now (cached), so the first frame already uses them.
  smoothPlan(def, depth);
  stage.innerHTML = '';
  stage.style.position = 'relative';
  const under = document.createElementNS(SVG_NS, 'svg');
  under.setAttribute('viewBox', '0 0 100 100');
  under.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;overflow:visible;pointer-events:none';
  const host = document.createElement('div');
  host.style.cssText = 'position:absolute;inset:0';
  const over = document.createElementNS(SVG_NS, 'svg');
  over.setAttribute('viewBox', '0 0 100 100');
  over.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;overflow:visible;pointer-events:none';
  const floor = document.createElementNS(SVG_NS, 'svg');
  floor.setAttribute('viewBox', '0 0 100 100');
  floor.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;overflow:visible;pointer-events:none';
  stage.append(floor, under, host, over);
  host.innerHTML = renderAvatarScene(def, { depth });
  host.style.color = pet.color;
  smoothSlices(host, def, depth);
  paintParts(host, def, pet.partColors, pet.paints, depth);
  alignSlices(host);
  // Paint overlays share the slice's outline, so each slice edge anti-aliases twice (base color,
  // then paint) and a light hairline shows at every slice edge of a painted band. A thin stroke in
  // the paint color covers the base's edge pixels.
  const sealPaint = () => host.querySelectorAll('[data-stack] svg path[clip-path]:not([data-seal])').forEach((pa) => {
    pa.dataset.seal = '1';
    pa.setAttribute('stroke', pa.getAttribute('fill'));
    pa.setAttribute('stroke-width', '0.7');
    pa.setAttribute('stroke-linejoin', 'round');
  });
  sealPaint();
  new MutationObserver(sealPaint).observe(host, { childList: true, subtree: true });
  const { vol } = preparedVolume(def, depth);
  const q = (s) => host.querySelector(s);
  const stacks = { z: q('[data-stack="z"]'), x: q('[data-stack="x"]') };
  const b = vol.bounds;
  const ink = pet.eyeColor || '#151515';
  const look = eyeLook(ink, pet.color);
  const w = EYE_W * vol.eyeScale, h = EYE_H * vol.eyeScale;
  const eyes = [0, 1].map((i) => {
    const root = q(`[data-eye="${i}"]`);
    root.querySelector('i').style.display = 'none';
    root.querySelector('svg').style.display = 'none';
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('viewBox', `${r2(-w / 2)} ${r2(-h / 2)} ${r2(w)} ${r2(h)}`);
    svg.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;overflow:visible';
    root.appendChild(svg);
    return { root, svg, last: '' };
  });
  // Face plane (blush, mouth) at the height of the eyes.
  const faceZ = Math.max(...vol.eyeZ) + EYE_LIFT - 0.2;
  const face = document.createElement('div');
  face.style.cssText = `position:absolute;left:0;top:0;width:100%;height:100%;backface-visibility:hidden;transform:translateZ(${U(faceZ)})`;
  const faceSvg = document.createElementNS(SVG_NS, 'svg');
  faceSvg.setAttribute('viewBox', '0 0 100 100');
  faceSvg.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;overflow:visible';
  face.appendChild(faceSvg);
  q('[data-view]').appendChild(face);
  const motionEl = q('[data-motion]');
  motionEl.style.transformOrigin = '0 0';
  const anchors = {
    cx: (b.minX + b.maxX) / 2, cy: (b.minY + b.maxY) / 2, top: b.minY, bottom: b.maxY, left: b.minX, right: b.maxX,
    w: b.maxX - b.minX, h: b.maxY - b.minY, ey: def.eyes.y,
  };
  const centers = [def.eyes.x - def.eyes.spacing / 2, def.eyes.x + def.eyes.spacing / 2];
  const uid = `x${++uidN}`;
  let last = {};
  const put = (key, el, prop, v) => { if (last[key] !== v) { last[key] = v; el.style[prop] = v; } };

  function frame(st) {
    const size = host.clientWidth || undefined;
    const f = sceneFrame(def, {
      depth, size, reducedMotion: true,
      view: { yaw: st.yaw * D2R - BASE_YAW, pitch: st.pitch * D2R - BASE_PITCH },
      gaze: { x: clamp(st.gx, -1, 1), y: clamp(st.gy, -1, 1), weight: 1 },
    });
    put('view', q('[data-view]'), 'transform', f.view);
    put('sz', stacks.z, 'display', f.stack === 'z' ? 'block' : 'none');
    put('sx', stacks.x, 'display', f.stack === 'x' ? 'block' : 'none');
    const els = [...stacks[f.stack].children];
    f.slices.forEach((shown, i) => els[i] && put(`${f.stack}${i}`, els[i], 'display', shown ? 'block' : 'none'));
    const { cx, bottom, cy } = anchors;
    const tf = `translate(0,${U(st.lift)}) translate(${U(cx)},${U(bottom)}) rotate(${r2(st.roll)}deg) scale(${r2(st.sx * 10000) / 10000},${r2(st.sy * 10000) / 10000}) translate(${U(-cx)},${U(-bottom)}) translate(${U(cx)},${U(cy)}) rotate(${r2(st.spin)}deg) translate(${U(-cx)},${U(-cy)})`;
    put('motion', motionEl, 'transform', tf);
    f.eyes.forEach((e, i) => {
      put(`et${i}`, eyes[i].root, 'transform', e.transform);
      put(`ev${i}`, eyes[i].root, 'visibility', e.visible ? 'visible' : 'hidden');
      const m = eyeMarkup(st.eyes[i], i, w, h, ink, `${uid}e${i}`, look);
      if (m !== eyes[i].last) { eyes[i].last = m; eyes[i].svg.innerHTML = m; }
    });
    // face: blush + mouth
    let fm = '';
    if (st.blush > 0.01) {
      const at = st.blushAt ?? { dx: 0.95, dy: 0.62 };
      centers.forEach((x, i) => {
        const o = i === 0 ? -1 : 1;
        const bx = x + o * w * at.dx, by = def.eyes.y + 0.75 * h * at.dy;
        fm += `<ellipse cx="${r2(bx)}" cy="${r2(by)}" rx="${r2(w * 0.95)}" ry="${r2(w * 0.5)}" fill="${PAL.blush}" opacity="${r2(0.55 * st.blush)}"/>`;
        if (st.blushLines) {
          [-1, 0, 1].forEach((k) => {
            const lx = bx + k * w * 0.42;
            fm += `<path d="M${r2(lx + w * 0.14)} ${r2(by - w * 0.26)}L${r2(lx - w * 0.14)} ${r2(by + w * 0.26)}" stroke="${PAL.blushLine}" stroke-width="${r2(w * 0.09)}" stroke-linecap="round" opacity="${r2(0.75 * st.blush * st.blushLines)}"/>`;
          });
        }
      });
    }
    if (st.mouth && st.mouth.k === 'w') {
      const sm2 = st.mouth.small ? 0.72 : 1;
      const a = w * 0.42 * sm2, d = w * 0.36 * sm2, my = def.eyes.y + 0.75 * h * 0.62, sw = w * 0.17 * (st.mouth.small ? 0.85 : 1);
      fm += `<path d="M${r2(def.eyes.x - 2 * a)} ${r2(my - d * 0.15)}Q${r2(def.eyes.x - 2 * a)} ${r2(my + d)} ${r2(def.eyes.x - a)} ${r2(my + d)}Q${r2(def.eyes.x)} ${r2(my + d)} ${r2(def.eyes.x)} ${r2(my)}Q${r2(def.eyes.x)} ${r2(my + d)} ${r2(def.eyes.x + a)} ${r2(my + d)}Q${r2(def.eyes.x + 2 * a)} ${r2(my + d)} ${r2(def.eyes.x + 2 * a)} ${r2(my - d * 0.15)}" fill="none" stroke="${ink}" stroke-width="${r2(sw)}" stroke-linecap="round" stroke-linejoin="round" opacity="${r2(clamp(st.mouth.s, 0, 1))}"/>`;
    } else if (st.mouth) {
      const k = st.mouth.k === 'yawn' ? 1 : 0.55, s = st.mouth.s;
      const rx = w * 0.55 * k * (0.5 + 0.5 * s), ry = w * 0.78 * k * s;
      const my = def.eyes.y + 0.75 * h * 0.5 + 1.4 + w * 0.78 * k;
      fm += `<ellipse cx="${r2(def.eyes.x)}" cy="${r2(my)}" rx="${r2(rx)}" ry="${r2(Math.max(0.4, ry))}" fill="${ink}"/>`;
    }
    if (fm !== last.face) { last.face = fm; faceSvg.innerHTML = fm; }
    // ground shadow + effects
    const fkey = `${PAL.canvas}${PAL.accent}${PAL.shadow}`;
    if (fkey !== last.fkey) { last.fkey = fkey; floor.innerHTML = floorMarkup(uid, cx, bottom + 1.1, rug); last.rugEl = floor.querySelector('[data-rug]'); last.press = null; }
    if (shadow) {
      const lift = Math.max(0, -st.lift);
      const k = 1 / (1 + lift / 14), sw = anchors.w * st.sx;
      const sh = `<ellipse cx="${r2(cx)}" cy="${r2(bottom + 1.1)}" rx="${r2(sw * 0.47 * k)}" ry="${r2((rug ? 3.1 : 2.9) * k)}" fill="url(#${uid}sh)" opacity="${r2(k)}"/>`
        + `<ellipse cx="${r2(cx)}" cy="${r2(bottom + 0.95)}" rx="${r2(sw * 0.31 * k)}" ry="${r2(1.15 * k)}" fill="url(#${uid}sh)" opacity="${r2(k ** 4)}"/>`;
      if (sh !== last.sh) last.sh = sh;
    }
    if (last.rugEl) {
      // the rug gives a little when the pet lands (squash), nothing while it breathes
      const p = Math.max(0, -st.lift) < 1 ? clamp((1 - st.sy - 0.025) * 1.4, 0, 0.12) : 0;
      const pr = r2(p * 100) / 100;
      if (pr !== last.press) {
        last.press = pr;
        const fy = bottom + 1.1;
        last.rugEl.setAttribute('transform', pr ? `translate(${r2(cx)} ${r2(fy)}) scale(${r2(1 + pr * 0.12)} ${r2(1 - pr * 0.35)}) translate(${r2(-cx)} ${r2(-fy)})` : '');
      }
    }
    const back = (last.sh || '') + st.fx.filter((f) => f.back).map(fxMarkup).join('');
    if (back !== last.back) { last.back = back; under.innerHTML = back; }
    const fx = st.fx.filter((f) => !f.back).map(fxMarkup).join('');
    if (fx !== last.fx) { last.fx = fx; over.innerHTML = fx; }
  }
  return { frame, anchors, def, pet, host };
}

// ------------------------------------------------------------------------------------
// Smoothness for every expression, so a gallery loop or a hand-over in the app never jumps:
//  - a loop ends exactly where it started (body numbers ease into the first frame over the last 0.3 s,
//    breathing fits a whole number of breaths);
//  - wherever the eye shape changes in one frame (^^ to pill, a lid snapping open...), the eye
//    closes for ~0.09 s and opens on the new shape, like a quick blink, instead of popping.
// ------------------------------------------------------------------------------------
const wrap180 = (a) => ((((a + 180) % 360) + 360) % 360) - 180;
/** Rough visible size of an eye (0 = shut). */
function eyeVis(e) {
  const sq = e.squash ?? 1;
  if (e.k === 'pill') return (e.sy ?? 1) * Math.max(0.18, Math.min(1, e.open ?? 1)) * (1 - 0.8 * (e.lid ?? 0)) * sq;
  return (e.s ?? 1) * 0.7 * sq;
}
/** Would going from eye a to eye b in one frame be a visible pop? */
function eyePops(a, b) {
  if (Math.min(eyeVis(a), eyeVis(b)) < 0.12) return false; // one of them is (nearly) shut
  if (a.k !== b.k) return true;
  if (a.k !== 'pill') return Math.abs((a.s ?? 1) - (b.s ?? 1)) > 0.25;
  return Math.abs((a.lid ?? 0) - (b.lid ?? 0)) > 0.12 || Math.abs((a.slant ?? 0) - (b.slant ?? 0)) > 0.2
    || Math.abs((a.sx ?? 1) - (b.sx ?? 1)) > 0.04 || Math.abs((a.sy ?? 1) - (b.sy ?? 1)) > 0.04
    || Math.abs((a.hl ? a.hlS ?? 1 : 0) - (b.hl ? b.hlS ?? 1 : 0)) > 0.3;
}
const SEAM_KEYS = ['lift', 'roll', 'sx', 'sy', 'yaw', 'pitch', 'gx', 'gy', 'blush', 'spin'];
const EYE_CUT = 0.09;
EXPRS.forEach((e) => {
  const raw = e.f;
  const period = e.dur / Math.max(1, Math.round(e.dur / 3.4));
  const call = (t, c) => { const keep = BREATH_P; BREATH_P = period; try { return raw.call(e, t, c); } finally { BREATH_P = keep; } };
  // find the eye cuts once (the eyes do not depend on the pet's outline)
  const C0 = { cx: 50, cy: 50, top: 13, bottom: 87, left: 9, right: 91, w: 82, h: 74, ey: 50 };
  const cuts = [[], []], N = Math.ceil(e.dur * 240);
  let prev = call(0, C0);
  for (let i = 1; i < N; i++) {
    const s = call(i / 240, C0);
    [0, 1].forEach((k) => { if (eyePops(prev.eyes[k], s.eyes[k])) cuts[k].push((i - 0.5) / 240); });
    prev = s;
  }
  if (e.loop) { const s0 = call(0, C0); [0, 1].forEach((k) => { if (eyePops(prev.eyes[k], s0.eyes[k])) cuts[k].push(e.dur); }); }
  const T = Math.min(0.3, e.dur * 0.15);
  e.cuts = cuts;
  e.f = function (t, c) {
    const s = call(t, c);
    if (e.loop && t > e.dur - T) {
      const z = call(0, c), k = sm((t - (e.dur - T)) / T);
      SEAM_KEYS.forEach((key) => { s[key] = key === 'spin' ? s[key] + wrap180(z[key] - s[key]) * k : lerp(s[key], z[key], k); });
    }
    [0, 1].forEach((k) => {
      for (const tc of cuts[k]) {
        let d = Math.abs(t - tc);
        if (e.loop) d = Math.min(d, e.dur - d);
        if (d < EYE_CUT) s.eyes[k] = { ...s.eyes[k], squash: (s.eyes[k].squash ?? 1) * sm(d / EYE_CUT) };
      }
    });
    return s;
  };
});
const EXPR_BY_ID = Object.fromEntries(EXPRS.map((e) => [e.id, e]));
function stateOf(exprId, t, anchors) {
  const e = EXPR_BY_ID[exprId];
  return e.f(((t % e.dur) + e.dur) % e.dur, anchors);
}
