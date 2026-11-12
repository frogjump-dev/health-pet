// ===================================================================================
// 小装饰 · wearable decorations for the 3D方案 slice pets (2026-11-09).
//
// A separate layer. It never changes the pet's own slices, eyes, face or motion: each decoration is
// its own little slice object, built with the same method as the pets (open-bot-avatar's buildVolume:
// an inflated outline cut into depth slices, outlines smoothed with the pet-svg3d helpers), then hung
// inside the pet's 3D view ([data-view]). So it turns, hops, squashes and tilts with the pet for free,
// and the pet underneath is exactly the same pet.
//
// Where each decoration sits is worked out from the pet's own outline and volume (fitPet): hats slide
// down until their rim touches the head, horns and ears stand on the top profile, glasses ring the
// eyes, beards and bow ties float just in front of the face, wings and tails hide behind the body,
// head and neck bands are copies of the pet's own slices, a little larger. A few pets get a nudge
// in FIT_OVERRIDES (toppers like the cherry, the straw, the honey dipper).
//
// Slots: head 头顶 · eyes 眼睛 · mouth 嘴边 · neck 脖子 · back 背后. One decoration per slot.
// ===================================================================================

const DC = {
  red: '#D9483B', white: '#FBF8F2', fur: '#FFFDF8', gold: '#EDBE4E', wire: '#A9781F', ink: '#2D392A', jade: '#4B6844',
  furRim: '#E2D9CB', lime: '#D9D387', pink: '#F7B3C2', coral: '#F48C9E', cream: '#FFF3DA', sky: '#9CC7E6', berry: '#C7404A',
};

// ---------- the catalogue ----------
// Pieces are drawn in pet units around an attach point A (base centre for hats, top centre for beards...).
// piece: d (outline), color, vol (depth factor for buildVolume), rim (width of a deeper edge band),
// paints [{ d, color, face }] (bands and stickers; face = front face only), dz (z offset),
// pivot + dangle (secondary motion), lens (flat glass plane, not a volume).
const D = (s) => s.replace(/\s+/g, ' ').trim();
const circ = (cx, cy, r) => `M${cx - r} ${cy}A${r} ${r} 0 1 0 ${cx + r} ${cy}A${r} ${r} 0 1 0 ${cx - r} ${cy}Z`;
/** The same circle wound the other way: a hole when it sits inside a circle(). */
const hole = (cx, cy, r) => `M${cx - r} ${cy}A${r} ${r} 0 1 1 ${cx + r} ${cy}A${r} ${r} 0 1 1 ${cx - r} ${cy}Z`;
/** A ring as two overlapping half-rings (the volume builder reads a thin ring with a hole as all hole). */
const arcSeg = (cx, cy, R, r, a1, a2) => {
  const P = (rr, a) => `${(cx + rr * Math.cos(a * D2R)).toFixed(2)} ${(cy + rr * Math.sin(a * D2R)).toFixed(2)}`;
  const big = a2 - a1 > 180 ? 1 : 0;
  return `M${P(R, a1)}A${R} ${R} 0 ${big} 1 ${P(R, a2)}L${P(r, a2)}A${r} ${r} 0 ${big} 0 ${P(r, a1)}Z`;
};
const ringD = (cx, cy, R, r) => arcSeg(cx, cy, R, r, -96, 96) + arcSeg(cx, cy, R, r, 84, 276);
const rrect = (x1, y1, x2, y2, r) => `M${x1 + r} ${y1}H${x2 - r}A${r} ${r} 0 0 1 ${x2} ${y1 + r}V${y2 - r}A${r} ${r} 0 0 1 ${x2 - r} ${y2}H${x1 + r}A${r} ${r} 0 0 1 ${x1} ${y2 - r}V${y1 + r}A${r} ${r} 0 0 1 ${x1 + r} ${y1}Z`;
const starPath = (cx, cy, R, r) => {
  let d = '';
  for (let k = 0; k < 10; k++) { const a = -Math.PI / 2 + (k * Math.PI) / 5, q = k % 2 ? r : R; d += `${k ? 'L' : 'M'}${(cx + Math.cos(a) * q).toFixed(2)} ${(cy + Math.sin(a) * q).toFixed(2)}`; }
  return d + 'Z';
};
/** A heart of width `w`, centred on (cx, cy), turned `rot`° about its centre (tip down at rot 0). */
const heartAt = (cx, cy, w, rot = 0) => {
  const a = rot * D2R, c = Math.cos(a), sn = Math.sin(a);
  const P = (x, y) => `${r2(cx + (c * x - sn * y) * w)} ${r2(cy + (sn * x + c * y) * w)}`;
  const H = [[0, 0.464], [-0.271, 0.264], [-0.5, 0.064], [-0.5, -0.179], [-0.5, -0.35], [-0.371, -0.464], [-0.229, -0.464], [-0.129, -0.464], [-0.043, -0.407], [0, -0.321]];
  const L = H.map(([x, y]) => P(x, y)), R = [...H].reverse().map(([x, y]) => P(-x, y));
  return `M${L[0]}C${L[1]} ${L[2]} ${L[3]}C${L[4]} ${L[5]} ${L[6]}C${L[7]} ${L[8]} ${L[9]}C${R[1]} ${R[2]} ${R[3]}C${R[4]} ${R[5]} ${R[6]}C${R[7]} ${R[8]} ${R[9]}Z`;
};
const BAND = (y1, y2) => `M-50 ${y1}H150V${y2}H-50Z`;

// The wizard beard's outline. Its top edge runs well up under the moustache (round 3: it used to
// meet the moustache's lower edge, and the two rims drew a mouth across the beard).
const BEARD_D = D(`M37.4 51.4C41.4 51.6 45.6 51.6 50 51.6C54.4 51.6 58.6 51.6 62.6 51.4C64.8 54.6 65.2 58.4 64 61.8C63.4 63.6 62.2 64.8 61.2 65.8
  C61.6 67.8 60.8 69.8 59.2 71.2C58.2 72 57.2 72.4 56.2 72.6C55.8 75 54.6 77.4 53 79.2C52.4 79.9 52.2 80.8 52.8 81.6
  C51.2 81.4 49.8 80.8 48.8 79.8C46.8 77.8 45 75.4 44.2 72.6C43.2 72.4 42.2 72 41.2 71.2C39.4 69.8 38.6 67.8 39 65.8
  C37.9 64.8 36.6 63.6 36 61.8C34.8 58.4 35.2 54.6 37.4 51.4Z`);
const MOUSTACHE_D = D(`M50 50.6C47.6 48.8 44 48.2 40.8 48.8C37.8 49.4 35.6 51.4 34.6 54.2C34 55.8 34.2 57.6 35 58.6C35.8 57.2 37.2 56.2 39 55.8
  C42.6 55 46.4 54.6 50 53.6C53.6 54.6 57.4 55 61 55.8C62.8 56.2 64.2 57.2 65 58.6C65.8 57.6 66 55.8 65.4 54.2
  C64.4 51.4 62.2 49.4 59.2 48.8C56 48.2 52.4 48.8 50 50.6Z`);
const FLOWER_D = circ(50.00, 46.10, 3.3)+circ(53.71, 48.79, 3.3)+circ(52.29, 53.16, 3.3)+circ(47.71, 53.16, 3.3)+circ(46.29, 48.79, 3.3);
const CLOVER_D = [45, 135, 225, 315].map((a) => heartAt(50 + 3.1 * Math.sin(a * D2R), 50 - 3.1 * Math.cos(a * D2R), 7.4, a)).join('');
// Neither draws its rim over the other: the beard drops a little on a yawn and no line opens up.
// round 5 shapes
const SKI_D = 'M35.6 41.4H64.4C68 41.4 70.6 44 70.6 47.6V52.6C70.6 56.2 68 58.8 64.6 58.8H58C55.6 58.8 54.2 56.8 52.8 55.2C51.4 53.6 48.6 53.6 47.2 55.2C45.8 56.8 44.4 58.8 42 58.8H35.4C32 58.8 29.4 56.2 29.4 52.6V47.6C29.4 44 32 41.4 35.6 41.4Z';
// 11-10 round 6 (user: 画风要跟宠物设计规范一致) shapes: chunky, rounded corners, no outline
/** A closed polygon with every corner rounded (r: one radius, or one per corner), convex and concave alike. */
const roundPoly = (pts, r) => {
  const n = pts.length; let d = '';
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i + n - 1) % n], p1 = pts[i], p2 = pts[(i + 1) % n], rr = Array.isArray(r) ? r[i] : r;
    const v1 = [p0[0] - p1[0], p0[1] - p1[1]], v2 = [p2[0] - p1[0], p2[1] - p1[1]], l1 = Math.hypot(...v1), l2 = Math.hypot(...v2);
    const ang = Math.acos(Math.max(-1, Math.min(1, (v1[0] * v2[0] + v1[1] * v2[1]) / (l1 * l2))));
    const t = Math.min(rr / Math.tan(ang / 2), l1 * 0.45, l2 * 0.45);
    const a = [p1[0] + (v1[0] / l1) * t, p1[1] + (v1[1] / l1) * t], b = [p1[0] + (v2[0] / l2) * t, p1[1] + (v2[1] / l2) * t];
    d += `${i ? 'L' : 'M'}${r2(a[0])} ${r2(a[1])}Q${r2(p1[0])} ${r2(p1[1])} ${r2(b[0])} ${r2(b[1])}`;
  }
  return d + 'Z';
};
const starPts = (cx, cy, R, r) => Array.from({ length: 10 }, (_, k) => { const a = -Math.PI / 2 + (k * Math.PI) / 5, q = k % 2 ? r : R; return [cx + Math.cos(a) * q, cy + Math.sin(a) * q]; });
/** A five-point star with soft tips (rt) and soft inner corners (ri). */
const softStar = (cx, cy, R, r, rt, ri) => roundPoly(starPts(cx, cy, R, r), Array.from({ length: 10 }, (_, k) => (k % 2 ? ri : rt)));
const ell = (cx, cy, rx, ry) => `M${cx - rx} ${cy}A${rx} ${ry} 0 1 0 ${cx + rx} ${cy}A${rx} ${ry} 0 1 0 ${cx - rx} ${cy}Z`;
/** A rose held in the mouth: a cup with three round petals on top, a deeper inner petal. */
const ROSE_D = 'M60.4 47.4C60.4 45.8 61.8 45 63 45.8C63.6 44.6 64.6 44 65.4 44C66.2 44 67.2 44.6 67.8 45.8C69 45 70.4 45.8 70.4 47.4V50.4C70.4 53.4 68.2 55.6 65.4 55.6C62.6 55.6 60.4 53.4 60.4 50.4Z';
const ROSE_IN = 'M62.8 48.2C64 49.4 66.8 49.4 68 48.2C68 51 66.8 52.8 65.4 52.8C64 52.8 62.8 51 62.8 48.2Z';
// 11-11 round 8 (user's 14 notes) shapes
/** An ellipse turned rot° about its centre; hole: wound the other way (a hole inside a nonzero fill). */
const rell = (cx, cy, rx, ry, rot = 0, isHole = false) => {
  const a = rot * D2R, c = Math.cos(a), s = Math.sin(a), sw = isHole ? 1 : 0;
  const p1 = `${r2(cx - rx * c)} ${r2(cy - rx * s)}`, p2 = `${r2(cx + rx * c)} ${r2(cy + rx * s)}`;
  return `M${p1}A${rx} ${ry} ${rot} 1 ${sw} ${p2}A${rx} ${ry} ${rot} 1 ${sw} ${p1}Z`;
};
/** A round-ended bar from (x1, y1) to (x2, y2), w wide. */
const capsule = (x1, y1, x2, y2, w) => {
  const L = Math.hypot(x2 - x1, y2 - y1), ux = (x2 - x1) / L, uy = (y2 - y1) / L, nx = (-uy * w) / 2, ny = (ux * w) / 2, r = r2(w / 2);
  return `M${r2(x1 + nx)} ${r2(y1 + ny)}L${r2(x2 + nx)} ${r2(y2 + ny)}A${r} ${r} 0 0 0 ${r2(x2 - nx)} ${r2(y2 - ny)}L${r2(x1 - nx)} ${r2(y1 - ny)}A${r} ${r} 0 0 0 ${r2(x1 + nx)} ${r2(y1 + ny)}Z`;
};
/** A path made of M L C Q Z only (absolute), scaled k and turned rot° about (px, py), then moved (dx, dy). */
const tpath = (d, px, py, rot = 0, k = 1, dx = 0, dy = 0) => {
  const a = rot * D2R, c = Math.cos(a), s = Math.sin(a);
  return d.replace(/(-?\d*\.?\d+)[ ,](-?\d*\.?\d+)/g, (_, x, y) => {
    const u = (+x - px) * k, v = (+y - py) * k;
    return `${r2(px + dx + c * u - s * v)} ${r2(py + dy + s * u + c * v)}`;
  });
};
// the light bulb: a round glass top narrowing to its neck, five short rays round the top
const BULB_D = 'M45.8 50.2C45.8 47.6 41.6 46 41.6 40.6C41.6 36 45.4 32.2 50 32.2C54.6 32.2 58.4 36 58.4 40.6C58.4 46 54.2 47.6 54.2 50.2Z';
const RAYS_D = [-72, -36, 0, 36, 72].map((a) => { const sx = Math.sin(a * D2R), cy = -Math.cos(a * D2R); return capsule(50 + 11.4 * sx, 40.6 + 11.4 * cy, 50 + 15 * sx, 40.6 + 15 * cy, 2.4); }).join('');
// the cowboy hat: a wide brim turned up at both sides, a crown dented in the middle
const COWBOY_BRIM = 'M26.4 49.4C27.6 54.8 32 58.6 39 59.8C45.6 60.8 54.4 60.8 61 59.8C68 58.6 72.4 54.8 73.6 49.4C73.9 48.2 72.8 47.6 71.9 48.4C68.8 51.6 64.2 53.4 57.6 54C52.4 54.4 47.6 54.4 42.4 54C35.8 53.4 31.2 51.6 28.1 48.4C27.2 47.6 26.1 48.2 26.4 49.4Z';
const COWBOY_CROWN = 'M38.4 55.4L37.8 43C37.6 38.8 39.6 35.8 42.8 35.2C45.2 34.8 47.6 36.6 50 36.6C52.4 36.6 54.8 34.8 57.2 35.2C60.4 35.8 62.4 38.8 62.2 43L61.6 55.4Z';
// the snorkel mask: one window over both eyes (the frame dips to a nose bridge in the middle)
const MASK_WIN = roundPoly([[31, 43.8], [69, 43.8], [69.6, 56.6], [55.6, 57.2], [52.6, 53.2], [47.4, 53.2], [44.4, 57.2], [30.4, 56.6]], [4, 4, 3.4, 1.6, 1.4, 1.4, 1.6, 3.4]);
const MASK_OUT = roundPoly([[27.6, 40.8], [72.4, 40.8], [73.2, 58], [56.4, 59.2], [53.2, 56.6], [46.8, 56.6], [43.6, 59.2], [26.8, 58]], [5, 5, 3.4, 1.6, 1.6, 1.6, 1.6, 3.4]);
const MASK_SKIRT = roundPoly([[25.4, 38.8], [74.6, 38.8], [75.4, 60.2], [50, 61.8], [24.6, 60.2]], [6, 6, 4, 8, 4]);
// odd shades: a small square lens on the left, a big slanted one on the right
const WILD_L_OUT = roundPoly([[28.2, 42.4], [49, 42.4], [49, 58.6], [28.2, 58.6]], 2.6);
const WILD_L_IN = roundPoly([[31.2, 45.2], [46, 45.2], [46, 55.8], [31.2, 55.8]], 1.4);
const WILD_R_OUT = roundPoly([[50.4, 43.4], [67, 36.8], [74.8, 44.4], [73, 60.2], [51, 59.8]], [2.4, 2.8, 2.8, 2.6, 2.4]);
const WILD_R_IN = roundPoly([[53.4, 45.4], [66.2, 40.2], [71.6, 45.6], [70.2, 57.2], [53.8, 57]], [1.4, 1.8, 1.8, 1.6, 1.4]);
// the rose, upright at the end of its stem: dark back petals, a red cup of two petals (the left one a
// lighter red), a curl in the opening, a green calyx where the stem comes in
const ROSE_BACK = 'M60.2 50C59.4 46.6 61 43.8 63.6 43.6C64.6 42.4 66.6 42.2 67.8 43.4C69.8 43.2 71.6 45 71.4 47.6C71.4 48.6 71.2 49.4 70.8 50.2Z';
const ROSE_CUP = 'M59.8 48.8C61.6 47.6 63.6 48 65.2 49.4C66.6 47.8 69.2 47.4 71.4 48.8C71.8 53.2 69.2 56.4 65.6 56.4C62 56.4 59.4 53.4 59.8 48.8Z';
const ROSE_FOLD = 'M59.8 48.8C61.6 47.6 63.6 48 65.2 49.4C64.8 52.8 63.6 55.4 61.6 56.2C60.2 54.6 59.6 52 59.8 48.8Z';
const ROSE_CURL = 'M63.4 47.2C63.6 45.4 66.4 44.8 67.4 46.2C68.2 47.4 67.2 48.6 65.8 48.2';
// the flower sits a little right and down of where it was drawn, so an eye looking down-right never lands on it
// the digital thermometer's body: rounded at the back, narrowing to the probe at the front
const THERMO_BODY = 'M56.2 50.7C58.4 50.7 59.4 48.9 61.4 48.9L75.6 48.9C77.4 48.9 78.8 50.3 78.8 52C78.8 53.7 77.4 55.1 75.6 55.1L61.4 55.1C59.4 55.1 58.4 53.3 56.2 53.3C55.5 53.3 55 52.7 55 52C55 51.3 55.5 50.7 56.2 50.7Z';
const ROSE_AT = (d) => tpath(d, 0, 0, 0, 1, 1.2, 0.6);
const ROSE_CALYX = roundPoly([[61.2, 54.4], [65.6, 55.6], [70, 54.4], [67.6, 57.6], [63.6, 57.6]], [0.8, 1, 0.8, 1.2, 1.2]);
// paisley (腰果花), a unit shape: a round drop whose tip curls over
const PAISLEY_U = 'M0 1.2C-0.75 1.2 -1.1 0.6 -1 0C-0.9 -0.7 -0.3 -1.2 0.3 -1.5C0.55 -1.62 0.85 -1.55 0.9 -1.35C0.6 -1.25 0.45 -1 0.55 -0.65C0.75 -0.1 0.85 0.5 0.55 0.9C0.4 1.1 0.2 1.2 0 1.2Z';
const paisleyAt = (cx, cy, k, rot) => tpath(PAISLEY_U, 0, 0, rot, k, cx, cy);
// the bandana: one big triangle of cloth (the top edge the width of the neck, so it is not a waistband
// over a small triangle), the point swung a little to the left, the knot showing at the right side
// with its two ends flaring out sideways; a dotted border along the two lower edges
// round 9 (user: 思路对，细节更高级): the two lower sides drape a little (bow out), a dotted hem on all
// three sides, longer paisleys whose tip bends over (a round eye in them read as a 6), a real knot with two soft tails
const BANDANA_TRI = (() => {
  const A = [29.4, 37.8], B = [70.6, 37.8], C = [47.4, 61.2], n = 7;
  const q = (p0, c, p1, t) => [(1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1]];
  const pts = [A, B], rr = [2.4, 2.4];
  for (let i = 1; i < n; i++) { pts.push(q(B, [60.4, 50.8], C, i / n)); rr.push(0.01); }
  pts.push(C); rr.push(3);
  for (let i = 1; i < n; i++) { pts.push(q(C, [36.9, 50.6], A, i / n)); rr.push(0.01); }
  return roundPoly(pts, rr);
})();
const BANDANA_DOTS = (() => {
  const dots = [], edge = (a, b, n, t0, t1) => { for (let i = 0; i < n; i++) { const t = t0 + ((t1 - t0) * i) / (n - 1); dots.push(circ(+(a[0] + (b[0] - a[0]) * t).toFixed(2), +(a[1] + (b[1] - a[1]) * t).toFixed(2), 0.72)); } };
  edge([35.1, 40.7], [47.4, 57.4], 6, 0.04, 0.96);
  edge([63.9, 40.7], [47.4, 57.4], 6, 0.24, 0.8);
  edge([35.1, 40.7], [63.9, 40.7], 7, 0.16, 0.76);
  return dots.join('');
})();
const PAISLEYS = [[41.6, 45.2, 2, 22], [55.4, 45.2, 1.95, -32], [48.4, 51.8, 1.75, 6]];
const BANDANA_KNOT = roundPoly([[66.4, 37.6], [71.4, 36.8], [72.4, 41.4], [67.4, 42.6]], [1.8, 1.8, 1.8, 1.8]);
// the two tails start wide under the knot and overlap each other there, so they grow out of it with no gap
// (11-11 round 9b, user: 结和布角的连接处有点分离)
const BANDANA_ENDS = 'M68.8 37.2C71.6 36.2 74.4 34.6 76.8 34C77.9 33.8 78.4 34.8 77.8 35.6C76.4 37.6 73.8 39.6 70.4 40.8Z'
  + 'M70.4 39C73.4 40.2 75.8 42.2 77.2 44.8C77.7 45.7 77 46.4 76.1 45.9C73.6 44.6 71.4 43.6 68.8 42.2Z';
// the vampire cape: black outside, red lining (what shows behind the pet is the inside), a scalloped
// hem, a tall collar standing up behind the head in two broad flaps flaring out (not points: those read as horns)
const VCAPE_OUT = 'M38 29.4C44 31.4 56 31.4 62 29.4L80.4 70.6C81.2 72.6 80.2 74.6 78 74.8C75.6 75 74 76.6 73.4 78.6C70.6 77.2 67.2 77.4 65 79.4C62.2 77.6 58.6 77.6 56.2 79.6C54.2 78 51.6 78 50 79.2C48.4 78 45.8 78 43.8 79.6C41.4 77.6 37.8 77.6 35 79.4C32.8 77.4 29.4 77.2 26.6 78.6C26 76.6 24.4 75 22 74.8C19.8 74.6 18.8 72.6 19.6 70.6Z';
const VCOLLAR_L = roundPoly([[45.6, 34.2], [32.4, 35], [21.8, 19.4], [29.6, 18], [37.8, 23.2]], [1, 1.4, 2.4, 2.4, 1.6]);
// the surfboard (nose up), the yoga mat roll (one end), the pinwheel (four blades round a pin)
const SURF_D = 'M48.6 13.4C49.4 12.4 50.6 12.4 51.4 13.4C55.4 18.6 57.4 27 57.4 38C57.4 50 56.4 60 54.8 64.6C54.2 66 53.2 66.6 51.8 66.6H48.2C46.8 66.6 45.8 66 45.2 64.6C43.6 60 42.6 50 42.6 38C42.6 27 44.6 18.6 48.6 13.4Z';
const PINWHEEL_BLADE = 'M50 28.6L50.8 18.6C51 17.4 52.2 16.8 53.2 17.4C57.4 19.8 59.4 24.4 58.8 28.6Z';
/** n points along a smile from (x0, y0) to (x1, y0) through (50, ymid). */
const smilePts = (n, x0, x1, y0, ymid) => Array.from({ length: n }, (_, i) => {
  const t = i / (n - 1), u = 1 - t;
  return [u * u * x0 + 2 * u * t * 50 + t * t * x1, u * u * y0 + 2 * u * t * (2 * ymid - y0) + t * t * y0];
});
/** 11-11 round 8 (user: 珍珠加一点阴影高光): pearls at pts (radius rr(i)), a crescent of shadow low on the
 *  right of each and a small shine high on the left. */
