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
  Tambien pone altos en las esquinas.
- Parte la zona en manzanas (lo que encierran las calles) y le da a cada una la
  colonia que mas negocios del DENUE tiene ahi (data/map/denue_colonias.json).
- En las colonias de data/map/casas.json cambia las casas por modelos 3D: parte
  las hileras en lotes, alinea las fachadas de cada cuadra y escribe
  resources/map/casas_mapa.json para MapCasas.gd.
- Deduce los cotos (calles privadas o con pluma) y pone bardas y mallas en su
  contorno, en los baldios y alrededor de las bodegas
  (resources/map/bardas_mapa.json para MapBardas.gd).

Uso: ver build_glb.sh (python3 prepare_osm.py --help)
"""

import argparse
import array
import collections
import csv
import json
import math
import os
import random
import re
import struct
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

# Colores de las casas modelo (MapCasas): mas vivos que PALETTE, porque el shader
# los multiplica por la sombra de la textura y la niebla los deslava
CASA_PALETTE = [
	"#e05a47",  # rojo
	"#f2994a",  # naranja
	"#f2c94c",  # amarillo
	"#7cc06a",  # verde
	"#3fa7b5",  # turquesa
	"#5b8fd9",  # azul
	"#d9608f",  # rosa mexicano
	"#a47ad1",  # morado
	"#e8d7b9",  # crema
	"#f7f4ec",  # blanco
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

# Tamano (ancho, fondo en metros) cuando el punto no cae sobre una casa. El puesto de
# tacos (MapPuntos._make_puesto_tacos): el carrito y el taquero detras
DEFAULT_SIZE = {"puesto_tacos": (2.6, 1.6), "puesto": (2.5, 2.0)}
FALLBACK_SIZE = (8.0, 10.0)

# Distancia (m) del eje de la calle a la que se ponen los puestos (en la banqueta)
PUESTO_STREET_DIST = 4.5
# Lo que el frente de un puesto queda detras de la guarnicion (m)
PUESTO_GUARNICION = 0.3

# Si una tienda no cae sobre una casa (el DENUE suele ponerla en la banqueta),
# toma la casa mas cercana a menos de esto (m)
HOUSE_SNAP_DIST = 15.0

# Edificios mas grandes que esto (m2) son plazas o manzanas enteras mal trazadas:
# una tienda no los reemplaza
MAX_SHOP_LOT = 300.0

# De dos negocios del mismo tipo a menos de esto (m) solo se deja uno
# (repetidos entre DENUE y OSM, o varios abarrotes pegados)
DUPLICATE_DIST = 40.0
# Radio propio por tipo: los abarrotes sobran aun con DUPLICATE_DIST; las farmacias
# van todas (solo se junta la misma farmacia que viene del DENUE y de OSM)
DUPLICATE_DIST_TIPO = {"abarrotes": 80.0, "farmacia": 15.0}
# Los repetidos se buscan por familia: el local de tacos y el puesto de tacos son el
# mismo giro y a menos de DUPLICATE_DIST gana el local
FAMILIA = {"puesto_tacos": "taqueria"}
# Tipos que ya no se dibujan (de OSM o de puntos.json viejos)
TIPOS_QUITADOS = {"tortilleria"}
# Nombres de licoreria en una tienda de OSM o de puntos.json (como fetch_denue.LICORERIA)
LICORERIA = re.compile(r"\b(DEP[OÓ]SITO|MODELORAMA|SIX|VINOS|LICORES?|LICORER[IÍ]A|CERVEZAS?|EXPENDIO)\b")
# Comida que si es taqueria (como fetch_denue.TACOS)
TACOS = re.compile(r"TACO|TAQUER|CARNITAS|BARBACOA|BIRRI|PASTOR|VAPOR")

# Marcas reales -> parodia (solo el nombre; los modelos aun traen su marca):
# (regex sin importar mayusculas, reemplazo). El nombre entero si es la cadena.
MARCAS_PARODIA = [
	(r"\bfarmacias?\s+(de\s+)?similares\b.*", "Farmacias Dr Simio"),
	(r"\bsimilares\b", "Dr Simio"),
	(r"\bfarmacias?\s+guadalajara\b.*", "Farmacias Guadalaraja"),
	(r"\boxxo\b", "Oxo"),
	(r"\bpemex\b", "Perez"),
]

# Giros del juego (docs/especificaciones.md 4.6): tipo de dibujo -> giro. Solo los
# negocios con giro pueden ser interactivos (marcador amarillo, minimapa)
GIROS = {
	"oxxo": "oxxo", "abarrotes": "abarrotes", "licoreria": "licoreria",
	"farmacia": "farmacia",
	"taqueria": "taqueria", "puesto_tacos": "puesto_tacos", "gasolinera": "gasolinera",
	"ferreteria": "ferreteria", "purificadora": "purificadora", "puesto": "tejuino",
	"punto": "punto",
}
# Se compra afuera, con el que atiende (sin interior)
GIRO_AIRE_LIBRE = {"puesto_tacos", "tejuino", "punto"}
# Dos interactivos del mismo giro, a mas de esto (m); los demas se ven igual pero sin marcador
INTERACTIVO_DIST = 80.0
INTERACTIVO_DIST_GIRO = {"abarrotes": 150.0, "punto": 0.0}  # el punto ya va uno por colonia
# Ganan el marcador primero los que tienen modelo de marca
INTERACTIVO_PRIORIDAD = ["oxxo", "farmacia", "gasolinera"]

# Casas-local (MapPuntos.GIROS_LOCAL y la purificadora) que van dentro de la hilera de
# casas, con la fachada al pano de las vecinas: frente y fondo del lote (m), min y max
LOCALES_HILERA = {"abarrotes", "licoreria", "oxxo", "farmacia", "taqueria", "ferreteria", "purificadora"}
# Un local que choca con otro lote o negocio se recorre a un lado de lo que estorba,
# hasta LOCAL_INTENTOS veces; si no cabe se queda en su lugar si ahi no estorba, y si
# no, no se pone
LOCAL_INTENTOS = 3
# Pisos de un local: los de la casa modelo mas cercana a menos de esto (m)
LOCAL_PISOS_VECINA = 25.0
LOCAL_ANCHO = (4.5, 9.0)
LOCAL_FONDO = (6.0, 14.0)


# Calles que separan manzanas (las de servicio y andadores quedan dentro de los cotos)
BLOCK_STREET_TYPES = {"primary", "secondary", "tertiary", "unclassified", "residential", "living_street"}
# Resolucion (m por celda) y medio grosor (m) de las calles al dibujar las manzanas.
# Las calles se engordan para cerrar los huecos donde OSM no une dos calles.
BLOCK_CELL = 1.0
BLOCK_STREET_HALF = 4.0
# Las privadas sin salida dejarian manzanas enormes: se alargan hasta la calle
# siguiente si esta a menos de esto (m)
BLOCK_DEAD_END = 50.0

# Votacion de la colonia: negocios mas cercanos que cuentan y distancia maxima (m)
COLONIA_VECINOS = 9
COLONIA_MAX_DIST = 250.0

# Casas modelo: cada cara de cuadra se llena de casas pegadas donde hay casas;
# un hueco de mas de HUECO_MAX m sin casas (baldio, parque) se deja vacio
HUECO_MAX = 10.0
# Escala de los modelos para llenar el tramo (como MapCasas.ESCALA_MIN/MAX)
CASA_ESCALA = (0.8, 1.25)
# Lo que se encoge un lote antes de ver si choca con otro lote o con otra calle (m)
LOTE_MARGEN = 0.2
# Dos lotes cuyas fachadas forman mas de ~135 grados se dan la espalda y se
# pueden encimar por atras (coseno del angulo)
ESPALDA_COS = -0.7
# Frente de una casa cuando no hay modelo (m)
ANCHO_LOTE_TIPICO = 6.5
# La fachada nunca se pega mas que esto al eje de la calle (m)
SETBACK_MIN = 3.5
# Casas mas lejos de una calle que esto (m) se quedan como estan
CASA_MAX_CALLE = 30.0
# Huellas fuera de este rango (m2) no son casas (tinacos, bodegas, escuelas)
CASA_AREA = (25.0, 1500.0)
CASA_FONDO_MIN = 6.0

# Bodegas huecas (MapBodegas.gd): todo edificio de BODEGA_COLONIAS de al menos
# BODEGA_AREA_MIN_INDUSTRIAL m2 y, en las demas colonias, las huellas sin nombre de
# al menos BODEGA_AREA_MIN m2. Las de mas de BODEGA_LARGO_MAX m se parten en naves.
BODEGA_COLONIAS = {"AGUA BLANCA INDUSTRIAL"}
BODEGA_TIPOS = {"yes", "warehouse", "industrial", "commercial"}
BODEGA_AREA_MIN_INDUSTRIAL = 100.0
BODEGA_AREA_MIN = 600.0
BODEGA_LADO_MIN = 8.0
BODEGA_LARGO_MAX = 70.0
BODEGA_PASILLO = 6.0
# Lo que se deja de banqueta (m) desde la orilla del arroyo cuando una bodega se
# sale a la calle: las de Agua Blanca estan pegadas a la calle y con la banqueta
# completa quedaban de menos de BODEGA_LADO_MIN
BODEGA_BANQUETA = 0.8
# Lamina: gris, azul, crema, oxido, verde
BODEGA_COLORES = ["#9a9c9e", "#5d7891", "#c9bf9f", "#8a5a3c", "#6f8466"]

# Altos: uno de cada ALTO_CADA esquinas, ALTO_ANTES m antes del cruce
ALTO_CADA = 20
ALTO_ANTES = 6.0

# Semilla fija: los altos salen igual en cada corrida
SEMILLA_PROPS = 2026

# Calles: ancho del arroyo (m, sin banquetas) y de cada banqueta por tipo. Si las
# fachadas de la calle estan mas cerca, se angostan (primero la banqueta, hasta
# BANQUETA_MIN, luego el arroyo, hasta ARROYO_MIN_MEDIO de cada lado del eje)
ANCHO_CALLE = {
	"primary": 14.0, "primary_link": 7.0, "secondary": 12.0, "tertiary": 10.0,
	"residential": 7.0, "unclassified": 6.0, "living_street": 6.0, "service": 4.0,
}
BANQUETA = {"primary": 2.0, "secondary": 2.0, "tertiary": 2.0, "residential": 1.5,
	"unclassified": 1.2, "living_street": 1.2}
BANQUETA_MIN = 0.9
ARROYO_MIN_MEDIO = 2.5
# Espacio que se deja entre la banqueta y la fachada (m)
FACHADA_HOLGURA = 0.3

# Camellones: dos calles de un sentido, con el mismo nombre, en sentidos opuestos
# y a esta distancia (m) entre ejes. Cada una lleva la mitad del arroyo mas 1 m.
CAMELLON_DIST = (6.0, 40.0)
CAMELLON_MUESTRA = 4.0
# No se dibuja camellon a menos de esto (m) de una calle que lo atraviesa
CAMELLON_CRUCE = 6.0
CAMELLON_ANCHO_MIN = 1.0
# Guarnicion del camellon: una barda de concreto bajita
CAMELLON_GUARNICION = 0.12
CAMELLON_ID_START = 3 * 10**15
CAMELLON_FUENTE = "camellon taquito"

# Bardas y mallas (place_bardas -> resources/map/bardas_mapa.json, MapBardas.gd)
PLUMAS = {"gate", "lift_gate"}
# Alumbrado publico (place_alumbrado -> resources/map/alumbrado_mapa.json, MapAlumbrado.gd).
# OSM no tiene postes de luz aqui (highway=street_lamp): van cada ALUMBRADO_PASO m en
# la banqueta, junto a la guarnicion; en las avenidas alternando de lado, en las demas
# de un solo lado; en las avenidas con camellon, de doble brazo en el camellon.
ALUMBRADO_PASO = 30.0
ALUMBRADO_AVENIDAS = {"primary", "secondary", "tertiary"}
# (alto del poste, largo del brazo) en m
ALUMBRADO_POSTE = (8.0, 1.5)
ALUMBRADO_POSTE_AVENIDA = (10.0, 2.5)
# Distancia del poste a la orilla del arroyo (m)
ALUMBRADO_GUARNICION = 0.4
# Ningun poste a menos de esto (m) de una esquina, ni de un alto, puesto, pluma o caseta
ALUMBRADO_ESQUINA = 6.0
ALUMBRADO_ESTORBO = 3.0
# Camellones mas angostos que esto (m) no llevan postes
ALUMBRADO_CAMELLON_MIN = 1.2

# Plumas a menos de esto (m) y del mismo coto son un solo acceso (una caseta)
ACCESO_RADIO = 25.0
# De un acceso solo quedan las plumas a lo mas esto (m) mas lejos de la calle publica que
# la mas cercana (la linea de afuera)
ACCESO_LINEA = 3.0
# La caseta va en la isleta entre dos carriles si queda al menos este hueco (m)
CASETA_ISLETA = 2.5
# Distancia del centro de la caseta a la orilla del carril, cuando va a un lado
CASETA_LADO = 1.9
# Una manzana es de un coto si al menos esta fraccion de su orilla da a calles del coto
COTO_FRACCION = 0.25
# Manzanas mas grandes (m2) no son de un coto (el terreno abierto alrededor de la zona)
COTO_MANZANA_MAX = 60000.0
# Una manzana de un coto con a lo mas este fondo (m) desde sus calles es toda del coto;
# si es mas honda, cada casa va con la calle (del coto o publica) mas cercana
COTO_FONDO = 24.0
# ... salvo que en la parte que da a la calle publica haya a lo mas esta fraccion de sus casas
COTO_CASAS_FUERA = 0.15
# Cada cuanto (m) se prueba por donde pasa una barda; tramos mas cortos que BARDA_MIN no van
BARDA_PASO = 1.0
BARDA_MIN = 4.0
BARDA_SIMPLIFICAR = 0.3
# Baldio: tramo de al menos BALDIO_MIN m sin nada en BALDIO_FONDO m hacia adentro
BALDIO_MIN = 12.0
BALDIO_FONDO = 15.0
# Distancia (m) de la malla a las naves de una bodega
BODEGA_MALLA = 3.0
# Pasto del satelite (satelite_pasto.png >= 0.6): un baldio con al menos la mitad
# de su franja con pasto es area verde y no lleva malla
VERDE_SATELITE = 153
VERDE_FRACCION = 0.5
# Areas verdes de OSM: nunca llevan barda
VERDES = {"leisure": {"park", "garden", "playground", "pitch", "recreation_ground"},
	"landuse": {"grass", "recreation_ground", "meadow", "village_green"}}


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
		elif tags.get("shop") in ("alcohol", "beverages"):
			tipo = "licoreria"
		elif tags.get("amenity") == "pharmacy":
			tipo = "farmacia"
		elif tags.get("amenity") == "fuel":
			tipo = "gasolinera"
		elif tags.get("amenity") in ("fast_food", "restaurant") and (
				"taco" in tags.get("cuisine", "") or TACOS.search(tags.get("name", "").upper())):
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


def calle_cercana(px, pz, streets):
	"""(d2, cx, cz, way_id) del punto de calle mas cercano a (px, pz)."""
	best = None
	for street_id, line in streets:
		for (ax, az), (bx, bz) in zip(line, line[1:]):
			dx, dz = bx - ax, bz - az
			length2 = dx * dx + dz * dz or 1e-9
			t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / length2))
			cx, cz = ax + t * dx, az + t * dz
			d2 = (cx - px) ** 2 + (cz - pz) ** 2
			if best is None or d2 < best[0]:
				best = (d2, cx, cz, street_id)
	return best


def subtipo(p) -> dict:
	"""El punto con su tipo de dibujo: una tienda es licoreria si el nombre lo dice, si
	no abarrotes; toda farmacia es `farmacia` (tambien las farmacia_similares y
	farmacia_local de antes, en puntos.json)."""
	p = dict(p)
	nombre = p.get("nombre", "").upper()
	if p["tipo"] == "tienda":
		p["tipo"] = "licoreria" if LICORERIA.search(nombre) else "abarrotes"
	elif p["tipo"].startswith("farmacia"):
		p["tipo"] = "farmacia"
	return p


def parodia(nombre: str) -> str:
	"""El nombre con las marcas reales cambiadas por su parodia (MARCAS_PARODIA),
	respetando si venia en mayusculas."""
	for patron, reemplazo in MARCAS_PARODIA:
		nombre = re.sub(patron, lambda m: reemplazo.upper() if m.group(0).isupper() else reemplazo,
			nombre, flags=re.IGNORECASE)
	return nombre


def marcar_interactivos(puntos) -> collections.Counter:
	"""Pone `giro`, `interactivo` y `aire_libre` a cada negocio. Del mismo giro solo
	es interactivo uno por radio (INTERACTIVO_DIST)."""
	def orden(p):
		tipo = p["tipo"]
		return (INTERACTIVO_PRIORIDAD.index(tipo) if tipo in INTERACTIVO_PRIORIDAD else len(INTERACTIVO_PRIORIDAD),
			seed(p.get("origen") or p.get("nombre", "")), p["x"], p["z"])

	elegidos = collections.defaultdict(list)
	conteo = collections.Counter()
	for p in sorted(puntos, key=orden):
		giro = GIROS.get(p["tipo"])
		p["giro"] = giro
		p["aire_libre"] = giro in GIRO_AIRE_LIBRE
		radio = INTERACTIVO_DIST_GIRO.get(giro, INTERACTIVO_DIST)
		p["interactivo"] = giro is not None and all(math.hypot(p["x"] - x, p["z"] - z) >= radio for x, z in elegidos[giro])
		if p["interactivo"]:
			elegidos[giro].append((p["x"], p["z"]))
			conteo[giro] += 1
	return conteo


def place_puntos(puntos, kept_ways, pos, lat0, lon0, perfil=None) -> list:
	"""Calcula posicion, giro y tamano de cada punto en el mapa. Si un punto cae
	sobre una casa, la quita de kept_ways para que la tienda ocupe su lote."""
	perfil = perfil or {}
	streets = []
	for way_id, way in kept_ways.items():
		if tags_of(way).get("highway") in STREET_TYPES:
			streets.append((way_id, [local_xz(*pos[nd.get("ref")], lat0, lon0) for nd in way.findall("nd")]))

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
		best = calle_cercana(px, pz, streets)
		rot = math.atan2(best[1] - px, best[2] - pz) if best else 0.0
		if "rotacion" in punto:
			rot = math.radians(punto["rotacion"])
		forward = (math.sin(rot), math.cos(rot))
		right = (math.cos(rot), -math.sin(rot))

		# Los puestos van en la banqueta, de frente a la calle (su frente pasando la
		# guarnicion), tambien los que el DENUE pone a media calle
		ancho, fondo = DEFAULT_SIZE.get(tipo, FALLBACK_SIZE)
		dist = PUESTO_STREET_DIST
		if best and best[3] in perfil:
			dist = max(dist, perfil[best[3]][0] + PUESTO_GUARNICION + fondo / 2)
		if tipo in NO_REPLACE_TIPOS and best:
			if best[0] < 0.01:
				# Justo en el eje: se toma el lado izquierdo de la calle
				line = dict(streets)[best[3]]
				seg = min(zip(line, line[1:]), key=lambda s: math.hypot(s[0][0] - best[1], s[0][1] - best[2])
					+ math.hypot(s[1][0] - best[1], s[1][1] - best[2]))
				length = math.hypot(seg[1][0] - seg[0][0], seg[1][1] - seg[0][1]) or 1.0
				rot = math.atan2((seg[1][1] - seg[0][1]) / length, -(seg[1][0] - seg[0][0]) / length)
				forward = (math.sin(rot), math.cos(rot))
			px = best[1] - forward[0] * dist
			pz = best[2] - forward[1] * dist

		reemplazada = None
		if replaces_house:
			# La casa donde cae el punto o, si cae en la banqueta, la mas cercana de
			# su lado de la calle; si cae en el arroyo, la mas cercana de cualquier lado
			en_arroyo = best and best[3] in perfil and best[0] < perfil[best[3]][0] ** 2
			best_house = None
			for way_id, local in buildings.items():
				d = ring_distance(px, pz, local)
				if d > HOUSE_SNAP_DIST:
					continue
				if best and not en_arroyo and d > 0.0:
					hx, hz = centroid(local[:-1])
					if (hx - best[1]) * (px - best[1]) + (hz - best[2]) * (pz - best[2]) < 0:
						d += HOUSE_SNAP_DIST
				if best_house is None or d < best_house[0]:
					best_house = (d, way_id, local)
					if d == 0.0:
						break
			if best_house:
				_, way_id, local = best_house
				# El giro se vuelve a sacar desde la casa: el punto pudo estar del otro lado
				if "rotacion" not in punto:
					hx, hz = centroid(local[:-1])
					casa_calle = calle_cercana(hx, hz, streets)
					if casa_calle:
						rot = math.atan2(casa_calle[1] - hx, casa_calle[2] - hz)
						forward = (math.sin(rot), math.cos(rot))
						right = (math.cos(rot), -math.sin(rot))
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


# Lo que se encoge la huella de un negocio antes de buscar casas encimadas (m), para
# no quitar la vecina que solo toca la orilla
HUELLA_MARGEN = 0.3


def huella_negocio(punto, huellas):
	"""Esquinas (x, z) de lo que ocupa un negocio en el juego (como MapPuntos.gd): el
	modelo escalado a su frente, o el local armado, con la fachada en la orilla del
	lote que da a la calle y creciendo hacia atras. None para los altos."""
	tipo = punto["tipo"]
	if tipo in ("alto", "punto"):
		return None
	ancho, fondo = punto["ancho"], punto["fondo"]
	# Los locales primero: un huellas_tiendas.json viejo aun trae modelos de oxxo o farmacia
	if tipo in huellas.get("_locales", []):
		w, d = max(ancho, huellas["_local_min"][0]), max(fondo, huellas["_local_min"][1])
	elif tipo in huellas.get("modelos", {}):
		w, d = huellas["modelos"][tipo]
	else:
		w, d = ancho, fondo
	frente = fondo / 2.0
	return rectangulo(punto["x"], punto["z"], punto["rotacion_y"], w - 2 * HUELLA_MARGEN,
		frente - HUELLA_MARGEN, frente - d + HUELLA_MARGEN)


def alejar_de_calles(punto, huellas, calles, perfil, ignorar=None, vueltas=4) -> float:
	"""Empuja un negocio ya colocado para que su huella no pise el arroyo ni la
	banqueta de ninguna calle (DENUE pone algunos a media calle o en la esquina):
	queda con la fachada en la orilla de la banqueta. `ignorar`: la calle de un
	puesto, que si va en la banqueta. Devuelve lo que se movio (m)."""
	x0, z0 = punto["x"], punto["z"]
	for _ in range(vueltas):
		huella = huella_negocio(punto, huellas)
		if not huella:
			break
		mx = sum(p[0] for p in huella) / len(huella)
		mz = sum(p[1] for p in huella) / len(huella)
		peor = None
		for x, z in huella + [((huella[0][0] + huella[1][0]) / 2, (huella[0][1] + huella[1][1]) / 2)]:
			for _, way_id, (qx, qz), (dx, dz) in calles.cercanos(x, z, 25.0):
				if way_id == ignorar:
					continue
				# Normal del tramo hacia el centro del negocio
				nx, nz = -dz, dx
				if (mx - qx) * nx + (mz - qz) * nz < 0:
					nx, nz = -nx, -nz
				# Solo si la esquina queda frente al tramo, no pasando su punta
				if abs((x - qx) * dx + (z - qz) * dz) > 0.5:
					continue
				medio, izq, der = perfil.get(way_id, (SETBACK_MIN - 1.5, 0.0, 0.0))
				falta = medio + max(izq, der) + FACHADA_HOLGURA - ((x - qx) * nx + (z - qz) * nz)
				if falta > 0.05 and (peor is None or falta > peor[0]):
					peor = (falta, nx, nz)
		if not peor:
			break
		falta, nx, nz = peor
		punto["x"] = round(punto["x"] + nx * falta, 3)
		punto["z"] = round(punto["z"] + nz * falta, 3)
	return math.hypot(punto["x"] - x0, punto["z"] - z0)


def rectangulo(x, z, rot, ancho, z_frente, z_fondo) -> list:
	"""Esquinas de un rectangulo en los ejes de un lote girado `rot` (+Z = frente)."""
	c, s = math.cos(rot), math.sin(rot)
	return [(x + lx * c + lz * s, z - lx * s + lz * c)
		for lx, lz in ((-ancho / 2, z_frente), (ancho / 2, z_frente), (ancho / 2, z_fondo), (-ancho / 2, z_fondo))]


def se_enciman(a, b) -> bool:
	"""Si dos poligonos (listas de (x, z), sin repetir el primero) se tocan por dentro."""
	if max(p[0] for p in a) < min(p[0] for p in b) or max(p[0] for p in b) < min(p[0] for p in a) \
			or max(p[1] for p in a) < min(p[1] for p in b) or max(p[1] for p in b) < min(p[1] for p in a):
		return False
	if any(point_in_polygon(x, z, b) for x, z in a) or any(point_in_polygon(x, z, a) for x, z in b):
		return True

	def cruza(p1, p2, p3, p4):
		def lado(o, p, q):
			return (p[0] - o[0]) * (q[1] - o[1]) - (p[1] - o[1]) * (q[0] - o[0])
		return lado(p3, p4, p1) * lado(p3, p4, p2) < 0 and lado(p1, p2, p3) * lado(p1, p2, p4) < 0

	return any(cruza(a[i], a[(i + 1) % len(a)], b[j], b[(j + 1) % len(b)])
		for i in range(len(a)) for j in range(len(b)))


class Rejilla:
	"""Indice por celdas de poligonos, para ver rapido con cuales se enciman."""

	CELDA = 32.0

	def __init__(self, poligonos=()):
		self.celdas = collections.defaultdict(list)
		self.poligonos = []
		self.datos = []
		for poly in poligonos:
			self.agregar(poly)

	def _celdas_de(self, poly):
		x0, x1 = min(p[0] for p in poly), max(p[0] for p in poly)
		z0, z1 = min(p[1] for p in poly), max(p[1] for p in poly)
		for cx in range(int(x0 // self.CELDA), int(x1 // self.CELDA) + 1):
			for cz in range(int(z0 // self.CELDA), int(z1 // self.CELDA) + 1):
				yield (cx, cz)

	def agregar(self, poly, dato=None) -> None:
		self.poligonos.append(poly)
		self.datos.append(dato)
		for celda in self._celdas_de(poly):
			self.celdas[celda].append(len(self.poligonos) - 1)

	def chocan(self, poly) -> list:
		"""Los poligonos con que se encima `poly`."""
		indices = {i for celda in self._celdas_de(poly) for i in self.celdas.get(celda, ())}
		return [self.poligonos[i] for i in sorted(indices) if se_enciman(poly, self.poligonos[i])]

	def encima(self, poly, cuenta=None) -> bool:
		"""Si `poly` se encima con alguno; `cuenta(dato)` puede dejar pasar algunos."""
		vistos = set()
		for celda in self._celdas_de(poly):
			for i in self.celdas.get(celda, ()):
				if i not in vistos:
					vistos.add(i)
					if (cuenta is None or cuenta(self.datos[i])) and se_enciman(poly, self.poligonos[i]):
						return True
		return False


def quitar_edificios_encimados(kept_ways, pos, lat0, lon0, poligonos) -> int:
	"""Quita de kept_ways los edificios que se enciman con alguno de `poligonos`
	(huellas de negocios, lotes de casas modelo)."""
	rejilla = Rejilla(poligonos)
	quitar = []
	for way_id, way in kept_ways.items():
		if "building" not in tags_of(way):
			continue
		ring = [local_xz(*pos[nd.get("ref")], lat0, lon0) for nd in way.findall("nd")]
		ring = ring[:-1] if ring[0] == ring[-1] else ring
		if rejilla.encima(ring):
			quitar.append(way_id)
	for way_id in quitar:
		del kept_ways[way_id]
	return len(quitar)


def street_lines(kept_ways, pos, lat0, lon0, types) -> list:
	"""[(way_id, [(x, z), ...], [node_id, ...])] de las calles de esos tipos."""
	lines = []
	for way_id, way in kept_ways.items():
		if tags_of(way).get("highway") in types:
			refs = [nd.get("ref") for nd in way.findall("nd")]
			lines.append((way_id, [local_xz(*pos[r], lat0, lon0) for r in refs], refs))
	return lines


class Manzanas:
	"""Las calles dibujadas en una rejilla de BLOCK_CELL m; cada region que
	encierran es una manzana (se etiquetan con una inundacion)."""

	def __init__(self, lines, x0, z0, x1, z1):
		self.x0, self.z0 = x0, z0
		self.w = int((x1 - x0) / BLOCK_CELL) + 1
		self.h = int((z1 - z0) / BLOCK_CELL) + 1
		street = bytearray(self.w * self.h)
		self.street = street
		for _, line, _ in lines:
			for a, b in zip(line, line[1:]):
				self._draw(a, b)

		# Privadas: extremos de calle que no tocan otra calle se alargan en su
		# misma direccion hasta topar con una calle
		grado = collections.Counter()
		for _, _, refs in lines:
			grado[refs[0]] += 1
			grado[refs[-1]] += 1
			for r in refs[1:-1]:
				grado[r] += 2
		for _, line, refs in lines:
			for end, prev, ref in ((line[-1], line[-2], refs[-1]), (line[0], line[1], refs[0])):
				if grado[ref] != 1:
					continue
				length = math.hypot(end[0] - prev[0], end[1] - prev[1])
				if length < 1e-6:
					continue
				dx, dz = (end[0] - prev[0]) / length, (end[1] - prev[1]) / length
				d = BLOCK_STREET_HALF + 1.5
				while d <= BLOCK_DEAD_END:
					cx, cz = self.cell(end[0] + dx * d, end[1] + dz * d)
					if not (0 <= cx < self.w and 0 <= cz < self.h):
						break
					if street[cz * self.w + cx]:
						self._draw(end, (end[0] + dx * d, end[1] + dz * d))
						break
					d += BLOCK_CELL / 2
		# 0 = calle, 1.. = manzana
		labels = array.array("i", bytes(4 * self.w * self.h))
		count = 0
		w, h = self.w, self.h
		for start in range(w * h):
			if street[start] or labels[start]:
				continue
			count += 1
			labels[start] = count
			stack = [start]
			while stack:
				i = stack.pop()
				x = i % w
				for j in (i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w):
					if 0 <= j < w * h and not street[j] and not labels[j]:
						labels[j] = count
						stack.append(j)
		self.labels = labels
		self.count = count

	def _draw(self, a, b) -> None:
		r = int(math.ceil(BLOCK_STREET_HALF / BLOCK_CELL))
		(ax, az), (bx, bz) = a, b
		steps = int(math.hypot(bx - ax, bz - az) / (BLOCK_CELL / 2)) + 1
		for i in range(steps + 1):
			t = i / steps
			cx, cz = self.cell(ax + (bx - ax) * t, az + (bz - az) * t)
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if 0 <= cx + dx < self.w and 0 <= cz + dz < self.h:
						self.street[(cz + dz) * self.w + cx + dx] = 1

	def cell(self, x, z) -> tuple:
		return int((x - self.x0) / BLOCK_CELL), int((z - self.z0) / BLOCK_CELL)

	def at(self, x, z) -> int:
		"""Manzana del punto; si cae en la calle, la mas cercana (hasta 6 celdas)."""
		cx, cz = self.cell(x, z)
		for radius in range(7):
			for dz in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if max(abs(dx), abs(dz)) != radius:
						continue
					if 0 <= cx + dx < self.w and 0 <= cz + dz < self.h:
						label = self.labels[(cz + dz) * self.w + cx + dx]
						if label:
							return label
		return 0


def colonias_por_manzana(manzanas, negocios, casas_xz, manuales) -> dict:
	"""Manzana -> colonia. Gana la colonia con mas negocios del DENUE dentro de la
	manzana; si no tiene, votan sus casas con sus negocios mas cercanos."""
	votos = collections.defaultdict(collections.Counter)
	for x, z, colonia in negocios:
		label = manzanas.at(x, z)
		if label:
			votos[label][colonia] += 1
	result = {label: c.most_common(1)[0][0] for label, c in votos.items()}

	grid = collections.defaultdict(list)
	for x, z, colonia in negocios:
		grid[(int(x // 100), int(z // 100))].append((x, z, colonia))
	sin_negocios = collections.defaultdict(collections.Counter)
	for x, z in casas_xz:
		label = manzanas.at(x, z)
		if not label or label in result:
			continue
		cerca = []
		for radius in range(1, 4):
			cx, cz = int(x // 100), int(z // 100)
			cerca = [(math.hypot(nx - x, nz - z), colonia)
				for dx in range(-radius, radius + 1) for dz in range(-radius, radius + 1)
				for nx, nz, colonia in grid.get((cx + dx, cz + dz), ())]
			if len(cerca) >= COLONIA_VECINOS:
				break
		cerca.sort()
		cerca = [c for c in cerca[:COLONIA_VECINOS] if c[0] <= COLONIA_MAX_DIST]
		if cerca:
			sin_negocios[label][collections.Counter(c for _, c in cerca).most_common(1)[0][0]] += 1
	for label, c in sin_negocios.items():
		result[label] = c.most_common(1)[0][0]
	for (x, z), colonia in manuales:
		label = manzanas.at(x, z)
		if label:
			result[label] = colonia
	return result


def write_png(path, width, height, rgb: bytearray) -> None:
	raw = b"".join(b"\0" + bytes(rgb[y * width * 3:(y + 1) * width * 3]) for y in range(height))

	def chunk(kind, data):
		body = kind + data
		return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

	with open(path, "wb") as f:
		f.write(b"\x89PNG\r\n\x1a\n")
		f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
		f.write(chunk(b"IDAT", zlib.compress(raw, 6)))
		f.write(chunk(b"IEND", b""))


def png_colonias(path, manzanas, colonia_de, casas) -> None:
	"""Manzanas pintadas por colonia (calles negras, casas mas oscuras)."""
	nombres = sorted(set(colonia_de.values()))
	colores = {}
	for nombre in nombres:
		s = seed(nombre)
		colores[nombre] = (80 + s % 160, 80 + (s >> 8) % 160, 80 + (s >> 16) % 160)
	w, h = manzanas.w, manzanas.h
	rgb = bytearray(w * h * 3)
	por_label = [(235, 235, 235)] * (manzanas.count + 1)
	for label, nombre in colonia_de.items():
		por_label[label] = colores[nombre]
	for i in range(w * h):
		if manzanas.street[i]:
			continue
		rgb[i * 3:i * 3 + 3] = bytes(por_label[manzanas.labels[i]])
	for ring in casas:
		xs = [p[0] for p in ring]
		zs = [p[1] for p in ring]
		ax, az = manzanas.cell(min(xs), min(zs))
		bx, bz = manzanas.cell(max(xs), max(zs))
		for cz in range(max(az, 0), min(bz + 1, h)):
			for cx in range(max(ax, 0), min(bx + 1, w)):
				x = manzanas.x0 + (cx + 0.5) * BLOCK_CELL
				z = manzanas.z0 + (cz + 0.5) * BLOCK_CELL
				if point_in_polygon(x, z, ring):
					i = (cz * w + cx) * 3
					rgb[i:i + 3] = bytes(c * 3 // 5 for c in rgb[i:i + 3])
	write_png(path, w, h, rgb)
	print(f"  Colonias: {path}")
	for nombre in nombres:
		print(f"    rgb{colores[nombre]}  {nombre}")


def ring_area(local) -> float:
	return abs(sum(ax * bz - bx * az for (ax, az), (bx, bz) in zip(local, local[1:]))) / 2


def nearest_segment(px, pz, lines, max_dist):
	"""(dist, way_id, (ax, az), (dx, dz) unitario, largo) del tramo de calle mas cercano."""
	best = None
	for way_id, line, _ in lines:
		for (ax, az), (bx, bz) in zip(line, line[1:]):
			if min(ax, bx) - max_dist > px or px > max(ax, bx) + max_dist:
				continue
			if min(az, bz) - max_dist > pz or pz > max(az, bz) + max_dist:
				continue
			dx, dz = bx - ax, bz - az
			length = math.hypot(dx, dz)
			if length < 1e-6:
				continue
			t = max(0.0, min(length, ((px - ax) * dx + (pz - az) * dz) / length))
			cx, cz = ax + dx / length * t, az + dz / length * t
			d = math.hypot(cx - px, cz - pz)
			if d <= max_dist and (best is None or d < best[0]):
				best = (d, way_id, (ax, az), (dx / length, dz / length), length)
	return best


class Tramos:
	"""Indice por celdas de los tramos de calle, para buscar el mas cercano rapido."""

	CELDA = 40.0

	def __init__(self, lines):
		self.celdas = collections.defaultdict(list)
		for way_id, line, refs in lines:
			for i, ((ax, az), (bx, bz)) in enumerate(zip(line, line[1:])):
				for cx in range(int(min(ax, bx) // self.CELDA), int(max(ax, bx) // self.CELDA) + 1):
					for cz in range(int(min(az, bz) // self.CELDA), int(max(az, bz) // self.CELDA) + 1):
						self.celdas[(cx, cz)].append((way_id, (ax, az), (bx, bz), refs[i], refs[i + 1]))

	def cercanos(self, px, pz, max_dist):
		"""[(dist, way_id, (cx, cz) punto mas cercano, (dx, dz) unitario)], de cada tramo a menos de max_dist."""
		out = []
		vistos = set()
		r = int(max_dist // self.CELDA) + 1
		cx0, cz0 = int(px // self.CELDA), int(pz // self.CELDA)
		for cx in range(cx0 - r, cx0 + r + 1):
			for cz in range(cz0 - r, cz0 + r + 1):
				for tramo in self.celdas.get((cx, cz), ()):
					if id(tramo) in vistos:
						continue
					vistos.add(id(tramo))
					way_id, (ax, az), (bx, bz), _, _ = tramo
					dx, dz = bx - ax, bz - az
					length = math.hypot(dx, dz)
					if length < 1e-6:
						continue
					dx, dz = dx / length, dz / length
					t = max(0.0, min(length, (px - ax) * dx + (pz - az) * dz))
					qx, qz = ax + dx * t, az + dz * t
					d = math.hypot(qx - px, qz - pz)
					if d <= max_dist:
						out.append((d, way_id, (qx, qz), (dx, dz)))
		return out


def muestras(line, paso):
	"""Puntos cada `paso` m sobre la linea: [(x, z, dx, dz)]."""
	out = []
	for (ax, az), (bx, bz) in zip(line, line[1:]):
		length = math.hypot(bx - ax, bz - az)
		if length < 1e-6:
			continue
		dx, dz = (bx - ax) / length, (bz - az) / length
		n = max(1, int(length // paso))
		for i in range(n):
			t = (i + 0.5) * length / n
			out.append((ax + dx * t, az + dz * t, dx, dz))
	return out


def calles_y_banquetas(root, kept_ways, pos, lat0, lon0) -> tuple:
	"""Pone ancho y banquetas a las calles y agrega los camellones.

	- Ancho del arroyo y banquetas segun ANCHO_CALLE/BANQUETA, angostados si la
	  mediana de las fachadas de la calle esta mas cerca del eje.
	- Las avenidas con camellon (dos calles de un sentido paralelas) llevan
	  banqueta solo del lado de afuera; entre las dos se agrega un camellon de
	  pasto (landuse=grass) con guarnicion.
	Regresa ({way_id: (medio_arroyo, banqueta_izq, banqueta_der)}, [camellones en metros])."""
	lines = street_lines(kept_ways, pos, lat0, lon0, STREET_TYPES)
	tramos = Tramos(lines)
	tags_way = {way_id: tags_of(kept_ways[way_id]) for way_id, _, _ in lines}
	linea_de = {way_id: line for way_id, line, _ in lines}

	def un_sentido(way_id):
		return tags_way[way_id].get("oneway") in ("yes", "1", "-1")

	def misma_avenida(a, b):
		ta, tb = tags_way[a], tags_way[b]
		if ta.get("name") or tb.get("name"):
			return ta.get("name") == tb.get("name")
		return ta.get("highway") == tb.get("highway")

	# Pares con camellon: por cada muestra de una calle de un sentido, la calle
	# hermana mas cercana del otro lado
	lado_camellon = {}  # way_id -> "left"/"right": de que lado queda el camellon
	pares = collections.defaultdict(list)  # way_id -> [(x, z, dx, dz, qx, qz, otra)]
	for way_id, line, _ in lines:
		if not un_sentido(way_id):
			continue
		votos = collections.Counter()
		ss = muestras(line, CAMELLON_MUESTRA)
		for x, z, dx, dz in ss:
			best = None
			for d, otra, (qx, qz), (ox, oz) in tramos.cercanos(x, z, CAMELLON_DIST[1]):
				if otra == way_id or d < CAMELLON_DIST[0] or not un_sentido(otra) or not misma_avenida(way_id, otra):
					continue
				if dx * ox + dz * oz > -0.8:  # tienen que ir en sentidos opuestos
					continue
				if best is None or d < best[0]:
					best = (d, otra, qx, qz)
			if best:
				_, otra, qx, qz = best
				# izquierda del sentido de la calle = (dz, -dx)
				votos["left" if (qx - x) * dz - (qz - z) * dx > 0 else "right"] += 1
				pares[way_id].append((x, z, dx, dz, qx, qz, otra))
		if ss and sum(votos.values()) >= 0.6 * len(ss):
			lado_camellon[way_id] = votos.most_common(1)[0][0]

	# Cortes del camellon: nodos de una avenida con camellon donde otra calle sale hacia
	# el lado del camellon (lo atraviesa: cruce o retorno). Las calles que llegan por
	# fuera (cruce en T) no lo cortan.
	vias_nodo = collections.defaultdict(list)  # nodo -> [(way_id, indice)]
	xz_nodo = {}
	for way_id, line, refs in lines:
		for i, r in enumerate(refs):
			vias_nodo[r].append((way_id, i))
			xz_nodo[r] = line[i]
	cortes = collections.defaultdict(list)
	for way_id, line, refs in lines:
		lado = lado_camellon.get(way_id)
		if not lado:
			continue
		for i, r in enumerate(refs):
			if len(vias_nodo[r]) < 2:
				continue
			a, b = line[max(i - 1, 0)], line[min(i + 1, len(line) - 1)]
			length = math.hypot(b[0] - a[0], b[1] - a[1])
			if length < 1e-6:
				continue
			dx, dz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
			x, z = line[i]
			for otra, j in vias_nodo[r]:
				if otra == way_id or (otra in lado_camellon and misma_avenida(way_id, otra)):
					continue
				otra_line = linea_de[otra]
				for k in (j - 1, j + 1):
					if 0 <= k < len(otra_line):
						vx, vz = otra_line[k][0] - x, otra_line[k][1] - z
						# izquierda del sentido de la calle = (dz, -dx)
						if ("left" if vx * dz - vz * dx > 0 else "right") == lado:
							cortes[(int(x // 20), int(z // 20))].append((x, z))

	def cerca_de_cruce(x, z, dist):
		cx, cz = int(x // 20), int(z // 20)
		return any(math.hypot(x - ox, z - oz) < dist
			for dx in (-1, 0, 1) for dz in (-1, 0, 1) for ox, oz in cortes.get((cx + dx, cz + dz), ()))

	# Fachadas: distancia del eje de cada calle a la casa mas cercana de cada lado
	frentes = collections.defaultdict(list)  # (way_id, lado) -> [dist]
	for way in kept_ways.values():
		tags = tags_of(way)
		if "building" not in tags:
			continue
		local = [local_xz(*pos[nd.get("ref")], lat0, lon0) for nd in way.findall("nd")]
		if not CASA_AREA[0] <= ring_area(local) <= CASA_AREA[1]:
			continue
		cx, cz = centroid(local[:-1])
		cerca = tramos.cercanos(cx, cz, CASA_MAX_CALLE)
		if not cerca:
			continue
		_, way_id, (qx, qz), (dx, dz) = min(cerca)
		lado = "left" if (cx - qx) * dz - (cz - qz) * dx > 0 else "right"
		nx, nz = (dz, -dx) if lado == "left" else (-dz, dx)
		frente = min((x - qx) * nx + (z - qz) * nz for x, z in local)
		if frente > 0.5:
			frentes[(way_id, lado)].append(frente)

	perfil = {}
	con_banqueta = 0
	for way_id, line, _ in lines:
		way = kept_ways[way_id]
		tags = tags_way[way_id]
		hw = tags.get("highway")
		arroyo = ANCHO_CALLE.get(hw, 6.0)
		banqueta = BANQUETA.get(hw, 0.0) if hw in BLOCK_STREET_TYPES else 0.0
		camellon = lado_camellon.get(way_id)
		if camellon:
			arroyo = arroyo / 2 + 1.0
		medio = arroyo / 2
		lados = {}
		for lado in ("left", "right"):
			sw = 0.0 if lado == camellon else banqueta
			f = frentes.get((way_id, lado))
			if f and sw > 0:
				disponible = sorted(f)[len(f) // 2] - FACHADA_HOLGURA
				if disponible < medio + sw:
					sw = max(BANQUETA_MIN, disponible - medio)
			lados[lado] = sw
		# Si aun asi no cabe, se angosta el arroyo
		for lado in ("left", "right"):
			f = frentes.get((way_id, lado))
			if f and lados[lado] > 0:
				disponible = sorted(f)[len(f) // 2] - FACHADA_HOLGURA
				medio = max(ARROYO_MIN_MEDIO, min(medio, disponible - lados[lado]))
		perfil[way_id] = (medio, lados["left"], lados["right"])

		if "width" not in tags:
			set_tag(way, "width", f"{2 * medio + lados['left'] + lados['right']:.1f}")
		if not any(k.startswith("sidewalk") for k in tags) and (lados["left"] or lados["right"]):
			con_banqueta += 1
			if lados["left"] and lados["right"]:
				set_tag(way, "sidewalk", "both")
			else:
				set_tag(way, "sidewalk", "left" if lados["left"] else "right")
			for lado in ("left", "right"):
				if lados[lado]:
					set_tag(way, f"sidewalk:{lado}:width", f"{lados[lado]:.1f}")
					set_tag(way, f"sidewalk:{lado}:surface", "concrete")
		elif tags.get("sidewalk") in ("both", "left", "right"):
			for lado in ("left", "right") if tags["sidewalk"] == "both" else (tags["sidewalk"],):
				if f"sidewalk:{lado}:surface" not in tags and "sidewalk:both:surface" not in tags:
					set_tag(way, f"sidewalk:{lado}:surface", "concrete")

	# Camellones: entre cada muestra y su hermana, del borde de un arroyo al del otro.
	# Solo los dibuja la calle con id menor del par, para no repetirlos.
	camellones = []
	for way_id, ss in pares.items():
		if way_id not in lado_camellon:
			continue
		corrida = []

		def cerrar():
			if len(corrida) >= 3:
				camellones.append([p for p, _ in corrida] + [q for _, q in reversed(corrida)])
			corrida.clear()

		for x, z, dx, dz, qx, qz, otra in ss:
			if otra not in lado_camellon or int(way_id) > int(otra):
				cerrar()
				continue
			d = math.hypot(qx - x, qz - z)
			ux, uz = (qx - x) / d, (qz - z) / d
			a = perfil[way_id][0] + 0.3
			b = perfil[otra][0] + 0.3
			if d - a - b < CAMELLON_ANCHO_MIN or cerca_de_cruce(x, z, CAMELLON_CRUCE + d / 2) \
					or cerca_de_cruce(qx, qz, CAMELLON_CRUCE + d / 2):
				cerrar()
				continue
			# Muestras salteadas (la calle hermana cambia de tramo) cortan el camellon
			if corrida and math.hypot(corrida[-1][0][0] - (x + ux * a), corrida[-1][0][1] - (z + uz * a)) > 3 * CAMELLON_MUESTRA:
				cerrar()
			corrida.append(((x + ux * a, z + uz * a), (qx - ux * b, qz - uz * b)))
		cerrar()

	# Al .osm: nodos en lat/lon (inverso de local_xz) y dos ways por camellon
	scale = math.cos(math.radians(lat0))
	merc_y0 = EARTH_RADIUS * math.log(math.tan(math.pi / 4 + math.radians(lat0) / 2))
	node_id = way_id = CAMELLON_ID_START
	nuevos = []
	for ring in camellones:
		refs = []
		for x, z in ring:
			lon = lon0 + math.degrees(x / scale / EARTH_RADIUS)
			lat = math.degrees(2 * math.atan(math.exp((merc_y0 - z / scale) / EARTH_RADIUS)) - math.pi / 2)
			ET.SubElement(root, "node", id=str(node_id), version="1", lat=f"{lat:.7f}", lon=f"{lon:.7f}")
			pos[str(node_id)] = (lat, lon)
			refs.append(str(node_id))
			node_id += 1
		for kind in ("pasto", "guarnicion"):
			way = ET.Element("way", id=str(way_id), version="1")
			for r in refs + refs[:1]:
				ET.SubElement(way, "nd", ref=r)
			if kind == "pasto":
				ET.SubElement(way, "tag", k="landuse", v="grass")
			else:
				ET.SubElement(way, "tag", k="barrier", v="wall")
				ET.SubElement(way, "tag", k="height", v=str(CAMELLON_GUARNICION))
				ET.SubElement(way, "tag", k="width", v="0.2")
				ET.SubElement(way, "tag", k="material", v="concrete")
			ET.SubElement(way, "tag", k="source", v=CAMELLON_FUENTE)
			kept_ways[str(way_id)] = way
			nuevos.append(way)
			way_id += 1
	print(f"  Calles: {len(lines)} con ancho, {con_banqueta} con banquetas nuevas, "
		f"{len(lado_camellon)} con camellon, {len(camellones)} camellones")
	return perfil, camellones, lado_camellon


def borde_banqueta(perfil, way_id, izquierda: bool, default: float) -> float:
	"""Distancia del eje de la calle al borde de afuera de su banqueta (m)."""
	if way_id not in perfil:
		return default
	medio, izq, der = perfil[way_id]
	return medio + (izq if izquierda else der)


def unir_intervalos(intervalos, hueco) -> list:
	"""Une intervalos (a, b) separados por menos de `hueco`."""
	out = []
	for a, b in sorted(intervalos):
		if out and a - out[-1][1] < hueco:
			out[-1][1] = max(out[-1][1], b)
		else:
			out.append([a, b])
	return out


def restar_intervalos(intervalos, cortes) -> list:
	"""Los intervalos sin lo que tapan los `cortes`."""
	for c0, c1 in cortes:
		nuevos = []
		for a, b in intervalos:
			if c1 <= a or c0 >= b:
				nuevos.append([a, b])
				continue
			if c0 > a:
				nuevos.append([a, c0])
			if c1 < b:
				nuevos.append([c1, b])
		intervalos = nuevos
	return intervalos


def escoger(opciones, s):
	"""Un modelo de [[modelo, peso], ...] segun la semilla `s`."""
	total = sum(peso for _, peso in opciones)
	pick = ((s >> 8) % 10000) / 10000.0 * total
	for modelo, peso in opciones:
		pick -= peso
		if pick < 0:
			break
	return modelo


def llenar_tramo(largo, elegir) -> list:
	"""Casas pegadas que llenan `largo` m: [(modelo, pisos, escala)]. `elegir(i)`
	da (modelo, pisos, frente) de la casa i. Todas llevan la misma escala, dentro
	de CASA_ESCALA; [] si ni una casa cabe."""
	casas, suma = [], 0.0
	while suma < largo and len(casas) < 500:
		casas.append(elegir(len(casas)))
		suma += casas[-1][2]
	# Con la ultima casa la escala queda <= 1, sin ella > 1: la que quede mas cerca de 1
	opciones = [(casas, largo / suma)]
	if len(casas) > 1:
		opciones.append((casas[:-1], largo / (suma - casas[-1][2])))
	validas = [o for o in opciones if CASA_ESCALA[0] <= o[1] <= CASA_ESCALA[1]]
	if not validas:
		return []
	casas, escala = min(validas, key=lambda o: abs(math.log(o[1])))
	return [(modelo, pisos, escala) for modelo, pisos, _ in casas]


def invade_calle(poly, calles, perfil, propia) -> bool:
	"""Si alguna esquina de `poly` cae en el arroyo o la banqueta de una calle que
	no es `propia` (esquinas de la manzana, calles que doblan)."""
	for x, z in poly:
		for d, way_id, _, _ in calles.cercanos(x, z, 15.0):
			if way_id == propia:
				continue
			medio, izq, der = perfil.get(way_id, (SETBACK_MIN - 1.5, 0.0, 0.0))
			if d < medio + max(izq, der):
				return True
	return False


def place_casas(kept_ways, pos, lat0, lon0, lines, manzanas, colonia_de, reglas, modelos,
		perfil=None, negocios=(), calles=None, cotos=None, locales=(), huellas=None) -> list:
	"""Cambia por modelos las casas de las colonias de `reglas` (data/map/casas.json).
	Las casas se juntan por cara de cuadra (tramo recto de calle, lado, manzana) y
	donde hay casas se ponen modelos pegados uno junto a otro, sin importar cada
	huella de Google (se enciman y no son lotes). Todas las fachadas de la cuadra
	van a la misma distancia del eje de la calle: la mediana de sus casas.
	`modelos`: modelo -> [frente, fondo] (huellas_tiendas.json); `negocios`: sus
	huellas (la hilera llega hasta ellas); `calles`: Tramos de todas las calles.
	`cotos`: las casas de un coto que dan a una calle publica (su contorno) no se
	cambian: ahi va la barda y quedan detras de ella. `locales`: negocios de
	LOCALES_HILERA ya colocados; se mueven a un lote de la hilera (misma fachada,
	pegados a las casas) y se cambian en el lugar. El que no cabe en la hilera ni en su
	lugar se marca con "_quitar" (`huellas`: huellas_tiendas.json, para su lugar)."""
	casas = []
	en_contorno = 0
	for way_id, way in kept_ways.items():
		tags = tags_of(way)
		if tags.get("building") not in ("yes", "house", "residential") or "name" in tags or "shop" in tags or "amenity" in tags:
			continue
		local = [local_xz(*pos[nd.get("ref")], lat0, lon0) for nd in way.findall("nd")]
		area = ring_area(local)
		if not CASA_AREA[0] <= area <= CASA_AREA[1]:
			continue
		cx, cz = centroid(local[:-1])
		calle = nearest_segment(cx, cz, lines, CASA_MAX_CALLE)
		if calle is None:
			continue
		_, street_id, (ax, az), (dx, dz), largo = calle
		if cotos and street_id not in cotos.calles and cotos.at(cx, cz):
			en_contorno += 1
			continue
		# n: de la calle hacia la casa
		nx, nz = -dz, dx
		if (cx - ax) * nx + (cz - az) * nz < 0:
			nx, nz = -nx, -nz
		us = [(x - ax) * dx + (z - az) * dz for x, z in local]
		vs = [(x - ax) * nx + (z - az) * nz for x, z in local]
		izquierda = nx * dz - nz * dx > 0
		manzana = manzanas.at(cx, cz)
		casas.append({
			"way_id": way_id, "tags": tags, "ring": local,
			"grupo": (street_id, izquierda, manzana),
			"cara": (street_id, izquierda, manzana, (round(ax, 2), round(az, 2))),
			"a": (ax, az), "d": (dx, dz), "n": (nx, nz), "largo": largo,
			"u0": min(us), "u1": max(us), "frente": min(vs), "fondo": max(vs),
		})

	# Alineacion: mediana del frente de todas las casas de la cuadra (tambien las
	# que no se cambian, para que los modelos queden al pano con las vecinas)
	frentes = collections.defaultdict(list)
	for casa in casas:
		frentes[casa["grupo"]].append(casa["frente"])
	# Nunca encima de la banqueta
	setback = {g: max(borde_banqueta(perfil or {}, g[0], g[1], SETBACK_MIN) + FACHADA_HOLGURA, sorted(f)[len(f) // 2])
		for g, f in frentes.items()}

	caras = collections.defaultdict(list)
	for casa in casas:
		caras[casa["cara"]].append(casa)
	# Las caras largas primero: en las esquinas gana la hilera mas larga
	orden = sorted(caras, key=lambda k: (-sum(c["u1"] - c["u0"] for c in caras[k]), str(k)))

	lotes = Rejilla()
	# Locales de colonia: un lote de la hilera de su cara, con la fachada en la
	# mediana de las casas; la hilera pasa por ellos y las casas quedan pegadas
	en_cara = collections.defaultdict(list)  # cara -> [(u0, u1)]
	en_hilera = 0
	otros_negocios = Rejilla(negocios)

	def fuera_de_hilera(local):
		"""Se queda donde lo puso place_puntos si ahi no estorba; si no, no se pone."""
		propia = huella_negocio(local, huellas) if huellas else None
		if propia and (otros_negocios.encima(propia) or lotes.encima(propia)):
			local["_quitar"] = True
			print(f"  Local sin lugar (encimado en otro): {local['tipo']} {local.get('nombre', '')}")
		elif propia:
			lotes.agregar(propia, local["rotacion_y"])

	for local in locales:
		calle = nearest_segment(local["x"], local["z"], lines, CASA_MAX_CALLE)
		if calle is None:
			fuera_de_hilera(local)
			continue
		_, street_id, (ax, az), (dx, dz), largo = calle
		nx, nz = -dz, dx
		if (local["x"] - ax) * nx + (local["z"] - az) * nz < 0:
			nx, nz = -nx, -nz
		izquierda = nx * dz - nz * dx > 0
		manzana = manzanas.at(local["x"], local["z"])
		grupo_id = (street_id, izquierda, manzana)
		cara = (*grupo_id, (round(ax, 2), round(az, 2)))
		frente = setback.get(grupo_id, borde_banqueta(perfil or {}, street_id, izquierda, SETBACK_MIN) + FACHADA_HOLGURA)
		fondo = local["fondo"]
		if cara in caras:
			fondos = sorted(c["fondo"] for c in caras[cara])
			fondo = fondos[len(fondos) // 2] - frente
		ancho = min(max(local["ancho"], LOCAL_ANCHO[0]), LOCAL_ANCHO[1])
		fondo = min(max(fondo, LOCAL_FONDO[0]), LOCAL_FONDO[1])
		rot = math.atan2(-nx, -nz)

		def lote_en(uc):
			x = ax + dx * uc + nx * (frente + fondo / 2)
			z = az + dz * uc + nz * (frente + fondo / 2)
			return x, z, rectangulo(x, z, rot, ancho - 2 * LOTE_MARGEN, fondo / 2 - LOTE_MARGEN, -fondo / 2 + LOTE_MARGEN)

		uc0 = (local["x"] - ax) * dx + (local["z"] - az) * dz
		if largo > ancho:
			uc0 = min(max(uc0, ancho / 2), largo - ancho / 2)
		# Si cae sobre otro negocio (gasolinera, nave...) u otro local, se recorre a un
		# lado de lo que estorba, pegado, el lado mas cerca de donde estaba
		candidatos = [uc0]
		lugar = None
		for _ in range(LOCAL_INTENTOS + 1):
			if not candidatos:
				break
			uc = min(candidatos, key=lambda u: abs(u - uc0))
			candidatos.remove(uc)
			x, z, rect = lote_en(uc)
			estorban = otros_negocios.chocan(rect) + lotes.chocan(rect)
			if not estorban:
				if not (calles and invade_calle(rect, calles, perfil or {}, street_id)):
					lugar = (uc, x, z, rect)
					break
				continue
			for huella in estorban:
				us = [(hx - ax) * dx + (hz - az) * dz for hx, hz in huella]
				candidatos += [min(us) - ancho / 2, max(us) + ancho / 2]
		if lugar is None:
			fuera_de_hilera(local)
			continue
		uc, x, z, rect = lugar
		lotes.agregar(rect, rot)
		local.update({"x": round(x, 3), "z": round(z, 3), "rotacion_y": round(rot, 4),
			"ancho": round(ancho, 2), "fondo": round(fondo, 2)})
		en_cara[cara].append((uc - ancho / 2, uc + ancho / 2))
		en_hilera += 1

	placed = []
	replaced = []
	descartados = 0
	for cara in orden:
		grupo = caras[cara]
		colonia = colonia_de.get(cara[2], "")
		regla = reglas.get(colonia) or reglas.get("*")
		if not regla:
			continue
		# La proporcion va por cara: una cara a medias volveria a encimarse
		cara_id = f"cara/{cara[0]}/{int(cara[1])}/{cara[2]}/{cara[3][0]:.1f},{cara[3][1]:.1f}"
		if (seed(cara_id) % 1000) / 1000.0 >= regla.get("_proporcion", 1.0):
			continue
		(ax, az), (dx, dz), (nx, nz), largo = grupo[0]["a"], grupo[0]["d"], grupo[0]["n"], grupo[0]["largo"]
		frente = setback[grupo[0]["grupo"]]
		fondos = sorted(c["fondo"] for c in grupo)
		fondo_cuadra = max(CASA_FONDO_MIN, fondos[len(fondos) // 2] - frente) + 1.0
		rot = math.atan2(-nx, -nz)

		# Donde hay casas, recortado al tramo de calle
		tramos = unir_intervalos([(max(0.0, c["u0"]), min(largo, c["u1"]))
			for c in grupo if c["u1"] > 0 and c["u0"] < largo] + en_cara[cara], HUECO_MAX)
		# Los negocios de este lado de la calle cortan la hilera
		cortes = []
		for huella in negocios:
			vs = [(x - ax) * nx + (z - az) * nz for x, z in huella]
			if max(vs) < 0 or min(vs) > frente + fondo_cuadra:
				continue
			us = [(x - ax) * dx + (z - az) * dz for x, z in huella]
			if max(us) > 0 and min(us) < largo:
				cortes.append((min(us), max(us)))
		tramos = restar_intervalos(tramos, cortes + en_cara[cara])

		for t0, t1 in tramos:
			def elegir(i):
				s = seed(f"{cara_id}#{t0:.0f}#{i}")
				pisos = 1 + s % 2
				# Si la casa de Google/OSM de ese lugar trae pisos, se respetan
				u = t0 + (i + 0.5) * ANCHO_LOTE_TIPICO
				px, pz = ax + dx * u + nx * (frente + 2.0), az + dz * u + nz * (frente + 2.0)
				for c in grupo:
					levels = c["tags"].get("building:levels")
					if levels and levels.isdigit() and point_in_polygon(px, pz, c["ring"]):
						pisos = int(levels)
						break
				opciones = [o for o in (regla.get(str(pisos)) or regla.get("*") or []) if o[0] in modelos]
				# Solo modelos que caben en el fondo de la cuadra (si ninguno, el menos hondo)
				caben = [o for o in opciones if modelos[o[0]][1] * CASA_ESCALA[0] <= fondo_cuadra]
				if opciones and not caben:
					caben = [min(opciones, key=lambda o: modelos[o[0]][1])]
				if not caben:
					return (None, pisos, ANCHO_LOTE_TIPICO)
				modelo = escoger(caben, s)
				return (modelo, pisos, modelos[modelo][0])

			u = t0
			for modelo, pisos, escala in llenar_tramo(t1 - t0, elegir):
				if modelo is None:
					u += ANCHO_LOTE_TIPICO * escala
					continue
				ancho, fondo = modelos[modelo][0] * escala, modelos[modelo][1] * escala
				uc = u + ancho / 2
				u += ancho
				x, z = ax + dx * uc + nx * frente, az + dz * uc + nz * frente
				rect = rectangulo(x, z, rot, ancho - 2 * LOTE_MARGEN, -LOTE_MARGEN, -fondo + LOTE_MARGEN)
				# Casas espalda con espalda (fachadas opuestas) si se pueden encimar por
				# atras; por los lados (misma hilera, esquinas) no
				if lotes.encima(rect, lambda otra: math.cos(otra - rot) > ESPALDA_COS) \
						or (calles and invade_calle(rect, calles, perfil or {}, cara[0])):
					descartados += 1
					continue
				lotes.agregar(rect, rot)
				s = seed(f"{cara_id}#{uc:.1f}")
				placed.append({
					"modelo": modelo,
					"x": round(x, 2), "z": round(z, 2),
					"rotacion_y": round(rot, 4),
					"ancho": round(ancho, 2), "fondo": round(fondo, 2),
					"pisos": pisos,
					"color": CASA_PALETTE[(s >> 4) % len(CASA_PALETTE)],
					"colonia": colonia,
				})
		replaced += [c["way_id"] for c in grupo]
	for way_id in replaced:
		del kept_ways[way_id]
	# Lo que quede debajo de un lote (casas de otra cara, huellas grandes) tambien se va
	encimados = quitar_edificios_encimados(kept_ways, pos, lat0, lon0, lotes.poligonos)
	print(f"  Casas modelo: {len(replaced)} huellas cambiadas por hileras, {descartados} lotes descartados "
		f"(chocaban con otro o con una calle), {encimados} edificios debajo de un lote quitados, "
		f"{en_contorno} en el contorno de un coto sin cambiar, {en_hilera} de {len(locales)} locales en la hilera")
	return placed


def pisos_locales(locales, casas) -> None:
	"""Pone `pisos` a cada local: los de la casa modelo mas cercana (LOCAL_PISOS_VECINA)
	para que quede de la altura de sus vecinas; sin vecina, casi siempre 1."""
	rejilla = collections.defaultdict(list)
	for c in casas:
		rejilla[(int(c["x"] // LOCAL_PISOS_VECINA), int(c["z"] // LOCAL_PISOS_VECINA))].append(c)
	for local in locales:
		cx, cz = int(local["x"] // LOCAL_PISOS_VECINA), int(local["z"] // LOCAL_PISOS_VECINA)
		cerca = [c for i in (-1, 0, 1) for j in (-1, 0, 1) for c in rejilla.get((cx + i, cz + j), ())]
		vecina = min(cerca, key=lambda c: math.hypot(c["x"] - local["x"], c["z"] - local["z"]), default=None)
		if vecina and math.hypot(vecina["x"] - local["x"], vecina["z"] - local["z"]) <= LOCAL_PISOS_VECINA:
			local["pisos"] = vecina["pisos"]
		else:
			local["pisos"] = 2 if seed(local.get("origen") or local.get("nombre", "")) % 4 == 0 else 1


def quitar_negocios_encimados(placed, huellas):
	"""Ultima revision: de cada par de negocios cuyas huellas se enciman se queda uno
	(el local o modelo antes que el puesto, la gasolinera/OXXO/farmacia antes que los
	demas, el puesto a mano antes que el DENUE y OSM). Devuelve (placed, quitados)."""
	def rango(p):
		tipo = p["tipo"]
		origen = p.get("origen", "")
		return (tipo in NO_REPLACE_TIPOS,
			INTERACTIVO_PRIORIDAD.index(tipo) if tipo in INTERACTIVO_PRIORIDAD else len(INTERACTIVO_PRIORIDAD),
			0 if origen == "puntos.json" else (1 if origen.startswith("denue") else 2), origen)

	puestos = Rejilla()
	quedan = []
	quitados = []
	for p in sorted(placed, key=rango):
		huella = huella_negocio(p, huellas)
		if huella and puestos.encima(huella):
			quitados.append(p)
			continue
		if huella:
			puestos.agregar(huella)
		quedan.append(p)
	# En el orden de antes (el json queda igual de ordenado)
	ids = {id(p) for p in quedan}
	return [p for p in placed if id(p) in ids], quitados


def elegir_puntos(casas) -> list:
	"""El punto (venta ilegal): una casa modelo de 1 piso por colonia, con vecinas
	pegadas a los dos lados (no en esquina). La casa se marca con "punto" (MapCasas la
	pinta con el deterioro al maximo) y se devuelve como negocio para puntos_mapa.json."""
	por_colonia = collections.defaultdict(list)
	for c in casas:
		if c["colonia"] and c["pisos"] == 1:
			por_colonia[c["colonia"]].append(c)
	puntos = []
	for colonia, grupo in sorted(por_colonia.items()):
		def entre_vecinas(c):
			dx, dz = math.cos(c["rotacion_y"]), -math.sin(c["rotacion_y"])
			lados = set()
			for o in grupo:
				if o is c or abs(o["rotacion_y"] - c["rotacion_y"]) > 0.01:
					continue
				u = (o["x"] - c["x"]) * dx + (o["z"] - c["z"]) * dz
				v = (o["x"] - c["x"]) * dz - (o["z"] - c["z"]) * dx
				if abs(v) < 0.2 and abs(abs(u) - (c["ancho"] + o["ancho"]) / 2) < 0.2:
					lados.add(u > 0)
			return len(lados) == 2
		candidatas = sorted((c for c in grupo if entre_vecinas(c)), key=lambda c: (c["x"], c["z"]))
		if not candidatas:
			continue
		c = candidatas[seed(colonia) % len(candidatas)]
		c["punto"] = True
		# x/z de la casa es el centro de la fachada; el del negocio, el centro del lote
		rot = c["rotacion_y"]
		puntos.append({
			"tipo": "punto", "nombre": "El punto",
			"x": round(c["x"] - math.sin(rot) * c["fondo"] / 2, 3),
			"z": round(c["z"] - math.cos(rot) * c["fondo"] / 2, 3),
			"rotacion_y": rot, "ancho": c["ancho"], "fondo": c["fondo"],
			"casa_reemplazada": None, "origen": f"punto {colonia}",
		})
	return puntos


def envolvente(puntos) -> list:
	"""Envolvente convexa (cadena monotona), sin repetir el primer punto."""
	pts = sorted(set(puntos))
	if len(pts) < 3:
		return pts

	def cruz(o, a, b):
		return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

	abajo, arriba = [], []
	for p in pts:
		while len(abajo) >= 2 and cruz(abajo[-2], abajo[-1], p) <= 0:
			abajo.pop()
		abajo.append(p)
	for p in reversed(pts):
		while len(arriba) >= 2 and cruz(arriba[-2], arriba[-1], p) <= 0:
			arriba.pop()
		arriba.append(p)
	return abajo[:-1] + arriba[:-1]


def rectangulo_minimo(puntos):
	"""Rectangulo de area minima que contiene los puntos (lados de la envolvente):
	(centro x, centro z, eje unitario (ux, uz), largo sobre u, largo sobre el otro eje)."""
	hull = envolvente(puntos)
	best = None
	for (ax, az), (bx, bz) in zip(hull, hull[1:] + hull[:1]):
		largo = math.hypot(bx - ax, bz - az)
		if largo < 1e-6:
			continue
		ux, uz = (bx - ax) / largo, (bz - az) / largo
		us = [x * ux + z * uz for x, z in hull]
		vs = [-x * uz + z * ux for x, z in hull]
		area = (max(us) - min(us)) * (max(vs) - min(vs))
		if best is None or area < best[0]:
			cu, cv = (max(us) + min(us)) / 2, (max(vs) + min(vs)) / 2
			best = (area, cu * ux - cv * uz, cu * uz + cv * ux, (ux, uz), max(us) - min(us), max(vs) - min(vs))
	return best[1:] if best else None


def partir(largo, maximo, pasillo) -> list:
	"""Tramos (inicio, largo) de una nave de `largo` m partida en naves de <= `maximo`
	con `pasillo` m entre ellas, medidos desde -largo/2."""
	n = max(1, math.ceil((largo + pasillo) / (maximo + pasillo)))
	tramo = (largo - (n - 1) * pasillo) / n
	return [(-largo / 2 + i * (tramo + pasillo), tramo) for i in range(n)]


def recortar_nave(nave, puntos):
	"""Achica una nave (x0, x1, z0, z1 en ejes de la bodega) para que no la cruce
	ninguna calle: `puntos` son (x, z, medio ancho ocupado) del eje de las calles.
	Se queda con el pedazo mas grande; None si no queda uno de BODEGA_LADO_MIN."""
	for _ in range(200):
		x0, x1, z0, z1 = nave
		cruza = next(((px, pz, h) for px, pz, h in puntos if x0 - h < px < x1 + h and z0 - h < pz < z1 + h), None)
		if cruza is None:
			return nave
		px, pz, h = cruza
		opciones = [(px + h, x1, z0, z1), (x0, px - h, z0, z1), (x0, x1, z0, pz - h), (x0, x1, pz + h, z1)]
		opciones = [o for o in opciones if o[1] - o[0] >= BODEGA_LADO_MIN and o[3] - o[2] >= BODEGA_LADO_MIN]
		if not opciones:
			return None
		nave = max(opciones, key=lambda o: (o[1] - o[0]) * (o[3] - o[2]))
	return None


def puntos_de_calles(calles, perfil, x0, z0, x1, z1) -> list:
	"""Puntos cada 1 m del eje de las calles cerca de un rectangulo, con lo que
	ocupa cada calle de cada lado (arroyo + BODEGA_BANQUETA)."""
	puntos = []
	vistos = set()
	for cx in range(int(x0 // calles.CELDA) - 1, int(x1 // calles.CELDA) + 2):
		for cz in range(int(z0 // calles.CELDA) - 1, int(z1 // calles.CELDA) + 2):
			for tramo in calles.celdas.get((cx, cz), ()):
				if id(tramo) in vistos:
					continue
				vistos.add(id(tramo))
				way_id, (ax, az), (bx, bz), _, _ = tramo
				medio, izq, der = perfil.get(way_id, (SETBACK_MIN - 1.5, 0.0, 0.0))
				h = medio + BODEGA_BANQUETA
				n = max(1, int(math.hypot(bx - ax, bz - az)))
				puntos += [(ax + (bx - ax) * i / n, az + (bz - az) * i / n, h) for i in range(n + 1)]
	return puntos


def place_bodegas(kept_ways, pos, lat0, lon0, manzanas, colonia_de, calles, perfil, negocios=()) -> list:
	"""Cambia las bodegas (todo lo de BODEGA_COLONIAS y las huellas grandes sin nombre)
	por bodegas huecas de MapBodegas.gd: su rectangulo minimo, con el frente hacia la
	calle mas cercana; las enormes se parten en naves con pasillos. Las quita de kept_ways.
	Una nave que choca con otra o con un negocio (`negocios`: sus huellas) no va."""
	ocupado = Rejilla(negocios)
	bodegas = []
	quitar = []
	partidas = 0
	recortes = 0
	chocan = 0
	for way_id, way in kept_ways.items():
		tags = tags_of(way)
		if tags.get("building") not in BODEGA_TIPOS or "name" in tags or "shop" in tags or "amenity" in tags:
			continue
		local = [local_xz(*pos[nd.get("ref")], lat0, lon0) for nd in way.findall("nd")]
		area = ring_area(local)
		if area < BODEGA_AREA_MIN_INDUSTRIAL:
			continue
		cx, cz = centroid(local[:-1])
		colonia = colonia_de.get(manzanas.at(cx, cz), "") if manzanas else ""
		if area < BODEGA_AREA_MIN and colonia not in BODEGA_COLONIAS:
			continue
		rect = rectangulo_minimo(local[:-1])
		if rect is None:
			continue
		mx, mz, (ux, uz), lu, lv = rect
		# Los cuatro lados: (normal hacia afuera, largo del lado, largo hacia adentro)
		lados = [((-uz, ux), lu, lv), ((uz, -ux), lu, lv), ((ux, uz), lv, lu), ((-ux, -uz), lv, lu)]

		def distancia_calle(lado):
			(nx, nz), _, hondo = lado
			px, pz = mx + nx * hondo / 2, mz + nz * hondo / 2
			cerca = calles.cercanos(px, pz, 80.0)
			return min((d for d, _, _, _ in cerca), default=1e9)

		(nx, nz), ancho, fondo = min(lados, key=distancia_calle)
		if min(ancho, fondo) < BODEGA_LADO_MIN:
			continue
		# Ejes de la bodega: +Z hacia la calle (n), X a lo largo del frente
		rot = math.atan2(nx, nz)
		rx, rz = nz, -nx
		# Naves en ejes de la bodega (x a lo largo del frente, z hacia la calle; el
		# frente de todo esta en z = fondo/2): (x0, x1, z0, z1)
		naves = [(a0, a0 + al, -f0 - fl, -f0) for a0, al in partir(ancho, BODEGA_LARGO_MAX, BODEGA_PASILLO)
			for f0, fl in partir(fondo, BODEGA_LARGO_MAX, BODEGA_PASILLO)]
		# El rectangulo minimo de una huella chueca se puede salir a la calle: se recorta
		r = math.hypot(ancho, fondo) / 2
		puntos = [((px - mx) * rx + (pz - mz) * rz, (px - mx) * nx + (pz - mz) * nz, h)
			for px, pz, h in puntos_de_calles(calles, perfil, mx - r, mz - r, mx + r, mz + r)]
		recortadas = [recortar_nave(nave, puntos) for nave in naves]
		recortes += sum(1 for a, b in zip(naves, recortadas) if a != b)
		naves = [nave for nave in recortadas if nave]
		if not naves:
			continue
		if len(naves) > 1:
			partidas += 1
		puestas = 0
		for i, (x0, x1, z0, z1) in enumerate(naves):
			a, al, fl = (x0 + x1) / 2, x1 - x0, z1 - z0
			x, z = mx + rx * a + nx * z1, mz + rz * a + nz * z1
			huella = rectangulo(x, z, rot, al - 2 * LOTE_MARGEN, -LOTE_MARGEN, -fl + LOTE_MARGEN)
			if ocupado.encima(huella):
				chocan += 1
				continue
			ocupado.agregar(huella)
			puestas += 1
			s = seed(f"bodega/{way_id}#{i}")
			bodegas.append({
				"x": round(x, 2), "z": round(z, 2), "rotacion_y": round(rot, 4),
				"ancho": round(al, 2), "fondo": round(fl, 2),
				"alto": round(min(9.0, max(6.0, 5.0 + math.sqrt(al * fl) / 25.0)) + (s % 5) * 0.2, 2),
				"color": BODEGA_COLORES[(s >> 4) % len(BODEGA_COLORES)],
				"semilla": s % 100000,
				"colonia": colonia,
				"grupo": way_id,
			})
		# Si no cupo ninguna nave, el edificio se queda como estaba
		if puestas:
			quitar.append(way_id)
	for way_id in quitar:
		del kept_ways[way_id]
	print(f"  Bodegas: {len(bodegas)} naves de {len(quitar)} huellas ({partidas} partidas en varias naves, "
		f"{recortes} recortadas porque se salian a una calle, {chocan} quitadas porque chocaban con otra o con un negocio)")
	return bodegas


def huella_bodega(b) -> list:
	return rectangulo(b["x"], b["z"], b["rotacion_y"], b["ancho"], 0.0, -b["fondo"])


class Raster:
	"""Rejilla de BLOCK_CELL m (la misma de Manzanas) con poligonos pintados."""

	def __init__(self, manzanas):
		self.x0, self.z0, self.w, self.h = manzanas.x0, manzanas.z0, manzanas.w, manzanas.h
		self.data = bytearray(self.w * self.h)

	def poligono(self, ring, valor=1) -> None:
		"""Relleno por renglones (centro de la celda adentro = se pinta)."""
		pts = [((x - self.x0) / BLOCK_CELL, (z - self.z0) / BLOCK_CELL) for x, z in ring]
		if pts[0] != pts[-1]:
			pts.append(pts[0])
		ys = [p[1] for p in pts]
		for row in range(max(int(min(ys)), 0), min(int(max(ys)) + 1, self.h)):
			cy = row + 0.5
			cortes = sorted(ax + (cy - ay) / (by - ay) * (bx - ax)
				for (ax, ay), (bx, by) in zip(pts, pts[1:]) if (ay <= cy) != (by <= cy))
			for a, b in zip(cortes[::2], cortes[1::2]):
				c0 = max(int(math.ceil(a - 0.5)), 0)
				c1 = min(int(math.floor(b - 0.5)), self.w - 1)
				if c1 >= c0:
					self.data[row * self.w + c0:row * self.w + c1 + 1] = bytes([valor]) * (c1 - c0 + 1)

	def at(self, x, z) -> int:
		cx, cz = int((x - self.x0) / BLOCK_CELL), int((z - self.z0) / BLOCK_CELL)
		if 0 <= cx < self.w and 0 <= cz < self.h:
			return self.data[cz * self.w + cx]
		return 0


class Cotos:
	"""Fraccionamientos cerrados: cada coto es un grupo conectado de calles privadas
	(access=private) o con pluma (barrier=gate/lift_gate). Una manzana es del coto
	si al menos COTO_FRACCION de su orilla da a sus calles; si es de dos cotos, se
	reparte (cada celda al coto de la calle mas cercana), y si es mas honda que
	COTO_FONDO y hay casas del lado de una calle publica, las celdas mas cerca de
	esa calle no son del coto.
	`dueno`: coto de cada celda de la rejilla de Manzanas (0 = ninguno)."""

	def __init__(self, kept_ways, pos, lat0, lon0, plumas, manzanas):
		self.manzanas = manzanas
		centros = []
		w, h = manzanas.w, manzanas.h
		lines = []
		for way_id, way in kept_ways.items():
			tags = tags_of(way)
			if "building" in tags:
				centros.append(centroid([local_xz(*pos[nd.get("ref")], lat0, lon0) for nd in way.findall("nd")][:-1]))
			if tags.get("highway") not in STREET_TYPES:
				continue
			refs = [nd.get("ref") for nd in way.findall("nd")]
			if tags.get("access") == "private" or any(r in plumas for r in refs):
				lines.append((way_id, [local_xz(*pos[r], lat0, lon0) for r in refs], refs))
		# Grupos conectados por nodos compartidos
		padre = list(range(len(lines)))

		def raiz(i):
			while padre[i] != i:
				padre[i] = padre[padre[i]]
				i = padre[i]
			return i

		de_nodo = {}
		for i, (_, _, refs) in enumerate(lines):
			for r in refs:
				if r in de_nodo:
					padre[raiz(i)] = raiz(de_nodo[r])
				else:
					de_nodo[r] = i
		ids = {}
		self.calles = {way_id: ids.setdefault(raiz(i), len(ids) + 1) for i, (way_id, _, _) in enumerate(lines)}

		# Las calles de cada coto en la rejilla
		marca = array.array("i", bytes(4 * w * h))
		r = int(math.ceil(BLOCK_STREET_HALF / BLOCK_CELL))
		for way_id, line, _ in lines:
			k = self.calles[way_id]
			for (ax, az), (bx, bz) in zip(line, line[1:]):
				steps = int(math.hypot(bx - ax, bz - az) / (BLOCK_CELL / 2)) + 1
				for s in range(steps + 1):
					cx, cz = manzanas.cell(ax + (bx - ax) * s / steps, az + (bz - az) * s / steps)
					for dz in range(-r, r + 1):
						for dx in range(-r, r + 1):
							if 0 <= cx + dx < w and 0 <= cz + dz < h:
								marca[(cz + dz) * w + cx + dx] = k

		# Orilla de cada manzana y cuanta da a cada coto
		labels, street = manzanas.labels, manzanas.street
		orilla = collections.Counter()
		da_a = collections.defaultdict(collections.Counter)
		for i in range(w * h):
			label = labels[i]
			if not label:
				continue
			x = i % w
			vecinos = [j for j in (i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w)
				if 0 <= j < w * h and (street[j] or marca[j])]
			if marca[i]:
				vecinos.append(i)
			if not vecinos:
				continue
			orilla[label] += 1
			for k in {marca[j] for j in vecinos if marca[j]}:
				da_a[label][k] += 1
		reclamada = {label: {k for k, n in cuenta.items() if n >= COTO_FRACCION * orilla[label]}
			for label, cuenta in da_a.items()}
		area = collections.Counter(labels)
		reclamada = {label: ks for label, ks in reclamada.items() if ks and area[label] * BLOCK_CELL ** 2 <= COTO_MANZANA_MAX}

		def distancias(semillas, entra):
			"""Distancia en celdas (4 vecinos) y semilla mas cercana; -1 = no llega."""
			dist = array.array("i", [-1]) * (w * h)
			de = array.array("i", bytes(4 * w * h))
			cola = collections.deque()
			for i, k in semillas:
				dist[i], de[i] = 0, k
				cola.append(i)
			while cola:
				i = cola.popleft()
				x = i % w
				for j in (i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w):
					if 0 <= j < w * h and dist[j] < 0 and entra(j, de[i]):
						dist[j], de[j] = dist[i] + 1, de[i]
						cola.append(j)
			return dist, de

		# Cada celda de una manzana reclamada, al coto cuya calle llega primero
		d_coto, cerca = distancias(((i, marca[i]) for i in range(w * h) if marca[i]),
			lambda j, k: k in reclamada.get(labels[j], ()))
		d_calle, _ = distancias(((i, 1) for i in range(w * h) if street[i] and not marca[i]),
			lambda j, k: labels[j] != 0)
		# Una manzana angosta (una hilera de casas entre el coto y la calle) es toda del
		# coto: la barda va en la banqueta. En una mas honda, las casas que estan mas cerca
		# de una calle publica no son del coto y la barda va por atras.
		hondo = collections.Counter()
		for i in range(w * h):
			if cerca[i] and labels[i]:
				hondo[labels[i]] = max(hondo[labels[i]], d_coto[i])
		# Si en la parte que da a la calle publica casi no hay casas, tambien es del coto
		# (la barda del coto va en la banqueta de la avenida)
		casas_fuera, casas_total = collections.Counter(), collections.Counter()
		for x, z in centros:
			cx, cz = manzanas.cell(x, z)
			if 0 <= cx < w and 0 <= cz < h:
				i = cz * w + cx
				if cerca[i] and labels[i]:
					casas_total[labels[i]] += 1
					if not (d_calle[i] < 0 or d_coto[i] <= d_calle[i]):
						casas_fuera[labels[i]] += 1
		toda = {label for label in hondo if hondo[label] * BLOCK_CELL <= COTO_FONDO
			or casas_fuera[label] <= COTO_CASAS_FUERA * casas_total[label]}
		dueno = array.array("i", bytes(4 * w * h))
		for i in range(w * h):
			if cerca[i] and (not labels[i] or labels[i] in toda or d_calle[i] < 0 or d_coto[i] <= d_calle[i]):
				dueno[i] = cerca[i]
		self.dueno = dueno
		self.n = len({k for ks in reclamada.values() for k in ks})
		print(f"  Cotos: {self.n} con manzanas ({len(ids)} grupos de calles privadas o con pluma, "
			f"{len(lines)} calles), {len(reclamada)} manzanas")

	def at(self, x, z) -> int:
		"""Coto de la manzana en (x, z); 0 si no es de un coto o si cae en la calle."""
		cx, cz = self.manzanas.cell(x, z)
		if 0 <= cx < self.manzanas.w and 0 <= cz < self.manzanas.h:
			i = cz * self.manzanas.w + cx
			if self.manzanas.labels[i]:
				return self.dueno[i]
		return 0


def simplificar(pts, tol) -> list:
	"""Ramer-Douglas-Peucker."""
	if len(pts) < 3:
		return list(pts)
	(ax, az), (bx, bz) = pts[0], pts[-1]
	dx, dz = bx - ax, bz - az
	largo = math.hypot(dx, dz)
	peor, k = -1.0, 0
	for i in range(1, len(pts) - 1):
		px, pz = pts[i]
		d = abs((px - ax) * dz - (pz - az) * dx) / largo if largo > 1e-9 else math.hypot(px - ax, pz - az)
		if d > peor:
			peor, k = d, i
	if peor <= tol:
		return [pts[0], pts[-1]]
	return simplificar(pts[:k + 1], tol)[:-1] + simplificar(pts[k:], tol)


def largo_linea(pts) -> float:
	return sum(math.hypot(bx - ax, bz - az) for (ax, az), (bx, bz) in zip(pts, pts[1:]))


def muestras_lado(line, izquierda, paso):
	"""Puntos cada `paso` m sobre la linea con la normal hacia ese lado: [(x, z, nx, nz)]."""
	out = []
	for x, z, dx, dz in muestras(line, paso):
		out.append((x, z, dz, -dx) if izquierda else (x, z, -dz, dx))
	return out


def corridas(muestras_ok) -> list:
	"""Agrupa [(punto o None, clave)] en corridas seguidas con la misma clave: [(clave, [puntos])]."""
	out = []
	actual, clave = [], None
	for punto, k in muestras_ok:
		if punto is None or k != clave:
			if len(actual) >= 2:
				out.append((clave, actual))
			actual, clave = [], k
		if punto is not None:
			actual.append(punto)
	if len(actual) >= 2:
		out.append((clave, actual))
	return out


def place_bardas(kept_ways, pos, lat0, lon0, manzanas, cotos, perfil, ocupado_polys, grupos_bodegas,
		satelite=None) -> list:
	"""Bardas y mallas deducidas del mapa, para MapBardas.gd: [{tipo, puntos, semilla}].
	- coto_calle: contorno de un coto que da a una calle publica, en la orilla de la
	  banqueta (MapBardas elige barda o malla segun el deterioro de la zona).
	- baldio: frente de un tramo sin construcciones (malla).
	- bodega: alrededor de cada grupo de naves (malla).
	- osm: las barrier=wall de OSM (se quitan de kept_ways para que OSM2World no las dibuje).
	Nada va encima de una construccion, de una calle o de un area verde (OSM, o pasto
	del satelite para los baldios). `ocupado_polys`: lotes de casas modelo, negocios y
	bodegas; `grupos_bodegas`: [[nave, ...]] (las naves de cada huella original);
	`satelite`: (ancho, alto, canales, bytes, x0, z0) de satelite_pasto.png."""
	ocupado = Raster(manzanas)
	verde = Raster(manzanas)
	osm_bardas = []
	for way_id, way in list(kept_ways.items()):
		tags = tags_of(way)
		ring = [local_xz(*pos[nd.get("ref")], lat0, lon0) for nd in way.findall("nd")]
		if "building" in tags:
			ocupado.poligono(ring)
		elif tags.get("barrier") == "wall" and tags.get("source") != CAMELLON_FUENTE:
			osm_bardas.append(ring)
			del kept_ways[way_id]
		elif len(ring) > 3 and ring[0] == ring[-1] and any(tags.get(k) in v for k, v in VERDES.items()):
			verde.poligono(ring)
	for poly in ocupado_polys:
		ocupado.poligono(poly)

	def pasto(x, z) -> bool:
		if satelite is None:
			return False
		sw, sh, ch, data, sx0, sz0 = satelite
		px, pz = int(x - sx0), int(z - sz0)
		return 0 <= px < sw and 0 <= pz < sh and data[(pz * sw + px) * ch] >= VERDE_SATELITE

	lines = street_lines(kept_ways, pos, lat0, lon0, STREET_TYPES)
	calles = Tramos(lines)

	def en_calle(x, z, propia, holgura=0.0) -> bool:
		"""Si (x, z) cae en el arroyo o la banqueta de una calle que no es `propia`."""
		for d, way_id, _, _ in calles.cercanos(x, z, 15.0):
			if way_id == propia:
				continue
			medio, izq, der = perfil.get(way_id, (SETBACK_MIN - 1.5, 0.0, 0.0))
			if d < medio + max(izq, der) + holgura:
				return True
		return False

	def libre(x, z) -> bool:
		return not ocupado.at(x, z) and not verde.at(x, z)

	def es_calle(x, z) -> bool:
		cx, cz = manzanas.cell(x, z)
		return not (0 <= cx < manzanas.w and 0 <= cz < manzanas.h) or bool(manzanas.street[cz * manzanas.w + cx])

	bardas = []

	def agregar(tipo, pts, tol=BARDA_SIMPLIFICAR):
		pts = simplificar(pts, tol)
		if len(pts) >= 2 and largo_linea(pts) >= BARDA_MIN:
			x, z = pts[len(pts) // 2]
			bardas.append({"tipo": tipo, "puntos": [[round(x, 2), round(z, 2)] for x, z in pts],
				"semilla": seed(f"barda/{tipo}/{x:.1f},{z:.1f}") % 100000})

	# Contorno de los cotos y baldios, por las calles: en la orilla de la banqueta
	baldios_verdes = 0
	for way_id, line, _ in lines:
		highway = tags_of(kept_ways[way_id]).get("highway")
		publica = way_id not in cotos.calles
		for izquierda in (True, False):
			s = borde_banqueta(perfil, way_id, izquierda, SETBACK_MIN) + FACHADA_HOLGURA
			puntos = muestras_lado(line, izquierda, BARDA_PASO)
			coto, baldio = [], []
			for x, z, nx, nz in puntos:
				bx, bz = x + nx * s, z + nz * s
				k = cotos.at(x + nx * (s + 1.5), z + nz * (s + 1.5))
				ok = libre(bx, bz) and not en_calle(bx, bz, way_id)
				coto.append(((bx, bz), k) if ok and publica and k else (None, 0))
				# Baldio: nada en BALDIO_FONDO m hacia adentro (o hasta otra calle)
				franja = None
				if ok and highway in BLOCK_STREET_TYPES and not k and manzanas.at(bx + nx * 1.5, bz + nz * 1.5):
					franja = 0
					d = s + 1.0
					while d < s + BALDIO_FONDO:
						px, pz = x + nx * d, z + nz * d
						if es_calle(px, pz):
							break
						if not libre(px, pz) or cotos.at(px, pz):
							franja = None
							break
						franja += pasto(px, pz)
						d += 1.5
					franja = None if franja is None else (franja, int((d - s - 1.0) / 1.5))
				baldio.append(((bx, bz, franja), 1) if franja else (None, 0))
			for k, pts in corridas(coto):
				agregar("coto_calle", pts)
			for _, pts in corridas(baldio):
				verdes = sum(f[0] for _, _, f in pts)
				total = sum(f[1] for _, _, f in pts)
				if largo_linea([(x, z) for x, z, _ in pts]) < BALDIO_MIN:
					continue
				if total and verdes >= VERDE_FRACCION * total:
					baldios_verdes += 1
					continue
				agregar("baldio", [(x, z) for x, z, _ in pts])
	n_calle = sum(1 for b in bardas if b["tipo"] == "coto_calle")
	n_baldio = len(bardas) - n_calle

	# Bodegas: malla a BODEGA_MALLA m de las naves de cada huella
	for naves in grupos_bodegas:
		esquinas = []
		for b in naves:
			esquinas += rectangulo(b["x"], b["z"], b["rotacion_y"], b["ancho"] + 2 * BODEGA_MALLA, BODEGA_MALLA,
				-b["fondo"] - BODEGA_MALLA)
		casco = envolvente(esquinas)
		puntos = []
		for (ax, az), (bx, bz) in zip(casco, casco[1:] + casco[:1]):
			n = max(1, int(math.hypot(bx - ax, bz - az) / BARDA_PASO))
			puntos += [(ax + (bx - ax) * t / n, az + (bz - az) * t / n) for t in range(n)]
		ok = [libre(x, z) and not en_calle(x, z, None, FACHADA_HOLGURA) for x, z in puntos]
		if all(ok):
			agregar("bodega", puntos + puntos[:1])
			continue
		# Que la vuelta empiece en un hueco, para no partir una corrida en dos
		k = ok.index(False)
		puntos, ok = puntos[k:] + puntos[:k], ok[k:] + ok[:k]
		for _, pts in corridas([(p, 1) if bueno else (None, 0) for p, bueno in zip(puntos, ok)]):
			agregar("bodega", pts)
	n_bodega = len(bardas) - n_calle - n_baldio

	for ring in osm_bardas:
		agregar("osm", ring, 0.05)
	print(f"  Bardas: {n_calle} tramos de contorno de coto, {n_baldio} baldios "
		f"({baldios_verdes} quitados por pasto), {n_bodega} mallas de bodega, {len(bardas) - n_calle - n_baldio - n_bodega} de OSM; "
		f"{sum(largo_linea(b['puntos']) for b in bardas) / 1000:.1f} km")
	return bardas, ocupado


def place_plumas(kept_ways, pos, lat0, lon0, plumas, perfil, inside, cotos, ocupado) -> tuple:
	"""Plumas (poste y brazo roto en MapBardas.gd) y casetas de los cotos.
	Cada barrier=gate/lift_gate de una calle es una pluma, pero en OSM una entrada de
	coto suele tener dos carriles (entrada y salida) y a veces dos lineas de plumas:
	las plumas cercanas del mismo coto forman un acceso, del que solo queda la linea mas
	cercana a la calle publica (una pluma por carril) y una sola caseta, en la isleta
	entre carriles si cabe, si no a un lado (hacia adentro del coto). Un acceso cuyo
	coto solo tiene calles service (estacionamiento, gasolinera) no lleva caseta.
	Devuelve (plumas, casetas)."""
	todas = []
	vistos = set()
	for way_id, way in kept_ways.items():
		if tags_of(way).get("highway") not in STREET_TYPES:
			continue
		refs = [nd.get("ref") for nd in way.findall("nd")]
		for i, r in enumerate(refs):
			# Un nodo puede estar en dos calles: una pluma por nodo
			if r not in plumas or r in vistos:
				continue
			x, z = local_xz(*pos[r], lat0, lon0)
			if not inside(x, z):
				continue
			a, b = refs[max(0, i - 1)], refs[min(len(refs) - 1, i + 1)]
			(ax, az), (bx, bz) = local_xz(*pos[a], lat0, lon0), local_xz(*pos[b], lat0, lon0)
			if math.hypot(bx - ax, bz - az) < 1e-6:
				continue
			vistos.add(r)
			medio = perfil.get(way_id, (SETBACK_MIN - 1.5, 0.0, 0.0))[0]
			todas.append({"x": round(x, 2), "z": round(z, 2), "rotacion_y": round(math.atan2(bx - ax, bz - az), 4),
				"ancho": round(2 * medio, 2), "tipo": plumas[r], "semilla": seed(f"pluma/{r}") % 100000,
				"_coto": cotos.calles.get(way_id, 0), "_nodo": r})

	# Cotos que solo tienen calles service
	tipos_coto = collections.defaultdict(set)
	for way_id, k in cotos.calles.items():
		tipos_coto[k].add(tags_of(kept_ways[way_id]).get("highway"))
	publicas = [(way_id, line) for way_id, line, _ in street_lines(kept_ways, pos, lat0, lon0, BLOCK_STREET_TYPES)
		if way_id not in cotos.calles]

	# Accesos: plumas cercanas del mismo coto
	padre = list(range(len(todas)))

	def raiz(i):
		while padre[i] != i:
			padre[i] = padre[padre[i]]
			i = padre[i]
		return i

	for i, p in enumerate(todas):
		for j in range(i):
			q = todas[j]
			if p["_coto"] == q["_coto"] and math.hypot(p["x"] - q["x"], p["z"] - q["z"]) < ACCESO_RADIO:
				padre[raiz(i)] = raiz(j)
	accesos = collections.defaultdict(list)
	for i, p in enumerate(todas):
		accesos[raiz(i)].append(p)

	salida, casetas = [], []
	for grupo in accesos.values():
		# La linea de afuera, y una pluma por carril (la del arroyo mas ancho): otra
		# pluma que cae dentro del ancho de su arroyo esta en el mismo carril
		lejos = {id(p): math.sqrt((calle_cercana(p["x"], p["z"], publicas) or (math.inf,))[0]) for p in grupo}
		minimo = min(lejos.values())
		carriles = []
		for p in sorted((p for p in grupo if lejos[id(p)] <= minimo + ACCESO_LINEA), key=lambda p: -p["ancho"]):
			if all(abs((p["x"] - q["x"]) * math.cos(q["rotacion_y"]) - (p["z"] - q["z"]) * math.sin(q["rotacion_y"]))
					>= q["ancho"] / 2 for q in carriles):
				carriles.append(p)
		for p in carriles:
			salida.append({k: v for k, v in p.items() if not k.startswith("_")})
		if not tipos_coto[carriles[0]["_coto"]] - {"service"}:
			continue

		# Carriles ordenados a lo ancho (X local de la primera pluma, como en MapBardas)
		rot = carriles[0]["rotacion_y"]
		ux, uz = math.cos(rot), -math.sin(rot)
		x0, z0 = carriles[0]["x"], carriles[0]["z"]
		orden = sorted(((p["x"] - x0) * ux + (p["z"] - z0) * uz, p) for p in carriles)
		along = sum(((p["x"] - x0) * -uz + (p["z"] - z0) * ux) for p in carriles) / len(carriles)
		isleta = None
		for (sa, pa), (sb, pb) in zip(orden, orden[1:]):
			hueco = sb - sa - pa["ancho"] / 2 - pb["ancho"] / 2
			if hueco >= CASETA_ISLETA and (isleta is None or hueco > isleta[0]):
				isleta = (hueco, (sa + pa["ancho"] / 2 + sb - pb["ancho"] / 2) / 2)
		if isleta is not None:
			s = isleta[1]
			# Cada poste del lado de afuera de su carril, lejos de la caseta
			for p in salida[len(salida) - len(carriles):]:
				pu = (math.cos(p["rotacion_y"]), -math.sin(p["rotacion_y"]))
				hacia = (p["x"] - (x0 + s * ux), p["z"] - (z0 + s * uz))
				p["lado"] = 1 if hacia[0] * pu[0] + hacia[1] * pu[1] >= 0 else -1
		else:
			# A un lado: hacia adentro del coto y fuera de lo construido
			(s_min, p_min), (s_max, p_max) = orden[0], orden[-1]
			opciones = [s_min - p_min["ancho"] / 2 - CASETA_LADO, s_max + p_max["ancho"] / 2 + CASETA_LADO]

			def punto(s):
				return x0 + s * ux + along * -uz, z0 + s * uz + along * ux

			def calificar(s):
				x, z = punto(s)
				return (cotos.at(x, z) != carriles[0]["_coto"], bool(ocupado.at(x, z)))

			s = min(opciones, key=calificar)
		x, z = x0 + s * ux + along * -uz, z0 + s * uz + along * ux
		casetas.append({"x": round(x, 2), "z": round(z, 2), "rotacion_y": rot,
			"semilla": seed(f"caseta/{carriles[0]['_nodo']}") % 100000})
	return salida, casetas


def a_lo_largo(line, paso, inicio):
	"""Puntos cada `paso` m a lo largo de toda la linea, el primero a `inicio` m: [(x, z, dx, dz)]."""
	out = []
	falta = inicio
	for (ax, az), (bx, bz) in zip(line, line[1:]):
		length = math.hypot(bx - ax, bz - az)
		if length < 1e-6:
			continue
		dx, dz = (bx - ax) / length, (bz - az) / length
		t = falta
		while t <= length:
			out.append((ax + dx * t, az + dz * t, dx, dz))
			t += paso
		falta = t - length
	return out


class RejillaPuntos:
	"""Indice por celdas de puntos (x, z), para buscar los cercanos rapido."""

	CELDA = 20.0

	def __init__(self):
		self.celdas = collections.defaultdict(list)

	def agregar(self, x, z) -> None:
		self.celdas[(int(x // self.CELDA), int(z // self.CELDA))].append((x, z))

	def hay(self, x, z, radio) -> bool:
		r = int(radio // self.CELDA) + 1
		cx, cz = int(x // self.CELDA), int(z // self.CELDA)
		return any(math.hypot(x - px, z - pz) < radio
			for i in range(cx - r, cx + r + 1) for j in range(cz - r, cz + r + 1) for px, pz in self.celdas.get((i, j), ()))


def place_alumbrado(lines, perfil, lado_camellon, camellones, inside, ocupado, estorbos) -> list:
	"""Postes de luz: [{x, z, rotacion_y (el brazo ve a +Z local), alto, brazo, doble,
	avenida, semilla}]. `lines`: calles de BLOCK_STREET_TYPES con su tipo
	[(way_id, line, refs, highway)]; `estorbos`: [(x, z)] de altos, puestos, plumas y
	casetas; `ocupado`: Raster de construcciones y lotes."""
	tramos = Tramos([(w, l, r) for w, l, r, _ in lines])
	grado = collections.Counter()
	xz = {}
	for _, line, refs, _ in lines:
		for (a, ra), (b, rb) in zip(zip(line, refs), zip(line[1:], refs[1:])):
			grado[ra] += 1
			grado[rb] += 1
			xz[ra], xz[rb] = a, b
	esquinas = RejillaPuntos()
	for r, n in grado.items():
		if n >= 3:
			esquinas.agregar(*xz[r])
	cerca = RejillaPuntos()
	for x, z in estorbos:
		cerca.agregar(x, z)

	postes = []

	def libre(x, z, propia) -> bool:
		if not inside(x, z) or ocupado.at(x, z):
			return False
		if esquinas.hay(x, z, ALUMBRADO_ESQUINA) or cerca.hay(x, z, ALUMBRADO_ESTORBO):
			return False
		# Ni en el arroyo de otra calle
		for d, way_id, _, _ in tramos.cercanos(x, z, 12.0):
			if way_id != propia and d < perfil.get(way_id, (3.0,))[0] + 0.2:
				return False
		return True

	def agregar(x, z, rot, avenida, doble, clave):
		alto, brazo = ALUMBRADO_POSTE_AVENIDA if avenida or doble else ALUMBRADO_POSTE
		postes.append({"x": round(x, 2), "z": round(z, 2), "rotacion_y": round(rot, 4), "alto": alto,
			"brazo": brazo, "doble": doble, "avenida": avenida, "semilla": seed(clave) % 100000})
		cerca.agregar(x, z)

	for way_id, line, _, hw in lines:
		if way_id in lado_camellon:
			continue  # Van en el camellon
		medio, izq, der = perfil.get(way_id, (3.0, 0.0, 0.0))
		avenida = hw in ALUMBRADO_AVENIDAS
		s = seed(f"alumbrado/{way_id}")
		# Las calles locales: del lado con banqueta mas ancha (al azar si son iguales)
		lado_fijo = izq > der or (izq == der and s % 2 == 0)
		for i, (x, z, dx, dz) in enumerate(a_lo_largo(line, ALUMBRADO_PASO, ALUMBRADO_PASO / 2)):
			izquierda = (i + s) % 2 == 0 if avenida else lado_fijo
			nx, nz = (dz, -dx) if izquierda else (-dz, dx)
			d = medio + ALUMBRADO_GUARNICION
			px, pz = x + nx * d, z + nz * d
			if libre(px, pz, way_id):
				# El brazo hacia la calle
				agregar(px, pz, math.atan2(-nx, -nz), avenida, False, f"alumbrado/{way_id}/{i}")

	# Camellones: el anillo es un lado de ida y el otro de vuelta, punto por punto
	for k, ring in enumerate(camellones):
		n = len(ring) // 2
		medio_linea = [((ring[i][0] + ring[-1 - i][0]) / 2, (ring[i][1] + ring[-1 - i][1]) / 2) for i in range(n)]
		anchos = [math.hypot(ring[i][0] - ring[-1 - i][0], ring[i][1] - ring[-1 - i][1]) for i in range(n)]
		if not medio_linea or min(anchos) < ALUMBRADO_CAMELLON_MIN:
			continue
		for i, (x, z, dx, dz) in enumerate(a_lo_largo(medio_linea, ALUMBRADO_PASO, ALUMBRADO_PASO / 2)):
			if libre(x, z, None):
				# Los dos brazos a lo ancho del camellon
				agregar(x, z, math.atan2(dz, -dx), True, True, f"alumbrado/camellon/{k}/{i}")
	return postes


def place_altos(lines, inside, perfil=None) -> tuple:
	"""Un alto en una de cada ALTO_CADA esquinas (nodos donde llegan 3 o mas tramos
	de calle), en la banqueta derecha antes del cruce, viendo al trafico."""
	vecinos = collections.defaultdict(set)
	xz = {}
	calle_de = {}
	for way_id, line, refs in lines:
		for (a, ra), (b, rb) in zip(zip(line, refs), zip(line[1:], refs[1:])):
			vecinos[ra].add(rb)
			vecinos[rb].add(ra)
			xz[ra], xz[rb] = a, b
			calle_de[(ra, rb)] = calle_de[(rb, ra)] = way_id
	esquinas = sorted(n for n, v in vecinos.items() if len(v) >= 3 and inside(*xz[n]))
	rng = random.Random(SEMILLA_PROPS)
	rng.shuffle(esquinas)
	placed = []
	for node in esquinas[::ALTO_CADA]:
		x, z = xz[node]
		llega = sorted(vecinos[node])[seed(node) % len(vecinos[node])]
		lx, lz = xz[llega]
		length = math.hypot(x - lx, z - lz)
		if length < ALTO_ANTES + 2.0:
			continue
		dx, dz = (x - lx) / length, (z - lz) / length  # sentido del trafico que llega
		rx, rz = -dz, dx  # derecha del conductor (x = este, z = sur)
		# En la banqueta, junto a la guarnicion
		lado = PUESTO_STREET_DIST
		if perfil and calle_de[(llega, node)] in perfil:
			lado = perfil[calle_de[(llega, node)]][0] + 0.4
		placed.append({
			"tipo": "alto", "nombre": "Alto",
			"x": round(x - dx * ALTO_ANTES + rx * lado, 3),
			"z": round(z - dz * ALTO_ANTES + rz * lado, 3),
			"rotacion_y": round(math.atan2(-dx, -dz), 4),
			"ancho": 0.6, "fondo": 0.2, "casa_reemplazada": None, "origen": f"esquina node/{node}",
		})
	return placed, len(esquinas)


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
	parser.add_argument("--colonias-denue", help="data/map/denue_colonias.json (fetch_denue.py)")
	parser.add_argument("--colonias", help="data/map/colonias.json: correcciones a mano por manzana")
	parser.add_argument("--casas", help="data/map/casas.json: que modelos de casa van en cada colonia")
	parser.add_argument("--salida-casas", help="JSON con las casas modelo, para Godot (MapCasas.gd)")
	parser.add_argument("--salida-bodegas", help="JSON con las bodegas huecas, para Godot (MapBodegas.gd)")
	parser.add_argument("--salida-bardas", help="JSON con las bardas, mallas y plumas, para Godot (MapBardas.gd)")
	parser.add_argument("--salida-alumbrado", help="JSON con los postes de luz, para Godot (MapAlumbrado.gd)")
	parser.add_argument("--satelite-pasto", help="data/map/satelite_pasto.png (fetch_satelite.py): los baldios con pasto no llevan malla")
	parser.add_argument("--png-colonias", help="PNG de debug con las manzanas pintadas por colonia")
	parser.add_argument("--huellas", help="data/map/huellas_tiendas.json (huellas_tiendas.gd): lo que ocupa cada modelo de negocio")
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

	def inside_local(x, z):
		return min_x <= x <= max_x and min_z <= z <= max_z

	# Anchos, banquetas y camellones (antes de casas y tiendas, que se alinean a la banqueta)
	perfil, camellones, lado_camellon = calles_y_banquetas(root, kept_ways, pos, lat0, lon0)

	min_x, max_z = local_xz(south, west, lat0, lon0)
	max_x, min_z = local_xz(north, east, lat0, lon0)

	# Lo que ocupa cada modelo de negocio y de casa en el juego (huellas_tiendas.gd)
	huellas = {}
	if args.huellas and os.path.exists(args.huellas):
		with open(args.huellas, encoding="utf-8") as f:
			huellas = json.load(f)

	# Manzanas y colonias (antes de las tiendas: las tiendas quitan casas)
	manzanas = colonia_de = None
	huellas_negocios = []
	if args.colonias_denue and os.path.exists(args.colonias_denue):
		block_lines = street_lines(kept_ways, pos, lat0, lon0, BLOCK_STREET_TYPES)
		mx0, mz0 = local_xz(south - dlat, west - dlon, lat0, lon0)
		mx1, mz1 = local_xz(north + dlat, east + dlon, lat0, lon0)
		manzanas = Manzanas(block_lines, mx0, min(mz0, mz1), mx1, max(mz0, mz1))
		with open(args.colonias_denue, encoding="utf-8") as f:
			negocios = [(*local_xz(lat, lon, lat0, lon0), colonia) for lat, lon, colonia in json.load(f)["negocios"]]
		manuales = []
		if args.colonias and os.path.exists(args.colonias):
			with open(args.colonias, encoding="utf-8") as f:
				for key, colonia in json.load(f).items():
					if not key.startswith("_"):
						lat, lon = map(float, key.split(","))
						manuales.append((local_xz(lat, lon, lat0, lon0), colonia))
		building_rings = [[local_xz(*pos[nd.get("ref")], lat0, lon0) for nd in way.findall("nd")]
			for way in kept_ways.values() if "building" in tags_of(way)]
		colonia_de = colonias_por_manzana(manzanas, negocios, [centroid(r[:-1]) for r in building_rings], manuales)
		print(f"  Manzanas: {manzanas.count}, con colonia: {len(colonia_de)}")
		if args.png_colonias:
			png_colonias(args.png_colonias, manzanas, colonia_de, building_rings)

	# Tiendas y puestos: los de puntos.json mas los que ya estan en OSM
	placed = []
	if args.salida_puntos:
		puntos = []
		omitir = set()
		cambiar_tipo = {}
		for path in args.puntos:
			if os.path.exists(path):
				with open(path, encoding="utf-8") as f:
					data = json.load(f)
				puntos += [p for p in data.get("puntos", []) if not p.get("tipo", "").startswith("_")]
				omitir.update(data.get("omitir", []))
				cambiar_tipo.update(data.get("cambiar_tipo", {}))
		puntos += osm_puntos(root, kept_ways, pos)
		puntos = [p for p in puntos if p.get("origen") not in omitir]
		# El tipo de dibujo antes de buscar repetidos (abarrotes o licoreria...)
		puntos = [subtipo(dict(p, tipo=cambiar_tipo.get(p.get("origen"), p["tipo"]))) for p in puntos]
		quitados = [p for p in puntos if p["tipo"] in TIPOS_QUITADOS]
		if quitados:
			print(f"  Puntos de tipos que ya no se dibujan: {len(quitados)} quitados ({', '.join(sorted({p['tipo'] for p in quitados}))})")
		puntos = [p for p in puntos if p["tipo"] not in TIPOS_QUITADOS]

		# Repetidos de la misma familia: gana el local sobre el puesto (taqueria), luego
		# el puesto a mano, el DENUE y al final OSM
		def priority(p):
			origen = p.get("origen", "")
			return (p["tipo"] in NO_REPLACE_TIPOS, 0 if not origen else (1 if origen.startswith("denue") else 2))

		def familia(tipo):
			return FAMILIA.get(tipo, tipo)

		kept_puntos = []
		for p in sorted(puntos, key=priority):
			px, pz = local_xz(p["lat"], p["lon"], lat0, lon0)
			if all(familia(q["tipo"]) != familia(p["tipo"])
					or math.hypot(px - qx, pz - qz) >= DUPLICATE_DIST_TIPO.get(p["tipo"], DUPLICATE_DIST)
					for q, qx, qz in kept_puntos):
				kept_puntos.append((p, px, pz))
		print(f"  Puntos repetidos (misma familia a < {DUPLICATE_DIST:.0f} m, abarrotes a < {DUPLICATE_DIST_TIPO['abarrotes']:.0f} m): {len(puntos) - len(kept_puntos)} quitados")
		for p, _, _ in kept_puntos:
			p["nombre"] = parodia(p.get("nombre", ""))
		print("  Negocios: " + ", ".join(f"{t} {n}" for t, n in collections.Counter(p["tipo"] for p, _, _ in kept_puntos).most_common()))
		placed = place_puntos([p for p, _, _ in kept_puntos], kept_ways, pos, lat0, lon0, perfil)
		# Ningun negocio en la calle: se recorre a la banqueta mas cercana (sin service:
		# entradas de gasolineras y estacionamientos)
		todas = street_lines(kept_ways, pos, lat0, lon0, BLOCK_STREET_TYPES)
		calles = Tramos(todas)
		streets = [(w, line) for w, line, _ in todas]
		movidos = []
		for p in placed:
			ignorar = None
			if p["tipo"] in NO_REPLACE_TIPOS:
				ignorar = calle_cercana(p["x"], p["z"], streets)[3]
			d = alejar_de_calles(p, huellas, calles, perfil, ignorar)
			if d > 0.05:
				movidos.append(d)
		if movidos:
			print(f"  Negocios recorridos fuera de la calle: {len(movidos)}, {sum(movidos) / len(movidos):.1f} m en promedio")
		prop_lines = street_lines(kept_ways, pos, lat0, lon0, BLOCK_STREET_TYPES)
		altos, n_esquinas = place_altos(prop_lines, inside_local, perfil)
		placed += altos
		print(f"  Altos: {len(altos)} de {n_esquinas} esquinas")
		# Casas encimadas en un negocio (los modelos crecen hacia atras y a los lados): se quitan
		if huellas:
			huellas_negocios = [h for h in (huella_negocio(p, huellas) for p in placed) if h]
			quitadas = quitar_edificios_encimados(kept_ways, pos, lat0, lon0, huellas_negocios)
			print(f"  Casas debajo de un negocio: {quitadas} quitadas")

	# Bodegas huecas (despues de las tiendas, antes de las casas: las hileras paran en ellas)
	grupos_bodegas = []
	huellas_bodegas_todas = []
	if args.salida_bodegas and colonia_de is not None:
		todas = street_lines(kept_ways, pos, lat0, lon0, STREET_TYPES)
		bodegas = place_bodegas(kept_ways, pos, lat0, lon0, manzanas, colonia_de, Tramos(todas), perfil, huellas_negocios)
		huellas_bodegas = [huella_bodega(b) for b in bodegas]
		encimados = quitar_edificios_encimados(kept_ways, pos, lat0, lon0, huellas_bodegas)
		if encimados:
			print(f"  Edificios debajo de una bodega: {encimados} quitados")
		huellas_negocios += huellas_bodegas
		huellas_bodegas_todas = huellas_bodegas
		grupos = collections.defaultdict(list)
		for b in bodegas:
			grupos[b.pop("grupo")].append(b)
		grupos_bodegas = list(grupos.values())
		os.makedirs(os.path.dirname(args.salida_bodegas), exist_ok=True)
		with open(args.salida_bodegas, "w", encoding="utf-8") as f:
			f.write('{"bodegas": [\n' + ",\n".join(json.dumps(b, ensure_ascii=False) for b in bodegas) + "\n]}\n")

	# Cotos (antes de las casas: en su contorno no van casas modelo, va la barda)
	cotos = None
	plumas = {}
	if args.salida_bardas and manzanas is not None:
		plumas = {node_id: tags_of(n)["barrier"] for node_id, n in nodes.items()
			if tags_of(n).get("barrier") in PLUMAS}
		cotos = Cotos(kept_ways, pos, lat0, lon0, plumas, manzanas)

	# Casas modelo por colonia (despues de las tiendas, que ya tomaron sus lotes)
	lotes_casas = []
	if args.casas and args.salida_casas and colonia_de is not None:
		with open(args.casas, encoding="utf-8") as f:
			reglas = {k: v for k, v in json.load(f).items() if not k.startswith("_")}
		casa_lines = street_lines(kept_ways, pos, lat0, lon0, STREET_TYPES)
		# Los locales de colonia no cortan la hilera: se meten en ella
		locales = [p for p in placed if p["tipo"] in LOCALES_HILERA] if args.salida_puntos and huellas else []
		otros = [h for h in (huella_negocio(p, huellas) for p in placed if p["tipo"] not in LOCALES_HILERA) if h] \
			if args.salida_puntos and huellas else []
		casas = place_casas(kept_ways, pos, lat0, lon0, casa_lines, manzanas, colonia_de, reglas,
			huellas.get("casas", {}), perfil, otros + huellas_bodegas_todas, Tramos(casa_lines), cotos, locales, huellas)
		sin_lugar = [p for p in locales if p.pop("_quitar", False)]
		if sin_lugar:
			placed = [p for p in placed if not any(p is q for q in sin_lugar)]
			locales = [p for p in locales if not any(p is q for q in sin_lugar)]
			print(f"  Locales sin lugar: {len(sin_lugar)} quitados")
		pisos_locales(locales, casas)
		if locales:
			# Con su lote nuevo: lo que quede debajo se va, y las bardas y postes lo esquivan
			huellas_locales = [h for h in (huella_negocio(p, huellas) for p in locales) if h]
			quitadas = quitar_edificios_encimados(kept_ways, pos, lat0, lon0, huellas_locales)
			if quitadas:
				print(f"  Edificios debajo de un local movido a la hilera: {quitadas} quitados")
			huellas_negocios = otros + huellas_bodegas_todas + huellas_locales
		# Un lote de casa modelo que se mete en un negocio tampoco va
		antes = len(casas)
		casas = [c for c in casas if not any(se_enciman(rectangulo(c["x"], c["z"], c["rotacion_y"], c["ancho"], 0.0, -c["fondo"]), h)
			for h in huellas_negocios)]
		if antes != len(casas):
			print(f"  Casas modelo encimadas en un negocio: {antes - len(casas)} quitadas")
		if args.salida_puntos:
			punto = elegir_puntos(casas)
			placed += punto
			print(f"  El punto (venta ilegal): {len(punto)} casas, una por colonia")
		os.makedirs(os.path.dirname(args.salida_casas), exist_ok=True)
		with open(args.salida_casas, "w", encoding="utf-8") as f:
			f.write('{"casas": [\n' + ",\n".join(json.dumps(c, ensure_ascii=False) for c in casas) + "\n]}\n")
		print(f"  Casas modelo: {len(casas)} -> {args.salida_casas}")
		for (colonia, modelo), n in sorted(collections.Counter((c["colonia"], c["modelo"]) for c in casas).items()):
			print(f"    {colonia or '(sin colonia)'}: {modelo} x{n}")
		lotes_casas = [rectangulo(c["x"], c["z"], c["rotacion_y"], c["ancho"], 0.0, -c["fondo"]) for c in casas]

	# Negocios (despues de las casas: los locales se movieron a la hilera)
	if args.salida_puntos:
		if huellas:
			placed, quitados = quitar_negocios_encimados(placed, huellas)
			if quitados:
				print(f"  Negocios encimados en otro: {len(quitados)} quitados ("
					+ ", ".join(f"{p['tipo']} {p.get('nombre', '')}" for p in quitados) + ")")
		conteo = marcar_interactivos([p for p in placed if p["tipo"] != "alto"])
		print("  Interactivos: " + ", ".join(f"{g} {n}" for g, n in conteo.most_common())
			+ f" (de {sum(1 for p in placed if p.get('giro'))} con giro)")
		os.makedirs(os.path.dirname(args.salida_puntos), exist_ok=True)
		with open(args.salida_puntos, "w", encoding="utf-8") as f:
			json.dump({"puntos": placed}, f, ensure_ascii=False, indent="\t")
		replaced = sum(1 for p in placed if p.get("casa_reemplazada"))
		print(f"  Puntos: {len(placed)} ({replaced} reemplazan una casa) -> {args.salida_puntos}")

	# Bardas y mallas (al final: no van encima de nada de lo anterior)
	if cotos is not None:
		satelite = None
		meta_path = os.path.join(os.path.dirname(args.satelite_pasto or ""), "satelite_meta.json")
		if args.satelite_pasto and os.path.exists(args.satelite_pasto) and os.path.exists(meta_path):
			sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
			from make_vegetacion import read_png
			with open(meta_path, encoding="utf-8") as f:
				meta = json.load(f)
			satelite = (*read_png(args.satelite_pasto), meta["x0"], meta["z0"])
		bardas, ocupado = place_bardas(kept_ways, pos, lat0, lon0, manzanas, cotos, perfil,
			lotes_casas + huellas_negocios, grupos_bodegas, satelite)
		plumas_mapa, casetas = place_plumas(kept_ways, pos, lat0, lon0, plumas, perfil, inside_local, cotos, ocupado)
		print(f"  Plumas: {len(plumas_mapa)} de {len(plumas)} nodos, casetas: {len(casetas)}")
		os.makedirs(os.path.dirname(args.salida_bardas), exist_ok=True)
		with open(args.salida_bardas, "w", encoding="utf-8") as f:
			f.write('{"bardas": [\n' + ",\n".join(json.dumps(b) for b in bardas) + '\n],\n"plumas": [\n'
				+ ",\n".join(json.dumps(p) for p in plumas_mapa) + '\n],\n"casetas": [\n'
				+ ",\n".join(json.dumps(c) for c in casetas) + "\n]}\n")

		# Alumbrado publico (al final: no va encima de nada de lo anterior)
		if args.salida_alumbrado:
			estorbos = [(p["x"], p["z"]) for p in placed if p["tipo"] == "alto" or p["tipo"].startswith("puesto")]
			# El puesto de la taqueria-local, en la banqueta frente a la mitad derecha
			# del local (MapPuntos._taqueria_puesto: TAQUERIA_PUESTO m de la fachada)
			for p in placed:
				if p["tipo"] == "taqueria":
					r = p["rotacion_y"]
					adelante = p["fondo"] / 2 + 1.3
					estorbos.append((p["x"] + math.sin(r) * adelante + math.cos(r) * 1.2,
						p["z"] + math.cos(r) * adelante - math.sin(r) * 1.2))
			estorbos += [(p["x"], p["z"]) for p in plumas_mapa + casetas]
			calles = [(w, l, r, tags_of(kept_ways[w]).get("highway"))
				for w, l, r in street_lines(kept_ways, pos, lat0, lon0, BLOCK_STREET_TYPES)]
			postes = place_alumbrado(calles, perfil, lado_camellon, camellones, inside_local, ocupado, estorbos)
			os.makedirs(os.path.dirname(args.salida_alumbrado), exist_ok=True)
			with open(args.salida_alumbrado, "w", encoding="utf-8") as f:
				f.write('{"postes": [\n' + ",\n".join(json.dumps(p) for p in postes) + "\n]}\n")
			print(f"  Alumbrado: {len(postes)} postes ({sum(p['doble'] for p in postes)} en camellones) -> {args.salida_alumbrado}")

	filled = 0
	for way in kept_ways.values():
		filled += fill_building(way, "way")
		# Sin ventanas: las pinta ps1_facade. Asi el LOD 2 (que trae las banquetas) no agrega vidrios
		if "building" in tags_of(way) or "building:part" in tags_of(way):
			set_tag(way, "window", "no")
	for rel in kept_relations:
		filled += fill_building(rel, "relation")
		set_tag(rel, "window", "no")

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
