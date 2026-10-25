#!/usr/bin/env bash
# Descarga los datos de OpenStreetMap de la zona del mapa a data/map/area.osm.
# Uso: bash tools/map_import/fetch_osm.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/tools/map_import/area.env"
OUT="$ROOT/data/map/area.osm"
mkdir -p "$(dirname "$OUT")"

BBOX="$SOUTH,$WEST,$NORTH,$EAST"
# Solo ways y multipoligonos: las relaciones grandes (limites, rutas) traen
# nodos a kilometros de la zona. prepare_osm.py recorta lo que sobra.
QUERY="[out:xml][timeout:180];(way($BBOX);relation[\"type\"=\"multipolygon\"]($BBOX););(._;>;);out meta;"

# Overpass responde 406 si no mandamos User-Agent.
# Si un servidor esta saturado (504) probamos con el siguiente.
SERVERS=(
	https://overpass-api.de/api/interpreter
	https://overpass.kumi.systems/api/interpreter
	https://overpass.private.coffee/api/interpreter
)
for server in "${SERVERS[@]}"; do
	echo "Descargando de $server ..."
	if curl --fail --silent --show-error --max-time 300 \
		-A "project-taquito-map-import/0.1" \
		--data-urlencode "data=$QUERY" \
		-o "$OUT" \
		"$server"; then
		break
	fi
	rm -f "$OUT"
done
[ -s "$OUT" ] || { echo "ERROR: ningun servidor de Overpass respondio" >&2; exit 1; }

echo "OK: $OUT ($(grep -c 'k="building"' "$OUT") edificios)"
