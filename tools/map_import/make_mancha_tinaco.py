"""Dibuja textures/mapa/mancha_tinaco.png: la mancha de moho de la Virgen del Tinaco, con la silueta de la
Virgen de Guadalupe (cabeza con el manto, hombros, y el manto que se abre hasta los pies), como la de la
foto de referencia: un centro casi negro, una orilla de musgo verde con flecos y escurrimientos, y una
humedad oscura alrededor. 64 x 176 px, con alfa; la pone Colonia.gd (_mancha_tinaco) en un parche curvo
pegado a la base del tinaco comunitario:

    python3 -I tools/map_import/make_mancha_tinaco.py
"""

import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SALIDA = os.path.join(RAIZ, "textures", "mapa", "mancha_tinaco.png")
W, H = 64, 176

azar = random.Random(11)
# Que tan opaca queda la mancha en conjunto (1 es lo que dicen ALFA_*): la pared del tinaco se transparenta
OPACIDAD = 0.8


def silueta(escala=1.0, subir=0):
    """La figura: cabeza velada, hombros angostos, el manto que se ensancha y se abre abajo."""
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    cx = 32
    def px(v):
        return cx + (v - cx) * escala
    d.ellipse((px(27), 10 - subir, px(37), 28 + subir), fill=255)                  # cabeza con el velo
    puntos_izq = [(29, 26), (24, 40), (21, 62), (19, 92), (14, 124), (9, 154), (7, 170)]
    puntos_der = [(2 * cx - x, y) for x, y in reversed(puntos_izq)]
    d.polygon([(px(x), y - (subir if y < 100 else -subir)) for x, y in puntos_izq + puntos_der], fill=255)
    d.ellipse((px(4), 160, px(60), 176 + subir), fill=255)                         # la base abierta
    return m


# Las capas, todas suaves para que se mezclen: la humedad (la mas ancha y tenue), el musgo (la silueta crecida con
# flecos y escurrimientos) y el centro oscuro; el color y el alfa pasan de una a otra con un degradado
musgo = silueta(1.62, 6).filter(ImageFilter.GaussianBlur(2.6))
flecos = Image.effect_noise((W, H), 70).filter(ImageFilter.GaussianBlur(0.8))
musgo = ImageChops.multiply(musgo, flecos.point(lambda v: 150 + v // 2)).point(lambda v: 255 if v > 95 else 0)
d = ImageDraw.Draw(musgo)
for _ in range(34):                                                                # escurrimientos verticales
    x = azar.randint(8, 56)
    d.line((x, azar.randint(110, 150), x + azar.choice((-1, 0, 0, 1)), azar.randint(165, 176)), fill=255, width=1)
musgo = musgo.filter(ImageFilter.GaussianBlur(0.9))
nucleo = silueta(0.72).filter(ImageFilter.GaussianBlur(4.5))        # sin recortar: de claro a oscuro de a poco
humedad = silueta(1.9, 8).filter(ImageFilter.GaussianBlur(6))

OSCURO = (30, 40, 26)       # el centro, casi negro verdoso
MUSGO = (112, 150, 44)      # el musgo, verde
PUNTA = (172, 178, 70)      # las puntas del musgo, amarillentas
HUMEDO = (58, 68, 52)       # la humedad de alrededor
ALFA_NUCLEO, ALFA_MUSGO, ALFA_HUMEDAD = 0.85, 0.75, 0.25

imagen = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = imagen.load()
mm, nn, hh = musgo.load(), nucleo.load(), humedad.load()
for y in range(H):
    for x in range(W):
        a_musgo, c, a_hum = mm[x, y] / 255.0, nn[x, y] / 255.0, hh[x, y] / 255.0
        ruido = azar.uniform(-1.0, 1.0)
        # c: 0 en la orilla, 1 en el centro. El color baja del musgo (con puntas amarillas) al oscuro, sin saltos
        t = 0.5 + 0.5 * ruido
        verde = tuple(MUSGO[i] * (1 - 0.5 * t) + PUNTA[i] * 0.5 * t for i in range(3))
        k = min(1.0, c * 1.25)
        k = k * k * (3 - 2 * k)
        color = tuple(verde[i] * (1 - k) + OSCURO[i] * k for i in range(3))
        # El alfa tambien baja de a poco hacia afuera: centro > musgo > humedad
        alfa = max(a_hum * ALFA_HUMEDAD, a_musgo * ALFA_MUSGO * (1 - k) + k * ALFA_NUCLEO * min(1.0, c * 1.6 + a_musgo * 0.3))
        if alfa < 0.02:
            continue
        mezcla = min(1.0, a_hum * 0.6)
        color = tuple(color[i] * (1 - 0.0) for i in range(3)) if a_musgo > 0.15 or c > 0.15 else tuple(HUMEDO[i] for i in range(3))
        px[x, y] = (int(color[0]), int(color[1]), int(color[2]), int(255 * min(1.0, alfa)))

imagen.putalpha(imagen.getchannel("A").point(lambda v: int(v * OPACIDAD)))
os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
imagen.save(SALIDA)
print("guardado", SALIDA)
