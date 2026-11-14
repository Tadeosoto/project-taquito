#!/usr/bin/env bash
# Iteracion rapida del diseno del mapa: SOLO Python, sin Blender. Genera el .json de la colonia
# (favela.py) y el minimapa (minimapa_colonia.py) en segundos, y deja la imagen ampliada en
# capturas_favela/minimapa.png para revisarla. El .glb NO se toca: los edificios y detalles se
# renderizan en Blender solo cuando el minimapa este aprobado.
#   tools/blender/mapa/minimapa_rapido.sh [la_gotera_favela]
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../../.." && pwd)"
COLONIA="${1:-la_gotera_favela}"
cd "$RAIZ"
python3 tools/blender/mapa/favela.py "$COLONIA"
python3 tools/blender/mapa/minimapa_colonia.py "$COLONIA"
mkdir -p capturas_favela
if command -v magick >/dev/null 2>&1; then
	magick "textures/map/minimapa_${COLONIA}.png" -filter point -resize 300% "capturas_favela/minimapa.png"
else
	cp "textures/map/minimapa_${COLONIA}.png" "capturas_favela/minimapa.png"
fi
echo "Minimapa listo (sin Blender): capturas_favela/minimapa.png"
