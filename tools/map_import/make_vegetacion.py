#!/usr/bin/env python3
"""Junta lo que vio el satelite (fetch_satelite.py) con las calles y casas del mapa.

- Pasto: el puntaje de data/map/satelite_pasto.png, menos casas, lotes de casas
  modelo y tiendas, arroyos y banquetas, mas los camellones que agrego
  prepare_osm.py. Sale en textures/map/pasto_mascara.png (1 m/px, la misma
  rejilla que el minimapa) para shaders/ps1_suelo.gdshader y MapPasto.gd.
- Arboles: las copas de data/map/satelite_copas.json que no caen en una casa ni
  en el arroyo de una calle (si caen cerca de la orilla, se recorren a la
  banqueta). Sale en resources/map/arboles_mapa.json para MapArboles.gd.
- data/map/calles_debug.png: todo pintado encima de la foto de Sentinel-2, para
  revisar a ojo (no se sube a git).

Lee el .osm que deja prepare_osm.py, asi que va despues de el (lo corre build_glb.sh).
Si no hay datos satelitales, solo avisa.

Uso: python3 -I tools/map_import/make_vegetacion.py
"""

import json
import math
import os
import struct
import sys
import xml.etree.ElementTree as ET
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_minimapa import MARGEN, METROS_POR_PIXEL, Lienzo, lote  # noqa: E402
from prepare_osm import huella_negocio, local_xz, tags_of, write_png  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OSM = os.path.join(ROOT, "tools/map_import/bin/area_prepared.osm")
CASAS = os.path.join(ROOT, "resources/map/casas_mapa.json")
PUNTOS = os.path.join(ROOT, "resources/map/puntos_mapa.json")
HUELLAS = os.path.join(ROOT, "data/map/huellas_tiendas.json")
SAT_PASTO = os.path.join(ROOT, "data/map/satelite_pasto.png")
SAT_RGB = os.path.join(ROOT, "data/map/satelite_rgb.png")
SAT_COPAS = os.path.join(ROOT, "data/map/satelite_copas.json")
SAT_META = os.path.join(ROOT, "data/map/satelite_meta.json")
SALIDA_MASCARA = os.path.join(ROOT, "textures/map/pasto_mascara.png")
SALIDA_MASCARA_JSON = os.path.join(ROOT, "resources/map/pasto_mascara.json")
SALIDA_ARBOLES = os.path.join(ROOT, "resources/map/arboles_mapa.json")
SALIDA_DEBUG = os.path.join(ROOT, "data/map/calles_debug.png")

# Ancho (m) de lo que no trae `width` (andadores, y calles si se corre sin prepare_osm nuevo)
ANCHO_DEFAULT = {"footway": 1.5, "path": 1.2, "pedestrian": 4.0, "cycleway": 2.0}
# Un arbol cuyo tronco cae en el arroyo se recorre hasta esto (m) para salir a la banqueta
ARBOL_RECORRER = 3.0
ARBOL_ALTURA = (3.0, 25.0)
# Copas mas angostas que esto respecto a su altura son de arbol alto (eucalipto, pino)
ARBOL_ESBELTO = 0.28


