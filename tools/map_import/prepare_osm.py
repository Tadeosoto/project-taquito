"""Prepara data/map/area.osm para OSM2World.

- Recorta todo lo que se sale del rectangulo (calles largas, landuse enormes).
- A las casas sin altura les pone 1 o 2 pisos, techo plano y un color de
  fachada. Siempre salen igual porque se eligen con el id de OSM como semilla.
- Agrega las casas de Google Open Buildings que OSM no tiene
  (data/map/google_buildings.csv, ver fetch_google_buildings.py).
- Aplica data/map/overrides.json (lo que corriges a mano viendo Street View).
- Coloca las tiendas y puestos de data/map/denue_puntos.json (INEGI, ver
  fetch_denue.py), data/map/puntos.json (a mano) y los que ya trae OSM:
  quita la casa que esta debajo y escribe sus posiciones en metros para Godot.

Uso: ver build_glb.sh (python3 prepare_osm.py --help)
"""

import argparse
import csv
import json
import math
import os
import sys
import xml.etree.ElementTree as ET
import zlib

# Margen (en metros) alrededor del rectangulo para no cortar las calles justo en la orilla
MARGIN_M = 30.0

# Colores tipicos de fachada tapatia
PALETTE = [
	"#e8d7b9",  # crema
	"#d9a066",  # ocre
	"#c96f4a",  # terracota
	"#f2efe6",  # blanco gastado
	"#b5c99a",  # verde palido
	"#e3b448",  # amarillo
	"#9fb8c9",  # azul palido
	"#d4b3a3",  # rosa viejo
]

HEIGHT_KEYS = ("height", "building:levels", "levels")

# Casas de Google: confianza minima y area minima (m2) para no meter tinacos ni sombras
GOOGLE_MIN_CONFIDENCE = 0.70
GOOGLE_MIN_AREA = 20.0

# Ids para lo que agregamos nosotros (no chocan con los de OSM)
SPLIT_ID_START = 10**15
GOOGLE_ID_START = 2 * 10**15

# Tamano de celda (grados, ~55 m) del indice para buscar edificios cercanos
GRID = 0.0005

# Radio de la Tierra que usa OSM2World para proyectar (WGS84)
EARTH_RADIUS = 6378137.0

# Calles hacia las que se orienta la fachada de una tienda
STREET_TYPES = {"primary", "secondary", "tertiary", "unclassified", "residential", "living_street", "service"}

# Los puestos van en la banqueta: no quitan la casa donde caen
NO_REPLACE_TIPOS = {"puesto_tacos", "puesto"}

# Tamano (ancho, fondo en metros) cuando el punto no cae sobre una casa
# puesto_tacos es mas grande porque el modelo trae un pedazo de calle
DEFAULT_SIZE = {"puesto_tacos": (4.0, 4.0), "puesto": (2.5, 2.0)}
FALLBACK_SIZE = (8.0, 10.0)

# Distancia (m) del eje de la calle a la que se ponen los puestos (en la banqueta)
PUESTO_STREET_DIST = 4.5

# Si una tienda no cae sobre una casa (el DENUE suele ponerla en la banqueta),
# toma la casa mas cercana a menos de esto (m)
HOUSE_SNAP_DIST = 15.0

# Edificios mas grandes que esto (m2) son plazas o manzanas enteras mal trazadas:
# una tienda no los reemplaza
MAX_SHOP_LOT = 300.0

# De dos negocios del mismo tipo a menos de esto (m) solo se deja uno
# (repetidos entre DENUE y OSM, o varios abarrotes pegados)
DUPLICATE_DIST = 80.0
# Radio propio para tipos que sobran aun con DUPLICATE_DIST
DUPLICATE_DIST_TIPO = {"tienda": 150.0}


def seed(osm_id: str) -> int:
	return zlib.crc32(osm_id.encode())


def tags_of(elem) -> dict:
	return {t.get("k"): t.get("v") for t in elem.findall("tag")}


def set_tag(elem, key: str, value) -> None:
	for t in elem.findall("tag"):
		if t.get("k") == key:
			if value is None:
				elem.remove(t)
			else:
				t.set("v", str(value))
			return
	if value is not None:
		ET.SubElement(elem, "tag", k=key, v=str(value))


def fill_building(elem, kind: str) -> bool:
	"""Rellena pisos, techo y color si faltan. Regresa True si cambio algo."""
	tags = tags_of(elem)
	if "building" not in tags and "building:part" not in tags:
		return False
	s = seed(kind + "/" + elem.get("id"))
	changed = False
	if not any(k in tags for k in HEIGHT_KEYS):
		set_tag(elem, "building:levels", 1 + (s % 2))
		changed = True
	if "roof:shape" not in tags:
		set_tag(elem, "roof:shape", "flat")
	if "building:colour" not in tags:
		set_tag(elem, "building:colour", PALETTE[(s >> 4) % len(PALETTE)])
	return changed


