"""Genera las texturas PS1 de fachadas y azoteas del mapa con ImageMagick.

Cada mosaico mide TILE px y equivale a 2.5 x 2.5 m (un piso de OSM2World).
- textures/map/fachadas.png: 4 columnas x 2 filas. Fila 0 = pisos de arriba,
  fila 1 = planta baja. ps1_facade.gdshader elige un mosaico al azar por tramo.
- textures/map/fachadas_mascara.png: blanco = pared (se pinta del color de la
  casa), negro = ventana/puerta/cortina (se queda con su color).
- textures/map/azoteas.png: 2 mosaicos, impermeabilizante rojo y losa gris.
- textures/map/suelo.png: pasto verde oscuro para el piso entre casas (shaders/ps1_suelo y el
  terreno de OSM2World) y textures/map/banqueta.png (MapPostImport.GROUND_TEXTURES).
- textures/map/pasto.png y pasto_seco.png (ps1_suelo los mezcla donde la mascara
  satelital dice pasto), asfalto.png y empedrado.png (calles).
- textures/map/mata_pasto.png: una mata con transparencia (MapPasto.gd) y
  textures/map/arbol.png: corteza a la izquierda, hojas a la derecha (MapArboles.gd).

Dos estilos:
- dibujado (default): todo son dibujos propios, sin licencia de terceros.
- fotos: el aplanado, la puerta, las cortinas y las azoteas salen de texturas
  CC0 de Poly Haven (FOTOS, se bajan a tools/map_import/bin/texturas_cc0/);
  las ventanas con herreria se siguen dibujando encima.

Uso: python3 -I tools/map_import/make_textures.py [--estilo fotos]
Despues: borrar .godot/imported/zona_mapa.glb-*, reimportar y correr
split_cuadros.gd (los materiales de los cuadros copian estas texturas).
"""

import argparse
import json
import os
import random
import subprocess
import urllib.request

TILE = 64
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "textures", "map")
CC0_DIR = os.path.join(ROOT, "tools", "map_import", "bin", "texturas_cc0")

# Texturas CC0 de https://polyhaven.com para el estilo "fotos"
FOTOS = {
	"aplanado": "white_stucco",
	"puerta": "rough_pine_door",
	"cortina": "painted_metal_shutter",
	"zaguan": "worn_shutter",
	"impermeabilizante": "red_plaster_weathered",
	"losa": "painted_plaster_wall",
	"banqueta": "dirty_concrete",
	"pasto": "leafy_grass",
	"pasto_seco": "withered_grass",
	"asfalto": "asphalt_02",
	"empedrado": "cobblestone_floor_05",
}

# Lado (px) de textures/map/suelo.png; el shader ps1_suelo la repite cada 3 m
SUELO_PX = 128

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

# En el estilo fotos, ("foto:<clave de FOTOS>", x0, y0, x1, y1) pega un recorte de la foto
TILES_FOTOS = dict(TILES)
TILES_FOTOS[(0, 1)] = [(FRAME, 19, 15, 44, 63), ("foto:puerta", 22, 18, 41, 63), ("#d9b44a", 38, 40, 39, 41)]
TILES_FOTOS[(1, 1)] = [("#e0b030", 3, 3, 60, 11), ("#55585b", 4, 12, 59, 17), ("foto:cortina", 6, 17, 57, 63)]
TILES_FOTOS[(3, 1)] = [("#2a2d31", 3, 12, 60, 15), ("foto:zaguan", 4, 15, 59, 63)]

ROOF_TILES = [
	("#a5432f", "#8e3826"),  # impermeabilizante rojo
	("#9a9a96", "#7f7f7b"),  # losa de concreto
]


def magick(*args) -> None:
	subprocess.run(["magick", *args], check=True)


def foto_path(key: str) -> str:
	"""Baja (una vez) el color 1k de una textura de Poly Haven."""
	asset = FOTOS[key]
	path = os.path.join(CC0_DIR, f"{asset}.jpg")
	if not os.path.exists(path):
		os.makedirs(CC0_DIR, exist_ok=True)
		request = urllib.request.Request(f"https://api.polyhaven.com/files/{asset}",
			headers={"User-Agent": "taquito-map-import/1.0"})
		with urllib.request.urlopen(request, timeout=60) as response:
			url = json.load(response)["Diffuse"]["1k"]["jpg"]["url"]
		print(f"  bajando {asset}...")
		urllib.request.urlretrieve(url, path)
	return path


def foto_tile(key: str, size: int) -> str:
	"""La foto completa achicada: las de Poly Haven se repiten sin costura, un recorte no."""
	out = os.path.join(CC0_DIR, f"_{key}_{size}.png")
	magick(foto_path(key), "-resize", f"{size}x{size}!", "-type", "TrueColor", out)
	return out