def read_png(path):
	"""(ancho, alto, canales, bytes) de un PNG de 8 bits gris/RGB/RGBA sin entrelazar."""
	with open(path, "rb") as f:
		data = f.read()
	pos, idat = 8, b""
	while pos < len(data):
		length, kind = struct.unpack(">I4s", data[pos:pos + 8])
		body = data[pos + 8:pos + 8 + length]
		if kind == b"IHDR":
			w, h, depth, color = struct.unpack(">IIBB", body[:10])
		elif kind == b"IDAT":
			idat += body
		pos += 12 + length
	if depth != 8 or color not in (0, 2, 6):
		raise ValueError(f"{path}: PNG no soportado (profundidad {depth}, color {color})")
	ch = {0: 1, 2: 3, 6: 4}[color]
	raw = zlib.decompress(idat)
	stride = w * ch
	out = bytearray(h * stride)
	prev = bytearray(stride)
	for y in range(h):
		f = raw[y * (stride + 1)]
		line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
		for i in range(stride):
			a = line[i - ch] if i >= ch else 0
			b = prev[i]
			c = prev[i - ch] if i >= ch else 0
			if f == 1:
				line[i] = (line[i] + a) & 255
			elif f == 2:
				line[i] = (line[i] + b) & 255
			elif f == 3:
				line[i] = (line[i] + (a + b) // 2) & 255
			elif f == 4:
				p = a + b - c
				pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
				line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
		out[y * stride:(y + 1) * stride] = line
		prev = line
	return w, h, ch, out


def anchos(tags):
	"""(ancho total, ancho del arroyo) en metros."""
	try:
		total = float(tags.get("width", "").split()[0])
	except (ValueError, IndexError):
		total = ANCHO_DEFAULT.get(tags.get("highway"), 6.0)
	banquetas = 0.0
	for lado in ("left", "right"):
		try:
			banquetas += float(tags.get(f"sidewalk:{lado}:width", 0))
		except ValueError:
			pass
	return total, max(total - banquetas, 1.0)


def main():
	if not (os.path.exists(SAT_PASTO) and os.path.exists(SAT_COPAS)):
		print("AVISO: no hay datos satelitales (corre fetch_satelite.py); sin pasto ni arboles nuevos")
		return
	root = ET.parse(OSM).getroot()
	b = root.find("bounds")
	south, west, north, east = (float(b.get(k)) for k in ("minlat", "minlon", "maxlat", "maxlon"))
	lat0, lon0 = (south + north) / 2, (west + east) / 2
	min_x, max_z = local_xz(south, west, lat0, lon0)
	max_x, min_z = local_xz(north, east, lat0, lon0)
	caja = (min_x - MARGEN, min_z - MARGEN, max_x + MARGEN, max_z + MARGEN)

	with open(SAT_META, encoding="utf-8") as f:
		meta = json.load(f)
	bloqueo, banqueta, calzada, camellon = (Lienzo(*caja) for _ in range(4))
	w, h = bloqueo.w, bloqueo.h
	if (meta["ancho"], meta["alto"]) != (w, h) or abs(meta["x0"] - bloqueo.x0) > 0.01 or abs(meta["z0"] - bloqueo.z0) > 0.01:
		sys.exit("ERROR: la rejilla del satelite no es la del mapa (cambio area.env?): corre fetch_satelite.py otra vez")
	blanco = (255, 255, 255)
	for lienzo in (bloqueo, banqueta, calzada, camellon):
		lienzo.rgb = bytearray(w * h * 3)

	pos = {n.get("id"): local_xz(float(n.get("lat")), float(n.get("lon")), lat0, lon0) for n in root.findall("node")}
	for way in root.findall("way"):
		refs = [nd.get("ref") for nd in way.findall("nd")]
		if not all(r in pos for r in refs):
			continue
		tags = tags_of(way)
		line = [pos[r] for r in refs]
		closed = refs[0] == refs[-1]
		if closed and ("building" in tags or "building:part" in tags):
			bloqueo.poligono(line, blanco)
		elif closed and tags.get("source") == "camellon taquito" and tags.get("landuse") == "grass":
			camellon.poligono(line, blanco)
		elif "highway" in tags and not (closed and tags.get("area") == "yes"):
			total, arroyo = anchos(tags)
			banqueta.linea(line, total, blanco)
			calzada.linea(line, arroyo, blanco)
	with open(CASAS, encoding="utf-8") as f:
		for c in json.load(f)["casas"]:
			bloqueo.poligono(lote(c["x"], c["z"], c["rotacion_y"], c["ancho"], c["fondo"], 0.0), blanco)
	huellas = {}
	if os.path.exists(HUELLAS):
		with open(HUELLAS, encoding="utf-8") as f:
			huellas = json.load(f)
	with open(PUNTOS, encoding="utf-8") as f:
		for p in json.load(f)["puntos"]:
			if p.get("casa_reemplazada"):
				bloqueo.poligono(lote(p["x"], p["z"], p["rotacion_y"], p["ancho"], p["fondo"], p["fondo"] / 2), blanco)
			# Lo que ocupa el modelo del negocio (puede salirse del lote)
			huella = huella_negocio(p, huellas)
			if huella and p["tipo"] not in ("puesto", "puesto_tacos"):
				bloqueo.poligono(huella, blanco)

	# Pasto = satelite sin casas ni calles, mas camellones
	sw, sh, sch, sat = read_png(SAT_PASTO)
	mascara = bytearray(w * h * 3)
	for i in range(w * h):
		j = i * 3
		if camellon.rgb[j]:
			v = 255
		elif bloqueo.rgb[j] or banqueta.rgb[j]:
			v = 0
		else:
			v = sat[i * sch]
		mascara[j] = mascara[j + 1] = mascara[j + 2] = v
	os.makedirs(os.path.dirname(SALIDA_MASCARA), exist_ok=True)
	write_png(SALIDA_MASCARA, w, h, mascara)
	with open(SALIDA_MASCARA_JSON, "w", encoding="utf-8") as f:
		json.dump({"x0": bloqueo.x0, "z0": bloqueo.z0, "metros_por_pixel": METROS_POR_PIXEL,
			"ancho": w, "alto": h}, f, indent="\t")
	pasto = sum(1 for i in range(0, w * h * 3, 3) if mascara[i] >= 128)
	print(f"OK: {SALIDA_MASCARA} ({pasto / (w * h):.0%} de la zona es pasto)")

	# Arboles
	def celda(x, z):
		return int((x - bloqueo.x0) / METROS_POR_PIXEL), int((z - bloqueo.z0) / METROS_POR_PIXEL)

	def libre(cx, cz, permitir_banqueta=True):
		if not (0 <= cx < w and 0 <= cz < h):
			return False
		j = (cz * w + cx) * 3
		return not bloqueo.rgb[j] and not calzada.rgb[j] and (permitir_banqueta or not banqueta.rgb[j])

	with open(SAT_COPAS, encoding="utf-8") as f:
		copas = json.load(f)["copas"]
	arboles = []
	quitados = {"casa": 0, "calle": 0, "fuera": 0}
	r_max = int(math.ceil(ARBOL_RECORRER / METROS_POR_PIXEL))
	for x, z, altura, radio in copas:
		cx, cz = celda(x, z)
		if not (min_x - MARGEN <= x <= max_x + MARGEN and min_z - MARGEN <= z <= max_z + MARGEN):
			quitados["fuera"] += 1
			continue
		j = (cz * w + cx) * 3
		if bloqueo.rgb[j]:
			quitados["casa"] += 1
			continue
		if calzada.rgb[j]:
			# Al pixel libre mas cercano (banqueta, camellon o jardin)
			mejor = None
			for dz in range(-r_max, r_max + 1):
				for dx in range(-r_max, r_max + 1):
					d = math.hypot(dx, dz) * METROS_POR_PIXEL
					if d <= ARBOL_RECORRER and libre(cx + dx, cz + dz) and (mejor is None or d < mejor[0]):
						mejor = (d, dx, dz)
			if mejor is None:
				quitados["calle"] += 1
				continue
			x += mejor[1] * METROS_POR_PIXEL
			z += mejor[2] * METROS_POR_PIXEL
		altura = min(max(altura, ARBOL_ALTURA[0]), ARBOL_ALTURA[1])
		variante = 1 if altura >= 9.0 and radio < ARBOL_ESBELTO * altura else 0
		arboles.append([round(x, 2), round(z, 2), round(altura, 1), round(radio, 1), variante])
	with open(SALIDA_ARBOLES, "w", encoding="utf-8") as f:
		f.write('{"arboles": [\n' + ",\n".join(json.dumps(a) for a in arboles) + "\n]}\n")
	print(f"OK: {SALIDA_ARBOLES} ({len(arboles)} arboles; quitados: {quitados['casa']} en casas, "
		f"{quitados['calle']} en medio de la calle, {quitados['fuera']} fuera de la zona)")

	# Debug: foto de Sentinel-2 aclarada, con pasto, banquetas, calles, casas y arboles encima
	if os.path.exists(SAT_RGB):
		_, _, rch, debug = read_png(SAT_RGB)
		debug = bytearray(debug) if rch == 3 else bytearray(b for i, b in enumerate(debug) if i % rch < 3)
	else:
		debug = bytearray(w * h * 3)
	for i in range(w * h):
		j = i * 3
		color = None
		if bloqueo.rgb[j]:
			color = (120, 80, 70)
		elif calzada.rgb[j]:
			color = (40, 40, 44)
		elif banqueta.rgb[j]:
			color = (200, 200, 190)
		elif mascara[j] >= 128:
			color = (90, 170, 60) if not camellon.rgb[j] else (40, 220, 120)
		if color:
			debug[j:j + 3] = bytes((a + 2 * c) // 3 for a, c in zip(debug[j:j + 3], color))
	for x, z, _, radio, variante in arboles:
		cx, cz = celda(x, z)
		for dz in (-1, 0, 1):
			for dx in (-1, 0, 1):
				if 0 <= cx + dx < w and 0 <= cz + dz < h:
					j = ((cz + dz) * w + cx + dx) * 3
					debug[j:j + 3] = b"\xff\x30\x30" if variante == 0 else b"\xff\xd0\x30"
	write_png(SALIDA_DEBUG, w, h, debug)
	print(f"  debug: {SALIDA_DEBUG}")


if __name__ == "__main__":
	main()