const pearlPiece = (pts, rr) => ({
  d: pts.map(([x, y], i) => circ(r2(x), r2(y), r2(rr(i)))).join(''), color: '#FBF5EC', alt: '#EBD6BC', rule: 'nonzero',
  paints: [
    { d: pts.map(([x, y], i) => circ(r2(x), r2(y), r2(rr(i))) + hole(r2(x - 0.3 * rr(i)), r2(y - 0.36 * rr(i)), r2(0.92 * rr(i)))).join(''), color: '#E2D0B8', alt: '#CDB08A' },
    { d: pts.map(([x, y], i) => circ(r2(x - 0.34 * rr(i)), r2(y - 0.36 * rr(i)), r2(0.27 * rr(i)))).join(''), color: '#FFFFFF' },
  ],
});
const PEARLS_PC = pearlPiece(smilePts(7, 31.4, 68.6, 40.6, 48.6), (i) => (i === 3 ? 3.6 : 3.3));
// a flower: five round petals round a centre of the same colour (round 6: no centre dot)
const flowerAt = (cx, cy, r) => [0, 1, 2, 3, 4].map((k) => { const a = (-90 + 72 * k) * D2R; return circ(r2(cx + 0.6 * r * Math.cos(a)), r2(cy + 0.6 * r * Math.sin(a)), r2(0.44 * r)); }).join('') + circ(r2(cx), r2(cy), r2(0.56 * r));
const LEI_D = (() => {
  const out = ['', '', ''];
  smilePts(5, 32, 68, 40.6, 49.4).forEach(([x, y], i) => { out[i % 3] += flowerAt(x, y, 4.2); });
  return out;
})();
const DECOR = [
  // ---------------- 头顶 head ----------------
  { id: 'santa', zh: '圣诞帽', en: 'Santa hat', slot: 'head', culture: '圣诞节', place: 'hat', flat: true, A: [50, 59.5], W0: 30, fitW: 0.4, lo: 23, hi: 34, deep: 4.5, flip: true,
    // 11-09 lighter (user: 太厚重): a slim cone that flops over, a thin fur band, a small pom
    pieces: [
      // 11-10 (user: 帽球和帽身连接处转身穿模): the flopping end tapers to a slim tip, and the pom sits
      // wholly in front of it (dz): the tip only ever goes behind the pom, never through it
      { d: D(`M37.2 56.4C37.2 47.6 40.6 39.2 47.4 34.8C53.4 30.9 61.6 30.4 66.8 33.6C68.6 34.7 69.9 36.2 70.6 38
             C70.8 38.6 70.2 39 69.7 38.6C68.6 37.4 67 36.9 65 37.4C61.8 38.2 60.7 42.6 61.4 47.6C61.8 50.6 62.3 53.6 62.8 56.4Z`), color: DC.red, vol: 0.7, nowrap: true },
      { d: rrect(35.4, 55.4, 64.6, 61, 2.8), color: DC.fur, vol: 0.9, rim: 0.8, dz: 0.4, cut: 1 },
      // 11-10 (user: 帽球和帽身连接处转身穿模): a rounder, deeper pom centred on the tip's end, so the
      // tip stays inside it at any turn; it swings round a point near its own centre
      { d: circ(70, 39.3, 3.4), color: DC.fur, vol: 0.9, rim: 0.5, dz: 5.6, pivot: [69.6, 38.6], dangle: 0.6 },
    ] },
  { id: 'halo', zh: '天使光环', en: 'Halo', slot: 'head', culture: '天使', place: 'halo', A: [50, 50], W0: 30, fitW: 0.36, lo: 20, hi: 30,
    pieces: [{ d: ringD(50, 50, 15, 11.6), color: DC.gold, vol: 0.55 }] },
  // ---- 11-10 floating head pieces (user: head things must not touch the pet; like the halo) ----
  // place 'float': the art's foot (A) floats `gap` above the highest point of the head under it; it bobs
  // 11-10 round 5 (user): the little cloud became 下雨天, a grey rain cloud that keeps raining; it floats
  // higher, and the drops fade out before they get anywhere near the head
  { id: 'rain', zh: '下雨天', en: 'Rain cloud', slot: 'head', culture: '下雨天 / 宅家', place: 'float', A: [50, 56], W0: 32.4, fitW: 0.46, lo: 26, hi: 32, gap: 9.5, isNew: true,
    rain: { xs: [43.6, 50.4, 57.2, 46.8, 53.8], y0: 55.2, per: 0.95, color: '#7FB3DE' },
    pieces: [{ d: D(`M40 56C36.4 56 34 53.6 34 50.6C34 47.8 36.2 45.6 39 45.4C39.6 41.4 43 38.4 47 38.4C50.2 38.4 53 40.2 54.3 42.9
        C55.2 42.5 56.2 42.3 57.2 42.3C61 42.3 64.1 45.2 64.4 48.9C65.6 49.6 66.4 50.9 66.4 52.4C66.4 54.4 64.8 56 62.8 56Z`),
      color: '#CBD5DF', vol: 0.5 }] },
  // 11-11 round 8 (user): the moon became a light bulb lighting up (灵光一闪, 想到了). It floats as the
  // moon did; its rays pop out from behind the glass every few seconds (blink), the glass stays lit
  { id: 'bulb', zh: '灵光灯泡', en: 'Bright idea', slot: 'head', culture: '灵光一闪 / 想到了', place: 'float', A: [50, 57.4], W0: 28, fitW: 0.42, lo: 23, hi: 29, gap: 4, sway: 4, isNew: true,
    pieces: [
      { d: RAYS_D, color: '#FFC83D', vol: 0.4, dz: -0.6, pivot: [50, 40.6], blink: 2.8 },
      { d: BULB_D, color: '#FFD84D', vol: 0.62 },
      { d: rrect(45.8, 49.4, 54.2, 54.6, 1.6), color: '#A9B3BB', vol: 0.55, dz: 0.1, paints: [{ d: BAND(51.2, 52.8), color: '#7E878F' }] },
      { d: rrect(47.6, 54, 52.4, 57.4, 1.6), color: '#7E878F', vol: 0.5 },
    ] },
  // (11-10: a star ring was tried and dropped: stars round the head already mean 晕乎乎, the dizzy face)
  // a butterfly hovering by the head: wings beat by narrowing (flat, in their own plane), it drifts
  { id: 'butterfly', zh: '小蝴蝶', en: 'Butterfly', slot: 'head', culture: '春天 / 轻盈', place: 'float', A: [50, 56], W0: 23, fitW: 0.34, lo: 19, hi: 24, gap: 3.6, dx: 0.2, flap: true, sway: 7,
    pieces: [
      { d: D(`M49.2 50.4C47.6 46.2 44.4 42.8 41 42.4C38.6 42.2 37.6 44 38.4 46.2C39.2 48.4 41.4 49.8 43.6 50.6C41.4 51.4 40 53.4 40.6 55.2C41.2 57 43.4 57.4 45.4 56.2C47.4 55 48.8 52.8 49.2 50.4Z
             M50.8 50.4C52.4 46.2 55.6 42.8 59 42.4C61.4 42.2 62.4 44 61.6 46.2C60.8 48.4 58.6 49.8 56.4 50.6C58.6 51.4 60 53.4 59.4 55.2C58.8 57 56.6 57.4 54.6 56.2C52.6 55 51.2 52.8 50.8 50.4Z`),
        color: DC.coral, alt: DC.sky, vol: 0.32,
        paints: [{ d: circ(42.4, 46, 1.5) + circ(57.6, 46, 1.5), color: DC.cream, face: true }, { d: circ(44, 54, 0.9) + circ(56, 54, 0.9), color: DC.cream, face: true }] },
      { d: rrect(49.1, 45.6, 50.9, 55.8, 0.9), color: '#3B2A22', vol: 0.5, dz: 0.2 },
      { d: D(`M49.5 46C49 44.2 47.8 42.8 46.4 42.2L46.7 41.6C48.3 42.3 49.6 43.9 50.2 45.9ZM50.5 46C51 44.2 52.2 42.8 53.6 42.2L53.3 41.6C51.7 42.3 50.4 43.9 49.8 45.9Z`), color: '#3B2A22', vol: 0.3, dz: 0.2 },
    ] },
  { id: 'crown', zh: '小皇冠', en: 'Crown', slot: 'head', culture: '国王', place: 'hat', flat: true, A: [50, 59.5], W0: 28, fitW: 0.39, lo: 22, hi: 32, base: 0, deep: 7,
    pieces: [
      { d: D(`M36 61V45.5C36 44.6 36.9 44.1 37.6 44.6L43.2 48.6L49.1 37.9C49.5 37.2 50.5 37.2 50.9 37.9L56.8 48.6L62.4 44.6
             C63.1 44.1 64 44.6 64 45.5V61Z`), color: DC.gold, vol: 1, cut: 1,
        paints: [{ d: circ(50, 55.2, 2.3), color: DC.red, face: true }, { d: circ(42.2, 55.6, 1.25), color: DC.cream, face: true }, { d: circ(57.8, 55.6, 1.25), color: DC.cream, face: true }] },
      { d: circ(36.6, 43.4, 2.1) + circ(50, 36.6, 2.4) + circ(63.4, 43.4, 2.1), color: DC.gold, vol: 0.8, dz: 0.2 },
    ] },
  { id: 'horns', zh: '小恶魔角', en: 'Devil horns', slot: 'head', culture: '万圣节', place: 'pair', flat: true, A: [50, 60], W0: 10, fitW: 0.14, lo: 8.5, hi: 12, sep: 2.2, splay: 14,
    pieces: [{ d: D(`M45 61C45 53 44 47.2 41 42.3C40.6 41.6 41.2 40.9 41.9 41.3C46.6 43.8 51.4 48 53.6 53.2C54.6 55.6 55 58.2 55 61Z`), color: DC.red, vol: 0.9 }] },
  // 11-10 (user): the three hats deleted in round 4 are back, drawn as ONE flat layer (flatMarkup)
  // instead of as sliced solids that the head can poke through; 11-10 round 5: every head piece that
  // touches the pet (santa, crown, horns too) is drawn this way
  { id: 'party', zh: '生日帽', en: 'Party hat', slot: 'head', culture: '生日', place: 'hat', flat: true, A: [50, 59.5], W0: 25, fitW: 0.36, lo: 22, hi: 30, base: 0, deep: 6,
    pieces: [
      // 11-10: the cone keeps its own slim depth (nowrap) so the ball can hold its tip; the wrapping
      // the head needs (pad) is done by a base of the same colour and stripe, hidden inside the cone
      { d: D(`M37.5 60C42 48 45.6 37.6 48.3 30.8C48.9 29.3 51.1 29.3 51.7 30.8C54.4 37.6 58 48 62.5 60C55 61.4 45 61.4 37.5 60Z`), color: DC.coral, vol: 0.6, cut: 1.5, nowrap: true,
        paints: [{ d: BAND(50.5, 54.2), color: DC.cream }, { d: BAND(39.5, 42.6), color: DC.cream }] },
      // (it starts right on the lower stripe's top edge, so where it is deeper than the cone, the step is a colour edge too)
      { d: D(`M41.01 50.5H58.99L62.5 60C55 61.4 45 61.4 37.5 60Z`), color: DC.coral, vol: 1, cut: 1.5, pad: 3,
        paints: [{ d: BAND(50.5, 54.2), color: DC.cream }] },
      // 11-10 (user: 圆球包裹住帽尖): the ball sits down over the tip and is deep enough to hold it
      { d: circ(50, 31, 4.5), color: DC.gold, vol: 0.85, rim: 0.8, dz: 6.2, pivot: [50, 31.4], dangle: 0.4 },
    ] },
  { id: 'tophat', zh: '绅士礼帽', en: 'Top hat', slot: 'head', culture: '绅士', place: 'hat', flat: true, A: [50, 59.5], W0: 34, fitW: 0.44, lo: 26, hi: 38, base: 0, tilt: -6, deep: 2.5,
    pieces: [
      { d: rrect(30.5, 55.2, 69.5, 60.6, 2.7), color: DC.ink, vol: 1.15, cut: 1 },
      { d: D(`M38.4 56.5L37.2 32.4C37.1 30.6 38.3 29.4 40 29.4H60C61.7 29.4 62.9 30.6 62.8 32.4L61.6 56.5Z`), color: DC.ink, vol: 1, dz: -0.2,
        paints: [{ d: BAND(48.6, 54.2), color: DC.jade }] },
    ] },
  { id: 'chef', zh: '厨师帽', en: 'Chef hat', slot: 'head', culture: '厨房', place: 'hat', flat: true, A: [50, 59.5], W0: 28, fitW: 0.38, lo: 22, hi: 32, base: 1, deep: 8,
    pieces: [
      { d: D(`M37 53V42.6C34 41.2 32.2 38.4 32.2 35.2C32.2 30.4 36.2 26.6 41 26.6C42 26.6 43 26.8 43.9 27.1C45.4 23.9 48 22 51.2 22
             C54.6 22 57.4 24.1 58.6 27.2C59.4 27 60.2 26.9 61 26.9C65.5 26.9 69 30.5 69 35C69 38.4 66.9 41.3 63 42.6V53Z`), color: DC.fur, vol: 1, rim: 1.1 },
      { d: rrect(35.8, 50.5, 64.2, 61, 2.2), color: DC.fur, vol: 1.1, rim: 1.1, dz: 0.3, cut: 1 },
    ] },
  // 11-11 round 8 (user): a cowboy hat: a wide brim turned up at both sides, a crown dented in the
  // middle, one dark band (one flat layer, like the other hats)
  { id: 'cowboy', zh: '牛仔帽', en: 'Cowboy hat', slot: 'head', culture: '西部牛仔', place: 'hat', flat: true, A: [50, 59.5], W0: 47, fitW: 0.68, lo: 38, hi: 56, base: 0, deep: 3, isNew: true,
    pieces: [
      // round 9 (user: 颜色会跟面包人的轮廓重合): deep brown felt, a light band; straw-coloured on brown pets
      { d: COWBOY_CROWN, color: '#6E4A35', alt: '#E3C792', dz: -0.2, paints: [{ d: BAND(50.4, 54.2), color: '#E8CFA0', alt: '#7A4E2B', follow: true }] },
      { d: COWBOY_BRIM, color: '#5C3D2B', alt: '#D6B47A' },
    ] },
  { id: 'glasses', zh: '绅士圆眼镜', en: 'Round glasses', slot: 'eyes', culture: '绅士', place: 'eyes', A: [50, 50], W0: 17,
    pieces: [
      // round 3: bigger lenses (the eyes sit towards the nose side of each) and a thicker frame
      { d: ringD(39.8, 50, 9.2, 7.2) + ringD(60.2, 50, 9.2, 7.2), color: DC.wire, alt: '#F2D58A', vol: 0.36 },
      { d: D(`M47.6 46.6C49.1 45.2 50.9 45.2 52.4 46.6L52 48.2C50.8 47.1 49.2 47.1 48 48.2Z`), color: DC.wire, alt: '#F2D58A', vol: 0.44 },
      { lens: [[39.8, 50, 7.05], [60.2, 50, 7.05]], dz: 0.1 },
    ] },

  // ---- 11-10 round 5 (user: every slot about as many as the head): flat pieces, one layer each ----
  // place 'specs': on the eyes (art units: eye centres at 41.5 / 58.5, s = eye spacing / 17), one flat
  // layer just in front of the eyes. Lenses are open or see-through: the eyes and every expression show.
  // 11-10 round 6 (user: 画风跟宠物的设计规范有差别): every round-5 piece redrawn to the pets' rules: solid
  // flat colour, no outline (rim), no shine or highlight line, nothing thinner than ~1.5 units, round tips
  // and corners, no rows of small dots or fine stripes (stripes run level), one or two features each;
  // a lens keeps one light tint so the eyes and every expression still show.
  // 11-11 round 8 (user, a photo): odd-shaped flirty shades: a chunky white frame, a small square lens
  // on the left, a big slanted one on the right, dark see-through lenses
  { id: 'wildshades', zh: '不规则墨镜', en: 'Odd shades', slot: 'eyes', culture: '拍照 / 挑眉搞怪', place: 'specs', flat: true, A: [50, 50], isNew: true,
    pieces: [
      { d: WILD_L_IN + WILD_R_IN, color: DC.ink, op: 0.55, dz: -1 },
      { d: WILD_L_OUT + WILD_L_IN + WILD_R_OUT + WILD_R_IN, color: DC.white, alt: DC.ink, clash: 90 },
      { d: rrect(47.4, 46.2, 52.4, 49.6, 1.4), color: DC.white, alt: DC.ink, clash: 90, dz: -0.1 },
    ] },
  { id: 'starglasses', zh: '星星眼镜', en: 'Star glasses', slot: 'eyes', culture: '派对 / 明星', place: 'specs', flat: true, A: [50, 50], isNew: true,
    pieces: [
      { d: softStar(39.2, 50.8, 15.6, 9.6, 1.8, 1.2) + circ(39.2, 50.8, 7.2), color: DC.gold, alt: DC.coral },
      { d: softStar(60.8, 50.8, 15.6, 9.6, 1.8, 1.2) + circ(60.8, 50.8, 7.2), color: DC.gold, alt: DC.coral, dz: 0.1 },
    ] },
  { id: 'sunglasses', zh: '酷墨镜', en: 'Sunglasses', slot: 'eyes', culture: '夏天 / 酷', place: 'specs', flat: true, A: [50, 50], isNew: true,
    pieces: [
      { d: 'M30.6 45.6H48.4C49.2 45.6 49.6 46.2 49.4 47L48.4 53.2C47.9 56.2 45.8 58 42.8 58H37.2C34 58 31.7 56.1 31.1 53L29.6 46.8C29.4 46.1 29.9 45.6 30.6 45.6Z'
        + 'M69.4 45.6H51.6C50.8 45.6 50.4 46.2 50.6 47L51.6 53.2C52.1 56.2 54.2 58 57.2 58H62.8C66 58 68.3 56.1 68.9 53L70.4 46.8C70.6 46.1 70.1 45.6 69.4 45.6Z', color: DC.ink, op: 0.56 },
      { d: rrect(28.2, 43.2, 71.8, 46.6, 1.7), color: DC.ink, alt: DC.berry },
    ] },
  // 11-11 round 8 (user, a photo): the swim goggles became a snorkel mask: one window over both eyes,
  // a mint skirt round the frame (it shows under the nose bridge), strap ends, a snorkel up the right side
  { id: 'snorkel', zh: '浮潜面镜', en: 'Snorkel mask', slot: 'eyes', culture: '浮潜 / 海边', place: 'specs', flat: true, A: [50, 50], isNew: true,
    pieces: [
      { d: rrect(22.4, 46.4, 30, 53.2, 2.4) + rrect(70, 46.4, 77.6, 53.2, 2.4), color: '#5CCFB0', alt: '#9CC7E6', dz: -1.3 },
      { d: capsule(78.6, 52.4, 78.6, 30, 3.6), color: '#1E3A4C', alt: '#3D5A80', dz: -1.2 },
      { d: rrect(75.6, 20.6, 81.6, 32.4, 2.6), color: '#7FE0C2', alt: '#9CC7E6', dz: -1.1 },
      { d: MASK_WIN, color: '#CFEFF0', op: 0.3, dz: -1 },
      { d: MASK_SKIRT + MASK_WIN, color: '#7FE0C2', alt: '#9CC7E6', dz: -0.5 },
      { d: MASK_OUT + MASK_WIN, color: '#1E5A63', alt: DC.ink },
    ] },
  { id: 'skigoggles', zh: '滑雪镜', en: 'Ski goggles', slot: 'eyes', culture: '滑雪 / 冬天', place: 'specs', flat: true, A: [50, 50], isNew: true,
    pieces: [
      { d: rrect(23.4, 47.2, 31, 53.2, 2.4) + rrect(69, 47.2, 76.6, 53.2, 2.4), color: DC.coral, alt: '#5FA8D8', dz: -1 },
      { d: SKI_D, color: DC.ink, alt: DC.jade, line: 3.4 },
      { d: SKI_D, color: '#F2A65A', op: 0.45, dz: 0.1 },
    ] },
  { id: 'monocle', zh: '单片眼镜', en: 'Monocle', slot: 'eyes', culture: '侦探', place: 'specs', flat: true, A: [50, 50], isNew: true,
    pieces: [
      { d: circ(59.6, 50.4, 7.6), color: '#CDEBF7', op: 0.25, dz: -1 },
      { d: 'M66.8 57C68.6 59.8 69 62.8 67.8 65.8', color: DC.gold, alt: DC.ink, line: 1.8, pivot: [66.8, 57], dangle: 0.6, dz: -0.5 },
      { d: circ(59.6, 50.4, 10.2) + circ(59.6, 50.4, 7.6), color: DC.gold, alt: DC.ink },
    ] },
  { id: 'glasses3d', zh: '3D 眼镜', en: '3D glasses', slot: 'eyes', culture: '电影院', place: 'specs', flat: true, A: [50, 50], isNew: true,
    pieces: [
      { d: rrect(30.8, 45, 48.4, 56.2, 2.2), color: '#E2584B', op: 0.5, dz: -1 },
      { d: rrect(51.6, 45, 69.2, 56.2, 2.2), color: '#4FB8D8', op: 0.5, dz: -1 },
      { d: rrect(28.2, 42.4, 71.8, 58.8, 4.2) + rrect(30.8, 45, 48.4, 56.2, 2.2) + rrect(51.6, 45, 69.2, 56.2, 2.2), color: DC.white, alt: DC.ink },
    ] },
  { id: 'nerdglasses', zh: '学霸眼镜', en: 'Square glasses', slot: 'eyes', culture: '学霸 / 读书', place: 'specs', flat: true, A: [50, 50], isNew: true,
    pieces: [
      { d: rrect(31.6, 45, 46.8, 55.8, 2.6) + rrect(53.2, 45, 68.4, 55.8, 2.6), color: DC.white, op: 0.16, dz: -1 },
      { d: rrect(29, 42.4, 49.4, 58.4, 4.6) + rrect(31.6, 45, 46.8, 55.8, 2.6), color: DC.ink, alt: DC.gold },
      { d: rrect(50.6, 42.4, 71, 58.4, 4.6) + rrect(53.2, 45, 68.4, 55.8, 2.6), color: DC.ink, alt: DC.gold },
      { d: rrect(48.4, 46.2, 51.6, 48.8, 1.3), color: DC.ink, alt: DC.gold },
    ] },
  { id: 'sportglasses', zh: '运动镜', en: 'Sport shades', slot: 'eyes', culture: '跑步', place: 'specs', flat: true, A: [50, 50], isNew: true,
    pieces: [
      { d: 'M27 46.6C27 44 29 42.8 31.8 42.8H68.2C71 42.8 73 44 73 46.6C73 52.8 69 57.6 62.6 57.6C57.6 57.6 55.4 53.8 52.4 52C51 51.2 49 51.2 47.6 52C44.6 53.8 42.4 57.6 37.4 57.6C31 57.6 27 52.8 27 46.6Z', color: '#6C7FD1', op: 0.6 },
      { d: rrect(26.2, 41, 73.8, 44.8, 1.9), color: DC.ink, alt: DC.coral },
    ] },
  // ---------------- 嘴边 mouth ----------------
  { id: 'beard', zh: '白胡子', en: 'Wizard beard', slot: 'mouth', culture: '魔法师 / 圣诞老人', place: 'mouth', A: [50, 49], W0: 32, fitW: 1.9, H0: 32.6,
    // 11-09 wizard (user: 更有魔法师的睿智感): longer than wide, wavy, ending in a point that curls a
    // little, three flowing strands; a moustache drooping over it into two long tips
    pieces: [
      { d: BEARD_D,
        color: DC.fur, vol: 0.42, rim: 1.0, jaw: 0.6, rimOut: MOUSTACHE_D,
        paints: [
          // 11-11 round 8 (user: 三根竖线更自然): curved locks that follow the beard's waves, tapering, of
          // different lengths: one sweeping in from each side, a long one curling with the tip
          { d: D(`M41.4 58.8C39.8 62.4 40.2 66.4 42.8 69.6C43.4 70.2 44.2 69.8 43.8 69.1C42.2 66 42.2 62.6 43.2 59.4Z`), color: DC.furRim, face: true },
          { d: D(`M58.4 59.6C60.4 62.8 60.4 66.2 58.6 68.8C58.1 69.5 57.3 69 57.6 68.3C58.8 65.6 58.6 62.8 56.9 60.2Z`), color: DC.furRim, face: true },
          { d: D(`M49.2 60.6C47.6 64.6 47.8 69 49.8 72.8C50.8 74.8 52 76.6 52.6 78.6C52.8 79.2 53.4 79 53.3 78.4C53 76 51.9 74 51.2 72C50 68.4 50 64.6 51 61Z`), color: DC.furRim, face: true },
        ] },
      { d: MOUSTACHE_D,
        color: DC.fur, vol: 0.5, rim: 0.9, dz: 1.2, rimOut: BEARD_D },
    ] },
  { id: 'mustache', zh: '八字胡', en: 'Moustache', slot: 'mouth', culture: '绅士', place: 'mouth', A: [50, 49.2], W0: 34, fitW: 1.75, H0: 7, inkColor: true,
    pieces: [{ d: D(`M50 51.2C47.6 49.3 44.7 48.6 42 49.1C39.6 49.6 37.6 51 35.4 50.6C34 50.3 33.3 49.2 33.6 48C32.4 49.2 32.3 51.2 33.7 52.6
        C35.8 54.6 39.6 54.7 43.2 54C46 53.4 48.3 52.6 50 52.7C51.7 52.6 54 53.4 56.8 54C60.4 54.7 64.2 54.6 66.3 52.6C67.7 51.2 67.6 49.2 66.4 48
        C66.7 49.2 66 50.3 64.6 50.6C62.4 51 60.4 49.6 58 49.1C55.3 48.6 52.4 49.3 50 51.2Z`), color: '#3B2A22', vol: 0.5 }] },

  // place 'muzzle': just under the eyes (art (50, 50) = the mouth line), scaled with the face, one flat
  // layer in front of it. Things held in the mouth sit at its corner, so a yawn still shows.
  // 11-11 round 8 (user): the whistle became a thermometer held in the mouth: a glass stick tipped up,
  // a red line inside, a silver tip at the lips
  { id: 'thermometer', zh: '体温计', en: 'Thermometer', slot: 'mouth', culture: '量体温 / 照顾自己', place: 'muzzle', flat: true, A: [50, 50], W0: 29, H0: 10, tilt: -16, k: 1.32, isNew: true,
    pieces: [
      // 11-11 round 9 (user: 有点潦草，更高级一些): a digital thermometer: a metal probe in the mouth, a
      // white body that narrows to the probe, a teal display with a light reading, a coral button
      { d: capsule(47.6, 52, 57.4, 52, 2.6), color: '#B9C3C9', alt: '#8F9BA3', dz: -0.1 },
      { d: THERMO_BODY, color: '#F7F8F6', alt: '#DCE6EC',
        paints: [{ d: rrect(62.6, 50.2, 70.8, 53.8, 1.2), color: '#3E8F86', alt: '#2F6F8F' },
                 { d: rrect(64, 51.3, 68.2, 52.7, 0.7), color: '#C8F1E6' },
                 { d: circ(74.6, 52, 1.35), color: '#F0806E', alt: '#E2584B' }] },
    ] },
  { id: 'toothbrush', zh: '牙刷', en: 'Toothbrush', slot: 'mouth', culture: '早晚刷牙', place: 'muzzle', flat: true, A: [50, 50], W0: 31, H0: 9, tilt: -6, isNew: true,
    pieces: [
      { d: rrect(54, 50.8, 76, 54.6, 1.9) + rrect(46.4, 50.2, 57.6, 55.2, 2.4), color: '#7FB7E0', alt: DC.coral, rule: 'nonzero', anim: { r: 5, per: 0.34, px: 70, py: 52.6 } },
      { d: rrect(47.2, 46, 56.8, 51, 1.8), color: DC.white, alt: '#DCEFFA', anim: { r: 5, per: 0.34, px: 70, py: 52.6 },
        paints: [{ d: BAND(46, 47.9), color: '#9CD3EE' }] },
      { d: circ(44.4, 54.2, 2.7) + circ(42.6, 51.6, 2) + circ(46.2, 51.4, 1.8), color: DC.white, alt: '#DCEFFA', rule: 'nonzero', dz: 1 },
    ] },
  // 11-11 round 8 (user): still now (no growing), leaning a little to the right, with a soft shadow on
  // its lower side and one shine
  { id: 'bubblegum', zh: '泡泡糖', en: 'Bubble gum', slot: 'mouth', culture: '调皮', place: 'muzzle', flat: true, A: [50, 50], W0: 17, H0: 16, k: 1.2, isNew: true,
    pieces: [
      { d: rell(53, 57.4, 7.6, 7.1, -20), color: '#F48FB8', alt: '#E86FA0',
        paints: [
          { d: rell(53, 57.4, 7.6, 7.1, -20) + rell(51.6, 55.7, 7.3, 6.7, -20, true), color: '#E2709F', alt: '#C9568A' },
          { d: rell(49.4, 53.9, 2.1, 1.25, -40), color: '#FFE4EF' },
        ] },
    ] },
  // 11-11 round 8 (user: 花头更自然): the stem curves up into an upright rose: dark back petals, a cup of
  // two petals (the left one lighter), a curl in the opening, a green calyx
  { id: 'rose', zh: '叼玫瑰', en: 'Rose', slot: 'mouth', culture: '浪漫 / 探戈', place: 'muzzle', flat: true, A: [50, 50], W0: 33, H0: 9, isNew: true,
    pieces: [
      { d: 'M38.2 53.2C45.4 52.2 53.6 52 60.4 53.2C63.2 53.8 65.4 55.2 66.6 57', color: '#5E9B4F', line: 2.2 },
      { d: 'M46.4 52.4C45.2 55.8 41.4 57.6 38.4 56.2C39.8 53.6 42.8 52 46.4 52.4Z', color: '#6FA05C', alt: '#4E8A44' },
      { d: ROSE_AT(ROSE_BACK), color: '#B03228', alt: '#C7404A', dz: 0.1 },
      { d: ROSE_AT(ROSE_CURL), color: '#7E2019', line: 1.6, dz: 0.15 },
      { d: ROSE_AT(ROSE_CUP), color: DC.red, alt: DC.coral, dz: 0.2, paints: [{ d: ROSE_AT(ROSE_FOLD), color: '#EA6A57', alt: '#F7A2B0' }] },
      { d: ROSE_AT(ROSE_CALYX), color: '#5E9B4F', dz: 0.3 },
    ] },
  { id: 'whiskers', zh: '猫胡须', en: 'Cat whiskers', slot: 'mouth', culture: '猫咪', place: 'muzzle', flat: true, A: [50, 50], W0: 40, H0: 9, dy: 0.2, fill: 1.02, isNew: true,
    pieces: [
      { d: 'M40.2 52.4L31.4 50.6M40.2 55.6L31.4 56.6M59.8 52.4L68.6 50.6M59.8 55.6L68.6 56.6', color: '#3B2A22', ink: true, line: 1.7 },
      { d: roundPoly([[46.6, 51], [53.4, 51], [50, 55.2]], [1.4, 1.4, 1.2]), color: DC.coral, alt: DC.berry },
    ] },
  // 11-11 round 8 (user: 不要嘴巴轮廓; one fang with a drop of blood): two white fangs straight on the
  // face (a warm grey edge so they show on white pets), the right one red at the tip, a drop under it
  // round 9 (user: 看着突兀): no outline round the teeth, teeth and drop a size smaller
  { id: 'fangs', zh: '吸血鬼牙', en: 'Vampire fangs', slot: 'mouth', culture: '万圣节', place: 'muzzle', flat: true, A: [50, 50], W0: 16, H0: 15, k: 0.96, isNew: true,
    pieces: [
      { d: roundPoly([[42.4, 50.4], [49, 51.2], [45.6, 59.4]], [0.9, 0.9, 1.5]) + roundPoly([[57.6, 50.4], [54.4, 59.4], [51, 51.2]], [0.9, 1.5, 0.9]), color: DC.white, alt: '#EDE2CF',
        // a cream shadow side on each fang; on a white pet the teeth turn ivory so their shape shows (no outline)
        paints: [{ d: roundPoly([[46.8, 50.9], [49.8, 51.2], [45.6, 60.2], [45.2, 57.4]], 0.4) + roundPoly([[55, 50.6], [58.4, 50.2], [54.6, 60.2], [54.2, 57.4]], 0.4), color: '#E6DED3', alt: '#D6C6AE', rule: 'nonzero' },
                 { d: circ(54.4, 59.3, 2.2), color: '#C7303A' }] },
      { d: tpath('M54.4 60.2C55.6 62 56.6 63.4 56.6 64.6C56.6 65.9 55.6 66.8 54.4 66.8C53.2 66.8 52.2 65.9 52.2 64.6C52.2 63.4 53.2 62 54.4 60.2Z', 54.4, 60.2, 0, 0.82), color: '#C7303A', alt: '#9E1F2A', dz: 0.1 },
    ] },
  { id: 'pacifier', zh: '奶嘴', en: 'Pacifier', slot: 'mouth', culture: '小宝宝', place: 'muzzle', flat: true, A: [50, 50], W0: 16, H0: 15, k: 1.12, isNew: true,
    pieces: [
      { d: circ(50, 60.8, 3.8) + circ(50, 60.8, 1.8), color: '#7FB7E0', alt: DC.coral, pivot: [50, 57], dangle: 0.7, dz: -0.5 },
      { d: 'M42.4 53.8C42.4 50.8 45.4 49.8 50 49.8C54.6 49.8 57.6 50.8 57.6 53.8C57.6 56.8 54.6 58 50 58C45.4 58 42.4 56.8 42.4 53.8Z', color: '#9CC7E6', alt: DC.pink },
      { d: circ(50, 53.9, 2.6), color: DC.white },
    ] },
  // 11-11 round 8 (user, a photo): a round lollipop with a band round its middle on a white stick
  // that pokes out the far side, held sideways at the mouth
  { id: 'lollipop', zh: '棒棒糖', en: 'Lollipop', slot: 'mouth', culture: '甜甜的', place: 'muzzle', flat: true, A: [50, 50], W0: 31, H0: 12, dx: -2, k: 1.15, isNew: true,
    pieces: [
      { d: capsule(52.4, 52.2, 76.2, 56.9, 2.4), color: '#F4EFE6', alt: '#E2D3BC', dz: -0.5 },
      { d: circ(67.6, 55.2, 6.6), color: '#E98BC4', alt: '#9CC7E6' },
      { d: roundPoly([[-1.6, -7.6], [1.6, -7.6], [1.6, 7.6], [-1.6, 7.6]].map(([u, v]) => { const a = 11.2 * D2R; return [67.6 + u * Math.cos(a) - v * Math.sin(a), 55.2 + u * Math.sin(a) + v * Math.cos(a)]; }), 1.4), color: '#F6BFDD', alt: '#CDE3F2', dz: 0.1 },
    ] },
  // ---------------- 脖子 neck ----------------
  { id: 'bowtie', zh: '领结', en: 'Bow tie', slot: 'neck', culture: '绅士 / 派对', place: 'neck', A: [50, 50], W0: 29, fitW: 0.31, lo: 17, hi: 24, H0: 11,
    pieces: [
      { d: D(`M48.4 48.5C45 46 41.5 44.5 38.5 44.5C36.5 44.5 35.5 46 35.5 50C35.5 54 36.5 55.5 38.5 55.5C41.5 55.5 45 54 48.4 51.5H51.6
             C55 54 58.5 55.5 61.5 55.5C63.5 55.5 64.5 54 64.5 50C64.5 46 63.5 44.5 61.5 44.5C58.5 44.5 55 46 51.6 48.5Z`), color: DC.red, alt: DC.ink, vol: 0.55 },
      { d: rrect(46.8, 46.6, 53.2, 53.4, 2.2), color: DC.berry, alt: '#1F2A1D', vol: 0.6, dz: 0.8 },
    ] },
  { id: 'medal', zh: '金牌', en: 'Gold medal', slot: 'neck', culture: '冠军', place: 'neck', A: [50, 40], W0: 16.8, fitW: 0.27, lo: 15, hi: 20, H0: 22.4,
    pieces: [
      { d: D(`M41.6 40H47.8L50 45.6L52.2 40H58.4L53.4 52H46.6Z`), color: DC.jade, alt: DC.ink, vol: 0.35, paints: [{ d: BAND(40, 41.9), color: DC.lime }] },
      { d: circ(50, 55.6, 6.8), color: DC.gold, vol: 0.42, rim: 0.85, rimColor: '#B98327', dz: 0.9, pivot: [50, 50], dangle: 0.5,
        paints: [{ d: starPath(50, 55.8, 3.6, 1.6), color: '#C99032', face: true }] },
    ] },
  { id: 'scarf', zh: '围巾', en: 'Scarf', slot: 'neck', culture: '冬天', place: 'band', band: { at: 'neck', h: 7.4, o: 1.7, color: DC.red, alt: DC.jade, stripe: null },
    tail: { d: D(`M46.3 49.4H53.7V65.6H46.3Z`), color: DC.red, alt: DC.jade, A: [50, 49.6], vol: 0.55, pivot: [50, 50], dangle: 0.7,
      paints: [{ d: BAND(56.4, 58.2), color: DC.cream }, { d: BAND(60.6, 62.4), color: DC.cream }],
      fringe: D(`M46.5 65H48.1V68.1H46.5ZM48.5 65H50.1V68.6H48.5ZM50.5 65H52.1V68.1H50.5ZM52.1 65H53.5V67.6H52.1Z`) } },

  // place 'collar': hung from the neckline (art (50, 40)) under the face, one flat layer in front of the
  // body; as wide as the body there allows; on a short body it gets shorter (sy) before it gets smaller.
  // a collar is a thin band round the body (copies of its own slices, as the scarf), the bell flat in front
  { id: 'bellcollar', zh: '铃铛项圈', en: 'Bell collar', slot: 'neck', culture: '小猫咪', place: 'band', band: { at: 'neck', h: 3.4, o: 1.3, color: DC.red, alt: DC.jade, stripe: null, dy: 1.6 }, bell: true, isNew: true,
    pieces: [
      { d: 'M32 41H68V44.4H32Z', color: DC.red },
      { d: circ(50, 50.8, 4.8) + rrect(48.4, 45, 51.6, 47.4, 1), color: DC.gold, rule: 'nonzero',
        paints: [{ d: rrect(45.8, 51.2, 54.2, 52.6, 0.7) + circ(50, 53.9, 1.1), color: '#B98327' }] },
    ] },
  { id: 'pearls', zh: '珍珠项链', en: 'Pearl necklace', slot: 'neck', culture: '优雅', place: 'collar', gen: 'pearls', flat: true, A: [50, 40], W0: 37, H0: 11, isNew: true,
    pieces: [PEARLS_PC] },
  { id: 'necktie', zh: '领带', en: 'Necktie', slot: 'neck', culture: '上班族', place: 'collar', flat: true, A: [50, 40], W0: 11, H0: 24.6, k: 1, sy: true, syMin: 0.5, tieUp: 2.4, isNew: true,
    pieces: [
      { d: roundPoly([[47.4, 44.4], [52.6, 44.4], [55.8, 59.4], [50, 65.2], [44.2, 59.4]], [0.6, 0.6, 1.8, 2.4, 1.8]), color: '#3D5A80', alt: DC.berry, pivot: [50, 44.6], dangle: 0.35,
        paints: [{ d: BAND(50.4, 52.6) + BAND(55.8, 58), color: DC.gold }] },
      { d: roundPoly([[45.6, 39.4], [54.4, 39.4], [53, 45.4], [47, 45.4]], [1.2, 1.2, 1.4, 1.4]), color: '#2F4866', alt: '#9E3038', dz: 0.2 },
    ] },
  { id: 'lei', zh: '花环', en: 'Flower lei', slot: 'neck', culture: '度假 / 夏威夷', place: 'collar', gen: 'lei', flat: true, A: [50, 40], W0: 40, H0: 13, isNew: true,
    pieces: [
      { d: LEI_D[0], color: DC.coral, rule: 'nonzero' },
      { d: LEI_D[1], color: DC.gold, alt: '#F2A65A', rule: 'nonzero' },
      { d: LEI_D[2], color: '#F7C9D9', alt: DC.pink, rule: 'nonzero' },
    ] },
  { id: 'locket', zh: '爱心吊坠', en: 'Heart locket', slot: 'neck', culture: '陪伴', place: 'collar', gen: 'locket', flat: true, A: [50, 40], W0: 30, H0: 17, isNew: true,
    pieces: [
      { d: 'M35.6 40C40 46 45.6 49 50 49.6M64.4 40C60 46 54.4 49 50 49.6', color: DC.gold, line: 1.6 },
      { d: heartAt(50, 55.2, 11.4), color: DC.coral, alt: DC.red },
      { d: circ(50, 50.4, 1.5), color: DC.gold, dz: 0.1 },
    ] },
  { id: 'towel', zh: '运动毛巾', en: 'Gym towel', slot: 'neck', culture: '健身', place: 'collar', gen: 'towel', flat: true, A: [50, 40], W0: 36, H0: 19, isNew: true,
    pieces: [
      { d: 'M32 39.6C40 42.8 60 42.8 68 39.6L68 43.2C60 46.4 40 46.4 32 43.2Z', color: '#8CC4E8', alt: DC.lime },
      { d: 'M31.8 40.4H39.8V56.6Q39.8 58.4 38 58.4H33.6Q31.8 58.4 31.8 56.6Z', color: '#8CC4E8', alt: DC.lime, pivot: [35.8, 41], dangle: 0.45, dz: 0.2,
        paints: [{ d: BAND(53.6, 55.4), color: DC.white }] },
      { d: 'M60.2 40.4H68.2V56.6Q68.2 58.4 66.4 58.4H62Q60.2 58.4 60.2 56.6Z', color: '#8CC4E8', alt: DC.lime, pivot: [64.2, 41], dangle: 0.45, dz: 0.2,
        paints: [{ d: BAND(53.6, 55.4), color: DC.white }] },
    ] },
  // 11-11 round 8 (user: 看着像内裤): a neckerchief: one big triangle of cloth, swung a little to the
  // left, the knot at the right side, paisleys (腰果花) and a dotted border on the cloth
  { id: 'bandana', zh: '牛仔方巾', en: 'Bandana', slot: 'neck', culture: '牛仔', place: 'collar', flat: true, A: [50, 38.6], W0: 41.2, H0: 22.8, wSp: 2.73, fillMax: 0.95, at0: true, sy: true, syMin: 0.75, lift: 8, eyeGap: 3, foot: 0.8, isNew: true,
    pieces: [
      { d: BANDANA_ENDS, color: '#B5352B', alt: '#2F4866', dz: -0.1, rule: 'nonzero' },
      { d: BANDANA_TRI, color: DC.red, alt: '#3D5A80',
        paints: [{ d: PAISLEYS.map((p) => paisleyAt(...p)).join(''), color: DC.cream },
                 { d: BANDANA_DOTS, color: DC.cream }] },
      { d: BANDANA_KNOT, color: '#B5352B', alt: '#2F4866', dz: 0.1 },
    ] },
  // ---------------- 背后 back ----------------
  // 11-10 (user): back to the round-2 cloud wing (the round-3 three-feather wing is dropped)
  { id: 'wings', zh: '天使翅膀', en: 'Angel wings', slot: 'back', culture: '天使', place: 'wings', A: [50, 50], W0: 29, fitH: 0.45,
    pieces: [{ d: D(`M50 47.2C55 42 62 38.6 70 38C75 37.7 78.6 39.5 78.6 42.5C78.6 44 77.6 45 76 45.5C78 46.5 78.6 48.5 77.6 50
        C76.8 51.3 75 51.8 73.5 51.6C75 53 75 55 73.8 56.2C72.5 57.5 70.5 57.6 69 56.8C68.8 58.6 67.3 59.9 65.5 59.9C61 59.9 55 56 50 53.2Z`),
      color: DC.fur, vol: 0.38, rim: 1.0 }] },
  { id: 'tail', zh: '恶魔尾巴', en: 'Devil tail', slot: 'back', culture: '万圣节', place: 'tail', A: [50, 62], W0: 22,
    pieces: [{ d: D(`M50 61C55.4 61.4 60.2 60 63.1 56.6C65.4 53.9 66.2 50.8 67.5 48.5L65.2 47.6C64.4 47.3 64.4 46.2 65.2 45.9L72.2 43.6
        C73 43.3 73.7 44 73.5 44.8L72 52C71.8 52.8 70.8 53 70.3 52.3L69.4 50.7C68.3 53.3 67.3 56.6 64.8 59.5C61.4 63.4 56 64.6 50 64.2Z`),
      color: DC.red, vol: 0.6, pivot: [50, 62.6], dangle: 0.9 }] },
  // place 'behind': one flat layer behind the whole pet (nothing of it can come in front); only what
  // reaches past the outline shows. at: where it hangs (see placeDecor).
  { id: 'backpack', zh: '小书包', en: 'Backpack', slot: 'back', culture: '上学', place: 'behind', at: 'side', flat: true, A: [55, 49], W0: 22, fitH: 0.36, fy: 0.5, isNew: true,
    pieces: [
      { d: 'M54.2 37.4V35.8C54.2 31 65.8 31 65.8 35.8V37.4H63.4V36C63.4 33.8 56.6 33.8 56.6 36V37.4Z', color: '#B5352B', alt: '#2F4866', dz: -0.5 },
      { d: rrect(49, 35.6, 71, 62.4, 6.6), color: DC.coral, alt: '#5FA8D8',
        paints: [{ d: rrect(53.2, 48.6, 66.8, 59.6, 3.4), color: DC.cream }] },
    ] },
  { id: 'cape', zh: '超人披风', en: 'Hero cape', slot: 'back', culture: '超级英雄', place: 'behind', at: 'cape', flat: true, A: [50, 30], W0: 60, H0: 50, isNew: true,
    pieces: [{ d: 'M38 29.4C44 31.4 56 31.4 62 29.4L78.4 72C79.4 74.8 78 77.4 75.2 78C66.8 79.8 58.4 78.2 50 78.2C41.6 78.2 33.2 79.8 24.8 78C22 77.4 20.6 74.8 21.6 72Z', color: DC.red, alt: '#3D5A80',
      anim: { r: 2.2, per: 2.4, px: 50, py: 30 } }] },
  // 11-11 round 8 (user): the bat wings became a vampire count's cape: black outside, the red lining
  // showing where it reaches past the pet, a scalloped hem, a tall pointed collar behind the head
  { id: 'vampcape', zh: '吸血鬼披风', en: 'Vampire cape', slot: 'back', culture: '万圣节 / 吸血鬼伯爵', place: 'behind', at: 'cape', flat: true, A: [50, 30], W0: 62, H0: 50, isNew: true,
    pieces: [
      { d: VCAPE_OUT, color: '#2A2230', anim: { r: 2, per: 2.6, px: 50, py: 30 } },
      { d: tpath(VCAPE_OUT, 50, 46, 0, 0.9, 0, 1.4), color: '#B3263A', alt: '#7A3B8F', dz: 0.1, anim: { r: 2, per: 2.6, px: 50, py: 30 } },
      { d: VCOLLAR_L + tpath(VCOLLAR_L, 50, 0, 0, 1).replace(/(-?\d*\.?\d+) (-?\d*\.?\d+)/g, (_, x, y) => `${r2(100 - +x)} ${y}`), color: '#2A2230', dz: 0.2 },
      { d: tpath(VCOLLAR_L, 33.4, 27.4, 0, 0.7) + tpath(VCOLLAR_L, 33.4, 27.4, 0, 0.7).replace(/(-?\d*\.?\d+) (-?\d*\.?\d+)/g, (_, x, y) => `${r2(100 - +x)} ${y}`), color: '#B3263A', alt: '#7A3B8F', dz: 0.3 },
    ] },
  { id: 'fairywings', zh: '仙子翅膀', en: 'Fairy wings', slot: 'back', culture: '童话', place: 'behind', at: 'sides', flat: true, A: [50, 50], W0: 26, fitH: 0.42, isNew: true,
    pieces: [
      { d: 'M50 51C56 52 63 55 64.6 60C65.8 64.4 62 66.6 58.6 64.4C54.4 61.6 51.2 56 50 51.6Z', color: '#F7C9D9', alt: DC.pink, anim: { r: 9, per: 0.7, px: 50, py: 50 } },
      { d: 'M50 49C52 40 60 33 68 33.6C73.6 34 75 39 72 43.4C68.6 48 59 50 50 50.4Z', color: '#BFE3F5', alt: '#9CC7E6', anim: { r: 9, per: 0.7, px: 50, py: 50 } },
    ] },
  { id: 'jetpack', zh: '喷气背包', en: 'Jetpack', slot: 'back', culture: '太空 / 冲呀', place: 'behind', at: 'shoulders', flat: true, A: [50, 44], W0: 13, isNew: true,
    pieces: [
      { d: 'M50 61.4C53.6 64.2 54 68.6 50 73C46 68.6 46.4 64.2 50 61.4Z', color: DC.gold, dz: -1,
        paints: [{ d: 'M50 64C51.8 65.6 52 68.2 50 70.6C48 68.2 48.2 65.6 50 64Z', color: DC.coral }], anim: { s: 0.18, s0: 0.95, per: 0.16, px: 50, py: 61.6 } },
      { d: roundPoly([[45.6, 56.4], [54.4, 56.4], [56, 62.2], [44, 62.2]], [0.6, 0.6, 1.3, 1.3]), color: '#8E979F', dz: -0.5 },
      { d: rrect(43.6, 30, 56.4, 58, 6.4), color: '#D3D9DE', alt: '#9CC7E6',
        paints: [{ d: BAND(36.2, 39.4), color: DC.red }] },
    ] },
  // 11-11 round 8 (user: 气球、网球拍、恐龙背刺换成新的): a surfboard stood on its tail behind the right
  // side, leaning out: its edge shows down the side and its nose rises past the shoulder
  { id: 'surfboard', zh: '冲浪板', en: 'Surfboard', slot: 'back', culture: '冲浪 / 夏天', place: 'behind', at: 'lean', flat: true, A: [50, 66.6], W0: 15, H0: 54, fitH: 1.02, rot: 12, isNew: true,
    pieces: [{ d: SURF_D, color: '#5FB7E6', alt: DC.coral, paints: [{ d: BAND(24.4, 28.6), color: DC.white }] }] },
  // round 9 (user: 瑜伽垫换成其他运动): a barbell resting across the back, the plates out past each side
  { id: 'barbell', zh: '杠铃', en: 'Barbell', slot: 'back', culture: '力量训练 / 健身', place: 'behind', at: 'roll', flat: true, A: [52, 48.6], W0: 14, fy: 0.34, isNew: true,
    pieces: [
      { d: capsule(30, 48.6, 73.6, 48.6, 2.4), color: '#B9C3C9', alt: '#8F9BA3' },
      { d: rrect(57.8, 45.4, 60.2, 51.8, 0.9), color: '#4A545C', dz: 0.1 },
      { d: rrect(60.6, 38.2, 65.6, 59, 2.2), color: '#E0533F', alt: '#3E7CC4', dz: 0.2 },
      { d: rrect(66, 42.4, 69.4, 54.8, 1.6), color: '#2F3A40', alt: '#4A545C', dz: 0.2 },
    ] },
  // a pinwheel tucked behind the back, its wheel up over the right shoulder, turning
  { id: 'pinwheel', zh: '小风车', en: 'Pinwheel', slot: 'back', culture: '童年 / 开心', place: 'behind', at: 'slung', flat: true, A: [50, 46], W0: 22, H0: 46, rot: 16, ks: 1.25, up: 3, isNew: true,
    pieces: [
      { d: capsule(50, 30, 50, 64, 2.4), color: '#E8D9B8', alt: '#B9A27A', dz: -0.5 },
      { d: PINWHEEL_BLADE + tpath(PINWHEEL_BLADE, 50, 28.6, 180), color: DC.coral, alt: DC.red, anim: { w: 120, px: 50, py: 28.6 } },
      { d: tpath(PINWHEEL_BLADE, 50, 28.6, 90) + tpath(PINWHEEL_BLADE, 50, 28.6, 270), color: '#5FB7E6', alt: DC.jade, anim: { w: 120, px: 50, py: 28.6 } },
      { d: circ(50, 28.6, 2.2), color: DC.gold, dz: 0.2 },
    ] },
];
const DECOR_BY_ID = Object.fromEntries(DECOR.map((d) => [d.id, d]));
const SLOTS = [
  { id: 'head', zh: '头顶' }, { id: 'eyes', zh: '眼睛' }, { id: 'mouth', zh: '嘴巴' }, { id: 'neck', zh: '脖子' }, { id: 'back', zh: '背后' },
];
// 11-10 round 5 (user): one decoration per slot, no other limit (the 胸前 slot and its stickers are gone).
// 11-10 (user): no outfits; every decoration stands on its own. (How they are earned: PRD §5.4, check-in points → a draw.)

