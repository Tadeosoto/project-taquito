"""Texturas de la casa del personaje (textures/casa_personaje/*.png), tileables 256 px.

pared.png y techo.png son repello (aplanado) con la pintura de las fotos de referencia; piso.png
es un vitropiso rojo claro de 2x2 losetas con su junta. tools/construir_casa_personaje.gd las
proyecta en 3D con coordenadas de mundo: la pared y el techo repiten cada 1 m y el piso cada 0.8 m
(losetas de 0.4 m). Se regeneran con:  python3 -I tools/make_texturas_casa.py
"""
import os
import random

from PIL import Image

N = 256
SALIDA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "textures", "casa_personaje")


def ruido_periodico(rng: random.Random, celdas: int) -> list:
	"""Ruido de valor que cierra sobre si mismo (celdas x celdas), suavizado con smoothstep, en 0..1."""
	g = [[rng.random() for _ in range(celdas)] for _ in range(celdas)]
	salida = [[0.0] * N for _ in range(N)]
	for y in range(N):
		fy = y * celdas / N
		y0 = int(fy) % celdas
		y1 = (y0 + 1) % celdas
		ty = fy - int(fy)
		ty = ty * ty * (3 - 2 * ty)
		for x in range(N):
			fx = x * celdas / N
			x0 = int(fx) % celdas
			x1 = (x0 + 1) % celdas
			tx = fx - int(fx)
			tx = tx * tx * (3 - 2 * tx)
			a = g[y0][x0] + (g[y0][x1] - g[y0][x0]) * tx
			b = g[y1][x0] + (g[y1][x1] - g[y1][x0]) * tx
			salida[y][x] = a + (b - a) * ty
	return salida


def repello(nombre: str, base: tuple, semilla: int, manchas: float) -> None:
	"""Pared o techo de repello: tono base con nubes grandes, grano medio, grano fino y puntitos."""
	rng = random.Random(semilla)
	nubes = ruido_periodico(rng, 3)
	medio = ruido_periodico(rng, 16)
	fino = ruido_periodico(rng, 96)
	img = Image.new("RGB", (N, N))
	px = img.load()
	for y in range(N):
		for x in range(N):
			v = 1.0 + (nubes[y][x] - 0.5) * 0.07 * manchas + (medio[y][x] - 0.5) * 0.04 + (fino[y][x] - 0.5) * 0.06
			if rng.random() < 0.0008:
				v *= 0.9   # puntito de arena
			px[x, y] = tuple(max(0, min(255, int(c * v * 255))) for c in base)
	img.save(os.path.join(SALIDA, nombre))


def piso(nombre: str) -> None:
	"""Vitropiso blanco grisaceo: 2x2 losetas con tono propio, veta suave, brillo en diagonal y junta clara."""
	rng = random.Random(11)
	veta = ruido_periodico(rng, 5)
	grano = ruido_periodico(rng, 64)
	base = (0.86, 0.86, 0.84)
	junta = (0.62, 0.62, 0.60)
	lado = N // 2
	tonos = [[1.0 + (rng.random() - 0.5) * 0.12 for _ in range(2)] for _ in range(2)]
	img = Image.new("RGB", (N, N))
	px = img.load()
	for y in range(N):
		for x in range(N):
			dx = min(x % lado, lado - 1 - x % lado)
			dy = min(y % lado, lado - 1 - y % lado)
			if min(dx, dy) < 2:
				v = 0.95 + (grano[y][x] - 0.5) * 0.1
				px[x, y] = tuple(max(0, min(255, int(c * v * 255))) for c in junta)
				continue
			u = (x % lado) / lado
			w = (y % lado) / lado
			brillo = 0.06 * max(0.0, 1.0 - abs(u + w - 1.0) * 2.5)   # reflejo en diagonal
			v = tonos[y // lado][x // lado] + (veta[y][x] - 0.5) * 0.08 + (grano[y][x] - 0.5) * 0.04 + brillo
			px[x, y] = tuple(max(0, min(255, int(c * v * 255))) for c in base)
	img.save(os.path.join(SALIDA, nombre))


if __name__ == "__main__":
	os.makedirs(SALIDA, exist_ok=True)
	repello("pared.png", (0.12, 0.68, 0.60), 3, 1.0)
	repello("techo.png", (0.70, 0.76, 0.58), 5, 1.0)
	piso("piso.png")
	print("texturas en", SALIDA)
