#!/usr/bin/env python3
"""Recorta las fotos de "Publicidad de barda y grafittis/" para los catalogos de
MapBardas: cada barda pintada de las fotos -> textures/map/propaganda/, y cada
pieza de las hojas de grafitis (fondo negro) y de firmas (fondo blanco) ->
textures/map/grafitis/ con fondo transparente.

Usa ImageMagick (`magick`), como make_textures.py. Solo escribe los archivos
`propaganda_foto_*`, `grafiti_hoja_NN` y `grafiti_firma_NN`; los dibujados no
se tocan.

    python3 -I tools/map_import/recortar_calcomanias.py
"""

import argparse
import os
import re
import subprocess
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FUENTE = os.path.join(RAIZ, "Publicidad de barda y grafittis")
PROPAGANDA_DIR = os.path.join(RAIZ, "textures/map/propaganda")
GRAFITIS_DIR = os.path.join(RAIZ, "textures/map/grafitis")
LADO = 128  # DISENO_PX de MapBardas

# nombre de salida -> (foto, recorte WxH+X+Y de la parte pintada)
BARDAS = {
	"llamaradas": ("barda1.webp", "875x245+5+105"),
	"arrolladora": ("barda.jpeg", "614x140+24+188"),
	"cadetes": ("3ead9eb8675057b219b6ec1474720d94.jpeg", "830x320+108+228"),
	# sin el letrero "SE RENTA" (tiene un telefono real)
	"eliomx": ("bardismo-bardas-anuncios-arte-callejero-mexico-bailes-sonideros.webp", "612x195+285+158"),
	"bailazo": ("guns-n-roses-listos-para-el-gran-bailazo-merida-barda-publicitaria-fans-mexico-conciertos-2-20082022.webp",
		"748x450+110+112"),
	"transfobia": ("rotulosmtzmerida.webp", "940x660+10+30"),
}

# Hoja de 25 grafitis de colores sobre negro (sin el titulo de abajo)
HOJA = "il_fullxfull.7225506757_nc5i.webp"
HOJA_AREA = "1080x985+0+0"
HOJA_UMBRAL = "30%"  # mas bajo, las salpicaduras juntan todas las piezas
# El rojo oscuro de "ZONE" no pasa el umbral: su caja va a mano
HOJA_EXTRA = ["220x112+845+28"]
HOJA_DESCARTAR = [(906, 76)]  # el pedazo de ZONE que si sale

# Hoja de 32 firmas negras sobre blanco (sin el titulo ni el pie)
FIRMAS = "tags.jpg"
FIRMAS_AREA = "736x915+0+120"
# Casi todas negras; algunas de aerosol de color
# Un escurrimiento toca la firma de abajo: caja (x, y) -> renglon donde se parte
FIRMAS_PARTIR = {(544, 613): 710}
FIRMAS_COLORES = ["#161616", "#161616", "#161616", "#8a1414", "#161616", "#1b2f86"]


def magick(*args, salida=False) -> str:
	r = subprocess.run(["magick", *args], check=True, capture_output=True, text=True)
	return r.stdout if salida else ""


def cajas(mascara: str, area_min: int) -> list:
	"""Cajas (w, h, x, y) de los componentes blancos de una mascara."""
	texto = magick(mascara, "-define", "connected-components:verbose=true",
		"-define", f"connected-components:area-threshold={area_min}",
		"-connected-components", "8", "null:", salida=True)
	res = []
	for linea in texto.splitlines():
		m = re.match(r"\s*\d+: (\d+)x(\d+)\+(\d+)\+(\d+) .* gray\(255\)", linea)
		if m:
			res.append(tuple(int(v) for v in m.groups()))
	# en orden de lectura: por renglon (aprox.) y luego de izquierda a derecha
	res.sort(key=lambda c: (round((c[3] + c[1] / 2) / 60), c[2]))
	return res


def caja_texto(c, pad=0) -> str:
	w, h, x, y = c
	return f"{w + 2 * pad}x{h + 2 * pad}+{max(0, x - pad)}+{max(0, y - pad)}"


def a_lado(*ops) -> list:
	"""Reduce promediando a LADO px y deja el alfa duro (el shader corta en 0.5)."""
	return [*ops, "-filter", "Box", "-resize", f"{LADO}x{LADO}>",
		"-channel", "A", "-threshold", "50%", "+channel", "-trim", "+repage"]


