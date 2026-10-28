"""Baja las tiendas, puestos y farmacias de la zona del mapa desde el DENUE de INEGI.

El DENUE (Directorio Estadistico Nacional de Unidades Economicas) trae cada
negocio con su giro (codigo SCIAN), si es fijo o semifijo (puesto) y su lat/lon.
Es informacion publica (Terminos de Libre Uso del INEGI, hay que citar la fuente).
Google Maps no sirve para esto: sus terminos prohiben sacar sus datos.

Solo guardamos los giros que el mapa sabe dibujar (ver TIPOS_SCIAN); el resto
se cuenta y se ignora. Para agregar o corregir puntos a mano usa data/map/puntos.json.

Ademas guarda la colonia (nomb_asent) de todos los negocios de la zona, de
cualquier giro: prepare_osm.py la usa para saber de que colonia es cada manzana.

Uso: python3 -I tools/map_import/fetch_denue.py   (lee tools/map_import/area.env)
Salida: data/map/denue_puntos.json y data/map/denue_colonias.json (las lee
prepare_osm.py desde build_glb.sh)
"""

import collections
import csv
import io
import json
import os
import re
import sys
import tempfile
import urllib.request
import zipfile

# 14 = Jalisco. INEGI reemplaza este archivo con cada actualizacion del DENUE.
DENUE_URL = "https://www.inegi.org.mx/contenidos/masiva/denue/denue_14_csv.zip"

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Codigo SCIAN -> tipo de punto del mapa (MapPuntos.gd tiene un color por tipo)
TIPOS_SCIAN = {
	"461110": "tienda",       # abarrotes, misceláneas
	"462112": "tienda",       # minisupers (los OXXO salen por nombre)
	"461130": "tienda",       # frutas y verduras
	"461121": "tienda",       # carnicerias
	"461122": "tienda",       # pollerias
	"461150": "tienda",       # cremerias
	"464111": "farmacia",
	"464112": "farmacia",     # farmacias con minisuper
	"722514": "taqueria",     # tacos y tortas
	"722513": "taqueria",     # antojitos
	"311830": "tortilleria",
	"468411": "gasolinera",
	"467111": "ferreteria",   # ferreterias y tlapalerias
	"312112": "purificadora", # purificacion y embotellado de agua
}

# Nombres de colonia que el DENUE escribe de varias formas -> nombre unico
COLONIA_ALIAS = {
	"PARQUES DE SANTAMARIA": "PARQUES DE SANTA MARIA",
	"PARQUE SANTA MARIA": "PARQUES DE SANTA MARIA",
	"HACIENDA DE SAN JOSE": "HACIENDAS DE SAN JOSE",
	"PALMIRA": "LA PALMIRA",
	"FRACCIONAMIENTO ARROYO SECO": "ARROYO SECO",
	"FRACCIONAMIENTO DE REAL": "EL REAL",
	"FRACCIONAMIENTO EL REAL": "EL REAL",
	"FRACCIONAMIENTO DEL REAL": "EL REAL",
}

# Comida que se vende en puesto (semifijo) aunque el giro sea otro
GIROS_COMIDA = {"722511", "722512", "722513", "722514", "722515", "722517", "722519", "461170"}


def read_area() -> dict:
	area = {}
	with open(os.path.join(ROOT, "tools", "map_import", "area.env"), encoding="utf-8") as f:
		for line in f:
			line = line.strip()
			if line and not line.startswith("#") and "=" in line:
				key, value = line.split("=", 1)
				area[key] = float(value)
	return area


def tipo_de(row) -> str | None:
	codigo = row["codigo_act"]
	nombre = (row["nom_estab"] + " " + row["raz_social"]).upper()
	if row["tipoUniEco"].strip().lower() == "semifijo":
		return "puesto_tacos" if codigo in GIROS_COMIDA else "puesto"
	if "OXXO" in nombre and codigo.startswith("46"):
		return "oxxo"
	# Muchas purificadoras de barrio estan dadas de alta como comercio de agua
	if ("PURIFICADORA" in nombre or "AGUA PURIFICADA" in nombre) and codigo[:2] in ("31", "46"):
		return "purificadora"
	return TIPOS_SCIAN.get(codigo)