def foto_crop(key: str, width: int, height: int) -> str:
	"""Recorte de la foto ya al tamano del hueco (pixel art: sin suavizar de mas)."""
	out = os.path.join(CC0_DIR, f"_{key}_{width}x{height}.png")
	magick(foto_path(key), "-gravity", "center", "-crop", "70%x70%+0+0", "+repage",
		"-resize", f"{width}x{height}!", "-type", "TrueColor", out)
	return out


def draw_args(shapes, ox, oy, color_override=None):
	args = []
	for color, x0, y0, x1, y1 in shapes:
		fill = color_override if color_override else color
		if color_override and color == "#00000000":
			continue
		if color.startswith("foto:"):
			if color_override:
				args += ["-fill", fill, "-draw", f"rectangle {ox + x0},{oy + y0} {ox + x1},{oy + y1}"]
			else:
				crop = foto_crop(color[5:], x1 - x0 + 1, y1 - y0 + 1)
				args += ["-draw", f"image over {ox + x0},{oy + y0} 0,0 '{crop}'"]
			continue
		if x0 == x1 or y0 == y1:
			args += ["-stroke", fill, "-draw", f"line {ox + x0},{oy + y0} {ox + x1},{oy + y1}", "-stroke", "none"]
		else:
			args += ["-fill", fill, "-draw", f"rectangle {ox + x0},{oy + y0} {ox + x1},{oy + y1}"]
	return args


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--estilo", choices=["dibujado", "fotos"], default="dibujado")
	estilo = parser.parse_args().estilo
	os.makedirs(OUT_DIR, exist_ok=True)
	width, height = TILE * 4, TILE * 2

	if estilo == "fotos":
		# Aplanado de foto en gris claro: el shader lo pinta del color de la casa
		tiles = TILES_FOTOS
		base = ["(", foto_path("aplanado"), "-resize", f"{TILE * 2}x{TILE * 2}!", "-colorspace", "gray",
			"-auto-level", "+level", "72%,100%", "-colorspace", "sRGB", "-write", "mpr:aplanado", "+delete", ")",
			"-size", f"{width}x{height}", "tile:mpr:aplanado"]
	else:
		# Aplanado claro con un poco de ruido
		tiles = TILES
		base = ["-size", f"{width}x{height}", "xc:#e8e4dc", "-seed", "7",
			"-attenuate", "0.25", "+noise", "Uniform", "-colorspace", "sRGB"]
	# Mas sucio abajo en planta baja
	color_args = base + ["-fill", "#c9c1b2", "-draw", f"rectangle 0,{height - 5} {width},{height}"]
	mask_args = ["-size", f"{width}x{height}", "xc:white"]
	for (col, row), shapes in tiles.items():
		color_args += draw_args(shapes, col * TILE, row * TILE)
		mask_args += draw_args(shapes, col * TILE, row * TILE, color_override="black")
	magick(*color_args, "-type", "TrueColor", "-depth", "8", os.path.join(OUT_DIR, "fachadas.png"))
	magick(*mask_args, "-type", "Grayscale", "-depth", "8", os.path.join(OUT_DIR, "fachadas_mascara.png"))

	roof_path = os.path.join(OUT_DIR, "azoteas.png")
	if estilo == "fotos":
		# Impermeabilizante rojo y losa: recortes de foto lado a lado
		magick(foto_tile("impermeabilizante", TILE), foto_tile("losa", TILE), "+append",
			"-type", "TrueColor", "-depth", "8", roof_path)
	else:
		# Azoteas: base con ruido y juntas cada 16 px
		roof_args = ["-size", f"{TILE * len(ROOF_TILES)}x{TILE}", "xc:black"]
		for i, (base_color, seam) in enumerate(ROOF_TILES):
			ox = i * TILE
			roof_args += ["-fill", base_color, "-draw", f"rectangle {ox},0 {ox + TILE - 1},{TILE - 1}"]
			for k in range(0, TILE, 16):
				roof_args += ["-stroke", seam, "-draw", f"line {ox + k},0 {ox + k},{TILE - 1}",
					"-draw", f"line {ox},{k} {ox + TILE - 1},{k}", "-stroke", "none"]
		roof_args += ["-seed", "3", "-attenuate", "0.2", "+noise", "Uniform", "-colorspace", "sRGB", "-type", "TrueColor", "-depth", "8"]
		magick(*roof_args, roof_path)

	suelo_path = os.path.join(OUT_DIR, "suelo.png")
	banqueta_path = os.path.join(OUT_DIR, "banqueta.png")
	if estilo == "fotos":
		# Piso base: pasto verde oscuro (la zona no es desierto); el pasto del satelite va encima mas claro
		magick(foto_tile("pasto", SUELO_PX), *verde("#1c2e16", "#4f7038"), "-depth", "8", suelo_path)
		magick(foto_tile("banqueta", SUELO_PX), "-depth", "8", banqueta_path)
	else:
		# Piso base: verde oscuro con ruido y unas piedritas
		magick("-size", f"{SUELO_PX}x{SUELO_PX}", "xc:#34502a", "-seed", "11", "-attenuate", "0.6",
			"+noise", "Uniform", "-colorspace", "sRGB", "-fill", "#6a6a52", "-draw", "point 20,30",
			"-draw", "point 90,70", "-draw", "point 50,110", "-type", "TrueColor", "-depth", "8", suelo_path)
		# Banqueta: concreto gris con juntas
		magick("-size", f"{SUELO_PX}x{SUELO_PX}", "xc:#a9a59c", "-seed", "5", "-attenuate", "0.3",
			"+noise", "Uniform", "-colorspace", "sRGB", "-stroke", "#8a867e",
			"-draw", f"line 0,0 {SUELO_PX},0", "-draw", f"line 0,0 0,{SUELO_PX}",
			"-type", "TrueColor", "-depth", "8", banqueta_path)

	pisos = {
		# nombre: (color base, color del ruido, intensidad del ruido)
		"pasto": ("#5f7a3a", "#3f5a28", 0.5),
		"pasto_seco": ("#9a8a52", "#7a6a3e", 0.5),
		"asfalto": ("#4a4a4c", "#2e2e30", 0.35),
		"empedrado": ("#8a7e70", "#5e554a", 0.4),
	}
	for nombre, (color, oscuro, ruido) in pisos.items():
		path = os.path.join(OUT_DIR, f"{nombre}.png")
		if estilo == "fotos":
			# Las fotos de pasto salen cafes: se pasan a gris y se pintan de verde
			ajuste = {"pasto": verde("#2f4a22", "#86ad5c"), "pasto_seco": verde("#4a5228", "#a8ac68")}.get(nombre, [])
			magick(foto_tile(nombre, SUELO_PX), *ajuste, "-depth", "8", path)
		else:
			magick("-size", f"{SUELO_PX}x{SUELO_PX}", f"xc:{color}", "-seed", str(len(nombre)), "-attenuate", str(ruido),
				"+noise", "Uniform", "-colorspace", "sRGB", "-fill", oscuro, "-draw", "point 30,40",
				"-type", "TrueColor", "-depth", "8", path)
	mata_pasto(os.path.join(OUT_DIR, "mata_pasto.png"))
	arbol(os.path.join(OUT_DIR, "arbol.png"))

	print(f"OK: texturas ({estilo}) en {OUT_DIR}")


