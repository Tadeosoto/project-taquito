// Recortado de water/drip para el arma de golpe de Guadalajaja: solo la gota que se hincha en la
// punta del machete, se suelta y cae estirada, sin piedra, sin charco y sin plic (el arma y el
// suelo son 3D). El origen es la punta; Player la cuelga de ahi un rato tras cada golpe.
// The bead swelling at the tip and the falling drop's tail follow Sprite Fusion's open-source blood
// (https://www.spritefusion.com/pixel-art-vfx/blood), MIT License, Copyright (c) 2026 Hugo Duprez.
import { fit, smooth, ease, WHITE } from "../../core/index.js";
import { bead } from "../water/_lib.js";

export const meta = {
  name: "Gota del arma",
  desc: "Una gota de sangre que se hincha en la punta del arma, se suelta y cae estirada, una y otra vez. Recortado de water/drip.",
  tags: ["blood", "drip", "drop", "weapon", "taquito", "loop"],
  size: [24, 64],
  origin: [12, 6],
  duration: 0.9,
  loop: true,
  fps: 30,
  bg: "dark",
  options: { palette: ["#3a0404", "#5a0606", "#7a0a0a", "#a00e12", "#c0141a", "#ff2a2a", "#ff8080", "#ffffff"], fall: 50, seed: 1 },
};

const D = meta.duration, G = 760, LET = 0.55;

export function draw(p, t, o) {
  const C = fit(o.palette, 8), FALL = o.fall;
  // the bead swells at the tip, wobbling, and catches the light; its neck stretches before it lets go
  if (t < LET) {
    const k = t / LET, r = 0.6 + 1.9 * ease.inQuad(k), wob = 0.15 * Math.sin(t * 26) * k, neck = smooth(0.82, 1, k) * 2;
    const cy = r + neck;
    if (neck > 0.2) p.line(0, 0, 0, cy - r, C[5]);
    p.ellipse(0, cy, r * (1 - wob), r * (1 + wob) + 0.3 * k, (d, a) => (d > 0.72 ? (Math.cos(a) < 0 && Math.sin(a) < 0.3 ? C[5] : C[3]) : d < 0.35 && Math.cos(a) > 0 ? C[6] : C[4]));
    if (r > 1) p.px(-r * 0.4, cy - r * 0.45, WHITE);
    p.glow(0, cy, 3 + r * 2, C[5], 0.12 + 0.12 * k);
  } else {
    // a little of it springs back up the tip after it lets go
    const s = (t - LET) / 0.12;
    if (s < 1) p.ellipse(0, 0.8, 1 * (1 - s * 0.6), 0.8 + Math.sin(s * Math.PI) * 0.6, C[4]);
  }
  // the fall, stretched by its speed, gone before it would reach the (3D) floor
  const f = t - LET;
  if (f > 0) {
    const y = 3 + 0.5 * G * f * f, vy = G * f;
    if (y < FALL) bead(p, 0, y, 0, vy, 2, C, Math.min(1, (FALL - y) / 12));
  }
}
