// ===================================================================================
// A living pet: transitions, a non-repeating idle, an arbiter for who gets the stage,
// and dozing off when nobody is around. Ideas borrowed from Aora Bot (no code taken).
// ===================================================================================
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
/** Second-order spring, integrated at a fixed 120 Hz substep. zeta 1 = no overshoot. */
const spr = (v = 0, omega = 8, zeta = 1) => ({ v, vel: 0, target: v, omega, zeta });
function stepSpr(s, dt) {
  let r = Math.min(dt, 0.1);
  while (r > 0) {
    const h = Math.min(1 / 120, r); r -= h;
    const acc = -s.omega * s.omega * (s.v - s.target) - 2 * s.zeta * s.omega * s.vel;
    s.vel += acc * h; s.v += s.vel * h;
  }
  return s.v;
}

// ---------- 1. transitions ----------
const BLEND_OMEGA = 11; // critically damped: ~95% of the way in 0.43 s
const blendW = (t) => 1 - (1 + BLEND_OMEGA * t) * Math.exp(-BLEND_OMEGA * t);
const wrapDeg = (a) => ((((a + 180) % 360) + 360) % 360) - 180;
const NUM_KEYS = ['lift', 'roll', 'sx', 'sy', 'yaw', 'pitch', 'gx', 'gy', 'blush'];
/**
 * Mix two eyes for a cross-fade. Pills morph (lid, size, openness, highlight growing in or out);
 * the same special shape morphs its size; different shapes are not mixed at all — the new one is
 * returned, and the eye stage below turns the change into a quick blink.
 */
function eyeMix(a, b, w) {
  if (a.k === 'pill' && b.k === 'pill') {
    const o = { k: 'pill' };
    for (const key of ['sx', 'sy', 'open', 'squash']) o[key] = lerp(a[key] ?? 1, b[key] ?? 1, w);
    for (const key of ['lid', 'slant', 'tear', 'hlX', 'hlY']) o[key] = lerp(a[key] ?? 0, b[key] ?? 0, w);
    if (a.hl || b.hl) {
      o.hl = b.hl || a.hl;
      o.hlS = lerp(a.hl ? a.hlS ?? 1 : 0, b.hl ? b.hlS ?? 1 : 0, w);
    }
    return o;
  }
  if (a.k === b.k) return { ...b, s: lerp(a.s ?? 1, b.s ?? 1, w), rot: (a.rot ?? 0) + wrapDeg((b.rot ?? 0) - (a.rot ?? 0)) * w, tear: lerp(a.tear ?? 0, b.tear ?? 0, w), squash: lerp(a.squash ?? 1, b.squash ?? 1, w) };
  // different looks: the new one is drawn, but its openness still follows the old one, so the moment
  // the old side changes its look (shut, at one of its own cuts) and the two start to mix, nothing jumps
  return { ...b, squash: lerp(a.squash ?? 1, b.squash ?? 1, w) };
}
function blendStates(A, B, w) {
  if (w >= 0.999) return B;
  const s = { ...B };
  NUM_KEYS.forEach((k) => { s[k] = lerp(A[k], B[k], w); });
  s.spin = A.spin + wrapDeg(B.spin - A.spin) * w; // the short way round
  s.blushLines = lerp(A.blushLines ?? 0, B.blushLines ?? 0, w);
  const da = A.blushAt ?? { dx: 0.95, dy: 0.62 }, db = B.blushAt ?? { dx: 0.95, dy: 0.62 };
  s.blushAt = { dx: lerp(da.dx, db.dx, w), dy: lerp(da.dy, db.dy, w) };
  s.eyes = [0, 1].map((i) => eyeMix(A.eyes[i], B.eyes[i], w));
  if (A.mouth && B.mouth && A.mouth.k === B.mouth.k) s.mouth = { k: B.mouth.k, s: lerp(A.mouth.s, B.mouth.s, w) };
  else if (A.mouth && w < 0.5) s.mouth = { ...A.mouth, s: A.mouth.s * (1 - 2 * w) };
  else s.mouth = B.mouth ? { ...B.mouth, s: B.mouth.s * sm(w * 2 - 1) } : null;
  s.fx = [...A.fx.map((f) => ({ ...f, a: (f.a ?? 1) * (1 - w) })), ...B.fx.map((f) => ({ ...f, a: (f.a ?? 1) * w }))];
  return s;
}
/**
 * The last stage before the screen: an eye never jumps from one look to another. When the eye it is
 * asked to show would pop (another shape, a lid snapping open), it closes the old eye (0.09 s) and
 * opens the new one (0.09 s). Natural blinks and smooth morphs pass straight through.
 */
