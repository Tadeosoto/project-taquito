"""Analiza imagenes satelitales abiertas de la zona: donde hay arboles y donde pasto.

- Arboles: Meta/WRI "High Resolution Canopy Height" (CC BY 4.0), altura de la
  vegetacion a ~1 m por pixel. Cada copa es un maximo local de altura.
- Pasto: Sentinel-2 L2A (Copernicus, 10 m). El NDVI de la temporada de
  lluvias dice que se pone verde; el indice de suelo desnudo (BSI) de secas dice
  que es tierra. Las dos cosas cuentan como pasto (en secas el pasto es tierra).

Todo se lee por rangos HTTP (solo el pedazo de la zona) con rasterio y se
remuestrea a la rejilla del minimapa: 1 m por pixel en metros locales de Godot
(misma proyeccion que prepare_osm.local_xz), esquina = bbox menos MARGEN.

Necesita numpy, scipy y rasterio (no son stdlib), en un venv aparte:
  python3 -m venv tools/map_import/bin/venv
  tools/map_import/bin/venv/bin/pip install rasterio numpy scipy
Uso:
  tools/map_import/bin/venv/bin/python -I tools/map_import/fetch_satelite.py
Salida (data/map/):
  satelite_pasto.png   puntaje de pasto 0-255 (gris), 1 m/px
  satelite_copas.json  copas detectadas [x, z, altura, radio] en metros locales
  satelite_meta.json   rejilla y escenas usadas
  satelite_rgb.png     color real de Sentinel-2 (debug, no se sube a git)
  satelite_chm.png     altura de copas, 1 m = 8 niveles de gris (debug)
"""

import datetime
import json
import math
import os
import sys
import urllib.request

# GDAL lee los GeoTIFF remotos por rangos HTTP; que se identifique y no liste carpetas de S3
os.environ.setdefault("GDAL_HTTP_USERAGENT", "taquito-map-import/1.0")
os.environ.setdefault("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
os.environ.setdefault("CPL_VSIL_CURL_ALLOWED_EXTENSIONS", ".tif")

try:
	import numpy as np
	import rasterio
	from rasterio.warp import transform as warp_transform
	from rasterio.windows import from_bounds
	from scipy import ndimage
except ImportError:
	sys.exit(__doc__)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "map_import"))
from prepare_osm import EARTH_RADIUS, local_xz, write_png  # noqa: E402

UA = "taquito-map-import/1.0"
DATA = os.path.join(ROOT, "data", "map")
CACHE = os.path.join(ROOT, "tools", "map_import", "bin", "satelite")

# Misma rejilla que make_minimapa.py
METROS_POR_PIXEL = 1.0
MARGEN = 30.0

CHM_URL = "https://dataforgood-fb-data.s3.amazonaws.com/forests/v1/alsgedi_global_v6_float/chm/{}.tif"
CHM_ZOOM = 9

STAC = "https://earth-search.aws.element84.com/v1/search"
# Temporadas (meses) y anos que se juntan; cada pixel usa solo las fechas sin nube
LLUVIAS = (8, 10)
SECAS = (3, 5)
ANOS = (2023, 2024, 2025)
NUBES_MAX = 30
# Escenas que se usan por temporada (las de menos nubes)
ESCENAS = 5
# Fraccion minima de la zona sin nubes para usar una escena
LIMPIO_MIN = 0.9
# SCL de Sentinel-2: 4 vegetacion, 5 suelo, 6 agua, 7 sin clasificar. Lo demas es nube/sombra
SCL_BUENOS = (4, 5, 6, 7)

# Puntaje de pasto: rampa de NDVI de lluvias y de BSI de secas (0 -> 1). Lo urbano
# (techos, calles, patios) anda en NDVI ~0.1-0.2 y BSI ~0.1; la tierra pelona pasa de 0.2
NDVI_PASTO = (0.30, 0.45)
BSI_TIERRA = (0.17, 0.25)

# Copas: altura minima (m), NDVI de lluvias minimo (descarta azoteas y postes)
COPA_ALTURA_MIN = 3.0
COPA_NDVI_MIN = 0.25
COPA_RADIO = (1.5, 8.0)


def read_area() -> dict:
	area = {}
	with open(os.path.join(ROOT, "tools", "map_import", "area.env"), encoding="utf-8") as f:
		for line in f:
			line = line.strip()
			if line and not line.startswith("#") and "=" in line:
				key, value = line.split("=", 1)
				area[key] = float(value)
	return area


