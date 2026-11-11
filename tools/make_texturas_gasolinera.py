"""Texturas de detalle de la gasolinera (textures/map/gasolinera_*.png), tileables 128 px.

El modelo de la gasolinera (models/tiendas/gasolinera) viene en colores planos de una paleta;
shaders/ps1_gasolinera.gdshader les suma estas texturas en 3D (concreto con poros para la pared
de la tienda, aplanado fino para la pintura blanca de las bombas y lamina galvanizada para el techo,
la columna y los postes; la isla usa textures/map/banqueta.png) para que no parezca caricatura. Se regeneran con:  python3 -I tools/make_texturas_gasolinera.py
"""
import os
import random

from PIL import Image

N = 128
SALIDA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "textures", "map")


def ruido_periodico(rng: random.Random, celdas: int) -> list:
	"""Ruido de valor que cierra sobre si mismo (celdas x celdas), suavizado con smoothstep."""
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
			arriba = g[y0][x0] * (1 - tx) + g[y0][x1] * tx
			abajo = g[y1][x0] * (1 - tx) + g[y1][x1] * tx
			salida[y][x] = arriba * (1 - ty) + abajo * ty
	return salida


def normalizar(a: list, medio: float, amplitud: float) -> list:
	vals = [v for fila in a for v in fila]
	m = sum(vals) / len(vals)
	sd = (sum((v - m) ** 2 for v in vals) / len(vals)) ** 0.5 + 1e-6
	return [[medio + (v - m) / sd * amplitud for v in fila] for fila in a]


def guardar(nombre: str, gris: list, calido: tuple) -> None:
	img = Image.new("RGB", (N, N))
	datos = []
	for fila in gris:
		for v in fila:
			v = min(max(v, 0.0), 1.0)
			datos.append(tuple(int(min(v * c, 1.0) * 255) for c in calido))
	img.putdata(datos)
	img.save(os.path.join(SALIDA, nombre))
	print("listo", nombre)


def main() -> None:
	rng = random.Random(11)
	r4, r8, r16, r32 = (ruido_periodico(rng, c) for c in (4, 8, 16, 32))
	base = [[0.5 * r4[y][x] + 0.25 * r8[y][x] + 0.15 * r16[y][x] + 0.1 * r32[y][x] for x in range(N)] for y in range(N)]
	concreto = normalizar(base, 0.62, 0.075)
	for y in range(N):
		for x in range(N):
			concreto[y][x] += (rng.random() - 0.5) * 0.09
	# Poros oscuros de 1-2 px
	for _ in range(int(N * N * 0.008)):
		x, y = rng.randrange(N), rng.randrange(N)
		concreto[y][x] -= 0.28
		concreto[(y + 1) % N][x] -= 0.12
		concreto[y][(x + 1) % N] -= 0.12
	# Grieta de pelo que no cruza la textura entera (repetida en cada mosaico no se nota)
	y = rng.randrange(20, 100)
	x0 = rng.randrange(0, N - 50)
	for x in range(x0, x0 + 45):
		concreto[y % N][x] -= 0.16
		y += rng.choice((-1, 0, 0, 1))
	guardar("gasolinera_concreto.png", concreto, (1.0, 0.985, 0.95))
	# Aplanado: grano fino de pasta, con ondulacion suave
	fino = [[rng.random() for _ in range(N)] for _ in range(N)]
	fino = [[(fino[y][x] + fino[y - 1][x] + fino[y][x - 1]) / 3.0 for x in range(N)] for y in range(N)]
	fino = normalizar(fino, 0.7, 0.055)
	onda = normalizar(ruido_periodico(rng, 6), 0.0, 0.03)
	aplanado = [[fino[y][x] + onda[y][x] for x in range(N)] for y in range(N)]
	guardar("gasolinera_aplanado.png", aplanado, (1.0, 0.99, 0.96))
	# Lamina galvanizada: vetas finas (cepillado) a lo largo de la textura, una junta con remaches
	# cada 64 px y unas manchitas de oxido; el gris frio de lo galvanizado
	crudo = [[rng.random() for _ in range(N)] for _ in range(N)]
	vetas = [[sum(crudo[(y + k) % N][x] for k in range(-6, 7)) / 13.0 for x in range(N)] for y in range(N)]
	vetas = normalizar(vetas, 0.72, 0.085)
	onda = normalizar(ruido_periodico(rng, 5), 0.0, 0.035)
	metal = [[vetas[y][x] + onda[y][x] + (crudo[y][x] - 0.5) * 0.03 for x in range(N)] for y in range(N)]
	for junta in (0, 64):
		for x in range(N):
			metal[junta][x] -= 0.42
			metal[(junta + 1) % N][x] += 0.12
			metal[(junta + 2) % N][x] -= 0.06
	# Doblez a media lamina
	for doblez in (32, 96):
		for x in range(N):
			metal[doblez][x] -= 0.14
			metal[(doblez + 1) % N][x] += 0.07
		for x in range(8, N, 16):
			for dy in (-4, 4):
				py = (junta + dy) % N
				metal[py][x] -= 0.25
				metal[py][x + 1] += 0.1
	for _ in range(26):
		x, y = rng.randrange(N), rng.randrange(N)
		for dy in range(rng.randrange(1, 6)):
			metal[(y + dy) % N][x] -= 0.3
	guardar("gasolinera_metal.png", metal, (0.96, 0.98, 1.0))


if __name__ == "__main__":
	main()