const SWAP = 0.09;
function createEyeStage() {
  const st = [0, 1].map(() => ({ mode: 'show', t: 0, old: null, last: null }));
  return function (eyes, dt) {
    return eyes.map((want, i) => {
      const e = st[i];
      let show = want;
      if (e.mode === 'opening') {
        e.t += dt;
        if (e.t < SWAP) show = { ...want, squash: (want.squash ?? 1) * sm(e.t / SWAP) };
        else e.mode = 'show';
      }
      // also while it is still opening: if the look it is opening into jumps, shut it again first
      if (e.mode !== 'closing' && e.last && eyePops(e.last, show)) { e.mode = 'closing'; e.t = 0; e.old = e.last; }
      if (e.mode === 'closing') {
        e.t += dt;
        if (e.t < SWAP) show = { ...e.old, squash: (e.old.squash ?? 1) * (1 - sm(e.t / SWAP)) };
        else { e.mode = 'opening'; e.t = Math.min(dt, SWAP * 0.5); show = { ...want, squash: (want.squash ?? 1) * sm(e.t / SWAP) }; }
      }
      e.last = show;
      return show;
    });
  };
}

// ---------- 2. an idle that never loops ----------
function createLiveIdle(seed = 7) {
  const rnd = mulberry32(seed);
  const R = (a, b) => a + (b - a) * rnd();
  let t = 0, nextBlink = R(1.2, 3), blinks = [], nextGaze = R(1.5, 3.5), lastSpot = 0;
  const gx = spr(0, 16), gy = spr(0, 16), yaw = spr(0, 3.2, 0.9), pitch = spr(0, 3.2, 0.9), roll = spr(0, 2.6, 0.85);
  // Where it looks. The centre twice, so it comes back to you often.
  const SPOTS = [[0, 0], [0, 0], [0.6, 0.05], [-0.6, 0.05], [0.4, -0.5], [-0.45, -0.45], [0.25, 0.35], [-0.3, 0.3]];
  let st = null;
  function update(dt) {
    t += dt;
    if (t >= nextBlink) {
      blinks.push(t);
      if (rnd() < 0.22) blinks.push(t + 0.28); // sometimes a double blink
      nextBlink = t + R(3.4, 7.2);
    }
    if (t >= nextGaze) {
      let k; do { k = Math.floor(rnd() * SPOTS.length); } while (k === lastSpot && rnd() < 0.8);
      lastSpot = k;
      const [x, y] = SPOTS[k];
      gx.target = x; gy.target = y;
      yaw.target = x * 13; pitch.target = -y * 5; roll.target = -x * 2.5 + (rnd() - 0.5) * 2;
      nextGaze = t + (x === 0 && y === 0 ? R(2.5, 5) : R(1.6, 3.6));
      if (rnd() < 0.3) blinks.push(t + 0.02); // a glance often comes with a blink
    }
    blinks = blinks.filter((b) => t - b < 0.45);
    [gx, gy, yaw, pitch, roll].forEach((s) => stepSpr(s, dt));
    const s = breathe(base(), t);
    s.lift = -0.5 * (1 - Math.cos((2 * Math.PI * t) / 4.4));
    s.gx = gx.v; s.gy = gy.v;
    s.yaw = yaw.v + 2 * osc(t, 7.3); s.pitch = pitch.v; s.roll = roll.v + osc(t, 5.1);
    let close = 0;
    blinks.forEach((b) => { close = Math.max(close, blink(t, b, 0.2)); });
    setOpen(s, 1 - close);
    st = s;
    return s;
  }
  return { update, state: () => st || update(0) };
}

// ---------- 3 + 4. the director: who gets the stage, and dozing off ----------
const GROUP_PRIO = { idle: 0.5, care: 1, sleep: 1, touch: 2, cheer: 3, new: 2, new2: 2 }; // a new expression may set its own prio
const FIDGETS = ['lookaround', 'daydream', 'hum', 'stretch', 'bored'];
const TAP_POOL = ['shy', 'surprised', 'tilt', 'wink'];

