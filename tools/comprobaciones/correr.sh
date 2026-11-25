#!/bin/bash
# Corre las comprobaciones (Correr.gd) y ademas cuenta los SCRIPT ERROR de la consola.
#   tools/comprobaciones/correr.sh            todas
#   tools/comprobaciones/correr.sh bolsa      solo una
# GODOT: el ejecutable (si no, `godot`). Sale con fallas + errores (0 = todo bien).
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
ARGS=()
[ -n "$1" ] && ARGS=(-- "--solo=$1")
timeout 1200 "$GODOT" --path . --headless res://tools/comprobaciones/correr.tscn "${ARGS[@]}" 2>&1 | tee "$LOG"
SALIDA=${PIPESTATUS[0]}
ERRORES=$(grep -c "SCRIPT ERROR" "$LOG")
rm -f "$LOG"
echo "salida de Godot: $SALIDA · SCRIPT ERROR: $ERRORES"
exit $(( SALIDA + ERRORES ))