// Per-pet nudges where the outline alone does not say enough (toppers that should stay visible).
// head: { x, rot, w (width factor), k (size factor past the size limits), dy } for hats; pair: x offset for horns/ears; band: { brow, neck } y.
const FIT_OVERRIDES = {
  // 11-11 round 11 (user): the baguette wears its neck things (not the bow tie, medal or tie) as a sash,
  // upper left to lower right across the loaf, beside the face
  baguette: { head: { rot: -30 }, bandRot: -30, sash: { x: 33.5, y: 59.5, rot: 45, skip: ['necktie'] } },
  // pets with a topper: head things sit beside it on the main part's top (rot 'auto' = follow it)
  // 11-10 round 7: the bubble tea is 1.2× wider and 1.088× taller (pet-svg3d shape sx/sy), the pineapple 1.1× wider:
  // their numbers follow (the lid now starts at y 27.4; x and half scaled about the centre)
  bubbletea: { seatTop: 27.2, head: { x: 32, rot: 'auto', w: 0.8 }, pair: { cx: 50, half: 20.4 } },
  pudding: { wrap: false, head: { x: 61, rot: 'auto', k: 0.55 }, items: { chef: { x: 63.5, k: 0.65 }, tophat: { x: 63.5, k: 0.65 }, party: { x: 63, k: 0.7 }, cowboy: { x: 63.5, k: 0.6 } }, pair: { cx: 50, half: 19 } },
  strawberrycake: { head: { x: 28.5, rot: 'auto', w: 0.8, k: 0.9 }, pair: { cx: 50, half: 19 } },
  lemon: { head: { x: 37, rot: 'auto', w: 0.85 }, pair: { cx: 50, half: 17 } },
  honey: { head: { x: 36.3, rot: -10, w: 0.75 }, pair: { cx: 50, half: 15 } },
  // 11-11 round 10 (user): the pineapple wears them at the lemon's angle, beside its leaves.
  // Pets with a peak (the onigiri's narrow tip, the mantou's swirl, the chili's stem, the milk carton's
  // cap) wear head things at a slant, like the baguette's cowboy hat. The onigiri's hat swallows the
  // tip (deep: how far a peak may go up inside the hat); slant: the hat rests its low end on the
  // shoulder and the peak stays beside it, never under it. cover: a flat hat stands in front of all of
  // the head under it, so no tip or rim shows through its foot (the white edge on the onigiri).
  pineapple: { head: { x: 35, rot: -22, w: 0.85, deep: 8, slant: true }, pair: { cx: 50, half: 23.1 }, cover: true },
  onigiri: { head: { x: 48, rot: -30, deep: 16 }, cover: true },
  mantou: { head: { x: 33, rot: -32, w: 0.9, deep: 8, slant: true }, cover: true },
  chili: { seatAll: true, head: { x: 38, rot: -20, deep: 8, slant: true }, cover: true },
  warmmilk: { head: { x: 38, rot: -30, w: 0.85, deep: 10, slant: true }, cover: true },
};