def colonia_de(row) -> str:
	nombre = re.sub(r"\s+", " ", row["nomb_asent"]).strip().upper()
	return COLONIA_ALIAS.get(nombre, nombre)


def nombre_de(row, tipo: str) -> str:
	nombre = re.sub(r"\s+", " ", row["nom_estab"]).strip()
	if tipo == "oxxo":
		return "OXXO"  # quita "SUC 509EO PARQUES ITESO GDL"
	return nombre.title()


def main() -> None:
	area = read_area()
	south, west, north, east = area["SOUTH"], area["WEST"], area["NORTH"], area["EAST"]
	out_path = os.path.join(ROOT, "data", "map", "denue_puntos.json")
	colonias_path = os.path.join(ROOT, "data", "map", "denue_colonias.json")

	print(f"Bajando {DENUE_URL} (~40 MB)...")
	request = urllib.request.Request(DENUE_URL, headers={"User-Agent": "taquito-map-import/1.0"})
	with tempfile.TemporaryFile() as tmp:
		with urllib.request.urlopen(request, timeout=300) as response:
			if "zip" not in response.headers.get("Content-Type", ""):
				sys.exit(f"ERROR: INEGI no devolvio un zip ({response.headers.get('Content-Type')}); revisa DENUE_URL")
			while chunk := response.read(1 << 20):
				tmp.write(chunk)
		tmp.seek(0)

		puntos = []
		colonias = []
		ignorados = collections.Counter()
		with zipfile.ZipFile(tmp) as archive:
			csv_name = next(n for n in archive.namelist() if n.startswith("conjunto_de_datos/") and n.endswith(".csv"))
			with archive.open(csv_name) as raw:
				for row in csv.DictReader(io.TextIOWrapper(raw, encoding="latin-1", newline="")):
					try:
						lat, lon = float(row["latitud"]), float(row["longitud"])
					except ValueError:
						continue
					if not (south <= lat <= north and west <= lon <= east):
						continue
					if colonia_de(row):
						colonias.append([round(lat, 6), round(lon, 6), colonia_de(row)])
					tipo = tipo_de(row)
					if tipo is None:
						ignorados[row["nombre_act"]] += 1
						continue
					puntos.append({
						"tipo": tipo,
						"lat": lat, "lon": lon,
						"nombre": nombre_de(row, tipo),
						"origen": f"denue {row['id']} {row['codigo_act']}",
					})

	puntos.sort(key=lambda p: p["origen"])
	with open(out_path, "w", encoding="utf-8") as f:
		json.dump({
			"_fuente": "INEGI, Directorio Estadistico Nacional de Unidades Economicas (DENUE). Generado por fetch_denue.py",
			"puntos": puntos,
		}, f, ensure_ascii=False, indent="\t")

	colonias.sort()
	with open(colonias_path, "w", encoding="utf-8") as f:
		json.dump({
			"_fuente": "INEGI, DENUE (colonia de cada negocio). Generado por fetch_denue.py",
			"_formato": "[lat, lon, colonia]",
			"negocios": colonias,
		}, f, ensure_ascii=False, indent=0)

	por_tipo = collections.Counter(p["tipo"] for p in puntos)
	print(f"OK: {len(puntos)} puntos -> {out_path}")
	print("  " + ", ".join(f"{t}: {n}" for t, n in por_tipo.most_common()))
	por_colonia = collections.Counter(c[2] for c in colonias)
	print(f"OK: colonia de {len(colonias)} negocios -> {colonias_path}")
	print("  " + ", ".join(f"{c}: {n}" for c, n in por_colonia.most_common(6)))
	print(f"  Ignorados {sum(ignorados.values())} negocios de otros giros (los mas comunes:"
		f" {', '.join(n for n, _ in ignorados.most_common(3))})")


if __name__ == "__main__":
	main()
