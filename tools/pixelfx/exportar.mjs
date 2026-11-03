// Hace las hojas de efectos de efectos.json con pixelfx y las copia a resources/fx/.
//   node tools/pixelfx/exportar.mjs <ruta-a-pixelfx> [nombre...]
// Sin nombres hace todas. Las hojas de contacto quedan en <pixelfx>/records/taquito/<nombre>/ para revisarlas.
// Despues: godot --path . --headless --import
import { execFileSync } from "node:child_process";
import { copyFileSync, cpSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const AQUI = dirname(fileURLToPath(import.meta.url));
const PROYECTO = resolve(AQUI, "..", "..");
const DESTINO = join(PROYECTO, "resources", "fx");

const [pixelfx, ...solo] = process.argv.slice(2);
if (!pixelfx) {
  console.error("uso: node tools/pixelfx/exportar.mjs <ruta-a-pixelfx> [nombre...]");
  process.exit(1);
}
const RAIZ = resolve(pixelfx);
const { efectos } = JSON.parse(readFileSync(join(AQUI, "efectos.json"), "utf8"));
mkdirSync(DESTINO, { recursive: true });
// Los efectos propios (tools/pixelfx/fx/taquito/*.js, recortes de los de pixelfx) se copian al
// checkout para que render.mjs y check.mjs los encuentren como taquito/<nombre>
cpSync(join(AQUI, "fx"), join(RAIZ, "src", "fx"), { recursive: true });

for (const e of efectos) {
  if (solo.length && !solo.includes(e.nombre)) continue;
  const out = join(RAIZ, "records", "taquito", e.nombre);
  // `fps` opcional: menos cuadros para lo lento y grande (los rayos son de pantalla completa)
  const otroFps = e.fps ? ["--fps", String(e.fps)] : [];
  execFileSync(process.execPath, [join(RAIZ, "tools", "render.mjs"), e.id, "--sheet", "--opts", JSON.stringify(e.opts ?? {}), "--out", out, ...otroFps],
    { cwd: RAIZ, stdio: "inherit" });
  const hecho = join(out, e.id), corto = basename(e.id);
  copyFileSync(join(hecho, `${corto}.png`), join(DESTINO, `${e.nombre}.png`));
  // Solo lo que lee EfectosPixel.gd: la hoja completa trae cada cuadro y la actuacion del personaje
  const meta = JSON.parse(readFileSync(join(hecho, `${corto}.json`), "utf8")).meta.pixelfx;
  const { id, fps, loop, frames, frameSize, pivot, columns } = meta;
  // Cuando pega: el juego lanza el efecto en el golpe, asi que empieza desde ahi y la congelada
  // se queda en el cuadro bueno, no en uno vacio
  const golpe_en = meta.act?.hits?.[0]?.t ?? 0;
  writeFileSync(join(DESTINO, `${e.nombre}.json`), JSON.stringify({ id, fps, loop, frames, frameSize, pivot, columns, golpe_en }, null, 1) + "\n");
  console.log(`  -> resources/fx/${e.nombre}.png`);
}
