// Un solo tiro de projectiles/muzzle-smg para La Matraca y La Chicharra de Guadalajaja: el
// fogonazo de picos con el centro blanco (dos cuadros) y unas chispas, sin humo ni casquillos (el
// juego avienta casquillos de fisica, Casquillo.gd). Corto, porque sale en cada tiro de la rafaga.
// El origen es la boca (Pistola._fogonazo_tiro, lugar "fogonazo_auto" de EfectosPixel).
// The flash lobes and spark recipes are adapted from Sprite Fusion's open-source muzzle-flash
// (https://www.spritefusion.com/pixel-art-vfx/muzzle-flash), MIT License, Copyright (c) 2026 Hugo Duprez.
import { rng, fit, fly, flyV, WHITE } from "../../core/index.js";
import { flashShape, flash, spark } from "../projectiles/_lib.js";

export const meta = {
  name: "Fogonazo automatico",
  desc: "Un tiro de rafaga desde la boca: un fogonazo de picos con el centro blanco que dura dos cuadros y unas chispas que salen al frente. Recortado de projectiles/muzzle-smg.",
  tags: ["projectile", "muzzle", "gun", "automatic", "flash", "directional", "taquito", "one-shot"],
  size: [64, 40],
  origin: [10, 20],
  duration: 0.2,
  loop: false,
  fps: 30,
  options: {
    palette: ["#4a1712", "#8a1f17", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"],
    seed: 6,
  },
};

const F1 = 1 / 30;

export function draw(p, t, o) {
  const F = fit(o.palette, 9), S = o.seed, SP = [F[7], F[6], F[4], F[3]];
  if (t < 2 * F1) {
    const r = rng(S, 1), f = t < F1 ? 1 : 2;
    const L = flashShape(r, f, { size: 1.05, spike: [12, 21], diag: [6, 11], cross: [4, 7.5], back: [2.5, 5] });
    flash(p, 0, 0, r.range(-0.06, 0.06), L, f === 1 ? [WHITE, F[7], F[6], F[3]] : [F[7], F[6], F[4], F[2]], 7 + f);
  }
  for (let j = 0; j < 5; j++) {
    const r = rng(S, j, 11), life = r.range(0.05, 0.14) * (j > 2 ? 1.3 : 1);
    if (t >= life) continue;
    const a = r.range(-0.3, 0.3), sp = r.range(170, 360) * (j > 2 ? 0.5 : 1);
    const [x, y] = fly(2, 0, Math.cos(a) * sp, Math.sin(a) * sp, t, 420, 2.2);
    const [vx, vy] = flyV(Math.cos(a) * sp, Math.sin(a) * sp, t, 420, 2.2);
    if (j > 2) p.px(x, y, t / life < 0.5 ? F[6] : F[4]);
    else spark(p, x, y, vx, vy, 1 - t / life, SP, 0.45, 0.011);
  }
  const pop = Math.exp(-(t + 0.008) / 0.035);
  p.glow(4, 0, 18, F[4], 0.7 * pop);
  p.glow(2, 0, 6, WHITE, 0.5 * pop);
}