// ---------- geometry: one decoration piece as a slice object ----------
const DGEO = new Map();
function decorGeom(d, vol = 1, cut = 0, ext = 0) {
  const key = `${vol}|${cut}|${ext}|${d}`;
  let g = DGEO.get(key);
  if (g) return g;
  const body = analyzeBody(d);
  // Flat-bottomed piece (hat bands, brims, the crown): the slices keep their full depth all the way
  // down to the bottom line, and pieceMarkup cuts them straight there. Each slice's outline is the
  // usual erosion of the piece, but measured as if the outline went on far below its lowest `cut`
  // units, so it only rounds off at the top and the ends. An inflated piece otherwise thins to
  // nothing along its bottom edge, and the pet's head shows in front of the hat when it turns.
  const cutY = cut ? body.bounds.maxY : null;
  const stretch = (polys) => polys.map((loop) => loop.map(([x, y]) => [x, y > cutY - cut ? y + 14 : y]));
  // what it looks like from the front: the outline with its lowest `cut` units squared off
  const flat = (polys) => loopsToPath(polys.map((loop) => loop.map(([x, y]) => [x, y > cutY - cut ? cutY : y])));
  const b = body.bounds;
  const def = { version: 1, id: 'decor', name: 'decor', body: { path: d }, eyes: { x: (b.minX + b.maxX) / 2, y: (b.minY + b.maxY) / 2, spacing: 7, scale: 0.6 } };
  const v = buildVolume(def, vol, body);
  const parts = v.parts.map((part) => {
    let field = null;
    const seen = new Map();
    const slices = [];
    const flatD = cut ? flat(part.polys) : null;
    for (const s of part.zSlices) {
      const id = s.at.toFixed(3);
      if (seen.has(id)) continue; // a level once (refinement slices of thin parts become full contours)
      let sd = flatD ?? s.d, box = s.box;
      const ero = part.kind === 'inflate' && s.at !== 0 ? erosionAt(part, Math.abs(s.at)) : 0;
      if (s.at !== 0) {
        let loops = null;
        if (part.kind === 'inflate') {
          const e = erosionAt(part, Math.abs(s.at));
          if (e > 1e-3) {
            if (!field) { const sp = cut ? stretch(part.polys) : part.polys; field = distanceField(sp, cut ? bounds(sp) : part.bounds); }
            loops = contourLoops(field, e).filter((l) => l.length >= 3);
          }
        } else loops = revolveLoops(part, Math.abs(s.at), vol).filter((l) => l.length >= 3);
        if (loops && loops.length) {
          sd = loops.map(smoothLoop).join('');
          const bb = bounds(loops);
          box = { x: bb.minX, y: bb.minY, w: bb.maxX - bb.minX, h: bb.maxY - bb.minY };
        }
      }
      seen.set(id, 1);
      slices.push({ at: s.at, d: sd, box, evenOdd: s.at !== 0 || s.evenOdd, ero });
    }
    slices.sort((m, n) => m.at - n.at);
    if (ext > 0) {
      // Extruded: the full outline (the core) runs from -ext to +ext, and the piece's own rounded
      // edge comes after it at both ends. A hat that wraps the head keeps its whole front face in
      // front of it; made deeper by inflating instead, its front would shrink as it got deeper.
      const core = slices.find((x) => x.at === 0) ?? slices[Math.floor(slices.length / 2)];
      const n = Math.ceil(ext / 0.9), out = [];
      for (const x of slices) if (x.at < 0) out.push({ ...x, at: x.at - ext });
      for (let k = -n; k <= n; k++) out.push({ ...core, at: (ext * k) / n, ero: 0 });
      for (const x of slices) if (x.at > 0) out.push({ ...x, at: x.at + ext });
      return { d: flatD ?? part.d, slices: out, half: part.depth / 2 + ext, bounds: part.bounds };
    }
    return { d: flatD ?? part.d, slices, half: part.depth / 2, bounds: part.bounds };
  });
  g = { parts, half: Math.max(...parts.map((p) => p.half)), bounds: b, cutY };
  DGEO.set(key, g);
  return g;
}

let decorUid = 0;
const D2R_ = Math.PI / 180;
const DU = (n) => `${r2(n)}cqw`;
const FILL3D = 'position:absolute;left:0;top:0;width:100%;height:100%;transform-style:preserve-3d;';
const r4 = (n) => Math.round(n * 1e4) / 1e4;
const DU4 = (n) => `${r4(n)}cqw`;
/** Slice svg at a common raster box (all slices of a part share it, see pieceMarkup). */
function boxStyle(x, y, w, h) { return `left:${DU4(x)};top:${DU4(y)};width:${DU4(w)};height:${DU4(h)}`; }

/**
 * Markup of one decoration piece: a stack of z slices, like the pet's own.
 * Every slice of a part is rasterised in ONE shared box (the part's bounds plus the rim), so all
 * of them sit at the same fraction of a device pixel and colour edges drawn across slices (bands,
 * rims, stickers) line up when the slices fan out in a turn — the pets solve the same problem by
 * snapping each slice corner to the pixel grid (alignSlices); mountDecor snaps the shared box too.
 * Data on each slice: at (depth), inset (how far its outline sits inside the part's), keep (paint).
 */
function pieceMarkup(pc, color) {
  if (pc.lens) {
    const z = pc.dz ?? 0;
    const lens = pc.lens.map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}" fill="#fff" opacity=".2"/>`
      + `<path d="M${r2(x + r * 0.28)} ${r2(y - r * 0.78)}L${r2(x + r * 0.62)} ${r2(y - r * 0.42)}M${r2(x + r * 0.5)} ${r2(y - r * 0.82)}L${r2(x + r * 0.78)} ${r2(y - r * 0.54)}" stroke="#fff" stroke-width=".85" stroke-linecap="round" opacity=".8"/>`).join('');
    return `<svg data-lens="1" viewBox="0 0 100 100" style="position:absolute;left:0;top:0;width:100%;height:100%;overflow:visible;transform:translateZ(${DU(z)})">${lens}</svg>`;
  }
  const g = decorGeom(pc.d, pc.vol ?? 1, pc.cut ?? 0, pc.ext ?? 0);
  const rimC = pc.rimColor ?? (luma(hexOf(color)) > 0.85 ? DC.furRim : shadeC(color, 0.13));
  const pad = 0.6 + (pc.rim ?? 0);
  let out = '';
  for (const [pi, part] of g.parts.entries()) {
    const front = part.slices[part.slices.length - 1].at;
    const pb = part.bounds;
    const x = pb.minX - pad, y = pb.minY - pad, w = pb.maxX - pb.minX + 2 * pad;
    // a flat-bottomed piece is cut straight at its bottom line (the box ends there, overflow hidden)
    const h = g.cutY !== null ? g.cutY - y : pb.maxY - pb.minY + 2 * pad;
    const clip = g.cutY !== null ? 'hidden' : 'visible';
    for (const s of part.slices) {
      const rule = s.evenOdd ? ' fill-rule="evenodd"' : '';
      const paints = (pc.paints || []).filter((p) => !p.face || s.at === front);
      // inset: how far this slice's outline sits inside the part's outline (0 = it makes the silhouette)
      // (a flat-bottomed piece's slices all reach its bottom line, so none is ever hidden inside it)
      const inset = g.cutY !== null ? 0 : s.ero > 0 ? s.ero : Math.max(0, Math.min(s.box.x - pb.minX, pb.maxX - s.box.x - s.box.w, s.box.y - pb.minY, pb.maxY - s.box.y - s.box.h));
      let inner = '';
      if (pc.rim || paints.length) {
        // paint and rim reach a little past the slice edge (the mask's stroke is twice the seal's), so
        // they cover the base colour's anti-aliased edge: no pink hatching on a turned stripe (the
        // pets' sealPaint does the same)
        const cid = `dc${++decorUid}`;
        // rimOut: a shape (in piece units) the rim is not drawn over, kept back 1.2 from its edge so the
        // rim still outlines the piece where it reaches past that shape (the moustache over the beard)
        const ro = pc.rim && pc.rimOut ? `dr${++decorUid}` : null;
        const box = `x="${r2(x)}" y="${r2(y)}" width="${r2(w)}" height="${r2(h)}"`;
        const rimOutDefs = ro ? `<mask id="${ro}a" maskUnits="userSpaceOnUse" ${box}><rect ${box} fill="#fff"/><path d="${pc.rimOut}" fill="#000" stroke="#fff" stroke-width="2.4"/></mask>`
          + `<mask id="${ro}b" maskUnits="userSpaceOnUse" ${box}><path d="${pc.rimOut}" fill="#fff" stroke="#000" stroke-width="2.4"/></mask>` : '';
        inner = `<mask id="${cid}" maskUnits="userSpaceOnUse" x="${r2(x)}" y="${r2(y)}" width="${r2(w)}" height="${r2(h)}"><path d="${s.d}"${rule} fill="#fff" stroke="#fff" stroke-width=".9" stroke-linejoin="round"/></mask><g mask="url(#${cid})">`
          + paints.map((p) => `<path d="${p.d}" fill="${p.color}"/>`).join('')
          + (pc.rim ? rimOutDefs + `<path d="${part.d}" fill="none" stroke="${rimC}" stroke-width="${r2(pc.rim * 2)}" stroke-linejoin="round"${ro ? ` mask="url(#${ro}a)"` : ''}/>` : '')
          // under the rimOut shape the slice's rim-coloured seal is painted back in the base colour
          + (ro ? `<path d="${s.d}"${rule} fill="${color}" stroke="${color}" stroke-width=".9" stroke-linejoin="round" mask="url(#${ro}b)"/>` : '')
          + `</g>`;
      }
      const z = s.at + (pc.dz ?? 0);
      out += `<svg data-part="${pi}" data-at="${r4(s.at)}" data-inset="${r2(inset)}"${paints.some((p) => p.face) ? ' data-keep="1"' : ''} data-bx="${r4(x)}" data-by="${r4(y)}" data-bw="${r4(w)}" data-bh="${r4(h)}"`
        + ` viewBox="${r4(x)} ${r4(y)} ${r4(w)} ${r4(h)}" style="position:absolute;${boxStyle(x, y, w, h)};overflow:${clip};transform:translateZ(${DU4(z)})" aria-hidden="true">`
        // the pets' seal: a stroke in the colour the slice edge should have covers its anti-aliased
        // edge pixels, so no light hairline shows between slices when the decoration turns
        + `<path d="${s.d}"${rule} fill="${color}" stroke="${pc.rim && s.ero < pc.rim ? rimC : color}" stroke-width=".45" stroke-linejoin="round"/>${inner}</svg>`;
    }
  }
  return out;
}

// ---------- colour: keep a decoration readable on every pet ----------
/** Perceptual-ish distance of two colours ("redmean" RGB). */
function colorDist(a, b) {
  const [r1, g1, b1] = rgbOf(a), [r2_, g2, b2] = rgbOf(b), rm = (r1 + r2_) / 2;
  return Math.sqrt((2 + rm / 256) * (r1 - r2_) ** 2 + 4 * (g1 - g2) ** 2 + (2 + (255 - rm) / 256) * (b1 - b2) ** 2);
}
/** The piece's colour, or its alternate when the own colour nearly matches the pet underneath. */
function pickColor(color, alt, pet, lim = 150) {
  if (!alt) return color;
  const under = pet.color;
  return colorDist(color, under) < lim && colorDist(alt, under) > colorDist(color, under) ? alt : color;
}

