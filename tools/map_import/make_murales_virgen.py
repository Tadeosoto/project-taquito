"""Dibuja los murales de la Virgen del Tinaco de textures/map/virgen/: lo que pintan los fieles de
Santa Mugre en su muralla, en los espectaculares que eran de GelA y junto a las rejas. Van en su
propia carpeta (no en propaganda/) para que las bardas de map_test no cambien de diseño; kit.murales()
los mete al atlas del mapa en Blender con el tipo "virgen".

    uv run --with pillow python -I tools/map_import/make_murales_virgen.py

Despues, en Blender: kit.murales() (lo corre colonia.py si falta el atlas) y exportar.
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SALIDA = os.path.join(RAIZ, "textures", "map", "virgen")

AZUL_GELA = (26, 84, 184)
MANTO = (24, 96, 92)
MANTO_LUZ = (46, 140, 128)
ORO = (236, 186, 60)
ROSA = (214, 110, 120)
PIEL = (150, 100, 70)
NEGRO = (16, 14, 14)
CAL = (232, 226, 208)
ROJO = (176, 34, 30)
TINACO = (28, 28, 32)

FUENTE = ImageFont.load_default()


def texto(d, xy, t, color, centro=None):
    """Texto de la fuente de mapa de bits; con `centro` (ancho de la imagen) va centrado."""
    x, y = xy
    if centro is not None:
        x = (centro - d.textlength(t, font=FUENTE)) / 2
    d.text((x, y), t, fill=color, font=FUENTE)


def virgen(d, cx, base, alto, azar):
    """La Virgen como la pintan en el barrio: rayos, manto verde con estrellas, y en vez de las
    manos juntas carga un tinaco negro."""
    ancho = alto * 0.42
    # Rayos
    for i in range(26):
        a = math.tau * i / 26
        r0, r1 = alto * 0.36, alto * (0.56 if i % 2 else 0.5)
        d.line([(cx + math.cos(a) * r0 * 0.8, base - alto * 0.5 + math.sin(a) * r0),
                (cx + math.cos(a) * r1 * 0.8, base - alto * 0.5 + math.sin(a) * r1)], fill=ORO, width=1)
    # Manto: una almendra
    d.ellipse([cx - ancho / 2, base - alto, cx + ancho / 2, base], fill=MANTO, outline=ORO)
    d.ellipse([cx - ancho * 0.3, base - alto * 0.86, cx + ancho * 0.3, base - alto * 0.06], fill=ROSA)
    # Estrellas del manto
    for _ in range(int(alto / 4)):
        a = azar.uniform(0, math.tau)
        x, y = cx + math.cos(a) * ancho * 0.41, base - alto / 2 + math.sin(a) * alto * 0.43
        d.point((x, y), fill=ORO)
    # Cara
    d.ellipse([cx - ancho * 0.14, base - alto * 0.9, cx + ancho * 0.14, base - alto * 0.72], fill=PIEL)
    d.arc([cx - ancho * 0.2, base - alto * 0.96, cx + ancho * 0.2, base - alto * 0.66], 180, 360, fill=MANTO_LUZ, width=2)
    # El tinaco en brazos
    tw, th = ancho * 0.44, alto * 0.24
    d.rectangle([cx - tw / 2, base - alto * 0.56, cx + tw / 2, base - alto * 0.56 + th], fill=TINACO)
    d.ellipse([cx - tw / 2, base - alto * 0.6, cx + tw / 2, base - alto * 0.52], fill=(48, 48, 54))
    d.rectangle([cx - tw * 0.14, base - alto * 0.64, cx + tw * 0.14, base - alto * 0.58], fill=TINACO)
    # La luna a los pies
    d.arc([cx - ancho * 0.36, base - alto * 0.12, cx + ancho * 0.36, base + alto * 0.06], 20, 160, fill=NEGRO, width=2)


def brochazos(d, w, h, color, azar, n=60):
    """Cal aventada con brocha: tapa lo de abajo sin cubrirlo parejo."""
    for _ in range(n):
        x, y = azar.uniform(-10, w), azar.uniform(0, h)
        largo, grueso = azar.uniform(20, 70), azar.randint(3, 7)
        d.line([(x, y), (x + largo, y + azar.uniform(-3, 3))], fill=color, width=grueso)


def nos_cuida():
    azar = random.Random(3)
    im = Image.new("RGBA", (160, 80), CAL + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 159, 79], outline=MANTO, width=3)
    virgen(d, 34, 74, 66, azar)
    texto(d, (70, 14), "LA VIRGEN", MANTO)
    texto(d, (70, 28), "DEL TINACO", MANTO)
    texto(d, (70, 46), "NOS CUIDA", ROJO)
    d.line([(70, 60), (150, 60)], fill=ORO, width=2)
    return im


def agua_bendita():
    azar = random.Random(5)
    im = Image.new("RGBA", (144, 72), (58, 120, 150, 255))
    d = ImageDraw.Draw(im)
    # Un tinaco con resplandor y gotas
    for i in range(18):
        a = math.tau * i / 18
        d.line([(112 + math.cos(a) * 16, 34 + math.sin(a) * 16), (112 + math.cos(a) * 27, 34 + math.sin(a) * 27)], fill=ORO, width=2)
    d.rectangle([100, 22, 124, 50], fill=TINACO)
    d.ellipse([100, 18, 124, 27], fill=(48, 48, 54))
    for _ in range(9):
        x, y = azar.uniform(6, 138), azar.uniform(54, 68)
        d.ellipse([x, y, x + 3, y + 4], fill=(170, 220, 236))
    texto(d, (8, 10), "AGUA BENDITA", CAL)
    texto(d, (8, 26), "LA DE AQUI", CAL)
    texto(d, (8, 42), "NO LA DE LA", ORO)
    texto(d, (8, 54), "LLAVE", ORO)
    return im


def sobre_gela():
    """Un anuncio de GelA tapado a brochazos de cal, con la Virgen encima (los espectaculares)."""
    azar = random.Random(8)
    im = Image.new("RGBA", (192, 96), AZUL_GELA + (255,))
    d = ImageDraw.Draw(im)
    # Lo que quedaba del anuncio
    texto(d, (10, 8), "GelA  CUIDA EL AGUA", (230, 236, 248))
    texto(d, (10, 78), "TRABAJAMOS PARA LLEVARTE AGUA", (230, 236, 248))
    d.ellipse([150, 4, 184, 38], outline=(230, 236, 248), width=2)
    brochazos(d, 192, 96, CAL, azar, 70)
    virgen(d, 46, 90, 80, azar)
    d.rectangle([86, 22, 186, 72], fill=CAL)
    texto(d, (92, 26), "AQUI MANDA", ROJO)
    texto(d, (92, 40), "LA VIRGEN", ROJO)
    texto(d, (92, 58), "DEL TINACO", MANTO)
    # Escurridos de pintura
    for _ in range(14):
        x = azar.uniform(4, 188)
        d.line([(x, azar.uniform(40, 70)), (x, 96)], fill=CAL, width=1)
    return im


def no_abras():
    im = Image.new("RGBA", (144, 64), (226, 202, 60, 255))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 143, 63], outline=NEGRO, width=3)
    for x in range(-64, 144, 16):                    # franjas de precaucion arriba y abajo
        d.polygon([(x, 3), (x + 8, 3), (x + 16, 11), (x + 8, 11)], fill=NEGRO)
        d.polygon([(x, 52), (x + 8, 52), (x + 16, 60), (x + 8, 60)], fill=NEGRO)
    texto(d, (0, 15), "AFUERA ANDAN", NEGRO, 144)
    texto(d, (0, 27), "LOS POSEIDOS", ROJO, 144)
    texto(d, (0, 39), "NO ABRAS LA REJA", NEGRO, 144)
    return im


def pinta_cal():
    """Pinta a brocha directa sobre el muro (fondo transparente), con la Virgen de un solo color."""
    azar = random.Random(13)
    im = Image.new("RGBA", (128, 72), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    virgen(d, 28, 68, 62, azar)
    texto(d, (58, 16), "ELLA NO", CAL)
    texto(d, (58, 30), "SE SECA", CAL)
    d.line([(58, 46), (118, 44)], fill=CAL, width=2)
    return im


def main():
    os.makedirs(SALIDA, exist_ok=True)
    for nombre, hacer in (("virgen_nos_cuida", nos_cuida), ("virgen_agua_bendita", agua_bendita),
                          ("virgen_sobre_gela", sobre_gela), ("virgen_no_abras", no_abras),
                          ("virgen_pinta_cal", pinta_cal)):
        ruta = os.path.join(SALIDA, nombre + ".png")
        hacer().save(ruta)
        print("escrito", ruta)


if __name__ == "__main__":
    main()
