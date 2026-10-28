"""Baja las huellas de casas de Google Open Buildings v3 para la zona del mapa.

OSM solo tiene trazadas las casas de algunas manzanas; Google Open Buildings
(CC BY 4.0) las detecta con imagenes satelitales. El archivo de Google viene por
celdas grandes (la de Guadalajara pesa ~1.7 GB comprimida), asi que lo leemos en
streaming y solo guardamos lo que cae dentro del rectangulo: no se guarda en disco.

Uso: python3 fetch_google_buildings.py   (lee tools/map_import/area.env)
Salida: data/map/google_buildings.csv
"""

import csv
import gzip
import os
import sys
import time
import urllib.request

# Celda S2 nivel 4 que cubre Guadalajara (ver tiles.geojson de Open Buildings)
TILE_URL = "https://storage.googleapis.com/open-buildings-data/v3/polygons_s2_level_4_gzip/843_buildings.csv.gz"

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read_area() -> dict:
	area = {}
	with open(os.path.join(ROOT, "tools", "map_import", "area.env"), encoding="utf-8") as f:
		for line in f:
			line = line.strip()
			if line and not line.startswith("#") and "=" in line:
				key, value = line.split("=", 1)
				area[key] = float(value)
	return area


def main() -> None:
	area = read_area()
	south, west, north, east = area["SOUTH"], area["WEST"], area["NORTH"], area["EAST"]
	out_path = os.path.join(ROOT, "data", "map", "google_buildings.csv")

	# La geometria (WKT) de algunos edificios rebasa el limite default del modulo csv
	csv.field_size_limit(sys.maxsize)

	request = urllib.request.Request(TILE_URL, headers={"User-Agent": "project-taquito-map-import/0.1"})
	kept = 0
	read = 0
	start = time.time()
	with urllib.request.urlopen(request) as response, \
			gzip.open(response, "rt", encoding="utf-8", newline="") as stream, \
			open(out_path, "w", encoding="utf-8", newline="") as out:
		reader = csv.DictReader(stream)
		writer = csv.writer(out)
		writer.writerow(["latitude", "longitude", "area_in_meters", "confidence", "geometry"])
		for row in reader:
			read += 1
			if read % 2_000_000 == 0:
				print(f"  {read:,} edificios leidos, {kept} en la zona ({time.time() - start:.0f} s)", flush=True)
			lat = float(row["latitude"])
			lon = float(row["longitude"])
			if south <= lat <= north and west <= lon <= east:
				writer.writerow([row["latitude"], row["longitude"], row["area_in_meters"], row["confidence"], row["geometry"]])
				kept += 1

	print(f"OK: {out_path} ({kept} edificios de {read:,} en la celda, {time.time() - start:.0f} s)")


if __name__ == "__main__":
	main()