// ---------- fitting: where things go on one pet ----------
const FITS = new Map();
function fitPet(pet) {
  const id = pet.def.id;
  if (FITS.has(id)) return FITS.get(id);
  const def = validateAvatar(pet.def).value;
  const { vol } = preparedVolume(def, pet.depth);
  const body = analyzeBody(def.body.path);
  const polys = body.polys;
  const main = vol.parts[vol.eyePart];
  const b = vol.bounds;
  const inside = (x, y) => isInside(polys, x, y);
  // How far the pet's front comes forward at (x, y), as its slices are drawn: smoothSlices rebuilds a
  // revolved part (pudding, cup, carton…) row by row as circle sections, flat right up to a flat top
  // edge, so it reaches further forward there than the library's height field says.
  const v = (pet.depth ?? DEFAULT_DEPTH) / DEFAULT_DEPTH;
  const surf = vol.parts.map((p) => {
    if (p.kind === 'inflate' || p.kind === 'revolve-x') return (x, y) => p.height(x, y);
    return (x, y) => {
      if (!isInside(p.polys, x, y)) return 0;
      const xs = [];
      for (const poly of p.polys)
        for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
          const a = poly[j], c = poly[i];
          if ((a[1] <= y && c[1] > y) || (c[1] <= y && a[1] > y)) xs.push(a[0] + ((y - a[1]) * (c[0] - a[0])) / (c[1] - a[1]));
        }
      const r = xs.length >= 2 ? (Math.max(...xs) - Math.min(...xs)) / 2 : 0;
      return Math.max(p.height(x, y), v * Math.sqrt(Math.max(0, r * r - (x - p.axis) ** 2)));
    };
  });
  const height = (x, y) => Math.max(0, ...surf.map((h) => h(x, y)));
  /** First inside y going down at column x (null if the column misses the pet). */
  const topAt = (x, from = b.minY - 1) => { for (let y = from; y < b.maxY + 1; y += 0.1) if (inside(x, y)) return y; return null; };
  /** Inside span of row y around x. */
  const spanAt = (x, y, mp = main.polys) => {
    if (!isInside(mp, x, y)) return null;
    let l = x, r = x;
    while (l > b.minX - 1 && isInside(mp, l - 0.1, y)) l -= 0.1;
    while (r < b.maxX + 1 && isInside(mp, r + 0.1, y)) r += 0.1;
    return [l, r];
  };
  const eyeW = EYE_W * vol.eyeScale, eyeH = EYE_H * vol.eyeScale;
  const o = FIT_OVERRIDES[id] || {};
  const f = {
    id, def, vol, polys, main, inside, height, topAt, spanAt, b,
    cx: (b.minX + b.maxX) / 2, w: b.maxX - b.minX, h: b.maxY - b.minY, top: b.minY, bottom: b.maxY,
    ex: def.eyes.x, ey: def.eyes.y, spacing: def.eyes.spacing, eyeW, eyeH,
    eyeZ: Math.max(...vol.eyeZ) + EYE_LIFT, half: main.depth / 2, o,
  };
  f.head = { x: o.head?.x ?? f.ex, rot: o.head?.rot ?? 0, w: o.head?.w ?? 1, k: o.head?.k ?? 1, dy: o.head?.dy ?? 0 };
  // Where head things rest: the main part's own top. A topper (the strawberry, the lemon leaf, the
  // honey dipper, the pineapple leaves, the cherry; the bubble tea straw via seatTop) never props a
  // hat up: hats sit beside it on the head, or around it, the way the crown sits on the honey jar.
  const seatTop = o.seatTop ?? -Infinity;
  // seatAll: the whole outline carries the hat (the chili's calyx and stem are a cap, not a topper:
  // a slim cone over the stem would show it through the cone, so the stem only goes `deep` units in)
  f.seatIn = (x, y) => y >= seatTop && (o.seatAll ? inside(x, y) : isInside(main.polys, x, y));
  f.topMain = (x) => { for (let y = Math.max(b.minY - 1, seatTop); y < b.maxY + 1; y += 0.1) if (f.seatIn(x, y)) return y; return null; };
  FITS.set(id, f);
  return f;
}

/**
 * A hat's rim (width W, tilted rot°, centred on x0) comes straight down onto the main part's top
 * until a rim point touches it. A hat worn at an angle (tilt°) keeps coming down until its high
 * side rests on the head too, at most as far as the tilt lifted it: no corner hangs in the air.
 */
function hatSeat(f, x0, rot, W, tilt = 0, deep = 5, zp = null, slant = false) {
  const a = rot * D2R, ux = Math.sin(a), uy = -Math.cos(a), px = Math.cos(a), py = Math.sin(a);
  // The rim's two ends rest on the head (as in round 1); a peak or knob between them may go up inside
  // the hat, which wraps it, but only `deep` units: the onigiri's tip stays inside the band, it never
  // pushes up into a slim cone.
  // zp: a flat hat standing at depth zp rests on the pet's cross-section there (what of the pet reaches that far forward)
  const on = zp == null ? (y, k) => f.seatIn(x0 + (px * k * W) / 2, y + (py * k * W) / 2)
    : (y, k) => { const x = x0 + (px * k * W) / 2, yy = y + (py * k * W) / 2; return f.seatIn(x, yy) && f.height(x, yy) >= zp; };
  const inner = [-0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75];
  const cap = (W / 2) * Math.abs(Math.sin(tilt * D2R));
  let y1 = null;
  for (let y = f.top - 40; y < f.bottom; y += 0.1) {
    // slant (a hat worn on the shoulder): only its low end rests on the head; a peak by its high end
    // (the mantou's swirl, the chili's stem) goes up inside it like any knob, `deep` units at most
    const touch = slant ? on(y, rot < 0 ? -1 : 1) || [rot < 0 ? 1 : -1, ...inner].some((k) => on(y - deep, k))
      : on(y, -1) || on(y, 1) || inner.some((k) => on(y - deep, k));
    if (y1 === null) { if (touch) y1 = y; else continue; }
    if ((on(y, -1) && on(y, 1)) || y - y1 >= cap) return { x: x0, y, ux, uy };
  }
  return { x: x0, y: y1 ?? f.top, ux, uy };
}
/** Local slope of the main part's top at x, in degrees (positive = going down to the right). */
function topSlope(f, x, dx = 2) {
  const l = f.topMain(x - dx), r = f.topMain(x + dx);
  if (l == null || r == null) return 0;
  return Math.atan2(r - l, 2 * dx) / D2R;
}
/** The highest front surface under a rectangle of the pet (pet units). */
function surfaceMax(f, x1, y1, x2, y2) {
  let m = 0;
  for (let i = 0; i <= 8; i++) for (let j = 0; j <= 8; j++) m = Math.max(m, f.height(x1 + ((x2 - x1) * i) / 8, y1 + ((y2 - y1) * j) / 8));
  return m;
}

/** How far the pet's front surface comes forward under one placed piece (pet units). */
function pieceNeed(f, pc, pl) {
  const body = analyzeBody(pc.d), b = body.bounds;
  const a = pl.rot * D2R, c = Math.cos(a), sn = Math.sin(a);
  let m = 0;
  for (let i = 0; i <= 10; i++) for (let j = 0; j <= 10; j++) {
    const x = b.minX + ((b.maxX - b.minX) * i) / 10, y = b.minY + ((b.maxY - b.minY) * j) / 10;
    if (!isInside(body.polys, x, y)) continue;
    const dx = (x - pl.A[0]) * pl.s * (pl.mirror ? -1 : 1), dy = (y - pl.A[1]) * pl.s;
    m = Math.max(m, f.height(pl.P[0] + c * dx - sn * dy, pl.P[1] + sn * dx + c * dy));
  }
  return m ? m + 0.7 : 0;
}

/** A flat head piece seated at depth zp stays behind the head below its foot (a little tuck), but
 *  whatever of the pet comes forward of zp ABOVE its foot (a peaked top like the onigiri's, the warm
 *  milk's cap, a straw) would poke through it at rest: the plane comes forward to clear that. */
function aboveNeed(f, dec, pl, full = false) {
  let m = 0;
  const a = pl.rot * D2R, c = Math.cos(a), sn = Math.sin(a), yCut = full ? Infinity : dec.A[1] - 1.2;
  for (const pc of dec.pieces) {
    if (!pc.d) continue;
    const body = analyzeBody(pc.d), b = body.bounds;
    for (let i = 0; i <= 12; i++) for (let j = 0; j <= 12; j++) {
      const x = b.minX + ((b.maxX - b.minX) * i) / 12, y = b.minY + ((b.maxY - b.minY) * j) / 12;
      if (y > yCut || !isInside(body.polys, x, y)) continue;
      const dx = (x - pl.A[0]) * pl.s * (pl.mirror ? -1 : 1), dy = (y - pl.A[1]) * pl.s;
      m = Math.max(m, f.height(pl.P[0] + c * dx - sn * dy, pl.P[1] + sn * dx + c * dy));
    }
  }
  return m;
}

/** How far each piece is extruded (piece units) so that its full outline wraps the head where it
 *  overlaps it: no head poking through a brim or a horn, whichever way the pet turns. More slices,
 *  not a stretch: a stretched thin band fans out when turned. */
function wrapExts(f, dec, pl) {
  return dec.pieces.map((pc) => (pc.lens ? 0 : Math.ceil((4 * pieceNeed(f, pc, pl)) / pl.s) / 4));
}
/** As round 1 approved it: each piece inflated deep enough to wrap the head where it overlaps it.
 *  On a flat-topped pet (wrap: false: the pudding) a hat sits on the top instead, its foot tucked
 *  behind the front rim, so the line between them is the pet's own straight top edge at any turn. */
function wrapVols(f, dec, pl) {
  if (f.o.wrap === false) return dec.pieces.map((pc) => pc.vol ?? 1);
  // pad: extra depth for a piece whose thin edge sits on a dome (the party cone's foot), seen from above
  const need = (pc) => { const n = pieceNeed(f, pc, pl); return n ? n + (pc.pad ?? 0) : 0; };
  return dec.pieces.map((pc) => (pc.lens || pc.nowrap ? pc.vol ?? 1 : (pc.vol ?? 1) * Math.ceil(4 * Math.max(1, need(pc) / (decorGeom(pc.d, pc.vol ?? 1, pc.cut ?? 0).half * pl.s))) / 4));
}

/**
 * Placements of one decoration on one pet: a list of instances, each
 * { P: [x, y], z, rot, rx, ry, s, sz, mirror, kind }. The authoring point A lands on P.
 */
function placeDecor(dec, f, ctx = {}) {
  const geomHalf = (k) => decorGeom(dec.pieces[k].d, dec.pieces[k].vol ?? 1, dec.pieces[k].cut ?? 0).half;
  switch (dec.place) {
    case 'hat': {
      // k: a smaller hat than any pet gets otherwise, beside a topper that has to stay in view (the pudding's cherry)
      const own = f.o.items?.[dec.id] ?? {};
      const W = clamp(dec.fitW * f.w * f.head.w, dec.lo, dec.hi) * (own.k ?? f.head.k);
      const s = W / dec.W0;
      const x0 = own.x ?? f.head.x;
      // the head's own lean under the hat ('auto': the main part's top, across the hat's width)
      const lean = (own.rot ?? f.head.rot) === 'auto'
        ? clamp(Math.atan2((f.topMain(x0 + W * 0.4) ?? 0) - (f.topMain(x0 - W * 0.4) ?? 0), W * 0.8) / D2R, -16, 16)
        : own.rot ?? f.head.rot;
      const tilt = (dec.tilt ?? 0) * (lean < -4 ? -1 : 1);
      const rot = lean + tilt;
      const zp = flatPlane(dec, f, x0, W);
      // deep: how far a peak may go up inside the hat (a slanted hat swallows the onigiri's tip, the mantou's swirl)
      const seat = hatSeat(f, x0, rot, W * 0.92, tilt, (own.deep ?? f.o.head?.deep ?? dec.deep ?? 5) * s, zp, !!f.o.head?.slant);
      // sunk a little into a round head (the wrap covers it); on a flat top it stands right on the edge
      const foot = Math.max(...dec.pieces.filter((pc) => pc.d).map((pc) => analyzeBody(pc.d).bounds.maxY)) - dec.A[1];
      const sink = f.o.wrap === false ? 0.35 - foot * s : zp != null ? 0.6 * s : 1.8 * s;
      const P = [seat.x - seat.ux * sink, seat.y - seat.uy * sink + f.head.dy];
      // a hat with a tip that flops to one side (santa) flops away from the topper it sits beside
      const pl = { P, z: 0, rot, s, sz: 1, A: dec.A, mirror: !!dec.flip && x0 < f.ex - 4, zp };
      if (zp != null) pl.zp = Math.max(zp, aboveNeed(f, dec, pl, !!f.o.cover));
      if (!dec.flat) pl.vols = wrapVols(f, dec, pl);
      return [pl];
    }
    case 'halo': {
      const W = clamp(dec.fitW * f.w, dec.lo, dec.hi), s = W / dec.W0;
      let top = Infinity;
      for (let x = f.ex - W / 2; x <= f.ex + W / 2; x += 1) { const t = f.topAt(x); if (t != null) top = Math.min(top, t); }
      return [{ P: [f.ex, top - 4.2 - 3 * s], z: 0, rot: (f.o.cover ? 0 : typeof f.head.rot === 'number' ? f.head.rot : 0) * 0.4, rx: 64, s, sz: 1, kind: 'halo' }];
    }
    case 'float': {
      // 11-10: floats clear of the head (never touches it), bobbing like the halo
      const W = clamp(dec.fitW * f.w, dec.lo, dec.hi), s = W / dec.W0;
      const x = f.ex + (dec.dx ?? 0) * f.w;
      const top = floatTop(f, x, W / 2 + 1);
      const gap = dec.gap * Math.max(1, s);
      // rain: drops fall from the cloud's foot and are gone 1.9 above the head (the cloud bobs 0.8)
      return [{ P: [x, top - gap], z: 0, rot: 0, s, sz: 1, kind: 'float', fall: (gap - 1.9) / s }];
    }
    case 'orbit': {
      // little stars round a tilted ring above the head: the front of the ring is lower, as the halo's
      const W = clamp(dec.fitW * f.w, dec.lo, dec.hi), s = W / dec.W0;
      const R = W / 2, r = 3.4 * s, tilt = 0.3;
      const top = floatTop(f, f.ex, R + r + 1);
      const yc = top - 3.6 - r - tilt * R;
      return Array.from({ length: dec.n }, (_, k) => ({ P: [f.ex, yc], z: 0, rot: 0, s: s * 0.95, sz: 1, kind: 'orbit', k, n: dec.n, R, tilt }));
    }
    case 'sticker': { const pl = stickerFit(dec, f, ctx.avoid); return pl ? [pl] : []; }
    case 'pair': {
      // On the main part's top, either side of the topper; built deep enough to wrap the head where
      // they stand on it, so the horns are always in front of it (never hidden behind its outline).
      const W = clamp(dec.fitW * f.w, dec.lo, dec.hi), s = W / dec.W0;
      const cx = f.o.pair?.cx ?? f.ex;
      const half = f.o.pair?.half ?? (dec.sep * W) / 2;
      const zp = flatPlane(dec, f, cx, 2 * half + W);
      return [-1, 1].map((side) => {
        const x = cx + side * half;
        const y = (zp != null ? topAtDepth(f, x, zp) : f.topMain(x)) ?? f.top;
        // half the head's slope: horns on a round head still point up, not out sideways
        const slope = 0.5 * clamp(topSlope(f, x), -24, 24);
        const pl = { P: [x, y + (zp != null ? 1.2 : 2.2) * s], z: 0, rot: slope + side * dec.splay, s, sz: 1, mirror: side > 0, A: dec.A, zp };
        if (zp != null) pl.zp = Math.max(zp, aboveNeed(f, dec, pl));
        if (!dec.flat) pl.vols = wrapVols(f, dec, pl);
        return pl;
      });
    }
    case 'eyes': {
      const s = f.spacing / dec.W0;
      const z = f.eyeZ + 0.35 + decorGeom(dec.pieces[0].d, dec.pieces[0].vol).half * s;
      return [{ P: [f.ex, f.ey + 0.5], z, rot: 0, s, sz: 1 }];
    }
    case 'mouth': {
      const top = f.ey + f.eyeH / 2 + (dec.id === 'beard' ? 1.2 : 1.4);
      let W = Math.min(dec.fitW * f.spacing, (f.spanAt(f.ex, top + 4) || [f.ex - 20, f.ex + 20]).reduce((a, c) => c - a) * 0.92);
      let s = W / dec.W0, sy = 1;
      const room = f.bottom - 1.2 - top;
      if (dec.id === 'beard') {
        // a long beard on a short face gets shorter (down to 62%) before it gets narrower
        sy = clamp(room / (dec.H0 * s), 0.62, 1);
        if (dec.H0 * s * sy > room) s = room / (dec.H0 * sy);
      } else if (dec.H0) s = Math.min(s, (room / dec.H0) * 3);
      W = dec.W0 * s;
      const z = surfaceMax(f, f.ex - W / 2, top, f.ex + W / 2, top + dec.H0 * s * sy) + geomHalf(0) * s + 0.25;
      return [{ P: [f.ex, top], z, rot: 0, s, sz: 1, sy }];
    }
    case 'neck': {
      const W = clamp(dec.fitW * f.w, dec.lo, dec.hi);
      let s = W / dec.W0;
      let y = f.ey + f.eyeH / 2 + (dec.id === 'medal' ? 4.2 : 9.5);
      const room = f.bottom + (dec.id === 'medal' ? 1.2 : -2.2) - y;
      if (dec.id === 'medal') { if (room < dec.H0 * s) s = Math.max(0.78, room / dec.H0); }
      else y = Math.min(y, f.bottom - 2.5 - (dec.H0 / 2) * s);
      const Wd = dec.W0 * s, Hd = (dec.H0 ?? 12) * s;
      const y1 = dec.id === 'medal' ? y : y - Hd / 2;
      const z = surfaceMax(f, f.ex - Wd / 2, y1, f.ex + Wd / 2, y1 + Hd) + geomHalf(0) * s + 0.3;
      return [{ P: [f.ex, y], z, rot: 0, s, sz: 1 }];
    }
    // ---- 11-10 round 5: flat pieces ----
    case 'specs': {
      // on the eyes, sized by their spacing; in front of the eyes
      const s = (f.spacing / 17) * (dec.k ?? 1);
      return [{ P: [f.ex, f.ey + 0.5], rot: 0, s, A: dec.A, zmin: f.eyeZ + 0.9 }];
    }
    case 'muzzle': {
      // under the eyes, sized with the face, narrower than the face there and short enough for the body
      const y = f.ey + f.eyeH / 2 + (dec.dy ?? 1.2);
      const span = f.spanAt(f.ex, y + 2) || f.spanAt(f.ex, y) || [f.ex - 20, f.ex + 20];
      let s = Math.min((f.spacing / 17) * (dec.k ?? 1), ((span[1] - span[0]) * (dec.fill ?? 0.92)) / dec.W0);
      if (dec.H0) s = Math.min(s, (f.bottom - 1.5 - y) / dec.H0);
      return [{ P: [f.ex + (dec.dx ?? 0) * s, y], rot: dec.tilt ?? 0, s, A: dec.A, zAdd: 0.3 }];
    }
    case 'collar': {
      // a necklace hangs in a wide curve across the body (as wide as the body there, ends inside the
      // outline), drawn for this pet in its own units; a tie or a bandana hangs from the middle of it
      // sash (the baguette, 11-11 round 11): worn across the body, upper left to lower right; everything
      // is laid out level in the sash's own frame (F.f: what is "down" there) and turned with it
      const F = sashFrame(f, dec);
      if (F) f = F.f;
      const g = F ? F.g : neckArc(f);
      const turn = (pls) => (F ? pls.map((pl) => ({ ...pl, P: F.toWorld(pl.P), rot: (pl.rot ?? 0) + F.rot })) : pls);
      if (dec.gen) return F ? [{ P: F.M, rot: F.rot, s: 1, A: F.M, pieces: NECK_GEN[dec.gen](g, f) }]
        : [{ P: [0, 0], rot: 0, s: 1, A: [0, 0], pieces: NECK_GEN[dec.gen](g, f) }];
      // on a short body a tie knots higher (tieUp) and gets shorter before it gets smaller
      const short = f.bottom - 1.6 - (g.yN + g.dip) < (dec.H0 - 4.6) * g.k * 0.8;
      let y = dec.at0 ? g.yN + g.dip * 0.35 : g.yN + g.dip - 1.2 * g.k - (short && dec.tieUp ? dec.tieUp * g.k : 0);
      // a bandana on a short body sits up to `lift` higher (tucked under a mouth item) before it shrinks
      if (dec.lift) y = Math.max(y - clamp(dec.H0 * g.k * 0.9 - (f.bottom - (dec.foot ?? 1.6) - y), 0, dec.lift * g.k), Math.min(y, f.ey + f.eyeH / 2 + (dec.eyeGap ?? -99)));
      // wSp (the bandana, 11-11 round 11): as wide as on the toast for every pet (wSp eye spacings),
      // never wider than fillMax of the body across the neck
      let s = dec.wSp ? Math.min((dec.wSp * f.spacing) / dec.W0, ((g.x2 - g.x1) * (dec.fillMax ?? 1)) / dec.W0)
        : dec.fill ? Math.min(((g.x2 - g.x1) * dec.fill) / dec.W0, g.k * 1.35) : g.k * (dec.k ?? 1), sy = 1;
      const room = f.bottom - (dec.foot ?? 1.6) - y, H = dec.H0 - (dec.at0 ? 0 : 4.6);
      if (H * s > room) {
        if (dec.sy) sy = clamp(room / (H * s), dec.syMin ?? 0.62, 1);
        if (H * s * sy > room) s = room / (H * sy);
      }
      return turn([{ P: [f.ex, y], rot: 0, s, sy, A: dec.at0 ? dec.A : [50, 44.6] }]);
    }
    case 'behind': {
      // one flat layer behind the deepest part of the pet: only what reaches past the outline shows
      const zFix = -(Math.max(...f.vol.parts.map((p) => p.depth / 2)) + 0.6);
      const A = dec.A;
      switch (dec.at) {
        case 'sides': {
          const y = f.ey - 1;
          const sp = f.spanAt(f.cx, y) || f.spanAt(f.ex, y) || [f.b.minX, f.b.maxX];
          const s = clamp((f.h * dec.fitH) / dec.W0, 0.75, 1.15);
          return [-1, 1].map((side) => ({ P: [side < 0 ? sp[0] + 4 : sp[1] - 4, y], rot: side * -8, s, mirror: side < 0, A, zFix }));
        }
        case 'side': {
          const y = f.top + f.h * (dec.fy ?? 0.5);
          const sp = f.spanAt(f.cx, y) || [f.b.minX, f.b.maxX];
          const s = clamp((f.h * dec.fitH) / dec.W0, 0.8, 1.2);
          return [{ P: [sp[1], y], rot: 6, s, A, zFix }];
        }
        case 'cape': {
          const y = f.top + f.h * 0.22;
          const s = clamp((f.w * 1.18) / dec.W0, 0.8, 1.5);
          const sy = clamp((f.bottom - 3 - y) / (dec.H0 * s), 0.5, 1);
          return [{ P: [f.cx, y], rot: 0, s, sy, A, zFix }];
        }
        case 'shoulders': {
          // a tank behind each shoulder, half of it out past the outline
          const y = f.top + f.h * 0.42;
          const sp = f.spanAt(f.cx, y) || [f.b.minX, f.b.maxX];
          const s = clamp(f.h / 62, 0.8, 1.2);
          return [-1, 1].map((side) => ({ P: [side < 0 ? sp[0] + 1.5 * s : sp[1] - 1.5 * s, y], rot: side * 4, s, mirror: side < 0, A, zFix }));
        }
        case 'lean': {
          // 11-11 a board stood on its end behind the right side, leaning out: half its width shows
          // down the side, the top past the shoulder
          const s = clamp((f.h * (dec.fitH ?? 1)) / dec.H0, 0.85, 1.5);
          const sp = f.spanAt(f.cx, f.top + f.h * 0.62) || [f.b.minX, f.b.maxX];
          return [{ P: [sp[1] + 1.2 * s, f.bottom - 1.2], rot: dec.rot ?? 12, s, A, zFix }];
        }
        case 'roll': {
          // 11-11 a rolled yoga mat across the back: an end out past each side, level
          const y = f.top + f.h * (dec.fy ?? 0.42);
          const sp = f.spanAt(f.cx, y) || [f.b.minX, f.b.maxX];
          const s = clamp(f.h / 62, 0.8, 1.2);
          return [-1, 1].map((side) => ({ P: [side < 0 ? sp[0] + 3 * s : sp[1] - 3 * s, y], rot: 0, s, mirror: side < 0, A, zFix }));
        }
        case 'balloon': {
          // the balloon floats up and right of the head; its string goes down behind the pet
          const s = clamp(f.h / 70, 0.8, 1.1);
          const xc = f.cx + f.w * 0.3, yc = Math.min(f.top, floatTop(f, xc, 8)) - 9.6 * s - 1;
          return [{ P: [xc - 12 * s, yc + 31 * s], rot: 0, s, A, zFix }];
        }
        case 'slung': {
          // across the back: the head over the right shoulder, just clear of the outline, the grip behind
          const s = clamp(f.h / 66, 0.8, 1.15) * (dec.ks ?? 1), rot = dec.rot ?? 30, a = rot * D2R;
          const xr = f.cx + f.w * 0.27, yr = (f.topAt(xr) ?? f.top) - (8.5 + (dec.up ?? 0)) * s;
          return [{ P: [xr - 17.4 * s * Math.sin(a), yr + 17.4 * s * Math.cos(a)], rot, s, A, zFix }];
        }
        case 'spine': {
          // a row of spikes along the top of the main part, each standing out along the outline
          const s0 = clamp(f.w / 70, 0.8, 1.15), ks = [0.72, 0.9, 1, 0.9, 0.72], out = [];
          ks.forEach((k, i) => {
            const x = f.cx + (i - 2) * f.w * 0.16;
            const y = f.topMain(x) ?? f.topAt(x);
            if (y == null) return;
            const s = s0 * k;
            out.push({ P: [x, y + 2.6 * s], rot: clamp(topSlope(f, x), -50, 50), s, A, zFix });
          });
          return out;
        }
      }
      return [];
    }
    case 'wings': {
      const y = f.ey - 1;
      const sp = f.spanAt(f.cx, y) || f.spanAt(f.ex, y) || [f.b.minX, f.b.maxX];
      const s = clamp((f.h * dec.fitH) / dec.W0, 0.75, 1.15);
      // Flat, parallel to the back, wholly behind the pet's deepest part: a wing turned on its root
      // (as in v1) cut through the pet's sides when it turned. They flap in their own plane instead.
      const back = Math.max(...f.vol.parts.map((p) => p.depth / 2));
      const z = -(back + 0.35 + geomHalf(0) * s);
      return [-1, 1].map((side) => ({ P: [side < 0 ? sp[0] + 4 : sp[1] - 4, y], z, rot: side * -8, s, sz: 1, mirror: side < 0, kind: 'wing', side }));
    }
    case 'tail': {
      const y = f.bottom - 7;
      const sp = f.spanAt(f.cx, y) || [f.b.minX, f.b.maxX];
      const s = clamp(f.w / 70, 0.8, 1.1);
      return [{ P: [sp[1] - 4, y], z: -f.half * 0.45, rot: 0, s, sz: 1, kind: 'tail' }];
    }
  }
  return [];
}