def quadkey(lat, lon, zoom) -> str:
	n = 2 ** zoom
	x = int((lon + 180) / 360 * n)
	s = math.sin(math.radians(lat))
	y = int((0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * n)
	return "".join(str(((x >> i) & 1) + 2 * ((y >> i) & 1)) for i in range(zoom - 1, -1, -1))


class Rejilla:
	"""Centros de pixel de la rejilla local, en lat/lon y en Mercator web (EPSG:3857)."""

	def __init__(self, area):
		south, west, north, east = area["SOUTH"], area["WEST"], area["NORTH"], area["EAST"]
		self.lat0, self.lon0 = (south + north) / 2, (west + east) / 2
		min_x, max_z = local_xz(south, west, self.lat0, self.lon0)
		max_x, min_z = local_xz(north, east, self.lat0, self.lon0)
		self.x0, self.z0 = min_x - MARGEN, min_z - MARGEN
		self.w = int(math.ceil((max_x + MARGEN - self.x0) / METROS_POR_PIXEL))
		self.h = int(math.ceil((max_z + MARGEN - self.z0) / METROS_POR_PIXEL))
		xs = self.x0 + (np.arange(self.w) + 0.5) * METROS_POR_PIXEL
		zs = self.z0 + (np.arange(self.h) + 0.5) * METROS_POR_PIXEL
		self.x, self.z = np.meshgrid(xs, zs)
		# Inverso de local_xz: Mercator escalado por cos(lat0)
		scale = math.cos(math.radians(self.lat0))
		merc_y0 = EARTH_RADIUS * math.log(math.tan(math.pi / 4 + math.radians(self.lat0) / 2))
		self.mx = self.x / scale + EARTH_RADIUS * math.radians(self.lon0)
		self.my = -self.z / scale + merc_y0
		self.lon = np.degrees(self.mx / EARTH_RADIUS)
		self.lat = np.degrees(2 * np.arctan(np.exp(self.my / EARTH_RADIUS)) - math.pi / 2)
		self.bbox = (float(self.lon.min()), float(self.lat.min()), float(self.lon.max()), float(self.lat.max()))

	def muestrear(self, ds, band_data, window, xs, ys, order=1):
		"""Valores de band_data (leido de `window` de ds) en los puntos xs, ys (CRS de ds)."""
		inv = ~ds.window_transform(window)
		cols, rows = inv * (xs, ys)
		return ndimage.map_coordinates(band_data, [rows - 0.5, cols - 0.5], order=order, mode="nearest")


def leer_ventana(ds, xs, ys, band=1, pad=3):
	"""Lee solo el pedazo de la banda que cubre los puntos (mas un margen)."""
	res = abs(ds.transform.a)
	window = from_bounds(xs.min() - pad * res, ys.min() - pad * res, xs.max() + pad * res, ys.max() + pad * res, ds.transform)
	window = window.round_offsets().round_lengths()
	window = window.intersection(rasterio.windows.Window(0, 0, ds.width, ds.height))
	return ds.read(band, window=window).astype(np.float32), window


def canopy(rejilla) -> np.ndarray:
	"""Altura de copas (m) en la rejilla local."""
	keys = {quadkey(lat, lon, CHM_ZOOM) for lat in (rejilla.bbox[1], rejilla.bbox[3]) for lon in (rejilla.bbox[0], rejilla.bbox[2])}
	if len(keys) != 1:
		sys.exit(f"La zona cae en varios tiles del Canopy Height ({sorted(keys)}); falta juntarlos")
	key = keys.pop()
	path = os.path.join(CACHE, f"chm_{key}_{rejilla.w}x{rejilla.h}.npy")
	if os.path.exists(path):
		return np.load(path)
	url = CHM_URL.format(key)
	print(f"Canopy Height: {url}")
	with rasterio.open("/vsicurl/" + url) as ds:
		data, window = leer_ventana(ds, rejilla.mx, rejilla.my)
		chm = rejilla.muestrear(ds, data, window, rejilla.mx, rejilla.my, order=1)
	os.makedirs(CACHE, exist_ok=True)
	np.save(path, chm)
	return chm


def stac_buscar(bbox, meses, ano) -> list:
	inicio = datetime.date(ano, meses[0], 1)
	fin = datetime.date(ano + (meses[1] == 12), meses[1] % 12 + 1, 1)
	body = json.dumps({
		"collections": ["sentinel-2-l2a"], "bbox": list(bbox), "limit": 100,
		"datetime": f"{inicio}T00:00:00Z/{fin}T00:00:00Z",
		"query": {"eo:cloud_cover": {"lt": NUBES_MAX}},
	}).encode()
	req = urllib.request.Request(STAC, data=body, headers={"User-Agent": UA, "Content-Type": "application/json"})
	with urllib.request.urlopen(req, timeout=60) as r:
		return json.load(r)["features"]


def banda(item, nombre, rejilla, cache, order=1):
	"""Reflectancia de una banda de una escena en la rejilla local."""
	asset = item["assets"][nombre]
	with rasterio.open("/vsicurl/" + asset["href"]) as ds:
		key = str(ds.crs)
		if key not in cache:
			cache[key] = warp_transform("EPSG:4326", ds.crs, rejilla.lon.ravel(), rejilla.lat.ravel())
		xs, ys = (np.asarray(v).reshape(rejilla.x.shape) for v in cache[key])
		data, window = leer_ventana(ds, xs, ys)
		valores = rejilla.muestrear(ds, data, window, xs, ys, order=order)
	return valores


def reflectancia(dn, con_offset):
	"""DN -> reflectancia (DN / 10000, menos 0.1 si el DN trae el offset de ESA)."""
	return np.maximum(dn * 0.0001 - (0.1 if con_offset else 0.0), 0.0)


def escena(item, rejilla, cache):
	"""Bandas de una escena en la rejilla, o None si esta nublada sobre la zona. Se
	guardan en bin/satelite/ para no volver a bajarlas."""
	path = os.path.join(CACHE, f"{item['id']}_{rejilla.w}x{rejilla.h}_dn.npz")
	if os.path.exists(path):
		bandas = dict(np.load(path))
		if not bandas:
			return None
	else:
		bandas = bajar_escena(item, rejilla, cache, path)
		if bandas is None:
			return None
	# Desde la version de procesamiento 04.00 (2022) ESA le suma 1000 al DN. Earth Search se
	# lo quita a casi todas, pero su etiqueta (earthsearch:boa_offset_applied) no siempre es
	# confiable: se ve en los datos. Lo mas oscuro del azul (agua, sombra) anda en 100-500.
	con_offset = np.percentile(bandas["blue"], 1) > 1000
	return {b: v if b == "scl" else reflectancia(v, con_offset) for b, v in bandas.items()}


def bajar_escena(item, rejilla, cache, path):
	os.makedirs(CACHE, exist_ok=True)
	bandas = {"scl": banda(item, "scl", rejilla, cache, order=0)}
	if np.isin(bandas["scl"], SCL_BUENOS).mean() < LIMPIO_MIN:
		np.savez_compressed(path)
		return None
	for b in ("red", "green", "blue", "nir", "swir16"):
		bandas[b] = banda(item, b, rejilla, cache).astype(np.float32)
	np.savez_compressed(path, **{b: v.astype(np.uint16) for b, v in bandas.items()})
	return bandas


def temporada(rejilla, meses, cache) -> tuple:
	"""(ndvi, bsi, rgb, fechas): medianas de las ESCENAS menos nubladas de esos meses."""
	ndvis, bsis, rgbs, fechas = [], [], [], []
	items = [item for ano in ANOS for item in stac_buscar(rejilla.bbox, meses, ano)]
	items.sort(key=lambda item: item["properties"]["eo:cloud_cover"])
	for item in items:
		fecha = item["properties"]["datetime"][:10]
		if len(fechas) >= ESCENAS or fecha in fechas:
			continue
		b = escena(item, rejilla, cache)
		if b is None:
			print(f"  {fecha}: nublado sobre la zona, se salta")
			continue
		buenos = np.isin(b["scl"], SCL_BUENOS)
		red, green, blue, nir, swir = b["red"], b["green"], b["blue"], b["nir"], b["swir16"]
		ndvi = (nir - red) / np.maximum(nir + red, 1e-4)
		bsi = ((swir + red) - (nir + blue)) / np.maximum(swir + red + nir + blue, 1e-4)
		ndvis.append(np.where(buenos, ndvi, np.nan))
		bsis.append(np.where(buenos, bsi, np.nan))
		rgbs.append(np.where(buenos, np.stack([red, green, blue]), np.nan))
		fechas.append(fecha)
		print(f"  {fecha}: {buenos.mean():.0%} limpio, NDVI medio {np.nanmean(ndvis[-1]):.2f}")
	if not fechas:
		sys.exit(f"No hay escenas de Sentinel-2 sin nubes en los meses {meses}")
	return (np.nanmedian(np.stack(ndvis), axis=0), np.nanmedian(np.stack(bsis), axis=0),
		np.nanmedian(np.stack(rgbs), axis=0), sorted(fechas))


def rampa(v, rango):
	return np.clip((v - rango[0]) / (rango[1] - rango[0]), 0.0, 1.0)


def copas(chm, ndvi, rejilla) -> list:
	"""Un arbol por maximo local del CHM suavizado. La ventana de supresion crece con la
	altura (copa ~ 0.3 h + 1 m de radio) y el radio de copa es donde baja a la mitad."""
	suave = ndimage.gaussian_filter(chm, 1.0 / METROS_POR_PIXEL)
	picos = (suave == ndimage.maximum_filter(suave, size=5)) & (suave >= COPA_ALTURA_MIN)
	picos &= ndimage.maximum_filter(ndvi, size=11) >= COPA_NDVI_MIN
	rows, cols = np.nonzero(picos)
	orden = np.argsort(-suave[rows, cols])
	tomados = []
	ocupado = {}
	celda = 8.0
	for i in orden:
		r, c = rows[i], cols[i]
		h = float(suave[r, c])
		x, z = float(rejilla.x[r, c]), float(rejilla.z[r, c])
		sep = 0.3 * h + 1.0
		cx, cz = int(x // celda), int(z // celda)
		if any(math.hypot(x - ox, z - oz) < max(sep, osep)
				for dx in (-1, 0, 1) for dz in (-1, 0, 1)
				for ox, oz, osep in ocupado.get((cx + dx, cz + dz), ())):
			continue
		radios = []
		for ang in range(8):
			dx, dz = math.cos(ang * math.pi / 4), math.sin(ang * math.pi / 4)
			d = 1.0
			while d < COPA_RADIO[1]:
				rr, cc = int(round(r + dz * d / METROS_POR_PIXEL)), int(round(c + dx * d / METROS_POR_PIXEL))
				if not (0 <= rr < chm.shape[0] and 0 <= cc < chm.shape[1]) or suave[rr, cc] < h * 0.5:
					break
				d += METROS_POR_PIXEL
			radios.append(d)
		radio = min(max(sum(radios) / len(radios), COPA_RADIO[0]), COPA_RADIO[1])
		ocupado.setdefault((cx, cz), []).append((x, z, sep))
		tomados.append([round(x, 2), round(z, 2), round(h, 1), round(radio, 1)])
	return tomados


def png_gris(path, v01) -> None:
	g = (np.clip(v01, 0, 1) * 255).astype(np.uint8)
	write_png(path, g.shape[1], g.shape[0], bytearray(np.repeat(g[..., None], 3, axis=2).tobytes()))


def main() -> None:
	area = read_area()
	rejilla = Rejilla(area)
	print(f"Rejilla: {rejilla.w}x{rejilla.h} px, esquina ({rejilla.x0:.1f}, {rejilla.z0:.1f})")
	os.makedirs(DATA, exist_ok=True)

	chm = canopy(rejilla)
	print(f"  copas >= {COPA_ALTURA_MIN:.0f} m: {(chm >= COPA_ALTURA_MIN).mean():.1%} de la zona")

	cache = {}
	print(f"Sentinel-2, lluvias (meses {LLUVIAS}):")
	ndvi_lluvias, _, rgb, fechas_lluvias = temporada(rejilla, LLUVIAS, cache)
	print(f"Sentinel-2, secas (meses {SECAS}):")
	_, bsi_secas, _, fechas_secas = temporada(rejilla, SECAS, cache)
	ndvi_lluvias = np.nan_to_num(ndvi_lluvias, nan=0.0)
	bsi_secas = np.nan_to_num(bsi_secas, nan=-1.0)

	pasto = np.maximum(rampa(ndvi_lluvias, NDVI_PASTO), rampa(bsi_secas, BSI_TIERRA))
	png_gris(os.path.join(DATA, "satelite_pasto.png"), pasto)
	png_gris(os.path.join(DATA, "satelite_chm.png"), chm / 32.0)
	rgb = np.nan_to_num(np.moveaxis(rgb, 0, -1), nan=0.0)
	bajo, alto = np.percentile(rgb, 2), np.percentile(rgb, 98)
	rgb8 = (np.clip((rgb - bajo) / (alto - bajo), 0, 1) ** (1 / 1.6) * 255).astype(np.uint8)
	write_png(os.path.join(DATA, "satelite_rgb.png"), rejilla.w, rejilla.h, bytearray(rgb8.tobytes()))
	print(f"  pasto (puntaje >= 0.5): {(pasto >= 0.5).mean():.1%} de la zona")

	arboles = copas(chm, ndvi_lluvias, rejilla)
	with open(os.path.join(DATA, "satelite_copas.json"), "w", encoding="utf-8") as f:
		f.write('{"copas": [\n' + ",\n".join(json.dumps(a) for a in arboles) + "\n]}\n")
	print(f"  copas detectadas: {len(arboles)}")

	with open(os.path.join(DATA, "satelite_meta.json"), "w", encoding="utf-8") as f:
		json.dump({
			"x0": rejilla.x0, "z0": rejilla.z0, "metros_por_pixel": METROS_POR_PIXEL,
			"ancho": rejilla.w, "alto": rejilla.h,
			"canopy_height": "Meta/WRI High Resolution Canopy Height v1 (CC BY 4.0)",
			"sentinel2_lluvias": fechas_lluvias, "sentinel2_secas": fechas_secas,
		}, f, indent="\t")
	print(f"OK: {DATA}/satelite_*")


if __name__ == "__main__":
	main()