function createDirector(anchors, opts = {}) {
  const live = createLiveIdle(opts.seed ?? 11);
  const rnd = mulberry32((opts.seed ?? 11) * 7 + 3);
  const R = (a, b) => a + (b - a) * rnd();
  const timing = { drowsy: 45, asleep: 120, ...(opts.timing || {}) };
  let mode = 'awake';      // awake → drowsy → asleep
  let mood = 'normal';     // today's condition: normal | tired | sad | rest (请假) | bedtime (睡前一小时)
  let workedOut = false;   // a workout is in today: 呼呼 joins the idle fidgets
  let quiet = 0, clock = 0, fidgetIn = R(8, 14);
  let cur = null, queue = [];
  let taps = [], lastPick = -1;
  const listeners = new Set();
  const emit = (what) => listeners.forEach((f) => f(what));

  // sources
  let srcN = 0;
  const liveSrc = () => ({ key: 'base:live', id: 'live', advance: (dt) => live.update(dt), eval: () => live.state() });
  function exprSrc(id, loop, key, ev) {
    const e = EXPR_BY_ID[id];
    const c = ev && ev.aim ? { ...anchors, aim: ev.aim } : anchors; // 眼巴巴: where the bubble is
    const seg = ev && e.holdSeg; // 等一下: while held, keep looping this stretch
    let t = 0;
    const src = { key: key ?? `ev:${id}:${++srcN}`, id,
      advance: (dt) => { t += dt; if (seg && ev.hold && t >= seg[1]) t = seg[0] + ((t - seg[0]) % (seg[1] - seg[0])); },
      eval: () => e.f(loop ? ((t % e.dur) + e.dur) % e.dur : Math.min(t, e.dur - 1e-3), c),
      time: () => t };
    if (ev) ev.src = src;
    return src;
  }
  const baseId = () => (mode === 'asleep' ? 'sleep' : mode === 'drowsy' ? 'doze' : mood === 'tired' ? 'tired' : mood === 'sad' ? 'sad' : mood === 'rest' ? 'holiday' : mood === 'bedtime' ? 'moon' : 'live');
  const baseSrc = () => { const id = baseId(); return id === 'live' ? liveSrc() : exprSrc(id, true, `base:${id}`); };

  // A hand-over cross-fades from the old source (still playing) to the new one. If another hand-over
  // comes in the middle, the fade in progress keeps playing as the "old" side, so nothing freezes.
  const blendSrc = (a, b, t0, depth) => {
    let t = t0;
    return { depth, advance: (dt) => { a.advance(dt); b.advance(dt); t += dt; }, eval: () => blendStates(a.eval(), b.eval(), blendW(t)) };
  };
  const stillSrc = (s) => ({ depth: 0, advance: () => {}, eval: () => s });
  let show = baseSrc(), from = null, bt = 0, out = null;
  const eyeStage = createEyeStage();
  function switchTo(src) {
    if (from) {
      const d = (from.depth ?? 0) + 1;
      from = d > 3 ? stillSrc(out) : blendSrc(from, show, bt, d);
    } else from = show;
    show = src; bt = 0;
  }

  function start(ev) {
    cur = ev; ev.el = 0;
    const e = EXPR_BY_ID[ev.id];
    switchTo(exprSrc(ev.id, e.loop || ev.hold, undefined, ev));
    emit('start');
  }
  function next() {
    queue = queue.filter((q) => q.kind !== 'touch' || clock - q.at < 6); // stale taps are forgotten
    const ev = queue.shift();
    if (ev) start(ev);
    else { cur = null; switchTo(baseSrc()); emit('base'); }
  }
  /**
   * Ask for an expression. Higher priority interrupts a lower one that allows it; equal priority
   * replaces it once it has been on screen for its minimum dwell. Otherwise it waits in line:
   * celebrations always keep their place, taps only keep the latest one.
   */
  function request(id, o = {}) {
    const e = EXPR_BY_ID[id];
    const prio = o.prio ?? e.prio ?? GROUP_PRIO[e.group];
    const ev = {
      id, prio, at: clock, hold: !!o.hold, aim: o.aim,
      kind: o.kind ?? (prio >= 3 ? 'event' : prio >= 2 ? 'touch' : 'ambient'),
      minDwell: o.minDwell ?? (prio >= 3 ? e.dur : prio >= 2 ? 0.9 : 0),
      interruptible: o.interruptible ?? prio < 3,
      endAt: o.endAt ?? e.dur,
    };
    if (!cur) { start(ev); return 'now'; }
    if (cur.interruptible && (ev.prio > cur.prio || (ev.prio >= cur.prio && cur.el >= cur.minDwell))) { start(ev); return 'now'; }
    if (ev.kind === 'touch') queue = queue.filter((q) => q.kind !== 'touch');
    queue.push(ev);
    queue.sort((a, b) => b.prio - a.prio);
    emit('queue');
    return 'queued';
  }

  function activity() {
    quiet = 0;
    if (mode === 'drowsy') { mode = 'awake'; emit('mode'); }
  }
  function tap() {
    quiet = 0;
    // woken up in the middle of a nap: a big yawn, then awake (醒来 itself is kept for the first open in the morning)
    if (mode === 'asleep') { mode = 'awake'; taps = []; request('yawn', { prio: 2, interruptible: false, minDwell: 99 }); emit('mode'); return; }
    if (mode === 'drowsy') { mode = 'awake'; taps = []; request('surprised'); emit('mode'); return; }
    if (mood === 'sad') { mood = 'normal'; taps = []; request('cheerup', { prio: 2 }); emit('mood'); return; }
    taps = taps.filter((x) => clock - x < 1.3);
    taps.push(clock);
    const n = taps.length;
    if (n >= 6) { request('dizzy'); taps = []; }
    else if (n >= 3) request('giggle');
    else if (n === 1) {
      let k; do { k = Math.floor(rnd() * TAP_POOL.length); } while (k === lastPick);
      lastPick = k;
      request(TAP_POOL[k]);
    }
  }
  function holdStart() {
    quiet = 0;
    if (mode !== 'awake') { tap(); return; }
    taps = [];
    request('pat', { hold: true });
  }
  function holdEnd() {
    queue.forEach((q) => { if (q.id === 'pat') q.hold = false; }); // released before its turn came
    if (cur && cur.id === 'pat' && cur.hold) {
      cur.hold = false;
      const d = EXPR_BY_ID.pat.dur;
      cur.endAt = Math.max(d, Math.ceil(cur.el / d) * d); // finish the stroke it is in
    }
  }
  /** End a hold (等一下: the data is in): it plays on from where it is to its end. */
  function release(id) {
    queue.forEach((q) => { if (q.id === id) q.hold = false; });
    if (cur && cur.id === id && cur.hold) {
      cur.hold = false;
      const e = EXPR_BY_ID[id];
      if (e.holdSeg && cur.src) cur.endAt = cur.el + Math.max(0, e.dur - cur.src.time());
      else cur.endAt = Math.max(e.dur, Math.ceil(cur.el / e.dur) * e.dur);
    }
  }
  /** First open of the day: whatever it was doing, it plays 醒来 to the end. */
  function morning() {
    quiet = 0; taps = []; queue = [];
    if (mode !== 'awake') { mode = 'awake'; emit('mode'); }
    request('wakeup', { prio: 2.5, interruptible: false, minDwell: 99, kind: 'event' });
  }
  /** Explicit "play this" (from the list): like a touch, but it may be replaced at once. */
  function play(id, o = {}) {
    quiet = 0;
    if (mode !== 'awake') { mode = 'awake'; emit('mode'); }
    request(id, { prio: 2, interruptible: true, minDwell: 0, kind: 'touch', ...o });
  }

  function update(dt) {
    clock += dt; quiet += dt;
    if (mode === 'awake' && quiet > timing.drowsy) { mode = 'drowsy'; request('yawn', { prio: 1 }); emit('mode'); }
    if (mode === 'drowsy' && quiet > timing.asleep) { mode = 'asleep'; emit('mode'); }
    if (mode === 'awake' && mood === 'normal' && !cur) {
      fidgetIn -= dt;
      if (fidgetIn <= 0) {
        const pool = workedOut ? FIDGETS.concat(['puff', 'puff']) : FIDGETS; // after a workout, 呼呼 comes up about every third fidget
        request(pool[Math.floor(rnd() * pool.length)], { prio: 0.5, kind: 'ambient' }); fidgetIn = R(12, 22);
      }
    }
    if (cur) {
      cur.el += dt;
      if (!cur.hold && cur.el >= cur.endAt) next();
      else if (queue.length && cur.interruptible && cur.el >= cur.minDwell && queue[0].prio >= cur.prio) next();
    } else if (show.key !== `base:${baseId()}`) {
      switchTo(baseSrc()); emit('base');
    }
    show.advance(dt);
    if (from) from.advance(dt);
    bt += dt;
    const to = show.eval();
    if (from) {
      out = blendStates(from.eval(), to, blendW(bt));
      if (bt > 0.9) from = null;
    } else out = to;
    out = { ...out, eyes: eyeStage(out.eyes, dt) };
    return out;
  }

  return {
    update, request, tap, holdStart, holdEnd, play, activity, morning, release,
    state: () => out ?? show.eval(),
    setMood(m) { mood = m; quiet = 0; if (mode !== 'awake') mode = 'awake'; emit('mood'); },
    setWorkedOut(b) { workedOut = !!b; emit('mood'); },
    setTiming(t) { Object.assign(timing, t); quiet = 0; if (mode !== 'awake') { mode = 'awake'; } emit('mode'); },
    on(f) { listeners.add(f); return () => listeners.delete(f); },
    status: () => ({
      showing: cur ? cur.id : baseId(), event: !!cur, queue: queue.map((q) => q.id), mode, mood, workedOut, quiet,
      toDrowsy: Math.max(0, timing.drowsy - quiet), toAsleep: Math.max(0, timing.asleep - quiet), timing: { ...timing },
    }),
  };
}
