#!/bin/sh
# Cuida el CLAUDE.md partido (commit 52a3103): en main-testing la raiz es un indice chico y
# el detalle de cada sistema vive en docs/sistemas/ o scripts/<carpeta>/CLAUDE.md.
# Si una rama vieja trae el CLAUDE.md grande (~160 KB) en una mezcla, esto la detiene.
# Se prende una vez por clon: git config core.hooksPath tools/git-hooks

TOPE=25600   # bytes (25 KB)

rama=$(git symbolic-ref --short HEAD 2>/dev/null)
[ "$rama" = "main-testing" ] || exit 0

# El tamano de lo que se va a guardar (el indice), no del archivo en disco
tam=$(git cat-file -s :CLAUDE.md 2>/dev/null) || exit 0

if [ "$tam" -gt "$TOPE" ]; then
	echo "" >&2
	echo "CLAUDE.md mide $tam bytes; en main-testing el tope es $TOPE." >&2
	echo "Seguramente viene el CLAUDE.md grande de una rama de antes de partirlo (52a3103)." >&2
	echo "Arreglo: git checkout --ours CLAUDE.md, y pasa los cambios de la rama al archivo" >&2
	echo "de cada sistema (docs/sistemas/ o scripts/<carpeta>/CLAUDE.md)." >&2
	echo "Ve la seccion \"CLAUDE.md layout\" del CLAUDE.md." >&2
	exit 1
fi
exit 0
