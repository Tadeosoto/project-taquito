// Recortado de projectiles/muzzle-pistol para la pistola de Guadalajaja: solo el casquillo (sin
// fogonazo, chispas ni humo, que el juego hace en 3D). Sale del arma, sube, gira, rebota y se
// queda tirado hasta desvanecerse. El origen es el piso bajo la boca; la boca esta `height` px
// arriba, asi que en el juego la hoja va a los pies del jugador (Pistola._soltar_casquillo).
// The casing recipe is adapted from Sprite Fusion's open-source muzzle-flash
// (https://www.spritefusion.com/pixel-art-vfx/muzzle-flash), MIT License, Copyright (c) 2026 Hugo Duprez.
import { Rng, fit } from "../../core/index.js";
import { casing, drawCasing } from "../projectiles/_lib.js";

export const meta = {
  name: "Casquillo",
  desc: "Un casquillo de pistola que sale para atras y arriba, gira, rebota un par de veces y se queda tirado hasta desvanecerse. Recortado de projectiles/muzzle-pistol.",
  tags: ["projectile", "casing", "gun", "pistol", "taquito", "one-shot"],
  size: [80, 76],
  origin: [62, 70],
  duration: 1.8,
  loop: false,
  fps: 30,
  bg: "ground",
  options: {
    brass: ["#4a2e10", "#8c5c1c", "#d9a441", "#ffe39a"],
    height: 52,
    seed: 3,
  },
};

export function create(o) {
  const B = fit(o.brass, 4), MY = -o.height, R = new Rng(o.seed);
  const shell = { vx: -R.range(25, 45), vy: -R.range(95, 130), va: R.sign() * R.range(22, 32), a0: R.range(0, 6.28) };
  let t = 0;
  return {
    update(dt) {
      t += dt;
    },
    draw(p) {
      if (t < meta.duration) drawCasing(p, casing(-7, MY - 1, shell.vx, shell.vy, shell.va, t, 850, -0.5, 0.42, shell.a0), B, Math.min(1, (meta.duration - 0.05 - t) / 0.3));
    },
  };
}