/** Where a necklace goes: across the body a little under the face, ends inside the outline, dipping
 *  in the middle (quadratic through (x1, yN), (ex, yN + dip), (x2, yN)); k = the face's size. */
// how far under the eyes the neckline hangs (11-10: 6.4 → 9.2 so a necklace clears whiskers, a toothbrush, a gum bubble)
const NECK_DROP = { v: 9.2 };
/** The baguette wears its neck things as a sash (FIT_OVERRIDES sash: { x, y, rot, skip }): a band
 *  across the loaf through (x, y), rot° (upper left → lower right), clear of the face. Returns the
 *  sash's own level frame: M (the middle of the band across the body), the necklace arc there, a stand-in
 *  for f whose "bottom" is how far the body goes on below the band (for what hangs from it), and the turn. */
function sashFrame(f, dec) {
  const sh = f.o.sash;
  if (!sh || (sh.skip || []).includes(dec.id)) return null;
  const a = sh.rot * D2R, dx = Math.cos(a), dy = Math.sin(a), nx = -dy, ny = dx;
  const reach = (x0, y0, ux, uy) => { let t = 0; while (t < 80 && f.inside(x0 + ux * (t + 0.25), y0 + uy * (t + 0.25))) t += 0.25; return t; };
  const t1 = reach(sh.x, sh.y, -dx, -dy), t2 = reach(sh.x, sh.y, dx, dy);
  const mid = (t2 - t1) / 2, M = [sh.x + dx * mid, sh.y + dy * mid];
  const W = (t1 + t2) * 0.86;
  const below = reach(M[0], M[1], nx, ny);
  const dip = Math.max(1.6, Math.min(W * 0.075, below * 0.3));
  const c = Math.cos(a), sn = Math.sin(a);
  const toWorld = ([x, y]) => [M[0] + c * (x - M[0]) - sn * (y - M[1]), M[1] + sn * (x - M[0]) + c * (y - M[1])];
  // sash: the turn (what hangs straight down is drawn turned back by it); fall: how far the body goes
  // on straight down (on screen) below a point of the sash's frame
  const fall = (x, y) => { const [wx, wy] = toWorld([x, y]); return reach(wx, wy, 0, 1); };
  const g = { yN: M[1] - dip * 0.5, x1: M[0] - W / 2, x2: M[0] + W / 2, ex: M[0], dip, k: f.spacing / 17, sash: sh.rot, fall };
  const ff = { ...f, ex: M[0], ey: -1e9, bottom: M[1] + below };
  return { M, g, f: ff, rot: sh.rot, toWorld, len: t1 + t2 };
}
function neckArc(f) {
  const yN = Math.min(f.ey + f.eyeH / 2 + (NECK_DROP.v), f.bottom - 9);
  const span = f.spanAt(f.ex, yN + 2) || f.spanAt(f.ex, yN) || [f.ex - 20, f.ex + 20];
  const W = (span[1] - span[0]) * 0.86;
  const dip = Math.max(1.6, Math.min(W * 0.075, (f.bottom - 2 - yN) * 0.3));
  return { yN, x1: f.ex - W / 2, x2: f.ex + W / 2, ex: f.ex, dip, k: f.spacing / 17 };
}
const arcY = (g, x) => { const t = (x - g.x1) / (g.x2 - g.x1); return g.yN + 4 * g.dip * t * (1 - t); };
const arcPts = (g, n) => Array.from({ length: n }, (_, i) => { const x = g.x1 + ((g.x2 - g.x1) * i) / (n - 1); return [x, arcY(g, x)]; });
const arcD = (g, inset = 0) => { const x1 = g.x1 + inset, x2 = g.x2 - inset; return `M${r2(x1)} ${r2(arcY(g, x1))}Q${r2(g.ex)} ${r2(2 * arcY(g, g.ex) - (arcY(g, x1) + arcY(g, x2)) / 2)} ${r2(x2)} ${r2(arcY(g, x2))}`; };
/** Necklaces drawn for one pet, in its own units. */
const NECK_GEN = {
  pearls(g) {
    // round 6 (pet rules: no row of small grains, no outline): fewer, bigger pearls that touch
    const n = Math.max(5, Math.round((g.x2 - g.x1) / (6.6 * g.k))) | 1, mid = (n - 1) / 2, pts = arcPts(g, n);
    const r0 = Math.min(3.4 * g.k, Math.hypot(pts[1][0] - pts[0][0], pts[1][1] - pts[0][1]) * 0.53);
    return [pearlPiece(pts, (i) => r0 * (i === mid ? 1.1 : 1))];
  },
  lei(g) {
    // round 6: fewer, bigger flowers in three colours, no centre dots, no outline
    const n = Math.max(4, Math.round((g.x2 - g.x1) / (7.6 * g.k))), out = ['', '', ''];
    arcPts(g, n).forEach(([x, y], i) => { out[i % 3] += flowerAt(x, y, 3.9 * g.k); });
    return [{ d: out[0], color: DC.coral, rule: 'nonzero' }, { d: out[1], color: DC.gold, alt: '#F2A65A', rule: 'nonzero' },
      { d: out[2], color: '#F7C9D9', alt: DC.pink, rule: 'nonzero' }];
  },
  bellcollar(g) {
    const k = g.k, y = arcY(g, g.ex) + 1.4 * k, cy = y + 4.6 * k;
    return [
      { d: arcD(g), color: DC.red, alt: DC.jade, line: 3.2 * k },
      { d: circ(r2(g.ex), r2(cy), r2(4.4 * k)) + rrect(r2(g.ex - 1.3 * k), r2(y - 1.2 * k), r2(g.ex + 1.3 * k), r2(y + 0.8 * k), r2(0.7 * k)), color: DC.gold, rim: 0.5, rimColor: '#B98327', pivot: [r2(g.ex), r2(y - 0.6 * k)], dangle: 0.6, dz: 0.2,
        paints: [{ d: rrect(r2(g.ex - 3.8 * k), r2(cy + 1.1 * k), r2(g.ex + 3.8 * k), r2(cy + 2 * k), r2(0.45 * k)) + circ(r2(g.ex), r2(cy + 2.9 * k), r2(0.85 * k)), color: '#B98327' },
          { d: circ(r2(g.ex - 1.6 * k), r2(cy - 1.7 * k), r2(0.95 * k)), color: DC.cream }] },
    ];
  },
  locket(g, f) {
    // a gold cord from near the sides down to a heart in the middle (round 6: a thicker cord, a bigger
    // heart with no outline and no shine, a round gold bail joining them)
    if (g.sash != null) {
      // on a sash (the baguette): the cord runs all the way across; the heart hangs straight down from its middle
      const k = g.k, ay = arcY(g, g.ex), up = (d) => tpath(d, g.ex, ay, -g.sash), pv = [r2(g.ex), r2(ay)];
      return [
        { d: arcD(g, (g.x2 - g.x1) * 0.04), color: DC.gold, alt: '#8E979F', line: r2(1.6 * k) },
        { d: up(heartAt(r2(g.ex), r2(ay + 5.4 * k), r2(11.4 * k))), color: DC.coral, alt: DC.red, pivot: pv, dangle: 0.5 },
        { d: up(circ(r2(g.ex), r2(ay + 0.4 * k), r2(1.5 * k))), color: DC.gold, alt: '#8E979F', pivot: pv, dangle: 0.5, dz: 0.1 },
      ];
    }
    const k = g.k, hy = Math.min(arcY(g, g.ex) + 3 * k, f.bottom - 2 - 6 * k), xa = g.x1 + (g.x2 - g.x1) * 0.14, xb = g.x2 - (g.x2 - g.x1) * 0.14;
    const pv = [r2(g.ex), r2(hy - 2.6 * k)];
    return [
      { d: `M${r2(xa)} ${r2(arcY(g, xa))}Q${r2(g.ex - (g.ex - xa) * 0.35)} ${r2(hy - 0.4 * k)} ${r2(g.ex)} ${r2(hy - 2.6 * k)}M${r2(xb)} ${r2(arcY(g, xb))}Q${r2(g.ex + (xb - g.ex) * 0.35)} ${r2(hy - 0.4 * k)} ${r2(g.ex)} ${r2(hy - 2.6 * k)}`, color: DC.gold, alt: '#8E979F', line: r2(1.6 * k) },
      { d: heartAt(r2(g.ex), r2(hy + 2.6 * k), r2(11.4 * k)), color: DC.coral, alt: DC.red, pivot: pv, dangle: 0.5 },
      { d: circ(r2(g.ex), r2(hy - 2.2 * k), r2(1.5 * k)), color: DC.gold, alt: '#8E979F', pivot: pv, dangle: 0.5, dz: 0.1 },
    ];
  },
  towel(g, f) {
    // round 6: a thicker band, ends with round bottom corners and one white stripe, no outline
    const k = g.k, out = [{ d: arcD(g), color: '#8CC4E8', alt: DC.lime, line: 3.6 * k }];
    if (g.sash != null) {
      // on a sash (the baguette): both ends hang straight down from the band, as far as the body goes
      for (const side of [-1, 1]) {
        const x = g.ex + side * (g.x2 - g.x1) * 0.3, top = arcY(g, x) - 0.6 * k;
        const L = Math.max(6 * k, Math.min(16 * k, g.fall(x, top) - 1.8)), w = 4 * k, rr = 1.8 * k, b = top + L;
        const up = (d) => tpath(d, x, top, -g.sash);
        out.push({ d: up(`M${r2(x - w)} ${r2(top)}L${r2(x + w)} ${r2(top)}L${r2(x + w)} ${r2(b - rr)}Q${r2(x + w)} ${r2(b)} ${r2(x + w - rr)} ${r2(b)}L${r2(x - w + rr)} ${r2(b)}Q${r2(x - w)} ${r2(b)} ${r2(x - w)} ${r2(b - rr)}Z`), color: '#8CC4E8', alt: DC.lime,
          pivot: [r2(x), r2(top + 0.6)], dangle: 0.45, dz: 0.2,
          paints: [{ d: up(`M${r2(x - w - 1)} ${r2(b - 4.4 * k)}L${r2(x + w + 1)} ${r2(b - 4.4 * k)}L${r2(x + w + 1)} ${r2(b - 2.6 * k)}L${r2(x - w - 1)} ${r2(b - 2.6 * k)}Z`), color: DC.white }] });
      }
      return out;
    }
    for (const side of [-1, 1]) {
      const x = g.ex + side * (g.x2 - g.x1) * 0.3, top = arcY(g, x) - 0.6 * k;
      const L = Math.max(6 * k, Math.min(16 * k, f.bottom - 1.8 - top)), w = 4 * k, rr = 1.8 * k, b = top + L;
      out.push({ d: `M${r2(x - w)} ${r2(top)}H${r2(x + w)}V${r2(b - rr)}Q${r2(x + w)} ${r2(b)} ${r2(x + w - rr)} ${r2(b)}H${r2(x - w + rr)}Q${r2(x - w)} ${r2(b)} ${r2(x - w)} ${r2(b - rr)}Z`, color: '#8CC4E8', alt: DC.lime,
        pivot: [r2(x), r2(top + 0.6)], dangle: 0.45, dz: 0.2,
        paints: [{ d: BAND(r2(b - 4.4 * k), r2(b - 2.6 * k)), color: DC.white }] });
    }
    return out;
  },
};
/** The highest point of the pet (toppers too) over x0 ± hw. */
function floatTop(f, x0, hw) {
  let top = Infinity;
  for (let x = x0 - hw; x <= x0 + hw; x += 0.5) { const t = f.topAt(x); if (t != null) top = Math.min(top, t); }
  return top === Infinity ? f.top : top;
}
/** Where a worn neck, mouth or scarf piece sits on this pet (a box), for a sticker to keep clear of. */
function decorRect(dec, f) {
  if (dec.place === 'neck' || dec.place === 'mouth') {
    const pl = placeDecor(dec, f)[0];
    const W = dec.W0 * pl.s, H = (dec.H0 ?? 12) * pl.s * (pl.sy ?? 1);
    const y1 = dec.place === 'mouth' || dec.id === 'medal' ? pl.P[1] : pl.P[1] - H / 2;
    return [pl.P[0] - W / 2, y1, W, H];
  }
  if (dec.place === 'band') {
    const st = bandStrip(dec, f);
    const r = [[f.b.minX, st.yc - st.h / 2 - 0.6, f.w, st.h + 1.2]];
    if (dec.tail) {
      const sp = f.spanAt(f.ex, st.yc) || [f.ex - 15, f.ex + 15];
      const s = clamp((sp[1] - sp[0]) / 44, 0.7, 1.05), x = f.ex - (sp[1] - sp[0]) * 0.2;
      r.push([x - 5 * s, st.yc, 10 * s, 18 * s]);
    }
    return r;
  }
  return null;
}
/** The pet's main part as the stickers see it, sampled once on a grid: where it is (and nothing of
 *  the pet's own sits in front of it, like the onigiri's nori) and how far forward its front comes. */
function surfaceProbe(f) {
  if (f._probe) return f._probe;
  const st = 0.5, b = f.main.bounds, x0 = b.minX - 2, y0 = b.minY - 2;
  const nx = Math.ceil((b.maxX - b.minX + 4) / st) + 1, ny = Math.ceil((b.maxY - b.minY + 4) / st) + 1;
  // filled as the search reaches them (most of a pet is never asked about)
  const H = new Float32Array(nx * ny).fill(NaN), M = new Uint8Array(nx * ny).fill(2);
  const others = f.vol.parts.filter((p) => p !== f.main);
  const hAt = (k) => {
    if (Number.isNaN(H[k])) H[k] = f.height(x0 + (k % nx) * st, y0 + Math.floor(k / nx) * st);
    return H[k];
  };
  const h = (x, y) => {
    const u = clamp((x - x0) / st, 0, nx - 1.001), v = clamp((y - y0) / st, 0, ny - 1.001);
    const i = Math.floor(u), j = Math.floor(v), a = u - i, c = v - j, k = j * nx + i;
    return (hAt(k) * (1 - a) + hAt(k + 1) * a) * (1 - c) + (hAt(k + nx) * (1 - a) + hAt(k + nx + 1) * a) * c;
  };
  const inMain = (x, y) => {
    const i = Math.round((x - x0) / st), j = Math.round((y - y0) / st);
    if (i < 0 || j < 0 || i >= nx || j >= ny) return false;
    const k = j * nx + i;
    if (M[k] === 2) {
      const px = x0 + i * st, py = y0 + j * st;
      M[k] = isInside(f.main.polys, px, py) && !others.some((p) => isInside(p.polys, px, py)) ? 1 : 0;
    }
    return M[k] === 1;
  };
  return (f._probe = { h, inMain });
}
/** Where a sticker goes: on the main part's front, below the eyes, on the viewer's right of the face's
 *  centre line (clear of a bow tie or medal in the middle), its whole disc well inside the outline.
 *  It is one flat decal (stickerMarkup), so the front under it must be about flat: an inflated
 *  part's face, or near the middle of a cup's round side. Where there is too little room, smaller. */
function stickerFit(dec, f, avoid = []) {
  const boxes = avoid.flatMap((r) => (r && Array.isArray(r[0]) ? r : r ? [r] : []));
  const key = dec.id + '|' + boxes.map((r) => r.map((v) => v.toFixed(1)).join(',')).join(';');
  f._stick ??= new Map();
  if (f._stick.has(key)) { const pl = f._stick.get(key); return pl && { ...pl }; }
  const pl = stickerSearch(dec, f, boxes);
  f._stick.set(key, pl);
  return pl && { ...pl };
}
/** How far a sticker may stand off the body at its edge, where the front curves away under it (a
 *  cup's round side): turned 22°, that edge slides ~0.4 of it across the body, under a pixel. */
const STICKER_ROOM = 2.5;
const TURNS = [[Math.tan(0.42), 0], [-Math.tan(0.42), 0], [0, Math.tan(0.21)], [0, -Math.tan(0.21)]];
const RING = Array.from({ length: 16 }, (_, i) => [Math.cos((i * Math.PI) / 8), Math.sin((i * Math.PI) / 8)]);
/** How far a sticker stands off the front: iOS WebKit merges planes closer than about a pixel (the
 *  eyes' own lift is 1.5 for that), and turned, a sticker drifts only lift × sin(turn) on it. */
const STICKER_LIFT = 0.6;
function stickerSearch(dec, f, boxes) {
  const { h, inMain } = surfaceProbe(f);
  const under = f.ey + f.eyeH / 2;
  // every spot, best first: the viewer's right is preferred, the left only when the right has no
  // room (the baguette)
  const x0 = f.ex + clamp(0.23 * f.w, 12, 18), y0 = under + 9;
  const spots = [];
  for (let y = f.ey - 1; y <= f.bottom; y += 0.5)
    for (let x = f.b.minX; x <= f.b.maxX; x += 0.5)
      if (inMain(x, y)) spots.push([Math.min((x - x0) ** 2, (x - (2 * f.ex - x0)) ** 2 + 60) + 1.6 * (y - y0) ** 2, x, y]);
  spots.sort((p, q) => p[0] - q[0]);
  // how far the sticker would stand off the body at its edge there (Infinity: it may not go there)
  const room = (x, y, R, loose = false) => {
    // clear of the eyes (beside them only, on a short face like the honey jar's) and of the mouth
    // (with room for the eyes' own travel when they look sideways or down: the gaze moves them ~3)
    if (y - R < under + 2.5 && Math.abs(x - f.ex) - R < f.spacing / 2 + f.eyeW / 2 + (loose ? 2 : 4)) return [Infinity];
    if (!(y - R > under + 7 || Math.abs(x - f.ex) - R > 2.5)) return [Infinity];
    // never in the middle under the eyes, where a round sticker (the rainbow most) reads as a mouth
    if (Math.abs(x - f.ex) < f.spacing / 2 + 0.4 * R + 1) return [Infinity];
    // clear of a worn bow tie, medal, beard or scarf
    for (const [bx, by, bw, bh] of boxes) if (x + R + 1.2 > bx && x - R - 1.2 < bx + bw && y + R + 1.2 > by && y - R - 1.2 < by + bh) return [Infinity];
    for (const [c, sn] of RING) if (!inMain(x + c * (R + 3.2), y + sn * (R + 1.6))) return [Infinity];
    // the sticker is one flat layer just in front of the highest point under it
    let lo = Infinity, hi = -Infinity;
    for (const r of [R + 1, R * 0.7, R * 0.35]) for (const [c, sn] of RING) { const v = h(x + c * r, y + sn * r); lo = Math.min(lo, v); hi = Math.max(hi, v); }
    const v = h(x, y);
    hi = Math.max(hi, v); lo = Math.min(lo, v);
    if (!loose && hi - lo > STICKER_ROOM) return [hi - lo, hi];
    // and turned as far as the pet looks round (20° each way, 8° up and down, with some to spare),
    // every point of its edge still lies over the body, never out past its outline (a thin pet's edge)
    const zs = hi + STICKER_LIFT, r = R + 0.8;
    for (const [c, sn] of RING) {
      const px = x + c * r, py = y + sn * r;
      for (const [tx, ty] of TURNS) {
        let hit = false;
        for (let z = zs; z > -zs && !hit; z -= 0.5) hit = h(px + (zs - z) * tx, py + (zs - z) * ty) >= Math.abs(z);
        if (!hit) return [Infinity];
      }
    }
    return [hi - lo, hi];
  };
  const place = (P, R, s, top) => ({ P, z: top + STICKER_LIFT, rot: (dec.tilt ?? 0) + (f.o.bandRot ?? 0) * 0.5, s, sz: 1, kind: 'sticker', R });
  const size = (k) => { const W = clamp(dec.fitW * f.w, dec.lo, dec.hi) * k; return [W / 2, W / dec.W0]; };
  for (let k = 1; k >= 0.6 - 1e-9; k -= 0.05) {
    const [R, s] = size(k);
    for (const [, x, y] of spots) {
      const [d, top] = room(x, y, R);
      if (d <= STICKER_ROOM) return place([x, y], R, s, top);
    }
  }
  // a round little front (the matcha bowl, the honey jar), or one with a bow tie, beard or scarf on
  // it too: smaller, a little nearer the eyes, where it stands off the body the least
  for (const k of [0.6, 0.5, 0.4]) {
    const [R, s] = size(k);
    let best = null;
    spots.forEach(([, x, y], n) => {
      const [d, top] = room(x, y, R, true);
      const score = d + n / spots.length;
      if (d < Infinity && (!best || score < best.score)) best = { score, P: [x, y], top };
    });
    if (best) return { ...place(best.P, R, s, best.top), loose: true };
  }
  // no room at all (the bubble tea's short front with a beard on it): not drawn
  return null;
}
/** A sticker's art in its own units (layers, front-view colours picked for this pet). */
function stickerArt(dec, pet) {
  return dec.art.map((L) => {
    const c = pet ? pickColor(L.color, L.alt, pet) : L.color;
    if (L.line) return `<path d="${L.d}" fill="none" stroke="${c}" stroke-width="${L.line}" stroke-linecap="round" stroke-linejoin="round"/>`;
    return `<path d="${L.d}" fill="${c}"${L.grow ? ` stroke="${c}" stroke-width="${r2(2 * L.grow)}" stroke-linejoin="round"` : ''}/>`;
  }).join('');
}
/** A piece-built decoration drawn flat, in its own units: each piece filled (warm-grey rim where the
 *  piece has one), its paints clipped to it, back pieces (lower dz) first. Colours picked for this pet. */
