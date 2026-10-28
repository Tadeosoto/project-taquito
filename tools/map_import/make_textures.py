"""Genera las texturas PS1 de fachadas y azoteas del mapa con ImageMagick.

Cada mosaico mide TILE px y equivale a 2.5 x 2.5 m (un piso de OSM2World).
- textures/map/fachadas.png: 4 columnas x 4 filas. Fila 0 = pisos de arriba,
  fila 1 = planta baja; filas 2 y 3 = lo mismo deteriorado (ventanas rotas o
  tapiadas, cortinas oxidadas con grafiti). ps1_facade.gdshader elige un
  mosaico al azar por tramo, y uno deteriorado segun el deterioro de la zona.
- textures/map/fachadas_mascara.png: blanco = pared (se pinta del color de la
  casa), negro = ventana/puerta/cortina (se queda con su color).
- textures/map/azoteas.png: 2 mosaicos, impermeabilizante rojo y losa gris.
- textures/map/suelo.png: pasto verde oscuro para el piso entre casas (shaders/ps1_suelo y el
  terreno de OSM2World) y textures/map/banqueta.png (MapPostImport.GROUND_TEXTURES).
- textures/map/pasto.png y pasto_seco.png (ps1_suelo los mezcla donde la mascara
  satelital dice pasto), asfalto.png y empedrado.png (calles).
- textures/map/grietas.png: grietas oscuras sobre blanco, se repite sin costura
  (shaders/ps1_deterioro.gdshaderinc: asfalto, banquetas y vidrios rotos).
- textures/map/lamina.png y lamina_techo.png: lamina acanalada clara (MapBodegas.gd
  la pinta con el color de cada bodega); una canal cada 8 px = 0.3 m.
- textures/map/mata_pasto.png: una mata con transparencia (MapPasto.gd) y
  textures/map/arbol.png: corteza a la izquierda, hojas a la derecha (MapArboles.gd).
- textures/map/barda.png: atlas de 3 bardas lisas; textures/map/grafitis/ y
  textures/map/propaganda/: catalogos de lo que se pinta encima (los dibujados
  aqui mas los que se agreguen a mano) y
  textures/map/malla.png: malla ciclonica entera y rota, con transparencia (MapBardas.gd).

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
import math
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
HOLE = "#0b0b0d"
WOOD = "#7a5a3a"
WOOD_DARK = "#5e4329"
BLOCK = "#8d8a84"
MORTAR = "#6f6c66"
RUST = "#7a4a2e"
RUST_DARK = "#4e2f1d"
SOOT = "#26221e"


def window(x0, y0, x1, y1, bars=5):
	"""Ventana con marco, vidrio y proteccion de herreria."""
	shapes = [(FRAME, x0 - 3, y0 - 3, x1 + 3, y1 + 3), (GLASS, x0, y0, x1, y1)]
	step = max(3, (x1 - x0) // bars)
	for x in range(x0 + step // 2, x1, step):
		shapes.append((IRON, x, y0, x, y1))
	shapes.append((IRON, x0, (y0 + y1) // 2, x1, (y0 + y1) // 2))
	shapes.append((SILL, x0 - 4, y1 + 3, x1 + 4, y1 + 5))
	return shapes


def broken_window(x0, y0, x1, y1):
	"""Ventana sin vidrio: hueco negro con picos de vidrio y la herreria chueca."""
	w, h = x1 - x0, y1 - y0
	return [(FRAME, x0 - 3, y0 - 3, x1 + 3, y1 + 3), (HOLE, x0, y0, x1, y1),
		(GLASS, [(x0, y0), (x0 + w // 2, y0), (x0 + w // 5, y0 + h // 3)]),
		(GLASS, [(x1, y1), (x1 - w // 3, y1), (x1, y1 - h // 2)]),
		(GLASS, [(x1, y0), (x1 - w // 6, y0), (x1, y0 + h // 4)]),
		(IRON, [(x0 + w // 4, y0), (x0 + w // 3, y1)]), (IRON, [(x0 + w // 2, y0), (x0 + w // 2 + 4, y0 + h // 2)]),
		(IRON, [(x0 + 3 * w // 4, y0), (x0 + 3 * w // 4 - 2, y1)]), (IRON, [(x0, y0 + h // 2), (x1, y0 + h // 2 - 4)]),
		(SILL, x0 - 4, y1 + 3, x1 + 4, y1 + 5)]


def boarded(x0, y0, x1, y1, inside=HOLE):
	"""Hueco tapiado con tablas chuecas y clavos."""
	shapes = [(FRAME, x0 - 3, y0 - 3, x1 + 3, y1 + 3), (inside, x0, y0, x1, y1)]
	h = (y1 - y0) // 4
	for i, (color, tilt) in enumerate(((WOOD, 3), (WOOD_DARK, -4), (WOOD, 2), (WOOD_DARK, -2))):
		ya = y0 + 2 + i * h
		shapes.append((color, [(x0 - 4, ya + tilt), (x1 + 4, ya - tilt), (x1 + 4, ya - tilt + h - 3), (x0 - 4, ya + tilt + h - 3)]))
		shapes += [(IRON, x0 - 1, ya + tilt + 2, x0, ya + tilt + 3), (IRON, x1, ya - tilt + 2, x1 + 1, ya - tilt + 3)]
	return shapes


def blocks(x0, y0, x1, y1):
	"""Hueco tapado con block gris (juntas cuatrapeadas)."""
	shapes = [(FRAME, x0 - 3, y0 - 3, x1 + 3, y1 + 3), (BLOCK, x0, y0, x1, y1)]
	for k, y in enumerate(range(y0 + 5, y1, 5)):
		shapes.append((MORTAR, x0, y, x1, y))
		for x in range(x0 + (5 if k % 2 else 0), x1, 10):
			shapes.append((MORTAR, x, y - 5, x, y))
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
	# Pisos de arriba, deteriorados
	(0, 2): [(SOOT, [(12, 14), (50, 14), (58, 0), (6, 0)])] + broken_window(17, 15, 46, 39),
	(1, 2): boarded(8, 17, 26, 36) + broken_window(37, 17, 55, 36),
	(2, 2): blocks(15, 10, 48, 46) + [(SILL, 9, 46, 54, 49)],
	(3, 2): [(SOOT, [(34, 12), (54, 12), (60, 0), (30, 0)]), (FRAME, 34, 10, 54, 26), (HOLE, 37, 13, 51, 23)],
	# Planta baja, deteriorada
	(0, 3): boarded(22, 18, 41, 62, inside="#3e2716"),
	(1, 3): [("#8a6a2a", 3, 3, 60, 11), ("#3a3532", 4, 12, 59, 17)]
		+ striped(6, 17, 57, 63, RUST, RUST_DARK, 3)
		+ [(HOLE, [(40, 63), (57, 63), (57, 50), (47, 55)]),
			("#c8326e", [(10, 30), (24, 26)]), ("#c8326e", [(24, 26), (16, 40)]), ("#c8326e", [(16, 40), (32, 36)]),
			("#2ea0c4", [(30, 44), (48, 30)]), ("#2ea0c4", [(36, 46), (52, 38)]), ("#e8e4dc", [(12, 52), (28, 48)])],
	(2, 3): broken_window(17, 18, 46, 42),
	(3, 3): [("#2a2d31", 3, 12, 60, 15)] + striped(4, 15, 59, 63, RUST_DARK, "#2a1a10", 4, vertical=True)
		+ [(HOLE, [(8, 63), (26, 63), (20, 46), (12, 50)]), ("#e8e4dc", [(34, 28), (50, 24)]), ("#e8e4dc", [(36, 34), (52, 32)])],
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
	for shape in shapes:
		if len(shape) == 2:
			# (color, [(x, y), ...]): 2 puntos = linea, mas = poligono
			color, points = shape
			fill = color_override if color_override else color
			coords = " ".join(f"{ox + x},{oy + y}" for x, y in points)
			if len(points) == 2:
				args += ["-stroke", fill, "-draw", f"line {coords}", "-stroke", "none"]
			else:
				args += ["-fill", fill, "-draw", f"polygon {coords}"]
			continue
		color, x0, y0, x1, y1 = shape
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
	width, height = TILE * 4, TILE * 4

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
	# Mas sucio abajo en planta baja (filas 1 y 3)
	color_args = base + ["-fill", "#c9c1b2", "-draw", f"rectangle 0,{TILE * 2 - 5} {width},{TILE * 2 - 1}",
		"-draw", f"rectangle 0,{TILE * 4 - 5} {width},{TILE * 4 - 1}"]
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
	grietas(os.path.join(OUT_DIR, "grietas.png"))
	lamina(os.path.join(OUT_DIR, "lamina.png"), juntas=False)
	lamina(os.path.join(OUT_DIR, "lamina_techo.png"), juntas=True)
	mata_pasto(os.path.join(OUT_DIR, "mata_pasto.png"))
	arbol(os.path.join(OUT_DIR, "arbol.png"))
	barda(os.path.join(OUT_DIR, "barda.png"))
	grafitis(os.path.join(OUT_DIR, "grafitis"))
	propaganda(os.path.join(OUT_DIR, "propaganda"))
	malla(os.path.join(OUT_DIR, "malla.png"))

	print(f"OK: texturas ({estilo}) en {OUT_DIR}")


def verde(oscuro: str, claro: str) -> list:
	"""Argumentos de magick que pasan una foto a gris y la pintan entre dos colores."""
	return ["-colorspace", "gray", "-auto-level", "-colorspace", "sRGB", "+level-colors", f"{oscuro},{claro}"]


def grietas(path: str, size: int = 128) -> None:
	"""Grietas que se ramifican, oscuras sobre blanco. Cada trazo se dibuja tambien
	corrido +-size para que la textura se repita sin costura."""
	rng = random.Random(41)
	args = ["-size", f"{size}x{size}", "xc:white", "-fill", "none"]
	for _ in range(6):
		ramas = [(rng.uniform(0, size), rng.uniform(0, size), rng.uniform(0, 2 * math.pi), 24, "#2a2a2a")]
		while ramas:
			x, y, ang, pasos, color = ramas.pop()
			for _ in range(pasos):
				ang += rng.uniform(-0.3, 0.3)
				nx, ny = x + math.cos(ang) * 3.5, y + math.sin(ang) * 3.5
				for dx in (-size, 0, size):
					for dy in (-size, 0, size):
						args += ["-stroke", color, "-draw", f"line {x + dx:.1f},{y + dy:.1f} {nx + dx:.1f},{ny + dy:.1f}"]
				x, y = nx, ny
				if pasos > 8 and rng.random() < 0.06:
					ramas.append((x, y, ang + rng.choice((-1, 1)) * rng.uniform(0.6, 1.2), pasos // 2, "#5a5a5a"))
	magick(*args, "-type", "Grayscale", "-depth", "8", path)


def lamina(path: str, juntas: bool, size: int = 64) -> None:
	"""Lamina acanalada vertical, clara para pintarla de color. Con `juntas`, el
	traslape de las hojas cada media textura (techo)."""
	args = ["-size", f"{size}x{size}", "xc:#d8d8d4"]
	for x in range(0, size, 8):
		args += ["-fill", "#b8b8b2", "-draw", f"rectangle {x},0 {x + 2},{size - 1}",
			"-fill", "#ecece8", "-draw", f"rectangle {x + 4},0 {x + 5},{size - 1}"]
	if juntas:
		args += ["-stroke", "#8e8e88", "-draw", f"line 0,{size // 2} {size - 1},{size // 2}", "-stroke", "none"]
	args += ["-seed", "13", "-attenuate", "0.15", "+noise", "Uniform", "-colorspace", "sRGB"]
	magick(*args, "-type", "TrueColor", "-depth", "8", path)


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


GRAFITI = ["#d03a8c", "#2f9a4a", "#2a5cc4", "#e0a020", "#c8322a", "#7a3ac0", "#18a0a8"]


def grafiti(rng, ox, oy) -> list:
	"""Argumentos de magick para un grafiti en el mosaico (ox, oy): letras gordas
	con contorno (throw-up) y firmas (tags), con escurrimientos."""
	args = []
	relleno, sombra = rng.sample(GRAFITI, 2)
	borde = rng.choice(["#111111", "#f2f2f2"])
	x, y = ox + rng.randint(2, 6), oy + rng.randint(14, 22)
	while x < ox + 50:
		w, h = rng.randint(11, 15), rng.randint(20, 28)
		args += ["-fill", sombra, "-stroke", "none", "-draw", f"roundrectangle {x + 3},{y + 3} {x + w + 3},{y + h + 3} 5,5",
			"-fill", relleno, "-stroke", borde, "-strokewidth", "2", "-draw", f"roundrectangle {x},{y} {x + w},{y + h} 5,5",
			"-stroke", borde, "-strokewidth", "1", "-draw", f"line {x + w // 2},{y + 5} {x + w // 2},{y + h - 6}"]
		if rng.random() < 0.6:
			dx = x + rng.randint(3, w - 3)
			args += ["-stroke", relleno, "-draw", f"line {dx},{y + h + 1} {dx},{min(oy + 60, y + h + rng.randint(4, 12))}"]
		x += w - 1
		y = max(oy + 6, min(oy + 30, y + rng.randint(-4, 4)))
	args += ["-stroke", "none", "-strokewidth", "1"]
	for _ in range(rng.randint(2, 4)):
		# Firma: un garabato de trazos cortos
		color = rng.choice(["#111111", "#111111", rng.choice(GRAFITI)])
		x, y = ox + rng.uniform(2, 30), oy + rng.uniform(6, 56)
		args += ["-stroke", color, "-fill", "none"]
		for _ in range(rng.randint(7, 12)):
			nx, ny = min(ox + 62, x + rng.uniform(1, 5)), max(oy + 2, min(oy + 60, y + rng.uniform(-7, 7)))
			args += ["-draw", f"line {x:.0f},{y:.0f} {nx:.0f},{ny:.0f}"]
			x, y = nx, ny
		args += ["-stroke", "none"]
	return args


def barda(path: str) -> None:
	"""Atlas de 3 mosaicos (2.5 x 2.5 m cada uno) para MapBardas.gd: aplanado liso,
	aplanado caido que deja ver el block y block aparente. Claro, porque se
	multiplica por el color de cada barda. La propaganda y los grafitis van encima,
	de los catalogos textures/map/propaganda/ y textures/map/grafitis/."""
	args = ["-size", f"{TILE * 3}x{TILE}", "xc:#e6e1d6", "-seed", "17",
		"-attenuate", "0.2", "+noise", "Uniform", "-colorspace", "sRGB"]
	# Rodapie sucio abajo en todos
	args += ["-fill", "#b9b1a2", "-draw", f"rectangle 0,{TILE - 6} {TILE * 3},{TILE - 1}"]
	# (1, 0): aplanado caido en manchones
	args += draw_args(blocks(8, 10, 30, 28)[1:], TILE, 0) + draw_args(blocks(38, 34, 58, 50)[1:], TILE, 0)
	# (2, 0): block aparente completo
	args += draw_args(blocks(0, 0, TILE - 1, TILE - 1)[1:], TILE * 2, 0)
	magick(*args, "-type", "TrueColor", "-depth", "8", path)


# Propaganda pintada en bardas (todo inventado: ni partidos ni negocios reales):
# (fondo, borde, [(texto, color, tamano, y), ...]) en un lienzo de 128 x 64
PROPAGANDA = [
	("#f2efe6", "#c8322a", [("SE VENDE", "#c8322a", 19, 7), ("33 1234 5678", "#151515", 14, 36)]),
	("#f0d64a", None, [("SE RENTA", "#1f4fa8", 22, 6), ("INFORMES AQUI", "#151515", 12, 38)]),
	("#1d2f6b", "#f0d64a", [("GRAN BAILE", "#f0d64a", 16, 5), ("SONIDO LA TAQUERA", "#f2f2f2", 10, 28),
		("SABADO 9 PM", "#e0503a", 11, 44)]),
	("#f2f2ee", None, [("VOTA", "#2f8a3a", 24, 2), ("PARTIDO DEL MAIZ", "#c8322a", 11, 34),
		("POR TU COLONIA", "#151515", 10, 48)]),
	("#e8862a", "#151515", [("FLETES Y", "#151515", 16, 4), ("MUDANZAS", "#151515", 16, 22),
		("33 8765 4321", "#f2f2f2", 12, 44)]),
	("#f2efe6", "#c8322a", [("PROHIBIDO", "#c8322a", 16, 6), ("TIRAR BASURA", "#151515", 13, 28),
		("MULTA", "#c8322a", 11, 46)]),
	("#f4f4f4", "#2a6cc4", [("AGUA", "#2a6cc4", 20, 4), ("PURIFICADA", "#2a6cc4", 14, 28), ("$15", "#c8322a", 12, 46)]),
	("#b9d9a0", None, [("TALLER EL GUERO", "#151515", 12, 8), ("HOJALATERIA", "#7a1f1a", 13, 26),
		("Y PINTURA", "#7a1f1a", 13, 42)]),
]
FUENTES = ["Arial-Black", "DejaVu-Sans-Bold", "Liberation-Sans-Bold", "Adwaita-Sans-Black", "Arial-Bold"]


def fuente_gruesa() -> list:
	"""["-font", nombre] de la primera fuente gruesa que tenga ImageMagick ([] = la de siempre)."""
	try:
		lista = subprocess.run(["magick", "-list", "font"], capture_output=True, text=True, check=True).stdout
	except (OSError, subprocess.CalledProcessError):
		return []
	hay = {linea.split(":", 1)[1].strip() for linea in lista.splitlines() if linea.strip().startswith("Font:")}
	return next((["-font", f] for f in FUENTES if f in hay), [])


def propaganda(carpeta: str) -> None:
	"""Propaganda dibujada para el catalogo de MapBardas.gd (propaganda_dibujada_NN.png,
	128 x 64, sin suavizar para que se vea pixeleada). Solo reescribe estos; los
	demas archivos de la carpeta son diseños agregados a mano."""
	os.makedirs(carpeta, exist_ok=True)
	fuente = fuente_gruesa()
	for i, (fondo, borde, lineas) in enumerate(PROPAGANDA):
		args = ["-size", "128x64", f"xc:{fondo}", "+antialias"]
		if borde:
			args += ["-fill", "none", "-stroke", borde, "-strokewidth", "2", "-draw", "rectangle 2,2 125,61", "-stroke", "none"]
		for texto, color, tamano, y in lineas:
			args += ["-fill", color, *fuente, "-pointsize", str(tamano), "-gravity", "north",
				"-annotate", f"+0+{y}", texto]
		# Pintura vieja: un poco de ruido
		args += ["-gravity", "northwest", "-seed", str(30 + i), "-attenuate", "0.25", "+noise", "Uniform"]
		magick(*args, "-type", "TrueColor", "-depth", "8", os.path.join(carpeta, f"propaganda_dibujada_{i + 1:02d}.png"))


def grafitis(carpeta: str, n: int = 8) -> None:
	"""Grafitis dibujados para el catalogo de MapBardas.gd (grafiti_dibujado_NN.png,
	con transparencia y recortados a lo que ocupan). Solo reescribe estos; los
	demas archivos de la carpeta son diseños agregados a mano."""
	os.makedirs(carpeta, exist_ok=True)
	for i in range(n):
		args = ["-size", f"{TILE}x{TILE}", "xc:none"] + grafiti(random.Random(100 + i), 0, 0)
		magick(*args, "-trim", "+repage", "-type", "TrueColorAlpha", "-depth", "8",
			os.path.join(carpeta, f"grafiti_dibujado_{i + 1:02d}.png"))


def malla(path: str) -> None:
	"""Malla ciclonica con transparencia, 2 mosaicos de 64 x 64 (2.5 m de largo por
	el alto de la malla): entera y rota (con un boquete abajo). Rombos de 8 px."""
	tile = ["-size", "64x64", "xc:none", "-stroke", "#8c9094", "-strokewidth", "1"]
	for k in range(-64, 64, 8):
		tile += ["-draw", f"line {k},0 {k + 64},64", "-draw", f"line {k},64 {k + 64},0"]
	# Alambre de arriba y de abajo
	tile += ["-stroke", "#6a6e72", "-draw", "line 0,1 63,1", "-draw", "line 0,62 63,62"]
	# Boquete de la rota: se borra un ovalo abajo (en el canal alfa) y quedan puntas sueltas
	rota = tile + ["(", "-size", "64x64", "xc:white", "-fill", "black", "-stroke", "none",
		"-draw", "ellipse 32,52 17,22 0,360", "-alpha", "copy", ")", "-compose", "DstIn", "-composite",
		"-compose", "Over", "-stroke", "#7a7e82"]
	rng = random.Random(5)
	for _ in range(10):
		a = rng.uniform(math.pi, 2 * math.pi)
		x, y = 32 + 17 * math.cos(a), 52 + 22 * math.sin(a)
		rota += ["-draw", f"line {x:.0f},{y:.0f} {x - 3 * math.cos(a):.0f},{y - 3 * math.sin(a):.0f}"]
	magick("(", *tile, ")", "(", *rota, ")", "+append", "+repage", "-type", "TrueColorAlpha", "-depth", "8", path)


if __name__ == "__main__":
	main()