def point_in_polygon(lon: float, lat: float, ring: list) -> bool:
	inside = False
	for i in range(len(ring)):
		x1, y1 = ring[i]
		x2, y2 = ring[(i + 1) % len(ring)]
		if (y1 > lat) != (y2 > lat) and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
			inside = not inside
	return inside


def centroid(ring: list) -> tuple:
	return (sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring))


def parse_wkt_polygon(wkt: str):
	"""Solo el anillo exterior de un POLYGON (los patios interiores se ignoran)."""
	if not wkt.startswith("POLYGON"):
		return None
	outer = wkt[wkt.index("((") + 2:].split(")")[0]
	ring = [tuple(map(float, pair.split())) for pair in outer.split(",")]
	if ring[0] == ring[-1]:
		ring = ring[:-1]
	return ring if len(ring) >= 3 else None


def add_google_buildings(root, google_path, osm_rings, inside_fn) -> tuple:
	"""Agrega como ways las casas de Google que no se enciman con una de OSM."""
	grid = {}
	for ring in osm_rings:
		lon, lat = centroid(ring)
		grid.setdefault((int(lon / GRID), int(lat / GRID)), []).append(ring)

	def overlaps_osm(ring):
		lon, lat = centroid(ring)
		cx, cy = int(lon / GRID), int(lat / GRID)
		for dx in (-1, 0, 1):
			for dy in (-1, 0, 1):
				for other in grid.get((cx + dx, cy + dy), ()):
					if point_in_polygon(lon, lat, other):
						return True
					if point_in_polygon(*centroid(other), ring):
						return True
		return False

	added, skipped_overlap, skipped_low = [], 0, 0
	node_id = GOOGLE_ID_START
	way_id = GOOGLE_ID_START
	with open(google_path, encoding="utf-8", newline="") as f:
		for row in csv.DictReader(f):
			if float(row["confidence"]) < GOOGLE_MIN_CONFIDENCE or float(row["area_in_meters"]) < GOOGLE_MIN_AREA:
				skipped_low += 1
				continue
			ring = parse_wkt_polygon(row["geometry"])
			if ring is None or not inside_fn(row["latitude"], row["longitude"]):
				continue
			if overlaps_osm(ring):
				skipped_overlap += 1
				continue
			way = ET.Element("way", id=str(way_id), version="1")
			first = None
			for lon, lat in ring:
				ET.SubElement(root, "node", id=str(node_id), version="1", lat=f"{lat:.7f}", lon=f"{lon:.7f}")
				ET.SubElement(way, "nd", ref=str(node_id))
				first = first or str(node_id)
				node_id += 1
			ET.SubElement(way, "nd", ref=first)
			ET.SubElement(way, "tag", k="building", v="yes")
			ET.SubElement(way, "tag", k="source", v="Google Open Buildings v3")
			added.append(way)
			way_id += 1
	return added, skipped_overlap, skipped_low


def local_xz(lat: float, lon: float, lat0: float, lon0: float) -> tuple:
	"""Lat/lon -> metros en el mapa de Godot. Es la misma proyeccion de OSM2World
	(Mercator escalada por cos(lat0), origen en el centro de <bounds>); medido
	contra el .glb, el error es menor a 1 mm. x = este, z = -norte."""
	def merc_y(lat_deg):
		return EARTH_RADIUS * math.log(math.tan(math.pi / 4 + math.radians(lat_deg) / 2))
	scale = math.cos(math.radians(lat0))
	x = EARTH_RADIUS * math.radians(lon - lon0) * scale
	z = -(merc_y(lat) - merc_y(lat0)) * scale
	return (x, z)


def osm_puntos(root, kept_ways, pos) -> list:
	"""Tiendas que ya estan en OSM (nodos o areas) con un tipo que conocemos."""
	found = []
	elements = [n for n in root.findall("node") if n.find("tag") is not None] + list(kept_ways.values())
	for elem in elements:
		tags = tags_of(elem)
		tipo = None
		if tags.get("shop") == "convenience":
			tipo = "oxxo" if "oxxo" in tags.get("brand", tags.get("name", "")).lower() else "tienda"
		elif tags.get("amenity") == "pharmacy":
			tipo = "farmacia"
		elif tags.get("amenity") == "fuel":
			tipo = "gasolinera"
		elif tags.get("amenity") in ("fast_food", "restaurant") and any(
				w in tags.get("cuisine", "") + tags.get("name", "").lower() for w in ("taco", "mexican")):
			tipo = "taqueria"
		if tipo is None:
			continue
		if elem.tag == "node":
			lat, lon = pos[elem.get("id")]
		else:
			ring = [pos[nd.get("ref")] for nd in elem.findall("nd")]
			lat = sum(p[0] for p in ring) / len(ring)
			lon = sum(p[1] for p in ring) / len(ring)
		found.append({"tipo": tipo, "lat": lat, "lon": lon, "nombre": tags.get("name", ""),
				"origen": f"osm {elem.tag}/{elem.get('id')}"})
	return found


