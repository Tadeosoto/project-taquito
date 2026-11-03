// Recortado de fire/brazier para los tambos de Guadalajaja: sin tripie, sin cazo y sin luz en
// el piso (el tambo es 3D; el borde queda en y = RIM).
// The tongue, lick, flame-puff, smoke, ember and spark recipe is adapted from Sprite Fusion's open-source fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.
import { fit, mix, rand, clamp, WHITE } from "../../core/index.js";
import { noiseFor, hotFirst, burn, looped, drift, spark, ember } from "../fire/_lib.js";

export const meta = {
  name: "Fuego de tambo",
  desc: "El fuego de un tambo en la calle (sin el tambo, que va en 3D): brasas asomando por el borde, lenguas, chispas, brasas y humo. Recortado de fire/brazier.",
  tags: ["fire", "barrel", "taquito", "loop"],
  size: [112, 116],
  origin: [56, 112],
  duration: 3,
  loop: true,
  fps: 30,
  bg: "ground",
  options: {
    palette: ["#4a1712", "#8a1f17", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"],
    iron: ["#0b0910", "#1c1924", "#302c3a", "#4c4658", "#78708a"],
    seed: 8,
  },
};

const D = meta.duration, NL = noiseFor(D), RIM = -2, RX = 15, RY = 3;
// the fire: [x, y from the rim, height share, half-width, back row?]
const TONGUES = [
  [-7, -1.5, 0.5, 2.0, 1],
  [7.2, -1.5, 0.55, 2.0, 1],
  [-3, -2.5, 0.84, 2.2, 1],
  [3.3, -2.5, 0.86, 2.2, 1],
  [-11.5, 0.5, 0.2, 1.5, 0],
  [11.5, 0.5, 0.22, 1.5, 0],
  [-8.3, 0, 0.34, 2.0, 0],
  [8.5, 0, 0.38, 2.0, 0],
  [-4.7, -0.5, 0.6, 2.8, 0],
  [4.9, -0.5, 0.64, 2.8, 0],
  [0, -1, 1, 3.6, 0],
];

// coals heaped in the bowl, showing over the rim, breathing in the heat
function coals(p, I, H, t, S) {
  p.shade(-RX, RIM - 6, RX, RIM + 1, (x, y, out) => {
    // a mound: highest in the middle, standing proud of the rim
    const top = RIM - 1 - 4 * Math.max(0, 1 - (x / (RX - 1)) ** 2);
    if (y < top || y > RIM + 0.5 || Math.abs(x) > RX - 0.5) return;
    const lump = rand(Math.floor((x + Math.floor(y) * 1.5) / 3), Math.floor(y / 2), S + 20), edge = y < top + 1;
    // the gaps between lumps stay dark; the lumps breathe, hottest deep in the heap
    if (rand(Math.floor(x), Math.floor(y), S + 21) < 0.16 || (edge && lump < 0.3)) return I[0];
    const g = (0.5 + 0.5 * Math.sin((t / D) * Math.PI * 4 + lump * 40)) * (edge ? 0.7 : 1);
    out.k = 0.3 * g;
    return g > 0.72 ? H[2] : g > 0.5 ? H[3] : g > 0.3 ? H[4] : g > 0.15 ? H[5] : H[6];
  });
}

export function draw(p, t, o) {
  const F = fit(o.palette, 9), H = hotFirst(F), I = fit(o.iron, 5), S = o.seed;
  const fl = 0.74 + 0.16 * NL(t, 7.3, S + 1) + 0.1 * NL(t, 19, S + 2), GLOW = mix(mix(H[3], H[4], 0.5), WHITE, 0.25);
  const SPARKS = [H[1], H[2], H[4], H[5]], EMB = [H[1], H[2], H[4], H[6]];
  burn(p, t, TONGUES, {
    H, D, NL, S, x: 0, y: RIM, height: 32, lean: 0.1, spread: 7,
    puffs: 8, licks: 4, smoke: 14, smokeSize: 3, smokeLife: [1.6, 2.4], embers: 10, glowR: 40, glow: 1.4, wind: 3,
    mid: () => {
      coals(p, I, H, t, S);
    },
  });
  // sparks streaming up in the draught: fast streaks that slow, wander and cool to embers high above
  looped(t, D, 60, S + 600, (r) => {
    const side = r.range(-1, 1);
    return { x: side * 8, y: RIM - r.range(4, 18), vx: side * r.range(10, 40), vy: -r.range(70, 150), life: r.range(0.7, 1.7), a: r.range(0, 6.3), w: r.range(1.8, 3.2), m: r.range(3, 8), big: r.chance(0.12) };
  }, (q, age) => {
    const [x, y, vx, vy] = drift(q.x, q.y, q.vx, q.vy, age, 0, -22, 1.9, 1.9), k = 1 - age / q.life;
    // they bend and wander as the draught slows them
    const wob = q.m * (Math.sin(age * q.w + q.a) - Math.sin(q.a)) * Math.min(1, age * 1.5), wv = q.m * q.w * Math.cos(age * q.w + q.a) * Math.min(1, age * 1.5);
    if (Math.hypot(vx + wv, vy) > 40) spark(p, x + wob, y, vx + wv, vy, k, SPARKS);
    else ember(p, x + wob, y, k, q.big ? 2 : 1, EMB, age * 40 + q.a);
  });
}