def verde(oscuro: str, claro: str) -> list:
	"""Argumentos de magick que pasan una foto a gris y la pintan entre dos colores."""
	return ["-colorspace", "gray", "-auto-level", "-colorspace", "sRGB", "+level-colors", f"{oscuro},{claro}"]


def mata_pasto(path: str) -> None:
	"""Hojas de pasto en abanico sobre fondo transparente (32 x 32, pixel art)."""
	rng = random.Random(4)
	args = ["-size", "32x32", "xc:none", "-strokewidth", "1"]
	verdes = ["#4f6e2c", "#6b8a3a", "#829c48", "#a39a58", "#3d5a24"]
	for _ in range(22):
		x0 = rng.uniform(9, 23)
		x1 = x0 + rng.uniform(-9, 9)
		y1 = rng.uniform(2, 14)
		args += ["-stroke", rng.choice(verdes), "-draw", f"line {x0:.0f},31 {x1:.0f},{y1:.0f}"]
	magick(*args, "-type", "TrueColorAlpha", "-depth", "8", path)


def arbol(path: str) -> None:
	"""Atlas de 128 x 64: corteza (izquierda) y hojas (derecha). Las hojas van en gris
	verdoso claro porque ps1_arbol las multiplica por el verde de cada arbol."""
	args = ["-size", "64x64", "xc:#6a5442", "-seed", "21", "-attenuate", "0.5", "+noise", "Uniform",
		"-colorspace", "sRGB", "-stroke", "#4a3a2e"]
	for x in range(3, 64, 9):
		args += ["-draw", f"line {x},0 {x + 2},63"]
	# Hojas: ruido gris con manchas oscuras (huecos entre hojas), luego a verde grisaceo
	args += ["(", "-size", "64x64", "xc:gray50", "-seed", "22", "+noise", "Random", "-level", "-20%,110%",
		"-colorspace", "gray", "-fill", "gray35"]
	rng = random.Random(9)
	for _ in range(30):
		x, y = rng.randrange(64), rng.randrange(64)
		args += ["-draw", f"circle {x},{y} {x + rng.randint(1, 2)},{y}"]
	args += ["-colorspace", "sRGB", "+level-colors", "#4a5a3e,#e8f0d8", ")", "+append"]
	magick(*args, "-type", "TrueColor", "-depth", "8", path)


if __name__ == "__main__":
	main()