def ring_distance(px: float, pz: float, ring: list) -> float:
	"""Distancia (m) de un punto al contorno de una casa; 0 si esta adentro."""
	if point_in_polygon(px, pz, ring):
		return 0.0
	best = math.inf
	for (ax, az), (bx, bz) in zip(ring, ring[1:]):
		if abs(ax - px) > HOUSE_SNAP_DIST + 50 or abs(az - pz) > HOUSE_SNAP_DIST + 50:
			continue
		dx, dz = bx - ax, bz - az
		t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz or 1e-9)))
		best = min(best, math.hypot(ax + t * dx - px, az + t * dz - pz))
	return best


def place_puntos(puntos, kept_ways, pos, lat0, lon0) -> list:
	"""Calcula posicion, giro y tamano de cada punto en el mapa. Si un punto cae
	sobre una casa, la quita de kept_ways para que la tienda ocupe su lote."""
	streets = []
	for way in kept_ways.values():
		if tags_of(way).get("highway") in STREET_TYPES:
			streets.append([local_xz(*pos[nd.get("ref")], lat0, lon0) for nd in way.findall("nd")])

	buildings = {}
	for way_id, way in kept_ways.items():
		if "building" in tags_of(way):
			local = [local_xz(*pos[nd.get("ref")], lat0, lon0) for nd in way.findall("nd")]
			area = abs(sum(ax * bz - bx * az for (ax, az), (bx, bz) in zip(local, local[1:]))) / 2
			if area <= MAX_SHOP_LOT:
				buildings[way_id] = local

	placed = []
	replaced_rings = []
	for punto in puntos:
		tipo = punto["tipo"]
		replaces_house = punto.get("reemplaza_casa", tipo not in NO_REPLACE_TIPOS)
		# Dos negocios en la misma casa (plaza, local con varios giros): solo cabe uno
		if replaces_house and any(ring_distance(*local_xz(punto["lat"], punto["lon"], lat0, lon0), ring) == 0.0
				for ring in replaced_rings):
			print(f"  Punto omitido, su casa ya es otra tienda: {tipo} {punto.get('nombre', '')}")
			continue
		px, pz = local_xz(punto["lat"], punto["lon"], lat0, lon0)

		# La fachada (+Z del modelo) ve hacia la calle mas cercana
		best = None
		for line in streets:
			for (ax, az), (bx, bz) in zip(line, line[1:]):
				dx, dz = bx - ax, bz - az
				length2 = dx * dx + dz * dz or 1e-9
				t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / length2))
				cx, cz = ax + t * dx, az + t * dz
				d2 = (cx - px) ** 2 + (cz - pz) ** 2
				if best is None or d2 < best[0]:
					best = (d2, cx, cz)
		rot = math.atan2(best[1] - px, best[2] - pz) if best else 0.0
		if "rotacion" in punto:
			rot = math.radians(punto["rotacion"])
		forward = (math.sin(rot), math.cos(rot))
		right = (math.cos(rot), -math.sin(rot))

		# Los puestos se recorren a la banqueta, de frente a la calle
		if tipo in NO_REPLACE_TIPOS and best and best[0] > PUESTO_STREET_DIST ** 2:
			px = best[1] - forward[0] * PUESTO_STREET_DIST
			pz = best[2] - forward[1] * PUESTO_STREET_DIST

		ancho, fondo = DEFAULT_SIZE.get(tipo, FALLBACK_SIZE)
		reemplazada = None
		if replaces_house:
			# La casa donde cae el punto o, si cae en la banqueta, la mas cercana
			best_house = None
			for way_id, local in buildings.items():
				d = ring_distance(px, pz, local)
				if d <= HOUSE_SNAP_DIST and (best_house is None or d < best_house[0]):
					best_house = (d, way_id, local)
					if d == 0.0:
						break
			if best_house:
				_, way_id, local = best_house
				# El lote de la casa, medido en los ejes de la tienda
				along = [(x - px) * right[0] + (z - pz) * right[1] for x, z in local]
				depth = [(x - px) * forward[0] + (z - pz) * forward[1] for x, z in local]
				ancho, fondo = max(along) - min(along), max(depth) - min(depth)
				cx, cz = (max(along) + min(along)) / 2, (max(depth) + min(depth)) / 2
				px += right[0] * cx + forward[0] * cz
				pz += right[1] * cx + forward[1] * cz
				reemplazada = way_id
				replaced_rings.append(local)
		if reemplazada:
			del kept_ways[reemplazada]
			del buildings[reemplazada]

		placed.append({
			"tipo": tipo,
			"nombre": punto.get("nombre", ""),
			"x": round(px, 3), "z": round(pz, 3),
			"rotacion_y": round(rot, 4),
			"ancho": round(ancho, 2), "fondo": round(fondo, 2),
			"casa_reemplazada": f"way/{reemplazada}" if reemplazada else None,
			"origen": punto.get("origen", "puntos.json"),
		})
	return placed


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--bbox", nargs=4, type=float, required=True, metavar=("SOUTH", "WEST", "NORTH", "EAST"))
	parser.add_argument("--osm", required=True, help="entrada .osm (data/map/area.osm)")
	parser.add_argument("--salida", required=True, help=".osm preparado para OSM2World")
	parser.add_argument("--overrides", help="data/map/overrides.json")
	parser.add_argument("--google", help="data/map/google_buildings.csv")
	parser.add_argument("--puntos", action="append", default=[],
		help="JSON de tiendas/puestos (se puede repetir: denue_puntos.json, puntos.json)")
	parser.add_argument("--salida-puntos", help="JSON con los puntos ya en metros, para Godot")
	args = parser.parse_args()
	south, west, north, east = args.bbox
	src, overrides_path, dst, google_path = args.osm, args.overrides, args.salida, args.google

	lat0 = (south + north) / 2.0
	lon0 = (west + east) / 2.0
	dlat = MARGIN_M / 110540.0
	dlon = MARGIN_M / (111320.0 * math.cos(math.radians(lat0)))

	def strictly_inside(lat, lon):
		return south <= lat <= north and west <= lon <= east

	def in_margin(lat, lon):
		return south - dlat <= lat <= north + dlat and west - dlon <= lon <= east + dlon

	tree = ET.parse(src)
	root = tree.getroot()

	nodes = {n.get("id"): n for n in root.findall("node")}
	pos = {i: (float(n.get("lat")), float(n.get("lon"))) for i, n in nodes.items()}

	kept_ways = {}
	next_id = SPLIT_ID_START
	for way in root.findall("way"):
		refs = [nd.get("ref") for nd in way.findall("nd")]
		root.remove(way)
		if not refs or any(r not in pos for r in refs):
			continue
		tags = tags_of(way)
		closed = len(refs) > 3 and refs[0] == refs[-1]
		if closed:
			# Areas: los edificios se quedan si tocan la zona; lo demas solo si cabe completo
			if "building" in tags or "building:part" in tags:
				keep = any(strictly_inside(*pos[r]) for r in refs)
			else:
				keep = all(in_margin(*pos[r]) for r in refs)
			if keep:
				kept_ways[way.get("id")] = way
			continue
		# Lineas (calles): se parten en tramos que quedan dentro del margen
		runs, run = [], []
		for r in refs:
			if in_margin(*pos[r]):
				run.append(r)
			else:
				if len(run) >= 2:
					runs.append(run)
				run = []
		if len(run) >= 2:
			runs.append(run)
		for i, run in enumerate(runs):
			piece = ET.Element("way", way.attrib)
			if i > 0:
				piece.set("id", str(next_id))
				next_id += 1
			for r in run:
				ET.SubElement(piece, "nd", ref=r)
			for t in way.findall("tag"):
				piece.append(t)
			kept_ways[piece.get("id")] = piece

	# Multipoligonos: solo edificios con todas sus ways completas
	kept_relations = []
	for rel in root.findall("relation"):
		root.remove(rel)
		members = [m for m in rel.findall("member") if m.get("type") == "way"]
		if "building" in tags_of(rel) and members and all(m.get("ref") in kept_ways for m in members):
			kept_relations.append(rel)

	used = {nd.get("ref") for w in kept_ways.values() for nd in w.findall("nd")}
	for node_id, node in nodes.items():
		tagged_inside = node.find("tag") is not None and strictly_inside(*pos[node_id])
		if node_id not in used and not tagged_inside:
			root.remove(node)

	# Casas de Google que OSM no tiene
	google_added = []
	if google_path and os.path.exists(google_path):
		osm_rings = []
		for way in kept_ways.values():
			if "building" in tags_of(way):
				ring = [(pos[nd.get("ref")][1], pos[nd.get("ref")][0]) for nd in way.findall("nd")]
				osm_rings.append(ring[:-1] if ring[0] == ring[-1] else ring)
		google_added, skipped_overlap, skipped_low = add_google_buildings(
			root, google_path, osm_rings,
			lambda lat, lon: strictly_inside(float(lat), float(lon)))
		for way in google_added:
			kept_ways[way.get("id")] = way
		print(f"  Google: {len(google_added)} casas nuevas, {skipped_overlap} ya estaban en OSM, {skipped_low} descartadas (confianza/area)")
		for node in root.findall("node"):
			if node.get("id") not in pos:
				pos[node.get("id")] = (float(node.get("lat")), float(node.get("lon")))

	# Tiendas y puestos: los de puntos.json mas los que ya estan en OSM
	if args.salida_puntos:
		puntos = []
		omitir = set()
		for path in args.puntos:
			if os.path.exists(path):
				with open(path, encoding="utf-8") as f:
					data = json.load(f)
				puntos += [p for p in data.get("puntos", []) if not p.get("tipo", "").startswith("_")]
				omitir.update(data.get("omitir", []))
		puntos += osm_puntos(root, kept_ways, pos)
		puntos = [p for p in puntos if p.get("origen") not in omitir]

		# Repetidos: gana el puesto a mano, luego el DENUE y al final OSM
		def priority(p):
			origen = p.get("origen", "")
			return 0 if not origen else (1 if origen.startswith("denue") else 2)

		kept_puntos = []
		for p in sorted(puntos, key=priority):
			px, pz = local_xz(p["lat"], p["lon"], lat0, lon0)
			if all(q["tipo"] != p["tipo"] or math.hypot(px - qx, pz - qz) >= DUPLICATE_DIST_TIPO.get(p["tipo"], DUPLICATE_DIST)
					for q, qx, qz in kept_puntos):
				kept_puntos.append((p, px, pz))
		print(f"  Puntos repetidos (mismo tipo a < {DUPLICATE_DIST:.0f} m, tiendas a < {DUPLICATE_DIST_TIPO['tienda']:.0f} m): {len(puntos) - len(kept_puntos)} quitados")
		placed = place_puntos([p for p, _, _ in kept_puntos], kept_ways, pos, lat0, lon0)
		os.makedirs(os.path.dirname(args.salida_puntos), exist_ok=True)
		with open(args.salida_puntos, "w", encoding="utf-8") as f:
			json.dump({"puntos": placed}, f, ensure_ascii=False, indent="\t")
		replaced = sum(1 for p in placed if p["casa_reemplazada"])
		print(f"  Puntos: {len(placed)} ({replaced} reemplazan una casa) -> {args.salida_puntos}")

	filled = 0
	for way in kept_ways.values():
		filled += fill_building(way, "way")
	for rel in kept_relations:
		filled += fill_building(rel, "relation")

	# Correcciones a mano: {"way/123": {"building:levels": "2", "building:colour": "#c96f4a"}}
	# Un valor null borra la etiqueta. Las llaves que empiezan con "_" se ignoran.
	by_key = {"way/" + i: w for i, w in kept_ways.items()}
	by_key.update({"relation/" + r.get("id"): r for r in kept_relations})
	overrides = {}
	if overrides_path and os.path.exists(overrides_path):
		with open(overrides_path, encoding="utf-8") as f:
			overrides = json.load(f)
	applied = 0
	for key, new_tags in overrides.items():
		if key.startswith("_"):
			continue
		elem = by_key.get(key)
		if elem is None:
			print(f"AVISO: override {key} no existe en la zona", file=sys.stderr)
			continue
		for k, v in new_tags.items():
			set_tag(elem, k, v)
		applied += 1

	for way in kept_ways.values():
		root.append(way)
	for rel in kept_relations:
		root.append(rel)

	# OSM2World centra el modelo en <bounds>, asi el origen queda en el centro de la zona
	for old in root.findall("bounds"):
		root.remove(old)
	bounds = ET.Element("bounds", minlat=str(south), minlon=str(west), maxlat=str(north), maxlon=str(east))
	root.insert(0, bounds)

	tree.write(dst, encoding="UTF-8", xml_declaration=True)

	buildings = sum(1 for e in list(kept_ways.values()) + kept_relations if "building" in tags_of(e))
	print(f"OK: {dst}")
	print(f"  ways: {len(kept_ways)}  edificios: {buildings}  con pisos inventados: {filled}  overrides: {applied}")


if __name__ == "__main__":
	main()
