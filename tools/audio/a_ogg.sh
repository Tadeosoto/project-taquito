#!/usr/bin/env bash
# Convierte un sonido (wav de Splice, mp3...) a .ogg ligero para el juego.
# Uso: tools/audio/a_ogg.sh entrada.wav audio/zombis/zombi_alerta.ogg [--estereo] [--sin-recorte]
#   - mono a 44.1 kHz, Vorbis calidad 4 (~64-80 kb/s): un wav de Splice de 1 MB queda en ~50 KB
#   - quita el silencio del principio y del final (--sin-recorte para bucles, que no deben perder nada)
#   - --estereo para ambientes y musica, donde el paneo importa; los efectos van en mono porque
#     Godot los pone en 3D y el estereo solo pesa el doble
# ffmpeg: si no esta en el PATH usa el de `uv tool install static-ffmpeg`.
set -euo pipefail

if [ $# -lt 2 ]; then
	echo "Uso: $0 entrada salida.ogg [--estereo] [--sin-recorte]" >&2
	exit 1
fi
entrada=$1
salida=$2
shift 2
canales=1
recorte=1
for op in "$@"; do
	case $op in
		--estereo) canales=2 ;;
		--sin-recorte) recorte=0 ;;
		*) echo "Opcion desconocida: $op" >&2; exit 1 ;;
	esac
done

ff=$(command -v ffmpeg || command -v static_ffmpeg || true)
if [ -z "$ff" ]; then
	echo "Falta ffmpeg: uv tool install static-ffmpeg" >&2
	exit 1
fi

filtro=anull
if [ $recorte = 1 ]; then
	# Silencio = por debajo de -50 dB; se deja 20 ms de cola para no cortar el final en seco
	filtro="silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.02,areverse"
fi

mkdir -p "$(dirname "$salida")"
"$ff" -hide_banner -loglevel error -y -i "$entrada" -af "$filtro" -ac $canales -ar 44100 \
	-c:a libvorbis -q:a 4 "$salida"

antes=$(stat -c %s "$entrada")
despues=$(stat -c %s "$salida")
echo "$salida: $((antes / 1024)) KB -> $((despues / 1024)) KB"