function flatArt(dec, pet, mirror = false) {
  return [...dec.pieces].sort((a, b) => (a.dz ?? 0) - (b.dz ?? 0)).map((pc) => {
    const g = pc.pivot && pc.dangle ? `<g data-sp="1" data-k="${pc.dangle}" data-px="${pc.pivot[0]}" data-py="${pc.pivot[1]}" data-m="${mirror ? 1 : 0}">` : '';
    const a = pc.anim;
    const an = a ? `<g data-an="${[a.r ?? 0, a.s ?? 0, a.s0 ?? 1, a.y ?? 0, a.o ?? 0, a.per ?? 1, a.ph ?? 0, a.px ?? 50, a.py ?? 50, a.w ?? 0].join(',')}">` : '';
    return g + an + flatPiece(pc, pet) + (an ? '</g>' : '') + (g ? '</g>' : '');
  }).join('');
}
/** One piece, flat: a fill (rim: a darker edge; grow: an edge of its own colour), or a line (line =
 *  width). op: see-through (lenses, fairy wings). ink: the pet's eye colour (whiskers, a smile line). */
function flatPiece(pc, pet) {
  const inkC = pet ? pet.eyeColor || '#3B2A22' : '#3B2A22';
  // inkDark: a dark shape even on a pet with light eyes (the fangs' open mouth, so the white fangs show)
  const color = pc.ink ? (pc.inkDark && luma(hexOf(inkC)) > 0.5 ? '#2A1D17' : inkC) : pet ? pickColor(pc.color, pc.alt, pet, pc.clash) : pc.color;
  const ink = pc.ink && !pet ? ' data-ink="1"' : '';
  let out;
  if (pc.line) out = `<path d="${pc.d}" fill="none" stroke="${color}" stroke-width="${pc.line}" stroke-linecap="round" stroke-linejoin="round"${ink ? ' data-inkline="1"' : ''}/>`;
  else {
    const rimC = pc.rimColor ?? (luma(hexOf(color)) > 0.85 ? DC.furRim : shadeC(color, 0.13));
    const edge = pc.rim ? ` stroke="${rimC}" stroke-width="${pc.rim * 1.6}" stroke-linejoin="round" paint-order="stroke"`
      : pc.grow ? ` stroke="${color}" stroke-width="${2 * pc.grow}" stroke-linejoin="round" paint-order="stroke"` : '';
    const rule = pc.rule ?? 'evenodd';
    const cid = `df${++decorUid}`;
    // a paint with `follow` takes its alt exactly when its piece took the piece's alt (a hat band stays light on a dark hat)
    const paints = (pc.paints || []).map((q) => `<path d="${q.d}" fill="${pet ? (q.follow ? (color === pc.color ? q.color : q.alt) : pickColor(q.color, q.alt, pet)) : q.color}"/>`).join('');
    out = `<path d="${pc.d}" fill="${color}" fill-rule="${rule}"${edge}${ink}/>`
      + (paints ? `<clipPath id="${cid}"><path d="${pc.d}" clip-rule="${rule}"/></clipPath><g clip-path="url(#${cid})">${paints}</g>` : '');
  }
  return pc.op != null ? `<g opacity="${pc.op}">${out}</g>` : out;
}
/** Bounds of a path (control points included; an arc as a circle about its chord's middle). */
function pathBox(d) {
  const tok = d.match(/[a-zA-Z]|-?\d*\.?\d+(?:e-?\d+)?/g) || [];
  const b = [Infinity, Infinity, -Infinity, -Infinity];
  const add = (px, py) => { b[0] = Math.min(b[0], px); b[1] = Math.min(b[1], py); b[2] = Math.max(b[2], px); b[3] = Math.max(b[3], py); };
  let i = 0, cmd = 'M', x = 0, y = 0, x0 = 0, y0 = 0;
  const num = () => +tok[i++];
  while (i < tok.length) {
    if (/[a-zA-Z]/.test(tok[i])) cmd = tok[i++];
    const rel = cmd !== cmd.toUpperCase(), C = cmd.toUpperCase();
    const pt = () => { let px = num(), py = num(); if (rel) { px += x; py += y; } add(px, py); return [px, py]; };
    if (C === 'Z') { x = x0; y = y0; continue; }
    if (C === 'M' || C === 'L' || C === 'T') { [x, y] = pt(); if (C === 'M') { x0 = x; y0 = y; cmd = rel ? 'l' : 'L'; } }
    else if (C === 'H') { x = num() + (rel ? x : 0); add(x, y); }
    else if (C === 'V') { y = num() + (rel ? y : 0); add(x, y); }
    else if (C === 'C') { pt(); pt(); [x, y] = pt(); }
    else if (C === 'S' || C === 'Q') { pt(); [x, y] = pt(); }
    else if (C === 'A') {
      const rx = num(), ry = num(); num(); num(); num();
      let nx = num(), ny = num(); if (rel) { nx += x; ny += y; }
      const mx = (x + nx) / 2, my = (y + ny) / 2;
      add(mx - rx, my - ry); add(mx + rx, my + ry); add(nx, ny); x = nx; y = ny;
    } else i++;
  }
  return b;
}
/** A piece's bounds in its own units, with its line or edge. */
const PBOX = new Map();
function pieceBox(pc) {
  const key = pc.d + '|' + (pc.line ?? 0) + '|' + (pc.rim ?? pc.grow ?? 0);
  if (PBOX.has(key)) return PBOX.get(key);
  const q = pathBox(pc.d), w = pc.line ? pc.line / 2 : (pc.rim ?? pc.grow ?? 0) * 0.8;
  const r = [q[0] - w, q[1] - w, q[2] + w, q[3] + w];
  if (PBOX.size > 2000) PBOX.clear();
  PBOX.set(key, r);
  return r;
}
function artBox(dec) {
  let bx = [Infinity, Infinity, -Infinity, -Infinity];
  for (const pc of dec.pieces) { const b = pieceBox(pc); bx = [Math.min(bx[0], b[0]), Math.min(bx[1], b[1]), Math.max(bx[2], b[2]), Math.max(bx[3], b[3])]; }
  return bx;
}
/** 11-10 试验: a hat as ONE flat layer, seated where the solid hat would be (the hat fit), standing just
 *  in front of the highest point of the pet it covers, so nothing of the pet can come through it. */
function flatMarkup(dec, f, pls, pet) {
  const m = 1.5, boxes = [], groups = [];
  for (const pl of pls) {
    const own = pl.pieces ? { ...dec, pieces: pl.pieces } : dec, bx = artBox(own);
    const c = Math.cos(pl.rot * D2R), sn = Math.sin(pl.rot * D2R), sx = pl.mirror ? -pl.s : pl.s, A = pl.A ?? dec.A, sy = pl.s * (pl.sy ?? 1);
    const pts = [[bx[0], bx[1]], [bx[2], bx[1]], [bx[0], bx[3]], [bx[2], bx[3]]].map(([u, v]) => {
      const dx = (u - A[0]) * sx, dy = (v - A[1]) * sy;
      return [pl.P[0] + c * dx - sn * dy, pl.P[1] + sn * dx + c * dy];
    });
    boxes.push([Math.min(...pts.map((q) => q[0])) - m, Math.min(...pts.map((q) => q[1])) - m, Math.max(...pts.map((q) => q[0])) + m, Math.max(...pts.map((q) => q[1])) + m]);
    const tf = `translate(${r2(pl.P[0])} ${r2(pl.P[1])}) rotate(${r2(pl.rot)}) scale(${r4(sx)} ${r4(sy)}) translate(${r2(-A[0])} ${r2(-A[1])})`;
    groups.push(`<g transform="${tf}">${flatArt(own, pet, pl.mirror)}</g>`);
  }
  const x = Math.min(...boxes.map((q) => q[0])), y = Math.min(...boxes.map((q) => q[1]));
  const w = Math.max(...boxes.map((q) => q[2])) - x, h = Math.max(...boxes.map((q) => q[3])) - y;
  const z = flatDepth(f, boxes, pls);
  return `<svg data-part="0" data-flat="1" data-keep="1" data-at="${r4(z)}" viewBox="${r4(x)} ${r4(y)} ${r4(w)} ${r4(h)}" style="position:absolute;${boxStyle(x, y, w, h)};overflow:visible;transform:translateZ(${DU4(z)})" aria-hidden="true">`
    + groups.join('') + `</svg>`;
}
/** How deep a flat head piece stands. 'front' (round 5 trial): just in front of the highest point of
 *  the pet under it. A number k: that fraction of the way from the pet's middle (z 0) to 'front'. */
const FLAT_Z = { mode: 0.5 };
function flatDepth(f, boxes, pls) {
  const p0 = pls[0];
  if (p0.zFix != null) return p0.zFix;
  if (p0.zp != null) return Math.max(...pls.map((p) => p.zp ?? p0.zp)) + STICKER_LIFT;
  const z = Math.max(...boxes.map((b) => surfaceMax(f, b[0], b[1], b[2], b[3]))) + STICKER_LIFT + (p0.zAdd ?? 0);
  return p0.zmin != null ? Math.max(z, p0.zmin) : z;
}
/** The depth a flat head piece stands at (null: in front of everything it covers). */
function flatPlane(dec, f, x0, W) {
  if (!dec.flat || FLAT_Z.mode === 'front') return null;
  const t = f.topMain(x0) ?? f.top;
  return FLAT_Z.mode * surfaceMax(f, x0 - W / 2, t, x0 + W / 2, t + 6);
}
/** First y going down at column x where the pet's main part reaches zp forward. */
function topAtDepth(f, x, zp) {
  for (let y = f.top - 1; y < f.bottom + 1; y += 0.1) if (f.seatIn(x, y) && f.height(x, y) >= zp) return y;
  return null;
}
/** A sticker as a decal on the pet's front, the way the pets' own face paints are laid: one flat
 *  layer just in front of the face (on a round front, just in front of its highest point under the
 *  sticker, the way the eyes ride). Drawn once, parallel to the slices and in front of all of them,
 *  it cannot stack up, show steps or be cut when the pet turns (v1 printed it on every slice, and
 *  the slices' different depths slid the copies apart; a decal bent round in tilted tiles crossed
 *  the slices, and the browser cracked it along every crossing). */
function stickerMarkup(dec, f, pl, pet) {
  const artId = `da${++decorUid}`;
  const tf = `translate(${r2(pl.P[0])} ${r2(pl.P[1])}) rotate(${r2(pl.rot)}) scale(${r4(pl.s)}) translate(-50 -50)`;
  const R = pl.R + 1.2, x = pl.P[0] - R, y = pl.P[1] - R, w = 2 * R;
  return `<svg data-part="0" data-sticker="1" data-keep="1" data-at="${r4(pl.z)}" viewBox="${r4(x)} ${r4(y)} ${r4(w)} ${r4(w)}" style="position:absolute;${boxStyle(x, y, w, w)};overflow:hidden;transform:translateZ(${DU4(pl.z)})" aria-hidden="true">`
    + `<defs><g id="${artId}" transform="${tf}">${stickerArt(dec, pet)}</g></defs><use href="#${artId}"/></svg>`;
}

// ---------- bands: copies of the pet's own slices, a little larger, clipped to a strip ----------
function bandStrip(dec, f) {
  const bd = dec.band;
  let yc;
  if (bd.at === 'brow') {
    const topAtEyes = f.topAt(f.ex) ?? f.top;
    yc = f.o.band?.brow ?? Math.max(topAtEyes + bd.h / 2 + 1.5, f.ey - f.eyeH / 2 - 1.2 - bd.h / 2);
  } else {
    const sh = f.o.sash;
    if (sh && !(sh.skip || []).includes(dec.id)) return { yc: sh.y, cx: sh.x, h: bd.h, rot: sh.rot, len: sashFrame(f, dec).len };
    yc = f.o.band?.neck ?? Math.min(f.ey + f.eyeH / 2 + 4.6 + (bd.dy ?? 0) + bd.h / 2, f.bottom - 3.5 - bd.h / 2);
  }
  return { yc, h: bd.h, rot: f.o.bandRot ?? 0 };
}
function bandMarkup(dec, f, color) {
  const bd = dec.band, st = bandStrip(dec, f);
  const plan = smoothPlan(f.def, f.pet?.depth ?? undefined);
  const pi = f.vol.eyePart, part = f.main;
  const half = f.half, o = bd.o;
  const rot = st.rot ? ` transform="rotate(${r2(st.rot)} ${r2(st.cx ?? f.ex)} ${r2(st.yc)})"` : '';
  let out = '';
  const pb = part.bounds;
  part.zSlices.forEach((s, i) => {
    const sm = plan?.[pi]?.[i];
    const d = sm?.d ?? s.d;
    const z = s.at === 0 ? 0 : Math.sign(s.at) * (Math.abs(s.at) * (half + o)) / half;
    const cid = `db${++decorUid}`, cid2 = `db${++decorUid}`;
    const y1 = st.yc - st.h / 2, y2 = st.yc + st.h / 2;
    // one raster box for every slice of the band (same idea as pieceMarkup)
    const x = pb.minX - o - 1, w = pb.maxX - pb.minX + 2 * o + 2;
    const by1 = st.rot ? pb.minY - o - 1 : y1 - 3, bh = st.rot ? pb.maxY - pb.minY + 2 * o + 2 : st.h + 6;
    const stripe = bd.stripe ? `<clipPath id="${cid2}"><rect x="-100" y="${r2(y1 + st.h * bd.stripe[0])}" width="300" height="${r2(st.h * (bd.stripe[1] - bd.stripe[0]))}"${rot}/></clipPath>`
      + `<path d="${d}" fill="${bd.stripe[2]}" stroke="${bd.stripe[2]}" stroke-width="${r2(2 * o)}" stroke-linejoin="round" clip-path="url(#${cid2})"/>` : '';
    out += `<svg data-part="0" data-band="1" data-at="${r4(z)}" data-inset="${r2(s.inset ?? 0)}" data-bx="${r4(x)}" data-by="${r4(by1)}" data-bw="${r4(w)}" data-bh="${r4(bh)}" viewBox="${r4(x)} ${r4(by1)} ${r4(w)} ${r4(bh)}" style="position:absolute;${boxStyle(x, by1, w, bh)};overflow:visible;transform:translateZ(${DU4(z)})" aria-hidden="true">`
      + `<clipPath id="${cid}"><rect x="-100" y="${r2(y1)}" width="300" height="${r2(st.h)}"${rot}/></clipPath>`
      + `<path d="${d}" fill="${color}" stroke="${color}" stroke-width="${r2(2 * o)}" stroke-linejoin="round" clip-path="url(#${cid})"/>${stripe}</svg>`;
  });
  return { html: out, strip: st };
}

