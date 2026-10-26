#!/usr/bin/env bash
# Convierte data/map/area.osm en models/zona_mapa.glb con OSM2World.
# Uso: bash tools/map_import/build_glb.sh   (antes: fetch_osm.sh y fetch_google_buildings.py)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/tools/map_import/area.env"

O2W_VERSION=0.4.0
# Nivel de detalle de OSM2World (0 = minimo, 4 = maximo). Con 1 no salen
# ventanas en 3D: para el look PS1 sobra y el .glb baja muchisimo.
LOD="${LOD:-1}"
O2W_DIR="$ROOT/tools/map_import/bin/osm2world-$O2W_VERSION"
PREPARED="$ROOT/tools/map_import/bin/area_prepared.osm"
OUT="$ROOT/models/zona_mapa.glb"

# 1. Bajar OSM2World si no esta (~450 MB, incluye texturas)
if [ ! -f "$O2W_DIR/OSM2World.jar" ]; then
	mkdir -p "$O2W_DIR"
	curl --fail -L -A "project-taquito-map-import/0.1" \
		-o "$O2W_DIR.zip" \
		"https://osm2world.org/download/files/$O2W_VERSION/OSM2World-$O2W_VERSION-bin.zip"
	unzip -q "$O2W_DIR.zip" -d "$O2W_DIR"
	rm "$O2W_DIR.zip"
fi

# 1b. Texturas a baja resolucion (look PS1 y un .glb mucho mas ligero).
#     Se hace una sola vez sobre la copia local de OSM2World.
TEX_SIZE=256
# Java no sabe reescalar PNG en gris+alfa (le salta "Unknown image type 0" y
# OSM2World tira las mallas), asi que forzamos PNG RGBA de 32 bits y JPG a color.
MARKER="$O2W_DIR/.texturas_${TEX_SIZE}px_rgba"
if [ ! -f "$MARKER" ]; then
	echo "Reduciendo texturas de OSM2World a ${TEX_SIZE}px ..."
	find "$O2W_DIR/textures" -type f -iname '*.png' \
		-exec magick mogrify -resize "${TEX_SIZE}x${TEX_SIZE}>" -define png:format=png32 {} +
	find "$O2W_DIR/textures" -type f -iname '*.jpg' \
		-exec magick mogrify -resize "${TEX_SIZE}x${TEX_SIZE}>" -type TrueColor {} +
	touch "$MARKER"
fi

# 2. Recortar la zona, agregar casas de Google (si ya corriste
#    fetch_google_buildings.py), rellenar pisos/colores/overrides y colocar
#    las tiendas del DENUE (fetch_denue.py) y de puntos.json (quitando la casa que reemplazan),
#    altos; partir en manzanas con su colonia y cambiar las casas de
#    las colonias de casas.json por modelos (resources/map/casas_mapa.json)
python3 -I "$ROOT/tools/map_import/prepare_osm.py" \
	--bbox "$SOUTH" "$WEST" "$NORTH" "$EAST" \
	--osm "$ROOT/data/map/area.osm" \
	--salida "$PREPARED" \
	--overrides "$ROOT/data/map/overrides.json" \
	--google "$ROOT/data/map/google_buildings.csv" \
	--puntos "$ROOT/data/map/denue_puntos.json" \
	--puntos "$ROOT/data/map/puntos.json" \
	--salida-puntos "$ROOT/resources/map/puntos_mapa.json" \
	--colonias-denue "$ROOT/data/map/denue_colonias.json" \
	--colonias "$ROOT/data/map/colonias.json" \
	--casas "$ROOT/data/map/casas.json" \
	--salida-casas "$ROOT/resources/map/casas_mapa.json" \
	--png-colonias "$ROOT/data/map/colonias_debug.png"

# 3. Config = estilo estandar + nuestros ajustes (las rutas de texturas son
#    relativas a la carpeta de OSM2World, por eso corremos desde ahi)
CONFIG="$O2W_DIR/taquito.properties"
LOG="$ROOT/tools/map_import/bin/osm2world.log"
cat "$O2W_DIR/standard.properties" "$ROOT/tools/map_import/osm2world.properties" > "$CONFIG"

cd "$O2W_DIR"
java --add-exports java.base/java.lang=ALL-UNNAMED \
	--add-exports java.desktop/sun.awt=ALL-UNNAMED \
	--add-exports java.desktop/sun.java2d=ALL-UNNAMED \
	-Xmx4g -jar OSM2World.jar \
	-i "$PREPARED" -o "$OUT" --config "$CONFIG" --lod "$LOD" > "$LOG" 2>&1 || true

# OSM2World no truena cuando falla una malla: la salta y sigue. Por eso
# revisamos el log y que el .glb si traiga edificios.
ERRORS=$(grep -c '^ERROR' "$LOG" || true)
if [ "$ERRORS" -gt 0 ]; then
	echo "AVISO: OSM2World reporto $ERRORS errores (log completo: $LOG). Los primeros:"
	grep -v '^\s*at ' "$LOG" | grep -B2 -A2 -m3 'ERROR' | head -30
fi
[ -s "$OUT" ] || { echo "ERROR: OSM2World no genero $OUT" >&2; exit 1; }
python3 -I - "$OUT" <<'PY'
import collections, json, struct, sys
data = open(sys.argv[1], "rb").read()
size = struct.unpack("<I", data[12:16])[0]
gltf = json.loads(data[20:20 + size])
kinds = collections.Counter(n.get("name", "").split(" ")[0] for n in gltf["nodes"])
print("Contenido del .glb:", dict(kinds.most_common(8)))
if not any(k.startswith("Building") for k in kinds):
	sys.exit("ERROR: el .glb no trae edificios; revisa el log")
PY

# 4. Que Godot use nuestro post-import (materiales PS1 + colisiones)
IMPORT="$OUT.import"
if [ ! -f "$IMPORT" ]; then
	cat > "$IMPORT" <<'IMP'
[remap]

importer="scene"
importer_version=1

[params]

import_script/path="res://scripts/map/MapPostImport.gd"
IMP
fi

echo "OK: $OUT ($(du -h "$OUT" | cut -f1))"
echo "Ahora: rm -f \"$ROOT\"/.godot/imported/zona_mapa.glb-* && godot --path \"$ROOT\" --headless --import"
echo "  y despues: godot --path \"$ROOT\" --headless -s tools/map_import/split_cuadros.gd  (cuadros para MapStreamer)"

# 5. Minimapa (radar de MapMinimapa.gd) con las calles y casas que acaban de salir
python3 -I "$ROOT/tools/map_import/make_minimapa.py"
