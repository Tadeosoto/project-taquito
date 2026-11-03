// Recortado de status/rage para los zombis cazadores de Guadalajaja: solo la marca de enojo que
// late, el vapor y las rayas, sin cuerpo, ojos ni piso (status/rage dibuja al personaje de
// pixelfx). y = 0 es la coronilla; se pone sobre la cabeza del zombi.
// The shaded, outlined anger mark is adapted from Sprite Fusion's open-source heal
// (https://www.spritefusion.com/pixel-art-vfx/heal), MIT License, Copyright (c) 2026 Hugo Duprez.
import { fit, hex, rand } from "../../core/index.js";
import { icon, bitmap, travel } from "../status/_lib.js";

export const meta = {
  name: "Marca de rabia",
  desc: "Sobre la cabeza de un zombi cazador: una marca de enojo que late lub-dub, vapor que sale a chorros despues de cada latido y rayas de coraje que destellan alrededor.",
  tags: ["status", "rage", "taquito", "loop"],
  size: [52, 56],
  origin: [26, 40],
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: "ground",
  options: {
    palette: ["#1a0208", "#4a0612", "#8a0c1c", "#c81828", "#ff3040", "#ff7a7a", "#ffc8c8", "#ffffff"],
    steam: "#d8d2d4",
    seed: 6,
  },
};

const D = meta.duration, LUB = 0.05, DUB = 0.29;
const pulse = (t, at, w = 0.06) => Math.exp(-((((((t - at) % D) + D + D / 2) % D - D / 2) / w) ** 2));
const beat = (t) => pulse(t, LUB) + 0.65 * pulse(t, DUB);
const since = (t, at) => (((t - at) % D) + D) % D;
// the anger mark: four curves round a cross-shaped gap, at two sizes for the throb
const MARK = [
  bitmap(["..#.#..", "..#.#..", "##...##", ".......", "##...##", "..#.#..", "..#.#.."]),
  bitmap(["...#.#...", "...#.#...", "..##.##..", "###...###", ".........", "###...###", "..##.##..", "...#.#...", "...#.#..."]),
];
// la cabeza: su centro y su medio ancho, en pixeles bajo la coronilla
const CY = 6, HW = 6;

export function draw(p, t, o) {
  const C = fit(o.palette, 8), b = beat(t), steam = hex(o.steam);
  // la marca, al lado de la sien: grande en el lub, chica en el dub
  const big = pulse(t, LUB + 0.02, 0.05) > 0.35 || pulse(t, DUB + 0.02, 0.04) > 0.6;
  const mx = HW + 2, my = -4;
  icon(p, mx, my, 5, MARK[big ? 1 : 0], [C[0], C[3], C[4], C[5]]);
  p.px(mx - (big ? 3 : 2), my - (big ? 3 : 2), C[6]);
  p.glow(mx, my, 8, C[4], 0.25 + 0.4 * b);
  // vapor a chorros de los lados de la cabeza despues de cada latido
  for (const [at, n, power] of [[LUB + 0.04, 7, 1], [DUB + 0.04, 4, 0.75]])
    for (const side of [-1, 1])
      for (let i = 0; i < n; i++) {
        const age = since(t, at + i * 0.016), life = 0.22 + 0.12 * rand(i, side, 3);
        if (age >= life) continue;
        const u = age / life, ang = -Math.PI / 2 + side * (0.5 + 0.2 * rand(i, side, 5)), sp = (80 + 30 * rand(i, side, 7)) * power;
        const x = side * HW + Math.cos(ang) * travel(sp, 0, 7, age), y = Math.sin(ang) * travel(sp, 0, 7, age) - 8 * age;
        const rad = (1 + 2.6 * Math.sqrt(u)) * (0.8 + 0.4 * rand(i, side, 9)), k = Math.min(1, u * 12) * Math.pow(1 - u, 2);
        p.disc(x, y, rad, steam, 0.6 * k);
        p.disc(x - rad * 0.2, y - rad * 0.25, rad * 0.6, 0xffffffff, 0.45 * k);
      }
  // rayas de coraje que destellan alrededor de la cabeza en cada latido
  for (const [at, n, len] of [[LUB, 8, 6], [DUB, 6, 4]]) {
    const age = since(t, at);
    if (age > 0.2) continue;
    const k = age / 0.2;
    for (let i = 0; i < n; i++) {
      const ang = -Math.PI / 2 + ((i + 0.5) / n - 0.5) * 4.0, r0 = 10 + 5 * k, ca = Math.cos(ang), sa = Math.sin(ang);
      const pts = [];
      for (let j = 0; j <= 3; j++) {
        const r = r0 + (j / 3) * len, off = j % 2 ? 1.3 : -0.4;
        pts.push([ca * r - sa * off, CY + sa * r + ca * off]);
      }
      p.polyline(pts, (u) => (u > 0.66 ? C[7] : u > 0.33 ? C[5] : C[4]), 1.2 - k);
    }
  }
  // el latido enciende una luz roja alrededor de la cabeza
  p.glow(0, CY, 16, C[4], 0.08 + 0.3 * b);
}
