// El chorro de water/water-jet puesto de pie, para el cuello de un zombi al que le volaron la
// cabeza de un balazo (Zombie._sin_cabeza). Solo cambia el lienzo (alto en vez de ancho), el
// origen (abajo, en el cuello) y el giro; el dibujo es el de water-jet.
import { draw as jet } from "../water/water-jet.js";
import { WATER } from "../water/_lib.js";

export const meta = {
  name: "Fuente del cuello",
  desc: "Un chorro de agua sucia que sale para arriba y se dobla tantito, rompiéndose en gotas. water/water-jet de pie.",
  tags: ["water", "jet", "fountain", "taquito", "loop"],
  size: [80, 132],
  origin: [30, 126],
  duration: 1,
  loop: true,
  fps: 30,
  bg: "dark",
  options: { palette: WATER, length: 70, seed: 3 },
};

// Gira el pintor un cuarto de vuelta (para arriba) encima del giro que ya traiga, y lo deja como estaba
export function draw(p, t, o) {
  const cs = p.cs, sn = p.sn;
  p.cs = sn;
  p.sn = -cs;
  jet(p, t, o);
  p.cs = cs;
  p.sn = sn;
}
