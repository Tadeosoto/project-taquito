#!/usr/bin/env bash
# Rehace una colonia del mapa de Blender de punta a punta, en un solo comando:
#   tools/mapa/rehacer_colonia.sh [colonia] [--rapido] [--sin-favela] [--sin-import]
#
#   --rapido      no guarda el .blend ni rehace el minimapa (lo lento). Para estar probando;
#                 antes de commitear hay que correrlo una vez sin --rapido.
#   --sin-favela  no corre favela.py (cuando solo cambiaron las piezas de Blender)
#   --sin-import  no corre el import de Godot
#
# Despues:  godot --path . --headless -s tools/mapa/recorrer_favela.gd -- --solo=callejones
#           godot --path . -s tools/mapa/captura_colonia.gd -- --colonia=<c> --vistas=todas --carpeta=/tmp/x
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLONIA="la_gotera_favela"
FAVELA=1
IMPORT=1
export RAPIDO="${RAPIDO:-}"

for arg in "$@"; do
	case "$arg" in
		--rapido) RAPIDO=1 ;;
		--sin-favela) FAVELA=0 ;;
		--sin-import) IMPORT=0 ;;
		--*) echo "no se que es $arg" >&2; exit 2 ;;
		*) COLONIA="$arg" ;;
	esac
done
export RAPIDO

cd "$RAIZ"
inicio=$SECONDS
if [ "$FAVELA" = 1 ] && [ -f "tools/blender/mapa/colonias/$COLONIA.json" ] && \
	python3 -c "import json,sys; sys.exit(0 if json.load(open('tools/blender/mapa/colonias/$COLONIA.json')).get('favela') else 1)"; then
	echo "== favela.py =="
	python3 tools/blender/mapa/favela.py "$COLONIA"
fi

echo "== blender (colonia + exportar)${RAPIDO:+ RAPIDO} =="
TAQUITO_RAIZ="$RAIZ" COLONIA="$COLONIA" blender --background --python-expr "
import os
R = os.path.join(os.environ['TAQUITO_RAIZ'], 'tools', 'blender', 'mapa')
C = os.environ['COLONIA']
for paso, nom in (('colonia', 'colonia'), ('exportar', '__main__')):
    print('=== %s %s ===' % (paso, C), flush=True)
    exec(open(os.path.join(R, paso + '.py'), encoding='utf-8').read(), {'__name__': nom, 'COLONIA': C})
" 2>&1 | grep -E "^(===|colonia |favela |minimapa |RAPIDO|Error|Traceback)" || true

if [ "$IMPORT" = 1 ]; then
	echo "== godot --import =="
	godot --path . --headless --import 2>&1 | grep -iE "^ERROR" || true
fi
echo "== listo en $((SECONDS - inicio)) s =="
