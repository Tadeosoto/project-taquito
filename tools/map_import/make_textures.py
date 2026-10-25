"""Genera las texturas PS1 de fachadas y azoteas del mapa con ImageMagick.

Cada mosaico mide TILE px y equivale a 2.5 x 2.5 m (un piso de OSM2World).
- textures/map/fachadas.png: 4 columnas x 2 filas. Fila 0 = pisos de arriba,
  fila 1 = planta baja. ps1_facade.gdshader elige un mosaico al azar por tramo.
- textures/map/fachadas_mascara.png: blanco = pared (se pinta del color de la
  casa), negro = ventana/puerta/cortina (se queda con su color).
- textures/map/azoteas.png: 2 mosaicos, impermeabilizante rojo y losa gris.

Son dibujos propios (sin licencia de terceros); se pueden reemplazar por fotos
recortadas al mismo acomodo. Uso: python3 -I tools/map_import/make_textures.py
"""

import os
import subprocess

TILE = 64
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "textures", "map")

FRAME = "#cfc9be"
GLASS = "#2c3a48"
IRON = "#151515"
SILL = "#b3ab9e"


def window(x0, y0, x1, y1, bars=5):
	"""Ventana con marco, vidrio y proteccion de herreria."""
	shapes = [(FRAME, x0 - 3, y0 - 3, x1 + 3, y1 + 3), (GLASS, x0, y0, x1, y1)]
	step = max(3, (x1 - x0) // bars)
	for x in range(x0 + step // 2, x1, step):
		shapes.append((IRON, x, y0, x, y1))
	shapes.append((IRON, x0, (y0 + y1) // 2, x1, (y0 + y1) // 2))
	shapes.append((SILL, x0 - 4, y1 + 3, x1 + 4, y1 + 5))
	return shapes


def striped(x0, y0, x1, y1, base, stripe, step, vertical=False):
	shapes = [(base, x0, y0, x1, y1)]
	if vertical:
		shapes += [(stripe, x, y0, x, y1) for x in range(x0 + step, x1, step)]
	else:
		shapes += [(stripe, x0, y, x1, y) for y in range(y0 + step, y1, step)]
	return shapes


# (columna, fila) -> lista de (color, x0, y0, x1, y1) en coordenadas del mosaico
TILES = {
	# Pisos de arriba
	(0, 0): window(17, 15, 46, 39),
	(1, 0): window(8, 17, 26, 36, bars=3) + window(37, 17, 55, 36, bars=3),
	(2, 0): [(FRAME, 15, 7, 48, 46), (GLASS, 18, 10, 45, 46)]
		+ striped(11, 33, 52, 46, "#00000000", IRON, 4, vertical=True)
		+ [(IRON, 11, 33, 52, 34), (SILL, 9, 46, 54, 49)],
	(3, 0): window(37, 13, 51, 23, bars=2),
	# Planta baja
	(0, 1): [(FRAME, 19, 15, 44, 63), ("#5a3a22", 22, 18, 41, 63), ("#3e2716", 25, 22, 38, 38),
		("#d9b44a", 38, 40, 39, 41)],
	(1, 1): [("#e0b030", 3, 3, 60, 11), ("#55585b", 4, 12, 59, 17)]
		+ striped(6, 17, 57, 63, "#8a8d90", "#6c6f72", 3),
	(2, 1): window(17, 18, 46, 42),
	(3, 1): [("#2a2d31", 3, 12, 60, 15)] + striped(4, 15, 59, 63, "#3b3f45", "#2a2d31", 4, vertical=True),
}

ROOF_TILES = [
	("#a5432f", "#8e3826"),  # impermeabilizante rojo
	("#9a9a96", "#7f7f7b"),  # losa de concreto
]


def magick(*args) -> None:
	subprocess.run(["magick", *args], check=True)


def draw_args(shapes, ox, oy, color_override=None):
	args = []
	for color, x0, y0, x1, y1 in shapes:
		fill = color_override if color_override else color
		if color_override and color == "#00000000":
			continue
		if x0 == x1 or y0 == y1:
			args += ["-stroke", fill, "-draw", f"line {ox + x0},{oy + y0} {ox + x1},{oy + y1}", "-stroke", "none"]
		else:
			args += ["-fill", fill, "-draw", f"rectangle {ox + x0},{oy + y0} {ox + x1},{oy + y1}"]
	return args


def main() -> None:
	os.makedirs(OUT_DIR, exist_ok=True)
	width, height = TILE * 4, TILE * 2

	# Color: aplanado claro con un poco de ruido, mas sucio abajo en planta baja
	color_args = ["-size", f"{width}x{height}", "xc:#e8e4dc", "-seed", "7",
		"-attenuate", "0.25", "+noise", "Uniform", "-colorspace", "sRGB",
		"-fill", "#c9c1b2", "-draw", f"rectangle 0,{height - 5} {width},{height}"]
	mask_args = ["-size", f"{width}x{height}", "xc:white"]
	for (col, row), shapes in TILES.items():
		color_args += draw_args(shapes, col * TILE, row * TILE)
		mask_args += draw_args(shapes, col * TILE, row * TILE, color_override="black")
	magick(*color_args, "-type", "TrueColor", "-depth", "8", os.path.join(OUT_DIR, "fachadas.png"))
	magick(*mask_args, "-type", "Grayscale", "-depth", "8", os.path.join(OUT_DIR, "fachadas_mascara.png"))

	# Azoteas: base con ruido y juntas cada 16 px
	roof_args = ["-size", f"{TILE * len(ROOF_TILES)}x{TILE}", "xc:black"]
	for i, (base, seam) in enumerate(ROOF_TILES):
		ox = i * TILE
		roof_args += ["-fill", base, "-draw", f"rectangle {ox},0 {ox + TILE - 1},{TILE - 1}"]
		for k in range(0, TILE, 16):
			roof_args += ["-stroke", seam, "-draw", f"line {ox + k},0 {ox + k},{TILE - 1}",
				"-draw", f"line {ox},{k} {ox + TILE - 1},{k}", "-stroke", "none"]
	roof_args += ["-seed", "3", "-attenuate", "0.2", "+noise", "Uniform", "-colorspace", "sRGB", "-type", "TrueColor", "-depth", "8"]
	magick(*roof_args, os.path.join(OUT_DIR, "azoteas.png"))

	print(f"OK: texturas en {OUT_DIR}")


if __name__ == "__main__":
	main()