// ---------- mounting on a live pet (the object mountPet returns) ----------
function mountDecor(m, opts = {}) {
  const view = m.host.querySelector('[data-view]');
  const layer = document.createElement('div');
  layer.dataset.decor = '';
  layer.style.cssText = FILL3D + 'pointer-events:none';
  view.appendChild(layer);
  const f = fitPet(m.pet);
  f.pet = m.pet;
  let items = [];
  let lastLift = 0, liftVel = 0, prevVel = 0;

  function build(ids) {
    layer.innerHTML = '';
    items = [];
    for (const id of ids) {
      const dec = DECOR_BY_ID[id];
      if (!dec) continue;
      if (dec.place === 'band') {
        const el = document.createElement('div');
        el.style.cssText = FILL3D;
        const { html, strip } = bandMarkup(dec, f, pickColor(dec.band.color, dec.band.alt, m.pet));
        el.innerHTML = html;
        layer.appendChild(el);
        const inst = [];
        if (dec.tail) {
          // the hanging end of the scarf, just in front of the band, a little to the left
          const t = dec.tail, sp = f.spanAt(f.ex, strip.yc) || [f.ex - 15, f.ex + 15];
          const s = clamp((strip.len ?? sp[1] - sp[0]) / 44, 0.7, 1.05);
          // on a sash (the baguette) the end hangs from the front of the band, a little below its middle
          const sa = (strip.rot ?? 0) * D2R;
          const P = strip.cx != null ? [strip.cx + Math.cos(sa) * strip.len * 0.12 - Math.sin(sa) * strip.h * 0.15, strip.yc + Math.sin(sa) * strip.len * 0.12 + Math.cos(sa) * strip.h * 0.15]
            : [f.ex - (sp[1] - sp[0]) * 0.2, strip.yc + strip.h * 0.15];
          const tg = decorGeom(t.d, t.vol);
          const z = surfaceMax(f, P[0] - 4, strip.yc - strip.h / 2, P[0] + 4, strip.yc + strip.h / 2) * (f.half + dec.band.o) / Math.max(1e-3, f.half) + tg.half * s + 0.4;
          const room = f.bottom + 1.5 - P[1];
          const sy = clamp(room / (17 * s), 0.55, 1);
          inst.push(mountInst(dec, [{ ...t, dangle: t.dangle }, { d: t.fringe, color: t.color, alt: t.alt, vol: 0.4, pivot: t.pivot, dangle: t.dangle, dz: 0 }], { P, z, rot: -6, s, sz: 1, sy, A: t.A }));
        }
        if (dec.bell) {
          // the bell hangs from the middle of the collar, flat, just in front of the collar's front
          // on a sash (the baguette) it hangs from the band's lower edge at the middle, straight down
          const sa = (strip.cx != null ? strip.rot : 0) * D2R;
          const k = f.spacing / 17, y = strip.yc + Math.cos(sa) * (strip.h / 2 - 0.3), cy = y + 4.7 * k, ex = (strip.cx ?? f.ex) - Math.sin(sa) * (strip.h / 2 - 0.3);
          const front = surfaceMax(f, ex - 5 * k, strip.yc - strip.h / 2, ex + 5 * k, strip.yc + strip.h / 2) * (f.half + dec.band.o) / Math.max(1e-3, f.half);
          // round 6: no outline, no shine (pet rules); one slit and a round hole, the loop joined in (nonzero)
          const bell = { P: [0, 0], rot: 0, s: 1, A: [0, 0], zFix: front + 0.8, pieces: [
            { d: circ(r2(ex), r2(cy), r2(4.5 * k)) + rrect(r2(ex - 1.5 * k), r2(y - 0.9 * k), r2(ex + 1.5 * k), r2(y + 1.2 * k), r2(0.9 * k)), color: DC.gold, rule: 'nonzero', pivot: [r2(ex), r2(y - 0.3)], dangle: 0.6,
              paints: [{ d: rrect(r2(ex - 3.9 * k), r2(cy + 0.5 * k), r2(ex + 3.9 * k), r2(cy + 1.9 * k), r2(0.7 * k)) + circ(r2(ex), r2(cy + 3 * k), r2(1.05 * k)), color: '#B98327' }] }] };
          const be = document.createElement('div');
          be.style.cssText = FILL3D;
          be.innerHTML = flatMarkup(dec, f, [bell], m.pet);
          layer.appendChild(be);
          const sps = [...be.querySelectorAll('g[data-sp]')].map((g) => ({ g, v: 0, vel: 0, k: +g.dataset.k, px: g.dataset.px, py: g.dataset.py, mirror: false, last: '' }));
          items.push({ dec, el, inst, sps, el2: be });
          continue;
        }
        items.push({ dec, el, inst });
        continue;
      }
      if (dec.flat) {
        const el = document.createElement('div');
        el.style.cssText = FILL3D;
        el.innerHTML = flatMarkup(dec, f, placeDecor(dec, f), m.pet);
        layer.appendChild(el);
        // the pom of a flat santa hat or party hat still swings, inside the flat picture
        const sps = [...el.querySelectorAll('g[data-sp]')].map((g) => ({ g, v: 0, vel: 0, k: +g.dataset.k, px: g.dataset.px, py: g.dataset.py, mirror: g.dataset.m === '1', last: '' }));
        // little loops of their own (a toothbrush scrubbing, a bubble growing, wings beating, flames)
        const ans = [...el.querySelectorAll('g[data-an]')].map((g) => {
          const [r, sc, s0, y, o, per, ph, px, py, w] = g.dataset.an.split(',').map(Number);
          return { g, r, sc, s0, y, o, per, ph, px, py, w, last: '', lastO: '' };
        });
        items.push({ dec, el, inst: [], sps, ans });
        continue;
      }
      if (dec.place === 'sticker') {
        const el = document.createElement('div');
        el.style.cssText = FILL3D;
        // clear of whatever else is worn on the front (a bow tie, a medal, a beard, a scarf)
        const avoid = ids.filter((o) => o !== id && DECOR_BY_ID[o]).map((o) => decorRect(DECOR_BY_ID[o], f));
        const pl = placeDecor(dec, f, { avoid })[0];
        el.innerHTML = pl ? stickerMarkup(dec, f, pl, m.pet) : '';
        if (!pl) el.dataset.noroom = '1';
        layer.appendChild(el);
        items.push({ dec, el, inst: [] });
        continue;
      }
      const inst = placeDecor(dec, f).map((pl) => mountInst(dec, dec.pieces, pl));
      items.push({ dec, inst });
    }
    // springs restart at rest
    items.forEach((it) => { it.inst.forEach((ins) => ins.springs.forEach((sp) => { sp.v = 0; sp.vel = 0; })); (it.sps || []).forEach((sp) => { sp.v = 0; sp.vel = 0; }); });
    prepare();
  }

  // ---- the pets' slice rules, applied to the decorations ----
  // groups: slices of one part of one piece, with how their local units map to the pet's.
  let groups = [], lastSize = 0, cullKey = '';
  function prepare() {
    groups = [];
    for (const it of items) {
      // a sticker's layers are its own (one decal, or tiles laid on a round front): never culled or re-boxed
      if (it.el && it.dec.place !== 'sticker' && !it.dec.flat) groups.push({ svgs: [...it.el.querySelectorAll(':scope > svg[data-at]')], zs: 1, xs: 1, band: true, el: it.el });
      for (const ins of it.inst) {
        const { pl } = ins;
        const fixed = !pl.rx && !(pl.ry ?? 0) && !['wing', 'halo', 'orbit'].includes(pl.kind);
        for (const p of ins.pels) {
          const by = new Map();
          for (const sv of p.el.querySelectorAll(':scope > svg[data-at]')) {
            const k = sv.dataset.part;
            if (!by.has(k)) by.set(k, []);
            by.get(k).push(sv);
          }
          for (const svgs of by.values()) groups.push({ svgs, zs: pl.s * pl.sz, xs: pl.s, cull: fixed, ins, pel: p });
        }
      }
    }
    for (const g of groups) {
      g.svgs.sort((a, b) => +a.dataset.at - +b.dataset.at);
      g.sl = g.svgs.map((el) => ({ el, at: +el.dataset.at, inset: +(el.dataset.inset ?? 0), keep: el.dataset.keep === '1', lod: true, on: true }));
    }
    lastSize = 0; cullKey = '';
    detail();
    align();
  }
  // sliceDetail: keep slices at least SLICE_GAP (0.75 px) apart on screen at the size they are drawn
  function detail() {
    const size = m.host.clientWidth;
    if (!size || size === lastSize) return;
    lastSize = size;
    const gap = (0.75 * 100) / size;
    for (const g of groups) {
      let last = -Infinity;
      g.sl.forEach((sl, j) => {
        const core = sl.at === 0 && sl.inset === 0;
        sl.lod = core || sl.keep || j === 0 || j === g.sl.length - 1 || (sl.at - last) * g.zs >= gap;
        if (sl.lod) last = sl.at;
      });
    }
    cullKey = '';
  }
  // alignSlices: put each shared raster box on the device pixel grid at rest (no tilt, no turn of its own)
  function align() {
    const k = (m.host.clientWidth / 100) * (globalThis.devicePixelRatio || 1);
    if (!k) return;
    const setBox = (sv, x, y, w, h) => {
      sv.setAttribute('viewBox', `${r4(x)} ${r4(y)} ${r4(w)} ${r4(h)}`);
      sv.style.left = DU4(x); sv.style.top = DU4(y); sv.style.width = DU4(w); sv.style.height = DU4(h);
    };
    const box = (sv) => [+sv.dataset.bx, +sv.dataset.by, +sv.dataset.bw, +sv.dataset.bh];
    const snapped = new Set();
    for (const g of groups) {
      if (!g.svgs.length) continue;
      if (g.band) {
        const [x, y, w, h] = box(g.svgs[0]);
        const x2 = Math.floor(x * k) / k, y2 = Math.floor(y * k) / k;
        g.svgs.forEach((sv) => setBox(sv, x2, y2, w + x - x2, h + y - y2));
        continue;
      }
      const { ins } = g, pl = ins.pl;
      if (pl.rot || pl.rx || pl.ry || ['halo', 'wing', 'tail', 'float', 'orbit'].includes(pl.kind) || g.pel.sp) continue;
      const sx = pl.mirror ? -pl.s : pl.s, sy = pl.s * (pl.sy ?? 1);
      const [x, y, w, h] = box(g.svgs[0]);
      if (!snapped.has(ins)) {
        // move the instance so this box's corner lands on a device pixel
        snapped.add(ins);
        ins.ref = [x, y];
        const X = pl.P[0] + sx * (x - pl.A[0]), Y = pl.P[1] + sy * (y - pl.A[1]);
        pl.Ps = [pl.P[0] + Math.round(X * k) / k - X, pl.P[1] + Math.round(Y * k) / k - Y];
        ins.last = '';
        continue;
      }
      // other boxes of the same instance: onto the same lattice
      const lx = 1 / (Math.abs(sx) * k), ly = 1 / (sy * k);
      const x2 = ins.ref[0] + Math.floor((x - ins.ref[0]) / lx) * lx, y2 = ins.ref[1] + Math.floor((y - ins.ref[1]) / ly) * ly;
      g.svgs.forEach((sv) => setBox(sv, x2, y2, w + x - x2, h + y - y2));
    }
  }
  const ro = typeof ResizeObserver === 'function' ? new ResizeObserver(() => { detail(); align(); }) : null;
  ro?.observe(m.host);
  // sliceCull: a slice whose outline sits further inside than its depth shifts it on screen is
  // hidden behind the others, and the pieces are flat colour, so it is not drawn at all
  function cull(st) {
    const yaw = (st.yaw ?? 0) * D2R_, pitch = (st.pitch ?? 0) * D2R_;
    const sweep = Math.hypot(Math.sin(yaw), Math.cos(yaw) * Math.sin(pitch));
    const insetK = Math.min(Math.abs(Math.cos(yaw)), Math.abs(Math.cos(pitch)));
    const key = `${r4(sweep)}|${r4(insetK)}|${lastSize}`;
    if (key === cullKey) return;
    cullKey = key;
    for (const g of groups) {
      const zr = g.zs / g.xs;
      for (const sl of g.sl) {
        // only slices behind the core (at < 0) are culled: a decoration's front slices sit in front of
        // the pet where it overlaps it (horn roots, a scarf across the face), not behind its own core
        const on = sl.lod && (!g.cull && !g.band || sl.keep || sl.at > 0 || sl.inset <= 0 || Math.abs(sl.at) * zr * sweep > sl.inset * insetK - 0.15);
        if (on !== sl.on) { sl.on = on; sl.el.style.display = on ? '' : 'none'; }
      }
    }
  }

  function mountInst(dec, pieces, pl) {
    const wrap = document.createElement('div');
    wrap.style.cssText = FILL3D + 'transform-origin:0 0';
    const springs = [];
    const pels = pieces.map((pc, pi) => {
      const color = dec.inkColor ? (m.pet.eyeColor || '#3B2A22') : pickColor(pc.color, pc.alt, m.pet);
      const el = document.createElement('div');
      el.style.cssText = FILL3D;
      if (pc.pivot) el.style.transformOrigin = `${DU(pc.pivot[0])} ${DU(pc.pivot[1])}`;
      el.innerHTML = pieceMarkup(pl.vols ? { ...pc, vol: pl.vols[pi] } : pc, color);
      wrap.appendChild(el);
      const sp = pc.dangle ? { v: 0, vel: 0, k: pc.dangle } : null;
      if (sp) springs.push(sp);
      return { pc, el, sp, last: '' };
    });
    // 下雨天: drops in the cloud's own plane, falling from its foot (they come out from behind its front)
    let drops = null;
    if (dec.rain && pl.fall) {
      const R = dec.rain, x1 = Math.min(...R.xs) - 2, x2 = Math.max(...R.xs) + 2, y1 = R.y0 - 2, y2 = R.y0 + pl.fall + 2.5;
      const sv = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      sv.setAttribute('viewBox', `${r4(x1)} ${r4(y1)} ${r4(x2 - x1)} ${r4(y2 - y1)}`);
      sv.setAttribute('aria-hidden', 'true');
      sv.dataset.keep = '1';
      sv.style.cssText = `position:absolute;${boxStyle(x1, y1, x2 - x1, y2 - y1)};overflow:visible;transform:translateZ(0)`;
      const DROP = 'M0 -2.3C0.8 -0.8 1.5 0.1 1.5 1C1.5 1.9 0.8 2.6 0 2.6C-0.8 2.6 -1.5 1.9 -1.5 1C-1.5 0.1 -0.8 -0.8 0 -2.3Z';
      sv.innerHTML = R.xs.map(() => `<path d="${DROP}" fill="${R.color}"/>`).join('');
      wrap.appendChild(sv);
      drops = [...sv.children].map((el, i) => ({ el, x: R.xs[i], ph: (i * 0.37) % 1, last: '' }));
    }
    layer.appendChild(wrap);
    return { dec, pl: { ...pl, A: pl.A ?? dec.A }, wrap, pels, springs, drops, last: '' };
  }

  /** A pendulum: hangs straight while the body rolls, lags on hops, sways a touch on its own. */
  function swing(sp, mirror, st, t, dt, acc) {
    const target = -(st.roll ?? 0) * 0.55 * sp.k * (mirror ? -1 : 1) + 2.2 * sp.k * Math.sin((2 * Math.PI * t) / 2.9 + sp.k);
    if (dt > 0) {
      const kick = clamp(acc * 0.012 * sp.k, -40, 40);
      let r = Math.min(dt, 0.1);
      while (r > 0) { const h = Math.min(1 / 120, r); r -= h; const a = -64 * (sp.v - target) - 2 * 0.28 * 8 * sp.vel + kick * 60; sp.vel += a * h; sp.v += sp.vel * h; }
    } else sp.v = target;
  }
  /** Per frame: st = the pet's state (same object the pet drew), t = clock (s), dt = step (s, 0 = still). */
  function frame(st, t = 0, dt = 0) {
    cull(st);
    // vertical acceleration of the body (hops, landings) shakes the dangly bits
    const lift = st.lift ?? 0;
    if (dt > 0) { const v = (lift - lastLift) / dt; liftVel = v; } else liftVel = 0;
    const acc = dt > 0 ? (liftVel - prevVel) / dt : 0;
    prevVel = liftVel; lastLift = lift;
    const mouth = st.mouth && st.mouth.k === 'yawn' ? clamp(st.mouth.s, 0, 1) : 0;
    const air = clamp(-lift / 5, 0, 1);
    for (const it of items) {
      for (const sp of it.sps || []) {
        swing(sp, sp.mirror, st, t, dt, acc);
        const tf = `rotate(${r2(clamp(sp.v, -28, 28))} ${sp.px} ${sp.py})`;
        if (tf !== sp.last) { sp.last = tf; sp.g.setAttribute('transform', tf); }
      }
      for (const a of it.ans || []) {
        const v = Math.sin((2 * Math.PI * t) / a.per + a.ph);
        let tf = '';
        if (a.y) tf += `translate(0 ${r2(a.y * v)}) `;
        if (a.r) tf += `rotate(${r2(a.r * v)} ${a.px} ${a.py}) `;
        // w: a steady turn (the pinwheel), degrees a second
        if (a.w) tf += `rotate(${r2((a.w * t) % 360)} ${a.px} ${a.py}) `;
        if (a.sc) { const k = a.s0 + a.sc * v; tf += `translate(${a.px} ${a.py}) scale(${r4(k)}) translate(${-a.px} ${-a.py})`; }
        if (tf !== a.last) { a.last = tf; a.g.setAttribute('transform', tf); }
        if (a.o) { const op = String(r2(1 - a.o * (0.5 - 0.5 * v))); if (op !== a.lastO) { a.lastO = op; a.g.setAttribute('opacity', op); } }
      }
      for (const ins of it.inst) {
        const { pl } = ins;
        let dy = 0, ry = pl.ry ?? 0, rz = pl.rot, sx = 1;
        let P = pl.Ps ?? pl.P, z = pl.z;
        if (pl.kind === 'halo') dy = 0.75 * Math.sin((2 * Math.PI * t) / 2.6);
        if (pl.kind === 'float') {
          // floats: a slow bob and a little rock, never down to the head (the gap is bigger than the bob)
          dy = 0.8 * Math.sin((2 * Math.PI * t) / 3.1);
          rz += (it.dec.sway ?? 2.5) * Math.sin((2 * Math.PI * t) / 4.3 + 0.7);
          if (it.dec.flap) {
            // a butterfly: quick beats (the wings narrow towards the body), a lazy figure-of-eight drift
            sx = 0.42 + 0.58 * Math.abs(Math.cos((2 * Math.PI * t) / 0.62));
            P = [P[0] + 1.6 * Math.sin((2 * Math.PI * t) / 5.2), P[1]];
            dy = 1.1 * Math.sin((4 * Math.PI * t) / 5.2);
          }
        }
        if (pl.kind === 'orbit') {
          const a = 2 * Math.PI * (t / 9 + pl.k / pl.n);
          P = [pl.P[0] + pl.R * Math.cos(a), pl.P[1] + pl.R * pl.tilt * Math.sin(a)];
          z = pl.R * 0.9 * Math.sin(a);
          dy = 0.35 * Math.sin((2 * Math.PI * t) / 1.7 + pl.k * 1.3);
          rz = 10 * Math.sin(a * 2 + pl.k);
        }
        if (pl.kind === 'wing') {
          // a flap in the wing's own plane: the tip lifts and the wing narrows a little as it beats
          // (slow and soft at rest, fast and wide in the air)
          const slow = Math.sin((2 * Math.PI * t) / 1.9), fast = Math.sin((2 * Math.PI * t) / 0.32);
          rz -= pl.side * (3.5 * slow + air * (9 * fast + 7));
          sx = 1 - 0.05 * (1 + slow) - air * 0.12 * (1 + fast);
        }
        if (pl.kind === 'tail') rz += 7 * Math.sin((2 * Math.PI * t) / 2.3);
        if (ins.drops) {
          const R = it.dec.rain;
          for (const d of ins.drops) {
            const u = (t / R.per + d.ph) % 1;
            const op = u < 0.12 ? u / 0.12 : u > 0.72 ? Math.max(0, (1 - u) / 0.28) : 1;
            const tf = `translate(${d.x} ${r2(R.y0 + u * pl.fall)})|${r2(op)}`;
            if (tf !== d.last) { d.last = tf; const [a, o] = tf.split('|'); d.el.setAttribute('transform', a); d.el.setAttribute('opacity', o); }
          }
        }
        const sc = (pl.mirror ? -pl.s : pl.s) * sx;
        const tf = `translate3d(${DU4(P[0])},${DU4(P[1] + dy)},${DU(z)}) rotate(${r2(rz)}deg)`
          + (pl.rx ? ` rotateX(${r2(pl.rx)}deg)` : '') + (ry ? ` rotateY(${r2(ry)}deg)` : '')
          + ` scale3d(${r2(sc * 1000) / 1000},${r2(pl.s * (pl.sy ?? 1) * 1000) / 1000},${r2(pl.s * pl.sz * 1000) / 1000}) translate(${DU(-pl.A[0])},${DU(-pl.A[1])})`;
        if (tf !== ins.last) { ins.last = tf; ins.wrap.style.transform = tf; }
        for (const p of ins.pels) {
          let ptf = '';
          if (p.sp) {
            swing(p.sp, pl.mirror, st, t, dt, acc);
            ptf = `rotate(${r2(clamp(p.sp.v, -28, 28))}deg)`;
          }
          if (p.pc.jaw && mouth) ptf += ` translateY(${DU(3.4 * p.pc.jaw * mouth)})`;
          if (p.pc.blink) {
            // 11-11 the bulb's rays: pop out (a little past full size), stay, shrink back behind the glass, rest
            const u = (t / p.pc.blink + 0.35) % 1, e = u / 0.1 - 1;
            const on = u < 0.1 ? 1 + 2.7 * e * e * e + 1.7 * e * e : u < 0.62 ? 1 : u < 0.74 ? 1 - (u - 0.62) / 0.12 : 0;
            ptf += ` scale(${r4(Math.max(0.001, on))})`;
          }
          if (ptf !== p.last) { p.last = ptf; p.el.style.transform = ptf; }
        }
      }
    }
  }
  let ids = [];
  build(opts.items || []);
  return {
    frame,
    set(list) { ids = [...list]; build(ids); },
    destroy() { ro?.disconnect(); layer.remove(); },
    items: () => ids.slice(),
    fit: f,
  };
}

/** Icon of a round-5 flat piece: its own flat drawing (wings as a pair, spikes as a row of three). */
function flatIcon(dec, size) {
  let art = flatArt(dec, null), bx = artBox(dec);
  if (dec.at === 'sides') { art = art + `<g transform="translate(100 0) scale(-1 1)">${art}</g>`; bx = [100 - bx[2], bx[1], bx[2], bx[3]]; }
  if (dec.at === 'roll') { art = art + `<g transform="translate(100 0) scale(-1 1)">${art}</g>`; bx = [Math.min(bx[0], 100 - bx[2]), bx[1], Math.max(bx[2], 100 - bx[0]), bx[3]]; }
  if (dec.at === 'shoulders') { art = `<g transform="translate(-8 0)">${art}</g><g transform="translate(8 0)">${art}</g>`; bx = [bx[0] - 8, bx[1], bx[2] + 8, bx[3]]; }
  if (dec.at === 'spine') {
    art = `<g transform="translate(-10 4) rotate(-28 50 60) scale(.85)" transform-origin="50 60">${art}</g><g transform="translate(10 4) rotate(28 50 60)">${art}</g>` + art;
    bx = [bx[0] - 14, bx[1], bx[2] + 14, bx[3] + 4];
  }
  const w = bx[2] - bx[0], h = bx[3] - bx[1], m = Math.max(w, h) * 0.1, side = Math.max(w, h) + 2 * m;
  const vx = (bx[0] + bx[2]) / 2 - side / 2, vy = (bx[1] + bx[3]) / 2 - side / 2;
  return `<svg viewBox="${r2(vx)} ${r2(vy)} ${r2(side)} ${r2(side)}" width="${size}" height="${size}" aria-hidden="true">${art}</svg>`;
}
/** A flat front-view icon of a decoration (for chips): the outlines, no volume. */
function decorIcon(dec, size = 40) {
  if (dec.place === 'band' && dec.bell) {
    return `<svg viewBox="0 0 40 40" width="${size}" height="${size}" aria-hidden="true"><rect x="5" y="13" width="30" height="5" rx="2.5" fill="${dec.band.color}"/>`
      + `<rect x="18" y="16.5" width="4" height="3.4" rx="1.2" fill="${DC.gold}"/><circle cx="20" cy="25" r="6.2" fill="${DC.gold}"/><rect x="14.6" y="25.6" width="10.8" height="1.9" rx=".95" fill="#B98327"/><circle cx="20" cy="29.2" r="1.4" fill="#B98327"/></svg>`;
  }
  if (dec.place === 'band') {
    const c = dec.band.color, st = dec.band.stripe;
    const tail = dec.tail ? `<path d="M23 24h6v13h-6z" fill="${c}"/><path d="M23 30h6v1.5h-6zM23 33.5h6V35h-6z" fill="${DC.cream}"/>` : '';
    return `<svg viewBox="0 0 40 40" width="${size}" height="${size}" aria-hidden="true"><rect x="5" y="15" width="30" height="${dec.tail ? 9 : 10}" rx="${dec.tail ? 4.5 : 5}" fill="${c}"/>`
      + (st ? `<rect x="5" y="19" width="30" height="2" fill="${st[2]}"/>` : '') + tail + `</svg>`;
  }
  if (dec.place === 'sticker') {
    const k = dec.W0 / 2 + 0.6;
    return `<svg viewBox="${r2(50 - k)} ${r2(50 - k)} ${r2(2 * k)} ${r2(2 * k)}" width="${size}" height="${size}" aria-hidden="true"><g transform="rotate(${dec.tilt ?? 0} 50 50)">${stickerArt(dec)}</g></svg>`;
  }
  if (['specs', 'muzzle', 'collar', 'behind'].includes(dec.place)) return flatIcon(dec, size);
  if (dec.place === 'orbit') {
    const pc = dec.pieces[0], one = (x, y, k) => `<path d="${pc.d}" fill="${pc.color}" transform="translate(${x} ${y}) scale(${k}) translate(-50 -50)"/>`;
    return `<svg viewBox="30 36 40 28" width="${size}" height="${size}" aria-hidden="true"><ellipse cx="50" cy="50" rx="15" ry="4.4" fill="none" stroke="${pc.color}" stroke-width=".8" stroke-dasharray="1.6 2.2" opacity=".55"/>`
      + one(35, 50, 0.9) + one(50, 54.4, 1.1) + one(65, 50, 0.9) + one(43, 46.2, 0.7) + one(57, 46.2, 0.7) + `</svg>`;
  }
  const paths = [];
  let bx = [Infinity, Infinity, -Infinity, -Infinity];
  const grow = (b) => { bx = [Math.min(bx[0], b.minX), Math.min(bx[1], b.minY), Math.max(bx[2], b.maxX), Math.max(bx[3], b.maxY)]; };
  dec.pieces.forEach((pc) => {
    if (pc.lens) { paths.push(pc.lens.map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}" fill="#fff" opacity=".35"/>`).join('')); return; }
    const color = dec.inkColor ? '#3B2A22' : pc.color;
    grow(analyzeBody(pc.d).bounds);
    const rim = pc.rim ? ` stroke="${shadeC(color, 0.16)}" stroke-width="${pc.rim * 1.4}"` : '';
    const cid = `di${++decorUid}`;
    const paints = (pc.paints || []).map((p) => `<path d="${p.d}" fill="${p.color}"/>`).join('');
    // rimOut: no rim over that shape (the moustache's lower edge on the beard), as on the stage
    const ro = pc.rim && pc.rimOut ? `dt${++decorUid}` : null;
    const roMask = ro ? `<mask id="${ro}" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100"><rect width="100" height="100" fill="#fff"/><path d="${pc.rimOut}" fill="#000" stroke="#fff" stroke-width="2.4"/></mask>` : '';
    paths.push(ro
      ? roMask + `<path d="${pc.d}" fill="${color}" fill-rule="evenodd"/>` + (paints ? `<clipPath id="${cid}"><path d="${pc.d}" fill-rule="evenodd"/></clipPath><g clip-path="url(#${cid})">${paints}</g>` : '') + `<path d="${pc.d}" fill="none"${rim} mask="url(#${ro})"/>`
      : `<path d="${pc.d}" fill="${color}" fill-rule="evenodd"${rim}${dec.inkColor ? ' data-ink="1"' : ''}/>` + (paints ? `<clipPath id="${cid}"><path d="${pc.d}" fill-rule="evenodd"/></clipPath><g clip-path="url(#${cid})">${paints}</g>` : ''));
  });
  if (dec.rain) {
    paths.push(dec.rain.xs.slice(0, 3).map((x, i) => `<path d="M${x} ${59 + i % 2 * 2.6}c.7 1.2 1.3 2 1.3 2.7a1.3 1.3 0 0 1-2.6 0c0-.7.6-1.5 1.3-2.7z" fill="${dec.rain.color}"/>`).join(''));
    bx = [bx[0], bx[1], bx[2], bx[3] + 6.5];
  }
  if (dec.place === 'wings') {
    const mirror = `<g transform="translate(100 0) scale(-1 1)">${paths.join('')}</g>`;
    paths.push(mirror);
    bx = [100 - bx[2], bx[1], bx[2], bx[3]];
  }
  if (dec.place === 'pair') {
    const k = dec.sep * dec.W0 / 2;
    const one = paths.join('');
    paths.length = 0;
    paths.push(`<g transform="translate(${-k} 0) rotate(${-dec.splay} 50 60)">${one}</g><g transform="translate(${100 + k} 0) scale(-1 1) rotate(${-dec.splay} 50 60)">${one}</g>`);
    bx = [bx[0] - k - 4, bx[1] - 2, bx[2] + k + 4, bx[3]];
  }
  const w = bx[2] - bx[0], h = bx[3] - bx[1], m = Math.max(w, h) * 0.12, side = Math.max(w, h) + 2 * m;
  const vx = (bx[0] + bx[2]) / 2 - side / 2, vy = (bx[1] + bx[3]) / 2 - side / 2;
  return `<svg viewBox="${r2(vx)} ${r2(vy)} ${r2(side)} ${r2(side)}" width="${size}" height="${size}" aria-hidden="true">${paths.join('')}</svg>`;
}
