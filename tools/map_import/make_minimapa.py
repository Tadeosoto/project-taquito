#!/usr/bin/env python3
"""Dibuja el minimapa (radar estilo GTA) del mapa real en un PNG, a 1 m por pixel.

Lee el .osm que prepare_osm.py deja para OSM2World (ya con las casas de Google y
sin las casas que se cambiaron por tiendas o casas modelo) y dibuja encima los
lotes de resources/map/casas_mapa.json, resources/map/puntos_mapa.json y
resources/map/bodegas_mapa.json.
Escribe textures/map/minimapa.png y resources/map/minimapa.json (de que punto
del mapa es la esquina superior izquierda), que lee scripts/map/MapMinimapa.gd.

Uso (despues de build_glb.sh):
  python3 -I tools/map_import/make_minimapa.py
"""

import json
import math
import os
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from prepare_osm import local_xz, tags_of, write_png  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OSM = os.path.join(ROOT, "tools/map_import/bin/area_prepared.osm")
CASAS = os.path.join(ROOT, "resources/map/casas_mapa.json")
PUNTOS = os.path.join(ROOT, "resources/map/puntos_mapa.json")
BODEGAS = os.path.join(ROOT, "resources/map/bodegas_mapa.json")
# De make_vegetacion.py (si ya se corrio): pasto del satelite y arboles
PASTO = os.path.join(ROOT, "textures/map/pasto_mascara.png")
ARBOLES = os.path.join(ROOT, "resources/map/arboles_mapa.json")
SALIDA_PNG = os.path.join(ROOT, "textures/map/minimapa.png")
SALIDA_JSON = os.path.join(ROOT, "resources/map/minimapa.json")

METROS_POR_PIXEL = 1.0
MARGEN = 30.0

FONDO = (58, 64, 52)
EDIFICIO = (104, 106, 112)
VERDE = (64, 102, 56)
ARBOL = (44, 78, 40)
AGUA = (58, 104, 160)
ESTACIONAMIENTO = (82, 84, 84)

AREAS = [
	# (llave, valores, color); se pintan en este orden
	("landuse", {"grass", "recreation_ground", "farmland"}, VERDE),
	("natural", {"scrub"}, VERDE),
	("leisure", {"park", "pitch", "garden", "playground", "sports_centre", "track"}, VERDE),
	("amenity", {"parking"}, ESTACIONAMIENTO),
	("natural", {"water"}, AGUA),
	("leisure", {"swimming_pool"}, AGUA),
]

# highway -> (ancho en metros, color); las calles grandes van al final, encima
CALLES = [
	({"footway", "path", "pedestrian"}, 1.5, (120, 118, 108)),
	({"service"}, 4.0, (150, 148, 140)),
	({"living_street", "residential", "unclassified"}, 6.0, (196, 192, 180)),
	({"tertiary"}, 9.0, (226, 222, 206)),
	({"primary", "primary_link"}, 13.0, (240, 214, 140)),
]
CANAL = 4.0


class Lienzo:
	def __init__(self, x0, z0, x1, z1):
		self.x0, self.z0 = x0, z0
		self.w = int(math.ceil((x1 - x0) / METROS_POR_PIXEL))
		self.h = int(math.ceil((z1 - z0) / METROS_POR_PIXEL))
		self.rgb = bytearray(bytes(FONDO) * (self.w * self.h))

	def px(self, x, z):
		return (x - self.x0) / METROS_POR_PIXEL, (z - self.z0) / METROS_POR_PIXEL

	def poligono(self, ring, color):
		"""Relleno por renglones (centro del pixel adentro = se pinta)."""
		pts = [self.px(x, z) for x, z in ring]
		if pts[0] != pts[-1]:
			pts.append(pts[0])
		ys = [p[1] for p in pts]
		color = bytes(color)
		for row in range(max(int(min(ys)), 0), min(int(max(ys)) + 1, self.h)):
			cy = row + 0.5
			cortes = []
			for (ax, ay), (bx, by) in zip(pts, pts[1:]):
				if (ay <= cy) != (by <= cy):
					cortes.append(ax + (cy - ay) / (by - ay) * (bx - ax))
			cortes.sort()
			for a, b in zip(cortes[::2], cortes[1::2]):
				c0 = max(int(math.ceil(a - 0.5)), 0)
				c1 = min(int(math.floor(b - 0.5)), self.w - 1)
				if c1 >= c0:
					i = (row * self.w + c0) * 3
					self.rgb[i:i + (c1 - c0 + 1) * 3] = color * (c1 - c0 + 1)

	def linea(self, line, ancho, color):
		r = ancho / 2 / METROS_POR_PIXEL
		color = bytes(color)
		pts = [self.px(x, z) for x, z in line]
		for (ax, ay), (bx, by) in zip(pts, pts[1:]):
			dx, dy = bx - ax, by - ay
			l2 = dx * dx + dy * dy
			for row in range(max(int(min(ay, by) - r), 0), min(int(max(ay, by) + r) + 1, self.h)):
				cy = row + 0.5
				for col in range(max(int(min(ax, bx) - r), 0), min(int(max(ax, bx) + r) + 1, self.w)):
					cx = col + 0.5
					t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((cx - ax) * dx + (cy - ay) * dy) / l2))
					ex, ey = ax + dx * t - cx, ay + dy * t - cy
					if ex * ex + ey * ey <= r * r:
						i = (row * self.w + col) * 3
						self.rgb[i:i + 3] = color