def propaganda(fuente: str) -> None:
	for nombre, (foto, recorte) in BARDAS.items():
		destino = os.path.join(PROPAGANDA_DIR, f"propaganda_foto_{nombre}.png")
		magick(os.path.join(fuente, foto), "-crop", recorte, "+repage",
			"-filter", "Box", "-resize", f"{LADO}x{LADO}",
			"-modulate", "100,115", "+dither", "-colors", "48",
			"-strip", "-define", "png:color-type=2", destino)
		print(destino)


def hoja(fuente: str, tmp: str) -> None:
	img = os.path.join(tmp, "hoja.png")
	magick(os.path.join(fuente, HOJA), "-crop", HOJA_AREA, "+repage", img)
	# alfa: solo la pintura de color. Sin el contorno negro ni las salpicaduras
	# oscuras (se veian como un aura de sticker); las lineas negras delgadas de
	# adentro de las letras se cierran, las gruesas quedan transparentes.
	alfa = os.path.join(tmp, "hoja_alfa.png")
	magick(img, "-colorspace", "gray", "-threshold", "28%",
		"-morphology", "Close", "Disk:4", "-morphology", "Open", "Disk:2", alfa)
	mascara = os.path.join(tmp, "hoja_mascara.png")
	magick(img, "-colorspace", "gray", "-threshold", HOJA_UMBRAL,
		"-morphology", "Open", "Disk:2", "-morphology", "Dilate", "Disk:4", mascara)
	lista = [c for c in cajas(mascara, 2500) if (c[2], c[3]) not in HOJA_DESCARTAR]
	for extra in HOJA_EXTRA:
		w, h, x, y = (int(v) for v in re.match(r"(\d+)x(\d+)\+(\d+)\+(\d+)", extra).groups())
		lista.append((w, h, x, y))
	lista.sort(key=lambda c: (round((c[3] + c[1] / 2) / 60), c[2]))
	for i, c in enumerate(lista, 1):
		destino = os.path.join(GRAFITIS_DIR, f"grafiti_hoja_{i:02d}.png")
		recorte = caja_texto(c, 6)
		magick("(", img, "-crop", recorte, "+repage", ")",
			"(", alfa, "-crop", recorte, "+repage", ")",
			"-alpha", "off", "-compose", "CopyOpacity", "-composite",
			*a_lado(), "-strip", "-define", "png:color-type=6", destino)
		print(destino)


def firmas(fuente: str, tmp: str) -> None:
	alfa = os.path.join(tmp, "firmas_alfa.png")
	magick(os.path.join(fuente, FIRMAS), "-crop", FIRMAS_AREA, "+repage",
		"-colorspace", "gray", "-negate", "-level", "20%,70%", alfa)
	mascara = os.path.join(tmp, "firmas_mascara.png")
	# dilatada a lo ancho: junta los trazos de cada firma sin pegarla con la de abajo
	magick(alfa, "-threshold", "30%", "-morphology", "Dilate", "Rectangle:25x7", mascara)
	lista = []
	for w, h, x, y in cajas(mascara, 1500):
		corte = FIRMAS_PARTIR.get((x, y))
		if corte:
			lista += [(w, corte - y, x, y), (w, y + h - corte, x, corte)]
		else:
			lista.append((w, h, x, y))
	for i, c in enumerate(lista, 1):
		destino = os.path.join(GRAFITIS_DIR, f"grafiti_firma_{i:02d}.png")
		recorte = caja_texto(c, 2)
		color = FIRMAS_COLORES[(i - 1) % len(FIRMAS_COLORES)]
		magick("(", alfa, "-crop", recorte, "+repage", ")",
			"(", "+clone", "-fill", color, "-colorize", "100", ")",
			"+swap", "-alpha", "off", "-compose", "CopyOpacity", "-composite",
			*a_lado(), "-strip", "-define", "png:color-type=6", destino)
		print(destino)


def main() -> None:
	ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	ap.add_argument("--fuente", default=FUENTE)
	args = ap.parse_args()
	with tempfile.TemporaryDirectory() as tmp:
		propaganda(args.fuente)
		hoja(args.fuente, tmp)
		firmas(args.fuente, tmp)


if __name__ == "__main__":
	main()
