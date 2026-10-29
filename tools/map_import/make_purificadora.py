"""Anuncio de las purificadoras (MapPuntos._make_purificadora), con ImageMagick,
copiando la foto de referencia del usuario:

  textures/map/purificadora_lona.png  el anuncio sin letras (las pone un Label3D): blanco
                                      arriba, olas azules abajo, garrafon a la izquierda,
                                      gota y un vaso de agua a la derecha (en la foto hay
                                      una modelo; no se usan fotos de personas reales)

    python3 -I tools/map_import/make_purificadora.py
"""

import math
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "textures", "map")
LONA = (512, 128)


def magick(*args) -> None:
	subprocess.run(["magick", *args], check=True)


def ola(y0: float, amplitud: float, periodo: float, fase: float, linea: bool = False) -> str:
	"""Poligono de una ola de y0 hacia abajo hasta la orilla de la lona (o solo su
	borde, con `linea`)."""
	ancho, alto = LONA
	puntos = [f"{x},{y0 + amplitud * math.sin((x / periodo + fase) * math.tau):.1f}" for x in range(0, ancho + 8, 8)]
	if linea:
		return "polyline " + " ".join(puntos)
	return "polygon " + " ".join(puntos + [f"{ancho},{alto}", f"0,{alto}"])


def lona(path: str) -> None:
	ancho, alto = LONA
	args = ["-size", f"{ancho}x{alto}", "xc:#f7f9fb"]
	# Olas: claras atras, azul fuerte enfrente, con una raya blanca de espuma
	args += ["-fill", "#9fd2f2", "-draw", ola(78, 6, 140, 0.1)]
	args += ["-fill", "#3d9be0", "-draw", ola(88, 7, 170, 0.45)]
	args += ["-fill", "none", "-stroke", "#e8f6ff", "-strokewidth", "2", "-draw", ola(95, 6, 120, 0.7, linea=True)]
	args += ["-stroke", "none", "-fill", "#1c64b8", "-draw", ola(104, 5, 200, 0.2)]
	# Garrafon de 20 l: cuerpo azul claro, tapa azul fuerte y etiqueta blanca
	args += ["-fill", "#a9d6f5", "-stroke", "#3b7fc4", "-strokewidth", "2",
		"-draw", "roundrectangle 22,30 72,118 10,10",
		"-draw", "polygon 34,30 60,30 54,18 40,18",
		"-stroke", "none", "-fill", "#1d4fa0", "-draw", "rectangle 40,10 54,18",
		"-fill", "#ffffff", "-draw", "rectangle 26,70 68,88",
		"-fill", "#2a6fd0", "-draw", "rectangle 26,74 68,77",
		"-fill", "#d8eefc", "-draw", "rectangle 28,38 33,110"]
	# Gota del logo: circulo con punta y una hoja verde (sin marca real)
	args += ["-fill", "#2a6fd0", "-draw", "circle 112,52 112,70",
		"-draw", "polygon 97,46 127,46 112,18",
		"-fill", "#8fd0ff", "-draw", "circle 106,48 106,54",
		"-fill", "#3fa24a", "-draw", "polygon 120,64 140,58 130,74"]
	# Vaso de agua a la derecha con burbujas y gotas alrededor
	args += ["-fill", "#d9f0ff", "-stroke", "#5a9bd4", "-strokewidth", "2",
		"-draw", "polygon 440,16 484,16 478,100 446,100",
		"-stroke", "none", "-fill", "#74bff0", "-draw", "polygon 442,40 482,40 478,99 446,99",
		"-fill", "#f2fbff", "-draw", "circle 458,70 458,73", "-draw", "circle 468,56 468,58",
		"-draw", "rectangle 447,44 451,95",
		"-fill", "#3d9be0", "-draw", "circle 500,30 500,34", "-draw", "circle 428,52 428,55",
		"-draw", "circle 498,64 498,67"]
	magick(*args, "-type", "TrueColor", "-depth", "8", path)


def main() -> None:
	os.makedirs(OUT_DIR, exist_ok=True)
	lona(os.path.join(OUT_DIR, "purificadora_lona.png"))
	print(f"OK: purificadora_lona.png en {OUT_DIR}")


if __name__ == "__main__":
	main()