def lote(x, z, rot, ancho, fondo, z_frente):
	"""Esquinas del lote; z_frente/z_fondo en ejes del lote (frente = +Z)."""
	c, s = math.cos(rot), math.sin(rot)
	out = []
	for lx, lz in ((-ancho / 2, z_frente), (ancho / 2, z_frente), (ancho / 2, z_frente - fondo), (-ancho / 2, z_frente - fondo)):
		out.append((x + lx * c + lz * s, z - lx * s + lz * c))
	return out


def main():
	root = ET.parse(OSM).getroot()
	b = root.find("bounds")
	south, west, north, east = (float(b.get(k)) for k in ("minlat", "minlon", "maxlat", "maxlon"))
	lat0, lon0 = (south + north) / 2, (west + east) / 2
	min_x, max_z = local_xz(south, west, lat0, lon0)
	max_x, min_z = local_xz(north, east, lat0, lon0)
	lienzo = Lienzo(min_x - MARGEN, min_z - MARGEN, max_x + MARGEN, max_z + MARGEN)

	pos = {n.get("id"): local_xz(float(n.get("lat")), float(n.get("lon")), lat0, lon0) for n in root.findall("node")}
	ways = []
	for way in root.findall("way"):
		refs = [nd.get("ref") for nd in way.findall("nd")]
		if all(r in pos for r in refs):
			ways.append((tags_of(way), [pos[r] for r in refs], refs[0] == refs[-1]))

	if os.path.exists(PASTO):
		from make_vegetacion import read_png
		w, h, ch, pasto = read_png(PASTO)
		if (w, h) == (lienzo.w, lienzo.h):
			verde = bytes(VERDE)
			for i in range(w * h):
				if pasto[i * ch] >= 128:
					lienzo.rgb[i * 3:i * 3 + 3] = verde
	for key, values, color in AREAS:
		for tags, line, closed in ways:
			if closed and tags.get(key) in values:
				lienzo.poligono(line, color)
	if os.path.exists(ARBOLES):
		with open(ARBOLES, encoding="utf-8") as f:
			for x, z, _, radio, _ in json.load(f)["arboles"]:
				copa = [(x + radio * math.cos(a * math.pi / 4), z + radio * math.sin(a * math.pi / 4)) for a in range(8)]
				lienzo.poligono(copa, ARBOL)
	edificios = 0
	for tags, line, closed in ways:
		if closed and ("building" in tags or "building:part" in tags):
			lienzo.poligono(line, EDIFICIO)
			edificios += 1
	with open(CASAS, encoding="utf-8") as f:
		casas = json.load(f)["casas"]
	for c in casas:
		# La fachada esta en (x, z) y la casa crece hacia atras
		lienzo.poligono(lote(c["x"], c["z"], c["rotacion_y"], c["ancho"], c["fondo"], 0.0), EDIFICIO)
	if os.path.exists(BODEGAS):
		with open(BODEGAS, encoding="utf-8") as f:
			for b in json.load(f)["bodegas"]:
				# Como las casas: el frente en (x, z), crece hacia atras
				lienzo.poligono(lote(b["x"], b["z"], b["rotacion_y"], b["ancho"], b["fondo"], 0.0), EDIFICIO)
	with open(PUNTOS, encoding="utf-8") as f:
		puntos = [p for p in json.load(f)["puntos"] if p.get("casa_reemplazada")]
	for p in puntos:
		# (x, z) es el centro del lote
		lienzo.poligono(lote(p["x"], p["z"], p["rotacion_y"], p["ancho"], p["fondo"], p["fondo"] / 2), EDIFICIO)

	for tags, line, closed in ways:
		if tags.get("waterway") in {"canal", "stream", "river", "ditch"}:
			lienzo.linea(line, CANAL, AGUA)
	for tipos, ancho, color in CALLES:
		for tags, line, closed in ways:
			if tags.get("highway") in tipos and not (closed and tags.get("area") == "yes"):
				lienzo.linea(line, ancho, color)

	write_png(SALIDA_PNG, lienzo.w, lienzo.h, lienzo.rgb)
	with open(SALIDA_JSON, "w", encoding="utf-8") as f:
		json.dump({"x0": lienzo.x0, "z0": lienzo.z0, "metros_por_pixel": METROS_POR_PIXEL,
			"ancho": lienzo.w, "alto": lienzo.h}, f, indent="\t")
	print(f"OK: {SALIDA_PNG} ({lienzo.w}x{lienzo.h} px, {edificios} edificios OSM, {len(casas)} casas modelo, {len(puntos)} tiendas)")


if __name__ == "__main__":
	main()
