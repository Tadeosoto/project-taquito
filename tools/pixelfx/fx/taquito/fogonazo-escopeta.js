// Recortado de projectiles/muzzle-shotgun para La Tinaquera de Guadalajaja: el abanico de fuego,
// los perdigones, las chispas y una bocanada corta de humo, sin cartucho (el juego avienta uno de
// fisica, Casquillo.gd) ni luz en el piso. El origen es la boca misma (no el piso): en el juego la
// hoja sale en Player.canon() (Pistola._fogonazo_tiro, lugar "fogonazo_escopeta" de EfectosPixel).
// The flash lobes, spark and smoke recipes are adapted from Sprite Fusion's open-source
// muzzle-flash (https://www.spritefusion.com/pixel-art-vfx/muzzle-flash), MIT License, Copyright (c) 2026 Hugo Duprez.
import { Particles, P, Rng, fit, mix, WHITE } from "../../core/index.js";
import { flash, cloud, Smoke } from "../projectiles/_lib.js";

export const meta = {
  name: "Fogonazo de escopeta",
  desc: "El tiro de La Tinaquera desde la boca: abanico de fuego con centro blanco, perdigones, chispas y una bocanada de humo corta. Recortado de projectiles/muzzle-shotgun.",
  tags: ["projectile", "muzzle", "gun", "shotgun", "flash", "directional", "taquito", "one-shot"],
  size: [128, 76],
  origin: [12, 36],
  duration: 0.5,
  loop: false,
  fps: 30,
  options: {
    palette: ["#4a1712", "#8a1f17", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"],
    smoke: ["#221e2a", "#36313f", "#4e4858", "#6a6474", "#888192", "#a8a1b1", "#c8c1cf"],
    seed: 5,
  },
};

const F1 = 1 / 30;

// el abanico: una bola gorda en la boca y lenguas desgarradas a lo ancho, cada una de su largo
function fan(R, f) {
  const k = f === 1 ? 1 : f === 2 ? 0.82 : 0.55, w = f === 1 ? 1 : 1.25;
  const L = [{ off: 0.5, a: 0, len: 11 * k, wid: 3.6 * w, core: 0.5 }];
  for (let i = 0; i < 9; i++) {
    const u = i / 8 - 0.5, a = u * 1.15 + R[i * 3] * 0.12, len = (17 + 11 * (1 - Math.abs(u) * 1.4) + R[i * 3 + 1] * 7) * k;
    L.push({ off: 2, a, len, wid: (1.7 + R[i * 3 + 2]) * w, core: f === 1 ? 0.32 : 0 });
  }
  if (f === 1) for (const s of [-1, 1]) L.push({ off: 1, a: s * (1.6 + R[27 + (s > 0)] * 0.4), len: 5 + R[29] * 3, wid: 1.2, core: 0 });
  return L;
}

export function create(o) {
  const F = fit(o.palette, 9), SM = fit(o.smoke, 7), R = new Rng(o.seed);
  // sin piso: las chispas caen y se apagan antes de salirse
  const ps = new Particles({ rng: R, ground: () => 1e6, sparks: [F[7], F[6], F[4], F[3]] }), smoke = new Smoke(R);
  const right = meta.size[0] - meta.origin[0] - 2, jit = Array.from({ length: 32 }, () => R.next());
  const pellets = Array.from({ length: 10 }, () => ({ a: R.range(-0.13, 0.13), v: R.range(900, 1150), d0: R.range(0, 4) }));
  for (let i = 0; i < 14; i++) {
    const a = R.range(-0.5, 0.5), sp = R.range(180, 420);
    ps.spawn(P.SPARK, 4, 0, Math.cos(a) * sp, Math.sin(a) * sp - 20, R.range(0.06, 0.22));
  }
  for (let i = 0; i < 4; i++) {
    const a = R.range(-0.4, 0.2), sp = R.range(60, 150);
    ps.spawn(P.EMBER, 4, 0, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.2, 0.35), F[5]);
  }
  // la bocanada: un empujon de gas al frente que se frena, se hincha tantito y se va
  for (let i = 0; i < 18; i++) {
    const a = R.range(-0.45, 0.35), sp = R.range(70, 230);
    smoke.add({ x: 4 + R.range(0, 5), y: R.range(-2, 2), vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, r0: R.range(2.5, 3.5), r1: R.range(7, 11), life: R.range(0.36, 0.48), a: R.range(0.62, 0.78), b: R.range(0.92, 1), drag: R.range(4.5, 6), rise: R.range(10, 18), grow: R.range(4, 6), warm: 1, delay: R.range(0, 0.03) });
  }
  let t = 0;
  return {
    update(dt) {
      t += dt;
      ps.update(dt);
      smoke.update(dt);
    },
    draw(p) {
      const pop = Math.exp(-(t + 0.008) / 0.05), list = smoke.puffs();
      for (const q of list) q.w *= 0.25 + pop * 1.2;
      cloud(p, list, SM, [SM[0], mix(F[1], SM[1], 0.5), mix(F[2], SM[2], 0.4), F[3], F[4], F[5], F[7]], { dens: 1.3, max: 0.8, lit: 1.4 });
      // el fogonazo: un cuadro blanco, luego el abanico enfriandose y abriendose
      if (t < 3 * F1) {
        const f = t < F1 ? 1 : t < 2 * F1 ? 2 : 3;
        flash(p, 0, 0, 0, fan(jit, f), f === 1 ? [WHITE, F[7], F[6], F[3]] : f === 2 ? [F[7], F[6], F[4], F[2]] : [F[5], F[4], F[3], F[1]], f + 9);
      }
      // los perdigones: cabezas calientes con colas que se enfrian, cortadas en la orilla
      if (t < 0.2)
        for (const q of pellets) {
          const head = 6 + q.d0 + q.v * t, tail = Math.max(4, head - 26), ca = Math.cos(q.a), sa = Math.sin(q.a);
          for (let d = tail; d <= head; d += 0.5) {
            const x = ca * d;
            if (x > right) break;
            const u = (d - tail) / Math.max(1, head - tail);
            p.dot(x, sa * d, u > 0.85 ? WHITE : u > 0.5 ? F[6] : F[4], u > 0.3 ? 1 : u / 0.3);
          }
          if (ca * head < right) p.glow(ca * head, sa * head, 4, F[6], 0.5);
        }
      ps.draw(p);
      p.glow(8, 0, 30, F[4], 0.8 * pop);
      p.glow(4, 0, 10, WHITE, 0.55 * pop);
    },
  };
}
