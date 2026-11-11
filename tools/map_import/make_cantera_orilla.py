"""La orilla entre los andadores rosas de la plaza y su piedra gris: piedritas irregulares (Voronoi que se repite)
de tonos entre el gris de textures/mapa/piedra_plaza.png y el rosa de cantera_rosa.png, con juntas oscuras. Sale a
textures/mapa/cantera_orilla.png (material "cantera_orilla": la cenefa de los andadores y la glorieta del tinaco).

    python3 -I tools/map_import/make_cantera_orilla.py
"""
import math
import os
import random
from PIL import Image, ImageFilter, ImageStat

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEX = os.path.join(RAIZ, "textures", "mapa")
TAM = 128
PIEDRAS = 70          # por textura (la textura cubre 1.5 m: piedras de ~18 cm)
JUNTA = 1.6           # px de junta
OSCURO = 0.9          # la cenefa un poco mas oscura que los dos pisos


def promedio(nombre):
    return [v for v in ImageStat.Stat(Image.open(os.path.join(TEX, nombre)).convert("RGB")).mean]


gris, rosa = promedio("piedra_plaza.png"), promedio("cantera_rosa.png")
azar = random.Random(77)
centros = [(azar.uniform(0, TAM), azar.uniform(0, TAM)) for _ in range(PIEDRAS)]
tonos = []
for _ in centros:
    t = azar.random() ** 0.8                 # mas hacia el rosa
    luz = azar.uniform(0.82, 1.08) * OSCURO
    tonos.append([((1 - t) * g + t * r) * luz for g, r in zip(gris, rosa)])
junta = [g * 0.55 for g in gris]
img = Image.new("RGB", (TAM, TAM))
for y in range(TAM):
    for x in range(TAM):
        d1 = d2 = 1e9
        k1 = 0
        for k, (cx, cy) in enumerate(centros):
            dx = min(abs(x - cx), TAM - abs(x - cx))
            dy = min(abs(y - cy), TAM - abs(y - cy))
            d = dx * dx + dy * dy
            if d < d1:
                d1, d2, k1 = d, d1, k
            elif d < d2:
                d2 = d
        borde = math.sqrt(d2) - math.sqrt(d1)
        c = tonos[k1]
        grano = azar.uniform(0.93, 1.07)
        if borde < JUNTA:
            c = junta
        elif borde < JUNTA + 1.2:
            c = [v * 0.85 for v in c]
        img.putpixel((x, y), tuple(max(0, min(255, round(v * grano))) for v in c))
img = img.filter(ImageFilter.SMOOTH)
img.save(os.path.join(TEX, "cantera_orilla.png"))
print("guardado", os.path.join(TEX, "cantera_orilla.png"))
