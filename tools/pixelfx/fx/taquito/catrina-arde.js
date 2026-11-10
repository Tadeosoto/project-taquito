// Recortado de status/burning para las partes de La Mojiganga que arden (falda, blusa, cabeza): sin
// el personaje de pixelfx (no hay cuerpo que destelle ni que se chamusque: el carton es 3D). Seis
// focos fijos en un parche ancho, con lenguas, humo y chispas, y la llamarada cada 0.6 s.
// The flame tongues, embers and thin smoke are
// adapted from Sprite Fusion's open-source fire (https://www.spritefusion.com/pixel-art-vfx/fire),
// MIT License, Copyright (c) 2026 Hugo Duprez.
import { cycle, fit, hex, mix, rand, Rng } from "../../core/index.js";
import { tnoise, travel, tongue, smoke, ember } from "../status/_lib.js";

export const meta = {
  name: "Carton ardiendo",
  desc: "Un parche de carton ardiendo: seis focos con lenguas que lamen hacia arriba, humo delgado y chispas; cada 0.6 s llamarada. Recortado de status/burning, sin el personaje.",
  tags: ["fire", "burn", "taquito", "loop"],
  size: [96, 96],
  origin: [48, 84],
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: "ground",
  options: {
    palette: ["#4a1712", "#8a1f17", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"],
    smoke: "#5b5566",
    seed: 3,
  },
};

const D = meta.duration, TICK = 0.6, WIND = -10;
const since = (t) => (((t % TICK) + TICK) % TICK);
const flare = (t) => Math.exp(-since(t) / 0.12);

// los focos: x, y (desde el origen), cuantas lenguas, que tan altas
const BASE = [[-20, -4, 3, 6], [-8, -10, 3, 7.5], [6, -6, 3, 7], [18, -2, 2, 5.5], [-14, -22, 2, 5], [12, -20, 2, 5.5]];
const CACHE = new Map();
function spots(seed) {
  if (CACHE.has(seed)) return CACHE.get(seed);
  const R = new Rng(seed * 13 + 5);
  const list = BASE.map(([x, y, n, h], i) => ({
    x, y,
    tongues: Array.from({ length: n }, (_, j) => ({ dx: (j - (n - 1) / 2) * 2.2 + R.range(-0.6, 0.6), h: h * R.range(0.8, 1.2), n: i * 17 + j * 5 + seed })),
  }));
  CACHE.set(seed, list);
  return list;
}

export function drawBack(p, t, o) {
  const F = fit(o.palette, 9).reverse(), list = spots(o.seed);
  const smokeC = mix(hex(o.smoke), F[6], 0.2);
  cycle(t, D, 22, o.seed + 4, (r) => r.range(0.8, 1.2), (age, life, r, i) => {
    const sp = list[i % list.length], x = sp.x + travel(WIND * 0.6, WIND * 0.5, 0.8, age) + Math.sin(age * 4 + i) * 1.4, y = sp.y - 6 - travel(22, 8, 1, age);
    smoke(p, x, y, r.range(1.3, 2.3), age / life, smokeC, 0.9);
  });
}

export function draw(p, t, o) {
  const F = fit(o.palette, 9).reverse(), list = spots(o.seed);
  const ph = since(t), tick = Math.floor(t / TICK) % 2, fl = flare(t);
  for (const sp of list) {
    for (const tg of sp.tongues) {
      const h = tg.h * (0.85 + 0.25 * tnoise(t, D, 5, tg.n)) * (1 + 1.4 * fl);
      tongue(p, sp.x + tg.dx, sp.y, h, 1.3 + 0.3 * fl, WIND * 0.08 * h / 4 + tnoise(t, D, 3, tg.n + 9) * 0.8, F, t, D, tg.n);
    }
    p.glow(sp.x, sp.y - 2, 10 + 6 * fl, F[4], 0.22 + 0.32 * fl);
  }
  cycle(t, D, 26, o.seed + 6, (r) => r.range(0.5, 0.9), (age, life, r, i) => {
    const sp = list[i % list.length], x = sp.x + r.range(-2, 2) + travel(WIND + r.range(-10, 6), WIND * 0.6, 1.2, age) + Math.sin(age * 9 + i) * 1.2 * age;
    const y = sp.y - 2 + travel(-r.range(30, 60), -18, 1.4, age);
    ember(p, x, y, age / life, [F[1], F[3], F[5]], age + i);
  });
  if (ph < 0.3)
    for (const [k, sp] of list.entries())
      for (let j = 0; j < 3; j++) {
        const an = -Math.PI / 2 + (rand(k, j, tick) - 0.5) * 2.2, v = 50 + 50 * rand(k, j, 2), x = sp.x + Math.cos(an) * travel(v, 0, 3, ph), y = sp.y - 2 + Math.sin(an) * travel(v, 0, 3, ph) + 60 * ph * ph;
        p.px(x, y, ph < 0.12 ? F[1] : F[3]);
        p.light(x, y, F[3], 0.4 * (1 - ph / 0.3));
      }
}
